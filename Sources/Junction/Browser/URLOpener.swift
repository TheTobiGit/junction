import AppKit

enum URLOpener {
    static func open(_ url: URL, with option: LaunchOption, completion: ((Bool) -> Void)? = nil) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let profile = option.profile {
            let (dirName, spaceID) = splitProfileDirectory(profile.directoryName)

            if option.browser.bundleID == ArcSpacesDiscovery.bundleID, let spaceID {
                let script = "open -b \(option.browser.bundleID) \(url.absoluteString.shellQuoted)"
                _ = script
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

            config.arguments = [
                "--profile-directory=\(dirName)",
                url.absoluteString
            ]
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.openApplication(
                at: option.browser.url,
                configuration: config
            ) { _, error in
                DispatchQueue.main.async { completion?(error == nil) }
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

    private static func splitProfileDirectory(_ raw: String) -> (dir: String, spaceID: String?) {
        if let sep = raw.range(of: "|space:") {
            let dir = String(raw[..<sep.lowerBound])
            let space = String(raw[sep.upperBound...])
            return (dir, space)
        }
        return (raw, nil)
    }
}

private extension String {
    var shellQuoted: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
