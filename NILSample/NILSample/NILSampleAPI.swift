import Foundation
import NIL

actor NILSampleAPI {
    static let shared = NILSampleAPI()

    func fetchPost() async throws -> String {
        let session = await makeSession()
        let url = URL(string: "https://sample.nil.mock/posts/1")!
        let (data, response) = try await session.data(from: url)
        return "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1) \(String(decoding: data, as: UTF8.self).prefix(80))"
    }

    func postPayload() async throws -> String {
        let session = await makeSession()
        let url = URL(string: "https://sample.nil.mock/post")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("""
        {
          "platform": "ios",
          "library": "nil",
          "mode": "sample-app"
        }
        """.utf8)

        let (data, response) = try await session.data(for: request)
        return "HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1) \(String(decoding: data, as: UTF8.self).prefix(80))"
    }

    func fetchHTMLBadGateway() async throws -> String {
        let session = await makeSession()
        let url = URL(string: "https://sample.nil.mock/mock/html-502")!
        let (data, response) = try await session.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        return "HTTP \(code) \(String(decoding: data, as: UTF8.self).prefix(60))"
    }

    func fetchNestedJSON() async throws -> String {
        let session = await makeSession()
        let url = URL(string: "https://sample.nil.mock/mock/nested-json")!
        let (data, response) = try await session.data(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        return "HTTP \(code) nested JSON \(data.count) bytes"
    }

    func fetchFailure() async throws -> String {
        let session = await makeSession()
        let url = URL(string: "https://sample.nil.mock/mock/failure")!
        let (_, _) = try await session.data(from: url)
        return "unexpected success"
    }

    private func makeSession() async -> URLSession {
        let baseConfiguration = URLSessionConfiguration.default
        baseConfiguration.protocolClasses = [NILSampleMockURLProtocol.self]
        let configuration = await NIL.interceptingSessionConfiguration(from: baseConfiguration)
        return URLSession(configuration: configuration)
    }
}
