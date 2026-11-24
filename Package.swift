// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchBuddy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "NotchBuddy", path: "Sources/NotchBuddy"),
        .testTarget(name: "NotchBuddyTests", dependencies: ["NotchBuddy"], path: "Tests/NotchBuddyTests"),
    ]
)
