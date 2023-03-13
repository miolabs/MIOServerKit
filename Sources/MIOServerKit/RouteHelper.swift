//
//  RouteHelper.swift
//  DLAPIServer
//
//  Created by David Trallero on 07/07/2020.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation

public typealias RequestDispatcher<T> = (T) throws -> Any

open class EndpointHooks<T>
{
    let GET: RequestDispatcher<T>?
    let POST:RequestDispatcher<T>?
    let PUT: RequestDispatcher<T>?
    let PATCH: RequestDispatcher<T>?
    let DELETE: RequestDispatcher<T>?

    public init(
        get:    RequestDispatcher<T>? = nil,
        post:   RequestDispatcher<T>? = nil,
        put:    RequestDispatcher<T>? = nil,
        patch:  RequestDispatcher<T>? = nil,
        delete: RequestDispatcher<T>? = nil ) {
      GET    = get
      POST   = post
      PUT    = put
      PATCH  = patch
      DELETE = delete
    }
}

/*
open class ServerRouter<T>
{
//    public var router = Router()
    
    public init() {
        
        // Setting up CORS
//        let options = Options(allowedOrigin: .all, methods: ["GET", "POST"], maxAge: 5)
//        let cors = CORS(options: options)
//
//        router.all(middleware: cors)
//        router.post(middleware: BodyParser())
//        router.put(middleware: BodyParser())
    }
    
    open func GET ( _ endpoint: String, _ fn: @escaping RequestDispatcher<T> ) {
//    router.get( endpoint, handler: request_dispatcher(fn) )
    //get( endpoint + "/:entity_id?", handler: request_dispatcher(fn) )
  }

  open func POST ( _ endpoint: String, _ fn: @escaping RequestDispatcher<T>) {
//    router.post( endpoint, handler: request_dispatcher(fn) )
  }

  open func PUT ( _ endpoint: String, _ fn: @escaping RequestDispatcher<T> ) {
//    router.put( endpoint, handler: request_dispatcher(fn) )
  }

  open func PATCH ( _ endpoint: String, _ fn: @escaping RequestDispatcher<T> ) {
    //patch( endpoint + "/:entity_id", handler: request_entity_dispatcher(fn) )
//    router.patch( endpoint, handler: request_dispatcher(fn) )
  }

  open func DELETE ( _ endpoint: String, _ fn: @escaping RequestDispatcher<T> ) {
    //delete( endpoint + "/:entity_id", handler: request_entity_dispatcher(fn) )
//    router.delete( endpoint, handler: request_dispatcher(fn) )
  }

  open func endpoint ( _ path: String, _ hooks: EndpointHooks<T> ) -> Void {
    if hooks.GET    != nil { self.GET(    path, hooks.GET!    ) }
    if hooks.POST   != nil { self.POST(   path, hooks.POST!   ) }
    if hooks.PUT    != nil { self.PUT(    path, hooks.PUT!    ) }
    if hooks.PATCH  != nil { self.PATCH(  path, hooks.PATCH!  ) }
    if hooks.DELETE != nil { self.DELETE( path, hooks.DELETE! ) }
  }

  // if fn return nil, nothing will be done
<<<<<<< HEAD
  open func request_dispatcher( _ fn: @escaping RequestDispatcher<T> ) -> RouterHandler {
    
    return { (request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws -> Void in
        try self.context_dispatcher( RouterContext( RouterRequest( request ), RouterResponse( response ) ), fn )
    }
  }
=======

    //TODO: Review this
//open func request_dispatcher( _ fn: @escaping RequestDispatcher<T> ) -> RouterHandler {
//
//    return { (request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws -> Void in
//        try self.context_dispatcher( RouterContext( RouterRequest( request ), RouterResponse( response ) ), fn )
//    }
//  }
>>>>>>> c63c849bacc0851be0dfcb401a5825219e90759f

  // if fn return nil, nothing will be done
//  public func request_entity_dispatcher( _ fn: @escaping RequestEntityDispatcher ) -> RouterHandler {
//    return { (request: RouterRequest, response: RouterResponse, next: @escaping () -> Void) throws -> Void in
//        try self.context_dispatcher(request, response, next ) { context in
//            let entity_id: String = try context.param( "entity_id" )
//            return try fn( context, entity_id )
//        }
//    }
//  }

    //TODO: review this
//    open func context_dispatcher( _ context:RouterContext, _ fn: @escaping RequestDispatcher<T> ) throws -> Void {
//        //try _context_dispatcher(context, fn)
//    }
        
//    func _context_dispatcher( _ context:RouterContext, _ fn: @escaping RequestDispatcher<T> ) throws -> Void {
//    //defer { context.disconnect( ) }
//
//    do {
//        let response_data = try fn( context )
//        //try context.save( )
//
//        willDispatchRequest( context, responseData: response_data )
//        try context.sendOKResponse( response_data )
//        didDispatchRequest( context, responseData: response_data )
//    } catch {
//        print( "[DISPATCH ERROR]: \(error.localizedDescription.prefix(2048))" )
//        try context.sendErrorResponse( error, httpStatus: .OK )
//    }
//  }

    //TODO: review
//    open func willDispatchRequest ( _ context: RouterContext, responseData:Any? ) {
//    }
//
//    open func didDispatchRequest ( _ context: RouterContext, responseData:Any? ) {
//    }
}
*/


//public func response_not_found ( _ response: RouterResponse, _ entity: String, _ id: String ) {
//    _ = response.sendErrorResponse(DLDBError.objectNotFound(entity: entity, id: id), httpStatus: HTTPStatusCode.notFound)
//}


 

