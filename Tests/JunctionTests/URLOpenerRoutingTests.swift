import XCTest
import Foundation
@testable import JunctionApp

// MARK: - Mock launcher

/// Records every `launch` call so tests can assert routing without spawning real processes.
final class MockBrowserLauncher: BrowserLaunching {
    struct Call: Equatable {
        let appURL: URL
        let profileDirectory: String?
        let incognito: Bool
        let url: URL
    }

    private(set) var calls: [Call] = []

    func launch(
        appURL: URL,
        profileDirectory: String?,
        incognito: Bool,
        url: URL,
        completion: @escaping (Bool) -> Void
    ) {
        calls.append(Call(appURL: appURL, profileDirectory: profileDirectory, incognito: incognito, url: url))
        DispatchQueue.main.async { completion(true) }
    }
}

// MARK: - URLOpener routing tests

final class URLOpenerRoutingTests: XCTestCase {

    private let targetURL = URL(string: "https://example.com/test")!
    private let fakeAppURL = URL(fileURLWithPath: "/Applications/FakeBrowser.app")

    // MARK: - Helpers

    private func makeBrave(profile: ChromiumProfile? = nil) -> LaunchOption {
        let browser = Browser(bundleID: "com.brave.Browser", name: "Brave Browser", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: profile)
    }

    private func makeHelium(profile: ChromiumProfile? = nil) -> LaunchOption {
        let browser = Browser(bundleID: "net.imput.helium", name: "Helium", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: profile)
    }

    // MARK: - VAL-OPENER-001: Chromium profile path uses BrowserLauncher

    func test_chromiumProfileNoIncognito_usesBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let profile = ChromiumProfile(directoryName: "Default", displayName: "Personal", colorHex: nil)
        let option = makeBrave(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 1, "BrowserLauncher must be called exactly once")
        XCTAssertEqual(mock.calls[0].appURL, fakeAppURL)
        XCTAssertEqual(mock.calls[0].profileDirectory, "Default")
        XCTAssertFalse(mock.calls[0].incognito)
        XCTAssertEqual(mock.calls[0].url, targetURL)
    }

    // MARK: - VAL-OPENER-002: Chromium non-profile path uses BrowserLauncher

    func test_chromiumNoProfile_nonIncognito_usesBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let option = makeBrave()

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 1, "BrowserLauncher must be called for Chromium no-profile non-incognito")
        XCTAssertEqual(mock.calls[0].appURL, fakeAppURL)
        XCTAssertNil(mock.calls[0].profileDirectory)
        XCTAssertFalse(mock.calls[0].incognito)
        XCTAssertEqual(mock.calls[0].url, targetURL)
    }

    // MARK: - VAL-OPENER-003: Chromium incognito paths use BrowserLauncher

    func test_chromiumProfileIncognito_usesBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let profile = ChromiumProfile(directoryName: "Profile 1", displayName: "Work", colorHex: nil)
        let option = makeBrave(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: true, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertEqual(mock.calls[0].profileDirectory, "Profile 1")
        XCTAssertTrue(mock.calls[0].incognito)
        XCTAssertEqual(mock.calls[0].url, targetURL)
    }

    func test_chromiumNoProfileIncognito_usesBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let option = makeBrave()

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: true, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertNil(mock.calls[0].profileDirectory)
        XCTAssertTrue(mock.calls[0].incognito)
        XCTAssertEqual(mock.calls[0].url, targetURL)
    }

    func test_heliumProfile_usesBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let profile = ChromiumProfile(directoryName: "Profile 1", displayName: "Test", colorHex: nil)
        let option = makeHelium(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 1, "Helium profiles should use Chromium-style launching")
        XCTAssertEqual(mock.calls[0].profileDirectory, "Profile 1")
        XCTAssertFalse(mock.calls[0].incognito)
        XCTAssertEqual(mock.calls[0].url, targetURL)
    }

    // MARK: - Incognito support stays pure and side-effect free

    func test_supportsIncognito_knownBrowserCapabilities() {
        XCTAssertTrue(URLOpener.supportsIncognito(bundleID: "com.brave.Browser"))
        XCTAssertTrue(URLOpener.supportsIncognito(bundleID: "net.imput.helium"))
        XCTAssertTrue(URLOpener.supportsIncognito(bundleID: "company.thebrowser.dia"))
        XCTAssertTrue(URLOpener.supportsIncognito(bundleID: "org.mozilla.firefox"))
        XCTAssertTrue(URLOpener.supportsIncognito(bundleID: "com.apple.Safari"))
        XCTAssertFalse(URLOpener.supportsIncognito(bundleID: "com.example.NotABrowser"))
    }

    // MARK: - Profile directory with spaces is passed through correctly

    func test_profileDirectoryWithSpaces_passedThrough() {
        let mock = MockBrowserLauncher()
        let profile = ChromiumProfile(directoryName: "Profile 1", displayName: "Work", colorHex: nil)
        let option = makeBrave(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls[0].profileDirectory, "Profile 1",
                       "Profile directory name with spaces must be passed as a single value")
    }

    func test_diaWindowScript_usesFastAccessibilityWindowLookupForProfiles() {
        let script = URLOpener.diaWindowScript(
            profileName: "thetobi",
            incognito: false,
            url: targetURL
        )

        XCTAssertTrue(script.contains("repeat with diaWindow in windows"))
        XCTAssertTrue(script.contains("if itemName starts with \"thetobi:\""))
        XCTAssertTrue(script.contains("perform action \"AXRaise\" of diaWindow"))
        XCTAssertTrue(script.contains("keystroke \"t\" using {command down}"))
        XCTAssertTrue(script.contains("New thetobi Window"))
        XCTAssertTrue(script.contains("Dia could not open the requested profile window for New thetobi Window"))
        XCTAssertFalse(script.contains("set currentURL to URL of active tab of front window"))
        XCTAssertTrue(script.contains(targetURL.absoluteString))
    }

    func test_diaWindowScript_doesNotFallbackToNormalTabForIncognito() {
        let script = URLOpener.diaWindowScript(
            profileName: nil,
            incognito: true,
            url: targetURL
        )

        XCTAssertTrue(script.contains("New Incognito Window"))
        XCTAssertTrue(script.contains("if true then error \"Dia did not open a private window"))
        XCTAssertFalse(script.contains("set currentURL to URL of active tab of front window"))
    }

    func test_diaWindowScript_usesPlainNewWindowMenuItemWithoutProfile() {
        let script = URLOpener.diaWindowScript(
            profileName: nil,
            incognito: false,
            url: targetURL
        )

        XCTAssertTrue(script.contains("New Window"))
        XCTAssertFalse(script.contains("New Window Window"))
    }
}
