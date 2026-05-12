//
//  ServerObserver.swift
//
//
//  Lifecycle hooks the NIO server emits so application code can build
//  metrics, tracing, or audit pipelines without the kit having to ship
//  any concrete implementation. The kit holds a single weak reference;
//  apps that need fan-out compose their own observer.
//

import Foundation


/// Per-request handle returned by `ServerObserver.requestWillDispatch`.
/// The kit calls `end(error:)` exactly once when the dispatch completes
/// (success or failure). The observer owns whatever state the span
/// carries (start time, URL, counters) and is responsible for keeping
/// `end` cheap and non-blocking.
public protocol RequestSpan: AnyObject
{
    func end ( error: Error? )
}


/// Implemented by application code and assigned to `NIOServer.observer`.
/// Every method has a default no-op so adopters only override the hooks
/// they care about.
///
/// **Threading.** Hooks fire from whichever thread is driving the event
/// (event loop, thread-pool worker, Swift Task). Implementations must be
/// thread-safe and must not block — anything heavier than a counter
/// bump or dictionary write should be deferred to the observer's own
/// queue.
public protocol ServerObserver: AnyObject
{
    // MARK: Request lifecycle

    /// Called once per HTTP request, on the event loop, immediately
    /// before the endpoint is dispatched. Return `nil` to skip tracking
    /// this request — `end` will not be called.
    func requestWillDispatch (
        url: String,
        method: String,
        executionType: MethodEndpoint.EndpointExecutionType
    ) -> RequestSpan?

    // MARK: Server lifecycle

    /// Fired after the listening socket is bound and the server has
    /// announced readiness.
    func serverDidStart ( port: Int )

    /// Fired right before the channel is closed and thread pools wind
    /// down. Implementations should flush any buffered telemetry here.
    func serverWillShutdown ()

    // MARK: WebSocket lifecycle

    /// Fired after a WebSocket upgrade completes and the client has been
    /// added to the catalog.
    func webSocketClientConnected ( uri: String, clientId: ConnectedClientID )

    /// Fired when a WebSocket client is removed from the catalog —
    /// either because the peer closed, the channel went inactive, or
    /// the server tore the connection down. Idempotent: only fires for
    /// the actual removal, not for repeated cleanup calls.
    func webSocketClientDisconnected ( uri: String, clientId: ConnectedClientID )
}


extension ServerObserver
{
    public func requestWillDispatch (
        url: String,
        method: String,
        executionType: MethodEndpoint.EndpointExecutionType
    ) -> RequestSpan? { nil }

    public func serverDidStart ( port: Int ) {}
    public func serverWillShutdown () {}

    public func webSocketClientConnected ( uri: String, clientId: ConnectedClientID ) {}
    public func webSocketClientDisconnected ( uri: String, clientId: ConnectedClientID ) {}
}
