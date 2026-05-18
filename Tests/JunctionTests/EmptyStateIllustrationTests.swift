import XCTest
import SwiftUI
@testable import JunctionApp

// VAL-M6-EMPTY-001: Rules empty-state view-builder returns custom illustration with accessibilityIdentifier == "rules-empty-illustration"
// VAL-M6-EMPTY-002: Activity empty-state view-builder returns custom illustration with accessibilityIdentifier == "activity-empty-illustration"
// VAL-M6-EMPTY-003: Rendered empty states have no descendant Image(systemName:)
final class EmptyStateIllustrationTests: XCTestCase {

    func test_rulesEmptyIllustrationHasAccessibilityIdentifier_VAL_M6_EMPTY_001() {
        let view = RulesEmptyIllustration()
        XCTAssertTrue(
            mirrorContainsString("rules-empty-illustration", in: Mirror(reflecting: view.body)),
            "RulesEmptyIllustration body must carry accessibilityIdentifier 'rules-empty-illustration'"
        )
    }

    func test_activityEmptyIllustrationHasAccessibilityIdentifier_VAL_M6_EMPTY_002() {
        let view = ActivityEmptyIllustration()
        XCTAssertTrue(
            mirrorContainsString("activity-empty-illustration", in: Mirror(reflecting: view.body)),
            "ActivityEmptyIllustration body must carry accessibilityIdentifier 'activity-empty-illustration'"
        )
    }

    func test_rulesEmptyIllustrationHasNoSystemImage_VAL_M6_EMPTY_003() {
        let view = RulesEmptyIllustration()
        XCTAssertFalse(
            mirrorContainsSystemImage(Mirror(reflecting: view.body)),
            "RulesEmptyIllustration must not contain Image(systemName:)"
        )
    }

    func test_activityEmptyIllustrationHasNoSystemImage_VAL_M6_EMPTY_003() {
        let view = ActivityEmptyIllustration()
        XCTAssertFalse(
            mirrorContainsSystemImage(Mirror(reflecting: view.body)),
            "ActivityEmptyIllustration must not contain Image(systemName:)"
        )
    }

    // MARK: - Mirror helpers

    private func mirrorContainsString(_ target: String, in mirror: Mirror, depth: Int = 0) -> Bool {
        guard depth < 20 else { return false }
        for child in mirror.children {
            if let str = child.value as? String, str == target {
                return true
            }
            if mirrorContainsString(target, in: Mirror(reflecting: child.value), depth: depth + 1) {
                return true
            }
        }
        return false
    }

    private func mirrorContainsSystemImage(_ mirror: Mirror, depth: Int = 0) -> Bool {
        guard depth < 20 else { return false }
        let typeName = String(describing: mirror.subjectType)
        if typeName == "Image" {
            for child in mirror.children {
                let childMirror = Mirror(reflecting: child.value)
                let childTypeName = String(describing: childMirror.subjectType)
                if childTypeName.contains("NamedImageProvider") || childTypeName.contains("SystemImageProvider") {
                    return true
                }
                for grandchild in childMirror.children {
                    if grandchild.label == "isSystem", let isSystem = grandchild.value as? Bool, isSystem {
                        return true
                    }
                }
            }
        }
        for child in mirror.children {
            if mirrorContainsSystemImage(Mirror(reflecting: child.value), depth: depth + 1) {
                return true
            }
        }
        return false
    }
}
