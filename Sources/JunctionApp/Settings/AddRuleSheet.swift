import SwiftUI
import AppKit

struct AddRuleSheet: View {
    let options: [LaunchOption]
    let prefill: Prefill?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var hostKind: HostKind = .suffix
    @State private var hostValue: String = ""
    @State private var actionKind: ActionKind = .open
    @State private var selectedTarget: LaunchTarget? = nil
    @State private var schemeValue: String = ""
    @State private var pathKind: PathKind = .prefix
    @State private var pathValue: String = ""
    @State private var runningApps: [RunningAppEntry] = []
    @State private var selectedSourceApps: Set<String> = []

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

    private struct RunningAppEntry: Identifiable {
        let id: String
        let name: String
    }

    enum PathKind: String, CaseIterable, Identifiable {
        case prefix, contains, regex, glob
        var id: String { rawValue }
        var label: String {
            switch self {
            case .prefix:   return "Prefix"
            case .contains: return "Contains"
            case .regex:    return "Regex"
            case .glob:     return "Glob"
            }
        }
        var placeholder: String {
            switch self {
            case .prefix:   return "/orgs/acme"
            case .contains: return "/issues"
            case .regex:    return "^/v[0-9]+/"
            case .glob:     return "/files/*.swift"
            }
        }
    }

    enum HostKind: String, CaseIterable, Identifiable {
        case equals, suffix, regex, urlEquals
        var id: String { rawValue }
        var label: String {
            switch self {
            case .equals:    return "Equals"
            case .suffix:    return "Suffix"
            case .regex:     return "Regex"
            case .urlEquals: return "URL"
            }
        }
        var placeholder: String {
            switch self {
            case .equals:    return "api.github.com"
            case .suffix:    return "github.com"
            case .regex:     return "^.*\\.slack\\.com$"
            case .urlEquals: return "https://github.com/orgs/acme/people"
            }
        }
        var isExactURL: Bool { self == .urlEquals }
    }

    enum ActionKind: String, CaseIterable, Identifiable {
        case open, incognito, ask, block, appScheme
        var id: String { rawValue }
        var label: String {
            switch self {
            case .open:      return "Open in"
            case .incognito: return "Open privately in"
            case .ask:       return "Always ask"
            case .block:     return "Block"
            case .appScheme: return "Open via app scheme"
            }
        }
        var needsTarget: Bool { self == .open || self == .incognito }
    }

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
            return hostKind == .urlEquals ? "URL can't be empty" : "Host can't be empty"
        }
        if hostKind == .regex, (try? NSRegularExpression(pattern: trimmedHost)) == nil {
            return "Invalid regular expression"
        }
        if pathKind == .regex, !trimmedPath.isEmpty,
           (try? NSRegularExpression(pattern: trimmedPath)) == nil {
            return "Invalid path regular expression"
        }
        if hostKind == .urlEquals {
            guard let parsed = URL(string: trimmedHost),
                  let scheme = parsed.scheme, !scheme.isEmpty,
                  parsed.host?.isEmpty == false
            else {
                return "Enter a full URL including scheme (https://…)"
            }
        }
        if actionKind.needsTarget, selectedTarget == nil {
            return "Pick a target browser"
        }
        if actionKind == .appScheme, trimmedScheme.isEmpty {
            return "Scheme can't be empty (e.g. slack, zoommtg)"
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("New rule")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 10) {
                Text("MATCH")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.secondary.opacity(0.75))

                Picker("Match by", selection: $hostKind) {
                    ForEach(HostKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                TextField(hostKind.placeholder, text: $hostValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
                    .disableAutocorrection(true)

                Text(hostKindHelp)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !hostKind.isExactURL {
                VStack(alignment: .leading, spacing: 10) {
                    Text("PATH (OPTIONAL)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.secondary.opacity(0.75))

                    Picker("Path match", selection: $pathKind) {
                        ForEach(PathKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    TextField(pathKind.placeholder, text: $pathValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))
                        .disableAutocorrection(true)

                    Text("Leave empty to match any path.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            if !hostKind.isExactURL {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SOURCE APP (OPTIONAL)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.secondary.opacity(0.75))
                        .help("Best-effort attribution via FrontmostTracker — the most recent non-Junction frontmost app. May be inaccurate when links are opened from background apps.")

                    if runningApps.isEmpty {
                        Text("No regular apps running.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(runningApps) { app in
                                    Toggle(isOn: Binding(
                                        get: { selectedSourceApps.contains(app.id) },
                                        set: { checked in
                                            if checked { selectedSourceApps.insert(app.id) }
                                            else { selectedSourceApps.remove(app.id) }
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(app.name)
                                                .font(.system(size: 12))
                                            Text(app.id)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .frame(maxHeight: 120)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("ACTION")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.secondary.opacity(0.75))

                Picker("Action", selection: $actionKind) {
                    ForEach(ActionKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()

                if actionKind.needsTarget {
                    targetPicker
                } else if actionKind == .appScheme {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("slack", text: $schemeValue)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, design: .monospaced))
                            .disableAutocorrection(true)
                        Text("Junction hands matching URLs to the app registered for this scheme.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !trimmedHost.isEmpty, let validationError {
                Label(validationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add rule") { submit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(validationError != nil)
            }
        }
        .padding(26)
        .frame(minWidth: 460)
        .onAppear {
            if let p = prefill { applyPrefill(p) }
            seedDefaultTarget()
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
                .compactMap { app in
                    guard let bid = app.bundleIdentifier else { return nil }
                    return RunningAppEntry(id: bid, name: app.localizedName ?? bid)
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        .onChange(of: actionKind) { _ in seedDefaultTarget() }
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

    private var hostKindHelp: String {
        switch hostKind {
        case .equals:    return "Matches one host exactly (api.github.com)."
        case .suffix:    return "Matches that host and all subdomains."
        case .regex:     return "NSRegularExpression syntax, case-insensitive."
        case .urlEquals: return "Matches only this exact URL. Junction strips trackers first."
        }
    }

    private var targetPicker: some View {
        let targets = pickableTargets
        return Group {
            if targets.isEmpty {
                Text("No browsers support this action.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                Picker("Target", selection: Binding(
                    get: { selectedTarget },
                    set: { selectedTarget = $0 }
                )) {
                    Text("Select a browser…").tag(LaunchTarget?.none)
                    ForEach(targets) { option in
                        Text(option.displayName).tag(LaunchTarget?.some(option.target))
                    }
                }
                .labelsHidden()
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
            let condition: RuleCondition? = selectedSourceApps.isEmpty ? nil :
                RuleCondition(sourceApp: Array(selectedSourceApps).sorted())
            rule = DomainRule(host: host, action: action, when: condition, path: pathMatch)
        }

        RulesStore.shared.addRule(rule)
        dismiss()
    }
}
