//
//  MIOServerKitMacrosTests.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//

import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(MIOServerKitMacrosPlugin)
import MIOServerKitMacrosPlugin

let testMacros: [String: Macro.Type] = [
    "Endpoint": EndpointMacro.self
]
#endif


final class MIOServerKitMacrosTests: XCTestCase
{
    // @Endpoint is a marker for the generate-endpoints pre-build tool:
    // it validates the annotation and expands to nothing.

    func testEndpointMacro_pathOnly_expandsToNothing() throws {
        assertMacroExpansion(
            """
            @Endpoint( path: "/api/schema/:schema" )
            func schemaHandler( context: APIContext ) throws -> Any? {
                return nil
            }
            """,
            expandedSource: """
            func schemaHandler( context: APIContext ) throws -> Any? {
                return nil
            }
            """,
            macros: testMacros
        )
    }

    func testEndpointMacro_methodsAndPath_expandsToNothing() throws {
        assertMacroExpansion(
            """
            @Endpoint( [.get, .post], path: "/api/schema/:schema" )
            func schemaHandler( context: APIContext ) async throws -> Any? {
                return nil
            }
            """,
            expandedSource: """
            func schemaHandler( context: APIContext ) async throws -> Any? {
                return nil
            }
            """,
            macros: testMacros
        )
    }

    func testEndpointMacro_missingPath_emitsError() throws {
        assertMacroExpansion(
            """
            @Endpoint( [.get] )
            func schemaHandler( context: APIContext ) throws -> Any? {
                return nil
            }
            """,
            expandedSource: """
            func schemaHandler( context: APIContext ) throws -> Any? {
                return nil
            }
            """,
            diagnostics: [
                DiagnosticSpec( message: "@Endpoint requires a 'path:' string literal", line: 1, column: 1 )
            ],
            macros: testMacros
        )
    }

    func testEndpointMacro_unsupportedMethod_emitsError() throws {
        assertMacroExpansion(
            """
            @Endpoint( [.options], path: "/api/schema" )
            func schemaHandler( context: APIContext ) throws -> Any? {
                return nil
            }
            """,
            expandedSource: """
            func schemaHandler( context: APIContext ) throws -> Any? {
                return nil
            }
            """,
            diagnostics: [
                DiagnosticSpec( message: "@Endpoint does not support method '.options'. Supported: .get, .post, .put, .patch, .delete", line: 1, column: 1 )
            ],
            macros: testMacros
        )
    }

    func testEndpointMacro_wrongParameterCount_emitsError() throws {
        assertMacroExpansion(
            """
            @Endpoint( path: "/api/schema" )
            func schemaHandler( context: APIContext, extra: Int ) throws -> Any? {
                return nil
            }
            """,
            expandedSource: """
            func schemaHandler( context: APIContext, extra: Int ) throws -> Any? {
                return nil
            }
            """,
            diagnostics: [
                DiagnosticSpec( message: "@Endpoint handler must take exactly one parameter (the router context)", line: 1, column: 1 )
            ],
            macros: testMacros
        )
    }

    func testEndpointMacro_onClass_emitsError() throws {
        assertMacroExpansion(
            """
            @Endpoint( path: "/api" )
            class APIContext {
            }
            """,
            expandedSource: """
            class APIContext {
            }
            """,
            diagnostics: [
                DiagnosticSpec( message: "@Endpoint can only be applied to functions", line: 1, column: 1 )
            ],
            macros: testMacros
        )
    }
}
