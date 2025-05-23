//
//  EndpointRegistry.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//

import NIOHTTP1
import MIOCoreLogger

@MainActor
public final class EndpointRegistry
{
    public typealias EndpointHandlerFunction<T:EndpointRegisterable> = ( _ context: T ) throws -> Any?
    
    static let shared = EndpointRegistry()
    
    private var endpoints: [String: (type:Any.Type, methods:[HTTPMethod])] = [:]
    
    private init() {}
    
    func register<T:EndpointRegisterable>(methods: [HTTPMethod], path: String, for type: EndpointRegisterable.Type, handler: T ) {
        let full_path = "/\(type.endpointPath)/\(path)"
        endpoints[full_path] = (type, methods)
        Log.debug("Registered endpoint: \(full_path) for type \(type)")
    }
    
    func allEndpoints() -> [String] {
        return Array(endpoints.keys)
    }
        
//    func getTypeForEndpoint(_ path: String) -> Any.Type? {
//        return endpoints[path]
//    }
}
