//
//  MIOServerKitStressTests.swift
//
//  Stress tests for the NIO-backed server. The goal is to push the server
//  hard enough to surface thread-creation / thread-pool problems without
//  turning into a full-blown load test:
//
//    - Burst many concurrent connections to stress accept + handler init.
//    - Saturate the NIOThreadPool with blocking sync work to force
//      backpressure on the work queue (default pool size is 16, see
//      MIO_SERVER_KIT_MAX_THREADS).
//    - Drive the async-endpoint path, which blocks a thread-pool worker
//      on a DispatchSemaphore while a Task runs (the most fragile path).
//    - Run sustained traffic in rounds to catch thread / fd leaks.
//    - Force per-request connection churn (Connection: close) so the
//      ServerHTTPHandler init/deinit path runs on every call.
//
//  All counts are tunable at the top of the test class. They are sized
//  to run in CI in ~1 minute on a developer machine. Push them up if
//  you want to investigate a specific suspicion.
//
//  Reuses launchServerHttp(_:) from MIOServerKitNIOTests.swift.
//
//  Created by Javier Segura Perez.
//

@testable import MIOServerKit
import XCTest
import Foundation


#if !os(macOS)
extension MIOServerKitStressTests {
    static var allTests = [
        ( "testStress_HighConcurrencyFastRequests",                testStress_HighConcurrencyFastRequests ),
        ( "testStress_SlowEndpointThreadPoolSaturation",           testStress_SlowEndpointThreadPoolSaturation ),
        ( "testStress_SustainedLoad",                              testStress_SustainedLoad ),
        ( "testStress_AsyncEndpointsUnderLoad",                    testStress_AsyncEndpointsUnderLoad ),
        ( "testStress_MixedSyncAsyncEndpoints",                    testStress_MixedSyncAsyncEndpoints ),
        ( "testStress_ConnectionChurn",                            testStress_ConnectionChurn ),
        ( "testStress_StuckAsyncHandlers_DoNotPinThreadPoolWorkers", testStress_StuckAsyncHandlers_DoNotPinThreadPoolWorkers ),
        ( "testStress_StuckSyncHandlers_DoNotBlockSystemEndpoint",  testStress_StuckSyncHandlers_DoNotBlockSystemEndpoint ),
        ( "testStress_StuckHandlers_ServerStaysResponsive",        testStress_StuckHandlers_ServerStaysResponsive ),
    ]
}
#endif


// MARK: - Endpoint handlers

/// Returns immediately. Stresses dispatch path without holding a worker.
fileprivate func stressFastHandler( context: RouterContext ) throws -> [String:Any] {
    return [ "ok": true ]
}

/// Configurable blocking sleep on a thread-pool worker. Lets us force
/// backpressure on the pool by combining with high concurrency.
fileprivate let stressSlowSleepMicros: UInt32 = 50_000   // 50 ms
fileprivate func stressSlowHandler( context: RouterContext ) throws -> [String:Any] {
    usleep( stressSlowSleepMicros )
    return [ "ok": true ]
}


// MARK: - Stuck handler infrastructure
//
// These handlers "hang forever" by design. They exist to verify that one
// stuck handler does not compromise other concurrency paths:
//
//   - A stuck async handler must not pin a NIOThreadPool worker (the whole
//     point of removing the DispatchSemaphore in dispatch_request).
//   - A stuck sync handler must not stall the EventLoop (which is what makes
//     system endpoints answer regardless of pool saturation).
//
// Each test owns the lifecycle of its stuck handlers via the helpers below
// and MUST release them in `defer` so the thread pool can shut down cleanly.

/// Thread-safe park for async continuations. The async stuck handler
/// suspends inside `withCheckedContinuation`, parks the continuation here,
/// and waits to be released. `releaseAll` resumes every parked continuation,
/// allowing each handler to return normally.
fileprivate final class StuckContinuationStore: @unchecked Sendable {
    private let lock = NSLock()
    private var conts: [CheckedContinuation<Void, Never>] = []

    func park( _ cont: CheckedContinuation<Void, Never> ) {
        lock.lock(); defer { lock.unlock() }
        conts.append( cont )
    }

    func parkedCount() -> Int {
        lock.lock(); defer { lock.unlock() }
        return conts.count
    }

    func releaseAll() {
        lock.lock()
        let drained = conts
        conts.removeAll()
        lock.unlock()
        for c in drained { c.resume() }
    }
}

fileprivate let stuckAsyncStore = StuckContinuationStore()

