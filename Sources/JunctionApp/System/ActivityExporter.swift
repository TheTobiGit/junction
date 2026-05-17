import Foundation

enum ActivityExporter {

    static func json(entries: [RoutingHistory.Entry]) -> Data {
        guard !entries.isEmpty else { return Data("[]".utf8) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(entries)) ?? Data("[]".utf8)
    }

    static func csv(entries: [RoutingHistory.Entry]) -> String {
        let header = "id,timestamp,originalURL,cleanedURL,outcome,targetBundleID,ruleLabel,cleaningSteps,sourceBundleID,targetStorageKey"
        guard !entries.isEmpty else { return header }
        let formatter = ISO8601DateFormatter()
        let rows = entries.map { entry -> String in
            let fields: [String] = [
                entry.id.uuidString,
                formatter.string(from: entry.timestamp),
                entry.originalURL,
                entry.cleanedURL,
                entry.outcome.rawValue,
                entry.targetBundleID ?? "",
                entry.ruleLabel ?? "",
                entry.cleaningSteps.joined(separator: ";"),
                entry.sourceBundleID ?? "",
                entry.targetStorageKey ?? "",
            ]
            return fields.map(rfc4180Escape).joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\r\n")
    }

    private static func rfc4180Escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
