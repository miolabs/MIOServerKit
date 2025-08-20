
import Foundation
import Kitura
import MIOCoreLogger


#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ArgumentParser
import MIOCore

public class MIOServerKit
{
    struct ServerOption:ParsableCommand
    {
        @Option(name: .shortAndLong, help: "The path server files.")
        var serverPath: String?

        @Option(name: .shortAndLong, help: "The path of document files.")
        var documentPath: String?
    }
    
    
    public static let shared = MIOServerKit()

    // Initialization
    private init( ) {
        parse_command_line_arguments()
        settings = loadSettingsPlist(path: "\(serverPath)/App.plist")
        
        let server_settings = loadSettingsPlist(path: "\(serverPath)/Server.plist")
        settings = settings.merging( server_settings ) { (_, new) in new }
    }
    
    public func run (port:Int, router:MSKServerRouter<Any>) {
        Kitura.addHTTPServer(onPort: port, with: router.router)
        Kitura.run()
    }
    
    public func urlDataRequest(_ request:URLRequest) throws -> Data? {
        return try MIOCoreURLDataRequest_sync(request)
    }
    
    public func urlJSONRequest(_ request:URLRequest) throws -> Any? {
        return try MIOCoreURLJSONRequest_sync(request)
    }
            
    public func loadSettingsPlist(path:String) -> [String : Any]{
        
        guard let xml = FileManager.default.contents(atPath: path) else {
            Log.warning("Path not found: \(path)")
            return [:]
        }
        
        do {
            guard let items = try PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: nil) as? [String:Any] else {
                return [:]
            }
            
            return items
        }
        catch let error {
            print(error.localizedDescription)
            return [:]
        }
    }
    
    var _serverPath:String?
    public var serverPath:String { return _serverPath ?? FileManager().currentDirectoryPath }
    
    var _documentPath:String?
    public var documentPath:String { return _documentPath ?? FileManager().currentDirectoryPath }
    
    func parse_command_line_arguments(){
        do {
            let args = CommandLine.arguments.last == "&" ? Array ( CommandLine.arguments.dropFirst().dropLast() ) : Array ( CommandLine.arguments.dropFirst() )
            let options = try ServerOption.parse( args )
            _serverPath = options.serverPath
            _documentPath = options.documentPath
        }
        catch {
            NSLog(error.localizedDescription)
        }
    }
    
    public func settingValue(forKey key:String) -> Any? {
        settings.keys.contains(key) ? settings[key]! : nil
    }
    var settings:[String:Any] = [:]
    public var serverVersion:String {
        return settings.keys.contains("Version") ? settings["Version"] as! String : "UNKOWN"
    }
}

extension MSKRouterResponse {

    // TODO: Used in auth server...
    public func sendOKResponse(json : Any? = nil) -> MSKRouterResponse {

        self.status(.OK)
        if json == nil {
            self.send(json: ["status" : "OK"])
        } else if json is [Any] || json is [String: Any] {
            self.send(json: ["status" : "OK", "data" : json! ])
        }

        return self
    }

    // TODO: Used in redsys...
    public func sendErrorResponse(_ error : Error, httpStatus : HTTPStatusCode = .badRequest) -> MSKRouterResponse {

        self.status(httpStatus)

        self.send(json: ["status" : "Error",
                    "error" : error.localizedDescription])

        return self
    }
    
}
