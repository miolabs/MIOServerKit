//
//  EndpointAnnotation.swift
//  MIOServerKit
//
//  Shared parser for the @Endpoint attribute syntax. Used both by the
//  compiler macro (validation only) and by the generate-endpoints tool
//  (route file generation), so the two never disagree on what is valid.
//

import SwiftSyntax

public struct EndpointAnnotation: Equatable
{
    public static let attributeName = "Endpoint"

    /// HTTP methods the runtime `Endpoint` builder supports.
    public static let supportedMethods = [ "get", "post", "put", "patch", "delete" ]

    /// Lowercase method names, in declaration order. Defaults to ["get"].
    public var methods: [String]
    public var path: String

    public enum ParseError: Error, Equatable, CustomStringConvertible
    {
        case missingPath
        case invalidPath
        case unsupportedMethod(String)
        case emptyMethods
        case unknownPathPattern(String)

        public var description: String {
            switch self {
            case .missingPath:                  return "@Endpoint requires a 'path:' string literal"
            case .invalidPath:                  return "@Endpoint path must be a plain string literal (no interpolation)"
            case .unsupportedMethod(let m):     return "@Endpoint does not support method '.\(m)'. Supported: \(supportedMethods.map { ".\($0)" }.joined(separator: ", "))"
            case .emptyMethods:                 return "@Endpoint methods array cannot be empty"
            case .unknownPathPattern(let p):    return "@Endpoint path uses unknown path pattern '\(p)'. Supported: \(EndpointPathPattern.known.keys.sorted().map { "{\($0)}" }.joined(separator: ", "))"
            }
        }

        var supportedMethods: [String] { EndpointAnnotation.supportedMethods }
    }

    public init( methods: [String], path: String ) {
        self.methods = methods
        self.path = path
    }

    /// Returns true when the attribute is spelled `@Endpoint`.
    public static func matches( _ node: AttributeSyntax ) -> Bool {
        return node.attributeName.as( IdentifierTypeSyntax.self )?.name.text == attributeName
    }

    /// Parses `@Endpoint( [.get, .post], path: "/api/schema/:schema" )`.
    /// The methods array is optional and defaults to `[.get]`.
    public static func parse( from node: AttributeSyntax ) throws -> EndpointAnnotation
    {
        var methods: [String] = []
        var path: String? = nil

        for arg in node.arguments?.as( LabeledExprListSyntax.self ) ?? [] {
            switch arg.label?.text {
            case "path":
                path = try stringLiteral( arg.expression )
            case nil:
                if let array = arg.expression.as( ArrayExprSyntax.self ) {
                    for element in array.elements {
                        guard let name = element.expression.as( MemberAccessExprSyntax.self )?.declName.baseName.text else {
                            continue
                        }
                        let method = name.lowercased()
                        guard supportedMethods.contains( method ) else { throw ParseError.unsupportedMethod( name ) }
                        if methods.contains( method ) == false { methods.append( method ) }
                    }
                    if methods.isEmpty { throw ParseError.emptyMethods }
                }
                else if path == nil {
                    // Be lenient: accept an unlabeled trailing string as the path.
                    path = try stringLiteral( arg.expression )
                }
            default:
                break
            }
        }

        guard let p = path, p.isEmpty == false else { throw ParseError.missingPath }

        for case .pattern( let name ) in EndpointPathPattern.split( p ) where EndpointPathPattern.known[ name ] == nil {
            throw ParseError.unknownPathPattern( name )
        }

        return EndpointAnnotation( methods: methods.isEmpty ? ["get"] : methods, path: p )
    }

    static func stringLiteral( _ expression: ExprSyntax ) throws -> String
    {
        guard let literal = expression.as( StringLiteralExprSyntax.self ) else { throw ParseError.missingPath }
        guard literal.segments.count == 1,
              let segment = literal.segments.first?.as( StringSegmentSyntax.self )
        else { throw ParseError.invalidPath }
        return segment.content.text
    }
}


/// Named patterns for path variables: `:scheme{uuid}`.
///
/// An @Endpoint path must be a plain string literal, so it cannot interpolate
/// the regex constants a hand-written route uses (`":scheme\(uuidRegexRoute)"`).
/// A pattern name stands for one of those constants: the generated file emits
/// the very same interpolation, so an annotated route and a hand-written one
/// resolve to the same route node and the regex keeps a single definition.
public enum EndpointPathPattern
{
    /// Pattern name -> the Swift constant (declared in MIOServerKit) it expands to.
    public static let known: [String: String] = [
        "uuid": "uuidRegexRoute",
    ]

    public enum Piece: Equatable
    {
        case text(String)
        case pattern(String)
    }

    /// Splits a path into literal text and pattern names. A pattern is a
    /// `{name}` that comes right after a variable name (`:scheme{uuid}`);
    /// braces anywhere else, such as a `{8}` quantifier of an inline regex
    /// (`:code([0-9a-f]{8})`), are plain text.
    public static func split( _ path: String ) -> [Piece]
    {
        var pieces: [Piece] = []
        var text = ""
        var inVarName = false   // between the ':' of a variable and the end of its name

        func isNameChar( _ c: Character ) -> Bool { return c.isLetter || c.isNumber || c == "_" }

        var index = path.startIndex
        while index < path.endIndex {
            let c = path[ index ]

            if c == "{", inVarName,
               let close = path[ index... ].firstIndex( of: "}" ) {
                let name = String( path[ path.index( after: index ) ..< close ] )
                if name.isEmpty == false && name.allSatisfy( isNameChar ) && name.first!.isNumber == false {
                    if text.isEmpty == false { pieces.append( .text( text ) ); text = "" }
                    pieces.append( .pattern( name ) )
                    index = path.index( after: close )
                    inVarName = false
                    continue
                }
            }

            if c == ":" { inVarName = true }
            else if isNameChar( c ) == false { inVarName = false }

            text.append( c )
            index = path.index( after: index )
        }

        if text.isEmpty == false { pieces.append( .text( text ) ) }
        return pieces
    }
}
