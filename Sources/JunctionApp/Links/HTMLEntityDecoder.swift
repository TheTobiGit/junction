import Foundation

enum HTMLEntityDecoder {
    /// Decodes HTML character references found in `<title>` / og: meta strings.
    /// Covers numeric (`&#1234;` / `&#x1F600;`) and the most common named refs
    /// publishers actually emit. Unknown entities are left as-is so the user
    /// at least sees the raw text.
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

    private static func decodeEntity(_ raw: String) -> String? {
        if raw.hasPrefix("#x") || raw.hasPrefix("#X") {
            let hex = String(raw.dropFirst(2))
            guard let value = UInt32(hex, radix: 16), let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }
        if raw.first == "#", raw.count > 1 {
            let digits = String(raw.dropFirst())
            guard let value = UInt32(digits, radix: 10), let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }

        // Named refs are case-sensitive in the HTML spec, but `&AMP;` shows up
        // in practice. Try lowercase first, then exact, before giving up.
        if let v = namedEntities[raw] { return v }
        if let v = namedEntities[raw.lowercased()] { return v }
        return nil
    }

    private static let namedEntities: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": "\u{00A0}",

        "mdash": "\u{2014}",
        "ndash": "\u{2013}",
        "hellip": "\u{2026}",
        "bull": "\u{2022}",
        "middot": "\u{00B7}",

        "lsquo": "\u{2018}",
        "rsquo": "\u{2019}",
        "sbquo": "\u{201A}",
        "ldquo": "\u{201C}",
        "rdquo": "\u{201D}",
        "bdquo": "\u{201E}",
        "laquo": "\u{00AB}",
        "raquo": "\u{00BB}",
        "lsaquo": "\u{2039}",
        "rsaquo": "\u{203A}",

        "copy": "\u{00A9}",
        "reg": "\u{00AE}",
        "trade": "\u{2122}",
        "deg": "\u{00B0}",
        "plusmn": "\u{00B1}",
        "para": "\u{00B6}",
        "sect": "\u{00A7}",
        "iexcl": "\u{00A1}",
        "iquest": "\u{00BF}",

        "cent": "\u{00A2}",
        "pound": "\u{00A3}",
        "yen": "\u{00A5}",
        "euro": "\u{20AC}",
        "curren": "\u{00A4}",

        "frac12": "\u{00BD}",
        "frac14": "\u{00BC}",
        "frac34": "\u{00BE}",

        "times": "\u{00D7}",
        "divide": "\u{00F7}",

        "Aacute": "\u{00C1}", "aacute": "\u{00E1}",
        "Eacute": "\u{00C9}", "eacute": "\u{00E9}",
        "Iacute": "\u{00CD}", "iacute": "\u{00ED}",
        "Oacute": "\u{00D3}", "oacute": "\u{00F3}",
        "Uacute": "\u{00DA}", "uacute": "\u{00FA}",
        "Auml":   "\u{00C4}", "auml":   "\u{00E4}",
        "Euml":   "\u{00CB}", "euml":   "\u{00EB}",
        "Iuml":   "\u{00CF}", "iuml":   "\u{00EF}",
        "Ouml":   "\u{00D6}", "ouml":   "\u{00F6}",
        "Uuml":   "\u{00DC}", "uuml":   "\u{00FC}",
        "Agrave": "\u{00C0}", "agrave": "\u{00E0}",
        "Egrave": "\u{00C8}", "egrave": "\u{00E8}",
        "Igrave": "\u{00CC}", "igrave": "\u{00EC}",
        "Ograve": "\u{00D2}", "ograve": "\u{00F2}",
        "Ugrave": "\u{00D9}", "ugrave": "\u{00F9}",
        "Acirc":  "\u{00C2}", "acirc":  "\u{00E2}",
        "Ecirc":  "\u{00CA}", "ecirc":  "\u{00EA}",
        "Icirc":  "\u{00CE}", "icirc":  "\u{00EE}",
        "Ocirc":  "\u{00D4}", "ocirc":  "\u{00F4}",
        "Ucirc":  "\u{00DB}", "ucirc":  "\u{00FB}",
        "Atilde": "\u{00C3}", "atilde": "\u{00E3}",
        "Ntilde": "\u{00D1}", "ntilde": "\u{00F1}",
        "Otilde": "\u{00D5}", "otilde": "\u{00F5}",
        "Aring":  "\u{00C5}", "aring":  "\u{00E5}",
        "Ccedil": "\u{00C7}", "ccedil": "\u{00E7}",
        "AElig":  "\u{00C6}", "aelig":  "\u{00E6}",
        "Oslash": "\u{00D8}", "oslash": "\u{00F8}",
        "szlig":  "\u{00DF}",
    ]
}
