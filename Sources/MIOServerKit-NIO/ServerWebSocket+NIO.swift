

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import MIOServerKit


let websocketResponse = """
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <title>Swift NIO WebSocket Test Page</title>
        <script>
            var wsconnection = new WebSocket("ws://localhost:8888/websocket");
            wsconnection.onmessage = function (msg) {
                var element = document.createElement("p");
                element.innerHTML = msg.data;

                var textDiv = document.getElementById("websocket-stream");
                textDiv.insertBefore(element, null);
            };
        </script>
      </head>
      <body>
        <h1>WebSocket Stream</h1>
        <div id="websocket-stream"></div>
      </body>
    </html>
    """


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

// xxx quitar ringr de los tests!!
//open class NIOWebSocketServer<T : ConnectedWebSocket> : Server {  
open class NIOWebSocketServer : Server {   
    private var eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    //public var clients: [String:T] = [:]
    public var webSocketClients = ConnectedWebSocketCatalog()  // xxx cambiar a private?? hace falta por los tests?

    private var channel: NIOAsyncChannel<EventLoopFuture<UpgradeResult>, Never>!  // xxx convertir esto solo a channel y simplicar el terminarServer?
    let alreadyRunning = DispatchSemaphore(value: 0)

    private let responseBody = ByteBuffer(string: websocketResponse)

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

