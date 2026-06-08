import Foundation

public enum NILBodyAnalyzerMode: String, CaseIterable, Identifiable, Sendable {
    case text = "Text"
    case path = "Path"

    public var id: String { rawValue }
}

public struct NILBodyTextMatch: Equatable, Sendable {
    public let lineIndex: Int
}

public struct NILJSONLine: Identifiable, Equatable, Sendable {
    public let id: String
    public let depth: Int
    public let path: String
    public let rendered: String
}

public struct NILJSONSearchResult: Equatable, Sendable {
    public let rowID: String
    public let path: String
    public let expansionPaths: [String]
}

public struct NILJSONRenderRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let depth: Int
    public let rendered: String
    public let isExpandable: Bool
    public let isClosingRow: Bool
}

public indirect enum NILJSONTreeNode: Equatable, Sendable {
    case object(
        key: String?,
        path: String,
        children: [NILJSONTreeNode],
        isLast: Bool
    )
    case array(
        key: String?,
        path: String,
        children: [NILJSONTreeNode],
        isLast: Bool
    )
    case value(
        key: String?,
        path: String,
        value: String,
        isLast: Bool
    )
}

public enum NILBodyAnalyzer {
    public static func textLines(from body: String) -> [String] {
        let normalizedBody = prettyPrintedText(from: body)
        return normalizedBody.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    public static func textMatches(lines: [String], query: String) -> [NILBodyTextMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return lines.enumerated().compactMap { index, line in
            line.localizedCaseInsensitiveContains(trimmed) ? NILBodyTextMatch(lineIndex: index) : nil
        }
    }

    public static func jsonLines(from body: String) -> [NILJSONLine] {
        guard let tree = jsonTree(from: body) else { return [] }
        let rows = jsonRenderRows(root: tree, expandedPaths: allContainerPaths(in: tree))
        return rows.compactMap { row in
            guard !row.isClosingRow || row.rendered == "}" || row.rendered == "]" || row.rendered.hasSuffix(",") else {
                return NILJSONLine(id: row.id, depth: row.depth, path: row.path, rendered: row.rendered)
            }
            return NILJSONLine(id: row.id, depth: row.depth, path: row.path, rendered: row.rendered)
        }
    }

    public static func prettyPrintedText(from body: String) -> String {
        guard let tree = jsonTree(from: body) else { return body }
        let rows = jsonRenderRows(root: tree, expandedPaths: allContainerPaths(in: tree))
        return rows
            .map { String(repeating: "  ", count: $0.depth) + $0.rendered }
            .joined(separator: "\n")
    }

    public static func jsonMatches(lines: [NILJSONLine], query: String, mode: NILBodyAnalyzerMode) -> [Int] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return lines.enumerated().compactMap { index, line in
            let target = mode == .path ? line.path : line.rendered
            return target.localizedCaseInsensitiveContains(trimmed) ? index : nil
        }
    }

    public static func jsonTree(from body: String) -> NILJSONTreeNode? {
        guard let data = body.data(using: .utf8) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return buildTreeNode(
            object,
            key: nil,
            path: "$",
            isLast: true
        )
    }

    public static func jsonRenderRows(
        root: NILJSONTreeNode,
        expandedPaths: Set<String>
    ) -> [NILJSONRenderRow] {
        var rows: [NILJSONRenderRow] = []
        appendRenderRows(node: root, depth: 0, expandedPaths: expandedPaths, rows: &rows)
        return rows
    }

    public static func jsonSearchResults(
        root: NILJSONTreeNode,
        query: String,
        mode: NILBodyAnalyzerMode
    ) -> [NILJSONSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [NILJSONSearchResult] = []
        appendSearchResults(
            node: root,
            ancestors: [],
            query: trimmed,
            mode: mode,
            results: &results
        )
        return results
    }

    public static func allContainerPaths(in root: NILJSONTreeNode) -> Set<String> {
        var paths: Set<String> = []
        appendContainerPaths(node: root, into: &paths)
        return paths
    }

    public static func toggledExpandedPaths(
        current: Set<String>,
        path: String
    ) -> Set<String> {
        var updated = current
        if updated.contains(path) {
            updated.remove(path)
        } else {
            updated.insert(path)
        }
        return updated
    }

