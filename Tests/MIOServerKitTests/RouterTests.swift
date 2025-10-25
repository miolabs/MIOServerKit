import XCTest
@testable import MIOServerKit

fileprivate func httpFuncHandler ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        "status": "success"
    ]
    return response
}

final class RouterTests: XCTestCase {
// MARK: - Root 
    func testRouterRootWithSlash ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )
        let route_3 = routes.endpoint( "/healthz/").get( nop )
        let route_4 = routes.endpoint( "/hook/version").get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }

     func testRouterRootMultiMethod ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )
        //let route_3 = routes.endpoint( "/hook").post( httpFuncHandler )
         route_2.post( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertEqual(route_2.methods.count, 2)
        XCTAssertTrue(routes.root.match( RouterPath( "/"              ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }

    func testRouterRootWithSlashUnsorted_1 ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( nop )
        let route_3 = routes.endpoint( "/healthz/").get( nop )
        let route_4 = routes.endpoint( "/hook/version").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }    

     func testRouterRootWithSlashUnsorted_2 ( ) {
        let routes = Router()
        
        let route_3 = routes.endpoint( "/healthz/").get( nop )
        let route_4 = routes.endpoint( "/hook/version").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )
        let route_1 = routes.endpoint( "/").get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }    

    func testRouterRootWithOutSlash ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/hook").get( nop )
        let route_2 = routes.endpoint( "/healthz/").get( nop )
        let route_3 = routes.endpoint( "/hook/version").get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz/"      ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/healthz"       ), &route_vars ) === nil )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/healthz/"      ), &route_vars ) === nil )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/hook/version"  ), &route_vars ) === nil )
     }

    func testRouterRootWithOutSlashUnsorted ( ) {
        let routes = Router()
        
        let route_1 = routes.endpoint( "/hook/version/debug").get( nop )
        let route_3 = routes.endpoint( "/healthz/debug").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )
        let route_4 = routes.endpoint( "/hook/version").get( nop )
        let route_5 = routes.endpoint( "/healthz").get( nop )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"                ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"               ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz/"            ), &route_vars ) === route_5 )
        XCTAssertTrue(routes.root.match( RouterPath( "/healthz/debug"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version"        ), &route_vars ) === route_4 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/version/debug"  ), &route_vars ) === route_1 )
     }
    
// MARK: - root & subrouter    
    func testRouterOneSubrouter ( ) {
        let routes = Router()
        
        let ringr_routes = routes.router( "/ringr" )
        let route_r = ringr_routes.endpoint( "/ready").get( nop )
        let route_1 = ringr_routes.endpoint( "/bookings/business").get( nop )
        let route_2 = ringr_routes.endpoint( "/bookings/update").get( nop )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/ready"            ), &route_vars ) === route_r )
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/bookings/business"), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/bookings/update"  ), &route_vars ) === route_2 )

        XCTAssertTrue(routes.root.match( RouterPath( "/ready"            ), &route_vars ) !== route_r )
        XCTAssertTrue(routes.root.match( RouterPath( "/bookings/business"), &route_vars ) !== route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/bookings/update"  ), &route_vars ) !== route_2 )
    }

     func testRouterRootAndSubrouter ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )

        let ringr_routes = routes.router( "/ringr" )
        let route_r1 = ringr_routes.endpoint( "/ready").get( nop )
        let route_r2 = ringr_routes.endpoint( "/bookings/update").get( nop )
         
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/"              ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )

        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/ready"            ), &route_vars ) === route_r1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/bookings/update"  ), &route_vars ) === route_r2 )
     }

// MARK: - root 2 subrouter 
     func testRouterRootAndTwoSubrouters ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( nop )
        let route_2 = routes.endpoint( "/hook").get( nop )

        let ringr_routes = routes.router( "/ringr" )
        let route_r1 = ringr_routes.endpoint( "/ready").get( nop )
        let route_r2 = ringr_routes.endpoint( "/bookings/update").get( nop )

        let more_routes = routes.router( "/more" )
        let route_m1 = more_routes.endpoint( "/ready").get( nop )
        let route_m2 = more_routes.endpoint( "/another/info").get( nop )
       
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( RouterPath( "/"              ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_2 )

        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/ready"            ), &route_vars ) === route_r1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/bookings/update"  ), &route_vars ) === route_r2 )

        XCTAssertTrue(routes.root.match( RouterPath( "/more/ready"       ), &route_vars ) === route_m1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/more/another/info"), &route_vars ) === route_m2 )
     }

// MARK: - 2 subrouters
    func testRouterTwoSubRouter ( ) {
       let routes = Router()
        
        let ringr_routes = routes.router( "/ringr" )
        let route_r = ringr_routes.endpoint( "/ready").get( nop )
        let route_1 = ringr_routes.endpoint( "/bookings/business").get( nop )

        let more_routes = routes.router( "/more" )
        let route_m = more_routes.endpoint( "/ready").get( nop )
        let route_2 = more_routes.endpoint( "/another/info").get( nop )
        
        var route_vars: RouterPathVars = [:]
        // let e0 = routes.endpoint( "/ready").get( httpFuncHandler )
        // let e1 = routes.root.match( .GET, RouterPath( "/ringr/ready"), &route_vars)
        // let e2 = routes.root.match( .GET, RouterPath( "/more/ready"), &route_vars)
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/ready"            ), &route_vars ) === route_r )
        XCTAssertTrue(routes.root.match( RouterPath( "/ringr/bookings/business"), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( RouterPath( "/ready"            ), &route_vars ) !== route_r )
        XCTAssertTrue(routes.root.match( RouterPath( "/bookings/business"), &route_vars ) !== route_1 )
        
        XCTAssertTrue(routes.root.match( RouterPath( "/more/ready"       ), &route_vars ) === route_m )
        XCTAssertTrue(routes.root.match( RouterPath( "/more/another/info"), &route_vars ) === route_2 )
    }

}
