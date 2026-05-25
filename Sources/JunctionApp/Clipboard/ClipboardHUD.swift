import AppKit
import SwiftUI
import JunctionCore

struct ClipboardHUDHandlers {
    var onRoute: ((URL) -> Void)?
}

final class ClipboardHUDController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?
    private var handlers = ClipboardHUDHandlers()
    private var lastPlacedHeight: CGFloat = 0
    private let autoDismissInterval: TimeInterval = 14

    private static let edgeInset: CGFloat = 22

    func configure(handlers: ClipboardHUDHandlers) {
        self.handlers = handlers
    }

    func present(url: URL) {
        dismissWork?.cancel()
        lastPlacedHeight = 0

        let panel = panel ?? makePanel()
        self.panel = panel

        let view = ClipboardHUDView(
            url: url,
            handlers: handlers,
            onDismiss: { [weak self] in self?.dismiss(animated: true) },
            onHoverChanged: { [weak self] hovering in
                self?.setHoverPaused(hovering)
            },
            onPreferredSize: { [weak self] size in
                self?.resizePanel(to: size)
            }
        )
        let host = NSHostingView(rootView: view)
        Self.configureTransparentHosting(host)
        host.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = host

        if let contentView = panel.contentView {
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                host.topAnchor.constraint(equalTo: contentView.topAnchor),
                host.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            ])
        }

        placeTopRight(panel, size: panel.frame.size, animate: false)
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        scheduleDismiss(after: autoDismissInterval)
    }

    private static func configureTransparentHosting<Content: View>(_ host: NSHostingView<Content>) {
        host.wantsLayer = true
        host.layer?.backgroundColor = NSColor.clear.cgColor
        host.layer?.cornerRadius = ClipboardHUDMetrics.cornerRadius
        host.layer?.masksToBounds = true
    }

    private func setHoverPaused(_ hovering: Bool) {
        if hovering {
            dismissWork?.cancel()
        } else {
            scheduleDismiss(after: autoDismissInterval)
        }
    }

    private func scheduleDismiss(after interval: TimeInterval) {
        dismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss(animated: true) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }

    private func dismiss(animated: Bool) {
        dismissWork?.cancel()
        guard let panel else { return }
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        })
    }

    private func resizePanel(to size: CGSize) {
        guard let panel else { return }
        let height = max(88, size.height)
        let animate = abs(height - lastPlacedHeight) > 2
        lastPlacedHeight = height
        placeTopRight(
            panel,
            size: NSSize(width: ClipboardHUDMetrics.cardWidth, height: height),
            animate: animate
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: ClipboardHUDMetrics.cardWidth, height: 120),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        return panel
    }

    private func placeTopRight(_ panel: NSPanel, size: NSSize, animate: Bool) {
        let frame = Self.topRightFrame(size: size, on: NSScreen.main)
        if animate {
            panel.animator().setFrame(frame, display: true)
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private static func topRightFrame(size: NSSize, on screen: NSScreen?) -> NSRect {
        guard let visible = (screen ?? NSScreen.main)?.visibleFrame else {
            return NSRect(x: 120, y: 120, width: size.width, height: size.height)
        }
        var origin = NSPoint(
            x: visible.maxX - size.width - edgeInset,
            y: visible.maxY - size.height - edgeInset
        )
        if origin.y + size.height > visible.maxY - edgeInset {
            origin.y = visible.maxY - size.height - edgeInset
        }
        if origin.x < visible.minX + edgeInset { origin.x = visible.minX + edgeInset }
        if origin.y < visible.minY + edgeInset { origin.y = visible.minY + edgeInset }
        return NSRect(origin: origin, size: size)
    }
}

// MARK: - URL analysis

enum ClipboardURLContext {
    static func analyze(_ url: URL) -> (
        trace: URLTransformResult,
        riskFlags: [RiskFlag],
        matchedRule: DomainRule?,
        matchedAction: RuleAction
    ) {
        let globalSettings = SettingsStore.shared.settings
        let globalTrace = URLTransformers.default.runTraced(url)
        let context = RouteContext(
            source: FrontmostTracker.shared.lastNonJunction,
            focus: FocusTracker.current()
        )
        let match = RulesStore.shared.match(
            url: URLTransformers.urlForRuleMatching(url),
            context: context
        )
        let trace: URLTransformResult
        if let ruleOverrides = match.rule?.trackerOverrides {
            trace = URLTransformers.pipeline(
                globalOverrides: globalSettings.trackerOverrides,
                ruleOverrides: ruleOverrides
            ).runTraced(url)
        } else {
            trace = globalTrace
        }
        let cleaningEnabled = DomainRule.resolveCleanFlag(
            rule: match.rule,
            globalEnabled: globalSettings.cleanURLsBeforeOpening
        )
        let flags = PickerURLRisk.flags(
            for: url,
            cleanedURL: trace.final,
            cleanURLsBeforeOpening: cleaningEnabled
        )
        return (trace, flags, match.rule, match.action)
    }
}

// MARK: - Root view

private struct ClipboardHUDSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next.width > 0, next.height > 0 { value = next }
    }
}

struct ClipboardHUDView: View {
    let url: URL
    let handlers: ClipboardHUDHandlers
    let onDismiss: () -> Void
    let onHoverChanged: (Bool) -> Void
    let onPreferredSize: (CGSize) -> Void

    @ObservedObject private var appSettings = SettingsStore.shared
    @StateObject private var model: ClipboardHUDViewModel
    @State private var appeared = false
    @State private var showRiskDetail = false

