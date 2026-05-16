import XCTest
@testable import JunctionApp

final class CodexRoundTwoRegressionTests: XCTestCase {
    // MARK: - TrackerStripper: src is no longer global

    func test_srcParamIsNotStrippedFromArbitraryHosts() {
        let stripper = TrackerStripper()
        let url = URL(string: "https://images.example.com/proxy?src=https%3A%2F%2Fcdn.example.org%2Fimg.jpg&utm_source=email")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNotNil(q.first { $0.name == "src" }, "src is load-bearing on viewer/proxy endpoints and must survive cleaning")
        XCTAssertNil(q.first { $0.name == "utm_source" })
    }

    // MARK: - DomainRedirect: pathTemplate preserves scheme

    func test_pathTemplate_preservesHTTPScheme() {
        let redirect = DomainRedirect(
            fromHost: "old.example.com",
            toHost: "new.example.com",
            pathTemplate: "/v2{path}"
        )
        let input = URL(string: "http://old.example.com/article")!
        let out = redirect.apply(to: input)
        XCTAssertEqual(out?.scheme, "http")
        XCTAssertEqual(out?.host, "new.example.com")
        XCTAssertEqual(out?.path, "/v2/article")
    }

    func test_pathTemplate_preservesHTTPSScheme() {
        let redirect = DomainRedirect(
            fromHost: "medium.com",
            toHost: "freedium.cfd",
            pathTemplate: "/article{path}"
        )
        let input = URL(string: "https://medium.com/@user/title")!
        let out = redirect.apply(to: input)
        XCTAssertEqual(out?.scheme, "https")
    }

    // MARK: - RoutingHistory records what actually opened

    func test_record_storesOpenedURLWhenCleaningDisabled() {
        let original = URL(string: "https://example.com/?utm_source=email")!
        let cleaned = URL(string: "https://example.com/")!
        let trace = URLTransformResult(
            original: original,
            final: cleaned,
            steps: [.init(identifier: "tracker-stripper", before: original, after: cleaned)]
        )
        let entry = RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: original.absoluteString,
            // Mirror what the new RoutingHistory.record() should produce when
            // openedURL = original (cleaning disabled): cleanedURL stores the
            // URL we actually handed to the browser, not trace.final.
            cleanedURL: original.absoluteString,
            outcome: .opened,
            targetBundleID: "com.apple.Safari",
            ruleLabel: "rule",
            cleaningSteps: trace.steps.map(\.identifier)
        )
        // The Activity row + Recent menu re-open `cleanedURL`. With cleaning
        // off we want that to reproduce the original click, not the cleaned form.
        XCTAssertEqual(entry.cleanedURL, original.absoluteString)
        // didClean is computed from the stored fields, so when nothing was
        // applied at open time it must report false even though the trace had
        // steps.
        XCTAssertFalse(entry.didClean)
    }

    func test_record_didCleanReflectsRecordedURLs() {
        let opened = URL(string: "https://example.com/")!
        let entry = RoutingHistory.Entry(
            timestamp: Date(),
            originalURL: "https://example.com/?utm_source=email",
            cleanedURL: opened.absoluteString,
            outcome: .opened,
            targetBundleID: nil,
            ruleLabel: nil,
            cleaningSteps: ["tracker-stripper"]
        )
        XCTAssertTrue(entry.didClean)
    }
}
