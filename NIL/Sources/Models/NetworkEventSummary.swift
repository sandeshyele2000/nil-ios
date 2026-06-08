import Foundation

public struct NetworkEventSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let url: String
    public let method: String
    public let statusCode: Int?
    public let durationMs: Int
    public let timestamp: Date
    public let pinned: Bool

    init(event: NetworkEvent) {
        id = event.id
        url = event.url
        method = event.method
        statusCode = event.statusCode
        durationMs = event.durationMs
        timestamp = event.timestamp
        pinned = event.pinned
    }
}
