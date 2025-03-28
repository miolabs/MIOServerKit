//
//  MIOServerKitNIOTests.swift
//  
//  Tests to perform actual calls to real NIO servers and validate that the Router class works
//
//  Created by Manuel Escribano on 4/3/25.
//

import MIOServerKit
import MIOServerKit_NIO
import XCTest
import Foundation


// MARK: - Resp handlers
func httpFuncHandler ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        //"status": "success"
        "url": context.request.url.absoluteString
    ]
    return response
}

func httpRootFuncHandler ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        //"status": "success"
        "url": "I'm Root"
    ]
    return response
}

func httpFuncHandlerStr2 ( context: RouterContext ) throws -> [String:Any] {
    let response:[String:Any] = [
        //"status": "success"
        "url": "Str2"
    ]
    return response
}

// MARK: - http utils
class HTTPClient {
    let session : URLSession
    init (_ session: URLSession) {
        self.session = session
    }
    func get(url: String, placeID:String? = nil, appID: String? = nil, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: URL(string: url)!)
        if placeID != nil { request.setValue(placeID!, forHTTPHeaderField: "DL-PLACE-ID") }
        if appID != nil  { request.setValue(appID!, forHTTPHeaderField: "DL-APP-ID") }
        let task = session.dataTask(with: request ) { data, response, error in
            completion(data, response, error)
        }
        task.resume()
    }

    func post(url: String, body: Data?, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        guard let requestUrl = URL(string: url) else {
            completion(nil, nil, NSError(domain: "Invalid URL", code: -1, userInfo: nil))
            return
        }
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Ajusta si envías otro tipo de datos
        
        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
        task.resume()
    }
}

func extraerRuta(_ url: String) -> String {
    let componentes = url.components(separatedBy: "8080")
    return componentes.count > 1 ? componentes[1] : ""
}
// MARK: - call post
func canonicalPostRequest(_ url: String, _ body: Data? = nil, _ expectedParam: String = "") throws -> Int {
    let semaphore = DispatchSemaphore(value: 0)
    let httpClient = HTTPClient(URLSession(configuration: URLSessionConfiguration.default))
    var ret = 0
    httpClient.post(url: url, body: body) { data, response, error in
        XCTAssertNil(error, "Error: \(error!)")
        if let httpResponse = response as? HTTPURLResponse {
            ret = httpResponse.statusCode
        } else {
            XCTFail("Unexpected response type")
        }
        XCTAssertNotNil(data)
        if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
            if ret == 200 {
               var expected = expectedParam
                if expected == "" {
                    expected = extraerRuta(url)
                }
                let fullExpected = "{\"url\":\"\(expected)\"}"
                let sanitizedResponse = responseString.replacingOccurrences(of: "\\/", with: "/")
                XCTAssertEqual(sanitizedResponse, fullExpected)
            }
        } else {
            XCTFail("Can't convert data to string")
        }
        semaphore.signal()
    }
    let timeout = DispatchTime.now() + .seconds(5)
    if semaphore.wait(timeout: timeout) == .timedOut {
        XCTFail("****** REQUEST TIME OUT (post)!!  ********************")
    }
    return ret
}
// MARK: - call get
func canonicalGetRequest(_ url : String, _ expectedParam:String = "") throws -> Int {
    let semaphore = DispatchSemaphore(value: 0)
    let httpClient = HTTPClient(URLSession(configuration: URLSessionConfiguration.default)) //MIOServerKitNIOTests.urlSession!)
    var ret = 0
    httpClient.get(url: url) { data, response, error in
        XCTAssertNil(error, "Error: \(error!)")
        if let httpResponse = response as? HTTPURLResponse {
            ret = httpResponse.statusCode
        } else {
            XCTFail("Unexpected response type")
        }
        XCTAssertNotNil(data)
        if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
            if (ret == 200) {
                var expected = expectedParam
                if expected == "" {
                    expected = extraerRuta(url)
                }
                let fullExpected = "{\"url\":\"\(expected)\"}"
                let sanitizedResponse = responseString.replacingOccurrences(of: "\\/", with: "/")
                XCTAssertEqual(sanitizedResponse, fullExpected)
            }
            //print(responseString)
        } else {
          XCTFail("Cant convert data to string")
        }
        semaphore.signal()
    }
    let timeout = DispatchTime.now() + .seconds(5)
    if semaphore.wait(timeout: timeout) == .timedOut {
        XCTFail("****** REQUEST TIME OUT (get)!!  ********************")
    }
    return ret
}
// MARK: - launch server
func launchServerHttp(_ urls:[String: [String]]) -> (NIOServer, Router) {
    let routes = Router()

    for (seccion, paths) in urls {  // root
        if (seccion == "/") {
            for path in paths {
                if (path == "/") {
                    routes.endpoint( path ).get( httpRootFuncHandler )
                }
                else {
                    routes.endpoint( path ).get( httpFuncHandler )
                }
            }
        }
    }
    for (seccion, paths) in urls { // subrouters
        if (seccion != "/") {
            let subrouter =  routes.router( seccion )
            for path in paths {
                subrouter.endpoint( path ).get( httpFuncHandler )
            }
        }
    }
    return launchServerHttp(routes)
}

func launchServerHttp(_ routes:Router) -> (NIOServer, Router) {
    let server = NIOServer( routes: routes )
    let serverThread = Thread {
        server.run( port: 8080 )
    }
    serverThread.start()
    let serverOk = server.waitForServerRunning()
    XCTAssertTrue(serverOk)
    //usleep(2 * 1000000) // seconds
    return (server, routes)
}

