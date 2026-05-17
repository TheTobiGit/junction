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
}
