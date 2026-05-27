// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AirPodsCtl",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "airpods-ctl", targets: ["AirPodsCtl"]),
        .library(name: "AirPodsCore", targets: ["AirPodsCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "AirPodsCtl",
            dependencies: [
                "AirPodsCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/Info.plist",
                ]),
            ]
        ),
        .target(
            name: "AirPodsCore"
        ),
        .testTarget(
            name: "AirPodsCoreTests",
            dependencies: ["AirPodsCore"]
        ),
    ]
)
