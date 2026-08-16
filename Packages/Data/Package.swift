// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "Data", targets: ["Data"])],
    dependencies: [
        .package(path: "../Core"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "Data",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
        .testTarget(
            name: "DataTests",
            dependencies: [
                "Data",
                .product(name: "Core", package: "Core"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ]
        ),
    ]
)
