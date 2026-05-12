//
//  ConnectedWebSocketCatalog.swift
//
//
//  Registry of WebSocket endpoints + the connected clients bucketed under
//  each endpoint's URI. Owned by `NIOServer` and consulted at upgrade time
//  to decide whether a request can be promoted to a WebSocket connection.
//

import Foundation
import NIOCore
import NIOConcurrencyHelpers
import MIOCoreLogger

public typealias ConnectedClientID = String
public typealias EndpointURI = String

/// Reply primitives exposed to user-supplied frame handlers. The concrete
/// implementation is `ConnectedWebSocket`; abstracted as a protocol so the
/// public DSL doesn't depend on the concrete connection type.
public protocol ConnectedWebSocketOperations: AnyObject, Sendable
{
    // MARK: Text frames — implemented.

    func sendMessageToCaller ( _ text: String ) async throws

    /// Broadcast to every peer on this endpoint. `skipCaller` defaults
    /// to `true` (via the protocol extension below) because the most
    /// common pattern — chat-style fan-out — wants the sender excluded
    /// since they already have a local copy of the message. Pass
    /// `skipCaller: false` for echo-to-everyone scenarios.
    func sendMessageToAll ( _ text: String, skipCaller: Bool ) async throws

    // MARK: Binary frames — surface declared, encoder TODO.
    //
    // These overloads exist so application code can compile against the
    // final shape of the API. They currently throw
    // `WebSocketError.notImplemented`; flip on the binary frame
    // encoder + opcode dispatch and they light up.
    func sendMessageToCaller ( _ data: Data ) async throws
    func sendMessageToAll ( _ data: Data, skipCaller: Bool ) async throws
}

extension ConnectedWebSocketOperations
{
    /// Convenience overload — `skipCaller` defaults to `true` for the
    /// common chat / broadcast case.
    ///
    /// Lives in an extension because Swift's support for default
    /// arguments in protocol method *requirements* is brittle (the
    /// default sometimes does not flow through to call sites typed as
    /// the protocol). The wrapper guarantees `ops.sendMessageToAll(text)`
    /// always resolves cleanly through the protocol witness.
    public func sendMessageToAll ( _ text: String ) async throws {
        try await sendMessageToAll( text, skipCaller: true )
    }

    public func sendMessageToAll ( _ data: Data ) async throws {
        try await sendMessageToAll( data, skipCaller: true )
    }
}

/// All clients currently connected to a single WebSocket endpoint, plus a
/// back-reference to the endpoint definition so frame handlers can be
/// looked up without a second hop through the catalog.
///
/// Concurrency: this type owns its own lock for client list mutations.
/// The parent catalog's lock protects the dict-of-buckets only; once you
/// have a bucket reference, all `_clients` access flows through the lock
/// here. Locks are never held simultaneously, so there is no ordering risk.
public final class ConnectedClientsToEndpoint: @unchecked Sendable
{
    public let endPoint: WebSocketEndpoint
    private var _clients: [ ConnectedClientID: ConnectedWebSocket ] = [:]
    private let lock = NIOLock()

    public init ( _ endPoint: WebSocketEndpoint ) {
        self.endPoint = endPoint
    }

    /// Returns a snapshot copy of the connected clients. Callers iterate the
    /// snapshot without holding the lock — essential for broadcasts that
    /// `await` per-peer writes.
    public func snapshot () -> [ ConnectedWebSocket ] {
        lock.lock(); defer { lock.unlock() }
        return Array( _clients.values )
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return _clients.count
    }

    func addClient ( _ id: ConnectedClientID, _ client: ConnectedWebSocket ) {
        lock.lock(); defer { lock.unlock() }
        _clients[ id ] = client
    }

    @discardableResult
    func removeClient ( _ id: ConnectedClientID ) -> ConnectedWebSocket? {
        lock.lock(); defer { lock.unlock() }
        return _clients.removeValue( forKey: id )
    }
}

/// Top-level WebSocket catalog. One instance per `NIOServer`.
///
/// Concurrency: every public method is short and non-suspending. Internal
/// state is protected by an `NIOLock` (faster than `NSLock` and explicitly
/// designed for NIO). The async `sendMessageToAll` snapshots the client list
/// under the lock and writes outside of it so we never await while holding.
public final class ConnectedWebSocketCatalog: @unchecked Sendable
{
    private var webSockets: [ EndpointURI: ConnectedClientsToEndpoint ] = [:]
    private let lock = NIOLock()

    /// Lifecycle observer set by `NIOServer` when the application
    /// assigns one. The catalog calls connect/disconnect hooks outside
    /// the catalog lock to keep observer code from blocking other
    /// catalog operations.
    public weak var observer: ServerObserver?

