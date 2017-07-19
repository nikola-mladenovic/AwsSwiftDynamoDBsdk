import Foundation
import AwsSign

public class AwsDynamoDB {
    
    private enum RequestType: String {
        case getItem        = "GetItem"
        case deleteItem     = "DeleteItem"
        case putItem        = "PutItem"
        case query          = "Query"
        
        var target: String {
            return "\(AwsDynamoDB.apiVersion).\(rawValue)"
        }
    }
    
    private static let apiVersion = "DynamoDB_20120810"
    
    private let host: String
    private let session: URLSession
    private let accessKeyId: String
    private let secretAccessKey: String
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    public init(host: String, session: URLSession = URLSession(configuration: .default), accessKeyId: String, secretAccessKey: String) {
        self.host = host.hasSuffix("/") ? host.substring(to: host.characters.index(host.endIndex, offsetBy: -1)) : host
        self.session = session
        self.accessKeyId = accessKeyId
        self.secretAccessKey = secretAccessKey
    }
    
    public func getItem<T: Codable>(tableName: String, key: (field :String, value: Any), fetchAttributes: [String] = [], consistentRead: Bool = false, completion: @escaping (_ success: Bool, _ item: T?, _ error: Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : tableName,
                                       "ConsistentRead" : consistentRead,
                                       "Key" : toAwsJson(from: [key.field : key.value]) ]
        if fetchAttributes.count > 0 {
            params["ProjectionExpression"] = fetchAttributes.joined(separator: ",")
        }
        
        let dataTask = session.dataTask(with: request(for: .getItem, with: params), completionHandler: { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode ?? 999 <= 299
            if success,
                let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let awsJson = jsonObject?["Item"] as? [String : Any],
                let item: T = self.deserialize(from: awsJson) {
                completion(success, item, error)
            } else {
                completion(false, nil, error)
            }
        })
        dataTask.resume()
    }
    
    public func deleteItem(tableName: String, key: (field :String, value: Any), completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        let params: [String : Any] = [ "TableName" : tableName,
                                       "Key" : toAwsJson(from: [key.field : key.value]) ]
        
        let dataTask = session.dataTask(with: request(for: .deleteItem, with: params), completionHandler: { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode ?? 999 <= 299
            completion(success, error)
        })
        dataTask.resume()
    }
    
    public func putItem<T: Codable>(tableName: String, item: T, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        let params: [String : Any] = [ "TableName" : tableName,
                                       "Item" : serialize(from: item) ]
        
        let dataTask = session.dataTask(with: request(for: .putItem, with: params), completionHandler: { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode ?? 999 <= 299
            completion(success, error)
        })
        dataTask.resume()
    }
    
    public func query<T: Codable>(tableName: String, keyConditionExpression: String, expressionAttributeNames: [String : String]? = nil, expressionAttributeValues: [String : String]? = nil, fetchAttributes: [String] = [], startKey: (field :String, value: Any)? = nil, filterExpression: String? = nil, limit: Int? = nil, consistentRead: Bool = false, completion: @escaping (_ success: Bool, _ items: [T]?, _ error: Error?) -> Void) {
        var params: [String : Any] = [ "TableName" : tableName,
                                       "KeyConditionExpression" : keyConditionExpression,
                                       "ConsistentRead" : consistentRead ]
        if let expressionAttributeNames = expressionAttributeNames{
            params["ExpressionAttributeNames"] = expressionAttributeNames
            params["Select"] = "SPECIFIC_ATTRIBUTES"
        }
        if let expressionAttributeValues = expressionAttributeValues{
            params["ExpressionAttributeValues"] = toAwsJson(from: expressionAttributeValues)
        }
        if let startKey = startKey{
            params["StartKey"] = toAwsJson(from: [startKey.field : startKey.value])
        }
        if let filterExpression = filterExpression{
            params["FilterExpression"] = filterExpression
        }
        if let limit = limit{
            params["Limit"] = limit
        }
        if fetchAttributes.count > 0 {
            params["ProjectionExpression"] = fetchAttributes.joined(separator: ",")
        }
        
        let dataTask = session.dataTask(with: request(for: .query, with: params), completionHandler: { data, response, error in
            let success = (response as? HTTPURLResponse)?.statusCode ?? 999 <= 299
            if success,
                let data = data,
                let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any],
                let jsonItems = jsonObject?["Items"] as? [[String : Any]] {
                let items = jsonItems.map { return self.deserialize(from: $0) as T? }.filter { $0 != nil } as! [T]
                completion(success, items, error)
            } else {
                completion(false, nil, error)
            }
        })
        dataTask.resume()
    }
    
    private func deserialize<T: Codable>(from awsJson: [String : Any]) -> T? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: toJson(from: awsJson), options: []) else { return nil }
        return try? decoder.decode(T.self, from: jsonData)
    }
    
    private func serialize<T: Codable>(from object: T) -> [String : Any] {
        guard let jsonData = try? encoder.encode(object) else { return [:] }
        let json = (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String : Any] ?? [:]
        return toAwsJson(from: json)
    }
    
    private func toAwsJson(from json: [String : Any]) -> [String : Any] {
        var awsJson = [String : Any]()
        
        json.forEach { (key, value) in
            guard let awsValue = toAwsJsonValue(from: value) else { return }
            awsJson[key] = awsValue
        }
        
        return awsJson
    }
    
    private func toAwsJsonValue(from value: Any) -> [String : Any]? {
        let value = "\(Mirror(reflecting: value).subjectType)" == "__NSCFBoolean" ? value as! Bool : value
        switch value {
        case is String:
            return ["S" : value]
        case is [String]:
            return ["SS" : value]
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
        case nil:
            return ["NULL" : true]
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
    
    private func request(for type: RequestType, with jsonParams: [String : Any]) -> URLRequest {
        var urlRequest = URLRequest(url: URL(string: host)!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/x-amz-json-1.0", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue(type.target, forHTTPHeaderField: "X-Amz-Target")
        urlRequest.httpBody = try! JSONSerialization.data(withJSONObject: jsonParams, options: [])
        
        try? urlRequest.sign(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey)
        
        return urlRequest
    }
    
}
