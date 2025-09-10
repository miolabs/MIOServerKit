//
//  RouterContext.swift
//
//
//  Created by Javier Segura Perez on 14/9/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import MIOCore
import MIOCoreContext
import NIOHTTP1

public let uuidRegexRoute = "([0-9a-fA-F]{8}-[0-96a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"


public protocol RouterContextProtocol : AnyObject
{
    var request: RouterRequest { get }
    var response: RouterResponse { get }
    
    init( _ request: RouterRequest, _ response: RouterResponse, values:[String:Any] ) throws
    
    func queryParam ( _ name: String ) -> String?
    func urlParam<T> ( _ name: String ) throws -> T
    func bodyParam<T> (_ name: String, optional: Bool ) throws -> T?
    
    func bodyAsData() -> Data?
    func bodyAsJSON<T>() throws -> T?
        
    // Sync methods
    func willExecute() throws
    func didExecute() throws

    // Async methods
    func willExecute() async throws
    func didExecute() async throws
}

extension RouterContextProtocol
{
    public func urlParam<T> ( _ name: String ) throws -> T {
        return try MIOCoreParam( request.parameters, name )
    }
    
    public func queryParam ( _ name: String ) -> String? {
        return request.queryParameters[ name ]
    }
    
    public func bodyAsData() -> Data? {
        return request.body
    }

    public func bodyAsJSON<T>() throws -> T {
        if request.body == nil { throw ServerError.missingJSONBody() }
        let json = try JSONSerialization.jsonObject( with: request.body! ) as? T
        if json == nil { throw ServerError.invalidJSONBodyCast() }
        return json!
    }
    
    public func bodyParam<T> (_ name: String, optional: Bool = false ) throws -> T? {
        let json:[ String:Any ]? = try bodyAsJSON()
        if json == nil {
            if optional { return nil }
            throw ServerError.missingJSONBody( )
        }

        if let dict = json {

            if let value = dict[ name ] as? T {
                return value
            }
            else if optional { return nil }
            else { throw ServerError.fieldNotFound( name ) }
        }

        if optional { return nil }
        throw ServerError.fieldNotFound( name )
    }
    
    // Default implementations for sync methods
    public func willExecute() throws { }
    public func didExecute() throws { }
       
    // Default implementations for async methods
    public func willExecute() async throws { }
    public func didExecute() async throws { }
    
}


@objc
open class RouterContext : MIOCoreContext, RouterContextProtocol
{
    public var request: RouterRequest
    public var response: RouterResponse
    
    public required init ( _ request: RouterRequest, _ response: RouterResponse, values:[String:Any] = [:] ) throws {
        self.request        = request
        self.response       = response
        super.init( values )
    }
    
    // Default implementations for sync methods
    open func willExecute() throws { }
    open func didExecute() throws { }
        
    // Default implementations for async methods
    open func willExecute() async throws { }
    open func didExecute() async throws { }
        
    open func extraResponseHeaders ( ) -> [String:String] { return [:] }
    open func responseBody ( _ value : Any? = nil ) throws -> Data? {
        var content_type:String? = nil
        var body:Data?           = nil
        
        switch value {
        case let d as Data:
            content_type = "application/octet-stream"
            body = d
        case let s as String:
            content_type = "text/plain"
            body = s.data(using: .utf8)
        case let arr as [Any]:
        case let dic as [String:Any]:
            content_type = "application/json"
            body = try MIOCoreJsonValue(withJSONObject: dic)

            if self.response.headers[.contentType].count == 0 {
                self.response.headers.replaceOrAdd(name: .contentType, value: "application/json" )
            }
            return try MIOCoreJsonValue(withJSONObject: dic)
        
        default: break
        }
        
        if self.response.headers[.contentType].count == 0, let ct = content_type {
            self.response.headers.replaceOrAdd(name: .contentType, value: ct )
        }

        return body
    }
}
