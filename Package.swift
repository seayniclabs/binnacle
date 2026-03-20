// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Binnacle",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "binnacle", targets: ["Binnacle"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Binnacle",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ]
        ),
        .testTarget(
            name: "BinnacleTests",
            dependencies: ["Binnacle"]
        )
    ]
)
