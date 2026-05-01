//
//  WebSocketEndpoint.swift
//
//
//  Public DSL for declaring a WebSocket endpoint and its frame handlers.
//  Mirrors the HTTP endpoint authoring style (chainable, @discardableResult)
//  while keeping the WebSocket lifecycle separate.
//

import Foundation

/// Frame types a `WebSocketEndpoint` can handle. Currently only TEXT is
/// surfaced to user code; ping/pong/close are handled by the framework.
/// BINARY is reserved for a future extension.
public enum WebSocketEndpointFrameType: String, Sendable
{
    case TEXT = "TEXT"
}

/// User-supplied callback invoked on every incoming text frame.
/// `operations` provides reply primitives (caller / all / all-but-caller).
public typealias WebSocketEndpointRequestDispatcher =
    @Sendable ( _ message: String, _ operations: ConnectedWebSocketOperations ) async throws -> Void

/// Wrapper around the user's frame handler. Kept as a struct so the endpoint
/// methods table can be stored by value and copied cheaply.
public struct WebSocketEndpointMethodHandler: Sendable
{
    private let cb: WebSocketEndpointRequestDispatcher

    public init ( cb: @escaping WebSocketEndpointRequestDispatcher ) {
        self.cb = cb
    }

    public func run ( _ message: String, _ operations: ConnectedWebSocketOperations ) async throws {
        try await cb( message, operations )
    }
}

/// Declares a WebSocket endpoint at a given URI (e.g. "/socket").
///
/// Usage:
/// ```swift
/// let chat = WebSocketEndpoint( "/chat" )
///     .onText { message, ops in
///         try await ops.sendMessageToAllButCaller( message )
///     }
/// let server = NIOServer( routes: router, webSocketEndpoints: [ chat ] )
/// ```
///
/// Endpoints are passed to `NIOServer` at construction time and registered
/// in a `ConnectedWebSocketCatalog`. The framework consults the catalog in
/// `shouldUpgrade` to decide whether to accept the upgrade request.
public final class WebSocketEndpoint: @unchecked Sendable
{
    public let uri: String
    public internal( set ) var methods: [ WebSocketEndpointFrameType: WebSocketEndpointMethodHandler ] = [:]

    public init ( _ uri: String ) {
        self.uri = uri
    }

    /// Register a handler for incoming text frames. Returns self so calls
    /// chain in the same style as the HTTP endpoint DSL.
    @discardableResult
    public func onText ( _ cb: @escaping WebSocketEndpointRequestDispatcher ) -> WebSocketEndpoint {
        methods[ .TEXT ] = WebSocketEndpointMethodHandler( cb: cb )
        return self
    }
}
