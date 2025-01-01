// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "DuoCamDemo",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "DuoCamDemo",
            targets: ["DuoCamDemo"]
        ),
    ],
    targets: [
        .target(
            name: "DuoCamDemo",
            dependencies: []
        ),
        .testTarget(
            name: "DuoCamDemoTests",
            dependencies: ["DuoCamDemo"]
        ),
    ]
)