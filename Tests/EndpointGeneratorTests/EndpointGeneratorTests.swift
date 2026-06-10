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
    func endpoint( _ methods: [String], _ path: String, _ handler: String ) -> ScannedEndpoint {
        return ScannedEndpoint( methods: methods, path: path, handler: handler, context: "APIContext", isAsync: false, file: "Test.swift", line: 1 )
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
