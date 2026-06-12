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

    func test_buildPreservesInputOrder() {
        let a = entry(cleaned: "https://a.com/", ts: 100)
        let b = entry(cleaned: "https://b.com/", ts: 200)
        let rows = ActivityRowDisplayBuilder.build(entries: [a, b])
        XCTAssertEqual(rows.map(\.entry.cleanedURL), ["https://a.com/", "https://b.com/"])
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

    func test_filterCanGroupDuplicatesWhenEnabled() {
        let newest = entry(cleaned: "https://example.com/", original: "https://example.com/?utm=2", ts: 200)
        let other = entry(cleaned: "https://other.com/", ts: 150)
        let oldest = entry(cleaned: "https://example.com/", original: "https://example.com/?utm=1", ts: 100)
        let built = ActivityRowDisplayBuilder.build(entries: [newest, other, oldest])

        let grouped = ActivityRowDisplayBuilder.filter(built, query: "", groupDuplicates: true)

        XCTAssertEqual(grouped.map(\.entry.cleanedURL), ["https://example.com/", "https://other.com/"])
        XCTAssertEqual(grouped.first?.duplicateCount, 2)
        XCTAssertEqual(grouped.first?.entry.originalURL, "https://example.com/?utm=2")
    }

    func test_groupedFilterMatchesAnyDuplicateMember() {
        let newest = entry(cleaned: "https://example.com/", original: "https://example.com/new", ts: 200)
        let oldest = entry(cleaned: "https://example.com/", original: "https://example.com/legacy", ts: 100)
        let built = ActivityRowDisplayBuilder.build(entries: [newest, oldest])

        let grouped = ActivityRowDisplayBuilder.filter(built, query: "legacy", groupDuplicates: true)

        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped.first?.duplicateCount, 2)
        XCTAssertEqual(grouped.first?.entry.originalURL, "https://example.com/new")
    }

    func test_haystackIncludesRuleLabelAndBundleID() {
        let row = entry(
            cleaned: "https://example.com/",
            target: "com.brave.Browser",
            rule: "github-rule"
        )
        let built = ActivityRowDisplayBuilder.build(entries: [row])
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(built, query: "github-rule").count, 1)
        XCTAssertEqual(ActivityRowDisplayBuilder.filter(built, query: "com.brave").count, 1)
    }

    func test_bundleDisplayNameCacheReturnsBundleIDForUnknown() {
        BundleDisplayNameCache.shared.clearForTesting()
        let unknown = "com.junction.tests.\(UUID().uuidString)"
        XCTAssertEqual(BundleDisplayNameCache.shared.name(for: unknown), unknown)
    }
}
