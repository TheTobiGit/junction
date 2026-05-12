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

    private let pickHandler: (LaunchOption, Bool) -> Void
    private let pickMultiHandler: ([LaunchOption]) -> Void
    private let saveLaterHandler: () -> Void
    private let cancelHandler: () -> Void

    init(
        url: URL,
        options: [LaunchOption],
        context: RouteContext,
        onPick: @escaping (LaunchOption, Bool) -> Void,
        onPickMulti: @escaping ([LaunchOption]) -> Void,
        onSaveLater: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.url = url
        self.cleanedURL = URLTransformers.default.run(url)
        self.options = options
        self.context = context
        self.riskFlags = URLRiskAssessor.assess(url)
        self.pickHandler = onPick
        self.pickMultiHandler = onPickMulti
        self.saveLaterHandler = onSaveLater
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

    var didClean: Bool {
        cleanedURL.absoluteString != url.absoluteString
    }

    var sourceApp: URLSource? { context.source }
    var focusName: String? { context.focus.modeName }

    var filteredOptions: [LaunchOption] { options }

    func moveSelection(_ delta: Int) {
        let count = filteredOptions.count
        guard count > 0 else { return }
        let next = (selectedIndex + delta + count) % count
        selectedIndex = next
    }

    func confirmSelection(remember: Bool? = nil) {
        if !multiSelection.isEmpty {
            confirmMulti()
            return
        }
        let list = filteredOptions
        guard list.indices.contains(selectedIndex) else { return }
        let shouldRemember = remember ?? rememberChoice
        pickHandler(list[selectedIndex], shouldRemember)
    }

    func pick(_ option: LaunchOption, remember: Bool? = nil) {
        let shouldRemember = remember ?? rememberChoice
        pickHandler(option, shouldRemember)
    }

    func pickByNumber(_ number: Int, remember: Bool? = nil) {
        let idx = number - 1
        let list = filteredOptions
        guard list.indices.contains(idx) else { return }
        selectedIndex = idx
        let shouldRemember = remember ?? rememberChoice
        pickHandler(list[idx], shouldRemember)
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

    private func confirmMulti() {
        let chosen = options.filter { multiSelection.contains($0.id) }
        guard !chosen.isEmpty else { return }
        pickMultiHandler(chosen)
    }

    func cancel() {
        cancelHandler()
    }

    func saveForLater() {
        saveLaterHandler()
    }

    func copyCleanedURL() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(cleanedURL.absoluteString, forType: .string)
    }
}

