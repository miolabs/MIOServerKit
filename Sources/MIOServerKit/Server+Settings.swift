//
//  Server+Settings.swift
//
//
//  Created by Javier Segura Perez on 30/7/24.
//

import Foundation
import MIOCore
import MIOCoreLogger
import ArgumentParser

struct ServerOptionParsableCommand : ParsableCommand
{
    @Option(name: .shortAndLong, help: "The path server files.")
    var serverPath: String?

    @Option(name: .shortAndLong, help: "The path of document files.")
    var documentPath: String?
    
    @Option(name: .shortAndLong, help: "The port of server.")
    var port: Int?
}

open class ServerSettings
{
    public let name:String
    public let version:String
    public let documentsPath:String
    public let serverPath:String
    
    required public init( )
    {
        let name: String? = nil
        let version: String? = nil
        var documentsPath: String? = nil
        var serverPath: String? = nil

        // Parse options - has priority over the options adding in code
        let command_options = ( try? ServerOptionParsableCommand.parse( ) ) ?? ServerOptionParsableCommand()
        if let dp = command_options.documentPath { documentsPath = dp }
        if let sp = command_options.serverPath { serverPath = sp }
        
        documentsPath = documentsPath ?? MCEnvironmentVar("DOCUMENTS_PATH") ?? FileManager().currentDirectoryPath
        serverPath = serverPath ?? MCEnvironmentVar("SERVER_PATH") ?? FileManager().currentDirectoryPath
            
        // Load App.plist
        let app_settings_dict:[String:Any] = ( try? ServerSettings.loadPropertyList( path: serverPath! + "/App.plist" ) ) ?? [:]
        
        let file_name = CommandLine.arguments.first?.components(separatedBy: "/").last
        
        self.name = app_settings_dict[ "ServerName" ] as? String ?? name ?? file_name ?? "NO_NAME"
        self.version = app_settings_dict[ "Version" ] as? String ?? version ?? "x.x.x"
        self.documentsPath = documentsPath!
        self.serverPath = serverPath!
        
        Log.debug( "Server settings: name=\(name!), version=\(version!), documentsPath=\(documentsPath!), serverPath=\(serverPath!)" )
    }
    
    static public func loadPropertyList<T>( path: String ) throws -> T
    {
        guard let xml = FileManager.default.contents( atPath: path ) else {
            Log.warning("Property list file not found in path: \(path)")
            throw ServerError.loadingSettings( "Property list file not found in path: \(path)" )
        }
            
        guard let items = try PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? T else {
            Log.warning("File \(path) could not be parsed" )
            throw ServerError.loadingSettings( "File \(path) could not be parsed" )
        }
        
        return items
    }
}
