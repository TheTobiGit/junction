import Foundation

enum HostMatch: Hashable {
    case equals(String)
    case suffix(String)
    case regex(String)

    func matches(_ host: String) -> Bool {
        let target = IDNA.toUnicode(host: HostMatch.canonicalize(host))
        switch self {
        case .equals(let s):
            return target == IDNA.toUnicode(host: HostMatch.canonicalize(s))
        case .suffix(let s):
            let needle = IDNA.toUnicode(host: HostMatch.canonicalize(s))
            return target == needle || target.hasSuffix("." + needle)
        case .regex(let pattern):
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
            let range = NSRange(target.startIndex..<target.endIndex, in: target)
            return re.firstMatch(in: target, options: [], range: range) != nil
        }
    }

    /// Lowercase + strip trailing DNS dots so an FQDN form ("example.com.")
    /// matches rules keyed on the canonical "example.com".
    private static func canonicalize(_ host: String) -> String {
        var lowered = host.lowercased()
        while lowered.hasSuffix(".") { lowered.removeLast() }
        return lowered
    }

    var displayValue: String {
        switch self {
        case .equals(let v), .suffix(let v), .regex(let v): return v
        }
    }

    var kindLabel: String {
        switch self {
        case .equals: return "equals"
        case .suffix: return "suffix"
        case .regex: return "regex"
        }
    }
}

extension HostMatch: Codable {
    private enum Keys: String, CodingKey { case kind, value }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .equals(let v): try c.encode("equals", forKey: .kind); try c.encode(v, forKey: .value)
        case .suffix(let v): try c.encode("suffix", forKey: .kind); try c.encode(v, forKey: .value)
        case .regex(let v):  try c.encode("regex", forKey: .kind);  try c.encode(v, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let value = try c.decode(String.self, forKey: .value)
        switch kind {
        case "equals": self = .equals(value)
        case "suffix": self = .suffix(value)
        case "regex":  self = .regex(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown host match kind: \(kind)"
            )
        }
    }
}

enum RuleAction: Hashable {
    case open(LaunchTarget)
    case openIncognito(LaunchTarget)
    case ask
    case block
    case appScheme(String)

    var label: String {
        switch self {
        case .open: return "open"
        case .openIncognito: return "incognito"
        case .ask: return "ask"
        case .block: return "block"
        case .appScheme(let s): return "app:\(s)"
        }
    }
}

extension RuleAction: Codable {
    private enum Keys: String, CodingKey { case kind, target, scheme }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .open(let t):
            try c.encode("open", forKey: .kind)
            try c.encode(t, forKey: .target)
        case .openIncognito(let t):
            try c.encode("openIncognito", forKey: .kind)
            try c.encode(t, forKey: .target)
        case .ask:
            try c.encode("ask", forKey: .kind)
        case .block:
            try c.encode("block", forKey: .kind)
        case .appScheme(let s):
            try c.encode("appScheme", forKey: .kind)
            try c.encode(s, forKey: .scheme)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "open":
            self = .open(try c.decode(LaunchTarget.self, forKey: .target))
        case "openIncognito":
            self = .openIncognito(try c.decode(LaunchTarget.self, forKey: .target))
        case "ask":
            self = .ask
        case "block":
            self = .block
        case "appScheme":
            self = .appScheme(try c.decode(String.self, forKey: .scheme))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown action kind: \(kind)"
            )
        }
    }
}

enum URLPathMatch: Codable, Hashable {
    case prefix(String)
    case contains(String)
    case regex(String)
    case glob(String)

    private enum Keys: String, CodingKey { case kind, value }

    func matches(_ path: String) -> Bool {
        let target = path
        switch self {
        case .prefix(let v): return target.hasPrefix(v)
        case .contains(let v): return target.contains(v)
        case .regex(let v):
            guard let re = try? NSRegularExpression(pattern: v) else { return false }
            let range = NSRange(target.startIndex..<target.endIndex, in: target)
            return re.firstMatch(in: target, range: range) != nil
        case .glob(let pattern):
            return URLPathMatch.globMatches(pattern: pattern, in: target)
        }
    }

    var displayValue: String {
        switch self {
        case .prefix(let v), .contains(let v), .regex(let v), .glob(let v): return v
        }
    }

