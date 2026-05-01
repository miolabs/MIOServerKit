//
//  WebSocketServerTests.swift
//
//
//  End-to-end tests for the NIO WebSocket upgrade path. Each test
//  spins up a real `NIOServer` on a fixed port, drives it with a
//  `URLSession`-based client (see `WebSocketClient.swift`), and
//  asserts on framework-level outcomes (handler fired, broadcast
//  delivered, frame too big closed connection).
//
//  Concurrency: the framework's `OnText` dispatcher is `@Sendable`,
//  so tests can't capture a mutable `var` directly inside the closure.
//  Instead we use `XCTestExpectation` — fulfilment is Sendable-safe
//  and `await fulfillment(of:timeout:)` replaces the `usleep` poll
//  loops the legacy branch was using.
//

import XCTest
import Foundation
@testable import MIOServerKit

// MARK: - Server bootstrap

/// Test port. swift test runs serially per target so a fixed port is
/// fine; if you parallelise tests in the future, randomise this.
fileprivate let testPort = 8888
fileprivate let testHost = "ws://localhost:\(testPort)"

/// Spin up a real `NIOServer` on `testPort` and block until it
/// accepts connections. Returns after the listen socket is ready.
fileprivate func launchServer (
    routes: Router = Router(),
    webSocketEndpoints: [WebSocketEndpoint] = []
) async throws -> NIOServer {
    let server = NIOServer( routes: routes, webSocketEndpoints: webSocketEndpoints )
    Task.detached { server.run( port: testPort ) }
    let started = server.waitForServerRunning()
    XCTAssertTrue( started, "Server failed to start within timeout" )
    // Small slack so the listen socket is fully ready for accept().
    // Without it, fast tests occasionally connect-before-listen.
    try await Task.sleep( nanoseconds: 100_000_000 )  // 0.1s
    return server
}

/// Wait until at least `expected` clients are registered on the URI,
/// or fail the test if it doesn't happen in time. Replaces the usleep
/// busy-loop the branch tests used.
fileprivate func waitForClients (
    _ server: NIOServer,
    uri: String,
    atLeast expected: Int,
    timeoutSeconds: Double = 3
) async throws {
    let deadline = Date().addingTimeInterval( timeoutSeconds )
    while server.webSocketCatalog.ConnectedClientsCount( uri ) < expected {
        if Date() > deadline {
            XCTFail( "Timed out waiting for \(expected) client(s) on \(uri); current = \(server.webSocketCatalog.ConnectedClientsCount(uri))" )
            return
        }
        try await Task.sleep( nanoseconds: 50_000_000 )  // 0.05s
    }
}

// MARK: - Client behaviours

/// Connect, wait for the server to send `messageToRead`, assert
/// equality, then close. `onReady` fires once the connection is open
/// so the caller knows when it's safe to broadcast.
fileprivate func connectToServerAndRead (
    _ url: String,
    _ messageToRead: String,
    onReady: @escaping @Sendable () -> Void
) async {
    guard let parsed = URL( string: url ) else { XCTFail( "bad url: \(url)" ); return }
    let connection: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory().open( at: parsed )
    do {
        onReady()
        for try await message in connection.receive() {
            XCTAssertEqual( message, messageToRead )
            connection.close()
            return
        }
    } catch {
        XCTFail( "unexpected exception: \(error)" )
    }
}

fileprivate func connectToServerAndWrite ( _ url: String, _ messageToSend: String ) async {
    guard let parsed = URL( string: url ) else { XCTFail( "bad url: \(url)" ); return }
    let connection: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory().open( at: parsed )
    do {
        try await connection.send( messageToSend )
        connection.close()
    } catch {
        XCTFail( "unexpected exception: \(error)" )
    }
}

fileprivate func connectToServerReadAndWrite (
    _ url: String, _ messageToRead: String, _ messageToSend: String
) async {
    guard let parsed = URL( string: url ) else { XCTFail( "bad url: \(url)" ); return }
    let connection: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory().open( at: parsed )
    do {
        for try await message in connection.receive() {
            XCTAssertEqual( message, messageToRead )
            try await connection.send( messageToSend )
            connection.close()
            return
        }
    } catch {
        XCTFail( "unexpected exception: \(error)" )
    }
}

