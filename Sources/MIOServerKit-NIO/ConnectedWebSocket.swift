import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket

open class ConnectedWebSocket : ConnectedWebSocketOperations { 
    var inbound:  NIOAsyncChannelInboundStream<WebSocketFrame>
    var outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>
    var allocator: ByteBufferAllocator
    var id : String = ""
    var allConnections: ConnectedClientsToEndpoint

    required public init(
        _ id : String,
        _ allocator: ByteBufferAllocator, 
        _ inbound: NIOAsyncChannelInboundStream<WebSocketFrame>,
        _ outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>,
        _ allConnections: ConnectedClientsToEndpoint) {

        self.id = id
        self.allocator = allocator
        self.inbound = inbound
        self.outbound = outbound
        self.allConnections = allConnections
    }

    // static func New<T: ConnectedWebSocket>(
    //     _ type: T.Type, 
    //     _ id : String,
    //     _ allocator: ByteBufferAllocator,
    //     _ inbound: NIOAsyncChannelInboundStream<WebSocketFrame>, 
    //     _ outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>) -> T {

    //     return T(id, allocator, inbound, outbound)
    // }

    open func OnFrameFromClientProcessed(_ frame: WebSocketFrame) -> (Bool, Bool) {
        let frameProcessed = false
        let closeConnection = false
        return (frameProcessed, closeConnection)
    }

    open func OnTextMessageFromClient(_ message: String) async {
        print("Received message: \(message)")
        let endPoint = allConnections.endPoint
        if let handler = endPoint.methods[.TEXT] {
            do {
                _ = try await handler.run(message, self)
            }
            catch {
                
            }
        }
    }

    //OnConnected() ?? xxx

    public func SendTextToClient(_ text: String) async throws {
        var buffer = allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        //print("Sending message")
        try await outbound.write(frame)
    }

    public func SendTextToAll(_ text: String) async throws{
        for (_, connection) in allConnections.clients {
            try await connection.SendTextToClient(text)
        }
    }
    public func SendTextToCaller(_ text: String) async throws {
        try await SendTextToClient(text)    
    }

    public func SendTextToAllButCaller(_ text: String) async throws {
        for (_, connection) in allConnections.clients {
            if connection.id != self.id {
                try await connection.SendTextToClient(text)
            }
        }
    }

    func gotFrame(_ frame: WebSocketFrame) async throws -> Bool {
        var (frameProcessed, closeConnection) = self.OnFrameFromClientProcessed(frame)
        if  !closeConnection && !frameProcessed {
            switch frame.opcode {
                case .text:
                    var frameData = frame.data
                    let maskingKey = frame.maskKey
                    if let maskingKey = maskingKey {
                        frameData.webSocketUnmask(maskingKey)
                    }
                    // let bytes = frameData.readableBytesView
                    // print("unmasked bytes: \(Array(bytes))")
                    await self.OnTextMessageFromClient(frameData.getString(at: 0, length: frameData.readableBytes) ?? "")
                case .ping:
                    var frameData = frame.data
                    let maskingKey = frame.maskKey

                    if let maskingKey = maskingKey {
                        frameData.webSocketUnmask(maskingKey)
                    }
                    let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
                    try await outbound.write(responseFrame)
                case .connectionClose:
                    print("Received close")
                    var data = frame.unmaskedData
                    let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
                    let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
                    try await outbound.write(closeFrame)
                    closeConnection = true
                case .binary, .continuation, .pong:
                    // xxxxx
                    break
                default:
                    print("Unknown frames ")
            }
        }
        return closeConnection
    } // gotFrame()

}
