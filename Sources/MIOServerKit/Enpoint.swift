//
//  Endpoint.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import MIOCore
import MIOCoreLogger

public enum EndpointMethod: String
{
    case GET     = "GET"
    case POST    = "POST"
    case PUT     = "PUT"
    case PATCH   = "PATCH"
    case DELETE  = "DELETE"
    case OPTIONS = "OPTIONS"
    case HEAD    = "HEAD"
}

// MARK: - EndpointPath
public class EndpointPath
{
    public var path: RouterPath

    public init ( _ url: String = "" ) {
        path = RouterPath( url )
    }

    public init ( _ partial_path: RouterPath ) {
        path = partial_path
    }
    
    @discardableResult
    public func set_path ( _ new_path: RouterPath ) -> EndpointPath {
        path = new_path
        return self
    }
    
    public func match ( _ method: EndpointMethod, _ url: RouterPath, _ vars: inout RouterPathVars ) -> RouterPathDiff? {
        return path.match( url, &vars )
    }
    
    public func diff ( _ node: EndpointPath /*, _ vars: inout RouterPathVars */ ) -> RouterPathDiff {
        return diff( node.path /*, &vars */ )
    }
    
    public func diff ( _ parts: RouterPath /*, _ vars: inout RouterPathVars */  ) -> RouterPathDiff {
        return path.diff( parts /*, &vars */ )
    }
    
    public func index_part ( ) -> String { return path.index_part() }
    public func starts_with_var ( ) -> Bool { return path.starts_with_var() }
    public func starts_with_regex ( ) -> Bool { return path.starts_with_regex() }
    
    public func debug_info ( _ spaces: Int = 0, _ prefix: String = "" ) {
        print( "".padding(toLength: spaces, withPad: " ", startingAt: 0) + prefix + path.debug_path()  )
    }
}

// MARK: - MethodEndpoint

public typealias SyncEndpointRequestDispatcher<T:RouterContext> = @Sendable ( _ context: T ) throws -> (any Sendable)?
public typealias AsyncEndpointRequestDispatcher<T:RouterContext> = @Sendable ( _ context: T ) async throws -> (any Sendable)?

/// Result of running an endpoint handler. Success carries the handler's return
/// value; failure carries any error thrown by the handler or its lifecycle hooks
/// (`willExecute` / `didExecute` / `responseBodyData`).
public typealias MethodEndpointResult = Result<(any Sendable)?, Error>

/// Completion-style callback used at the boundary between `dispatch_request`
/// and `channelRead`. Internal to the NIO handler — not part of the endpoint
/// authoring API.
public typealias MethodEndpointCompletionBlock = ( (any Sendable)?, Error? ) -> Void

protocol MethodEndpointExecutionProtocol : Sendable {
    /// Runs synchronously on the calling thread. Used by `.system` (event loop)
    /// and `.sync` (thread pool) execution paths.
    /// Errors are returned via `Result.failure` so callers can compose with
    /// `EventLoopFuture` without juggling completion handlers.
    func runSync( _ request: RouterRequest, _ response: RouterResponse ) -> MethodEndpointResult

    /// Runs asynchronously inside a `Task`. Used by the `.async` execution path.
    /// The returned `Result` is later used to fulfill an `EventLoopPromise`.
    func runAsync( _ request: RouterRequest, _ response: RouterResponse ) async -> MethodEndpointResult
}

public struct MethodEndpoint
{
    // Wrapper for sync callbacks
    struct SyncEndpointWrapper<T : Sendable & RouterContext > : MethodEndpointExecutionProtocol
    {
        let cb: SyncEndpointRequestDispatcher<T>

        init ( _ cb: @escaping SyncEndpointRequestDispatcher<T> ) {
            self.cb = cb
        }

        func runAsync( _ request: RouterRequest, _ response: RouterResponse ) async -> MethodEndpointResult {
            return .failure( MIOCoreError.general( "Sync endpoint invoked via async path" ) )
        }

        func runSync( _ request: RouterRequest, _ response: RouterResponse ) -> MethodEndpointResult {
            do {
                let ctx = try T.init( request, response )
                try ctx.willExecute()
                var result: Any? = try cb( ctx )
                try ctx.didExecute()

                // Add custom headers if available
                for (k,v) in ctx.responseHeaders() {
                    response.headers.replaceOrAdd( name: k, value: v )
                }

                result = try ctx.responseBodyData( result )

                Log.debug( "Synchronous endpoint executed successfully." )
                return .success( result )
            }
            catch {
                Log.error( "\(error)" )
                return .failure( error )
            }
        }
    }
        
    // Wrapper for async callbacks
    struct AsyncEndpointWrapper<T : Sendable & RouterContext > : MethodEndpointExecutionProtocol
    {
        let cb: AsyncEndpointRequestDispatcher<T>

        init ( _ cb: @escaping AsyncEndpointRequestDispatcher<T> ) {
            self.cb = cb
        }

        func runSync( _ request: RouterRequest, _ response: RouterResponse ) -> MethodEndpointResult {
            return .failure( MIOCoreError.general( "Async endpoint invoked via sync path" ) )
        }

