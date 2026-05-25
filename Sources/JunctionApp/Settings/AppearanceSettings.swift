import AppKit
import SwiftUI

/// Layout style for the browser picker.
enum PickerStyle: String, Codable, CaseIterable, Identifiable {
    case tiles
    case list
    case dial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiles: return "Tiles"
        case .list: return "List"
        case .dial: return "Dial"
        }
    }
}

/// Background treatment for floating panels (picker, clipboard HUD).
enum ChromeTheme: String, Codable, CaseIterable, Identifiable {
    case glass
    case solid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .solid: return "Solid"
        }
    }
}

/// Accent used for gradients, progress bars, and control tint in Junction UI.
enum AccentPreset: String, Codable, CaseIterable, Identifiable {
    case system
    case blue
    case purple
    case teal
    case green
    case orange
    case pink
    case red

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .teal: return "Teal"
        case .green: return "Green"
        case .orange: return "Orange"
        case .pink: return "Pink"
        case .red: return "Red"
        }
    }

    /// Color for gradients and `.tint`. `.system` tracks the macOS control accent.
    var swiftUIColor: Color {
        switch self {
        case .system:
            return Color(nsColor: .controlAccentColor)
        case .blue:
            return Color(red: 0.0, green: 0.478, blue: 1.0)
        case .purple:
            return Color(red: 0.45, green: 0.32, blue: 0.98)
        case .teal:
            return Color(red: 0.0, green: 0.62, blue: 0.60)
        case .green:
            return Color(red: 0.20, green: 0.72, blue: 0.35)
        case .orange:
            return Color(red: 1.0, green: 0.48, blue: 0.0)
        case .pink:
            return Color(red: 1.0, green: 0.32, blue: 0.55)
        case .red:
            return Color(red: 1.0, green: 0.27, blue: 0.23)
        }
    }
}
