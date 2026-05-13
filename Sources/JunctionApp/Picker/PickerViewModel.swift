import SwiftUI
import AppKit

final class PickerViewModel: ObservableObject {
    let url: URL
    let cleanedURL: URL
    let options: [LaunchOption]
    let context: RouteContext
    let riskFlags: [RiskFlag]
    @Published var selectedIndex: Int = 0
    @Published var rememberChoice: Bool = false
    @Published var multiSelection: Set<String> = []
    @Published var preview: LinkPreview? = nil
    @Published var incognitoMode: Bool = false
    @Published var previewMode: Bool = false
    @Published var previewTitle: String? = nil
    @Published var previewLoading: Bool = false
    @Published var previewProgress: Double = 0

    private let pickHandler: (LaunchOption, Bool, Bool) -> Void
    private let pickMultiHandler: ([LaunchOption], Bool) -> Void
    private let cancelHandler: () -> Void

    init(
        url: URL,
        options: [LaunchOption],
        context: RouteContext,
        onPick: @escaping (LaunchOption, Bool, Bool) -> Void,
        onPickMulti: @escaping ([LaunchOption], Bool) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.url = url
        self.cleanedURL = URLTransformers.default.run(url)
        self.options = options
        self.context = context
        self.riskFlags = URLRiskAssessor.assess(url)
        self.pickHandler = onPick
        self.pickMultiHandler = onPickMulti
        self.cancelHandler = onCancel
        loadPreview()
    }

    private func loadPreview() {
        LinkPreviewFetcher.fetch(cleanedURL) { [weak self] preview in
            DispatchQueue.main.async {
                self?.preview = preview
            }
        }
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

    var sourceApp: URLSource? { context.source }
    var focusName: String? { context.focus.modeName }

    var filteredOptions: [LaunchOption] { options }

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
        let list = filteredOptions
        guard list.indices.contains(idx) else { return }
        selectedIndex = idx
        let shouldRemember = remember ?? rememberChoice
        let option = list[idx]
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

    func cancel() {
        cancelHandler()
    }

    func copyCleanedURL() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(cleanedURL.absoluteString, forType: .string)
    }
}
