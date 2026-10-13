// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CountriesKit",
    platforms: [
        .iOS(.v17),
        // macOS only so `swift test` runs on CI; the views are made for iPhone and iPad.
        .macOS(.v14),
    ],
    products: [
        .library(name: "CountriesKit", targets: ["CountriesKit"]),
        .library(name: "CountriesUI", targets: ["CountriesUI"]),
    ],
    targets: [
        .target(name: "CountriesKit"),
        .target(name: "CountriesUI", dependencies: ["CountriesKit"]),
        .testTarget(
            name: "CountriesKitTests",
            dependencies: ["CountriesKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
