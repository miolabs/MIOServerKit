
import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket


public enum WebSocketEndpointFrameType: String
{
    case TEXT   = "TEXT"
}


public typealias WebSocketEndpointRequestDispatcher = (String, ConnectedWebSocketOperations) async throws -> Void

public struct WebSocketEndpointMethodHandler
{
    private var cb: WebSocketEndpointRequestDispatcher?

    //public init (cb: @escaping ( ) throws -> Any?)
    public init (cb: @escaping WebSocketEndpointRequestDispatcher)
    {
        self.cb = cb
    }
    
    public func run(_ message: String, _ operations: ConnectedWebSocketOperations) async throws
    {
        if cb != nil {
            _ = try await cb!(message, operations)
        }
    }
}

public class WebSocketEndpoint {
    public var uri: String = ""
    public var methods: [ WebSocketEndpointFrameType : WebSocketEndpointMethodHandler ] = [:]

    @discardableResult
    public func OnText( _ cb: @escaping WebSocketEndpointRequestDispatcher) -> WebSocketEndpoint {
        return addMethod( .TEXT, cb)
    }

    public init ( _ uri: String ) {
        self.uri = uri
    }

    private func addMethod( _ method: WebSocketEndpointFrameType, _ cb: @escaping WebSocketEndpointRequestDispatcher) -> WebSocketEndpoint {
        methods[ method ] = WebSocketEndpointMethodHandler(cb: cb)
        return self
    }
}

public typealias ConnectedClientID = String

//public typealias ConnectedClientsToEndpoint = [ConnectedClientID: ConnectedWebSocket]
public protocol ConnectedWebSocketOperations {
    func SendTextToAll(_ text: String) async throws
    func SendTextToCaller(_ text: String) async throws
    func SendTextToAllButCaller(_ text: String) async throws
}

public class ConnectedClientsToEndpoint  {
    public var clients : [ConnectedClientID: ConnectedWebSocket] = [:]
    public var endPoint: WebSocketEndpoint

    public init( _ endPoint: WebSocketEndpoint ) {
        self.endPoint = endPoint
    }

    // public func SendTextToAll() {
    //     // xxx
    // }
    // public func SendTextToCaller() {
    //     // xxx
    // }
    // public func SendTextToAllButCaller() {
    //     // xxx
    // }

    public func AddClient( _ clientId: ConnectedClientID, _ client: ConnectedWebSocket ) {
        clients[clientId] = client
    }
}

public typealias EndpointURI = String
public class ConnectedWebSocketCatalog {

    private var webSockets: [EndpointURI: ConnectedClientsToEndpoint] = [:]
    private let webSocketsLock = NSLock()
    //private var endPoints: [WebSocketEndpoint] = []

    public func AddEndpoints( _ endPoints: [WebSocketEndpoint] ) {
        webSocketsLock.lock()
        defer { webSocketsLock.unlock() } 
        for ep in endPoints {
            webSockets[ep.uri] = ConnectedClientsToEndpoint(ep)
        }
    }

    public func SendTextToAll(_ serverUri: String, _ text: String) async throws{
        webSocketsLock.lock()
        defer { webSocketsLock.unlock() } 
        if let cc = webSockets[serverUri] {
            for (_, connection) in cc.clients {
                try await connection.SendTextToClient(text)
            }
        }
    }

    public func ConnectedClientsCount(_ serverUri: String) -> Int {
        webSocketsLock.lock()
        defer { webSocketsLock.unlock() } 
        if let cc = webSockets[serverUri] {
            return cc.clients.count
        }
        return 0
    }   

    public func AddClient(
        _ uri: String, 
        _ newClientId: String, 
        _ allocator: ByteBufferAllocator,
        _ inbound: NIOAsyncChannelInboundStream<WebSocketFrame>, 
        _ outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>) -> ConnectedWebSocket? {

        webSocketsLock.lock()
        defer { webSocketsLock.unlock() } 
        if let cc = webSockets[uri] {
            //let client = ConnectedWebSocket.New(ConnectedWebSocket.self, newClientId, allocator, inbound, outbound, endPoint)
            let clientSocket = ConnectedWebSocket(newClientId, allocator, inbound, outbound, cc)
            webSockets[uri]!.AddClient(newClientId, clientSocket)    
            return clientSocket
        } else {
            return nil
        }
    }

    public func RemoveClient( _ uri: String, _ clientId: String ) {
        webSocketsLock.lock()
        defer { webSocketsLock.unlock() } 
        if webSockets[uri] != nil {
            _ = webSockets[uri]!.clients.removeValue(forKey: clientId)
        }
    }
}
