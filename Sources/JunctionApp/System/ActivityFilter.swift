import Foundation

/// Pure filter logic for the Activity tab. Pulled out of the SwiftUI view so
/// the predicate is testable without standing up a real `RoutingHistory`
/// observable, and so the same filter can be reused (e.g. for an export
/// command in the future).
enum ActivityFilter {
    struct Criteria {
        var query: String = ""
        var showCleanedOnly: Bool = false
        var outcomes: Set<RoutingHistory.Outcome> = []
        var host: String? = nil
        var sourceBundleID: String? = nil
        var targetBundleID: String? = nil
    }

    static func filter(_ entries: [RoutingHistory.Entry], criteria: Criteria) -> [RoutingHistory.Entry] {
        var rows = entries
        if criteria.showCleanedOnly {
            rows = rows.filter { $0.didClean }
        }
        if !criteria.outcomes.isEmpty {
            rows = rows.filter { criteria.outcomes.contains($0.outcome) }
        }
        if let host = criteria.host {
            rows = rows.filter { URL(string: $0.cleanedURL)?.host?.lowercased() == host.lowercased() }
        }
        if let sourceBundleID = criteria.sourceBundleID {
            rows = rows.filter { $0.sourceBundleID == sourceBundleID }
        }
        if let targetBundleID = criteria.targetBundleID {
            rows = rows.filter { $0.targetBundleID == targetBundleID }
        }
        let q = criteria.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return rows }
        return rows.filter {
            $0.originalURL.lowercased().contains(q)
                || $0.cleanedURL.lowercased().contains(q)
                || ($0.targetBundleID ?? "").lowercased().contains(q)
                || ($0.ruleLabel ?? "").lowercased().contains(q)
        }
    }

    static func outcomeCounts(_ entries: [RoutingHistory.Entry]) -> [RoutingHistory.Outcome: Int] {
        var counts: [RoutingHistory.Outcome: Int] = [:]
        for entry in entries {
            counts[entry.outcome, default: 0] += 1
        }
        return counts
    }
}
