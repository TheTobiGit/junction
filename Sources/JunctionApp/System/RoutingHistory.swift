import Foundation
import Combine

/// Lightweight audit log of recent routing decisions: which URL came in, what
/// the pipeline made of it, where it was sent, and which rule (if any) fired.
/// Capped in memory and on disk so it can't grow unbounded.
final class RoutingHistory: ObservableObject {
    static let shared = RoutingHistory()

    enum Outcome: String, Codable {
        case opened
        case openedIncognito
        case opened_appScheme
        case blocked
        case picker
    }

    struct Entry: Codable, Identifiable, Hashable {
        var id: UUID = UUID()
        let timestamp: Date
        let originalURL: String
        let cleanedURL: String
        let outcome: Outcome
        let targetBundleID: String?
        let ruleLabel: String?
        let cleaningSteps: [String]
        var sourceBundleID: String? = nil
        var targetStorageKey: String? = nil

        var didClean: Bool { originalURL != cleanedURL }
    }

    static let maxEntries = 200

    @Published private(set) var entries: [Entry] = []

    private let queue = DispatchQueue(label: "dev.gideonsarfo.Junction.history")
    let persistQueue = DispatchQueue(label: "dev.gideonsarfo.Junction.history.persist")
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? dir.appendingPathComponent("history.json")
        self.entries = Self.load(from: self.fileURL)
    }

    func record(
        originalURL: URL,
        result: URLTransformResult,
        outcome: Outcome,
        targetBundleID: String? = nil,
        ruleLabel: String? = nil,
        openedURL: URL? = nil,
        sourceBundleID: String? = nil,
        targetStorageKey: String? = nil
    ) {
        // Activity / Recent re-open the URL we record here, so it has to be
        // the URL we *actually* opened. When cleaning was disabled (globally
        // or via a rule's cleanOverride), `result.final` differs from what
        // hit the browser; callers pass `openedURL` to keep history honest.
        let recordedURL = (openedURL ?? result.final).absoluteString

        let entry = Entry(
            timestamp: Date(),
            originalURL: originalURL.absoluteString,
            cleanedURL: recordedURL,
            outcome: outcome,
            targetBundleID: targetBundleID,
            ruleLabel: ruleLabel,
            cleaningSteps: result.steps.map(\.identifier),
            sourceBundleID: sourceBundleID,
            targetStorageKey: targetStorageKey
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var next = [entry] + self.entries
            if next.count > Self.maxEntries {
                next.removeLast(next.count - Self.maxEntries)
            }
            self.entries = next
            self.persist(next)
        }
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries = []
            self.persist([])
        }
    }

    private func persist(_ entries: [Entry]) {
        let url = fileURL
        persistQueue.async {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(entries) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func load(from url: URL) -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Entry].self, from: data)) ?? []
    }
}
