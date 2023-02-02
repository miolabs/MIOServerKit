//
//  File.swift
//  
//
//  Created by David Trallero on 25/11/21.
//

import Foundation

public enum ServerError: Error
{
    case fieldNotFound(_ description:String)
    case missingJSONBody( functionName: String = #function )
}


extension ServerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .fieldNotFound( description ):
            return "[FATAL Error] Field not found: \(description)."
        case let .missingJSONBody( functionName ):
            return "[FATAL ERROR] Missing JSON Body. Called from \(functionName)"
        }
    }
}
