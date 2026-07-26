//
//  RouterRequest.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import NIOHTTP1
import MIOCoreLogger

// Single-threaded by construction: created in channelRead, captured into
// exactly one of {.system, .sync via runIfActive, .async via Task} and
// never shared. Do not store or pass to multiple consumers concurrently.
open class RouterRequest : @unchecked Sendable
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
        _http_request_head = HTTPRequestHead(version: .http1_1, method: .GET, uri: "http://localhost")
        _url = URL( string: "http://localhost" )!
        _query_parameters = [:]
    }
    
    /// Path used when the request-target cannot be parsed as a URL. It is
    /// deliberately not routable, so such a request is answered with
    /// "endpoint not found" rather than reaching a handler.
    static let unparsableTargetPath = "/__mioserverkit_unparsable_request_target__"

    public init( _ httpRequestHead: HTTPRequestHead )
    {
        _http_request_head = httpRequestHead

        // A request-target the URL parser rejects must not abort the process:
        // this runs on an event-loop thread, so a trap here takes the whole
        // server down for every connection.
        if let url = URL( string: httpRequestHead.uri ) {
            _url = url
        }
        else {
            Log.error( "Cannot parse request target as a URL: \(httpRequestHead.uri)" )
            _url = URL( string: RouterRequest.unparsableTargetPath )!
        }

        _query_parameters = RouterRequest.parseQueryParameters( _url.query )
    }

    /// Parses a raw query string into key/value pairs.
    ///
    /// Splits each pair on its *first* `=` only, so a value may contain `=`
    /// (`?filter=a=b` yields `a=b`). A parameter with no `=` at all (`?flag`)
    /// maps to an empty string instead of being a fatal error.
    ///
    /// Values are returned exactly as they appear on the wire — they are not
    /// percent-decoded. Callers that need decoding must do it themselves.
    static func parseQueryParameters ( _ query: String? ) -> [String:String]
    {
        guard let query, query.isEmpty == false else { return [:] }

        var params:[String:String] = [:]
        for pair in query.components( separatedBy: "&" )
        {
            if pair.isEmpty { continue }

            guard let separator = pair.firstIndex( of: "=" ) else {
                // A valueless parameter such as "?flag".
                params[ pair ] = ""
                continue
            }

            let key = String( pair[ pair.startIndex ..< separator ] )
            if key.isEmpty { continue }

            params[ key ] = String( pair[ pair.index( after: separator )... ] )
        }

        return params
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
