import SwiftUI
import AppKit

extension Color {
    init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

struct PickerView: View {
    @ObservedObject var model: PickerViewModel
    let width: CGFloat
    @State private var appeared: Bool = false

    static let tileWidth: CGFloat = 112
    static let tileSpacing: CGFloat = 10
    static let listHorizontalPadding: CGFloat = 16
    static let minWidth: CGFloat = 480
    static let pickerHeight: CGFloat = 268
    static let previewWidth: CGFloat = 1120
    static let previewHeight: CGFloat = 760

    static func desiredWidth(forOptionCount count: Int) -> CGFloat {
        let content = CGFloat(count) * tileWidth
            + CGFloat(max(count - 1, 0)) * tileSpacing
            + listHorizontalPadding * 2
        let screenMax: CGFloat = {
            if let screen = NSScreen.main {
                return max(minWidth, screen.visibleFrame.width - 80)
            }
            return 1200
        }()
        return max(minWidth, min(content, screenMax))
    }

    static func previewSize() -> CGSize {
        if let screen = NSScreen.main {
            let w = min(previewWidth, screen.visibleFrame.width - 80)
            let h = min(previewHeight, screen.visibleFrame.height - 120)
            return CGSize(width: max(minWidth, w), height: max(360, h))
        }
        return CGSize(width: previewWidth, height: previewHeight)
    }

