import XCTest
@testable import JunctionApp

final class HTMLEntityDecoderTests: XCTestCase {
    func test_namedEntities() {
        XCTAssertEqual(HTMLEntityDecoder.decode("Tom &amp; Jerry"), "Tom & Jerry")
        XCTAssertEqual(HTMLEntityDecoder.decode("&lt;tag&gt;"), "<tag>")
        XCTAssertEqual(HTMLEntityDecoder.decode("&quot;x&quot;"), "\"x\"")
        XCTAssertEqual(HTMLEntityDecoder.decode("&apos;x&apos;"), "'x'")
    }

    func test_numericEntities() {
        XCTAssertEqual(HTMLEntityDecoder.decode("it&#39;s"), "it's")
        XCTAssertEqual(HTMLEntityDecoder.decode("&#x2014;"), "\u{2014}")
        XCTAssertEqual(HTMLEntityDecoder.decode("&#8212;"), "\u{2014}") // em dash decimal
    }

    func test_nbsp() {
        XCTAssertEqual(HTMLEntityDecoder.decode("a&nbsp;b"), "a\u{00A0}b")
    }

    func test_unknownEntityLeftIntact() {
        XCTAssertEqual(HTMLEntityDecoder.decode("foo &unknown; bar"), "foo &unknown; bar")
    }
}
