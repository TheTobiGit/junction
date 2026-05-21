import SwiftUI

struct AddRuleSheet: View {
    let options: [LaunchOption]
    let prefill: Prefill?

    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var hostKind: HostKind = .suffix
    @State private var hostValue: String = ""
    @State private var actionKind: ActionKind = .open
    @State private var selectedTarget: LaunchTarget? = nil
    @State private var schemeValue: String = ""
    @State private var pathKind: PathKind = .prefix
    @State private var pathValue: String = ""

    init(options: [LaunchOption], prefill: Prefill? = nil) {
        self.options = options
        self.prefill = prefill
    }

    struct Prefill {
        var host: HostMatch
        var action: RuleAction?
    }

    static func prefill(for entry: RoutingHistory.Entry, options: [LaunchOption]) -> Prefill? {
        let host = HostMatch.equals(URL(string: entry.cleanedURL)?.host ?? "")
        let action = resolvedAction(for: entry, options: options)
        return Prefill(host: host, action: action)
    }

    private static func resolvedAction(for entry: RoutingHistory.Entry, options: [LaunchOption]) -> RuleAction? {
        func action(for target: LaunchTarget) -> RuleAction {
            entry.outcome == .openedIncognito ? .openIncognito(target) : .open(target)
        }
        if let storageKey = entry.targetStorageKey {
            if let target = resolvedTarget(from: storageKey, in: options) {
                return action(for: target)
            }
            if let bundleID = entry.targetBundleID {
                return action(for: .app(bundleID: bundleID))
            }
            return nil
        }
        if let bundleID = entry.targetBundleID {
            return action(for: .app(bundleID: bundleID))
        }
        return nil
    }

    private static func resolvedTarget(from storageKey: String, in options: [LaunchOption]) -> LaunchTarget? {
        if storageKey.hasPrefix("app:") {
            let bundleID = String(storageKey.dropFirst(4))
            guard !bundleID.isEmpty else { return nil }
            return .app(bundleID: bundleID)
        }
        if storageKey.hasPrefix("profile:") {
            let rest = String(storageKey.dropFirst(8))
            let parts = rest.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            let bundleID = parts[0], profileID = parts[1]
            return options.first(where: {
                $0.browser.bundleID == bundleID && $0.profile?.directoryName == profileID
            })?.target
        }
        return nil
    }

    enum PathKind: String, CaseIterable, Identifiable {
        case prefix, contains, regex, glob
        var id: String { rawValue }

        static var displayCases: [PathKind] { [.prefix, .contains, .glob, .regex] }

        var label: String {
            switch self {
            case .prefix:   return "Starts with"
            case .contains: return "Includes"
            case .regex:    return "Pattern"
            case .glob:     return "Wildcard"
            }
        }

        var placeholder: String {
            switch self {
            case .prefix:   return "/docs"
            case .contains: return "/issues"
            case .regex:    return "^/v[0-9]+/"
            case .glob:     return "/files/*.pdf"
            }
        }

        var help: String {
            switch self {
            case .prefix:   return "Only pages whose address starts with this text."
            case .contains: return "Only pages whose address includes this text."
            case .regex:    return "Advanced: match page addresses with a custom pattern."
            case .glob:     return "Use * as a wildcard, like /files/*.pdf."
            }
        }
    }

    enum HostKind: String, CaseIterable, Identifiable {
        case equals, suffix, regex, urlEquals
        var id: String { rawValue }

        static var displayCases: [HostKind] { [.suffix, .equals, .urlEquals, .regex] }

        var label: String {
            switch self {
            case .equals:    return "Subdomain"
            case .suffix:    return "Website"
            case .regex:     return "Pattern"
            case .urlEquals: return "Exact link"
            }
        }

        var placeholder: String {
            switch self {
            case .equals:    return "mail.google.com"
            case .suffix:    return "github.com"
            case .regex:     return "^.*\\.slack\\.com$"
            case .urlEquals: return "https://github.com/orgs/acme/people"
            }
        }

        var isExactURL: Bool { self == .urlEquals }

        var help: String {
            switch self {
            case .equals:    return "One hostname only, like mail.google.com."
            case .suffix:    return "The whole site and its subdomains, like docs.github.com."
            case .regex:     return "Advanced: match websites with a custom pattern."
            case .urlEquals: return "One specific link only. Junction removes tracking first."
            }
        }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case open, incognito, ask, block, appScheme
        var id: String { rawValue }

