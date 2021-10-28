//
//  File.swift
//  
//
//  Created by David Trallero on 20/10/21.
//

import Kitura
import KituraCORS
import LoggerAPI
import Foundation


public let asUUID = "([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})"

open class MSKServer<T>: MSKRouter<T> {

    private var kituraRouter: Router
    

    // MARK: Initializer
    
    /// Initialize a `MIORouter` instance.
    /// ### Usage Example: ###
    /// ```swift
    ///  let router = MIORouter()
    /// ```
    public override init() {        
        kituraRouter = Router( )
        super.init( )

        func dispatch ( ) -> RouterHandler {
          return { (request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws -> Void in
              self.dispatchRequest( MSKRouterRequest( request ), MSKRouterResponse( response ) )
          }
        }

        // Setting up CORS
        let options = Options(allowedOrigin: .all, methods: ["GET", "POST"], maxAge: 5)
        let cors = CORS(options: options)

        kituraRouter.all(middleware: cors)
        kituraRouter.post(middleware: BodyParser())
        kituraRouter.put(middleware: BodyParser())

        
        kituraRouter.get(     "*", handler: dispatch( ) )
        kituraRouter.post(    "*", handler: dispatch( ) )
        kituraRouter.delete(  "*", handler: dispatch( ) )
        kituraRouter.put(     "*", handler: dispatch( ) )
        kituraRouter.patch(   "*", handler: dispatch( ) )
        kituraRouter.options( "*", handler: dispatch( ) )

        
        Log.verbose("MIORouter initialized")
    }


 
    public func dispatchRequest ( _ request: MSKRouterRequest, _ response: MSKRouterResponse ) {
        let path = request.url.relativePath
        var route_vars: RouterPathVars = [:]
        let method = EndpointMethod( rawValue: request.method.rawValue )!

        let endpoint = root.match( method
                                 , RouterPath( path )
                                 , &route_vars )
        
        if endpoint != nil {
            request.parameters = route_vars
            self.process( endpoint!.methods[ method ]!.cb, route_vars, request, response )
        } else {
            // TODO: respond: page not found
            response.send( data: "NOT FOUND: \(method.rawValue) \(path)".data(using: .utf8)! )
        }
    }

    open func process ( _ callback: EndpoingRequestDispatcher<T>, _ vars: RouterPathVars, _ request: MSKRouterRequest, _ response: MSKRouterResponse ) { }
    
    public func run ( port:Int ) {
        Kitura.addHTTPServer( onPort: port, with: kituraRouter )
        Kitura.run( )
    }
}
