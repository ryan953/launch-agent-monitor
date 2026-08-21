// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BGMonitor",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "BGMonitor",
            path: "Sources/BGMonitor"
        )
    ]
)
