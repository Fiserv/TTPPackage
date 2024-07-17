// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FiservTTP",
    platforms: [
            .iOS("16.7")
        ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "FiservTTP",
            targets: ["FiservTTP"]),
    ],
    targets: [
        .target(name: "FiservTTP", dependencies: [], path: "Sources"),
        .testTarget(name: "FiservTTPTests", dependencies: ["FiservTTP"])
    ],
    swiftLanguageVersions: [.v5]
)

