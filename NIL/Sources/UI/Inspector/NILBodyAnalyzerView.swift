import SwiftUI

public struct NILBodyAnalyzerView: View {
    public let title: String
    public let bodyText: String
    public let onBack: (() -> Void)?

    private let cachedJSONTree: NILJSONTreeNode?
    private let cachedTextLines: [String]

    @State private var query = ""
    @State private var mode: NILBodyAnalyzerMode = .text
    @State private var activeMatchIndex = 0
    @State private var expandedPaths: Set<String> = ["$"]
    @State private var jsonSearchResultsState: [NILJSONSearchResult] = []
    @State private var jsonRowsState: [NILJSONRenderRow] = []

    public init(title: String, bodyText: String, onBack: (() -> Void)? = nil) {
        self.title = title
        self.bodyText = bodyText
        self.onBack = onBack
        self.cachedJSONTree = NILBodyAnalyzer.jsonTree(from: bodyText)
        self.cachedTextLines = NILBodyAnalyzer.textLines(from: bodyText)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 12) {
                searchControls

                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView([.horizontal, .vertical]) {
                            Group {
                                if cachedJSONTree != nil {
                                    jsonContent
                                } else {
                                    textContent
                                }
                            }
                            .frame(
                                minWidth: geometry.size.width,
                                minHeight: geometry.size.height,
                                alignment: .topLeading
                            )
                        }
                        .onAppear {
                            scrollToActiveMatch(proxy: proxy)
                        }
                        .onChange(of: activeMatchIndex) { _ in
                            scrollToActiveMatch(proxy: proxy)
                        }
                        .onChange(of: query) { _ in
                            scrollToActiveMatch(proxy: proxy)
                        }
                        .onChange(of: expandedPaths) { _ in
                            scrollToActiveMatch(proxy: proxy)
                        }
                        .onChange(of: jsonRowsState) { _ in
                            scrollToActiveMatch(proxy: proxy)
                        }
                        .onChange(of: mode) { _ in
                            scrollToActiveMatch(proxy: proxy)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding(12)
        }
        .background(NILInspectorTheme.background.ignoresSafeArea())
        .onChange(of: query) { _ in
            activeMatchIndex = 0
        }
        .onChange(of: mode) { _ in
            activeMatchIndex = 0
        }
        .task(id: jsonSearchTaskID) {
            guard let cachedJSONTree else {
                jsonSearchResultsState = []
                return
            }

            let currentQuery = query
            let currentMode = mode
            if !currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            guard !Task.isCancelled else { return }

            let results = await Task.detached(priority: .userInitiated) {
                NILBodyAnalyzer.jsonSearchResults(root: cachedJSONTree, query: currentQuery, mode: currentMode)
            }.value

            guard !Task.isCancelled else { return }
            jsonSearchResultsState = results
            if activeMatchIndex >= results.count {
                activeMatchIndex = max(0, results.count - 1)
            }
        }
        .task(id: jsonRowsTaskID) {
            guard let cachedJSONTree else {
                jsonRowsState = []
                return
            }

            let resolvedExpandedPaths = effectiveExpandedPaths
            let rows = await Task.detached(priority: .userInitiated) {
                NILBodyAnalyzer.jsonRenderRows(root: cachedJSONTree, expandedPaths: resolvedExpandedPaths)
            }.value

            guard !Task.isCancelled else { return }
            jsonRowsState = rows
        }
    }

