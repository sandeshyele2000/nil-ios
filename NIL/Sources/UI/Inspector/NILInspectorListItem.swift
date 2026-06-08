import Foundation

public struct NILInspectorListItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let summary: NetworkEventSummary
    public let title: String
    public let subtitle: String
    public let statusText: String
    public let timestampText: String

    init(summary: NetworkEventSummary) {
        id = summary.id
        self.summary = summary
        title = summary.method
        subtitle = summary.url
        if let statusCode = summary.statusCode {
            statusText = "\(statusCode) • \(summary.durationMs) ms"
        } else {
            statusText = "\(summary.durationMs) ms"
        }
        timestampText = Self.timestampFormatter.string(from: summary.timestamp)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy, HH:mm:ss"
        return formatter
    }()
}
