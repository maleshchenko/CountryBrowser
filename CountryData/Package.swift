// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CountryData",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CountryData", targets: ["CountryData"])
    ],
    dependencies: [
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.17.0"),
        .package(path: "Sources/CountryData/Generated")
    ],
    targets: [
        .target(
            name: "CountryData",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "CountriesAPI", package: "generated")
            ],
            exclude: ["Generated", "Operations"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "CountryDataTests",
            dependencies: ["CountryData"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        )
    ]
)
