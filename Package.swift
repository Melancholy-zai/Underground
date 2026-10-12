// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MetroCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "MetroCore", targets: ["MetroCore"])],
    targets: [
        .target(name: "MetroCore"),
        .testTarget(name: "MetroCoreTests", dependencies: ["MetroCore"])
    ]
)