fileprivate func connectToServerWriteAndRead (
    _ url: String, _ messageToSend: String, _ messageToRead: String
) async {
    guard let parsed = URL( string: url ) else { XCTFail( "bad url: \(url)" ); return }
    let connection: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory().open( at: parsed )
    do {
        try await connection.send( messageToSend )
        for try await message in connection.receive() {
            XCTAssertEqual( message, messageToRead )
            connection.close()
            return
        }
    } catch {
        XCTFail( "unexpected exception: \(error)" )
    }
}

/// Send a message then sit on the receive side for a fixed window —
/// used by the broadcast test where a third "writer" client should
/// not get its own message echoed back.
fileprivate func connectToServerWriteAndReadNothing (
    _ url: String, _ messageToSend: String, timeoutSeconds: Double
) async {
    guard let parsed = URL( string: url ) else { XCTFail( "bad url: \(url)" ); return }
    let connection: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory().open( at: parsed )
    let listener = Task {
        do {
            try await connection.send( messageToSend )
            for try await message in connection.receive() {
                XCTFail( "writer client should not receive its own broadcast: \(message)" )
                connection.close()
                return
            }
        } catch {
            // 'closed' is the expected termination when we cancel below.
            if String( describing: error ) != "closed" {
                XCTFail( "unexpected exception in writer: \(error)" )
            }
        }
    }
    try? await Task.sleep( nanoseconds: UInt64( timeoutSeconds * 1_000_000_000 ) )
    connection.close()
    listener.cancel()
}

// MARK: - Tests

final class WebSocketServerTests: XCTestCase
{
    func test_Launch_AndJustClose () async throws {
        let server = try await launchServer()
        try server.terminateServer()
    }

    // MARK: invalid connections

    func test_InvalidConnection_NoEndpointsRegistered () async throws {
        let server = try await launchServer()
        let client: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory()
            .open( at: URL( string: "\(testHost)/invalid" )! )
        try await Task.sleep( nanoseconds: 1_500_000_000 )
        XCTAssertTrue( client.isClosed(), "Expected client to be closed when no endpoints exist" )
        try server.terminateServer()
    }

    func test_InvalidConnection_WrongURI () async throws {
        let ep = WebSocketEndpoint( "/socket" )
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        // Wrong URI: should fail upgrade and the URLSession task should
        // close. We give it 1.5s — in practice the rejection is much faster.
        let bad: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory()
            .open( at: URL( string: "\(testHost)/invalid" )! )
        try await Task.sleep( nanoseconds: 1_500_000_000 )
        XCTAssertTrue( bad.isClosed(), "wrong-URI client should be closed" )

        // Right URI: should stay open.
        let good: WebSocketConnection<String, String> = DefaultWebSocketConnectionFactory()
            .open( at: URL( string: "\(testHost)/socket" )! )
        try await Task.sleep( nanoseconds: 1_000_000_000 )
        XCTAssertFalse( good.isClosed(), "valid-URI client should be open" )

        good.close()
        try server.terminateServer()
    }

    // MARK: client → server

    func test_ClientSendsString () async throws {
        let received = expectation( description: "OnText fires with client message" )
        let ep = WebSocketEndpoint( "/socket" ).OnText { message, _ in
            XCTAssertEqual( message, "Hello server" )
            received.fulfill()
        }
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        await Task.detached {
            await connectToServerAndWrite( "\(testHost)/socket", "Hello server" )
        }.value

        await fulfillment( of: [ received ], timeout: 3 )
        try server.terminateServer()
    }

    // MARK: server → client (broadcast)

    func test_ServerSendsString () async throws {
        let ep = WebSocketEndpoint( "/socket" )
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        let connected = expectation( description: "client connected" )
        let clientTask = Task.detached {
            await connectToServerAndRead( "\(testHost)/socket", "Hello client" ) {
                connected.fulfill()
            }
        }
        await fulfillment( of: [ connected ], timeout: 3 )
        try await waitForClients( server, uri: "/socket", atLeast: 1 )

        try await server.webSocketCatalog.SendTextToAll( "/socket", "Hello client" )
        _ = await clientTask.result

        try server.terminateServer()
    }

    // MARK: round-trip — client speaks, server replies via SendTextToCaller

