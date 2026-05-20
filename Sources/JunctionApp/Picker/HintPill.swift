import SwiftUI

struct HintPill: View {
    let key: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.1))
                )
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}

enum PickerShortcutHelp {
    static let pickerEntries: [String] = [
        "␣ preview",
        "↵ open · ⌘↵ open + remember · ⌥↵ open private",
        "← → or 1-9 switch",
        "⇧␣ multi-select · ⇧click multi-open",
        "⌘C copy cleaned URL · ⌘⇧C copy as Markdown",
        "⌥P toggle private",
        "⎋ close",
        "? shortcuts",
    ]

    static let previewEntries: [String] = [
        "␣ back · ⎋ back",
        "↵ open · ⌘↵ open + remember · ⌥↵ open private",
        "⌘← ⌘→ or ⌘1-9 switch",
        "⌘C copy cleaned URL · ⌘⇧C copy as Markdown",
        "⌥P toggle private",
        "? shortcuts",
    ]

    static let picker: String = pickerEntries.joined(separator: " • ")
    static let preview: String = previewEntries.joined(separator: " • ")
}
