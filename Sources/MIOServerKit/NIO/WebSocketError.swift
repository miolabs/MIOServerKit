//
//  WebSocketError.swift
//
//
//  Errors thrown from the WebSocket subsystem. Kept narrow on purpose:
//  most failures (encode, transport, peer write) are propagated as-is
//  from NIO/Foundation. This type exists for application-level signals
//  that need a stable case the caller can switch on.
//

import Foundation

public enum WebSocketError: Error, Sendable
{
    /// A feature that is declared on the public API but not yet
    /// implemented. Currently raised by the binary `Data` overloads of
    /// `sendMessageTo*` — the surface exists so callers can compile
    /// against the final shape, but the encoder for binary frames has
    /// not been wired up. Callers must check for this and fall back to
    /// the text path until the feature lands.
    case notImplemented( String )
}

extension WebSocketError: LocalizedError
{
    public var errorDescription: String? {
        switch self {
        case .notImplemented( let detail ):
            return "WebSocket feature not implemented: \(detail)"
        }
    }
}
