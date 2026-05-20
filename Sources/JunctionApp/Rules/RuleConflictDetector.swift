import Foundation

enum RuleConflictDetector {

    /// Returns the set of rule IDs that are unreachable because an earlier
    /// enabled rule fully covers them. Walks `rules` in order; for each rule
    /// R, if any earlier enabled rule E satisfies all four coverage conditions
    /// below, R is shadowed:
    ///
    /// 1. E's host-shape fully covers R's host-shape.
    /// 2. E's path covers R's path (E.path == nil dominates any R.path).
    /// 3. E's `when` is nil-or-superset of R's `when`.
    /// 4. E's schemes are nil-or-superset of R's schemes.
    /// 5. E's `queryContains` is nil-or-superset of R's `queryContains`.
    /// 6. R's `urlEquals` is not strictly different from E's.
    static func shadowed(rules: [DomainRule]) -> Set<UUID> {
        var result = Set<UUID>()
        for rIdx in rules.indices {
            let r = rules[rIdx]
            for eIdx in rules.indices where eIdx < rIdx {
                let e = rules[eIdx]
                guard e.enabled else { continue }
                if covers(e, r) {
                    result.insert(r.id)
                    break
                }
            }
        }
        return result
    }

    private static func covers(_ e: DomainRule, _ r: DomainRule) -> Bool {
        // urlEquals: if E is pinned to a specific URL it only covers R when
        // R is pinned to the same URL. If E has no urlEquals it matches any
        // URL for the host, so it can cover a urlEquals-bearing R.
        if let eURL = e.urlEquals {
            guard let rURL = r.urlEquals, eURL == rURL else { return false }
        }

        guard hostCovers(e.host, r.host) else { return false }

        // Path: nil on E means "any path" and therefore dominates.
        if let ePath = e.path {
            guard let rPath = r.path, ePath == rPath else { return false }
        }

        // When: nil on E means "any condition" and therefore dominates.
        if let eWhen = e.when {
            guard let rWhen = r.when else { return false }
            guard whenCovers(eWhen, rWhen) else { return false }
        }

        // Schemes: nil on E means "any scheme" and therefore dominates.
        if let eSchemes = e.schemes, !eSchemes.isEmpty {
            guard let rSchemes = r.schemes, !rSchemes.isEmpty else { return false }
            let eSet = Set(eSchemes.map { $0.lowercased() })
            let rSet = Set(rSchemes.map { $0.lowercased() })
            guard rSet.isSubset(of: eSet) else { return false }
        }

        // Query: nil on E means "any query" and therefore dominates. A restricted
        // earlier rule cannot shadow a later host-wide rule.
        if let eQuery = e.queryContains, !eQuery.isEmpty {
            guard let rQuery = r.queryContains, !rQuery.isEmpty else { return false }
            guard rQuery.lowercased().contains(eQuery.lowercased()) else { return false }
        }

        return true
    }

    private static func hostCovers(_ e: HostMatch, _ r: HostMatch) -> Bool {
        switch (e, r) {
        case (.equals(let ev), .equals(let rv)):
            return ev.lowercased() == rv.lowercased()
        case (.suffix(let ev), .suffix(let rv)):
            return suffixPatternCovers(ev, rv)
        case (.suffix(let ev), .equals(let rv)):
            return suffixPatternCovers(ev, rv)
        case (.regex(let ep), .regex(let rp)):
            return ep == rp
        default:
            return false
        }
    }

    /// True when every host matching suffix pattern `narrower` also matches `broader`.
    private static func suffixPatternCovers(_ broader: String, _ narrower: String) -> Bool {
        let needle = broader.lowercased()
        let target = narrower.lowercased()
        return target == needle || target.hasSuffix("." + needle)
    }

    private static func whenCovers(_ e: RuleCondition, _ r: RuleCondition) -> Bool {
        if let eApps = e.sourceApp, !eApps.isEmpty {
            guard let rApps = r.sourceApp, !rApps.isEmpty else { return false }
            let eSet = Set(eApps.map { $0.lowercased() })
            let rSet = Set(rApps.map { $0.lowercased() })
            guard rSet.isSubset(of: eSet) else { return false }
        }
        if let eFocus = e.focus, !eFocus.isEmpty {
            guard let rFocus = r.focus, !rFocus.isEmpty else { return false }
            let eSet = Set(eFocus.map { $0.lowercased() })
            let rSet = Set(rFocus.map { $0.lowercased() })
            guard rSet.isSubset(of: eSet) else { return false }
        }
        return true
    }
}
