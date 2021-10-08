//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 14/9/21.
//

import Foundation


public enum MIOServerKitError: Error
{
    case invalidBodyData(_ parameterName: String, _ value: Any = #function)
}


extension MIOServerKitError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidBodyData(parameterName, value):
            return "[MIOServerKitError] \(parameterName) has invalid body data \"\(value)\"."
        }
    }
}
