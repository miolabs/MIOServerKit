//
//  Queues.swift
//  
//
//  Created by David Trallero on 9/8/21.
//  Modified by Javier Segura on 12/03/23.
//

import Foundation

var g_sync_queue: [ String: DispatchQueue ] = [:]

let server_queue = DispatchQueue(label: "com.miolabs.server.main" )

public func sync_queue_id ( _ key: String ) -> DispatchQueue {
    var queue:DispatchQueue? = nil
    
    server_queue.sync {
        if !g_sync_queue.keys.contains( key ) {
            g_sync_queue[ key ] = DispatchQueue(label: "com.miolabs.server." + key )
        }
        
        queue = g_sync_queue[ key ]
    }
    
    return queue!
}
