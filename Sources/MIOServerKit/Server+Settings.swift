//
//  Server+Settings.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//

import Foundation
import MIOCore

public struct ServerSettings
{
    var _settings : [String:Any] = [:]
        
    public var name:String { return ( _settings[ "ServerName" ] as? String ) ?? "NO_NAME" }
    public var version:String { return ( _settings[ "Version" ] as? String ) ?? "x.x.x" }
    public var documentsPath:String { ( _settings[ "DocPath" ] as? String ) ?? "/dev/null" }
    
    mutating func _load_settings() {
        // TODO: Load App.plist settings
        _settings[ "DocPath" ] = MCEnvironmentVar("DOCUMENTS_PATH") ?? "/dev/null"
    }
}

extension Server {
    
    static func _load_settings( _ settings:[String:Any]? = nil ) -> ServerSettings
    {
        // TODO: Load App.plist settings
        var settings_dict : [String:Any] = settings ?? [:]
        if !settings_dict.keys.contains( "DocPath" ) {
            settings_dict[ "DocPath" ] = MCEnvironmentVar("DOCUMENTS_PATH") ?? "/dev/null"
        }
        
        _load_settings_app_list( settings: &settings_dict )
        
        return ServerSettings(_settings: settings_dict )
    }
    
    static func _load_settings_app_list( settings:inout [String:Any]) {
        
        if let server_path = settings[ "ServerPath" ] as? String {
            let path = server_path.appending("/App.plist")
            guard let xml = FileManager.default.contents( atPath: path ) else {
                _logger.warning("Server app.plist not found in path: \(path)")
                return
            }
            
            do {
                guard let items = try PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String:Any] else {
                    _logger.warning("Server app.plist could not be parsed")
                    return
                }
                
                settings.merge(items) { (_, new) in new }
            }
            catch {
                _logger.error( "\(error)")
            }
        }
    }
}
