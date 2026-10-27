// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusarteCore",
    platforms: [
        .tvOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "FocusarteCore", targets: ["FocusarteCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        .target(
            name: "FocusarteCore",
            dependencies: ["SwiftSoup"]
        ),
        .testTarget(
            name: "FocusarteCoreTests",
            dependencies: ["FocusarteCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
