// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RawComp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RawComp", targets: ["RawComp"])
    ],
    targets: [
        .executableTarget(
            name: "RawComp"
        ),
        .testTarget(
            name: "RawCompTests",
            dependencies: ["RawComp"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
