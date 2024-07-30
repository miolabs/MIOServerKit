//
//  Server.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//

public let uuid_regex = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

open class Server
{
    public var router:Router { return _router }
    
    var _router:Router
    var _settings : [String:Any] = [:]
    var _docs_path = "/dev/null"
    
    // MARK: Initializer
    
    /// Initialize a `MIORouter` instance.
    /// ### Usage Example: ###
    /// ```swift
    ///  let router = MIORouter()
    /// ```
    public init( routes: Router )
    {
        _router = routes
        _load_settings()
        print("Router initialized")
    }
        
    open func run ( port:Int ) { }
}

