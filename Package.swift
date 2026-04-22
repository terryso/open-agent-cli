// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OpenAgentCLI",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "openagent",
            targets: ["OpenAgentCLI"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/terryso/open-agent-sdk-swift",
            branch: "main"
        ),
    ],
    targets: [
        .executableTarget(
            name: "OpenAgentCLI",
            dependencies: [
                .product(name: "OpenAgentSDK", package: "open-agent-sdk-swift"),
            ],
            path: "Sources/OpenAgentCLI"
        ),
        .testTarget(
            name: "OpenAgentCLITests",
            dependencies: ["OpenAgentCLI"],
            path: "Tests/OpenAgentCLITests"
        ),
        .testTarget(
            name: "OpenAgentE2ETests",
            dependencies: ["OpenAgentCLI"],
            path: "Tests/OpenAgentE2ETests"
        ),
    ]
)
