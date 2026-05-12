import Foundation

public enum AgentConstants {
    public static let socketName = "agent.sock"

    public static var socketURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/Application Support/Junction", isDirectory: true)
            .appendingPathComponent(socketName)
    }
}

public enum AgentRequest: Codable, Sendable {
    case ping
    case open(url: String, inTarget: String?, ask: Bool, clean: Bool?)
    case listRules
    case listTargets
    case addRule(hostKind: String, hostValue: String, target: String?)
    case removeRule(hostValue: String)

    private enum Keys: String, CodingKey { case kind, url, inTarget, ask, clean, hostKind, hostValue, target }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .ping:
            try c.encode("ping", forKey: .kind)
        case .open(let url, let inTarget, let ask, let clean):
            try c.encode("open", forKey: .kind)
            try c.encode(url, forKey: .url)
            try c.encodeIfPresent(inTarget, forKey: .inTarget)
            try c.encode(ask, forKey: .ask)
            try c.encodeIfPresent(clean, forKey: .clean)
        case .listRules:
            try c.encode("listRules", forKey: .kind)
        case .listTargets:
            try c.encode("listTargets", forKey: .kind)
        case .addRule(let hostKind, let hostValue, let target):
            try c.encode("addRule", forKey: .kind)
            try c.encode(hostKind, forKey: .hostKind)
            try c.encode(hostValue, forKey: .hostValue)
            try c.encodeIfPresent(target, forKey: .target)
        case .removeRule(let hostValue):
            try c.encode("removeRule", forKey: .kind)
            try c.encode(hostValue, forKey: .hostValue)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "ping":
            self = .ping
        case "open":
            self = .open(
                url: try c.decode(String.self, forKey: .url),
                inTarget: try c.decodeIfPresent(String.self, forKey: .inTarget),
                ask: try c.decode(Bool.self, forKey: .ask),
                clean: try c.decodeIfPresent(Bool.self, forKey: .clean)
            )
        case "listRules":
            self = .listRules
        case "listTargets":
            self = .listTargets
        case "addRule":
            self = .addRule(
                hostKind: try c.decode(String.self, forKey: .hostKind),
                hostValue: try c.decode(String.self, forKey: .hostValue),
                target: try c.decodeIfPresent(String.self, forKey: .target)
            )
        case "removeRule":
            self = .removeRule(hostValue: try c.decode(String.self, forKey: .hostValue))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown request kind: \(kind)"
            )
        }
    }
}

public struct AgentRuleSummary: Codable, Sendable {
    public let hostKind: String
    public let hostValue: String
    public let action: String
    public init(hostKind: String, hostValue: String, action: String) {
        self.hostKind = hostKind
        self.hostValue = hostValue
        self.action = action
    }
}

public struct AgentTargetSummary: Codable, Sendable {
    public let key: String
    public let displayName: String
    public init(key: String, displayName: String) {
        self.key = key
        self.displayName = displayName
    }
}

public enum AgentResponse: Codable, Sendable {
    case pong
    case ok(message: String?)
    case rules([AgentRuleSummary])
    case targets([AgentTargetSummary])
    case error(String)

    private enum Keys: String, CodingKey { case kind, message, rules, targets }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        switch self {
        case .pong:
            try c.encode("pong", forKey: .kind)
        case .ok(let m):
            try c.encode("ok", forKey: .kind)
            try c.encodeIfPresent(m, forKey: .message)
        case .rules(let r):
            try c.encode("rules", forKey: .kind)
            try c.encode(r, forKey: .rules)
        case .targets(let t):
            try c.encode("targets", forKey: .kind)
            try c.encode(t, forKey: .targets)
        case .error(let m):
            try c.encode("error", forKey: .kind)
            try c.encode(m, forKey: .message)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "pong": self = .pong
        case "ok":   self = .ok(message: try c.decodeIfPresent(String.self, forKey: .message))
        case "rules":   self = .rules(try c.decode([AgentRuleSummary].self, forKey: .rules))
        case "targets": self = .targets(try c.decode([AgentTargetSummary].self, forKey: .targets))
        case "error":   self = .error(try c.decode(String.self, forKey: .message))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown response kind: \(kind)"
            )
        }
    }
}

public enum AgentCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: line)
    }
}
