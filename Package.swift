// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HFitCore",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "HFitCore", targets: ["HFitCore"])],
    targets: [
        .target(name: "HFitCore", path: "Sources/HFitCore"),
        .testTarget(name: "HFitCoreTests", dependencies: ["HFitCore"], path: "Tests/HFitCoreTests")
    ]
)
