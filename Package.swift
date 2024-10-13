// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SharedQueueServer",
    platforms: [
       .macOS(.v13)
    ],
    products: [
        .plugin(name: "incv", targets: ["incv"])
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/jwt", from: "4.2.2"),
        .package(url: "https://github.com/mapbox/turf-swift.git", from: "3.0.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "Leaf", package: "leaf"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "Turf", package: "turf-swift")
            ],
            resources: [
                .copy("version.json")
            ]
        ),
        .plugin(name: "incv", capability: .command(intent: .custom(verb: "incv", description: "Increment Version Number"), permissions: [.writeToPackageDirectory(reason: "Inc Version Number")]))
    ]
)
