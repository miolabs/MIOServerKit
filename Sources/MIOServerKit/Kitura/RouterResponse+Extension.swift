//
//  RouterResponse+Extension.swift
//  
//
//  Created by Javier Segura Perez on 17/10/21.
//

//import Kitura
//
//extension RouterResponse
//{
//    // TODO: Used in auth server...
//    public func sendOKResponse(json : Any? = nil) -> RouterResponse {
//
//        status(.OK)
//        if json == nil {
//            send(json: ["status" : "OK"])
//        } else if json is [Any] || json is [String: Any] {
//            send(json: ["status" : "OK", "data" : json! ])
//        }
//
//        return self
//    }
//
//    // TODO: Used in redsys...
//    public func sendErrorResponse(_ error : Error, httpStatus : HTTPStatusCode = .badRequest) -> RouterResponse {
//
//        status(httpStatus)
//
//        send(json: ["status" : "Error",
//                    "error" : error.localizedDescription])
//
//        return self
//    }
//}
