import XCTest
@testable import JunctionApp

final class ActivityFilterTests: XCTestCase {
    private func entry(
        outcome: RoutingHistory.Outcome,
        original: String = "https://example.com/?utm_source=email",
        cleaned: String = "https://example.com/",
        target: String? = "com.apple.Safari",
        rule: String? = nil
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: original,
            cleanedURL: cleaned,
            outcome: outcome,
            targetBundleID: target,
            ruleLabel: rule,
            cleaningSteps: original == cleaned ? [] : ["tracker-stripper"]
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
}
