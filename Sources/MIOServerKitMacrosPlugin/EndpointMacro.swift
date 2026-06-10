//
//  EndpointMacro.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//
import Foundation
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import EndpointGeneratorCore

/// Compile-time validator for `@Endpoint( [.get, .post], path: "/api/schema/:schema" )`.
///
/// The macro deliberately expands to nothing: compiler plugins run inside a
/// sandbox without filesystem access, so route codegen cannot happen here.
/// The `generate-endpoints` pre-build tool parses the sources with
/// swift-syntax (sharing `EndpointAnnotation` with this macro) and writes the
/// registration file. The macro's job is only to fail the build early when an
/// annotation is malformed.
public struct EndpointMacro: PeerMacro
{
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let funcDecl = declaration.as( FunctionDeclSyntax.self ) else {
            throw MacroExpansionErrorMessage( "@Endpoint can only be applied to functions" )
        }

        do { _ = try EndpointAnnotation.parse( from: node ) }
        catch { throw MacroExpansionErrorMessage( "\(error)" ) }

        let params = funcDecl.signature.parameterClause.parameters
        guard params.count == 1 else {
            throw MacroExpansionErrorMessage( "@Endpoint handler must take exactly one parameter (the router context)" )
        }

        // No expansion on purpose — see generate-endpoints.
        return []
    }
}

public struct EndpointContextRegisterableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some SwiftSyntax.DeclGroupSyntax,
        providingExtensionsOf type: some SwiftSyntax.TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context:  some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {

        // Get the declaration to determine its super type
        guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
            throw MacroExpansionErrorMessage( "Endpoint can only be applied to classes" )
        }

        var methods: [String] = [".GET"]
        var pathString:String? = nil

        for arg in node.arguments?.as(LabeledExprListSyntax.self) ?? [] {
            switch arg.label?.text {
            case  "methods":
                if let values = arg.expression.as(ArrayExprSyntax.self)?.elements.compactMap({ $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text }) {
                    methods = values.map { ".\($0.uppercased())" }
                }
            default:
                if let path = arg.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                    pathString = path
                }
            }
        }

        if pathString == nil {
            throw MacroExpansionErrorMessage( "@Endpoint requires a path string literal." )
        }

        // Check if there's a parent type
        var parentImplementation = "return nil"
        if let inheritance = classDecl.inheritanceClause,
           let inheritedType = inheritance.inheritedTypes.first?.type {
            let parentClass = "\(inheritedType.description)"
            parentImplementation = "return \(parentClass.trimmingCharacters(in: .whitespacesAndNewlines)).self as? EndpointRegisterable.Type"
        }

        return try [
//            ImportDeclSyntax(importKeyword: TokenSyntax("import"), path: StringLiteralSyntax(quotedString: "FoundationNetworking")),
            ExtensionDeclSyntax("extension \(type.trimmed): EndpointRegisterable") {
                try VariableDeclSyntax( "public static var endpointPath: String { return \"\(raw: pathString!)\" }" )
                try VariableDeclSyntax( "public static var endpointMethods: [HTTPMethod] { return [\(raw: methods.joined(separator: ",") )] }" )
                try VariableDeclSyntax( "public static var endpointParentClass: EndpointRegisterable.Type? { \(raw: parentImplementation) }" )
            }
        ]
    }
}
