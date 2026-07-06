// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "KotoriKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "KotoriKit", targets: ["KotoriKit"]),
        .executable(name: "kotori-probe", targets: ["KotoriProbe"]),
    ],
    targets: [
        .target(name: "KotoriKit"),
        .executableTarget(name: "KotoriProbe", dependencies: ["KotoriKit"]),
        .testTarget(
            name: "KotoriKitTests",
            dependencies: ["KotoriKit"],
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
