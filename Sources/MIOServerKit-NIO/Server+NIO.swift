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
import MIOServerKit

open class NIOServer : Server
{        
    deinit {
        try! group.syncShutdownGracefully()
    }
  
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
    var bootstrap: ServerBootstrap!
    
    open override func run ( port:Int )
    {
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
            let channel = try bootstrap.bind( host: "0.0.0.0", port: port ).wait()

            guard let channelLocalAddress = channel.localAddress else {
                fatalError("Address was unable to bind. Please check that the socket was not closed or that the address family was understood.")
               }
            
            print("Server started and listening on \(channelLocalAddress), htdocs path \(documentsPath)")

            // This will never unblock as we don't close the ServerChannel
            try channel.closeFuture.wait()
        } catch {
            
        }
    }
    
    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler( ServerHTTPHandler( router: self.router, docsPath: self.documentsPath ) )
        }
    }
}
