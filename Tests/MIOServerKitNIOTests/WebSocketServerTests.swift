

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation


func launchServer() async throws -> (NIOWebSocketServer) {
    let server = NIOWebSocketServer(port:8888 )
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

 
}
