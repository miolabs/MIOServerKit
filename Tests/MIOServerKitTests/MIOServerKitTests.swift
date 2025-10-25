import XCTest
@testable import MIOServerKit

func nop ( _ ctx: any Sendable ) { }

final class MIOServerKitTests: XCTestCase {
// MARK: - RouterPath     
    func testRouterPathNode ( ) {
        let part_1 = RouterPathNode( ":var_name" )
        let part_2 = RouterPathNode( "value" )
        
        XCTAssertTrue( part_1.match( RouterPathNode( "whatever" ) ) == true  )
        XCTAssertTrue( part_2.match( RouterPathNode( "whatever" ) ) == false )
        XCTAssertTrue( part_2.match( RouterPathNode( "value"    ) ) == true  )
    }
    
    func testRouterPathIsOptional ( ) {
        let part_1 = RouterPathNode( ":var_name" )
        let part_2 = RouterPathNode( ":value?" )
        let part_3 = RouterPathNode( ":value?\(uuidRegexRoute)" )
        
        XCTAssertTrue( part_1.isOptional == false )
        XCTAssertTrue( part_2.isOptional == true  )
        XCTAssertTrue( part_3.isOptional == true  )
    }
    
    
    func testRouterPath ( ) {
        let home = RouterPath( "/" )
        let hook = RouterPath( "/hook/" )
        let hook_version = RouterPath( "/hook/version" )
        
        XCTAssertTrue( home.debug_path() == "/" )
        XCTAssertTrue( hook.debug_path() == "hook" )
        XCTAssertTrue( hook_version.debug_path() == "hook/version" )
    }
    
    func testRouterPathMatch ( ) {
        let home = RouterPath( "/" )
        let hook = RouterPath( "/hook/" )
        let hook_version = RouterPath( "/hook/version" )
        var vars: RouterPathVars = [:]
        
        XCTAssertTrue( home.match( RouterPath( ""      ), &vars ) != nil )
        XCTAssertTrue( home.match( RouterPath( "/"     ), &vars ) != nil )
        XCTAssertTrue( home.match( RouterPath( ""      ), &vars )?.right.is_empty() ?? false )
        XCTAssertTrue( home.match( RouterPath( "/"     ), &vars )?.right.is_empty() ?? false )
        XCTAssertTrue( home.match( RouterPath( "/hook" ), &vars ) != nil )
        
        XCTAssertTrue( hook.match( RouterPath( "/"        ), &vars ) == nil )
        XCTAssertTrue( hook.match( RouterPath( "/hook"    ), &vars ) != nil )
        XCTAssertTrue( hook.match( RouterPath( "/hook/"   ), &vars ) != nil )
        XCTAssertTrue( hook.match( RouterPath( "/hook/me" ), &vars )?.right.debug_path() == "me" )
        
        XCTAssertTrue( hook_version.match( RouterPath( "/hook/version" ), &vars ) != nil )
        XCTAssertTrue( hook_version.match( RouterPath( "/hook/version2" ), &vars ) == nil )
    }
    
    func testRouterPathMatchVars ( ) {
        let hook = RouterPath( "/hook/:entity\(uuidRegexRoute)/me/:sync_id?" )
        var vars: RouterPathVars = [:]
        let left = hook.match( RouterPath( "/hook/2847C6A3-D338-4E5B-A1DB-3F3F5A34B2C6/me/1234" ), &vars )
        
        XCTAssertTrue( vars[ "entity"  ]! == "2847C6A3-D338-4E5B-A1DB-3F3F5A34B2C6" )
        XCTAssertTrue( vars[ "sync_id" ]! == "1234" )
        XCTAssertTrue( left?.right.is_empty() ?? false )
        
        var vars2: RouterPathVars = [:]
        let left2 = hook.match( RouterPath( "/hook/2847C6A3-D338-4E5B-A1DB-3F3F5A34B2C6/me" ), &vars2 )
        
        XCTAssertTrue( vars2[ "entity"  ]! == "2847C6A3-D338-4E5B-A1DB-3F3F5A34B2C6" )
        XCTAssertTrue( vars2[ "sync_id" ] == nil )
        XCTAssertTrue( left2?.right.is_empty() ?? false )
    }
    
    // MARK: - Endpoint
    
    func testEndpoint() {
        let router = Router()
        let route_1 = router.endpoint( "/entity/Product" ).get( nop )
        let route_2 = router.endpoint( "/entity/ProductPlace" ).get( nop )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace" ), &route_vars ) === route_2 )
        XCTAssertTrue( router.root.match( RouterPath( "/entity/Not exists"  ), &route_vars ) == nil )
        XCTAssertTrue( router.root.match( RouterPath( "root"                ), &route_vars ) == nil )
    }
    
    func testEndpointWithVar() {
        let router = Router()
        let route_1 = router.endpoint( "/entity/:name" ).get( nop )
        var route_vars: RouterPathVars = [:]
        
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace"     ), &route_vars ) === route_1 )
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace/123" ), &route_vars ) === nil )
        XCTAssertTrue( route_vars[ "name" ] == "ProductPlace" )
    }

