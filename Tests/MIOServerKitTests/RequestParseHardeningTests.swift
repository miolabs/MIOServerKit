//
//  RequestParseHardeningTests.swift
//
//  End-to-end tests for request-parse failures that used to abort the whole
//  server process. Unit tests prove the parser returns sane values; these prove
//  the server is *still answering requests afterwards*, which is the property
//  that actually matters — a trap on an event-loop thread takes down every
//  connection, not just the offending one.
//
//  Raw sockets rather than URLSession: these cases need exact control of the
//  request line (a bare `?x`, an unknown method), and URLSession normalises or
//  refuses some of them.
//

@testable import MIOServerKit
import XCTest
import Foundation

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif


@Sendable
fileprivate func okHandler ( context: RouterContext ) throws -> String {
    return "OK"
}

/// Sends `raw` verbatim and returns the response, or nil if the connection
/// failed or produced nothing (which is what a crashed server looks like).
fileprivate func sendRaw ( port: Int, _ raw: String ) -> String?
{
    #if canImport(Glibc)
    let stream_type = Int32( SOCK_STREAM.rawValue )
    #else
    let stream_type = SOCK_STREAM
    #endif

    let fd = socket( AF_INET, stream_type, 0 )
    guard fd >= 0 else { return nil }
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
    guard connected == 0 else { return nil }

    // Don't hang forever if the server never answers.
    var timeout = timeval( tv_sec: 3, tv_usec: 0 )
    setsockopt( fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t( MemoryLayout<timeval>.size ) )

    let out = [UInt8]( raw.utf8 )
    guard send( fd, out, out.count, 0 ) == out.count else { return nil }

    var response = ""
    var buffer = [UInt8]( repeating: 0, count: 4096 )
    while true {
        let n = recv( fd, &buffer, buffer.count, 0 )
        if n <= 0 { break }
        response += String( decoding: buffer[ 0..<n ], as: UTF8.self )
        if response.contains( "\r\n\r\n" ) { break }
    }

    return response.isEmpty ? nil : response
}

fileprivate func statusCode ( _ response: String? ) -> Int? {
    guard let line = response?.components( separatedBy: "\r\n" ).first else { return nil }
    let parts = line.components( separatedBy: " " )
    guard parts.count >= 2 else { return nil }
    return Int( parts[ 1 ] )
}


final class RequestParseHardeningTests: XCTestCase
{
    private static let port = 8137

    private func withServer ( _ body: ( Int ) throws -> Void ) throws
    {
        let routes = Router()
        routes.endpoint( "/health" ).get( okHandler )

        let server = NIOServer( routes: routes )
        let thread = Thread { server.run( port: RequestParseHardeningTests.port ) }
        thread.start()
        XCTAssertTrue( server.waitForServerRunning() )

        defer { try? server.terminateServer() }
        try body( RequestParseHardeningTests.port )
    }

    /// Asserts the server is still serving — the real regression check.
    private func assertStillAlive ( _ port: Int, _ message: String ) {
        let response = sendRaw( port: port, "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" )
        XCTAssertEqual( statusCode( response ), 200, message )
    }

    /// `GET /health?x` used to trap on `array[1]` in the query parser.
    func test_valuelessQueryParameter_doesNotKillServer ( ) throws {
        try withServer { port in
            let response = sendRaw( port: port, "GET /health?x HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" )
            XCTAssertEqual( statusCode( response ), 200, "A valueless query parameter should be served normally" )

            assertStillAlive( port, "Server died handling a valueless query parameter" )
        }
    }

    func test_queryParameterWithRepeatedEquals_doesNotKillServer ( ) throws {
        try withServer { port in
            let response = sendRaw( port: port, "GET /health?a=b=c HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" )
            XCTAssertEqual( statusCode( response ), 200 )

            assertStillAlive( port, "Server died handling a value containing '='" )
        }
    }

    /// `TRACE /` used to trap force-unwrapping `EndpointMethod(rawValue:)`.
    func test_unknownHTTPMethod_returnsNotImplementedAndKeepsServing ( ) throws {
        try withServer { port in
            let response = sendRaw( port: port, "TRACE /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" )
            XCTAssertEqual( statusCode( response ), 501, "An unsupported method should be answered with 501" )

            assertStillAlive( port, "Server died handling TRACE" )
        }
    }

    func test_extensionHTTPMethod_returnsNotImplementedAndKeepsServing ( ) throws {
        try withServer { port in
            let response = sendRaw( port: port, "PROPFIND /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n" )
            XCTAssertEqual( statusCode( response ), 501 )

            assertStillAlive( port, "Server died handling PROPFIND" )
        }
    }

    /// All of them in sequence on one server, to catch any cumulative damage.
    func test_serverSurvivesAllMalformedRequestsInSequence ( ) throws {
        try withServer { port in
            let malformed = [ "GET /health?x HTTP/1.1",
                              "GET /health?&& HTTP/1.1",
                              "GET /health?=novalue HTTP/1.1",
                              "GET /health?a=b=c HTTP/1.1",
                              "TRACE /health HTTP/1.1",
                              "PROPFIND /health HTTP/1.1",
                              "WHATEVER /health HTTP/1.1",
                            ]

            for line in malformed {
                _ = sendRaw( port: port, "\(line)\r\nHost: localhost\r\nConnection: close\r\n\r\n" )
                assertStillAlive( port, "Server died after: \(line)" )
            }
        }
    }
}