    private static func buildJSONLines(
        _ value: Any,
        path: String,
        depth: Int,
        key: String?,
        isLast: Bool,
        into lines: inout [NILJSONLine]
    ) {
        switch value {
        case let dictionary as [String: Any]:
            lines.append(
                NILJSONLine(
                    id: "\(path)-open",
                    depth: depth,
                    path: path,
                    rendered: openingLine(prefix: keyPrefix(key), symbol: "{")
                )
            )
            let sortedKeys = dictionary.keys.sorted()
            for (index, childKey) in sortedKeys.enumerated() {
                let childPath = path == "$" ? "$.\(childKey)" : "\(path).\(childKey)"
                buildJSONLines(
                    dictionary[childKey] as Any,
                    path: childPath,
                    depth: depth + 1,
                    key: childKey,
                    isLast: index == sortedKeys.count - 1,
                    into: &lines
                )
            }
            lines.append(
                NILJSONLine(
                    id: "\(path)-close",
                    depth: depth,
                    path: path,
                    rendered: closingLine(symbol: "}", isLast: isLast)
                )
            )

        case let array as [Any]:
            lines.append(
                NILJSONLine(
                    id: "\(path)-open",
                    depth: depth,
                    path: path,
                    rendered: openingLine(prefix: keyPrefix(key), symbol: "[")
                )
            )
            for (index, child) in array.enumerated() {
                let childPath = "\(path)[\(index)]"
                buildJSONLines(
                    child,
                    path: childPath,
                    depth: depth + 1,
                    key: "[\(index)]",
                    isLast: index == array.count - 1,
                    into: &lines
                )
            }
            lines.append(
                NILJSONLine(
                    id: "\(path)-close",
                    depth: depth,
                    path: path,
                    rendered: closingLine(symbol: "]", isLast: isLast)
                )
            )

        case let string as String:
            let rendered = leafLine(key: key, value: stringLiteral(string), isLast: isLast)
            lines.append(NILJSONLine(id: path, depth: depth, path: path, rendered: rendered))

        case let number as NSNumber:
            let rendered = leafLine(key: key, value: literal(for: number), isLast: isLast)
            lines.append(NILJSONLine(id: path, depth: depth, path: path, rendered: rendered))

        case _ as NSNull:
            lines.append(
                NILJSONLine(
                    id: path,
                    depth: depth,
                    path: path,
                    rendered: leafLine(key: key, value: "null", isLast: isLast)
                )
            )

        default:
            lines.append(
                NILJSONLine(
                    id: path,
                    depth: depth,
                    path: path,
                    rendered: leafLine(key: key, value: stringLiteral(String(describing: value)), isLast: isLast)
                )
            )
        }
    }

    private static func openingLine(prefix: String?, symbol: String) -> String {
        guard let prefix else { return symbol }
        return "\(prefix): \(symbol)"
    }

    private static func closingLine(symbol: String, isLast: Bool) -> String {
        isLast ? symbol : "\(symbol),"
    }

    private static func leafLine(key: String?, value: String, isLast: Bool) -> String {
        let suffix = isLast ? "" : ","
        if let key {
            return "\(keyPrefix(key) ?? key): \(value)\(suffix)"
        }
        return "\(value)\(suffix)"
    }

    private static func keyPrefix(_ key: String?) -> String? {
        guard let key else { return nil }
        if key.hasPrefix("[") && key.hasSuffix("]") {
            return key
        }
        return "\"\(escaped(key))\""
    }

