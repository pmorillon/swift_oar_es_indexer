import Foundation
import PostgreSQL

struct OARJob: NodeInitializable {
    let jobId: Int
    let state: String
    let jobUser: String
    let startTime: Int
    let stopTime: Int
    let submissionTime: Int
    let jobName: String?
    let initialRequest: String
    let resourcesCount: Int
    let cluster: String?
    let host: String?
    let jobType: String
    let queueName: String
    
    init(node: Node) throws {
        jobId = try node.get("job_id")
        state = try node.get("state")
        jobUser = try node.get("job_user")
        startTime = try node.get("start_time")
        stopTime = try node.get("stop_time")
        submissionTime = try node.get("submission_time")
        jobName = try node.get("job_name")
        initialRequest = try node.get("initial_request")
        resourcesCount = try node.get("resources_count")
        cluster = try node.get("cluster")
        host = try node.get("host")
        jobType = try node.get("job_type")
        queueName = try node.get("queue_name")
    }
}
