import XCTest
@testable import AwsDynamoDB

struct Item: Codable {
    let id: String
    let name: String
    let bool: Bool
    let num: Int
}

class AwsDynamoDBTest: XCTestCase {
    static let key = ProcessInfo.processInfo.environment["AWS_KEY"]!
    static let secret = ProcessInfo.processInfo.environment["AWS_SECRET"]!
    static let host = "https://dynamodb.us-west-2.amazonaws.com"
    
    var dynamoDb: AwsDynamoDB?
    
    override func setUp() {
        super.setUp()
        dynamoDb = AwsDynamoDB(host: AwsDynamoDBTest.host, accessKeyId: AwsDynamoDBTest.key, secretAccessKey: AwsDynamoDBTest.secret)
    }
    
    func testGetItem() {
        var item: Item?
        var success = false
        var error: Error?
        let getItemExpectation = expectation(description: "getItemAsyncCall")
        dynamoDb?.getItem(tableName: "msokol-test", key: (field: "id", value: "Test"), completion: { (rSuccess, rItem: Item?, rError) in
            item = rItem
            error = rError
            success = rSuccess
            getItemExpectation.fulfill()
        })
        
        waitForExpectations(timeout: 3, handler: nil)
        
        XCTAssert(success, "Request failed")
        XCTAssertNil(error, "Error should be nil")
        XCTAssertNotNil(item, "Item should not be nil")
        XCTAssert(item?.id == "Test", "Item id should be Test")
        XCTAssert(item?.name == "Marek Sokol", "Item name should be Marek Sokol")
        XCTAssert(item?.bool == false, "Item bool should be false")
        XCTAssert(item?.num == 21, "Item num should be 21.")
    }
    
    func testPutItem() {
        var success = false
        var error: Error?
        let item = Item(id: "Test2", name: "Lol Iks De", bool: true, num: 20)
        let putItemExpectation = expectation(description: "putItemAsyncCall")
        
        dynamoDb?.putItem(tableName: "msokol-test", item: item, completion: { (rSuccess, rError) in
            error = rError
            success = rSuccess
            putItemExpectation.fulfill()
        })
        waitForExpectations(timeout: 3, handler: nil)
        
        XCTAssert(success, "Request failed")
        XCTAssertNil(error, "Error should be nil")
    }
    
    func testDeleteItem() {
        var success = false
        var error: Error?
        let item = Item(id: "Test2", name: "Lol Iks De", bool: true, num: 20)
        let deleteItemExpectation = expectation(description: "deleteItemAsyncCall")
        
        dynamoDb?.putItem(tableName: "msokol-test", item: item, completion: { (rSuccess, rError) in
            if rSuccess {
                self.dynamoDb?.deleteItem(tableName: "msokol-test", key: (field: "id", value: "Test2"), completion: { (rSuccess, rError) in
                    error = rError
                    success = rSuccess
                    deleteItemExpectation.fulfill()
                })
            } else {
                deleteItemExpectation.fulfill()
            }
        })
        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssert(success, "Request failed")
        XCTAssertNil(error, "Error should be nil")
    }
    
    func testQuery() {
        var items: [Item]?
        var success = false
        var error: Error?
        let queryExpectation = expectation(description: "queryAsyncCall")
        dynamoDb?.query(tableName: "msokol-test", keyConditionExpression: "id = :ident", expressionAttributeValues: [":ident" : "Test"]) { (rSuccess, rItems: [Item]?, rError) in
            items = rItems
            error = rError
            success = rSuccess
            queryExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let item = items?.first
        XCTAssert(success, "Request failed")
        XCTAssertNil(error, "Error should be nil")
        XCTAssertNotNil(items, "Item should not be nil")
        XCTAssert(items?.count == 1, "Query should return only one item")
        XCTAssert(item?.id == "Test", "Item id should be Test")
        XCTAssert(item?.name == "Marek Sokol", "Item name should be Marek Sokol")
        XCTAssert(item?.bool == false, "Item bool should be false")
        XCTAssert(item?.num == 21, "Item num should be 21")
    }

    static var allTests = [
        ("testGetItem", testGetItem),
        ("testPutItem", testPutItem),
        ("testDeleteItem", testDeleteItem),
        ("testQuery", testQuery),
    ]
}