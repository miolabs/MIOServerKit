

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation


class ServerTest01: ConnectedWebSocket {
    override func OnTextMessageFromClient(_ message: String) {
        print("ServerTest01:Received message: \(message)")
        Task.detached {
            try await self.SendTextToClient("You sent me: \(message)")
        }
    }
}

final class WebSocketServerManualTests: XCTestCase {

    func test_Launch_HaltAndCatchFire() async throws {
        let server = NIOWebSocketServer<ServerTest01>(port:8888 )
        print("Websocket server started")
        try server.runAndWait()
        print("This line is never reached")  
    }
}
