import SwiftUI
import AppKit
import JunctionCore

final class PickerViewModel: ObservableObject {
    let url: URL
    let cleanedURL: URL
    let cleaningTrace: URLTransformResult
    let options: [LaunchOption]
    let context: RouteContext
    let riskFlags: [RiskFlag]
    /// Rule matching the cleaned URL at the time the picker was presented.
    /// Cached so the per-rule `cleanOverride` is consulted without re-running
    /// the matcher on every SwiftUI render.
    let matchedRule: DomainRule?
    /// Stable favicon: host service icon fills first; page preview replaces it when sharper **or** when still showing the generic host placeholder (same-size page icons beat DuckDuckGo).
    @Published private(set) var displayFaviconData: Data? = nil
    @Published var selectedIndex: Int = 0
    @Published var rememberChoice: Bool = false
    @Published var multiSelection: Set<String> = []
    @Published var preview: LinkPreview? = nil
    /// Fast host-level icon (e.g. DuckDuckGo); superseded by page favicon when available.
    @Published private(set) var hostFaviconData: Data? = nil
    @Published var incognitoMode: Bool = false
    @Published var optionKeyHeld: Bool = false
    @Published var previewMode: Bool = false
    @Published var previewTitle: String? = nil
    @Published var previewLoading: Bool = false
    @Published var previewProgress: Double = 0
    @Published var showQRSheet: Bool = false
    @Published private(set) var qrImage: CGImage? = nil
    var qrImageProvider: (String) -> CGImage? = QRCodeGenerator.generate(from:)
    @Published var expandedGroupIDs: Set<String> = []
    @Published var cheatSheetVisible: Bool = false

    private let pickHandler: (LaunchOption, Bool, Bool) -> Void
    private let pickMultiHandler: ([LaunchOption], Bool) -> Void
    private let cancelHandler: () -> Void
    private let openPreferencesHandler: (() -> Void)?

    init(
        url: URL,
        options: [LaunchOption],
        context: RouteContext,
        onPick: @escaping (LaunchOption, Bool, Bool) -> Void,
        onPickMulti: @escaping ([LaunchOption], Bool) -> Void,
        onCancel: @escaping () -> Void,
        onOpenPreferences: (() -> Void)? = nil
    ) {
        self.url = url
        let trace = URLTransformers.default.runTraced(url)
        self.cleanedURL = trace.final
        self.cleaningTrace = trace
        self.options = options
        self.context = context
        // Resolve the matching rule once at init — the URL doesn't change for
        // the picker's lifetime, so we can avoid re-running the rule matcher
        // on every SwiftUI re-render. The global cleaning toggle is still
        // read live so user changes mid-presentation take effect.
        self.matchedRule = RulesStore.shared.match(url: trace.final, context: context).rule
        // Risk flags follow the URL that's about to open, including the
        // per-rule `cleanOverride`. Otherwise a rule that forces "Always
        // clean" for a host would still warn against the raw URL's trackers.
        let cleaningEnabled = DomainRule.resolveCleanFlag(
            rule: matchedRule,
            globalEnabled: SettingsStore.shared.settings.cleanURLsBeforeOpening
        )
        self.riskFlags = PickerURLRisk.flags(
            for: url,
            cleanedURL: cleanedURL,
            cleanURLsBeforeOpening: cleaningEnabled
        )
        self.pickHandler = onPick
        self.pickMultiHandler = onPickMulti
        self.cancelHandler = onCancel
        self.openPreferencesHandler = onOpenPreferences
        let grouped = LaunchOptionGrouping.group(options: options)
        self.expandedGroupIDs = LaunchOptionGrouping.defaultExpandedGroupIDs(
            grouped: grouped,
            pinnedTargetKey: SettingsStore.shared.settings.pinnedTargetKey
        )
        loadPreview()
        loadHostFavicon()
    }

    private var displayedFaviconPixelMin: Int?
    /// True when ``displayFaviconData`` came from ``applyHostFaviconCandidate`` (generic host service), not HTML preview.
    private var displayUsesHostServiceFavicon = false

    private func loadPreview() {
        LinkPreviewFetcher.fetch(cleanedURL) { [weak self] preview in
            DispatchQueue.main.async {
                guard let self else { return }
                self.preview = preview
                self.applyPreviewFaviconCandidate(preview?.faviconData)
            }
        }
    }

    private func loadHostFavicon() {
        guard let host = cleanedURL.host ?? url.host else { return }
        HostFaviconFetcher.fetch(host: host) { [weak self] data in
            DispatchQueue.main.async {
                guard let self else { return }
                self.hostFaviconData = data
                self.applyHostFaviconCandidate(data)
            }
        }
    }

    private func applyHostFaviconCandidate(_ data: Data?) {
        guard let data, NSImage(data: data) != nil else { return }
        guard displayFaviconData == nil else { return }
        displayFaviconData = data
        displayedFaviconPixelMin = pixelMinDimension(for: data)
        displayUsesHostServiceFavicon = true
    }

