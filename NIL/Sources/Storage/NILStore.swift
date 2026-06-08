import Foundation

public actor NILStore {
    private var events: [NetworkEvent] = []
    private var filterQuery: String = ""
    private var requestWindowSize: Int
    private var streamContinuations: [UUID: AsyncStream<[NetworkEvent]>.Continuation] = [:]

    init(requestWindowSize: Int) {
        self.requestWindowSize = max(1, requestWindowSize)
    }

    func configure(requestWindowSize: Int) {
        self.requestWindowSize = max(1, requestWindowSize)
        trimUnpinnedIfNeeded()
        publish()
    }

    func stream() -> AsyncStream<[NetworkEvent]> {
        let id = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id: id) }
            }
            streamContinuations[id] = continuation
            continuation.yield(filteredEvents())
        }
    }

    func snapshot() -> [NetworkEvent] {
        filteredEvents()
    }

    func unfilteredSnapshot() -> [NetworkEvent] {
        events
    }

    func replaceAll(with events: [NetworkEvent]) {
        self.events = events
        trimUnpinnedIfNeeded()
        publish()
    }

    func add(_ event: NetworkEvent) {
        events.insert(event, at: 0)
        trimUnpinnedIfNeeded()
        publish()
    }

    func clear() {
        events.removeAll { !$0.pinned }
        publish()
    }

    func setFilter(_ query: String) {
        filterQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        publish()
    }

    func setPinned(id: UUID, pinned: Bool) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].pinned = pinned
        trimUnpinnedIfNeeded()
        publish()
    }

    private func removeContinuation(id: UUID) {
        streamContinuations.removeValue(forKey: id)
    }

    private func publish() {
        let visible = filteredEvents()
        for continuation in streamContinuations.values {
            continuation.yield(visible)
        }
    }

    private func filteredEvents() -> [NetworkEvent] {
        guard !filterQuery.isEmpty else { return events }
        let needle = filterQuery.lowercased()
        return events.filter { event in
            if event.url.lowercased().contains(needle) { return true }
            if event.method.lowercased().contains(needle) { return true }
            if event.requestBody?.lowercased().contains(needle) == true { return true }
            if event.responseBody?.lowercased().contains(needle) == true { return true }
            if event.errorDescription?.lowercased().contains(needle) == true { return true }
            return false
        }
    }

    private func trimUnpinnedIfNeeded() {
        var unpinnedCount = events.reduce(into: 0) { partialResult, event in
            if !event.pinned {
                partialResult += 1
            }
        }

        guard unpinnedCount > requestWindowSize else { return }

        var index = events.count - 1
        while index >= 0 && unpinnedCount > requestWindowSize {
            if !events[index].pinned {
                events.remove(at: index)
                unpinnedCount -= 1
            }
            index -= 1
        }
    }
}
