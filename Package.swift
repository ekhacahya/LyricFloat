// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "LyricFloat", platforms: [.macOS(.v13)], products: [.executable(name: "LyricFloat", targets: ["LyricFloat"])], targets: [.target(name: "LyricCore"), .executableTarget(name: "LyricFloat", dependencies: ["LyricCore"]), .testTarget(name: "LyricCoreTests", dependencies: ["LyricCore"])])
