import Foundation

@MainActor
public final class NILInspectorListViewModel: ObservableObject {
    @Published public private(set) var items: [NILInspectorListItem] = []
    @Published public private(set) var isLoggingPaused = false
    @Published public private(set) var selectedEvent: NetworkEvent?
    @Published public private(set) var searchQuery: String = ""
    @Published public private(set) var statusFilter: NILInspectorStatusFilter = .all
    @Published public private(set) var overview = NILInspectorOverview(totalCount: 0, pinnedCount: 0, errorCount: 0)

    private var allSummaries: [NetworkEventSummary] = []

    private var eventsTask: Task<Void, Never>?
    private var queryTask: Task<Void, Never>?
    
    public init() {}

    deinit {
        eventsTask?.cancel()
        queryTask?.cancel()
    }

    public func start() {
        guard eventsTask == nil else { return }

        eventsTask = Task { [weak self] in
            guard let self else { return }
            self.isLoggingPaused = await NIL.isLoggingPaused()
            let stream = await NIL.eventSummariesStream()
            for await summaries in stream {
                guard !Task.isCancelled else { break }
                self.allSummaries = summaries
                self.overview = NILInspectorOverview.fromSummaries(summaries)
                self.applyActiveFilters()
            }
        }
    }

    public func selectEvent(id: UUID?) {
        guard let id else {
            selectedEvent = nil
            return
        }

        Task { [weak self] in
            guard let self else { return }
            self.selectedEvent = await NIL.getEventById(id)
        }
    }

    public func toggleLogging() {
        Task { [weak self] in
            guard let self else { return }
            if self.isLoggingPaused {
                await NIL.resumeLogging()
                self.isLoggingPaused = false
            } else {
                await NIL.pauseLogging()
                self.isLoggingPaused = true
            }
        }
    }

    public func clearEvents() {
        Task {
            await NIL.clearEvents()
            await MainActor.run {
                self.selectedEvent = nil
            }
        }
    }

    public func togglePinned(for item: NILInspectorListItem) {
        Task { [weak self] in
            guard let self else { return }
            await NIL.setPinned(eventId: item.id, pinned: !item.summary.pinned)
            if self.selectedEvent?.id == item.id {
                self.selectedEvent = await NIL.getEventById(item.id)
            }
        }
    }

    public func updateSearchQuery(_ query: String) {
        searchQuery = query
        queryTask?.cancel()
        queryTask = Task {
            await NIL.setFilter(query)
        }
    }

    public func updateStatusFilter(_ filter: NILInspectorStatusFilter) {
        statusFilter = filter
        applyActiveFilters()
    }

    private func applyActiveFilters() {
        items = allSummaries
            .filter { statusFilter.matches(statusCode: $0.statusCode) }
            .map(NILInspectorListItem.init(summary:))
    }
}
