
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

        // Reject ambiguous registrations at startup. Two variable nodes at
        // the same path position are ambiguous if any input could match both;
        // the framework cannot decide which route to invoke. We use a
        // conservative rule:
        //   - two unconstrained vars              -> ambiguous
        //   - one constrained + one unconstrained -> ambiguous
        //   - two vars with identical patterns    -> ambiguous
        //   - two vars with different patterns    -> allowed (assumed disjoint)
        // Different-pattern overlap (e.g. one regex matching a subset of
        // another) is not detected — full regex intersection is intractable
        // and rarely a real-world concern.
        if let new_pn = node.pathNode, new_pn.isVar {
            for (_, existing) in subNodes {
                guard let existing_pn = existing.pathNode, existing_pn.isVar else { continue }
                if EndpointTree.varsAreAmbiguous( existing_pn, new_pn ) {
                    fatalError( """
                        Ambiguous route registration: ':\(existing_pn.key)' and \
                        ':\(new_pn.key)' at the same path position can both match \
                        the same input. The framework cannot decide which route \
                        to pick. Differentiate the regex constraints so they \
                        don't overlap, or merge into a single route and dispatch \
                        inside the handler.
                        """ )
                }
            }
        }

        subNodes[ node.pathNode!.key ] = node
        
        return node.insert( path: path.drop_first() )
    }

    /// Returns true if two variable path-nodes at the same position could both
    /// match the same input — see the ambiguity rule documented in `insert`.
    private static func varsAreAmbiguous( _ a: RouterPathNode, _ b: RouterPathNode ) -> Bool {
        // Two unconstrained vars: each matches everything.
        if a.regex == nil && b.regex == nil { return true }
        // One constrained, one unconstrained: the unconstrained one matches
        // every input the constrained one does (and more).
        if a.regex == nil || b.regex == nil { return true }
        // Two constrained vars: only flag if patterns are identical. Different
        // patterns are assumed disjoint by convention.
        return a.regex!.pattern == b.regex!.pattern
    }
    
    public func match ( _ path: RouterPath, _ vars: inout RouterPathVars ) -> Endpoint? {
        if path.parts.isEmpty { return endpoint }
                        
        let key = path.parts.first?.key
        if key == nil { return self.endpoint }
        
        var node = subNodes[ key! ]
        var path_node = path.parts.first
        
        // check the endpint in the sub nodes if not could be a var node
        if let ep = node?.match(path.drop_first(), &vars) { return ep }
        
        // Check for var nodes. Sibling vars at the same path position are
        // guaranteed to be unambiguous (enforced by `insert(path:)` at
        // registration time), so dictionary iteration order is fine here —
        // at most one of them can match any given input.
        let var_nodes = subNodes.values.filter { $0.pathNode!.isVar }
        if path_node == nil { return nil }
        for n in var_nodes {
            if n.pathNode!.match( path_node! ) {
                // Capture the segment verbatim (`name`), not `key`: key has
                // had any `(...)` stripped by the regex-constraint parsing,
                // which is pattern syntax — request values like
                // "chargeToAccount(_:)" must arrive intact.
                vars[ n.pathNode!.key ] = path_node!.name
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
                    vars[ n.key ] = path_node!.name
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
