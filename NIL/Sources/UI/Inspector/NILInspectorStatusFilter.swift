import Foundation

public enum NILInspectorStatusFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case status2xx = "2xx"
    case status3xx = "3xx"
    case status4xx = "4xx"
    case status5xx = "5xx"
    case error = "Errors"

    public var id: String { rawValue }

    func matches(statusCode: Int?) -> Bool {
        switch self {
        case .all:
            return true
        case .status2xx:
            return (statusCode ?? -1) >= 200 && (statusCode ?? -1) <= 299
        case .status3xx:
            return (statusCode ?? -1) >= 300 && (statusCode ?? -1) <= 399
        case .status4xx:
            return (statusCode ?? -1) >= 400 && (statusCode ?? -1) <= 499
        case .status5xx:
            return (statusCode ?? -1) >= 500 && (statusCode ?? -1) <= 599
        case .error:
            return statusCode == nil || (statusCode ?? 0) >= 400
        }
    }
}
