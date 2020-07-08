import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Dispatch
import AwsSign

public class AwsDynamoDB {
    
    fileprivate let host: String
    fileprivate let session: URLSession
    fileprivate let accessKeyId: String
    fileprivate let secretAccessKey: String
    
    /// Initializes a new AwsDynamoDB client, using the specified host, session, and access credentials.
    ///
    /// - Parameters:
    ///   - host: The host for the DynamoDB, e.g `https://dynamodb.us-west-2.amazonaws.com`
    ///   - session: Optional parameter, specifying a `URLSession` to be used for all DynamoDB related requests. If not provided, `URLSession(configuration: .default)` will be used.
    ///   - accessKeyId: The access key for using the DynamoDB.
    ///   - secretAccessKey: The secret access key for using the DynamoDB.
    
    public init(host: String, session: URLSession = URLSession(configuration: .default), accessKeyId: String, secretAccessKey: String) {
        self.host = host.hasSuffix("/") ? String(host[..<host.index(before: host.endIndex)]) : host
        self.session = session
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
    
    /// Initializes `AwsDynamoDBTable` instance for given name.
    ///
    /// - name: The name of the table.
    /// - Returns: `AwsDynamoDBTalbe` instance.
    public func table(name: String) -> AwsDynamoDBTable {
        return AwsDynamoDBTable(name: name, dynamoDb: self)
    }
    
}

public struct AwsDynamoDBTable {
    
    private enum RequestType: String {
        case getItem        = "GetItem"
        case deleteItem     = "DeleteItem"
        case putItem        = "PutItem"
        case query          = "Query"
        case updateItem     = "UpdateItem"
        case scan           = "Scan"
        
        var target: String {
            return "\(AwsDynamoDBTable.apiVersion).\(rawValue)"
        }
    }
    
    private static let apiVersion = "DynamoDB_20120810"
    
    public let name: String
    
    private let dynamoDb: AwsDynamoDB
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    /// Initializes a new `AwsDynamoDBTable` instance, using the specified host, session, access credentials and name.
    ///
    /// - Parameters:
    ///   - name: The name of the table.
    ///   - host: The host for the DynamoDB, e.g `https://dynamodb.us-west-2.amazonaws.com`
    ///   - session: Optional parameter, specifying a `URLSession` to be used for all DynamoDB related requests. If not provided, `URLSession(configuration: .default)` will be used.
    ///   - accessKeyId: The access key for using the DynamoDB.
    ///   - secretAccessKey: The secret access key for using the DynamoDB.
    fileprivate init(name: String, dynamoDb: AwsDynamoDB) {
        self.name = name
        self.dynamoDb = dynamoDb
    }
    
    /// Method used for fetching items from table.
    ///
    /// - Parameters:
    ///   - keyParams: Dictionary that represents primary key, or primary and sort key, e.g `["id": "012345"]`, or `["id": "1", "name": "doe"]`
    ///   - fetchAttributes: Array that represents attributes that should be returned from item. Defaults to empty array.
    ///   - consistentRead: If your application requires a strongly consistent read, set this parameter to 'true'. Defaults to `false`.
    ///   - completion: Completion closure that will be called when request has completed.
    ///     - success: Bool value that will be `true` if request has succeeded, otherwise false.
    ///     - item: Item returned from DynamoDB or `nil` if request has failed. Item must conform to `Decodable` protocol.
    ///     - error: Error if request has failed or `nil` if request has succeeded.
    public func getItem<T: Decodable>(keyParams: [String: Any], fetchAttributes: [String] = [], consistentRead: Bool = false, completion: @escaping (Bool, T?, Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : name,
                                       "ConsistentRead" : consistentRead,
                                       "Key" : toAwsJson(from: keyParams) ]
        if fetchAttributes.count > 0 {
            params["ProjectionExpression"] = fetchAttributes.joined(separator: ",")
        }
        
        let request: URLRequest
        do {
            request = try self.request(for: .getItem, with: params)
        } catch {
            completion(false, nil, error)
            return
        }
        perform(request: request) { (data, response, error) in
            if error == nil,
                let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let awsJson = jsonObject["Item"] as? [String : Any] {
                do {
                    let item: T = try self.deserialize(from: awsJson)
                    completion(true, item, error)
                } catch {
                    completion(false, nil, error)
                }
            } else {
                completion(false, nil, error)
            }
        }
    }
    
