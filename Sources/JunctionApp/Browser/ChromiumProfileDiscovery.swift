import Foundation

struct ChromiumProfile: Hashable {
    let directoryName: String
    let displayName: String
    let colorHex: String?
}

enum ChromiumProfileDiscovery {
    struct Vendor {
        let bundleID: String
        let localStatePaths: [String]
    }

    private static let vendors: [Vendor] = [
        Vendor(bundleID: "com.google.Chrome", localStatePaths: ["Google/Chrome/Local State"]),
        Vendor(bundleID: "com.google.Chrome.canary", localStatePaths: ["Google/Chrome Canary/Local State"]),
        Vendor(bundleID: "com.google.Chrome.beta", localStatePaths: ["Google/Chrome Beta/Local State"]),
        Vendor(bundleID: "com.microsoft.edgemac", localStatePaths: ["Microsoft Edge/Local State"]),
        Vendor(bundleID: "com.microsoft.edgemac.Beta", localStatePaths: ["Microsoft Edge Beta/Local State"]),
        Vendor(bundleID: "com.brave.Browser", localStatePaths: ["BraveSoftware/Brave-Browser/Local State"]),
        Vendor(bundleID: "com.brave.Browser.beta", localStatePaths: ["BraveSoftware/Brave-Browser-Beta/Local State"]),
        Vendor(bundleID: "com.brave.Browser.nightly", localStatePaths: ["BraveSoftware/Brave-Browser-Nightly/Local State"]),
        Vendor(bundleID: "com.vivaldi.Vivaldi", localStatePaths: ["Vivaldi/Local State"]),
        Vendor(bundleID: "com.operasoftware.Opera", localStatePaths: ["com.operasoftware.Opera/Local State"]),
        Vendor(bundleID: "com.operasoftware.OperaGX", localStatePaths: ["com.operasoftware.OperaGX/Local State"]),
        Vendor(bundleID: "org.chromium.Chromium", localStatePaths: ["Chromium/Local State"]),
        Vendor(bundleID: "company.thebrowser.dia", localStatePaths: ["Dia/User Data/Local State"]),
    ]

    static func supports(bundleID: String) -> Bool {
        vendors.contains { $0.bundleID == bundleID }
    }

    static func profiles(for bundleID: String) -> [ChromiumProfile] {
        guard let vendor = vendors.first(where: { $0.bundleID == bundleID }) else { return [] }

        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        for relative in vendor.localStatePaths {
            guard let base = appSupport else { continue }
            let path = base.appendingPathComponent(relative)
            if let profiles = parseLocalState(at: path), !profiles.isEmpty {
                return profiles
            }
        }
        return []
    }

    static func menuIndex(for bundleID: String, profileDirectory: String) -> Int? {
        guard let vendor = vendors.first(where: { $0.bundleID == bundleID }) else { return nil }

        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        for relative in vendor.localStatePaths {
            let path = appSupport.appendingPathComponent(relative)
            guard let data = try? Data(contentsOf: path),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profile = obj["profile"] as? [String: Any],
                  let order = profile["profiles_order"] as? [String],
                  let index = order.firstIndex(of: profileDirectory)
            else { continue }
            return index + 1
        }
        return nil
    }

    private static func parseLocalState(at url: URL) -> [ChromiumProfile]? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = obj["profile"] as? [String: Any]
        else { return nil }

        let infoCache = profile["info_cache"] as? [String: [String: Any]] ?? [:]
        let lastUsed = profile["last_used"] as? String

        var profiles: [ChromiumProfile] = []
        for (dir, info) in infoCache {
            if let hidden = info["is_ephemeral"] as? Bool, hidden { continue }
            let name = (info["name"] as? String)
                ?? (info["gaia_name"] as? String)
                ?? (info["user_name"] as? String)
                ?? dir
            let color = info["profile_highlight_color"] as? Int
            let hex = color.flatMap { hexFromChromeColor($0) }
            profiles.append(ChromiumProfile(
                directoryName: dir,
                displayName: name,
                colorHex: hex
            ))
        }

        profiles.sort { lhs, rhs in
            if lhs.directoryName == lastUsed { return true }
            if rhs.directoryName == lastUsed { return false }
            if lhs.directoryName == "Default" { return true }
            if rhs.directoryName == "Default" { return false }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return profiles
    }

    private static func hexFromChromeColor(_ value: Int) -> String? {
        let r = (value >> 16) & 0xFF
        let g = (value >> 8) & 0xFF
        let b = value & 0xFF
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
