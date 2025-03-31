/*

WebSocketClient implementation for testing the server 

*/

import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket

// import MIOServerKit
// import MIOServerKit_NIO

import Foundation


public protocol WebSocketConnectionFactory: Sendable {
    func open<Incoming: Decodable & Sendable, Outgoing: Encodable & Sendable>(at url: URL) -> WebSocketConnection<Incoming, Outgoing>
}

class WebSocketDelegate: NSObject, URLSessionTaskDelegate {
    public var closed = false

    // Tells the delegate that the task finished transferring data.
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        closed = true
        if let error = error {
            //print("WebSocket cerrado con error: \(error.localizedDescription)")
        } else {
            //print("WebSocket cerrado correctamente")
        }
    }
}

/// A default implementation of ``WebSocketConnectionFactory``.
public final class DefaultWebSocketConnectionFactory: Sendable {
    //private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// Initialise a new instance of ``WebSocketConnectionFactory``.
    ///
    /// - Parameters:
    ///   - urlSession: URLSession used for opening WebSockets.
    ///   - encoder: JSONEncoder used to encode outgoing message bodies.
    ///   - decoder: JSONDecoder used to decode incoming message bodies.
    public init(
        //urlSession: URLSession = URLSession.shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        //self.urlSession = urlSession
        self.encoder = encoder
        self.decoder = decoder
    }
}

extension DefaultWebSocketConnectionFactory: WebSocketConnectionFactory {
    public func open<Incoming: Decodable & Sendable, Outgoing: Encodable & Sendable>(at url: URL) -> WebSocketConnection<Incoming, Outgoing> {
        let request = URLRequest(url: url)
        let delegate = WebSocketDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let webSocketTask = session.webSocketTask(with: request)

        let ret =  WebSocketConnection<Incoming, Outgoing>(webSocketTask: webSocketTask, delegate: delegate, encoder: encoder, decoder: decoder)
        return ret
    }
}

// Enumeration of possible errors that might occur while using ``WebSocketConnection``.
public enum WebSocketConnectionError: Error {
    case connectionError
    case transportError
    case encodingError
    case decodingError
    case disconnected
    case closed
}

/// A generic WebSocket Connection over an expected `Incoming` and `Outgoing` message type.
public final class WebSocketConnection<Incoming: Decodable & Sendable, Outgoing: Encodable & Sendable>: NSObject, Sendable {
    private let webSocketTask: URLSessionWebSocketTask
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let delegate: WebSocketDelegate

    internal init(webSocketTask: URLSessionWebSocketTask, delegate: WebSocketDelegate, encoder: JSONEncoder = JSONEncoder(), decoder: JSONDecoder = JSONDecoder()) {
        self.webSocketTask = webSocketTask
        self.delegate = delegate
        self.encoder = encoder
        self.decoder = decoder
        super.init()
        webSocketTask.resume()
    }

    deinit {
        webSocketTask.cancel(with: .goingAway, reason: nil) // Make sure to cancel the WebSocketTask (if not already canceled or completed)
    }

    public func isClosed() -> Bool {
        return delegate.closed
    }

    private func receiveSingleMessage() async throws -> Incoming {
        switch try await webSocketTask.receive() {
            case let .data(messageData):
                guard let message = try? decoder.decode(Incoming.self, from: messageData) else {
                    throw WebSocketConnectionError.decodingError
                }

                return message

            case let .string(text):
                //assertionFailure("Did not expect to receive message as text")

                // Alternative 1: Unsupported data, closing the WebSocket Connection
                // webSocketTask.cancel(with: .unsupportedData, reason: nil)
                // throw WebSocketConnectionError.decodingFailure

                // Alternative 1: Try to parse the message data anyway
                // guard
                //     let messageData = text.data(using: .utf8),
                //     let message = try? decoder.decode(Incoming.self, from: messageData)
                // else {
                //     throw WebSocketConnectionError.decodingError
                // }
                // return message
                print("Message received as text: \(text)")
                // let messageData = text.data(using: .utf8)
                // if var byteBuffer = messageData as? ByteBuffer {
                //     let bytes = byteBuffer.readableBytesView
                //     print("Received bytes: \(Array(bytes))") 
                //     print("Received string: \(String(decoding: bytes, as: UTF8.self))") 
                // } else {
                //     print("Frame is not a ByteBuffer")
                // }
                return text as! Incoming

            @unknown default:
                assertionFailure("Unknown message type")

                // Unsupported data, closing the WebSocket Connection
                webSocketTask.cancel(with: .unsupportedData, reason: nil)
                throw WebSocketConnectionError.decodingError
        }
    }
}

// MARK: Public Interface

extension WebSocketConnection {
    func send(_ message: Outgoing) async throws {
        do {
            if Outgoing.self == String.self {
                guard let stringValue = message as? String else {
                    return 
                }
                try await webSocketTask.send(.string(stringValue))
            } else {
                guard let messageData = try? encoder.encode(message) else {
                    throw WebSocketConnectionError.encodingError
                }
                try await webSocketTask.send(.data(messageData))
            }
        } catch {
            switch webSocketTask.closeCode {
                case .invalid:
                    throw WebSocketConnectionError.connectionError

                case .goingAway:
                    throw WebSocketConnectionError.disconnected

                case .normalClosure:
                    throw WebSocketConnectionError.closed

                default:
                    throw WebSocketConnectionError.transportError
            }
        }
    }

    func receiveOnce() async throws -> Incoming {
        do {
            return try await receiveSingleMessage()
        } catch let error as WebSocketConnectionError {
            throw error
        } catch {
            switch webSocketTask.closeCode {
                case .invalid:
                    throw WebSocketConnectionError.connectionError

                case .goingAway:
                    throw WebSocketConnectionError.disconnected

                case .normalClosure:
                    throw WebSocketConnectionError.closed

                default:
                    throw WebSocketConnectionError.transportError
            }
        }
    }

    func receive() -> AsyncThrowingStream<Incoming, Error> {
        AsyncThrowingStream { [weak self] in
            guard let self else {
                // Self is gone, return nil to end the stream
                return nil
            }

            let message = try await self.receiveOnce()

            // End the stream (by returning nil) if the calling Task was canceled
            return Task.isCancelled ? nil : message
        }
    }

    func close() {
        webSocketTask.cancel(with: .normalClosure, reason: nil)
    }
}
