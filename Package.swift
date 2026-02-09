// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MeetingLogger",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MeetingLogger",
            path: "Sources/MeetingLogger"
        )
    ]
)
