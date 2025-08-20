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


enum EndpointMacroError : Error
{
    case noClass
    case noPath
}

extension EndpointMacroError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noClass: return "@Endpoint can only be applied to classes"
        case .noPath: return "@Endpoint requires a path string literal"
        }
    }
}

public struct EndpointMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
      ) throws -> [DeclSyntax] {
          // Only on functions at the moment.
          guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
              throw MacroExpansionErrorMessage("@Endpoint only works on functions")
          }
                              
          var methods: [String] = [".GET"]
          var path_str:String? = nil
                  
          for arg in node.arguments?.as(LabeledExprListSyntax.self) ?? [] {
              switch arg.label?.text {
              case  "methods":
                  if let values = arg.expression.as(ArrayExprSyntax.self)?.elements.compactMap({ $0.expression.as(MemberAccessExprSyntax.self)?.declName.baseName.text }) {
                      methods = values.map { ".\($0.uppercased())" }
                  }
              default:
                  if let path = arg.expression.as(StringLiteralExprSyntax.self)?.segments.first?.as(StringSegmentSyntax.self)?.content.text {
                      path_str = path
                  }
              }
          }
          
          if path_str == nil {
              throw MacroExpansionErrorMessage( "@Endpoint requires a path string literal." )
          }
          
          let func_name = funcDecl.name.text
          let params = funcDecl.signature.as(FunctionSignatureSyntax.self)?.parameterClause.parameters.as(FunctionParameterListSyntax.self) ?? []
          if params.count != 1 {
              throw MacroExpansionErrorMessage( "Invalid number of parameters for @Endpoint. Expecting 1")
          }
          
          if params.first?.firstName.text != "context" {
              throw MacroExpansionErrorMessage("Expecting the first parameter to be named 'context'")
          }
          
          guard let ctx_param_value = params.first?.type.as(IdentifierTypeSyntax.self)?.name.text else {
              throw MacroExpansionErrorMessage( "Invalid value from context parameter" )
          }
          
          let register_fnc = "EndpointRegistry.shared.register( methods: [\(methods.joined(separator: ","))], path: \(path_str!), for: \(ctx_param_value).Type, handler: \(func_name) )"
                   
          let a = FunctionCallExprSyntax(callee: DeclReferenceExprSyntax(baseName: .identifier("print")), argumentList: {
              LabeledExprSyntax(expression: StringLiteralExprSyntax(content: "hola"))
          })
          
          return [ ]
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
