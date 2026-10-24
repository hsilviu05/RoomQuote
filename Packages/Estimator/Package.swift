// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Estimator",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Estimator", targets: ["Estimator"])
    ],
    targets: [
        .target(name: "Estimator"),
        .testTarget(name: "EstimatorTests", dependencies: ["Estimator"])
    ]
)
