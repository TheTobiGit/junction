import Foundation

enum LaunchTarget: Hashable, Codable {
    case app(bundleID: String)
    case profile(bundleID: String, profileID: String, label: String, colorHex: String?)

    var bundleID: String {
        switch self {
        case .app(let b), .profile(let b, _, _, _): return b
        }
    }

    var profileID: String? {
        if case .profile(_, let id, _, _) = self { return id }
        return nil
    }

    var storageKey: String {
        switch self {
        case .app(let b): return "app:\(b)"
        case .profile(let b, let p, _, _): return "profile:\(b):\(p)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case kind, bundleID, profileID, label, colorHex
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let bundleID):
            try c.encode("app", forKey: .kind)
            try c.encode(bundleID, forKey: .bundleID)
        case .profile(let bundleID, let profileID, let label, let colorHex):
            try c.encode("profile", forKey: .kind)
            try c.encode(bundleID, forKey: .bundleID)
            try c.encode(profileID, forKey: .profileID)
            try c.encode(label, forKey: .label)
            try c.encodeIfPresent(colorHex, forKey: .colorHex)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "app":
            self = .app(bundleID: try c.decode(String.self, forKey: .bundleID))
        case "profile":
            self = .profile(
                bundleID: try c.decode(String.self, forKey: .bundleID),
                profileID: try c.decode(String.self, forKey: .profileID),
                label: try c.decode(String.self, forKey: .label),
                colorHex: try c.decodeIfPresent(String.self, forKey: .colorHex)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind, in: c,
                debugDescription: "Unknown LaunchTarget kind: \(kind)"
            )
        }
    }
}
