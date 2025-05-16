# MIOServerKit

MIOServerKit is a lightweight, flexible Swift server framework that provides HTTP routing capabilities with multiple backend implementations. It offers a consistent API while supporting both IBM's Kitura and Apple's SwiftNIO as underlying engines.

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

// Using async endpoint handlers
server.router.endpoint("/users").get { (context: RouterContext) async throws -> Any? in
    // Perform async operations
    let users = try await fetchUsersFromDatabase()
    return ["users": users]
}

// With path parameters
server.router.endpoint("/users/:id").get { (context: RouterContext) async throws -> Any? in
    let userId: String = try context.urlParam("id")
    let user = try await fetchUserById(userId)
    return user
}
```

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
