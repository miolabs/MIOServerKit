import XCTest
@testable import MIOServerKit

@Sendable
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

        // TODO
        _ = routes.endpoint( "/").get( httpFuncHandler )
        _ = routes.endpoint( "/hook").get( httpFuncHandler )
        _ = routes.endpoint( "/healthz/").get( httpFuncHandler )
        _ = routes.endpoint( "/hook/version").get( httpFuncHandler )

//        routes.root.debug_info( )
    }
    
    func testRootAndSubrouterTree() throws {
        let routes = Router()

        _ = routes.endpoint( "/").get( httpFuncHandler )
        _ = routes.endpoint( "/hook").get( httpFuncHandler )

        let ringr_routes = routes.router( "/ringr" )
        _ = ringr_routes.endpoint( "/ready").get( httpFuncHandler )
        _ = ringr_routes.endpoint( "/bookings/update").get( httpFuncHandler )

//        routes.root.debug_info( )
    }

}