    /// Method used for deleteting items from table.
    ///
    /// - Parameters:
    ///   - keyParams: Dictionary that represents primary key, or primary and sort key, e.g `["id": "012345"]`, or `["id": "1", "name": "doe"]`
    ///   - completion: Completion closure that will be called when request has completed.
    ///     - success: Bool value that will be `true` if request has succeeded, otherwise false.
    ///     - error: Error if request has failed or `nil` if request has succeeded.
    public func deleteItem(keyParams: [String: Any], completion: @escaping (Bool, Error?) -> Void) {
        let params: [String : Any] = [ "TableName" : name,
                                       "Key" : toAwsJson(from: keyParams) ]
        
        let request: URLRequest
        do {
            request = try self.request(for: .deleteItem, with: params)
        } catch {
            completion(false, error)
            return
        }
        
        perform(request: request) { (data, response, error) in
            completion(error == nil, error)
        }
    }
    
    /// Method used for saving the items to table.
    ///
    /// - Parameters:
    ///   - item: Item to put, must conform to `Encodable` protocol.
    ///   - completion: Completion closure that will be called when request has completed.
    ///      success: Bool value that will be `true` if request has succeeded, otherwise false.
    ///     - error: Error if request has failed or `nil` if request has succeeded.
    public func put<T: Encodable>(item: T, completion: @escaping (Bool, Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : name ]
        let request: URLRequest
        do {
            params["Item"] = try serialize(from: item)
            request = try self.request(for: .putItem, with: params)
        } catch {
            completion(false, error)
            return
        }
        
        perform(request: request) { (data, response, error) in
            completion(error == nil, error)
        }
    }
    
    /// Methods used for updating the items in table.
    ///
    /// - Parameters:
    ///   - keyParams: Dictionary that represents primary key, or primary and sort key, e.g `["id": "012345"]`, or `["id": "1", "name": "doe"]`
    ///   - conditionExpression: A condition that must be satisfied in order for a conditional update to succeed.
    ///   - expressionAttributeNames: One or more substitution tokens for attribute names in an expression.
    ///   - expressionAttributeValues: One or more values that can be substituted in an expression.
    ///   - updateExpression: An expression that defines one or more attributes to be updated, the action to be performed on them, and new value(s) for them. For more information, see [Amazon DynamoDB Update Expressions Documentation.](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Expressions.UpdateExpressions.html)
    ///   - completion: Completion closure that will be called when request has completed.
    ///     - success: Bool value that will be `true` if request has succeeded, otherwise false.
    ///     - error: Error if request has failed or `nil` if request has succeeded.
    public func update(keyParams: [String: Any], conditionExpression: String? = nil, expressionAttributeNames: [String : String]? = nil, expressionAttributeValues: [String : Any?]? = nil, updateExpression: String? = nil, completion: @escaping (Bool, Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : name,
                                       "Key" : toAwsJson(from: keyParams) ]
        if let conditionExpression = conditionExpression {
            params["ConditionExpression"] = conditionExpression
        }
        if let expressionAttributeNames = expressionAttributeNames{
            params["ExpressionAttributeNames"] = expressionAttributeNames
        }
        if let expressionAttributeValues = expressionAttributeValues{
            params["ExpressionAttributeValues"] = toAwsJson(from: expressionAttributeValues)
        }
        if let updateExpression = updateExpression {
            params["UpdateExpression"] = updateExpression
        }
        
        let request: URLRequest
        do {
            request = try self.request(for: .updateItem, with: params)
        } catch {
            completion(false, error)
            return
        }
        
        perform(request: request) { (data, response, error) in
            completion(error == nil, error)
        }
    }
    