    var kindLabel: String {
        switch self {
        case .prefix: return "prefix"
        case .contains: return "contains"
        case .regex: return "regex"
        case .glob: return "glob"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .prefix(let v): try c.encode("prefix", forKey: .kind); try c.encode(v, forKey: .value)
        case .contains(let v): try c.encode("contains", forKey: .kind); try c.encode(v, forKey: .value)
        case .regex(let v): try c.encode("regex", forKey: .kind); try c.encode(v, forKey: .value)
        case .glob(let v): try c.encode("glob", forKey: .kind); try c.encode(v, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let value = try c.decode(String.self, forKey: .value)
        switch kind {
        case "prefix": self = .prefix(value)
        case "contains": self = .contains(value)
        case "regex": self = .regex(value)
        case "glob": self = .glob(value)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown path match kind: \(kind)"
            )
        }
    }

    /// Builds a `URLPathMatch` from a kind string and value. Returns `nil`
    /// for unknown kind strings so callers can surface a clean error.
    static func from(kind: String, value: String) -> URLPathMatch? {
        switch kind {
        case "prefix":   return .prefix(value)
        case "contains": return .contains(value)
        case "regex":    return .regex(value)
        case "glob":     return .glob(value)
        default:         return nil
        }
    }

    private static func globMatches(pattern: String, in text: String) -> Bool {
        var regex = "^"
        for ch in pattern {
            switch ch {
            case "*": regex += ".*"
            case "?": regex += "."
            case ".", "+", "(", ")", "[", "]", "{", "}", "|", "^", "$", "\\":
                regex += "\\\(ch)"
            default:
                regex.append(ch)
            }
        }
        regex += "$"
        guard let re = try? NSRegularExpression(pattern: regex) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return re.firstMatch(in: text, range: range) != nil
    }
}

struct DomainRule: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var host: HostMatch
    var action: RuleAction
    var enabled: Bool = true
    var when: RuleCondition? = nil
    var schemes: [String]? = nil
    var path: URLPathMatch? = nil
    var queryContains: String? = nil
    var alsoCopyCleaned: Bool = false
    /// Per-rule override of `cleanURLsBeforeOpening`. `nil` means "use the
    /// global setting"; `true`/`false` force on/off for matched URLs. Useful
    /// for "never clean my internal `myinternal.example.com`" or "always
    /// clean even when global cleaning is off for this host".
    var cleanOverride: Bool? = nil
    /// When set, the rule matches **only** the exact URL specified (after
    /// minimal canonicalization: lowercase scheme/host, strip default port,
    /// strip URL fragment, treat `/` and empty path as equivalent). When
    /// `urlEquals` is set, `host` / `path` / `queryContains` / `schemes` are
    /// all ignored — exact matches by definition specify the full URL.
    /// `enabled` and `when` are still honored.
    var urlEquals: String? = nil
    var trackerOverrides: TrackerOverrides? = nil

    enum CodingKeys: String, CodingKey {
        case id, host, action, enabled, when, schemes, path, queryContains, alsoCopyCleaned, cleanOverride, urlEquals, trackerOverrides
    }

    init(
        id: UUID = UUID(),
        host: HostMatch,
        action: RuleAction,
        enabled: Bool = true,
        when: RuleCondition? = nil,
        schemes: [String]? = nil,
        path: URLPathMatch? = nil,
        queryContains: String? = nil,
        alsoCopyCleaned: Bool = false,
        cleanOverride: Bool? = nil,
        urlEquals: String? = nil,
        trackerOverrides: TrackerOverrides? = nil
    ) {
        self.id = id
        self.host = host
        self.action = action
        self.enabled = enabled
        self.when = when
        self.schemes = schemes
        self.path = path
        self.queryContains = queryContains
        self.alsoCopyCleaned = alsoCopyCleaned
        self.cleanOverride = cleanOverride
        self.urlEquals = urlEquals
        self.trackerOverrides = trackerOverrides
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.host = try c.decode(HostMatch.self, forKey: .host)
        self.action = try c.decode(RuleAction.self, forKey: .action)
        self.enabled = (try? c.decode(Bool.self, forKey: .enabled)) ?? true
        self.when = try? c.decodeIfPresent(RuleCondition.self, forKey: .when)
        self.schemes = try? c.decodeIfPresent([String].self, forKey: .schemes)
        self.path = try? c.decodeIfPresent(URLPathMatch.self, forKey: .path)
        self.queryContains = try? c.decodeIfPresent(String.self, forKey: .queryContains)
        self.alsoCopyCleaned = (try? c.decode(Bool.self, forKey: .alsoCopyCleaned)) ?? false
        self.cleanOverride = try? c.decodeIfPresent(Bool.self, forKey: .cleanOverride)
        self.urlEquals = try? c.decodeIfPresent(String.self, forKey: .urlEquals)
        self.trackerOverrides = try? c.decodeIfPresent(TrackerOverrides.self, forKey: .trackerOverrides)
    }

