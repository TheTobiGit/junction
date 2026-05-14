import SwiftUI
import AppKit

struct FaviconView: View {
    let data: Data?
    var fallbackSize: CGFloat = 12

    var body: some View {
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            ZStack {
                Color.secondary.opacity(0.15)
                Image(systemName: "globe")
                    .font(.system(size: fallbackSize))
                    .foregroundColor(.secondary)
            }
        }
    }
}
