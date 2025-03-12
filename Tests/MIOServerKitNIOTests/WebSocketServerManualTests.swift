

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation

final class WebSocketServerManualTests: XCTestCase {

    func test_Launch_HaltAndCatchFire() async throws {
        let server = NIOWebSocketServer(port:8888 )
        print("Websocket server started")
        try server.runAndWait()
        print("This line is never reached")  
    }
}
