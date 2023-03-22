//
//  Endpoint.swift
//
//
//  Created by David Trallero on 21/10/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import MIOCore

public typealias RouterPathVars = [String:String]

public class RouterPathNode: Equatable
{
    var name: String
    var key: String
    var is_var: Bool
    var is_optional: Bool
    var regex: NSRegularExpression?
    
    
    public init ( _ n : String ) {
        name = n
        is_var = n.first == ":"
        
        if let from = name.firstIndex( of: "(" ) {
            key = String( name[..<from] )
            
            let pattern = name.dropFirst( from.utf16Offset(in: name ) )
            do {
                regex = try NSRegularExpression( pattern: String( pattern ) )
            } catch {
                NSLog( "ERROR IN REGEX: \(pattern)" )
            }
        } else {
            regex = nil
            key = name
        }
        
        if is_var {
            key = String( key.dropFirst() )
        }

        is_optional = key.last == "?"

        if is_optional {
            key = String( key.dropLast() )
        }
    }
    
    
    public func match ( _ node: RouterPathNode ) -> Bool {
        return is_var && node.is_var ? name == node.name
             : regex != nil ?
               regex!.firstMatch( in: node.name, options: [], range: NSRange( location: 0, length: node.name.count ) ) != nil
             : is_var || name == node.name
    }
}


public func ==( left:RouterPathNode, right:RouterPathNode ) -> Bool {
    return left.name == right.name
}


public typealias RouterPathDiff = ( common: RouterPath, left: RouterPath, right: RouterPath )

public class RouterPath
{
    var parts: [RouterPathNode]

    init ( _ path: String = "" ) {
        parts = path.components(separatedBy: "/").filter{ $0 != "" }.map{ RouterPathNode( $0 ) }
    }

    init ( from: [RouterPathNode] ) {
        parts = from
    }
    
    func is_empty ( ) -> Bool { return parts.count == 0 }
    public func index_part ( ) -> String { return parts[ 0 ].name }
    public func starts_with_var ( ) -> Bool { return parts.count > 0 && parts[ 0 ].is_var }
    public func starts_with_regex ( ) -> Bool { return parts.count > 0 && parts[ 0 ].regex != nil }
    public func drop_first ( ) -> RouterPath { return RouterPath( from: Array( parts.dropFirst() ) ) }
    
    func match ( _ rhs: RouterPath, _ vars: inout RouterPathVars ) -> RouterPathDiff? {
        var common: [RouterPathNode] = []
        
        let optional_parts = parts.filter{ p in p.is_optional }.count
        
        if parts.count - optional_parts > rhs.parts.count { return nil }
        
        for i in Array(0..<parts.count) {
            let p = parts[ i ]
            
            if i >= rhs.parts.count {
                if p.is_optional {
                    common.append( p )
                    continue
                } else {
                    return nil
                }
            }
            
            if !p.match( rhs.parts[ i ] ) {
                return nil
            }
            
            if p.is_var {
                vars[ p.key ] = rhs.parts[ i ].name
            }
            
            common.append( p )
        }
        
        let j = min( parts.count, rhs.parts.count )
        
        return ( common: RouterPath( from: common )
               , left  : RouterPath( from: Array( parts[ common.count ..< parts.count ] ) )
               , right : RouterPath( from: Array( rhs.parts[  j ..< rhs.parts.count  ] ) ) )
    }
    

    func diff ( _ rhs: RouterPath ) -> RouterPathDiff {
        var common: [RouterPathNode] = []
        let max_len = min( parts.count, rhs.parts.count )
        
        func rest ( _ j: Int ) -> RouterPathDiff {
            return ( common: RouterPath( from: common )
                   , left  : RouterPath( from: Array( parts[ j ..< parts.count ] ) )
                   , right : RouterPath( from: Array( rhs.parts[  j ..< rhs.parts.count  ] ) ) )
        }
        
        for i in Array(0..<max_len) {
            let left  = parts[ i ]
            let right = rhs.parts[ i ]
            
            if left.name != right.name {
                return rest( i )
            }
            
            common.append( parts[ i ] )
        }
        
        return rest( max_len )
    }
    
    public func join ( _ extra: RouterPath ) {
        parts.append(contentsOf: extra.parts )
    }
    
