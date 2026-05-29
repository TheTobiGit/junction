import SwiftUI
import AppKit

/// Search field + Clear button rendered in the page header (next to the
/// "Activity" title), matching how the Redirects tab puts its "Add" button
/// in the same slot. Hoisting these controls out of the rows panel means
/// they never participate in the page's scroll view; the box below scrolls
/// independently.
struct ActivityHeaderControls: View {
    @Binding var query: String
    @Binding var confirmingClear: Bool
    @ObservedObject private var history = RoutingHistory.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                TextField("Search links…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 180)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05))
            )

            PrefsButton(title: "Clear", symbol: "trash") {
                confirmingClear = true
            }
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
    }
}

struct ActivityTab: View {
    let debouncedQuery: String

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var history = RoutingHistory.shared

    private var visibleRows: [ActivityRowDisplay] {
        ActivityRowDisplayBuilder.filter(history.displayRows, query: debouncedQuery)
    }

    var body: some View {
        if history.entries.isEmpty {
            PrefsBlock {
                PrefsEmptyState(
                    title: "Nothing here yet",
                    message: "Links you open through Junction will appear in this list.",
                    actionTitle: nil,
                    action: nil
                )
            }
        } else if visibleRows.isEmpty {
            PrefsBlock {
                PrefsEmptyState(
                    title: "No matches",
                    message: "Try a different search term.",
                    actionTitle: nil,
                    action: nil
                )
            }
        } else {
            // Single fixed-height block whose interior is the scroll
            // surface. The page itself doesn't scroll on this tab —
            // only the rows do.
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleRows) { row in
                            ActivityRow(row: row, colorScheme: colorScheme)
                                .padding(.horizontal, 16)
                            if row.id != visibleRows.last?.id {
                                PrefsHairline()
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.automatic)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
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
                .help(outcomeTooltip)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.cleanedURL)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(linkColor)
                    .lineLimit(1)
                    .truncationMode(.middle)

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
                }
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help(linkTooltip)

            HStack(spacing: 0) {
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
                .help("Copy \(entry.cleanedURL)")

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
                .help(reopenTooltip)

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
                .help("Create a rule from this link")
            }
            .layoutPriority(1)
            .fixedSize()
        }
        .padding(.vertical, 12)
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

    private var outcomeTooltip: String {
        switch entry.outcome {
        case .opened:           return "Opened"
        case .openedIncognito:  return "Opened in private window"
        case .opened_appScheme: return "Opened in app"
        case .blocked:          return "Blocked"
        case .picker:           return "Showed picker"
        }
    }

    private var reopenTooltip: String {
        if let pretty = row.prettyTargetBundleName {
            return "Reopen in \(pretty)"
        }
        return "Reopen link"
    }

    private var linkTooltip: String {
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
}
