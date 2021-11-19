//
//  RouterContext.swift
//  
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation
import Kitura
import MIOCore

public let uuidRegexRoute = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

public struct RequestRecorded {
    public var method  : RouterMethod
    public var url     : String
    public var body    : Any?
    public var response: [String:Any?]
    
    public init ( _ context: RouterContext, _ res: [String:Any?] ) {
        method   = context.request.method
        url      = context.request.url.path
        body     = try? context.request.bodyAsJSON()
        response = res
    }
    
    
    public func as_swift_code ( ) -> [Any?] {
        return [method.rawValue,url,body,response]
    }
}

#if DEBUG
var g_request_recorder: [RequestRecorded] = []


public func recorded_test ( ) -> [ Any ] {
    return g_request_recorder.map{ $0.as_swift_code() }
}


public func clean_recorded_test ( ) { g_request_recorder = [] }
#endif


public struct ResponseContext {
    var data: Any
    var status: String = "OK"
    var error: String  = ""
    var errorCode: Int = 0
    
    public init ( data: Any, status: String = "OK", error: String = "", errorCode: Int = 0 ) {
        self.data = data
        self.status = status
        self.error = error
        self.errorCode = errorCode
    }
    
    func asJson ( ) -> [String:Any] {
        return [ "data": data
               , "status": status
               , "error": error
               , "errorCode": errorCode ]
    }
}


public protocol RouterContextProtocol {
    func queryParam ( _ name: String ) -> String?
    func urlParam<T> ( _ name: String ) throws -> T
    func bodyParam (_ name: String) -> Any?
}


@objc open class RouterContext : MIOCoreContext, RouterContextProtocol
{
    public var request: MSKRouterRequest
    public var response: MSKRouterResponse

    public init ( _ request: MSKRouterRequest, _ response: MSKRouterResponse ) {
        self.request  = request
        self.response = response
    }
    
    public init ( ) {
        self.request = MSKRouterRequest( )
        self.response = MSKRouterResponse( )
    }
    
    open func urlParam<T> ( _ name: String ) throws -> T {
        return try MIOCoreParam( request.parameters, name )
    }
    
    open func queryParam ( _ name: String ) -> String? {
        return request.queryParameters[ name ]
    }
    
    
    var _body_as_json: [String : Any]? = nil
    
    public func bodyParam (_ name: String) -> Any? {
        if _body_as_json == nil {
            guard let body = try? request.bodyAsJSON() else { return nil }
            _body_as_json = body
        }
        
        if !_body_as_json!.keys.contains(name) { return nil }
        return _body_as_json![ name ]!
    }

    
    public func sendOKResponse ( _ json : Any? = nil ) throws {
        response.status(.OK)
        
        if json is nil {
            
        } else if json is Data {
            response.send( data: json as! Data )
        } else if let ret = json as? ResponseContext {
            response.send( json: ret.asJson( ) )
        } else if let ret = json as? String {
            response.send( ret )
        } else {
            let response_json = json is [Any] || json is [String: Any] ? ["status" : "OK", "data" : json! ]
                              :                                          ["status" : "OK"]
            
            #if SAVE_RECORD
            if record_request {
                g_request_recorder.append( RequestRecorded( self, response_json ) )
            }
            #endif
            
            response.send(json: response_json )
        }
        
        try response.end( )
    }
    
    
    public func sendErrorResponse ( _ error : Error, httpStatus : MSKHTTPStatusCode = .badRequest) throws {
        
        response.status( httpStatus )
        
        let response_json: [String:Any] = ["status" : "Error", "error" : error.localizedDescription, "errorCode": error is MIOErrorCode ? (error as! MIOErrorCode).code : 0 ]
        
        #if SAVE_RECORD
        if record_request {
            g_request_recorder.append( RequestRecorded( self, response_json ) )
        }
        #endif

        response.send( json: response_json )
    
        try response.end( )
    }
}
