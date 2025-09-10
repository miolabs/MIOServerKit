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
    
//    public func sendOKResponse ( _ json : Any? = nil ) throws {
//        response.status(.ok)
//
//        if json == nil {
//
//        } else if json is Data {
//            response.send( data: json as! Data )
//        } else if let ret = json as? ResponseContext {
//            response.send( json: ret.asJson( ) )
//        } else if let ret = json as? String {
//            response.send( ret )
//        } else {
//            let response_json = json is [Any] || json is [String: Any] ? [ "status" : "OK", "data" : json! ]
//                              :                                          [ "status" : "OK" ]
//            #if SAVE_RECORD
//            if record_request {
//                g_request_recorder.append( RequestRecorded( self, response_json ) )
//            }
//            #endif
//
//            response.send(json: MIOCoreSerializableJSON( response_json ) as! [String:Any] )
//        }
//
//        try response.end( )
//    }
//
    
//    public func sendErrorResponse ( _ error : Error, httpStatus : HTTPResponseStatus = .badRequest) throws {
//
//        response.status( httpStatus )
//
//        let response_json: [String:Any] = ["status" : "Error", "error" : error.localizedDescription, "errorCode": error is MIOErrorCode ? (error as! MIOErrorCode).code : 0 ]
//
//        #if SAVE_RECORD
//        if record_request {
//            g_request_recorder.append( RequestRecorded( self, response_json ) )
//        }
//        #endif
//
//        response.send( json: response_json )
//
//        try response.end( )
//    }

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
        switch value {
        case let d as Data  :
            self.response.headers.replaceOrAdd(name: .contentType, value: "application/octet-stream" )
            return d
        case let s as String:
            self.response.headers.replaceOrAdd(name: .contentType, value: "text/plain" )
            return s.data(using: .utf8)
        case let arr as [Any]:
            self.response.headers.replaceOrAdd(name: .contentType, value: "application/json" )
            return try MIOCoreJsonValue(withJSONObject: arr)
        case let dic as [String:Any]:
            self.response.headers.replaceOrAdd(name: .contentType, value: "application/json" )
            return try MIOCoreJsonValue(withJSONObject: dic)
        default: return nil
        }
    }
}
