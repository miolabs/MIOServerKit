

// import NIOCore
// import NIOPosix
// import NIOHTTP1
// import NIOWebSocket

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation

// MARK: - client behavior
func connectToServerAndRead(_ serverUrl: String, _ messageToRead: String,  onReady: @escaping () -> Void) async {
    let url = URL(string: serverUrl)!
    let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    let connection: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: url)
    do {
        onReady()
        for try await message in connection.receive() {
            XCTAssertEqual(message, messageToRead)
            connection.close()
        }
    } catch {
       XCTFail("unexpected exception: \(error)")
    }
}

func connectToServerAndWrite(_ serverUrl: String, _ messageToSend: String) async {
    let url = URL(string: serverUrl)!
    let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    let connection: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: url)

    do {
        try await connection.send(messageToSend)
        connection.close()
    } catch {
        XCTFail("unexpected exception: \(error)")
    }
}

func connectToServerWriteAndRead(_ serverUrl: String, _ messageToSend: String, _ messageToRead: String) async {
    let url = URL(string: serverUrl)!
    let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    let connection: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: url)

    do {
        try await connection.send(messageToSend)
        for try await message in connection.receive() {
            XCTAssertEqual(message, messageToRead)
            connection.close()
         }
    } catch {
        XCTFail("unexpected exception: \(error)")
    }
}

// MARK: - Launch Server
func launchServer(routes: Router = Router(), webSocketEndpoints: [WebSocketEndpoint] = []) async throws -> NIOWebSocketServer {
    let server = NIOWebSocketServer(routes: Router(), webSocketEndpoints: webSocketEndpoints )
    Task {
        do {
            try server.run(port:8888)
        } catch {
             print("Error ejecutando el servidor: \(error)")
        }
    }
    let serverOk = server.waitForServerRunning()
    XCTAssertTrue(serverOk)
    ////usleep(2 * 1000000) // seconds
    print("Test:  Server started")
    return (server)
}

final class WebSocketServerTests: XCTestCase {
// MARK: - Replace hndlr
    
    func test_Launch_AndJustClose() async throws {
        let server = try await launchServer()
        usleep(useconds_t(2 * 1000000)) // seconds
        try server.terminateServer()
    }

    func test_ClientSendsString_01() async throws {
        let wsEndPoint = WebSocketEndpoint("/socket").OnText { message, _ in
            XCTAssertEqual(message, "Hello server")
        }
        let server = try await launchServer(routes: Router(), webSocketEndpoints: [wsEndPoint] )

        let clientTask = Task.detached {
            await connectToServerAndWrite("ws://localhost:8888/socket", "Hello server")
        }
        _ = await clientTask.result
        
        try server.terminateServer()
        usleep(2 * 1000000)
    }

    func test_ServerSendsString_01() async throws {
        let wsEndPoint = WebSocketEndpoint("/socket")

        let server = try await launchServer(routes: Router(), webSocketEndpoints: [wsEndPoint] )

        var clientTask: Task<Void, Never>? = nil
        await withCheckedContinuation { continuation in
            clientTask = Task.detached {
                let textToRead = "Hello client"
                await connectToServerAndRead("ws://localhost:8888/socket", textToRead ) {
                   continuation.resume()
                }
            }
        }
        while server.webSocketClients.ConnectedClientsCount("/socket") == 0 { usleep(100000) } // 0.1 seconds 
        try await server.webSocketClients.SendTextToAll("/socket", "Hello client")
        _ = await clientTask?.result
        try server.terminateServer()
        usleep(useconds_t(2 * 1000000)) // seconds
    }

    func test_ClientSendsStringServerAnswer_01() async throws {
        let clientMessage = "Hello server"
        let serverAnswer = "Hello client, I'm the server"
        let wsEndPoint = WebSocketEndpoint("/socket").OnText { message, operations in
            XCTAssertEqual(message, clientMessage)
            try await operations.SendTextToCaller(serverAnswer)
        }
        let server = try await launchServer(routes: Router(), webSocketEndpoints: [wsEndPoint] )

        let clientTask = Task.detached {
            await connectToServerWriteAndRead("ws://localhost:8888/socket", clientMessage, serverAnswer)
        }
        _ = await clientTask.result
        
        try server.terminateServer()
        usleep(2 * 1000000)
    }


   


 
}



