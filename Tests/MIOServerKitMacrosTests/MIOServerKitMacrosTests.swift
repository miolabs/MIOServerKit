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
#if canImport(MIOCoreMacrosPlugin)
import MIOServerKitMacrosPlugin

let testMacros: [String: Macro.Type] = [
    "Endpoint": EndpointMacro.self
]
#endif


final class MIOServerKitMacrosTests: XCTestCase
{
    func testEnpointMacroOnlyPath() throws {
        assertMacroExpansion(
            """
            @Endpoint( "api" ) 
            func api_handler( context: APIContext ) {
            }
            """,
            expandedSource: """
            func api_handler( context: APIContext ) {
            }
            
            EndpointRegistry.shared.register( methods: [.GET], path: api, for: APIContext.Type, handler: api_handler )
            """,
            macros: testMacros
        )
    }
    /*
    func testEnpointRegisterableMacroOnlyPath() throws {
        assertMacroExpansion(
            """
            @Endpoint( "api" ) 
            class ApiContext : RouterContext {
            }
            """,
            expandedSource: """
            class ApiContext : RouterContext {
            }
            
            extension ApiContext: EndpointRegisterable {
                static var endpointPath: String {
                    return "api"
                }
                static var endpointMethods: [HTTPMethod] {
                    return [.GET]
                }
                static var endpointParentClass: EndpointRegisterable.Type? {
                    return RouterContext.self as? EndpointRegisterable.Type
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testEnpointRegisterableMacroGET() throws {
        assertMacroExpansion(
            """
            @Endpoint( methods: [.GET], "api" ) 
            class ApiContext : RouterContext {
            }
            """,
            expandedSource: """
            class ApiContext : RouterContext {
            }
            
            extension ApiContext: EndpointRegisterable {
                static var endpointPath: String {
                    return "api"
                }
                static var endpointMethods: [HTTPMethod] {
                    return [.GET]
                }
                static var endpointParentClass: EndpointRegisterable.Type? {
                    return RouterContext.self as? EndpointRegisterable.Type
                }
            }
            """,
            macros: testMacros
        )
    }
    
    func testEnpointRegisterableMacroGETAndPOST() throws {
        assertMacroExpansion(
            """
            @Endpoint( methods: [.GET,.POST], "api" ) 
            class ApiContext : RouterContext {
            }
            """,
            expandedSource: """
            class ApiContext : RouterContext {
            }
            
            extension ApiContext: EndpointRegisterable {
                static var endpointPath: String {
                    return "api"
                }
                static var endpointMethods: [HTTPMethod] {
                    return [.GET, .POST]
                }
                static var endpointParentClass: EndpointRegisterable.Type? {
                    return RouterContext.self as? EndpointRegisterable.Type
                }
            }
            """,
            macros: testMacros
        )
    }*/

