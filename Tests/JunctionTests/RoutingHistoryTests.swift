import XCTest
@testable import JunctionApp

final class RoutingHistoryTests: XCTestCase {
    private func makeTrace(from input: String, to output: String, steps: [String] = []) -> URLTransformResult {
        let inURL = URL(string: input)!
        let outURL = URL(string: output)!
        let mapped: [URLTransformResult.Step] = steps.map { id in
            URLTransformResult.Step(identifier: id, before: inURL, after: outURL)
        }
        return URLTransformResult(original: inURL, final: outURL, steps: mapped)
    }

    private func makeTempHistory() -> (RoutingHistory, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-history-\(UUID().uuidString).json")
        let history = RoutingHistory(fileURL: url)
        return (history, url)
    }

    private func drainMain() {
        let exp = expectation(description: "main queue drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    func test_recordingAndDecodingPreservesAllFields() throws {
        let entry = RoutingHistory.Entry(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            originalURL: "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com",
            cleanedURL: "https://example.com",
            outcome: .opened,
            targetBundleID: "com.apple.Safari",
            ruleLabel: "equals:example.com",
            cleaningSteps: ["outgoing-redirect-unwrapper", "tracker-stripper"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([entry])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([RoutingHistory.Entry].self, from: data)
        XCTAssertEqual(decoded.first?.outcome, .opened)
        XCTAssertEqual(decoded.first?.cleaningSteps, ["outgoing-redirect-unwrapper", "tracker-stripper"])
        XCTAssertTrue(decoded.first?.didClean ?? false)
    }

    func test_didCleanIsFalseWhenURLsMatch() {
        let entry = RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: "https://example.com/",
            cleanedURL: "https://example.com/",
            outcome: .opened,
            targetBundleID: nil,
            ruleLabel: nil,
            cleaningSteps: []
        )
        XCTAssertFalse(entry.didClean)
    }

    // VAL-M1-SCHEMA-001: Legacy history.json (no new keys) decodes successfully
    func test_legacyHistoryDecodesWithoutNewFields_VAL_M1_SCHEMA_001() throws {
        let legacyJSON = """
        [{
            "id": "00000000-0000-0000-0000-000000000001",
            "timestamp": "2024-01-01T00:00:00Z",
            "originalURL": "https://example.com",
            "cleanedURL": "https://example.com",
            "outcome": "opened",
            "targetBundleID": "com.apple.Safari",
            "ruleLabel": "suffix:example.com",
            "cleaningSteps": []
        }]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([RoutingHistory.Entry].self, from: legacyJSON)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].targetBundleID, "com.apple.Safari")
        XCTAssertEqual(entries[0].ruleLabel, "suffix:example.com")
        XCTAssertEqual(entries[0].cleaningSteps, [])
    }

    // VAL-M1-SCHEMA-002: Legacy entries default new fields to nil
    func test_legacyEntriesDefaultNewFieldsToNil_VAL_M1_SCHEMA_002() throws {
        let legacyJSON = """
        [{
            "id": "00000000-0000-0000-0000-000000000002",
            "timestamp": "2024-01-01T00:00:00Z",
            "originalURL": "https://example.com",
            "cleanedURL": "https://example.com",
            "outcome": "opened",
            "targetBundleID": null,
            "ruleLabel": null,
            "cleaningSteps": []
        }]
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([RoutingHistory.Entry].self, from: legacyJSON)
        XCTAssertNil(entries[0].sourceBundleID)
        XCTAssertNil(entries[0].targetStorageKey)
    }

    // VAL-M1-SCHEMA-003: New fields round-trip through JSON
    func test_newFieldsRoundTripThroughJSON_VAL_M1_SCHEMA_003() throws {
        let entry = RoutingHistory.Entry(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            originalURL: "https://example.com",
            cleanedURL: "https://example.com",
            outcome: .opened,
            targetBundleID: "com.google.Chrome",
            ruleLabel: nil,
            cleaningSteps: [],
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "profile:com.google.Chrome:Default"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RoutingHistory.Entry.self, from: data)
        XCTAssertEqual(decoded.sourceBundleID, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(decoded.targetStorageKey, "profile:com.google.Chrome:Default")
        XCTAssertEqual(decoded.targetBundleID, "com.google.Chrome")
        XCTAssertEqual(decoded.outcome, .opened)
    }

    // VAL-M1-SCHEMA-004: record(...) populates sourceBundleID from caller
    func test_recordPopulatesSourceBundleIDFromCaller_VAL_M1_SCHEMA_004() {
        let (history, _) = makeTempHistory()
        let trace = makeTrace(from: "https://example.com", to: "https://example.com")
        history.record(
            originalURL: URL(string: "https://example.com")!,
            result: trace,
            outcome: .opened,
            sourceBundleID: "com.tinyspeck.slackmacgap"
        )
        drainMain()
        XCTAssertEqual(history.entries.first?.sourceBundleID, "com.tinyspeck.slackmacgap")

        let (history2, _) = makeTempHistory()
        history2.record(
            originalURL: URL(string: "https://example.com")!,
            result: trace,
            outcome: .opened
        )
        drainMain()
        XCTAssertNil(history2.entries.first?.sourceBundleID)
    }

    // VAL-M1-SCHEMA-005: record(...) populates targetStorageKey from caller
    func test_recordPopulatesTargetStorageKeyFromCaller_VAL_M1_SCHEMA_005() {
        let (history, _) = makeTempHistory()
        let trace = makeTrace(from: "https://example.com", to: "https://example.com")
        history.record(
            originalURL: URL(string: "https://example.com")!,
            result: trace,
            outcome: .opened,
            targetStorageKey: "profile:com.google.Chrome:Default"
        )
        drainMain()
        XCTAssertEqual(history.entries.first?.targetStorageKey, "profile:com.google.Chrome:Default")

        let (history2, _) = makeTempHistory()
        history2.record(
            originalURL: URL(string: "https://example.com")!,
            result: trace,
            outcome: .opened
        )
        drainMain()
        XCTAssertNil(history2.entries.first?.targetStorageKey)
    }

    // VAL-M1-SCHEMA-006: Disk persistence preserves new fields across reload
    func test_diskPersistencePreservesNewFieldsAcrossReload_VAL_M1_SCHEMA_006() {
        let (history, fileURL) = makeTempHistory()
        let trace = makeTrace(from: "https://example.com", to: "https://example.com")
        history.record(
            originalURL: URL(string: "https://example.com")!,
            result: trace,
            outcome: .opened,
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "app:com.apple.Safari"
        )
        drainMain()
        let persistExp = expectation(description: "persist queue drain")
        history.persistQueue.async { persistExp.fulfill() }
        wait(for: [persistExp], timeout: 2)

        let reloaded = RoutingHistory(fileURL: fileURL)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.sourceBundleID, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(reloaded.entries.first?.targetStorageKey, "app:com.apple.Safari")
    }

    // VAL-M1-SCHEMA-007: AppDelegate call sites pass FrontmostTracker source
    func test_appDelegateCallSitesPassFrontmostSource_VAL_M1_SCHEMA_007() {
        let (history, _) = makeTempHistory()
        let trace = makeTrace(from: "https://example.com", to: "https://example.com")
        history.record(
            originalURL: URL(string: "https://example.com")!,
            result: trace,
            outcome: .opened,
            targetBundleID: "com.apple.Safari",
            ruleLabel: "suffix:example.com",
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "app:com.apple.Safari"
        )
        drainMain()
        XCTAssertEqual(history.entries.first?.sourceBundleID, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(history.entries.first?.targetStorageKey, "app:com.apple.Safari")
        XCTAssertEqual(history.entries.first?.targetBundleID, "com.apple.Safari")
    }
}
