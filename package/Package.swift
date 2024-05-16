// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FiservTTP",
    products: [
        .library(
            name: "FiservTTP",
            targets: ["FiservTTP"]),
    ],
    targets: [
        .binaryTarget(name: "FiservTTP",
                      url: "https://gitlab.onefiserv.net/na/gbs/carat-digital-ecommerce/commercehub/sdk/ch-apple-ttp/-/raw/main/FiservTTP.xcframework.zip",
                      checksum: "6340962aab92b31015f67ed448693229c647f911397282fd0f905c9885ff1c8b")
    ]
)
