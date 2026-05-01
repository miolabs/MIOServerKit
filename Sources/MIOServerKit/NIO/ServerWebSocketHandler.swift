//
//  ServerWebSocketHandler.swift
//
//
//  Channel handler installed on a connection AFTER the HTTP→WebSocket
//  upgrade completes. Receives `WebSocketFrame` inbound and dispatches
//  each frame to the per-connection `ConnectedWebSocket.gotFrame` async
//  method, preserving per-connection arrival order.
//
//  Bridges NIO (sync, on the event loop) → Swift Concurrency (async)
//  via a single `AsyncStream` per connection: `channelRead` yields
//  frames into the stream; one consumer Task awaits each `gotFrame`
//  call serially. This guarantees ordering without spawning a Task
//  per frame.
//

import Foundation
import NIOCore
import NIOWebSocket
import MIOCoreLogger

final class ServerWebSocketHandler: ChannelInboundHandler, @unchecked Sendable
{
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let uri: String
    private let connection: ConnectedWebSocket
    private let catalog: ConnectedWebSocketCatalog

    /// Continuation half of the frame pipe. Frames yielded from
    /// `channelRead` are consumed serially by `consumerTask`.
    private var continuation: AsyncStream<WebSocketFrame>.Continuation?
    private var consumerTask: Task<Void, Never>?

    /// Tracks whether `RemoveClient` has been called. `channelInactive`
    /// fires once per channel but defensive idempotency makes this safe
    /// even if a future refactor changes the call pattern.
    private var didRemoveFromCatalog = false

    init ( uri: String, connection: ConnectedWebSocket, catalog: ConnectedWebSocketCatalog ) {
        self.uri = uri
        self.connection = connection
        self.catalog = catalog
    }

    func handlerAdded ( context: ChannelHandlerContext ) {
        let ( stream, continuation ) = AsyncStream<WebSocketFrame>.makeStream()
        self.continuation = continuation

        // Capture everything the consumer task needs by value/ref so the
        // Task closure stays Sendable. `connection` is @unchecked Sendable.
        let conn = self.connection
        let uri = self.uri
        let channel = context.channel

        consumerTask = Task {
            do {
                for await frame in stream {
                    let shouldClose = try await conn.gotFrame( frame )
                    if shouldClose {
                        // Peer asked to close (or subclass requested it).
                        // Closing the channel triggers channelInactive,
                        // which finishes the stream and unregisters us.
                        try? await channel.close().get()
                        break
                    }
                }
            } catch {
                Log.error( "WebSocket frame loop crashed on \(uri): \(error)" )
                try? await channel.close().get()
            }
        }
    }

    func channelRead ( context: ChannelHandlerContext, data: NIOAny ) {
        let frame = self.unwrapInboundIn( data )
        // yield is non-blocking and threadsafe per the AsyncStream contract.
        // If the consumer is slow, frames buffer in the stream — the only
        // alternative would be to drop, which the WebSocket spec disallows.
        continuation?.yield( frame )
    }

    func channelInactive ( context: ChannelHandlerContext ) {
        // Finish the stream first so the consumer drains and exits cleanly.
        continuation?.finish()
        continuation = nil

        // Remove from catalog BEFORE firing the inactive event so any
        // broadcast that races with the close doesn't try to write to a
        // dead channel.
        if !didRemoveFromCatalog {
            catalog.removeClient( uri, connection.id )
            didRemoveFromCatalog = true
        }

        context.fireChannelInactive()
    }

    func errorCaught ( context: ChannelHandlerContext, error: Error ) {
        Log.error( "WebSocket channel error on \(uri): \(error)" )
        context.close( promise: nil )
    }

    deinit {
        // Defensive: if the channel was torn down without channelInactive
        // (shouldn't happen in normal NIO flow), make sure the Task
        // doesn't leak waiting on a stream that will never finish.
        continuation?.finish()
        consumerTask?.cancel()
    }
}
