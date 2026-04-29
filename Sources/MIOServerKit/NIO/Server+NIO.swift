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
import MIOCore

open class NIOServer: Server
{
    let threadPool:NIOThreadPool
    let group:MultiThreadedEventLoopGroup
    let startedPromise = MultiThreadedEventLoopGroup(numberOfThreads: 1).next().makePromise(of: Void.self)
    
    var bootstrap: ServerBootstrap!
    var channel: Channel!
        
    // Pool occupancy tracking. Updated at sync-handler dispatch boundaries
    // in ServerHTTPHandler. Single shared instance across all connections so
    // /health can report server-wide pool state, not per-connection state.
    private let poolStatsLock = NSLock()
    private var _poolActive: Int = 0
    private var _poolPeak: Int = 0
    private var _poolTotalDispatched: Int = 0
    private var _activeRequests: [UUID: (url: String, started: Date)] = [:]

    
    public override init(routes: Router)
    {
        // Thread pool is usually tied to IO bound. Can be create more threads. Between 16 or 32 is a good balance
        let max_threads = MIOCoreIntValue( MCEnvironmentVar( "MIO_SERVER_KIT_MAX_THREADS"), 16 )!
        threadPool = NIOThreadPool(numberOfThreads: max_threads)
        // LoopGroup is tied to CPU bound so if better to keep to System.coreCount
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
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
    
    func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
        return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
            channel.pipeline.addHandler( ServerHTTPHandler( router: self.router, threadPool: self.threadPool, server: self ) )
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
        public let active: Int           // workers running handler code right now
        public let peak: Int             // high-water mark since last reset
        public let totalDispatched: Int  // monotonic count of all dispatches ever
        public let configured: Int       // pool size from config
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
        _poolTotalDispatched += 1
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
