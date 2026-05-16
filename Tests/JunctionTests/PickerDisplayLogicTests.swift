import XCTest
@testable import JunctionApp

final class PickerDisplayLogicTests: XCTestCase {
    private let raw = URL(string: "https://example.com/?utm_source=email")!
    private let cleaned = URL(string: "https://example.com/")!

    func test_willOpenCleaned_trueWhenChangedAndEnabled() {
        XCTAssertTrue(PickerViewModel.willOpenCleaned(didClean: true, cleaningEnabled: true))
    }

    func test_willOpenCleaned_falseWhenCleaningDisabled() {
        XCTAssertFalse(PickerViewModel.willOpenCleaned(didClean: true, cleaningEnabled: false))
    }

    func test_willOpenCleaned_falseWhenURLDidNotChange() {
        XCTAssertFalse(PickerViewModel.willOpenCleaned(didClean: false, cleaningEnabled: true))
    }

    func test_displayURL_picksCleanedWhenEnabled() {
        let display = PickerViewModel.displayURL(raw: raw, cleaned: cleaned, cleaningEnabled: true)
        XCTAssertEqual(display, cleaned)
    }

    func test_displayURL_picksRawWhenCleaningDisabled() {
        let display = PickerViewModel.displayURL(raw: raw, cleaned: cleaned, cleaningEnabled: false)
        XCTAssertEqual(display, raw)
    }

    func test_displayURL_returnsRawWhenNoChange() {
        let display = PickerViewModel.displayURL(raw: raw, cleaned: raw, cleaningEnabled: true)
        XCTAssertEqual(display, raw)
    }
}
