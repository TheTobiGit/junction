import XCTest
@testable import JunctionApp

final class RegressionFixesTests: XCTestCase {
    // MARK: - URLSafety trailing-dot normalization

    func test_urlSafety_trailingDotLocalhostIsRejected() {
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("localhost."))
    }

    func test_urlSafety_trailingDotLocalSuffixIsRejected() {
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("foo.local."))
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("router.lan."))
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("anything.test."))
    }

    func test_urlSafety_trailingDotPrivateIPIsRejected() {
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("10.0.0.1."))
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("127.0.0.1."))
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("169.254.169.254."))
    }

    func test_urlSafety_trailingDotPublicIsAccepted() {
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("example.com."))
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("8.8.8.8."))
    }

    // MARK: - TrackerStripper no longer drops single-letter `s`/`t`

    func test_trackerStripper_keepsWordPressSearchParam() {
        let stripper = TrackerStripper()
        let url = URL(string: "https://blog.example.com/?s=swift+url&utm_source=email")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNotNil(q.first { $0.name == "s" })
        XCTAssertEqual(q.first { $0.name == "s" }?.value, "swift+url")
        XCTAssertNil(q.first { $0.name == "utm_source" })
    }

    func test_trackerStripper_keepsTOnArbitraryHost() {
        let stripper = TrackerStripper()
        let url = URL(string: "https://video.example.com/watch?v=abc&t=42")!
        let cleaned = stripper.transform(url)
        let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(q.first { $0.name == "t" }?.value, "42")
    }

    func test_trackerStripper_stripsSAndTOnTwitter() {
        let stripper = TrackerStripper()
        for host in ["twitter.com", "x.com", "www.twitter.com", "mobile.x.com"] {
            let url = URL(string: "https://\(host)/user/status/1?s=20&t=abc&keep=1")!
            let cleaned = stripper.transform(url)
            let q = URLComponents(url: cleaned, resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertNil(q.first { $0.name == "s" }, "expected s stripped on \(host)")
            XCTAssertNil(q.first { $0.name == "t" }, "expected t stripped on \(host)")
            XCTAssertEqual(q.first { $0.name == "keep" }?.value, "1")
        }
    }

    // MARK: - Unquoted attribute values can contain slashes

    func test_metaParser_unquotedRootRelativeHref() {
        let attrs = LinkPreviewFetcher.parseTagAttributes("<link rel=icon href=/favicon.ico>")
        XCTAssertEqual(attrs["rel"], "icon")
        XCTAssertEqual(attrs["href"], "/favicon.ico")
    }

    func test_metaParser_unquotedAbsoluteUrl() {
        let attrs = LinkPreviewFetcher.parseTagAttributes("<link rel=icon href=https://cdn.example.com/icon.png>")
        XCTAssertEqual(attrs["href"], "https://cdn.example.com/icon.png")
    }

    func test_metaParser_handlesSelfClosingMarker() {
        let attrs = LinkPreviewFetcher.parseTagAttributes("<meta name=description content=hello/>")
        XCTAssertEqual(attrs["name"], "description")
        XCTAssertEqual(attrs["content"], "hello")
    }

    func test_metaParser_unquotedMetaContentWithSlashes() {
        let html = "<meta name=description content=https://example.com/article>"
        XCTAssertEqual(
            LinkPreviewFetcher.metaContent(html: html, attribute: "name", value: "description"),
            "https://example.com/article"
        )
    }

    func test_appDelegate_acceptsFileScheme() {
        let delegate = AppDelegate()
        XCTAssertTrue(delegate.isAcceptableScheme(URL(string: "file:///Users/z/test.html")!))
        XCTAssertTrue(delegate.isAcceptableScheme(URL(string: "http://example.com")!))
        XCTAssertTrue(delegate.isAcceptableScheme(URL(string: "https://example.com")!))
        XCTAssertFalse(delegate.isAcceptableScheme(URL(string: "javascript:alert(1)")!))
        XCTAssertFalse(delegate.isAcceptableScheme(URL(string: "data:text/html,evil")!))
    }
}
