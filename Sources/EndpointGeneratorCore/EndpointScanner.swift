//
//  EndpointScanner.swift
//  MIOServerKit
//
//  Walks Swift sources looking for functions annotated with @Endpoint and
//  collects everything the generator needs to register them into a Router.
//

import Foundation
import SwiftSyntax
import SwiftParser

public struct ScannedEndpoint: Equatable, Codable
{
    /// Lowercase HTTP method names ("get", "post", ...).
    public let methods: [String]
    /// Route path as written in the annotation, e.g. "/api/schema/:schema".
    public let path: String
    /// How to reference the handler from generated code, e.g. "getSchema" or "SchemaAPI.getSchema".
    public let handler: String
    /// Type of the single context parameter, e.g. "APIContext".
    public let context: String?
    public let isAsync: Bool
    public let file: String
    public let line: Int
}

public struct ScanDiagnostic: Equatable
{
    public enum Severity: String { case warning, error }

    public let severity: Severity
    public let message: String
    public let file: String
    public let line: Int

    public var description: String { return "\(file):\(line): \(severity.rawValue): \(message)" }
}

public struct ScanResult
{
    public var endpoints: [ScannedEndpoint] = []
    public var diagnostics: [ScanDiagnostic] = []

    public var hasErrors: Bool { return diagnostics.contains { $0.severity == .error } }

    public mutating func merge( _ other: ScanResult ) {
        endpoints.append( contentsOf: other.endpoints )
        diagnostics.append( contentsOf: other.diagnostics )
    }
}

public struct EndpointScanner
{
    public init() {}

    /// Scans a single Swift source string.
    public func scan( source: String, filePath: String ) -> ScanResult
    {
        let tree = Parser.parse( source: source )
        let visitor = EndpointVisitor( filePath: filePath, tree: tree )
        visitor.walk( tree )
        return visitor.result
    }

    /// Recursively scans every *.swift file under the given directories.
    /// `excluding` paths (e.g. the generated output file) are skipped, as are
    /// hidden directories and ".build".
    public func scan( directories: [URL], excluding excluded: [URL] = [] ) throws -> ScanResult
    {
        var result = ScanResult()
        let excludedPaths = Set( excluded.map { $0.standardizedFileURL.path } )

        for directory in directories {
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [ .isRegularFileKey ],
                options: [ .skipsHiddenFiles ]
            )

            while let item = enumerator?.nextObject() as? URL {
                if item.lastPathComponent == ".build" { enumerator?.skipDescendants(); continue }
                guard item.pathExtension == "swift" else { continue }
                guard excludedPaths.contains( item.standardizedFileURL.path ) == false else { continue }

                let source = try String( contentsOf: item, encoding: .utf8 )
                result.merge( scan( source: source, filePath: item.path ) )
            }
        }

        return result
    }
}

// MARK: - Visitor

final class EndpointVisitor: SyntaxVisitor
{
    let filePath: String
    let converter: SourceLocationConverter
    var typeStack: [String] = []
    var result = ScanResult()

    init( filePath: String, tree: SourceFileSyntax ) {
        self.filePath = filePath
        self.converter = SourceLocationConverter( fileName: filePath, tree: tree )
        super.init( viewMode: .sourceAccurate )
    }

    func line( of node: some SyntaxProtocol ) -> Int {
        return node.startLocation( converter: converter ).line
    }

    // Track type nesting so static handlers can be referenced as "Type.handler".
    override func visit( _ node: ClassDeclSyntax )     -> SyntaxVisitorContinueKind { typeStack.append( node.name.text ); return .visitChildren }
    override func visit( _ node: StructDeclSyntax )    -> SyntaxVisitorContinueKind { typeStack.append( node.name.text ); return .visitChildren }
    override func visit( _ node: EnumDeclSyntax )      -> SyntaxVisitorContinueKind { typeStack.append( node.name.text ); return .visitChildren }
    override func visit( _ node: ActorDeclSyntax )     -> SyntaxVisitorContinueKind { typeStack.append( node.name.text ); return .visitChildren }
    override func visit( _ node: ExtensionDeclSyntax ) -> SyntaxVisitorContinueKind { typeStack.append( node.extendedType.trimmedDescription ); return .visitChildren }

    override func visitPost( _ node: ClassDeclSyntax )     { typeStack.removeLast() }
    override func visitPost( _ node: StructDeclSyntax )    { typeStack.removeLast() }
    override func visitPost( _ node: EnumDeclSyntax )      { typeStack.removeLast() }
    override func visitPost( _ node: ActorDeclSyntax )     { typeStack.removeLast() }
    override func visitPost( _ node: ExtensionDeclSyntax ) { typeStack.removeLast() }

    override func visit( _ node: FunctionDeclSyntax ) -> SyntaxVisitorContinueKind
    {
        guard let attribute = endpointAttribute( of: node ) else { return .skipChildren }

        let annotation: EndpointAnnotation
        do {
            annotation = try EndpointAnnotation.parse( from: attribute )
        }
        catch {
            diagnose( .error, "\(error)", at: attribute )
            return .skipChildren
        }

        let params = node.signature.parameterClause.parameters
        guard params.count == 1 else {
            diagnose( .error, "@Endpoint handler '\(node.name.text)' must take exactly one parameter (the router context)", at: node )
            return .skipChildren
        }

        // Handlers inside a type must be static so they can be referenced
        // without an instance from the generated registration code.
        if typeStack.isEmpty == false {
            let isStatic = node.modifiers.contains { $0.name.tokenKind == .keyword( .static ) || $0.name.tokenKind == .keyword( .class ) }
            if isStatic == false {
                diagnose( .error, "@Endpoint handler '\(node.name.text)' in '\(typeStack.joined(separator: "."))' must be static (or a free function)", at: node )
                return .skipChildren
            }
        }

        let handler = ( typeStack + [ node.name.text ] ).joined( separator: "." )

        result.endpoints.append( ScannedEndpoint(
            methods: annotation.methods,
            path: annotation.path,
            handler: handler,
            context: params.first?.type.trimmedDescription,
            isAsync: node.signature.effectSpecifiers?.asyncSpecifier != nil,
            file: filePath,
            line: line( of: node )
        ) )

        return .skipChildren
    }

    func endpointAttribute( of node: FunctionDeclSyntax ) -> AttributeSyntax?
    {
        for case .attribute( let attribute ) in node.attributes {
            if EndpointAnnotation.matches( attribute ) { return attribute }
        }
        return nil
    }

    func diagnose( _ severity: ScanDiagnostic.Severity, _ message: String, at node: some SyntaxProtocol ) {
        result.diagnostics.append( ScanDiagnostic( severity: severity, message: message, file: filePath, line: line( of: node ) ) )
    }
}
