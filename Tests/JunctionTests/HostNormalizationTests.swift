import XCTest
@testable import JunctionApp

final class HostNormalizationTests: XCTestCase {
    // MARK: - RulesStore.normalizedHost

    func test_normalizedHost_stripsTrailingDot() {
        let url = URL(string: "https://example.com./path")!
        XCTAssertEqual(RulesStore.normalizedHost(for: url), "example.com")
    }

    func test_normalizedHost_stripsMultipleTrailingDots() {
        let url = URL(string: "https://example.com.../path")!
        XCTAssertEqual(RulesStore.normalizedHost(for: url), "example.com")
    }

    func test_normalizedHost_stripsTrailingDotAndWWWPrefix() {
        let url = URL(string: "https://www.example.com./path")!
        XCTAssertEqual(RulesStore.normalizedHost(for: url), "example.com")
    }

    // MARK: - HostMatch trailing-dot folding

    func test_hostMatchEquals_acceptsTrailingDot() {
        XCTAssertTrue(HostMatch.equals("example.com").matches("example.com."))
        XCTAssertTrue(HostMatch.equals("example.com.").matches("example.com"))
    }

    func test_hostMatchSuffix_acceptsTrailingDot() {
        XCTAssertTrue(HostMatch.suffix("example.com").matches("shop.example.com."))
    }

    func test_hostMatchEquals_idempotentForCanonical() {
        XCTAssertTrue(HostMatch.equals("example.com").matches("example.com"))
        XCTAssertTrue(HostMatch.equals("EXAMPLE.COM.").matches("example.com"))
    }
}
