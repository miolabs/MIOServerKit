//
//  RouterResponse.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import NIOHTTP1
import MIOCore

open class RouterResponse
{
    public var status:HTTPResponseStatus = .ok
    public var headers:HTTPHeaders = HTTPHeaders()
    
    public var body:Any? = nil
 
    let _http_request_head: HTTPRequestHead
    
    public init( _ httpRequestHead: HTTPRequestHead ) {
        _http_request_head = httpRequestHead
    }
    
    @discardableResult
    public func status ( _ status:HTTPResponseStatus ) -> RouterResponse {
        self.status = status
        return self
    }
    
//    @discardableResult
//    public func send ( data: Data ) -> RouterResponse {
//        body = data
//        return self
//    }
//
//    @discardableResult
//    public func send ( json:[Any] ) throws -> RouterResponse {
//        headers["Content-Type"] = "application/json"
//        body = try MIOCoreJsonValue( withJSONObject: json )
//        return self
//    }
//
//    @discardableResult
//    public func send ( json:[String:Any] ) throws -> RouterResponse {
//        headers["Content-Type"] = "application/json"
//        body = try MIOCoreJsonValue( withJSONObject: json )
//        return self
//    }
//
//    @discardableResult
//    public func send (_ text:String ) -> RouterResponse {
//        body = text.data( using: .utf8 )
//        return self
//    }

//    public func redirect ( _ path: String ) throws {
//        try response!.redirect( path )
//    }
    
//    public func end() throws {
//        try response!.end()
//    }
    
//    public func send(json: Encodable) -> RouterResponse {
//        response.send(json: json)
//        return self
//    }
}
