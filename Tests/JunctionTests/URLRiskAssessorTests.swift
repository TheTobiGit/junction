import XCTest
import Foundation
@testable import JunctionApp

final class URLRiskAssessorTests: XCTestCase {
    func test_assessCleanedURL_keepsSuspiciousHostFlags() {
        let raw = URL(string: "https://login.example.zip?utm_source=email&fbclid=abc")!
        let cleaned = URLTransformers.default.run(raw)
        let flagsRaw = URLRiskAssessor.assess(raw)
        let flagsCleaned = URLRiskAssessor.assess(cleaned)
        XCTAssertTrue(flagsCleaned.contains { $0.title == "Uncommon TLD" })
        XCTAssertEqual(
            flagsCleaned.filter { $0.title == "Uncommon TLD" }.count,
            flagsRaw.filter { $0.title == "Uncommon TLD" }.count
        )
    }

    func test_punycodeHostFlag() {
        let url = URL(string: "https://xn--e1afmkfd.xn--p1ai/path")!
        let cleaned = URLTransformers.default.run(url)
        XCTAssertFalse(URLRiskAssessor.assess(cleaned).filter { $0.title == "Punycode host" }.isEmpty)
    }

    func test_shortenerDetectedBeforeExpansion() {
        let url = URL(string: "https://bit.ly/abc123")!
        let cleaned = URLTransformers.default.run(url)
        XCTAssertFalse(URLRiskAssessor.assess(cleaned).filter { $0.title == "Shortened URL" }.isEmpty)
    }

    func test_pickerRiskUsesRawWhenCleaningDisabledEvenIfCleanedDiffers() {
        let raw = URL(string: "https://evil.zip/deeplink")!
        let cleaned = URL(string: "https://example.com/deeplink")!
        let flagsCleaningOn = PickerURLRisk.flags(for: raw, cleanedURL: cleaned, cleanURLsBeforeOpening: true)
        let flagsCleaningOff = PickerURLRisk.flags(for: raw, cleanedURL: cleaned, cleanURLsBeforeOpening: false)
        XCTAssertTrue(flagsCleaningOff.contains { $0.title == "Uncommon TLD" })
        XCTAssertFalse(flagsCleaningOn.contains { $0.title == "Uncommon TLD" })
    }
}
