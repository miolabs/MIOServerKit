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
    
    // public func endpointOld ( _ url: String ) -> Endpoint
    // {
    //     // We have to unify concepts:
    //     // hook/ is hook as that is the convention URL uses
    //     // let relativeUrl = url.count > 1 && url.last == "/" ? String(url.dropLast()) : url
    //     let abs_path = root.value!.path.joining( RouterPath( url ) )
    //     let newEndpoint = Endpoint( abs_path )
        
    //     root.insert( newEndpoint )
        
    //     return newEndpoint
    // }

    public func nop() -> Void  // just to be used in tests to set breakpoints and dump the state of this object
    {
        Log.debug("nop")
    }

    public func endpoint ( _ url: String ) -> Endpoint
    {
        /*
        var abs_path : RouterPath
        if (root.value == nil){
            abs_path = RouterPath( url )
        }
        else {
            // We have to unify concepts:
            // hook/ is hook as that is the convention URL uses
            // let relativeUrl = url.count > 1 && url.last == "/" ? String(url.dropLast()) : url
            abs_path = root.value!.path.joining( RouterPath( url ) )
        }
        let newEndpoint = Endpoint( abs_path )
        
        root.insert( newEndpoint )
        
        return newEndpoint
        */
        
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
/*
        let path = RouterPath( url )
        var node = root.find( path )
        Log.debug("Node '\(url)' \(node == nil ? "NOT" : "")found")
        
        if node == nil {
            root.insert( EndpointPath( url ) )
            node = root.find( path )
            // if node == nil {
            //     print(" node for path still not found")
            // }
            //return node!.value as! Router
            //return self
        }
        
        let ret = Router( )
        ret.root.is_root = false
        ret.root = node!
        //ret.root.value = EndpointPath( )
        //node!.insert_subnode( ret.root )
        
        return ret
 */
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


//     public func router ( _ url: String ) -> Router 
//     {
//         let path = RouterPath( url )
//         var node = root.find( path )
        
// //            let ret = Router( )
// //            ret.root = node

// //            for n in node.nodes {
// //                if let empty_node = n as? EndpointTreeNode {
// //                    if empty_node.path.is_empty() {
// //                        ret.root = empty_node
// //
// //                        return ret
// //                    }
// //                }
// //            }
// //
// //            let empty_node = EndpointTreeNode()
// //            empty_node.set_path( node.path )
// //            node.insert(empty_node)
// //            ret.root = empty_node
            
// //            return ret
// //        }

//         if node == nil {
//             print("router: node '\(url)' NOT found")
//             root.insert( EndpointPath( url ) )
//             node = root.find( path )
//             if node == nil {
//                 print(" node for path still not found")
//             }
//             return self
//         }
//         else {
//             print("router: node '\(url)' was found")
//         }
        
//         let ret = Router( )
//         ret.root.value = EndpointPath( )
//         node!.insert_subnode( ret.root )
        
//         return ret
//     }
}

