// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "AwsDynamoDB",
    products: [.library(name: "AwsDynamoDB", targets: ["AwsDynamoDB"])],
    dependencies: [.package(url: "https://github.com/nikola-mladenovic/AwsSwiftSign.git", .branch("swift4-linux"))],
    targets: [.target(name: "AwsDynamoDB", dependencies: ["AwsSign"], path: "Sources"),
              .testTarget(name: "AwsDynamoDBTests", dependencies: ["AwsDynamoDB"])]
)

