import XCTest
import WebKit
@testable import JunctionApp

final class PreviewWebViewFactoryTests: XCTestCase {
    private var savedProvider: (() -> String?)?

    override func setUp() {
        super.setUp()
        savedProvider = PreviewWebViewFactory.readabilitySourceProvider
        let repoRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let readabilityURL = repoRoot.appendingPathComponent("Resources/Readability.js")
        PreviewWebViewFactory.readabilitySourceProvider = {
            try? String(contentsOf: readabilityURL, encoding: .utf8)
        }
    }

    override func tearDown() {
        if let saved = savedProvider {
            PreviewWebViewFactory.readabilitySourceProvider = saved
        }
        super.tearDown()
    }

    // VAL-M4-READER-003: PreviewWebViewFactory injects Readability when reader mode is on
    func test_userScriptsContainReadabilityMarkerWhenReaderEnabled_VAL_M4_READER_003() {
        let scripts = PreviewWebViewFactory.userScripts(readerEnabled: true)
        let allSource = scripts.map { $0.source }.joined()
        XCTAssertTrue(
            allSource.contains("function Readability("),
            "userScripts(readerEnabled: true) must include Readability.js source"
        )
        XCTAssertTrue(
            allSource.contains("new Readability("),
            "userScripts(readerEnabled: true) must include the reader wrapper invoking new Readability(...)"
        )
    }

    func test_userScriptsDoNotContainReadabilityWhenReaderDisabled_VAL_M4_READER_003() {
        let scripts = PreviewWebViewFactory.userScripts(readerEnabled: false)
        let allSource = scripts.map { $0.source }.joined()
        XCTAssertFalse(
            allSource.contains("function Readability("),
            "userScripts(readerEnabled: false) must not include Readability.js source"
        )
    }

    func test_readerEnabledScriptsRunAtDocumentEnd_VAL_M4_READER_003() {
        let scripts = PreviewWebViewFactory.userScripts(readerEnabled: true)
        let readerScripts = scripts.filter { $0.source.contains("function Readability(") || $0.source.contains("new Readability(") }
        XCTAssertFalse(readerScripts.isEmpty, "Reader scripts must be present when readerEnabled is true")
        for script in readerScripts {
            XCTAssertEqual(
                script.injectionTime, .atDocumentEnd,
                "Reader scripts must inject at document end so the DOM is ready"
            )
        }
    }
}
