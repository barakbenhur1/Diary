//
//  Api.swift
//  Diary Ai
//
//  Created by Barak Ben Hur on 31/01/2024.
//

import Foundation

internal class NetworkConfig: NSObject {
    static let sheard = NetworkConfig()
    private override init(){}
    
    var local: Bool {
        get {
#if DEBUG
            return true
#else
            return false
#endif
        }
    }
}

class Api {
    enum Method: String {
        case post, get
    }
    
    enum HTTP {
        enum Error: LocalizedError {
            case invalidResponse
            case badStatusCode
            case missingData
            case noAuth
        }
    }
    
    internal lazy var baseUrl = { return NetworkConfig.sheard.local ? "http://localhost:3000" : "" }()
    
    internal var currentUrl: String {
        get {
            return baseUrl
        }
    }
    
    @discardableResult func analyze(string: String) async -> (Result<String, Error>) {
        let body = try? JSONSerialization.data(withJSONObject: string,
                                                           options: [.prettyPrinted])
        return await mainNoUploadReqeset(taskName: "analyze", url: "\(baseUrl)/api/nlp/s-analyzer", params: ["string": string], httpMethod: .post)
    }
    
    func mainNoUploadReqeset<T: Codable>(taskName: String, url: String, params: [String: String]? = nil, httpMethod: Method) async -> (Result<T, Error>) {
        return await withCheckedContinuation({ c in
            guard !url.isEmpty else { return c.resume(returning: .failure(HTTP.Error.badStatusCode)) }
            guard let url = URL(string: url) else { return c.resume(returning: .failure(HTTP.Error.badStatusCode)) }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpMethod = httpMethod.rawValue
            
            if httpMethod == .post, let params = params {
                let json = try? JSONSerialization.data(withJSONObject: params)
                request.httpBody = json
            }
            
            print("================ start ================\n")
            print("url: \(url.absoluteString)\n")
            print("**************** request **************\n")
            let parameters = "\(httpMethod == .post ? "\(params ?? [:])" : "\(request)".replacingOccurrences(of: url.absoluteString, with: ""))\n"
            print(parameters)
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                guard let data = data else { return c.resume(returning: .failure(HTTP.Error.missingData)) }
                guard error == nil else { return c.resume(returning: .failure(error!)) }
                print("**************** response *************\n")
                print("\(data.prettyPrintedJSONString ?? "bad response")\n")
                print("================ end ==================\n\n")
                guard let result = try? JSONDecoder().decode(T.self, from: data) else { return c.resume(returning: .failure(HTTP.Error.invalidResponse)) }
                c.resume(returning:.success(result))
            }
            task.resume()
        })
    }
}

extension Data {
    var prettyPrintedJSONString: NSString? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: self, options: []),
              let data = try? JSONSerialization.data(withJSONObject: jsonObject,
                                                     options: [.prettyPrinted]),
              let prettyJSON = NSString(data: data, encoding: String.Encoding.utf8.rawValue) else {
            return nil
        }
        
        return prettyJSON
    }
}
