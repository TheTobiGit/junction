import AppKit
import SwiftUI

enum ClipboardHUDMetrics {
    static let cardWidth: CGFloat = 304
    static let cornerRadius: CGFloat = 14
    static let actionHeight: CGFloat = 30
    static let iconSize: CGFloat = 26
}

struct ClipboardHUDIconButton: View {
    let symbol: String
    let help: String
    var isActive: Bool = false
    var accent: Color? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { label }
                    .buttonStyle(.plain)
            } else {
                label
            }
        }
        .help(help)
    }

    private var label: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(isActive ? (accent ?? .accentColor) : .secondary)
            .frame(width: ClipboardHUDMetrics.iconSize, height: ClipboardHUDMetrics.iconSize)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? (accent ?? .accentColor).opacity(0.14) : Color.clear)
            )
    }
}

struct ClipboardQRPlate: View {
    let image: CGImage?
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let cgImage = image {
                Image(nsImage: NSImage(
                    cgImage: cgImage,
                    size: NSSize(width: cgImage.width, height: cgImage.height)
                ))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                ProgressView().controlSize(.small)
                    .frame(width: size, height: size)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.92))
        )
    }
}
