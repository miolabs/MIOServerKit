//
//  Server.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//
import Logging
import MIOCoreLogger

public let uuid_regex = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

open class Server < S:ServerSettings >
{
    public let router:Router
    public let settings: S

    public init( routes: Router, settings: S? = nil ) {
        self.router = routes
        self.settings = settings ?? S()
    }
    
    open func run ( port: Int ) {
        Log.info( "\(self.settings.name) \(self.settings.version) running on port \(port)" )
    }
}

