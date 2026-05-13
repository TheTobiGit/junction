import XCTest
@testable import JunctionApp

/// Regression guard: ensures no existing Chromium vendor is silently dropped.
/// If a vendor is removed or renamed, this test will fail and force an explicit decision.
final class ChromiumVendorSnapshotTests: XCTestCase {

    // The full set of Chromium vendors that must always be present.
    private let expectedBundleIDs: [String] = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.google.Chrome.beta",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Beta",
        "com.brave.Browser",
        "com.brave.Browser.beta",
        "com.brave.Browser.nightly",
        "net.imput.helium",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "org.chromium.Chromium",
        "company.thebrowser.dia",
    ]

    func test_allExpectedVendorsAreSupported() {
        for bundleID in expectedBundleIDs {
            XCTAssertTrue(
                ChromiumProfileDiscovery.supports(bundleID: bundleID),
                "ChromiumProfileDiscovery should support \(bundleID) but does not"
            )
        }
    }
}
