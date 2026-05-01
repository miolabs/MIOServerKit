//
//  WebSocketEndpoint.swift
//
//
//  Public DSL for declaring a WebSocket endpoint and its frame handlers.
//  Mirrors the HTTP endpoint authoring style (chainable, @discardableResult)
//  while keeping the WebSocket lifecycle separate.
//

import Foundation

/// User-supplied callback for incoming TEXT frames.
/// `operations` exposes the reply primitives (caller / all / all-but-caller).
public typealias WebSocketTextDispatcher =
    @Sendable ( _ text: String, _ operations: ConnectedWebSocketOperations ) async throws -> Void

/// User-supplied callback for incoming BINARY frames.
///
/// Receive-side binary is fully implemented: frames arriving with the
/// `.binary` opcode are decoded into `Data` and dispatched here. The
/// send-side counterpart (`sendMessageTo*(_: Data)`) is still a TODO,
/// so a handler can read binary payloads but cannot reply with one yet.
public typealias WebSocketBinaryDispatcher =
    @Sendable ( _ data: Data, _ operations: ConnectedWebSocketOperations ) async throws -> Void

// MARK: - Handler wrappers

/// Stored form of a `WebSocketTextDispatcher`. Wrapping the closure in a
/// struct keeps the endpoint type a plain value-holder and lets us add
/// per-handler hooks (logging, metrics) without touching the public
/// closure signature.
public struct WebSocketTextHandler: Sendable
{
    private let cb: WebSocketTextDispatcher

    public init ( cb: @escaping WebSocketTextDispatcher ) {
        self.cb = cb
    }

    public func run ( _ text: String, _ operations: ConnectedWebSocketOperations ) async throws {
        try await cb( text, operations )
    }
}

/// Stored form of a `WebSocketBinaryDispatcher`. See note on
/// `WebSocketBinaryDispatcher` — present but inert until binary receive
/// dispatch lands in `ConnectedWebSocket.gotFrame`.
public struct WebSocketBinaryHandler: Sendable
{
    private let cb: WebSocketBinaryDispatcher

    public init ( cb: @escaping WebSocketBinaryDispatcher ) {
        self.cb = cb
    }

    public func run ( _ data: Data, _ operations: ConnectedWebSocketOperations ) async throws {
        try await cb( data, operations )
    }
}

// MARK: - Endpoint

/// Declares a WebSocket endpoint at a given URI (e.g. "/socket").
///
/// Usage — text handler (works today):
/// ```swift
/// let chat = WebSocketEndpoint( "/chat" )
///     .onMessageReceived { (text: String, ops) in
///         try await ops.sendMessageToAllButCaller( text )
///     }
/// let server = NIOServer( routes: router, webSocketEndpoints: [ chat ] )
/// ```
///
/// Usage — binary handler (declared, dispatch TODO):
/// ```swift
/// chat.onMessageReceived { (data: Data, ops) in
///     // handle binary payload
/// }
/// ```
///
/// The two overloads of `onMessageReceived` differ only in the closure's
/// first parameter type (`String` vs `Data`). Swift's overload resolution
/// can usually pick the right one from context, but if your closure body
/// doesn't make the type obvious, annotate the parameter explicitly
/// (as in the examples above) to keep diagnostics readable.
///
/// Endpoints are passed to `NIOServer` at construction time and registered
/// in a `ConnectedWebSocketCatalog`. The framework consults the catalog in
/// `shouldUpgrade` to decide whether to accept the upgrade request.
public final class WebSocketEndpoint: @unchecked Sendable
{
    public let uri: String

    /// Handler invoked for every TEXT frame received on this endpoint.
    /// `nil` if no `onMessageReceived(String, …)` overload was registered.
    public internal( set ) var textHandler: WebSocketTextHandler?

    /// Handler invoked for every BINARY frame received on this endpoint.
    /// `nil` if no `onMessageReceived(Data, …)` overload was registered.
    public internal( set ) var binaryHandler: WebSocketBinaryHandler?

    public init ( _ uri: String ) {
        self.uri = uri
    }

    /// Register a handler for incoming TEXT frames. Returns self so calls
    /// chain in the same style as the HTTP endpoint DSL.
    @discardableResult
    public func onMessageReceived ( _ cb: @escaping WebSocketTextDispatcher ) -> WebSocketEndpoint {
        textHandler = WebSocketTextHandler( cb: cb )
        return self
    }

    /// Register a handler for incoming BINARY frames. Returns self so
    /// calls chain in the same style as the text overload.
    @discardableResult
    public func onMessageReceived ( _ cb: @escaping WebSocketBinaryDispatcher ) -> WebSocketEndpoint {
        binaryHandler = WebSocketBinaryHandler( cb: cb )
        return self
    }
}
