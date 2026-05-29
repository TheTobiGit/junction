import SwiftUI
import AppKit

struct ActivityTab: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var history = RoutingHistory.shared
    @State private var query: String = ""
    @State private var debouncedQuery: String = ""
    @State private var groupDuplicates: Bool = false
    @State private var confirmingClear: Bool = false
    @State private var allRows: [ActivityRowDisplay] = []
    @State private var visibleRows: [ActivityRowDisplay] = []
    @State private var debounceWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !history.entries.isEmpty {
                PrefsBlock {
                    searchBar
                }
            }

            PrefsBlock {
                content
            }
        }
        .onAppear {
            rebuildRows()
            applyQuery()
        }
        .onChange(of: history.entries) { _ in
            rebuildRows()
            applyQuery()
        }
        .onChange(of: groupDuplicates) { _ in
            rebuildRows()
            applyQuery()
        }
        .onChange(of: query) { newValue in
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [newValue] in
                debouncedQuery = newValue
                applyQuery()
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }
    }

    private func rebuildRows() {
        allRows = ActivityRowDisplayBuilder.build(
            entries: history.entries,
            groupDuplicates: groupDuplicates
        )
    }

    private func applyQuery() {
        visibleRows = ActivityRowDisplayBuilder.filter(allRows, query: debouncedQuery)
    }

    private var searchBar: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search links…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
            )

            Spacer()

            Toggle(isOn: $groupDuplicates) {
                Text("Group duplicates")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)

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
    }

    @ViewBuilder
    private var content: some View {
        if history.entries.isEmpty {
            PrefsEmptyState(
                title: "Nothing here yet",
                message: "Links you open through Junction will appear in this list.",
                actionTitle: nil,
                action: nil
            )
        } else if visibleRows.isEmpty {
            PrefsEmptyState(
                title: "No matches",
                message: "Try a different search term.",
                actionTitle: nil,
                action: nil
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleRows) { row in
                        ActivityRow(row: row, colorScheme: colorScheme)
                        if row.id != visibleRows.last?.id {
                            PrefsHairline()
                        }
                    }
                }
            }
            .frame(maxHeight: 520)
        }
    }
}

private struct ActivityRow: View {
    let row: ActivityRowDisplay
    var colorScheme: ColorScheme = .light

    @State private var showingPromoteSheet: Bool = false

    private var entry: RoutingHistory.Entry { row.entry }

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
                Text(entry.cleanedURL)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(linkColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(row.relativeTimeString)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let prettyTarget = row.prettyTargetBundleName {
                        Text("·").foregroundStyle(.secondary.opacity(0.5))
                        Text(prettyTarget)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if let rule = entry.ruleLabel {
                        Text("·").foregroundStyle(.secondary.opacity(0.5))
                        Text(rule)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if row.isGrouped {
                        Text("·").foregroundStyle(.secondary.opacity(0.5))
                        Text("\(row.groupedCount)×")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.08))
                            )
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
            .help("Copy URL")

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
        if row.isGrouped {
            lines.append("Opened \(row.groupedCount) times")
        }
        return lines.joined(separator: "\n")
    }

    private func copy(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }
}