/// Async handler that suspends until `stuckAsyncStore.releaseAll()` is called.
/// Critically: while suspended it holds NO NIOThreadPool worker, NO event
/// loop slot, and consumes ~no CPU. Just a parked continuation in memory.
fileprivate func stuckAsyncHandler( context: RouterContext ) async throws -> Any? {
    await withCheckedContinuation { ( cont: CheckedContinuation<Void, Never> ) in
        stuckAsyncStore.park( cont )
    }
    return [ "released": true ]
}

/// Counting semaphore used to release stuck SYNC handlers. Sync handlers
/// that are blocked on `wait()` DO pin a NIOThreadPool worker — that is the
/// scenario under test. Tests must `signal()` once per stuck handler in
/// `defer`, otherwise `threadPool.shutdownGracefully` will hang waiting for
/// the workers to return.
fileprivate let stuckSyncSemaphore = DispatchSemaphore( value: 0 )

/// Sync handler that blocks its NIOThreadPool worker until released.
fileprivate func stuckSyncHandler( context: RouterContext ) throws -> [String:Any] {
    stuckSyncSemaphore.wait()
    return [ "released": true ]
}

/// System endpoint handler. Runs inline on the EventLoop — must NEVER block
/// or do I/O.
fileprivate func stressSystemHealthHandler( context: RouterContext ) throws -> String {
    return "OK"
}


// MARK: - Stress harness

fileprivate struct StressStats {
    var success     : Int          = 0
    var failure     : Int          = 0
    var statusCodes : [Int:Int]    = [:]
    var elapsed     : TimeInterval = 0
    
    var description: String {
        return "success=\(success) failure=\(failure) statuses=\(statusCodes) elapsed=\(String(format:"%.2f", elapsed))s"
    }
}

/// Fires `total` GETs against `url` with at most `concurrency` in flight at
/// any moment. Uses a fresh ephemeral URLSession so we don't inherit state
/// from URLSession.shared between tests.
fileprivate func runConcurrentGets( url: String
                                  , total: Int
                                  , concurrency: Int
                                  , timeoutSeconds: TimeInterval = 30 ) -> StressStats
{
    let config = URLSessionConfiguration.ephemeral
    config.httpMaximumConnectionsPerHost = concurrency
    config.timeoutIntervalForRequest     = timeoutSeconds
    config.timeoutIntervalForResource    = timeoutSeconds * 2
    let session = URLSession( configuration: config )
    defer { session.invalidateAndCancel() }
    
    let inflight = DispatchSemaphore( value: concurrency )
    let group    = DispatchGroup()
    let lock     = NSLock()
    var stats    = StressStats()
    
    let target   = URL( string: url )!
    let start    = Date()
    
    for _ in 0..<total {
        inflight.wait()
        group.enter()
        let task = session.dataTask( with: target ) { _, response, error in
            lock.lock()
            if error != nil {
                stats.failure += 1
            } else if let http = response as? HTTPURLResponse {
                stats.statusCodes[ http.statusCode, default: 0 ] += 1
                if (200..<300).contains( http.statusCode ) { stats.success += 1 }
                else { stats.failure += 1 }
            } else {
                stats.failure += 1
            }
            lock.unlock()
            inflight.signal()
            group.leave()
        }
        task.resume()
    }
    
    let waitResult = group.wait( timeout: .now() + .seconds( Int( timeoutSeconds * 3 ) ) )
    stats.elapsed  = Date().timeIntervalSince( start )
    
    if waitResult == .timedOut {
        XCTFail( "Stress harness timed out before all requests completed (url=\(url) total=\(total))" )
    }
    
    return stats
}


// MARK: - Stress tests

final class MIOServerKitStressTests: XCTestCase
{
    // Tune these to push harder. Defaults aim for ~minute total runtime.
    private static let fastTotal             = 1_000
    private static let fastConcurrency       = 200
    
    private static let slowTotal             = 200
    private static let slowConcurrency       = 64    // > default thread pool (16) on purpose
    
    private static let sustainedRounds       = 5
    private static let sustainedPerRound     = 200
    private static let sustainedConcurrency  = 100
    
    private static let asyncTotal            = 500
    private static let asyncConcurrency      = 100
    
    private static let mixedPerEndpoint      = 500
    private static let mixedConcurrency      = 100
    
    private static let churnTotal            = 500
    private static let churnConcurrency      = 50

