import XCTest
@testable import JunctionApp

final class ReaderModeBundlingTests: XCTestCase {

    // VAL-M4-READER-001: Readability.js bundled in Resources
    func test_readabilityJsBundledWithApacheLicenseHeader_VAL_M4_READER_001() throws {
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let readabilityURL = repoRoot.appendingPathComponent("Resources/Readability.js")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: readabilityURL.path),
            "Resources/Readability.js must exist in the repository"
        )

        let content = try String(contentsOf: readabilityURL, encoding: .utf8)
        XCTAssertGreaterThan(content.count, 0, "Resources/Readability.js must be non-empty")

        let lines = content.components(separatedBy: "\n")
        let first40 = lines.prefix(40).joined(separator: "\n")
        XCTAssertTrue(
            first40.contains("Apache License"),
            "First 40 lines must contain Apache 2.0 license header marker"
        )
    }
}
