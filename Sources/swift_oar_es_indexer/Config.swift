import Foundation

struct Config: Codable {
    
    struct OAR: Codable {
        let hostname: String
        let database: String
        let port: Int
        let user: String
        let password: String
    }
    
    struct Elasticsearch: Codable {
        let hostname: String
        let port: Int
        let user: String?
        let password: String?
    }
    
    let oar: OAR
    let elasticsearch: Elasticsearch
    
    static func read(path: String) -> Config {
        let fileUrl = URL(fileURLWithPath: path)
        let decoder = JSONDecoder()
        let data = try! String(contentsOf: fileUrl, encoding: .utf8)
        return try! decoder.decode(Config.self, from: data.data(using: .utf8)!)
    }
    
}
