// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NIL",
    platforms: [
        .iOS(.v16),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NIL",
            targets: ["NIL"]
        ),
    ],
    targets: [
        .target(
            name: "NIL",
            path: "Sources"
        ),
        .testTarget(
            name: "NILTests",
            dependencies: ["NIL"]
        ),
    ]
)
