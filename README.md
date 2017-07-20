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

To use library first initialize the `AwsDynamoDB` instance with your credentials and host:
``` swift
let dynamoDb = AwsDynamoDB(host: "https://dynamodb.us-west-2.amazonaws.com", accessKeyId: "OPKASPJPOAS23IOJS", secretAccessKey: "232(I(%$jnasoijaoiwj2919109233")
```
To get item from DynamoDB use the  `getItem` method of the `AwsDynamoDB` instance:
``` swift
dynamoDb.getItem(tableName: "table1", key: (field: "id", value: "012345"), completion: { (success, item, error) in
    // Do some work
    ...
})
```
To put item from DynamoDB use the `putItem` method of the `AwsDynamoDB` instance:
``` swift
struct Person: Codable {
    let id: String
    let name: String?
}

let person = Person(id: "012345", name: "Bill")

dynamoDb.putItem(tableName: "table1", item: person, completion: { (success, error) in
    // Do some work
    ...
})
```
To delete item from DynamoDB use the `deleteItem` method of the `AwsDynamoDB` instance:
``` swift
dynamoDb.getItem(tableName: "table1", key: (field: "id", value: "012345"), completion: { (success, error) in
    // Do some work
    ...
})
```
To query items in DynamoDB use the `query` method of the `AwsDynamoDB` instance:
``` swift
dynamoDb.query(tableName: "table1", keyConditionExpression: "id = :ident", expressionAttributeValues: [":ident" : "012345"]) { (success, items, error) in
    // Do some work
    ...
})
```

