import PackageDescription

let package = Package(
    name: "BrightFutures",
    dependencies: [
        .Package(url: "https://github.com/antitypical/Result.git", majorVersion: 4),
    ]
)
