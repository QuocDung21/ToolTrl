// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NekoTrans",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "NekoTrans",
            targets: ["NekoTrans"]
        ),
        .library(
            name: "NekoTransKit",
            targets: ["NekoTransKit"]
        ),
        .library(
            name: "NekoTransiPad",
            targets: ["NekoTransiPad"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NekoTransKit",
            dependencies: [],
            path: "Sources/NekoTrans",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "NekoTransiPad",
            dependencies: [],
            path: "Sources/NekoTransiPad",
            exclude: [
                "Info.plist"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "NekoTrans",
            dependencies: ["NekoTransKit"],
            path: "Sources/NekoTransLauncher",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "NekoTransTests",
            dependencies: ["NekoTransKit"],
            path: "Tests/NekoTransTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
