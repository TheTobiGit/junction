import XCTest
@testable import JunctionApp

final class RoutingHistoryDedupeTests: XCTestCase {
    private func entry(
        id: UUID = UUID(),
        cleaned: String,
        target: String? = "com.apple.Safari",
        ts: TimeInterval
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            id: id,
            timestamp: Date(timeIntervalSince1970: ts),
            originalURL: cleaned,
            cleanedURL: cleaned,
            outcome: .opened,
            targetBundleID: target,
            ruleLabel: nil,
            cleaningSteps: []
        )
    }

    private func makeTrace(_ s: String) -> URLTransformResult {
        let url = URL(string: s)!
        return URLTransformResult(original: url, final: url, steps: [])
    }

    private func drainMain() {
        let exp = expectation(description: "main queue drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    private func makeTempHistory(seed: [RoutingHistory.Entry] = []) throws -> (RoutingHistory, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dedupe-history-\(UUID().uuidString).json")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        if !seed.isEmpty {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(seed)
            try data.write(to: url, options: .atomic)
        }
        return (RoutingHistory(fileURL: url), url)
    }

    func test_dedupeKeyDistinguishesByURLAndTarget() {
        let safari = entry(cleaned: "https://a.com/", target: "com.apple.Safari", ts: 0)
        let chrome = entry(cleaned: "https://a.com/", target: "com.google.Chrome", ts: 0)
        XCTAssertNotEqual(
            RoutingHistory.dedupeKey(for: safari),
            RoutingHistory.dedupeKey(for: chrome)
        )
    }

    func test_dedupeKeyHandlesNilTargetBundleID() {
        let blocked = entry(cleaned: "https://a.com/", target: nil, ts: 0)
        let opened = entry(cleaned: "https://a.com/", target: "com.apple.Safari", ts: 0)
        XCTAssertNotEqual(
            RoutingHistory.dedupeKey(for: blocked),
            RoutingHistory.dedupeKey(for: opened)
        )
    }

    func test_removingDuplicatesKeepsMostRecentAndPreservesOrder() {
        let aOld = entry(cleaned: "https://a.com/", ts: 100)
        let b = entry(cleaned: "https://b.com/", ts: 150)
        let aNew = entry(cleaned: "https://a.com/", ts: 200)
        let result = RoutingHistory.removingDuplicates([aOld, b, aNew])
        XCTAssertEqual(result.map(\.cleanedURL), ["https://a.com/", "https://b.com/"])
        let aRow = result.first { $0.cleanedURL == "https://a.com/" }
        XCTAssertEqual(aRow?.timestamp, Date(timeIntervalSince1970: 200))
    }

    func test_removingDuplicatesPreservesIDOfFirstSeen() {
        let stableID = UUID()
        let aOld = entry(id: stableID, cleaned: "https://a.com/", ts: 100)
        let aNew = entry(cleaned: "https://a.com/", ts: 200)
        let result = RoutingHistory.removingDuplicates([aOld, aNew])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, stableID)
    }

    func test_recordKeepsDuplicateRowsWhenGroupingIsDisabled() throws {
        let (history, _) = try makeTempHistory()
        let trace = makeTrace("https://a.com/")
        history.record(originalURL: URL(string: "https://a.com/")!, result: trace, outcome: .opened, targetBundleID: "com.apple.Safari")
        drainMain()
        XCTAssertEqual(history.entries.count, 1)

        let trace2 = makeTrace("https://b.com/")
        history.record(originalURL: URL(string: "https://b.com/")!, result: trace2, outcome: .opened, targetBundleID: "com.apple.Safari")
        drainMain()
        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(history.entries.first?.cleanedURL, "https://b.com/")

        // Re-open the first URL: history should keep both opens because
        // grouping is now opt-in at display time.
        history.record(originalURL: URL(string: "https://a.com/")!, result: trace, outcome: .opened, targetBundleID: "com.apple.Safari")
        drainMain()
        XCTAssertEqual(history.entries.count, 3)
        XCTAssertEqual(history.entries.first?.cleanedURL, "https://a.com/")
        XCTAssertEqual(history.entries.dropFirst().first?.cleanedURL, "https://b.com/")
    }

    func test_recordKeepsDistinctTargetsAsSeparateRows() throws {
        let (history, _) = try makeTempHistory()
        let trace = makeTrace("https://a.com/")
        history.record(originalURL: URL(string: "https://a.com/")!, result: trace, outcome: .opened, targetBundleID: "com.apple.Safari")
        history.record(originalURL: URL(string: "https://a.com/")!, result: trace, outcome: .opened, targetBundleID: "com.google.Chrome")
        drainMain()
        XCTAssertEqual(history.entries.count, 2)
    }

    func test_initPreservesLegacyDuplicateFileUntilGroupingEnabled() throws {
        let aOld = entry(cleaned: "https://a.com/", ts: 100)
        let b = entry(cleaned: "https://b.com/", ts: 150)
        let aNew = entry(cleaned: "https://a.com/", ts: 200)
        let (history, fileURL) = try makeTempHistory(seed: [aNew, b, aOld])

        XCTAssertEqual(history.entries.count, 3)

        let reloaded = RoutingHistory(fileURL: fileURL)
        XCTAssertEqual(reloaded.entries.count, 3)
    }
}
