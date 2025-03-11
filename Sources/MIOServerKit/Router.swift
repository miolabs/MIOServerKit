//
//  Router.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation

open class Router
{
    public var root: EndpointTreeNode

    public init ( ) {
        root = EndpointTree( )
        root.is_root = true
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
        print("nop")
    }

    public func endpoint ( _ url: String ) -> Endpoint
    {
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
    }

    public func router ( _ url: String ) -> Router 
    {
        let path = RouterPath( url )
        var node = root.find( path )
        
        if node == nil {
            print("router: node '\(url)' NOT found")
            root.insert( EndpointPath( url ) )
            node = root.find( path )
            // if node == nil {
            //     print(" node for path still not found")
            // }
            //return node!.value as! Router
            //return self
        }
        else {
            print("router: node '\(url)' was found")
        }
        
        let ret = Router( )
        ret.root.is_root = false
        ret.root = node!
        //ret.root.value = EndpointPath( )
        //node!.insert_subnode( ret.root )
        
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

