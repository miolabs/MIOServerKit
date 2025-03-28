import XCTest
@testable import MIOServerKit

func httpFuncHandler ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        "status": "success"
    ]
    return response
}
final class RouterTests: XCTestCase {
// MARK: - Root 
    func testRouterRootWithSlash ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
        let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }

     func testRouterRootMultiMethod ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
        //let route_3 = routes.endpoint( "/hook").post( httpFuncHandler )
         route_2.post( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )

        var route_vars: RouterPathVars = [:]
        XCTAssertEqual(route_2.methods.count, 2)
        XCTAssertTrue(routes.root.match( .GET,  RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( .GET,  RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET,  RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET,  RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .POST, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .POST, RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET,  RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }

    func testRouterRootWithSlashUnsorted_1 ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }    

     func testRouterRootWithSlashUnsorted_2 ( ) {
        let routes = Router()
        
        let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
        let route_1 = routes.endpoint( "/").get( httpFuncHandler )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/"              ), &route_vars ) === route_1)
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_4 )
     }    

    func testRouterRootWithOutSlash ( ) {
        let routes = Router()

        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
        let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz/"      ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_4 )  
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/healthz"       ), &route_vars ) !== route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/healthz/"      ), &route_vars ) !== route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/hook/version"  ), &route_vars ) !== route_4 )  
     }

    func testRouterRootWithOutSlashUnsorted ( ) {
        let routes = Router()
        
        let route_1 = routes.endpoint( "/hook/version/debug").get( httpFuncHandler )
        let route_3 = routes.endpoint( "/healthz/debug").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
        let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )
        let route_5 = routes.endpoint( "/healthz").get( httpFuncHandler )

        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"                ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"               ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz/"            ), &route_vars ) === route_5 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/healthz/debug"       ), &route_vars ) === route_3 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/version"        ), &route_vars ) === route_4 )  
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/version/debug"  ), &route_vars ) === route_1 )  
     }
    
// MARK: - root & subrouter    
    func testRouterOneSubrouter ( ) {
        let routes = Router()
        
        let svc_routes = routes.router( "/svc" )
        let route_r = svc_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_1 = svc_routes.endpoint( "/bookings/business").get( httpFuncHandler )
        let route_2 = svc_routes.endpoint( "/bookings/update").get( httpFuncHandler )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/ready"            ), &route_vars ) === route_r )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/bookings/business"), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/bookings/update"  ), &route_vars ) === route_2 )

        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/ready"            ), &route_vars ) !== route_r )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/bookings/business"), &route_vars ) !== route_1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/bookings/update"  ), &route_vars ) !== route_2 )
    }

     func testRouterRootAndSubrouter ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )

        let svc_routes = routes.router( "/svc" )
        let route_r1 = svc_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_r2 = svc_routes.endpoint( "/bookings/update").get( httpFuncHandler )
         
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/"              ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_2 )

        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/ready"            ), &route_vars ) === route_r1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/bookings/update"  ), &route_vars ) === route_r2 )
     }

// MARK: - root 2 subrouter 
     func testRouterRootAndTwoSubrouters ( ) {
        let routes = Router()

        let route_1 = routes.endpoint( "/").get( httpFuncHandler )
        let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )

        let svc_routes = routes.router( "/svc" )
        let route_r1 = svc_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_r2 = svc_routes.endpoint( "/bookings/update").get( httpFuncHandler )

        let more_routes = routes.router( "/more" )
        let route_m1 = more_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_m2 = more_routes.endpoint( "/another/info").get( httpFuncHandler )
       
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/"              ), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_2 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_2 )

        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/ready"            ), &route_vars ) === route_r1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/bookings/update"  ), &route_vars ) === route_r2 )

        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/more/ready"       ), &route_vars ) === route_m1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/more/another/info"), &route_vars ) === route_m2 )
     }

// MARK: - 2 subrouters
    func testRouterTwoSubRouter ( ) {
       let routes = Router()
        
        let svc_routes = routes.router( "/svc" )
        let route_r = svc_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_1 = svc_routes.endpoint( "/bookings/business").get( httpFuncHandler )

        let more_routes = routes.router( "/more" )
        let route_m = more_routes.endpoint( "/ready").get( httpFuncHandler )
        let route_2 = more_routes.endpoint( "/another/info").get( httpFuncHandler )
        
        var route_vars: RouterPathVars = [:]
        // let e0 = routes.endpoint( "/ready").get( httpFuncHandler )
        // let e1 = routes.root.match( .GET, RouterPath( "/svc/ready"), &route_vars)
        // let e2 = routes.root.match( .GET, RouterPath( "/more/ready"), &route_vars)
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/ready"            ), &route_vars ) === route_r )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/svc/bookings/business"), &route_vars ) === route_1 )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/ready"            ), &route_vars ) !== route_r )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/bookings/business"), &route_vars ) !== route_1 )
        
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/more/ready"       ), &route_vars ) === route_m )
        XCTAssertTrue(routes.root.match( .GET, RouterPath( "/more/another/info"), &route_vars ) === route_2 )
    }

}
