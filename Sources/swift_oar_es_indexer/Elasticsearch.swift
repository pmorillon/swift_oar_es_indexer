import Foundation
import Dispatch

struct Elasticsearch {
    let baseUrl: String
    var username, password: String?
    
    var credential: String {
        return "\(String(describing: username!)):\(String(describing: password!))"
    }
    
    var base64Credential: String {
        return credential.data(using: String.Encoding.utf8)!.base64EncodedString()
    }
    
    private func addAuthHeader(to: inout URLRequest) {
        if (username != nil && password != nil) {
            to.setValue("application/json", forHTTPHeaderField: "Content-Type")
            to.setValue("Basic \(String(describing: base64Credential))", forHTTPHeaderField: "Authorization")
        }
    }
    
    func createIndex(name: String, body: Data, completionHandler: @escaping () -> Void) {
        let url = URL(string: baseUrl + "/" + name)
        var request = URLRequest(url: url!)
        request.httpMethod = "PUT"
        request.httpBody = body
        addAuthHeader(to: &request)
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print(error!)
                completionHandler()
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("Elasticsearch index \(name) created.")
                } else {
                    print("Failed to create index \(name)")
                    print(String(bytes: data!, encoding: .utf8)!)
                }
                completionHandler()
            }
        }
        task.resume()
    }
    
    func getMaxJobId() -> Int {
        let url = URL(string: baseUrl + "/_search")
        var request = URLRequest(url: url!)
        var result: Int = 0
        let body = """
{
  "query": {
    "type": {
      "value": "oar_document"
    }
  },
  "aggs": {
    "max_id": {
      "max": {
        "field": "job_id"
      }
    }
  }
}
""".data(using: .utf8)!
        let semaphore = DispatchSemaphore(value: 0)
        request.httpMethod = "POST"
        request.httpBody = body
        addAuthHeader(to: &request)
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print(error!)
                exit(1)
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    let decoder = JSONDecoder()
                    do {
                        let maxJobId = try decoder.decode(ESAggsMaxJobId.self, from: data!)
                        result = maxJobId.aggregations.max_id.value
                    } catch {
                        result = 0
                    }
                    
                } else {
                    print("[Elasticsearch] Failed to get max job ID")
                    print(String(bytes: data!, encoding: .utf8)!)
                    exit(1)
                }
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        return result
    }
    
    func bulk(body: Data, completionHandler: @escaping () -> Void) {
        let url = URL(string: baseUrl + "/_bulk")
        var request = URLRequest(url: url!)
        request.httpMethod = "PUT"
        request.httpBody = body
        addAuthHeader(to: &request)
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print(error!)
                completionHandler()
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    //
                } else {
                    print(httpResponse)
                }
            }
            completionHandler()
        }
        task.resume()
    }
    
}
