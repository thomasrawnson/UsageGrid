// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageGrid",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "UsageGrid", targets: ["UsageGrid"])
    ],
    targets: [
        .executableTarget(name: "UsageGrid"),
        .testTarget(name: "UsageGridTests", dependencies: ["UsageGrid"])
    ]
)
