//
//  ConnectedWebSocket.swift
//
//
//  Per-connection state for an upgraded WebSocket channel. Owns the frame
//  decode loop (text / ping / close / continuation) and exposes the reply
//  primitives declared by `ConnectedWebSocketOperations`.
//
//  Designed for the classic NIO pipeline: writes go through `Channel`'s
//  outbound side, and the WebSocket frame encoder (installed by the
//  upgrader) converts `WebSocketFrame` to bytes before they hit the wire.
//

import Foundation
import NIOCore
import NIOWebSocket
import MIOCoreLogger

open class ConnectedWebSocket: ConnectedWebSocketOperations, @unchecked Sendable
{
    /// Stable id assigned at upgrade time. Used as the catalog key and
    /// surfaced in logs so a misbehaving client can be tracked across
    /// frames without leaking the underlying socket address.
    public let id: ConnectedClientID
    public let allocator: ByteBufferAllocator

    /// The upgraded channel. `Channel` is `Sendable` in current swift-nio;
    /// `writeAndFlush` is thread-safe (it hops to the channel's event loop
    /// internally). We keep a strong reference so reply primitives can be
    /// called from any Task without worrying about lifetime.
    public let channel: Channel

    /// Back-reference to the bucket of all clients on this endpoint.
    /// Lets `sendMessageToAll` / `sendMessageToAllButCaller` enumerate peers
    /// without round-tripping through the catalog.
    public let allConnections: ConnectedClientsToEndpoint

    required public init (
        _ id: ConnectedClientID,
        _ allocator: ByteBufferAllocator,
        _ channel: Channel,
        _ allConnections: ConnectedClientsToEndpoint
    ) {
        self.id = id
        self.allocator = allocator
        self.channel = channel
        self.allConnections = allConnections
    }

    // MARK: - Subclass hooks

    /// Override to short-circuit the default frame dispatch. Return
    /// `( frameProcessed: true, _ )` to skip default handling, or
    /// `( _, closeConnection: true )` to tear the connection down.
    open func onFrameFromClientProcessed ( _ frame: WebSocketFrame ) -> ( Bool, Bool ) {
        return ( false, false )
    }

    /// Default TEXT-frame entry point. Looks up the endpoint's registered
    /// text handler and runs it. Errors are logged, never silently
    /// swallowed — silent catch was a debugging hazard on the legacy branch.
    /// Subclasses can override either this overload or the binary one
    /// below independently.
    open func onMessageReceivedFromClient ( _ text: String ) async {
        let endPoint = allConnections.endPoint
        guard let handler = endPoint.textHandler else {
            Log.debug( "WebSocket text frame on \(endPoint.uri) but no text handler registered" )
            return
        }
        do {
            try await handler.run( text, self )
        } catch {
            Log.error( "WebSocket text handler failed on \(endPoint.uri) for client \(id): \(error)" )
        }
    }

    /// Default BINARY-frame entry point. Symmetric with the text overload:
    /// looks up the endpoint's binary handler and runs it. Receive-side
    /// binary is fully wired (no encoding needed — frames arrive as raw
    /// bytes); send-side is still a TODO (see the `Data` overloads of
    /// `sendMessageTo*` further down).
    open func onMessageReceivedFromClient ( _ data: Data ) async {
        let endPoint = allConnections.endPoint
        guard let handler = endPoint.binaryHandler else {
            Log.debug( "WebSocket binary frame on \(endPoint.uri) but no binary handler registered" )
            return
        }
        do {
            try await handler.run( data, self )
        } catch {
            Log.error( "WebSocket binary handler failed on \(endPoint.uri) for client \(id): \(error)" )
        }
    }

    // MARK: - ConnectedWebSocketOperations (reply primitives)

    public func sendMessageToClient ( _ text: String ) async throws {
        var buffer = allocator.buffer( capacity: text.utf8.count )
        buffer.writeString( text )
        let frame = WebSocketFrame( fin: true, opcode: .text, data: buffer )
        try await channel.writeAndFlush( frame ).get()
    }

    public func sendMessageToCaller ( _ text: String ) async throws {
        try await sendMessageToClient( text )
    }

    /// Fan out a text frame to every peer on this endpoint.
    ///
    /// Writes run in parallel via `withTaskGroup` so a slow peer only delays
    /// its own delivery — the rest of the cohort isn't blocked behind it.
    /// Per-peer failures are logged and swallowed; this method never throws
    /// in practice, but the signature stays `throws` to match the protocol.
    /// `channelInactive` eventually evicts the dead client from the bucket.
    public func sendMessageToAll ( _ text: String ) async throws {
        let peers = allConnections.snapshot()
        await withTaskGroup( of: Void.self ) { group in
            for peer in peers {
                group.addTask {
                    do {
                        try await peer.sendMessageToClient( text )
                    } catch {
                        Log.error( "WebSocket fan-out failed for peer \(peer.id): \(error)" )
                    }
                }
            }
        }
    }

    /// Same fan-out as `sendMessageToAll`, but skips the caller. Captures
    /// `self.id` into a local before the task group so the closures don't
    /// retain `self`.
    public func sendMessageToAllButCaller ( _ text: String ) async throws {
        let peers = allConnections.snapshot()
        let myId = self.id
        await withTaskGroup( of: Void.self ) { group in
            for peer in peers where peer.id != myId {
                group.addTask {
                    do {
                        try await peer.sendMessageToClient( text )
                    } catch {
                        Log.error( "WebSocket fan-out (skip-caller) failed for peer \(peer.id): \(error)" )
                    }
                }
            }
        }
    }

