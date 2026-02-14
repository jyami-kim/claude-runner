// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "claude-runner",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "ClaudeRunnerLib",
            path: "Sources",
            resources: [
                .copy("../Resources/Info.plist"),
                .copy("../Scripts/claude-runner-hook.sh"),
            ],
        ),
        .executableTarget(
            name: "claude-runner",
            dependencies: ["ClaudeRunnerLib"],
            path: "Entry"
        ),
        .testTarget(
            name: "ClaudeRunnerTests",
            dependencies: ["ClaudeRunnerLib"],
            path: "Tests"
        )
    ]
)
