import XCTest
import Foundation
import Darwin
@testable import JunctionApp

// MARK: - Mock launcher

/// Records every `launch` / `run` call so tests can assert routing without spawning real processes.
final class MockBrowserLauncher: BrowserLaunching {
    struct Call: Equatable {
        let appURL: URL
        let profileDirectory: String?
        let incognito: Bool
        let url: URL
    }

    struct RunCall: Equatable {
        let appURL: URL
        let arguments: [String]
    }

    private(set) var calls: [Call] = []
    private(set) var runCalls: [RunCall] = []

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

    func run(
        appURL: URL,
        arguments: [String],
        completion: @escaping (Bool) -> Void
    ) {
        runCalls.append(RunCall(appURL: appURL, arguments: arguments))
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

    private func makeZen(profile: ChromiumProfile? = nil) -> LaunchOption {
        let browser = Browser(bundleID: "app.zen-browser.zen", name: "Zen", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: profile)
    }

    private func makeFirefox() -> LaunchOption {
        let browser = Browser(bundleID: "org.mozilla.firefox", name: "Firefox", url: fakeAppURL)
        return LaunchOption(browser: browser, profile: nil)
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

    // MARK: - Firefox/Zen profile lock detection
    //
    // Regression for the "Zen duplicate window open bug" where Junction
    // detected only Junction-launched Zen instances (argv contained
    // `--profile <path>`), missed Dock/Spotlight launches, and consequently
    // added `--new-instance` to a profile that was already locked. Zen then
    // aborted with "already running but not responding" and nothing opened.

    private func makeTempProfileDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("junction-profile-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Locates the `POSIXLockHolder` test helper built by SwiftPM alongside the test bundle.
    private func posixLockHolderURL() throws -> URL {
        let name = "POSIXLockHolder"
        let fm = FileManager.default
        let root = URL(fileURLWithPath: fm.currentDirectoryPath)
        let candidates = [
            root.appendingPathComponent(".build/debug/\(name)"),
            root.appendingPathComponent(".build/arm64-apple-macosx/debug/\(name)"),
            root.appendingPathComponent(".build/x86_64-apple-macosx/debug/\(name)"),
        ]
        if let url = candidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) {
            return url
        }
        throw NSError(domain: "URLOpenerRoutingTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "POSIXLockHolder helper not found; run `swift build` first.",
        ])
    }

    func test_firefoxProfileActivelyLocked_emptyDirectory_returnsFalse() throws {
        let dir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        XCTAssertFalse(URLOpener.isFirefoxProfileActivelyLocked(dir.path),
                       "An empty profile directory must not be reported as locked.")
    }

    func test_firefoxProfileActivelyLocked_parentLockWithoutFcntlLock_returnsFalse() throws {
        let dir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Firefox leaves `.parentlock` on disk after clean shutdown without
        // an active fcntl lock. Presence alone must not be treated as
        // "running" or we'd hit the original bug from the opposite side.
        let parentLock = dir.appendingPathComponent(".parentlock")
        XCTAssertTrue(FileManager.default.createFile(atPath: parentLock.path, contents: nil))

        XCTAssertFalse(URLOpener.isFirefoxProfileActivelyLocked(dir.path),
                       "Stale .parentlock without an fcntl lock must report as not running.")
    }

    func test_firefoxProfileActivelyLocked_parentLockWithFcntlLock_returnsTrue() throws {
        let dir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lockPath = dir.appendingPathComponent(".parentlock").path
        XCTAssertTrue(FileManager.default.createFile(atPath: lockPath, contents: nil))

        let holder = Process()
        holder.executableURL = try posixLockHolderURL()
        holder.arguments = [lockPath]
        try holder.run()
        defer {
            if holder.isRunning { holder.terminate() }
            holder.waitUntilExit()
        }

        var locked = false
        for _ in 0..<50 where !locked {
            locked = URLOpener.isFirefoxProfileActivelyLocked(dir.path)
            if !locked { usleep(20_000) }
        }
        XCTAssertTrue(locked, "fcntl-held .parentlock must report as actively locked.")
    }

    func test_firefoxProfileActivelyLocked_symlinkToDeadPid_returnsFalse() throws {
        let dir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lockPath = dir.appendingPathComponent("lock").path
        let target = "127.0.0.1:+2147483640"
        try FileManager.default.createSymbolicLink(atPath: lockPath, withDestinationPath: target)

        XCTAssertFalse(URLOpener.isFirefoxProfileActivelyLocked(dir.path),
                       "Symlink lock pointing at a dead PID must report as not running.")
    }

    func test_firefoxProfileActivelyLocked_symlinkToLivePid_returnsTrue() throws {
        let dir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lockPath = dir.appendingPathComponent("lock").path
        let target = "127.0.0.1:+\(getpid())"
        try FileManager.default.createSymbolicLink(atPath: lockPath, withDestinationPath: target)

        XCTAssertTrue(URLOpener.isFirefoxProfileActivelyLocked(dir.path),
                      "Symlink lock pointing at a live PID must report as running.")
    }

    func test_firefoxProfileActivelyLocked_unparseableSymlink_returnsFalse() throws {
        let dir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let lockPath = dir.appendingPathComponent("lock").path
        try FileManager.default.createSymbolicLink(atPath: lockPath, withDestinationPath: "not-a-valid-lock-target")

        XCTAssertFalse(URLOpener.isFirefoxProfileActivelyLocked(dir.path),
                       "Unparseable lock symlink must not be treated as actively locked.")
    }

    // MARK: - Firefox/Zen routing via injected launcher

    func test_zenProfile_unlocked_includesNewInstance() throws {
        let mock = MockBrowserLauncher()
        let profileDir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: profileDir) }

        let profile = ChromiumProfile(directoryName: profileDir.path, displayName: "Test", colorHex: nil)
        let option = makeZen(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.runCalls.count, 1)
        XCTAssertEqual(mock.runCalls[0].appURL, fakeAppURL)
        XCTAssertEqual(
            mock.runCalls[0].arguments,
            ["--new-instance", "--profile", profileDir.path, "--new-tab", targetURL.absoluteString]
        )
    }

    func test_zenProfile_locked_omitsNewInstance() throws {
        let mock = MockBrowserLauncher()
        let profileDir = try makeTempProfileDir()
        defer { try? FileManager.default.removeItem(at: profileDir) }

        let lockPath = profileDir.appendingPathComponent("lock").path
        try FileManager.default.createSymbolicLink(
            atPath: lockPath,
            withDestinationPath: "127.0.0.1:+\(getpid())"
        )

        let profile = ChromiumProfile(directoryName: profileDir.path, displayName: "Test", colorHex: nil)
        let option = makeZen(profile: profile)

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: false, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.runCalls.count, 1)
        XCTAssertEqual(
            mock.runCalls[0].arguments,
            ["--profile", profileDir.path, "--new-tab", targetURL.absoluteString]
        )
    }

    func test_firefoxNoProfileIncognito_usesLauncherRun() {
        let mock = MockBrowserLauncher()
        let option = makeFirefox()

        let exp = expectation(description: "completion fires")
        URLOpener.open(targetURL, with: option, incognito: true, launcher: mock) { _ in exp.fulfill() }
        waitForExpectations(timeout: 1.0)

        XCTAssertEqual(mock.runCalls.count, 1)
        XCTAssertEqual(mock.runCalls[0].appURL, fakeAppURL)
        XCTAssertEqual(
            mock.runCalls[0].arguments,
            ["--private-window", targetURL.absoluteString]
        )
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
