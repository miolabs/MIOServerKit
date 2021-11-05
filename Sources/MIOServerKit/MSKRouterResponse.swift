//
//  File.swift
//  
//
//  Created by David Trallero on 21/10/21.
//

import Foundation
import Kitura

open class MSKRouterResponse
{
    public var response:RouterResponse? = nil
    
    public init ( _ response:RouterResponse? = nil ){
        self.response = response
    }
    
    @discardableResult
    public func status ( _ status:MSKHTTPStatusCode ) -> MSKRouterResponse {
        response!.status(status)
        return self
    }
    
    @discardableResult
    public func send ( data: Data ) -> MSKRouterResponse {
        response!.send(data: data)
        return self
    }
    
    @discardableResult
    public func send ( json:[Any] ) -> MSKRouterResponse {
        response!.send(json: json)
        return self
    }
    
    @discardableResult
    public func send ( json:[String:Any] ) -> MSKRouterResponse {
        response!.send(json: json)
        return self
    }

    
    @discardableResult
    public func send (_ data:String ) -> MSKRouterResponse {
        response!.send( data )
        return self
    }

    public func redirect ( _ path: String ) throws {
        try response!.redirect( path )
    }
    
    public func end() throws {
        try response!.end()
    }
    
//    public func send(json: Encodable) -> MSKRouterResponse {
//        response.send(json: json)
//        return self
//    }
}
