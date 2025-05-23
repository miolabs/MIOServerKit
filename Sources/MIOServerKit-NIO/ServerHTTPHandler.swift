//
//  ServerHTTPHandler.swift
//
//
//  Created by Javier Segura Perez on 12/3/23.
//

import Foundation

import NIO
import NIOHTTP1
import NIOFoundationCompat
import MIOCore
import MIOServerKit

class ServerHTTPHandler: ChannelInboundHandler
{
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
        
    private enum State {
        case idle
        case waitingForRequestBody
        case sendingResponse
        
        mutating func requestReceived() {
            precondition( self == .idle, "Invalid state for request received: \(self)" )
            self = .waitingForRequestBody
        }

        mutating func requestComplete() {
            precondition( self == .waitingForRequestBody, "Invalid state for request complete: \(self)" )
            self = .sendingResponse
        }

        mutating func responseComplete() {
            precondition( self == .sendingResponse, "Invalid state for response complete: \(self)" )
            self = .idle
        }
    }
    
    private var buffer: ByteBuffer! = nil
    private var keepAlive = false
    private var state = State.idle
        
    private var infoSavedRequestHead: HTTPRequestHead?
    private var infoSavedBodyBytes: Int = 0
    private var infoSavedBodyBuffer: ByteBuffer? = nil
    
//    private var continuousCount: Int = 0
    
    var request:RouterRequest!
    var response:RouterResponse!
        
    private let router: Router
    private let serverSettings: ServerSettings
    
    public init( router:Router, settings: ServerSettings ) {
        self.router = router
        self.serverSettings = settings
    }
    
    private func dispatch_request( completion: @escaping MethodEndpointCompletionBlock )
    {
        let path = request.url.relativePath
        var route_vars: RouterPathVars = [:]
        let method = EndpointMethod( rawValue: request!.method.rawValue )!
                
        let endpoint = router.root.match( RouterPath( path ), &route_vars )
        
        if endpoint == nil { completion( nil, ServerError.endpointNotFound( path, method.rawValue ), nil ); return }
        
        response.headers[ "Access-Control-Allow-Origin" ] = "*"
        response.headers[ "Access-Control-Allow-Methods" ] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        if let headers = request.headers[ "Access-Control-Request-Headers" ] {
            response.headers[ "Access-Control-Allow-Headers" ] = headers
        }
        
        if method == .OPTIONS {
            response.status(.noContent)
//            response.headers[ "Allow" ] = Array( endpoint!.methods.keys ).map(\.rawValue).joined(separator: ", ") + ", HEAD"
            completion(nil, nil, nil)
        }
        else if method == .HEAD {
            response.status(.ok)
            completion(nil, nil, nil)
        }
        else if endpoint!.methods[ method ] != nil {
            request.parameters = route_vars
            let endpoint_spec = endpoint!.methods[ method ]!
            endpoint_spec.run( serverSettings, request, response, completion )
        }
    }
                   
    func channelRead(context: ChannelHandlerContext, data: NIOAny) 
    {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let http_request):
            self.keepAlive = http_request.isKeepAlive
            
            infoSavedRequestHead = http_request
            self.infoSavedBodyBytes = 0
            self.infoSavedBodyBuffer = nil
            
            request = RouterRequest( http_request )
            response = RouterResponse( http_request )
            
            self.state.requestReceived()
                        
        case .body( buffer: var buf ):
            self.infoSavedBodyBytes += buf.readableBytes
            if infoSavedBodyBuffer == nil {
                infoSavedBodyBuffer = context.channel.allocator.buffer(capacity: 0)
            }
            
            infoSavedBodyBuffer!.writeBuffer( &buf )
            
        case .end:
            self.state.requestComplete()
                        
