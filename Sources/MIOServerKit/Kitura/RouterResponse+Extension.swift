//
//  RouterResponse+Extension.swift
//  
//
//  Created by Javier Segura Perez on 17/10/21.
//

import Kitura
import KituraNet

extension RouterResponse
{
    // TODO: Used in auth server...
    public func sendOKResponse (json : Any? = nil) -> RouterResponse {

        status(.OK)
        if json == nil {
            send(json: ["status" : "OK"])
        } else if json is [Any] || json is [String: Any] {
            send(json: ["status" : "OK", "data" : json! ])
        }

        return self
    }

    // TODO: Used in redsys...
    public func sendErrorResponse(_ error : Error, httpStatus : MSKHTTPStatusCode = MSKHTTPStatusCode.badRequest) -> RouterResponse {

        status( KituraNet.HTTPStatusCode( rawValue: httpStatus.rawValue )! )

        send(json: ["status" : "Error",
                    "error" : error.localizedDescription])

        return self
    }
}
