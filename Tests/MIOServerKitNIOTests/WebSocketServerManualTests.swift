/*

Test to just load the server and interact with it manually (see WebSocketClient.html)
This is not a test that can be run automatically because it never returns

*/

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation

final class WebSocketServerManualTests: XCTestCase {

    func test_Launch_HaltAndCatchFire() async throws {
        let routes = Router()
        routes.endpoint( "/hook").get( httpFuncHandler ).post( httpFuncHandler )

        let wsEndPoint = WebSocketEndpoint("/socket").OnText { message, operations in
            print("Hello endpoint: \(message)")
            Task {
                try await operations.SendTextToCaller("Hello from server. You sent me \(message)")
            }
            return
        }

        let server = NIOWebSocketServer(routes: routes, webSocketEndpoints: [wsEndPoint] )
        print("Websocket server started")
        server.run(port:8888)
        print("This line is never reached")
    }
}



