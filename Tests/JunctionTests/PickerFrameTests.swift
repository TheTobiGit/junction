@testable import JunctionApp
import XCTest

final class PickerFrameTests: XCTestCase {

    private let controller = PickerPanelController()

    func test_listStyleDesiredSize_reservesDockShadowInset() {
        let bodyHeight = PickerView.listStyleHeight(forOptionCount: 8)
        let size = PickerView.desiredSize(forOptionCount: 8, style: .list)

        XCTAssertEqual(size.width, PickerView.listStyleWidth, accuracy: 0.001)
        XCTAssertEqual(
            size.height,
            bodyHeight + PickerView.listDockGap + PickerView.listDockHeight + PickerView.listDockBottomInset,
            accuracy: 0.001,
            "List picker window must reserve bottom inset so the shortcut dock shadow is not clipped."
        )
    }

    func test_listStyleHeight_showsNineRowsBeforeScrolling() {
        let oneThroughNineHeight = PickerView.listStyleHeight(forOptionCount: 9)
        let tenthHeight = PickerView.listStyleHeight(forOptionCount: 10)

        XCTAssertGreaterThan(
            oneThroughNineHeight,
            PickerView.listStyleHeight(forOptionCount: 8),
            "List picker should grow through the ninth keyboard-selectable row."
        )
        XCTAssertEqual(
            tenthHeight,
            oneThroughNineHeight,
            accuracy: 0.001,
            "List picker should stop growing after nine rows so the tenth browser scrolls."
        )
    }

    func test_restoreFrame_usesCurrentPickerSizeWithSavedOrigin() {
        let saved = CGRect(x: 60, y: 70, width: 600, height: PickerView.pickerHeight)
        let currentSize = PickerView.desiredSize(forOptionCount: 8, style: .list)
        let restored = PickerPanelController.restoredFrame(from: saved, currentSize: currentSize)

        XCTAssertEqual(restored.origin.x, saved.origin.x, accuracy: 0.001)
        XCTAssertEqual(restored.origin.y, saved.origin.y, accuracy: 0.001)
        XCTAssertEqual(restored.size.width, currentSize.width, accuracy: 0.001)
        XCTAssertEqual(restored.size.height, currentSize.height, accuracy: 0.001)
    }

    // VAL-M3-FRAME-003: clampToScreen returns a frame intersecting at least one
    // NSScreen.visibleFrame when input is fully off-screen.
    func test_clampToScreen_returnsOnScreenWhenFullyOffScreen_VAL_M3_FRAME_003() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        // Place frame far to the right of every screen
        let offScreen = CGRect(
            x: visible.maxX + 5000,
            y: visible.midY,
            width: 480,
            height: 320
        )
        let clamped = controller.clampToScreen(offScreen, screens: [screen])
        let intersection = clamped.intersection(visible)
        XCTAssertTrue(intersection.width > 0 && intersection.height > 0,
                      "Clamped frame must intersect the screen's visibleFrame")
    }

    // VAL-M3-FRAME-004: clampToScreen is identity when input fits a current screen.
    func test_clampToScreen_identityWhenFitsScreen_VAL_M3_FRAME_004() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let fitting = CGRect(
            x: visible.minX + 50,
            y: visible.minY + 50,
            width: min(480, visible.width - 100),
            height: min(320, visible.height - 100)
        )
        let clamped = controller.clampToScreen(fitting, screens: [screen])
        XCTAssertEqual(clamped, fitting, "Frame that fits within visibleFrame must be returned unchanged")
    }

    // VAL-M3-FRAME-005: clampToScreen preserves size when only origin is off-screen.
    func test_clampToScreen_preservesSizeWhenOnlyOriginOffScreen_VAL_M3_FRAME_005() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = CGSize(width: min(480, visible.width - 20), height: min(320, visible.height - 20))
        // Origin is off-screen to the left
        let offOrigin = CGRect(
            x: visible.minX - 200,
            y: visible.minY + 50,
            width: size.width,
            height: size.height
        )
        let clamped = controller.clampToScreen(offOrigin, screens: [screen])
        XCTAssertEqual(clamped.size.width, size.width, accuracy: 0.001,
                       "Width must be preserved when only origin is off-screen")
        XCTAssertEqual(clamped.size.height, size.height, accuracy: 0.001,
                       "Height must be preserved when only origin is off-screen")
    }

    // VAL-M3-FRAME-007: Saved frame from a now-disconnected display (fully off-screen)
    // does not place panel off-screen — clampToScreen brings it onto a current screen.
    func test_clampToScreen_offScreenFromDisconnectedDisplay_VAL_M3_FRAME_007() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        // Simulate a frame saved from a secondary display that is no longer connected
        let disconnectedFrame = CGRect(
            x: visible.maxX + 2560,
            y: visible.maxY + 1440,
            width: 480,
            height: 320
        )
        let clamped = controller.clampToScreen(disconnectedFrame, screens: [screen])
        let intersection = clamped.intersection(visible)
        XCTAssertTrue(intersection.width > 0 && intersection.height > 0,
                      "Frame from disconnected display must be clamped onto a current screen")
    }
}