    private func applyPreviewFaviconCandidate(_ data: Data?) {
        guard let data, NSImage(data: data) != nil else { return }
        let newMin = pixelMinDimension(for: data) ?? 0
        if displayFaviconData == nil {
            displayFaviconData = data
            displayedFaviconPixelMin = newMin
            displayUsesHostServiceFavicon = false
            return
        }
        let oldMin = displayedFaviconPixelMin ?? 0
        // Page favicon always replaces the DuckDuckGo placeholder, even at matching size (P2).
        // Otherwise avoid pointless swaps unless meaningfully sharper (1.5× min side).
        let previewWins: Bool
        if displayUsesHostServiceFavicon {
            previewWins = true
        } else if oldMin <= 0 {
            previewWins = newMin > 0
        } else {
            previewWins = newMin * 2 >= oldMin * 3
        }
        guard previewWins else { return }
        displayFaviconData = data
        displayedFaviconPixelMin = newMin
        displayUsesHostServiceFavicon = false
    }

    /// Largest min(width,height) among bitmap reps so multi-resolution ICOs don't under-report (P3).
    private func pixelMinDimension(for imageData: Data) -> Int? {
        guard let img = NSImage(data: imageData) else { return nil }
        let bitmapReps = img.representations.compactMap { $0 as? NSBitmapImageRep }
        var best = 0
        for rep in bitmapReps {
            let w = rep.pixelsWide
            let h = rep.pixelsHigh
            guard w > 0, h > 0 else { continue }
            best = max(best, min(w, h))
        }
        if best > 0 {
            return best
        }
        let s = img.size
        guard s.width > 0, s.height > 0 else { return nil }
        return Int(min(s.width, s.height))
    }

    var host: String {
        RulesStore.normalizedHost(for: url) ?? url.absoluteString
    }

    var displayHost: String {
        cleanedURL.host ?? url.host ?? url.absoluteString
    }

    var rememberHost: String? {
        RulesStore.normalizedHost(for: url)
    }

    func toggleRemember() {
        rememberChoice.toggle()
    }

    func enterPreview() {
        guard !previewMode else { return }
        previewTitle = nil
        previewLoading = true
        previewProgress = 0
        previewMode = true
    }

    func exitPreview() {
        guard previewMode else { return }
        previewMode = false
        previewLoading = false
        previewProgress = 0
    }

    func togglePreview() {
        if previewMode { exitPreview() } else { enterPreview() }
    }

    func openInBrowserFromPreview(remember: Bool? = nil, incognito: Bool? = nil) {
        guard let option = selectedOption() else { return }
        let shouldRemember = remember ?? rememberChoice
        pickHandler(option, shouldRemember, resolvedIncognito(for: option, requested: incognito))
    }

    var didClean: Bool {
        cleanedURL.absoluteString != url.absoluteString
    }

    /// Effective "should we clean before opening" decision for this URL.
    /// Mirrors ``AppDelegate.routeAfterExpansion`` and ``PickerPanelController.openOnce``
    /// so the chip, displayed URL, and the actual open all agree.
    private var effectiveCleaningEnabled: Bool {
        DomainRule.resolveCleanFlag(
            rule: matchedRule,
            globalEnabled: SettingsStore.shared.settings.cleanURLsBeforeOpening
        )
    }

    /// True when the resolved settings cause the open to use the cleaned URL.
    /// The picker uses this to decide whether to show the "cleaned" chip and
    /// the cleaned URL string.
    var willOpenCleaned: Bool {
        Self.willOpenCleaned(didClean: didClean, cleaningEnabled: effectiveCleaningEnabled)
    }

    /// URL the picker should display: matches `urlToOpen` in
    /// ``AppDelegate.routeAfterExpansion``.
    var displayURLString: String {
        Self.displayURL(
            raw: url,
            cleaned: cleanedURL,
            cleaningEnabled: effectiveCleaningEnabled
        ).absoluteString
    }

    /// URL to load in the in-picker preview WebView. Mirrors what would
    /// actually open if the user confirms, so the rendered page matches.
    var previewURL: URL {
        Self.displayURL(
            raw: url,
            cleaned: cleanedURL,
            cleaningEnabled: effectiveCleaningEnabled
        )
    }

    /// Pure helper exposed for unit tests; mirrors what the picker actually
    /// shows without requiring a full ``PickerViewModel`` instance.
    static func willOpenCleaned(didClean: Bool, cleaningEnabled: Bool) -> Bool {
        didClean && cleaningEnabled
    }

    /// Pure helper exposed for unit tests.
    static func displayURL(raw: URL, cleaned: URL, cleaningEnabled: Bool) -> URL {
        let didClean = raw.absoluteString != cleaned.absoluteString
        return willOpenCleaned(didClean: didClean, cleaningEnabled: cleaningEnabled) ? cleaned : raw
    }

    /// Human-readable, multi-line summary of the cleaning steps that fired.
    /// Used as the URL row's tooltip so users can see exactly what changed.
    /// Suppressed when the user has cleaning disabled — we never lie about
    /// what's about to open.
    var cleaningSummary: String? {
        guard willOpenCleaned, !cleaningTrace.steps.isEmpty else { return nil }
        let lines = cleaningTrace.steps.map { step -> String in
            "• " + URLPipelineStepLabel.label(for: step.identifier)
        }
        return (["Cleaned this link:"] + lines).joined(separator: "\n")
    }