    private var header: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .foregroundStyle(.primary)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Analyse")
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(NILInspectorTheme.textSecondary)
            }

            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NILInspectorTheme.elevatedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            nilNoAutoCaps(
                TextField("Search", text: $query)
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

            if cachedJSONTree != nil {
                HStack(spacing: 12) {
                    modeChip(title: "Text", isSelected: mode == .text) {
                        mode = .text
                    }
                    modeChip(title: "Path", isSelected: mode == .path) {
                        mode = .path
                    }
                    Spacer()
                }
            }

            if currentMatchCount > 0 {
                HStack {
                    Button {
                        activeMatchIndex = activeMatchIndex == 0 ? currentMatchCount - 1 : activeMatchIndex - 1
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()

                    Text("\(activeMatchIndex + 1)/\(currentMatchCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NILInspectorTheme.textSecondary)

                    Spacer()

                    Button {
                        activeMatchIndex = activeMatchIndex == currentMatchCount - 1 ? 0 : activeMatchIndex + 1
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private var effectiveExpandedPaths: Set<String> {
        var paths = expandedPaths
        if let activeMatch = jsonSearchResultsState.indices.contains(activeMatchIndex) ? jsonSearchResultsState[activeMatchIndex] : nil {
            activeMatch.expansionPaths.forEach { paths.insert($0) }
        }
        paths.insert("$")
        return paths
    }

    private var currentMatchCount: Int {
        if cachedJSONTree != nil {
            return jsonSearchResultsState.count
        }
        return textMatches.count
    }

    private var activeJSONRowID: String? {
        guard jsonSearchResultsState.indices.contains(activeMatchIndex) else { return nil }
        return jsonSearchResultsState[activeMatchIndex].rowID
    }

    private var textLines: [String] {
        cachedTextLines
    }

    private var textMatches: [NILBodyTextMatch] {
        NILBodyAnalyzer.textMatches(lines: textLines, query: query)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(textLines.enumerated()), id: \.offset) { index, line in
                rowText(
                    line: line,
                    query: query,
                    anchorID: activeTextLineIndex == index ? textHorizontalAnchorID(index: index) : nil
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(rowBackground(isMatch: textMatches.map(\.lineIndex).contains(index), isActive: activeTextLineIndex == index))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .id(textRowAnchorID(index: index))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var jsonContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(jsonRowsState) { row in
                HStack(spacing: 6) {
                    Color.clear
                        .frame(width: CGFloat(row.depth) * 14, height: 1)

                    if row.isExpandable && !row.isClosingRow {
                        Image(systemName: effectiveExpandedPaths.contains(row.path) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NILInspectorTheme.textSecondary)
                    } else {
                        Color.clear.frame(width: 12, height: 12)
                    }

                    rowText(
                        line: row.rendered,
                        query: query,
                        anchorID: activeJSONRowID == row.id ? jsonHorizontalAnchorID(rowID: row.id) : nil
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(rowBackground(isMatch: matchedJSONRowIDs.contains(row.id), isActive: activeJSONRowID == row.id))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onTapGesture {
                    guard row.isExpandable, !row.isClosingRow else { return }
                    expandedPaths = NILBodyAnalyzer.toggledExpandedPaths(current: expandedPaths, path: row.path)
                }
                .id(jsonRowAnchorID(rowID: row.id))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var matchedJSONRowIDs: Set<String> {
        Set(jsonSearchResultsState.map(\.rowID))
    }

    private var activeTextLineIndex: Int? {
        guard textMatches.indices.contains(activeMatchIndex) else { return nil }
        return textMatches[activeMatchIndex].lineIndex
    }

    private func scrollToActiveMatch(proxy: ScrollViewProxy) {
        guard let targetID = activeScrollTargetID else { return }
        Task { @MainActor in
            await Task.yield()
            await Task.yield()
            withAnimation {
                proxy.scrollTo(targetID, anchor: UnitPoint(x: 0.2, y: 0.2))
            }
        }
    }

    private var activeScrollTargetID: String? {
        if cachedJSONTree != nil {
            guard let activeJSONRowID else { return nil }
            let hasMatchAnchor = jsonRowsState.contains { row in
                row.id == activeJSONRowID && firstMatchSegments(in: row.rendered, query: query) != nil
            }
            return hasMatchAnchor ? jsonHorizontalAnchorID(rowID: activeJSONRowID) : jsonRowAnchorID(rowID: activeJSONRowID)
        }

        guard let activeTextLineIndex else { return nil }
        let hasMatchAnchor = textLines.indices.contains(activeTextLineIndex)
            && firstMatchSegments(in: textLines[activeTextLineIndex], query: query) != nil
        return hasMatchAnchor ? textHorizontalAnchorID(index: activeTextLineIndex) : textRowAnchorID(index: activeTextLineIndex)
    }

    private func textHorizontalAnchorID(index: Int) -> String {
        "text-anchor-\(index)"
    }

    private func jsonHorizontalAnchorID(rowID: String) -> String {
        "json-anchor-\(rowID)"
    }

    private func textRowAnchorID(index: Int) -> String {
        "text-row-\(index)"
    }

    private func jsonRowAnchorID(rowID: String) -> String {
        "json-row-\(rowID)"
    }

    @ViewBuilder
    private func rowText(line: String, query: String, anchorID: String?) -> some View {
        if let segments = firstMatchSegments(in: line, query: query) {
            HStack(spacing: 0) {
                Text(segments.prefix)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                Text(segments.match)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .background(Color.yellow.opacity(0.4))
                    .id(anchorID)
                Text(segments.suffix)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
            }
            .fixedSize(horizontal: true, vertical: false)
        } else {
            Text(line)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func firstMatchSegments(in line: String, query: String) -> (prefix: String, match: String, suffix: String)? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowerLine = line.lowercased()
        let lowerQuery = trimmed.lowercased()
        guard let range = lowerLine.range(of: lowerQuery) else { return nil }

        return (
            prefix: String(line[..<range.lowerBound]),
            match: String(line[range]),
            suffix: String(line[range.upperBound...])
        )
    }

    private var jsonSearchTaskID: String {
        "\(query)|\(mode.rawValue)|\(cachedJSONTree != nil)"
    }

    private var jsonRowsTaskID: String {
        effectiveExpandedPaths.sorted().joined(separator: "|")
    }

    private func rowBackground(isMatch: Bool, isActive: Bool) -> some View {
        Group {
            if isActive {
                NILInspectorTheme.accent.opacity(0.25)
            } else if isMatch {
                Color.yellow.opacity(0.22)
            } else {
                NILInspectorTheme.surface
            }
        }
    }

    private func modeChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? NILInspectorTheme.accent.opacity(0.16) : NILInspectorTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.clear : NILInspectorTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func highlighted(line: String, query: String) -> AttributedString {
        var attributed = AttributedString(line)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return attributed }

        let lowerLine = line.lowercased()
        let lowerQuery = trimmed.lowercased()
        var searchStart = lowerLine.startIndex

        while let range = lowerLine.range(of: lowerQuery, range: searchStart..<lowerLine.endIndex) {
            if let start = AttributedString.Index(range.lowerBound, within: attributed),
               let end = AttributedString.Index(range.upperBound, within: attributed) {
                attributed[start..<end].backgroundColor = .yellow.opacity(0.4)
            }
            searchStart = range.upperBound
        }

        return attributed
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
