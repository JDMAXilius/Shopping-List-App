// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Catalog",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "Catalog", targets: ["Catalog"])
    ],
    targets: [
        .systemLibrary(name: "CSQLite", path: "Sources/CSQLite"),
        .target(
            name: "Catalog",
            dependencies: ["CSQLite"],
            resources: [.copy("Resources/catalog.db")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(name: "CatalogTests", dependencies: ["Catalog"]),
    ]
)
