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
import NIOWebSocket
import MIOCoreLogger
import MIOCore

open class NIOServer: Server
{
    let threadPool:NIOThreadPool
    let group:MultiThreadedEventLoopGroup
    let startedPromise = MultiThreadedEventLoopGroup(numberOfThreads: 1).next().makePromise(of: Void.self)

    var bootstrap: ServerBootstrap!
    var channel: Channel!

    /// Catalog of WebSocket endpoints + their connected clients. Public so
    /// application code and tests can drive broadcasts directly:
    /// `server.webSocketCatalog.SendTextToAll(uri, text)`. Empty if the
    /// server was constructed without `webSocketEndpoints` — in that case
    /// the upgrade handler refuses every WebSocket request and the HTTP
    /// path is unaffected.
    public let webSocketCatalog: ConnectedWebSocketCatalog

    // Pool occupancy tracking. Updated at sync-handler dispatch boundaries
    // in ServerHTTPHandler. Single shared instance across all connections so
    // /health can report server-wide pool state, not per-connection state.
    private let poolStatsLock = NSLock()
    private var _poolActive: Int = 0
    private var _poolPeak: Int = 0
    private var _poolTotalDispatched: UInt64 = 0
    private var _activeRequests: [UUID: (url: String, started: Date)] = [:]


    /// Default-empty `webSocketEndpoints` keeps every existing call site
    /// (`NIOServer(routes: r)`) source-compatible. The parent `Server`
    /// declares only `init(routes:)`; this designated init shadows it.
    public init ( routes: Router, webSocketEndpoints: [WebSocketEndpoint] = [] )
    {
        // Thread pool is usually tied to IO bound. Can be create more threads. Between 16 or 32 is a good balance
        let max_threads = MIOCoreIntValue( MCEnvironmentVar( "MIO_SERVER_KIT_MAX_THREADS"), 16 )!
        threadPool = NIOThreadPool(numberOfThreads: max_threads)
        // LoopGroup is tied to CPU bound so if better to keep to System.coreCount
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

        let catalog = ConnectedWebSocketCatalog()
        catalog.AddEndpoints( webSocketEndpoints )
        self.webSocketCatalog = catalog

        super.init(routes: routes)
    }
    
