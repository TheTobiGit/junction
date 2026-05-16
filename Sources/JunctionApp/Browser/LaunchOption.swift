import AppKit

struct LaunchOption: Identifiable, Hashable {
    let browser: Browser
    let profile: ChromiumProfile?

    var id: String { target.storageKey }

    var target: LaunchTarget {
        if let profile {
            return .profile(
                bundleID: browser.bundleID,
                profileID: profile.directoryName,
                label: profile.displayName,
                colorHex: profile.colorHex
            )
        }
        return .app(bundleID: browser.bundleID)
    }

    var displayName: String {
        if let profile { return "\(browser.name) — \(profile.displayName)" }
        return browser.name
    }

    var colorHex: String? { profile?.colorHex }

    var icon: NSImage { browser.icon }
}

enum LaunchOptionDiscovery {
    static func options() -> [LaunchOption] {
        let browsers = BrowserDiscovery.installedBrowsers()
        var result: [LaunchOption] = []

        for browser in browsers {
            if browser.bundleID == ArcSpacesDiscovery.bundleID {
                let spaces = ArcSpacesDiscovery.spaces()
                if spaces.isEmpty {
                    result.append(LaunchOption(browser: browser, profile: nil))
                } else {
                    for space in spaces {
                        result.append(LaunchOption(browser: browser, profile: space))
                    }
                }
                continue
            }
            if ChromiumProfileDiscovery.supports(bundleID: browser.bundleID) {
                let profiles = ChromiumProfileDiscovery.profiles(for: browser.bundleID)
                if profiles.isEmpty {
                    result.append(LaunchOption(browser: browser, profile: nil))
                } else {
                    for profile in profiles {
                        result.append(LaunchOption(browser: browser, profile: profile))
                    }
                }
            } else if FirefoxProfileDiscovery.supports(bundleID: browser.bundleID) {
                let profiles = FirefoxProfileDiscovery.profiles(for: browser.bundleID)
                if profiles.isEmpty {
                    result.append(LaunchOption(browser: browser, profile: nil))
                } else {
                    for profile in profiles {
                        result.append(LaunchOption(browser: browser, profile: profile))
                    }
                }
            } else {
                result.append(LaunchOption(browser: browser, profile: nil))
            }
        }
        return applyUserOrder(result)
    }

    static func visibleOptions() -> [LaunchOption] {
        let hidden = Set(SettingsStore.shared.settings.hiddenTargetKeys)
        return options().filter { !hidden.contains($0.target.storageKey) }
    }

    static func resolve(target: LaunchTarget, in options: [LaunchOption] = options()) -> LaunchOption? {
        if let match = options.first(where: { $0.target == target }) {
            return match
        }
        if case .app = target {
            return options.first { $0.browser.bundleID == target.bundleID }
        }
        return nil
    }

    private static func applyUserOrder(_ options: [LaunchOption]) -> [LaunchOption] {
        let order = SettingsStore.shared.settings.targetOrder
        guard !order.isEmpty else { return options }

        var byKey = Dictionary(uniqueKeysWithValues: options.map { ($0.target.storageKey, $0) })
        var ordered: [LaunchOption] = []
        for key in order {
            if let option = byKey.removeValue(forKey: key) {
                ordered.append(option)
            }
        }
        ordered.append(contentsOf: options.filter { byKey[$0.target.storageKey] != nil })
        return ordered
    }
}
