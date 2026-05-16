import Foundation

/// Minimal IDNA helper: decodes `xn--`-prefixed Punycode labels per RFC 3492 so
/// risk warnings can render the human-readable host, and rule matching can
/// canonicalize both ASCII and Unicode forms to a single value.
///
/// Encoding (Unicode → ASCII) is intentionally not implemented; storing rules
/// in their decoded Unicode form and folding URL hosts the same way is enough
/// for byte-identical comparison.
enum IDNA {
    private static let base = 36
    private static let tmin = 1
    private static let tmax = 26
    private static let skew = 38
    private static let damp = 700
    private static let initialBias = 72
    private static let initialN: UInt32 = 0x80
    private static let prefix = "xn--"

    /// Decodes any `xn--<…>` labels in `host` to their Unicode form. Labels
    /// that fail to decode are kept as-is so the caller can still see them.
    static func toUnicode(host: String) -> String {
        guard !host.isEmpty else { return host }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let decoded = labels.map { label -> String in
            let s = String(label).lowercased()
            guard s.hasPrefix(prefix) else { return s }
            let payload = String(s.dropFirst(prefix.count))
            return decodePunycodeLabel(payload) ?? s
        }
        return decoded.joined(separator: ".")
    }

    private static func decodePunycodeLabel(_ input: String) -> String? {
        var n = initialN
        var i: UInt32 = 0
        var bias = initialBias
        var output: [UnicodeScalar] = []

        var encoded = Array(input.unicodeScalars)
        if let lastDash = encoded.lastIndex(of: "-") {
            for scalar in encoded[..<lastDash] {
                guard isBasic(scalar) else { return nil }
                output.append(scalar)
            }
            encoded.removeSubrange(0...lastDash)
        }

        var idx = 0
        while idx < encoded.count {
            let oldi = i
            var w: UInt32 = 1
            var k = base
            while true {
                guard idx < encoded.count else { return nil }
                let scalar = encoded[idx]
                idx += 1
                guard let digit = digitValue(scalar) else { return nil }
                let addition = UInt64(digit) * UInt64(w)
                let nextI = UInt64(i) + addition
                guard nextI <= UInt64(UInt32.max) else { return nil }
                i = UInt32(nextI)
                let t: Int
                if k <= bias { t = tmin }
                else if k >= bias + tmax { t = tmax }
                else { t = k - bias }
                if digit < t { break }
                let factor = UInt64(base - t)
                let nextW = UInt64(w) * factor
                guard nextW <= UInt64(UInt32.max) else { return nil }
                w = UInt32(nextW)
                k += base
            }
            let outLen = output.count + 1
            bias = adapt(delta: Int(i - oldi), numPoints: outLen, firstTime: oldi == 0)
            let advance = UInt64(n) + UInt64(i / UInt32(outLen))
            guard advance <= UInt64(UInt32.max) else { return nil }
            n = UInt32(advance)
            i %= UInt32(outLen)
            guard let scalar = UnicodeScalar(n) else { return nil }
            output.insert(scalar, at: Int(i))
            i += 1
        }
        return String(String.UnicodeScalarView(output))
    }

    private static func adapt(delta: Int, numPoints: Int, firstTime: Bool) -> Int {
        var d = firstTime ? delta / damp : delta / 2
        d += d / numPoints
        var k = 0
        let threshold = ((base - tmin) * tmax) / 2
        while d > threshold {
            d /= (base - tmin)
            k += base
        }
        return k + (((base - tmin + 1) * d) / (d + skew))
    }

    private static func digitValue(_ scalar: UnicodeScalar) -> Int? {
        switch scalar {
        case "A"..."Z": return Int(scalar.value - UnicodeScalar("A").value)
        case "a"..."z": return Int(scalar.value - UnicodeScalar("a").value)
        case "0"..."9": return 26 + Int(scalar.value - UnicodeScalar("0").value)
        default: return nil
        }
    }

    private static func isBasic(_ scalar: UnicodeScalar) -> Bool {
        scalar.value < 0x80
    }
}
