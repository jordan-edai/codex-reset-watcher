// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexResetWatcher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexResetWatcher", targets: ["CodexResetWatcher"])
    ],
    targets: [
        .executableTarget(
            name: "CodexResetWatcher",
            path: "Sources/CodexResetWatcher"
        ),
        .testTarget(
            name: "CodexResetWatcherTests",
            dependencies: ["CodexResetWatcher"],
            path: "Tests/CodexResetWatcherTests"
        )
    ]
)
