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
        .package(
            url: "https://github.com/andybest/linenoise-swift",
            revision: "cbf0a35c6e159e4fe6a03f76c8a17ef08e907b0e"
        ),
    ],
    targets: [
        .executableTarget(
            name: "OpenAgentCLI",
            dependencies: [
                .product(name: "OpenAgentSDK", package: "open-agent-sdk-swift"),
                .product(name: "LineNoise", package: "linenoise-swift"),
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
