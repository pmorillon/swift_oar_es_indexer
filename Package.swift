// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift_oar_es_indexer",
    dependencies: [
        .package(url: "https://github.com/vapor-community/postgresql.git", from: "2.1.1"),
        .package(url: "https://github.com/vapor/console.git", from: "2.3.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "swift_oar_es_indexer",
            dependencies: ["PostgreSQL", "Console"]),
    ]
)
