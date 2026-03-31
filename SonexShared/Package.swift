// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SonexShared",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SonexShared",
            targets: ["SonexShared"]
        ),
    ],
    targets: [
        .target(
            name: "SonexShared",
            path: "Sources/SonexShared"
        ),
    ]
)