        func runAsync( _ request: RouterRequest, _ response: RouterResponse ) async -> MethodEndpointResult {
            do {
                let ctx = try T.init( request, response )

                try await ctx.willExecute()
                var result: Any? = try await cb( ctx )
                try await ctx.didExecute()

                // Add custom headers if available
                for (k,v) in ctx.responseHeaders() {
                    response.headers.replaceOrAdd( name: k, value: v )
                }

                result = try ctx.responseBodyData( result )

                Log.debug( "Asynchronous endpoint executed successfully." )
                return .success( result )
            }
            catch {
                Log.error( "\(error)" )
                return .failure( error )
            }
        }
    }
    
    public enum EndpointExecutionType {
        case system
        case sync
        case async
    }
    
    var wrapper: any MethodEndpointExecutionProtocol
    var extra_url: RouterPath?
    var _execution_type: EndpointExecutionType
    public var executionType : EndpointExecutionType { return _execution_type }

    // Init for system callbacks
    init <T:RouterContext>(systemCb: @escaping SyncEndpointRequestDispatcher<T>, extraUrl: RouterPath? = nil) {
        wrapper = SyncEndpointWrapper(systemCb)
        extra_url = extraUrl
        _execution_type = .system
    }
    
    // Init for sync callbacks
    init <T:RouterContext>(cb: @escaping SyncEndpointRequestDispatcher<T>, extraUrl: RouterPath? = nil ) {
        wrapper = SyncEndpointWrapper( cb )
        extra_url = extraUrl
        _execution_type = .sync
    }
    
    // Init for async callbacks
    init <T:RouterContext>(async_cb: @escaping AsyncEndpointRequestDispatcher<T>, extraUrl: RouterPath? = nil ) {
        wrapper = AsyncEndpointWrapper( async_cb )
        extra_url = extraUrl
        _execution_type = .async
    }

    public func runSync( _ request: RouterRequest, _ response: RouterResponse ) -> MethodEndpointResult {
        return wrapper.runSync( request, response )
    }

    public func runAsync( _ request: RouterRequest, _ response: RouterResponse ) async -> MethodEndpointResult {
        return await wrapper.runAsync( request, response )
    }
}

// MARK: - Endpoint
public class Endpoint
{
//   public typealias RouterClass = RouterContextProtocol
        
    public var methods: [ EndpointMethod : MethodEndpoint ] = [:]
    
//    public var methods: [ EndpointMethod: (cb: EndpointRequestDispatcher<T>, extra_url: RouterPath?, ct: RouterContextProtocol) ] = [:]

    // Sync methods    
    @discardableResult
    public func get<T>( _ cb: @escaping SyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addSyncMethod( .GET, cb, url )
    }

    @discardableResult
    public func post<T>( _ cb: @escaping SyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addSyncMethod( .POST, cb, url )
    }
    
    @discardableResult
    public func put<T> ( _ cb: @escaping SyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addSyncMethod( .PUT, cb, url )
    }
    
    @discardableResult
    public func patch<T> ( _ cb: @escaping SyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addSyncMethod( .PATCH , cb, url )
    }

    @discardableResult
    public func delete<T> ( _ cb: @escaping SyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addSyncMethod( .DELETE, cb, url )
    }
    
    func addSyncMethod<T> ( _ method: EndpointMethod, _ cb: @escaping SyncEndpointRequestDispatcher<T>, _ url: String? ) -> Endpoint {
        methods[ method ] = MethodEndpoint(cb: cb, extraUrl: url != nil ? RouterPath( url! ): nil )
        return self
    }

    // Async methods
    @discardableResult
    public func get<T>( _ cb: @escaping AsyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addAsyncMethod( .GET, cb, url )
    }

    @discardableResult
    public func post<T>( _ cb: @escaping AsyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addAsyncMethod( .POST, cb, url )
    }
    
    @discardableResult
    public func put<T> ( _ cb: @escaping AsyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addAsyncMethod( .PUT, cb, url )
    }
    
    @discardableResult
    public func patch<T> ( _ cb: @escaping AsyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addAsyncMethod( .PATCH , cb, url )
    }

    @discardableResult
    public func delete<T> ( _ cb: @escaping AsyncEndpointRequestDispatcher<T>, _ url: String? = nil ) -> Endpoint {
        return addAsyncMethod( .DELETE, cb, url )
    }

    func addAsyncMethod<T> ( _ method: EndpointMethod, _ cb: @escaping AsyncEndpointRequestDispatcher<T>, _ url: String? ) -> Endpoint {
        methods[ method ] = MethodEndpoint(async_cb: cb, extraUrl: url != nil ? RouterPath( url! ): nil )
        return self
    }
/*
    public override func debug_info ( _ spaces: Int = 0, _ prefix: String = "" ) {
        super.debug_info( spaces, prefix )
        
        for (key, value ) in methods {
            // let wrapper = value.wrapper as! MethodEndpoint.EndpointWrapper<RouterContext>
            // let address = unsafeBitCast(wrapper.cb, to: Int.self)
            let str = "\(key.rawValue) \(value.extra_url?.debug_path() ?? "<no extra url>")"
            print( "".padding(toLength: spaces + 2, withPad: " ", startingAt: 0) + "-> " + str) // + "\(String(format: "%p", address))")
        }
    }
 */
}

public final class SystemEndpoint
{
    private let endpoint: Endpoint
    init(endpoint: Endpoint) { self.endpoint = endpoint }

    @discardableResult
    public func get<T>(_ cb: @escaping SyncEndpointRequestDispatcher<T>) -> SystemEndpoint {
        endpoint.methods[.GET] = MethodEndpoint(systemCb: cb)
        return self
    }
}

