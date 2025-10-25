
import Foundation
import MIOCore
import MIOCoreLogger


// MARK: - TreeNode
public class EndpointTreeNode
{
    var value: EndpointPath?
    var null_node: EndpointTreeNode? = nil
    var var_nodes: [EndpointTreeNode] = []
    var nodes: [String:EndpointTreeNode] = [:]
    var is_root: Bool = false  
    
    public init ( _ leaf: EndpointPath? = nil ) {
        value = leaf
    }
    
    func clone ( ) -> EndpointTreeNode 
    {
        let cloned = EndpointTreeNode( )
        
        cloned.value     = value
        cloned.nodes     = nodes
        cloned.var_nodes = var_nodes
        cloned.null_node = null_node
        
        return cloned
    }
    
    func clean ( ) 
    {
        value     = nil
        nodes     = [:]
        var_nodes = []
        null_node = nil
    }

// MARK: - Ins EndpointPath
    func insert ( _ ep: EndpointPath ) 
    {
        // CASO MINIMAL
        // HAS (null)
        // INS: /a/b/c
        // OUT: /a/b/c
        if nodes.count == 0 && value == nil && !is_root {
            value = ep
        } else {
            insert( EndpointTreeNode( ep ) )
        }
    }
    
    func insert ( _ node: EndpointTreeNode ) 
    {
        if value == nil || node.has_no_path_info() 
        {
          // CASE 1:
          // HAS:
          // (null)
          //   - entity
          //   - book
          // INS: /whatever
          // OUT:
          // (null)
          //   - entity
          //   - book
          //   - whatever
          //
          // CASE 1.1: We do insert the null_node
          insert_subnode( node )
        } 
        else
        {
            // var unused_vars: RouterPathVars = [:]
            let root_diff = value!.diff( node.value! /*, &unused_vars */ )
            
            // CASE 1:
            // HAS: /entity
            // INS: /book
            // OUT:
            // (null)
            //   - entity
            //   - book
            if root_diff.common.is_empty() 
            {
//                let cloned = self.clone( )
//                self.clean( )
//                
//                insert_subnode( cloned )
                insert_subnode( node )
            } 
            else
            {
                // CASE 2: (left is NOT empty)
                // HAS /entity/A     OR /entity/A/A1
                //             - A1
                // INS /entity/B
                // OUT:
                //   entity
                //     - A        OR - A/A1
                //       - A1
                //     - B
                //
                // CASE 2.1: (left is empty)
                // HAS /entity/A
                // INS /entity/A/A1
                // OUT:
                //   entity/A
                //       - A1
                node.value!.set_path( root_diff.right )

                if !root_diff.left.is_empty() 
                {
                    let cloned = self.clone( )
                    cloned.value!.set_path( root_diff.left )

                    self.clean( )
                    
                    value = EndpointPath( root_diff.common )
                    
                    insert_subnode( cloned )
                }
                
                insert_subnode( node )
            }
        }
    }

// MARK: - Ins Subnode    
    func insert_subnode ( _ n: EndpointTreeNode ) 
    {
        if n.has_no_path_info() 
        {
            // CASE:
            // HAS /hook/version
            // INS /hook
            // OUT:
            //  (null)
            //     - version
            //     - /
            if value != nil {
                let cloned = self.clone( )
                self.clean( )
                insert_subnode( cloned )
            }
            
            // overwrite? should we launch exception? No, this is normal behaviour. It happens, for instance, with endpoint("/"); endpoint("/version")
            null_node = n
        } 
        else if n.starts_with_var() {
            var_nodes.append( n )
        } 
        else
        {
            let key = n.index_part()
            
            n.value!.set_path( n.value!.path.drop_first() )
            
            if nodes[ key ] == nil {
                nodes[ key ] = n
            } else {
                nodes[ key ]!.insert( n )
            }
        }
    }

