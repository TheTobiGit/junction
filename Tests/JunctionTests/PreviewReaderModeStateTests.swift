import XCTest
@testable import JunctionApp

final class PreviewReaderModeStateTests: XCTestCase {

    // VAL-M4-READER-004: Reader toggle is per-session, not persisted
    func test_junctionSettingsHasNoReaderModeField_VAL_M4_READER_004() throws {
        let settings = JunctionSettings()
        let data = try JSONEncoder().encode(settings)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(
            json.lowercased().contains("reader"),
            "JunctionSettings must not contain any reader-mode field — reader state is per-session @State only"
        )
    }

    func test_pickerViewModelHasNoReaderModeProperty_VAL_M4_READER_004() {
        let url = URL(string: "https://example.com")!
        let context = RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
        let model = PickerViewModel(
            url: url,
            options: [],
            context: context,
            onPick: { _, _, _ in },
            onPickMulti: { _, _ in },
            onCancel: {}
        )
        let mirror = Mirror(reflecting: model)
        let hasReaderField = mirror.children.contains { child in
            child.label?.lowercased().contains("reader") ?? false
        }
        XCTAssertFalse(
            hasReaderField,
            "PickerViewModel must not expose a reader-mode property — reader state lives in PreviewView @State"
        )
    }
}
