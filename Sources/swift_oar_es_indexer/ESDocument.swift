import Foundation

struct ESDocument: Codable {
    let location: String
    let jobId: Int
    let uniqJobId: String
    let state: String
    let jobUser: String
    var startTime: Int
    var stopTime: Int
    var duration: Int
    var durationResource: Int
    var submissionTime: Int
    let jobName: String?
    let initialRequest: String?
    let jobType: String
    let queueName: String
    var resourcesCount: Int
    let host: String?
    let cluster: String?
    let resourceType: String?
    
    enum CodingKeys: String, CodingKey {
        case location, state, duration, host, cluster
        case jobId = "job_id"
        case uniqJobId = "uniq_job_id"
        case jobUser = "job_user"
        case startTime = "start_time"
        case stopTime = "stop_time"
        case submissionTime = "submission_time"
        case jobName = "job_name"
        case jobType = "job_type"
        case queueName = "queue_name"
        case initialRequest = "initial_request"
        case resourcesCount = "resources_count"
        case durationResource = "duration_resource"
        case resourceType = "resource_type"
    }
    
}
