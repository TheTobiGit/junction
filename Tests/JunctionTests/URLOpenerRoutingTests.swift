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

    private func makeDia(profile: ChromiumProfile? = nil) -> LaunchOption {
        let browser = Browser(bundleID: "company.thebrowser.dia", name: "Dia", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: profile)
    }

    private func makeFirefox() -> LaunchOption {
        let browser = Browser(bundleID: "org.mozilla.firefox", name: "Firefox", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: nil)
    }

    private func makeSafari() -> LaunchOption {
        let browser = Browser(bundleID: "com.apple.Safari", name: "Safari", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: nil)
    }

    private func makeArc(profile: ChromiumProfile) -> LaunchOption {
        let browser = Browser(bundleID: ArcSpacesDiscovery.bundleID, name: "Arc", url: fakeAppURL)
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

    func test_chromiumProfileNoIncognito_dia_usesBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let profile = ChromiumProfile(directoryName: "Profile 1", displayName: "Work", colorHex: nil)
        let option = makeDia(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 1)
        XCTAssertEqual(mock.calls[0].profileDirectory, "Profile 1")
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

    // MARK: - VAL-OPENER-004: Firefox incognito path does NOT use BrowserLauncher

    func test_firefoxIncognito_doesNotUseBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let option = makeFirefox()

        // Firefox incognito goes through NSWorkspace with --private-window, not BrowserLauncher.
        // We don't pass a completion here; we just verify the mock is never called.
        URLOpener.open(targetURL, with: option, incognito: true, launcher: mock)

        let exp = expectation(description: "brief settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 0, "Firefox incognito must NOT route through BrowserLauncher")
    }

    func test_firefoxNonIncognito_doesNotUseBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let option = makeFirefox()

        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock)

        let exp = expectation(description: "brief settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 0, "Firefox non-incognito must NOT route through BrowserLauncher")
    }

    // MARK: - VAL-OPENER-005: Safari incognito AppleScript path does NOT use BrowserLauncher

    func test_safariIncognito_doesNotUseBrowserLauncher() {
        let mock = MockBrowserLauncher()
        let option = makeSafari()

        URLOpener.open(targetURL, with: option, incognito: true, launcher: mock)

        let exp = expectation(description: "brief settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 0, "Safari incognito must NOT route through BrowserLauncher")
    }

    // MARK: - VAL-OPENER-006: Arc profile/space path does NOT use BrowserLauncher

    func test_arcSpacePath_doesNotUseBrowserLauncher() {
        let mock = MockBrowserLauncher()
        // Arc profile directory encodes the space ID after the "|space:" separator.
        let profile = ChromiumProfile(
            directoryName: "Default|space:abc123",
            displayName: "My Space",
            colorHex: nil
        )
        let option = makeArc(profile: profile)

        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock)

        let exp = expectation(description: "brief settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.calls.count, 0, "Arc space path must NOT route through BrowserLauncher")
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
}
