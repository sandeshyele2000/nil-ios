import SwiftUI
import NIL

struct ContentView: View {
    @State private var statusText = "No calls yet"

    var body: some View {
        NavigationStack {
            List {
                Section("Usage") {
                    Text("Run mocked requests, then open the floating NIL button.")
                        .foregroundColor(.secondary)
                }

                Section("Traffic") {
                    actionButton("JSON Call") {
                        await runAction("JSON") {
                            try await NILSampleAPI.shared.fetchPost()
                        }
                    }

                    actionButton("POST Call") {
                        await runAction("POST") {
                            try await NILSampleAPI.shared.postPayload()
                        }
                    }

                    actionButton("HTML 502") {
                        await runAction("HTML 502") {
                            try await NILSampleAPI.shared.fetchHTMLBadGateway()
                        }
                    }

                    actionButton("Long JSON") {
                        await runAction("Long JSON") {
                            try await NILSampleAPI.shared.fetchNestedJSON()
                        }
                    }

                    actionButton("Failed Call") {
                        await runAction("Failure") {
                            try await NILSampleAPI.shared.fetchFailure()
                        }
                    }

                    actionButton("Parallel Calls") {
                        await runParallelCalls()
                    }
                }

                Section("Status") {
                    Text(statusText)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("NIL Sample")
        }
        .nilInspectorLauncher()
    }

    private func actionButton(_ title: String, action: @escaping () async -> Void) -> some View {
        Button(title) {
            Task { await action() }
        }
    }

    private func runAction(_ label: String, action: @escaping () async throws -> String) async {
        do {
            let result = try await action()
            statusText = "\(label): \(result)"
        } catch {
            statusText = "\(label) failed: \(error.localizedDescription)"
        }
    }

    private func runParallelCalls() async {
        do {
            async let first = NILSampleAPI.shared.fetchPost()
            async let second = NILSampleAPI.shared.fetchNestedJSON()
            let results = try await [first, second]
            statusText = "Parallel: \(results.count) mocked calls finished"
        } catch {
            statusText = "Parallel failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
