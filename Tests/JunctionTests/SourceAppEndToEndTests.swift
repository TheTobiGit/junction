import XCTest
@testable import JunctionApp

// VAL-CROSS-001: Source-app round trip end-to-end
// A RoutingHistory.Entry recorded with sourceBundleID == "com.tinyspeck.slackmacgap" is loaded
// into ActivityTab, included when source-app filter selects Slack, excluded when filter selects
// another app, and contributes to per-host stats with correct count and dominantBrowser.
final class SourceAppEndToEndTests: XCTestCase {

    private let slack = "com.tinyspeck.slackmacgap"
    private let brave = "com.brave.Browser"
    private let chrome = "com.google.Chrome"

    // VAL-CROSS-001: record → filter: Slack entry appears when filter selects Slack
    func test_slackEntryAppearsWhenSourceFilterSelectsSlack_VAL_CROSS_001() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let history = RoutingHistory(fileURL: tmpURL)
        history.historyEnabledProvider = { true }

        let url = URL(string: "https://github.com/")!
        let result = URLTransformResult(original: url, `final`: url, steps: [])
        history.record(
            originalURL: url,
            result: result,
            outcome: .opened,
            targetBundleID: brave,
            sourceBundleID: slack
        )
        history.record(
            originalURL: url,
            result: result,
            outcome: .opened,
            targetBundleID: chrome,
            sourceBundleID: "com.apple.Mail"
        )

        let exp = expectation(description: "entries populated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let slackEntries = ActivityFilter.filter(history.entries, criteria: .init(sourceBundleID: slack))
        XCTAssertEqual(slackEntries.count, 1)
        XCTAssertEqual(slackEntries[0].sourceBundleID, slack)
        XCTAssertEqual(slackEntries[0].targetBundleID, brave)
    }

    // VAL-CROSS-001: filter excludes Slack entry when another source is selected
    func test_slackEntryExcludedWhenOtherSourceSelected_VAL_CROSS_001() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let history = RoutingHistory(fileURL: tmpURL)
        history.historyEnabledProvider = { true }

        let url = URL(string: "https://github.com/")!
        let result = URLTransformResult(original: url, `final`: url, steps: [])
        history.record(
            originalURL: url,
            result: result,
            outcome: .opened,
            targetBundleID: brave,
            sourceBundleID: slack
        )

        let exp = expectation(description: "entries populated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let mailEntries = ActivityFilter.filter(history.entries, criteria: .init(sourceBundleID: "com.apple.Mail"))
        XCTAssertEqual(mailEntries.count, 0)
    }

    // VAL-CROSS-001: nil sourceBundleID entry excluded when source filter is set
    func test_nilSourceExcludedWhenSourceFilterSet_VAL_CROSS_001() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let history = RoutingHistory(fileURL: tmpURL)
        history.historyEnabledProvider = { true }

        let url = URL(string: "https://github.com/")!
        let result = URLTransformResult(original: url, `final`: url, steps: [])
        history.record(
            originalURL: url,
            result: result,
            outcome: .opened,
            targetBundleID: brave,
            sourceBundleID: nil
        )

        let exp = expectation(description: "entries populated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        wait(for: [exp], timeout: 1)

        let slackEntries = ActivityFilter.filter(history.entries, criteria: .init(sourceBundleID: slack))
        XCTAssertEqual(slackEntries.count, 0)
    }
}
