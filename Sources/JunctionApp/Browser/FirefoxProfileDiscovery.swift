import Foundation

/// Discovers profiles for Firefox-family browsers (Firefox, Zen, etc.).
///
/// Firefox stores profiles in a `profiles.ini` file alongside the
/// `Profiles/` directory. Each profile section has a `Name` (user-facing,
/// passed via `-P "<name>"` on launch) and `Path` (relative or absolute).
///
/// Reuses `ChromiumProfile` as the value type — it carries name +
/// directory + optional color, which is all we need. Profile colors
/// aren't stored in `profiles.ini` so `colorHex` is always nil for
/// this family.
enum FirefoxProfileDiscovery {
    struct Vendor {
        let bundleID: String
        /// Path relative to `~/Library/Application Support/`.
        let configRelativePath: String
    }

    private static let vendors: [Vendor] = [
        Vendor(bundleID: "org.mozilla.firefox", configRelativePath: "Firefox"),
        Vendor(bundleID: "org.mozilla.firefoxdeveloperedition", configRelativePath: "Firefox"),
        Vendor(bundleID: "org.mozilla.nightly", configRelativePath: "Firefox"),
        Vendor(bundleID: "app.zen-browser.zen", configRelativePath: "zen"),
    ]

    static func supports(bundleID: String) -> Bool {
        vendors.contains { $0.bundleID == bundleID }
    }

    static func profiles(for bundleID: String) -> [ChromiumProfile] {
        guard let vendor = vendors.first(where: { $0.bundleID == bundleID }) else { return [] }

        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return []
        }

        let iniURL = appSupport
            .appendingPathComponent(vendor.configRelativePath, isDirectory: true)
            .appendingPathComponent("profiles.ini", isDirectory: false)

        guard let content = try? String(contentsOf: iniURL, encoding: .utf8) else { return [] }
        return parseProfilesIni(content)
    }

    /// Visible for testing.
    static func parseProfilesIni(_ text: String) -> [ChromiumProfile] {
        let sections = parseIniSections(text)

        // `[InstallXXXX]` sections point at the active default profile by `Path`.
        // `[General] StartWithLastProfile=1` plus an `[ProfileN] Default=1` is the
        // legacy mechanism. Honour both.
        var defaultPaths: Set<String> = []
        for s in sections where s.name.hasPrefix("Install") {
            if let def = s.kv["Default"] { defaultPaths.insert(def) }
        }
        for s in sections where s.name.hasPrefix("Profile") {
            if s.kv["Default"] == "1", let path = s.kv["Path"] {
                defaultPaths.insert(path)
            }
        }

        var profiles: [ChromiumProfile] = []
        for s in sections where s.name.hasPrefix("Profile") {
            guard let name = s.kv["Name"], let path = s.kv["Path"] else { continue }
            // Track the path in directoryName so the storage key is stable even
            // if the user renames the profile. The launch CLI takes the name,
            // so URLOpener pulls it from displayName instead.
            profiles.append(ChromiumProfile(
                directoryName: path,
                displayName: name,
                colorHex: nil
            ))
        }

        profiles.sort { lhs, rhs in
            let lhsDefault = defaultPaths.contains(lhs.directoryName)
            let rhsDefault = defaultPaths.contains(rhs.directoryName)
            if lhsDefault && !rhsDefault { return true }
            if !lhsDefault && rhsDefault { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return profiles
    }

    private struct IniSection {
        let name: String
        let kv: [String: String]
    }

    private static func parseIniSections(_ text: String) -> [IniSection] {
        var sections: [IniSection] = []
        var currentName: String? = nil
        var currentKV: [String: String] = [:]

        let flush: () -> IniSection? = {
            guard let name = currentName else { return nil }
            return IniSection(name: name, kv: currentKV)
        }

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                if let s = flush() { sections.append(s) }
                currentName = String(line.dropFirst().dropLast())
                currentKV = [:]
                continue
            }
            guard currentName != nil, let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq])
            let value = String(line[line.index(after: eq)...])
            currentKV[key] = value
        }
        if let s = flush() { sections.append(s) }
        return sections
    }
}
