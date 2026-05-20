import XCTest
@testable import JunctionApp

// VAL-M6-CHEAT-001: ? with cheatSheetVisible == false sets it to true
// VAL-M6-CHEAT-002: ? with cheatSheetVisible == true sets it to false
// VAL-M6-CHEAT-003: Escape with sheet visible hides sheet, consumed, picker stays
// VAL-M6-CHEAT-004: Escape with sheet hidden signals not-consumed / dismiss-picker
// VAL-M6-CHEAT-005: Number keys 1-9 pass through (not consumed) so existing logic picks options
// VAL-M6-CHEAT-006: Cheat sheet content covers every key in PickerShortcutHelp.picker
// VAL-M6-CHEAT-007: Cheat sheet preview pane covers every key in PickerShortcutHelp.preview
// VAL-CROSS-006: Cheat sheet toggle does not dismiss picker (frame preserved)
final class PickerKeyHandlerTests: XCTestCase {

    private func makeModel(optionCount: Int = 3) -> PickerViewModel {
        let browsers: [Browser] = (0..<optionCount).map { i in
            Browser(
                bundleID: "com.test.Browser\(i)",
                name: "Browser \(i)",
                url: URL(fileURLWithPath: "/Applications/Safari.app")
            )
        }
        let options = browsers.map { LaunchOption(browser: $0, profile: nil) }
        return PickerViewModel(
            url: URL(string: "https://example.com/")!,
            options: options,
            context: RouteContext(
                source: nil,
                focus: FocusInfo(modeIdentifier: nil, modeName: nil)
            ),
            onPick: { _, _, _ in },
            onPickMulti: { _, _ in },
            onCancel: { }
        )
    }

    private func questionEvent() -> KeyEvent {
        KeyEvent(characters: "?", keyCode: 44)
    }

    private func shiftSlashEvent() -> KeyEvent {
        KeyEvent(characters: "/", keyCode: 44, shift: true)
    }

    private func escapeEvent() -> KeyEvent {
        KeyEvent(characters: nil, keyCode: 53)
    }

    private func numberEvent(_ digit: Int) -> KeyEvent {
        KeyEvent(characters: "\(digit)", keyCode: UInt16(digit + 17))
    }

    // MARK: - VAL-M6-CHEAT-001

    func test_questionTogglesCheatSheetOn_VAL_M6_CHEAT_001() {
        let model = makeModel()
        XCTAssertFalse(model.cheatSheetVisible)
        let outcome = PickerKeyHandler.handle(event: questionEvent(), model: model)
        XCTAssertTrue(model.cheatSheetVisible)
        XCTAssertTrue(outcome.consumed)
        XCTAssertFalse(outcome.dismiss)
    }

    func test_shiftSlashTogglesCheatSheetOn() {
        let model = makeModel()
        XCTAssertFalse(model.cheatSheetVisible)
        let outcome = PickerKeyHandler.handle(event: shiftSlashEvent(), model: model)
        XCTAssertTrue(model.cheatSheetVisible)
        XCTAssertTrue(outcome.consumed)
        XCTAssertFalse(outcome.dismiss)
    }

    func test_unshiftedSlashDoesNotToggleCheatSheet() {
        let model = makeModel()
        let outcome = PickerKeyHandler.handle(
            event: KeyEvent(characters: "/", keyCode: 44, shift: false),
            model: model
        )
        XCTAssertFalse(model.cheatSheetVisible)
        XCTAssertFalse(outcome.consumed)
    }

    // MARK: - VAL-M6-CHEAT-002

    func test_questionTogglesCheatSheetOff_VAL_M6_CHEAT_002() {
        let model = makeModel()
        model.cheatSheetVisible = true
        let outcome = PickerKeyHandler.handle(event: questionEvent(), model: model)
        XCTAssertFalse(model.cheatSheetVisible)
        XCTAssertTrue(outcome.consumed)
        XCTAssertFalse(outcome.dismiss)
    }

    // MARK: - VAL-M6-CHEAT-003

    func test_escapeWithSheetVisibleHidesSheetConsumedPickerStays_VAL_M6_CHEAT_003() {
        let model = makeModel()
        model.cheatSheetVisible = true
        let outcome = PickerKeyHandler.handle(event: escapeEvent(), model: model)
        XCTAssertFalse(model.cheatSheetVisible, "cheatSheetVisible must become false")
        XCTAssertTrue(outcome.consumed, "event must be consumed so picker stays")
        XCTAssertFalse(outcome.dismiss, "picker must not be dismissed")
    }

    // MARK: - VAL-M6-CHEAT-004

    func test_escapeWithSheetHiddenSignalsDismiss_VAL_M6_CHEAT_004() {
        let model = makeModel()
        XCTAssertFalse(model.cheatSheetVisible)
        let outcome = PickerKeyHandler.handle(event: escapeEvent(), model: model)
        XCTAssertFalse(outcome.consumed, "event must not be consumed (existing semantics)")
        XCTAssertTrue(outcome.dismiss, "picker must be dismissed")
        XCTAssertFalse(model.cheatSheetVisible, "cheatSheetVisible must remain false")
    }

