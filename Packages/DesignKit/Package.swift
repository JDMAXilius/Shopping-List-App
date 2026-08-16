// swift-tools-version: 6.0
import PackageDescription

// macOS is declared alongside iOS so the Mac gate can run `swift test`
// (ContrastTests / SoundAssetTests / GlyphTests); Core does the same.
let package = Package(
    name: "DesignKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "DesignKit", targets: ["DesignKit"])],
    dependencies: [.package(path: "../Core")],
    targets: [
        .target(
            name: "DesignKit",
            dependencies: [.product(name: "Core", package: "Core")],
            resources: [.copy("Resources/check.wav"), .copy("Resources/complete.wav")]
        ),
        .testTarget(
            name: "DesignKitTests",
            dependencies: ["DesignKit", .product(name: "Core", package: "Core")]),
    ]
)
