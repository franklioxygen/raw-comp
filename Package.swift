// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RawComp",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RawComp", targets: ["RawComp"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .executableTarget(
            name: "RawComp",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            exclude: [
                "Info.plist",
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-DCI_SILENCE_GL_DEPRECATION"], .when(configuration: .debug)),
                .unsafeFlags(["-Xcc", "-DCI_SILENCE_GL_DEPRECATION"], .when(configuration: .release))
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/RawComp/Info.plist",
                ], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "RawCompTests",
            dependencies: ["RawComp"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
