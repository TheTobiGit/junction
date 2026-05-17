import XCTest
@testable import JunctionApp

final class ActivityStatsTests: XCTestCase {

    private func entry(
        cleanedURL: String,
        timestamp: Date = Date(),
        targetBundleID: String? = nil,
        cleaningSteps: [String] = []
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: timestamp,
            originalURL: cleanedURL,
            cleanedURL: cleanedURL,
            outcome: .opened,
            targetBundleID: targetBundleID,
            ruleLabel: nil,
            cleaningSteps: cleaningSteps
        )
    }

    // VAL-M5-STATS-001: byHost returns rows ordered by count descending; ties break stably (insertion order)
    func test_byHostOrderedByCountDescendingTiesStable_VAL_M5_STATS_001() {
        let t = Date()
        let entries: [RoutingHistory.Entry] = [
            entry(cleanedURL: "https://github.com/a", timestamp: t),
            entry(cleanedURL: "https://github.com/b", timestamp: t),
            entry(cleanedURL: "https://github.com/c", timestamp: t),
            entry(cleanedURL: "https://news.ycombinator.com/1", timestamp: t),
            entry(cleanedURL: "https://news.ycombinator.com/2", timestamp: t),
            entry(cleanedURL: "https://slack.com/x", timestamp: t),
        ]
        let stats = ActivityStats.byHost(entries: entries)
        XCTAssertEqual(stats.map(\.host), ["github.com", "news.ycombinator.com", "slack.com"])
        XCTAssertEqual(stats.map(\.count), [3, 2, 1])
    }

    // VAL-M5-STATS-001 (tie stability): two hosts with equal count preserve insertion order
    func test_byHostTiesPreserveInsertionOrder_VAL_M5_STATS_001() {
        let t = Date()
        let entries: [RoutingHistory.Entry] = [
            entry(cleanedURL: "https://alpha.com/1", timestamp: t),
            entry(cleanedURL: "https://beta.com/1", timestamp: t),
            entry(cleanedURL: "https://alpha.com/2", timestamp: t),
            entry(cleanedURL: "https://beta.com/2", timestamp: t),
        ]
        let stats = ActivityStats.byHost(entries: entries)
        XCTAssertEqual(stats.map(\.host), ["alpha.com", "beta.com"])
        XCTAssertEqual(stats[0].count, 2)
        XCTAssertEqual(stats[1].count, 2)
    }

    // VAL-M5-STATS-002: dominantBrowser is the most frequent target for the host; nil targets excluded
    func test_dominantBrowserIsMostFrequentNonNilTarget_VAL_M5_STATS_002() {
        let t = Date()
        let chrome = "com.google.Chrome"
        let brave = "com.brave.Browser"
        let entries: [RoutingHistory.Entry] = [
            entry(cleanedURL: "https://github.com/a", timestamp: t, targetBundleID: chrome),
            entry(cleanedURL: "https://github.com/b", timestamp: t, targetBundleID: chrome),
            entry(cleanedURL: "https://github.com/c", timestamp: t, targetBundleID: brave),
            entry(cleanedURL: "https://github.com/d", timestamp: t, targetBundleID: nil),
        ]
        let stats = ActivityStats.byHost(entries: entries)
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].dominantBrowser, chrome)
    }

    // VAL-M5-STATS-002: all nil targets → dominantBrowser is nil
    func test_dominantBrowserNilWhenAllTargetsNil_VAL_M5_STATS_002() {
        let entries: [RoutingHistory.Entry] = [
            entry(cleanedURL: "https://github.com/a", targetBundleID: nil),
        ]
        let stats = ActivityStats.byHost(entries: entries)
        XCTAssertNil(stats[0].dominantBrowser)
    }

    // VAL-M5-STATS-003: lastRoute is the most recent timestamp for the host
    func test_lastRouteIsMostRecentTimestamp_VAL_M5_STATS_003() {
        let now = Date()
        let t3h = now.addingTimeInterval(-3 * 3600)
        let t1h = now.addingTimeInterval(-1 * 3600)
        let t10m = now.addingTimeInterval(-10 * 60)
        let entries: [RoutingHistory.Entry] = [
            entry(cleanedURL: "https://github.com/a", timestamp: t3h),
            entry(cleanedURL: "https://github.com/b", timestamp: t1h),
            entry(cleanedURL: "https://github.com/c", timestamp: t10m),
        ]
        let stats = ActivityStats.byHost(entries: entries)
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].lastRoute, t10m)
    }

    // VAL-M5-STATS-004: trackerHits counts entries whose cleaningSteps include the tracker stripper
    func test_trackerHitsCountsEntriesWithTrackerStepIdentifier_VAL_M5_STATS_004() {
        let t = Date()
        let entries: [RoutingHistory.Entry] = [
            entry(cleanedURL: "https://github.com/a", timestamp: t, cleaningSteps: ["tracker-stripper"]),
            entry(cleanedURL: "https://github.com/b", timestamp: t, cleaningSteps: ["rule-tracker-stripper"]),
            entry(cleanedURL: "https://github.com/c", timestamp: t, cleaningSteps: ["amp-collapser"]),
            entry(cleanedURL: "https://github.com/d", timestamp: t, cleaningSteps: []),
        ]
        let stats = ActivityStats.byHost(entries: entries)
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].trackerHits, 2)
    }

    // VAL-M5-STATS-005: empty entries returns empty stats
    func test_emptyEntriesReturnsEmptyStats_VAL_M5_STATS_005() {
        let stats = ActivityStats.byHost(entries: [])
        XCTAssertTrue(stats.isEmpty)
    }

    // VAL-M5-STATS-006: stats are bounded by the in-memory window (200 entries)
    func test_statsBoundedByInMemoryWindow_VAL_M5_STATS_006() {
        let t = Date()
        let entries = (0..<200).map { i in
            entry(cleanedURL: "https://host\(i % 10).com/path", timestamp: t)
        }
        let stats = ActivityStats.byHost(entries: entries)
        let total = stats.reduce(0) { $0 + $1.count }
        XCTAssertLessThanOrEqual(total, RoutingHistory.maxEntries)
        XCTAssertEqual(total, 200)
    }
}
