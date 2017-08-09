// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AwsDynamoDB",
    products: [.library(name: "AwsDynamoDB", targets: ["AwsDynamoDB"])],
    dependencies: [.package(url: "https://github.com/nikola-mladenovic/AwsSwiftSign.git", .branch("crypto-swift-fix"))],
    targets: [.target(name: "AwsDynamoDB", dependencies: ["AwsSign"]),
              .testTarget(name: "AwsDynamoDBTests", dependencies: ["AwsDynamoDB"])]
)