    var body: some View {
        ZStack {
            if model.previewMode {
                PreviewView(model: model)
                    .frame(width: Self.previewSize().width, height: Self.previewSize().height)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                pickerBody
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: model.previewMode)
        .background(KeyEventCatcher(model: model))
        .scaleEffect(appeared ? 1.0 : 0.96)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var pickerBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            optionList
            footer
        }
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.04), Color.black.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .frame(width: width, height: Self.pickerHeight)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 6) {
                if let source = model.sourceApp {
                    sourcePill(source)
                }
                if let focus = model.focusName {
                    focusBadge(focus)
                }
                if model.incognitoMode {
                    incognitoBadge
                }
                if !model.riskFlags.isEmpty {
                    riskChip(model.riskFlags)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            GeometryReader { geo in
                let faviconSlot: CGFloat = 14 + 6
                let textCap = max(48, geo.size.width - faviconSlot)
                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: 4) {
                        FaviconView(data: model.resolvedFaviconData, fallbackSize: 9)
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                        Text(displayURL)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: textCap)
                    Spacer(minLength: 0)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 28)

            HStack(spacing: 6) {
                Button {
                    model.openPreferences()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Open Preferences")
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var incognitoBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 9, weight: .semibold))
            Text("Private")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.indigo)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(Color.indigo.opacity(0.18)))
        .help("Open in private/incognito mode (⌥ to toggle, ⌥⏎ to confirm)")
    }

    private var displayURL: String {
        model.didClean ? model.cleanedURL.absoluteString : model.url.absoluteString
    }

    private func sourcePill(_ source: URLSource) -> some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 18, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                if let icon = source.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            }
            (Text("from ")
                .foregroundColor(.secondary)
                + Text(source.name)
                .foregroundColor(.primary)
                .fontWeight(.semibold))
                .font(.system(size: 11))
        }
        .padding(.leading, 8)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.white.opacity(0.08)))
    }

    private func focusBadge(_ name: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "moon.fill")
                .font(.system(size: 9))
            Text(name)
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .foregroundColor(.purple)
        .background(Capsule().fill(Color.purple.opacity(0.18)))
    }

    private func riskChip(_ flags: [RiskFlag]) -> some View {
        let highest = flags.max(by: { $0.level.rawValue < $1.level.rawValue }) ?? flags[0]
        let tint = riskTint(highest.level)
        return HStack(spacing: 4) {
            Image(systemName: riskIcon(highest.level))
                .font(.system(size: 9, weight: .semibold))
            Text(flags.count == 1 ? highest.title : "\(flags.count) risk flags")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.18)))
        .help(flags.map { "\($0.title): \($0.detail)" }.joined(separator: "\n"))
    }

    private func riskTint(_ level: RiskLevel) -> Color {
        switch level {
        case .info: return .blue
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }

    private func riskIcon(_ level: RiskLevel) -> String {
        switch level {
        case .info: return "info.circle.fill"
        case .low: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "shield.lefthalf.filled"
        }
    }

    private var optionList: some View {
        let list = model.filteredOptions
        return Group {
            if list.isEmpty {
                Text("No browsers enabled — open Preferences to show some.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: Self.tileSpacing) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { idx, option in
                        tile(idx: idx, option: option)
                    }
                }
                .padding(.horizontal, Self.listHorizontalPadding)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func tile(idx: Int, option: LaunchOption) -> some View {
        let incognitoUnsupported = model.incognitoMode
            && !URLOpener.supportsIncognito(bundleID: option.browser.bundleID)
        return PickerTile(
            option: option,
            number: idx + 1,
            selected: idx == model.selectedIndex,
            multiSelected: model.multiSelection.contains(option.id),
            dimmed: incognitoUnsupported,
            appearDelay: Double(idx) * 0.018
        )
        .help(incognitoUnsupported
              ? "\(option.browser.name) doesn't support private windows — it will open normally."
              : "Open in \(option.displayName)")
        .contentShape(Rectangle())
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            if flags.contains(.shift) {
                model.toggleMulti(option)
            } else {
                let incognito = flags.contains(.option) || model.incognitoMode
                model.pick(option, incognito: incognito)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 10) {
            if !model.multiSelection.isEmpty {
                Text("\(model.multiSelection.count) selected")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }

            if let host = model.rememberHost, !model.incognitoMode {
                rememberToggle(host: host)
            }

            Spacer(minLength: 8)

            hintSegments
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
    }

    private func rememberToggle(host: String) -> some View {
        Button {
            model.toggleRemember()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.rememberChoice ? "checkmark.square.fill" : "square")
                    .font(.system(size: 10, weight: .semibold))
                Text("Always open ")
                    .foregroundColor(.secondary)
                + Text(host)
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                + Text(" here")
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 11))
            .foregroundColor(model.rememberChoice ? .accentColor : .secondary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                Capsule().fill(
                    model.rememberChoice
                        ? Color.accentColor.opacity(0.16)
                        : Color.white.opacity(0.06)
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    model.rememberChoice
                        ? Color.accentColor.opacity(0.5)
                        : Color.white.opacity(0.08),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
        .help("Remember the browser you pick next as the default for \(host)")
    }

    private var hintSegments: some View {
        HStack(alignment: .center, spacing: 8) {
            HintPill(key: "␣", label: "Preview")
            HintPill(key: "↵", label: "Open")
            HintPill(key: "⌥", label: "Private")
            HintPill(key: "1-9", label: "Switch")
        }
        .help(PickerShortcutHelp.picker)
    }
}

private extension RiskLevel {
    var rank: Int { rawValue }
}

private struct PickerTile: View {
    let option: LaunchOption
    let number: Int
    let selected: Bool
    let multiSelected: Bool
    let dimmed: Bool
    let appearDelay: Double
    @State private var hovered: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: option.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 48, height: 48)
                    .scaleEffect(hovered && !selected ? 1.06 : (selected ? 1.03 : 1.0))

                if number <= 9 {
                    Text("\(number)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.85))
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                        )
                        .offset(x: 6, y: -4)
                }

                if multiSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                        .background(Circle().fill(Color.black.opacity(0.5)))
                        .offset(x: 6, y: 38)
                }
            }
            .frame(height: 54)

            VStack(spacing: 2) {
                Text(option.browser.name)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let profile = option.profile {
                    HStack(spacing: 4) {
                        if let hex = option.colorHex, let color = Color(hexString: hex) {
                            Capsule()
                                .fill(color)
                                .frame(width: 10, height: 3)
                        }
                        Text(profile.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .frame(width: 112, height: 124)
        .background(
            tileFill
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tileStroke, lineWidth: selected || multiSelected ? 2 : 1)
        )
        .shadow(
            color: selected ? Color.accentColor.opacity(0.35) : Color.black.opacity(hovered ? 0.22 : 0.0),
            radius: selected ? 14 : 8,
            x: 0,
            y: selected ? 6 : 3
        )
        .opacity(dimmed ? 0.45 : 1.0)
        .contentShape(Rectangle())
        .scaleEffect(appeared ? 1.0 : 0.9)
        .opacity(appeared ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(appearDelay)) {
                appeared = true
            }
        }
        .onHover { isHovered in
            hovered = isHovered
            if isHovered {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .animation(.easeOut(duration: 0.15), value: hovered)
        .animation(.easeOut(duration: 0.15), value: selected)
        .animation(.easeOut(duration: 0.15), value: multiSelected)
    }

    @ViewBuilder
    private var tileFill: some View {
        if multiSelected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.30), Color.accentColor.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if selected {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.34), Color.accentColor.opacity(0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if hovered {
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var tileStroke: Color {
        if multiSelected { return Color.accentColor.opacity(0.75) }
        if selected { return Color.accentColor.opacity(0.85) }
        if hovered { return Color.white.opacity(0.18) }
        return Color.white.opacity(0.06)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private struct KeyEventCatcher: NSViewRepresentable {
    let model: PickerViewModel

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.model = model
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyCatcherView: NSView {
    weak var model: PickerViewModel?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            return
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let model = self.model, event.window === self.window else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let cmd = modifiers.contains(.command)
            let opt = modifiers.contains(.option)
            let shift = modifiers.contains(.shift)

            if model.previewMode {
                switch event.keyCode {
                case 53:
                    model.exitPreview(); return nil
                case 49 where !shift && !cmd:
                    model.exitPreview(); return nil
                case 36, 76:
                    model.openInBrowserFromPreview(
                        remember: cmd ? true : nil,
                        incognito: opt ? true : nil
                    )
                    return nil
                case 123, 126:
                    model.moveSelection(-1); return nil
                case 124, 125:
                    model.moveSelection(1); return nil
                default: break
                }
                if cmd && shift,
                   event.charactersIgnoringModifiers?.lowercased() == "c" {
                    model.copyCleanedURL()
                    return nil
                }
                if modifiers == .option,
                   event.charactersIgnoringModifiers?.lowercased() == "p" {
                    model.toggleIncognito()
                    return nil
                }
                if (modifiers.isEmpty || modifiers == .command) && !shift,
                   let chars = event.charactersIgnoringModifiers,
                   chars.count == 1,
                   let digit = Int(chars),
                   digit >= 1, digit <= 9 {
                    let idx = digit - 1
                    guard model.filteredOptions.indices.contains(idx) else { return nil }
                    model.selectedIndex = idx
                    return nil
                }
                return event
            }

            switch event.keyCode {
            case 124, 125:
                model.moveSelection(1); return nil
            case 123, 126:
                model.moveSelection(-1); return nil
            case 53:
                model.cancel(); return nil
            case 49:
                if shift {
                    model.toggleMultiAtSelection()
                } else {
                    model.enterPreview()
                }
                return nil
            case 36, 76:
                model.confirmSelection(
                    remember: cmd ? true : nil,
                    incognito: opt ? true : nil
                )
                return nil
            default: break
            }
            if modifiers == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                model.copyCleanedURL()
                return nil
            }
            if modifiers == .option,
               event.charactersIgnoringModifiers?.lowercased() == "p" {
                model.toggleIncognito()
                return nil
            }
            if (modifiers.isEmpty || modifiers == .shift || modifiers == .command || modifiers == .option),
               let chars = event.charactersIgnoringModifiers,
               chars.count == 1,
               let digit = Int(chars),
               digit >= 1, digit <= 9 {
                let withRemember = modifiers.contains(.command)
                let withPrivate = modifiers.contains(.option) ? true : nil
                model.pickByNumber(
                    digit,
                    remember: withRemember ? true : nil,
                    incognito: withPrivate
                )
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
