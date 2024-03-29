//
//  File.swift
//  
//
//  Created by David Trallero on 21/10/21.
//

import Foundation

open class MSKRouter<T> {
    public  var root: EndpointTreeNode<T>

    public init ( ) {
        root = EndpointTree<T>( )
    }
    

    public func endpoint ( _ url: String ) -> Endpoint<T> {
        // We have to unify concepts:
        // hook/ is hook as that is the convention URL uses
        // let relativeUrl = url.count > 1 && url.last == "/" ? String(url.dropLast()) : url
        
        let newEndpoint = Endpoint<T>( url )
        
        root.insert( newEndpoint )
        
        return newEndpoint
    }

    public func router ( _ url: String ) -> MSKRouter<T> {
        if let node = root.find( RouterPath( url ) ) {
            let ret = MSKRouter<T>( )
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
        
        let ret = MSKRouter<T>( )
        
        root.insert( EndpointTreeLeaf( url ) )
        ret.root = root.find( RouterPath( url ) )!
        
        return ret
    }
}

