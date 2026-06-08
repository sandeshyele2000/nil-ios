import Foundation

public enum CurlGenerator {
    public static func fromEvent(_ event: NetworkEvent) -> String {
        var components: [String] = ["curl", "-X", event.method]

        for key in event.requestHeaders.keys.sorted() {
            let value = event.requestHeaders[key] ?? ""
            components.append("-H")
            components.append(shellQuote("\(key): \(value)"))
        }

        if let body = event.requestBody, !body.isEmpty {
            components.append("--data-raw")
            components.append(shellQuote(body))
        }

        components.append(shellQuote(event.url))
        return components.joined(separator: " ")
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }
}
