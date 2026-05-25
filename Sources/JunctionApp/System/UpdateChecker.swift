import AppKit
import Combine
import Foundation

/// Checks the GitHub Releases API for newer versions of Junction.
///
/// We use a tiny inline JSON decoder against a single endpoint instead of
/// pulling in Sparkle. Trade-off: no in-app delta updates, but zero new
/// dependencies and zero new code-signing requirements (Sparkle wants its
/// own EdDSA signature on the appcast).
@MainActor
final class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()

    enum State: Equatable {
        case idle
        case checking
        case upToDate(currentVersion: String)
        case updateAvailable(latestVersion: String, htmlURL: URL, downloadURL: URL?)
        case downloading(latestVersion: String, htmlURL: URL, progress: Double)
        case readyToInstall(latestVersion: String, htmlURL: URL, stagedAppURL: URL)
        case error(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckedAt: Date?

    private static let endpoint = URL(string: "https://api.github.com/repos/TheTobiGit/junction/releases/latest")!

    private var downloadSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var downloadObservation: NSKeyValueObservation?
    private var downloadContext: DownloadContext?

    private struct DownloadContext {
        let latestVersion: String
        let htmlURL: URL
        let downloadURL: URL
    }

    override private init() {
        super.init()
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    func check(silent: Bool = false) {
        switch state {
        case .checking, .downloading, .readyToInstall:
            return
        default:
            break
        }
        state = .checking
        Task { [weak self] in
            guard let self else { return }
            do {
                let release = try await self.fetchLatestRelease()
                let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
                let current = self.currentVersion
                self.lastCheckedAt = Date()
                if Self.isNewer(latest: latest, than: current) {
                    let download = release.assets.first(where: { $0.name.hasSuffix("-macos.zip") && !$0.name.contains("cli") })?.browser_download_url
                    self.state = .updateAvailable(latestVersion: latest, htmlURL: release.html_url, downloadURL: download)
                } else {
                    self.state = .upToDate(currentVersion: current)
                }
            } catch {
                if silent {
                    self.state = .idle
                } else {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func openLatestRelease() {
        switch state {
        case .updateAvailable(_, let htmlURL, _),
             .downloading(_, let htmlURL, _),
             .readyToInstall(_, let htmlURL, _):
            NSWorkspace.shared.open(htmlURL)
        default:
            NSWorkspace.shared.open(URL(string: "https://github.com/TheTobiGit/junction/releases/latest")!)
        }
    }

    /// Downloads the latest -macos.zip in-process and stages the extracted
    /// .app under Application Support so the user can install or reveal it
    /// without leaving the preferences window. Falls back to the release
    /// page if no zip asset is published.
    func downloadUpdate() {
        guard case let .updateAvailable(latest, htmlURL, downloadURL) = state else { return }
        guard let downloadURL else {
            NSWorkspace.shared.open(htmlURL)
            return
        }

        let context = DownloadContext(latestVersion: latest, htmlURL: htmlURL, downloadURL: downloadURL)
        downloadContext = context
        state = .downloading(latestVersion: latest, htmlURL: htmlURL, progress: 0)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 60 * 10
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        downloadSession = session

        var request = URLRequest(url: downloadURL)
        request.setValue("Junction/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        downloadObservation = task.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] progress, _ in
            let value = progress.fractionCompleted
            Task { @MainActor [weak self] in
                guard let self else { return }
                if case .downloading = self.state {
                    self.state = .downloading(latestVersion: context.latestVersion, htmlURL: context.htmlURL, progress: value)
                }
            }
        }
        downloadTask = task
        task.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        teardownDownload()
        if let context = downloadContext {
            state = .updateAvailable(latestVersion: context.latestVersion, htmlURL: context.htmlURL, downloadURL: context.downloadURL)
        } else {
            state = .idle
        }
        downloadContext = nil
    }

    /// Replaces the running bundle with the staged copy and relaunches.
    ///
    /// macOS keeps the running executable mapped in memory, so the app can
    /// be safely replaced on disk while we're still alive — the trick is
    /// spawning a detached helper that waits for our PID to exit, swaps the
    /// bundle, and reopens the app.
    func installAndRelaunch() {
        guard case let .readyToInstall(_, _, stagedAppURL) = state else { return }
        let currentAppURL = Bundle.main.bundleURL
        let parentDir = currentAppURL.deletingLastPathComponent().path
        let fm = FileManager.default

        // The installer script does its work via rename within the parent
        // directory (ditto into a sibling staging path, mv old aside, mv
        // staged into place). rename(2) only checks write+execute on the
        // parent directory; the bundle's own mode bits don't matter, so
        // root-owned-but-replaceable installs in /Applications still work.
        guard fm.isWritableFile(atPath: parentDir) else {
            state = .error("Junction can't write into \(parentDir). Make sure you have permission to modify that folder, or move Junction.app to ~/Applications and try again.")
            return
        }

        guard fm.fileExists(atPath: stagedAppURL.path) else {
            state = .error("The downloaded update is no longer available on disk. Download it again to continue.")
            return
        }

        do {
            try Self.spawnInstaller(currentApp: currentAppURL, newApp: stagedAppURL)
        } catch {
            state = .error("Couldn't launch installer: \(error.localizedDescription)")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }

    private static func spawnInstaller(currentApp: URL, newApp: URL) throws {
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("junction-installer-\(UUID().uuidString).sh")

        // Atomic swap: copy NEW to a sibling staging path, mv OLD aside,
        // mv staging into OLD's place, only then remove the backup. If
        // anything fails before the final mv, we restore the original
        // bundle and reopen it so the user is never left without a
        // running app. The main process has already been told to quit,
        // so every early exit needs to reopen $OLD itself. The script
        // also unlinks itself on the way out so repeated update attempts
        // don't pile up junction-installer-*.sh files in the temp dir.
        let script = """
        #!/bin/bash
        SCRIPT="$0"
        PID="$1"
        OLD="$2"
        NEW="$3"
        trap '/bin/rm -f "$SCRIPT"' EXIT
        for _ in $(seq 1 600); do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.1
        done

        STAGE="${OLD}.junction-update-$$"
        BACKUP="${OLD}.junction-backup-$$"

        reopen_old() {
            if [ -e "$OLD" ]; then
                /usr/bin/open "$OLD" 2>/dev/null || true
            fi
        }

        /bin/rm -rf "$STAGE"
        if ! /usr/bin/ditto "$NEW" "$STAGE"; then
            /bin/rm -rf "$STAGE"
            reopen_old
            exit 1
        fi

        if [ -e "$OLD" ]; then
            if ! /bin/mv "$OLD" "$BACKUP"; then
                /bin/rm -rf "$STAGE"
                reopen_old
                exit 1
            fi
        fi

        if ! /bin/mv "$STAGE" "$OLD"; then
            if [ -e "$BACKUP" ]; then
                /bin/mv "$BACKUP" "$OLD" || true
            fi
            /bin/rm -rf "$STAGE"
            reopen_old
            exit 1
        fi

        /usr/bin/xattr -dr com.apple.quarantine "$OLD" 2>/dev/null || true
        /bin/rm -rf "$BACKUP"
        /usr/bin/open "$OLD"
        """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o755))],
            ofItemAtPath: scriptURL.path
        )

        let invocation = "nohup /bin/bash \(shellQuote(scriptURL.path)) \(pid) \(shellQuote(currentApp.path)) \(shellQuote(newApp.path)) >/dev/null 2>&1 < /dev/null &"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", invocation]
        try process.run()
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func teardownDownload() {
        downloadObservation?.invalidate()
        downloadObservation = nil
        downloadTask = nil
        downloadSession?.finishTasksAndInvalidate()
        downloadSession = nil
    }

    private func handleDownloadFinished(temporaryURL: URL, context: DownloadContext) {
        // Staging and verification shell out to ditto, codesign, and spctl
        // and use Process.waitUntilExit(), which is seconds of blocking
        // I/O. Hop off the main actor so the preferences UI keeps
        // breathing while a multi-megabyte zip is being unpacked and
        // checked.
        let runningBundleURL = Bundle.main.bundleURL
        let runningIdentifier = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let stagedApp = try Self.stageDownloadedApp(zipAt: temporaryURL, version: context.latestVersion, runningIdentifier: runningIdentifier)
                try Self.verifyStagedApp(at: stagedApp,
                                         expectedVersion: context.latestVersion,
                                         runningBundleURL: runningBundleURL,
                                         runningIdentifier: runningIdentifier)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.state = .readyToInstall(latestVersion: context.latestVersion, htmlURL: context.htmlURL, stagedAppURL: stagedApp)
                    self.teardownDownload()
                    self.downloadContext = nil
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.state = .error("Couldn't prepare the update: \(error.localizedDescription)")
                    self.teardownDownload()
                    self.downloadContext = nil
                }
            }
        }
    }

    private func handleDownloadFailure(_ error: Error, context: DownloadContext) {
        teardownDownload()
        downloadContext = nil
        if (error as NSError).code == NSURLErrorCancelled { return }
        state = .error("Download failed: \(error.localizedDescription)")
    }

    private static nonisolated func stageDownloadedApp(zipAt zipTempURL: URL, version: String, runningIdentifier: String) throws -> URL {
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let stageRoot = support
            .appendingPathComponent("Junction", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
        try fm.createDirectory(at: stageRoot, withIntermediateDirectories: true)

        let zipDest = stageRoot.appendingPathComponent("Junction-\(version).zip")
        if fm.fileExists(atPath: zipDest.path) {
            try fm.removeItem(at: zipDest)
        }
        try fm.moveItem(at: zipTempURL, to: zipDest)

        let extractDir = stageRoot.appendingPathComponent("Junction-\(version)", isDirectory: true)
        if fm.fileExists(atPath: extractDir.path) {
            try fm.removeItem(at: extractDir)
        }
        try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipDest.path, extractDir.path]
        let stderr = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "UpdateChecker", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "ditto failed: \(message)"])
        }

        let app = try locateApp(in: extractDir, runningIdentifier: runningIdentifier)
        return app
    }

    private static nonisolated func locateApp(in directory: URL, runningIdentifier: String) throws -> URL {
        let fm = FileManager.default
        var candidates: [URL] = []
        let enumerator = fm.enumerator(at: directory,
                                       includingPropertiesForKeys: [.isDirectoryKey],
                                       options: [.skipsHiddenFiles])
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "app" {
                candidates.append(url)
                // Helper apps live inside another .app's Contents/, so we
                // don't want to recurse into a matched bundle.
                enumerator?.skipDescendants()
            }
        }

        guard !candidates.isEmpty else {
            throw NSError(domain: "UpdateChecker", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "couldn't find Junction.app inside the downloaded archive"])
        }

        // Prefer a bundle whose CFBundleIdentifier matches the running app.
        // Falls back to the shallowest path so an archive that only ships
        // Junction.app at the root still works even if the plist is unreadable.
        if let match = candidates.first(where: { bundleIdentifier(at: $0) == runningIdentifier }) {
            return match
        }
        return candidates.min(by: { $0.pathComponents.count < $1.pathComponents.count })!
    }

    private static nonisolated func bundleIdentifier(at app: URL) -> String? {
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist["CFBundleIdentifier"] as? String
    }

    /// Confirms the downloaded bundle is the same Junction we're running:
    /// matching CFBundleIdentifier, matching version, matching Team ID,
    /// valid Developer ID signature, and Gatekeeper-approved (i.e.
    /// notarized). We also strip the GitHub-applied quarantine xattr only
    /// after these pass so a tampered or stale archive can't slip past
    /// the user's first-launch warning.
    private static nonisolated func verifyStagedApp(at app: URL,
                                                    expectedVersion: String,
                                                    runningBundleURL: URL,
                                                    runningIdentifier: String) throws {
        let runningInfo = try codesignInfo(forApp: runningBundleURL)

        let stagedInfoPlist = app.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: stagedInfoPlist),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let stagedIdentifier = plist["CFBundleIdentifier"] as? String else {
            throw NSError(domain: "UpdateChecker", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "downloaded archive is missing a bundle identifier"])
        }
        guard stagedIdentifier == runningIdentifier else {
            throw NSError(domain: "UpdateChecker", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "downloaded bundle ID (\(stagedIdentifier)) doesn't match Junction's"])
        }

        // The release tag and the bundle's CFBundleShortVersionString are
        // both produced by release-please from the same manifest, so a
        // mismatch means the published asset is stale or pointed at the
        // wrong tag. Refusing here avoids silently downgrading the user
        // or installing whatever build happened to be in the zip.
        let stagedShort = (plist["CFBundleShortVersionString"] as? String)?.trimmingCharacters(in: .whitespaces)
        let stagedBuild = (plist["CFBundleVersion"] as? String)?.trimmingCharacters(in: .whitespaces)
        let normalizedExpected = expectedVersion.trimmingCharacters(in: CharacterSet(charactersIn: "v "))
        let candidates = [stagedShort, stagedBuild].compactMap { $0 }.filter { !$0.isEmpty }
        guard !candidates.isEmpty else {
            throw NSError(domain: "UpdateChecker", code: -6,
                          userInfo: [NSLocalizedDescriptionKey: "downloaded archive is missing a version string"])
        }
        guard candidates.contains(where: { $0 == normalizedExpected }) else {
            throw NSError(domain: "UpdateChecker", code: -7,
                          userInfo: [NSLocalizedDescriptionKey: "downloaded bundle reports version \(candidates.joined(separator: "/")), expected \(normalizedExpected)"])
        }

        let stagedInfo = try codesignInfo(forApp: app)
        if let expectedTeam = runningInfo.teamID, !expectedTeam.isEmpty {
            guard stagedInfo.teamID == expectedTeam else {
                throw NSError(domain: "UpdateChecker", code: -4,
                              userInfo: [NSLocalizedDescriptionKey: "downloaded build is signed by a different team (\(stagedInfo.teamID ?? "unknown"))"])
            }
        }
        if let expectedAuthority = runningInfo.firstAuthority {
            guard stagedInfo.firstAuthority == expectedAuthority else {
                throw NSError(domain: "UpdateChecker", code: -5,
                              userInfo: [NSLocalizedDescriptionKey: "downloaded build's signing authority doesn't match (\(stagedInfo.firstAuthority ?? "unknown"))"])
            }
        }

        try runOrThrow(executable: "/usr/bin/codesign",
                       arguments: ["--verify", "--deep", "--strict", app.path],
                       failurePrefix: "signature verification failed")
        try runOrThrow(executable: "/usr/sbin/spctl",
                       arguments: ["--assess", "--type", "execute", "--verbose=4", app.path],
                       failurePrefix: "Gatekeeper rejected the downloaded build")
    }

    private struct CodesignInfo {
        let teamID: String?
        let firstAuthority: String?
    }

    private static nonisolated func codesignInfo(forApp app: URL) throws -> CodesignInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvv", app.path]
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        let raw = stderr.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: raw, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "UpdateChecker", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "codesign couldn't read \(app.lastPathComponent): \(text)"])
        }
        let teamID = text
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("TeamIdentifier=") })
            .map { String($0.dropFirst("TeamIdentifier=".count)) }
        let authority = text
            .split(separator: "\n")
            .first(where: { $0.hasPrefix("Authority=") })
            .map { String($0.dropFirst("Authority=".count)) }
        return CodesignInfo(teamID: teamID, firstAuthority: authority)
    }

    private static nonisolated func runOrThrow(executable: String, arguments: [String], failurePrefix: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let raw = stderr.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: raw, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw NSError(domain: "UpdateChecker", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(failurePrefix): \(text)"])
        }
    }

    private struct GHRelease: Decodable {
        let tag_name: String
        let html_url: URL
        let assets: [GHAsset]
    }

    private struct GHAsset: Decodable {
        let name: String
        let browser_download_url: URL
    }

    private func fetchLatestRelease() async throws -> GHRelease {
        var request = URLRequest(url: Self.endpoint)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Junction/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "UpdateChecker", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "GitHub API returned HTTP \(http.statusCode)"])
        }
        return try JSONDecoder().decode(GHRelease.self, from: data)
    }

    /// Compares dot-separated semver prefixes numerically. Strips leading "v"
    /// and any pre-release suffix after the first "-".
    static func isNewer(latest: String, than current: String) -> Bool {
        compare(normalize(latest), normalize(current)) == .orderedDescending
    }

    private static func normalize(_ raw: String) -> [Int] {
        let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let core = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
        return core.split(separator: ".").compactMap { Int($0) }
    }

    private static func compare(_ a: [Int], _ b: [Int]) -> ComparisonResult {
        let count = max(a.count, b.count)
        for i in 0..<count {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x > y { return .orderedDescending }
            if x < y { return .orderedAscending }
        }
        return .orderedSame
    }
}

extension UpdateChecker: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // The delegate-provided file is removed when this callback returns,
        // so move it to a stable temp path before hopping to the main actor.
        let fm = FileManager.default
        let temp = fm.temporaryDirectory.appendingPathComponent("junction-update-\(UUID().uuidString).zip")
        do {
            try fm.moveItem(at: location, to: temp)
        } catch {
            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    guard let self, let context = self.downloadContext else { return }
                    self.handleDownloadFailure(error, context: context)
                }
            }
            return
        }
        DispatchQueue.main.async {
            Task { @MainActor [weak self] in
                guard let self, let context = self.downloadContext else {
                    try? FileManager.default.removeItem(at: temp)
                    return
                }
                self.handleDownloadFinished(temporaryURL: temp, context: context)
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error else { return }
        DispatchQueue.main.async {
            Task { @MainActor [weak self] in
                guard let self, let context = self.downloadContext else { return }
                self.handleDownloadFailure(error, context: context)
            }
        }
    }
}
