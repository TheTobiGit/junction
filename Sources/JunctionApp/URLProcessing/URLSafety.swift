import Foundation
import Darwin

/// Centralized URL safety checks: scheme allow-listing for routing, plus
/// "is this host publicly routable?" so we never follow a shortener (or any
/// other transformer) into a private/loopback/link-local target.
enum URLSafety {
    /// Schemes Junction will deliver to a browser/app without an explicit rule.
    /// Anything else must be opt-in via a per-host rule (e.g. ``RuleAction/appScheme``).
    static let routableSchemes: Set<String> = ["http", "https"]

    static func isRoutableWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        guard routableSchemes.contains(scheme) else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return true
    }

    /// True when `host` looks like a public destination: not loopback, not
    /// private RFC1918, not link-local, not the AWS-style metadata IP, and not
    /// a "test"/"local" suffix that should never leave the machine.
    /// IDNs are accepted (they may resolve later); IP literals are rejected
    /// when they fall in private ranges.
    static func isPubliclyRoutableHost(_ rawHost: String) -> Bool {
        var host = rawHost.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("[") && host.hasSuffix("]") {
            host.removeFirst()
            host.removeLast()
        }
        // DNS allows trailing dots ("example.com.", "localhost.") to mark
        // fully-qualified names; resolvers strip them. We must too — otherwise
        // `localhost.` slips past the bare-name and IP-literal checks below.
        while host.hasSuffix(".") { host.removeLast() }
        guard !host.isEmpty else { return false }

        if let ipv4 = parseIPv4(host) ?? parseIPv4Loose(host) {
            return !isPrivateIPv4(ipv4)
        }
        if let ipv6 = parseIPv6(host) { return !isPrivateIPv6(ipv6) }

        let blockedSuffixes: [String] = [
            ".corp", ".example", ".home", ".home.arpa", ".invalid",
            ".internal", ".intranet", ".lan", ".local", ".localhost",
            ".onion", ".test",
        ]
        for suffix in blockedSuffixes where host.hasSuffix(suffix) {
            return false
        }
        if host == "localhost" { return false }

        // Bare hostnames (no dot) usually resolve via mDNS / search domain — treat
        // as private. Public destinations always have at least one dot.
        guard host.contains(".") else { return false }
        return true
    }

    static func isPubliclyRoutable(_ url: URL) -> Bool {
        guard isRoutableWebURL(url) else { return false }
        guard let host = url.host else { return false }
        return isPubliclyRoutableHost(host)
    }

    // MARK: - IPv4

    static func parseIPv4(_ s: String) -> in_addr? {
        var addr = in_addr()
        let ok = s.withCString { inet_pton(AF_INET, $0, &addr) }
        return ok == 1 ? addr : nil
    }

    /// Loose IPv4 parser that accepts the legacy notations system resolvers
    /// still honor: `127.1`, `0x7f.0.0.1`, `192.168.1`, `2130706433`, octal
    /// `0177.0.0.1`. `inet_aton(3)` understands all of these; `inet_pton(3)`
    /// (used by ``parseIPv4``) only accepts strict dotted-quad. Without this
    /// the SSRF guard can be bypassed by writing the private address in a
    /// non-canonical form that the OS still resolves to loopback / RFC1918.
    private static func parseIPv4Loose(_ s: String) -> in_addr? {
        var addr = in_addr()
        let ok = s.withCString { inet_aton($0, &addr) }
        return ok != 0 ? addr : nil
    }

    private static func isPrivateIPv4(_ addr: in_addr) -> Bool {
        let host = UInt32(bigEndian: addr.s_addr)
        let a = UInt8((host >> 24) & 0xFF)
        let b = UInt8((host >> 16) & 0xFF)

        if a == 10 { return true }                                  // 10.0.0.0/8
        if a == 127 { return true }                                 // 127.0.0.0/8 loopback
        if a == 169 && b == 254 { return true }                     // 169.254.0.0/16 link-local + AWS metadata
        if a == 172 && (16...31).contains(Int(b)) { return true }   // 172.16.0.0/12
        if a == 192 && b == 168 { return true }                     // 192.168.0.0/16
        if a == 192 && b == 0 { return true }                       // 192.0.0.0/24 + 192.0.2.0/24 (TEST-NET-1)
        if a == 198 && (b == 18 || b == 19) { return true }         // 198.18.0.0/15 benchmark
        if a == 198 && b == 51 { return true }                      // 198.51.100.0/24 TEST-NET-2
        if a == 203 && b == 0 { return true }                       // 203.0.113.0/24 TEST-NET-3
        if a >= 224 { return true }                                 // 224.0.0.0/4 multicast + 240/4 reserved
        if host == 0 { return true }                                // 0.0.0.0
        return false
    }

    // MARK: - IPv6

    private static func parseIPv6(_ s: String) -> in6_addr? {
        var addr = in6_addr()
        let ok = s.withCString { inet_pton(AF_INET6, $0, &addr) }
        return ok == 1 ? addr : nil
    }

    private static func isPrivateIPv6(_ addr: in6_addr) -> Bool {
        let bytes = withUnsafeBytes(of: addr) { Array($0) }
        guard bytes.count == 16 else { return true }
        if bytes.allSatisfy({ $0 == 0 }) { return true }            // ::
        if bytes[0..<15].allSatisfy({ $0 == 0 }) && bytes[15] == 1 { return true } // ::1 loopback
        if bytes[0] == 0xfe && (bytes[1] & 0xC0) == 0x80 { return true }           // fe80::/10 link-local
        if (bytes[0] & 0xFE) == 0xfc { return true }                               // fc00::/7 unique local
        if bytes[0] == 0xff { return true }                                        // ff00::/8 multicast
        // IPv4-mapped (::ffff:a.b.c.d) — treat as the IPv4 it wraps.
        if bytes[0..<10].allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
            var v4 = in_addr()
            v4.s_addr = (UInt32(bytes[12]) << 24
                       | UInt32(bytes[13]) << 16
                       | UInt32(bytes[14]) << 8
                       | UInt32(bytes[15])).bigEndian
            return isPrivateIPv4(v4)
        }
        return false
    }
}
