import SwiftUI
import AppKit

struct ActivityTab: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var history = RoutingHistory.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var query: String = ""
    @State private var showCleanedOnly: Bool = false
    @State private var selectedOutcomes: Set<RoutingHistory.Outcome> = []
    @State private var selectedHost: String? = nil
    @State private var selectedSourceBundleID: String? = nil
    @State private var selectedTargetBundleID: String? = nil
    @State private var confirmingClear: Bool = false

    private var filteredEntries: [RoutingHistory.Entry] {
        ActivityFilter.filter(history.entries, criteria: .init(
            query: query,
            showCleanedOnly: showCleanedOnly,
            outcomes: selectedOutcomes,
            host: selectedHost,
            sourceBundleID: selectedSourceBundleID,
            targetBundleID: selectedTargetBundleID
        ))
    }

    private var distinctHosts: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in history.entries {
            if let h = URL(string: entry.cleanedURL)?.host?.lowercased(), seen.insert(h).inserted {
                result.append(h)
            }
        }
        return result.sorted()
    }

    private var distinctSourceBundleIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in history.entries {
            if let s = entry.sourceBundleID, seen.insert(s).inserted {
                result.append(s)
            }
        }
        return result.sorted()
    }

    private var distinctTargetBundleIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in history.entries {
            if let t = entry.targetBundleID, seen.insert(t).inserted {
                result.append(t)
            }
        }
        return result.sorted()
    }

    private var outcomeCounts: [RoutingHistory.Outcome: Int] {
        ActivityFilter.outcomeCounts(history.entries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            recordRow

            if !history.entries.isEmpty {
                filterBar
                outcomePills
                statsCard
            }

            content
        }
    }

    // MARK: - Record toggle

    private var recordRow: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Record activity")
                    .font(.system(size: 13, weight: .medium))
                Text("Stored on this Mac only, up to \(RoutingHistory.maxEntries) entries.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 24)
            Toggle("", isOn: Binding(
                get: { settings.settings.historyEnabled },
                set: { settings.settings.historyEnabled = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Filters

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
                )
                .frame(maxWidth: 260)

                Toggle(isOn: $showCleanedOnly) {
                    Text("Cleaned only").font(.system(size: 11, weight: .medium))
                }
                .toggleStyle(.checkbox)

                Spacer()

                Text("\(filteredEntries.count) of \(history.entries.count)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Text("Clear")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .foregroundStyle(.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(history.entries.isEmpty)
                .confirmationDialog(
                    "Clear all \(history.entries.count) entries?",
                    isPresented: $confirmingClear,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) { history.clear() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently removes Junction's local activity log.")
                }
            }

            if !distinctHosts.isEmpty || !distinctSourceBundleIDs.isEmpty || !distinctTargetBundleIDs.isEmpty {
                dropdownFilterRow
            }
        }
    }

    private var dropdownFilterRow: some View {
        HStack(spacing: 10) {
            if !distinctHosts.isEmpty {
                Picker(selection: $selectedHost) {
                    Text("All hosts").tag(String?.none)
                    ForEach(distinctHosts, id: \.self) { h in
                        Text(h).tag(String?.some(h))
                    }
                } label: {
                    Text("Host").font(.system(size: 11, weight: .medium))
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .help("Filter by host")
            }

            if !distinctSourceBundleIDs.isEmpty {
                Picker(selection: $selectedSourceBundleID) {
                    Text("All sources").tag(String?.none)
                    ForEach(distinctSourceBundleIDs, id: \.self) { s in
                        Text(prettyBundleIDLabel(s)).tag(String?.some(s))
                    }
                } label: {
                    Text("Source app").font(.system(size: 11, weight: .medium))
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .help("Filter by source app")
            }

            if !distinctTargetBundleIDs.isEmpty {
                Picker(selection: $selectedTargetBundleID) {
                    Text("All browsers").tag(String?.none)
                    ForEach(distinctTargetBundleIDs, id: \.self) { t in
                        Text(prettyBundleIDLabel(t)).tag(String?.some(t))
                    }
                } label: {
                    Text("Browser").font(.system(size: 11, weight: .medium))
                }
                .pickerStyle(.menu)
                .controlSize(.small)
                .help("Filter by target browser")
            }

            if selectedHost != nil || selectedSourceBundleID != nil || selectedTargetBundleID != nil {
                Button("Reset") {
                    selectedHost = nil
                    selectedSourceBundleID = nil
                    selectedTargetBundleID = nil
                }
                .buttonStyle(.borderless)
                .controlSize(.mini)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func prettyBundleIDLabel(_ id: String) -> String {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
           let bundle = Bundle(url: app),
           let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return id
    }

    private var outcomePills: some View {
        HStack(spacing: 6) {
            outcomePill(.opened,           title: "Opened",     color: .accentColor)
            outcomePill(.openedIncognito,  title: "Private",    color: .indigo)
            outcomePill(.opened_appScheme, title: "Native app", color: .pink)
            outcomePill(.picker,           title: "Picker",     color: .orange)
            outcomePill(.blocked,          title: "Blocked",    color: .red)

            if !selectedOutcomes.isEmpty {
                Button("Reset") { selectedOutcomes.removeAll() }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func outcomePill(
        _ outcome: RoutingHistory.Outcome,
        title: String,
        color: Color
    ) -> some View {
        let count = outcomeCounts[outcome] ?? 0
        let isSelected = selectedOutcomes.contains(outcome)
        let isAvailable = count > 0
        return Button {
            if isSelected { selectedOutcomes.remove(outcome) }
            else { selectedOutcomes.insert(outcome) }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.system(size: 11, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(isSelected ? Color.primary : .secondary.opacity(isAvailable ? 1.0 : 0.5))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07)
                        : Color.primary.opacity(0.03)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .help(isAvailable ? "Filter by \(title.lowercased())" : "No \(title.lowercased()) entries yet")
    }

    // MARK: - Stats card

    private var statsCard: some View {
        let stats = ActivityStats.byHost(entries: history.entries)
        return VStack(alignment: .leading, spacing: 10) {
            Text("PER-HOST STATS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary.opacity(0.7))

            VStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.host) { idx, stat in
                    hostStatRow(stat)
                    if idx < stats.count - 1 {
                        Rectangle()
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.06))
                            .frame(height: 0.5)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    private func hostStatRow(_ stat: ActivityStats.HostStat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(stat.host)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 120, alignment: .leading)

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                statCell(label: "routes", value: "\(stat.count)")

                statCell(label: "last", value: relativeTime(stat.lastRoute))

                if let browser = stat.dominantBrowser {
                    statCell(label: "browser", value: prettyBundleIDLabel(browser))
                }

                if stat.trackerHits > 0 {
                    statCell(label: "cleaned", value: "\(stat.trackerHits)")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.secondary.opacity(0.6))
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !settings.settings.historyEnabled && history.entries.isEmpty {
            emptyText("Recording is off.", detail: "Enable it above to start collecting recent links.")
        } else if history.entries.isEmpty {
            emptyText("No activity yet.", detail: "Open a link through Junction and it'll show up here.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { idx, entry in
                    ActivityRow(entry: entry, colorScheme: colorScheme)
                    if idx < filteredEntries.count - 1 {
                        Rectangle()
                            .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.06))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    private func emptyText(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 28)
    }
}

private struct ActivityRow: View {
    let entry: RoutingHistory.Entry
    var colorScheme: ColorScheme = .light

    @State private var showingPromoteSheet: Bool = false

    private var linkColor: Color {
        colorScheme == .dark
        ? Color(red: 0.52, green: 0.82, blue: 1.0)
        : Color(nsColor: .linkColor)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(outcomeColor)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(entry.cleanedURL)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(linkColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    if entry.didClean {
                        Text("cleaned")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                HStack(spacing: 8) {
                    Text(relativeTime)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let target = entry.targetBundleID {
                        Text("·").foregroundStyle(.secondary.opacity(0.5))
                        Text(prettyBundleID(target))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if let rule = entry.ruleLabel {
                        Text("·").foregroundStyle(.secondary.opacity(0.5))
                        Text(rule)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button {
                copy(entry.cleanedURL)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy cleaned URL")

            Button {
                if let url = URL(string: entry.cleanedURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Open again")

            Button {
                showingPromoteSheet = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Promote to rule")
        }
        .padding(.vertical, 12)
        .help(toolTip)
        .sheet(isPresented: $showingPromoteSheet) {
            let opts = LaunchOptionDiscovery.options()
            AddRuleSheet(options: opts, prefill: AddRuleSheet.prefill(for: entry, options: opts))
        }
    }

    private var outcomeColor: Color {
        switch entry.outcome {
        case .opened:           return .accentColor
        case .openedIncognito:  return .indigo
        case .opened_appScheme: return .pink
        case .blocked:          return .red
        case .picker:           return .orange
        }
    }

    private var relativeTime: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: entry.timestamp, relativeTo: Date())
    }

    private var toolTip: String {
        var lines: [String] = []
        if entry.didClean {
            lines.append("Original: \(entry.originalURL)")
            lines.append("Cleaned:  \(entry.cleanedURL)")
            if !entry.cleaningSteps.isEmpty {
                lines.append("Steps: " + entry.cleaningSteps.joined(separator: ", "))
            }
        } else {
            lines.append(entry.cleanedURL)
        }
        return lines.joined(separator: "\n")
    }

    private func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func prettyBundleID(_ id: String) -> String {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
           let bundle = Bundle(url: app),
           let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        }
        return id
    }
}