    // public func runAsync(port: Int) async throws {
    //     try await actualRun(port: port)
    // }
/*
     func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        //channel.eventLoop.makeCompletedFuture {
            print("En Make Completed Future")
            let upgrader = NIOTypedWebSocketServerUpgrader<UpgradeResult>(
                shouldUpgrade: { (channel, head) in
                    channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                },
                upgradePipelineHandler: { (channel, _) in
                    channel.eventLoop.makeCompletedFuture {
                        let asyncChannel = try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(wrappingChannelSynchronously: channel)
                        return UpgradeResult.websocket(asyncChannel)
                    }
                }
            )

            let serverUpgradeConfiguration = NIOTypedHTTPServerUpgradeConfiguration(
                upgraders: [upgrader],
                notUpgradingCompletionHandler: { channel in
                    channel.eventLoop.makeCompletedFuture {
                        try channel.pipeline.syncOperations.addHandler(HTTPByteBufferResponsePartHandler())
                        let asyncChannel = try NIOAsyncChannel<HTTPServerRequestPart, HTTPPart<HTTPResponseHead, ByteBuffer>>(wrappingChannelSynchronously: channel)
                        return UpgradeResult.notUpgraded(asyncChannel)
                    }
                }
            )

            let negotiationResultFuture = try channel.pipeline.syncOperations.configureUpgradableHTTPServerPipeline(
                configuration: .init(upgradeConfiguration: serverUpgradeConfiguration)
            )
            print("Fin Make Completed Future")
            return negotiationResultFuture
        //}
    }
*/
    /// This method starts the server and handles incoming connections.
    private func actualRun(port:Int ) async throws  {
        print("Starting server on 0.0.0.0:\(port)")
        channel = try await ServerBootstrap(
            group: self.eventLoopGroup
        )
        .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
        //.childChannelInitializer(childChannelInitializer(channel:))
        .bind( host: "0.0.0.0", port: port )
        //.wait()
        
         { channel in
            channel.eventLoop.makeCompletedFuture {
                print("En Make Completed Future")
                let upgrader = NIOTypedWebSocketServerUpgrader<UpgradeResult>(
                    shouldUpgrade: { channel, head in
                        // HTTPRequestHead
                        //print("shouldUgrade \(head.uri)")
                        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                        //channel.eventLoop.makeFailedFuture(NSError(domain:"com.m", code:100, userInfo: ["error":"shouldUpgrade"]))
                    },
                    upgradePipelineHandler: { channel, head in
                        channel.eventLoop.makeCompletedFuture {
                            let asyncChannel = try NIOAsyncChannel<WebSocketFrame, WebSocketFrame>(wrappingChannelSynchronously: channel)
                            return UpgradeResult.websocket(WebSocketChannelWithURI(asyncChannel, head.uri))
                        }
                    }
                )

                let serverUpgradeConfiguration = NIOTypedHTTPServerUpgradeConfiguration(
                    upgraders: [upgrader],
                    notUpgradingCompletionHandler: { channel in
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
                print("Fin Make Completed Future")
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
        print("Antes del task group")
        try await withThrowingDiscardingTaskGroup { group in
            print("Dentro del task group 1")
            try await channel.executeThenClose { inbound in
                print("Dentro del task group 2")
                for try await upgradeResult in inbound {
                    print("Dentro del task group 3")
                    group.addTask {
                        print("Dentro del task group 4")
                        await self.handleUpgradeResult(upgradeResult)
                        print("Dentro del task group 5")
                    }
                }
            }
        }
        print("Despues del task group")
        /*
         var taskGroup = [Task<Void, Never>]()

    // Ejecuta la operación en paralelo
    let inbound = try await channel.executeThenClose()

    for try await upgradeResult in inbound {
        // Crea y añade la tarea para cada resultado
        let task = Task {
            await self.handleUpgradeResult(upgradeResult)
        }
        taskGroup.append(task)  // Guardamos la tarea en el grupo
    }

    // Espera a que todas las tareas se completen
    for task in taskGroup {
        await task.value  // Espera a que cada tarea termine
    }
         */

    }

    /// This method handles a single connection by echoing back all inbound data.
    private func handleUpgradeResult(_ upgradeResult: EventLoopFuture<UpgradeResult>) async {
        // Note that this method is non-throwing and we are catching any error.
        // We do this since we don't want to tear down the whole server when a single connection
        // encounters an error.
        do {
            print("**handleUpgradeResult ")
            switch try await upgradeResult.get() {
            case .websocket(let websocketChannel):
                print("Handling websocket connection")
                try await self.handleWebsocketChannel(websocketChannel)
                print("Done handling websocket connection")
            case .notUpgraded(let httpChannel):
                print("Handling HTTP connection")
                //try await self.handleHTTPChannel(httpChannel)
                try httpChannel.channel.closeFuture.wait()
                print("Done handling HTTP connection")
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
                print("handlewebsocket ---- 1")
                if newClient != nil {
                    print("handlewebsocket ---- 2")
                    group.addTask {
                        for try await frame in inbound {
                            let closeConnection = try await newClient!.gotFrame(frame)
                            if closeConnection {
                                return
                            }
                        }
                    }
                    try await group.next() 
                    print("handlewebsocket ---- 3")
                    group.cancelAll()  
                    //self.clients[newClientId] = nil  // xxx
                    webSocketClients.RemoveClient(channel.uri, newClientId)
                }   
                print("handlewebsocket ---- 4")
            }
        }
    }

   private func handleHTTPChannel(
        _ channel: NIOAsyncChannel<HTTPServerRequestPart, HTTPPart<HTTPResponseHead, ByteBuffer>>
    ) async throws {
print("xxxxxxx  1")        
        try await channel.executeThenClose { inbound, outbound in
print("xxxxxxx  2")       
            for try await requestPart in inbound {
print("xxxxxxx  3")                

                // We're not interested in request bodies here: we're just serving up GET responses
                // to get the client to initiate a websocket request.
                guard case .head(let head) = requestPart else {
                    return
                }
print("head.method: \(head.method), head.uri: \(head.uri)")
                // GETs only.
                guard case .GET = head.method else {
                    try await self.respond405(writer: outbound)
                    return
                }
print("xxxxxxx  3a") 
                var headers = HTTPHeaders()
                headers.add(name: "Content-Type", value: "text/html")
                headers.add(name: "Content-Length", value: String(responseBody.readableBytes))
                headers.add(name: "Connection", value: "close")
                let responseHead = HTTPResponseHead(
                    version: .init(major: 1, minor: 1),
                    status: .ok,
                    headers: headers
                )
print("xxxxxxx  4")
                try await outbound.write(
                    contentsOf: [
                        .head(responseHead),
                        .body(responseBody),
                        .end(nil),
                    ]
                )
print("xxxxxxx  5")             
            }
          }
    }

    private func respond405(writer: NIOAsyncChannelOutboundWriter<HTTPPart<HTTPResponseHead, ByteBuffer>>) async throws
    {
        var headers = HTTPHeaders()
        headers.add(name: "Connection", value: "close")
        headers.add(name: "Content-Length", value: "0")
        let head = HTTPResponseHead(
            version: .http1_1,
            status: .methodNotAllowed,
            headers: headers
        )

        try await writer.write(
            contentsOf: [
                .head(head),
                .end(nil),
            ]
        )
    }
}

final class HTTPByteBufferResponsePartHandler: ChannelOutboundHandler {
    typealias OutboundIn = HTTPPart<HTTPResponseHead, ByteBuffer>
    typealias OutboundOut = HTTPServerResponsePart

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let part = Self.unwrapOutboundIn(data)
        switch part {
        case .head(let head):
            context.write(Self.wrapOutboundOut(.head(head)), promise: promise)
        case .body(let buffer):
            context.write(Self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: promise)
        case .end(let trailers):
            context.write(Self.wrapOutboundOut(.end(trailers)), promise: promise)
        }
    }
}







