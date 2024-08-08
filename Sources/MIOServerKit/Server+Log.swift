//
//  Server+Log.swift
//
//
//  Created by Javier Segura Perez on 8/8/24.
//

import Foundation
import Logging

actor ServerLogger
{
    var _logger:Logger
    
    init() {
        _logger = Logger( label: "com.miolabs.server-kit" )
        
        var log_level = "info"
        
        if let value = getenv( "SERVER_LOG_LEVEL") {
            log_level = String(utf8String: value)!
        }
        
        var level:Logger.Level = .info
        switch log_level {
        case "trace": level = .trace
        case "debug": level = .debug
        case "info" : level = .info
        case "notice": level = .notice
        case "warning" : level = .warning
        case "error": level = .error
        case "critical": level = .critical
        default: break
        }
        
        _logger.logLevel = level
    }
    
    func log( level: Logger.Level, _ message: Logger.Message ) {
        _logger.log(level: level, message )
    }
        
}

let _logger = ServerLogger()

public func Log( _ level:Logger.Level = .info, _ message:Logger.Message )
{
    Task {
        await _logger.log(level: level, message )
    }
}
