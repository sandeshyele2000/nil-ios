import Foundation

public enum NIL {
    fileprivate static let state = NILState()
    public static let defaultInspectorPayloadCharLimit = 200_000
    public static let defaultMaxStoredEvents = 100

    public static func initialize(
        enableFloatingButton: Bool = false,
        inspectorPayloadCharLimit: Int = defaultInspectorPayloadCharLimit,
        maxStoredEvents: Int = defaultMaxStoredEvents,
        persistenceEnabled: Bool = true
    ) async {
        await state.initialize(
            configuration: .init(
                enableFloatingButton: enableFloatingButton,
                inspectorPayloadCharLimit: inspectorPayloadCharLimit,
                maxStoredEvents: maxStoredEvents,
                persistenceEnabled: persistenceEnabled
            )
        )
    }

    public static func pauseLogging() async {
        await state.setLoggingPaused(true)
    }

    public static func resumeLogging() async {
        await state.setLoggingPaused(false)
    }

    public static func isLoggingPaused() async -> Bool {
        await state.loggingPaused()
    }

    public static func clearEvents() async {
        await state.clearEvents()
    }

    public static func setFilter(_ query: String) async {
        await state.setFilter(query)
    }

    public static func setPinned(eventId: UUID, pinned: Bool) async {
        await state.setPinned(eventId: eventId, pinned: pinned)
    }

    public static func getEventById(_ eventId: UUID) async -> NetworkEvent? {
        await state.getEventById(eventId)
    }

    public static func eventsSnapshot() async -> [NetworkEvent] {
        await state.snapshot()
    }

    public static func eventSummariesSnapshot() async -> [NetworkEventSummary] {
        await state.summariesSnapshot()
    }

    public static func eventsStream() async -> AsyncStream<[NetworkEvent]> {
        await state.eventsStream()
    }

    public static func eventSummariesStream() async -> AsyncStream<[NetworkEventSummary]> {
        await state.summariesStream()
    }

    public static func interceptingSessionConfiguration(
        from base: URLSessionConfiguration = .default
    ) async -> URLSessionConfiguration {
        await state.interceptingSessionConfiguration(from: base)
    }
}

actor NILState {
    private var configuration = NILConfiguration()
    private var isInitialized = false
    private var isLoggingPaused = false
    private var repository = NILRepository(requestWindowSize: NILConfiguration.defaultMaxStoredEvents)

    func initialize(configuration: NILConfiguration) async {
        self.configuration = configuration
        let persistenceURL = resolvedPersistenceURL(from: configuration)
        if isInitialized {
            await repository.configure(
                requestWindowSize: configuration.maxStoredEvents,
                persistenceURL: persistenceURL
            )
        } else {
            repository = NILRepository(
                requestWindowSize: configuration.maxStoredEvents,
                persistenceURL: persistenceURL
            )
            await repository.configure(
                requestWindowSize: configuration.maxStoredEvents,
                persistenceURL: persistenceURL
            )
            isInitialized = true
        }
        await NILURLProtocol.configure(configuration: configuration)
    }

    func setLoggingPaused(_ value: Bool) async {
        isLoggingPaused = value
        await NILURLProtocol.setLoggingPaused(value)
    }

    func loggingPaused() -> Bool {
        isLoggingPaused
    }

    func clearEvents() async {
        await repository.clear()
    }

    func setFilter(_ query: String) async {
        await repository.setFilter(query)
    }

    func setPinned(eventId: UUID, pinned: Bool) async {
        await repository.setPinned(id: eventId, pinned: pinned)
    }

    func getEventById(_ eventId: UUID) async -> NetworkEvent? {
        await repository.getEventById(eventId)
    }

    func snapshot() async -> [NetworkEvent] {
        await repository.eventsSnapshot()
    }

    func summariesSnapshot() async -> [NetworkEventSummary] {
        await repository.summariesSnapshot()
    }

    func eventsStream() async -> AsyncStream<[NetworkEvent]> {
        await repository.eventsStream()
    }

    func summariesStream() async -> AsyncStream<[NetworkEventSummary]> {
        await repository.summariesStream()
    }

    func interceptingSessionConfiguration(from base: URLSessionConfiguration) async -> URLSessionConfiguration {
        let copy = base.copy() as? URLSessionConfiguration ?? .default
        configuration.upstreamProtocolClasses = (copy.protocolClasses ?? []).filter { $0 != NILURLProtocol.self }
        await NILURLProtocol.configure(configuration: configuration)
        var classes = copy.protocolClasses ?? []
        classes.removeAll(where: { $0 == NILURLProtocol.self })
        classes.insert(NILURLProtocol.self, at: 0)
        copy.protocolClasses = classes
        return copy
    }

    private func resolvedPersistenceURL(from configuration: NILConfiguration) -> URL? {
        guard configuration.persistenceEnabled else { return nil }

        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return baseURL?
            .appendingPathComponent("NIL", isDirectory: true)
            .appendingPathComponent("events.json", isDirectory: false)
    }
}

enum NILCaptureBridge {
    static func capture(event: NetworkEvent) {
        Task {
            await NIL.state.capture(event: event)
        }
    }
}

private extension NILState {
    func capture(event: NetworkEvent) async {
        guard !isLoggingPaused else { return }
        await repository.addEvent(event)
    }
}
