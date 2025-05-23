//
//  MIOServerKitMacrosPlugin.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct EndpointMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EndpointMacro.self
    ]
}
