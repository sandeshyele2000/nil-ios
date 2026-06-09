# N.I.L - Network Intelligence Layer

N.I.L (Network Intelligence Layer) is an iOS network inspector library for `URLSession`.
It captures request/response data, stores events locally, and provides a built-in inspector UI for reviewing network traffic inside your app.

## What It Does

- Captures HTTP and HTTPS traffic from `URLSession` clients configured through `NIL.interceptingSessionConfiguration(...)`.
- Persists events locally when `persistenceEnabled = true`.
- Optional non-persistent mode (`persistenceEnabled = false`) to keep events in memory only.
- Provides inspector UI with event search, status-code filters, pause/resume logging, clear-all, pinning, request/response detail views, body analysis, and cURL/XHR export.
- Provides a SwiftUI floating launcher for apps built with SwiftUI.

## Project Structure

- `NIL/` -> Swift Package library module (runtime + inspector UI).
- `NILSample/` -> Sample app demonstrating integration with `URLSession`.

Key source areas in `NIL/Sources`:

- `Core/` -> public API (`NIL`).
- `Interceptor/` -> `URLProtocol`-based interception.
- `Storage/` -> in-memory store + optional file persistence.
- `Models/` -> captured event models.
- `UI/` -> inspector screens and launcher.
- `Utils/` -> cURL/XHR export helpers.

## Requirements

- Xcode 16+
- Swift 6.2+
- Deployment targets: iOS 16+, macOS 14+

## Installation (Swift Package Manager)

Add the package to your project:

```swift
.package(url: "https://github.com/sandeshyele2000/nil-ios.git", from: "1.0.0")
```

Then add `NIL` to your target dependencies.

## Quick Start

### 1) Initialize once at app launch

```swift
import NIL

Task {
    await NIL.initialize(
        inspectorPayloadCharLimit: 200_000,
        maxStoredEvents: 300,
        persistenceEnabled: true
    )
}
```

### 2) Build an intercepted `URLSessionConfiguration`

```swift
let configuration = await NIL.interceptingSessionConfiguration(from: .default)
let session = URLSession(configuration: configuration)
```

### 3) Use the session normally

```swift
let url = URL(string: "https://jsonplaceholder.typicode.com/posts/1")!
let (data, response) = try await session.data(from: url)
```

All requests executed through that session are captured automatically.

### 4) Add the inspector launcher in SwiftUI apps

```swift
import SwiftUI
import NIL

struct ContentView: View {
    var body: some View {
        NavigationStack {
            Text("Your app content")
        }
        .nilInspectorLauncher()
    }
}
```

## UIKit Usage

N.I.L works in UIKit projects as well, but the built-in inspector UI is implemented in SwiftUI.
That means UIKit apps should:

- Initialize `NIL` once during app startup.
- Use `NIL.interceptingSessionConfiguration(...)` for the `URLSession` instances they want to inspect.
- Present `NILInspectorView` from UIKit using `UIHostingController`.

### Initialize in `AppDelegate` or `SceneDelegate`

```swift
import UIKit
import NIL

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task {
            await NIL.initialize(
                inspectorPayloadCharLimit: 200_000,
                maxStoredEvents: 300,
                persistenceEnabled: true
            )
        }
        return true
    }
}
```

### Build intercepted sessions in UIKit

```swift
import Foundation
import NIL

func makeSession() async -> URLSession {
    let configuration = await NIL.interceptingSessionConfiguration(from: .default)
    return URLSession(configuration: configuration)
}
```

### Present the inspector from a `UIViewController`

```swift
import SwiftUI
import UIKit
import NIL

final class HomeViewController: UIViewController {
    @IBAction func openInspector() {
        let inspector = NILInspectorView()
        let controller = UIHostingController(rootView: inspector)
        controller.modalPresentationStyle = .fullScreen
        present(controller, animated: true)
    }
}
```

### Important UIKit note