    func debug_path ( ) -> String {
        return parts.count == 0 ? "/"
             : parts.map{ $0.name }.joined(separator: "/")
    }
}

public enum EndpointMethod: String
{
    case GET     = "GET"
    case POST    = "POST"
    case PUT     = "PUT"
    case PATCH   = "PATCH"
    case DELETE  = "DELETE"
    case OPTIONS = "OPTIONS"
}

public class EndpointTreeLeaf
{
    var path: RouterPath

    public init ( _ url: String = "" ) {
        path = RouterPath( url )
    }

    public init ( _ partial_path: RouterPath ) {
        path = partial_path
    }
    
    @discardableResult
    public func set_path ( _ new_path: RouterPath ) -> EndpointTreeLeaf {
        path = new_path
        return self
    }
    
    public func match ( _ method: EndpointMethod, _ url: RouterPath, _ vars: inout RouterPathVars ) -> RouterPathDiff? {
        return path.match( url, &vars )
    }
    
    public func diff ( _ node: EndpointTreeLeaf /*, _ vars: inout RouterPathVars */ ) -> RouterPathDiff {
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


public class EndpointTreeNode
{
    var value: EndpointTreeLeaf?
    var nodes: [String:EndpointTreeNode] = [:]
    var var_nodes: [EndpointTreeNode] = []
    var null_node: EndpointTreeNode? = nil
    
    public init ( _ leaf: EndpointTreeLeaf? = nil ) {
        value = leaf
    }
    
    func clone ( ) -> EndpointTreeNode {
        let cloned = EndpointTreeNode( )
        
        cloned.value     = value
        cloned.nodes     = nodes
        cloned.var_nodes = var_nodes
        cloned.null_node = null_node
        
        return cloned
    }
    
    func clean ( ) {
        value     = nil
        nodes     = [:]
        var_nodes = []
        null_node = nil
    }

    func insert ( _ ep: EndpointTreeLeaf ) {
        // CASO MINIMAL
        // HAS (null)
        // INS: /a/b/c
        // OUT: /a/b/c
        if nodes.count == 0 && value == nil {
            value = ep
        } else {
            insert( EndpointTreeNode( ep ) )
        }
    }
    
    func insert ( _ node: EndpointTreeNode ) {
        if value == nil || node.is_null_node() {
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
        } else {
            // var unused_vars: RouterPathVars = [:]
            let root_diff = value!.diff( node.value! /*, &unused_vars */ )
            
            // CASE 1:
            // HAS: /entity
            // INS: /book
            // OUT:
            // (null)
            //   - entity
            //   - book
            if root_diff.common.is_empty() {
                let cloned = self.clone( )
                self.clean( )
                
                insert_subnode( cloned )
                insert_subnode( node )
            } else {
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

                if !root_diff.left.is_empty() {
                    let cloned = self.clone( )
                    cloned.value!.set_path( root_diff.left )

                    self.clean( )
                    
                    value = EndpointTreeLeaf( root_diff.common )
                    
                    insert_subnode( cloned )
                }
                
                insert_subnode( node )
            }
        }
    }

    
    // Leaf deriva de node? Y es el node el que tiene el Path!??
    func insert_subnode ( _ n: EndpointTreeNode ) {
        if n.is_null_node() {
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
            
            // overwrite? should we launch exception?
            null_node = n
        } else if n.starts_with_var() {
            var_nodes.append( n )
        } else {
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
    public func is_null_node ( ) -> Bool { return value == nil || value!.path.is_empty() }
    
    func find (  _ route: RouterPath ) -> EndpointTreeNode? {
        if value == nil {
            return find_subnode( route )
        } else {
            if route.is_empty() && value!.path.is_empty() {
                return self
            }
            
            let diff = value!.diff( route )

            if diff.common.is_empty() {
                return nil
            } else {
                if diff.right.is_empty() && diff.left.is_empty() {
                    return self
                }

                return find_subnode( diff.right )
            }
        }
    }
    
    
    func find_subnode ( _ route: RouterPath ) -> EndpointTreeNode? {
        if route.is_empty() {
            return null_node?.find( route )
        } else if route.starts_with_var() {
            for vnode in var_nodes {
                if let leaf = vnode.find( route ) {
                    return leaf
                }
            }
        } else {
            let key = route.index_part()
            
            if nodes.keys.contains( key ) {
                return nodes[ key ]!.find( route.drop_first( ) )
            }
        }
        
        return nil
    }

    
    func match ( _ method: EndpointMethod, _ route: RouterPath, _ vars: inout RouterPathVars ) -> Endpoint?
    {
        if value == nil {
            return match_subnode( method, route, &vars )
        } else {
            if route.is_empty() && value!.path.is_empty() {
                return self.value as? Endpoint
            }
            
            let diff = value!.match( method, route, &vars )

            if diff == nil || diff!.common.is_empty() {
                return nil
            } else {
                if diff!.right.is_empty() && diff!.left.is_empty() {
                    return self.value as? Endpoint
                }

                return match_subnode( method, diff!.right, &vars )
            }
        }
    }
    
    
    func match_subnode ( _ method: EndpointMethod, _ route: RouterPath, _ vars: inout RouterPathVars ) -> Endpoint? {
        if route.is_empty() {
            return null_node?.match( method, route, &vars )
        }
        
        let key = route.index_part()
        
        if nodes.keys.contains( key ) {
            return nodes[ key ]!.match( method, route.drop_first( ), &vars )
        } else {
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
    
    
    public func debug_info ( _ spaces: Int = 0, _ prefix: String = "" ) {
        func pad ( ) -> String {
            return "".padding(toLength: spaces, withPad: " ", startingAt: 0)
        }
        
        if value != nil {
            value!.debug_info( spaces, prefix )
        } else {
            print( pad( ) + (prefix == "" ? "(null)" : prefix) )
        }
        
        for (key,n) in nodes {
            n.debug_info( spaces + 2, key + "/" )
        }
        
        for n in var_nodes {
            n.debug_info( spaces + 2 )
        }
        
        if null_node != nil {
            null_node!.debug_info( spaces + 2 )
        }
    }
}


public typealias EndpointRequestDispatcher = ( _ context: RouterContextProtocol ) throws -> Any?

public class Endpoint : EndpointTreeLeaf
{
//    public struct MethodEndpoint<T>
//    {
//        var cb: EndpointRequestDispatcher<T>
//        var extra_url: RouterPath?
//
//        init(cb: @escaping ( _ context: T) throws -> Any?, extra_url: RouterPath? = nil ) {
//            self.cb = cb
//            self.extra_url = extra_url
//        }
//
//        func contextType ( ) -> T.Type {
//           return T.self
//        }
//    }
    
    public var methods: [ EndpointMethod: (cb: EndpointRequestDispatcher, extra_url: RouterPath?, ct: RouterContextProtocol.Type) ] = [:]
        
    @discardableResult
    public func get( _ cb: @escaping EndpointRequestDispatcher, _ url: String? = nil,_ ct: RouterContextProtocol.Type = RouterContext.self ) -> Endpoint {
        return add_method( .GET  , cb, url, ct )
    }

    @discardableResult
    public func post( _ cb: @escaping EndpointRequestDispatcher, _ url: String? = nil, _ ct: RouterContextProtocol.Type ) -> Endpoint { return add_method( .POST  , cb, url, ct )
    }
    
    @discardableResult
    public func put ( _ cb: @escaping EndpointRequestDispatcher, _ url: String? = nil, contextType ct: RouterContextProtocol.Type ) -> Endpoint {
        return add_method( .PUT, cb, url, ct )
    }
    
//    @discardableResult
//    public func patch  ( _ cb: @escaping EndpointRequestDispatcher, _ url: String? = nil ) -> Endpoint { return add_method( .PATCH , cb, url ) }
//
//    @discardableResult
//    public func delete ( _ cb: @escaping EndpointRequestDispatcher, _ url: String? = nil ) -> Endpoint { return add_method( .DELETE, cb, url ) }
    
    func add_method( _ method: EndpointMethod, _ cb: @escaping EndpointRequestDispatcher, _ url: String?, _ ct: RouterContextProtocol.Type) -> Endpoint {
        methods[ method ] = (cb: cb, extra_url: url != nil ? RouterPath( url! ): nil, ct: ct )
        return self
    }

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
            let str = "\(key.rawValue) \(value.extra_url?.debug_path() ?? "")"
            print( "".padding(toLength: spaces + 2, withPad: " ", startingAt: 0) + "-> " + str)
        }
    }
}


public class EndpointTree : EndpointTreeNode { }
