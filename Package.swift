// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BigPowersBenchmark",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.13.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "BigPowersBenchmarkKit",
            dependencies: [
                "SwiftTerm",
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources/BigPowersBenchmarkKit"
        ),
        .executableTarget(
            name: "BigPowersBenchmark",
            dependencies: ["BigPowersBenchmarkKit"],
            path: "Sources/BigPowersBenchmark",
            exclude: ["BigPowersBenchmark.entitlements"]
        ),
        .testTarget(
            name: "BigPowersBenchmarkTests",
            dependencies: ["BigPowersBenchmarkKit"],
            path: "Tests/BigPowersBenchmarkTests"
        ),
    ]
)
