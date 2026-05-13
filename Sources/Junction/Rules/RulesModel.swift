import Foundation

enum HostMatch: Hashable {
    case equals(String)
    case suffix(String)
    case regex(String)

    func matches(_ host: String) -> Bool {
        let target = host.lowercased()
        switch self {
        case .equals(let s):
            return target == s.lowercased()
        case .suffix(let s):
            let needle = s.lowercased()
            return target == needle || target.hasSuffix("." + needle)
        case .regex(let pattern):
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
            let range = NSRange(target.startIndex..<target.endIndex, in: target)
            return re.firstMatch(in: target, options: [], range: range) != nil
        }
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

    enum CodingKeys: String, CodingKey {
        case id, host, action, enabled, when, schemes, path, queryContains, alsoCopyCleaned
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
        alsoCopyCleaned: Bool = false
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
    }

    func matches(url: URL, host resolvedHost: String?, context: RouteContext) -> Bool {
        guard enabled else { return false }

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