    // Stuck-handler isolation tests.
    // stuckAsyncCount must be >= 2 × default thread pool size (16) so that the
    // test would have wedged the pool under the old DispatchSemaphore design.
    private static let stuckAsyncCount       = 64
    // stuckSyncCount should equal the pool size so the pool is fully saturated
    // but not over-queued (we don't want stuck-sync work piling up indefinitely).
    private static let stuckSyncCount        = 16
    // Verification batch sizes — normal endpoints answered while stuck handlers
    // are live. Kept small so the test runs quickly; the property is qualitative.
    private static let isolationVerifyTotal       = 100
    private static let isolationVerifyConcurrency = 32
    // Per-request timeout for the system endpoint isolation test. K8s liveness
    // probes default to 1s; we use 2s to leave headroom for CI noise but still
    // fail loudly if the system path goes through the pool.
    private static let systemEndpointTimeout: TimeInterval = 2
    
    // MARK: high concurrency, no blocking work
    func testStress_HighConcurrencyFastRequests() throws {
        let routes = Router()
        routes.endpoint( "/fast" ).get( stressFastHandler )
        let (server, _) = launchServerHttp( routes )
        defer { try? server.terminateServer() }
        
        let stats = runConcurrentGets( url: "http://localhost:8080/fast"
                                     , total: Self.fastTotal
                                     , concurrency: Self.fastConcurrency )
        
        print( "[stress.fast] \(stats.description)" )
        XCTAssertEqual( stats.success, Self.fastTotal, "Fast endpoint failures: \(stats.description)" )
    }
    
    // MARK: thread pool saturation with blocking handlers
    func testStress_SlowEndpointThreadPoolSaturation() throws {
        let routes = Router()
        routes.endpoint( "/slow" ).get( stressSlowHandler )
        let (server, _) = launchServerHttp( routes )
        defer { try? server.terminateServer() }
        
        // 50ms * 200 / 16 (default pool) ≈ 0.6s wall minimum. Concurrency
        // of 64 is well above pool size so requests will queue on the pool.
        // We want all of them to complete cleanly without crashing.
        let stats = runConcurrentGets( url: "http://localhost:8080/slow"
                                     , total: Self.slowTotal
                                     , concurrency: Self.slowConcurrency
                                     , timeoutSeconds: 60 )
        
        print( "[stress.slow] \(stats.description)" )
        XCTAssertEqual( stats.success, Self.slowTotal, "Slow endpoint failures: \(stats.description)" )
    }
    
    // MARK: sustained traffic across multiple rounds
    func testStress_SustainedLoad() throws {
        let routes = Router()
        routes.endpoint( "/fast" ).get( stressFastHandler )
        let (server, _) = launchServerHttp( routes )
        defer { try? server.terminateServer() }
        
        for round in 0..<Self.sustainedRounds {
            let stats = runConcurrentGets( url: "http://localhost:8080/fast"
                                         , total: Self.sustainedPerRound
                                         , concurrency: Self.sustainedConcurrency )
            print( "[stress.sustained.\(round)] \(stats.description)" )
            XCTAssertEqual( stats.success, Self.sustainedPerRound
                          , "Sustained round \(round) failed: \(stats.description)" )
        }
    }
    
    // MARK: async endpoint path under load
    // The async dispatcher blocks a NIOThreadPool worker on a
    // DispatchSemaphore while a Task runs the handler. This is the most
    // fragile concurrency path - if it leaks or deadlocks under load,
    // we want to find out here.
    func testStress_AsyncEndpointsUnderLoad() throws {
        let routes = Router()
        routes.endpoint( "/async" ).get { ( ctx: RouterContext ) async throws -> Any? in
            return [ "ok": true ]
        }
        let (server, _) = launchServerHttp( routes )
        defer { try? server.terminateServer() }
        
        let stats = runConcurrentGets( url: "http://localhost:8080/async"
                                     , total: Self.asyncTotal
                                     , concurrency: Self.asyncConcurrency
                                     , timeoutSeconds: 60 )
        
        print( "[stress.async] \(stats.description)" )
        XCTAssertEqual( stats.success, Self.asyncTotal, "Async endpoint failures: \(stats.description)" )
    }
    
