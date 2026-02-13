// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "claude-runner",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "claude-runner",
            path: "Sources",
            resources: [
                .copy("../Resources/Info.plist")
            ]
        )
    ]
)
