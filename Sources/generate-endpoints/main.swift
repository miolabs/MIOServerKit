//
//  main.swift
//  generate-endpoints
//
//  Pre-build tool: scans Swift sources for @Endpoint annotations and writes
//  the route registration file. Compiler macro plugins run sandboxed and
//  cannot touch the filesystem, so this tool does the codegen instead —
//  run it as a pre-build phase (see Scripts/generate_endpoints.sh).
//

import Foundation
import EndpointGeneratorCore

let usageText = """
USAGE: generate-endpoints [options]

Scans Swift sources for functions annotated with @Endpoint and generates
the Router registration file.

OPTIONS:
  --sources <dir>     Directory to scan, repeatable. Default: ./Sources
  --output <file>     Generated Swift file.
                      Default: <first sources dir>/Endpoints+Generated.swift
  --json <file>       Also write a JSON description of the routes.
  --import <module>   Extra module to import in the generated file, repeatable.
  --quiet             Only print errors.
  --help              Show this help.
"""

struct Arguments
{
    var sources: [URL] = []
    var output: URL?
    var json: URL?
    var imports: [String] = []
    var quiet = false

    init( _ argv: [String] ) throws
    {
        var index = 0
        func value( for option: String ) throws -> String {
            index += 1
            guard index < argv.count else { throw ToolError.usage( "Missing value for \(option)" ) }
            return argv[ index ]
        }

        while index < argv.count {
            let arg = argv[ index ]
            switch arg {
            case "--sources": sources.append( URL( fileURLWithPath: try value( for: arg ) ) )
            case "--output":  output = URL( fileURLWithPath: try value( for: arg ) )
            case "--json":    json = URL( fileURLWithPath: try value( for: arg ) )
            case "--import":  imports.append( try value( for: arg ) )
            case "--quiet":   quiet = true
            case "--help":    print( usageText ); exit( 0 )
            default:          throw ToolError.usage( "Unknown option '\(arg)'" )
            }
            index += 1
        }

        if sources.isEmpty { sources = [ URL( fileURLWithPath: "Sources" ) ] }
        if output == nil { output = sources[0].appendingPathComponent( "Endpoints+Generated.swift" ) }
    }
}

enum ToolError: Error, CustomStringConvertible
{
    case usage( String )
    var description: String { switch self { case .usage( let message ): return "\(message)\n\n\(usageText)" } }
}

/// Writes only when the content changed, so unchanged routes never dirty the build.
func write( _ content: String, to url: URL ) throws -> Bool
{
    if let existing = try? String( contentsOf: url, encoding: .utf8 ), existing == content { return false }
    try FileManager.default.createDirectory( at: url.deletingLastPathComponent(), withIntermediateDirectories: true )
    try content.write( to: url, atomically: true, encoding: .utf8 )
    return true
}

do {
    let arguments = try Arguments( Array( CommandLine.arguments.dropFirst() ) )

    for source in arguments.sources {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists( atPath: source.path, isDirectory: &isDirectory ), isDirectory.boolValue else {
            throw ToolError.usage( "Sources directory not found: \(source.path)" )
        }
    }

    let scanner = EndpointScanner()
    let result = try scanner.scan( directories: arguments.sources, excluding: [ arguments.output! ] )

    for diagnostic in result.diagnostics {
        FileHandle.standardError.write( Data( ( diagnostic.description + "\n" ).utf8 ) )
    }
    if result.hasErrors { exit( 1 ) }

    let generator = EndpointFileGenerator( endpoints: result.endpoints )

    let swiftChanged = try write( try generator.generateSwift( extraImports: arguments.imports ), to: arguments.output! )
    var jsonChanged = false
    if let jsonURL = arguments.json {
        jsonChanged = try write( try generator.generateJSON(), to: jsonURL )
    }

    if arguments.quiet == false {
        let state = ( swiftChanged || jsonChanged ) ? "updated" : "up to date"
        print( "generate-endpoints: \(result.endpoints.count) endpoint(s) → \(arguments.output!.path) (\(state))" )
    }
}
catch {
    FileHandle.standardError.write( Data( "generate-endpoints: error: \(error)\n".utf8 ) )
    exit( 1 )
}