    public func index_part ( ) -> String { return value!.index_part( ) }
    public func starts_with_var ( ) -> Bool { return value?.starts_with_var() ?? false }
    public func starts_with_regex ( ) -> Bool { return value?.starts_with_regex() ?? false }
    public func has_no_path_info ( ) -> Bool { return value == nil || value!.path.is_empty() }
    
// MARK: - find      
    func find (  _ route: RouterPath ) -> EndpointTreeNode? 
    {
        if value == nil {
            return find_subnode( route )
        } 
        else
        {
            if route.is_empty() && value!.path.is_empty() {
                return self
            }
            
            let diff = value!.diff( route )

            if diff.common.is_empty() && !value!.path.is_empty() {
                return nil
            } else {
                if diff.right.is_empty() && diff.left.is_empty() {
                    return self
                }

                return find_subnode( diff.right )
            }
        }
    }
    
    
    func find_subnode ( _ route: RouterPath ) -> EndpointTreeNode? 
    {
        if route.is_empty() {
            return null_node?.find( route )
        } 
        else if route.starts_with_var()
        {
            for vnode in var_nodes {
                if let leaf = vnode.find( route ) {
                    return leaf
                }
            }
        } 
        else 
        {
            let key = route.index_part()
            
            if nodes.keys.contains( key ) {
                return nodes[ key ]!.find( route.drop_first( ) )
            }
        }
        
        return nil
    }

// MARK: - Match    
    public func match ( _ method: EndpointMethod, _ route: RouterPath, _ vars: inout RouterPathVars ) -> Endpoint?
    {
        if value == nil && route.is_empty() {
            return null_node?.match( method, route, &vars )
        }
        else if route.is_empty() && value!.path.is_empty() {
            if ( self.value as? Endpoint )?.methods.keys.contains( method ) != nil {
                return self.value as? Endpoint
            }
            return nil
        }
        else {
            return match_subnode( method, route, &vars )
//            let diff = value!.match( method, route, &vars )
//
//            if diff == nil || diff!.common.is_empty() {
//                return nil
//            } else {
//                if diff!.right.is_empty() && diff!.left.is_empty() {
//                    return self.value as? Endpoint
//                }
//
//                return match_subnode( method, diff!.right, &vars )
//            }
        }
    }
    
    
    func match_subnode ( _ method: EndpointMethod, _ route: RouterPath, _ vars: inout RouterPathVars ) -> Endpoint? 
    {
        let key = route.index_part()
        
        if nodes.keys.contains( key ) {
            return nodes[ key ]!.match( method, route.drop_first( ), &vars )
        } 
        else
        {
            for vnode in var_nodes {
                var leaf_vars: RouterPathVars = [:]
                
                if let leaf = vnode.match( method, route, &leaf_vars ) {
                    vars.merge( leaf_vars ){ (old,new) in new }
                    return leaf
                }
            }
        }
        
        // CASE:
        // (null)
        //   schema/:scheme([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})
        //     sync-annotations/:sync_id?
        //       -> GET
        //     all-sync-annotations//
        //       -> GET
        return null_node?.match( method, route, &vars )
    }
    
// MARK: - debug_info        
    public func debug_info ( _ spaces: Int = 0, _ prefixParam: String = "" ) 
    {
        func pad ( ) -> String {
            return "".padding(toLength: spaces, withPad: " ", startingAt: 0)
        }
        
        var prefix = prefixParam
        prefix = ""
        
        if value != nil {
            print( pad( ) + "value: ")
            value!.debug_info( spaces + 4, prefix )
        } else {
            print( pad( ) + "value: " + (prefix == "" ? "(null)" : prefix) )
        }

        if null_node != nil {
            print( pad( ) + "null_node: ")
            null_node!.debug_info( spaces + 4 )
        }
        else {
            print( pad( ) + "null_node: " + (prefix == "" ? "(null)" : prefix) )
        }
        
        print( pad( ) + "var_nodes: " + "\(var_nodes.count)" )
        for n in var_nodes {
            n.debug_info( spaces + 4 )
        }

        print( pad( ) + "nodes: " + "\(nodes.count)" )
        for (key,n) in nodes {
            print( pad( ) + "nodes[\(key)]" )
            n.debug_info( spaces + 4, key )
        }
       
    }
}

public class EndpointTree
{
    var subNodes: [String:EndpointTree] = [:]
    var pathNode:RouterPathNode? = nil
    var optionalPaths: [RouterPathNode]? = nil
    var endpoint:Endpoint? = nil
    
    func find( path: RouterPath ) -> (EndpointTree?, RouterPath) {
        if path.parts.isEmpty { return (self, path) }

        let key = path.parts.first?.key
        if key == nil { return (nil, path.drop_first()) }
        
        let node = subNodes[ key! ]
        if node == nil { return (self, path) }
                
        return node!.find(path: path.drop_first())
    }
    
    func insert( path: RouterPath ) -> EndpointTree {
        if path.parts.isEmpty { return self }
        
        // Check for optionals paths
        var path = path
        var path_node = path.parts.first
        while path_node != nil && path_node!.isOptional {
            if optionalPaths == nil { optionalPaths = [ ] }
            optionalPaths!.append( path_node! )
            path = path.drop_first()
            path_node = path.parts.first
        }
        
        // If we found optionals, we can not continue adding path nodes because optionals mark a leaf node.
        if optionalPaths?.isEmpty == false { return self }
        
        let node = EndpointTree()
        
        node.pathNode = path_node
        subNodes[ node.pathNode!.key ] = node
        
        return node.insert( path: path.drop_first() )
    }
    
    public func match ( _ path: RouterPath, _ vars: inout RouterPathVars ) -> Endpoint? {
        if path.parts.isEmpty { return endpoint }
                        
        let key = path.parts.first?.key
        if key == nil { return self.endpoint }
        
        var node = subNodes[ key! ]
        var path_node = path.parts.first
        
        // check the endpint in the sub nodes if not could be a var node
        if let ep = node?.match(path.drop_first(), &vars) { return ep }
        
        // Check for var nodes
        let var_nodes = subNodes.values.filter { $0.pathNode!.isVar }
        if path_node == nil { return nil }
        for n in var_nodes {
            if n.pathNode!.match( path_node! ) {
                vars[ n.pathNode!.key ] = path_node!.key
                node = n
                break
            }
        }
            
        // Check for optionals inside the node
        if node == nil && ( optionalPaths?.count ?? 0 ) > 0 {
            var path = path
            var node:EndpointTree? = nil
            for n in optionalPaths ?? [] {
                if path_node == nil { break }
                if n.match( path_node! ) {
                    vars[ n.key ] = path_node!.key
                    path = path.drop_first()
                    path_node = path.parts.first
                    node = self
                }
                else {
                    node = nil
                    break
                }
            }
            
            return node?.match(path.drop_first(), &vars)
        }
        
        return node?.match(path.drop_first(), &vars)
    }
    /*
    public func match_vars ( _ path: RouterPath, _ vars: inout RouterPathVars, _ pathVars: [RouterPathNode] = [], captureCount: inout Int ) -> Bool {
        guard let path_var = pathVars.first else { return true }
        guard let value = path.parts.first else { return path_var.is_optional }
        
        if path_var.match( value ) {
            vars[path_var.key] = value.key
            captureCount += 1
            return match_vars( path.drop_first(), &vars, Array(pathVars.dropFirst()), captureCount: &captureCount )
        }
        
        return false
    }
     */
}
