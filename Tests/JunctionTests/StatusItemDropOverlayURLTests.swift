import XCTest
@testable import JunctionApp

final class StatusItemDropOverlayURLTests: XCTestCase {
    func test_acceptsHTTPURL() {
        let url = URL(string: "https://example.com/path")!
        let result = StatusItemDropOverlay.extractURL(from: [url], text: nil)
        XCTAssertEqual(result, url)
    }

    func test_rejectsNonHTTPURL() {
        let url = URL(string: "ftp://example.com/x")!
        XCTAssertNil(StatusItemDropOverlay.extractURL(from: [url], text: nil))
    }

    func test_resolvesBookmarkFileURL() {
        let bookmark = URL(string: "file:///tmp/Bookmark.webloc")!
        let result = StatusItemDropOverlay.extractURL(
            from: [bookmark],
            text: nil,
            bookmarkResolver: { url in
                XCTAssertEqual(url, bookmark)
                return URL(string: "https://example.org/page")
            }
        )
        XCTAssertEqual(result?.host, "example.org")
    }

    func test_skipsBookmarkResolverForNonFileURL() {
        let url = URL(string: "https://a.com")!
        var calls = 0
        let result = StatusItemDropOverlay.extractURL(
            from: [url],
            text: nil,
            bookmarkResolver: { _ in calls += 1; return nil }
        )
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(result, url)
    }

    func test_pulledFromPlainText() {
        let result = StatusItemDropOverlay.extractURL(
            from: [],
            text: "https://example.com/x"
        )
        XCTAssertEqual(result?.host, "example.com")
    }

    func test_addsHTTPSToBareDomain() {
        let result = StatusItemDropOverlay.extractURL(from: [], text: "github.com/owner/repo")
        XCTAssertEqual(result?.scheme, "https")
        XCTAssertEqual(result?.host, "github.com")
    }

    func test_rejectsTextWithSpaces() {
        XCTAssertNil(StatusItemDropOverlay.extractURL(from: [], text: "see this site"))
    }

    func test_rejectsTextWithoutDot() {
        XCTAssertNil(StatusItemDropOverlay.extractURL(from: [], text: "githubcom"))
    }

    func test_returnsNilForEmptyInput() {
        XCTAssertNil(StatusItemDropOverlay.extractURL(from: [], text: nil))
        XCTAssertNil(StatusItemDropOverlay.extractURL(from: [], text: ""))
    }

    func test_preferUrlOverPlainText() {
        let result = StatusItemDropOverlay.extractURL(
            from: [URL(string: "https://from-url.com/a")!],
            text: "https://from-text.com/b"
        )
        XCTAssertEqual(result?.host, "from-url.com")
    }
}
