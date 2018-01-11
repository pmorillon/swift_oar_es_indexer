import Foundation
import PostgreSQL

struct OARCollection<T>: NodeInitializable {
    let items: [T]
    
    init(node: Node) throws {
        items = try node.get()
    }
}
