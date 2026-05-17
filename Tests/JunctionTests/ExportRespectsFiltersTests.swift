import XCTest
@testable import JunctionApp

final class ExportRespectsFiltersTests: XCTestCase {

    private func makeEntry(
        cleanedURL: String,
        sourceBundleID: String? = nil,
        targetBundleID: String? = nil,
        targetStorageKey: String? = nil
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            originalURL: cleanedURL,
            cleanedURL: cleanedURL,
            outcome: .opened,
            targetBundleID: targetBundleID,
            ruleLabel: nil,
            cleaningSteps: [],
            sourceBundleID: sourceBundleID,
            targetStorageKey: targetStorageKey
        )
    }

    // VAL-CROSS-012: Filter sourceBundleID=Slack → JSON emits exactly one record with sourceBundleID and targetStorageKey
    func test_jsonExportRespectsSourceBundleIDFilter_VAL_CROSS_012() throws {
        let slack = "com.tinyspeck.slackmacgap"
        let brave = "com.brave.Browser"
        let storageKey = "app:com.brave.Browser"

        let allEntries: [RoutingHistory.Entry] = [
            makeEntry(cleanedURL: "https://github.com/a", sourceBundleID: slack, targetBundleID: brave, targetStorageKey: storageKey),
            makeEntry(cleanedURL: "https://github.com/b", sourceBundleID: "com.apple.Mail", targetBundleID: "com.google.Chrome"),
            makeEntry(cleanedURL: "https://github.com/c", sourceBundleID: nil, targetBundleID: "com.apple.Safari"),
        ]

        let filtered = ActivityFilter.filter(allEntries, criteria: .init(sourceBundleID: slack))
        XCTAssertEqual(filtered.count, 1)

        let data = ActivityExporter.json(entries: filtered)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([RoutingHistory.Entry].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].sourceBundleID, slack)
        XCTAssertEqual(decoded[0].targetStorageKey, storageKey)
    }

    // VAL-CROSS-012: Filter sourceBundleID=Slack → CSV emits header + one data row with new columns
    func test_csvExportRespectsSourceBundleIDFilter_VAL_CROSS_012() {
        let slack = "com.tinyspeck.slackmacgap"
        let brave = "com.brave.Browser"
        let storageKey = "app:com.brave.Browser"

        let allEntries: [RoutingHistory.Entry] = [
            makeEntry(cleanedURL: "https://github.com/a", sourceBundleID: slack, targetBundleID: brave, targetStorageKey: storageKey),
            makeEntry(cleanedURL: "https://github.com/b", sourceBundleID: "com.apple.Mail", targetBundleID: "com.google.Chrome"),
            makeEntry(cleanedURL: "https://github.com/c", sourceBundleID: nil, targetBundleID: "com.apple.Safari"),
        ]

        let filtered = ActivityFilter.filter(allEntries, criteria: .init(sourceBundleID: slack))
        let csv = ActivityExporter.csv(entries: filtered)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }

        XCTAssertEqual(lines.count, 2, "Expected header + 1 data row")
        XCTAssertTrue(lines[0].contains("sourceBundleID"))
        XCTAssertTrue(lines[0].contains("targetStorageKey"))
        XCTAssertTrue(lines[1].contains(slack))
        XCTAssertTrue(lines[1].contains(storageKey))
    }

    // VAL-CROSS-012: Cleared filters re-exports all three entries
    func test_clearedFiltersExportsAllEntries_VAL_CROSS_012() throws {
        let allEntries: [RoutingHistory.Entry] = [
            makeEntry(cleanedURL: "https://github.com/a", sourceBundleID: "com.tinyspeck.slackmacgap"),
            makeEntry(cleanedURL: "https://github.com/b", sourceBundleID: "com.apple.Mail"),
            makeEntry(cleanedURL: "https://github.com/c", sourceBundleID: nil),
        ]

        let filtered = ActivityFilter.filter(allEntries, criteria: .init())
        XCTAssertEqual(filtered.count, 3)

        let data = ActivityExporter.json(entries: filtered)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([RoutingHistory.Entry].self, from: data)
        XCTAssertEqual(decoded.count, 3)

        let csv = ActivityExporter.csv(entries: filtered)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 4, "Expected header + 3 data rows")
    }

    // VAL-CROSS-012: Export uses filteredEntries not unfiltered history
    func test_exportUsesFilteredNotUnfilteredEntries_VAL_CROSS_012() throws {
        let slack = "com.tinyspeck.slackmacgap"
        let allEntries: [RoutingHistory.Entry] = [
            makeEntry(cleanedURL: "https://github.com/a", sourceBundleID: slack),
            makeEntry(cleanedURL: "https://github.com/b", sourceBundleID: "com.apple.Mail"),
        ]

        let filtered = ActivityFilter.filter(allEntries, criteria: .init(sourceBundleID: slack))
        let data = ActivityExporter.json(entries: filtered)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([RoutingHistory.Entry].self, from: data)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertNotEqual(decoded.count, allEntries.count, "Export must not include unfiltered entries")
    }
}
