// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadAI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ReadAI", targets: ["ReadAI"])
    ],
    targets: [
        .executableTarget(
            name: "ReadAI",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("PDFKit"),
                .linkedFramework("Security"),
                .linkedFramework("WebKit")
            ]
        )
    ]
)
