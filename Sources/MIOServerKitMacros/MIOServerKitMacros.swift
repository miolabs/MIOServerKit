//
//  MIOServerKitMacros.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//
// The Swift Programming Language
// https://docs.swift.org/swift-book

import NIOHTTP1

// Define the macro
@attached(peer)
public macro Endpoint( methods: [HTTPMethod] = [.GET], _ path:String ) = #externalMacro(module: "MIOServerKitMacrosPlugin", type: "EndpointMacro")

@attached(extension, conformances: EndpointRegisterable, names: arbitrary)
public macro EndpointContextRegisterableMacro( _ path:String ) = #externalMacro(module: "MIOServerKitMacrosPlugin", type: "EndpointContextRegisterableMacro")
