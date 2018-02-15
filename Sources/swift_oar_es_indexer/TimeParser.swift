import Foundation

struct TimeParser {
    
    enum TimeParserError: Error {
        case invalidUnit
    }
    
    enum Unit {
        case day, week, month
    }
    
    let humanString: String
    
    var value: Int {
        let str =  humanString.dropLast()
        return Int(str)!
    }
    
    func unit() throws -> Unit {
        let unit = humanString.suffix(1)
        switch unit {
        case "d":
            return .day
        case "w":
            return .week
        case "m":
            return .month
        default:
            throw TimeParserError.invalidUnit
        }
    }
    
    func toSeconds() throws -> Int {
        let unit = try self.unit()
        switch unit {
        case .day:
            return value * 24 * 60
        case .week:
            return value * 7 * 24 * 60
        case .month:
            return value * 4 * 7 * 24 * 60
        }
    }
    
}
