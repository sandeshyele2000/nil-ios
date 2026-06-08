import Foundation

public enum XHRGenerator {
    public static func fromEvent(_ event: NetworkEvent) -> String {
        var lines = [
            "const xhr = new XMLHttpRequest();",
            "xhr.open(\"\(escape(event.method))\", \"\(escape(event.url))\", true);"
        ]

        for key in event.requestHeaders.keys.sorted() {
            let value = event.requestHeaders[key] ?? ""
            lines.append("xhr.setRequestHeader(\"\(escape(key))\", \"\(escape(value))\");")
        }

        lines.append("xhr.onreadystatechange = function () {")
        lines.append("  if (xhr.readyState === 4) {")
        lines.append("    console.log(xhr.status, xhr.responseText);")
        lines.append("  }")
        lines.append("};")

        if let body = event.requestBody, !body.isEmpty {
            lines.append("xhr.send(\"\(escape(body))\");")
        } else {
            lines.append("xhr.send();")
        }

        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