    var sourceApp: URLSource? { context.source }
    var focusName: String? { context.focus.modeName }

    var filteredOptions: [LaunchOption] { options }

    var groupedFilteredOptions: [GroupedLaunchOption] {
        LaunchOptionGrouping.group(options: filteredOptions)
    }

    var visibleFlatOptions: [LaunchOption] {
        LaunchOptionGrouping.visibleOptions(
            grouped: groupedFilteredOptions,
            expandedGroupIDs: expandedGroupIDs
        )
    }

    func toggleGroupExpansion(_ groupID: String) {
        if expandedGroupIDs.contains(groupID) {
            expandedGroupIDs.remove(groupID)
        } else {
            expandedGroupIDs.insert(groupID)
        }
    }

    func selectedOption() -> LaunchOption? {
        let list = filteredOptions
        guard list.indices.contains(selectedIndex) else { return nil }
        return list[selectedIndex]
    }

    func selectedSupportsIncognito() -> Bool {
        guard let option = selectedOption() else { return false }
        return URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
    }

    func toggleIncognito() {
        incognitoMode.toggle()
    }

    func moveSelection(_ delta: Int) {
        let count = filteredOptions.count
        guard count > 0 else { return }
        let next = (selectedIndex + delta + count) % count
        selectedIndex = next
    }

    func confirmSelection(remember: Bool? = nil, incognito: Bool? = nil) {
        if !multiSelection.isEmpty {
            confirmMulti(incognito: incognito ?? incognitoMode)
            return
        }
        let list = filteredOptions
        guard list.indices.contains(selectedIndex) else { return }
        let shouldRemember = remember ?? rememberChoice
        let option = list[selectedIndex]
        pickHandler(option, shouldRemember, resolvedIncognito(for: option, requested: incognito))
    }

    func pick(_ option: LaunchOption, remember: Bool? = nil, incognito: Bool? = nil) {
        let shouldRemember = remember ?? rememberChoice
        pickHandler(option, shouldRemember, resolvedIncognito(for: option, requested: incognito))
    }

    func pickByNumber(_ number: Int, remember: Bool? = nil, incognito: Bool? = nil) {
        let idx = number - 1
        let visible = visibleFlatOptions
        guard visible.indices.contains(idx) else { return }
        let option = visible[idx]
        if let flatIdx = filteredOptions.firstIndex(where: { $0.id == option.id }) {
            selectedIndex = flatIdx
        }
        let shouldRemember = remember ?? rememberChoice
        pickHandler(option, shouldRemember, resolvedIncognito(for: option, requested: incognito))
    }

    func toggleMulti(_ option: LaunchOption) {
        let key = option.id
        if multiSelection.contains(key) {
            multiSelection.remove(key)
        } else {
            multiSelection.insert(key)
        }
    }

    func toggleMultiAtSelection() {
        let list = filteredOptions
        guard list.indices.contains(selectedIndex) else { return }
        toggleMulti(list[selectedIndex])
    }

    private func confirmMulti(incognito: Bool) {
        let chosen = options.filter { multiSelection.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let privateCapable = chosen.allSatisfy {
            URLOpener.supportsIncognito(bundleID: $0.browser.bundleID)
        }
        pickMultiHandler(chosen, incognito && privateCapable)
    }

    private func resolvedIncognito(for option: LaunchOption, requested: Bool?) -> Bool {
        let wantsPrivate = requested ?? incognitoMode
        return wantsPrivate && URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
    }

    var cheatSheetEntries: [String] {
        previewMode ? PickerShortcutHelp.previewEntries : PickerShortcutHelp.pickerEntries
    }

    func openQRSheet() {
        qrImage = qrImageProvider(previewURL.absoluteString)
        showQRSheet = true
    }

    func closeQRSheet() {
        showQRSheet = false
    }

    func cancel() {
        cancelHandler()
    }

    func openPreferences() {
        openPreferencesHandler?()
    }

    func copyCleanedURL() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(cleanedURL.absoluteString, forType: .string)
    }

    /// Copies the cleaned URL plus the page title (if known) as Markdown:
    /// `[Title](https://…)`. Falls back to the host when no title is loaded.
    func copyAsMarkdown() {
        let title = preview?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label: String
        if let title, !title.isEmpty {
            label = title
        } else {
            label = displayHost
        }
        let escaped = label
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let markdown = "[\(escaped)](\(cleanedURL.absoluteString))"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(markdown, forType: .string)
    }
}

/// Risk chips follow the same URL the picker will open when the user confirms (cleaned vs raw per settings).
enum PickerURLRisk {
    static func flags(for url: URL, cleanedURL: URL, cleanURLsBeforeOpening: Bool) -> [RiskFlag] {
        URLRiskAssessor.assess(cleanURLsBeforeOpening ? cleanedURL : url)
    }
}
