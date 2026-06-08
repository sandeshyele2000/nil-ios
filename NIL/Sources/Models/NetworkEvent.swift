import Foundation

public struct NetworkEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let url: String
    public let method: String
    public let requestHeaders: [String: String]
    public let requestBody: String?
    public let responseHeaders: [String: String]
    public let responseBody: String?
    public let statusCode: Int?
    public let durationMs: Int
    public let timestamp: Date
    public var pinned: Bool
    public let errorDescription: String?

    public init(
        id: UUID = UUID(),
        url: String,
        method: String,
        requestHeaders: [String: String] = [:],
        requestBody: String? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: String? = nil,
        statusCode: Int? = nil,
        durationMs: Int,
        timestamp: Date = .now,
        pinned: Bool = false,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.url = url
        self.method = method
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.statusCode = statusCode
        self.durationMs = durationMs
        self.timestamp = timestamp
        self.pinned = pinned
        self.errorDescription = errorDescription
    }
}
