//
//  Router.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import MIOCoreLogger

open class Router
{
    public var root: EndpointTree

    public init ( ) {
        root = EndpointTree( )
    }
    
    public func nop() -> Void { // just to be used in tests to set breakpoints and dump the state of this object
        Log.debug("nop")
    }

    public func systemEndpoint(_ url: String) -> SystemEndpoint {
        return SystemEndpoint(endpoint: endpoint(url))
    }
    
    public func endpoint ( _ url: String ) -> Endpoint
    {
        let path = RouterPath( url )
        var (node,diff_path) = root.find( path: path )
        if node == nil {
            node = root.insert( path: path )
        }
        else {
            node = node!.insert( path: diff_path )
        }
        
        node!.endpoint = Endpoint()
        return node!.endpoint!
    }

    public func router ( _ url: String ) -> Router 
    {
        let path = RouterPath( url )
        var (node,diff) = root.find( path: path )
        Log.debug("Node '\(url)' \(node == nil ? "NOT" : "")found")
        
        if node == nil {
            node = root.insert( path: path )
        }
        else {
            node = node!.insert( path: diff )
        }
        
        let ret = Router( )
        ret.root = node!
        return ret
    }

}

