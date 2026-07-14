// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TheQuestOfferwall",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "TheQuestOfferwall",
            targets: ["TheQuestOfferwall"]
        )
    ],
    targets: [
        .target(
            name: "TheQuestOfferwall",
            path: "Sources/TheQuestOfferwall",
            resources: [
                .process("Resources/PrivacyInfo.xcprivacy")
            ]
        ),
        .testTarget(
            name: "TheQuestOfferwallTests",
            dependencies: ["TheQuestOfferwall"],
            path: "Tests/TheQuestOfferwallTests"
        )
    ]
)
