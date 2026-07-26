//
//  EndpointGeneratorTests.swift
//  MIOServerKit
//
//  Tests for the @Endpoint scanner and the route file generator used by the
//  generate-endpoints pre-build tool.
//

import XCTest
@testable import EndpointGeneratorCore

final class EndpointScannerTests: XCTestCase
{
    func scan( _ source: String ) -> ScanResult {
        return EndpointScanner().scan( source: source, filePath: "Test.swift" )
    }

    func test_scan_freeFunction_pathOnly() {
        let result = scan( """
        @Endpoint( path: "/api/schema/:schema" )
        func getSchema( context: APIContext ) throws -> Any? { return nil }
        """ )

        XCTAssertTrue( result.diagnostics.isEmpty, "\(result.diagnostics)" )
        XCTAssertEqual( result.endpoints.count, 1 )
        XCTAssertEqual( result.endpoints[0].path, "/api/schema/:schema" )
        XCTAssertEqual( result.endpoints[0].methods, ["get"] )
        XCTAssertEqual( result.endpoints[0].handler, "getSchema" )
        XCTAssertEqual( result.endpoints[0].context, "APIContext" )
        XCTAssertFalse( result.endpoints[0].isAsync )
        XCTAssertEqual( result.endpoints[0].conditions, [] )
    }

    func test_scan_ifConfig_capturesCondition() {
        let result = scan( """
        #if DEBUG
        @Endpoint( path: "/api/debug" )
        func debugInfo( context: APIContext ) throws -> Any? { return nil }
        #endif
        """ )

        XCTAssertTrue( result.diagnostics.isEmpty, "\(result.diagnostics)" )
        XCTAssertEqual( result.endpoints.first?.conditions, ["DEBUG"] )
    }

    func test_scan_ifConfig_elseBranchesNegatePreviousConditions() {
        let result = scan( """
        #if os(Linux)
        @Endpoint( path: "/api/info" )
        func linuxInfo( context: APIContext ) throws -> Any? { return nil }
        #elseif os(macOS)
        @Endpoint( path: "/api/info" )
        func macInfo( context: APIContext ) throws -> Any? { return nil }
        #else
        @Endpoint( path: "/api/info" )
        func otherInfo( context: APIContext ) throws -> Any? { return nil }
        #endif
        """ )

        XCTAssertEqual( result.endpoints.count, 3 )
        XCTAssertEqual( result.endpoints[0].conditions, ["os(Linux)"] )
        XCTAssertEqual( result.endpoints[1].conditions, ["!(os(Linux)) && (os(macOS))"] )
        XCTAssertEqual( result.endpoints[2].conditions, ["!(os(Linux)) && !(os(macOS))"] )
    }

    func test_scan_ifConfig_nestedBlocksStackConditions() {
        let result = scan( """
        #if DEBUG
        #if os(Linux)
        @Endpoint( path: "/api/debug" )
        func debugInfo( context: APIContext ) throws -> Any? { return nil }
        #endif
        #endif
        """ )

        XCTAssertEqual( result.endpoints.first?.conditions, ["DEBUG", "os(Linux)"] )
    }

    func test_scan_ifConfig_aroundEnclosingType() {
        let result = scan( """
        #if DEBUG
        class DebugAPI {
            @Endpoint( path: "/api/debug" )
            static func info( context: APIContext ) throws -> Any? { return nil }
        }
        #endif
        """ )

        XCTAssertEqual( result.endpoints.first?.handler, "DebugAPI.info" )
        XCTAssertEqual( result.endpoints.first?.conditions, ["DEBUG"] )
    }

    func test_scan_methodsAndPath() {
        let result = scan( """
        @Endpoint( [.get, .post], path: "/api/schema/:schema" )
        func schema( context: APIContext ) async throws -> Any? { return nil }
        """ )

        XCTAssertEqual( result.endpoints.count, 1 )
        XCTAssertEqual( result.endpoints[0].methods, ["get", "post"] )
        XCTAssertTrue( result.endpoints[0].isAsync )
    }

    func test_scan_uppercaseMethodsAreNormalized() {
        let result = scan( """
        @Endpoint( [.GET, .DELETE], path: "/api/items/:id" )
        func item( context: APIContext ) throws -> Any? { return nil }
        """ )

        XCTAssertEqual( result.endpoints.first?.methods, ["get", "delete"] )
    }

    func test_scan_staticMethodInType_isQualified() {
        let result = scan( """
        class SchemaAPI {
            @Endpoint( path: "/api/schema" )
            static func list( context: APIContext ) throws -> Any? { return nil }
        }
        """ )

        XCTAssertTrue( result.diagnostics.isEmpty, "\(result.diagnostics)" )
        XCTAssertEqual( result.endpoints.first?.handler, "SchemaAPI.list" )
    }

    func test_scan_instanceMethod_isAnError() {
        let result = scan( """
        class SchemaAPI {
            @Endpoint( path: "/api/schema" )
            func list( context: APIContext ) throws -> Any? { return nil }
        }
        """ )

        XCTAssertTrue( result.endpoints.isEmpty )
        XCTAssertTrue( result.hasErrors )
        XCTAssertTrue( result.diagnostics[0].message.contains( "must be static" ) )
    }

