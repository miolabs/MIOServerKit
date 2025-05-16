//
//  ServerError.swift
//
//
//  Created by David Trallero on 25/11/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation
import NIOHTTP1

public protocol ServerErrorCodeProtocol
{
    var errorCode: HTTPResponseStatus { get }
}

public enum ServerError: Error
{
    case general ( _ errorCode: HTTPResponseStatus, _ message:String, _ functionName: String = #function)
    case endpointNotFound ( _ path:String, _ method:String, _ functionName: String = #function)
    case missingJSONBody(_ functionName : String = #function )
    case invalidJSONBodyCast(_ functionName: Any = #function)
    case fieldNotFound  (_ description  : String, _ functionName : String = #function )
    case invalidBodyData(_ parameterName: String, _ functionName: Any = #function)
    case invalidContext (_ functionName: String = #function)
}

extension ServerError: LocalizedError
{
    public var errorDescription: String?
    {
        switch self {
        case let .general( _, message, _ ): return message
        case let .endpointNotFound( path, method, _ ): return "Endpoint not found. \(method) \(path)"
        case .missingJSONBody( _ ): return "Missing JSON Body"
        case .invalidJSONBodyCast( _ ): return "Invalid JSON Body Cast type"
        case let .fieldNotFound( description, _ ): return "Field not found: \(description)."
        case let .invalidBodyData(parameterName, _): return "\(parameterName) has invalid body data."
        case .invalidContext(_): return "Invalid context."
        }
    }
    
    public var failureReason: String?
    {
        switch self
        {
            case let .general( _, message, functionName ):
            return "\(message). \(functionName)"
            
            case let .missingJSONBody( functionName ):
            return "Missing JSON Body. \(functionName)"

            case let .invalidJSONBodyCast( functionName ):
            return "Invalid JSON Body Cast type. \(functionName)"
            
            case let .fieldNotFound( description, functionName ):
            return "Field not found: \(description). \(functionName)"
                
            case let .invalidBodyData(parameterName, functionName):
            return "\(parameterName) has invalid body data. \(functionName)"
            
            case let .invalidContext( functionName ):
            return "Invalid context. \(functionName)"
            
            case let .endpointNotFound( path, method, functionName ):
            return "Endpoint not found. \(method) \(path). \(functionName)"
        }
    }
}

extension ServerError : ServerErrorCodeProtocol
{
    public var errorCode: HTTPResponseStatus {
        switch self {
        case .general( let code, _, _ ): return code
        case .endpointNotFound: return .notFound
        default: return .internalServerError
        }
    }
}
