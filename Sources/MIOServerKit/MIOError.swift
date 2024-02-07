//
//  File.swift
//  
//
//  Created by David Trallero on 25/11/21.
//

import Foundation

public enum MIOError: Error
{
    case fieldNotFound(_ description:String)
    case missingJSONBody( functionName: String = #function )
    case notImplemented( functionName: String = #function )
    case badURLArgument( _ description: String, functionName: String = #function )
}


extension MIOError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .notImplemented( functionName ):
            return "[FATAL] function not implements: \(functionName)"
        case let .fieldNotFound( description ):
            return "[FATAL Error] Field not found: \(description)."
        case let .missingJSONBody( functionName ):
            return "[FATAL ERROR] Missing JSON Body. Called from \(functionName)"
        case let .badURLArgument( description, functionName ):
                return "[ERROR] Bad URL Argument \(description). Called from \(functionName)"
        }
    }
}
