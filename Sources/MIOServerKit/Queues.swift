//
//  File.swift
//  
//
//  Created by David Trallero on 9/8/21.
//

import Foundation
import MIOCore

let _server_queue_prefix = "com.miolabs.server"

public func sync_queue_id ( _ key: String ) -> DispatchQueue {
    return MIOCoreQueue( label: key, prefix: _server_queue_prefix )
}

public func sync_queue_status ( _ key: String ) -> Bool {
    return MIOCoreQueueStatus( label: key, prefix: _server_queue_prefix )
}

public func sync_queues_set_status ( _ value:Bool, _ key: String ) {
    MIOCoreQueueSetStatus( value: value, label: key, prefix: _server_queue_prefix )
}
