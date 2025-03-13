

// import NIOCore
// import NIOPosix
// import NIOHTTP1
// import NIOWebSocket

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation


func openAndConsumeWebSocketConnection(_ notifyRunning: DispatchSemaphore) async {
    let url = URL(string: "ws://localhost:8888")!

    let webSocketConnectionFactory = DefaultWebSocketConnectionFactory()
    //let connection: WebSocketConnection<IncomingMessage, OutgoingMessage> = webSocketConnectionFactory.open(at: url)
    let connection: WebSocketConnection<String, String> = webSocketConnectionFactory.open(at: url)

    //self.connection = connection

    do {
        print("openAndConsumeWebSocketConnection")
        // Start consuming IncomingMessages
        notifyRunning.signal()
        for try await message in connection.receive() {
            print("Received message in client:", message)
        }

        print("IncomingMessage stream ended")
    } catch {
        print("Error receiving messages:", error)
    }
}



// MARK: - Launch Server
func launchServer() async throws -> (NIOWebSocketServer<ConnectedWebSocket>) {
    let server = NIOWebSocketServer<ConnectedWebSocket>(port:8888 )
    // let serverThread = Thread {
    //      try await server.run()
    // }
    // serverThread.start()
    Task {
        do {
            try server.runAndWait()
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

    func test_WithClient() async throws {
        let server = try await launchServer()

        let waitClient = DispatchSemaphore(value: 0)
        var webSocketConnectionTask = Task.detached {
            print("openAndConsumeWebSocketConnection in test 1")
            await openAndConsumeWebSocketConnection(waitClient)
            print("openAndConsumeWebSocketConnection in test 2")
            //waitClient.signal()
        }
        waitClient.wait()
        _ = await webSocketConnectionTask.result
        print("Waiting for webSocketConnectionTask")
        webSocketConnectionTask.cancel()
        print("webSocketConnectionTask cancelled")
        try server.terminateServer()
    }

    func test_WithClient02() async throws {
        let server = try await launchServer()

        let waitClient = DispatchSemaphore(value: 0)
        let webSocketConnectionTask = Task.detached {
            print("openAndConsumeWebSocketConnection in test 1")
            await openAndConsumeWebSocketConnection(waitClient)
            print("openAndConsumeWebSocketConnection in test 2")
            //waitClient.signal()
        }
        waitClient.wait()
        print("sending text to clients in test")
        usleep(useconds_t(2 * 1000000)) // seconds
        for cc in server.clients.values {
            try await cc.SendTextToClient("Hello client")
        }
        print("sent text to clients in test")

        _ = await webSocketConnectionTask.result
        print("Waiting for webSocketConnectionTask")
        webSocketConnectionTask.cancel()
        print("webSocketConnectionTask cancelled")
        try server.terminateServer()
    }

 
}



