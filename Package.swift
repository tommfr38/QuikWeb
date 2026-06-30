// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "QuikWeb",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "QuikWeb",
            path: "Sources/QuikWeb"
        )
    ]
)
