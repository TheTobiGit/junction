import XCTest
@testable import JunctionApp

final class ActivityExporterTests: XCTestCase {

    private func makeEntry(
        cleanedURL: String = "https://github.com/orgs/acme",
        originalURL: String? = nil,
        outcome: RoutingHistory.Outcome = .opened,
        targetBundleID: String? = "com.google.Chrome",
        ruleLabel: String? = nil,
        cleaningSteps: [String] = [],
        sourceBundleID: String? = nil,
        targetStorageKey: String? = nil
    ) -> RoutingHistory.Entry {
        RoutingHistory.Entry(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            originalURL: originalURL ?? cleanedURL,
            cleanedURL: cleanedURL,
            outcome: outcome,
            targetBundleID: targetBundleID,
            ruleLabel: ruleLabel,
            cleaningSteps: cleaningSteps,
            sourceBundleID: sourceBundleID,
            targetStorageKey: targetStorageKey
        )
    }

    // VAL-M5-EXPORT-001: JSON export round-trips through JSONDecoder
    func test_jsonExportRoundTrips_VAL_M5_EXPORT_001() throws {
        let entry = makeEntry(
            cleanedURL: "https://github.com/orgs/acme",
            originalURL: "https://github.com/orgs/acme?utm_source=email",
            targetBundleID: "com.google.Chrome",
            cleaningSteps: ["tracker-stripper"],
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "profile:com.google.Chrome:Default"
        )
        let data = ActivityExporter.json(entries: [entry])
        XCTAssertFalse(data.isEmpty)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode([RoutingHistory.Entry].self, from: data)
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].id, entry.id)
        XCTAssertEqual(decoded[0].cleanedURL, entry.cleanedURL)
        XCTAssertEqual(decoded[0].originalURL, entry.originalURL)
        XCTAssertEqual(decoded[0].outcome, entry.outcome)
        XCTAssertEqual(decoded[0].targetBundleID, entry.targetBundleID)
        XCTAssertEqual(decoded[0].cleaningSteps, entry.cleaningSteps)
        XCTAssertEqual(decoded[0].sourceBundleID, entry.sourceBundleID)
        XCTAssertEqual(decoded[0].targetStorageKey, entry.targetStorageKey)
    }

    // VAL-M5-EXPORT-001: JSON output is valid UTF-8 and parses as array
    func test_jsonOutputIsUTF8Array_VAL_M5_EXPORT_001() throws {
        let entries = [makeEntry(), makeEntry(cleanedURL: "https://example.com/")]
        let data = ActivityExporter.json(entries: entries)
        let str = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(str.hasPrefix("["))
        XCTAssertTrue(str.hasSuffix("]") || str.hasSuffix("]\n"))
    }

    // VAL-M5-EXPORT-002: CSV export has a stable header row
    func test_csvExportHasStableHeaderRow_VAL_M5_EXPORT_002() {
        let entry = makeEntry()
        let csv = ActivityExporter.csv(entries: [entry])
        let firstLine = csv.components(separatedBy: "\r\n").first ?? ""
        XCTAssertEqual(firstLine, "id,timestamp,originalURL,cleanedURL,outcome,targetBundleID,ruleLabel,cleaningSteps,sourceBundleID,targetStorageKey")
    }

    // VAL-M5-EXPORT-002: CSV header includes sourceBundleID and targetStorageKey columns
    func test_csvHeaderIncludesNewFields_VAL_M5_EXPORT_002() {
        let csv = ActivityExporter.csv(entries: [makeEntry()])
        let header = csv.components(separatedBy: "\r\n").first ?? ""
        XCTAssertTrue(header.contains("sourceBundleID"))
        XCTAssertTrue(header.contains("targetStorageKey"))
    }

    // VAL-M5-EXPORT-002: RFC 4180 — field with comma is wrapped in double quotes
    func test_csvRFC4180EscapesComma_VAL_M5_EXPORT_002() {
        let entry = makeEntry(ruleLabel: "host,with,commas")
        let csv = ActivityExporter.csv(entries: [entry])
        XCTAssertTrue(csv.contains("\"host,with,commas\""))
    }

    // VAL-M5-EXPORT-002: RFC 4180 — field with double quote has embedded quotes doubled
    func test_csvRFC4180EscapesDoubleQuote_VAL_M5_EXPORT_002() {
        let entry = makeEntry(ruleLabel: "say \"hello\"")
        let csv = ActivityExporter.csv(entries: [entry])
        XCTAssertTrue(csv.contains("\"say \"\"hello\"\"\""))
    }

    // VAL-M5-EXPORT-002: RFC 4180 — field with newline is wrapped in double quotes
    func test_csvRFC4180EscapesNewline_VAL_M5_EXPORT_002() {
        let entry = makeEntry(ruleLabel: "line1\nline2")
        let csv = ActivityExporter.csv(entries: [entry])
        XCTAssertTrue(csv.contains("\"line1\nline2\""))
    }

    // VAL-M5-EXPORT-002: multi-value cleaningSteps joined with semicolon and quoted per RFC 4180
    func test_csvCleaningStepsJoinedWithSemicolon_VAL_M5_EXPORT_002() {
        let entry = makeEntry(cleaningSteps: ["tracker-stripper", "amp-collapser"])
        let csv = ActivityExporter.csv(entries: [entry])
        XCTAssertTrue(csv.contains("\"tracker-stripper;amp-collapser\""))
    }

    // VAL-M5-EXPORT-002: multi-value cleaningSteps cell is quoted (redirect-transformer + tracker-stripper fixture)
    func test_csvMultiValueCleaningStepsIsQuoted_VAL_M5_EXPORT_002() {
        let entry = makeEntry(cleaningSteps: ["redirect-transformer", "tracker-stripper"])
        let csv = ActivityExporter.csv(entries: [entry])
        XCTAssertTrue(csv.contains("\"redirect-transformer;tracker-stripper\""))
    }

    // VAL-M5-EXPORT-003: empty filtered set — JSON is `[]` and CSV is header-only
    func test_emptyFilteredSetExportsCorrectly_VAL_M5_EXPORT_003() throws {
        let allEntries: [RoutingHistory.Entry] = [
            makeEntry(cleanedURL: "https://github.com/a", targetBundleID: "com.brave.Browser"),
            makeEntry(cleanedURL: "https://example.com/b", targetBundleID: "com.apple.Safari"),
        ]
        let filtered = ActivityFilter.filter(allEntries, criteria: .init(targetBundleID: "com.google.Chrome"))
        XCTAssertTrue(filtered.isEmpty)

        let jsonData = ActivityExporter.json(entries: filtered)
        let jsonStr = try XCTUnwrap(String(data: jsonData, encoding: .utf8))
        XCTAssertEqual(jsonStr.trimmingCharacters(in: .whitespacesAndNewlines), "[]")

        let csv = ActivityExporter.csv(entries: filtered)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("id,"))
    }

    // VAL-M5-EXPORT-002: sourceBundleID and targetStorageKey appear in data rows
    func test_csvDataRowIncludesNewFields_VAL_M5_EXPORT_002() {
        let entry = makeEntry(
            sourceBundleID: "com.tinyspeck.slackmacgap",
            targetStorageKey: "profile:com.google.Chrome:Default"
        )
        let csv = ActivityExporter.csv(entries: [entry])
        XCTAssertTrue(csv.contains("com.tinyspeck.slackmacgap"))
        XCTAssertTrue(csv.contains("profile:com.google.Chrome:Default"))
    }

    // VAL-M5-EXPORT-003: empty entries — JSON is `[]`
    func test_emptyEntriesJSONIsEmptyArray_VAL_M5_EXPORT_003() throws {
        let data = ActivityExporter.json(entries: [])
        let str = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertEqual(str.trimmingCharacters(in: .whitespacesAndNewlines), "[]")
    }

    // VAL-M5-EXPORT-003: empty entries — CSV is header row only
    func test_emptyEntriesCSVIsHeaderOnly_VAL_M5_EXPORT_003() {
        let csv = ActivityExporter.csv(entries: [])
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].hasPrefix("id,"))
    }

    // VAL-M5-EXPORT-003: empty entries — CSV has no trailing CRLF data rows
    func test_emptyEntriesCSVHasNoDataRows_VAL_M5_EXPORT_003() {
        let csv = ActivityExporter.csv(entries: [])
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertEqual(lines.filter { !$0.isEmpty }.count, 1)
    }
}
