// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlayerEngines",
    platforms: [
        .tvOS(.v18),
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "VideoPlayerCore", targets: ["VideoPlayerCore"]),
        .library(name: "AetherPlayerModule", targets: ["AetherPlayerModule"]),
    ],
    dependencies: [
        .package(url: "https://github.com/superuser404notfound/AetherEngine.git", exact: "7.22.0"),
    ],
    targets: [
        .target(
            name: "VideoPlayerCore",
            path: "Sources/VideoPlayerCore"
        ),
        .target(
            name: "AetherPlayerModule",
            dependencies: [
                "VideoPlayerCore",
                .product(name: "AetherEngine", package: "AetherEngine"),
            ],
            path: "Sources/AetherPlayerModule"
        ),
    ]
)
