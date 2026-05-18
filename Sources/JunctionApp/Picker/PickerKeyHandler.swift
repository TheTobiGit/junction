import Foundation

struct KeyEvent: Codable {
    let characters: String?
    let keyCode: UInt16
}

struct KeyHandlerOutcome {
    let consumed: Bool
    let dismiss: Bool
}

enum PickerKeyHandler {
    // VAL-M6-CHEAT-001: ? with cheatSheetVisible == false sets it to true
    // VAL-M6-CHEAT-002: ? with cheatSheetVisible == true sets it to false
    // VAL-M6-CHEAT-003: Escape with sheet visible hides sheet, consumed, picker stays
    // VAL-M6-CHEAT-004: Escape with sheet hidden signals not-consumed / dismiss-picker
    // VAL-M6-CHEAT-005: Number keys 1-9 pass through (not consumed) so existing logic picks options
    static func handle(event: KeyEvent, model: PickerViewModel) -> KeyHandlerOutcome {
        if event.characters == "?" {
            model.cheatSheetVisible.toggle()
            return KeyHandlerOutcome(consumed: true, dismiss: false)
        }

        if event.keyCode == 53 {
            if model.cheatSheetVisible {
                model.cheatSheetVisible = false
                return KeyHandlerOutcome(consumed: true, dismiss: false)
            }
            return KeyHandlerOutcome(consumed: false, dismiss: true)
        }

        return KeyHandlerOutcome(consumed: false, dismiss: false)
    }
}
