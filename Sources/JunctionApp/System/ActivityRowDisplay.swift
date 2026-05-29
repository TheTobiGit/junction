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
}

enum ActivityRowDisplayBuilder {
    static func build(
        entries: [RoutingHistory.Entry],
        now: Date = Date()
    ) -> [ActivityRowDisplay] {
        guard !entries.isEmpty else { return [] }
        let formatter = relativeFormatter
        return entries.map { entry in
            let pretty = entry.targetBundleID.flatMap(BundleDisplayNameCache.shared.name(for:))
            return ActivityRowDisplay(
                id: entry.id,
                entry: entry,
                relativeTimeString: formatter.localizedString(for: entry.timestamp, relativeTo: now),
                prettyTargetBundleName: pretty,
                lowercasedHaystack: makeHaystack(entry: entry, prettyTarget: pretty)
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

    /// Forces the lazy `relativeFormatter` to materialize. The first
    /// call to `localizedString(for:relativeTo:)` triggers ICU and Foundation
    /// locale work that can take 30-100 ms on cold launch; calling this
    /// from a background queue at app start keeps that cost off of the
    /// first Activity-tab render.
    @discardableResult
    static func warmFormatter() -> Bool {
        _ = relativeFormatter.localizedString(for: Date(), relativeTo: Date())
        return true
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
