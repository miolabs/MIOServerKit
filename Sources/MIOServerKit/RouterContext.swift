//
//  RouterContext.swift
//
//
//  Created by Javier Segura Perez on 14/9/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import MIOCore
import NIOHTTP1
import MIOCoreLogger
#if canImport(Glibc)
import Glibc
#endif


public let uuidRegexRoute = "([0-9a-fA-F]{8}-[0-96a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"


public protocol RouterContextProtocol : AnyObject
{
    var request: RouterRequest { get }
    var response: RouterResponse { get }
    
    init( _ request: RouterRequest, _ response: RouterResponse, values:[String:Any] ) throws
    
    func queryParam ( _ name: String ) -> String?
    func urlParam<T> ( _ name: String ) throws -> T
    func bodyParam<T> (_ name: String, optional: Bool ) throws -> T?
    
    func bodyAsData() -> Data?
    func bodyAsJSON<T>() throws -> T?
        
    // Sync methods
    func willExecute() throws
    func didExecute() throws

    // Async methods
    func willExecute() async throws
    func didExecute() async throws
}

extension RouterContextProtocol
{
    public func urlParam<T> ( _ name: String ) throws -> T {
        return try MIOCoreParam( request.parameters, name )
    }
    
    public func queryParam ( _ name: String ) -> String? {
        return request.queryParameters[ name ]
    }
    
    public func bodyAsData() -> Data? {
        return request.body
    }

    public func bodyAsJSON<T>() throws -> T {
        if request.body == nil { throw ServerError.missingJSONBody() }
        let json = try JSONSerialization.jsonObject( with: request.body! ) as? T
        if json == nil { throw ServerError.invalidJSONBodyCast() }
        return json!
    }
    
    public func bodyParam<T> (_ name: String, optional: Bool = false ) throws -> T? {
        let json:[ String:Any ]? = try bodyAsJSON()
        if json == nil {
            if optional { return nil }
            throw ServerError.missingJSONBody( )
        }

        if let dict = json {

            if let value = dict[ name ] as? T {
                return value
            }
            else if optional { return nil }
            else { throw ServerError.fieldNotFound( name ) }
        }

        if optional { return nil }
        throw ServerError.fieldNotFound( name )
    }
    
    // Default implementations for sync methods
    public func willExecute() throws { }
    public func didExecute() throws { }
       
    // Default implementations for async methods
    public func willExecute() async throws { }
    public func didExecute() async throws { }
    
}

// Single-threaded by construction: created in channelRead, captured into
// exactly one of {.system, .sync via runIfActive, .async via Task} and
// never shared. Do not store or pass to multiple consumers concurrently.
//
// Misuse detection (DEBUG only):
// Each context stamps an owner identity at construction — a Task-local UUID
// for async handlers (set by the dispatcher), and the construction pthread
// for sync/system handlers. `assertOwner()` compares against the current
// identity and trips an assertion if the context is being accessed from a
// different Task, DispatchQueue, OperationQueue, or thread. The check is
// debug-only and compiles to a no-op in release.
#if DEBUG
extension RouterContext {
    /// Task-local owner token. Set by the dispatcher around the async
    /// handler invocation; inherited by structured children (`async let`,
    /// `withTaskGroup`) but reset at thread/queue boundaries that don't
    /// participate in Swift Concurrency.
    @TaskLocal
    public static var currentOwnerToken: UUID?
}
#endif

open class RouterContext : MIOCoreContext, RouterContextProtocol, @unchecked Sendable
{
    public var request: RouterRequest
    public var response: RouterResponse

    #if DEBUG
    private let _ownerToken: UUID
    private let _ownerThreadID: pthread_t
    #endif

    public required init ( _ request: RouterRequest, _ response: RouterResponse, values:[String:Any] = [:] ) throws {
        self.request        = request
        self.response       = response
        #if DEBUG
        // Inherit the dispatcher's token if one is set (async path).
        // Otherwise stamp a fresh UUID — the pthread fallback covers sync/system.
        self._ownerToken    = Self.currentOwnerToken ?? UUID()
        self._ownerThreadID = pthread_self()
        #endif
        super.init( values )
    }

