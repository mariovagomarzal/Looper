// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .strictMemorySafety(),
]

let package = Package(
    name: "LooperPackage",
    platforms: [.macOS("27.0")],
    // Products define the executables and libraries a package produces, making them visible to other packages.
    products: [
        .executable(name: "looper", targets: ["Cli"]),
        .executable(name: "LooperApp", targets: ["LooperApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/InerziaSoft/ISSoundAdditions.git", exact: "2.0.1"),
        .package(url: "https://github.com/dduan/TOMLDecoder", exact: "0.4.5"),
        .package(url: "https://github.com/apple/swift-collections.git", exact: "1.6.0", traits: ["UnstableHashedContainers"]),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", exact: "604.0.0"),
    ],
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    targets: [
        // Exposes the private _AXUIElementGetWindow function to swift
        .target(
            name: "PrivateApi",
            path: "Sources/PrivateApi",
            publicHeadersPath: "include",
        ),
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
        ),
        .target(
            name: "Common",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
                .target(name: "Macros"),
            ],
            swiftSettings: swiftSettings,
        ),
        .target(
            name: "AppBundle",
            dependencies: [
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "ISSoundAdditions", package: "ISSoundAdditions"),
                .product(name: "TOMLDecoder", package: "TOMLDecoder"),
                .target(name: "Common"),
                .target(name: "Macros"),
                .target(name: "PrivateApi"),
            ],
            swiftSettings: swiftSettings,
        ),
        .executableTarget(
            name: "LooperApp",
            dependencies: [
                .target(name: "AppBundle"),
                .target(name: "Macros"),
            ],
            swiftSettings: swiftSettings,
        ),
        .executableTarget(
            name: "Cli",
            dependencies: [
                .target(name: "Common"),
                .target(name: "Macros"),
            ],
            swiftSettings: swiftSettings,
        ),
        .testTarget(
            name: "AppBundleTests",
            dependencies: [
                .target(name: "AppBundle"),
                .target(name: "Macros"),
            ],
            exclude: ["Fixtures"],
            swiftSettings: swiftSettings,
        ),
    ],
)
