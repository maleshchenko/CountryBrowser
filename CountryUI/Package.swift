// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountryUI",
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
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "CountryUITests",
            dependencies: ["CountryUI", "CountryData"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        )
    ]
)
