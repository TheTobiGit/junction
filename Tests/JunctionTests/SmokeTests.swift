import XCTest
import Foundation

final class SmokeTests: XCTestCase {
    func test_foundationIsImportable() {
        // Verifies Foundation is importable and basic types work
        let url = URL(string: "https://example.com")
        XCTAssertNotNil(url)
    }
}
