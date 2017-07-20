# AwsDynamoDB - Swift

AwsDynamoDB is a Swift library that enables you to use Amazon DynamoDB  with Swift. More details on this are available from the [AWS DynamoDB docmentation](https://aws.amazon.com/documentation/dynamodb/).

<p>
<a href="https://developer.apple.com/swift/" target="_blank">
<img src="https://img.shields.io/badge/Swift-4.0-orange.svg?style=flat" alt="Swift 4.0">
</a>
<a href="https://developer.apple.com/swift/" target="_blank">
<img src="https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20Linux-4E4E4E.svg?colorA=EF5138" alt="Platforms iOS | macOS | watchOS | tvOS | Linux">
</a>
<a href="https://github.com/apple/swift-package-manager" target="_blank">
<img src="https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat&colorB=64A5DE" alt="SPM compatible">
</a>
</p>

This package builds with Swift Package Manager. Ensure you have installed and activated the latest Swift 4.0 tool chain.

## Quick Start

To use AwsSns, modify the Package.swift file and add following dependency:

``` swift
.package(url: "https://github.com/nikola-mladenovic/AwsSwiftDynamoDBsdk", .branch("master"))
```

Then import the `AwsDynamoDB` library into the swift source code:

``` swift
import AwsDynamoDB
```

## Usage

The current release supports following functionalities: Get Item, Put Item, Delete Item and Query. Library uses `Codable` to encode and decode items sent and recieved from DynamoDB.

To use library first initialize `AwsDynamoDB` instance with your credentials and host:
``` swift
let dynamoDb = AwsDynamoDB(host: ..., accessKeyId: ..., secretAccessKey: ...)
```
To get item from DynamoDB use `getItem` method of `AwsDynamoDB` instance:
``` swift
dynamoDb.getItem(tableName: ..., key: (field: ..., value: ...), completion: { (success, item, error) in
// Do some work
...
})
```
To put item from DynamoDB use `putItem` method of `AwsDynamoDB` instance:
``` swift
dynamoDb.putItem(tableName: ..., item: ..., completion: { (success, error) in
// Do some work
...
})
```
To delete item from DynamoDB use `deleteItem` method of `AwsDynamoDB` instance:
``` swift
dynamoDb.getItem(tableName: ..., key: (field: ..., value: ...), completion: { (success, error) in
// Do some work
...
})
```
To query items in DynamoDB use `query` method of `AwsDynamoDB` instance:
``` swift
dynamoDb.query(tableName: ..., keyConditionExpression: "id = :ident", expressionAttributeValues: [":ident" : ...]) { (success, items, error) in
// Do some work
...
})
```

