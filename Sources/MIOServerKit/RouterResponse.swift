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
    
    public init() {
        _http_request_head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "")
    }
    
    public init( _ httpRequestHead: HTTPRequestHead ) {
        _http_request_head = httpRequestHead
    }
    
    @discardableResult
    public func status ( _ status:HTTPResponseStatus ) -> RouterResponse {
        self.status = status
        return self
    }    
}
