// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iCloudPhotoOptimizer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "iCloudPhotoOptimizer",
            targets: ["iCloudPhotoOptimizer"]
        )
    ],
    dependencies: [
        // Add external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "iCloudPhotoOptimizer",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "iCloudPhotoOptimizerTests",
            dependencies: ["iCloudPhotoOptimizer"],
            path: "Tests"
        )
    ]
)