    // MARK: sync + async traffic in parallel
    func testStress_MixedSyncAsyncEndpoints() throws {
        let routes = Router()
        routes.endpoint( "/sync" ).get( stressFastHandler )
        routes.endpoint( "/async" ).get { ( ctx: RouterContext ) async throws -> Any? in
            return [ "ok": true ]
        }
        let (server, _) = launchServerHttp( routes )
        defer { try? server.terminateServer() }
        
        let group = DispatchGroup()
        var syncStats  = StressStats()
        var asyncStats = StressStats()
        
        DispatchQueue.global().async( group: group ) {
            syncStats = runConcurrentGets( url: "http://localhost:8080/sync"
                                         , total: Self.mixedPerEndpoint
                                         , concurrency: Self.mixedConcurrency
                                         , timeoutSeconds: 60 )
        }
        DispatchQueue.global().async( group: group ) {
            asyncStats = runConcurrentGets( url: "http://localhost:8080/async"
                                          , total: Self.mixedPerEndpoint
                                          , concurrency: Self.mixedConcurrency
                                          , timeoutSeconds: 60 )
        }
        group.wait()
        
        print( "[stress.mixed.sync ] \(syncStats.description)" )
        print( "[stress.mixed.async] \(asyncStats.description)" )
        XCTAssertEqual( syncStats.success,  Self.mixedPerEndpoint, "Mixed sync failures: \(syncStats.description)" )
        XCTAssertEqual( asyncStats.success, Self.mixedPerEndpoint, "Mixed async failures: \(asyncStats.description)" )
    }
    
    // MARK: connection churn - force handler init/deinit each request
    func testStress_ConnectionChurn() throws {
        let routes = Router()
        routes.endpoint( "/fast" ).get( stressFastHandler )
        let (server, _) = launchServerHttp( routes )
        defer { try? server.terminateServer() }
        
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = Self.churnConcurrency
        config.timeoutIntervalForRequest     = 30
        let session = URLSession( configuration: config )
        defer { session.invalidateAndCancel() }
        
        let target   = URL( string: "http://localhost:8080/fast" )!
        let inflight = DispatchSemaphore( value: Self.churnConcurrency )
        let group    = DispatchGroup()
        let lock     = NSLock()
        var stats    = StressStats()
        let start    = Date()
        
        for _ in 0..<Self.churnTotal {
            inflight.wait()
            group.enter()
            var req = URLRequest( url: target )
            // Force the server to tear down the channel after each response,
            // so we exercise ServerHTTPHandler init / deinit on every request.
            req.setValue( "close", forHTTPHeaderField: "Connection" )
            let task = session.dataTask( with: req ) { _, response, error in
                lock.lock()
                if error != nil {
                    stats.failure += 1
                } else if let http = response as? HTTPURLResponse {
                    stats.statusCodes[ http.statusCode, default: 0 ] += 1
                    if (200..<300).contains( http.statusCode ) { stats.success += 1 }
                    else { stats.failure += 1 }
                } else {
                    stats.failure += 1
                }
                lock.unlock()
                inflight.signal()
                group.leave()
            }
            task.resume()
        }
        
        let waited  = group.wait( timeout: .now() + .seconds( 90 ) )
        stats.elapsed = Date().timeIntervalSince( start )
        XCTAssertEqual( waited, .success, "Connection churn timed out" )
        
        print( "[stress.churn] \(stats.description)" )
        XCTAssertEqual( stats.success, Self.churnTotal, "Churn failures: \(stats.description)" )
    }


