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

## Usage

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

Generate Xcode project:
```
swift package generate-xcodeproj
```

## License

[MIT License](LICENSE)