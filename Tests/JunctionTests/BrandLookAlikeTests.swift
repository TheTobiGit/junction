import XCTest
@testable import JunctionApp

final class BrandLookAlikeTests: XCTestCase {
    func test_realBrandsAreNotFlagged() {
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("google.com"))
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("github.com"))
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("paypal.com"))
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("amazon.co.uk"))
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("apple.com"))
    }

    func test_singleCharSubstitutionFlagged() {
        XCTAssertEqual(URLRiskAssessor.brandLookAlikeMatch("g00gle.com"), "google.com")
        XCTAssertEqual(URLRiskAssessor.brandLookAlikeMatch("paypa1.com"), "paypal.com")
        XCTAssertEqual(URLRiskAssessor.brandLookAlikeMatch("micros0ft.com"), "microsoft.com")
        XCTAssertEqual(URLRiskAssessor.brandLookAlikeMatch("amaz0n.net"), "amazon.com")
    }

    func test_oneEditTypoFlagged() {
        // 1-edit insert
        XCTAssertEqual(URLRiskAssessor.brandLookAlikeMatch("googel.com"), "google.com")
        // 1-edit delete
        XCTAssertEqual(URLRiskAssessor.brandLookAlikeMatch("paypl.com"), "paypal.com")
    }

    func test_unrelatedDomainsAreNotFlagged() {
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("example.com"))
        XCTAssertNil(URLRiskAssessor.brandLookAlikeMatch("totally-different.org"))
    }

    func test_assessIncludesLookAlikeFlag() {
        let url = URL(string: "https://g00gle.com/login")!
        let flags = URLRiskAssessor.assess(url)
        XCTAssertTrue(flags.contains { $0.title == "Look-alike host" })
    }
}
