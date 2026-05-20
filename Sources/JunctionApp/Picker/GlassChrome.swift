import AppKit
import SwiftUI

enum GlassChrome {
    /// Procedurally generated tile for film-grain style texture (repeats cleanly).
    static let noiseTile: NSImage = {
        let w = 128
        let h = 128
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: w,
            pixelsHigh: h,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let data = rep.bitmapData else {
            return NSImage()
        }
        for y in 0..<h {
            for x in 0..<w {
                let o = y * rep.bytesPerRow + x * 4
                // Tighter noise around mid-gray so blend modes read as grain, not static.
                let v = UInt8.random(in: 108...148)
                data[o] = v
                data[o + 1] = v
                data[o + 2] = v
                data[o + 3] = 255
            }
        }
        let img = NSImage(size: NSSize(width: w, height: h))
        img.addRepresentation(rep)
        return img
    }()
}

/// Picker / HUD background: vibrancy + color wash + film grain (over `VisualEffectView`).
struct GlassChromeOverlay: View {
    var accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.18, green: 0.20, blue: 0.30).opacity(0.42), location: 0.0),
                    .init(color: Color(red: 0.14, green: 0.16, blue: 0.26).opacity(0.32), location: 0.28),
                    .init(color: accent.opacity(0.28), location: 0.52),
                    .init(color: accent.opacity(0.14), location: 0.74),
                    .init(color: Color(red: 0.04, green: 0.06, blue: 0.14).opacity(0.58), location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.22, green: 0.28, blue: 0.52).opacity(0.22),
                ],
                startPoint: .center,
                endPoint: .bottom
            )

            Image(nsImage: GlassChrome.noiseTile)
                .resizable(resizingMode: .tile)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blendMode(.softLight)
                .opacity(0.52)
        }
        .allowsHitTesting(false)
    }
}

/// Opaque-style panel: no vibrancy; window blues + accent + grain.
struct SolidChromeOverlay: View {
    var accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.16, green: 0.17, blue: 0.22).opacity(0.28), location: 0.0),
                    .init(color: accent.opacity(0.20), location: 0.45),
                    .init(color: accent.opacity(0.10), location: 0.72),
                    .init(color: Color.black.opacity(0.16), location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(nsImage: GlassChrome.noiseTile)
                .resizable(resizingMode: .tile)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blendMode(.softLight)
                .opacity(0.38)
        }
        .allowsHitTesting(false)
    }
}

struct JunctionChromeBackground: View {
    var theme: ChromeTheme
    var accent: Color

    var body: some View {
        Group {
            switch theme {
            case .glass:
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .overlay(GlassChromeOverlay(accent: accent))
            case .solid:
                SolidChromeOverlay(accent: accent)
            }
        }
    }
}

/// Frosted inset panel for picker overlays (QR sheet, shortcuts, etc.).
struct PickerGlassPanel<Content: View>: View {
    var theme: ChromeTheme
    var accent: Color
    var cornerRadius: CGFloat = 18
    /// Quieter wash and shadows for compact overlays (e.g. QR sheet).
    var subtle: Bool = false
    @ViewBuilder var content: () -> Content

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content()
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    Group {
                        switch theme {
                        case .glass:
                            GlassChromeOverlay(accent: accent)
                        case .solid:
                            SolidChromeOverlay(accent: accent)
                        }
                    }
                    .opacity(subtle ? 0.38 : 1)
                    .clipShape(shape)
                    shape.fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(subtle ? 0.06 : 0.10),
                                Color.white.opacity(subtle ? 0.01 : 0.02),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(subtle ? 0.14 : 0.22),
                            Color.white.opacity(0.05),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .shadow(
                color: Color.black.opacity(subtle ? 0.32 : 0.42),
                radius: subtle ? 14 : 22,
                x: 0,
                y: subtle ? 5 : 8
            )
            .shadow(
                color: accent.opacity(subtle ? 0 : 0.16),
                radius: 16,
                x: 0,
                y: 4
            )
    }
}
