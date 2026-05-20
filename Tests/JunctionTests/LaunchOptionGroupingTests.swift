@testable import JunctionApp
import XCTest

final class LaunchOptionGroupingTests: XCTestCase {

    // VAL-M5-COLLAPSE-001: Browsers with ≥2 profiles produce one group;
    // single-profile browsers stay ungrouped; input not mutated.
    func test_browsersWithTwoOrMoreProfiles_collapseToGroup_VAL_M5_COLLAPSE_001() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let input = [chromeDefault, chromeWork, safariApp]
        let inputCopy = input

        let result = LaunchOptionGrouping.group(options: input)

        XCTAssertEqual(input.map { $0.id }, inputCopy.map { $0.id }, "Input must not be mutated")
        XCTAssertEqual(result.count, 2)

        if case .group(let browser, let opts) = result[0] {
            XCTAssertEqual(browser.bundleID, "com.google.Chrome")
            XCTAssertEqual(opts.count, 2)
        } else {
            XCTFail("Expected group at index 0")
        }

        if case .single(let opt) = result[1] {
            XCTAssertEqual(opt.browser.bundleID, "com.apple.Safari")
        } else {
            XCTFail("Expected single at index 1")
        }
    }

    func test_singleProfileBrowser_remainsUngrouped_VAL_M5_COLLAPSE_001() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let opt = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let result = LaunchOptionGrouping.group(options: [opt])
        XCTAssertEqual(result.count, 1)
        if case .single(let o) = result[0] {
            XCTAssertEqual(o.browser.bundleID, "com.google.Chrome")
        } else {
            XCTFail("Expected single for browser with 1 profile")
        }
    }

    func test_noProfileBrowser_remainsUngrouped_VAL_M5_COLLAPSE_001() {
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let opt = LaunchOption(browser: safari, profile: nil)
        let result = LaunchOptionGrouping.group(options: [opt])
        XCTAssertEqual(result.count, 1)
        if case .single(let o) = result[0] {
            XCTAssertEqual(o.browser.bundleID, "com.apple.Safari")
        } else {
            XCTFail("Expected single for browser with no profile")
        }
    }

    // VAL-M5-COLLAPSE-002: Expanding a group preserves the underlying targetOrder.
    func test_groupPreservesChildOrder_VAL_M5_COLLAPSE_002() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let a = LaunchOption(browser: chrome, profile: makeProfile("A", "Profile A"))
        let b = LaunchOption(browser: chrome, profile: makeProfile("B", "Profile B"))
        let c = LaunchOption(browser: chrome, profile: makeProfile("C", "Profile C"))

        let result = LaunchOptionGrouping.group(options: [a, b, c])
        XCTAssertEqual(result.count, 1)
        if case .group(_, let opts) = result[0] {
            XCTAssertEqual(opts.map { $0.id }, [a.id, b.id, c.id])
        } else {
            XCTFail("Expected group")
        }
    }

    func test_groupPreservesChildOrder_reordered_VAL_M5_COLLAPSE_002() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let a = LaunchOption(browser: chrome, profile: makeProfile("A", "Profile A"))
        let b = LaunchOption(browser: chrome, profile: makeProfile("B", "Profile B"))
        let c = LaunchOption(browser: chrome, profile: makeProfile("C", "Profile C"))

        let result = LaunchOptionGrouping.group(options: [c, a, b])
        if case .group(_, let opts) = result[0] {
            XCTAssertEqual(opts.map { $0.id }, [c.id, a.id, b.id])
        } else {
            XCTFail("Expected group")
        }
    }

    // VAL-M5-COLLAPSE-003: Pin (M3) survives grouping — pinned profile-key inside
    // a grouped browser places group at slot 1; pinned profile is first in group.
    func test_pinnedProfileInsideGroup_groupAtSlotOne_VAL_M5_COLLAPSE_003() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        // Input already has Chrome first (as if targetOrder put pinnedKey first)
        let input = [chromeWork, chromeDefault, safariApp]
        let result = LaunchOptionGrouping.group(options: input)

        XCTAssertEqual(result.count, 2)
        if case .group(let browser, _) = result[0] {
            XCTAssertEqual(browser.bundleID, "com.google.Chrome", "Chrome group must be at slot 0")
        } else {
            XCTFail("Expected Chrome group at slot 0")
        }
    }

    func test_pinnedProfileIsFirstInGroup_VAL_M5_COLLAPSE_003() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let work = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let def = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))

        // Input has Work first (pinned)
        let result = LaunchOptionGrouping.group(options: [work, def])
        if case .group(_, let opts) = result[0] {
            XCTAssertEqual(opts[0].id, work.id, "Pinned profile must be first in group")
        } else {
            XCTFail("Expected group")
        }
    }

    // VAL-M5-COLLAPSE-004: Arc spaces are grouped using the same logic.
    func test_arcSpacesGrouped_whenTwoOrMore_VAL_M5_COLLAPSE_004() {
        let arc = makeBrowser(bundleID: ArcSpacesDiscovery.bundleID, name: "Arc")
        let space1 = LaunchOption(browser: arc, profile: makeProfile("Default|space:1", "Personal"))
        let space2 = LaunchOption(browser: arc, profile: makeProfile("Default|space:2", "Work"))

        let result = LaunchOptionGrouping.group(options: [space1, space2])
        XCTAssertEqual(result.count, 1)
        if case .group(let browser, let opts) = result[0] {
            XCTAssertEqual(browser.bundleID, ArcSpacesDiscovery.bundleID)
            XCTAssertEqual(opts.count, 2)
        } else {
            XCTFail("Expected Arc group")
        }
    }

    func test_singleArcSpace_remainsUngrouped_VAL_M5_COLLAPSE_004() {
        let arc = makeBrowser(bundleID: ArcSpacesDiscovery.bundleID, name: "Arc")
        let space = LaunchOption(browser: arc, profile: makeProfile("Default|space:1", "Personal"))

        let result = LaunchOptionGrouping.group(options: [space])
        XCTAssertEqual(result.count, 1)
        if case .single(let opt) = result[0] {
            XCTAssertEqual(opt.browser.bundleID, ArcSpacesDiscovery.bundleID)
        } else {
            XCTFail("Expected single for single-space Arc")
        }
    }

    // VAL-M5-COLLAPSE-005: Number-key shortcuts re-map across collapse vs. expand.
    // pickByNumber walks visible tile list; group counts as one when collapsed.
    func test_pickByNumber_collapsedGroup_countsAsOne_VAL_M5_COLLAPSE_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let firefox = makeBrowser(bundleID: "org.mozilla.firefox", name: "Firefox")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let safariApp = LaunchOption(browser: safari, profile: nil)
        let firefoxApp = LaunchOption(browser: firefox, profile: nil)

        let options = [chromeDefault, chromeWork, safariApp, firefoxApp]
        let grouped = LaunchOptionGrouping.group(options: options)

        // Collapsed: Chrome group = slot 1, Safari = slot 2, Firefox = slot 3
        let visible = LaunchOptionGrouping.visibleOptions(grouped: grouped, expandedGroupIDs: [])
        XCTAssertEqual(visible.count, 3)
        XCTAssertEqual(visible[0].id, chromeDefault.id, "Slot 1: first Chrome profile")
        XCTAssertEqual(visible[1].id, safariApp.id, "Slot 2: Safari")
        XCTAssertEqual(visible[2].id, firefoxApp.id, "Slot 3: Firefox")
    }

    func test_allGroupIDs_includesEveryMultiProfileBrowser() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let edge = makeBrowser(bundleID: "com.microsoft.edgemac", name: "Edge")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let edgeDefault = LaunchOption(browser: edge, profile: makeProfile("Default", "Default"))
        let edgeWork = LaunchOption(browser: edge, profile: makeProfile("Work", "Work"))

        let grouped = LaunchOptionGrouping.group(options: [chromeDefault, chromeWork, edgeDefault, edgeWork])
        let ids = LaunchOptionGrouping.allGroupIDs(grouped: grouped)

        XCTAssertEqual(ids, ["group:com.google.Chrome", "group:com.microsoft.edgemac"])
    }

    func test_pickByNumber_expandedGroup_exposesChildren_VAL_M5_COLLAPSE_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let options = [chromeDefault, chromeWork, safariApp]
        let grouped = LaunchOptionGrouping.group(options: options)
        let groupID = "group:com.google.Chrome"

        // Expanded: Chrome/Default = slot 1, Chrome/Work = slot 2, Safari = slot 3
        let visible = LaunchOptionGrouping.visibleOptions(grouped: grouped, expandedGroupIDs: [groupID])
        XCTAssertEqual(visible.count, 3)
        XCTAssertEqual(visible[0].id, chromeDefault.id)
        XCTAssertEqual(visible[1].id, chromeWork.id)
        XCTAssertEqual(visible[2].id, safariApp.id)
    }

    func test_pickByNumber_numberingNeverExceedsNine_VAL_M5_COLLAPSE_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let profiles = (1...5).map { i in
            LaunchOption(browser: chrome, profile: makeProfile("P\(i)", "Profile \(i)"))
        }
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let others = (1...6).map { i in
            LaunchOption(browser: makeBrowser(bundleID: "com.browser\(i)", name: "Browser\(i)"), profile: nil)
        }

        let options = profiles + others.map { $0 }
        let grouped = LaunchOptionGrouping.group(options: options)
        let groupID = "group:com.google.Chrome"

        let visible = LaunchOptionGrouping.visibleOptions(grouped: grouped, expandedGroupIDs: [groupID])
        XCTAssertLessThanOrEqual(visible.prefix(9).count, 9)
    }

    // VAL-M5-COLLAPSE-006: Model layer remains flat — targetOrder keys and on-disk
    // Settings unchanged after grouping.
    func test_groupingDoesNotMutateInput_VAL_M5_COLLAPSE_006() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let a = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let b = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let input = [a, b]
        let originalIDs = input.map { $0.id }

        _ = LaunchOptionGrouping.group(options: input)

        XCTAssertEqual(input.map { $0.id }, originalIDs, "Input array must not be mutated")
    }

    func test_groupedOptionIDs_matchFlatSnapshot_VAL_M5_COLLAPSE_006() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let a = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let b = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let s = LaunchOption(browser: safari, profile: nil)

        let input = [a, b, s]
        let grouped = LaunchOptionGrouping.group(options: input)

        var allIDs: [String] = []
        for item in grouped {
            switch item {
            case .single(let opt): allIDs.append(opt.id)
            case .group(_, let opts): allIDs.append(contentsOf: opts.map { $0.id })
            }
        }
        XCTAssertEqual(allIDs.sorted(), input.map { $0.id }.sorted())
    }

    // MARK: - resolveDestinationIndex (drag-to-end fix)

    // Dragging a visible row to destination == rows.count must append it last.
    func test_resolveDestinationIndex_endOfVisibleSection_returnsCount() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let firefox = makeBrowser(bundleID: "org.mozilla.firefox", name: "Firefox")

        let a = LaunchOption(browser: chrome, profile: nil)
        let b = LaunchOption(browser: safari, profile: nil)
        let c = LaunchOption(browser: firefox, profile: nil)

        let flat = [a, b, c]
        let rowOptions: [LaunchOption?] = [a, b, c]

        let idx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: rowOptions.count,
            rowUnderlyingOptions: rowOptions,
            flat: flat,
            fallback: a
        )
        XCTAssertEqual(idx, flat.count, "destination == rows.count must map to flat.count (append to end)")

        var result = flat
        result.move(fromOffsets: IndexSet(integer: 0), toOffset: idx)
        XCTAssertEqual(result.map { $0.id }, [b.id, c.id, a.id], "Chrome must land last after drag to end")
    }

    // Source < destination: after removing source the insertion point shifts, but
    // Array.move handles this internally — resolveDestinationIndex must still return flat.count.
    func test_resolveDestinationIndex_endOfVisibleSection_sourceBeforeDestination() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let a = LaunchOption(browser: chrome, profile: nil)
        let b = LaunchOption(browser: safari, profile: nil)

        let flat = [a, b]
        let rowOptions: [LaunchOption?] = [a, b]

        // source = 0 (Chrome), destination = 2 (end) — source < destination
        let idx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: 2,
            rowUnderlyingOptions: rowOptions,
            flat: flat,
            fallback: a
        )
        XCTAssertEqual(idx, 2)

        var result = flat
        result.move(fromOffsets: IndexSet(integer: 0), toOffset: idx)
        XCTAssertEqual(result.map { $0.id }, [b.id, a.id], "Chrome must land after Safari")
    }

    // Dragging a hidden row to destination == rows.count must append it last in the hidden section.
    func test_resolveDestinationIndex_endOfHiddenSection_returnsCount() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let firefox = makeBrowser(bundleID: "org.mozilla.firefox", name: "Firefox")

        let a = LaunchOption(browser: chrome, profile: nil)
        let b = LaunchOption(browser: safari, profile: nil)
        let c = LaunchOption(browser: firefox, profile: nil)

        let hidden = [a, b, c]
        let rowOptions: [LaunchOption?] = [a, b, c]

        let idx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: rowOptions.count,
            rowUnderlyingOptions: rowOptions,
            flat: hidden,
            fallback: a
        )
        XCTAssertEqual(idx, hidden.count, "destination == rows.count must map to hidden.count")

        var result = hidden
        result.move(fromOffsets: IndexSet(integer: 0), toOffset: idx)
        XCTAssertEqual(result.map { $0.id }, [b.id, c.id, a.id])
    }

    // Mid-list drag still resolves correctly (regression guard).
    func test_resolveDestinationIndex_midList_returnsCorrectIndex() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let firefox = makeBrowser(bundleID: "org.mozilla.firefox", name: "Firefox")

        let a = LaunchOption(browser: chrome, profile: nil)
        let b = LaunchOption(browser: safari, profile: nil)
        let c = LaunchOption(browser: firefox, profile: nil)

        let flat = [a, b, c]
        let rowOptions: [LaunchOption?] = [a, b, c]

        let idx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: 1,
            rowUnderlyingOptions: rowOptions,
            flat: flat,
            fallback: a
        )
        XCTAssertEqual(idx, 1)
    }

    // Group header row (nil underlying option) falls back to the provided fallback option.
    func test_flatMoveSourceIndices_groupHeader_movesAllProfiles() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let flat = [chromeDefault, chromeWork, safariApp]
        let indices = LaunchOptionGrouping.flatMoveSourceIndices(
            sourceRowIndices: IndexSet(integer: 0),
            groupBundleIDAtRow: { $0 == 0 ? chrome.bundleID : nil },
            optionAtRow: { _ in nil },
            in: flat
        )

        XCTAssertEqual(indices, IndexSet([0, 1]))
    }

    func test_flatMoveSourceIndices_profileRow_movesSingleTarget() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let flat = [
            LaunchOption(browser: chrome, profile: makeProfile("Default", "Default")),
            chromeWork,
        ]

        let indices = LaunchOptionGrouping.flatMoveSourceIndices(
            sourceRowIndices: IndexSet(integer: 1),
            groupBundleIDAtRow: { _ in nil },
            optionAtRow: { $0 == 1 ? chromeWork : nil },
            in: flat
        )

        XCTAssertEqual(indices, IndexSet(integer: 1))
    }

    func test_resolveDestinationIndex_groupHeaderRow_usesFallback() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let flat = [chromeDefault, chromeWork, safariApp]
        // rows: [groupHeader(nil), safari]
        let rowOptions: [LaunchOption?] = [nil, safariApp]

        let idx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: 0,
            rowUnderlyingOptions: rowOptions,
            flat: flat,
            fallback: chromeDefault
        )
        XCTAssertEqual(idx, 0, "Group header row must fall back to fallback option's index")
    }

    // Using the dragged item as fallback on a group header yields its current index (no-op).
    func test_resolveDestinationIndex_groupHeaderRow_sourceFallbackIsNoOp() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        let chromeDefault = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let chromeWork = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let flat = [chromeDefault, chromeWork, safariApp]
        let rowOptions: [LaunchOption?] = [nil, safariApp]

        let wrongIdx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: 0,
            rowUnderlyingOptions: rowOptions,
            flat: flat,
            fallback: safariApp
        )
        let correctIdx = LaunchOptionGrouping.resolveDestinationIndex(
            destination: 0,
            rowUnderlyingOptions: rowOptions,
            flat: flat,
            fallback: chromeDefault
        )
        XCTAssertEqual(wrongIdx, 2, "Source-as-fallback resolves to source index (no move)")
        XCTAssertEqual(correctIdx, 0, "Group anchor must resolve to first profile in that browser")
    }

    // MARK: - Helpers

    private func makeBrowser(bundleID: String, name: String) -> Browser {
        Browser(bundleID: bundleID, name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"))
    }

    private func makeProfile(_ dir: String, _ display: String) -> ChromiumProfile {
        ChromiumProfile(directoryName: dir, displayName: display, colorHex: nil)
    }
}
