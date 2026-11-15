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

final class LaunchOptionCache {
    private let maxAge: TimeInterval
    private let now: () -> Date
    private let scan: () -> [LaunchOption]
    private let runInBackground: (@escaping () -> Void) -> Void
    private let lock = NSLock()
    private var cached: [LaunchOption]?
    private var scannedAt = Date.distantPast
    private var refreshing = false

    init(
        maxAge: TimeInterval = 5,
        now: @escaping () -> Date = Date.init,
        scan: @escaping () -> [LaunchOption],
        runInBackground: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.global(qos: .utility).async(execute: $0) }
    ) {
        self.maxAge = maxAge
        self.now = now
        self.scan = scan
        self.runInBackground = runInBackground
    }

    func current() -> [LaunchOption] {
        lock.lock()
        if let cached {
            let stale = now().timeIntervalSince(scannedAt) > maxAge && !refreshing
            if stale { refreshing = true }
            lock.unlock()
            if stale { runInBackground { [self] in store(scan(), refreshDone: true) } }
            return cached
        }
        lock.unlock()
        let fresh = scan()
        store(fresh, refreshDone: false)
        return fresh
    }

    private func store(_ options: [LaunchOption], refreshDone: Bool) {
        lock.lock()
        cached = options
        scannedAt = now()
        if refreshDone { refreshing = false }
        lock.unlock()
    }
}

enum LaunchOptionDiscovery {
    private static let cache = LaunchOptionCache(scan: scanInstalled)

    static func options() -> [LaunchOption] {
        applyUserOrder(cache.current())
    }

    static func warmUp() {
        DispatchQueue.global(qos: .utility).async { _ = cache.current() }
    }

    private static func scanInstalled() -> [LaunchOption] {
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
        return result
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

    /// Resolves the user's favorite browser/profile to a `LaunchOption` if
    /// the underlying app or profile is still installed and discoverable.
    /// When a previously-favored profile has been deleted, returns a
    /// synthesized bundle-level option (profile-less) for the same browser
    /// so "open in favorite" stays useful even after profile churn —
    /// importantly, this never silently routes the user into an unrelated
    /// surviving profile of the same browser. The `app:<bundleID>` form
    /// behaves the same way: when discovery has begun returning per-profile
    /// options for the bundle (e.g. profiles created after the favorite was
    /// saved), we synthesize a profile-less option rather than returning
    /// nil or routing into a profile the user never picked.
    /// `favoriteKey` defaults to the shared settings store's value;
    /// tests inject an explicit key to avoid touching the singleton.
    static func resolveFavorite(
        favoriteKey: String? = SettingsStore.shared.settings.favoriteTargetKey,
        in options: [LaunchOption] = options()
    ) -> LaunchOption? {
        guard let key = favoriteKey else { return nil }
        if let match = options.first(where: { $0.target.storageKey == key }) {
            return match
        }
        if key.hasPrefix("profile:") {
            let rest = String(key.dropFirst("profile:".count))
            let bundleID = rest.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
            return synthesizedBundleOption(forBundleID: bundleID, in: options)
        }
        if key.hasPrefix("app:") {
            let bundleID = String(key.dropFirst("app:".count))
            return synthesizedBundleOption(forBundleID: bundleID, in: options)
        }
        return nil
    }

    /// Returns a profile-less `LaunchOption` for `bundleID` when any option
    /// for that bundle exists in `options`, copying the existing `Browser`
    /// value (icon, name, install URL) instead of routing into an unrelated
    /// profile that happens to share the bundle.
    private static func synthesizedBundleOption(
        forBundleID bundleID: String,
        in options: [LaunchOption]
    ) -> LaunchOption? {
        guard !bundleID.isEmpty,
              let bundleMatch = options.first(where: { $0.browser.bundleID == bundleID })
        else { return nil }
        return LaunchOption(browser: bundleMatch.browser, profile: nil)
    }

    private static func applyUserOrder(_ options: [LaunchOption]) -> [LaunchOption] {
        applyUserOrder(options, order: SettingsStore.shared.settings.targetOrder)
    }

    static func applyUserOrder(_ options: [LaunchOption], order: [String]) -> [LaunchOption] {
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
