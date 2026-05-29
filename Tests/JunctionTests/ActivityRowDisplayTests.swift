import XCTest
@testable import JunctionApp

final class ActivityRowDisplayTests: XCTestCase {
    private func entry(
        id: UUID = UUID(),
        cleaned: String = "https://example.com/",
        original: String? = nil,
        target: String? = "com.apple.Safari",
        rule: String? = nil,
        ts: TimeInterval = 0
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            id: id,
            timestamp: Date(timeIntervalSince1970: ts),
            originalURL: original ?? cleaned,
            cleanedURL: cleaned,
            outcome: .opened,
            targetBundleID: target,
            ruleLabel: rule,
            cleaningSteps: []
        )
    }

    func test_buildPreservesOrderWhenNotGrouping() {
        let a = entry(cleaned: "https://a.com/", ts: 100)
        let b = entry(cleaned: "https://b.com/", ts: 200)
        let rows = ActivityRowDisplayBuilder.build(entries: [a, b])
        XCTAssertEqual(rows.map(\.entry.cleanedURL), ["https://a.com/", "https://b.com/"])
        XCTAssertEqual(rows.map(\.groupedCount), [1, 1])
        XCTAssertFalse(rows[0].isGrouped)
    }

    func test_groupCollapsesByCleanedURLAndTarget() {
        let a1 = entry(cleaned: "https://a.com/", ts: 100)
        let a2 = entry(cleaned: "https://a.com/", ts: 300)
        let b = entry(cleaned: "https://a.com/", target: "com.google.Chrome", ts: 200)
        let rows = ActivityRowDisplayBuilder.build(entries: [a1, b, a2], groupDuplicates: true)
        XCTAssertEqual(rows.count, 2)

        let safariRow = rows.first { $0.entry.targetBundleID == "com.apple.Safari" }
        let chromeRow = rows.first { $0.entry.targetBundleID == "com.google.Chrome" }
        XCTAssertEqual(safariRow?.groupedCount, 2)
        XCTAssertEqual(chromeRow?.groupedCount, 1)
    }

    func test_groupRepresentativeUsesMostRecentTimestamp() {
        let oldId = UUID()
        let newId = UUID()
        let oldEntry = entry(id: oldId, cleaned: "https://a.com/", ts: 100)
        let newEntry = entry(id: newId, cleaned: "https://a.com/", ts: 999)
        let rows = ActivityRowDisplayBuilder.build(entries: [oldEntry, newEntry], groupDuplicates: true)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.entry.id, newId)
        XCTAssertEqual(rows.first?.groupedCount, 2)
    }

    func test_filterByQueryUsesPrecomputedHaystack() {
        let safari = entry(cleaned: "https://example.com/", target: "com.apple.Safari")
        let chrome = entry(cleaned: "https://news.ycombinator.com/", target: "com.google.Chrome")
        let rows = ActivityRowDisplayBuilder.build(entries: [safari, chrome])
        let matched = ActivityRowDisplayBuilder.filter(rows, query: "ycombinator")
        XCTAssertEqual(matched.count, 1)
        XCTAssertEqual(matched.first?.entry.cleanedURL, "https://news.ycombinator.com/")
    }

    func test_filterIsCaseInsensitiveAndTrimsWhitespace() {
        let row = entry(cleaned: "https://example.com/")
        let built = ActivityRowDisplayBuilder.build(entries: [row])
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(built, query: "  EXAMPLE ").count, 1)
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(built, query: "").count, 1)
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(built, query: "absent").count, 0)
    }

    func test_groupedHaystackIncludesOriginalURLsFromAllMembers() {
        let a = entry(cleaned: "https://a.com/", original: "https://a.com/?utm_source=foo", ts: 100)
        let b = entry(cleaned: "https://a.com/", original: "https://a.com/?ref=bar", ts: 200)
        let rows = ActivityRowDisplayBuilder.build(entries: [a, b], groupDuplicates: true)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(rows, query: "utm_source").count, 1)
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(rows, query: "ref=bar").count, 1)
    }

    func test_bundleDisplayNameCacheReturnsBundleIDForUnknown() {
        BundleDisplayNameCache.shared.clearForTesting()
        let unknown = "com.junction.tests.\(UUID().uuidString)"
        XCTAssertEqual(BundleDisplayNameCache.shared.name(for: unknown), unknown)
    }
}