    func testEndpointWithVars() {
        let router = Router()
        let route_1 = router.endpoint( "/entity/:name/:entity_id" ).get( nop )
        var route_vars: RouterPathVars = [:]
        
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace"     ), &route_vars ) === nil )
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace/123" ), &route_vars ) === route_1 )
        XCTAssertTrue( route_vars[ "name" ] == "ProductPlace" )
        XCTAssertTrue( route_vars[ "entity_id" ] == "123" )
    }
    
    func testEndpointWithExtraVarsRegExp() {
        let router = Router()
        let asUUID = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"
        
        let route_1 = router.endpoint( "/entity/:name/:entity_id\(asUUID)" ).get( nop )
        var route_vars: RouterPathVars = [:]
        
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace"     ), &route_vars ) == nil )
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace/123" ), &route_vars ) == nil )
        
        XCTAssertTrue( router.root.match( RouterPath( "/entity/ProductPlace/48D3C8B3-72AA-4441-BA47-769E03A11576" ), &route_vars ) === route_1 )
        XCTAssertTrue( route_vars[ "name" ] == "ProductPlace" )
        XCTAssertTrue( route_vars[ "entity_id" ] == "48D3C8B3-72AA-4441-BA47-769E03A11576" )
    }
    
    func testEndpointWithExtraVarsRegExpPrio() {
        let router = Router()
        let asUUID = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"
        
        let route_1 = router.endpoint( "/entity/:name\(asUUID)" ).get( nop )
        let route_2 = router.endpoint( "/entity/:generic-name"  ).get( nop )
        var route_vars: RouterPathVars = [:]
        
        XCTAssertTrue( router.root.match( RouterPath( "/entity/48D3C8B3-72AA-4441-BA47-769E03A11576" ), &route_vars ) != nil )
        XCTAssertTrue( route_vars[ "name" ] == "48D3C8B3-72AA-4441-BA47-769E03A11576" )
    }
    
    func testEndpointRealCase1() {
        let router = Router()
        let route_home = router.endpoint( "/" ).get( nop )
        let route_hook = router.endpoint( "/hook/"  ).get( nop )
        let route_hook_version = router.endpoint( "/hook/version" ).get( nop )
        
        let route_sync_ann = router.endpoint( "/hook/schema/:scheme\(uuidRegexRoute)/sync-annotations/:sync_id?"  ).get( nop )
        let route_sync_all_ann = router.endpoint( "/hook/schema/:scheme\(uuidRegexRoute)/all-sync-annotations"  ).get( nop )
        let route_sync_range_ann = router.endpoint( "/hook/schema/:scheme\(uuidRegexRoute)/range-sync-annotations/:from_id?/:to_id?"  ).get( nop )
                
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( router.root.match( RouterPath( "/"              ), &route_vars ) === route_home )
        XCTAssertTrue( router.root.match( RouterPath( "/hook"          ), &route_vars ) === route_hook )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/"         ), &route_vars ) === route_hook )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_hook_version )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/version/" ), &route_vars ) === route_hook_version )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/sync-annotations" ), &route_vars ) === route_sync_ann )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/sync-annotations/123" ), &route_vars ) === route_sync_ann )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/all-sync-annotations" ), &route_vars ) === route_sync_all_ann )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/range-sync-annotations" ), &route_vars ) === route_sync_range_ann )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/range-sync-annotations/1" ), &route_vars ) === route_sync_range_ann )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/range-sync-annotations/1/2" ), &route_vars ) === route_sync_range_ann )
        XCTAssertTrue( route_vars[ "scheme" ] == "48D3C8B3-72AA-4441-BA47-769E03A11576" )
        XCTAssertTrue( route_vars[ "from_id" ] == "1" )
        XCTAssertTrue( route_vars[ "to_id" ] == "2" )
    }
    
    func testEndpointRealCase2 ( ) {
        let router = Router()
        let route_home = router.endpoint( "/" ).get( nop )
        let route_hook = router.endpoint( "/hook/"  ).get( nop )
        let route_hook_version = router.endpoint( "/hook/version" ).get( nop )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( router.root.match( RouterPath( "/"              ), &route_vars ) === route_home )
        XCTAssertTrue( router.root.match( RouterPath( "/hook"          ), &route_vars ) === route_hook )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_hook_version )
    }
    
    func testEndpointRealCase21 ( )
    {
        let router = Router()
        let route_home = router.endpoint( "/" ).get( nop )
        let route_hook_version = router.endpoint( "/hook/version" ).get( nop )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( router.root.match( RouterPath( "/"              ), &route_vars ) === route_home )
        XCTAssertTrue( router.root.match( RouterPath( "/hook"          ), &route_vars ) === nil )
        XCTAssertTrue( router.root.match( RouterPath( "/hook/version"  ), &route_vars ) === route_hook_version )
    }
}
    

