// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MIOServerKit",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "MIOServerKit",
            targets: ["MIOServerKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.4.0"),
        .package(url: "https://github.com/Kitura/Kitura.git", from: "2.9.1"),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", from: "1.9.0"),
        .package(url: "https://github.com/IBM-Swift/Kitura-CORS.git", from: "2.1.1"),
        .package(url: "https://github.com/miolabs/MIOCore.git", .branch("master")),
        // .package(url: "https://github.com/miolabs/MIOCoreData.git", .branch("master")),
        // .package(url: "https://github.com/miolabs/MIODB.git", .branch("master")),
        // .package(url: "https://github.com/miolabs/MIOPersistentStore.git", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "MIOServerKit",
            dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser"), "Kitura",  "HeliumLogger", "KituraCORS", "MIOCore", // "MIOCoreData", "MIODB", "MIOPersistentStore"
            ]),
        .testTarget(
            name: "MIOServerKitTests",
            dependencies: ["MIOServerKit"]),
    ]
)
