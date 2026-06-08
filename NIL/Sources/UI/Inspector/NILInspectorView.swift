import SwiftUI

public struct NILInspectorView: View {
    private struct AnalyzeState: Equatable {
        let title: String
        let bodyText: String
    }

    @StateObject private var viewModel = NILInspectorListViewModel()
    @State private var selectedEvent: NetworkEvent?
    @State private var isLoadingSelectedEvent = false
    @State private var analyzeState: AnalyzeState?
    @State private var showClearAlert = false

    private let onClose: () -> Void

    public init(onClose: @escaping () -> Void = {}) {
        self.onClose = onClose
    }

    public var body: some View {
        Group {
            if let analyzeState {
                NILBodyAnalyzerView(
                    title: analyzeState.title,
                    bodyText: analyzeState.bodyText,
                    onBack: { self.analyzeState = nil }
                )
            } else if let selectedEvent {
                NILInspectorDetailView(
                    event: selectedEvent,
                    onBack: { self.selectedEvent = nil },
                    onAnalyze: { title, payload in
                        self.analyzeState = AnalyzeState(title: title, bodyText: payload)
                    }
                )
            } else if isLoadingSelectedEvent {
                loadingView
            } else {
                listScreen
            }
        }
        .background(NILInspectorTheme.background.ignoresSafeArea())
        .onAppear {
            viewModel.start()
        }
        .alert("Clear all events?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearEvents()
                selectedEvent = nil
            }
        } message: {
            Text("This will delete all unpinned network events. Pinned events are kept.")
        }
    }

    private var listScreen: some View {
        VStack(spacing: 0) {
            headerBar(title: "Network Events", onBack: onClose) {
                HStack(spacing: 4) {
                    Menu {
                        ForEach(NILInspectorStatusFilter.allCases) { filter in
                            Button {
                                viewModel.updateStatusFilter(filter)
                            } label: {
                                if viewModel.statusFilter == filter {
                                    Label(filter.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(filter.rawValue)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }

                    Button {
                        viewModel.toggleLogging()
                    } label: {
                        Image(systemName: viewModel.isLoggingPaused ? "play.circle" : "pause.circle")
                    }

                    Button {
                        showClearAlert = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 10) {
                searchField
                Text(statusBannerText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NILInspectorTheme.textSecondary)
                overviewPanel
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if viewModel.items.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.items) { item in
                            eventRow(item)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 24)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            headerBar(title: "Network Events", onBack: { isLoadingSelectedEvent = false }) {
                EmptyView()
            }
            Spacer()
            ProgressView()
                .tint(NILInspectorTheme.accent)
            Text("Loading event details...")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(NILInspectorTheme.textSecondary)
            Spacer()
        }
    }

    private var searchField: some View {
        nilNoAutoCaps(
            TextField(
                "Search URL / method",
                text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.updateSearchQuery($0) }
                )
            )
            .font(.system(size: 15, weight: .regular))
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(NILInspectorTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(NILInspectorTheme.border, lineWidth: 1)
            )
        )
    }

    private var statusBannerText: String {
        "Filter: \(viewModel.statusFilter.rawValue)" + (viewModel.isLoggingPaused ? " • Paused" : "")
    }

    private var overviewPanel: some View {
        HStack(spacing: 10) {
            overviewCard(title: "Total", value: "\(viewModel.overview.totalCount)", tint: NILInspectorTheme.accent)
            overviewCard(title: "Pinned", value: "\(viewModel.overview.pinnedCount)", tint: .orange)
            overviewCard(title: "Errors", value: "\(viewModel.overview.errorCount)", tint: .red)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No network events yet")
                .font(.system(size: 16, weight: .medium))
            Text("Run requests in the host app and they will appear here.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(NILInspectorTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func eventRow(_ item: NILInspectorListItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(NILInspectorTheme.accent)
                Spacer()
                Text(item.summary.durationMs.formatted() + " ms")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                Button {
                    viewModel.togglePinned(for: item)
                } label: {
                    Image(systemName: item.summary.pinned ? "pin.fill" : "pin")
                        .foregroundStyle(item.summary.pinned ? NILInspectorTheme.accent : NILInspectorTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(item.subtitle)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text("Status: \(item.summary.statusCode.map(String.init) ?? "ERR")")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NILInspectorTheme.statusColor(for: item.summary.statusCode))

            Text(item.timestampText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(NILInspectorTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NILInspectorTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NILInspectorTheme.border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            openEvent(item.id)
        }
    }

    private func overviewCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(NILInspectorTheme.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NILInspectorTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(NILInspectorTheme.border, lineWidth: 1)
        )
    }

    private func openEvent(_ id: UUID) {
        isLoadingSelectedEvent = true
        Task {
            let event = await NIL.getEventById(id)
            await MainActor.run {
                selectedEvent = event
                isLoadingSelectedEvent = false
            }
        }
    }

    private func headerBar<Actions: View>(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .foregroundStyle(.primary)

            Text(title)
                .font(.system(size: 17, weight: .medium))

            Spacer()

            actions()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NILInspectorTheme.elevatedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func nilNoAutoCaps<V: View>(_ view: V) -> some View {
        #if os(iOS)
        view
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        view
        #endif
    }
}
