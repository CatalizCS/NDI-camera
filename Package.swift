// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TamaNDI",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Camera", targets: ["Camera"]),
    ],
    targets: [
        .target(
            name: "Domain",
            path: "Sources/Domain",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "Camera",
            dependencies: ["Domain"],
            path: "Sources/Camera",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"],
            path: "Tests/DomainTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CameraTests",
            dependencies: ["Camera", "Domain"],
            path: "Tests/CameraTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
