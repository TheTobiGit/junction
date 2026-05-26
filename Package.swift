// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Junction",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.2"),
    ],
    targets: [
        .target(
            name: "JunctionCore",
            path: "Sources/JunctionCore"
        ),
        .target(
            name: "JunctionApp",
            dependencies: [
                "JunctionCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/JunctionApp"
        ),
        .executableTarget(
            name: "Junction",
            dependencies: ["JunctionApp"],
            path: "Sources/Junction",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .executableTarget(
            name: "JunctionCLI",
            dependencies: ["JunctionCore"],
            path: "Sources/JunctionCLI"
        ),
        .executableTarget(
            name: "POSIXLockHolder",
            path: "Tests/Support/POSIXLockHolder"
        ),
        .testTarget(
            name: "JunctionTests",
            dependencies: ["JunctionApp", "JunctionCore", "POSIXLockHolder"],
            path: "Tests/JunctionTests"
        )
    ]
)
