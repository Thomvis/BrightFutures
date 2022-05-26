// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "BrightFutures",
    products: [
        .library(
            name: "BrightFutures",
            targets: ["BrightFutures"]),
    ],
    targets: [
        .target(
            name: "BrightFutures",
            dependencies: []),
        .testTarget(
            name: "BrightFuturesTests",
            dependencies: ["BrightFutures"],
            path: "Tests/BrightFuturesTests")
    ]
)
