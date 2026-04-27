
import Foundation
import MIOCore
import MIOCoreLogger

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
        
        // Check for var nodes. Prefer those with a regex constraint over
        // generic ones — a regex-constrained variable is more specific, so
        // it should win when both could match. Without this ordering the
        // result depends on dictionary iteration order, which Swift doesn't
        // guarantee.
        let regex_vars   = subNodes.values.filter { $0.pathNode?.isVar == true && $0.pathNode?.regex != nil }
        let generic_vars = subNodes.values.filter { $0.pathNode?.isVar == true && $0.pathNode?.regex == nil }
        let var_nodes    = regex_vars + generic_vars
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
