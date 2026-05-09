// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "codex-usage",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "CodexUsageKit",
            targets: ["CodexUsageKit"]
        ),
        .executable(
            name: "CodexUsageApp",
            targets: ["CodexUsageApp"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.99.0"),
    ],
    targets: [
        .target(
            name: "CodexUsageKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .executableTarget(
            name: "CodexUsageApp",
            dependencies: [
                "CodexUsageKit",
            ],
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "CodexUsageKitTests",
            dependencies: [
                "CodexUsageKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            resources: [
                .copy("Fixtures"),
            ]
        ),
        .testTarget(
            name: "SmokeTests",
            dependencies: [
                "CodexUsageKit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
