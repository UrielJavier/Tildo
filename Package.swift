// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VoiceToText",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VoiceToText",
            dependencies: ["whisper"],
            path: "Sources/VoiceToText",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/github-mark.png"),
                .copy("Resources/en.lproj"),
                .copy("Resources/es.lproj"),
            ],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/VoiceToText/Resources/Info.plist"])
            ]
        ),
        .binaryTarget(
            name: "whisper",
            path: "Frameworks/whisper.xcframework"
        )
    ]
)
