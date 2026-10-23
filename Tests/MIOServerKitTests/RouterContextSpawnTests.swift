//
//  RouterContextSpawnTests.swift
//  MIOServerKitTests
//
//  Pins spawn: a context built from an endpoint's context (or from values
//  alone) runs the router's own sequence — willExecute, the work, didExecute
//  — in the caller's type or any other RouterContextProtocol type, now on
//  this thread or later on a label's serial queue, one at a time per label.
//

import XCTest
import MIOCore
@testable import MIOServerKit


final class SpyContext: RouterContext, @unchecked Sendable {
    var events: [String] = []
    var rolled_back = 0

    override func willExecute ( ) throws { events.append( "will" ) }
    override func didExecute ( ) throws { events.append( "did" ) }
}

extension SpyContext : ExecutionRollback {
    func rollbackExecution ( ) { rolled_back += 1 }
}

final class OtherContext: RouterContext, @unchecked Sendable {
    var events: [String] = []
    override func willExecute ( ) throws { events.append( "will" ) }
    override func didExecute ( ) throws { events.append( "did" ) }
}

struct SpawnTestError: Error {}


final class RouterContextSpawnTests: XCTestCase {

    /// A caller whose values cross to a spawn: stored through the Sendable
    /// setter, as EntityContext stores schemaID / placeID / appID at setup.
    func makeCaller ( _ values: [String:(any Sendable)] = [:] ) throws -> SpyContext {
        let caller = try SpyContext( RouterRequest(), RouterResponse(), values: [:] )
        for ( key, value ) in values { caller.setGlobalValue( value, forKey: key ) }
        return caller
    }

    // MARK: - Now

    func test_spawn_runsRouterSequenceOnNewContextOfCallersType ( ) throws {
        let caller = try makeCaller( [ "schemaID": "venue-1" ] )
        var spawned: SpyContext? = nil

        let result = try caller.spawn { ctx -> Int in
            spawned = ctx
            ctx.events.append( "body" )
            return 42
        }

        XCTAssertEqual( result, 42, "spawn returns what the work returns" )
        XCTAssertTrue( spawned !== caller, "a new context, not the caller's" )
        XCTAssertEqual( spawned?.events, [ "will", "body", "did" ] )
        XCTAssertEqual( spawned?.globals[ "schemaID" ] as? String, "venue-1", "built from the caller's values" )
        XCTAssertEqual( caller.events, [], "the caller's own sequence is the router's business" )
    }

    func test_spawn_buildsAnyContextTypeAndMergesValues ( ) throws {
        let caller = try makeCaller( [ "schemaID": "venue-1", "appID": "app-1" ] )
        var spawned: OtherContext? = nil

        try caller.spawn( OtherContext.self, values: [ "appID": "app-2", "extra": true ] ) { ctx in
            spawned = ctx
        }

        XCTAssertEqual( spawned?.events, [ "will", "did" ] )
        XCTAssertEqual( spawned?.globals[ "schemaID" ] as? String, "venue-1", "the caller's values" )
        XCTAssertEqual( spawned?.globals[ "appID" ] as? String, "app-2", "merged over by the spawn's own" )
        XCTAssertEqual( spawned?.globals[ "extra" ] as? Bool, true )
    }

    func test_spawn_staticNeedsNoRequest ( ) throws {
        var spawned: OtherContext? = nil

        let result = try RouterContext.spawn( OtherContext.self, values: [ "schemaID": "venue-9" ] ) { ctx -> String in
            spawned = ctx
            return "done"
        }

        XCTAssertEqual( result, "done" )
        XCTAssertEqual( spawned?.events, [ "will", "did" ] )
        XCTAssertEqual( spawned?.globals[ "schemaID" ] as? String, "venue-9" )
    }

    func test_spawn_throwingWorkRollsBackSkipsDidExecuteAndRethrows ( ) throws {
        let caller = try makeCaller()
        var spawned: SpyContext? = nil

        XCTAssertThrowsError( try caller.spawn { ctx in
            spawned = ctx
            throw SpawnTestError()
        } ) { error in
            XCTAssertTrue( error is SpawnTestError )
        }

        XCTAssertEqual( spawned?.events, [ "will" ], "didExecute never runs for failed work" )
        XCTAssertEqual( spawned?.rolled_back, 1, "the context drops the failed work's changes" )
    }

    // MARK: - Later, on a label

    func test_spawn_labelledRunsOnItsQueueOneAtATime ( ) throws {
        let caller = try makeCaller( [ "schemaID": "venue-1" ] )
        let label = "spawn-test." + UUID().uuidString
        let running = DispatchSemaphore( value: 0 )
        let release = DispatchSemaphore( value: 0 )
        let lock = NSLock()
        var runs: [[String]] = []
        func record ( _ events: [String] ) { lock.lock(); runs.append( events ); lock.unlock() }

        let first = caller.spawn( label: label ) { ctx in
            ctx.events.append( "body" )
            running.signal()
            release.wait()
            record( ctx.events )
        }
        XCTAssertTrue( first, "queued" )
        XCTAssertEqual( running.wait( timeout: .now() + 5 ), .success, "runs on its queue" )

        let second = caller.spawn( label: label ) { _ in record( [ "must not run" ] ) }
        XCTAssertFalse( second, "the label is running: skipped, not queued" )

        release.signal()
        let drained = expectation( description: "queue drained" )
        MCQueue.named( label ).async { drained.fulfill() }
        wait( for: [ drained ], timeout: 5 )

        lock.lock(); let after_first = runs; lock.unlock()
        XCTAssertEqual( after_first, [ [ "will", "body" ] ], "willExecute before the body; didExecute after, outside what the body records" )

        let third = caller.spawn( OtherContext.self, label: label, values: [ "appID": "app-3" ] ) { ctx in
            record( [ ctx.globals[ "schemaID" ] as? String ?? "", ctx.globals[ "appID" ] as? String ?? "" ] )
        }
        XCTAssertTrue( third, "free again once the work ended" )
        let drained_again = expectation( description: "queue drained again" )
        MCQueue.named( label ).async { drained_again.fulfill() }
        wait( for: [ drained_again ], timeout: 5 )

        lock.lock(); let all = runs; lock.unlock()
        XCTAssertEqual( all.last, [ "venue-1", "app-3" ], "any type, the caller's values merged with the spawn's" )
    }

    func test_spawn_labelledFailureFreesTheLabel ( ) throws {
        let label = "spawn-test." + UUID().uuidString

        XCTAssertTrue( RouterContext.spawn( OtherContext.self, label: label ) { _ in throw SpawnTestError() } )
        let drained = expectation( description: "queue drained" )
        MCQueue.named( label ).async { drained.fulfill() }
        wait( for: [ drained ], timeout: 5 )

        XCTAssertTrue( RouterContext.spawn( OtherContext.self, label: label ) { _ in }, "a failed spawn releases its label" )
    }
}
