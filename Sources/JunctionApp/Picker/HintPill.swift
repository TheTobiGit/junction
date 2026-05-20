import SwiftUI

struct HintPill: View {
    let key: String
    let label: String
    var emphasized: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(emphasized ? 0.95 : 0.85))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(emphasized ? 0.16 : 0.1))
                )
            Text(label)
                .font(.system(size: 12, weight: emphasized ? .medium : .regular))
                .foregroundColor(emphasized ? .primary.opacity(0.9) : .secondary)
        }
    }
}

/// One row in the shortcuts cheat sheet (key column + description).
struct CheatSheetRow: View {
    let keys: String
    let description: String
    var keyWidth: CGFloat = 80
    var labelWidth: CGFloat = 210
    var rowHeight: CGFloat = 28

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(keys)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.92))
                .frame(width: keyWidth, alignment: .trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(height: rowHeight, alignment: .topLeading)
    }
}

/// Two-column shortcut list for the cheat sheet overlay.
struct CheatSheetGrid: View {
    let rows: [PickerShortcutHelp.CheatRow]
    var keyWidth: CGFloat = 80
    var labelWidth: CGFloat = 210
    var rowSpacing: CGFloat = 8
    var columnGap: CGFloat = 28
    var rowHeight: CGFloat = 28

    private var splitIndex: Int { (rows.count + 1) / 2 }
    private var columnWidth: CGFloat { keyWidth + 10 + labelWidth }

    var body: some View {
        HStack(alignment: .top, spacing: columnGap) {
            column(Array(rows.prefix(splitIndex)))
            column(Array(rows.suffix(from: splitIndex)))
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private func column(_ items: [PickerShortcutHelp.CheatRow]) -> some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(items) { row in
                CheatSheetRow(
                    keys: row.keys,
                    description: row.description,
                    keyWidth: keyWidth,
                    labelWidth: labelWidth,
                    rowHeight: rowHeight
                )
            }
        }
        .frame(width: columnWidth, alignment: .leading)
    }
}

/// Footer hints plus a discoverable control for the full shortcut list.
struct PickerShortcutFooter: View {
    let hints: [PickerShortcutHelp.FooterHint]
    let fullHelp: String
    @Binding var cheatSheetVisible: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ForEach(hints) { hint in
                HintPill(key: hint.key, label: hint.label)
            }
            shortcutsButton
        }
        .help(fullHelp)
    }

    private var shortcutsButton: some View {
        Button {
            cheatSheetVisible.toggle()
        } label: {
            HintPill(key: "?", label: "Shortcuts", emphasized: cheatSheetVisible)
        }
        .buttonStyle(.plain)
        .help("Show all keyboard shortcuts (?)")
    }
}

enum PickerShortcutHelp {
    struct FooterHint: Hashable, Identifiable {
        let key: String
        let label: String
        var id: String { key + label }
    }

    struct CheatRow: Hashable, Identifiable {
        let keys: String
        let description: String
        var id: String { keys + description }
    }

    static let pickerFooterHints: [FooterHint] = [
        FooterHint(key: "␣", label: "Preview"),
        FooterHint(key: "↵", label: "Open"),
        FooterHint(key: "⌘↵", label: "Remember"),
        FooterHint(key: "⌥", label: "Private"),
        FooterHint(key: "1-9", label: "Switch"),
    ]

    static let previewFooterHints: [FooterHint] = [
        FooterHint(key: "␣", label: "Back"),
        FooterHint(key: "↵", label: "Open"),
        FooterHint(key: "⌘↵", label: "Remember"),
        FooterHint(key: "⌥", label: "Private"),
        FooterHint(key: "⌘1-9", label: "Switch"),
    ]

    static let pickerCheatRows: [CheatRow] = [
        CheatRow(keys: "␣", description: "Preview"),
        CheatRow(keys: "↵", description: "Open"),
        CheatRow(keys: "⌘↵", description: "Open and remember this site"),
        CheatRow(keys: "⌥↵", description: "Open in private / incognito"),
        CheatRow(keys: "← →", description: "Move selection"),
        CheatRow(keys: "1-9", description: "Open that browser tile"),
        CheatRow(keys: "⌘C", description: "Copy URL"),
        CheatRow(keys: "⌥P", description: "Toggle private mode"),
        CheatRow(keys: "?", description: "Toggle this shortcuts panel"),
    ]

    static let previewCheatRows: [CheatRow] = [
        CheatRow(keys: "␣", description: "Back to browser grid"),
        CheatRow(keys: "↵", description: "Open in selected browser"),
        CheatRow(keys: "⌘↵", description: "Open and remember this site"),
        CheatRow(keys: "⌥↵", description: "Open in private / incognito"),
        CheatRow(keys: "⌘← ⌘→", description: "Move selection"),
        CheatRow(keys: "⌘1-9", description: "Switch browser"),
        CheatRow(keys: "⌘C", description: "Copy URL"),
        CheatRow(keys: "⌥P", description: "Toggle private mode"),
        CheatRow(keys: "?", description: "Toggle this shortcuts panel"),
    ]

    static let pickerEntries: [String] = pickerCheatRows.map { "\($0.keys) \($0.description)" }
    static let previewEntries: [String] = previewCheatRows.map { "\($0.keys) \($0.description)" }

    static let picker: String = pickerEntries.joined(separator: " • ")
    static let preview: String = previewEntries.joined(separator: " • ")
}
