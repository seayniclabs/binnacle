// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Binnacle",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0")
    ],
    targets: [
        .target(
            name: "BinnacleCore",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/BinnacleCore"
        ),
        .executableTarget(
            name: "Binnacle",
            dependencies: [
                "BinnacleCore",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/Binnacle",
            exclude: ["Binnacle.entitlements", "Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Binnacle/Info.plist"
                ])
            ]
        ),
        .testTarget(
            name: "BinnacleTests",
            dependencies: [
                "BinnacleCore",
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Tests/BinnacleTests"
        )
    ]
)