    init(
        url: URL,
        handlers: ClipboardHUDHandlers,
        onDismiss: @escaping () -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onPreferredSize: @escaping (CGSize) -> Void
    ) {
        self.url = url
        self.handlers = handlers
        self.onDismiss = onDismiss
        self.onHoverChanged = onHoverChanged
        self.onPreferredSize = onPreferredSize
        _model = StateObject(wrappedValue: ClipboardHUDViewModel(url: url))
    }

    private var accent: Color { appSettings.settings.accentPreset.swiftUIColor }
    private var theme: ChromeTheme { appSettings.settings.chromeTheme }

    var body: some View {
        PickerGlassPanel(
            theme: theme,
            accent: accent,
            cornerRadius: ClipboardHUDMetrics.cornerRadius,
            subtle: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                identityRow
                urlField
                actionBar
                if model.showQR {
                    qrRow
                }
            }
            .padding(12)
        }
        .frame(width: ClipboardHUDMetrics.cardWidth)
        .shadow(color: .black.opacity(0.34), radius: 18, y: 7)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.98, anchor: .topTrailing)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: ClipboardHUDSizeKey.self, value: proxy.size)
            }
        }
        .onPreferenceChange(ClipboardHUDSizeKey.self, perform: onPreferredSize)
        .onHover(perform: onHoverChanged)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                appeared = true
            }
        }
    }

    private var identityRow: some View {
        HStack(spacing: 8) {
            statusDot
            FaviconView(data: model.faviconData, fallbackSize: 9)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(model.displayHost)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                copyMenu
                ClipboardHUDIconButton(symbol: "xmark", help: "Dismiss", action: onDismiss)
            }
        }
    }

    private var statusDot: some View {
        Button {
            if model.linkStatus == .caution { showRiskDetail.toggle() }
        } label: {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
        }
        .buttonStyle(.plain)
        .help(model.statusHelp)
        .popover(isPresented: $showRiskDetail, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(model.riskFlags) { flag in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flag.title).font(.system(size: 12, weight: .semibold))
                        Text(flag.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(width: 260)
        }
    }

    private var statusColor: Color {
        switch model.linkStatus {
        case .ok: return Color.white.opacity(0.32)
        case .cleaned: return accent
        case .caution: return .orange
        case .blocked: return .red
        }
    }

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.openURL.absoluteString)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.72))
                .lineLimit(model.urlExpanded ? 3 : 1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .onTapGesture(count: 2) { model.urlExpanded.toggle() }
            HStack(spacing: 8) {
                if let feedback = model.copyFeedback {
                    Text(feedback)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(copyFeedbackTint(for: feedback))
                }
                if model.isShortened {
                    if model.isExpanding {
                        Text("Expanding…")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Expand short link", action: model.expandShortener)
                            .font(.system(size: 9, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundStyle(accent)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func copyFeedbackTint(for message: String) -> Color {
        if message.contains("review") { return .orange }
        if message.contains("cleaned") { return accent }
        return .secondary
    }

    private var copyMenu: some View {
        Menu {
            Button("Copy cleaned link", action: model.copyCleaned)
            if model.didClean {
                Button("Copy original link", action: model.copyOriginalLink)
            }
        } label: {
            ClipboardHUDIconButton(symbol: "doc.on.doc", help: "Copy link")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var routeURL: URL { model.sourceURL }

    private var actionBar: some View {
        HStack(spacing: 6) {
            Button {
                handlers.onRoute?(routeURL)
                onDismiss()
            } label: {
                Text("Open")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(height: ClipboardHUDMetrics.actionHeight)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent))
            .help("Opens via your rules, or the picker when you still need to choose")
            .disabled(model.matchedAction == .block)

            HStack(spacing: 2) {
                ClipboardHUDIconButton(
                    symbol: "qrcode",
                    help: "Send to phone",
                    isActive: model.showQR,
                    accent: accent
                ) {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        model.toggleQR()
                    }
                }
                moreMenu
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.07))
            )
        }
    }

    private var moreMenu: some View {
        Menu {
            if model.matchedAction != .block {
                Button("Open in default browser") {
                    NSWorkspace.shared.open(model.openURL)
                    onDismiss()
                }
            }
            Button("Copy domain", action: model.copyDomain)
            Divider()
            Button("Share…") { shareOpenURL() }
        } label: {
            ClipboardHUDIconButton(symbol: "ellipsis", help: "More")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var qrRow: some View {
        HStack(spacing: 10) {
            ClipboardQRPlate(image: model.qrImage, size: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text("Send to phone").font(.system(size: 11, weight: .semibold))
                Text("Scan to open this link")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func shareOpenURL() {
        let picker = NSSharingServicePicker(items: [model.openURL as NSURL])
        let anchor: NSView = {
            if let panel = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible }),
               let view = panel.contentView {
                return view
            }
            return NSApp.keyWindow?.contentView ?? NSView()
        }()
        picker.show(relativeTo: .zero, of: anchor, preferredEdge: .minY)
    }
}

// MARK: - View model

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

// MARK: - Components

private enum ClipboardHUDMetrics {
    static let cardWidth: CGFloat = 304
    static let cornerRadius: CGFloat = 14
    static let actionHeight: CGFloat = 30
    static let iconSize: CGFloat = 26
}

private struct ClipboardHUDIconButton: View {
    let symbol: String
    let help: String
    var isActive: Bool = false
    var accent: Color? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .help(help)
    }

    private var label: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isActive ? (accent ?? .accentColor) : .secondary)
            .frame(width: ClipboardHUDMetrics.iconSize, height: ClipboardHUDMetrics.iconSize)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? (accent ?? .accentColor).opacity(0.14) : Color.clear)
            )
    }
}

struct ClipboardQRPlate: View {
    let image: CGImage?
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let cgImage = image {
                Image(nsImage: NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                ))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ProgressView().controlSize(.small)
                    .frame(width: size, height: size)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }
}