    /// Method used to execute query on a given table.
    /// For more information, see [Amazon DynamoDB API Documentation.](http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Operations.html)
    ///
    /// - Parameters:
    ///   - indexName: The name of an index to query. This index can be any local secondary index or global secondary index on the table.
    ///   - keyConditionExpression: The condition that specifies the key value for items to be retrieved by the query execution.
    ///   - expressionAttributeNames: Substitution tokens for attribute names in an key condition expression.
    ///   - expressionAttributeValues: Values that can be substituted in an key condition expression.
    ///   - fetchAttributes: Array that represents attributes that should be returned from item. Defaults to empty array.
    ///   - startKeyParams: Dictionary that represents primary key, or primary and sort key, e.g `["id": "012345"]`, or `["id": "1", "name": "doe"]`. If start key is specified, query will start from item with that key. Defaults to `nil`.
    ///   - filterExpression: A string that contains conditions that DynamoDB applies after the query operation, but before the items are returned to you. Items that do not satisfy criteria are not returned.
    ///   - limit: Limit number of items returned by query. Defaults to nil.
    ///   - consistentRead: If your application requires a strongly consistent read, set this parameter to 'true'. Defaults to `false`.
    ///   - completion: Completion closure that will be called when request has completed.
    ///     - success: Bool value that will be `true` if request has succeeded, otherwise false.
    ///     - items: Items returned from DynamoDB or `nil` if request has failed. Items must conform to `Codable` protocol.
    ///     - error: Error if request has failed or `nil` if request has succeeded.
    public func query<T: Decodable>(indexName: String? = nil, keyConditionExpression: String, expressionAttributeNames: [String : String]? = nil, expressionAttributeValues: [String : Any]? = nil, fetchAttributes: [String] = [], startKeyParams: [String: Any]? = nil, filterExpression: String? = nil, limit: Int? = nil, consistentRead: Bool = false, completion: @escaping (Bool, [T]?, Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : name,
                                       "KeyConditionExpression" : keyConditionExpression,
                                       "ConsistentRead" : consistentRead ]
        if let indexName = indexName {
            params["IndexName"] = indexName
        }
        if let expressionAttributeNames = expressionAttributeNames {
            params["ExpressionAttributeNames"] = expressionAttributeNames
            params["Select"] = "SPECIFIC_ATTRIBUTES"
        }
        if let expressionAttributeValues = expressionAttributeValues {
            params["ExpressionAttributeValues"] = toAwsJson(from: expressionAttributeValues)
        }
        if let startKeyParams = startKeyParams {
            params["ExclusiveStartKey"] = toAwsJson(from: startKeyParams)
        }
        if let filterExpression = filterExpression {
            params["FilterExpression"] = filterExpression
        }
        if let limit = limit {
            params["Limit"] = limit
        }
        if fetchAttributes.count > 0 {
            params["ProjectionExpression"] = fetchAttributes.joined(separator: ",")
        }
        
        let request: URLRequest
        do {
            request = try self.request(for: .query, with: params)
        } catch {
            completion(false, nil, error)
            return
        }
        
        perform(request: request) { (data, response, error) in
            if error == nil,
                let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let jsonItems = jsonObject["Items"] as? [[String : Any]] {
                do {
                    let items: [T] = try jsonItems.map { return try self.deserialize(from: $0) }
                    completion(true, items, error)
                } catch {
                    completion(false, nil, error)
                }
            } else {
                completion(false, nil, error)
            }
        }
    }
    
