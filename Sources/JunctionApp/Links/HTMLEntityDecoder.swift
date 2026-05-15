import Foundation

enum HTMLEntityDecoder {
    /// Decodes a small set of HTML character references suitable for `<title>` / meta strings.
    static func decode(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex

        while i < s.endIndex {
            if s[i] == "&", let semi = s[i...].firstIndex(of: ";"), semi > i {
                let entityEnd = s.index(after: semi)
                let raw = String(s[s.index(after: i)..<semi])
                if let decoded = decodeEntity(raw) {
                    out.append(decoded)
                    i = entityEnd
                    continue
                }
            }
            out.append(s[i])
            i = s.index(after: i)
        }
        return out
    }

    private static func decodeEntity(_ raw: String) -> Character? {
        if raw.hasPrefix("#x") || raw.hasPrefix("#X") {
            let hex = String(raw.dropFirst(2))
            guard let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else { return nil }
            return Character(scalar)
        }
        if raw.first == "#", raw.count > 1 {
            let digits = String(raw.dropFirst())
            guard let value = UInt32(digits, radix: 10), let scalar = UnicodeScalar(value) else { return nil }
            return Character(scalar)
        }

        switch raw.lowercased() {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return "\u{00A0}"
        default: return nil
        }
    }
}
