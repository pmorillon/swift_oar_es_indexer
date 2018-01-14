import Foundation

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
    
    func bulk(body: Data) {
        let url = URL(string: baseUrl + "/_bulk")
        var request = URLRequest(url: url!)
        request.httpMethod = "PUT"
        request.httpBody = body
        addAuthHeader(to: &request)
        
        let session = URLSession(configuration: URLSessionConfiguration.default)
        let task = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print(error!)
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("Elasticsearch bulk created.")
                } else {
                    print(httpResponse)
                }
            }
        }
        task.resume()
        
    }
    
}
