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
}
