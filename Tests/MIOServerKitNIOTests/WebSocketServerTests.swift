/*

Test to send and receive messages

*/

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
            return
        }
        XCTFail("unexpected execution path")
    } catch {
       XCTFail("unexpected exception: \(error)")
    }
    XCTFail("unexpected execution path")
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

func connectToServerReadAndWrite(_ serverUrl: String, _ messageToRead: String, _ messageToSend: String) async {
    let url = URL(string: serverUrl)!
    let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    let connection: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: url)

    do {
        for try await message in connection.receive() {
            XCTAssertEqual(message, messageToRead)
            try await connection.send(messageToSend)
            connection.close()
            return
        }
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
            return
         }
    } catch {
        XCTFail("unexpected exception: \(error)")
    }
}

func connectToServerWriteAndReadNothing(_ serverUrl: String, _ messageToSend: String, timeoutSeconds: Int) async {
    let url = URL(string: serverUrl)!
    let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    let connection: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: url)
    Task {
        do {
            try await connection.send(messageToSend)
            for try await message in connection.receive() {
                XCTFail("unexpected message: \(message)")
                connection.close()
                return
            }
        } catch {
            let errorStr = String(describing: error)
            if errorStr != "closed" {
                XCTFail("unexpected exception: \(error)")
            }
        }
    }
    usleep(useconds_t(timeoutSeconds * 1000000)) 
    connection.close()
}

// MARK: - Launch Server
func launchServer(routes: Router = Router(), webSocketEndpoints: [WebSocketEndpoint] = []) async throws -> NIOWebSocketServer {
    let server = NIOWebSocketServer(routes: Router(), webSocketEndpoints: webSocketEndpoints )
    Task {
            server.run(port:8888)
        } 
    let serverOk = server.waitForServerRunning()
    XCTAssertTrue(serverOk)
    ////usleep(2 * 1000000) // seconds
    return (server)
}

final class WebSocketServerTests: XCTestCase {
    
    func test_Launch_AndJustClose() async throws {
        let server = try await launchServer()
        usleep(useconds_t(2 * 1000000)) // seconds
        try server.terminateServer()
    }

// MARK: - invalid conn
    // func test_InvalidConnection_01() async throws {
    //     let server = try await launchServer()
    //     let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    //     let client: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: URL(string: "ws://localhost:8888/invalid")!)
    //     usleep(useconds_t(2 * 1000000)) // seconds
    //     try server.terminateServer()
    // }    

// MARK: - ping
    func test_ClientSendsString_01() async throws {
        var closureCalled = false
        let wsEndPoint = WebSocketEndpoint("/socket").OnText { message, _ in
            XCTAssertEqual(message, "Hello server")
            closureCalled = true
        }
        let server = try await launchServer(routes: Router(), webSocketEndpoints: [wsEndPoint] )

        let clientTask = Task.detached {
            await connectToServerAndWrite("ws://localhost:8888/socket", "Hello server")
        }
        _ = await clientTask.result

        let startTime = Date()
        let timeOutSecs: TimeInterval  = 3
        while !closureCalled && Date().timeIntervalSince(startTime) < timeOutSecs { usleep(100000) } // give time to read the message 
        try server.terminateServer()
        XCTAssertTrue(closureCalled)
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

// MARK: - pong
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

    func test_ServerSendsStringClientAnswer_01() async throws {
        var closureCalled = false
        let serverMessage = "Hello client"
        let clientAnswer = "Hello server, I'm the client"
        let wsEndPoint = WebSocketEndpoint("/socket").OnText { message, operations in
            XCTAssertEqual(message, clientAnswer)
            closureCalled = true
        }
        let server = try await launchServer(routes: Router(), webSocketEndpoints: [wsEndPoint] )

        let clientTask = Task.detached {
            await connectToServerReadAndWrite("ws://localhost:8888/socket", serverMessage, clientAnswer)
        }
        
        while server.webSocketClients.ConnectedClientsCount("/socket") == 0 { usleep(100000) } // 0.1 seconds 
        try await server.webSocketClients.SendTextToAll("/socket", serverMessage)
        _ = await clientTask.result
        
        let startTime = Date()
        let timeOutSecs: TimeInterval  = 3
        while !closureCalled && Date().timeIntervalSince(startTime) < timeOutSecs { usleep(100000) } // give time to read the message
        try server.terminateServer()
        usleep(useconds_t(2 * 1000000)) // seconds
        XCTAssertTrue(closureCalled)
    }
   
// MARK: - rcv & distribute
    func test_ClientSendsStringServerDistribute_01() async throws {
        let clientMessage = "I changed something"
        let wsEndPoint = WebSocketEndpoint("/socket").OnText { message, operations in
            XCTAssertEqual(message, clientMessage)
            try await operations.SendTextToAllButCaller(clientMessage)
        }
        let server = try await launchServer(routes: Router(), webSocketEndpoints: [wsEndPoint] )

        var clientTask01: Task<Void, Never>? = nil
        await withCheckedContinuation { continuation in
            clientTask01 = Task.detached {
                await connectToServerAndRead("ws://localhost:8888/socket", clientMessage ) {
                   continuation.resume()
                }
            }
        }
        var clientTask02: Task<Void, Never>? = nil
        await withCheckedContinuation { continuation in
            clientTask02 = Task.detached {
                await connectToServerAndRead("ws://localhost:8888/socket", clientMessage ) {
                   continuation.resume()
                }
            }
        }
        while server.webSocketClients.ConnectedClientsCount("/socket") < 2 { usleep(100000) } // 0.1 seconds 
        
        let clientWriter = Task.detached {
            await connectToServerWriteAndReadNothing("ws://localhost:8888/socket", clientMessage, timeoutSeconds: 3)
        }
        _ = await clientWriter.result
        _ = await clientTask01?.result
        _ = await clientTask02?.result
        try server.terminateServer()
        usleep(useconds_t(2 * 1000000)) // seconds
    }
 
}



