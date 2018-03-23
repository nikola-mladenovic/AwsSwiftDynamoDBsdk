// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AwsDynamoDB",
    products: [.library(name: "AwsDynamoDB", targets: ["AwsDynamoDB"])],
    dependencies: [.package(url: "https://github.com/nikola-mladenovic/AwsSwiftSign.git", from: "0.1.0")],
    targets: [.target(name: "AwsDynamoDB", dependencies: ["AwsSign"]),
              .testTarget(name: "AwsDynamoDBTests", dependencies: ["AwsDynamoDB"])],
    swiftLanguageVersions: [4]
)
