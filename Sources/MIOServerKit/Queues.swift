//
//  File.swift
//  
//
//  Created by David Trallero on 9/8/21.
//

import Foundation
import MIOCore

public func sync_queue_id ( _ key: String ) -> DispatchQueue {
    return MIOCoreQueue( label: key, prefix: "com.miolabs.server" )
}
