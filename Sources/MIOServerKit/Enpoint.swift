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

public typealias SyncEndpointRequestDispatcher<T:RouterContext> = ( _ context: T ) throws -> Any?
public typealias AsyncEndpointRequestDispatcher<T:RouterContext> = ( _ context: T ) async throws -> Any?

public typealias MethodEndpointCompletionBlock = ( Any?, Error?, RouterContext? ) -> Void

protocol MethodEndpointExecutionProtocol {
    func run( _ request:RouterRequest, _ response:RouterResponse, _ completion: @escaping MethodEndpointCompletionBlock )
}

public struct MethodEndpoint
{
    // Wrapper for sync callbacks
    struct SyncEndpointWrapper<T : RouterContext > : MethodEndpointExecutionProtocol
    {
        let cb: SyncEndpointRequestDispatcher<T>
        
        init ( _ cb: @escaping SyncEndpointRequestDispatcher<T> ) {
            self.cb = cb
        }
        
        func run( _ request:RouterRequest, _ response:RouterResponse, _ completion: MethodEndpointCompletionBlock )
        {
            do {
                let ctx = try T.init( request, response )
                try ctx.willExecute()
                let result = try cb( ctx )
                try ctx.didExecute()
                
                completion( result, nil, ctx )
                Log.debug( "Syncrhonous endpoint executed successfully." )
            }
            catch {
                Log.error( "\(error)" )
                completion( nil, error, nil )
            }
        }
    }
        
    // Wrapper for async callbacks
    struct AsyncEndpointWrapper<T : RouterContext > : MethodEndpointExecutionProtocol
    {
        let cb: AsyncEndpointRequestDispatcher<T>
        
        init ( _ cb: @escaping AsyncEndpointRequestDispatcher<T> ) {
            self.cb = cb
        }
        
        func run( _ request:RouterRequest, _ response:RouterResponse, _ completion: @escaping MethodEndpointCompletionBlock )
        {
            Task {
                do {
                    let ctx = try T.init( request, response )
                    try await ctx.willExecute()
                    let result = try await cb( ctx )
                    try await ctx.didExecute()
                    
                    completion( result, nil, ctx )
                    Log.debug( "Asyncrhonous endpoint executed successfully." )
                }
                catch {
                    Log.error( "\(error)" )
                    completion( nil, error, nil )
                }
            }
        }
    }
    
    var wrapper: any MethodEndpointExecutionProtocol
    var extra_url: RouterPath?

    // Init for sync callbacks
    init <T:RouterContext>(cb: @escaping ( _ context: T ) throws -> Any?, extra_url: RouterPath? = nil ) {
        wrapper = SyncEndpointWrapper( cb )
        self.extra_url = extra_url
    }
    
    // Init for async callbacks
    init <T:RouterContext>(async_cb: @escaping AsyncEndpointRequestDispatcher<T>, extra_url: RouterPath? = nil ) {
        wrapper = AsyncEndpointWrapper( async_cb )
        self.extra_url = extra_url
    }

    public func run( _ request:RouterRequest, _ response:RouterResponse, _ completion: @escaping MethodEndpointCompletionBlock ) {
        wrapper.run( request, response, completion )
    }
}

// MARK: - Endpoint
public class Endpoint// : EndpointPath
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
        methods[ method ] = MethodEndpoint(cb: cb, extra_url: url != nil ? RouterPath( url! ): nil )
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
        methods[ method ] = MethodEndpoint(async_cb: cb, extra_url: url != nil ? RouterPath( url! ): nil )
        return self
    }
/*
    override public func match ( _ method: EndpointMethod, _ url: RouterPath, _ vars: inout RouterPathVars ) -> RouterPathDiff? {
        if methods[ method ] == nil { return nil }

        var super_vars: RouterPathVars = [:]

        if var ret = super.match( method, url, &super_vars ) {
            let entry = methods[ method ]
            var extra_vars: RouterPathVars = [:]

            if entry?.extra_url != nil {
                if !ret.right.is_empty() {
                    if let extra_ret = entry?.extra_url!.match( ret.right, &extra_vars ) {
                        ret.common.join( extra_ret.common )
                        ret.right = extra_ret.right
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            }

            vars.merge( super_vars ){ (old,new) in new }
            vars.merge( extra_vars ){ (old,new) in new }

            return ret
        }

        return nil
    }
    
    
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

