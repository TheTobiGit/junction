import XCTest
@testable import JunctionApp

final class IDNATests: XCTestCase {
    func test_decodesSimplePunycode() {
        // münchen.de
        XCTAssertEqual(IDNA.toUnicode(host: "xn--mnchen-3ya.de"), "münchen.de")
    }

    func test_decodesCyrillic() {
        // россия.рф
        XCTAssertEqual(IDNA.toUnicode(host: "xn--h1alffa9f.xn--p1ai"), "россия.рф")
    }

    func test_passthroughForAsciiHost() {
        XCTAssertEqual(IDNA.toUnicode(host: "example.com"), "example.com")
        XCTAssertEqual(IDNA.toUnicode(host: "sub.example.co.uk"), "sub.example.co.uk")
    }

    func test_keepsLabelOnDecodeFailure() {
        // Garbage payload after xn-- shouldn't crash; falls back to raw label.
        let host = "xn--!!!.example.com"
        let out = IDNA.toUnicode(host: host)
        XCTAssertTrue(out.hasSuffix(".example.com"))
    }

    func test_isCaseInsensitive() {
        XCTAssertEqual(IDNA.toUnicode(host: "XN--MNCHEN-3YA.DE"), "münchen.de")
    }
}

final class HostMatchIDNAFoldingTests: XCTestCase {
    func test_equalsMatchesAcrossPunycodeAndUnicode() {
        XCTAssertTrue(HostMatch.equals("münchen.de").matches("xn--mnchen-3ya.de"))
        XCTAssertTrue(HostMatch.equals("xn--mnchen-3ya.de").matches("münchen.de"))
    }

    func test_suffixMatchesAcrossPunycodeAndUnicode() {
        XCTAssertTrue(HostMatch.suffix("münchen.de").matches("shop.xn--mnchen-3ya.de"))
        XCTAssertTrue(HostMatch.suffix("xn--mnchen-3ya.de").matches("shop.münchen.de"))
    }
}
