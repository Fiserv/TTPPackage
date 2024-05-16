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
                      checksum: "1f9a08d19372fdc5f79d5f2c0c4f3090e6c99d17f6bb955248f52109f47bd04f")
    ]
)