    // MARK: - VAL-M6-CHEAT-005
    // Number keys 1-9 are not consumed by PickerKeyHandler when sheet is visible;
    // they pass through so the existing pickByNumber logic fires.

    func test_numberKeyWithSheetVisiblePassesThrough_VAL_M6_CHEAT_005() {
        let model = makeModel(optionCount: 3)
        model.cheatSheetVisible = true
        for digit in 1...9 {
            let outcome = PickerKeyHandler.handle(event: numberEvent(digit), model: model)
            XCTAssertFalse(outcome.consumed, "digit \(digit) must not be consumed by PickerKeyHandler")
            XCTAssertFalse(outcome.dismiss, "digit \(digit) must not signal dismiss via PickerKeyHandler")
            XCTAssertTrue(model.cheatSheetVisible, "cheatSheetVisible must remain true after digit \(digit)")
        }
    }

    func test_numberKeyWithSheetHiddenPassesThrough_VAL_M6_CHEAT_005() {
        let model = makeModel(optionCount: 3)
        XCTAssertFalse(model.cheatSheetVisible)
        for digit in 1...9 {
            let outcome = PickerKeyHandler.handle(event: numberEvent(digit), model: model)
            XCTAssertFalse(outcome.consumed, "digit \(digit) must not be consumed by PickerKeyHandler")
            XCTAssertFalse(outcome.dismiss, "digit \(digit) must not signal dismiss via PickerKeyHandler")
        }
    }

    // MARK: - VAL-M6-CHEAT-006

    func test_cheatSheetEntriesCoversAllPickerEntries_VAL_M6_CHEAT_006() {
        let model = makeModel()
        model.previewMode = false
        let entries = model.cheatSheetEntries
        for entry in PickerShortcutHelp.pickerEntries {
            XCTAssertTrue(entries.contains(entry), "cheatSheetEntries missing picker entry: \(entry)")
        }
        XCTAssertEqual(entries.count, PickerShortcutHelp.pickerEntries.count)
        XCTAssertEqual(model.cheatSheetRows.count, PickerShortcutHelp.pickerCheatRows.count)
    }

    // MARK: - VAL-M6-CHEAT-007

    func test_cheatSheetEntriesInPreviewModeCoversAllPreviewEntries_VAL_M6_CHEAT_007() {
        let model = makeModel()
        model.previewMode = true
        let entries = model.cheatSheetEntries
        for entry in PickerShortcutHelp.previewEntries {
            XCTAssertTrue(entries.contains(entry), "cheatSheetEntries missing preview entry: \(entry)")
        }
        XCTAssertEqual(entries.count, PickerShortcutHelp.previewEntries.count)
        XCTAssertEqual(model.cheatSheetRows.count, PickerShortcutHelp.previewCheatRows.count)
    }

    // MARK: - VAL-CROSS-006
    // Cheat sheet toggle does not dismiss picker; frame is preserved because
    // PickerKeyHandler returns consumed:true, dismiss:false for ? in both directions.

    func test_cheatSheetToggleDoesNotDismissPicker_VAL_CROSS_006() {
        let model = makeModel()

        let outcome1 = PickerKeyHandler.handle(event: questionEvent(), model: model)
        XCTAssertTrue(model.cheatSheetVisible)
        XCTAssertTrue(outcome1.consumed)
        XCTAssertFalse(outcome1.dismiss, "? must never signal dismiss (frame preserved)")

        let outcome2 = PickerKeyHandler.handle(event: questionEvent(), model: model)
        XCTAssertFalse(model.cheatSheetVisible)
        XCTAssertTrue(outcome2.consumed)
        XCTAssertFalse(outcome2.dismiss, "? must never signal dismiss (frame preserved)")
    }

    func test_escapeWithSheetVisibleDoesNotDismissPicker_VAL_CROSS_006() {
        let model = makeModel()
        model.cheatSheetVisible = true
        let outcome = PickerKeyHandler.handle(event: escapeEvent(), model: model)
        XCTAssertFalse(model.cheatSheetVisible)
        XCTAssertFalse(outcome.dismiss, "Escape with sheet visible must not dismiss picker")
    }

    // MARK: - pickerEntries and previewEntries are non-empty

    func test_pickerEntriesNonEmpty() {
        XCTAssertFalse(PickerShortcutHelp.pickerEntries.isEmpty)
    }

    func test_previewEntriesNonEmpty() {
        XCTAssertFalse(PickerShortcutHelp.previewEntries.isEmpty)
    }

    // MARK: - picker/preview strings still join from entries (backward compat)

    func test_pickerStringJoinsFromEntries() {
        let joined = PickerShortcutHelp.pickerEntries.joined(separator: " • ")
        XCTAssertEqual(PickerShortcutHelp.picker, joined)
    }

    func test_previewStringJoinsFromEntries() {
        let joined = PickerShortcutHelp.previewEntries.joined(separator: " • ")
        XCTAssertEqual(PickerShortcutHelp.preview, joined)
    }
}
