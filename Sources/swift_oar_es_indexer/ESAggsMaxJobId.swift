import Foundation

struct ESAggsMaxJobId: Decodable {
    struct MaxId: Decodable {
        struct Value: Decodable {
            let value: Int
        }
        let max_id: Value
    }
    let aggregations: MaxId
}