    /// Method used to execute scan on a given table.
    /// For more information, see [Amazon DynamoDB API Documentation.](http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Operations.html)
    ///
    /// - Parameters:
    ///   - indexName: The name of an seconday index used for scanning operation.
    ///   - expressionAttributeNames: Substitution tokens for attribute names in an key condition expression.
    ///   - expressionAttributeValues: Values that can be substituted in an key condition expression.
    ///   - fetchAttributes: Array that represents attributes that should be returned from item. Defaults to empty array.
    ///   - startKeyParams: Dictionary that represents primary key, or primary and sort key, e.g `["id": "012345"]`, or `["id": "1", "name": "doe"]`. If start key is specified, scan will start from item with that key. Defaults to `nil`.
    ///   - filterExpression: A string that contains conditions that DynamoDB applies after the query operation, but before the items are returned to you. Items that do not satisfy criteria are not returned.
    ///   - limit: Limit number of items returned by query. Defaults to nil.
    ///   - consistentRead: If your application requires a strongly consistent read, set this parameter to 'true'. Defaults to `false`.
    ///   - completion: Completion closure that will be called when request has completed.
    ///   - success: Bool value that will be `true` if request has succeeded, otherwise false.
    ///   - items: Items returned from DynamoDB or `nil` if request has failed. Items must conform to `Codable` protocol.
    ///   - error: Error if request has failed or `nil` if request has succeeded.
    public func scan<T: Decodable>(indexName: String? = nil, expressionAttributeNames: [String : String]? = nil, expressionAttributeValues: [String : Any]? = nil, fetchAttributes: [String] = [], startKeyParams: [String: Any]? = nil, filterExpression: String? = nil, limit: Int? = nil, consistentRead: Bool = false, completion: @escaping (Bool, [T]?, Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : name,
                                       "ConsistentRead" : consistentRead ]
        if let indexName = indexName {
            params["IndexName"] = indexName
        }
        if let expressionAttributeNames = expressionAttributeNames {
            params["ExpressionAttributeNames"] = expressionAttributeNames
            params["Select"] = "SPECIFIC_ATTRIBUTES"
        }
        if let expressionAttributeValues = expressionAttributeValues {
            params["ExpressionAttributeValues"] = toAwsJson(from: expressionAttributeValues)
        }
        if let startKeyParams = startKeyParams {
            params["ExclusiveStartKey"] = toAwsJson(from: startKeyParams)
        }
        if let filterExpression = filterExpression {
            params["FilterExpression"] = filterExpression
        }
        if let limit = limit {
            params["Limit"] = limit
        }
        if fetchAttributes.count > 0 {
            params["ProjectionExpression"] = fetchAttributes.joined(separator: ",")
        }
        
        let request: URLRequest
        do {
            request = try self.request(for: .scan, with: params)
        } catch {
            completion(false, nil, error)
            return
        }
        
        perform(request: request) { (data, response, error) in
            if error == nil,
                let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let jsonItems = jsonObject["Items"] as? [[String : Any]] {
                do {
                    let items: [T] = try jsonItems.map { return try self.deserialize(from: $0) }
                    completion(true, items, error)
                } catch {
                    completion(false, nil, error)
                }
            } else {
                completion(false, nil, error)
            }
        }
    }
    
    private func deserialize<T: Decodable>(from awsJson: [String : Any]) throws -> T {
        let jsonData = try JSONSerialization.data(withJSONObject: toJson(from: awsJson), options: [])
        return try decoder.decode(T.self, from: jsonData)
    }
    
    private func serialize<T: Encodable>(from object: T) throws -> [String : Any] {
        let jsonData = try encoder.encode(object)
        guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String : Any] else {
            throw AwsDynamoDBError.generalError(reason: "Initializing json dictionary from \(object) failed.")
        }
        return toAwsJson(from: json)
    }
    
    private func toAwsJson(from json: [String : Any?]) -> [String : Any] {
        var awsJson = [String : Any]()
        
        json.forEach { (key, value) in
            guard let awsValue = toAwsJsonValue(from: value) else { return }
            awsJson[key] = awsValue
        }
        
        return awsJson
    }
    
    private func toAwsJsonValue(from value: Any?) -> [String : Any]? {
        guard var value = value else {
            return ["NULL" : true]
        }
        value = "\(Mirror(reflecting: value).subjectType)" == "__NSCFBoolean" ? value as! Bool : value
        switch value {
        case is String:
            return ["S" : value]
        case is [String]:
            return ["L" : (value as! [String]).map { toAwsJsonValue(from: $0) } as! [[String : Any]] ]
        case is Int, is Double:
            return ["N" : "\(value)"]
        case is [Int], is [Double]:
            let numbers = (value as! [Any]).map { "\($0)" }
            return ["NS" : numbers]
        case is Bool:
            return ["BOOL" : value]
        case is [Any]:
            let awsValues = (value as! [Any]).map { toAwsJsonValue(from: $0) }
                .filter { $0 != nil } as! [[String : Any]]
            return ["L" : awsValues]
        case is [String : Any]:
            return ["M" : toAwsJson(from: value as! [String : Any])]
        case is Data:
            let data = (value as! Data).base64EncodedData()
            return ["B" : data]
        case is [Data]:
            let dataArray = (value as! [Data]).map { $0.base64EncodedData() }
            return ["BS" : dataArray]
        default:
            return nil
        }
    }
    
    private func toJson(from awsJson: [String : Any]) -> [String : Any] {
        guard let awsJson = awsJson as? [String : [String : Any]] else { return [:] }
        var json = [String : Any]()
        awsJson.forEach { (key, value) in
            guard let jsonValue = toJsonValue(from: value) else { return }
            json[key] = jsonValue
        }
        return json
    }
    
