// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport


let package = Package(
    name: "MIOServerKit",
    platforms: [.macOS(.v12)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library( name: "MIOServerKit", targets: ["MIOServerKit"] ),
        .library( name: "MIOServerKit-Kitura", targets: ["MIOServerKit-Kitura"] ),
        .library( name: "MIOServerKit-NIO", targets: ["MIOServerKit-NIO"] ),
        .library( name: "MIOServerKitMacros", targets: ["MIOServerKitMacros"] ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/Kitura/Kitura.git", from: "2.9.200"),
        .package(url: "https://github.com/Kitura/HeliumLogger.git", from: "1.9.200"),
        .package(url: "https://github.com/Kitura/Kitura-CORS.git", from: "2.1.201"),
        .package(url: "https://github.com/miolabs/MIOCore.git", branch: "master"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        // MARK: - Macros
        .macro(
            name: "MIOServerKitMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "MIOCoreLogger", package: "MIOCore"),
            ]
        ),
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "MIOServerKitMacros",
            dependencies: [
                "MIOServerKitMacrosPlugin",
                .product(name: "NIOHTTP1", package: "swift-nio")
            ]
        ),
        
        // A test target used to develop the macro implementation.
        .testTarget(
            name: "MIOServerKitMacrosTests",
            dependencies: [
                "MIOServerKitMacrosPlugin",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

        // MARK: - Server Kit
        .target(
            name: "MIOServerKit",
            dependencies: [
                .product(name: "MIOCore", package: "MIOCore"),
                .product(name: "MIOCoreContext", package: "MIOCore"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "MIOServerKitTests",
            dependencies: ["MIOServerKit"]
        ),

        // MARK: - Kitura
        .target(
            name: "MIOServerKit-Kitura",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Kitura",
                "HeliumLogger",
                .product(name: "KituraCORS", package: "Kitura-CORS"),
                .product(name: "MIOCore", package: "MIOCore"),
                .product(name: "MIOCoreContext", package: "MIOCore"),
//                .product(name: "Fortify", package: "Fortify" )
            ]
        ),
        
        // MARK: - Swift NIO
        .target(
            name: "MIOServerKit-NIO",
            dependencies: [
                "MIOServerKit",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "MIOCore", package: "MIOCore"),                
                .product(name: "MIOCoreContext", package: "MIOCore"),
                .product(name: "MIOCoreLogger", package: "MIOCore"),
//                .product(name: "Fortify", package: "Fortify" )
            ]
        ),
        .testTarget(
            name: "MIOServerKitNIOTests",
            dependencies: ["MIOServerKit-NIO"]
        ),
        

    ]
)
