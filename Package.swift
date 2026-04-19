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
            path: "../open-agent-sdk-swift"
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
    ]
)
