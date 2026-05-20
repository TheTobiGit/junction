import Foundation
import Darwin

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

    var isIDNRelated: Bool {
        title == "Punycode host" || title == "Mixed-script host"
    }
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

        if hasUserInfo(url) {
            flags.append(RiskFlag(
                level: .high,
                title: "Credentials in URL",
                detail: "This link embeds a username (or password) before the host. Phishing kits use this to disguise the real destination."
            ))
        }

        if let scheme = url.scheme?.lowercased(), scheme == "http" {
            flags.append(RiskFlag(
                level: .low,
                title: "Plain HTTP",
                detail: "This site is loaded over an unencrypted connection."
            ))
        }

        if let host = url.host?.lowercased() {
            if URLSafety.parseIPv4(host) != nil || isIPv6Literal(host) {
                flags.append(RiskFlag(
                    level: .medium,
                    title: "IP-literal host",
                    detail: "This URL points at a numeric IP address, not a domain name."
                ))
            }

            if host.contains("xn--") {
                let decoded = IDNA.toUnicode(host: host)
                if decoded != host {
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

            let folded = IDNA.toUnicode(host: host)
            if hasMixedScripts(folded) {
                flags.append(RiskFlag(
                    level: .high,
                    title: "Mixed-script host",
                    detail: "This host combines characters from multiple scripts, a common spoofing technique."
                ))
            }

            if let lookalike = brandLookAlikeMatch(folded) {
                flags.append(RiskFlag(
                    level: .high,
                    title: "Look-alike host",
                    detail: "This host closely resembles \(lookalike) but is not the same domain."
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

        if let port = url.port, isNonStandardPort(port, scheme: url.scheme) {
            flags.append(RiskFlag(
                level: .low,
                title: "Non-standard port",
                detail: "Connects on port \(port) instead of the default for \(url.scheme ?? "http(s)")."
            ))
        }

        return flags
    }

    private static func hasUserInfo(_ url: URL) -> Bool {
        if (url.user?.isEmpty == false) || (url.password?.isEmpty == false) { return true }
        // URLComponents catches some pathological forms URL drops silently.
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if (comps.user?.isEmpty == false) || (comps.password?.isEmpty == false) { return true }
        }
        return false
    }

    private static func isIPv6Literal(_ host: String) -> Bool {
        var trimmed = host
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        var addr = in6_addr()
        return trimmed.withCString { Darwin.inet_pton(AF_INET6, $0, &addr) } == 1
    }

    private static func isNonStandardPort(_ port: Int, scheme: String?) -> Bool {
        switch scheme?.lowercased() {
        case "https": return port != 443
        case "http": return port != 80
        default: return true
        }
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

    /// Common targets of phishing kits. Match is on the registrable label
    /// (the segment immediately before the public suffix, approximated as the
    /// last two labels). When the user-visible label is "close" to one of
    /// these brands but isn't the brand itself, surface a high-severity flag.
    private static let brandLabels: [String] = [
        "google", "youtube", "gmail", "googlemail",
        "apple", "icloud",
        "microsoft", "outlook", "office", "live", "hotmail",
        "amazon",
        "facebook", "instagram", "whatsapp", "messenger",
        "twitter",
        "linkedin",
        "github",
        "paypal",
        "netflix",
        "discord",
        "dropbox",
        "tiktok",
        "wellsfargo", "chase", "bankofamerica", "citibank", "barclays",
        "coinbase", "binance", "kraken", "metamask",
        "shopify", "squarespace",
        "slack", "zoom", "notion", "figma",
    ]

    private static let brandHosts: Set<String> = {
        var hosts: Set<String> = []
        for brand in brandLabels {
            hosts.insert(brand + ".com")
            hosts.insert(brand + ".net")
            hosts.insert(brand + ".org")
            hosts.insert(brand + ".io")
        }
        // Hosts that aren't brand.com but are the canonical brand sites.
        hosts.formUnion([
            "google.co.uk", "amazon.co.uk", "amazon.de", "amazon.fr", "amazon.ca",
            "apple.co", "twitter.com", "x.com", "github.io",
        ])
        return hosts
    }()

    static func brandLookAlikeMatch(_ host: String) -> String? {
        let labels = host.split(separator: ".")
        guard labels.count >= 2 else { return nil }
        let registrable = labels.suffix(2).joined(separator: ".")
        if brandHosts.contains(registrable) { return nil }
        let mainLabel = String(labels[labels.count - 2])

        for brand in brandLabels {
            if mainLabel == brand { continue }
            if isVisuallyClose(mainLabel, brand: brand) {
                return "\(brand).com"
            }
        }
        return nil
    }

    /// Heuristic that catches a few common look-alike patterns:
    /// - 1-edit Damerau-Levenshtein distance (insertion / deletion / substitution / swap)
    /// - One label that's the brand with a single common digit-letter swap (`0`↔`o`, `1`↔`l`/`i`, `5`↔`s`, `3`↔`e`)
    /// - Brand prefix or suffix with extra "secure"/"login"/"verify" tokens already covered
    ///   by the registrable-label rule above.
    private static func isVisuallyClose(_ candidate: String, brand: String) -> Bool {
        guard !candidate.isEmpty, brand.count >= 4 else { return false }
        let lowered = candidate.lowercased()
        if lowered.count < brand.count - 1 || lowered.count > brand.count + 2 { return false }

        if damerauLevenshtein(lowered, brand) == 1 { return true }

        // Digit-substitution: replace common digit homoglyphs and re-test equality.
        let restored = lowered
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: "1", with: "l")
            .replacingOccurrences(of: "3", with: "e")
            .replacingOccurrences(of: "5", with: "s")
            .replacingOccurrences(of: "7", with: "t")
        if restored == brand { return true }

        return false
    }

    private static func damerauLevenshtein(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let n = aChars.count
        let m = bChars.count
        if n == 0 { return m }
        if m == 0 { return n }

        var prevPrev = [Int](repeating: 0, count: m + 1)
        var prev = (0...m).map { $0 }
        var curr = [Int](repeating: 0, count: m + 1)

        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    curr[j - 1] + 1,
                    prev[j] + 1,
                    prev[j - 1] + cost
                )
                if i > 1, j > 1,
                   aChars[i - 1] == bChars[j - 2],
                   aChars[i - 2] == bChars[j - 1] {
                    curr[j] = min(curr[j], prevPrev[j - 2] + cost)
                }
            }
            prevPrev = prev
            prev = curr
            curr = [Int](repeating: 0, count: m + 1)
            curr[0] = i + 1
        }
        return prev[m]
    }
}