final class MIOServerKitNIOTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        print("tearDown after test")
    }

// MARK: - Replace hndlr
    func testReplaceURLs() throws {
        let routes = Router()
        routes.endpoint( "/").get( httpRootFuncHandler )
        routes.endpoint( "/hook").get( httpFuncHandler )
        routes.endpoint( "/healthz/").get( httpFuncHandler )
        routes.endpoint( "/hook/version").get( httpFuncHandler )
        routes.endpoint( "/healthz/").get( httpFuncHandlerStr2 )

        let (server, _) = launchServerHttp(routes)

        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/healthz/", "Str2"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/version"), 200)
        
        routes.endpoint( "/hook").get( httpFuncHandlerStr2 )
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook", "Str2"), 200)

        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

// MARK: - Root      
    func testRootPaths01() throws {
        let urls: [String: [String]] = [
            "/": ["/", "/hook", "/hook/version"],
        ]
        let (server, _) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/","I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/version"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/version/"), 200)

        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/"), 404)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/hook"), 404)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/hook/"), 404)
       
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

    func testRootPaths02() throws {
        let urls: [String: [String]] = [
            "/": ["/hook/version", "/healthz/version/debug", "/", "/hook", "/healthz", "/healthz/version"],
        ]
        let (server, _) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/","I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/version"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/hook/version/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/healthz/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/healthz/version"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/healthz/version/debug"), 200)
       
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }
// MARK: - 1 subrouter
    func testOneSubrouterPaths01() throws {
        let urls: [String: [String]] = [
            "/svc": ["/ready", "/bookings/business-info", "/bookings/update"],
        ]
        let (server, _) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update/"), 200)
           
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

    func testOneSubrouterPaths04() throws {
        let urls: [String: [String]] = [
            "/svc": ["/bookings/business-info", "/bookings/update", "/ready", "/bookings"],
        ]
        let (server, _) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update/"), 200)

        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready"), 404)
           
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

    func testOneSubrouterPaths03() throws {
        let routes = Router()
        let svc_routes = routes.router( "/svc" )
        svc_routes.endpoint( "/bookings/business/update").get( httpFuncHandler )
        // let readyEP = svc_routes.endpoint( "/ready").get( httpFuncHandler )
        // readyEP.post( httpFuncHandler )
        // svc_routes.endpoint( "/ready/go").post( httpFuncHandler )
        // let bookingsEP = svc_routes.endpoint( "/bookings").get( httpFuncHandler )
        // svc_routes.endpoint( "/bookings/business").get( httpFuncHandler )
        // bookingsEP.post( httpFuncHandler )
        svc_routes.endpoint( "/ready").get( httpFuncHandler ).post( httpFuncHandler )
        svc_routes.endpoint( "/ready/go").post( httpFuncHandler )
        svc_routes.endpoint( "/bookings").get( httpFuncHandler ).post( httpFuncHandler )
        svc_routes.endpoint( "/bookings/business").get( httpFuncHandler )

        let (server, _) = launchServerHttp(routes)

        routes.root.debug_info()
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business/update"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business/update/"), 200)

        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready/go"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready/go/"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/bookings"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/bookings/"), 200)
           
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

     func testOneSubrouterPaths02() throws {
        let routes = Router()
        let svc_routes = routes.router( "/svc" )
        svc_routes.endpoint( "/bookings/business/update").get( httpFuncHandler )
        let readyEP = svc_routes.endpoint( "/ready").get( httpFuncHandler )
        readyEP.post( httpFuncHandler )
        svc_routes.endpoint( "/ready/go").post( httpFuncHandler )
        let bookingsEP = svc_routes.endpoint( "/bookings").get( httpFuncHandler )
        svc_routes.endpoint( "/bookings/business").get( httpFuncHandler )
        bookingsEP.post( httpFuncHandler )
        
        let (server, _) = launchServerHttp(routes)

        //routes.root.debug_info()
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready/go"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/ready/go/"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/bookings"), 200)
        XCTAssertEqual(try canonicalPostRequest("http:/localhost:8080/svc/bookings/"), 200)
           
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

// MARK: - root subrouters
    func testRootAndSubrouterPaths() throws {
        let urls: [String: [String]] = [
            "/": ["/", "/version"],
            "/svc": ["/ready", "/bookings/business-info", "/bookings/update"],
        ]
        let (server, router) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/version"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/version/"), 200)
  
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update/"), 200)
        
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

    func testRootAndTwoSubroutersPaths() throws {
        let urls: [String: [String]] = [
            "/": ["/", "/version"],
            "/svc": ["/ready", "/bookings/business-info", "/bookings/update"],
            "/more": ["/ready", "/another/update"],
        ]
        let (server, _) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/", "I'm Root"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/version"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/version/"), 200)
  
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update/"), 200)

        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/more/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/more/another/update"), 200)
        
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

// MARK: - 2 subrouters
    func testRootTwoRoutersPaths() throws {
         let urls: [String: [String]] = [
            "/svc": ["/ready", "/bookings/business-info", "/bookings/update"],
            "/more": ["/ready", "/another/update"],
        ]
        let (server, _) = launchServerHttp(urls)
        
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/"), 404)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/business-info/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/svc/bookings/update/"), 200)

        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/more/ready/"), 200)
        XCTAssertEqual(try canonicalGetRequest("http:/localhost:8080/more/another/update"), 200)
        
        try server.terminateServer()
 //usleep(useconds_t(2 * 1000000)) // seconds
    }

}

