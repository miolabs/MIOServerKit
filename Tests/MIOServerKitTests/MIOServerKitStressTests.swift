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
        ( "testStress_HighConcurrencyFastRequests",      testStress_HighConcurrencyFastRequests ),
        ( "testStress_SlowEndpointThreadPoolSaturation", testStress_SlowEndpointThreadPoolSaturation ),
        ( "testStress_SustainedLoad",                    testStress_SustainedLoad ),
        ( "testStress_AsyncEndpointsUnderLoad",          testStress_AsyncEndpointsUnderLoad ),
        ( "testStress_MixedSyncAsyncEndpoints",          testStress_MixedSyncAsyncEndpoints ),
        ( "testStress_ConnectionChurn",                  testStress_ConnectionChurn ),
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
}
