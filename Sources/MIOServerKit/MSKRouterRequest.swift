//
//  File.swift
//  
//
//  Created by David Trallero on 21/10/21.
//

import Foundation
import NIOCore
import NIOHTTP1

open class MSKRouterRequest
{
    var _parameters: [String:String]? = nil
    var _query_parameters: [String:String]? = nil

    // Temporally public
//    public var request:RouterRequest? = nil

    public var parameters: [String:String] {
        get { _parameters ?? [:] }
        set { _parameters = newValue }
    }

    public var queryParameters: [String:String] {
        get { _query_parameters ?? [:] }
        set { _query_parameters = newValue }
    }
    
    public var body: ByteBuffer {
        get { _body }
    }

    public var method:HTTPMethod { get { _head.method } }
    public var url:URL { get { URL( string: _head.uri )! } }
//    public var userInfo:[String:Any] { get { request!.userInfo } }
    public var headers:HTTPHeaders { get { _head.headers } }
    
    var _head: HTTPRequestHead
    var _body: ByteBuffer
    
    public init(_ head:HTTPRequestHead, body: ByteBuffer ) {
        _head = head
        _body = body
    }
    
    public func bodyAsJSON ( ) throws -> Any {

        return false
//        let json = try JSONSerialization.jsonObject(with: _body! )
//        return json
    }
}
