import Foundation

enum GroupedLaunchOption: Identifiable {
    case single(LaunchOption)
    case group(browser: Browser, options: [LaunchOption])

    var id: String {
        switch self {
        case .single(let opt): return opt.id
        case .group(let browser, _): return "group:\(browser.bundleID)"
        }
    }

    var firstOption: LaunchOption? {
        switch self {
        case .single(let opt): return opt
        case .group(_, let opts): return opts.first
        }
    }
}

enum LaunchOptionGrouping {
    /// Groups `options` by browser bundleID. Browsers with ≥2 profiles collapse
    /// into a single `.group`; 0–1 profiles emit `.single`. Input array is NOT mutated.
    /// The order of first occurrence in `options` determines group position.
    static func group(options: [LaunchOption]) -> [GroupedLaunchOption] {
        var profileCountByBundleID: [String: Int] = [:]
        for option in options where option.profile != nil {
            profileCountByBundleID[option.browser.bundleID, default: 0] += 1
        }

        var result: [GroupedLaunchOption] = []
        var seenGroupBundleIDs: Set<String> = []
        var groupOptionsByBundleID: [String: [LaunchOption]] = [:]
        var groupInsertionIndex: [String: Int] = [:]

        for option in options {
            let bundleID = option.browser.bundleID
            let count = profileCountByBundleID[bundleID] ?? 0

            if count >= 2 {
                if !seenGroupBundleIDs.contains(bundleID) {
                    seenGroupBundleIDs.insert(bundleID)
                    groupInsertionIndex[bundleID] = result.count
                    result.append(.single(option))
                    groupOptionsByBundleID[bundleID] = []
                }
                groupOptionsByBundleID[bundleID]?.append(option)
            } else {
                result.append(.single(option))
            }
        }

        for (bundleID, idx) in groupInsertionIndex {
            guard let opts = groupOptionsByBundleID[bundleID], !opts.isEmpty else { continue }
            result[idx] = .group(browser: opts[0].browser, options: opts)
        }

        return result
    }

    /// Returns the flat list of `LaunchOption` values visible given the current
    /// expansion state. Collapsed groups contribute their first option (slot 1);
    /// expanded groups contribute all their children.
    static func visibleOptions(
        grouped: [GroupedLaunchOption],
        expandedGroupIDs: Set<String>
    ) -> [LaunchOption] {
        var result: [LaunchOption] = []
        for item in grouped {
            switch item {
            case .single(let opt):
                result.append(opt)
            case .group(let browser, let opts):
                let groupID = "group:\(browser.bundleID)"
                if expandedGroupIDs.contains(groupID) {
                    result.append(contentsOf: opts)
                } else {
                    if let first = opts.first {
                        result.append(first)
                    }
                }
            }
        }
        return result
    }

    /// Resolves the flat-array insertion index for a drag-to-reorder operation.
    /// When `destination` equals `rowUnderlyingOptions.count` (drop at end of list),
    /// returns `flat.count` so the moved item appends after the last element.
    /// For any other destination, maps through the row's underlying option to its
    /// index in `flat`, falling back to `flat.count` when the row is a group header.
    static func resolveDestinationIndex(
        destination: Int,
        rowUnderlyingOptions: [LaunchOption?],
        flat: [LaunchOption],
        fallback: LaunchOption
    ) -> Int {
        if destination >= rowUnderlyingOptions.count {
            return flat.count
        }
        let destOption = rowUnderlyingOptions[destination] ?? fallback
        return flat.firstIndex(where: { $0.id == destOption.id }) ?? flat.count
    }

    /// Returns the set of group IDs that should be expanded by default, based on
    /// whether the pinned target key lives inside a group.
    static func defaultExpandedGroupIDs(
        grouped: [GroupedLaunchOption],
        pinnedTargetKey: String?
    ) -> Set<String> {
        guard let pinnedKey = pinnedTargetKey else { return [] }
        for item in grouped {
            if case .group(let browser, let opts) = item {
                if opts.contains(where: { $0.target.storageKey == pinnedKey }) {
                    return ["group:\(browser.bundleID)"]
                }
            }
        }
        return []
    }
}
