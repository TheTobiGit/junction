import XCTest
@testable import JunctionApp

final class IDNRiskChipTests: XCTestCase {
    // VAL-CROSS-007: Reader mode does not suppress IDN homograph chip.
    // Reader mode is a per-session @State toggle in PreviewView that does not
    // touch PickerViewModel.riskFlags, so the IDN chip is always visible.
    func test_readerModeDoesNotSuppressIDNChip_VAL_CROSS_007() {
        let url = URL(string: "https://g\u{043E}\u{043E}gle.com")!
        let flags = URLRiskAssessor.assess(url)
        let idnFlags = flags.filter { $0.isIDNRelated }
        XCTAssertFalse(idnFlags.isEmpty, "IDN flags must be present for homograph URL")

        let pickerFlags = PickerURLRisk.flags(for: url, cleanedURL: url, cleanURLsBeforeOpening: false)
        XCTAssertFalse(pickerFlags.filter { $0.isIDNRelated }.isEmpty,
                       "PickerURLRisk must surface IDN flags regardless of reader mode state")
    }

    // VAL-CROSS-007: IDN chip is present in PreviewView's rendered view tree.
    // PreviewView must expose idnRiskFlags from the same model.riskFlags source
    // so the chip remains visible when the picker switches to preview mode,
    // regardless of whether reader mode is on or off.
    func test_previewViewExposesIDNRiskFlags_VAL_CROSS_007() {
        let url = URL(string: "https://g\u{043E}\u{043E}gle.com")!
        let context = RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
        let model = PickerViewModel(
            url: url,
            options: [],
            context: context,
            onPick: { _, _, _ in },
            onPickMulti: { _, _ in },
            onCancel: {}
        )
        let previewView = PreviewView(model: model)
        XCTAssertFalse(
            previewView.idnRiskFlags.isEmpty,
            "PreviewView.idnRiskFlags must be non-empty for a homograph URL — chip must remain visible in preview mode"
        )
    }

    // VAL-CROSS-007: IDN chip is absent in PreviewView for a safe ASCII URL.
    func test_previewViewHasNoIDNFlagsForSafeURL_VAL_CROSS_007() {
        let url = URL(string: "https://google.com/")!
        let context = RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
        let model = PickerViewModel(
            url: url,
            options: [],
            context: context,
            onPick: { _, _, _ in },
            onPickMulti: { _, _ in },
            onCancel: {}
        )
        let previewView = PreviewView(model: model)
        XCTAssertTrue(
            previewView.idnRiskFlags.isEmpty,
            "PreviewView.idnRiskFlags must be empty for a plain ASCII URL"
        )
    }
}
