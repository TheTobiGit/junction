import Foundation

struct FocusInfo: Equatable {
    let modeIdentifier: String?
    let modeName: String?

    var isActive: Bool { modeIdentifier != nil }
}

enum FocusTracker {
    static func current(
        rules: [DomainRule] = RulesStore.shared.rules.rules,
        read: (URL) -> Data? = { try? Data(contentsOf: $0) }
    ) -> FocusInfo {
        guard rules.contains(where: { $0.when?.focus?.isEmpty == false }) else {
            return FocusInfo(modeIdentifier: nil, modeName: nil)
        }
        let assertionsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")

        guard let data = read(assertionsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = obj["data"] as? [[String: Any]]
        else {
            return FocusInfo(modeIdentifier: nil, modeName: nil)
        }

        for record in records {
            guard let assertions = record["storeAssertionRecords"] as? [[String: Any]] else { continue }
            for assertion in assertions {
                if let details = assertion["assertionDetails"] as? [String: Any],
                   let modeID = details["assertionDetailsModeIdentifier"] as? String {
                    return FocusInfo(modeIdentifier: modeID, modeName: nameFromIdentifier(modeID))
                }
            }
        }
        return FocusInfo(modeIdentifier: nil, modeName: nil)
    }

    private static func nameFromIdentifier(_ id: String) -> String? {
        let parts = id.split(separator: ".")
        if let last = parts.last { return String(last).capitalized }
        return id
    }
}

