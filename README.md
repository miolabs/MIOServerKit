![macOS: supported](https://img.shields.io/badge/macOS-supported-green)
![macOS: supported](https://img.shields.io/badge/iOS-supported-green)
![Linux: supported](https://img.shields.io/badge/linux-supported-green)
![Windows: supported](https://img.shields.io/badge/windows-not_supported-red)

# MIOServerKit

MIOServerKit is a lightweight, flexible Swift server framework that provides HTTP routing capabilities with multiple backend implementations. It offers a consistent API while supporting both IBM's Kitura and Apple's SwiftNIO as underlying engines.

### ⚠️ Warning

**Kitura server is deprecated. It will be delete in future  releases.**

## Features

- Multi-backend support (Kitura and SwiftNIO)
- Robust routing system with path parameters and regex support
- Middleware capabilities for request/response processing
- Configurable server settings
- Clean, protocol-based API design

## Installation

### Swift Package Manager

Add MIOServerKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/MIOServerKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: [
            .product(name: "MIOServerKit", package: "MIOServerKit"),
            // Or use a specific backend:
            // .product(name: "MIOServerKit-Kitura", package: "MIOServerKit"),
            // .product(name: "MIOServerKit-NIO", package: "MIOServerKit")
        ]
    )
]
```

## Usage Kitura server option

### Basic Example

```swift
import MIOServerKit

// Create a server instance
let server = Server()

// Add routes
server.router.get("/hello") { request, response, next in
    response.send("Hello, World!")
    next()
}

// Start the server
try server.start(port: 8080)
```

### Using Path Parameters

```swift
server.router.get("/users/:id") { request, response, next in
    if let userId = request.parameters["id"] {
        response.send("User ID: \(userId)")
    }
    next()
}
```

## Usage SwiftNIO server option

### Basic Example

```swift
import MIOServerKit

// Create a server instance
let server = Server()

// Add routes
server.router.get("/hello") { context in
    return "Hello, World!"    
}

// Start the server
try server.start(port: 8080)
```

### Using Path Parameters

```swift
server.router.get("/users/:id") { context in
    if let userId = context.urlParam("id") {
        return "User ID: \(userId)"
    }
    return "User not found"
}
```

### Using Router Context

The `RouterContext` provides a convenient way to access request data and send responses. It also support sync and async/awaits for handling requests.

```swift
// Sync version
server.router.endpoint("/api/data").post { context in throws -> Any? in
    // Access body parameters
    let name: String = try context.bodyParam("name")
    let age: Int = try context.bodyParam("age")
    
    // Return JSON response
    return ["status": "success", "data": ["name": name, "age": age]]
}

// Async version
server.router.endpoint("/api/data").post { context in async throws -> Any? in
    // Access body parameters
    let name: String = try context.bodyParam("name")
    
    // Perform async operations
    let userData = try await processUserData(name)
    
    // Return JSON response
    return userData
}

// With path parameters
server.router.endpoint("/users/:id").get { context in async throws -> Any? in
    let userId: String = try context.urlParam("id")
    let user = try await fetchUserById(userId)
    return user
}
```

### Declarative endpoints with @Endpoint

Instead of registering routes by hand, any function can publish itself as an endpoint with the `@Endpoint` annotation:

```swift
import MIOServerKit
import MIOServerKitMacros

@Endpoint( [.get, .post], path: "/api/schema/:schema" )
func schemaHandler( context: RouterContext ) throws -> (any Sendable)? {
    let schema: String = try context.urlParam( "schema" )
    return [ "schema": schema ]
}

// Methods default to [.get]. Async handlers work too.
@Endpoint( path: "/api/version" )
func versionHandler( context: RouterContext ) async throws -> (any Sendable)? {
    return "1.0"
}

// Static functions inside a type are supported as well.
class EntityAPI {
    @Endpoint( [.delete], path: "/api/entity/:id" )
    static func deleteEntity( context: RouterContext ) throws -> (any Sendable)? { return nil }
}
```

The macro itself is a compile-time validator only — Swift compiler plugins run inside a sandbox and cannot write files. The actual route registration file is produced by the `generate-endpoints` tool, which runs as a **pre-build step**. It parses all Swift sources with swift-syntax, collects every `@Endpoint` annotation and writes `Endpoints+Generated.swift`:

```bash
# From your server project (or hook it as an Xcode/CI pre-build phase):
path/to/MIOServerKit/Scripts/generate_endpoints.sh \
    --sources Sources/MyServer \
    --output Sources/MyServer/Endpoints+Generated.swift

# Optionally also emit a JSON description of the routes:
#   --json endpoints.json
# See all options:
#   ... generate_endpoints.sh --help
```

The generated file extends `Router`, so the only manual step is:

```swift
let server = Server()
server.router.registerGeneratedEndpoints()
```

The tool only rewrites the file when routes actually changed (so it never dirties incremental builds), fails the build on duplicate method+path registrations, and the macro reports malformed annotations (missing path, unsupported method, wrong handler signature) directly in the compiler diagnostics.

### Choosing a Backend

By default, MIOServerKit will use the most appropriate backend available. To explicitly choose a backend:

```swift
// Using Kitura
import MIOServerKit_Kitura

let server = MSKServer()

// Using NIO
import MIOServerKit_NIO

let server = Server() // NIO implementation
```

## Building and Testing

Build the package:
```
swift build
```

Run tests:
```
swift test
```

Run a specific test:
```
swift test --filter MIOServerKitTests/testSpecificName
```

## License

[MIT License](LICENSE)
