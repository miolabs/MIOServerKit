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
import MIOCoreLogger


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
    
    private var idleTimeout: Scheduled<Void>?
    private let idleTimeoutDuration: TimeAmount = .seconds(60)
    
    private var requestCount = 0
    private let maxRequestsPerConnection = 100
    
    var request:RouterRequest!
    var response:RouterResponse!
        
    private let router: Router
    private let threadPool: NIOThreadPool

    public init(router: Router, threadPool: NIOThreadPool) {
        self.router = router
        self.threadPool = threadPool
    }
    
    deinit {
        Log.debug("ServerHTTPHandler deinit")
    }
    
    func handlerAdded(context: ChannelHandlerContext) {
        self.buffer = context.channel.allocator.buffer(capacity: 0)
        scheduleIdleTimeout(context: context)
        Log.debug("handlerAdded")
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        cancelIdleTimeout()
        Log.debug("handlerRemoved")
    }
    
    func channelInactive(context: ChannelHandlerContext) {
        cancelIdleTimeout()
        Log.debug("channelInactive")
        context.fireChannelInactive()
    }
    
    private func dispatch_request( _ context: ChannelHandlerContext, completion: @escaping MethodEndpointCompletionBlock )
    {
        let path = request.url.relativePath
        var route_vars: RouterPathVars = [:]
        let method = EndpointMethod( rawValue: request!.method.rawValue )!

        Log.debug( "Endpoint: \(method.rawValue) \(path)" )
        Log.trace( "Headers: \(request.headers)" )
        
        let endpoint = router.root.match( RouterPath( path ), &route_vars )
        
        if endpoint == nil {
            completion( nil, ServerError.endpointNotFound( path, method.rawValue ) )
            return
        }

        // TODO: Make a cors plugin so this can be setup externally
        response.headers.add(name: .accessControlAllowOrigin, value: "*")
        response.headers.add(name: .accessControlAllowMethods, value: "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD" )
        response.headers.add(name: .accessControlMaxAge, value: "5" )
        response.headers.add(name: .vary, value: "Origin" )
        
        let values = request.headers[ .accessControlRequestHeaders ].isEmpty ? ["Context-Type"] : request.headers[ .accessControlRequestHeaders ]
        response.headers.add(name: .accessControlAllowHeaders, value: values.joined(separator: ",") )
        
        if method == .OPTIONS {
            response.status(.noContent)
            response.headers.add(name: .allow, value: Array( endpoint!.methods.keys ).map(\.rawValue).joined(separator: ", ") + ", HEAD" )
            completion(nil, nil)
        }
        else if method == .HEAD {
            response.status(.ok)
            completion(nil, nil)
        }
        else if endpoint!.methods[ method ] != nil {
            request.parameters = route_vars
            let loop = context.eventLoop
            let endpoint_spec = endpoint!.methods[ method ]!
            
            let req = self.request!
            let res = self.response!
            
            switch endpoint_spec.executionType {
            case .sync:
                // Offload sync endpoints to the thread pool.
                Log.trace("Starting sync endpoint")
                threadPool.runIfActive(eventLoop: loop) { () -> Void in
                    Log.trace("Thread pool work starting")
                    endpoint_spec.run(req, res) { result, error in
                        Log.trace("Endpoint completed")
                        // Always hop back to the channel's event loop before touching NIO.
                        loop.execute {
                            completion(result, error)
                        }
                    }
                }
                .whenFailure { error in
                    Log.trace("Endpoint fail")
                    loop.execute {
                        completion(nil, error)
                    }
                }
            
            case .async:
                threadPool.runIfActive(eventLoop: loop) { () -> Void in
                    let semaphore = DispatchSemaphore(value: 0)
                    var capturedResult: (Any?, Error?)?
                    
                    Task {
                        await endpoint_spec.run(req, res) { result, error in
                            capturedResult = (result, error)
                            semaphore.signal()
                        }
                    }
                    
                    semaphore.wait()
                    
                    if let (result, error) = capturedResult {
                        loop.execute {
                            completion(result, error)
                        }
                    }
                }
                .whenFailure { error in
                    loop.execute {
                        completion(nil, error)
                    }
                }
            }
        }
        else {
            completion( nil, ServerError.endpointNotFound( path, method.rawValue ) )
        }
    }
                   
    func channelRead(context: ChannelHandlerContext, data: NIOAny) 
    {
        cancelIdleTimeout()
        
        let reqPart = self.unwrapInboundIn(data)
        
        switch reqPart {
        case .head(let http_request):
            self.keepAlive = http_request.isKeepAlive
            self.requestCount += 1
                                                
            if self.requestCount >= self.maxRequestsPerConnection {
                self.keepAlive = false
            }
            
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
            dispatch_request( context ) { [weak self] result, error in
                guard let self = self else { return }
                if context.eventLoop.inEventLoop {
                    self.handle_response( result: result, error: error, context: context )
                } else {
                    context.eventLoop.execute { [weak self] in
                        guard let self = self else { return }
                        self.handle_response( result: result, error: error, context: context )
                    }
                }
            }
        }
    }
    
    func handle_response( result: Any?, error:Error?, context: ChannelHandlerContext )
    {
        self.buffer.clear()
        
        if let error = error {
            handle_error(error: error, context: context)
        }
        else {
            do {
                switch result {
                case let d as Data  : self.buffer.writeData(d)
                case let s as String: self.buffer.writeString(s)
                case let arr as [Any]:
                    self.response.headers.add(name: .contentType, value: "application/json" )
                    let data = try MIOCoreJsonValue(withJSONObject: arr)
                    self.buffer.writeData(data)
                case let dic as [String:Any]:
                    self.response.headers.add(name: .contentType, value: "application/json" )
                    let data = try MIOCoreJsonValue(withJSONObject: dic)
                    self.buffer.writeData(data)
                default: break
                }
            }
            catch {
                handle_error( error: error, context: context )
            }
        }
        
        self.write_response( context: context )
        self.complete_response(context, trailers: nil, promise: nil)
        if self.keepAlive {
            scheduleIdleTimeout(context: context)
        }
        
        // Clean up
        self.infoSavedRequestHead = nil
        self.infoSavedBodyBuffer = nil
        self.infoSavedBodyBytes = 0
        self.request = nil
        self.response = nil
        self.buffer.clear()
    }
    
    // Method to handle errors
    private func handle_error(error:Error, context: ChannelHandlerContext)
    {
        Log.debug( "\(error)" )
        
        if let err = error as? ServerErrorProtocol {
            response.headers.replaceOrAdd(name: .contentType, value: err.contentType)
            response.status = err.errorCode
            self.buffer.writeData(err.body)
        }
        else {
            response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
            response.status = .internalServerError
            let msg = "Internal Server Error: \(error)"
            let data = msg.data(using: .utf8)!
            self.buffer.writeData(data)
        }
    }

    // Helper method to write the response on the event loop thread
    private func write_response( context: ChannelHandlerContext )
    {
        var responseHead = httpResponseHead(request: infoSavedRequestHead!, status: response.status)
                        
        for (k, v) in response.headers {
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

    private func scheduleIdleTimeout(context: ChannelHandlerContext) {
        idleTimeout = context.eventLoop.scheduleTask(in: idleTimeoutDuration) {
            Log.debug("Connection idle timeout, closing")
            context.close(promise: nil)
        }
    }
    
    private func cancelIdleTimeout() {
        idleTimeout?.cancel()
        idleTimeout = nil
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
