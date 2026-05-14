import AppKit
import SwiftUI

/// Checkbox row for “Remember my choice for {host} links” on picker chrome.
struct RememberHostToggle: View {
    let host: String
    let isOn: Bool
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary.opacity(0.9))

                label
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(hovered ? 0.07 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.14), value: hovered)
        .onHover { hover in
            hovered = hover
            if hover {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Remember the browser you pick next as the default for \(host) links")
    }

    private var label: Text {
        (Text("Remember my choice for ")
            .foregroundColor(.secondary)
            + Text(host)
            .foregroundColor(.primary)
            .fontWeight(.semibold)
            + Text(" links")
            .foregroundColor(.secondary))
            .font(.system(size: 11))
    }
}