    /*
  // Test classes with the macro applied
   @Endpoint("/api")
   class BaseEntity {
       // Base implementation
   }
   
   @Endpoint("/users")
   class UserEntity: BaseEntity {
       // User implementation
   }
   
   @Endpoint("/:id")
   class SpecificUserEntity: UserEntity {
       // Specific user implementation
   }
   
   @Endpoint("/products")
   class ProductEntity: BaseEntity {
       // Product implementation
   }
   
   @Endpoint("/:sku")
   class SpecificProductEntity: ProductEntity {
       // Specific product implementation
   }
   
   // Class without an endpoint but in the hierarchy
   class IntermediateEntity: BaseEntity {
       // No endpoint prefix for this class
   }
   
   @Endpoint("/special")
   class SpecialEntity: IntermediateEntity {
       // This should stack on top of BaseEntity, skipping IntermediateEntity
   }
   
   // Class with no parent in the hierarchy
   @Endpoint("/standalone")
   class StandaloneEntity {
       // No parent with endpoint prefix
   }
   
   // Clear registry before each test
   override func setUp() {
       super.setUp()
       // Reset the registry to ensure clean state for each test
       EndpointRegistry.shared = EndpointRegistry()
   }
   
   func testEndpointPrefixValues() {
       // Test that each class correctly reports its own prefix
       XCTAssertEqual(BaseEntity.endpointPath, "/api")
       XCTAssertEqual(UserEntity.endpointPath, "/users")
       XCTAssertEqual(SpecificUserEntity.endpointPath, "/:id")
       XCTAssertEqual(ProductEntity.endpointPath, "/products")
       XCTAssertEqual(SpecificProductEntity.endpointPath, "/:sku")
       XCTAssertEqual(SpecialEntity.endpointPath, "/special")
       XCTAssertEqual(StandaloneEntity.endpointPath, "/standalone")
   }
   
   func testParentTypeRelationships() {
       // Test parent-child relationships
       XCTAssertNil(BaseEntity.parentType, "Base entity should have no parent")
       XCTAssertTrue(UserEntity.parentType === BaseEntity.self, "UserEntity's parent should be BaseEntity")
       XCTAssertTrue(SpecificUserEntity.parentType === UserEntity.self, "SpecificUserEntity's parent should be UserEntity")
       XCTAssertTrue(ProductEntity.parentType === BaseEntity.self, "ProductEntity's parent should be BaseEntity")
       XCTAssertTrue(SpecificProductEntity.parentType === ProductEntity.self, "SpecificProductEntity's parent should be ProductEntity")
       XCTAssertTrue(SpecialEntity.parentType === IntermediateEntity.self, "SpecialEntity's parent should be IntermediateEntity")
       
       // Test intermediate class relationships
       if let intermediateParent = IntermediateEntity.parentType {
           XCTAssertTrue(intermediateParent === BaseEntity.self, "IntermediateEntity's parent should be BaseEntity")
       } else {
           XCTFail("IntermediateEntity should have BaseEntity as parent")
       }
       
       // Test standalone class
       XCTAssertNil(StandaloneEntity.parentType, "StandaloneEntity should have no parent")
   }
   
   func testEndpointRegistration() {
       // Register all endpoints
       BaseEntity.registerEndpoint()
       UserEntity.registerEndpoint()
       SpecificUserEntity.registerEndpoint()
       ProductEntity.registerEndpoint()
       SpecificProductEntity.registerEndpoint()
       IntermediateEntity.registerEndpoint() // No own prefix, but should inherit from parent
       SpecialEntity.registerEndpoint()
       StandaloneEntity.registerEndpoint()
       
       // Get all registered endpoints
       let endpoints = EndpointRegistry.shared.getAllEndpoints()
       
       // Verify expected endpoints
       XCTAssertTrue(endpoints.contains("/api"), "Registry should contain /api")
       XCTAssertTrue(endpoints.contains("/api/users"), "Registry should contain /api/users")
       XCTAssertTrue(endpoints.contains("/api/users/:id"), "Registry should contain /api/users/:id")
       XCTAssertTrue(endpoints.contains("/api/products"), "Registry should contain /api/products")
       XCTAssertTrue(endpoints.contains("/api/products/:sku"), "Registry should contain /api/products/:sku")
       XCTAssertTrue(endpoints.contains("/api"), "Registry should contain /api for IntermediateEntity")
       XCTAssertTrue(endpoints.contains("/api/special"), "Registry should contain /api/special")
       XCTAssertTrue(endpoints.contains("/standalone"), "Registry should contain /standalone")
       
       // Verify mapping between endpoints and types
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/api") === BaseEntity.self)
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/api/users") === UserEntity.self)
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/api/users/:id") === SpecificUserEntity.self)
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/api/products") === ProductEntity.self)
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/api/products/:sku") === SpecificProductEntity.self)
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/api/special") === SpecialEntity.self)
       XCTAssertTrue(EndpointRegistry.shared.getTypeForEndpoint("/standalone") === StandaloneEntity.self)
   }
   
   func testEndpointDuplication() {
       // Register the same endpoint twice
       BaseEntity.registerEndpoint()
       BaseEntity.registerEndpoint()
       
       // Get all registered endpoints
       let endpoints = EndpointRegistry.shared.getAllEndpoints()
       
       // There should be only one instance of each endpoint
       XCTAssertEqual(endpoints.count, 1, "Duplicate registrations should be overwritten")
       XCTAssertEqual(endpoints.first, "/api", "Only one /api endpoint should be registered")
   }
   
   func testComplexHierarchy() {
       // Create a more complex test with a deeper hierarchy
       @Endpoint("/v1")
       class ApiV1 {
           // API v1 base
       }
       
       @Endpoint("/auth")
       class AuthApi: ApiV1 {
           // Auth API
       }
       
       @Endpoint("/login")
       class LoginApi: AuthApi {
           // Login API
       }
       
       @Endpoint("/callback")
       class OAuthCallbackApi: LoginApi {
           // OAuth callback
       }
       
       // Register the endpoints
       ApiV1.registerEndpoint()
       AuthApi.registerEndpoint()
       LoginApi.registerEndpoint()
       OAuthCallbackApi.registerEndpoint()
       
       // Get all registered endpoints
       let endpoints = EndpointRegistry.shared.getAllEndpoints()
       
       // Verify expected endpoints
       XCTAssertTrue(endpoints.contains("/v1"), "Registry should contain /v1")
       XCTAssertTrue(endpoints.contains("/v1/auth"), "Registry should contain /v1/auth")
       XCTAssertTrue(endpoints.contains("/v1/auth/login"), "Registry should contain /v1/auth/login")
       XCTAssertTrue(endpoints.contains("/v1/auth/login/callback"), "Registry should contain /v1/auth/login/callback")
   }
   
   func testPathSlashHandling() {
       // Test handling of slashes in paths
       @Endpoint("/api/")
       class ApiWithTrailingSlash {
           // API with trailing slash
       }
       
       @Endpoint("users")
       class UsersNoLeadingSlash: ApiWithTrailingSlash {
           // Users without leading slash
       }
       
       // Register the endpoints
       ApiWithTrailingSlash.registerEndpoint()
       UsersNoLeadingSlash.registerEndpoint()
       
       // Get all registered endpoints
       let endpoints = EndpointRegistry.shared.getAllEndpoints()
       
       // Verify expected endpoints
       XCTAssertTrue(endpoints.contains("/api/"), "Registry should contain /api/")
       XCTAssertTrue(endpoints.contains("/api/users"), "Registry should contain /api/users")
   }
     */
}
