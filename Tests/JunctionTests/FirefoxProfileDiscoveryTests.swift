import XCTest
@testable import JunctionApp

final class FirefoxProfileDiscoveryTests: XCTestCase {

    func test_supportsFirefoxFamily() {
        XCTAssertTrue(FirefoxProfileDiscovery.supports(bundleID: "org.mozilla.firefox"))
        XCTAssertTrue(FirefoxProfileDiscovery.supports(bundleID: "app.zen-browser.zen"))
        XCTAssertTrue(FirefoxProfileDiscovery.supports(bundleID: "org.mozilla.firefoxdeveloperedition"))
        XCTAssertFalse(FirefoxProfileDiscovery.supports(bundleID: "com.google.Chrome"))
        XCTAssertFalse(FirefoxProfileDiscovery.supports(bundleID: "com.apple.Safari"))
    }

    func test_parseProfilesIni_zenLayout() {
        let ini = """
        [Install6ED35B3CA1B5D3AF]
        Default=Profiles/yvks0ltq.Default (release)
        Locked=1

        [Profile1]
        Name=Default Profile
        IsRelative=1
        Path=Profiles/bvo93qky.Default Profile
        Default=1

        [Profile0]
        Name=Default (release)
        IsRelative=1
        Path=Profiles/yvks0ltq.Default (release)

        [General]
        StartWithLastProfile=1
        Version=2
        """

        let profiles = FirefoxProfileDiscovery.parseProfilesIni(ini)

        XCTAssertEqual(profiles.count, 2)

        // Default (per Install section) must come first.
        XCTAssertEqual(profiles[0].displayName, "Default (release)")
        XCTAssertEqual(profiles[0].directoryName, "Profiles/yvks0ltq.Default (release)")
        XCTAssertNil(profiles[0].colorHex)

        XCTAssertEqual(profiles[1].displayName, "Default Profile")
    }

    func test_parseProfilesIni_emptyOrInvalid() {
        XCTAssertEqual(FirefoxProfileDiscovery.parseProfilesIni("").count, 0)
        XCTAssertEqual(FirefoxProfileDiscovery.parseProfilesIni("garbage\n\n").count, 0)
    }

    func test_parseProfilesIni_legacyDefaultEquals1() {
        let ini = """
        [Profile0]
        Name=Alpha
        Path=Profiles/aaa.alpha

        [Profile1]
        Name=Beta
        Path=Profiles/bbb.beta
        Default=1
        """

        let profiles = FirefoxProfileDiscovery.parseProfilesIni(ini)
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles[0].displayName, "Beta")  // Default=1 sorted first
        XCTAssertEqual(profiles[1].displayName, "Alpha")
    }
}
