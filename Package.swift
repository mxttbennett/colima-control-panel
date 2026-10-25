// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ColimaCtrl",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "ColimaCtrl", targets: ["ColimaCtrl"])],
    targets: [
        .target(name: "ColimaCtrlCore"),
        .executableTarget(name: "ColimaCtrl", dependencies: ["ColimaCtrlCore"]),
        .testTarget(name: "ColimaCtrlCoreTests", dependencies: ["ColimaCtrlCore"]),
    ]
)
