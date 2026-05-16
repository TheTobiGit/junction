import SwiftUI
import AppKit

struct ActivityTab: View {
    @ObservedObject private var history = RoutingHistory.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var query: String = ""
    @State private var showCleanedOnly: Bool = false
    @State private var selectedOutcomes: Set<RoutingHistory.Outcome> = []
    @State private var confirmingClear: Bool = false

    private var filteredEntries: [RoutingHistory.Entry] {
        ActivityFilter.filter(history.entries, criteria: .init(
            query: query,
            showCleanedOnly: showCleanedOnly,
            outcomes: selectedOutcomes
        ))
    }

    /// Counts each outcome present in the full history (not the filtered set)
    /// so pill badges keep showing totals regardless of the active filter.
    private var outcomeCounts: [RoutingHistory.Outcome: Int] {
        ActivityFilter.outcomeCounts(history.entries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            privacyRow

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter recent links", text: $query)
                    .textFieldStyle(.roundedBorder)
                Toggle(isOn: $showCleanedOnly) {
                    Text("Cleaned only").font(.system(size: 11))
                }
                .toggleStyle(.checkbox)

                Spacer()

                Text("\(filteredEntries.count) of \(history.entries.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button(role: .destructive) {
                    confirmingClear = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .controlSize(.small)
                .disabled(history.entries.isEmpty)
                .confirmationDialog(
                    "Clear all \(history.entries.count) entries?",
                    isPresented: $confirmingClear,
                    titleVisibility: .visible
                ) {
                    Button("Clear", role: .destructive) { history.clear() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently removes Junction's local activity log. The file is rewritten on disk.")
                }
            }
            .disabled(!settings.settings.historyEnabled && history.entries.isEmpty)

            if !history.entries.isEmpty {
                outcomeFilterRow
            }

            if !settings.settings.historyEnabled && history.entries.isEmpty {
                disabledState
            } else if history.entries.isEmpty {
                emptyState
            } else {
                List(filteredEntries) { entry in
                    ActivityRow(entry: entry)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 320)
            }
        }
    }

    private var outcomeFilterRow: some View {
        HStack(spacing: 8) {
            outcomePill(
                .opened,
                title: "Opened",
                symbol: "arrow.up.forward.app.fill",
                color: .accentColor
            )
            outcomePill(
                .openedIncognito,
                title: "Private",
                symbol: "eyeglasses",
                color: .indigo
            )
            outcomePill(
                .opened_appScheme,
                title: "Native app",
                symbol: "app.connected.to.app.below.fill",
                color: .pink
            )
            outcomePill(
                .picker,
                title: "Picker",
                symbol: "questionmark.app.fill",
                color: .orange
            )
            outcomePill(
                .blocked,
                title: "Blocked",
                symbol: "shield.lefthalf.filled",
                color: .red
            )

            if !selectedOutcomes.isEmpty {
                Button("Reset") { selectedOutcomes.removeAll() }
                    .buttonStyle(.borderless)
                    .controlSize(.mini)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    private func outcomePill(
        _ outcome: RoutingHistory.Outcome,
        title: String,
        symbol: String,
        color: Color
    ) -> some View {
        let count = outcomeCounts[outcome] ?? 0
        let isSelected = selectedOutcomes.contains(outcome)
        let isAvailable = count > 0
        return Button {
            if isSelected {
                selectedOutcomes.remove(outcome)
            } else {
                selectedOutcomes.insert(outcome)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
                Text(title).font(.system(size: 11, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(color.opacity(isSelected ? 0.45 : 0.2)))
                }
            }
            .foregroundColor(isSelected ? color : .secondary.opacity(isAvailable ? 1 : 0.5))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.15) : Color.primary.opacity(0.04))
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? color.opacity(0.45) : Color.clear,
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .help(isAvailable ? "Filter by \(title.lowercased())" : "No \(title.lowercased()) entries yet")
    }

    private var privacyRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 14))
                .foregroundColor(settings.settings.historyEnabled ? .accentColor : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text("Record activity")
                    .font(.system(size: 12, weight: .semibold))
                Text("Stores up to \(RoutingHistory.maxEntries) recent links locally so you can re-route or audit them. Off by default for incognito-by-default users.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { settings.settings.historyEnabled },
                set: { settings.settings.historyEnabled = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var disabledState: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Activity recording is off.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Enable it above to start collecting recent links.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No recent activity yet.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Open a link through Junction and it'll show up here.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

private struct ActivityRow: View {
    let entry: RoutingHistory.Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            outcomeIcon
                .frame(width: 24, alignment: .center)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.cleanedURL)
                        .font(.system(size: 12, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    if entry.didClean {
                        cleanedPill
                    }
                }
                HStack(spacing: 10) {
                    Text(relativeTime)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if let target = entry.targetBundleID {
                        bullet
                        Text(prettyBundleID(target))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if let rule = entry.ruleLabel {
                        bullet
                        Text(rule)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button {
                        copy(entry.cleanedURL)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy cleaned URL")

                    Button {
                        if let url = URL(string: entry.cleanedURL) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open again")
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .help(toolTip)
    }

    private var outcomeIcon: some View {
        let symbol: String
        let color: Color
        switch entry.outcome {
        case .opened:           symbol = "arrow.up.forward.app.fill"; color = .accentColor
        case .openedIncognito:  symbol = "eyeglasses"; color = .indigo
        case .opened_appScheme: symbol = "app.connected.to.app.below.fill"; color = .pink
        case .blocked:          symbol = "shield.lefthalf.filled"; color = .red
        case .picker:           symbol = "questionmark.app.fill"; color = .orange
        }
        return Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(color)
    }

    private var cleanedPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "wand.and.stars").font(.system(size: 8, weight: .semibold))
            Text("cleaned").font(.system(size: 9, weight: .semibold))
        }
        .foregroundColor(.accentColor)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
    }

    private var bullet: some View {
        Text("•")
            .font(.system(size: 10))
            .foregroundColor(.secondary.opacity(0.4))
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
