import Foundation
import Dispatch
import Console
import PostgreSQL

let fileManager = FileManager.default

// Parse command line
var arguments = CommandLine.arguments
arguments.reverse()
let scriptName = arguments.popLast()?.split(separator: "/").last
var location:String = "default"
var IntervalOption = "1w" // 1 week by default
var configFilePathString = fileManager.currentDirectoryPath + "/config.json"

while (arguments.count != 0) {
    let arg = arguments.popLast()
    switch arg {
    case "-h"?, "--help"?:
        print("Usage: \(String(describing: scriptName!)) [-l|--location <location>]")
        print("Options:")
        print("\t-l, --location : OAR server location (Default value: \(location))")
        print("\t-i, --interval : Index time interval <n>d|w|m")
        print("\t-c, --config : Configuration file path (Default : ./config.json)")
        exit(0)
    case "-l"?, "--location"?:
        guard arguments.count > 0 else {
            print("--location need an argument")
            exit(1)
        }
        location = arguments.popLast()!
    case "-i"?, "--interval"?:
        IntervalOption = arguments.popLast()!
    case "-c"?, "--config"?:
        configFilePathString = arguments.popLast()!
    default:
        print("Unknow option : \(String(describing: arg!))")
    }
}

// Parse config file
let config = Config.read(path: configFilePathString)

// Initialize console
let console: ConsoleProtocol = Terminal(arguments: CommandLine.arguments)


// Connect to the Postgres database
let oarConfig = config.oar.filter { $0.location == location }.first
guard oarConfig != nil else {
    print("Location \(location) not found into config file \(configFilePathString) or declared twice.")
    exit(1)
}

let postgreSQL = try PostgreSQL.Database(
    hostname: oarConfig!.hostname,
    port: oarConfig!.port,
    database: oarConfig!.database,
    user: oarConfig!.user,
    password: oarConfig!.password
)

let conn = try postgreSQL.makeConnection()

let es = Elasticsearch(baseUrl: "http://" + config.elasticsearch.hostname + ":" + String(config.elasticsearch.port),
                       username: config.elasticsearch.user,
                       password: config.elasticsearch.password
)

let maxJobId = es.getMaxJobId(location: location)
print("Last indexes job into elasticsearch : \(maxJobId)")

// Query Postgres database
let startTime: Int = 1504994400
let stopTime: Int = 1506722400

let sqlMinSubmissionTime = "SELECT MIN(submission_time) from jobs where job_id > \(maxJobId)"
let sqlMaxSubmissionTime = "SELECT MAX(submission_time) from jobs where job_id > \(maxJobId)"

console.print("SQL : \(sqlMinSubmissionTime)", newLine: true)
let loadingBar = console.loadingBar(title: "Postgres Request")
loadingBar.start()
let minSubmissionTime = try conn.execute(sqlMinSubmissionTime).wrapped.array?.first!["min"]
//let maxSubmissionTime = try conn.execute(sqlMaxSubmissionTime).wrapped.array?.first!["max"]
loadingBar.finish()

print(minSubmissionTime!)
//print(maxSubmissionTime!)

let incrementTime = try TimeParser(humanString: IntervalOption).toSeconds()

var sqlQuery:String {
    return """
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
WHERE jobs.submission_time > '\(minSubmissionTime!.int!)'
    AND jobs.submission_time < '\(minSubmissionTime!.int! + incrementTime)'
    AND jobs.job_id > \(maxJobId)
    AND jobs.queue_name != 'admin'
    AND jobs.state IN ('Terminated', 'Error')
GROUP BY jobs.job_id, resources.cluster, resources.host, resources.type
ORDER BY job_id ASC
"""
}

let loadingBar2 = console.loadingBar(title: "Postgres Request")
loadingBar2.start()
let request = try conn.execute(sqlQuery)
loadingBar2.finish()
let jobs = try OARCollection<OARJob>(node: request)


// Prepare Elasticsearch Documents
var documents: [ESDocument] = []
for job in jobs.items {
    // Remove corrupted jobs
    guard ((job.stopTime - job.startTime) > 0) else {
        continue
    }
    let doc = ESDocument(location: location,
                         jobId: job.jobId,
                         uniqJobId: "\(location)_\(job.jobId)",
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
                         cluster: job.cluster!,
                         resourceType: job.resourceType!
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
                "location": {"type": "keyword"},
                "job_id" : {"type": "double"},
                "uniq_job_id" : {"type": "keyword"},
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
                "cluster": {"type": "keyword"},
                "resource_type": {"type": "keyword"}
            }
        }
    }
}
""".data(using: .utf8)!

let group = DispatchGroup()
group.enter()
es.createIndex(name: "oar_01", body: indexBody, completionHandler: { () in
    group.leave()
})
group.wait()

let chuncks = documents.split(chunkSize: 1000)

let esProgressBar = console.progressBar(title: "Indexing documents")

var progressCount = 0
for chunk in chuncks {
    group.enter()
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
    es.bulk(body: lines.data(using: .utf8)!, completionHandler: { () in
        progressCount += 1
        esProgressBar.progress = Double(progressCount) / Double(chuncks.count)
        group.leave()
    })
}
group.wait()
esProgressBar.finish()
console.print("\(String(describing: documents.count)) documents indexed")
