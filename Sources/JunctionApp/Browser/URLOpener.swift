import AppKit
import ApplicationServices
import Darwin
import UserNotifications

enum URLOpener {
    /// Opens `url` in the browser described by `option`.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - option: The browser (and optional profile) to use.
    ///   - incognito: Whether to request a private/incognito window.
    ///   - launcher: The `BrowserLaunching` implementation used for all Chromium
    ///     paths. Defaults to `BrowserLauncher()`. Inject a mock in unit tests.
    ///   - completion: Called on the main queue with `true` on success.
    static func open(
        _ url: URL,
        with option: LaunchOption,
        incognito: Bool = false,
        launcher: BrowserLaunching = BrowserLauncher(),
        completion: ((Bool) -> Void)? = nil
    ) {
        // MARK: Profile branch

        if let profile = option.profile {
            let (dirName, spaceID) = splitProfileDirectory(profile.directoryName)

            // Arc branch — preserved as-is. Exit early via arc://space/<id>.
            if option.browser.bundleID == ArcSpacesDiscovery.bundleID, let spaceID {
                if let spaceURL = URL(string: "arc://space/\(spaceID)") {
                    let openConfig = NSWorkspace.OpenConfiguration()
                    openConfig.activates = true
                    NSWorkspace.shared.open(
                        [spaceURL, url],
                        withApplicationAt: option.browser.url,
                        configuration: openConfig
                    ) { _, error in
                        DispatchQueue.main.async { completion?(error == nil) }
                    }
                    return
                }
            }

            if option.browser.bundleID == diaBundleID {
                openDiaWindow(
                    profileName: incognito ? nil : profile.displayName,
                    incognito: incognito,
                    url: url
                ) { success in
                    DispatchQueue.main.async { completion?(success) }
                }
                return
            }

            // Chromium profile path (paths 1 & 2) — use BrowserLauncher so the
            // URL is delivered even when the browser is already running.
            if isChromiumBundleID(option.browser.bundleID) {
                launcher.launch(
                    appURL: option.browser.url,
                    profileDirectory: dirName,
                    incognito: incognito,
                    url: url
                ) { success in
                    DispatchQueue.main.async { completion?(success) }
                }
                return
            }

            // Firefox-family profile path (Firefox, Zen, …). Spawn the
            // Mach-O binary directly via `Foundation.Process` rather than
            // `NSWorkspace.openApplication`. Two reasons:
            //
            // 1. When the browser is already running,
            //    `NSWorkspace.openApplication` with
            //    `createsNewApplicationInstance = false` activates the
            //    existing process and SILENTLY DROPS `config.arguments`.
            //    The URL is never delivered — Zen just focuses and nothing
            //    opens. This was the user-visible "subsequent clicks just
            //    focus the window" bug.
            //
            // 2. Firefox/Zen's launcher binary already does the right thing
            //    on its own: cold-start → boot the browser with the URL;
            //    warm-start → detect the running profile via the lock file,
            //    IPC the URL over, exit. Doing it ourselves via NSWorkspace
            //    fights that mechanism.
            //
            // Flag choices:
            // - `--profile <abs-path>` is preferred over `-P <name>` because
            //   the path is stable (profiles.ini) and survives renames.
            // - `--new-instance` is added ONLY when the target profile is
            //   NOT currently locked. Adding it to a locked profile makes
            //   Firefox/Zen show the "already running but not responding"
            //   dialog and refuse to open the URL.
            // - `--new-tab` for normal URLs, `--private-window` for
            //   incognito.
            //
            // Note on Zen Spaces (workspaces within a profile): Zen exposes
            // no public API to switch the active workspace at launch — not a
            // CLI flag, not a URL scheme, and not the `zen.workspaces.active`
            // pref (Zen reconstructs the active workspace from tab focus
            // recorded in `zen-sessions.jsonlz4`, which we don't write). For
            // now Junction routes to the profile and lets Zen pick the
            // workspace per its own session-restore logic.
            if isFirefoxBundleID(option.browser.bundleID) {
                let absProfilePath = resolveFirefoxFamilyProfilePath(
                    bundleID: option.browser.bundleID,
                    relativePath: dirName
                )
                let profileFlag = incognito ? "--private-window" : "--new-tab"
                let alreadyRunning = isFirefoxFamilyProfileRunning(
                    bundleID: option.browser.bundleID,
                    absProfilePath: absProfilePath
                )

                var args: [String] = []
                if !alreadyRunning {
                    args.append("--new-instance")
                }
                args.append(contentsOf: ["--profile", absProfilePath, profileFlag, url.absoluteString])

                BrowserLauncher.run(appURL: option.browser.url, arguments: args) { success in
                    DispatchQueue.main.async { completion?(success) }
                }
                return
            }

            // Unknown vendor with a profile — fall back to plain open. Drops
            // the profile selection rather than passing a flag the browser
            // doesn't understand.
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: option.browser.url,
                configuration: config
            ) { _, error in
                DispatchQueue.main.async { completion?(error == nil) }
            }
            return
        }

