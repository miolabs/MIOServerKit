//
//  Server.swift
//
//
//  Created by David Trallero on 20/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation

import NIO
import NIOHTTP1
import MIOCoreLogger

open class NIOServer: Server
{
    let threadPool = NIOThreadPool(numberOfThreads: System.coreCount)
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let startedPromise = MultiThreadedEventLoopGroup(numberOfThreads: 1).next().makePromise(of: Void.self)
    
    var bootstrap: ServerBootstrap!
    var channel: Channel!
    
    open override func run ( port: Int )
    {
        super.run( port: port )
        threadPool.start()
        
        bootstrap = ServerBootstrap(group: group)
        // Specify backlog and enable SO_REUSEADDR for the server itself
        .serverChannelOption(ChannelOptions.backlog, value: 256)
        .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        // Set the handlers that are applied to the accepted Channels
        .childChannelInitializer(childChannelInitializer(channel:))

        // Enable SO_REUSEADDR for the accepted Channels
        .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
        .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true )
        
        do {
//            let channel = try bootstrap.bind( host: "127.0.0.1", port: port ).wait()
            channel = try bootstrap.bind( host: "0.0.0.0", port: port ).wait()

            guard let channelLocalAddress = channel.localAddress else {
                Log.critical("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
                fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
            }
                        
            Log.info( "Server started and listening on \(channelLocalAddress)" )
            
            // ✅ announce “server is ready”
            startedPromise.succeed(())
            
            // This will never unblock until terminateServer() is called
            try channel.closeFuture.wait()
            
            shutdown()
        } catch {
            Log.critical("\(error)")
            shutdown()
        }
    }
    
    private func shutdown() {
        threadPool.shutdownGracefully { error in
            if let error = error { Log.error("ThreadPool shutdown error: \(error)") }
        }
        group.shutdownGracefully { error in
            if let error = error { Log.error("EventLoopGroup shutdown error: \(error)") }
        }
    }
    
    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler( ServerHTTPHandler( router: self.router, threadPool: self.threadPool ) )
        }
    }
    
    public func waitForServerRunning(timeoutSeconds:Int = 5 ) -> Bool {
        precondition(!group.next().inEventLoop, "Do not block an EventLoop thread")
        let loop = group.next()

       // Race: started → true, timeout → false
       let result = loop.makePromise(of: Bool.self)

       startedPromise.futureResult.whenComplete { _ in
           result.succeed(true)
       }

       let timeout = loop.scheduleTask(in: .seconds(Int64(timeoutSeconds))) {
           result.succeed(true)
       }

       do {
           let ok = try result.futureResult.wait()
           timeout.cancel() // best effort
           if !ok { Log.warning("Timeout waiting for Server to start.") }
           return ok
       } catch {
           timeout.cancel()
           Log.warning("Error waiting for Server to start: \(error)")
           return false
       }
    }
    
    public func terminateServer() throws {
        do {
            try channel?.close().wait()
            //try group?.syncShutdownGracefully()
            Log.warning("Server terminated.")
        } catch {
            Log.error("Error terminating server: \(error)")
        }
    }
}
