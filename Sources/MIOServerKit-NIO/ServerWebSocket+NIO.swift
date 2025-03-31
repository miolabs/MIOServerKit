
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import MIOServerKit


class WebSocketChannelWithURI {
    var channel: NIOAsyncChannel<WebSocketFrame, WebSocketFrame>
    var uri: String

    init(_ channel: NIOAsyncChannel<WebSocketFrame, WebSocketFrame>, _ uri: String) {
        self.channel = channel
        self.uri = uri
    }
}

enum UpgradeResult {
        //case websocket(NIOAsyncChannel<WebSocketFrame, WebSocketFrame>)
        case websocket(WebSocketChannelWithURI)
        case notUpgraded(NIOAsyncChannel<HTTPServerRequestPart, HTTPPart<HTTPResponseHead, ByteBuffer>>)
    }

open class NIOWebSocketServer : Server {   
    private var eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    public var webSocketClients = ConnectedWebSocketCatalog() 

    private var channel: NIOAsyncChannel<EventLoopFuture<UpgradeResult>, Never>!  
    let alreadyRunning = DispatchSemaphore(value: 0)


    deinit {
        try! eventLoopGroup.syncShutdownGracefully()
    }

    public init( routes: Router, settings: [String:Any]? = nil, webSocketEndpoints: [WebSocketEndpoint] = [] )
    {
        super.init(routes: routes, settings: settings)
        webSocketClients.AddEndpoints(webSocketEndpoints)   
    }
    
    public func waitForServerRunning(timeoutSeconds:Int = 5 ) -> Bool {
        if alreadyRunning.wait(timeout: .now() + .seconds(timeoutSeconds)) == .timedOut {
            print("Timeout waiting for Server to start.")
            return false
        }
        return true
    }

    public func terminateServer() throws {
        do {
            try channel.channel.close().wait()
        } catch {
            print("Error terminating server: \(error)")
        }
    }

    open override func run ( port:Int )
    {
        super.run(port: port)
        try? runAndWait(port: port)
    }

    private func runAndWait(port:Int ) throws {
        let semaphore = DispatchSemaphore(value: 0)
        Task.detached {
            try await self.actualRun(port: port)
            semaphore.signal()
        }
        semaphore.wait()
    }

     /// This method starts the server and handles incoming connections.
    private func actualRun(port:Int ) async throws  {
        print("Starting server on 0.0.0.0:\(port)")
        channel = try await ServerBootstrap(
            group: self.eventLoopGroup
        )
        .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
        .bind( host: "0.0.0.0", port: port ) { channel in
            // this happens when a new connection is accepted
            channel.eventLoop.makeCompletedFuture {
                let upgrader = NIOTypedWebSocketServerUpgrader<UpgradeResult>(
                    shouldUpgrade: { channel, requestHead in  // decide if a connection can be upgraded to websocket
                        if self.webSocketClients.ContainsEndpoint(requestHead.uri) {
                            return channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                        } else {
                            let responseHead = HTTPResponseHead(version: requestHead.version, status: .forbidden)
                            let response = HTTPServerResponsePart.head(responseHead)

                            return channel.writeAndFlush(response).flatMap {
                                channel.close()
                            }.flatMap {
                                channel.eventLoop.makeSucceededFuture(nil) // Indica que el upgrade NO se realiza
                            }
                            //return channel.eventLoop.makeSucceededFuture(nil)
                            //return channel.eventLoop.makeFailedFuture(NSError(domain:"com.m", code:100, userInfo: ["error":"shouldUpgrade"]))
                        }
                    },
                    upgradePipelineHandler: { channel, head in   // attend websocket connection
                        channel.eventLoop.makeCompletedFuture {
                            let asyncChannel = try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(wrappingChannelSynchronously: channel)
                            return UpgradeResult.websocket(WebSocketChannelWithURI(asyncChannel, head.uri))
                        }
                    }
                )

                let serverUpgradeConfiguration = NIOTypedHTTPServerUpgradeConfiguration(
                    upgraders: [upgrader], // attend to upgrade requests
                    notUpgradingCompletionHandler: { channel in   // attend regular http calls
                        channel.eventLoop.makeCompletedFuture {
                            //try channel.pipeline.syncOperations.addHandler(HTTPByteBufferResponsePartHandler())
                            try channel.pipeline.syncOperations.addHandler(ServerHTTPHandler( router: self.router, settings: self.settings ))
                            let asyncChannel = try NIOAsyncChannel<HTTPServerRequestPart, HTTPPart<HTTPResponseHead, ByteBuffer>>(wrappingChannelSynchronously: channel)
                            return UpgradeResult.notUpgraded(asyncChannel)
                        }
                    }
                )

                let negotiationResultFuture = try channel.pipeline.syncOperations.configureUpgradableHTTPServerPipeline(
                    configuration: .init(upgradeConfiguration: serverUpgradeConfiguration)
                )
                return negotiationResultFuture
            }
        }
        

        alreadyRunning.signal()

        // We are handling each incoming connection in a separate child task. It is important
        // to use a discarding task group here which automatically discards finished child tasks.
        // A normal task group retains all child tasks and their outputs in memory until they are
        // consumed by iterating the group or by exiting the group. Since, we are never consuming
        // the results of the group we need the group to automatically discard them; otherwise, this
        // would result in a memory leak over time.
        try await withThrowingDiscardingTaskGroup { group in
            try await channel.executeThenClose { inbound in
                // thread waits here for connections
                for try await upgradeResult in inbound {
                    group.addTask {
                        // new task to process the connection (one task per client, probably not ideal)
                        await self.handleUpgradeResult(upgradeResult)
                        // connection closed
                    }
                }
            }
        }
     }

    /// This method handles a single connection by echoing back all inbound data.
    private func handleUpgradeResult(_ upgradeResult: EventLoopFuture<UpgradeResult>) async {
        // Note that this method is non-throwing and we are catching any error.
        // We do this since we don't want to tear down the whole server when a single connection
        // encounters an error.
        do {
            switch try await upgradeResult.get() {
            case .websocket(let websocketChannel):
                try await self.handleWebsocketChannel(websocketChannel)
            case .notUpgraded(let httpChannel):
                try httpChannel.channel.closeFuture.wait()
            }
        } catch {
            print("Hit error: \(error)")
        }
    }

    //private func handleWebsocketChannel(_ channel: NIOAsyncChannel<WebSocketFrame, WebSocketFrame>) async throws {
    private func handleWebsocketChannel(_ channel: WebSocketChannelWithURI) async throws {
        try await channel.channel.executeThenClose { inbound, outbound in
            try await withThrowingTaskGroup(of: Void.self) { group in
                let newClientId = UUID().uuidString
                //let newClient = ConnectedWebSocket.New(ConnectedWebSocket.self, newClientId, channel.channel.channel.allocator, inbound, outbound)
                let newClient = webSocketClients.AddClient(channel.uri, newClientId, channel.channel.channel.allocator, inbound, outbound)
                if newClient != nil {
                    group.addTask {
                        for try await frame in inbound {
                            let closeConnection = try await newClient!.gotFrame(frame)
                            if closeConnection {
                                return
                            }
                        }
                    }
                    try await group.next() 
                    group.cancelAll()  
                    webSocketClients.RemoveClient(channel.uri, newClientId)
                }   
            }
        }
    }



 }







