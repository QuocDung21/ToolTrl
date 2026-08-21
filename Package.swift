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
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "ToolTrL",
            dependencies: [],
            path: "Sources/ToolTrL",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
