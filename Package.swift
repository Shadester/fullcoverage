// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fullcoverage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.0.0"),
        .package(url: "https://github.com/JohnSundell/Plot", from: "0.14.0"),
    ],
    targets: [
        .executableTarget(
            name: "fullcoverage",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Plot", package: "Plot"),
            ],
            resources: [
                .copy("Resources/style.css"),
            ]
        ),
    ]
)
