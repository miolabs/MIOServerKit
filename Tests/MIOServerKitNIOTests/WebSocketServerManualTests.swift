

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
        try server.runAndWait(port:8888)
        print("This line is never reached")
    }
}



