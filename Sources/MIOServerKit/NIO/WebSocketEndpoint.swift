//
//  WebSocketEndpoint.swift
//
//
//  Public DSL for declaring a WebSocket endpoint and its frame handlers.
//  Mirrors the HTTP endpoint authoring style (chainable, @discardableResult)
//  while keeping the WebSocket lifecycle separate.
//

import Foundation

// MARK: - ReceivedMessage

/// A message handed to the user's `onMessageReceived` callback. The
/// framework populates exactly one underlying payload (text or binary)
/// based on the inbound frame's opcode; callers query `.text()` /
/// `.data()` to find out which arrived and to extract the payload.
///
/// Why a single value type with accessors instead of overloaded callbacks
/// (one per frame type)?
///
///   * **Method proliferation.** Each new frame type the framework cares
///     about (today: text, binary; tomorrow maybe app-level ping/pong)
///     would otherwise add another `onMessageReceived` overload — the
///     public surface keeps growing and Swift's overload resolution gets
///     more fragile every step.
///   * **Silently missed frames.** A subscriber that registers only a
///     text handler has no way to know a binary frame arrived. With this
///     design, every inbound message reaches the same callback; the
///     caller decides what to do (handle, log, ignore — explicitly).
///
/// New frame types are added as new accessors on this struct, never as
/// new endpoint methods. Old call sites keep working unchanged.
public struct ReceivedMessage: Sendable
{
    /// Internal storage. Hidden from users so we can add cases later
    /// (e.g. `.applicationPing(Data)`) without breaking call sites that
    /// only look at the public accessors.
    fileprivate enum Kind: Sendable
    {
        case text( String )
        case binary( Data )
    }

    fileprivate let kind: Kind

    fileprivate init ( _ kind: Kind ) {
        self.kind = kind
    }

    /// The text payload, if this message arrived as a TEXT frame.
    /// Returns `nil` for any other frame type.
    public func text () -> String? {
        if case .text( let s ) = kind { return s }
        return nil
    }

    /// The binary payload, if this message arrived as a BINARY frame.
    /// Returns `nil` for any other frame type.
    public func data () -> Data? {
        if case .binary( let d ) = kind { return d }
        return nil
    }

    // MARK: Factories — `internal` so user code can't synthesise messages
    //                   that didn't actually traverse the framework path.

    static func text ( _ s: String ) -> ReceivedMessage { .init( .text( s ) ) }
    static func binary ( _ d: Data ) -> ReceivedMessage { .init( .binary( d ) ) }
}

// MARK: - Dispatcher / handler

/// User-supplied callback invoked once per inbound WebSocket message
/// (text or binary). `operations` exposes the reply primitives
/// (caller / all / all-but-caller).
public typealias WebSocketMessageDispatcher =
    @Sendable ( _ message: ReceivedMessage, _ operations: ConnectedWebSocketOperations ) async throws -> Void

/// Stored form of a `WebSocketMessageDispatcher`. Wrapping the closure in
/// a struct keeps the endpoint type a plain value-holder and gives us a
/// place to add per-handler hooks (logging, metrics) later without
/// changing the public closure signature.
public struct WebSocketMessageHandler: Sendable
{
    private let cb: WebSocketMessageDispatcher

    public init ( cb: @escaping WebSocketMessageDispatcher ) {
        self.cb = cb
    }

    public func run ( _ message: ReceivedMessage, _ operations: ConnectedWebSocketOperations ) async throws {
        try await cb( message, operations )
    }
}

// MARK: - Endpoint

/// Declares a WebSocket endpoint at a given URI (e.g. "/socket").
///
/// Usage:
/// ```swift
/// let chat = WebSocketEndpoint( "/chat" )
///     .onMessageReceived { message, ops in
///         if let text = message.text() {
///             try await ops.sendMessageToAllButCaller( text )
///         } else if let data = message.data() {
///             // binary receive works today; binary send is TODO
///             _ = data
///         }
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

    /// Single inbound-message callback. `nil` if `onMessageReceived` was
    /// never registered, in which case incoming frames are dropped with
    /// a debug log.
    public internal( set ) var handler: WebSocketMessageHandler?

    public init ( _ uri: String ) {
        self.uri = uri
    }

    /// Register the inbound-message handler. Returns self so calls chain
    /// in the same style as the HTTP endpoint DSL.
    @discardableResult
    public func onMessageReceived ( _ cb: @escaping WebSocketMessageDispatcher ) -> WebSocketEndpoint {
        handler = WebSocketMessageHandler( cb: cb )
        return self
    }
}