    func test_scan_missingPath_isAnError() {
        let result = scan( """
        @Endpoint( [.get] )
        func broken( context: APIContext ) throws -> Any? { return nil }
        """ )

        XCTAssertTrue( result.endpoints.isEmpty )
        XCTAssertTrue( result.hasErrors )
    }

    func test_scan_unsupportedMethod_isAnError() {
        let result = scan( """
        @Endpoint( [.options], path: "/api/schema" )
        func broken( context: APIContext ) throws -> Any? { return nil }
        """ )

        XCTAssertTrue( result.endpoints.isEmpty )
        XCTAssertTrue( result.hasErrors )
        XCTAssertTrue( result.diagnostics[0].message.contains( "does not support" ) )
    }

    func test_scan_wrongParameterCount_isAnError() {
        let result = scan( """
        @Endpoint( path: "/api/schema" )
        func broken( context: APIContext, other: Int ) throws -> Any? { return nil }
        """ )

        XCTAssertTrue( result.endpoints.isEmpty )
        XCTAssertTrue( result.hasErrors )
        XCTAssertTrue( result.diagnostics[0].message.contains( "exactly one parameter" ) )
    }

    func test_scan_ignoresUnannotatedFunctions() {
        let result = scan( """
        func plain( context: APIContext ) throws -> Any? { return nil }
        @discardableResult func other() -> Int { return 0 }
        """ )

        XCTAssertTrue( result.endpoints.isEmpty )
        XCTAssertTrue( result.diagnostics.isEmpty )
    }
}

final class EndpointFileGeneratorTests: XCTestCase
{
    func endpoint( _ methods: [String], _ path: String, _ handler: String, conditions: [String] = [] ) -> ScannedEndpoint {
        return ScannedEndpoint( methods: methods, path: path, handler: handler, context: "APIContext", isAsync: false, conditions: conditions, file: "Test.swift", line: 1 )
    }

