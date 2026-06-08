import Foundation

public struct NILInspectorOverview: Equatable, Sendable {
    public let totalCount: Int
    public let pinnedCount: Int
    public let errorCount: Int

    static func fromSummaries(_ summaries: [NetworkEventSummary]) -> NILInspectorOverview {
        NILInspectorOverview(
            totalCount: summaries.count,
            pinnedCount: summaries.filter(\.pinned).count,
            errorCount: summaries.filter { summary in
                summary.statusCode == nil || (summary.statusCode ?? 0) >= 400
            }.count
        )
    }
}
