import XCTest
@testable import JunctionApp

final class PreviewCacheKeyNormalizationTests: XCTestCase {
    func test_lowercasesHost() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://Example.COM/path")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/path")!)
        XCTAssertEqual(a, b)
    }

    func test_dropsDefaultPort() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://example.com:443/x")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/x")!)
        XCTAssertEqual(a, b)

        let c = PreviewCache.previewCacheKey(for: URL(string: "http://example.com:80/x")!)
        let d = PreviewCache.previewCacheKey(for: URL(string: "http://example.com/x")!)
        XCTAssertEqual(c, d)
    }

    func test_keepsNonStandardPort() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://example.com:8443/x")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/x")!)
        XCTAssertNotEqual(a, b)
    }

    func test_dropsFragment() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/x#section")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/x")!)
        XCTAssertEqual(a, b)
    }

    func test_collapsesTrailingSlash() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/x/")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/x")!)
        XCTAssertEqual(a, b)
    }

    func test_keepsRootSlash() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com")!)
        XCTAssertEqual(a, b)
    }

    func test_keepsQueryDifferences() {
        let a = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/search?q=1")!)
        let b = PreviewCache.previewCacheKey(for: URL(string: "https://example.com/search?q=2")!)
        XCTAssertNotEqual(a, b)
    }
}

final class ShortenerExpanderListTests: XCTestCase {
    func test_isShortened_includesNewHosts() {
        XCTAssertTrue(ShortenerExpander.isShortened(URL(string: "https://fb.me/abc")!))
        XCTAssertTrue(ShortenerExpander.isShortened(URL(string: "https://spoti.fi/track/x")!))
        XCTAssertTrue(ShortenerExpander.isShortened(URL(string: "https://apple.co/3xyz")!))
        XCTAssertTrue(ShortenerExpander.isShortened(URL(string: "https://bit.do/short")!))
        XCTAssertTrue(ShortenerExpander.isShortened(URL(string: "https://www.t.co/x")!))
    }

    func test_isShortened_rejectsNonShorteners() {
        XCTAssertFalse(ShortenerExpander.isShortened(URL(string: "https://example.com")!))
        XCTAssertFalse(ShortenerExpander.isShortened(URL(string: "https://github.com/owner/repo")!))
    }
}
