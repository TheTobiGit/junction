import XCTest
@testable import JunctionApp

// VAL-CROSS-008: History schema upgrade is non-destructive
// Pre-mission history.json with no new fields decodes successfully; existing entries appear;
// new entries written carry both new fields populated; file rewritten in new shape only after
// a new entry is recorded.
final class HistorySchemaUpgradeTests: XCTestCase {

    private let legacyJSON = """
    [
      {
        "id": "00000000-0000-0000-0000-000000000001",
        "timestamp": "2024-01-15T10:00:00Z",
        "originalURL": "https://github.com/?utm_source=email",
        "cleanedURL": "https://github.com/",
        "outcome": "opened",
        "targetBundleID": "com.apple.Safari",
        "ruleLabel": "github-rule",
        "cleaningSteps": ["tracker-stripper"]
      },
      {
        "id": "00000000-0000-0000-0000-000000000002",
        "timestamp": "2024-01-15T11:00:00Z",
        "originalURL": "https://example.com/",
        "cleanedURL": "https://example.com/",
        "outcome": "blocked",
        "targetBundleID": null,
        "ruleLabel": null,
        "cleaningSteps": []
      }
    ]
    """

    private func drainMain() {
        let exp = expectation(description: "main queue drain")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    private func makeTempHistory() throws -> (RoutingHistory, URL) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        try legacyJSON.data(using: .utf8)!.write(to: tmpURL)
        let history = RoutingHistory(fileURL: tmpURL)
        return (history, tmpURL)
    }

    private func makeResult(for urlString: String) -> URLTransformResult {
        let url = URL(string: urlString)!
        return URLTransformResult(original: url, `final`: url, steps: [])
    }

    // VAL-CROSS-008: Pre-mission history.json (no new keys) decodes successfully
    func test_legacyHistoryDecodesSuccessfully_VAL_CROSS_008() throws {
        let (history, tmpURL) = try makeTempHistory()
        defer { try? FileManager.default.removeItem(at: tmpURL) }
        XCTAssertEqual(history.entries.count, 2)
    }

    // VAL-CROSS-008: Existing entries appear after decode (pre-existing fields preserved)
    func test_existingEntriesAppearAfterDecode_VAL_CROSS_008() throws {
        let (history, tmpURL) = try makeTempHistory()
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let entry = history.entries.first(where: { $0.cleanedURL == "https://github.com/" })
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.originalURL, "https://github.com/?utm_source=email")
        XCTAssertEqual(entry?.outcome, .opened)
        XCTAssertEqual(entry?.targetBundleID, "com.apple.Safari")
        XCTAssertEqual(entry?.ruleLabel, "github-rule")
        XCTAssertEqual(entry?.cleaningSteps, ["tracker-stripper"])
    }

    // VAL-CROSS-008: Legacy entries default new fields to nil
    func test_legacyEntriesDefaultNewFieldsToNil_VAL_CROSS_008() throws {
        let (history, tmpURL) = try makeTempHistory()
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        for entry in history.entries {
            XCTAssertNil(entry.sourceBundleID)
            XCTAssertNil(entry.targetStorageKey)
        }
    }

    // VAL-CROSS-008: New entries written carry both new fields populated
    func test_newEntriesCarryNewFieldsPopulated_VAL_CROSS_008() throws {
        let (history, tmpURL) = try makeTempHistory()
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let hnURL = "https://news.ycombinator.com/"
        history.record(
            originalURL: URL(string: hnURL)!,
            result: makeResult(for: hnURL),
            outcome: .opened,
            targetBundleID: "com.brave.Browser",
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "app:com.brave.Browser"
        )
        drainMain()

        let newEntry = history.entries.first(where: { $0.cleanedURL == hnURL })
        XCTAssertNotNil(newEntry)
        XCTAssertEqual(newEntry?.sourceBundleID, "com.tinyspeck.slackmacgap")
        XCTAssertEqual(newEntry?.targetStorageKey, "app:com.brave.Browser")
    }

    // VAL-CROSS-008: After new entry recorded, file is rewritten in new shape (new fields present)
    func test_fileRewrittenInNewShapeAfterNewEntry_VAL_CROSS_008() throws {
        let (history, tmpURL) = try makeTempHistory()
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let hnURL = "https://news.ycombinator.com/"
        history.record(
            originalURL: URL(string: hnURL)!,
            result: makeResult(for: hnURL),
            outcome: .opened,
            targetBundleID: "com.brave.Browser",
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "app:com.brave.Browser"
        )
        drainMain()
        let writeExp = expectation(description: "persist queue drain")
        history.persistQueue.async { writeExp.fulfill() }
        wait(for: [writeExp], timeout: 2)

        let data = try Data(contentsOf: tmpURL)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("sourceBundleID"))
        XCTAssertTrue(json.contains("targetStorageKey"))
        XCTAssertTrue(json.contains("com.tinyspeck.slackmacgap"))
    }

    // VAL-CROSS-008: Legacy entries still appear alongside new entries after reload
    func test_legacyAndNewEntriesCoexistAfterReload_VAL_CROSS_008() throws {
        let (history, tmpURL) = try makeTempHistory()
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        let hnURL = "https://news.ycombinator.com/"
        history.record(
            originalURL: URL(string: hnURL)!,
            result: makeResult(for: hnURL),
            outcome: .opened,
            targetBundleID: "com.brave.Browser",
            sourceBundleID: "com.tinyspeck.slackmacgap"
        )
        drainMain()
        let writeExp = expectation(description: "persist queue drain")
        history.persistQueue.async { writeExp.fulfill() }
        wait(for: [writeExp], timeout: 2)

        let history2 = RoutingHistory(fileURL: tmpURL)
        XCTAssertEqual(history2.entries.count, 3)

        let legacyEntry = history2.entries.first(where: { $0.cleanedURL == "https://github.com/" })
        XCTAssertNotNil(legacyEntry)
        XCTAssertNil(legacyEntry?.sourceBundleID)

        let newEntry = history2.entries.first(where: { $0.cleanedURL == hnURL })
        XCTAssertNotNil(newEntry)
        XCTAssertEqual(newEntry?.sourceBundleID, "com.tinyspeck.slackmacgap")
    }
}
