import Foundation

final class NILSampleMockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        if url.path == "/mock/failure" {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            return
        }

        let response: (Int, [String: String], Data)
        switch (request.httpMethod ?? "GET", url.path) {
        case ("GET", "/posts/1"):
            response = (
                200,
                ["Content-Type": "application/json"],
                Data("""
                {
                  "id": 1,
                  "title": "Mocked post",
                  "tags": ["ios", "nil", "sample"]
                }
                """.utf8)
            )
        case ("POST", "/post"):
            let requestBody = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            response = (
                201,
                ["Content-Type": "application/json"],
                Data("""
                {
                  "received": \(requestBody.isEmpty ? "null" : requestBody),
                  "status": "mocked"
                }
                """.utf8)
            )
        case ("GET", "/mock/html-502"):
            response = (
                502,
                ["Content-Type": "text/html; charset=utf-8"],
                Data("""
                <!doctype html>
                <html>
                  <body>
                    <h1>502 Bad Gateway</h1>
                    <p>Upstream timeout from mock edge.</p>
                  </body>
                </html>
                """.utf8)
            )
        case ("GET", "/mock/nested-json"):
            response = (
                200,
                ["Content-Type": "application/json"],
                Data(Self.buildNestedJSON(depth: 18).utf8)
            )
        default:
            response = (
                404,
                ["Content-Type": "application/json"],
                Data("""
                {
                  "error": "Not found"
                }
                """.utf8)
            )
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.0,
            httpVersion: "HTTP/1.1",
            headerFields: response.1
        )!

        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.2)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func buildNestedJSON(depth: Int) -> String {
        let leaf = """
        {
          "status": "ok",
          "items": [
            {"id": 1, "name": "alpha"},
            {"id": 2, "name": "beta"},
            {"id": 3, "name": "gamma"}
          ]
        }
        """

        return stride(from: depth, through: 1, by: -1).reduce(leaf) { acc, level in
            """
            {"level_\(level)":{"meta":{"path":"root.level_\(level)"},"responses":[{"id":"resp_\(level)_a","status":"ok","metrics":{"latencyMs":\(level * 7),"cacheHit":\(level % 2 == 0)}},{"id":"resp_\(level)_b","status":"partial","tags":["nested","array","level_\(level)"],"checks":[{"name":"schema","passed":true},{"name":"limits","passed":\(level % 3 != 0)}]}],"child":\(acc)}}
            """
        }
    }
}
