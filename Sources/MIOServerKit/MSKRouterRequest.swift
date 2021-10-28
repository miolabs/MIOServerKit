//
//  File.swift
//  
//
//  Created by David Trallero on 21/10/21.
//

import Foundation
import Kitura

open class MSKRouterRequest
{
    var _parameters: [String:String]? = nil
    
    // Temporally public
    public var request:RouterRequest

    public var parameters: [String:String] {
        get { _parameters ?? request.parameters }
        set { _parameters = newValue }
    }
    
    public var body: ParsedBody? {
        get { request.body }
    }

    public var method:RouterMethod { get { request.method } }
    public var url:URL { get { request.urlURL } }
    public var queryParameters:[String:String] {
        get { request.queryParameters }
        set { request.queryParameters = newValue }
    }
    public var userInfo:[String:Any] { get { request.userInfo } }
    public var headers:Headers { get { request.headers } }
    
    public init(_ request:RouterRequest) {
        self.request = request
    }
    
    public func bodyAsJSON ( ) throws -> [String : Any] {
        guard let json = request.body?.asJSON else {
          throw MIOServerKitError.invalidBodyData( "Expected JSON was not sent" )
        }
        
        return json
    }
}