    func test_generateSwift_groupsMethodsOfSamePath() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/schema/:schema", "getSchema" ),
            endpoint( ["post"], "/api/schema/:schema", "saveSchema" ),
            endpoint( ["get"], "/api/version", "version" ),
        ] )

        let swift = try generator.generateSwift()

        // One endpoint() call per path: Router.endpoint(path) resets the node,
        // so a second call for the same path would drop the first method.
        XCTAssertEqual( swift.components( separatedBy: "endpoint( \"/api/schema/:schema\" )" ).count - 1, 1 )
        XCTAssertTrue( swift.contains( ".get( getSchema )" ) )
        XCTAssertTrue( swift.contains( ".post( saveSchema )" ) )
        XCTAssertTrue( swift.contains( ".get( version )" ) )
        XCTAssertTrue( swift.contains( "import MIOServerKit" ) )
        XCTAssertTrue( swift.contains( "func registerGeneratedEndpoints() -> Router" ) )
    }

    func test_generateSwift_duplicateRoute_throws() {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/schema", "a" ),
            endpoint( ["get"], "/api/schema", "b" ),
        ] )

        XCTAssertThrowsError( try generator.generateSwift() ) { error in
            XCTAssertTrue( "\(error)".contains( "Duplicate route GET /api/schema" ) )
        }
    }

    func test_generateSwift_samePathDifferentMethods_isAllowed() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/schema", "a" ),
            endpoint( ["post", "put"], "/api/schema", "b" ),
        ] )

        XCTAssertNoThrow( try generator.generateSwift() )
    }

    func test_generateSwift_conditionalPath_wrapsWholeBlock() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/debug", "debugInfo", conditions: ["DEBUG"] ),
        ] )

        let swift = try generator.generateSwift()

        // The endpoint() call itself must be guarded: a bare call would insert
        // a route node even when the handler is compiled out.
        XCTAssertTrue( swift.contains( "        #if DEBUG\n        endpoint( \"/api/debug\" )\n            .get( debugInfo )\n        #endif" ), swift )
    }

    func test_generateSwift_nestedConditions_areConjoined() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/debug", "debugInfo", conditions: ["DEBUG", "os(Linux)"] ),
        ] )

        let swift = try generator.generateSwift()
        XCTAssertTrue( swift.contains( "#if (DEBUG) && (os(Linux))" ), swift )
    }

    func test_generateSwift_mixedConditions_bindNodeToVariable() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/thing", "list" ),
            endpoint( ["post"], "/api/thing", "reset", conditions: ["DEBUG"] ),
        ] )

        let swift = try generator.generateSwift()

        // Unconditional handler keeps the node alive; only the guarded one
        // sits inside #if.
        XCTAssertTrue( swift.contains( "let ep1 = endpoint( \"/api/thing\" )" ), swift )
        XCTAssertTrue( swift.contains( "        ep1.get( list )" ), swift )
        XCTAssertTrue( swift.contains( "        #if DEBUG\n        ep1.post( reset )\n        #endif" ), swift )
    }

    func test_generateSwift_exclusiveBranches_guardNodeWithDisjunction() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/info", "linuxInfo", conditions: ["os(Linux)"] ),
            endpoint( ["get"], "/api/info", "otherInfo", conditions: ["!(os(Linux))"] ),
        ] )

        let swift = try generator.generateSwift()

        XCTAssertTrue( swift.contains( "        #if (os(Linux)) || (!(os(Linux)))\n        let ep1 = endpoint( \"/api/info\" )" ), swift )
        XCTAssertTrue( swift.contains( "        #if os(Linux)\n        ep1.get( linuxInfo )\n        #endif" ), swift )
        XCTAssertTrue( swift.contains( "        #if !(os(Linux))\n        ep1.get( otherInfo )\n        #endif" ), swift )
    }

    func test_validate_duplicateInExclusiveBranches_isAllowed() {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/info", "a", conditions: ["os(Linux)"] ),
            endpoint( ["get"], "/api/info", "b", conditions: ["!(os(Linux))"] ),
        ] )

        XCTAssertNoThrow( try generator.validate() )
    }

    func test_validate_duplicateWithSameConditions_throws() {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/info", "a", conditions: ["DEBUG"] ),
            endpoint( ["get"], "/api/info", "b", conditions: ["DEBUG"] ),
        ] )

        XCTAssertThrowsError( try generator.validate() )
    }

    func test_validate_conditionalDuplicateOfUnconditional_throws() {
        // A DEBUG build compiles both handlers, so this is still a conflict.
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/info", "a" ),
            endpoint( ["get"], "/api/info", "b", conditions: ["DEBUG"] ),
        ] )

        XCTAssertThrowsError( try generator.validate() )
    }

    func test_generateSwift_extraImports() throws {
        let generator = EndpointFileGenerator( endpoints: [] )
        let swift = try generator.generateSwift( extraImports: ["MyServerLib"] )
        XCTAssertTrue( swift.contains( "import MyServerLib" ) )
    }

    func test_generateJSON_containsRouteMetadata() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get", "post"], "/api/schema/:schema", "SchemaAPI.handle" ),
        ] )

        let json = try generator.generateJSON()
        let object = try JSONSerialization.jsonObject( with: Data( json.utf8 ) ) as? [String: [[String: Any]]]
        let first = object?[ "endpoints" ]?.first

        XCTAssertEqual( first?[ "path" ] as? String, "/api/schema/:schema" )
        XCTAssertEqual( first?[ "methods" ] as? [String], ["get", "post"] )
        XCTAssertEqual( first?[ "handler" ] as? String, "SchemaAPI.handle" )
    }

    func test_generateJSON_containsConditions() throws {
        let generator = EndpointFileGenerator( endpoints: [
            endpoint( ["get"], "/api/debug", "debugInfo", conditions: ["DEBUG"] ),
        ] )

        let json = try generator.generateJSON()
        let object = try JSONSerialization.jsonObject( with: Data( json.utf8 ) ) as? [String: [[String: Any]]]

        XCTAssertEqual( object?[ "endpoints" ]?.first?[ "conditions" ] as? [String], ["DEBUG"] )
    }

    func test_endToEnd_ifConfigEndpointStaysGuarded() throws {
        let result = EndpointScanner().scan( source: """
        @Endpoint( path: "/api/version" )
        func versionHandler( context: APIContext ) throws -> Any? { return nil }

        #if DEBUG
        @Endpoint( [.post], path: "/api/debug/reset" )
        func resetHandler( context: APIContext ) throws -> Any? { return nil }
        #endif
        """, filePath: "Server.swift" )

        XCTAssertFalse( result.hasErrors )

        let swift = try EndpointFileGenerator( endpoints: result.endpoints ).generateSwift()
        XCTAssertTrue( swift.contains( "        #if DEBUG\n        endpoint( \"/api/debug/reset\" )\n            .post( resetHandler )\n        #endif" ), swift )
        XCTAssertTrue( swift.contains( ".get( versionHandler )" ), swift )
    }

    func test_endToEnd_scanAndGenerate() throws {
        let result = EndpointScanner().scan( source: """
        @Endpoint( [.get, .post], path: "/api/schema/:schema" )
        func schemaHandler( context: APIContext ) throws -> Any? { return nil }

        @Endpoint( path: "/api/version" )
        func versionHandler( context: APIContext ) async throws -> Any? { return nil }
        """, filePath: "Server.swift" )

        XCTAssertFalse( result.hasErrors )

        let swift = try EndpointFileGenerator( endpoints: result.endpoints ).generateSwift()
        XCTAssertTrue( swift.contains( "endpoint( \"/api/schema/:schema\" )" ) )
        XCTAssertTrue( swift.contains( ".get( schemaHandler )" ) )
        XCTAssertTrue( swift.contains( ".post( schemaHandler )" ) )
        XCTAssertTrue( swift.contains( ".get( versionHandler )" ) )
    }
}