    private func toJsonValue(from awsValue: [String : Any]) -> Any? {
        guard let (key, value) = awsValue.first else { return nil }
        switch key {
        case "S", "SS":
            return value
        case "N":
            guard let number = value as? String else { return nil }
            if let integer = Int(number) {
                return integer
            } else if let double = Double(number) {
                return double
            }
            return nil
        case "NS":
            guard let stringNumbers = value as? [String] else { return nil }
            var numbers = [Any]()
            stringNumbers.forEach { number in
                if let integer = Int(number) {
                    numbers.append(integer)
                } else if let double = Double(number) {
                    numbers.append(double)
                }
            }
            return numbers
        case "BOOL":
            return value as? Bool
        case "B":
            guard let encodedData = value as? Data,
                let data = Data(base64Encoded: encodedData) else { return nil }
            return data
        case "BS":
            guard let encodedDataArray = value as? [Data] else { return nil }
            let dataArray = encodedDataArray.map { Data(base64Encoded: $0) }
                .filter { $0 != nil } as! [Data]
            return dataArray
        case "L":
            guard let jsonPart = value as? [[String : Any]] else { return nil }
            var parts = [Any]()
            jsonPart.forEach {
                guard let value = toJsonValue(from: $0) else { return }
                parts.append(value)
            }
            return parts
        case "M":
            guard let jsonPart = value as? [String : [String : Any]] else { return nil }
            return toJson(from: jsonPart)
        default:
            return nil
        }
    }
    
    private func request(for type: RequestType, with jsonParams: [String : Any]) throws -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: dynamoDb.host)!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(type.target, forHTTPHeaderField: "X-Amz-Target")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: jsonParams, options: [])
        
        try urlRequest.sign(accessKeyId: dynamoDb.accessKeyId, secretAccessKey: dynamoDb.secretAccessKey)
        
        return urlRequest
    }
    
    private func perform(request: URLRequest, backoffTime: TimeInterval = 0, completion: @escaping (_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + backoffTime) {
            let dataTask = self.dynamoDb.session.dataTask(with: request) { (data, response, error) in
                let error = self.checkForError(response: response, data: data, error: error)
                if let awsDynamoDBError = error as? AwsDynamoDBError {
                    switch awsDynamoDBError {
                    case .provisionedThroughputExceeded, .throttlingException:
                        let newBackoffTime = backoffTime == 0 ? 0.05 : backoffTime * 2
                        if newBackoffTime < 60 {
                            self.perform(request: request, backoffTime: newBackoffTime, completion: completion)
                        } else {
                            fallthrough
                        }
                    default:
                        completion(data, response, error)
                    }
                } else {
                    completion(data, response, error)
                }
            }
            dataTask.resume()
        }
    }
    
    private func checkForError(response: URLResponse?, data: Data?, error: Error?) -> Error? {
        if let error = error {
            return error
        }
        
        if let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode > 299 {
            guard let data = data else { return AwsDynamoDBError.generalError(reason: nil) }
            
            if let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String : Any],
                let type = json["__type"] as? String {
                if type.contains("ProvisionedThroughputExceededException") {
                    return AwsDynamoDBError.provisionedThroughputExceeded
                } else if type.contains("ThrottlingException") {
                    return AwsDynamoDBError.throttlingException
                } else {
                    // AWS does not use same key for error messages.
                    let message = json["message"] ?? json["Message"]
                    return AwsDynamoDBError.generalError(reason: message as? String)
                }
            } else if let text = String(data: data, encoding: .utf8) {
                return AwsDynamoDBError.generalError(reason: text)
            }
            
            return AwsDynamoDBError.generalError(reason: nil)
        }
        
        return nil
    }
    
}

public enum AwsDynamoDBError: Error {
    case generalError(reason: String?)
    case provisionedThroughputExceeded
    case throttlingException
}

extension AwsDynamoDBError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .generalError(let reason):
            return "AWS DYNAMODB SDK error: \(reason ?? "No failure reason available")"
        case .provisionedThroughputExceeded:
            return "AWS DYNAMODB SDK error: The request was denied due to request throttling"
        case .throttlingException:
            return "AWS DYNAMODB SDK error: Your request rate is too high, reduce the frequency of requests and use exponential backoff."
        }
    }
    
    public var localizedDescription: String {
        return errorDescription!
    }
}