            request.body = infoSavedBodyBuffer != nil ? Data(buffer: infoSavedBodyBuffer! ) : nil
            dispatch_request() { result, error, handler in
                if context.eventLoop.inEventLoop {
                    self.handle_response( result: result, error: error, context: context, handlerContext: handler )
                } else {
                    context.eventLoop.execute {
                        self.handle_response( result: result, error: error, context: context, handlerContext: handler )
                    }
                }
            }
        }
    }
    
    func handle_response( result: Any?, error:Error?, context: ChannelHandlerContext, handlerContext: RouterContext? )
    {
        self.buffer.clear()
        
        if let error = error {
            handle_error(error: error, context: context)
        }
        else {
            do {
                let value = try handlerContext?.responseBody( result ) ?? result
                switch value {
                case let d as Data  : self.buffer.writeData(d)
                case let s as String: self.buffer.writeString(s)
                case let arr as [Any]:
                    self.response.headers["Content-Type"] = "application/json"
                    let data = try MIOCoreJsonValue(withJSONObject: arr)
                    self.buffer.writeData(data)
                case let dic as [String:Any]:
                    self.response.headers["Content-Type"] = "application/json"
                    let data = try MIOCoreJsonValue(withJSONObject: dic)
                    self.buffer.writeData(data)
                default: break
                }
            }
            catch {
                handle_error( error: error, context: context )
            }
        }
        
        self.write_response( context: context, handlerContext: handlerContext )
        self.complete_response(context, trailers: nil, promise: nil)
        
        // Clean up
//        self.infoSavedBodyBytes = 0
//        self.infoSavedBodyBuffer = nil
    }
    
    // Method to handle errors
    private func handle_error(error:Error, context: ChannelHandlerContext)
    {
        response.status = .internalServerError
        
        if let err = error as? ServerErrorCodeProtocol {
            response.status = err.errorCode
        }
                
        self.buffer.writeString(error.localizedDescription)
    }

    // Helper method to write the response on the event loop thread
    private func write_response( context: ChannelHandlerContext, handlerContext: RouterContext? )
    {
        var responseHead = httpResponseHead(request: infoSavedRequestHead!, status: response!.status)
        
        for (k,v) in handlerContext?.extraResponseHeaders( ) ?? [:] {
            responseHead.headers.add(name: k, value: v)
        }
                
        for (k, v) in response!.headers {
            responseHead.headers.add(name: k, value: v)
        }
        
        // Update Content Length header
        responseHead.headers.add(name: "content-length", value: "\(self.buffer!.readableBytes)")
                    
        let head = HTTPServerResponsePart.head(responseHead)
        context.write(self.wrapOutboundOut(head), promise: nil)
        
        let content = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
        context.write(self.wrapOutboundOut(content), promise: nil)

//        context.flush()
    }
    
    private func complete_response(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        self.state.responseComplete()

        let promise = self.keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
        if !self.keepAlive {
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in context.close(promise: nil) }
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: promise)
    }



    func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    func handlerAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 0)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        switch event {
        case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
            // The remote peer half-closed the channel. At this time, any
            // outstanding response will now get the channel closed, and
            // if we are idle or waiting for a request body to finish we
            // will close the channel immediately.
            switch self.state {
            case .idle, .waitingForRequestBody: context.close(promise: nil)
            case .sendingResponse: self.keepAlive = false
            }
        default:
            context.fireUserInboundEventTriggered(event)
        }
    }
}


// Helper Extentions
extension String {
    func chopPrefix(_ prefix: String) -> String? {
        if self.unicodeScalars.starts(with: prefix.unicodeScalars) {
            return String(self[self.index(self.startIndex, offsetBy: prefix.count)...])
        } else {
            return nil
        }
    }
    
    func containsDotDot() -> Bool {
        for idx in self.indices {
            if self[idx] == "." && idx < self.index(before: self.endIndex) && self[self.index(after: idx)] == "." {
                return true
            }
        }
        return false
    }
}



private func httpResponseHead(request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()) -> HTTPResponseHead {
    var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
    let connectionHeaders: [String] = head.headers[canonicalForm: "connection"].map { $0.lowercased() }

    if !connectionHeaders.contains("keep-alive") && !connectionHeaders.contains("close") {
        // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers
        switch (request.isKeepAlive, request.version.major, request.version.minor) {
        case (true, 1, 0):
            // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
            head.headers.add( name: "Connection", value: "keep-alive" )
        case (false, 1, let n) where n >= 1:
            // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
            head.headers.add( name: "Connection", value: "close" )
        default:
            // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
            ()
        }
    }
    return head

}
