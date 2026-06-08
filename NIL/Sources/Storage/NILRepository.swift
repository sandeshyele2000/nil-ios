import Foundation

public actor NILRepository {
    private var store: NILStore
    private var persistence: NILFilePersistence?
    private var summaryContinuations: [UUID: AsyncStream<[NetworkEventSummary]>.Continuation] = [:]

    init(requestWindowSize: Int, persistenceURL: URL? = nil) {
        store = NILStore(requestWindowSize: requestWindowSize)
        if let persistenceURL {
            persistence = NILFilePersistence(fileURL: persistenceURL)
        }
    }

    func configure(requestWindowSize: Int, persistenceURL: URL?) async {
        persistence = persistenceURL.map { NILFilePersistence(fileURL: $0) }
        await store.configure(requestWindowSize: requestWindowSize)
        if let persistence {
            let restoredEvents = await persistence.loadEvents()
            await store.replaceAll(with: restoredEvents)
        }
        await publishSummaries()
    }

    func addEvent(_ event: NetworkEvent) async {
        await store.add(event)
        await persistIfNeeded()
        await publishSummaries()
    }

    func clear() async {
        await store.clear()
        await persistIfNeeded()
        await publishSummaries()
    }

    func setFilter(_ query: String) async {
        await store.setFilter(query)
        await publishSummaries()
    }

    func setPinned(id: UUID, pinned: Bool) async {
        await store.setPinned(id: id, pinned: pinned)
        await persistIfNeeded()
        await publishSummaries()
    }

    func getEventById(_ eventId: UUID) async -> NetworkEvent? {
        let events = await store.unfilteredSnapshot()
        return events.first(where: { $0.id == eventId })
    }

    func eventsSnapshot() async -> [NetworkEvent] {
        await store.snapshot()
    }

    func summariesSnapshot() async -> [NetworkEventSummary] {
        await store.snapshot().map(NetworkEventSummary.init(event:))
    }

    func eventsStream() async -> AsyncStream<[NetworkEvent]> {
        await store.stream()
    }

    func summariesStream() async -> AsyncStream<[NetworkEventSummary]> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeSummaryContinuation(id: id) }
            }
            summaryContinuations[id] = continuation
            Task {
                let initial = await self.store.snapshot().map(NetworkEventSummary.init(event:))
                continuation.yield(initial)
            }
        }
    }

    private func removeSummaryContinuation(id: UUID) {
        summaryContinuations.removeValue(forKey: id)
    }

    private func publishSummaries() async {
        let visible = await store.snapshot().map(NetworkEventSummary.init(event:))
        for continuation in summaryContinuations.values {
            continuation.yield(visible)
        }
    }

    private func persistIfNeeded() async {
        guard let persistence else { return }
        let events = await store.unfilteredSnapshot()
        await persistence.saveEvents(events)
    }
}
