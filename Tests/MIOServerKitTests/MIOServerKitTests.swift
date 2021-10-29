import XCTest
@testable import MIOServerKit

func nop ( _ ctx: Any ) { }


final class MIOServerKitTests: XCTestCase {
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

        XCTAssertTrue( part_1.is_optional == false )
        XCTAssertTrue( part_2.is_optional == true  )
        XCTAssertTrue( part_3.is_optional == true  )
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

    
    func testEndpointTree() {
        let tree = EndpointTree<Any>( )
        let route_1 = Endpoint( "/entity/Product" ).get( nop )
        let route_2 = Endpoint( "/entity/ProductPlace" ).get( nop )

        tree.insert( route_1 )
        tree.insert( route_2 )
        
        var route_vars: RouterPathVars = [:]
        
        XCTAssertTrue( tree.match( .GET, RouterPath( "/entity/ProductPlace"), &route_vars ) === route_2 )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/entity/Not exists"  ), &route_vars ) == nil )
        XCTAssertTrue( tree.match( .GET, RouterPath( "root"                ), &route_vars ) == nil )
    }

    func testEndpointTreeVarsGoLast() {
        let tree = EndpointTree<Any>( )
        let route_1 = Endpoint( "/entity/:name" ).get( nop )
        let route_2 = Endpoint( "/entity/ProductPlace" ).get( nop )
        var route_vars: RouterPathVars = [:]

        tree.insert( route_1 )
        tree.insert( route_2 )
        
        XCTAssertTrue( tree.match( .GET, RouterPath( "/entity/ProductPlace" ), &route_vars )! === route_2 )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/entity/Not_exists"   ), &route_vars )! === route_1 )
    }

    
    func testEndpointWithExtraVars() {
        let tree = EndpointTree<Any>( )
        let route_1 = Endpoint( "/entity/:name" ).patch( nop, ":entity-id" )
        var route_vars: RouterPathVars = [:]

        tree.insert( route_1 )
        
        XCTAssertTrue( tree.match( .PATCH, RouterPath( "/entity/ProductPlace"     ), &route_vars ) == nil )
        XCTAssertTrue( tree.match( .PATCH, RouterPath( "/entity/ProductPlace/123" ), &route_vars ) === route_1 )
        XCTAssertTrue( route_vars[ "name" ] == "ProductPlace" )
        XCTAssertTrue( route_vars[ "entity-id" ] == "123" )
    }

    func testEndpointWithExtraVarsRegExp() {
        let tree = EndpointTree<Any>( )
        let asUUID = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

        let route_1 = Endpoint( "/entity/:name" ).patch( nop, ":entity-id\(asUUID)" )
        var route_vars: RouterPathVars = [:]

        tree.insert( route_1 )
        
        XCTAssertTrue( tree.match( .PATCH, RouterPath( "/entity/ProductPlace"     ), &route_vars ) == nil )
        XCTAssertTrue( tree.match( .PATCH, RouterPath( "/entity/ProductPlace/123" ), &route_vars ) == nil )
        XCTAssertTrue( route_vars.isEmpty == true )

        XCTAssertTrue( tree.match( .PATCH, RouterPath( "/entity/ProductPlace/48D3C8B3-72AA-4441-BA47-769E03A11576" ), &route_vars ) != nil )
        XCTAssertTrue( route_vars[ "name" ] == "ProductPlace" )
        XCTAssertTrue( route_vars[ "entity-id" ] == "48D3C8B3-72AA-4441-BA47-769E03A11576" )
    }

    func testEndpointWithExtraVarsRegExpPrio() {
        let tree = EndpointTree<Any>( )
        let asUUID = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

        let route_1 = Endpoint( "/entity/:name\(asUUID)" ).patch( nop )
        let route_2 = Endpoint( "/entity/:generic-name"  ).patch( nop )
        var route_vars: RouterPathVars = [:]

        tree.insert( route_1 )
        tree.insert( route_2 )
        
        XCTAssertTrue( tree.match( .PATCH, RouterPath( "/entity/48D3C8B3-72AA-4441-BA47-769E03A11576" ), &route_vars ) != nil )
        XCTAssertTrue( route_vars[ "name" ] == "48D3C8B3-72AA-4441-BA47-769E03A11576" )
    }

    
    func testEndpointRealCase1() {

        let route_home = Endpoint( "/" ).get( nop )
        let route_hook = Endpoint( "/hook/"  ).get( nop )
        let route_hook_version = Endpoint( "/hook/version" ).get( nop )
        
        let route_sync_ann = Endpoint( "/schema/:scheme\(uuidRegexRoute)/sync-annotations/:sync_id?"  ).get( nop )
        let route_sync_all_ann = Endpoint( "/schema/:scheme\(uuidRegexRoute)/all-sync-annotations"  ).get( nop )


        let tree = EndpointTree<Any>( )
        tree.insert( route_home )
        tree.insert( route_hook )
        tree.insert( route_hook_version )
        
        let node = tree.find( RouterPath( "hook" ) )!
        node.insert( route_sync_ann )
        node.insert( route_sync_all_ann )


        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( tree.match( .GET, RouterPath( "/"              ), &route_vars ) === route_home )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_hook )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/"         ), &route_vars ) === route_hook )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_hook_version )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/version/" ), &route_vars ) === route_hook_version )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/sync-annotations" ), &route_vars ) === route_sync_ann )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/sync-annotations/123" ), &route_vars ) === route_sync_ann )

        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/schema/48D3C8B3-72AA-4441-BA47-769E03A11576/all-sync-annotations" ), &route_vars ) === route_sync_all_ann )
    }

    func testEndpointRealCase2 ( ) {

        let route_home = Endpoint( "/" ).get( nop )
        let route_hook = Endpoint( "/hook/"  ).get( nop )
        let route_hook_version = Endpoint( "/hook/version" ).get( nop )

        let tree = EndpointTree<Any>( )
        tree.insert( route_home )
        tree.insert( route_hook_version )
        tree.insert( route_hook )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( tree.match( .GET, RouterPath( "/"              ), &route_vars ) === route_home )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_hook )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_hook_version )
    }

    func testEndpointRealCase21 ( ) {

        let route_home = Endpoint( "/" ).get( nop )
        let route_hook_version = Endpoint( "/hook/version" ).get( nop )

        let tree = EndpointTree<Any>( )
        tree.insert( route_home )
        tree.insert( route_hook_version )
        
        tree.insert( EndpointTreeLeaf( "/hook" ) )
        let node = tree.find( RouterPath( "/hook" ) )!
        let route_hook = Endpoint( "/" ).get( nop )
        node.insert( route_hook )
        
        var route_vars: RouterPathVars = [:]
        XCTAssertTrue( tree.match( .GET, RouterPath( "/"              ), &route_vars ) === route_home )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook"          ), &route_vars ) === route_hook )
        XCTAssertTrue( tree.match( .GET, RouterPath( "/hook/version"  ), &route_vars ) === route_hook_version )
    }}
