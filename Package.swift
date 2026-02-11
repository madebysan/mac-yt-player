// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "YTMacPlayer",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "YTMacPlayer",
            path: "Sources/YTMacPlayer",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist"
                ])
            ]
        )
    ]
)
