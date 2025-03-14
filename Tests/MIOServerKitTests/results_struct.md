
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- Root
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
let route_1 = routes.endpoint( "/").get( httpFuncHandler )
let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )
###
value: (null)
null_node: 
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0
var_nodes: 0
nodes: 2
nodes[hook]
  value: (null)
  null_node: 
    value: 
      Empty (will be /) ->   # parts: 0 
        -> GET <no extra url>
    null_node: (null)
    var_nodes: 0
    nodes: 0
  var_nodes: 0
  nodes: 1
  nodes[version]
    value: 
      Empty (will be /) ->   # parts: 0 
        -> GET <no extra url>
    null_node: (null)
    var_nodes: 0
    nodes: 0
nodes[healthz]
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0

### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- Root and one subrouter
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
let routes = Router()
let route_1 = routes.endpoint( "/").get( httpFuncHandler )
let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
let ringr_routes = routes.router( "/ringr" )
let route_r1 = ringr_routes.endpoint( "/ready").get( httpFuncHandler )
let route_r2 = ringr_routes.endpoint( "/bookings/update").get( httpFuncHandler )
## -------------------------------- tras barra
value: 
  Empty (will be /) ->   # parts: 0 
    -> GET <no extra url>
null_node: (null)
var_nodes: 0
nodes: 0
## -------------------------------- tras /hook
value: (null)
null_node: 
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0
var_nodes: 0
nodes: 1
nodes[hook]
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0
router: node '/ringr' NOT found
## -------------------------------- tras /ringr
value: (null)
null_node: 
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0
var_nodes: 0
nodes: 2
nodes[ringr]
  value: 
    Empty (will be /) ->   # parts: 0 
  null_node: (null)
  var_nodes: 0
  nodes: 0
nodes[hook]
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0
## -------------------------------- final
value: (null)
null_node: 
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0
var_nodes: 0
nodes: 2
nodes[ringr]
  value: (null)
  null_node: 
    value: 
      Empty (will be /) ->   # parts: 0 
    null_node: (null)
    var_nodes: 0
    nodes: 0
  var_nodes: 0
  nodes: 2
  nodes[ready]
    value: 
      Empty (will be /) ->   # parts: 0 
        -> GET <no extra url>
    null_node: (null)
    var_nodes: 0
    nodes: 0
  nodes[bookings]
    value: 
      update ->   # parts: 1  'update' 
        -> GET <no extra url>
    null_node: (null)
    var_nodes: 0
    nodes: 0
nodes[hook]
  value: 
    Empty (will be /) ->   # parts: 0 
      -> GET <no extra url>
  null_node: (null)
  var_nodes: 0
  nodes: 0