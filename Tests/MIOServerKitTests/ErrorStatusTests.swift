//
//  ErrorStatusTests.swift
//
//  A thrown error that carries its own HTTP status must be answered with that
//  status. Before this, anything that was not a ServerError became a 500, so
//  every authentication failure in the platform looked like a server fault.
//

@testable import MIOServerKit
import MIOCore
import XCTest
import Foundation

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif


private enum ProbeError : Error, LocalizedError, MIOHTTPStatusError
{
    case expired
    case forbidden
    case teapot
    case misconfigured

    var httpStatusCode: Int {
        switch self {
        case .expired      : return 401
        case .forbidden    : return 403
        case .teapot       : return 418
        case .misconfigured: return 500
        }
    }

    var errorDescription: String? {
        switch self {
        case .expired      : return "Token expired at some point"
        case .forbidden    : return "Not your business"
        case .teapot       : return "Short and stout"
        case .misconfigured: return "Keys not loaded"
        }
    }
}

/// Carries no status, so it must still fall through to 500.
private enum PlainError : Error { case boom }


@Sendable private func throwsExpired      ( context: RouterContext ) throws -> String { throw ProbeError.expired }
@Sendable private func throwsForbidden    ( context: RouterContext ) throws -> String { throw ProbeError.forbidden }
@Sendable private func throwsTeapot       ( context: RouterContext ) throws -> String { throw ProbeError.teapot }
@Sendable private func throwsMisconfigured( context: RouterContext ) throws -> String { throw ProbeError.misconfigured }
@Sendable private func throwsPlain        ( context: RouterContext ) throws -> String { throw PlainError.boom }
@Sendable private func throwsServerError  ( context: RouterContext ) throws -> String { throw ServerError.general( .badRequest, "nope" ) }
@Sendable private func succeeds           ( context: RouterContext ) throws -> String { return "OK" }


private func request ( port: Int, path: String ) -> ( status: Int?, body: String )
{
    #if canImport(Glibc)
    let stream_type = Int32( SOCK_STREAM.rawValue )
    #else
    let stream_type = SOCK_STREAM
    #endif

    let fd = socket( AF_INET, stream_type, 0 )
    guard fd >= 0 else { return ( nil, "" ) }
    defer { close( fd ) }

    var addr = sockaddr_in()
    addr.sin_family = sa_family_t( AF_INET )
    addr.sin_port   = UInt16( port ).bigEndian
    inet_pton( AF_INET, "127.0.0.1", &addr.sin_addr )

    let connected = withUnsafePointer( to: &addr ) { pointer in
        pointer.withMemoryRebound( to: sockaddr.self, capacity: 1 ) {
            connect( fd, $0, socklen_t( MemoryLayout<sockaddr_in>.size ) )
        }
    }
    guard connected == 0 else { return ( nil, "" ) }

    var timeout = timeval( tv_sec: 3, tv_usec: 0 )
    setsockopt( fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t( MemoryLayout<timeval>.size ) )

    let out = [UInt8]( "GET \(path) HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".utf8 )
    guard send( fd, out, out.count, 0 ) == out.count else { return ( nil, "" ) }

    var response = ""
    var buffer = [UInt8]( repeating: 0, count: 4096 )
    while true {
        let n = recv( fd, &buffer, buffer.count, 0 )
        if n <= 0 { break }
        response += String( decoding: buffer[ 0..<n ], as: UTF8.self )
    }

    let status = response.components( separatedBy: "\r\n" ).first
                         .flatMap { line -> Int? in
                             let parts = line.components( separatedBy: " " )
                             return parts.count >= 2 ? Int( parts[ 1 ] ) : nil
                         }

    let body = response.range( of: "\r\n\r\n" ).map { String( response[ $0.upperBound... ] ) } ?? ""
    return ( status, body )
}


final class ErrorStatusTests: XCTestCase
{
    private static let port = 8141

    private func withServer ( _ body: ( Int ) throws -> Void ) throws
    {
        let routes = Router()
        routes.endpoint( "/expired"       ).get( throwsExpired       )
        routes.endpoint( "/forbidden"     ).get( throwsForbidden     )
        routes.endpoint( "/teapot"        ).get( throwsTeapot        )
        routes.endpoint( "/misconfigured" ).get( throwsMisconfigured )
        routes.endpoint( "/plain"         ).get( throwsPlain         )
        routes.endpoint( "/servererror"   ).get( throwsServerError   )
        routes.endpoint( "/ok"            ).get( succeeds            )

        let server = NIOServer( routes: routes )
        let thread = Thread { server.run( port: ErrorStatusTests.port ) }
        thread.start()
        XCTAssertTrue( server.waitForServerRunning() )

        defer { try? server.terminateServer() }
        try body( ErrorStatusTests.port )
    }

    func test_errorCarryingStatus_isAnsweredWithThatStatus ( ) throws {
        try withServer { port in
            XCTAssertEqual( request( port: port, path: "/expired"       ).status, 401 )
            XCTAssertEqual( request( port: port, path: "/forbidden"     ).status, 403 )
            XCTAssertEqual( request( port: port, path: "/teapot"        ).status, 418 )
            XCTAssertEqual( request( port: port, path: "/misconfigured" ).status, 500 )
        }
    }

    func test_errorCarryingStatus_sendsItsDescription ( ) throws {
        try withServer { port in
            XCTAssertTrue( request( port: port, path: "/expired" ).body.contains( "Token expired" ) )
        }
    }

    /// The regression this guards: an error with no status must not be promoted
    /// out of 500, and a ServerError must keep taking precedence.
    func test_errorWithoutStatus_stillFallsBackTo500 ( ) throws {
        try withServer { port in
            XCTAssertEqual( request( port: port, path: "/plain" ).status, 500 )
        }
    }

    func test_serverErrorStillMapsThroughItsOwnStatus ( ) throws {
        try withServer { port in
            XCTAssertEqual( request( port: port, path: "/servererror" ).status, 400 )
        }
    }

    func test_successfulRequestIsUnaffected ( ) throws {
        try withServer { port in
            let result = request( port: port, path: "/ok" )
            XCTAssertEqual( result.status, 200 )
        }
    }
}
