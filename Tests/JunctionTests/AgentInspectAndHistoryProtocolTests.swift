import XCTest
import JunctionCore

final class AgentInspectAndHistoryProtocolTests: XCTestCase {
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func test_inspectRequestRoundTrip() throws {
        let original = AgentRequest.inspect(url: "https://example.com")
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .inspect(let url) = decoded else {
            return XCTFail("expected .inspect")
        }
        XCTAssertEqual(url, "https://example.com")
    }

    func test_listHistoryRequestRoundTrip() throws {
        let original = AgentRequest.listHistory(limit: 5)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(AgentRequest.self, from: data)
        guard case .listHistory(let limit) = decoded else {
            return XCTFail("expected .listHistory")
        }
        XCTAssertEqual(limit, 5)
    }

    func test_inspectResponseRoundTrip() throws {
        let result = AgentInspectResult(
            original: "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com",
            cleaned: "https://example.com",
            steps: [
                AgentInspectStep(identifier: "outgoing-redirect-unwrapper", after: "https://example.com")
            ],
            flags: [
                AgentInspectFlag(level: "warning", title: "Punycode host", detail: "Confirm host"),
            ]
        )
        let response = AgentResponse.inspectResult(result)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(AgentResponse.self, from: data)
        guard case .inspectResult(let r) = decoded else {
            return XCTFail("expected .inspectResult")
        }
        XCTAssertEqual(r.original, result.original)
        XCTAssertEqual(r.cleaned, result.cleaned)
        XCTAssertEqual(r.steps.count, 1)
        XCTAssertEqual(r.steps.first?.identifier, "outgoing-redirect-unwrapper")
        XCTAssertEqual(r.flags.first?.title, "Punycode host")
    }

    func test_historyResponseRoundTrip() throws {
        let entries = [
            AgentHistoryEntry(
                timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                originalURL: "https://example.com/?utm_source=email",
                cleanedURL: "https://example.com",
                outcome: "opened",
                targetBundleID: "com.apple.Safari",
                ruleLabel: "equals:example.com",
                cleaningSteps: ["tracker-stripper"]
            )
        ]
        let response = AgentResponse.history(entries)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(AgentResponse.self, from: data)
        guard case .history(let h) = decoded else {
            return XCTFail("expected .history")
        }
        XCTAssertEqual(h.count, 1)
        XCTAssertEqual(h.first?.outcome, "opened")
        XCTAssertEqual(h.first?.cleaningSteps, ["tracker-stripper"])
    }

    func test_unknownResponseKindFails() throws {
        let json = #"{"kind":"future-shape"}"#.data(using: .utf8)!
        XCTAssertThrowsError(try decoder.decode(AgentResponse.self, from: json))
    }

    func test_existingResponsesStillRoundTrip() throws {
        let pong = try decoder.decode(AgentResponse.self, from: try encoder.encode(AgentResponse.pong))
        if case .pong = pong {} else { XCTFail("expected .pong") }

        let ok = try decoder.decode(
            AgentResponse.self,
            from: try encoder.encode(AgentResponse.ok(message: "hi"))
        )
        if case .ok(let m) = ok { XCTAssertEqual(m, "hi") } else { XCTFail("expected .ok") }
    }

    // MARK: - addRule cleanOverride

    func test_addRuleRoundTripsCleanOverride() throws {
        for value: Bool? in [nil, true, false] {
            let original = AgentRequest.addRule(
                hostKind: "equals",
                hostValue: "internal.example.com",
                target: "app:com.apple.Safari",
                cleanOverride: value,
                pathKind: nil,
                pathValue: nil,
                sourceApps: nil
            )
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(AgentRequest.self, from: data)
            guard case .addRule(_, _, _, let decodedOverride, _, _, _) = decoded else {
                return XCTFail("expected .addRule")
            }
            XCTAssertEqual(decodedOverride, value, "for cleanOverride=\(String(describing: value))")
        }
    }

    func test_addRuleDecodesLegacyPayloadWithoutCleanOverride() throws {
        let json = #"""
        {"kind":"addRule","hostKind":"equals","hostValue":"example.com","target":null}
        """#.data(using: .utf8)!
        let decoded = try decoder.decode(AgentRequest.self, from: json)
        guard case .addRule(let kind, let host, let target, let cleanOverride, let pathKind, let pathValue, let sourceApps) = decoded else {
            return XCTFail("expected .addRule")
        }
        XCTAssertEqual(kind, "equals")
        XCTAssertEqual(host, "example.com")
        XCTAssertNil(target)
        XCTAssertNil(cleanOverride)
        XCTAssertNil(pathKind)
        XCTAssertNil(pathValue)
        XCTAssertNil(sourceApps)
    }

    // MARK: - AgentRuleSummary cleanOverride forward-compat

    func test_ruleSummaryRoundTripsCleanOverride() throws {
        for value: Bool? in [nil, true, false] {
            let summary = AgentRuleSummary(
                hostKind: "equals",
                hostValue: "internal.example.com",
                action: "app:com.apple.Safari",
                cleanOverride: value
            )
            let data = try encoder.encode(summary)
            let decoded = try decoder.decode(AgentRuleSummary.self, from: data)
            XCTAssertEqual(decoded.cleanOverride, value)
        }
    }

    func test_ruleSummaryDecodesLegacyPayloadWithoutField() throws {
        let json = #"""
        {"hostKind":"equals","hostValue":"example.com","action":"ask"}
        """#.data(using: .utf8)!
        let summary = try decoder.decode(AgentRuleSummary.self, from: json)
        XCTAssertEqual(summary.hostKind, "equals")
        XCTAssertEqual(summary.action, "ask")
        XCTAssertNil(summary.cleanOverride)
    }
}
