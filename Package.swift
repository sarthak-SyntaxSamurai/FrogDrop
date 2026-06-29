// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrogDrop",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FrogDrop", targets: ["FrogDrop"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FrogDrop",
            dependencies: [],
            path: "Sources",
            resources: []
        )
    ]
)
