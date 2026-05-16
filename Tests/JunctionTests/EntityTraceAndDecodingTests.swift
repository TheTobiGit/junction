import XCTest
@testable import JunctionApp

final class HTMLEntityDecoderExpansionTests: XCTestCase {
    func test_smartQuotesAndDashes() {
        XCTAssertEqual(HTMLEntityDecoder.decode("&ldquo;Hi&rdquo; &mdash; she said&hellip;"),
                       "“Hi” — she said…")
    }

    func test_typographicSymbols() {
        XCTAssertEqual(HTMLEntityDecoder.decode("&copy; 2026 &reg; &trade;"), "© 2026 ® ™")
    }

    func test_currencies() {
        XCTAssertEqual(HTMLEntityDecoder.decode("&euro;5 &pound;3 &yen;100 &cent;25"), "€5 £3 ¥100 ¢25")
    }

    func test_accentedLetters() {
        XCTAssertEqual(HTMLEntityDecoder.decode("Caf&eacute; &ouml;ber &ntilde;ez"), "Café öber ñez")
    }

    func test_uppercaseNamedEntityFallback() {
        XCTAssertEqual(HTMLEntityDecoder.decode("AT&AMP;T"), "AT&T")
    }
}

final class URLTransformTraceTests: XCTestCase {
    func test_traceRecordsEachStageThatChangedURL() {
        let pipeline = URLTransformPipeline(transformers: [
            OutgoingRedirectUnwrapper(),
            AMPCollapser(),
            TrackerStripper(),
        ])
        let url = URL(string: "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%2Farticle%2Famp%3Futm_source%3Demail")!
        let result = pipeline.runTraced(url)

        let ids = result.steps.map(\.identifier)
        XCTAssertEqual(ids, ["outgoing-redirect-unwrapper", "amp-collapser", "tracker-stripper"])
        XCTAssertEqual(result.final.host, "example.com")
        XCTAssertEqual(result.final.path, "/article")
        let q = URLComponents(url: result.final, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertNil(q.first { $0.name == "utm_source" })
        XCTAssertTrue(result.didChange)
    }

    func test_traceIsEmptyWhenNothingChanges() {
        let pipeline = URLTransformPipeline(transformers: [TrackerStripper()])
        let url = URL(string: "https://example.com/clean?keep=1")!
        let result = pipeline.runTraced(url)
        XCTAssertEqual(result.steps.count, 0)
        XCTAssertFalse(result.didChange)
        XCTAssertEqual(result.final, url)
    }
}

final class LinkPreviewFetcherDecodingTests: XCTestCase {
    func test_isHTMLLikeContentType_acceptsHtmlAndXhtml() {
        XCTAssertTrue(LinkPreviewFetcher.isHTMLLikeContentType("text/html; charset=utf-8"))
        XCTAssertTrue(LinkPreviewFetcher.isHTMLLikeContentType("application/xhtml+xml"))
        XCTAssertTrue(LinkPreviewFetcher.isHTMLLikeContentType(nil))
    }

    func test_isHTMLLikeContentType_rejectsBinary() {
        XCTAssertFalse(LinkPreviewFetcher.isHTMLLikeContentType("application/pdf"))
        XCTAssertFalse(LinkPreviewFetcher.isHTMLLikeContentType("image/png"))
        XCTAssertFalse(LinkPreviewFetcher.isHTMLLikeContentType("video/mp4"))
        XCTAssertFalse(LinkPreviewFetcher.isHTMLLikeContentType("application/octet-stream"))
    }

    func test_decodeHTML_usesContentTypeCharset() {
        // ISO-8859-1 byte for é is 0xE9.
        let bytes = Data([0x43, 0x61, 0x66, 0xE9]) // "Café" in latin-1
        let decoded = LinkPreviewFetcher.decodeHTML(bytes[bytes.startIndex..<bytes.endIndex],
                                                    contentType: "text/html; charset=iso-8859-1")
        XCTAssertEqual(decoded, "Café")
    }

    func test_decodeHTML_fallsBackToUtf8() {
        let bytes = "Café".data(using: .utf8)!
        let decoded = LinkPreviewFetcher.decodeHTML(bytes[bytes.startIndex..<bytes.endIndex],
                                                    contentType: nil)
        XCTAssertEqual(decoded, "Café")
    }
}
