// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceInput",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "VoiceInputCore",
            targets: ["VoiceInputCore"]
        )
    ],
    targets: [
        .target(
            name: "VoiceInputCore",
            path: "Sources/VoiceInputCore"
        ),
        .executableTarget(
            name: "VoiceInput",
            dependencies: ["VoiceInputCore"],
            path: "Sources/VoiceInput"
        ),
        .executableTarget(
            name: "VoiceInputTests",
            dependencies: ["VoiceInputCore"],
            path: "Tests/VoiceInputTests"
        )
    ]
)
