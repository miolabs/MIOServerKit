

### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- ROOT Y SUBROUTER 
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
"/": ["/", "/version"],
"/ringr": ["/ready", "/bookings/business-info", "/bookings/update"],
## no match accessing the subrouter paths, test fails
(MIOServerKit.Router) 0x000060000100cfe0 {
  root = 0x0000600001e30fc0 {
    MIOServerKit.EndpointTreeNode = {
      value = nil
      nodes = 2 key/value pairs {
        [0] = {
          key = "ringr"
          value = 0x0000600001e31170 {
            value = 0x000060000100dfe0{...}
            nodes = 2 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
        [1] = {
          key = "version"
          value = 0x0000600001e310e0 {
            value = 0x000060000100e360{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = 0x0000600001e31140 {
        value = 0x000060000100e0c0 {
          MIOServerKit.EndpointTreeLeaf = {
            path = 0x000060000100e400{...}
          }
          methods = 1 key/value pair {
            [0] ={...}
          }
        }
        nodes = 0 key/value pairs {}
        var_nodes = 0 values {}
        null_node = nil
      }
    }
  }
}
## match, test ok
(MIOServerKit.Router) 0x0000600002949dc0 {
  root = 0x0000600002717270 {
    MIOServerKit.EndpointTreeNode = {
      value = nil
      nodes = 2 key/value pairs {
        [0] = {
          key = "ringr"
          value = 0x0000600002717510 {
            value = nil{...}
            nodes = 2 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = 0x0000600002717600{...}
          }
        }
        [1] = {
          key = "version"
          value = 0x0000600002717060 {
            value = 0x0000600002940f80{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = 0x0000600002717480 {
        value = 0x0000600002940640 {
          MIOServerKit.EndpointTreeLeaf = {
            path = 0x0000600002940d40{...}
          }
          methods = 1 key/value pair {
            [0] ={...}
          }
        }
        nodes = 0 key/value pairs {}
        var_nodes = 0 values {}
        null_node = nil
      }
    }
  }
}