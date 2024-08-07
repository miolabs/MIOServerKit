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
    }
    
    public func endpoint ( _ url: String ) -> Endpoint
    {
        // We have to unify concepts:
        // hook/ is hook as that is the convention URL uses
        // let relativeUrl = url.count > 1 && url.last == "/" ? String(url.dropLast()) : url
        let abs_path = root.value!.path.joining( RouterPath( url ) )
        let newEndpoint = Endpoint( abs_path )
        
        root.insert( newEndpoint )
        
        return newEndpoint
    }

    public func router ( _ url: String ) -> Router 
    {
        let path = RouterPath( url )
        var node = root.find( path )
        
//            let ret = Router( )
//            ret.root = node

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
            
//            return ret
//        }

        if node == nil {
            root.insert( EndpointTreeLeaf( url ) )
            node = root.find( path )
            return self
        }
        
        let ret = Router( )
        ret.root.value = EndpointTreeLeaf( )
        node!.insert_subnode( ret.root )
        
        return ret
    }
}

