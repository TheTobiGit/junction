import Foundation

public enum AgentConstants {
    public static let socketName = "agent.sock"

    public static var socketURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let processName = ProcessInfo.processInfo.processName.lowercased()
        let isPreview = bundleID.contains("Preview") || processName.contains("preview")
        let appSupportFolder = isPreview ? "JunctionPreview" : "Junction"
        return home
            .appendingPathComponent("Library/Application Support/\(appSupportFolder)", isDirectory: true)
            .appendingPathComponent(socketName)
    }
}

public enum AgentRequest: Codable, Sendable {
    case ping
    case open(url: String, inTarget: String?, ask: Bool, clean: Bool?)
    case listRules
    case listTargets
    case addRule(hostKind: String, hostValue: String, target: String?, cleanOverride: Bool?, pathKind: String?, pathValue: String?, sourceApps: [String]?)
    case removeRule(hostValue: String)
    case inspect(url: String)
    case listHistory(limit: Int)

    private enum Keys: String, CodingKey { case kind, url, inTarget, ask, clean, hostKind, hostValue, target, limit, cleanOverride, pathKind, pathValue, sourceApps }

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
        case .addRule(let hostKind, let hostValue, let target, let cleanOverride, let pathKind, let pathValue, let sourceApps):
            try c.encode("addRule", forKey: .kind)
            try c.encode(hostKind, forKey: .hostKind)
            try c.encode(hostValue, forKey: .hostValue)
            try c.encodeIfPresent(target, forKey: .target)
            try c.encodeIfPresent(cleanOverride, forKey: .cleanOverride)
            try c.encodeIfPresent(pathKind, forKey: .pathKind)
            try c.encodeIfPresent(pathValue, forKey: .pathValue)
            try c.encodeIfPresent(sourceApps, forKey: .sourceApps)
        case .removeRule(let hostValue):
            try c.encode("removeRule", forKey: .kind)
            try c.encode(hostValue, forKey: .hostValue)
        case .inspect(let url):
            try c.encode("inspect", forKey: .kind)
            try c.encode(url, forKey: .url)
        case .listHistory(let limit):
            try c.encode("listHistory", forKey: .kind)
            try c.encode(limit, forKey: .limit)
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
                target: try c.decodeIfPresent(String.self, forKey: .target),
                cleanOverride: (try? c.decodeIfPresent(Bool.self, forKey: .cleanOverride)) ?? nil,
                pathKind: (try? c.decodeIfPresent(String.self, forKey: .pathKind)) ?? nil,
                pathValue: (try? c.decodeIfPresent(String.self, forKey: .pathValue)) ?? nil,
                sourceApps: (try? c.decodeIfPresent([String].self, forKey: .sourceApps)) ?? nil
            )
        case "removeRule":
            self = .removeRule(hostValue: try c.decode(String.self, forKey: .hostValue))
        case "inspect":
            self = .inspect(url: try c.decode(String.self, forKey: .url))
        case "listHistory":
            self = .listHistory(limit: (try? c.decode(Int.self, forKey: .limit)) ?? 20)
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
    public let cleanOverride: Bool?
    public init(hostKind: String, hostValue: String, action: String, cleanOverride: Bool? = nil) {
        self.hostKind = hostKind
        self.hostValue = hostValue
        self.action = action
        self.cleanOverride = cleanOverride
    }

    private enum CodingKeys: String, CodingKey { case hostKind, hostValue, action, cleanOverride }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.hostKind = try c.decode(String.self, forKey: .hostKind)
        self.hostValue = try c.decode(String.self, forKey: .hostValue)
        self.action = try c.decode(String.self, forKey: .action)
        // Older agents won't include this; default to nil.
        self.cleanOverride = (try? c.decodeIfPresent(Bool.self, forKey: .cleanOverride)) ?? nil
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

public struct AgentInspectStep: Codable, Sendable {
    public let identifier: String
    public let after: String
    public init(identifier: String, after: String) {
        self.identifier = identifier
        self.after = after
    }
}

public struct AgentInspectFlag: Codable, Sendable {
    public let level: String
    public let title: String
    public let detail: String
    public init(level: String, title: String, detail: String) {
        self.level = level
        self.title = title
        self.detail = detail
    }
}

public struct AgentInspectResult: Codable, Sendable {
    public let original: String
    public let cleaned: String
    public let steps: [AgentInspectStep]
    public let flags: [AgentInspectFlag]
    public let strippedTrackerParams: [String]
    public init(
        original: String,
        cleaned: String,
        steps: [AgentInspectStep],
        flags: [AgentInspectFlag],
        strippedTrackerParams: [String] = []
    ) {
        self.original = original
        self.cleaned = cleaned
        self.steps = steps
        self.flags = flags
        self.strippedTrackerParams = strippedTrackerParams
    }

    private enum CodingKeys: String, CodingKey {
        case original, cleaned, steps, flags, strippedTrackerParams
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.original = try c.decode(String.self, forKey: .original)
        self.cleaned = try c.decode(String.self, forKey: .cleaned)
        self.steps = try c.decode([AgentInspectStep].self, forKey: .steps)
        self.flags = try c.decode([AgentInspectFlag].self, forKey: .flags)
        // Older agents won't send this field; default to empty for forward
        // compatibility on older `junction` binaries talking to a new app.
        self.strippedTrackerParams = (try? c.decode([String].self, forKey: .strippedTrackerParams)) ?? []
    }
}

public struct AgentHistoryEntry: Codable, Sendable {
    public let timestamp: Date
    public let originalURL: String
    public let cleanedURL: String
    public let outcome: String
    public let targetBundleID: String?
    public let ruleLabel: String?
    public let cleaningSteps: [String]

    public init(
        timestamp: Date,
        originalURL: String,
        cleanedURL: String,
        outcome: String,
        targetBundleID: String?,
        ruleLabel: String?,
        cleaningSteps: [String]
    ) {
        self.timestamp = timestamp
        self.originalURL = originalURL
        self.cleanedURL = cleanedURL
        self.outcome = outcome
        self.targetBundleID = targetBundleID
        self.ruleLabel = ruleLabel
        self.cleaningSteps = cleaningSteps
    }
}

public enum AgentResponse: Codable, Sendable {
    case pong
    case ok(message: String?)
    case rules([AgentRuleSummary])
    case targets([AgentTargetSummary])
    case error(String)
    case inspectResult(AgentInspectResult)
    case history([AgentHistoryEntry])

    private enum Keys: String, CodingKey { case kind, message, rules, targets, inspect, history }

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
        case .inspectResult(let r):
            try c.encode("inspect", forKey: .kind)
            try c.encode(r, forKey: .inspect)
        case .history(let h):
            try c.encode("history", forKey: .kind)
            try c.encode(h, forKey: .history)
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
        case "inspect":
            self = .inspectResult(try c.decode(AgentInspectResult.self, forKey: .inspect))
        case "history":
            self = .history(try c.decode([AgentHistoryEntry].self, forKey: .history))
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
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    public static func decode<T: Decodable>(_ type: T.Type, from line: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: line)
    }
}
