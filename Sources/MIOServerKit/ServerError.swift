//
//  ServerError.swift
//
//
//  Created by David Trallero on 25/11/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation

public enum ServerError: Error
{
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
        switch self
        {
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
            case let .missingJSONBody( functionName ):
            return "[MIOServerKitError] \(functionName)# Missing JSON Body."

            case let .invalidJSONBodyCast( functionName ):
            return "[MIOServerKitError] \(functionName)# Invalid JSON Body Cast type."
            
            case let .fieldNotFound( description, functionName ):
            return "[MIOServerKitError] \(functionName)# Field not found: \(description)."
                
            case let .invalidBodyData(parameterName, functionName):
            return "[MIOServerKitError] \(functionName)# \(parameterName) has invalid body data."
            
            case let .invalidContext( functionName ):
            return "[MIOServerKitError] \(functionName)# Invalid context."
        }
    }
}
