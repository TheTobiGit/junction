import AppKit
import Foundation
import JunctionCore

enum ClipboardURLContext {
    static func analyze(_ url: URL) -> (
        trace: URLTransformResult,
        riskFlags: [RiskFlag],
        matchedRule: DomainRule?,
        matchedAction: RuleAction
    ) {
        let context = RouteContext(
            source: FrontmostTracker.shared.lastNonJunction,
            focus: FocusTracker.current()
        )
        let route = URLRouteResolver.resolve(url: url, context: context)
        let flags = PickerURLRisk.flags(
            for: url,
            cleanedURL: route.trace.final,
            cleanURLsBeforeOpening: route.cleaningEnabled
        )
        return (route.trace, flags, route.match.rule, route.match.action)
    }
}

struct ClipboardHUDAnalysis {
    let sourceURL: URL
    let trace: URLTransformResult
    let riskFlags: [RiskFlag]
    let matchedRule: DomainRule?
    let matchedAction: RuleAction

    init(url: URL) {
        let result = ClipboardURLContext.analyze(url)
        sourceURL = url
        trace = result.trace
        riskFlags = result.riskFlags
        matchedRule = result.matchedRule
        matchedAction = result.matchedAction
    }
}

enum ClipboardLinkStatus {
    case ok
    case cleaned
    case caution
    case blocked
}

@MainActor
final class ClipboardHUDViewModel: ObservableObject {
    let originalURL: URL
    @Published private(set) var analysis: ClipboardHUDAnalysis

    @Published private(set) var faviconData: Data?
    @Published var showQR = false
    @Published private(set) var qrImage: CGImage?
    @Published var isExpanding = false
    @Published var urlExpanded = false
    @Published private(set) var copyFeedback: String?

    var sourceURL: URL { analysis.sourceURL }
    var trace: URLTransformResult { analysis.trace }
    var riskFlags: [RiskFlag] { analysis.riskFlags }
    var matchedRule: DomainRule? { analysis.matchedRule }
    var matchedAction: RuleAction { analysis.matchedAction }

    var cleaned: URL { analysis.trace.final }
    var didClean: Bool { analysis.trace.didChange }
    var isShortened: Bool { ShortenerExpander.isShortened(analysis.sourceURL) }

    private var effectiveCleaningEnabled: Bool {
        DomainRule.resolveCleanFlag(
            rule: analysis.matchedRule,
            globalEnabled: SettingsStore.shared.settings.cleanURLsBeforeOpening
        )
    }

    /// URL shown and used for copy/QR/share/default browser — mirrors the picker.
    var openURL: URL {
        PickerViewModel.displayURL(
            raw: analysis.sourceURL,
            cleaned: analysis.trace.final,
            cleaningEnabled: effectiveCleaningEnabled
        )
    }

    var displayHost: String {
        if let host = openURL.host, !host.isEmpty { return host }
        return openURL.absoluteString
    }

    var willOpenCleaned: Bool {
        PickerViewModel.willOpenCleaned(
            didClean: didClean,
            cleaningEnabled: effectiveCleaningEnabled
        )
    }

    var linkStatus: ClipboardLinkStatus {
        if matchedAction == .block { return .blocked }
        if !riskFlags.isEmpty { return .caution }
        if willOpenCleaned { return .cleaned }
        return .ok
    }

    var statusHelp: String {
        switch linkStatus {
        case .ok: return "No trackers removed, no warnings"
        case .cleaned: return traceTooltip
        case .caution: return "Tap for warning details"
        case .blocked: return "A rule blocks this host"
        }
    }

    var traceTooltip: String {
        let lines = trace.steps.map { "• " + URLPipelineStepLabel.label(for: $0.identifier) }
        return (["Stripped before opening:"] + lines).joined(separator: "\n")
    }

    init(url: URL) {
        originalURL = url
        analysis = ClipboardHUDAnalysis(url: url)
        loadFavicon()
    }

    func toggleQR() {
        showQR.toggle()
        if showQR, qrImage == nil {
            qrImage = QRCodeGenerator.generate(from: openURL.absoluteString)
        }
    }

    func expandShortener() {
        guard isShortened, !isExpanding else { return }
        isExpanding = true
        ShortenerExpander.shared.expand(analysis.sourceURL) { [weak self] resolved in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isExpanding = false
                self.analysis = ClipboardHUDAnalysis(url: resolved)
                self.loadFavicon()
                if self.showQR {
                    self.qrImage = QRCodeGenerator.generate(from: self.openURL.absoluteString)
                }
            }
        }
    }

    func copyCleaned() {
        copyString(openURL.absoluteString)
        showCopyFeedback(cleaned: true)
    }

    func copyOriginalLink() {
        copyString(originalURL.absoluteString)
        showCopyFeedback(cleaned: false, original: true)
    }

    func copyDomain() {
        guard let host = openURL.host else { return }
        copyString(host)
        showCopyFeedback(message: "Copied domain")
    }

    private func showCopyFeedback(cleaned: Bool, original: Bool = false) {
        let message: String
        if original {
            message = "Copied original"
        } else if !riskFlags.isEmpty {
            message = "Copied · review link"
        } else if cleaned && willOpenCleaned {
            message = "Copied · cleaned"
        } else {
            message = "Copied"
        }
        showCopyFeedback(message: message)
    }

    private func showCopyFeedback(message: String) {
        copyFeedback = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.copyFeedback = nil
        }
    }

    private func copyString(_ value: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(value, forType: .string)
    }

    private func loadFavicon() {
        guard let host = openURL.host ?? originalURL.host else { return }
        HostFaviconFetcher.fetch(host: host) { [weak self] data in
            DispatchQueue.main.async { self?.faviconData = data }
        }
    }
}
