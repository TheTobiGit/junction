import XCTest
@testable import JunctionCore

final class URLPipelineStepLabelTests: XCTestCase {
    func test_knownIdentifiersHaveHumanLabels() {
        XCTAssertEqual(
            URLPipelineStepLabel.label(for: "outgoing-redirect-unwrapper"),
            "Unwrapped tracking redirect"
        )
        XCTAssertEqual(
            URLPipelineStepLabel.label(for: "domain-redirect"),
            "Applied domain redirect"
        )
        XCTAssertEqual(
            URLPipelineStepLabel.label(for: "amp-collapser"),
            "Collapsed AMP URL"
        )
        XCTAssertEqual(
            URLPipelineStepLabel.label(for: "tracker-stripper"),
            "Removed tracking parameters"
        )
    }

    func test_unknownIdentifierFallsBackToRawValue() {
        XCTAssertEqual(URLPipelineStepLabel.label(for: "future-transformer"), "future-transformer")
    }
}
