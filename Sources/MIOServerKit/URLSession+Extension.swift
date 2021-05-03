//
//  File.swift
//  
//
//  Created by Javier Segura Perez on 3/5/21.
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif


extension URLSession {
    
    public func synchronousDataTask(with request: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data: Data?
        var response: URLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.dataTask(with: request) {
            data = $0
            response = $1
            error = $2

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        return (data, response, error)
    }
}
