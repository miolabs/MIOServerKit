//
//  RouterContext.swift
//
//
//  Created by Javier Segura Perez on 14/9/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import MIOCore
import NIOHTTP1

public let uuidRegexRoute = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

//public struct RequestRecorded
//{
//    public var method  : HTTPMethod
//    public var url     : String
//    public var body    : Any?
//    public var response: [String:Any?]
//
//    public init ( _ context: RouterContext, _ res: [String:Any?] ) {
//        method   = context.request.method
//        url      = context.request.url.path
//        body     = [:] //try? context.request.bodyAsJSON()
//        response = res
//    }
//
//
//    public func as_swift_code ( ) -> [Any?] {
//        return [method.rawValue,url,body,response]
//    }
//}
//
//#if DEBUG
//var g_request_recorder: [RequestRecorded] = []
//
//
//public func recorded_test ( ) -> [ Any ] {
//    return g_request_recorder.map{ $0.as_swift_code() }
//}
//
//
//public func clean_recorded_test ( ) { g_request_recorder = [] }
//#endif
//


//public enum ResponseStatus: Int
//{
//    case ok    = 0
//    case error = -1
//}
//
//public struct ResponseContext
//{
//    var data: Any
//    var status: ResponseStatus = .ok
//    var error: String  = ""
//    var errorCode: Int = 0
//
//    public init ( data: Any, status: ResponseStatus = .ok, error: String = "", errorCode: Int = 0 ) {
//        self.data = data
//        self.status = status
//        self.error = error
//        self.errorCode = errorCode
//    }
//
//    func asJson ( ) -> [String:Any] {
//        return [ "data": MIOCoreSerializableJSON( data )
//               , "status": "OK"
//               , "error": error
//               , "errorCode": errorCode ]
//    }
//}


public protocol RouterContextProtocol : AnyObject
{
    init()
    
    func queryParam ( _ name: String ) -> String?
    func urlParam<T> ( _ name: String ) throws -> T
    func bodyParam<T> (_ name: String, optional: Bool ) throws -> T?
    
    func bodyAsData() -> Data?
    func bodyAsJSON() -> Any?
    
    var request: RouterRequest! { get set }
    var response: RouterResponse! { get set }
    
    func willExectute() throws
    func didExecute() throws
}

@objc
open class RouterContext : MIOCoreContext, RouterContextProtocol
{
    public var request: RouterRequest!
    public var response: RouterResponse!

    public init ( _ request: RouterRequest, _ response: RouterResponse ) {
        self.request  = request
        self.response = response
    }
    
    public override required init ( ) {
    }

    open func urlParam<T> ( _ name: String ) throws -> T {
        return try MIOCoreParam( request.parameters, name )
    }
    
    open func queryParam ( _ name: String ) -> String? {
        return request.queryParameters[ name ]
    }
    
    open func bodyAsData() -> Data? {
        return request.body
    }

    open func bodyAsJSON() -> Any? {
        if request.body == nil { return nil }
        return try? JSONSerialization.jsonObject( with: request.body! )
    }
    
    var _body_as_json: [String : Any]? = nil
    
    var _body: Any? = nil
    public func bodyParam<T> (_ name: String, optional: Bool = false ) throws -> T? {
        if _body == nil {
            let json = bodyAsJSON() as? [String:Any]
            
            if json == nil {
                if optional { return nil }
                throw ServerError.missingJSONBody( )
            }
            
            _body = json
        }
        
        if let dict = _body as? [ String:Any ] {
            
            if dict.keys.contains(name) {
                if optional { return nil }
                throw ServerError.fieldNotFound( name )
            }
            
            
            if let value = dict[ name ] as? T {
                return value
            }
            
            if optional { return nil }
            throw ServerError.fieldNotFound( name )
        }
                
//        if let value = _body![ name ] as? T {
//            return value
//        }

        if optional { return nil }
        throw ServerError.fieldNotFound( name )
    }
    
    
    open func willExectute() throws { }
    open func didExecute() throws { }

    
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