    private static func stringLiteral(_ value: String) -> String {
        "\"\(escaped(value))\""
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private static func literal(for number: NSNumber) -> String {
        if CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        return number.stringValue
    }

    private static func buildTreeNode(
        _ value: Any,
        key: String?,
        path: String,
        isLast: Bool
    ) -> NILJSONTreeNode {
        switch value {
        case let dictionary as [String: Any]:
            let sortedKeys = dictionary.keys.sorted()
            let children = sortedKeys.enumerated().map { index, childKey in
                buildTreeNode(
                    dictionary[childKey] as Any,
                    key: childKey,
                    path: path == "$" ? "$.\(childKey)" : "\(path).\(childKey)",
                    isLast: index == sortedKeys.count - 1
                )
            }
            return .object(key: key, path: path, children: children, isLast: isLast)

        case let array as [Any]:
            let children = array.enumerated().map { index, child in
                buildTreeNode(
                    child,
                    key: "[\(index)]",
                    path: "\(path)[\(index)]",
                    isLast: index == array.count - 1
                )
            }
            return .array(key: key, path: path, children: children, isLast: isLast)

        case let string as String:
            return .value(key: key, path: path, value: stringLiteral(string), isLast: isLast)

        case let number as NSNumber:
            return .value(key: key, path: path, value: literal(for: number), isLast: isLast)

        case _ as NSNull:
            return .value(key: key, path: path, value: "null", isLast: isLast)

        default:
            return .value(key: key, path: path, value: stringLiteral(String(describing: value)), isLast: isLast)
        }
    }

    private static func appendRenderRows(
        node: NILJSONTreeNode,
        depth: Int,
        expandedPaths: Set<String>,
        rows: inout [NILJSONRenderRow]
    ) {
        switch node {
        case let .object(key, path, children, isLast):
            rows.append(
                NILJSONRenderRow(
                    id: "\(path)-open",
                    path: path,
                    depth: depth,
                    rendered: openingLine(prefix: keyPrefix(key), symbol: "{"),
                    isExpandable: true,
                    isClosingRow: false
                )
            )
            guard expandedPaths.contains(path) else { return }
            for child in children {
                appendRenderRows(node: child, depth: depth + 1, expandedPaths: expandedPaths, rows: &rows)
            }
            rows.append(
                NILJSONRenderRow(
                    id: "\(path)-close",
                    path: path,
                    depth: depth,
                    rendered: closingLine(symbol: "}", isLast: isLast),
                    isExpandable: false,
                    isClosingRow: true
                )
            )

        case let .array(key, path, children, isLast):
            rows.append(
                NILJSONRenderRow(
                    id: "\(path)-open",
                    path: path,
                    depth: depth,
                    rendered: openingLine(prefix: keyPrefix(key), symbol: "["),
                    isExpandable: true,
                    isClosingRow: false
                )
            )
            guard expandedPaths.contains(path) else { return }
            for child in children {
                appendRenderRows(node: child, depth: depth + 1, expandedPaths: expandedPaths, rows: &rows)
            }
            rows.append(
                NILJSONRenderRow(
                    id: "\(path)-close",
                    path: path,
                    depth: depth,
                    rendered: closingLine(symbol: "]", isLast: isLast),
                    isExpandable: false,
                    isClosingRow: true
                )
            )

        case let .value(key, path, value, isLast):
            rows.append(
                NILJSONRenderRow(
                    id: path,
                    path: path,
                    depth: depth,
                    rendered: leafLine(key: key, value: value, isLast: isLast),
                    isExpandable: false,
                    isClosingRow: false
                )
            )
        }
    }

    private static func appendSearchResults(
        node: NILJSONTreeNode,
        ancestors: [String],
        query: String,
        mode: NILBodyAnalyzerMode,
        results: inout [NILJSONSearchResult]
    ) {
        switch node {
        case let .object(key, path, children, _):
            let rendered = openingLine(prefix: keyPrefix(key), symbol: "{")
            if matches(query: query, mode: mode, path: path, rendered: rendered),
               rendered.localizedCaseInsensitiveContains(query) {
                results.append(
                    NILJSONSearchResult(
                        rowID: "\(path)-open",
                        path: path,
                        expansionPaths: ancestors + [path]
                    )
                )
            }
            for child in children {
                appendSearchResults(node: child, ancestors: ancestors + [path], query: query, mode: mode, results: &results)
            }

        case let .array(key, path, children, _):
            let rendered = openingLine(prefix: keyPrefix(key), symbol: "[")
            if matches(query: query, mode: mode, path: path, rendered: rendered),
               rendered.localizedCaseInsensitiveContains(query) {
                results.append(
                    NILJSONSearchResult(
                        rowID: "\(path)-open",
                        path: path,
                        expansionPaths: ancestors + [path]
                    )
                )
            }
            for child in children {
                appendSearchResults(node: child, ancestors: ancestors + [path], query: query, mode: mode, results: &results)
            }

        case let .value(key, path, value, isLast):
            let rendered = leafLine(key: key, value: value, isLast: isLast)
            if matches(query: query, mode: mode, path: path, rendered: rendered),
               rendered.localizedCaseInsensitiveContains(query) {
                results.append(
                    NILJSONSearchResult(
                        rowID: path,
                        path: path,
                        expansionPaths: ancestors
                    )
                )
            }
        }
    }

    private static func appendContainerPaths(
        node: NILJSONTreeNode,
        into paths: inout Set<String>
    ) {
        switch node {
        case let .object(_, path, children, _):
            paths.insert(path)
            for child in children {
                appendContainerPaths(node: child, into: &paths)
            }
        case let .array(_, path, children, _):
            paths.insert(path)
            for child in children {
                appendContainerPaths(node: child, into: &paths)
            }
        case .value:
            break
        }
    }

    private static func matches(
        query: String,
        mode: NILBodyAnalyzerMode,
        path: String,
        rendered: String
    ) -> Bool {
        switch mode {
        case .path:
            return path.localizedCaseInsensitiveContains(query)
        case .text:
            return rendered.localizedCaseInsensitiveContains(query) || path.localizedCaseInsensitiveContains(query)
        }
    }
}
