
import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public class MIOServerKit
{
    public static let shared = MIOServerKit()

    // Initialization
    private init( ) {
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
    
    public func loadSettingsPlist(path:String) -> [String : Any]
    {
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

    
}

