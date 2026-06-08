import Foundation

struct NILConfiguration: Sendable {
    static let defaultInspectorPayloadCharLimit = 200_000
    static let defaultMaxStoredEvents = 100

    var enableFloatingButton: Bool
    var inspectorPayloadCharLimit: Int
    var maxStoredEvents: Int
    var persistenceEnabled: Bool
    var upstreamProtocolClasses: [AnyClass]

    init(
        enableFloatingButton: Bool = false,
        inspectorPayloadCharLimit: Int = NILConfiguration.defaultInspectorPayloadCharLimit,
        maxStoredEvents: Int = NILConfiguration.defaultMaxStoredEvents,
        persistenceEnabled: Bool = true,
        upstreamProtocolClasses: [AnyClass] = []
    ) {
        self.enableFloatingButton = enableFloatingButton
        self.inspectorPayloadCharLimit = max(10_000, inspectorPayloadCharLimit)
        self.maxStoredEvents = max(1, maxStoredEvents)
        self.persistenceEnabled = persistenceEnabled
        self.upstreamProtocolClasses = upstreamProtocolClasses
    }
}
