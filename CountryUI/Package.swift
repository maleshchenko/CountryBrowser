// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountryUI",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CountryUI", targets: ["CountryUI"])
    ],
    dependencies: [
        .package(path: "../CountryData")
    ],
    targets: [
        .target(
            name: "CountryUI",
            dependencies: ["CountryData"],
            resources: [.process("Resources")],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "CountryUITests",
            dependencies: ["CountryUI", "CountryData"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        )
    ]
)
