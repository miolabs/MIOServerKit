//
//  MSKHTTPHandler.swift
//  
//
//  Created by Javier Segura Perez on 19/1/23.
//

import NIOCore
import NIOPosix
import NIOHTTP1
//import NIOFoundationCompat

final class MSKHTTPHandler: ChannelInboundHandler
{
    public typealias InboundIn = HTTPServerRequestPart
    public typealias OutboundOut = HTTPServerResponsePart
    
    private enum State {
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
    
    
    private var requestHead: HTTPRequestHead?
    private var bodyBytes: Int = 0
    
    public init() {}
    
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny)
    {
        let reqPart = self.unwrapInboundIn(data)
        //        if let handler = self.handler {
        //            handler(context, reqPart)
        //            return
        //        }
        
        switch reqPart {
        case .head(let request):
            self.requestHead = request
            self.bodyBytes = 0
            self.keepAlive = request.isKeepAlive
            self.state.requestReceived()
            self.buffer.clear()
            
        case .body( buffer: var buf ):
            self.buffer.writeBuffer( &buf )
            // TODO: Parse body if necessary data with the information from header
            
        case .end:
            self.state.requestComplete()
            let request = MSKRouterRequest( requestHead!, body: buffer )
            let response = MSKRouterResponse( context: context )
            
            let content = HTTPServerResponsePart.body( .byteBuffer( buffer!.slice() ) )
            context.write( self.wrapOutboundOut(content), promise: nil )
            self.completeResponse( context, trailers: nil, promise: nil )
        }
    }
        
            
    func completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        self.state.responseComplete()

        let promise = self.keepAlive ? promise : ( promise ?? context.eventLoop.makePromise() )
        if !self.keepAlive {
            promise!.futureResult.whenComplete { (_: Result<Void, Error>) in context.close( promise: nil ) }
        }
        
//        self.handler = nil

        context.writeAndFlush( self.wrapOutboundOut(.end(trailers)), promise: promise )
    }

    
    func channelReadComplete(context: ChannelHandlerContext)
    {
        context.flush()
    }
    
    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any)
    {
        switch event
        {
            case let evt as ChannelEvent where evt == ChannelEvent.inputClosed:
                // The remote peer half-closed the channel. At this time, any
                // outstanding response will now get the channel closed, and
                // if we are idle or waiting for a request body to finish we
                // will close the channel immediately.
                switch self.state
                {
                    case .idle,
                         .waitingForRequestBody: context.close(promise: nil)
                    
                    case .sendingResponse: self.keepAlive = false
                }
            default:
                context.fireUserInboundEventTriggered(event)
        }
    }
    
}