        // MARK: No-profile incognito branch

        if incognito, option.browser.bundleID == diaBundleID {
            openDiaWindow(profileName: nil, incognito: true, url: url) { success in
                DispatchQueue.main.async { completion?(success) }
            }
            return
        }

        // Chromium no-profile incognito (path 3) — use BrowserLauncher.
        if incognito, isChromiumBundleID(option.browser.bundleID) {
            launcher.launch(
                appURL: option.browser.url,
                profileDirectory: nil,
                incognito: true,
                url: url
            ) { success in
                DispatchQueue.main.async { completion?(success) }
            }
            return
        }

        // Firefox-family no-profile incognito. Spawn the binary directly
        // for the same reason as the profiled path: NSWorkspace silently
        // drops arguments when the app is already running.
        if incognito,
           isFirefoxBundleID(option.browser.bundleID),
           let args = incognitoArguments(for: option.browser.bundleID, url: url)
        {
            BrowserLauncher.run(appURL: option.browser.url, arguments: args) { success in
                DispatchQueue.main.async { completion?(success) }
            }
            return
        }

        // Safari incognito — preserved as-is via AppleScript.
        if incognito, option.browser.bundleID == "com.apple.Safari" {
            openSafariPrivate(url: url, app: option.browser.url) { success in
                DispatchQueue.main.async { completion?(success) }
            }
            return
        }

        // MARK: Default branch

