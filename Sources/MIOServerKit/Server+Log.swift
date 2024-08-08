//
//  Server+Log.swift
//
//
//  Created by Javier Segura Perez on 8/8/24.
//

import Logging

let _logger = Logger(label: "com.miolabs.server-kit")

public func Log( _ level:Logger.Level = .info, _ message:Logger.Message )
{
    _logger.log(level: level, message )
}
