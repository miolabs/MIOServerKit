//
//  RouterRequest.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import NIOHTTP1

open class RouterRequest
{
    let _http_request_head: HTTPRequestHead
    let _url:URL
    let _query_parameters: [String:String]
    
    var _parameters: [String:String]? = nil
    public var parameters: [String:String] {
        get { _parameters ?? [:] }
        set { _parameters = newValue }
    }

    public var userInfo: [String:Any] = [:]
    public var method:HTTPMethod { get { _http_request_head.method } }
    public var url:URL { get { _url } }
    public var headers: HTTPHeaders { return _http_request_head.headers }
    public var queryParameters: [String:String] { get { _query_parameters } }
    //    public var body: Data? { get { _body } }
    public var body:Data? = nil
                
    public init() {
        _http_request_head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "")
        _url = URL( string: "" )!
        _query_parameters = [:]
    }
    
    public init( _ httpRequestHead: HTTPRequestHead )
    {
        _http_request_head = httpRequestHead
        _url = URL( string: httpRequestHead.uri )!
        
        var qm:[String:String] = [:]
        let query_params = (_url.query ?? "").components(separatedBy: "&")
        for p in query_params 
        {
            if p.isEmpty { continue }
            let array = p.components(separatedBy: "=")
            let key = array[ 0 ]
            let value = array[ 1 ]
            qm[ key ] = value
        }
        
        _query_parameters = qm
    }
    

    
//    public var userInfo:[String:Any] { get { request!.userInfo } }
//
//    public func bodyAsJSON ( ) throws -> [String : Any] {
//        guard let json = request?.body?.asJSON else {
//          throw MIOServerKitError.invalidBodyData( "Expected JSON was not sent" )
//        }
//
//        return json
//    }

}
