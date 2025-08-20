//
//  Server.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//
import Logging
import MIOCoreLogger

public let uuid_regex = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

open class Server
{
    public let router:Router

    public init( routes: Router ) {
        self.router = routes
    }
    
    open func run ( port: Int ) {
        Log.info( "Server running on port \(port)" )
    }
}

