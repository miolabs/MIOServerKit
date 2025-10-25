import XCTest
@testable import MIOServerKit

fileprivate func httpFuncHandler ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        //"status": "success"
        "url": context.request.url.absoluteString
    ]
    return response
}

final class NodeTreeStructTests: XCTestCase {
 
    func testOnlyRootTree() throws {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
        let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )

//        routes.root.debug_info( )
    }
    
    func testRootAndSubrouterTree() throws {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )

        let ringr_routes = routes.router( "/ringr" )
        let route_r1 = ringr_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_r2 = ringr_routes.endpoint( "/bookings/update").get( httpFuncHandler )

//        routes.root.debug_info( )
    }

}
