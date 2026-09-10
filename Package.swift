// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShimKit",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ShimKit", targets: ["ShimKit"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6")],
    targets: [
        .executableTarget(name: "ShimKit", dependencies: [.product(name: "Sparkle", package: "Sparkle")], path: "ShimKit"),
        .testTarget(name: "ShimKitTests", dependencies: ["ShimKit"], path: "Tests/ShimKitTests")
    ]
)
