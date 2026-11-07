//
//  ResponseCompression.swift
//  MIOServerKit
//
//  HTTP response compression (gzip / deflate) for NIOServer.
//

import NIOHTTP1
import NIOHTTPCompression

/// Controls whether `NIOServer` compresses HTTP responses.
///
/// Compression only happens when the client sends `Accept-Encoding: gzip`
/// (or `deflate`), the body is at least `minimumBytes` long, and the
/// content type is not one that is already compressed (PDF, XLSX, images…).
/// Set `NIOServer.responseCompression` before calling `run(port:)`.
public struct ResponseCompressionOptions: Sendable {
    public var enabled: Bool
    /// Bodies smaller than this are sent as is: compressing them costs more than it saves.
    public var minimumBytes: Int
    /// Content-type prefixes that are never compressed (already compressed formats).
    public var excludedContentTypes: [String]

    public init(
        enabled: Bool = true,
        minimumBytes: Int = 1024,
        excludedContentTypes: [String] = ResponseCompressionOptions.alreadyCompressedContentTypes
    ) {
        self.enabled = enabled
        self.minimumBytes = minimumBytes
        self.excludedContentTypes = excludedContentTypes
    }

    public static let `default` = ResponseCompressionOptions()
    public static let disabled = ResponseCompressionOptions(enabled: false)

    public static let alreadyCompressedContentTypes: [String] = [
        "image/",
        "video/",
        "audio/",
        "font/woff",
        "application/pdf",
        "application/zip",
        "application/gzip",
        "application/x-gzip",
        "application/wasm+br",
        "application/vnd.openxmlformats-officedocument", // xlsx, docx, pptx are zip containers
        "application/octet-stream",
    ]

    /// Decides from the response head alone (the body is not available yet).
    func shouldCompress(_ head: HTTPResponseHead) -> Bool {
        if !enabled { return false }
        if head.headers.contains(name: "content-encoding") { return false }

        if let length = head.headers.first(name: "content-length").flatMap({ Int($0) }),
           length < minimumBytes {
            return false
        }

        if let contentType = head.headers.first(name: "content-type")?.lowercased() {
            for prefix in excludedContentTypes where contentType.hasPrefix(prefix) {
                return false
            }
        }
        return true
    }

    func makeHandler() -> HTTPResponseCompressor {
        let options = self
        return HTTPResponseCompressor(responseCompressionPredicate: { head, _ in
            options.shouldCompress(head) ? .compressIfPossible : .doNotCompress
        })
    }
}
