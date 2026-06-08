import Foundation

actor NILFilePersistence {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadEvents() -> [NetworkEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([NetworkEvent].self, from: data)
        } catch {
            return []
        }
    }

    func saveEvents(_ events: [NetworkEvent]) {
        do {
            let directoryURL = fileURL.deletingLastPathComponent()
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(events)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            return
        }
    }
}
