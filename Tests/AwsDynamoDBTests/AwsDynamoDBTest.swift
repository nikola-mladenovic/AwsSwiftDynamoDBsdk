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
    
    var testTable: AwsDynamoDBTable?
    
    override func setUp() {
        super.setUp()
        let dynamoDb = AwsDynamoDB(host: AwsDynamoDBTest.host, accessKeyId: AwsDynamoDBTest.key, secretAccessKey: AwsDynamoDBTest.secret)
        testTable = dynamoDb.table(name: "msokol-test")
    }
    
    func testGetItem() {
        let getItemExpectation = expectation(description: "getItemAsyncCall")
        testTable?.getItem(key: (field: "id", value: "Test"), completion: { (success, item: Item?, error) in
            XCTAssert(success, "Request failed")
            XCTAssertNil(error, "Error should be nil")
            XCTAssertNotNil(item, "Item should not be nil")
            XCTAssert(item?.id == "Test", "Item id should be Test")
            XCTAssert(item?.name == "Marek Sokol", "Item name should be Marek Sokol")
            XCTAssert(item?.bool == false, "Item bool should be false")
            XCTAssert(item?.num == 21, "Item num should be 21.")
            getItemExpectation.fulfill()
        })
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testPutItem() {
        let item = Item(id: "Test2", name: "Lol Iks De", bool: true, num: 20)
        let putItemExpectation = expectation(description: "putItemAsyncCall")
        
        testTable?.put(item: item, completion: { success, error in
            XCTAssert(success, "Request failed")
            XCTAssertNil(error, "Error should be nil")
            putItemExpectation.fulfill()
        })
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testDeleteItem() {
        var success = false
        var error: Error?
        let item = Item(id: "Test2", name: "Lol Iks De", bool: true, num: 20)
        let deleteItemExpectation = expectation(description: "deleteItemAsyncCall")
        
        testTable?.put(item: item, completion: { (rSuccess, rError) in
            if rSuccess {
                self.testTable?.deleteItem(key: (field: "id", value: "Test2"), completion: { (rSuccess, rError) in
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
        let queryExpectation = expectation(description: "queryAsyncCall")
        testTable?.query(keyConditionExpression: "id = :ident", expressionAttributeValues: [":ident" : "Test"]) { (success, items: [Item]?, error) in
            let item = items?.first
            XCTAssert(success, "Request failed")
            XCTAssertNil(error, "Error should be nil")
            XCTAssertNotNil(items, "Item should not be nil")
            XCTAssert(items?.count == 1, "Query should return only one item")
            XCTAssert(item?.id == "Test", "Item id should be Test")
            XCTAssert(item?.name == "Marek Sokol", "Item name should be Marek Sokol")
            XCTAssert(item?.bool == false, "Item bool should be false")
            XCTAssert(item?.num == 21, "Item num should be 21")
            queryExpectation.fulfill()
        }
        waitForExpectations(timeout: 3, handler: nil)
    }

    static var allTests = [
        ("testGetItem", testGetItem),
        ("testPutItem", testPutItem),
        ("testDeleteItem", testDeleteItem),
        ("testQuery", testQuery),
    ]
}
