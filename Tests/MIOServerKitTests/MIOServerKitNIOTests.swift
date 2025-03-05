//
//  MIOServerKitNIOTests.swift
//  
//
//  Created by Manolo on 4/3/25.
//

import MIOServerKit
import MIOServerKit_NIO
import XCTest


func httpFuncHandler ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        "status": "success"
    ]
    return response
}

final class MIOServerKitNIOTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func launchServerHttp() throws {
        let routes = Router()
        routes.endpoint( "/" ).get( ) { ctx in
            let version = "1" //DLDB.shared.serverVersion
        //    ctx.response.send("DL Bot server \(version)")
            return nil
        }
        routes.endpoint( "/version" ).get( ) { ctx in
            let version = "1" //DLDB.shared.serverVersion
            return nil
        }
        let ringr_routes = routes.router( "/ringr" )
        ringr_routes.endpoint( "/ready").get( httpFuncHandler )
        
        ringr_routes.endpoint( "/bookings/business-info").post( httpFuncHandler )
        ringr_routes.endpoint( "/bookings/availability").post( httpFuncHandler )
        ringr_routes.endpoint( "/bookings/fetch").post( httpFuncHandler )
        ringr_routes.endpoint( "/bookings/insert").post( httpFuncHandler )
        ringr_routes.endpoint( "/bookings/update").post( httpFuncHandler )
        ringr_routes.endpoint( "/bookings/delete").post( httpFuncHandler )

        let server = NIOServer( routes: routes )
        server.run( port: 8080 )
    }
    
      
    func testExample() throws {
        let serverThread = Thread {
            try? self.launchServerHttp()
        }
        serverThread.start()

    }


    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}


/*
 func detener() {
         do {
             try channel?.close().wait()
             try group?.syncShutdownGracefully()
             print("Servidor detenido.")
         } catch {
             print("Error al detener servidor: \(error)")
         }
     }
 }
 */
