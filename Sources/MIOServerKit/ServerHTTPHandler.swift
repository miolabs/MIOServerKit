//
//  HTTPHandler.swift
//  
//
//  Created by Javier Segura Perez on 12/3/23.
//

import Foundation

import NIO
import NIOHTTP1
import NIOFoundationCompat
import MIOCore

class ServerHTTPHandler: ChannelInboundHandler
{
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
        
    private enum State
    {
        case idle
        case waitingForRequestBody
        case sendingResponse
        
        mutating func requestReceived() {
            precondition(self == .idle, "Invalid state for request received: \(self)")
            self = .waitingForRequestBody
        }

        mutating func requestComplete() {
            precondition(self == .waitingForRequestBody, "Invalid state for request complete: \(self)")
            self = .sendingResponse
        }

        mutating func responseComplete() {
            precondition(self == .sendingResponse, "Invalid state for response complete: \(self)")
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
    
    private let docsPath: String
    private let router: Router
    
    public init( router:Router, docsPath: String ) {
        self.router = router
        self.docsPath = docsPath
    }
    
    public func dispatchRequest ( ) throws {
        let path = request.url.relativePath
        var route_vars: RouterPathVars = [:]
        let method = EndpointMethod( rawValue: request!.method.rawValue )!

        let endpoint = router.root.match( method
                                 , RouterPath( path )
                                 , &route_vars )

        if endpoint != nil
        {
            request.parameters = route_vars
            let endpoint_spec = endpoint!.methods[ method ] as! Endpoint.MethodEndpoint<Any>
            try self.process( endpoint_spec.cb, route_vars, endpoint_spec.contextType( ) as! RouterContextProtocol.Type )
        }
        else
        {
            // TODO: respond: page not found
            response.status(.notFound)
            response.body = "NOT FOUND: \(method.rawValue) \(path)"
        }
    }

    open func process ( _ callback: EndpointRequestDispatcher<Any & RouterContextProtocol>, _ vars: RouterPathVars, _ contextType:RouterContextProtocol.Type ) throws {
        
        var ctx = contextType.init()
        ctx.request = request
        ctx.response = response
        
        try ctx.willExectute()
        
        let result = try callback( ctx )
                
        switch result {
        case let d as Data: self.buffer.writeData( d )
        case let s as String: self.buffer.writeString( s )
        case let arr as [Any]:
            response.headers["Content-Type"] = "application/json"
            let data = try MIOCoreJsonValue(withJSONObject: arr)
            self.buffer.writeData( data )
        case let dic as [String:Any]:
            response.headers["Content-Type"] = "application/json"
            let data = try MIOCoreJsonValue(withJSONObject: dic)
            self.buffer.writeData( data )
        default:break
        }
        
        try ctx.didExecute()
    }
           
    private func completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        self.state.responseComplete()

        let promise = self.keepAlive ? promise : (promise ?? context.eventLoop.makePromise())
        if !self.keepAlive {   
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in context.close(promise: nil) }
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: promise)
    }
        
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let http_request):
            self.keepAlive = http_request.isKeepAlive
            
            infoSavedRequestHead = http_request
            self.infoSavedBodyBytes = 0
            
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
            
            do {
                self.buffer.clear()
                
                request._body = infoSavedBodyBuffer != nil ? Data(buffer: infoSavedBodyBuffer! ) : nil
                try dispatchRequest( )
                
                var responseHead = httpResponseHead(request: infoSavedRequestHead!, status: response!.status )
                
                for (k, v) in response!.headers {
                    responseHead.headers.add( name: k, value: v )
                }
                
                // Update Content Length header
                responseHead.headers.add(name: "content-length", value: "\(self.buffer!.readableBytes)")
                                 
                let head = HTTPServerResponsePart.head( responseHead )
                context.write(self.wrapOutboundOut( head ), promise: nil)
                
                let content = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
                context.write(self.wrapOutboundOut(content), promise: nil)
            }
            catch {
                // TODO Error response
                self.buffer.clear()
                self.buffer.writeString( error.localizedDescription )
                
                var responseHead = httpResponseHead(request: infoSavedRequestHead!, status: .badRequest )
                responseHead.headers.add(name: "content-length", value: "\(self.buffer!.readableBytes)")
                
                let head = HTTPServerResponsePart.head( responseHead )
                context.write(self.wrapOutboundOut( head ), promise: nil)
                
                let content = HTTPServerResponsePart.body(.byteBuffer(buffer!.slice()))
                context.write(self.wrapOutboundOut(content), promise: nil)
            }
            
            self.completeResponse(context, trailers: nil, promise: nil)
        }
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
            case .idle, .waitingForRequestBody:
                context.close(promise: nil)
            case .sendingResponse:
                self.keepAlive = false
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
