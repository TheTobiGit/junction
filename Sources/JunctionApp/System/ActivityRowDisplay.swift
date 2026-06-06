import AppKit
import Foundation

/// Precomputed display data for an Activity row. Building these once keeps the
/// SwiftUI body cheap when scrolling through a few hundred entries: no
/// per-render `URL(string:)` parse, no per-render `NSWorkspace`/`Bundle`
/// roundtrip for the target bundle's pretty name, and duplicate grouping can
/// reuse the cached haystacks instead of rebuilding them.
struct ActivityRowDisplay: Identifiable, Hashable {
    let id: UUID
    let entry: RoutingHistory.Entry
    let prettyTargetBundleName: String?
    var lowercasedHaystack: String
    var representedEntries: [RoutingHistory.Entry]

    var relativeTimeString: String {
        ActivityRowDisplayBuilder.relativeTimeString(for: entry.timestamp)
    }

    var duplicateCount: Int {
        representedEntries.count
    }
}

enum ActivityRowDisplayBuilder {
    static func build(
        entries: [RoutingHistory.Entry]
    ) -> [ActivityRowDisplay] {
        guard !entries.isEmpty else { return [] }
        return entries.map { entry in
            let pretty = entry.targetBundleID.flatMap(BundleDisplayNameCache.shared.name(for:))
            return ActivityRowDisplay(
                id: entry.id,
                entry: entry,
                prettyTargetBundleName: pretty,
                lowercasedHaystack: makeHaystack(entry: entry, prettyTarget: pretty),
                representedEntries: [entry]
            )
        }
    }

    static func filter(
        _ rows: [ActivityRowDisplay],
        query: String,
        groupDuplicates: Bool = false
    ) -> [ActivityRowDisplay] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let displayRows = groupDuplicates ? group(rows) : rows
        return q.isEmpty ? displayRows : displayRows.filter { $0.lowercasedHaystack.contains(q) }
    }

    static func relativeTimeString(
        for date: Date,
        relativeTo now: Date = Date()
    ) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: now)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = makeRelativeFormatter()

    private static func makeRelativeFormatter() -> RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }

    /// Warms ICU and Foundation locale work with a temporary formatter so the
    /// first Activity-tab render doesn't pay the cold-start cost.
    static func warmFormatter() {
        _ = makeRelativeFormatter().localizedString(for: Date(), relativeTo: Date())
    }

    private static func makeHaystack(
        entry: RoutingHistory.Entry,
        prettyTarget: String?
    ) -> String {
        var parts: [String] = [
            entry.originalURL.lowercased(),
            entry.cleanedURL.lowercased(),
        ]
        if let target = entry.targetBundleID { parts.append(target.lowercased()) }
        if let pretty = prettyTarget { parts.append(pretty.lowercased()) }
        if let rule = entry.ruleLabel { parts.append(rule.lowercased()) }
        // Use Unit Separator for the cached haystack too so we can concatenate
        // fields without risking collisions with the printable row content.
        return parts.joined(separator: "\u{1F}")
    }

    private static func group(_ rows: [ActivityRowDisplay]) -> [ActivityRowDisplay] {
        var grouped: [ActivityRowDisplay] = []
        var indexByKey: [String: Int] = [:]
        grouped.reserveCapacity(rows.count)

        for row in rows {
            let key = RoutingHistory.dedupeKey(for: row.entry)
            if let existingIndex = indexByKey[key] {
                grouped[existingIndex].representedEntries.append(row.entry)
                grouped[existingIndex].lowercasedHaystack += "\u{1F}" + row.lowercasedHaystack
            } else {
                indexByKey[key] = grouped.count
                grouped.append(row)
            }
        }

        return grouped
    }
}

/// Process-wide cache for `bundleID -> display name` lookups. Resolution hits
/// `NSWorkspace.urlForApplication(...)` plus a `Bundle(url:)` infoDictionary
/// read, both of which touch the filesystem. The Activity tab calls this for
/// every visible row, so caching keeps scroll work O(1) per row.
final class BundleDisplayNameCache {
    static let shared = BundleDisplayNameCache()

    private let lock = NSLock()
    private var cache: [String: String] = [:]

    func name(for bundleID: String) -> String {
        lock.lock()
        if let cached = cache[bundleID] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let resolved = Self.resolve(bundleID)

        lock.lock()
        cache[bundleID] = resolved
        lock.unlock()
        return resolved
    }

    func clearForTesting() {
        lock.lock()
        cache.removeAll(keepingCapacity: false)
        lock.unlock()
    }

    private static func resolve(_ bundleID: String) -> String {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: app),
           let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return bundleID
    }
}
