Test Case '-[MIOServerKitNIOTests.MIOServerKitNIOTests testOneSubrouterPaths03]' started.
router: node '/svc' NOT found
2025-03-28T13:46:10+0100 info MIOServerKit.Server : [MIOServerKit] NO_NAME x.x.x
send failed: Invalid argument
send failed: Invalid argument
2025-03-28T13:46:10+0100 info MIOServerKit_NIO.Server+NIO : [MIOServerKit_NIO] Server started and listening on [IPv4]0.0.0.0/0.0.0.0:8080
value: (null)
null_node: (null)
var_nodes: 0
nodes: 1
nodes[svc]
    value: (null)
    null_node: 
        value: 
            /
        null_node: (null)
        var_nodes: 0
        nodes: 0
    var_nodes: 0
    nodes: 2
    nodes[ready]
        value: (null)
        null_node: 
            value: 
                /
                  -> GET <no extra url>
                  -> POST <no extra url>
            null_node: (null)
            var_nodes: 0
            nodes: 0
        var_nodes: 0
        nodes: 1
        nodes[go]
            value: 
                /
                  -> POST <no extra url>
            null_node: (null)
            var_nodes: 0
            nodes: 0
    nodes[bookings]
        value: (null)
        null_node: 
            value: 
                /
                  -> GET <no extra url>
                  -> POST <no extra url>
            null_node: (null)
            var_nodes: 0
            nodes: 0
        var_nodes: 0
        nodes: 1
        nodes[business]
            value: (null)
            null_node: 
                value: 
                    /
                      -> GET <no extra url>
                null_node: (null)
                var_nodes: 0
                nodes: 0
            var_nodes: 0
            nodes: 1
            nodes[update]
                value: 
                    /
                      -> GET <no extra url>
                null_node: (null)
                var_nodes: 0
                nodes: 0
nw_socket_handle_socket_event [C1.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012ce0ae90)
------------channelRead  ObjectIdentifier(0x000000012ce0ae90)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012ce0ae90)
------------requestComplete
------------dispatchRequest  path: /svc/ready
------------completeResponse  ObjectIdentifier(0x000000012ce0ae90)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012ce0ae90)
nw_socket_handle_socket_event [C2.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012ce0b570)
------------channelRead  ObjectIdentifier(0x000000012ce0b570)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012ce0b570)
------------requestComplete
------------dispatchRequest  path: /svc
------------404
------------completeResponse  ObjectIdentifier(0x000000012ce0b570)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012ce0b570)
nw_socket_handle_socket_event [C3.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012ce0ded0)
------------channelRead  ObjectIdentifier(0x000000012ce0ded0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012ce0ded0)
------------requestComplete
------------dispatchRequest  path: /svc
------------404
------------completeResponse  ObjectIdentifier(0x000000012ce0ded0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012ce0ded0)
nw_socket_handle_socket_event [C4.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012e01eba0)
------------channelRead  ObjectIdentifier(0x000000012e01eba0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e01eba0)
------------requestComplete
------------dispatchRequest  path: /svc/ready
------------completeResponse  ObjectIdentifier(0x000000012e01eba0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e01eba0)
nw_socket_handle_socket_event [C5.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012e020a30)
------------channelRead  ObjectIdentifier(0x000000012e020a30)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e020a30)
------------requestComplete
------------dispatchRequest  path: /svc/ready
------------completeResponse  ObjectIdentifier(0x000000012e020a30)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e020a30)
nw_socket_handle_socket_event [C6.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012ce110d0)
------------channelRead  ObjectIdentifier(0x000000012ce110d0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012ce110d0)
------------requestComplete
------------dispatchRequest  path: /svc/bookings
------------completeResponse  ObjectIdentifier(0x000000012ce110d0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012ce110d0)
nw_socket_handle_socket_event [C7.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012e025d30)
------------channelRead  ObjectIdentifier(0x000000012e025d30)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e025d30)
------------requestComplete
------------dispatchRequest  path: /svc/bookings/business
------------completeResponse  ObjectIdentifier(0x000000012e025d30)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e025d30)
nw_socket_handle_socket_event [C8.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000011e204ab0)
------------channelRead  ObjectIdentifier(0x000000011e204ab0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000011e204ab0)
------------requestComplete
------------dispatchRequest  path: /svc/bookings/business/update
------------completeResponse  ObjectIdentifier(0x000000011e204ab0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000011e204ab0)
nw_socket_handle_socket_event [C9.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012cf1d120)
------------channelRead  ObjectIdentifier(0x000000012cf1d120)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012cf1d120)
------------requestComplete
------------dispatchRequest  path: /svc/bookings/business/update
------------completeResponse  ObjectIdentifier(0x000000012cf1d120)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012cf1d120)
nw_socket_handle_socket_event [C10.1.1:2] Socket SO_ERROR [61: Connection refused]
------------handlerAdded  ObjectIdentifier(0x000000012e02bdd0)
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestComplete
------------dispatchRequest  path: /svc/ready
------------completeResponse  ObjectIdentifier(0x000000012e02bdd0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e02bdd0)
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestComplete
------------dispatchRequest  path: /svc/ready
------------completeResponse  ObjectIdentifier(0x000000012e02bdd0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e02bdd0)
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestComplete
------------dispatchRequest  path: /svc/ready/go
------------completeResponse  ObjectIdentifier(0x000000012e02bdd0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e02bdd0)
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestComplete
------------dispatchRequest  path: /svc/ready/go
------------completeResponse  ObjectIdentifier(0x000000012e02bdd0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e02bdd0)
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestComplete
------------dispatchRequest  path: /svc/bookings
------------completeResponse  ObjectIdentifier(0x000000012e02bdd0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e02bdd0)
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestReceived
------------channelRead  ObjectIdentifier(0x000000012e02bdd0)
------------requestComplete
------------dispatchRequest  path: /svc/bookings
------------completeResponse  ObjectIdentifier(0x000000012e02bdd0)
------------responseComplete
------------channelReadComplete  ObjectIdentifier(0x000000012e02bdd0)
Server terminated.
Test Case '-[MIOServerKitNIOTests.MIOServerKitNIOTests testOneSubrouterPaths03]' passed (3.930 seconds).
Test Suite 'MIOServerKitNIOTests' passed at 2025-03-28 13:46:14.403.
	 Executed 1 test, with 0 failures (0 unexpected) in 3.930 (3.931) seconds
Test Suite 'MIOServerKitNIOTests.xctest' passed at 2025-03-28 13:46:14.403.
	 Executed 1 test, with 0 failures (0 unexpected) in 3.930 (3.932) seconds
Test Suite 'Selected tests' passed at 2025-03-28 13:46:14.404.
	 Executed 1 test, with 0 failures (0 unexpected) in 3.930 (3.933) seconds
Program ended with exit code: 0