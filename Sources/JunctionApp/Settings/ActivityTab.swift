import SwiftUI
import AppKit

struct ActivityTab: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var history = RoutingHistory.shared
    @State private var query: String = ""
    @State private var confirmingClear: Bool = false

    private var filteredEntries: [RoutingHistory.Entry] {
        ActivityFilter.filter(history.entries, criteria: .init(query: query))
    }

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
        } else if filteredEntries.isEmpty {
            PrefsEmptyState(
                title: "No matches",
                message: "Try a different search term.",
                actionTitle: nil,
                action: nil
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(filteredEntries.enumerated()), id: \.element.id) { idx, entry in
                    ActivityRow(entry: entry, colorScheme: colorScheme)
                    if idx < filteredEntries.count - 1 { PrefsHairline() }
                }
            }
        }
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
                Text(entry.cleanedURL)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(linkColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

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
