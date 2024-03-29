// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeclarativeNetworking",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "DeclarativeNetworking",
            targets: ["DeclarativeNetworking"]
        ),
    ],
    dependencies: [
        .package(
            name: "DevKit",
            url: "https://github.com/BergerBytes/devkit.git",
            "1.6.0" ..< "1.7.0"
        ),
        .package(
            url: "https://github.com/BergerBytes/Cache",
            "6.0.1" ..< "6.1.0"
        ),
//        .package(
//            url: "https://github.com/BergerBytes/SwiftPlus",
//            branch: "main"
//        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "DeclarativeNetworking",
            dependencies: ["DevKit", "Cache"]
        ),
        .testTarget(
            name: "DeclarativeNetworkingTests",
            dependencies: ["DeclarativeNetworking"]
        ),
    ]
)
