import Foundation

enum RiskLevel: Int, Comparable {
    case info = 0
    case low = 1
    case medium = 2
    case high = 3

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .info: return "info"
        case .low: return "heads up"
        case .medium: return "caution"
        case .high: return "warning"
        }
    }
}

struct RiskFlag: Identifiable, Hashable {
    let id = UUID()
    let level: RiskLevel
    let title: String
    let detail: String
}

enum URLRiskAssessor {
    static func assess(_ url: URL) -> [RiskFlag] {
        var flags: [RiskFlag] = []

        if ShortenerExpander.isShortened(url) {
            flags.append(RiskFlag(
                level: .low,
                title: "Shortened URL",
                detail: "Junction can expand this before opening."
            ))
        }

        if let host = url.host?.lowercased() {
            if host.contains("xn--") {
                if let decoded = host.idnaDecoded {
                    flags.append(RiskFlag(
                        level: .medium,
                        title: "Punycode host",
                        detail: "Resolves to \(decoded). Confirm this matches the site you expect."
                    ))
                } else {
                    flags.append(RiskFlag(
                        level: .medium,
                        title: "Punycode host",
                        detail: "Host contains internationalized characters (xn--). Confirm it matches the site you expect."
                    ))
                }
            }

            if hasMixedScripts(host) {
                flags.append(RiskFlag(
                    level: .high,
                    title: "Mixed-script host",
                    detail: "This host combines characters from multiple scripts, a common spoofing technique."
                ))
            }

            if suspiciousTLD(for: host) {
                flags.append(RiskFlag(
                    level: .low,
                    title: "Uncommon TLD",
                    detail: "This top-level domain is frequently abused in phishing. Double-check the full host."
                ))
            }
        }

        return flags
    }

    private static func hasMixedScripts(_ host: String) -> Bool {
        var sawLatin = false
        var sawOther = false
        for scalar in host.unicodeScalars {
            if scalar == "." || scalar == "-" || ("0"..."9").contains(scalar) { continue }
            if (scalar >= "a" && scalar <= "z") || (scalar >= "A" && scalar <= "Z") {
                sawLatin = true
            } else if scalar.value > 0x7F {
                sawOther = true
            }
            if sawLatin && sawOther { return true }
        }
        return false
    }

    private static func suspiciousTLD(for host: String) -> Bool {
        let suspicious: Set<String> = [
            "zip", "mov", "click", "country", "download", "gq", "kim", "link",
            "quest", "stream", "surf", "support", "top", "work", "xyz"
        ]
        guard let tld = host.split(separator: ".").last else { return false }
        return suspicious.contains(String(tld))
    }
}

private extension String {
    var idnaDecoded: String? {
        let host = self as NSString
        return (host as String).applyingTransform(StringTransform("Any-Name"), reverse: false) ?? nil
    }
}
