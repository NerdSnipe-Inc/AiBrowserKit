// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AiBrowserKit",
    platforms: [.macOS("26.0"), .iOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "AiBrowserKit", targets: ["AiBrowserKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AiBrowserKit",
            dependencies: [],
            path: "Sources/AiBrowserKit"
        ),
        .testTarget(
            name: "AiBrowserKitTests",
            dependencies: ["AiBrowserKit"],
            path: "Tests/AiBrowserKitTests"
        ),
    ]
)
