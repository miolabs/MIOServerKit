//
//  WebSocketClient.swift
//
//
//  URLSession-based WebSocket client used by `WebSocketServerTests`.
//  Kept as test-only infrastructure — the framework itself ships only
//  the server side. URLSession was chosen over NIO-as-a-client to avoid
//  pulling another transport stack into the test target; for the
//  scenarios we care about (text frames, close, fragmentation limits)
//  it's fully sufficient.
//

import Foundation

// MARK: - URLSession delegate

/// Captures the close event so tests can poll `isClosed()` without
/// blocking on receive(). Threadsafe because `URLSession` invokes the
/// delegate from its own queue and we never write to `closed` outside
/// of `urlSession(_:task:didCompleteWithError:)`.
final class WebSocketDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable
{
    private let lock = NSLock()
    private var _closed: Bool = false

    var closed: Bool {
        lock.lock(); defer { lock.unlock() }
        return _closed
    }

    func urlSession ( _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error? ) {
        lock.lock(); _closed = true; lock.unlock()
    }
}

// MARK: - Factory

public protocol WebSocketConnectionFactory: Sendable
{
    func open<Incoming: Decodable & Sendable, Outgoing: Encodable & Sendable> (
        at url: URL
    ) -> WebSocketConnection<Incoming, Outgoing>
}

public final class DefaultWebSocketConnectionFactory: Sendable
{
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init ( encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder() ) {
        self.encoder = encoder
        self.decoder = decoder
    }
}

extension DefaultWebSocketConnectionFactory: WebSocketConnectionFactory
{
    public func open<Incoming: Decodable & Sendable, Outgoing: Encodable & Sendable> (
        at url: URL
    ) -> WebSocketConnection<Incoming, Outgoing> {
        let request = URLRequest( url: url )
        let delegate = WebSocketDelegate()
        let session = URLSession( configuration: .default, delegate: delegate, delegateQueue: nil )
        let task = session.webSocketTask( with: request )
        return WebSocketConnection<Incoming, Outgoing>(
            webSocketTask: task, delegate: delegate, encoder: encoder, decoder: decoder
        )
    }
}

// MARK: - Errors

public enum WebSocketConnectionError: Error
{
    case connectionError
    case transportError
    case encodingError
    case decodingError
    case disconnected
    case closed
}

// MARK: - Connection

/// Generic typed wrapper around `URLSessionWebSocketTask`. The text path
/// hands strings through verbatim; the data path JSON-encodes/decodes.
public final class WebSocketConnection<Incoming: Decodable & Sendable, Outgoing: Encodable & Sendable>:
    NSObject, @unchecked Sendable
{
    private let webSocketTask: URLSessionWebSocketTask
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let delegate: WebSocketDelegate

    internal init (
        webSocketTask: URLSessionWebSocketTask,
        delegate: WebSocketDelegate,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.webSocketTask = webSocketTask
        self.delegate = delegate
        self.encoder = encoder
        self.decoder = decoder
        super.init()
        webSocketTask.resume()
    }

    deinit {
        // Make sure the task is torn down even if the test forgot to
        // call close() — `cancel(with:reason:)` is idempotent.
        webSocketTask.cancel( with: .goingAway, reason: nil )
    }

    public func isClosed () -> Bool { delegate.closed }

    private func receiveSingleMessage () async throws -> Incoming {
        switch try await webSocketTask.receive() {
        case let .data( messageData ):
            guard let message = try? decoder.decode( Incoming.self, from: messageData ) else {
                throw WebSocketConnectionError.decodingError
            }
            return message

        case let .string( text ):
            // Server-side `SendTextToClient` produces text frames. When
            // Incoming == String we hand the value through unchanged;
            // otherwise we cast and rely on the test to use the right
            // generic parameter. A force-cast here is acceptable because
            // it's bounded to the test target.
            return text as! Incoming

        @unknown default:
            assertionFailure( "Unknown WebSocket message type" )
            webSocketTask.cancel( with: .unsupportedData, reason: nil )
            throw WebSocketConnectionError.decodingError
        }
    }

    /// Map a transport-level error to one of the typed cases.
    /// Centralised here so both `send` and `receive` paths are consistent.
    private func mapTransportError () -> WebSocketConnectionError {
        switch webSocketTask.closeCode {
        case .invalid:        return .connectionError
        case .goingAway:      return .disconnected
        case .normalClosure:  return .closed
        default:              return .transportError
        }
    }

    public func send ( _ message: Outgoing ) async throws {
        do {
            if Outgoing.self == String.self {
                guard let stringValue = message as? String else { return }
                try await webSocketTask.send( .string( stringValue ) )
            } else {
                guard let data = try? encoder.encode( message ) else {
                    throw WebSocketConnectionError.encodingError
                }
                try await webSocketTask.send( .data( data ) )
            }
        } catch {
            throw mapTransportError()
        }
    }

    public func receiveOnce () async throws -> Incoming {
        do {
            return try await receiveSingleMessage()
        } catch let error as WebSocketConnectionError {
            throw error
        } catch {
            throw mapTransportError()
        }
    }

    public func receive () -> AsyncThrowingStream<Incoming, Error> {
        AsyncThrowingStream { [weak self] in
            guard let self else { return nil }
            let message = try await self.receiveOnce()
            return Task.isCancelled ? nil : message
        }
    }

    public func close () {
        webSocketTask.cancel( with: .normalClosure, reason: nil )
    }
}
