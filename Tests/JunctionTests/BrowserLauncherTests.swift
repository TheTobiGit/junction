import XCTest
import Foundation
@testable import JunctionApp

final class BrowserLauncherTests: XCTestCase {

    // MARK: - Fixture helpers

    /// Creates a temporary fake `.app` bundle under a unique temp directory.
    /// - Parameters:
    ///   - executableName: Value written to `CFBundleExecutable` in Info.plist.
    ///   - createExecutable: When `true`, an empty file is placed at
    ///     `Contents/MacOS/<executableName>` so `resolveExecutable` succeeds.
    /// - Returns: URL of the `.app` bundle (parent temp dir is the cleanup target).
    private func makeFakeApp(
        executableName: String = "FakeBrowser",
        createExecutable: Bool
    ) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BrowserLauncherTests-\(UUID().uuidString)")
        let appURL = tmpDir.appendingPathComponent("FakeBrowser.app")
        let contentsDir = appURL.appendingPathComponent("Contents")
        let macosDir = contentsDir.appendingPathComponent("MacOS")

        try FileManager.default.createDirectory(at: macosDir, withIntermediateDirectories: true)

        let plist: [String: Any] = ["CFBundleExecutable": executableName]
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try plistData.write(to: contentsDir.appendingPathComponent("Info.plist"))

        if createExecutable {
            let execURL = macosDir.appendingPathComponent(executableName)
            try Data().write(to: execURL)
        }

        return appURL
    }

    // MARK: - VAL-LAUNCHER-001: Resolves executable path from .app bundle

    func test_resolvesExecutablePathFromAppBundle() throws {
        // Success path: valid Info.plist + binary present
        let appURL = try makeFakeApp(executableName: "FakeBrowser", createExecutable: true)
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

        let resolved = BrowserLauncher.resolveExecutable(for: appURL)
        XCTAssertNotNil(resolved, "Should resolve a path when Info.plist and binary exist")
        XCTAssertEqual(resolved?.lastPathComponent, "FakeBrowser")
        XCTAssertTrue(
            resolved?.path.hasSuffix("Contents/MacOS/FakeBrowser") == true,
            "Resolved path must end with Contents/MacOS/<CFBundleExecutable>"
        )

        // Failure path: no Info.plist at all → nil (no throw)
        let emptyAppURL = appURL.deletingLastPathComponent()
            .appendingPathComponent("EmptyBrowser.app")
        try FileManager.default.createDirectory(
            at: emptyAppURL.appendingPathComponent("Contents/MacOS"),
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: emptyAppURL) }
        XCTAssertNil(
            BrowserLauncher.resolveExecutable(for: emptyAppURL),
            "Should return nil when Info.plist is absent"
        )
    }

    // MARK: - VAL-LAUNCHER-002: Assembles args for profile launch (spaces preserved)

    func test_profileArgsPreserveSpaces() {
        let url = URL(string: "https://example.com/foo")!
        let args = BrowserLauncher.arguments(
            profileDirectory: "Profile 1",
            incognito: false,
            url: url
        )
        XCTAssertEqual(
            args,
            ["--profile-directory=Profile 1", "https://example.com/foo"],
            "Profile name with spaces must be a single element, not split"
        )
    }

    // MARK: - VAL-LAUNCHER-003: Assembles args for profile + incognito

    func test_profileAndIncognitoArgOrder() {
        let url = URL(string: "https://example.com/bar")!
        let args = BrowserLauncher.arguments(
            profileDirectory: "Default",
            incognito: true,
            url: url
        )
        XCTAssertEqual(
            args,
            ["--profile-directory=Default", "--incognito", "https://example.com/bar"],
            "Order must be: profile flag, incognito flag, URL"
        )
    }

    // MARK: - VAL-LAUNCHER-004: Assembles args for incognito-only (no profile)

    func test_incognitoOnlyArgs() {
        let url = URL(string: "https://example.com/baz")!
        let args = BrowserLauncher.arguments(
            profileDirectory: nil,
            incognito: true,
            url: url
        )
        XCTAssertEqual(
            args,
            ["--incognito", "https://example.com/baz"]
        )
    }

    // MARK: - VAL-LAUNCHER-005: Assembles args for plain URL (no profile, no incognito)

    func test_plainArgs() {
        let url = URL(string: "https://example.com/plain")!
        let args = BrowserLauncher.arguments(
            profileDirectory: nil,
            incognito: false,
            url: url
        )
        XCTAssertEqual(args, ["https://example.com/plain"])
    }

    // MARK: - VAL-LAUNCHER-006: Reports failure when executable is missing

    func test_missingExecutableReportsFailure() throws {
        // Info.plist present but no binary in Contents/MacOS/
        let appURL = try makeFakeApp(executableName: "FakeBrowser", createExecutable: false)
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

        let exp = expectation(description: "completion fires with false")
        BrowserLauncher().launch(
            appURL: appURL,
            profileDirectory: nil,
            incognito: false,
            url: URL(string: "https://example.com")!
        ) { success in
            XCTAssertFalse(success, "completion must receive false when executable is missing")
            exp.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    // MARK: - VAL-LAUNCHER-007: Does not block the caller; completion on main queue

    func test_completionFiresOnMainQueueWithoutBlocking() throws {
        // Use the missing-executable path so no real process is spawned,
        // while still exercising the full async dispatch + main-queue hop.
        let appURL = try makeFakeApp(executableName: "FakeBrowser", createExecutable: false)
        defer { try? FileManager.default.removeItem(at: appURL.deletingLastPathComponent()) }

        let exp = expectation(description: "completion fires on main queue")
        let start = Date()

        BrowserLauncher().launch(
            appURL: appURL,
            profileDirectory: nil,
            incognito: false,
            url: URL(string: "https://example.com")!
        ) { _ in
            XCTAssertTrue(Thread.isMainThread, "completion must be invoked on the main queue")
            exp.fulfill()
        }

        // The method must return synchronously — well within 50 ms.
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 0.05, "launch must return within 50 ms (got \(String(format: "%.1f", elapsed * 1000)) ms)")

        waitForExpectations(timeout: 2.0)
    }
}
