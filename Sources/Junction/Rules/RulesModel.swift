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
    case ask
}

extension RuleAction: Codable {
    private enum Keys: String, CodingKey { case kind, target }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .open(let t):
            try c.encode("open", forKey: .kind)
            try c.encode(t, forKey: .target)
        case .ask:
            try c.encode("ask", forKey: .kind)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "open":
            self = .open(try c.decode(LaunchTarget.self, forKey: .target))
        case "ask":
            self = .ask
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown action kind: \(kind)"
            )
        }
    }
}

struct DomainRule: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var host: HostMatch
    var action: RuleAction
    var enabled: Bool = true
    var when: RuleCondition? = nil
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
