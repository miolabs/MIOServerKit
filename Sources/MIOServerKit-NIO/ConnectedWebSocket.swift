import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket

open class ConnectedWebSocket { 
    var inbound:  NIOAsyncChannelInboundStream<WebSocketFrame>
    var outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>
    var allocator: ByteBufferAllocator
    var id : String = ""

    required public init(
        _ id : String,
        _ allocator: ByteBufferAllocator, 
        _ inbound: NIOAsyncChannelInboundStream<WebSocketFrame>,
        _ outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>) {

        self.id = id
        self.allocator = allocator
        self.inbound = inbound
        self.outbound = outbound
    }

    static func New<T: ConnectedWebSocket>(
    //static func New(
        //T: ConnectedWebSocket.Type,
        //T: T,
        _ type: T.Type, 
        _ id : String,
        _ allocator: ByteBufferAllocator,
        _ inbound: NIOAsyncChannelInboundStream<WebSocketFrame>, 
        _ outbound: NIOAsyncChannelOutboundWriter<WebSocketFrame>) -> T {

        return T(id, allocator, inbound, outbound)
    }

    open func OnFrameFromClientProcessed(_ frame: WebSocketFrame) -> (Bool, Bool) {
        let frameProcessed = false
        let closeConnection = false
        return (frameProcessed, closeConnection)
    }

    open func OnTextMessageFromClient(_ message: String) {
        print("Received message: \(message)")
    }

    //OnConnected() ??

    public func SendTextToClient(_ message: String) async throws {
        var buffer = allocator.buffer(capacity: message.utf8.count)
        buffer.writeString(message)
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        print("Sending message")
        try await outbound.write(frame)
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
                    self.OnTextMessageFromClient(frameData.getString(at: 0, length: frameData.readableBytes) ?? "")
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
