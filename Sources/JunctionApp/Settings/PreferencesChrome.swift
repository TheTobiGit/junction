import AppKit
import SwiftUI

// MARK: - Sidebar

struct PrefsSidebar: View {
    @Binding var selection: PrefsSection
    var showsBrand: Bool = false

    private let groups: [(String?, [PrefsSection])] = [
        (nil, [.general, .targets]),
        ("Links", [.rules, .rewrites, .appSchemes]),
        ("More", [.hotkeys, .activity, .trackers]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsBrand {
                Self.brand
                    .padding(.bottom, 12)
            }

            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    PrefsHairline()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                if let label = group.0 {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 6)
                }

                VStack(spacing: 2) {
                    ForEach(group.1) { section in
                        navRow(section)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 0)

            Text("v" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
        }
        .frame(width: 200)
    }

    static var brand: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.08)))

            Text("Settings")
                .font(.system(size: 15, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func navRow(_ section: PrefsSection) -> some View {
        let selected = selection == section
        return Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .frame(width: 18)

                Text(section.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.72))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Content blocks

struct PrefsBlock<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
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

struct PrefsPageHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Spacer(minLength: 12)
            trailing()
        }
    }
}

// MARK: - Rows & controls

struct PrefsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            Text(title)
                .font(.system(size: 13))
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.vertical, 11)
    }
}

struct PrefsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        PrefsRow(title: title) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct PrefsHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 0.5)
    }
}

struct PrefsVerticalRule: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }
}

struct PrefsButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isEnabled ? Color.primary : Color.primary.opacity(0.4))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

struct PrefsIconButton: View {
    var symbol: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct PrefsEmptyState: View {
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if let actionTitle, let action {
                PrefsButton(title: actionTitle, symbol: "plus", action: action)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct PrefsAccentSwatch: View {
    let preset: AccentPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if preset == .system {
                    Circle()
                        .fill(Color.primary.opacity(0.12))
                        .frame(width: 20, height: 20)
                    Image(systemName: "apple.logo")
                        .font(.system(size: 10, weight: .medium))
                } else {
                    Circle()
                        .fill(preset.swiftUIColor)
                        .frame(width: 20, height: 20)
                }
                if isSelected {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.85), lineWidth: 1.5)
                        .frame(width: 26, height: 26)
                }
            }
            .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .help(preset.title)
    }
}

struct PrefsFieldBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.06))
    }
}

// MARK: - Rule display

extension DomainRule {
    var prefsTitle: String {
        if let urlEquals, let host = URL(string: urlEquals)?.host {
            return host
        }
        return displayValue
    }

    var prefsSubtitle: String? {
        if urlEquals != nil { return "One specific link" }

        var parts: [String] = []
        if case .suffix = host { parts.append("All subdomains") }

        if let path {
            switch path {
            case .prefix(let v): parts.append("Paths starting with \(v)")
            case .contains(let v): parts.append("Paths containing \(v)")
            case .glob(let v): parts.append("Paths matching \(v)")
            case .regex: parts.append("Custom path pattern")
            }
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
