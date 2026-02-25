// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STOLFavorites",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "STOLFavorites", targets: ["STOLFavorites"]),
    ],
    dependencies: [
        // STOLData provides the shared TaxonID type.
        .package(path: "../STOLData"),
        // GRDB.swift for local SQLite access (MIT; no network, no PII risk).
        // Version pinned to avoid unreviewed updates.
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "STOLFavorites",
            dependencies: [
                .product(name: "STOLData", package: "STOLData"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "STOLFavoritesTests",
            dependencies: ["STOLFavorites"]
        ),
    ]
)