The SwiftUI helper `.nilInspectorLauncher()` is meant for SwiftUI view hierarchies.
In pure UIKit projects, add your own entry point such as:

- A debug button in a view controller.
- A hidden gesture.
- A debug-only menu item.
- A custom floating button managed by UIKit.

## Public API

### `NIL.initialize(enableFloatingButton = false, inspectorPayloadCharLimit = 200_000, maxStoredEvents = 100, persistenceEnabled = true)`

Initializes storage and configures interception runtime.
Initialization can be called again to update runtime configuration.

- `inspectorPayloadCharLimit` caps stored request/response payload text.
- `maxStoredEvents` keeps only the most recent N events.
- `persistenceEnabled = false` disables file-backed persistence.

### `NIL.interceptingSessionConfiguration(from:)`

Returns a copy of the supplied `URLSessionConfiguration` with `NILURLProtocol` inserted ahead of any upstream protocol classes.
Use this to create `URLSession` instances whose traffic should be captured.

### `NIL.pauseLogging()` / `NIL.resumeLogging()`

Temporarily disable or re-enable event capture.

### `NIL.isLoggingPaused()`

Returns current logging state.

### `NIL.clearEvents()`

Clears all captured events.

### `NIL.setFilter(_:)`

Applies text filtering over stored events.

### `NIL.setPinned(eventId:pinned:)`

Pins or unpins a captured event.

### `NIL.getEventById(_:)`

Returns the full `NetworkEvent` for a captured item.

### `NIL.eventsSnapshot()` / `NIL.eventSummariesSnapshot()`

Returns the current captured events as a one-time snapshot.

### `NIL.eventsStream()` / `NIL.eventSummariesStream()`

Returns `AsyncStream` updates for custom UIs.

### `NILInspectorView`

Built-in inspector UI for reviewing captured traffic.

### `View.nilInspectorLauncher()`

SwiftUI helper that overlays a draggable floating launcher and presents `NILInspectorView`.

## Inspector UX

From the built-in inspector you can:

- Browse traffic in reverse chronological order.
- Search by URL and method.
- Filter by status code groups.
- Pause logging during repro steps.
- Clear events.
- Pin events you want to keep visible.
- Open event details for request headers/body and response headers/body.
- Copy generated cURL and XHR snippets.
- Analyze payloads with plain text search and JSON tree mode.

## Sample App

`NILSample/` demonstrates:

- One-time N.I.L initialization.
- Intercepted `URLSession` construction.
- Mocked GET, POST, HTML error, nested JSON, failed, and parallel requests.
- SwiftUI launcher integration via `.nilInspectorLauncher()`.

Main entry points:

- `NILSample/NILSampleApp.swift`
- `NILSample/ContentView.swift`
- `NILSample/NILSampleAPI.swift`

## Build & Test

From `nil-ios/NIL`:

```bash
swift build
swift test
```

To run the sample app, open:

```bash
open nil-ios/NILSample/NILSample.xcodeproj
```

## Library Internals (High-Level)

1. `NIL.interceptingSessionConfiguration(...)` injects `NILURLProtocol`.
2. `NILURLProtocol` receives the outbound request and forwards it through an internal `URLSession`.
3. Request and response metadata are captured.
4. Payloads are decoded as UTF-8 text when possible, otherwise represented as binary.
5. `NILRepository` stores and streams `NetworkEvent` data.
6. Inspector screens consume repository snapshots and streams.

## Notes & Limitations

- N.I.L captures requests only from `URLSession` instances created with `NIL.interceptingSessionConfiguration(...)`.
- The built-in inspector UI is SwiftUI-based; UIKit apps need to present it with `UIHostingController`.
- `URLProtocol` interception is intended for app-controlled sessions, not arbitrary third-party networking stacks that bypass your supplied `URLSessionConfiguration`.
- Capture includes request and response bodies as strings where possible; avoid using it in production if payloads may contain sensitive data.
- Large payloads are truncated based on `inspectorPayloadCharLimit`.

## License

Apache License 2.0
