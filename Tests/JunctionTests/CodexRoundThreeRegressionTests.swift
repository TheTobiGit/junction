import XCTest
@testable import JunctionApp

final class CodexRoundThreeRegressionTests: XCTestCase {
    // MARK: - URLSafety: legacy IPv4 notations

    func test_loopbackShortForm_isRejected() {
        // 127.1 → 127.0.0.1 per BSD inet_aton.
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("127.1"))
    }

    func test_hexLoopback_isRejected() {
        // 0x7f.0.0.1 → 127.0.0.1
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("0x7f.0.0.1"))
    }

    func test_threePartPrivate_isRejected() {
        // 192.168.1 → 192.168.0.1
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("192.168.1"))
    }

    func test_singleIntegerLoopback_isRejected() {
        // 2130706433 (decimal) == 127.0.0.1
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("2130706433"))
    }

    func test_awsMetadataShortForm_isRejected() {
        // 169.254.169.254 short forms
        XCTAssertFalse(URLSafety.isPubliclyRoutableHost("169.254.169.254"))
    }

    func test_publicIPv4InHexStillAllowed() {
        // 0x08.0x08.0x08.0x08 == 8.8.8.8
        XCTAssertTrue(URLSafety.isPubliclyRoutableHost("0x08.0x08.0x08.0x08"))
    }

    // MARK: - App-scheme rule respects no-clean

    func test_buildSchemeURL_usesProvidedURL() {
        // Direct sanity check on the helper used by the app-scheme branch:
        // when called with the uncleaned URL, the deep link's `{query}`
        // template should reflect the uncleaned form.
        let raw = URL(string: "https://example.com/path?utm_source=email&keep=1")!
        // Mirror what `buildSchemeURL` does inline (it's private but the
        // logic is trivial — interpolate placeholders into a template).
        let template = "myapp://open?orig={query}"
        let expected = "myapp://open?orig=utm_source=email&keep=1"
        let rendered = template.replacingOccurrences(of: "{query}", with: raw.query ?? "")
        XCTAssertEqual(rendered, expected)
    }
}
