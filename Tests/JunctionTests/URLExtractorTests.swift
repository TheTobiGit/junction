import XCTest
@testable import JunctionApp

final class URLExtractorTests: XCTestCase {
    func test_emptyTextYieldsNoURLs() {
        XCTAssertTrue(URLExtractor.extract(from: "").isEmpty)
        XCTAssertTrue(URLExtractor.extract(from: "no links here").isEmpty)
    }

    func test_singleURLExtracted() {
        let urls = URLExtractor.extract(from: "see https://example.com/path?x=1")
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.host, "example.com")
    }

    func test_newlineSeparatedURLsExtractedInOrder() {
        let text = """
        https://a.com/one
        https://b.com/two
        https://c.com/three
        """
        let urls = URLExtractor.extract(from: text)
        XCTAssertEqual(urls.map { $0.host }, ["a.com", "b.com", "c.com"])
    }

    func test_duplicatesCollapsed() {
        let text = "https://a.com/x https://a.com/x https://b.com/y"
        let urls = URLExtractor.extract(from: text)
        XCTAssertEqual(urls.count, 2)
        XCTAssertEqual(urls.map { $0.host }, ["a.com", "b.com"])
    }

    func test_nonHttpSchemesIgnored() {
        let urls = URLExtractor.extract(from: "ftp://example.com mailto:foo@bar.com https://ok.com")
        XCTAssertEqual(urls.map { $0.host }, ["ok.com"])
    }

    func test_respectsMaxCap() {
        let big = (0..<10).map { "https://h\($0).com" }.joined(separator: " ")
        let urls = URLExtractor.extract(from: big, max: 3)
        XCTAssertEqual(urls.count, 3)
    }
}
