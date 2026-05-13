import AppKit

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

    private static func isChromiumBundleID(_ bundleID: String) -> Bool {
        let chromiumPrefixes = [
            "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser",
            "com.vivaldi.Vivaldi", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
            "org.chromium.Chromium", "company.thebrowser.dia",
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

    private static func openSafariPrivate(url: URL, app: URL, completion: @escaping (Bool) -> Void) {
        let encoded = url.absoluteString.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Safari"
            activate
            tell application "System Events"
                keystroke "n" using {command down, shift down}
            end tell
            delay 0.15
            open location "\(encoded)"
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            _ = script?.executeAndReturnError(&error)
            completion(error == nil)
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
