import XCTest
@testable import JunctionApp

final class ActivityFilterTests: XCTestCase {
    private func entry(
        outcome: RoutingHistory.Outcome,
        original: String = "https://example.com/?utm_source=email",
        cleaned: String = "https://example.com/",
        target: String? = "com.apple.Safari",
        rule: String? = nil,
        sourceBundleID: String? = nil
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: original,
            cleanedURL: cleaned,
            outcome: outcome,
            targetBundleID: target,
            ruleLabel: rule,
            cleaningSteps: original == cleaned ? [] : ["tracker-stripper"],
            sourceBundleID: sourceBundleID
        )
    }

    func test_emptyCriteriaReturnsEverything() {
        let rows = [
            entry(outcome: .opened),
            entry(outcome: .blocked, original: "https://example.org/x", cleaned: "https://example.org/x"),
        ]
        XCTAssertEqual(ActivityFilter.filter(rows, criteria: .init()).count, 2)
    }

    func test_showCleanedOnlyDropsUnchanged() {
        let rows = [
            entry(outcome: .opened),
            entry(outcome: .opened, original: "https://example.org/x", cleaned: "https://example.org/x"),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(showCleanedOnly: true))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.cleanedURL, "https://example.com/")
    }

    func test_outcomeFilter() {
        let rows = [
            entry(outcome: .opened),
            entry(outcome: .blocked),
            entry(outcome: .openedIncognito),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(outcomes: [.blocked, .openedIncognito]))
        XCTAssertEqual(Set(result.map { $0.outcome }), [.blocked, .openedIncognito])
    }

    func test_querySearchesAcrossFields() {
        let rows = [
            entry(outcome: .opened, original: "https://acme.com/x", cleaned: "https://acme.com/x"),
            entry(outcome: .opened, original: "https://example.com/", cleaned: "https://example.com/"),
            entry(outcome: .opened, original: "https://other.com/", cleaned: "https://other.com/", rule: "equals:acme.com"),
        ]
        // Matches host substring
        XCTAssertEqual(
            ActivityFilter.filter(rows, criteria: .init(query: "acme")).count,
            2
        )
        // Matches via target bundle
        XCTAssertEqual(
            ActivityFilter.filter(rows, criteria: .init(query: "safari")).count,
            3
        )
    }

    func test_filtersCompose() {
        let rows = [
            entry(outcome: .opened),
            entry(outcome: .blocked, original: "https://acme.com/x", cleaned: "https://acme.com/x"),
            entry(outcome: .opened, original: "https://acme.com/y?utm_source=x", cleaned: "https://acme.com/y"),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(
            query: "acme",
            showCleanedOnly: true,
            outcomes: [.opened]
        ))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.cleanedURL, "https://acme.com/y")
    }

    func test_outcomeCountsAreTotalNotFiltered() {
        let rows = [
            entry(outcome: .opened),
            entry(outcome: .opened),
            entry(outcome: .blocked),
            entry(outcome: .openedIncognito),
        ]
        let counts = ActivityFilter.outcomeCounts(rows)
        XCTAssertEqual(counts[.opened], 2)
        XCTAssertEqual(counts[.blocked], 1)
        XCTAssertEqual(counts[.openedIncognito], 1)
        XCTAssertNil(counts[.picker])
    }

    // VAL-M5-FILTER-001: Host filter narrows to matching cleanedURL host
    func test_hostFilterNarrowsToMatchingHost_VAL_M5_FILTER_001() {
        let rows = [
            entry(outcome: .opened, original: "https://github.com/orgs/acme", cleaned: "https://github.com/orgs/acme"),
            entry(outcome: .opened, original: "https://api.github.com/repos", cleaned: "https://api.github.com/repos"),
            entry(outcome: .opened, original: "https://example.com/", cleaned: "https://example.com/"),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(host: "github.com"))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(URL(string: result[0].cleanedURL)?.host, "github.com")
    }

    // VAL-M5-FILTER-002: Source-app filter narrows to entries from one bundleID
    func test_sourceAppFilterNarrowsToMatchingBundleID_VAL_M5_FILTER_002() {
        let slack = "com.tinyspeck.slackmacgap"
        let rows = [
            entry(outcome: .opened, original: "https://a.com/", cleaned: "https://a.com/", sourceBundleID: slack),
            entry(outcome: .opened, original: "https://b.com/", cleaned: "https://b.com/", sourceBundleID: "com.apple.Mail"),
            entry(outcome: .opened, original: "https://c.com/", cleaned: "https://c.com/", sourceBundleID: nil),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(sourceBundleID: slack))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].sourceBundleID, slack)
    }

    // VAL-M5-FILTER-003: Target-browser filter narrows to entries opened in one browser
    func test_targetBrowserFilterNarrowsToMatchingBundleID_VAL_M5_FILTER_003() {
        let brave = "com.brave.Browser"
        let rows = [
            entry(outcome: .opened, original: "https://a.com/", cleaned: "https://a.com/", target: brave),
            entry(outcome: .opened, original: "https://b.com/", cleaned: "https://b.com/", target: "com.google.Chrome"),
            entry(outcome: .opened, original: "https://c.com/", cleaned: "https://c.com/", target: nil),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(targetBundleID: brave))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].targetBundleID, brave)
    }

    // VAL-M5-FILTER-004: Host + source + target filters compose with AND semantics
    func test_hostSourceTargetFiltersComposeWithAND_VAL_M5_FILTER_004() {
        let slack = "com.tinyspeck.slackmacgap"
        let brave = "com.brave.Browser"
        let rows = [
            entry(outcome: .opened, original: "https://github.com/a", cleaned: "https://github.com/a", target: brave, sourceBundleID: slack),
            entry(outcome: .opened, original: "https://github.com/b", cleaned: "https://github.com/b", target: "com.google.Chrome", sourceBundleID: slack),
            entry(outcome: .opened, original: "https://example.com/", cleaned: "https://example.com/", target: brave, sourceBundleID: slack),
            entry(outcome: .opened, original: "https://github.com/c", cleaned: "https://github.com/c", target: brave, sourceBundleID: "com.apple.Mail"),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(host: "github.com", sourceBundleID: slack, targetBundleID: brave))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].cleanedURL, "https://github.com/a")
    }

    // VAL-M5-FILTER-005: Empty / nil filters do not constrain results
    func test_defaultCriteriaReturnsInputUnchanged_VAL_M5_FILTER_005() {
        let rows = [
            entry(outcome: .opened, original: "https://a.com/", cleaned: "https://a.com/"),
            entry(outcome: .blocked, original: "https://b.com/", cleaned: "https://b.com/"),
            entry(outcome: .picker, original: "https://c.com/", cleaned: "https://c.com/"),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init())
        XCTAssertEqual(result.map { $0.id }, rows.map { $0.id })
    }

    // VAL-M5-FILTER-006: Existing query text search still matches after schema additions
    func test_queryTextSearchPreservedAfterSchemaAdditions_VAL_M5_FILTER_006() {
        let rows = [
            entry(outcome: .opened, original: "https://github.com/orgs", cleaned: "https://github.com/orgs"),
            entry(outcome: .opened, original: "https://example.com/", cleaned: "https://example.com/"),
        ]
        let result = ActivityFilter.filter(rows, criteria: .init(query: "github"))
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result[0].cleanedURL.contains("github"))
    }
}