        if option.browser.bundleID == diaBundleID {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: option.browser.url,
                configuration: config
            ) { _, error in
                DispatchQueue.main.async { completion?(error == nil) }
            }
            return
        }

        // Chromium no-profile, non-incognito (path 4) — use BrowserLauncher so
        // the URL is delivered even when the browser is already running.
        if isChromiumBundleID(option.browser.bundleID) {
            launcher.launch(
                appURL: option.browser.url,
                profileDirectory: nil,
                incognito: false,
                url: url
            ) { success in
                DispatchQueue.main.async { completion?(success) }
            }
            return
        }

        // Non-Chromium, non-incognito (e.g. Safari plain launch) — NSWorkspace.
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: option.browser.url,
            configuration: config
        ) { _, error in
            DispatchQueue.main.async { completion?(error == nil) }
        }
    }

    static func supportsIncognito(bundleID: String) -> Bool {
        if isChromiumBundleID(bundleID) { return true }
        if isFirefoxBundleID(bundleID) { return true }
        if bundleID == "com.apple.Safari" { return true }
        return false
    }

    private static let diaBundleID = "company.thebrowser.dia"

    private static func isChromiumBundleID(_ bundleID: String) -> Bool {
        let chromiumPrefixes = [
            "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
            "net.imput.helium",
            "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
            "org.chromium.Chromium", diaBundleID,
            "com.kagi.kagimacOS", "app.sigmaos.sigmaos",
        ]
        return chromiumPrefixes.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }

    private static func isFirefoxBundleID(_ bundleID: String) -> Bool {
        let firefoxes = [
            "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition",
            "org.mozilla.nightly", "app.zen-browser.zen",
        ]
        return firefoxes.contains(bundleID)
    }

    private static func incognitoArguments(for bundleID: String, url: URL) -> [String]? {
        if isChromiumBundleID(bundleID) {
            return ["--incognito", url.absoluteString]
        }
        if isFirefoxBundleID(bundleID) {
            return ["--private-window", url.absoluteString]
        }
        return nil
    }

    /// Single notification per process when Safari private mode falls back to a normal window. Persist with `UserDefaults` if we ever want to cap across launches.
    private static var safariPrivateAccessibilityFallbackNotified = false

    private static func openSafariRegular(url: URL, app: URL, completion: @escaping (Bool) -> Void) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config) { _, error in
            completion(error == nil)
        }
    }

    private static func notifySafariPrivateNeedsAccessibility() {
        guard !safariPrivateAccessibilityFallbackNotified else { return }
        safariPrivateAccessibilityFallbackNotified = true

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let deliver: () -> Void = {
                let content = UNMutableNotificationContent()
                content.title = "Private Safari unavailable"
                content.body = "Grant Junction accessibility access in System Settings ▸ Privacy & Security ▸ Accessibility to open Private Browsing automatically. This link opened in a regular Safari window."
                let request = UNNotificationRequest(identifier: "junction.safari-private-accessibility", content: content, trigger: nil)
                center.add(request)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                deliver()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { deliver() }
                }
            default:
                NSLog("Junction: Safari private browsing requires accessibility trust; notifications denied.")
            }
        }
    }

    private static func openSafariPrivate(url: URL, app: URL, completion: @escaping (Bool) -> Void) {
        guard AXIsProcessTrusted() else {
            requestAccessibilityTrust()
            notifySafariPrivateNeedsAccessibility()
            openSafariRegular(url: url, app: app, completion: completion)
            return
        }

        let encoded = url.absoluteString.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Safari"
            activate
            tell application "System Events"
                keystroke "n" using {command down, shift down}
            end tell
            delay 0.5
            open location "\(encoded)"
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            do {
                try process.run()
                process.waitUntilExit()
                completion(process.terminationStatus == 0)
            } catch {
                completion(false)
            }
        }
    }

    private static func openDiaWindow(
        profileName: String?,
        incognito: Bool,
        url: URL,
        completion: @escaping (Bool) -> Void
    ) {
        if !AXIsProcessTrusted() {
            requestAccessibilityTrust()
            completion(false)
            return
        }

        runAppleScript(diaWindowScript(profileName: profileName, incognito: incognito, url: url)) { result in
            completion(result == url.absoluteString)
        }
    }

    static func diaWindowScript(
        profileName: String?,
        incognito: Bool,
        url: URL
    ) -> String {
        let encodedURL = appleScriptString(url.absoluteString)
        let rawMenuItem: String
        if incognito {
            rawMenuItem = "New Incognito Window"
        } else if let profileName {
            rawMenuItem = "New \(profileName) Window"
        } else {
            rawMenuItem = "New Window"
        }
        let menuItem = appleScriptString(rawMenuItem)
        let profilePrefix = profileName.map { appleScriptString("\($0):") }
        let profileWindowLookup = profilePrefix.map { prefix in
            """
                    repeat with diaWindow in windows
                        try
                            set itemName to name of diaWindow as text
                            if itemName starts with "\(prefix)" then
                                perform action "AXRaise" of diaWindow
                                set foundExistingProfileWindow to true
                                exit repeat
                            end if
                        end try
                    end repeat
            """
        } ?? ""
        let requiresExactProfileWindow = profileName != nil && !incognito

        return """
        tell application "Dia"
            set beforeWindowCount to count of windows
            activate
        end tell
        delay 0.05
        set foundExistingProfileWindow to false
        set menuOpenedWindow to false
        tell application "System Events"
            tell process "Dia"
                try
                    set frontmost to true
        \(profileWindowLookup)
                    if foundExistingProfileWindow then
                        keystroke "t" using {command down}
                    else
                        click menu item "\(menuItem)" of menu 1 of menu item "New Window" of menu 1 of menu bar item "File" of menu bar 1
                        set menuOpenedWindow to true
                    end if
                end try
            end tell
        end tell

        if foundExistingProfileWindow then
            delay 0.1
            tell application "Dia"
                set URL of active tab of front window to "\(encodedURL)"
                return "\(encodedURL)"
            end tell
        end if

        if menuOpenedWindow then
            repeat 30 times
                tell application "Dia"
                    if (count of windows) > beforeWindowCount then exit repeat
                end tell
                delay 0.05
            end repeat
        end if

        tell application "Dia"
            if (count of windows) <= beforeWindowCount then
                if \(requiresExactProfileWindow ? "true" : "false") then error "Dia could not open the requested profile window for \(menuItem)"
                if \(incognito ? "true" : "false") then error "Dia did not open a private window for \(menuItem)"

                try
                    make new window
                    delay 0.3
                end try

                if (count of windows) <= beforeWindowCount then
                    if (count of windows) = 0 then error "Dia has no window available for \(encodedURL)"
                    set newTab to make new tab at end of tabs of front window with properties {URL:"\(encodedURL)"}
                    focus newTab
                else
                    set URL of active tab of front window to "\(encodedURL)"
                end if
            else
                set URL of active tab of front window to "\(encodedURL)"
            end if

            return "\(encodedURL)"
        end tell
        """
    }

    private static func requestAccessibilityTrust() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private static func appleScriptString(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func runAppleScript(_ source: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error {
                NSLog("Junction: AppleScript failed: \(error)")
                completion(nil)
                return
            }

            completion(result?.stringValue)
        }
    }

    private static func splitProfileDirectory(_ raw: String) -> (dir: String, spaceID: String?) {
        if let sep = raw.range(of: "|space:") {
            let dir = String(raw[..<sep.lowerBound])
            let space = String(raw[sep.upperBound...])
            return (dir, space)
        }
        return (raw, nil)
    }

    /// Returns true when the Firefox-family profile at `absProfilePath` is
    /// currently in use by a running process. Used to decide whether
    /// `--new-instance` is needed on launch — if the target profile is
    /// already in use, omitting `--new-instance` lets the new URL IPC into
    /// the existing process for that profile. Adding `--new-instance` when
    /// the profile IS in use makes Firefox/Zen abort with the
    /// "already running but not responding" dialog and refuse to open
    /// anything — which is the bug this guards against.
    ///
    /// Primary signal: probe Firefox's profile lock files inside the
    /// profile directory itself. This works regardless of how the browser
    /// was launched (Dock click, Spotlight, Junction CLI, etc.), which the
    /// previous argv-only check did not.
    ///
    /// Fallback: keep the `ps -o command=` argv check for the rare case
    /// where lock probing is inconclusive (e.g. sandboxed FS access denies
    /// reading the profile dir) but Junction itself spawned the running
    /// instance with `--profile <absPath>`.
    private static func isFirefoxFamilyProfileRunning(
        bundleID: String,
        absProfilePath: String
    ) -> Bool {
        if isFirefoxProfileActivelyLocked(absProfilePath) { return true }

        let pids = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .map { Int($0.processIdentifier) }
            .filter { $0 > 0 }
        guard !pids.isEmpty else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", pids.map(String.init).joined(separator: ","), "-o", "command="]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return false
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)
        else { return false }

        let needle = "--profile \(absProfilePath)"
        return text.split(separator: "\n").contains { line in
            String(line).contains(needle)
        }
    }

    /// Returns true when a Firefox-family profile directory holds an active
    /// lock — i.e. another process currently has the profile open.
    ///
    /// Firefox/Zen uses two lock primitives inside each active profile dir:
    ///
    /// - `.parentlock` (and historically `parent.lock`): a regular file
    ///   guarded by an `fcntl` write lock. The file itself may persist
    ///   across clean shutdowns, so its mere presence is NOT a reliable
    ///   running signal — we must probe the lock state with
    ///   `fcntl(F_GETLK)`.
    ///
    /// - `lock`: a symbolic link whose target is `"<host>:+<pid>"` (modern)
    ///   or `"<host>:<pid>"` (legacy). The link target intentionally is not
    ///   a real filesystem path. We parse the PID and probe it with
    ///   `kill(pid, 0)`.
    ///
    /// Returns false if the directory can't be read or no lock is held;
    /// false negatives cause the caller to fall through to the `ps`
    /// fallback and ultimately to spawning `--new-instance`, which is the
    /// pre-fix behaviour.
    private static let firefoxParentLockNames = [".parentlock", "parent.lock"]

    static func isFirefoxProfileActivelyLocked(_ absProfilePath: String) -> Bool {
        let base = URL(fileURLWithPath: absProfilePath, isDirectory: true)

        for name in firefoxParentLockNames where regularLockFileIsActive(
            base.appendingPathComponent(name).path
        ) {
            return true
        }

        return symlinkLockIsActive(base.appendingPathComponent("lock").path)
    }

    /// Probes a regular lock file with `fcntl(F_GETLK, F_WRLCK)`. Returns
    /// true when another process currently holds an exclusive lock on it.
    private static func regularLockFileIsActive(_ path: String) -> Bool {
        let fd = Darwin.open(path, O_RDONLY)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }

        var lock = flock()
        lock.l_start = 0
        lock.l_len = 0
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        lock.l_pid = 0

        guard fcntl(fd, F_GETLK, &lock) != -1 else { return false }
        return lock.l_type != Int16(F_UNLCK)
    }

    /// Reads a Firefox-style `lock` symlink (without following it) and
    /// checks whether the encoded PID is still alive. The symlink target
    /// format is `"<host>:+<pid>"` (modern) or `"<host>:<pid>"` (legacy).
    private static func symlinkLockIsActive(_ path: String) -> Bool {
        var buf = [CChar](repeating: 0, count: 1024)
        let n = readlink(path, &buf, buf.count - 1)
        guard n > 0 else { return false }
        buf[n] = 0
        let target = String(cString: buf)

        guard let colon = target.lastIndex(of: ":") else { return false }
        var pidPart = target[target.index(after: colon)...]
        if pidPart.hasPrefix("+") { pidPart = pidPart.dropFirst() }
        guard let pid = pid_t(pidPart) else {
            // Unparseable target — treat as active to avoid spurious
            // `--new-instance` if Firefox changes the lock format.
            return true
        }

        return kill(pid, 0) == 0 || errno == EPERM
    }

    /// Maps a Firefox-family relative profile path (from `profiles.ini`) to
    /// an absolute on-disk path under `~/Library/Application Support/<vendor>/`.
    /// Single source of truth for the bundleID→config-dir mapping lives in
    /// `FirefoxProfileDiscovery.vendors`.
    private static func resolveFirefoxFamilyProfilePath(
        bundleID: String,
        relativePath: String
    ) -> String {
        // `profiles.ini` may store `IsRelative=0` with an absolute `Path`,
        // in which case it's already the on-disk profile path and must not
        // be re-rooted under Application Support.
        if relativePath.hasPrefix("/") { return relativePath }

        let configDir = FirefoxProfileDiscovery.configRelativePath(forBundleID: bundleID) ?? "Firefox"
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return relativePath
        }
        return appSupport
            .appendingPathComponent(configDir, isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: true)
            .path
    }
}
