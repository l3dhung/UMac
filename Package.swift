// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UMac",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "VirtualDisplayBridge",
            path: "Sources/VirtualDisplayBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "UMac",
            dependencies: ["VirtualDisplayBridge"],
            path: "Sources",
            exclude: ["VirtualDisplayBridge"],
            linkerSettings: [
                .linkedFramework("IOKit"),
            ]
        )
    ]
)
