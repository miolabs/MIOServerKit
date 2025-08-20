//
//  EndpointStackable.swift
//  MIOServerKit
//
//  Created by Javier Segura Perez on 17/5/25.
//

// Define the protocol for endpoint registration
public protocol EndpointRegisterable: AnyObject
{
    static var endpointPath: String { get }
    static var endpointParentClass: EndpointRegisterable.Type? { get }
}
