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

    private let persistLock = NSLock()
    private var persistSequence: UInt64 = 0

    init(fileURL: URL? = nil) {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? dir.appendingPathComponent("history.json")

        let loaded = Self.load(from: self.fileURL)
        let deduped = Self.removingDuplicates(loaded)
        self.entries = deduped
        if loaded.count != deduped.count {
            // One-shot compaction: prior versions of Junction wrote one row
            // per click, so an existing user's history.json may have many
            // duplicate (cleanedURL, targetBundleID) entries. Rewrite the
            // file in deduped form on first launch so the on-disk shape
            // matches the new in-memory invariant.
            self.persist(deduped)
        }
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
            // Auto-dedupe: a re-open of the same URL+target should refresh
            // the existing row in place rather than pushing a new row that
            // pushes the old one further down. Preserve the prior row's
            // UUID so SwiftUI animates the move-to-top instead of treating
            // it as a row destroyed + a new row created.
            let key = Self.dedupeKey(for: entry)
            var next = self.entries
            var promotedID: UUID? = nil
            if let priorIndex = next.firstIndex(where: { Self.dedupeKey(for: $0) == key }) {
                promotedID = next[priorIndex].id
                next.remove(at: priorIndex)
            }
            var promoted = entry
            if let promotedID { promoted.id = promotedID }
            next.insert(promoted, at: 0)
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

    /// Stable identity used to collapse repeated opens into a single row.
    /// Two entries with the same cleaned URL routed to the same target
    /// represent the "same" link in the user's mind; the rule label and
    /// outcome can drift over time (rule edits, cleaning toggles) but
    /// shouldn't fragment the row.
    static func dedupeKey(for entry: Entry) -> String {
        entry.cleanedURL + "\u{1F}" + (entry.targetBundleID ?? "")
    }

    /// Compacts an entries array so each `dedupeKey` appears at most once,
    /// keeping the most recent occurrence and preserving the input ordering
    /// of those survivors. Used at load time to migrate legacy
    /// pre-dedupe history.json files in place.
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
