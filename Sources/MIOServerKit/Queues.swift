//
//  File.swift
//  
//
//  Created by David Trallero on 9/8/21.
//

import Foundation

var g_sync_queue: [ String: DispatchQueue ] = [:]

public func sync_queue_id ( _ key: String ) -> DispatchQueue {
    if g_sync_queue[ key ] == nil {
        g_sync_queue[ key ] = DispatchQueue(label: "com.dual-link.server." + key )
    }
    
    return g_sync_queue[ key ]!
}
