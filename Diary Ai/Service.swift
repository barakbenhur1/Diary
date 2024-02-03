//
//  Service.swift
//  Diary Ai
//
//  Created by Barak Ben Hur on 03/02/2024.
//

import UIKit

internal class Service {
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
    
    func analyze(string: String) async -> (Result<[AnalyzedData], Error>) {
        let parameters = [
            [
                "id": "1",
                "language": "en",
                "text": "\(string)"
            ] as [String : Any]
        ]
        
        return await makeRequest(taskName: "analyze", url: "https://ekman-emotion-analysis.p.rapidapi.com/ekman-emotion",
                                 params: parameters,
                                 httpMethod: .post)
    }
    
    private func makeRequest<T: Codable>(taskName: String, url: String, params: [[String: Any]]? = nil, httpMethod: Method) async -> (Result<T, Error>) {
        return await withCheckedContinuation({ c in
            guard !url.isEmpty else { return c.resume(returning: .failure(HTTP.Error.badStatusCode)) }
            guard let url = URL(string: url) else { return c.resume(returning: .failure(HTTP.Error.badStatusCode)) }
            let request = NSMutableURLRequest(url: url, cachePolicy: .useProtocolCachePolicy,
                                     timeoutInterval: 10.0)
            
            let headers = [
                "content-type": "application/json",
                "Accept": "application/json",
                "X-RapidAPI-Key": "8d3836a577mshcb3b08ace209963p1056f4jsnec07b98e10ce",
                "X-RapidAPI-Host": "ekman-emotion-analysis.p.rapidapi.com"
            ]
            
            guard let postData = try? JSONSerialization.data(withJSONObject: [params], options: []) else { return }
            
            request.allHTTPHeaderFields = headers
            request.httpBody = postData as Data
            request.httpMethod = httpMethod.rawValue
            
            if httpMethod == .post, let params = params {
                let json = try? JSONSerialization.data(withJSONObject: params)
                request.httpBody = json
            }
            
            print("================ start ================\n")
            print("url: \(url.absoluteString)\n")
            print("**************** request **************\n")
            let parameters = "\(httpMethod == .post ? "\(params?.first ?? [:])" : "\(request)".replacingOccurrences(of: url.absoluteString, with: ""))\n"
            print(parameters)
            let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, response, error) in
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

// MARK: - AnalyzedData
struct AnalyzedData: Codable {
    let id: String
    let predictions: [Prediction]
}

// MARK: - Prediction
struct Prediction: Codable {
    let probability: Double
    let prediction: String
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

