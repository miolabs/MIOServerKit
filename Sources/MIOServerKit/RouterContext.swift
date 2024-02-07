//
//  RouterContext.swift
//  
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation
import Kitura
import MIOCore
import MIOCoreContext

public let uuidRegexRoute = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

#if DEBUG

//public struct RequestRecorded {
//    public var method  : RouterMethod
//    public var url     : String
//    public var body    : Any?
//    public var response: [String:Any?]
//    
//    public init ( _ context: RouterContext, _ res: [String:Any?] ) {
//        method   = context.request.method
//        url      = context.request.url.path
//        body     = try? context.request.bodyAsJSON()
//        response = res
//    }
//    
//    
//    public func as_swift_code ( ) -> [Any?] {
//        return [method.rawValue,url,body,response]
//    }
//}

// var g_request_recorder: [RequestRecorded] = []


//public func recorded_test ( ) -> [ Any ] {
//    return g_request_recorder.map{ $0.as_swift_code() }
//}


// public func clean_recorded_test ( ) { g_request_recorder = [] }
#endif


public enum ResponseStatus: Int
{
    case ok    = 0
    case error = -1
}

public struct ResponseContext {
    var data: Any
    var status: ResponseStatus = .ok
    var error: String  = ""
    var errorCode: Int = 0
    
    public init ( data: Any, status: ResponseStatus = .ok, error: String = "", errorCode: Int = 0 ) {
        self.data = data
        self.status = status
        self.error = error
        self.errorCode = errorCode
    }
    
    public func asJson ( ) -> [String:Any] {
        return [ "data": MIOCoreSerializableJSON( data )
               , "status": "OK"
               , "error": error
               , "errorCode": errorCode ]
    }
}


public protocol RouterContextProtocol  // : MIOCoreContextProtocol
{
    var request: MSKRouterRequest { get set }
    var response: MSKRouterResponse { get set }
  //  var _body_as_json: [String:Any]? { get set } // to define in derivated class
    var body_as_json: [String:Any] { get throws }
    
    func queryParam ( _ name: String ) -> String?
    func urlParam<T> ( _ name: String ) throws -> T
    func bodyParam<T> (_ name: String, optional: Bool) throws -> T?
    
    func save ( ) throws -> Void
}




//@objc open class RouterContext : MIOCoreContext, RouterContextProtocol
//{
//    public var request: MSKRouterRequest
//    public var response: MSKRouterResponse
//    
//    public init ( _ request: MSKRouterRequest, _ response: MSKRouterResponse ) {
//        self.request  = request
//        self.response = response
//    }
//    
//    public init ( ) {
//        self.request = MSKRouterRequest( )
//        self.response = MSKRouterResponse( )
//    }
//    
//    var _body: [String:Any]? = nil
//    
//    public var body_as_json: [String : Any]? {
//        get {
//            if _body == nil {
//                _body = try? request.bodyAsJSON()
//            }
//            
//            return _body
//        }
//    }
//}


public extension RouterContextProtocol
{
    func urlParam<T> ( _ name: String ) throws -> T {
        return try MIOCoreParam( request.parameters, name )
    }
    
    func queryParam ( _ name: String ) -> String? {
        return request.queryParameters[ name ]
    }
    
    func bodyParam<T> (_ name: String, optional: Bool = false ) throws -> T? {
        let body = try? body_as_json
        
        if body == nil {
            if optional { return nil }
            throw MIOError.missingJSONBody( )
        }
        
        if !body!.keys.contains(name) {
            if optional { return nil }
            throw MIOError.fieldNotFound( name )
        }
        
        
        if let value = body![ name ] as? T {
            return value
        }
        
        if optional { return nil }
        throw MIOError.fieldNotFound( name )
    }

    func sendOKResponse ( _ json : Any? = nil ) throws {
        response.status(.OK)
        
        if json == nil {
            
        } else if json is Data {
            response.send( data: json as! Data )
        } else if let ret = json as? ResponseContext {
            response.send( json: ret.asJson( ) )
        } else if let ret = json as? String {
            response.send( ret )
        } else {
            let response_json = json is [Any] || json is [String: Any] ? [ "status" : "OK", "data" : json! ]
                              :                                          [ "status" : "OK" ]
            #if SAVE_RECORD
            if record_request {
                g_request_recorder.append( RequestRecorded( self, response_json ) )
            }
            #endif
            
            response.send(json: MIOCoreSerializableJSON( response_json ) as! [String:Any] )
        }
        
        try response.end( )
    }
    
    
    func sendErrorResponse ( _ error : Error, httpStatus : MSKHTTPStatusCode = .badRequest) throws {
        
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

    func save ( ) throws { }
}
