//
//  Server+Settings.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//

import Foundation

protocol ServerSettings 
{
    var name:String { get }
    var version:String { get }
    var documentsPath: String { get }
}

extension Server : ServerSettings
{
    public var name:String { return ( _settings[ "ServerName" ] as? String ) ?? "NO_NAME"}
    public var version:String { return ( _settings[ "ServerVersion" ] as? String ) ?? "x.x.x" }
    public var documentsPath:String { return _docs_path }
    
    func _load_settings() {
        // TODO: Load App.plist settings
    }
}
