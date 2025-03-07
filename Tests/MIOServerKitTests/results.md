

### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- 2 subrouters
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
let routes = Router()
let ringr_routes = routes.router( "/ringr" )
let route_r = ringr_routes.endpoint( "/ready").get( httpFuncHandler )
let route_1 = ringr_routes.endpoint( "/bookings/business").get( httpFuncHandler )
let more_routes = routes.router( "/more" )

## before inserting the second
(MIOServerKit.Router) 0x0000600003e30be0 {
  root = 0x0000600003063870 {
    MIOServerKit.EndpointTreeNode = {
      value = (MIOServerKit.EndpointTreeLeaf?) 0x0000600003e35260 {
            path = 0x0000600003e35280 {
                parts = 1 value {
                [0] = 0x0000600002b0af00 {
                    name = "ringr"
                    key = "ringr"
                    is_var = false
                    is_optional = false
                    regex = nil
                    }
                }
            }
        }
      nodes = 2 key/value pairs {
        [0] = {
          key = "ready"
          value = 0x000060000300b330 {
            value = 0x0000600003e35340{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
        [1] = {
          key = "bookings"
          value = 0x000060000300b600 {
            value = 0x0000600003e35500{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = nil
    }
  }
}
## after inserting the second
(MIOServerKit.Router) 0x0000600003e30be0 {
  root = 0x0000600003063870 {
    MIOServerKit.EndpointTreeNode = {
      value = nil
      nodes = 2 key/value pairs {
        [0] = {
          key = "more"
          value = 0x000060000300b660 {
            value = 0x0000600003e355e0{...}  **<<<<<<<<<<<<<**
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
        [1] = {
          key = "ringr"
          value = 0x000060000300b5d0 {
            value = 0x0000600003e35260{...}
            nodes = 2 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = nil
    }
  }
}
## after full setup
(MIOServerKit.Router) 0x000060000321da20 {
  root = 0x0000600003c4ff90 {
    MIOServerKit.EndpointTreeNode = {
      value = nil
      nodes = 2 key/value pairs {
        [0] = {
          key = "more"
          value = 0x0000600003c45050 {
            value = nil{...}   **<<<<<<<<<<<<<**
            nodes = 2 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = 0x0000600003c450b0{...}
          }
        }
        [1] = {
          key = "ringr"
          value = 0x0000600003c446c0 {
            value = 0x000060000321dc20{...}  **<<<<<<<<<<<<<** deberia ser nil para q funcione el match
            nodes = 2 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = nil
    }
  }
}


### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- SOLO ROOT  (check if still valid)
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
let routes = Router()
let route_1 = routes.endpoint( "/").get( httpFuncHandler )
let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
let route_3 = routes.endpoint( "/healthz/").get( httpFuncHandler )
let route_4 = routes.endpoint( "/hook/version").get( httpFuncHandler )

Router:
(MIOServerKit.Router) 0x00006000011a1280 {
  root = 0x0000600001ff6850 {
    MIOServerKit.EndpointTreeNode = {
      value = nil  **<<<<<<<<<<<<<**
      nodes = 2 key/value pairs {
   [0] = {
    key = "hook"
    value = 0x000060000057f960 {
      value = nil
      nodes = 1 key/value pair {
        [0] = {
          key = "version"
          value = 0x000060000054d740 {
            value = 0x0000600000b24320{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = 0x00006000005712f0 {
        value = 0x0000600000b1fa20 {
          MIOServerKit.EndpointTreeLeaf = {
            path = 0x0000600000b1fac0{...}
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
  [1] = {
    key = "healthz"
    value = 0x000060000057fdb0 {
      value = 0x0000600000b1fb00 {
        MIOServerKit.EndpointTreeLeaf = {
          path = 0x0000600000b1fa80 {
            parts = 0 values{...}
          }
        }
        methods = 1 key/value pair {
          [0] = {
            key = GET{...}
            value ={...}
          }
        }
      }
      nodes = 0 key/value pairs {}
      var_nodes = 0 values {}
      null_node = nil
    }
  }
}

### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- SOLO SUBROUTER (check if still valid)
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
let routes = Router()
let ringr_routes = routes.router( "/ringr" )
let route_r = ringr_routes.endpoint( "/ready").get( httpFuncHandler )
let route_1 = ringr_routes.endpoint( "/bookings/business").get( httpFuncHandler )
let route_2 = ringr_routes.endpoint( "/bookings/update").get( httpFuncHandler )

router:
(MIOServerKit.EndpointTree) 0x000060000353cf60 {
  MIOServerKit.EndpointTreeNode = {
    value = 0x0000600003b3c280 {   **<<<<<<<<<<<<<**
      path = 0x0000600003b3d080 {
        parts = 1 value {
          [0] = 0x0000600002e3cd00 {
            name = "ringr"{...}
            key = "ringr"{...}
            is_var = false{...}
            is_optional = false{...}
            regex = nil{...}
          }
        }
      }
    }
    nodes = 2 key/value pairs {
   [0] = {
    key = "ready"
    value = 0x000060000353d2f0 {
      value = 0x0000600003b3d480 {
        MIOServerKit.EndpointTreeLeaf = {
          path = 0x0000600003b3d900 {
            parts = 0 values{...}
          }
        }
        methods = 1 key/value pair {
          [0] = {
            key = GET{...}
            value ={...}
          }
        }
      }
      nodes = 0 key/value pairs {}
      var_nodes = 0 values {}
      null_node = nil
    }
  }
  [1] = {
    key = "bookings"
    value = 0x000060000353d260 {
      value = nil
      nodes = 2 key/value pairs {
        [0] = {
          key = "business"
          value = 0x000060000355d2c0 {
            value = 0x0000600003b3dd40{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
        [1] = {
          key = "update"
          value = 0x000060000355cd80 {
            value = 0x0000600003b3de60{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = nil
    }
  }
}


### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
### ---------------- ROOT Y SUBROUTER
### ---------------------------------------------------------------------------------------------
### ---------------------------------------------------------------------------------------------
let routes = Router()
let route_1 = routes.endpoint( "/").get( httpFuncHandler )
let route_2 = routes.endpoint( "/hook").get( httpFuncHandler )
let ringr_routes = routes.router( "/ringr" )
let route_r1 = ringr_routes.endpoint( "/ready").get( httpFuncHandler )
let route_r2 = ringr_routes.endpoint( "/bookings/update").get( httpFuncHandler )

(MIOServerKit.Router) 0x0000600003af6680 {
  root = 0x000060000349eaf0 {
    MIOServerKit.EndpointTreeNode = {
      value = nil
      nodes = 2 key/value pairs {
        [0] = {
          key = "ringr"
          value = 0x00006000034f2e50 {
            value = nil{...}
            nodes = 2 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = 0x00006000034f2dc0{...}
          }
        }
        [1] = {
          key = "hook"
          value = 0x00006000034f3060 {
            value = 0x0000600003af3ce0{...}
            nodes = 0 key/value pairs{...}
            var_nodes = 0 values{...}
            null_node = nil{...}
          }
        }
      }
      var_nodes = 0 values {}
      null_node = 0x00006000034f2e20 {
        value = 0x0000600003af6900 {
          MIOServerKit.EndpointTreeLeaf = {
            path = 0x0000600003af67a0{...}
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