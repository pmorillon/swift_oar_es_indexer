import Foundation
import PostgreSQL


// Parse config file
let config = Config.read(path: "/tmp/config.json")


// Connect to the Postgres database
let postgreSQL = try PostgreSQL.Database(
    hostname: config.oar.hostname,
    database: config.oar.database,
    user: config.oar.user,
    password: config.oar.password
)
let conn = try postgreSQL.makeConnection()


// Query Postgres database
let startTime: Int = 1504994400
let stopTime: Int = 1506722400

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

let request = try conn.execute(sqlQuery)

let jobs = try OARCollection<OARJob>(node: request)


// Prepare Elasticsearch Documents
var documents: [ESDocument] = []
for job in jobs.items {
    guard (job.host != nil) else {
        print("error with job \(job.jobId), user \(job.jobUser)")
        continue
    }
    let doc = ESDocument(jobId: job.jobId,
                         state: job.state,
                         jobUser: job.jobUser,
                         startTime: job.startTime,
                         stopTime: job.stopTime,
                         duration: job.stopTime - job.startTime,
                         durationResource: (job.stopTime - job.startTime) * job.resourcesCount,
                         submissionTime: job.submissionTime,
                         jobName: (job.jobName ?? "").isEmpty ? "none" : job.jobName!,
                         initialRequest: job.initialRequest,
                         jobType: job.jobType,
                         queueName: job.queueName,
                         resourcesCount: job.resourcesCount,
                         host: job.host!,
                         cluster: job.cluster!
    )
    documents.append(doc)
}


let encoder = JSONEncoder()
let data = try encoder.encode(documents)


let indexBody = """
{
    "settings": {
        "number_of_replicas": 0
    },
    "mappings": {
        "oar_document": {
            "properties": {
                "job_id" : {"type": "double"},
                "resources_count" : {"type": "double"},
                "queue_name" : {"type": "keyword"},
                "submission_time" : {"type": "date"},
                "job_type" : {"type": "keyword"},
                "job_user" : {"type": "keyword"},
                "initial_request" : {"type": "text"},
                "state" : {"type": "keyword"},
                "start_time" : {"type": "date"},
                "stop_time" : {"type": "date"},
                "duration" : {"type": "double"},
                "duration_resource": {"type": "double"},
                "host": {"type": "keyword"},
                "cluster": {"type": "keyword"}
            }
        }
    }
}
""".data(using: .utf8)!

let es = Elasticsearch(baseUrl: "http://" + config.elasticsearch.hostname + ":" + String(config.elasticsearch.port),
                       username: config.elasticsearch.user,
                       password: config.elasticsearch.password
)
let group = DispatchGroup()
group.enter()
es.createIndex(name: "oar_01", body: indexBody, completionHandler: { () in
    group.leave()
})
group.wait()

let chuncks = documents.split(chunkSize: 1000)

for chunk in chuncks {
    var lines: String = ""
    for obj in chunk {
        var a = obj
        a.submissionTime *= 1000
        a.startTime *= 1000
        a.stopTime *= 1000
        let data = try encoder.encode(a)
        lines.append("{ \"index\" : { \"_index\": \"oar_01\", \"_type\": \"oar_document\" } }\n")
        
        lines.append(String(data: data, encoding: .utf8)! + "\n")
    }
    es.bulk(body: lines.data(using: .utf8)!)
}


