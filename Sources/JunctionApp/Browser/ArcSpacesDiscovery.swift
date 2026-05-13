import Foundation

enum ArcSpacesDiscovery {
    static let bundleID = "company.thebrowser.Browser"

    static func spaces() -> [ChromiumProfile] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("Library/Application Support/Arc/StorableSidebar.json")
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sidebar = root["sidebar"] as? [String: Any],
              let containers = sidebar["containers"] as? [[String: Any]]
        else { return [] }

        var spaces: [ChromiumProfile] = []
        for container in containers {
            guard let entries = container["spaces"] as? [Any] else { continue }
            for entry in entries {
                guard let dict = entry as? [String: Any],
                      let id = dict["id"] as? String,
                      let title = dict["title"] as? String,
                      !title.isEmpty
                else { continue }

                let profileDir = extractProfileDirectory(from: dict) ?? "Default"
                let colorHex = extractColorHex(from: dict)
                spaces.append(ChromiumProfile(
                    directoryName: "\(profileDir)|space:\(id)",
                    displayName: title,
                    colorHex: colorHex
                ))
            }
        }
        return spaces
    }

    private static func extractProfileDirectory(from dict: [String: Any]) -> String? {
        if let profile = dict["profile"] as? [String: Any] {
            if let custom = (profile["custom"] as? [String: Any])?["_0"] as? [String: Any],
               let basename = custom["directoryBasename"] as? String {
                return basename
            }
            if let str = profile["default"] as? String { return str }
        }
        return nil
    }

    private static func extractColorHex(from dict: [String: Any]) -> String? {
        guard let customInfo = dict["customInfo"] as? [String: Any],
              let theme = customInfo["windowTheme"] as? [String: Any],
              let palette = theme["semanticColorPalette"] as? [String: Any],
              let appearance = palette["appearanceBased"] as? [String: Any]
        else { return nil }

        for mode in ["dark", "light"] {
            if let m = appearance[mode] as? [String: Any],
               let title = m["title"] as? [String: Any],
               let r = title["red"] as? Double,
               let g = title["green"] as? Double,
               let b = title["blue"] as? Double {
                let rr = Int((r * 255).rounded())
                let gg = Int((g * 255).rounded())
                let bb = Int((b * 255).rounded())
                return String(format: "#%02X%02X%02X", rr, gg, bb)
            }
        }
        return nil
    }
}
