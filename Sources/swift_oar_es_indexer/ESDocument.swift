import Foundation

struct ESDocument: Codable {
    
    struct OARResource: Codable {
        let host: String
        let cluster: String
        let resourcesCount: Int
        
        enum CodingKeys: String, CodingKey {
            case host, cluster
            case resourcesCount = "resources_count"
        }
    }
    
    let jobId: Int
    let state: String
    let jobUser: String
    var startTime: Int
    var stopTime: Int
    var submissionTime: Int
    let jobName: String?
    let initialRequest: String
    let jobType: String
    let queueName: String
    var resourcesCount: Int
    var resources: [OARResource]
    
    enum CodingKeys: String, CodingKey {
        case state, resources
        case jobId = "job_id"
        case jobUser = "job_user"
        case startTime = "start_time"
        case stopTime = "stop_time"
        case submissionTime = "submission_time"
        case jobName = "job_name"
        case jobType = "job_type"
        case queueName = "queue_name"
        case initialRequest = "initial_request"
        case resourcesCount = "resources_count"
    }
    
}
