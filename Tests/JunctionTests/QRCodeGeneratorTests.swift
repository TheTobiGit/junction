import XCTest
import CoreImage
@testable import JunctionApp

final class QRCodeGeneratorTests: XCTestCase {

    // VAL-M3-QR-001: QR helper produces a non-empty CGImage for a non-empty URL
    func test_generateReturnsNonNilCGImageForNonEmptyURL_VAL_M3_QR_001() {
        let result = QRCodeGenerator.generate(from: "https://example.com")
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.width, 0)
        XCTAssertGreaterThan(result!.height, 0)
    }

    // VAL-M3-QR-002: QR helper handles long URLs without throwing
    func test_generateHandlesLongURLWithoutThrowing_VAL_M3_QR_002() {
        let longURL = "https://example.com/" + String(repeating: "a", count: 2028)
        XCTAssertEqual(longURL.count, 2048)
        let result = QRCodeGenerator.generate(from: longURL)
        XCTAssertNotNil(result)
    }

    // VAL-M3-QR-003: QR helper rejects empty input
    func test_generateReturnsNilForEmptyInput_VAL_M3_QR_003() {
        let result = QRCodeGenerator.generate(from: "")
        XCTAssertNil(result)
    }

    // VAL-M3-QR-004: QR encodes the cleaned URL, not the raw input
    func test_pickerPassesCleanedURLToQRHelper_VAL_M3_QR_004() {
        let rawURL = URL(string: "https://example.com/?utm_source=test&keep=1")!
        var capturedArgument: String?
        let context = RouteContext(source: nil, focus: FocusInfo(modeIdentifier: nil, modeName: nil))
        let model = PickerViewModel(
            url: rawURL,
            options: [],
            context: context,
            onPick: { _, _, _ in },
            onPickMulti: { _, _ in },
            onCancel: {}
        )
        model.qrImageProvider = { urlString in
            capturedArgument = urlString
            return nil
        }
        model.openQRSheet()
        XCTAssertNotNil(capturedArgument)
        XCTAssertFalse(
            capturedArgument?.contains("utm_source") ?? true,
            "QR helper must receive cleaned URL without tracker params"
        )
        XCTAssertTrue(
            capturedArgument?.contains("keep=1") ?? false,
            "QR helper must preserve non-tracker params"
        )
    }
}