    public init () {}

    /// Register endpoint definitions. Called once at server construction.
    /// Subsequent calls add to the existing set; collisions overwrite, which
    /// matches the HTTP `Router.endpoint` "last writer wins" behavior.
    public func addEndpoints ( _ endPoints: [ WebSocketEndpoint ] ) {
        lock.lock(); defer { lock.unlock() }
        for ep in endPoints {
            webSockets[ ep.uri ] = ConnectedClientsToEndpoint( ep )
        }
    }

    /// Used by `shouldUpgrade` to decide whether to accept the upgrade.
    public func containsEndpoint ( _ uri: String ) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return webSockets[ uri ] != nil
    }

    /// Look up the endpoint definition for a URI. Returns nil if the URI
    /// has no registered endpoint — callers must not have reached this
    /// point unless `containsEndpoint` previously returned true.
    public func endpoint ( for uri: String ) -> WebSocketEndpoint? {
        lock.lock(); defer { lock.unlock() }
        return webSockets[ uri ]?.endPoint
    }

    /// Number of clients currently connected to a given endpoint URI.
    /// Useful for tests and metrics. Releases the catalog lock before
    /// reading the bucket's count so the two locks are never nested.
    public func connectedClientsCount ( _ uri: String ) -> Int {
        lock.lock()
        let bucket = webSockets[ uri ]
        lock.unlock()
        return bucket?.count ?? 0
    }

    /// Construct and register a new client. Called from the upgrade
    /// pipeline handler once the WebSocket handshake completes. Returns nil
    /// if the URI has no registered endpoint, in which case the caller
    /// should close the channel — though in practice `shouldUpgrade` will
    /// have rejected the request before reaching this point.
    @discardableResult
    public func addClient (
        _ uri: String,
        _ newClientId: ConnectedClientID,
        _ allocator: ByteBufferAllocator,
        _ channel: Channel
    ) -> ConnectedWebSocket? {
        lock.lock()
        guard let bucket = webSockets[ uri ] else {
            lock.unlock()
            return nil
        }
        let client = ConnectedWebSocket( newClientId, allocator, channel, bucket )
        bucket.addClient( newClientId, client )
        lock.unlock()

        observer?.webSocketClientConnected( uri: uri, clientId: newClientId )
        return client
    }

    /// Remove a client. Idempotent — safe to call from `channelInactive`
    /// even if the upgrade never completed. The observer disconnect hook
    /// only fires when a client was actually removed, so repeated cleanup
    /// calls don't double-emit.
    public func removeClient ( _ uri: String, _ clientId: ConnectedClientID ) {
        lock.lock()
        let removed = webSockets[ uri ]?.removeClient( clientId ) != nil
        lock.unlock()

        if removed {
            observer?.webSocketClientDisconnected( uri: uri, clientId: clientId )
        }
    }

    /// Broadcast a text frame to every client connected to a given URI.
    ///
    /// Fan-out is parallel: each peer write is dispatched to its own child
    /// task so a slow peer only delays itself, not the rest of the cohort.
    /// Per-peer failures are logged and skipped; the broadcast as a whole
    /// never throws, so the caller's `try` is decorative — kept on the API
    /// surface for symmetry with `sendMessageToCaller` which can fail.
    /// `channelInactive` eventually evicts the dead client from the bucket.
    public func sendMessageToAll ( _ uri: String, _ text: String ) async throws {
        lock.lock()
        let bucket = webSockets[ uri ]
        lock.unlock()
        guard let bucket else { return }

        let snapshot = bucket.snapshot()
        await withTaskGroup( of: Void.self ) { group in
            for client in snapshot {
                group.addTask {
                    do {
                        try await client.sendMessageToClient( text )
                    } catch {
                        Log.error( "WebSocket broadcast failed for client \(client.id) on \(uri): \(error)" )
                    }
                }
            }
        }
    }

    /// Binary broadcast — surface declared, encoder TODO.
    ///
    /// Mirrors the text overload above. When the binary frame encoder
    /// lands on `ConnectedWebSocket.sendMessageToClient(_: Data)`, this
    /// stub can be replaced with the same `withTaskGroup` fan-out pattern
    /// used for text. Until then it throws so callers fail fast rather
    /// than silently no-op.
    public func sendMessageToAll ( _ uri: String, _ data: Data ) async throws {
        // TODO: implement once ConnectedWebSocket.sendMessageToClient(_: Data) lands.
        throw WebSocketError.notImplemented(
            "ConnectedWebSocketCatalog.sendMessageToAll(_:_: Data)"
        )
    }
}
