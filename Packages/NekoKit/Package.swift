// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NekoKit",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "NekoCore", targets: ["NekoCore"]),
        .library(name: "NekoServices", targets: ["NekoServices"]),
        .library(name: "NekoUI", targets: ["NekoUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.0")
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            path: "Frameworks/llama.xcframework"
        ),
        .target(
            name: "NekoCore",
            dependencies: [
                .product(name: "Defaults", package: "Defaults")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "NekoServices",
            dependencies: [
                "NekoCore",
                "llama",
                .product(name: "Defaults", package: "Defaults")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "NekoUI",
            dependencies: [
                "NekoCore",
                "NekoServices",
                .product(name: "Defaults", package: "Defaults")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NekoKitTests",
            dependencies: [
                "NekoCore",
                "NekoServices",
                "NekoUI",
                .product(name: "Defaults", package: "Defaults")
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
