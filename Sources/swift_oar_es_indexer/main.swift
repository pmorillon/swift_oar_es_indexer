import Foundation
import PostgreSQL

let postgreSQL = try PostgreSQL.Database(
    hostname: "localhost",
    database: "oar2",
    user: "oarreader",
    password: "read"
)

let startTime: Int = 1485946800
let stopTime: Int = 1485950400

let sqlQuery = """
SELECT jobs.job_id,
    jobs.start_time,
    jobs.stop_time,
    jobs.submission_time,
    jobs.job_user,
    jobs.queue_name,
    jobs.job_type,
    jobs.state,
    jobs.job_user,
    jobs.job_name,
    jobs.initial_request,
    resources.cluster,
    resources.type as resource_type,
    resources.host,
    count(resources.resource_id) as resources_count
FROM  jobs
LEFT JOIN assigned_resources
ON jobs.assigned_moldable_job = assigned_resources.moldable_job_id
LEFT JOIN resources
ON assigned_resources.resource_id = resources.resource_id
WHERE jobs.submission_time > '\(startTime)'
    AND jobs.submission_time < '\(stopTime)'
    AND jobs.queue_name != 'admin'
    AND jobs.state IN ('Terminated', 'Error')
GROUP BY jobs.job_id, resources.cluster, resources.host, resources.type
ORDER BY job_id ASC
"""

let conn = try postgreSQL.makeConnection()
let request = try conn.execute(sqlQuery)

let jobs = try OARCollection<OARJob>(node: request)

var documents: [ESDocument] = []

for job in jobs.items {
    let doc = ESDocument(jobId: job.jobId,
                         state: job.state,
                         jobUser: job.jobUser,
                         startTime: job.startTime,
                         stopTime: job.stopTime,
                         submissionTime: job.submissionTime,
                         jobName: job.jobName,
                         initialRequest: job.initialRequest,
                         jobType: job.jobType,
                         queueName: job.queueName,
                         resourcesCount: job.resourcesCount,
                         resources: [ESDocument.OARResource(host: job.host, cluster: job.cluster, resourcesCount: job.resourcesCount)]
    )
    if (documents.count > 0 && documents.last?.jobId == doc.jobId) {
        documents[documents.endIndex - 1].resources.append(ESDocument.OARResource(host: job.host, cluster: job.cluster, resourcesCount: job.resourcesCount))
        documents[documents.endIndex - 1].resourcesCount += job.resourcesCount
    } else {
        documents.append(doc)
    }
}

let encoder = JSONEncoder()
let data = try encoder.encode(documents)
print(String(data: data, encoding: .utf8)!)
