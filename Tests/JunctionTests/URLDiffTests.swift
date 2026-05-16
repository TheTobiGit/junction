import XCTest
@testable import JunctionApp

final class URLDiffTests: XCTestCase {
    func test_returnsEmptyWhenNothingChanged() {
        let url = URL(string: "https://example.com/?a=1&b=2")!
        XCTAssertEqual(URLDiff.strippedQueryParams(from: url, to: url), [])
    }

    func test_returnsEmptyWhenOriginalHasNoQuery() {
        let original = URL(string: "https://example.com/path")!
        let cleaned = URL(string: "https://example.com/path")!
        XCTAssertEqual(URLDiff.strippedQueryParams(from: original, to: cleaned), [])
    }

    func test_returnsRemovedNamesInOriginalOrder() {
        let original = URL(string: "https://example.com/?utm_source=email&keep=1&fbclid=xyz&utm_campaign=q1")!
        let cleaned = URL(string: "https://example.com/?keep=1")!
        XCTAssertEqual(
            URLDiff.strippedQueryParams(from: original, to: cleaned),
            ["utm_source", "fbclid", "utm_campaign"]
        )
    }

    func test_deduplicatesMultipleOccurrencesOfSameParam() {
        let original = URL(string: "https://example.com/?ref=a&ref=b&keep=1")!
        let cleaned = URL(string: "https://example.com/?keep=1")!
        XCTAssertEqual(URLDiff.strippedQueryParams(from: original, to: cleaned), ["ref"])
    }

    func test_handlesAllParamsRemoved() {
        let original = URL(string: "https://example.com/?utm_source=x&fbclid=y")!
        let cleaned = URL(string: "https://example.com/")!
        XCTAssertEqual(URLDiff.strippedQueryParams(from: original, to: cleaned), ["utm_source", "fbclid"])
    }

    func test_doesNotReportRetainedNames() {
        let original = URL(string: "https://example.com/?a=1&b=2")!
        let cleaned = URL(string: "https://example.com/?a=1&b=2")!
        XCTAssertTrue(URLDiff.strippedQueryParams(from: original, to: cleaned).isEmpty)
    }

    // MARK: - strippedTrackerParams(in:)

    func test_strippedTrackerParams_returnsOnlyTrackerStripperRemovals() {
        let trace = URLTransformers.default.runTraced(
            URL(string: "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Fa%3Futm_source%3Demail%26x%3D1&h=AT0xyz")!
        )
        let stripped = URLDiff.strippedTrackerParams(in: trace)
        // The wrapper's `u`/`h` were undone by the unwrap stage, NOT removed
        // as trackers — they should not appear here. Only `utm_source` should.
        XCTAssertEqual(stripped, ["utm_source"])
    }

    func test_strippedTrackerParams_emptyWhenStageDidNotFire() {
        let trace = URLTransformers.default.runTraced(URL(string: "https://example.com/path")!)
        XCTAssertEqual(URLDiff.strippedTrackerParams(in: trace), [])
    }
}