    open override func run ( port: Int )
    {
        Log.trace( "Starting NIO Server on port \(port). System coreCount: \(System.coreCount), thread pool: \(threadPool.numberOfThreads)")
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
    
    /// Name under which `ServerHTTPHandler` is registered in the channel
    /// pipeline. We need it by name so the WebSocket upgrade closure can
    /// find and remove it — a stale HTTP handler downstream of the WS
    /// frame decoder would crash on the first frame trying to unwrap it
    /// as `HTTPServerRequestPart`.
    private static let httpHandlerName = "MSK.ServerHTTPHandler"

    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        // Capture references locally so the upgrader closures (which run
        // on the channel's event loop) don't have to retain `self`.
        let catalog = self.webSocketCatalog

        let wsUpgrader = NIOWebSocketServerUpgrader(
            shouldUpgrade: { channel, head in
                // Only accept upgrades for URIs registered as WebSocket
                // endpoints. Returning `nil` aborts the upgrade — NIO then
                // continues the request through the HTTP pipeline, which
                // will respond with 404 from the regular router.
                if catalog.ContainsEndpoint( head.uri ) {
                    return channel.eventLoop.makeSucceededFuture( HTTPHeaders() )
                } else {
                    return channel.eventLoop.makeSucceededFuture( nil )
                }
            },
            upgradePipelineHandler: { channel, head in
                // Handshake succeeded. Three things have to happen, in order:
                //
                //   1. Remove the HTTP-side application handler. NIO's
                //      upgrade handler removes its own HTTP framing
                //      (encoder/decoder/upgrade handler) but knows nothing
                //      about ours. If we leave `ServerHTTPHandler` in
                //      place, the next inbound WebSocket frame reaches it
                //      and the precondition in `unwrapInboundIn` panics.
                //
                //   2. Register the new client with the catalog so
                //      broadcasts can find it.
                //
                //   3. Install `ServerWebSocketHandler` at the tail to
                //      consume frames.
                // The HTTP application handler does not speak WebSocket
                // frames; if left in place it will crash the next inbound
                // frame with a type mismatch. It conforms to
                // `RemovableChannelHandler` so this removal succeeds
                // synchronously on the event loop. Failure here is not
                // recoverable — propagate it so the channel closes.
                let removed = channel.pipeline.removeHandler( name: NIOServer.httpHandlerName )
                removed.whenFailure { error in
                    Log.error( "WS removeHandler(\(NIOServer.httpHandlerName)) failed: \(error)" )
                }
                return removed.flatMap {
                    let clientId = UUID().uuidString
                    guard let connection = catalog.AddClient(
                        head.uri, clientId, channel.allocator, channel
                    ) else {
                        Log.error( "WebSocket upgrade: bucket vanished for \(head.uri); closing" )
                        return channel.close()
                    }
                    return channel.pipeline.addHandler(
                        ServerWebSocketHandler( uri: head.uri, connection: connection, catalog: catalog )
                    )
                }
            }
        )

        let upgradeConfig: NIOHTTPServerUpgradeConfiguration = (
            upgraders: [ wsUpgrader ],
            completionHandler: { _ in
                // Once an upgrade succeeds NIO removes its own HTTP
                // handlers automatically. Our application handler is
                // removed by the upgradePipelineHandler closure above.
            }
        )

        return channel.pipeline.configureHTTPServerPipeline(
            withServerUpgrade: upgradeConfig,
            withErrorHandling: true
        ).flatMap {
            // The HTTP handler runs only on non-upgraded connections.
            // Named so the upgrade closure can locate and remove it.
            channel.pipeline.addHandler(
                ServerHTTPHandler( router: self.router, threadPool: self.threadPool, server: self ),
                name: NIOServer.httpHandlerName
            )
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

// Thread pool debug

extension NIOServer
{
    /// Increments the active-worker count. Call at the start of any dispatch
    /// path that occupies a NIOThreadPool worker (currently: .sync handlers).
    /// Returns the new active count for logging convenience.
    @discardableResult
    func poolStats_enter() -> Int {
        poolStatsLock.lock(); defer { poolStatsLock.unlock() }
        _poolActive += 1
        _poolTotalDispatched += 1
        if _poolActive > _poolPeak { _poolPeak = _poolActive }
        return _poolActive
    }

    /// Decrements the active-worker count. Must be paired with every
    /// poolStats_enter() call, including on error paths.
    func poolStats_exit() {
        poolStatsLock.lock(); defer { poolStatsLock.unlock() }
        _poolActive -= 1
    }

    /// Snapshot of current pool state. Safe to call from any thread.
    public struct PoolStats {
        public let active: Int             // workers running handler code right now
        public let peak: Int               // high-water mark since last reset
        public let totalDispatched: UInt64 // monotonic count of all dispatches ever
        public let configured: Int         // pool size from config
    }

    public func poolStats() -> PoolStats {
        poolStatsLock.lock(); defer { poolStatsLock.unlock() }
        return PoolStats(active: _poolActive,
                         peak: _poolPeak,
                         totalDispatched: _poolTotalDispatched,
                         configured: threadPool.numberOfThreads)
    }

    /// Resets the peak counter. Useful for periodic monitoring where you want
    /// to see "peak in the last N seconds" rather than peak-since-startup.
    public func poolStats_resetPeak() {
        poolStatsLock.lock(); defer { poolStatsLock.unlock() }
        _poolPeak = _poolActive   // reset to current active, not 0
    }
    
    func poolStats_enterWithRequest(url: String) -> UUID {
        let id = UUID()
        poolStatsLock.lock()
        _poolActive += 1
        _poolTotalDispatched &+= 1
        if _poolActive > _poolPeak { _poolPeak = _poolActive }
        _activeRequests[id] = (url: url, started: Date())
        poolStatsLock.unlock()
        return id
    }

    func poolStats_exitWithRequest(_ id: UUID) {
        poolStatsLock.lock()
        _poolActive -= 1
        _activeRequests.removeValue(forKey: id)
        poolStatsLock.unlock()
    }
    
    public struct ActiveRequest {
        public let url: String
        public let ageSeconds: Double
    }

    public func poolStats_inFlight() -> [ActiveRequest] {
        poolStatsLock.lock()
        defer { poolStatsLock.unlock() }
        let now = Date()
        return _activeRequests.values
            .map { ActiveRequest( url: $0.url
                                , ageSeconds: now.timeIntervalSince($0.started) ) }
            .sorted { $0.ageSeconds > $1.ageSeconds }
    }
}
