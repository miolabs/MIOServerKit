//
//  File.swift
//  
//
//  Created by David Trallero on 20/10/21.
//

import Foundation

import NIOCore
import NIOPosix
import NIOHTTP1

public let asUUID = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

open class MSKServer<T>: MSKRouter<T> {

    // MARK: Initializer
    
    /// Initialize a `MIORouter` instance.
    /// ### Usage Example: ###
    /// ```swift
    ///  let router = MIORouter()
    /// ```
    public override init() {        
        super.init( )

//        func dispatch ( ) -> RouterHandler {
//          return { (request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws -> Void in
//              self.dispatchRequest( MSKRouterRequest( request ), MSKRouterResponse( response ) )
//          }
//        }

        // Setting up CORS
//        let options = Options(allowedOrigin: .all, methods: ["GET", "POST"], maxAge: 5)
//        let cors = CORS(options: options)

//        kituraRouter.all(middleware: cors)
//        kituraRouter.post(middleware: BodyParser())
//        kituraRouter.put(middleware: BodyParser())

        
//        kituraRouter.get(     "*", handler: dispatch( ) )
//        kituraRouter.post(    "*", handler: dispatch( ) )
//        kituraRouter.delete(  "*", handler: dispatch( ) )
//        kituraRouter.put(     "*", handler: dispatch( ) )
//        kituraRouter.patch(   "*", handler: dispatch( ) )
//        kituraRouter.options( "*", handler: dispatch( ) )

        
//        Log.verbose("MSKRouter initialized")
    }


    deinit {
        try! group.syncShutdownGracefully()
    }
 
    public func dispatchRequest ( _ request: MSKRouterRequest, _ response: MSKRouterResponse ) {
        let path = request.url.relativePath
        var route_vars: RouterPathVars = [:]
        let method = EndpointMethod( rawValue: request.method.rawValue )!

        let endpoint = root.match( method
                                 , RouterPath( path )
                                 , &route_vars )
        
        if endpoint != nil {
            request.parameters = route_vars
            self.process( endpoint!.methods[ method ]!.cb, route_vars, request, response )
        } else {
            // TODO: respond: page not found
            response.status(.notFound)
            response.send( data: "NOT FOUND: \(method.rawValue) \(path)".data(using: .utf8)! )
        }
    }

    open func process ( _ callback: EndpoingRequestDispatcher<T>, _ vars: RouterPathVars, _ request: MSKRouterRequest, _ response: MSKRouterResponse ) { }
    
    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler( MSKHTTPHandler() )
        }
    }
    
    let group = MultiThreadedEventLoopGroup( numberOfThreads: System.coreCount )
    var allowHalfClosure = true
                
    var serverBootstrap: ServerBootstrap {
        return ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption( ChannelOptions.backlog, value: 256 )
            .serverChannelOption( ChannelOptions.socketOption( .so_reuseaddr ), value: 1 )
        
            // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer( childChannelInitializer(channel:) )
                    
            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption( ChannelOptions.socketOption( .so_reuseaddr ), value: 1 )
            .childChannelOption( ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption( ChannelOptions.allowRemoteHalfClosure, value: allowHalfClosure )
    }

    public func run ( host:String = "localhost", port:Int ) throws {
        
        let channel = try serverBootstrap.bind(host: host, port: port).wait()
                
        guard let localAddress = channel.localAddress else {
            fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
        }
        
        print("Server started and listening on \(localAddress)")
        
        // This will never unblock as we don't close the ServerChannel
        try? channel.closeFuture.wait()

        print("Server closed")
    }
}