    // MARK: stuck async handlers must not pin thread pool workers
    //
    // Regression test against the old DispatchSemaphore design in dispatch_request.
    // Under that design, every async endpoint occupied a NIOThreadPool worker for
    // the lifetime of its Task. Parking 64 async handlers (4× the pool size)
    // would have starved the pool and made all sync endpoints time out.
    //
    // With the promise-based bridge, parked async Tasks hold no NIO resources.
    // Sync endpoints must continue to answer normally.
    func testStress_StuckAsyncHandlers_DoNotPinThreadPoolWorkers() throws {
        let routes = Router()
        routes.endpoint( "/stuck-async" ).get { ( ctx: RouterContext ) async throws -> Any? in
            return try await stuckAsyncHandler( context: ctx )
        }
        routes.endpoint( "/fast" ).get( stressFastHandler )
        let (server, _) = launchServerHttp( routes )

        // Release everything we parked, no matter how the test exits.
        defer {
            stuckAsyncStore.releaseAll()
            try? server.terminateServer()
        }

        // Fire-and-forget the stuck async requests on a separate session.
        // We do NOT wait for them to complete — they never will, until cleanup.
        let stuckConfig = URLSessionConfiguration.ephemeral
        stuckConfig.httpMaximumConnectionsPerHost = Self.stuckAsyncCount
        stuckConfig.timeoutIntervalForRequest     = 60
        let stuckSession = URLSession( configuration: stuckConfig )
        defer { stuckSession.invalidateAndCancel() }

        let stuckURL = URL( string: "http://localhost:8080/stuck-async" )!
        for _ in 0..<Self.stuckAsyncCount {
            stuckSession.dataTask( with: stuckURL ) { _, _, _ in }.resume()
        }

        // Wait until the server has actually parked the expected number of
        // continuations. This avoids a race where the verification batch fires
        // before the stuck handlers are in flight.
        let parkDeadline = Date().addingTimeInterval( 10 )
        while stuckAsyncStore.parkedCount() < Self.stuckAsyncCount && Date() < parkDeadline {
            Thread.sleep( forTimeInterval: 0.05 )
        }
        XCTAssertGreaterThanOrEqual( stuckAsyncStore.parkedCount(), Self.stuckAsyncCount
                                   , "Stuck async handlers never reached the server" )

        // Verify normal sync endpoints still answer cleanly. Under the old
        // semaphore design these would time out because all 16 pool workers
        // were parked on `semaphore.wait()`.
        let stats = runConcurrentGets( url: "http://localhost:8080/fast"
                                     , total: Self.isolationVerifyTotal
                                     , concurrency: Self.isolationVerifyConcurrency
                                     , timeoutSeconds: 10 )
        print( "[stress.stuck-async.verify] parked=\(stuckAsyncStore.parkedCount()) \(stats.description)" )
        XCTAssertEqual( stats.success, Self.isolationVerifyTotal
                      , "Sync endpoint failed while \(Self.stuckAsyncCount) async handlers were parked: \(stats.description)" )
    }


    // MARK: stuck sync handlers must not block the system endpoint
    //
    // The original DLChangelogSerializer liveness-probe failure: blocking sync
    // handlers (e.g. waiting on libpq, advisory locks) consumed every worker in
    // the NIOThreadPool. The K8s probe — a regular endpoint — timed out behind
    // them.
    //
    // System endpoints bypass the pool and run inline on the EventLoop. This
    // test saturates the pool with stuck sync handlers and verifies the system
    // endpoint stays under the K8s probe timeout regardless.
    func testStress_StuckSyncHandlers_DoNotBlockSystemEndpoint() throws {
        let routes = Router()
        routes.endpoint( "/stuck-sync" ).get( stuckSyncHandler )
        routes.systemEndpoint( "/health" ).get( stressSystemHealthHandler )
        let (server, _) = launchServerHttp( routes )

        // Release stuck workers BEFORE shutting the server down, otherwise
        // threadPool.shutdownGracefully will wait for them indefinitely.
        defer {
            for _ in 0..<Self.stuckSyncCount { stuckSyncSemaphore.signal() }
            try? server.terminateServer()
        }

        // Saturate the pool. Each request occupies one worker until released.
        let stuckConfig = URLSessionConfiguration.ephemeral
        stuckConfig.httpMaximumConnectionsPerHost = Self.stuckSyncCount
        stuckConfig.timeoutIntervalForRequest     = 60
        let stuckSession = URLSession( configuration: stuckConfig )
        defer { stuckSession.invalidateAndCancel() }

        let stuckURL = URL( string: "http://localhost:8080/stuck-sync" )!
        for _ in 0..<Self.stuckSyncCount {
            stuckSession.dataTask( with: stuckURL ) { _, _, _ in }.resume()
        }

        // Give the server time to actually pick up all stuck requests onto
        // workers. We don't have direct visibility into the pool, so we sleep
        // briefly. 250ms is well past the request RTT on localhost.
        Thread.sleep( forTimeInterval: 0.25 )

        // Each system-endpoint request must answer within K8s-probe-like time.
        // We assert per-request, not just aggregate, so a single slow response
        // fails the test loudly.
        let stats = runConcurrentGets( url: "http://localhost:8080/health"
                                     , total: Self.isolationVerifyTotal
                                     , concurrency: Self.isolationVerifyConcurrency
                                     , timeoutSeconds: Self.systemEndpointTimeout )
        print( "[stress.stuck-sync.system] \(stats.description)" )
        XCTAssertEqual( stats.success, Self.isolationVerifyTotal
                      , "System endpoint failed while pool was saturated: \(stats.description)" )
        // Sanity check on the pace: 100 system requests at 32 concurrency on
        // localhost should finish in a fraction of a second. If it took more
        // than a couple of seconds, the system path is doing something it
        // shouldn't (queuing on the pool, hopping unnecessarily, etc).
        XCTAssertLessThan( stats.elapsed, 5.0
                         , "System endpoint batch took too long, suggesting it isn't bypassing the pool: \(stats.description)" )
    }


