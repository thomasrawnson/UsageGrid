// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UsageGrid",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "UsageGrid", targets: ["UsageGrid"]),
        .executable(name: "UsageGridClaudeCapture", targets: ["UsageGridClaudeCapture"])
    ],
    targets: [
        .target(name: "UsageGridClaudeCore"),
        .executableTarget(name: "UsageGrid", dependencies: ["UsageGridClaudeCore"]),
        .executableTarget(name: "UsageGridClaudeCapture", dependencies: ["UsageGridClaudeCore"]),
        .testTarget(name: "UsageGridTests", dependencies: ["UsageGrid", "UsageGridClaudeCore"])
    ]
)
