import Foundation

enum ActivityStats {
    struct HostStat {
        let host: String
        let count: Int
        let lastRoute: Date
        let dominantBrowser: String?
        let trackerHits: Int
    }

    private static let trackerStepIdentifiers: Set<String> = [
        "tracker-stripper",
        "rule-tracker-stripper",
    ]

    static func byHost(entries: [RoutingHistory.Entry]) -> [HostStat] {
        guard !entries.isEmpty else { return [] }

        struct Accumulator {
            var count: Int = 0
            var lastRoute: Date = .distantPast
            var browserCounts: [String: Int] = [:]
            var trackerHits: Int = 0
        }

        var insertionOrder: [String] = []
        var accumulators: [String: Accumulator] = [:]

        for entry in entries {
            guard let host = URL(string: entry.cleanedURL)?.host?.lowercased() else { continue }

            if accumulators[host] == nil {
                insertionOrder.append(host)
                accumulators[host] = Accumulator()
            }

            accumulators[host]!.count += 1

            if entry.timestamp > accumulators[host]!.lastRoute {
                accumulators[host]!.lastRoute = entry.timestamp
            }

            if let target = entry.targetBundleID {
                accumulators[host]!.browserCounts[target, default: 0] += 1
            }

            if entry.cleaningSteps.contains(where: { trackerStepIdentifiers.contains($0) }) {
                accumulators[host]!.trackerHits += 1
            }
        }

        let stats: [HostStat] = insertionOrder.compactMap { host in
            guard let acc = accumulators[host] else { return nil }
            let dominant = acc.browserCounts.max(by: { $0.value < $1.value })?.key
            return HostStat(
                host: host,
                count: acc.count,
                lastRoute: acc.lastRoute,
                dominantBrowser: dominant,
                trackerHits: acc.trackerHits
            )
        }

        return stats.sorted { $0.count > $1.count }
    }
}