        var label: String {
            switch self {
            case .open:      return "Open in a browser"
            case .incognito: return "Open privately"
            case .ask:       return "Ask me each time"
            case .block:     return "Don't open"
            case .appScheme: return "Open in another app"
            }
        }

        var needsTarget: Bool { self == .open || self == .incognito }
    }

    private var accent: Color { settings.settings.accentPreset.swiftUIColor }
    private var theme: ChromeTheme { settings.settings.chromeTheme }

    private var pickableTargets: [LaunchOption] {
        switch actionKind {
        case .incognito:
            return options.filter { URLOpener.supportsIncognito(bundleID: $0.browser.bundleID) }
        default:
            return options
        }
    }

    private var trimmedHost: String {
        hostValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedScheme: String {
        schemeValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPath: String {
        pathValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var validationError: String? {
        if trimmedHost.isEmpty {
            return hostKind == .urlEquals
                ? "Paste the full link you want to match."
                : "Enter a website to match."
        }
        if hostKind == .regex, (try? NSRegularExpression(pattern: trimmedHost)) == nil {
            return "That website pattern isn't valid."
        }
        if pathKind == .regex, !trimmedPath.isEmpty,
           !URLPathMatch.isValidRegexPattern(trimmedPath) {
            return "That page pattern isn't valid."
        }
        if hostKind == .urlEquals {
            guard let parsed = URL(string: trimmedHost),
                  let scheme = parsed.scheme, !scheme.isEmpty,
                  parsed.host?.isEmpty == false
            else {
                return "Include the full link, starting with https://"
            }
        }
        if actionKind.needsTarget, selectedTarget == nil {
            return "Choose a browser."
        }
        if actionKind == .appScheme, trimmedScheme.isEmpty {
            return "Enter the app name or scheme, like slack or zoommtg."
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 16)

            PrefsHairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let summary = ruleSummaryText {
                        rulePreview(summary)
                    }

                    matchBlock

                    if !hostKind.isExactURL {
                        pathBlock
                    }

                    actionBlock

                    if !trimmedHost.isEmpty, let validationError {
                        Label(validationError, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }

            PrefsHairline()

            footer
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
        }
        .frame(width: 500, height: 520)
        .background {
            JunctionChromeBackground(theme: theme, accent: accent)
                .ignoresSafeArea()
        }
        .tint(accent)
        .onAppear {
            if let p = prefill { applyPrefill(p) }
            seedDefaultTarget()
        }
        .onChange(of: actionKind) { _ in seedDefaultTarget() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add a rule")
                .font(.system(size: 17, weight: .semibold))
            Text("Tell Junction which links to catch and what to do with them.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rulePreview(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.22), lineWidth: 0.5)
        )
    }

    private var matchBlock: some View {
        PrefsBlock(title: "When the link is from") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Match type", selection: $hostKind) {
                    ForEach(HostKind.displayCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                prefsTextField(hostKind.placeholder, text: $hostValue, monospaced: hostKind == .regex)

                Text(hostKind.help)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }

    private var pathBlock: some View {
        PrefsBlock(title: "And only on pages that (optional)") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Page match", selection: $pathKind) {
                    ForEach(PathKind.displayCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                prefsTextField(pathKind.placeholder, text: $pathValue, monospaced: pathKind == .regex || pathKind == .glob)

                Text(trimmedPath.isEmpty ? "Leave blank to match every page on the site." : pathKind.help)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
    }

    private var actionBlock: some View {
        PrefsBlock(title: "Then") {
            VStack(alignment: .leading, spacing: 12) {
                PrefsRow(title: "Do this") {
                    Picker("", selection: $actionKind) {
                        ForEach(ActionKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }

                if actionKind.needsTarget {
                    PrefsHairline()
                    targetPicker
                } else if actionKind == .appScheme {
                    PrefsHairline()
                    VStack(alignment: .leading, spacing: 8) {
                        prefsTextField("slack", text: $schemeValue, monospaced: true)
                        Text("Junction sends matching links to the app registered for this name.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            PrefsButton(title: "Cancel", action: { dismiss() })
                .keyboardShortcut(.cancelAction)
            Button("Add rule") { submit() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil)
        }
    }

    // MARK: - Helpers

    private func prefsTextField(_ placeholder: String, text: Binding<String>, monospaced: Bool = false) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: monospaced ? .monospaced : .default))
            .disableAutocorrection(true)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(PrefsFieldBackground())
    }

    private var ruleSummaryText: String? {
        guard !trimmedHost.isEmpty else { return nil }

        var whenParts: [String] = []

        switch hostKind {
        case .equals:
            whenParts.append("a link from \(trimmedHost)")
        case .suffix:
            whenParts.append("a link from \(trimmedHost) or any page on that site")
        case .regex:
            whenParts.append("a link matching the website pattern you entered")
        case .urlEquals:
            whenParts.append("this exact link")
        }

        if !hostKind.isExactURL, !trimmedPath.isEmpty {
            switch pathKind {
            case .prefix:
                whenParts.append("on pages starting with \(trimmedPath)")
            case .contains:
                whenParts.append("on pages that include \(trimmedPath)")
            case .glob:
                whenParts.append("on pages matching \(trimmedPath)")
            case .regex:
                whenParts.append("on pages matching your page pattern")
            }
        }

        let whenClause = whenParts.joined(separator: ", ")

        let thenClause: String = {
            switch actionKind {
            case .open:
                let name = selectedTarget.flatMap { target in
                    options.first { $0.target == target }?.displayName
                } ?? "your browser"
                return "Junction will open it in \(name)."
            case .incognito:
                let name = selectedTarget.flatMap { target in
                    options.first { $0.target == target }?.displayName
                } ?? "your browser"
                return "Junction will open it privately in \(name)."
            case .ask:
                return "Junction will ask which browser to use."
            case .block:
                return "Junction will block the link."
            case .appScheme:
                let scheme = trimmedScheme.isEmpty ? "the app" : trimmedScheme
                return "Junction will open it in \(scheme)."
            }
        }()

        return "When someone opens \(whenClause), \(thenClause)"
    }

    private func applyPrefill(_ p: Prefill) {
        switch p.host {
        case .equals(let v):
            hostKind = .equals
            hostValue = v
        case .suffix(let v):
            hostKind = .suffix
            hostValue = v
        case .regex(let v):
            hostKind = .regex
            hostValue = v
        }
        guard let action = p.action else { return }
        switch action {
        case .open(let target):
            actionKind = .open
            selectedTarget = target
        case .openIncognito(let target):
            actionKind = .incognito
            selectedTarget = target
        case .ask:
            actionKind = .ask
        case .block:
            actionKind = .block
        case .appScheme(let s):
            actionKind = .appScheme
            schemeValue = s
        }
    }

    private var targetPicker: some View {
        let targets = pickableTargets
        return Group {
            if targets.isEmpty {
                Text("None of your browsers support private browsing.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                PrefsRow(title: "Browser") {
                    Picker("", selection: Binding(
                        get: { selectedTarget },
                        set: { selectedTarget = $0 }
                    )) {
                        Text("Choose…").tag(LaunchTarget?.none)
                        ForEach(targets) { option in
                            Text(option.displayName).tag(LaunchTarget?.some(option.target))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }
        }
    }

    private func seedDefaultTarget() {
        guard actionKind.needsTarget else {
            selectedTarget = nil
            return
        }
        let pool = pickableTargets
        if let current = selectedTarget, pool.contains(where: { $0.target == current }) {
            return
        }
        selectedTarget = pool.first?.target
    }

    private func submit() {
        guard validationError == nil else { return }

        let action: RuleAction = {
            switch actionKind {
            case .open:      return .open(selectedTarget!)
            case .incognito: return .openIncognito(selectedTarget!)
            case .ask:       return .ask
            case .block:     return .block
            case .appScheme: return .appScheme(trimmedScheme)
            }
        }()

        let pathMatch: URLPathMatch? = (!hostKind.isExactURL && !trimmedPath.isEmpty) ? {
            switch pathKind {
            case .prefix:   return .prefix(trimmedPath)
            case .contains: return .contains(trimmedPath)
            case .regex:    return .regex(trimmedPath)
            case .glob:     return .glob(trimmedPath)
            }
        }() : nil

        let rule: DomainRule
        if hostKind == .urlEquals {
            let parsed = URL(string: trimmedHost)
            let host: HostMatch = .equals(parsed?.host ?? trimmedHost)
            rule = DomainRule(host: host, action: action, urlEquals: trimmedHost)
        } else {
            let host: HostMatch = {
                switch hostKind {
                case .equals:    return .equals(trimmedHost)
                case .suffix:    return .suffix(trimmedHost)
                case .regex:     return .regex(trimmedHost)
                case .urlEquals: return .equals(trimmedHost)
                }
            }()
            rule = DomainRule(host: host, action: action, path: pathMatch)
        }

        RulesStore.shared.addRule(rule)
        dismiss()
    }
}
