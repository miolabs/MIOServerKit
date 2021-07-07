
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import ArgumentParser

public class MIOServerKit
{
    struct ServerOption:ParsableCommand
    {
        @Option(name: .shortAndLong, help: "The number of times to repeat 'phrase'.")
        var serverPath: String?

        @Option(name: .shortAndLong, help: "The number of times to repeat 'phrase'.")
        var documentPath: String?
        
//        @Argument
//        var port: Int32
    }
    
    
    public static let shared = MIOServerKit()

    // Initialization
    private init( ) {
        parse_command_line_arguments()
        settings = loadSettingsPlist(path: "\(serverPath)/App.plist")
    }
    
    public func urlDataRequest(_ request:URLRequest) throws -> Data? {
        
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil

        let session = URLSession.init(configuration: config)
        
        let (data, _, error) = session.synchronousDataTask(with: request)
                         
        if error != nil {
            print(error!.localizedDescription)
            throw error!
        }
        
        // TODO: Check response code

        return data
    }
            
    public func loadSettingsPlist(path:String) -> [String : Any]{
        
        let xml = FileManager.default.contents(atPath: path)
        
        do {
            guard let items = try PropertyListSerialization.propertyList(from: xml!, options: .mutableContainersAndLeaves, format: nil) as? [String:Any] else {
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
    
    var settings:[String:Any] = [:]
    public var serverVersion:String {
        return settings.keys.contains("Version") ? settings["Version"] as! String : "UNKOWN"
    }
}

