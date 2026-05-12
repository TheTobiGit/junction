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
        .executableTarget(
            name: "Junction",
            dependencies: ["JunctionCore"],
            path: "Sources/Junction"
        ),
        .executableTarget(
            name: "JunctionCLI",
            dependencies: ["JunctionCore"],
            path: "Sources/JunctionCLI"
        )
    ]
)
