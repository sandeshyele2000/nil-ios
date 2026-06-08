import Testing
@testable import NIL
import Foundation

@Test func repositoryRestoresPersistedEvents() async throws {
    let directoryURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("events.json", isDirectory: false)
    let event = makeEvent(url: "https://persisted.dev")

    let firstRepository = NILRepository(requestWindowSize: 5, persistenceURL: fileURL)
    await firstRepository.configure(requestWindowSize: 5, persistenceURL: fileURL)
    await firstRepository.addEvent(event)

    let secondRepository = NILRepository(requestWindowSize: 5, persistenceURL: fileURL)
    await secondRepository.configure(requestWindowSize: 5, persistenceURL: fileURL)

    let snapshot = await secondRepository.eventsSnapshot()
    #expect(snapshot.count == 1)
    #expect(snapshot.first?.url == event.url)
    #expect(snapshot.first?.id == event.id)
}

@Test func clearPreservesPinnedEvents() async throws {
    let store = NILStore(requestWindowSize: 5)
    await store.add(makeEvent(url: "https://keep.dev", pinned: true))
    await store.add(makeEvent(url: "https://drop.dev"))

    await store.clear()

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 1)
    #expect(snapshot.first?.url == "https://keep.dev")
    #expect(snapshot.first?.pinned == true)
}

@Test func curlGeneratorIncludesHeadersAndBody() {
    let event = NetworkEvent(
        url: "https://api.nil.dev/items",
        method: "POST",
        requestHeaders: ["Accept": "application/json"],
        requestBody: "{\"id\":1}",
        durationMs: 10
    )

    let curl = CurlGenerator.fromEvent(event)
    #expect(curl.contains("curl -X POST"))
    #expect(curl.contains("-H 'Accept: application/json'"))
    #expect(curl.contains("--data-raw '{\"id\":1}'"))
    #expect(curl.contains("'https://api.nil.dev/items'"))
}

@Test func xhrGeneratorIncludesHeadersAndBody() {
    let event = NetworkEvent(
        url: "https://api.nil.dev/items",
        method: "POST",
        requestHeaders: ["Accept": "application/json"],
        requestBody: "{\"id\":1}",
        durationMs: 10
    )

    let xhr = XHRGenerator.fromEvent(event)
    #expect(xhr.contains("xhr.open(\"POST\", \"https://api.nil.dev/items\", true);"))
    #expect(xhr.contains("xhr.setRequestHeader(\"Accept\", \"application/json\");"))
    #expect(xhr.contains("xhr.send(\"{\\\"id\\\":1}\");"))
}

@Test func bodyAnalyzerFindsTextMatches() {
    let lines = NILBodyAnalyzer.textLines(from: "alpha\nbeta\nalpha two")
    let matches = NILBodyAnalyzer.textMatches(lines: lines, query: "alpha")

    #expect(matches.map(\.lineIndex) == [0, 2])
}

@Test func bodyAnalyzerFlattensAndSearchesJSONPaths() {
    let json = """
    {"user":{"name":"Sam"},"items":[{"id":1}]}
    """

    let lines = NILBodyAnalyzer.jsonLines(from: json)
    let matches = NILBodyAnalyzer.jsonMatches(lines: lines, query: "$.user.name", mode: .path)

    #expect(!lines.isEmpty)
    #expect(matches.count == 1)
    #expect(lines.contains(where: { $0.rendered == "\"user\": {" }))
    #expect(lines.contains(where: { $0.rendered == "\"name\": \"Sam\"" }))
}

@Test func bodyAnalyzerPrettyPrintsJSONText() {
    let json = #"{"b":true,"a":[{"name":"Sam"}]}"#

    let pretty = NILBodyAnalyzer.prettyPrintedText(from: json)

    #expect(pretty.contains("{"))
    #expect(pretty.contains(#""a": ["#))
    #expect(pretty.contains(#"[0]: {"#))
    #expect(pretty.contains(#""name": "Sam""#))
    #expect(pretty.contains(#""b": true"#))
}

@Test func exportItemRetainsTitleAndContent() {
    let item = NILExportItem(title: "Request Body", content: "hello")
    #expect(item.title == "Request Body")
    #expect(item.content == "hello")
}

@Test func inspectorOverviewCountsPinnedAndErrors() {
    let summaries = [
        NetworkEventSummary(event: NetworkEvent(url: "https://ok.dev", method: "GET", statusCode: 200, durationMs: 5)),
        NetworkEventSummary(event: NetworkEvent(url: "https://pin.dev", method: "GET", statusCode: 500, durationMs: 5, pinned: true)),
        NetworkEventSummary(event: NetworkEvent(url: "https://err.dev", method: "GET", statusCode: nil, durationMs: 5))
    ]

    let overview = NILInspectorOverview.fromSummaries(summaries)
    #expect(overview.totalCount == 3)
    #expect(overview.pinnedCount == 1)
    #expect(overview.errorCount == 2)
}

@Test func windowSizeTrimsOldestUnpinned() async throws {
    let store = NILStore(requestWindowSize: 2)
    await store.add(makeEvent(url: "https://a.dev"))
    await store.add(makeEvent(url: "https://b.dev"))
    await store.add(makeEvent(url: "https://c.dev"))

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 2)
    #expect(snapshot.map(\.url) == ["https://c.dev", "https://b.dev"])
}

@Test func pinnedEventsArePreservedDuringTrim() async throws {
    let store = NILStore(requestWindowSize: 1)
    let pinned = makeEvent(url: "https://pinned.dev", pinned: true)
    await store.add(pinned)
    await store.add(makeEvent(url: "https://new.dev"))
    await store.add(makeEvent(url: "https://newer.dev"))

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 2)
    #expect(snapshot.contains(where: { $0.url == "https://pinned.dev" && $0.pinned }))
    #expect(snapshot.contains(where: { $0.url == "https://newer.dev" }))
}

@Test func filterMatchesAcrossFields() async throws {
    let store = NILStore(requestWindowSize: 5)
    await store.add(makeEvent(url: "https://one.dev", responseBody: "alpha"))
    await store.add(makeEvent(url: "https://two.dev", requestBody: "beta-payload"))
    await store.setFilter("beta")

    let snapshot = await store.snapshot()
    #expect(snapshot.count == 1)
    #expect(snapshot.first?.url == "https://two.dev")
}

@Test func repositoryProvidesSummaryProjection() async throws {
    let repository = NILRepository(requestWindowSize: 5)
    let event = makeEvent(url: "https://summary.dev", pinned: true)

    await repository.addEvent(event)

    let summaries = await repository.summariesSnapshot()
    #expect(summaries.count == 1)
    #expect(summaries.first?.id == event.id)
    #expect(summaries.first?.url == event.url)
    #expect(summaries.first?.pinned == true)
}

@Test func repositoryCanLoadEventById() async throws {
    let repository = NILRepository(requestWindowSize: 5)
    let event = makeEvent(url: "https://detail.dev")

    await repository.addEvent(event)

    let loaded = await repository.getEventById(event.id)
    #expect(loaded == event)
}

private func makeEvent(
    url: String,
    requestBody: String? = nil,
    responseBody: String? = nil,
    pinned: Bool = false
) -> NetworkEvent {
    NetworkEvent(
        url: url,
        method: "GET",
        requestBody: requestBody,
        responseBody: responseBody,
        durationMs: 12,
        pinned: pinned
    )
}
