import Foundation

public final class NILURLProtocol: URLProtocol, @unchecked Sendable {
    private static let handledKey = "com.sandesh.nil.handled"

    private var urlSessionTask: URLSessionDataTask?
    private var session: URLSession?
    private var responseBodyData = Data()
    private var responseHeaders: [String: String] = [:]
    private var statusCode: Int?
    private var requestStartedAt: Date?
    private var capturedRequest: URLRequest?

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        if URLProtocol.property(forKey: handledKey, in: request) != nil {
            return false
        }
        return !NILURLProtocolRuntime.shared.isLoggingPaused
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    static func configure(configuration: NILConfiguration) async {
        NILURLProtocolRuntime.shared.configure(configuration)
    }

    static func setLoggingPaused(_ paused: Bool) async {
        NILURLProtocolRuntime.shared.setLoggingPaused(paused)
    }

    public override func startLoading() {
        let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest ?? NSMutableURLRequest()
        mutableRequest.url = request.url
        mutableRequest.httpMethod = request.httpMethod ?? "GET"
        mutableRequest.allHTTPHeaderFields = request.allHTTPHeaderFields
        mutableRequest.httpBody = request.httpBody

        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutableRequest)
        let outboundRequest = mutableRequest as URLRequest

        capturedRequest = outboundRequest
        requestStartedAt = Date()

        let config = URLSessionConfiguration.ephemeral
        let runtime = NILURLProtocolRuntime.shared
        config.protocolClasses = runtime.upstreamProtocolClasses
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        urlSessionTask = session?.dataTask(with: outboundRequest)
        urlSessionTask?.resume()
    }

    public override func stopLoading() {
        urlSessionTask?.cancel()
        urlSessionTask = nil
        session?.invalidateAndCancel()
        session = nil
    }
}

extension NILURLProtocol: URLSessionDataDelegate {
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if let httpResponse = response as? HTTPURLResponse {
            statusCode = httpResponse.statusCode
            responseHeaders = httpResponse.allHeaderFields.reduce(into: [:]) { result, item in
                result[String(describing: item.key)] = String(describing: item.value)
            }
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        responseBodyData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
        captureEvent(error: error)
        session.finishTasksAndInvalidate()
    }

    private func captureEvent(error: Error?) {
        guard let capturedRequest else { return }
        let runtime = NILURLProtocolRuntime.shared
        let config = runtime.configuration

        let requestBody = capturedRequest.httpBody.flatMap {
            runtime.decodeBody($0, maxBytes: config.inspectorPayloadCharLimit)
        }
        let responseBody = runtime.decodeBody(responseBodyData, maxBytes: config.inspectorPayloadCharLimit)

        let startedAt = requestStartedAt ?? Date()
        let duration = Int((Date().timeIntervalSince(startedAt) * 1000.0).rounded())

        let event = NetworkEvent(
            url: capturedRequest.url?.absoluteString ?? "",
            method: capturedRequest.httpMethod ?? "GET",
            requestHeaders: capturedRequest.allHTTPHeaderFields ?? [:],
            requestBody: requestBody,
            responseHeaders: responseHeaders,
            responseBody: responseBody,
            statusCode: statusCode,
            durationMs: max(duration, 0),
            errorDescription: error?.localizedDescription
        )
        NILCaptureBridge.capture(event: event)
    }
}

enum NILURLProtocolRuntime {
    static let shared = Runtime()

    final class Runtime: @unchecked Sendable {
        private let lock = NSLock()
        private var _configuration = NILConfiguration()
        private var _isLoggingPaused = false

        var configuration: NILConfiguration {
            lock.lock()
            defer { lock.unlock() }
            return _configuration
        }

        var isLoggingPaused: Bool {
            lock.lock()
            defer { lock.unlock() }
            return _isLoggingPaused
        }

        var upstreamProtocolClasses: [AnyClass] {
            lock.lock()
            defer { lock.unlock() }
            return _configuration.upstreamProtocolClasses.filter { $0 != NILURLProtocol.self }
        }

        func configure(_ configuration: NILConfiguration) {
            lock.lock()
            _configuration = configuration
            lock.unlock()
        }

        func setLoggingPaused(_ paused: Bool) {
            lock.lock()
            _isLoggingPaused = paused
            lock.unlock()
        }

        func decodeBody(_ data: Data, maxBytes: Int) -> String? {
            let prefix = data.prefix(maxBytes)
            if let text = String(data: prefix, encoding: .utf8), !text.isEmpty {
                if data.count > maxBytes {
                    return "\(text)\n...[truncated \(data.count - maxBytes) bytes]"
                }
                return text
            }
            return data.isEmpty ? nil : "<\(data.count) bytes (binary)>"
        }
    }

}
