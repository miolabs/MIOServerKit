//
//  Router.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
// import NIO
import NIOHTTP1


public typealias DispatchResponse = ( status: HTTPResponseStatus, response: Any )

public protocol RouterProtocol {
    func dispatch ( _ method: EndpointMethod
                  , _ path: RouterPath
                  , _ request: inout RouterRequest
                  , _ response: inout RouterResponse
                  , _ onSuccess: @escaping ( _ res: Any? ) throws -> Void
                  ) throws -> Bool
}

open class Router<T: RouterContextProtocol>: RouterProtocol
{
    public  var root: EndpointTreeNode<T>

    public init ( ) {
        root = EndpointTree( )
    }
    
    public func endpoint ( _ url: String ) -> Endpoint<T>
    {
        // We have to unify concepts:
        // hook/ is hook as that is the convention URL uses
        // let relativeUrl = url.count > 1 && url.last == "/" ? String(url.dropLast()) : url
        
        let newEndpoint = Endpoint<T>( url )
        
        root.insert( newEndpoint )
        
        return newEndpoint
    }

    public func router ( _ url: String ) -> Router {
        if let node = root.find( RouterPath( url ) ) {
            let ret = Router( )
            ret.root = node

//            for n in node.nodes {
//                if let empty_node = n as? EndpointTreeNode {
//                    if empty_node.path.is_empty() {
//                        ret.root = empty_node
//
//                        return ret
//                    }
//                }
//            }
//
//            let empty_node = EndpointTreeNode()
//            empty_node.set_path( node.path )
//            node.insert(empty_node)
//            ret.root = empty_node
            
            return ret
        }
        
        let ret = Router( )
        
        root.insert( EndpointTreeLeaf( url ) )
        ret.root = root.find( RouterPath( url ) )!
        
        return ret
    }
    
    public func dispatch ( _ method: EndpointMethod
                         , _ path: RouterPath
                         , _ request: inout RouterRequest
                         , _ response: inout RouterResponse
                         , _ onSuccess: @escaping ( _ res: Any? ) throws -> Void
                         ) throws -> Bool {
        var route_vars: RouterPathVars = [:]
        
        let endpoint = root.match( method, path, &route_vars )

        if endpoint != nil
        {
            request.parameters = route_vars
 
            var ctx = T.init()
            ctx.request = request
            ctx.response = response
                
            try ctx.willExectute()
                
            let result = try endpoint!.methods[ method ]!.cb( ctx )
            
            try onSuccess( result )
            
            try ctx.didExecute()

            return true
        }
        
        return false
//        else {
//            return (status: .notFound, response: "NOT FOUND: \(method.rawValue) \(path)" )
//        }
    }

}

