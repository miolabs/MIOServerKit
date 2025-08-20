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
    deinit {
        try! group.syncShutdownGracefully()
    }
  
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    var bootstrap: ServerBootstrap!
    var channel: Channel!
    var alreadyRunning = DispatchSemaphore(value: 0)
    
    open override func run ( port: Int )
    {
        super.run( port: port )
        
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
            alreadyRunning.signal()
            // This will never unblock until terminateServer() is called
            try channel.closeFuture.wait()
        } catch {
            Log.critical("\(error)")
            fatalError("\(error)")
        }
    }
    
    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler( ServerHTTPHandler( router: self.router ) )
        }
    }
    
    public func waitForServerRunning(timeoutSeconds:Int = 5 ) -> Bool {
        if alreadyRunning.wait(timeout: .now() + .seconds(timeoutSeconds)) == .timedOut {
            Log.warning("Timeout waiting for Server to start.")
            return false
        }
        return true
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
