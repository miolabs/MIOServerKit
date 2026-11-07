//
//  ResponseCompressionTests.swift
//  MIOServerKitTests
//
//  gzip response compression in NIOServer.
//

@testable import MIOServerKit
import XCTest
import Foundation
import NIOHTTP1

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if !os(macOS)
extension ResponseCompressionTests {
    static var allTests = [
        ("test_shouldCompress_largeJSON", test_shouldCompress_largeJSON),
        ("test_shouldCompress_smallBody", test_shouldCompress_smallBody),
        ("test_shouldCompress_alreadyCompressedTypes", test_shouldCompress_alreadyCompressedTypes),
        ("test_shouldCompress_existingContentEncoding", test_shouldCompress_existingContentEncoding),
        ("test_shouldCompress_disabled", test_shouldCompress_disabled),
        ("test_server_gzipLargeJSON", test_server_gzipLargeJSON),
        ("test_server_identityWhenClientDoesNotAccept", test_server_identityWhenClientDoesNotAccept),
        ("test_server_smallBodyNotCompressed", test_server_smallBodyNotCompressed),
        ("test_server_pdfNotCompressed", test_server_pdfNotCompressed),
        ("test_server_compressionDisabled", test_server_compressionDisabled),
    ]
}
#endif

private let compressionPort = 8087

/// ~40 KB of repetitive JSON, like a report payload.
private let largeJSON: Data = {
    let rows = (0..<500).map { "{\"name\":\"Product \($0)\",\"total\":\($0 * 3).50,\"category\":\"Menus\"}" }
    return ("[" + rows.joined(separator: ",") + "]").data(using: .utf8)!
}()

final class ResponseCompressionTests: XCTestCase {

    // MARK: - Predicate

    private func head(_ headers: [(String, String)]) -> HTTPResponseHead {
        HTTPResponseHead(version: .http1_1, status: .ok, headers: HTTPHeaders(headers))
    }

    func test_shouldCompress_largeJSON() {
        let h = head([("content-type", "application/json"), ("content-length", "50000")])
        XCTAssertTrue(ResponseCompressionOptions.default.shouldCompress(h))
    }

    func test_shouldCompress_smallBody() {
        let h = head([("content-type", "application/json"), ("content-length", "200")])
        XCTAssertFalse(ResponseCompressionOptions.default.shouldCompress(h))
    }

    func test_shouldCompress_alreadyCompressedTypes() {
        for ct in ["application/pdf", "image/png",
                   "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                   "application/octet-stream"] {
            let h = head([("content-type", ct), ("content-length", "50000")])
            XCTAssertFalse(ResponseCompressionOptions.default.shouldCompress(h), ct)
        }
    }

    func test_shouldCompress_existingContentEncoding() {
        let h = head([("content-type", "application/json"), ("content-length", "50000"), ("content-encoding", "br")])
        XCTAssertFalse(ResponseCompressionOptions.default.shouldCompress(h))
    }

    func test_shouldCompress_disabled() {
        let h = head([("content-type", "application/json"), ("content-length", "50000")])
        XCTAssertFalse(ResponseCompressionOptions.disabled.shouldCompress(h))
    }

    // MARK: - Real server

    private func launch(_ options: ResponseCompressionOptions = .default) -> NIOServer {
        let routes = Router()
        routes.endpoint("/large").get { (context: RouterContext) throws -> Any? in
            context.response.headers.replaceOrAdd(name: .contentType, value: "application/json")
            return largeJSON
        }
        routes.endpoint("/small").get { (_: RouterContext) throws -> Any? in
            return ["ok": true]
        }
        routes.endpoint("/pdf").get { (context: RouterContext) throws -> Any? in
            context.response.headers.replaceOrAdd(name: .contentType, value: "application/pdf")
            return largeJSON
        }

        let server = NIOServer(routes: routes)
        server.responseCompression = options
        Thread { server.run(port: compressionPort) }.start()
        XCTAssertTrue(server.waitForServerRunning())
        return server
    }

    private func get(_ path: String, acceptEncoding: String) -> (HTTPURLResponse?, Data?) {
        var request = URLRequest(url: URL(string: "http://localhost:\(compressionPort)\(path)")!)
        request.setValue(acceptEncoding, forHTTPHeaderField: "Accept-Encoding")
        let semaphore = DispatchSemaphore(value: 0)
        var result: (HTTPURLResponse?, Data?) = (nil, nil)
        URLSession(configuration: .ephemeral).dataTask(with: request) { data, response, error in
            XCTAssertNil(error)
            result = (response as? HTTPURLResponse, data)
            semaphore.signal()
        }.resume()
        XCTAssertEqual(semaphore.wait(timeout: .now() + 10), .success)
        return result
    }

    func test_server_gzipLargeJSON() throws {
        let server = launch()
        defer { try? server.terminateServer() }

        let (response, data) = get("/large", acceptEncoding: "gzip")
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertEqual(response?.value(forHTTPHeaderField: "Content-Encoding"), "gzip")
        // URLSession inflates transparently: the body must be byte-identical.
        XCTAssertEqual(data, largeJSON)
    }

    func test_server_identityWhenClientDoesNotAccept() throws {
        let server = launch()
        defer { try? server.terminateServer() }

        let (response, data) = get("/large", acceptEncoding: "identity")
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(response?.value(forHTTPHeaderField: "Content-Encoding"))
        XCTAssertEqual(data, largeJSON)
    }

    func test_server_smallBodyNotCompressed() throws {
        let server = launch()
        defer { try? server.terminateServer() }

        let (response, _) = get("/small", acceptEncoding: "gzip")
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(response?.value(forHTTPHeaderField: "Content-Encoding"))
    }

    func test_server_pdfNotCompressed() throws {
        let server = launch()
        defer { try? server.terminateServer() }

        let (response, data) = get("/pdf", acceptEncoding: "gzip")
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(response?.value(forHTTPHeaderField: "Content-Encoding"))
        XCTAssertEqual(data, largeJSON)
    }

    func test_server_compressionDisabled() throws {
        let server = launch(.disabled)
        defer { try? server.terminateServer() }

        let (response, data) = get("/large", acceptEncoding: "gzip")
        XCTAssertEqual(response?.statusCode, 200)
        XCTAssertNil(response?.value(forHTTPHeaderField: "Content-Encoding"))
        XCTAssertEqual(data, largeJSON)
    }
}
