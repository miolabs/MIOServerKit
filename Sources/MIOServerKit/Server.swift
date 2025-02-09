//
//  Server.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//
import Logging

let _logger = Logger(label: "com.miolabs.server-kit")

public let uuid_regex = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

open class Server
{
    public var router:Router { return _router }
    public var settings: ServerSettings { return _settings }
    
    var _router:Router
    var _settings: ServerSettings
    
    // MARK: Initializer
    
    /// Initialize a `MIORouter` instance.
    /// ### Usage Example: ###
    /// ```swift
    ///  let router = MIORouter()
    /// ```
    public init( routes: Router, settings: [String:Any]? = nil )
    {
        _router = routes
        _settings = Server._load_settings( settings )
    }
        
    open func run ( port:Int ) {
        _logger.info( "Server \(self.settings.name) \(self.settings.version)")
        _logger.info( "Server settings: \(self.settings)")        
    }
}