    // MARK: combined isolation — stuck sync + stuck async + normal traffic
    //
    // Cross-talk test. With one stuck sync handler, one stuck async handler,
    // and the system endpoint all live simultaneously, normal sync and normal
    // async traffic should all answer. This catches subtle interactions that
    // the single-axis tests above might miss.
    func testStress_StuckHandlers_ServerStaysResponsive() throws {
        let routes = Router()
        routes.endpoint( "/stuck-sync" ).get( stuckSyncHandler )
        routes.endpoint( "/stuck-async" ).get { ( ctx: RouterContext ) async throws -> Any? in
            return try await stuckAsyncHandler( context: ctx )
        }
        routes.endpoint( "/fast" ).get( stressFastHandler )
        routes.endpoint( "/async-fast" ).get { ( ctx: RouterContext ) async throws -> Any? in
            return [ "ok": true ]
        }
        routes.systemEndpoint( "/health" ).get( stressSystemHealthHandler )
        let (server, _) = launchServerHttp( routes )

        // Use a smaller stuck-sync count here so we leave some pool capacity
        // for the verification sync traffic. We only need to prove the cross-
        // talk doesn't compromise other paths, not to fully saturate.
        let partialStuckSync = max( 1, Self.stuckSyncCount / 2 )

        defer {
            stuckAsyncStore.releaseAll()
            for _ in 0..<partialStuckSync { stuckSyncSemaphore.signal() }
            try? server.terminateServer()
        }

        let stuckConfig = URLSessionConfiguration.ephemeral
        stuckConfig.timeoutIntervalForRequest = 60
        let stuckSession = URLSession( configuration: stuckConfig )
        defer { stuckSession.invalidateAndCancel() }

        // Park stuck-async
        let stuckAsyncURL = URL( string: "http://localhost:8080/stuck-async" )!
        for _ in 0..<Self.stuckAsyncCount {
            stuckSession.dataTask( with: stuckAsyncURL ) { _, _, _ in }.resume()
        }
        // Park stuck-sync
        let stuckSyncURL = URL( string: "http://localhost:8080/stuck-sync" )!
        for _ in 0..<partialStuckSync {
            stuckSession.dataTask( with: stuckSyncURL ) { _, _, _ in }.resume()
        }

        // Wait for handlers to be in flight. We can directly check async park
        // count; for sync we just sleep.
        let parkDeadline = Date().addingTimeInterval( 10 )
        while stuckAsyncStore.parkedCount() < Self.stuckAsyncCount && Date() < parkDeadline {
            Thread.sleep( forTimeInterval: 0.05 )
        }
        Thread.sleep( forTimeInterval: 0.25 )

        // Run all three verification batches in parallel.
        let group = DispatchGroup()
        var syncStats   = StressStats()
        var asyncStats  = StressStats()
        var systemStats = StressStats()

        DispatchQueue.global().async( group: group ) {
            syncStats = runConcurrentGets( url: "http://localhost:8080/fast"
                                         , total: Self.isolationVerifyTotal
                                         , concurrency: Self.isolationVerifyConcurrency
                                         , timeoutSeconds: 15 )
        }
        DispatchQueue.global().async( group: group ) {
            asyncStats = runConcurrentGets( url: "http://localhost:8080/async-fast"
                                          , total: Self.isolationVerifyTotal
                                          , concurrency: Self.isolationVerifyConcurrency
                                          , timeoutSeconds: 15 )
        }
        DispatchQueue.global().async( group: group ) {
            systemStats = runConcurrentGets( url: "http://localhost:8080/health"
                                           , total: Self.isolationVerifyTotal
                                           , concurrency: Self.isolationVerifyConcurrency
                                           , timeoutSeconds: Self.systemEndpointTimeout )
        }
        group.wait()

        print( "[stress.combined.sync  ] \(syncStats.description)" )
        print( "[stress.combined.async ] \(asyncStats.description)" )
        print( "[stress.combined.system] \(systemStats.description)" )
        XCTAssertEqual( syncStats.success,   Self.isolationVerifyTotal, "Sync endpoint failed: \(syncStats.description)" )
        XCTAssertEqual( asyncStats.success,  Self.isolationVerifyTotal, "Async endpoint failed: \(asyncStats.description)" )
        XCTAssertEqual( systemStats.success, Self.isolationVerifyTotal, "System endpoint failed: \(systemStats.description)" )
    }
}
