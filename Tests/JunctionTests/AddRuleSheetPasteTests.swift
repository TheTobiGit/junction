import XCTest
@testable import JunctionApp

final class AddRuleSheetPasteTests: XCTestCase {

    // MARK: - Full URL with scheme

    func testFullHTTPSURL() {
        let result = AddRuleSheet.parsePastedURL("https://github.com/docs/something")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "github.com", path: "/docs/something"))
    }

    func testFullHTTPURL() {
        let result = AddRuleSheet.parsePastedURL("http://example.org/page")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "example.org", path: "/page"))
    }

    func testURLWithQueryAndFragment() {
        let result = AddRuleSheet.parsePastedURL("https://github.com/docs?utm=x#section")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "github.com", path: "/docs"))
    }

    func testURLWithTrailingSlashOnly() {
        let result = AddRuleSheet.parsePastedURL("https://github.com/")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "github.com", path: nil))
    }

    func testURLWithNoPath() {
        let result = AddRuleSheet.parsePastedURL("https://github.com")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "github.com", path: nil))
    }

    // MARK: - URL without scheme

    func testHostAndPathWithoutScheme() {
        let result = AddRuleSheet.parsePastedURL("github.com/docs/something")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "github.com", path: "/docs/something"))
    }

    // MARK: - Bare host (no slash, no scheme)

    func testBareHostReturnsNil() {
        XCTAssertNil(AddRuleSheet.parsePastedURL("github.com"))
    }

    // MARK: - Whitespace

    func testSurroundingWhitespaceTrimmed() {
        let result = AddRuleSheet.parsePastedURL("  https://github.com/docs  ")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "github.com", path: "/docs"))
    }

    func testEmptyStringReturnsNil() {
        XCTAssertNil(AddRuleSheet.parsePastedURL(""))
    }

    func testWhitespaceOnlyReturnsNil() {
        XCTAssertNil(AddRuleSheet.parsePastedURL("   "))
    }

    // MARK: - Subdomain

    func testSubdomainExtracted() {
        let result = AddRuleSheet.parsePastedURL("https://docs.github.com/en/get-started")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "docs.github.com", path: "/en/get-started"))
    }

    // MARK: - Port

    func testURLWithPort() {
        let result = AddRuleSheet.parsePastedURL("https://localhost:8080/api/v1")
        XCTAssertEqual(result, AddRuleSheet.ParsedPaste(host: "localhost", path: "/api/v1"))
    }
}
