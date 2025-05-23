//
//  RouterPath.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 20/5/25.
//
import Foundation
import MIOCore
import MIOCoreLogger

public typealias RouterPathVars = [String:String]

public final class RouterPathNode: Equatable
{
    var name: String
    var key: String
    var isVar: Bool
    var isOptional: Bool
    var regex: NSRegularExpression?
    
    
    public init ( _ n : String ) {
        name = n
        isVar = n.first == ":"
        
        if let from = name.firstIndex( of: "(" ), let to = name.lastIndex( of: ")" ) {
            let range = from...to
            key = name.replacingCharacters(in: range, with: "")
            
            let pattern = String( name[range] )
            do {
                regex = try NSRegularExpression( pattern: pattern )
            } catch {
                Log.error( "ERROR IN REGEX: \(pattern)" )
            }
        } else {
            regex = nil
            key = name
        }
        
        if isVar {
            key = String( key.dropFirst() )
        }

        isOptional = key.last == "?"

        if isOptional {
            key = String( key.dropLast() )
        }
    }
        
    public func match ( _ node: RouterPathNode ) -> Bool {
        return isVar && node.isVar ? name == node.name
             : regex != nil ?
               regex!.firstMatch( in: node.name, options: [], range: NSRange( location: 0, length: node.name.count ) ) != nil
             : isVar || name == node.name
    }
}

extension RouterPathNode: CustomDebugStringConvertible {
    public var debugDescription: String {
        return """
                name: \(name)
                key: \(key)
                isVar: \(isVar)
                isOptional: \(isOptional)
                regex: \(regex?.description ?? "nil")
                """
    }
}



public func ==( left:RouterPathNode, right:RouterPathNode ) -> Bool {
    return left.name == right.name
}


public typealias RouterPathDiff = ( common: RouterPath, left: RouterPath, right: RouterPath )

public class RouterPath
{
    var parts: [RouterPathNode]

    public init ( _ path: String = "" ) {
        // /usuarios/perfil/config ->  ["", "usuarios", "perfil", "config"] -> ["usuarios", "perfil", "config"] ->
        // -> [RouterPathNode("usuarios"), RouterPathNode("perfil"), RouterPathNode("config")]
        parts = path.components(separatedBy: "/").compactMap{ $0 != "" ? RouterPathNode( $0 ) : nil }
    }

    public init ( from: [RouterPathNode] ) {
        parts = from
    }
    
    func is_empty ( ) -> Bool { return parts.count == 0 }
    
    public func index_part ( ) -> String { return parts[ 0 ].name }
    public func starts_with_var ( ) -> Bool { return parts.count > 0 && parts[ 0 ].isVar }
    public func starts_with_regex ( ) -> Bool { return parts.count > 0 && parts[ 0 ].regex != nil }
    public func drop_first ( ) -> RouterPath { return RouterPath( from: Array( parts.dropFirst() ) ) }
    public func drop_first ( _ number: Int = 1 ) -> RouterPath { return RouterPath( from: Array( parts.dropFirst( number ) ) ) }
    
    func match ( _ rhs: RouterPath, _ vars: inout RouterPathVars ) -> RouterPathDiff? {
        var common: [RouterPathNode] = []
        
        let optional_parts = parts.filter{ p in p.isOptional }.count
        
        if parts.count - optional_parts > rhs.parts.count { return nil }
        
        for i in Array(0..<parts.count) {
            let p = parts[ i ]
            
            if i >= rhs.parts.count {
                if p.isOptional {
                    common.append( p )
                    continue
                } else {
                    return nil
                }
            }
            
            if !p.match( rhs.parts[ i ] ) {
                return nil
            }
            
            if p.isVar {
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

    public func joining ( _ extra: RouterPath ) -> RouterPath {
        return RouterPath( from: parts + extra.parts )
    }

    func debug_path ( ) -> String {
        return parts.count == 0 ? "/" : parts.map{ $0.name }.joined(separator: "/")
        // let regularAnswer = parts.count == 0 ? "Empty (will be /)" : parts.map{ $0.name }.joined(separator: "/")
        // var debugAnswer = "  # parts: \(parts.count) "
        // for i in Array(0..<parts.count) {
        //     let p = parts[ i ]
        //     debugAnswer += " '\(p.name)' "
        // }
        // return regularAnswer + " -> " + debugAnswer
    }
}