    deinit {
        Log.debug("RouterContext deinit")
    }

    /// Asserts that this context is being accessed from its owning execution
    /// context (the Task it was constructed in for async handlers, the thread
    /// it was constructed on for sync/system handlers).
    ///
    /// Catches the common @unchecked Sendable violations:
    ///   - Capturing into a `DispatchQueue.async { ... }` block
    ///   - Capturing into an `OperationQueue`
    ///   - Capturing into `Task.detached { ... }`
    ///   - Any pthread that isn't the owner
    ///
    /// Limitation: capturing into an unstructured `Task { ... }` from inside
    /// an async handler IS NOT detected, because unstructured Tasks inherit
    /// task-local values at creation. Avoid this pattern in handlers — use
    /// `Task.detached` if you really need fire-and-forget background work,
    /// and don't pass the context into it.
    ///
    /// Debug-only. No-op in release builds.
    @inline(__always)
    public func assertOwner( _ function: StaticString = #function
                           , _ file: StaticString = #file
                           , _ line: UInt = #line ) {
        #if DEBUG
        // Async path: dispatcher set a task-local, our init captured it.
        // The current task-local must equal what we stamped.
        if let taskToken = Self.currentOwnerToken {
            if taskToken != _ownerToken {
                _ownerCheckFailed( "task identity mismatch", function, file, line )
            }
            return
        }
        // Sync / system path: no task-local, fall back to pthread comparison.
        // pthread_equal returns Int32 (non-zero = equal), not Bool.
        if pthread_equal( pthread_self(), _ownerThreadID ) == 0 {
            _ownerCheckFailed( "thread identity mismatch", function, file, line )
        }
        #endif
    }

    #if DEBUG
    private func _ownerCheckFailed( _ kind: String
                                  , _ function: StaticString
                                  , _ file: StaticString
                                  , _ line: UInt ) {
        Log.error( "RouterContext: \(kind) in \(function) at \(file):\(line). The context was used outside of its owning Task or thread — did you capture it in Task.detached, a DispatchQueue, or an OperationQueue? @unchecked Sendable contract violated." )
        assertionFailure( "RouterContext: \(kind) in \(function) at \(file):\(line). The context was used outside of its owning Task or thread — did you capture it in Task.detached, a DispatchQueue, or an OperationQueue? @unchecked Sendable contract violated." )
    }
    #endif

    // Default implementations for sync methods
    open func willExecute() throws { assertOwner() }
    open func didExecute() throws { assertOwner() }

    // Default implementations for async methods
    open func willExecute() async throws { assertOwner() }
    open func didExecute() async throws { assertOwner() }
        
    open func responseHeaders ( ) -> [String:String] { return [:] }
    open func responseBodyData ( _ value : Any? = nil ) throws -> Data? {
        var content_type:String? = nil
        var body:Data?           = nil
        
        switch value {
        case let d as Data:
            content_type = "application/octet-stream"
            body = d
        case let s as String:
            content_type = "text/plain"
            body = s.data(using: .utf8)
        case let arr as [Any]:
            content_type = "application/json"
            body = try MIOCoreJsonValue(withJSONObject: arr)
        case let dic as [String:Any]:
            content_type = "application/json"
            body = try MIOCoreJsonValue(withJSONObject: dic)
        default: break
        }
        
        if self.response.headers[.contentType].count == 0, let ct = content_type {
            self.response.headers.replaceOrAdd(name: .contentType, value: ct )
        }

        return body
    }
        
    public override func sendableValues() -> [String:(any Sendable)] {
        var values:[String:(any Sendable)] = super.sendableValues()
                
        if request.parameters.isEmpty == false {
            values.merge(request.parameters) { (_, new) in new }
        }
        
        if request.queryParameters.isEmpty == false {
            values.merge(request.queryParameters) { (_, new) in new }
        }
        
        return values
    }

}
