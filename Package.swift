import PackageDescription

let package = Package(
    name: "BrightFutures",
    dependencies: [
      .Package(
        url: "https://github.com/antitypical/Result",
        majorVersion: 3
      )
    ],
    exclude: ["BrightFutures.xcworkspace", "BrightFutures.xcodeproj", "BrightFuturesTests", "Carthage", "Documentation"]
)
