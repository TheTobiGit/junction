// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Junction",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "JunctionCore",
            path: "Sources/JunctionCore"
        ),
        .target(
            name: "JunctionApp",
            dependencies: ["JunctionCore"],
            path: "Sources/JunctionApp"
        ),
        .executableTarget(
            name: "Junction",
            dependencies: ["JunctionApp"],
            path: "Sources/Junction"
        ),
        .executableTarget(
            name: "JunctionCLI",
            dependencies: ["JunctionCore"],
            path: "Sources/JunctionCLI"
        ),
        .testTarget(
            name: "JunctionTests",
            dependencies: ["JunctionApp", "JunctionCore"],
            path: "Tests/JunctionTests"
        )
    ]
)
