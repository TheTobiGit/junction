import AppKit
import Foundation

/// Precomputed display-time strings for an Activity row. Building these once
/// per filter pass keeps the SwiftUI body cheap when scrolling through a few
/// hundred entries: no per-render `RelativeDateTimeFormatter` allocation, no
/// per-render `URL(string:)` parse, no per-render `NSWorkspace`/`Bundle`
/// roundtrip for the target bundle's pretty name.
struct ActivityRowDisplay: Identifiable, Hashable {
    let id: UUID
    let entry: RoutingHistory.Entry
    let relativeTimeString: String
    let prettyTargetBundleName: String?
    let lowercasedHaystack: String
    let groupedCount: Int

    var isGrouped: Bool { groupedCount > 1 }
}

enum ActivityRowDisplayBuilder {
    static func build(
        entries: [RoutingHistory.Entry],
        groupDuplicates: Bool = false,
        now: Date = Date()
    ) -> [ActivityRowDisplay] {
        guard !entries.isEmpty else { return [] }
        let formatter = relativeFormatter

        if !groupDuplicates {
            return entries.map { entry in
                let pretty = entry.targetBundleID.flatMap(BundleDisplayNameCache.shared.name(for:))
                return ActivityRowDisplay(
                    id: entry.id,
                    entry: entry,
                    relativeTimeString: formatter.localizedString(for: entry.timestamp, relativeTo: now),
                    prettyTargetBundleName: pretty,
                    lowercasedHaystack: makeHaystack(entry: entry, prettyTarget: pretty),
                    groupedCount: 1
                )
            }
        }

        struct Group {
            var representative: RoutingHistory.Entry
            var count: Int
            var extraHaystack: [String]
        }

        var insertionOrder: [String] = []
        var groups: [String: Group] = [:]

        for entry in entries {
            let key = groupKey(for: entry)
            if var existing = groups[key] {
                existing.count += 1
                let priorOriginalURL = existing.representative.originalURL
                let priorRuleLabel = existing.representative.ruleLabel
                if entry.timestamp > existing.representative.timestamp {
                    existing.representative = entry
                    if priorOriginalURL != entry.originalURL {
                        existing.extraHaystack.append(priorOriginalURL.lowercased())
                    }
                    if let priorRuleLabel, priorRuleLabel != entry.ruleLabel {
                        existing.extraHaystack.append(priorRuleLabel.lowercased())
                    }
                } else {
                    if entry.originalURL != existing.representative.originalURL {
                        existing.extraHaystack.append(entry.originalURL.lowercased())
                    }
                    if let label = entry.ruleLabel,
                       label != existing.representative.ruleLabel {
                        existing.extraHaystack.append(label.lowercased())
                    }
                }
                groups[key] = existing
            } else {
                insertionOrder.append(key)
                groups[key] = Group(representative: entry, count: 1, extraHaystack: [])
            }
        }

        return insertionOrder.compactMap { key in
            guard let group = groups[key] else { return nil }
            let entry = group.representative
            let pretty = entry.targetBundleID.flatMap(BundleDisplayNameCache.shared.name(for:))
            return ActivityRowDisplay(
                id: entry.id,
                entry: entry,
                relativeTimeString: formatter.localizedString(for: entry.timestamp, relativeTo: now),
                prettyTargetBundleName: pretty,
                lowercasedHaystack: makeHaystack(
                    entry: entry,
                    prettyTarget: pretty,
                    extras: group.extraHaystack
                ),
                groupedCount: group.count
            )
        }
    }

    static func filter(
        _ rows: [ActivityRowDisplay],
        query: String
    ) -> [ActivityRowDisplay] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter { $0.lowercasedHaystack.contains(q) }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private static func groupKey(for entry: RoutingHistory.Entry) -> String {
        // `\u{1F}` is unit separator, can't appear in URLs or bundle IDs.
        return entry.cleanedURL + "\u{1F}" + (entry.targetBundleID ?? "")
    }

    private static func makeHaystack(
        entry: RoutingHistory.Entry,
        prettyTarget: String?,
        extras: [String] = []
    ) -> String {
        var parts: [String] = [
            entry.originalURL.lowercased(),
            entry.cleanedURL.lowercased(),
        ]
        if let target = entry.targetBundleID { parts.append(target.lowercased()) }
        if let pretty = prettyTarget { parts.append(pretty.lowercased()) }
        if let rule = entry.ruleLabel { parts.append(rule.lowercased()) }
        parts.append(contentsOf: extras)
        return parts.joined(separator: "\u{1F}")
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
