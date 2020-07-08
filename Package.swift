// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "AwsDynamoDB",
    products: [.library(name: "AwsDynamoDB", targets: ["AwsDynamoDB"])],
    dependencies: [.package(name: "AwsSign", url: "https://github.com/nikola-mladenovic/AwsSwiftSign.git", from: "0.4.0")],
    targets: [.target(name: "AwsDynamoDB", dependencies: ["AwsSign"]),
              .testTarget(name: "AwsDynamoDBTests", dependencies: ["AwsDynamoDB"])],
    swiftLanguageVersions: [.v5]
)
