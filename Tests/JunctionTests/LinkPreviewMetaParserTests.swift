import XCTest
@testable import JunctionApp

final class LinkPreviewMetaParserTests: XCTestCase {
    func test_parsesQuotedAttributes() {
        let attrs = LinkPreviewFetcher.parseTagAttributes(#"<meta property="og:title" content="Hello, World!">"#)
        XCTAssertEqual(attrs["property"], "og:title")
        XCTAssertEqual(attrs["content"], "Hello, World!")
    }

    func test_parsesSingleQuotedAttributes() {
        let attrs = LinkPreviewFetcher.parseTagAttributes("<meta name='description' content='Foo bar baz'>")
        XCTAssertEqual(attrs["name"], "description")
        XCTAssertEqual(attrs["content"], "Foo bar baz")
    }

    func test_parsesUnquotedAttributes() {
        let attrs = LinkPreviewFetcher.parseTagAttributes("<meta name=description content=hello>")
        XCTAssertEqual(attrs["name"], "description")
        XCTAssertEqual(attrs["content"], "hello")
    }

    func test_caseInsensitiveAttributeNames() {
        let attrs = LinkPreviewFetcher.parseTagAttributes(#"<META Property="og:title" Content="Hi">"#)
        XCTAssertEqual(attrs["property"], "og:title")
        XCTAssertEqual(attrs["content"], "Hi")
    }

    func test_decodesHTMLEntitiesInValues() {
        let attrs = LinkPreviewFetcher.parseTagAttributes(#"<meta property="og:title" content="Tom &amp; Jerry &mdash; the show">"#)
        XCTAssertEqual(attrs["content"], "Tom & Jerry — the show")
    }

    func test_metaContentHandlesAttributeOrderEither() {
        let html1 = #"<meta property="og:title" content="Title One">"#
        let html2 = #"<meta content="Title Two" property="og:title">"#
        XCTAssertEqual(LinkPreviewFetcher.metaContent(html: html1, attribute: "property", value: "og:title"), "Title One")
        XCTAssertEqual(LinkPreviewFetcher.metaContent(html: html2, attribute: "property", value: "og:title"), "Title Two")
    }

    func test_metaContentLooksAtName() {
        let html = #"<meta name="twitter:title" content="Cards Title">"#
        XCTAssertEqual(LinkPreviewFetcher.metaContent(html: html, attribute: "name", value: "twitter:title"), "Cards Title")
    }

    func test_metaContentHandlesUnquotedAttributes() {
        let html = "<meta name=description content=Hello>"
        XCTAssertEqual(LinkPreviewFetcher.metaContent(html: html, attribute: "name", value: "description"), "Hello")
    }

    func test_metaContentReturnsNilWhenAbsent() {
        let html = #"<meta property="og:title" content="x"><meta name="foo" content="bar">"#
        XCTAssertNil(LinkPreviewFetcher.metaContent(html: html, attribute: "property", value: "og:description"))
    }

    func test_metaContentSkipsMatchingAttributesWithoutContent() {
        let html = #"<meta name="og:title"><meta property="og:title" content="ok">"#
        XCTAssertEqual(LinkPreviewFetcher.metaContent(html: html, attribute: "property", value: "og:title"), "ok")
    }
}