    func test_ClientSendsServerReplies () async throws {
        let clientMessage = "Hello server"
        let serverAnswer = "Hello client, I'm the server"

        let ep = WebSocketEndpoint( "/socket" ).OnText { message, ops in
            XCTAssertEqual( message, clientMessage )
            try await ops.SendTextToCaller( serverAnswer )
        }
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        await Task.detached {
            await connectToServerWriteAndRead( "\(testHost)/socket", clientMessage, serverAnswer )
        }.value

        try server.terminateServer()
    }

    // MARK: round-trip — server speaks first, client replies

    func test_ServerSendsClientReplies () async throws {
        let serverMessage = "Hello client"
        let clientAnswer = "Hello server, I'm the client"

        let received = expectation( description: "OnText fires with client reply" )
        let ep = WebSocketEndpoint( "/socket" ).OnText { message, _ in
            XCTAssertEqual( message, clientAnswer )
            received.fulfill()
        }
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        let clientTask = Task.detached {
            await connectToServerReadAndWrite( "\(testHost)/socket", serverMessage, clientAnswer )
        }
        try await waitForClients( server, uri: "/socket", atLeast: 1 )
        try await server.webSocketCatalog.SendTextToAll( "/socket", serverMessage )
        _ = await clientTask.result

        await fulfillment( of: [ received ], timeout: 3 )
        try server.terminateServer()
    }

    // MARK: fan-out — caller broadcasts to peers via SendTextToAllButCaller

    func test_BroadcastSkipsCaller () async throws {
        let clientMessage = "I changed something"
        let ep = WebSocketEndpoint( "/socket" ).OnText { message, ops in
            XCTAssertEqual( message, clientMessage )
            try await ops.SendTextToAllButCaller( clientMessage )
        }
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        // Two readers — each should receive the broadcast.
        let connected1 = expectation( description: "reader 1 connected" )
        let reader1 = Task.detached {
            await connectToServerAndRead( "\(testHost)/socket", clientMessage ) {
                connected1.fulfill()
            }
        }
        let connected2 = expectation( description: "reader 2 connected" )
        let reader2 = Task.detached {
            await connectToServerAndRead( "\(testHost)/socket", clientMessage ) {
                connected2.fulfill()
            }
        }
        await fulfillment( of: [ connected1, connected2 ], timeout: 3 )
        try await waitForClients( server, uri: "/socket", atLeast: 2 )

        // Writer — should NOT receive its own broadcast.
        let writer = Task.detached {
            await connectToServerWriteAndReadNothing(
                "\(testHost)/socket", clientMessage, timeoutSeconds: 2
            )
        }

        _ = await writer.result
        _ = await reader1.result
        _ = await reader2.result
        try server.terminateServer()
    }

    // MARK: frame size

    func test_MaxFrameSize_OK () async throws {
        let size = 16 * 1024
        let payload = String( repeating: "U", count: size )
        let received = expectation( description: "OnText fires with full payload" )
        let ep = WebSocketEndpoint( "/socket" ).OnText { message, _ in
            XCTAssertEqual( message.count, size )
            received.fulfill()
        }
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        await Task.detached {
            await connectToServerAndWrite( "\(testHost)/socket", payload )
        }.value

        await fulfillment( of: [ received ], timeout: 3 )
        try server.terminateServer()
    }

    /// One byte over the default 16 KiB max frame size. NIO's WebSocket
    /// frame decoder closes the connection; the server's `OnText`
    /// handler must NOT fire. Inverted expectation asserts the absence
    /// over a fixed window.
    func test_FrameTooBig_ClosesConnection () async throws {
        let size = 16 * 1024 + 1
        let payload = String( repeating: "U", count: size )
        let notReceived = expectation( description: "OnText must NOT fire" )
        notReceived.isInverted = true

        let ep = WebSocketEndpoint( "/socket" ).OnText { _, _ in
            notReceived.fulfill()
        }
        let server = try await launchServer( webSocketEndpoints: [ ep ] )

        await Task.detached {
            await connectToServerAndWrite( "\(testHost)/socket", payload )
        }.value

        await fulfillment( of: [ notReceived ], timeout: 2 )
        try server.terminateServer()
    }
}
