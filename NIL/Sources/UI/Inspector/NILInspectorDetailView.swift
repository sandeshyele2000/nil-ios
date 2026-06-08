import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct NILInspectorDetailView: View {
    public let event: NetworkEvent
    public let onBack: () -> Void
    public let onAnalyze: (_ title: String, _ payload: String) -> Void

    @State private var requestHeadersExpanded = false
    @State private var requestParamsExpanded = false
    @State private var requestBodyExpanded = true
    @State private var responseHeadersExpanded = false
    @State private var responseBodyExpanded = true

    private var curlExportItem: NILExportItem {
        NILExportItem(title: "request_\(event.id).curl", content: CurlGenerator.fromEvent(event))
    }

    private var xhrExportItem: NILExportItem {
        NILExportItem(title: "request_\(event.id).xhr.js", content: XHRGenerator.fromEvent(event))
    }

    public init(
        event: NetworkEvent,
        onBack: @escaping () -> Void = {},
        onAnalyze: @escaping (_ title: String, _ payload: String) -> Void = { _, _ in }
    ) {
        self.event = event
        self.onBack = onBack
        self.onAnalyze = onAnalyze
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    urlBlock
                    actionButtons

                    expandableSection(
                        title: "Request Headers",
                        isExpanded: $requestHeadersExpanded
                    ) {
                        keyValueRows(event.requestHeaders, emptyLabel: "No request headers")
                    } actions: {
                        sectionActionButtons(
                            analyzeTitle: "Request Headers",
                            analyzePayload: text(from: event.requestHeaders),
                            shareTitle: "Request Headers",
                            shareContent: text(from: event.requestHeaders)
                        )
                    }

                    expandableSection(
                        title: "Request Params",
                        isExpanded: $requestParamsExpanded
                    ) {
                        keyValueRows(requestParams, emptyLabel: "No query params")
                    } actions: {
                        sectionActionButtons(
                            analyzeTitle: "Request Params",
                            analyzePayload: text(from: requestParams),
                            shareTitle: "Request Params",
                            shareContent: text(from: requestParams)
                        )
                    }

                    expandableSection(
                        title: "Request Body",
                        isExpanded: $requestBodyExpanded
                    ) {
                        bodyPreview(event.requestBody, emptyLabel: "No request body")
                    } actions: {
                        sectionActionButtons(
                            analyzeTitle: "Request Body",
                            analyzePayload: event.requestBody ?? "",
                            shareTitle: "Request Body",
                            shareContent: event.requestBody ?? "",
                            searchEnabled: !(event.requestBody ?? "").isEmpty
                        )
                    }

                    expandableSection(
                        title: "Response Headers",
                        isExpanded: $responseHeadersExpanded
                    ) {
                        keyValueRows(event.responseHeaders, emptyLabel: "No response headers")
                    } actions: {
                        sectionActionButtons(
                            analyzeTitle: "Response Headers",
                            analyzePayload: text(from: event.responseHeaders),
                            shareTitle: "Response Headers",
                            shareContent: text(from: event.responseHeaders)
                        )
                    }

                    expandableSection(
                        title: "Response Body",
                        isExpanded: $responseBodyExpanded
                    ) {
                        bodyPreview(event.responseBody, emptyLabel: "No response body")
                    } actions: {
                        sectionActionButtons(
                            analyzeTitle: "Response Body",
                            analyzePayload: event.responseBody ?? "",
                            shareTitle: "Response Body",
                            shareContent: event.responseBody ?? "",
                            searchEnabled: !(event.responseBody ?? "").isEmpty
                        )
                    }
                }
                .padding(12)
            }
            .background(NILInspectorTheme.background)
        }
        .background(NILInspectorTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 32, height: 32)
            }
            .foregroundStyle(.primary)

            Spacer()

            Text("Event Details")
                .font(.system(size: 17, weight: .medium))

            Spacer()

            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(NILInspectorTheme.elevatedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var urlBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(event.url)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                detailMeta(title: "Method", value: event.method, tint: NILInspectorTheme.accent)
                detailMeta(title: "Status", value: event.statusCode.map(String.init) ?? "ERR", tint: NILInspectorTheme.statusColor(for: event.statusCode))
                detailMeta(title: "Time", value: "\(event.durationMs) ms", tint: .primary)
            }

            if let errorDescription = event.errorDescription, !errorDescription.isEmpty {
                Text(errorDescription)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NILInspectorTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NILInspectorTheme.border, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                NILClipboard.copy(CurlGenerator.fromEvent(event))
            } label: {
                actionPill(title: "Copy cURL", systemImage: "doc.on.doc")
            }
            .buttonStyle(.plain)

            ShareLink(item: xhrExportItem.content, preview: SharePreview(xhrExportItem.title)) {
                actionPill(title: "Export XHR", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.plain)
        }
    }

    private func actionPill(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NILInspectorTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NILInspectorTheme.border, lineWidth: 1)
        )
    }

    private func expandableSection<Content: View, Actions: View>(
        title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NILInspectorTheme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                actions()
                content()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(NILInspectorTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(NILInspectorTheme.border, lineWidth: 1)
        )
    }

    private func sectionActionButtons(
        analyzeTitle: String,
        analyzePayload: String,
        shareTitle: String,
        shareContent: String,
        searchEnabled: Bool = true
    ) -> some View {
        HStack(spacing: 10) {
            if searchEnabled {
                Button {
                    onAnalyze(analyzeTitle, analyzePayload)
                } label: {
                    Text("Analyze")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NILInspectorTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(NILInspectorTheme.accent.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }

            if !shareContent.isEmpty {
                ShareLink(item: shareContent, preview: SharePreview(shareTitle)) {
                    Text("Share")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(NILInspectorTheme.elevatedSurface)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func bodyPreview(_ body: String?, emptyLabel: String) -> some View {
        Group {
            if let body, !body.isEmpty {
                ScrollView(.horizontal) {
                    Text(NILBodyAnalyzer.prettyPrintedText(from: body))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(NILInspectorTheme.elevatedSurface)
                )
            } else {
                Text(emptyLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(NILInspectorTheme.textSecondary)
            }
        }
    }

    private func keyValueRows(_ values: [String: String], emptyLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if values.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(NILInspectorTheme.textSecondary)
            } else {
                ForEach(values.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NILInspectorTheme.textSecondary)
                        Text(values[key] ?? "")
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if key != values.keys.sorted().last {
                        Divider()
                    }
                }
            }
        }
    }

    private func keyValueRows(_ values: [(key: String, value: String)], emptyLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if values.isEmpty {
                Text(emptyLabel)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(NILInspectorTheme.textSecondary)
            } else {
                ForEach(Array(values.enumerated()), id: \.offset) { index, pair in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pair.key)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(NILInspectorTheme.textSecondary)
                        Text(pair.value)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if index < values.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func detailMeta(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(NILInspectorTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private var requestParams: [(key: String, value: String)] {
        guard let components = URLComponents(string: event.url) else { return [] }
        let grouped = Dictionary(grouping: components.queryItems ?? [], by: \.name)
        return grouped.keys.sorted().flatMap { key in
            let items = grouped[key] ?? []
            if items.isEmpty {
                return [(key: key, value: "")]
            }
            return items.map { (key: key, value: $0.value ?? "") }
        }
    }

    private func text(from values: [String: String]) -> String {
        values.keys.sorted().map { "\($0): \(values[$0] ?? "")" }.joined(separator: "\n")
    }

    private func text(from values: [(key: String, value: String)]) -> String {
        values.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}

private enum NILClipboard {
    static func copy(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}
