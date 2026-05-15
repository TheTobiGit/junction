import AppKit
import ApplicationServices
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

            // Non-Chromium profile path (e.g. Firefox with a profile) — keep
            // NSWorkspace so Firefox-specific behaviour is unchanged.
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.arguments = ["--profile-directory=\(dirName)", url.absoluteString]
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(
                at: option.browser.url,
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

        // Firefox incognito — preserved as-is via NSWorkspace + --private-window.
        if incognito, let args = incognitoArguments(for: option.browser.bundleID, url: url) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            config.arguments = args
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(
                at: option.browser.url,
                configuration: config
            ) { _, error in
                DispatchQueue.main.async { completion?(error == nil) }
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
            "org.mozilla.nightly", "com.zen-browser.zen",
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
}
