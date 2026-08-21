// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ToolTrL",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "ToolTrL",
            targets: ["ToolTrL"]
        ),
        .library(
            name: "ToolTrLKit",
            targets: ["ToolTrLKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ToolTrLKit",
            dependencies: [],
            path: "Sources/ToolTrL",
            exclude: [
                "App/ToolTrLApp.swift"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "ToolTrL",
            dependencies: ["ToolTrLKit"],
            path: "Sources/ToolTrLLauncher",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
