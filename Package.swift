// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fullcoverage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "fullcoverage",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [
                .copy("Resources/style.css"),
            ]
        ),
    ]
)
