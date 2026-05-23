// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BigPowersBenchmark",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "BigPowersBenchmarkKit",
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
