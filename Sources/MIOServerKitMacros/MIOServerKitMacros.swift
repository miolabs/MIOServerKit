//
//  MIOServerKitMacros.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//
// The Swift Programming Language
// https://docs.swift.org/swift-book

import NIOHTTP1
import MIOServerKit

/// Marks a free function (or a static function) as an HTTP endpoint.
///
/// The macro itself is intentionally a no-op: compiler plugins run inside a
/// sandbox and cannot write files, so the macro only validates the annotation
/// at compile time. The actual route registration file is produced by the
/// `generate-endpoints` tool (see `Scripts/generate_endpoints.sh`), which is
/// meant to run as a pre-build step. It parses the project sources with
/// swift-syntax, collects every `@Endpoint` annotation and writes a
/// `Endpoints+Generated.swift` file that registers all routes into a `Router`.
///
/// Usage:
/// ```swift
/// @Endpoint( [.get, .post], path: "/api/schema/:schema" )
/// func schemaHandler( context: APIContext ) throws -> Any? {
///     ...
/// }
/// ```
@attached(peer)
public macro Endpoint( _ methods: [EndpointMethod] = [.get], path: String ) = #externalMacro(module: "MIOServerKitMacrosPlugin", type: "EndpointMacro")

@attached(extension, conformances: EndpointRegisterable, names: arbitrary)
public macro EndpointContextRegisterableMacro( _ path:String ) = #externalMacro(module: "MIOServerKitMacrosPlugin", type: "EndpointContextRegisterableMacro")
