//
//  File.swift
//  
//
//  Created by David Trallero on 21/10/21.
//

import Foundation
import NIOCore
import NIOHTTP1

open class MSKRouterResponse
{
    var _status: HTTPResponseStatus = .ok
    var _headers:HTTPHeaders = HTTPHeaders()
    var _ctx: ChannelHandlerContext
    var _data:Data? = nil
    
    public init ( context: ChannelHandlerContext ) {
        _ctx = context
    }
    
    @discardableResult
    public func status ( _ status: HTTPResponseStatus ) -> MSKRouterResponse {
        _status = status
        return self
    }
    
    @discardableResult
    public func send ( data: Data ) -> MSKRouterResponse {
        if _data == nil { _data = Data() }
        _data?.append( data )
        return self
    }
    
    @discardableResult
    public func send ( json:Any ) -> MSKRouterResponse {
        _headers.add( name: "Content-Type", value: "application/json" )
        var data:Data
        do {
            data = try JSONSerialization.data(withJSONObject: json )
        }
        catch {
            data = error.localizedDescription.data(using: .utf8 )!
        }
        
        send( data: data )
        return self
    }
    
    
    @discardableResult
    public func send (_ text:String ) -> MSKRouterResponse {
        send( data: text.data( using: .utf8 )! )
        return self
    }

    public func redirect ( _ path: String ) throws {
//        try response!.redirect( path )
    }
    
    public func end() throws {
//        try response!.end()
    }
    
//    public func send(json: Encodable) -> MSKRouterResponse {
//        response.send(json: json)
//        return self
//    }
}
