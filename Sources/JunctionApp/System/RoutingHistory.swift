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
    /// Display-ready rows precomputed off `entries`. Owning this cache here
    /// (rather than rebuilding inside the SwiftUI view on tab focus) means
    /// switching to Settings → Activity is a pure observation: no
    /// per-row `RelativeDateTimeFormatter` calls, no `NSWorkspace` lookups,
    /// no haystack-string allocations on the main thread when the user
    /// expects the panel to feel instant.
    @Published private(set) var displayRows: [ActivityRowDisplay] = []

    private let queue = DispatchQueue(label: "dev.gideonsarfo.Junction.history")
    let persistQueue = DispatchQueue(label: "dev.gideonsarfo.Junction.history.persist")
    private let fileURL: URL

    private let persistLock = NSLock()
    private var persistSequence: UInt64 = 0

    init(fileURL: URL? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? dir.appendingPathComponent("history.json")

        let loaded = Self.load(from: self.fileURL)
        self.entries = loaded
        self.displayRows = ActivityRowDisplayBuilder.build(entries: loaded)
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
            var next = self.entries
            next.insert(entry, at: 0)
            if next.count > Self.maxEntries {
                next.removeLast(next.count - Self.maxEntries)
            }
            self.entries = next
            self.displayRows = ActivityRowDisplayBuilder.build(entries: next)
            self.persist(next)
        }
    }

    func clear() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.entries = []
            self.displayRows = []
            self.persist([])
        }
    }

    /// Pre-warms the bundle-name and relative-formatter caches off the main
    /// thread. Call once at app launch so the first time the user clicks
    /// Settings → Activity is paying near-zero startup cost.
    func warmDisplayCaches() {
        let snapshot = displayRows
        DispatchQueue.global(qos: .utility).async {
            for row in snapshot {
                if let bundleID = row.entry.targetBundleID {
                    _ = BundleDisplayNameCache.shared.name(for: bundleID)
                }
            }
            ActivityRowDisplayBuilder.warmFormatter()
        }
    }

    private func persist(_ entries: [Entry]) {
        persistLock.lock()
        persistSequence &+= 1
        let mySeq = persistSequence
        persistLock.unlock()

        let url = fileURL
        persistQueue.async { [weak self] in
            guard let self else { return }
            self.persistLock.lock()
            let isLatest = (mySeq == self.persistSequence)
            self.persistLock.unlock()
            guard isLatest else { return }

            let encoder = JSONEncoder()
            // history.json is internal state, so prefer compact output to keep
            // burst writes smaller and faster.
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(entries) else { return }

            self.persistLock.lock()
            let isStillLatest = (mySeq == self.persistSequence)
            self.persistLock.unlock()
            guard isStillLatest else { return }

            try? data.write(to: url, options: .atomic)
        }
    }

    private static func load(from url: URL) -> [Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Entry].self, from: data)) ?? []
    }

    /// Stable identity used to collapse repeated opens into a single row.
    /// Two entries with the same cleaned URL routed to the same target
    /// represent the "same" link in the user's mind; the rule label and
    /// outcome can drift over time (rule edits, cleaning toggles) but
    /// shouldn't fragment the row.
    static func dedupeKey(for entry: Entry) -> String {
        // Use Unit Separator as a delimiter because URLs and bundle IDs are
        // printable strings, so this control character won't collide with data.
        entry.cleanedURL + "\u{1F}" + (entry.targetBundleID ?? "")
    }

    /// Compacts an entries array so each `dedupeKey` appears at most once,
    /// keeping the most recent occurrence and preserving the input ordering
    /// of those survivors. The Activity UI uses this when the user enables
    /// "Group duplicates".
    static func removingDuplicates(_ entries: [Entry]) -> [Entry] {
        var keptIndexByKey: [String: Int] = [:]
        var kept: [Entry] = []
        kept.reserveCapacity(entries.count)
        for entry in entries {
            let key = dedupeKey(for: entry)
            if let existingIndex = keptIndexByKey[key] {
                if entry.timestamp > kept[existingIndex].timestamp {
                    var promoted = entry
                    promoted.id = kept[existingIndex].id
                    kept[existingIndex] = promoted
                }
            } else {
                keptIndexByKey[key] = kept.count
                kept.append(entry)
            }
        }
        return kept
    }
}
