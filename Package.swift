// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ViewLens",
    platforms: [
        .macOS(.v15),
        .macCatalyst(.v18)
    ],
    products: [
        .library(
            name: "ViewLensKit",
            targets: ["ViewLensKit"]
        ),
        .executable(
            name: "viewlens",
            targets: ["ViewLensCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/SerialForBreakfast/NativeUIAuditKit.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "ViewLensKit",
            dependencies: [
                .product(name: "NativeUIAuditKitModels", package: "NativeUIAuditKit"),
                .product(name: "NativeUIAuditKit", package: "NativeUIAuditKit")
            ],
            path: "Sources/ViewLensKit",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .executableTarget(
            name: "ViewLensCLI",
            dependencies: [
                "ViewLensKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/ViewLensCLI",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ViewLensKitTests",
            dependencies: ["ViewLensKit"],
            path: "Tests/ViewLensKitTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "ViewLensCLITests",
            dependencies: [
                "ViewLensKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Tests/ViewLensCLITests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