    func matches(url: URL, host resolvedHost: String?, context: RouteContext) -> Bool {
        guard enabled else { return false }

        // Exact URL match short-circuits the host/path/query/scheme filter
        // chain — the user picked "this one URL specifically" and that
        // intent should not be diluted by per-component checks. `when`
        // still applies so source-app / focus filtering works for these.
        if let target = urlEquals {
            guard DomainRule.urlsMatchExactly(url, target: target) else { return false }
            if let condition = when, !condition.matches(context: context) {
                return false
            }
            return true
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if let schemes, !schemes.isEmpty {
            let allowed = Set(schemes.map { $0.lowercased() })
            guard allowed.contains(scheme) else { return false }
        } else {
            let isWebScheme = scheme == "http" || scheme == "https"
            guard isWebScheme || resolvedHost != nil else { return false }
        }

        if let resolvedHost {
            guard host.matches(resolvedHost) else { return false }
        } else if schemes == nil {
            return false
        }

        if let path {
            let p = url.path.isEmpty ? "/" : url.path
            guard path.matches(p) else { return false }
        }

        if let queryContains, !queryContains.isEmpty {
            let q = url.query ?? ""
            guard q.lowercased().contains(queryContains.lowercased()) else { return false }
        }

        if let condition = when, !condition.matches(context: context) {
            return false
        }

        return true
    }

    /// Resolves "should we open the cleaned URL" for this rule, given the
    /// global ``JunctionSettings.cleanURLsBeforeOpening`` setting. The
    /// per-rule override (if set) wins; otherwise we fall back to the global
    /// preference. Surfaced statically because the picker, the agent's
    /// `routeAgent`, and `routeAfterExpansion` all need the same resolution.
    static func resolveCleanFlag(rule: DomainRule?, globalEnabled: Bool) -> Bool {
        rule?.cleanOverride ?? globalEnabled
    }

    /// True when `url` matches `target` under the canonicalization rules
    /// documented on `urlEquals`. Exposed `static` so the matcher and the
    /// add-rule sheet's "Did you mean…?" hint can share one implementation.
    static func urlsMatchExactly(_ url: URL, target: String) -> Bool {
        guard let lhs = canonicalURLString(url),
              let targetURL = URL(string: target),
              let rhs = canonicalURLString(targetURL)
        else { return false }
        return lhs == rhs
    }

    /// Minimal RFC-aware canonicalization: lowercase scheme + host (both are
    /// case-insensitive per RFC 3986), strip default ports (`:80` for http,
    /// `:443` for https), strip the URL fragment (client-side only), and
    /// treat `/` and `""` as the same path. Path and query stay
    /// case-sensitive — servers differ on whether they're case-folding, so
    /// we play it strict.
    static func canonicalURLString(_ url: URL) -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        components.fragment = nil
        if let scheme = components.scheme {
            if scheme == "http",  components.port == 80  { components.port = nil }
            if scheme == "https", components.port == 443 { components.port = nil }
        }
        if components.path == "/" { components.path = "" }
        return components.url?.absoluteString
    }

    /// Human-readable kind label for both Rules UI and CLI/agent summaries.
    /// `urlEquals` rules report as `url`; path-bearing rules append the path
    /// kind so the Settings tab and `junction rules list` render distinct
    /// labels for path-bearing vs path-less rules.
    var kindLabel: String {
        if urlEquals != nil { return "url" }
        if let path { return "\(host.kindLabel)+\(path.kindLabel)" }
        return host.kindLabel
    }

    /// Human-readable value the row should show. For exact-URL rules this
    /// is the full URL; otherwise it's the host pattern.
    var displayValue: String {
        urlEquals ?? host.displayValue
    }

    /// Stable key for deduplicating rules when adding. Two exact-URL rules
    /// with the same target replace each other; two host rules with the same
    /// `kind:host:pathKind:pathValue` replace each other; a path-bearing rule
    /// and an otherwise-identical path-less rule never collide. Distinct
    /// `when` conditions (e.g. different source apps) never collide.
    var dedupKey: String {
        let whenPart = Self.whenDedupPart(when)
        if let urlEquals {
            return "url:\(urlEquals.lowercased())\(whenPart)"
        }
        let pathPart = path.map { ":\($0.kindLabel):\($0.displayValue)" } ?? ""
        return "\(host.kindLabel):\(host.displayValue.lowercased())\(pathPart)\(whenPart)"
    }

    private static func whenDedupPart(_ when: RuleCondition?) -> String {
        guard let when else { return "" }
        var parts: [String] = []
        if let apps = when.sourceApp, !apps.isEmpty {
            parts.append("src:" + apps.map { $0.lowercased() }.sorted().joined(separator: ","))
        }
        if let focus = when.focus, !focus.isEmpty {
            parts.append("focus:" + focus.map { $0.lowercased() }.sorted().joined(separator: ","))
        }
        guard !parts.isEmpty else { return "" }
        return ":" + parts.joined(separator: ":")
    }
}

struct RuleCondition: Codable, Hashable {
    var sourceApp: [String]? = nil
    var focus: [String]? = nil

    func matches(context: RouteContext) -> Bool {
        if let expected = sourceApp, !expected.isEmpty {
            guard let bid = context.source?.bundleID,
                  expected.contains(where: { $0.lowercased() == bid.lowercased() })
            else { return false }
        }
        if let expected = focus, !expected.isEmpty {
            guard let mode = context.focus.modeIdentifier,
                  expected.contains(where: {
                      mode.lowercased().contains($0.lowercased())
                  })
            else { return false }
        }
        return true
    }
}

struct RouteContext {
    var source: URLSource?
    var focus: FocusInfo
}

struct RulesFile: Codable {
    var version: Int = 1
    var rules: [DomainRule] = []
    var fallback: RuleAction = .ask
}
