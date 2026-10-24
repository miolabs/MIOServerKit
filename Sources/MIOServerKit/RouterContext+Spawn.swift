//
//  RouterContext+Spawn.swift
//  MIOServerKit
//
//  Spawning work from an endpoint: a new context, built as the router builds
//  its own (init(request, response, values:)), run with the router's own
//  sequence (willExecute, the work, didExecute — the SyncEndpointWrapper
//  order). Whether a request or a spawn built it, a context runs the same
//  sequence.
//
//  Three ways in:
//    context.spawn { ctx in ... }                       the caller's own type
//    context.spawn( OtherContext.self ) { ctx in ... }   any RouterContextProtocol type
//    RouterContext.spawn( OtherContext.self, values: )   no request at all (an event, a timer)
//  each now, on this thread, returning what the work returns — or later, on
//  the serial queue of a `label`, one at a time per label. A labelled spawn
//  that arrives while its label is running is not lost: it re-runs once the
//  running work ends (the last request wins), so a wake-up that lands
//  mid-run is still served.
//

import Foundation
import MIOCore
import MIOCoreLogger


/// A context that must drop the changes of a failed spawn before it is used
/// again (a Core Data context rolls back). The spawn calls it when the work
/// throws, before rethrowing; didExecute never runs for that work.
public protocol ExecutionRollback {
    func rollbackExecution ( )
}


/// The labelled spawns that arrived while their label was running: the last
/// request per label, re-spawned when the running work ends.
///
/// Without it such a request was dropped, and the running work was expected
/// to pick its state up — which it cannot when the request lands after its
/// last look. The serializer wakes the stock server from inside its own run;
/// the stock server writes and wakes the serializer back within milliseconds;
/// that awake found the label held and was lost, and the rows waited for the
/// next unrelated awake.
enum SpawnPending
{
    nonisolated(unsafe) private static var requests: [String: () -> Void] = [:]
    private static let lock = NSLock()

    static func set ( _ label: String, _ request: @escaping () -> Void ) {
        lock.lock(); defer { lock.unlock() }
        requests[ label ] = request
    }

    static func take ( _ label: String ) -> ( () -> Void )? {
        lock.lock(); defer { lock.unlock() }
        return requests.removeValue( forKey: label )
    }
}


extension RouterContextProtocol
{
    // MARK: - Now, on this thread

    /// Builds a context of `type` from `values`, as the router builds its own,
    /// and runs `body` on it with the router's sequence: willExecute, body,
    /// didExecute. A body that throws leaves nothing pending (ExecutionRollback)
    /// and didExecute does not run; the error is rethrown.
    public static func spawn<C: RouterContextProtocol, R> ( _ type: C.Type, values: [String:Any] = [:], _ body: ( C ) throws -> R ) throws -> R {
        let context = try C( RouterRequest(), RouterResponse(), values: values )
        return try context.run( body )
    }

    /// The same, from this context: the new one starts with this context's
    /// sendable values, `values` merged over them.
    public func spawn<C: RouterContextProtocol, R> ( _ type: C.Type, values: [String:Any] = [:], _ body: ( C ) throws -> R ) throws -> R {
        return try Self.spawn( type, values: spawnValues( values ), body )
    }

    /// The same, a context of this context's own type.
    public func spawn<R> ( values: [String:Any] = [:], _ body: ( Self ) throws -> R ) throws -> R {
        return try spawn( Self.self, values: values, body )
    }

    // MARK: - Later, on the label's queue

    /// Builds the context and runs `body` on the serial queue of `label`, one
    /// at a time per label. When the label is already running the call
    /// returns false and the request waits: it re-runs, with its own context,
    /// once the running work ends — one re-run however many requests arrived
    /// meanwhile, the last one's body and values. The context is built on
    /// the queue, never crossing threads. A failure is logged with the label;
    /// the work itself reports its own.
    @discardableResult
    public static func spawn<C: RouterContextProtocol> ( _ type: C.Type, label: String, values: [String:(any Sendable)] = [:], _ body: @Sendable @escaping ( C ) throws -> Void ) -> Bool {
        guard MCQueue.acquire( label ) else {
            SpawnPending.set( label ) { spawn( type, label: label, values: values, body ) }
            Log.debug( "\(label): already running, spawn re-runs when it ends" )

            // The running work may have released between the failed acquire
            // and the set, leaving no one to take the request. A second
            // acquire settles it: still held, the runner takes it on exit;
            // free, we hold the label now and run the pending request.
            if MCQueue.acquire( label ) {
                MCQueue.release( label )
                SpawnPending.take( label )?( )
            }
            return false
        }

        MCQueue.named( label ).async {
            do {
                try spawn( type, values: values, body )
            }
            catch {
                Log.error( "\(label): spawned work failed: \(error)" )
            }

            // Release first, then look for a request that arrived meanwhile:
            // its re-spawn acquires the label afresh.
            MCQueue.release( label )
            SpawnPending.take( label )?( )
        }

        return true
    }

    /// The same, from this context: its sendable values, `values` merged over them.
    @discardableResult
    public func spawn<C: RouterContextProtocol> ( _ type: C.Type, label: String, values: [String:(any Sendable)] = [:], _ body: @Sendable @escaping ( C ) throws -> Void ) -> Bool {
        return Self.spawn( type, label: label, values: spawnSendableValues( values ), body )
    }

    /// The same, a context of this context's own type.
    @discardableResult
    public func spawn ( label: String, values: [String:(any Sendable)] = [:], _ body: @Sendable @escaping ( Self ) throws -> Void ) -> Bool {
        return spawn( Self.self, label: label, values: values, body )
    }

    // MARK: - The sequence

    /// The router's sequence on this context: willExecute, body, didExecute.
    /// A context runs it once: the router, or the spawn that built it. Public
    /// for a context built elsewhere (legacy call sites); prefer spawn.
    @discardableResult
    public func run<R> ( _ body: ( Self ) throws -> R ) throws -> R {
        try willExecute()

        let result: R
        do {
            result = try body( self )
        }
        catch {
            ( self as? ExecutionRollback )?.rollbackExecution()
            throw error
        }

        try didExecute()
        return result
    }

    func spawnValues ( _ values: [String:Any] ) -> [String:Any] {
        var merged: [String:Any] = sendableValues()
        merged.merge( values ) { _, new in new }
        return merged
    }

    func spawnSendableValues ( _ values: [String:(any Sendable)] ) -> [String:(any Sendable)] {
        var merged = sendableValues()
        merged.merge( values ) { _, new in new }
        return merged
    }
}