    // MARK: - Binary frames — surface declared, encoder TODO
    //
    // The four overloads below mirror the text path one-for-one. Each
    // currently throws `WebSocketError.notImplemented` so callers can
    // compile against the final shape of the API but get a fast,
    // discoverable failure if they invoke them. To enable binary support:
    //
    //   1. Implement `sendMessageToClient(_: Data)` to wrap the bytes
    //      in a `WebSocketFrame(opcode: .binary, ...)` and write to the
    //      channel — same shape as the text version above.
    //   2. The other three overloads can then call through to it
    //      (caller / fan-out / fan-out-skipping-caller) using the same
    //      `withTaskGroup` pattern as text.
    //   3. Add `onBinary(_: Data)` on `WebSocketEndpoint` and dispatch
    //      `.binary` opcodes in `gotFrame` to make the receive side
    //      symmetrical.

    public func sendMessageToClient ( _ data: Data ) async throws {
        // TODO: implement binary frame encode + write.
        throw WebSocketError.notImplemented( "ConnectedWebSocket.sendMessageToClient(_: Data)" )
    }

    public func sendMessageToCaller ( _ data: Data ) async throws {
        // TODO: route to sendMessageToClient(_: Data) once implemented.
        throw WebSocketError.notImplemented( "ConnectedWebSocket.sendMessageToCaller(_: Data)" )
    }

    public func sendMessageToAll ( _ data: Data ) async throws {
        // TODO: parallel fan-out using sendMessageToClient(_: Data).
        throw WebSocketError.notImplemented( "ConnectedWebSocket.sendMessageToAll(_: Data)" )
    }

    public func sendMessageToAllButCaller ( _ data: Data ) async throws {
        // TODO: parallel fan-out using sendMessageToClient(_: Data), skipping self.
        throw WebSocketError.notImplemented( "ConnectedWebSocket.sendMessageToAllButCaller(_: Data)" )
    }

    // MARK: - Frame dispatch

    /// Drives the frame protocol for a single inbound frame. Returns
    /// `true` when the connection should be closed (peer sent a close
    /// frame, or a subclass requested it via `onFrameFromClientProcessed`).
    /// Called from `ServerWebSocketHandler` on the channel's event loop
    /// thread bridged into a Task.
    func gotFrame ( _ frame: WebSocketFrame ) async throws -> Bool {
        var ( frameProcessed, closeConnection ) = onFrameFromClientProcessed( frame )
        if closeConnection { return true }
        if frameProcessed { return false }

        switch frame.opcode {
        case .text:
            var data = frame.data
            if let mask = frame.maskKey { data.webSocketUnmask( mask ) }
            let text = data.getString( at: data.readerIndex, length: data.readableBytes ) ?? ""
            if frame.fin == false {
                // Fragmented frames: payload is delivered now, continuation
                // frames will follow. The current implementation does not
                // reassemble — left as a follow-up. Log so we notice if a
                // real client starts fragmenting.
                Log.warning( "WebSocket received fragmented TEXT frame on \(allConnections.endPoint.uri); reassembly not implemented" )
            }
            await onMessageReceivedFromClient( text )

        case .ping:
            var data = frame.data
            if let mask = frame.maskKey { data.webSocketUnmask( mask ) }
            let pong = WebSocketFrame( fin: true, opcode: .pong, data: data )
            try await channel.writeAndFlush( pong ).get()

        case .connectionClose:
            // Echo the status code per RFC 6455 §5.5.1, then signal closure.
            var unmasked = frame.unmaskedData
            let codeSlice = unmasked.readSlice( length: 2 ) ?? ByteBuffer()
            let closeFrame = WebSocketFrame( fin: true, opcode: .connectionClose, data: codeSlice )
            try await channel.writeAndFlush( closeFrame ).get()
            closeConnection = true

        case .continuation:
            // Continuation frames belong to a fragmented message — see
            // the note under `.text`. Drop until reassembly lands.
            Log.debug( "WebSocket received CONTINUATION frame; ignored (reassembly not implemented)" )

        case .binary:
            var payload = frame.data
            if let mask = frame.maskKey { payload.webSocketUnmask( mask ) }
            if frame.fin == false {
                // Same caveat as `.text`: fragmented binary frames are
                // delivered piecewise; reassembly across continuations
                // is not implemented.
                Log.warning( "WebSocket received fragmented BINARY frame on \(allConnections.endPoint.uri); reassembly not implemented" )
            }
            // Extract the raw bytes into a `Data` so user code doesn't
            // need to know about NIO's `ByteBuffer`. `payload.readData`
            // never returns nil for a valid buffer, but fall back to
            // empty just in case.
            let bytes = payload.readData( length: payload.readableBytes ) ?? Data()
            await onMessageReceivedFromClient( bytes )

        case .pong:
            // We don't currently send pings, so an unsolicited pong is
            // benign. Ignore.
            break

        default:
            Log.warning( "WebSocket received unknown opcode \(frame.opcode) on \(allConnections.endPoint.uri)" )
        }

        return closeConnection
    }
}
