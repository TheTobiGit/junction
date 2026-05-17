@testable import JunctionApp
import XCTest

// VAL-CROSS-005: Pinned Chrome profile renders at slot 1 when group expanded.
// With pinnedTargetKey == "profile:com.google.Chrome:Work" and Chrome having
// profiles Default and Work, the picker view-layer Chrome group renders at
// index 0; expanded group renders Work tile before Default.
// targetOrder model array unchanged (view-layer only).
final class PinnedChromeProfileGroupingTests: XCTestCase {

    func test_pinnedChromeProfile_groupAtIndexZero_VAL_CROSS_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")

        // targetOrder already has Work first (M3 pinning moved it to index 0)
        let work = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let def = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let input = [work, def, safariApp]
        let grouped = LaunchOptionGrouping.group(options: input)

        XCTAssertEqual(grouped.count, 2)
        if case .group(let browser, _) = grouped[0] {
            XCTAssertEqual(browser.bundleID, "com.google.Chrome",
                           "Chrome group must be at index 0 when pinned profile is first in input")
        } else {
            XCTFail("Expected Chrome group at index 0")
        }
    }

    func test_pinnedChromeProfile_expandedGroupShowsWorkFirst_VAL_CROSS_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")

        let work = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let def = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))

        // Input has Work first (pinned via targetOrder)
        let grouped = LaunchOptionGrouping.group(options: [work, def])
        let groupID = "group:com.google.Chrome"

        let visible = LaunchOptionGrouping.visibleOptions(grouped: grouped, expandedGroupIDs: [groupID])
        XCTAssertEqual(visible.count, 2)
        XCTAssertEqual(visible[0].id, work.id, "Work (pinned) must be first when expanded")
        XCTAssertEqual(visible[1].id, def.id, "Default must be second when expanded")
    }

    func test_targetOrderUnchangedAfterGrouping_VAL_CROSS_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let work = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let def = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))

        let input = [work, def]
        let originalIDs = input.map { $0.id }

        _ = LaunchOptionGrouping.group(options: input)

        XCTAssertEqual(input.map { $0.id }, originalIDs,
                       "targetOrder (represented by input order) must not be mutated by grouping")
    }

    func test_defaultExpansionForPinnedGroup_VAL_CROSS_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let work = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let def = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))
        let safari = makeBrowser(bundleID: "com.apple.Safari", name: "Safari")
        let safariApp = LaunchOption(browser: safari, profile: nil)

        let pinnedKey = work.id  // "profile:com.google.Chrome:Work"
        let options = [work, def, safariApp]
        let grouped = LaunchOptionGrouping.group(options: options)

        let defaultExpanded = LaunchOptionGrouping.defaultExpandedGroupIDs(
            grouped: grouped,
            pinnedTargetKey: pinnedKey
        )

        XCTAssertTrue(defaultExpanded.contains("group:com.google.Chrome"),
                      "Chrome group must be default-expanded when pinned profile is inside it")
    }

    func test_defaultExpansionEmpty_whenNoPinnedTarget_VAL_CROSS_005() {
        let chrome = makeBrowser(bundleID: "com.google.Chrome", name: "Chrome")
        let work = LaunchOption(browser: chrome, profile: makeProfile("Work", "Work"))
        let def = LaunchOption(browser: chrome, profile: makeProfile("Default", "Default"))

        let grouped = LaunchOptionGrouping.group(options: [work, def])
        let defaultExpanded = LaunchOptionGrouping.defaultExpandedGroupIDs(
            grouped: grouped,
            pinnedTargetKey: nil
        )

        XCTAssertTrue(defaultExpanded.isEmpty,
                      "No group should be default-expanded when there is no pinned target")
    }

    // MARK: - Helpers

    private func makeBrowser(bundleID: String, name: String) -> Browser {
        Browser(bundleID: bundleID, name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"))
    }

    private func makeProfile(_ dir: String, _ display: String) -> ChromiumProfile {
        ChromiumProfile(directoryName: dir, displayName: display, colorHex: nil)
    }
}
