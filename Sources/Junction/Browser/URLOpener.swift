import AppKit

enum URLOpener {
    static func open(_ url: URL, with option: LaunchOption, incognito: Bool = false, completion: ((Bool) -> Void)? = nil) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let profile = option.profile {
            let (dirName, spaceID) = splitProfileDirectory(profile.directoryName)

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

            var args = ["--profile-directory=\(dirName)"]
            if incognito, isChromiumBundleID(option.browser.bundleID) {
                args.append("--incognito")
            }
            args.append(url.absoluteString)

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

        if incognito, let args = incognitoArguments(for: option.browser.bundleID, url: url) {
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

        if incognito, option.browser.bundleID == "com.apple.Safari" {
            openSafariPrivate(url: url, app: option.browser.url) { success in
                DispatchQueue.main.async { completion?(success) }
            }
            return
        }

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
