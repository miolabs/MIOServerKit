// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MIOServerKit",
    platforms: [.macOS(.v11)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library( name: "MIOServerKit", targets: ["MIOServerKit"] ),
        .library( name: "MIOServerKit-Kitura", targets: ["MIOServerKit-Kitura"] ),
        .library( name: "MIOServerKit-NIO", targets: ["MIOServerKit-NIO"] ),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
        .package(url: "https://github.com/Kitura/Kitura.git", from: "2.9.200"),
        .package(url: "https://github.com/Kitura/HeliumLogger.git", from: "1.9.200"),
        .package(url: "https://github.com/Kitura/Kitura-CORS.git", from: "2.1.201"),
        .package(url: "https://github.com/miolabs/MIOCore.git", branch: "master"),
//        .package(url: "https://github.com/johnno1962/Fortify.git", from:"1.0.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MIOServerKit",
            dependencies: [
                .product(name: "MIOCore", package: "MIOCore"),
                .product(name: "MIOCoreContext", package: "MIOCore"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log")
            ]),

        .target(
            name: "MIOServerKit-Kitura",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "Kitura",
                "HeliumLogger",
                .product(name: "KituraCORS", package: "Kitura-CORS"),
                "MIOCore",
                .product(name: "MIOCoreContext", package: "MIOCore"),
//                .product(name: "Fortify", package: "Fortify" )
            ]),
        .target(
            name: "MIOServerKit-NIO",
            dependencies: [
                "MIOServerKit",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                "MIOCore",
                .product(name: "MIOCoreContext", package: "MIOCore"),
//                .product(name: "Fortify", package: "Fortify" )
            ]),

        
        
        .testTarget(
            name: "MIOServerKitTests",
            dependencies: ["MIOServerKit"]),
    ]
)
