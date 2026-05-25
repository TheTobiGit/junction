import AppKit
import SwiftUI
import ApplicationServices

final class OnboardingWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(
            onFinish: { [weak self] in
                SettingsStore.shared.markOnboardingComplete()
                self?.window?.close()
            }
        )
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Welcome to Junction"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.setContentSize(NSSize(width: 720, height: 620))
        window.minSize = NSSize(width: 720, height: 620)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome, defaultBrowser, permissions, appSchemes, hotkeys, done

    var headline: String {
        switch self {
        case .welcome: return "Every link.\nRight place."
        case .defaultBrowser: return "Make Junction\nyour default."
        case .permissions: return "A couple of\nquick permissions."
        case .appSchemes: return "Skip the browser\nwhen you can."
        case .hotkeys: return "Summon the picker\nfrom anywhere."
        case .done: return "You're all set."
        }
    }

    var caption: String {
        switch self {
        case .welcome: return "Junction catches every link click and lets you choose where it lands. Local. Private. Fast."
        case .defaultBrowser: return "macOS will ask once. Junction needs this to catch links from other apps."
        case .permissions: return "Optional, but they unlock the smartest routing."
        case .appSchemes: return "Send Slack, Figma, and Notion links straight to the desktop app."
        case .hotkeys: return "Two shortcuts. Pick a browser or paste-and-go without lifting your hands."
        case .done: return "Tweak rules, profiles, and rewrites anytime from the menu bar."
        }
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var step: OnboardingStep = .welcome
    @State private var heroPulse: Bool = false
    @ObservedObject private var settings = SettingsStore.shared
    @StateObject private var permissions = PermissionStatusModel()

    private var accent: Color { settings.settings.accentPreset.swiftUIColor }

    private var visibleSteps: [OnboardingStep] {
        if permissions.isJunctionDefaultBrowser {
            OnboardingStep.allCases.filter { $0 != .defaultBrowser }
        } else {
            Array(OnboardingStep.allCases)
        }
    }

    private var visibleStepIndex: Int {
        visibleSteps.firstIndex(of: step)
            ?? visibleSteps.firstIndex { $0.rawValue > step.rawValue }
            ?? max(visibleSteps.count - 1, 0)
    }

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                topBar
                heroArea
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                footer
            }
        }
        .frame(width: 720, height: 620)
        .tint(accent)
        .onAppear {
            permissions.startObserving()
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
        }
        .onDisappear { permissions.stopObserving() }
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    accent.opacity(0.06),
                    Color.black.opacity(0.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [accent.opacity(0.30), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 420
            )
            .blendMode(.plusLighter)
            .opacity(0.75)

            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 360
            )
            .blendMode(.plusLighter)
            .opacity(0.5)
        }
        .ignoresSafeArea()
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            ForEach(Array(visibleSteps.enumerated()), id: \.element) { index, _ in
                Capsule()
                    .fill(index <= visibleStepIndex ? accent : Color.primary.opacity(0.14))
                    .frame(
                        width: index == visibleStepIndex ? 22 : 8,
                        height: 6
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: visibleStepIndex)
            }
            Spacer()
            if step != .done {
                Button("Skip setup") { onFinish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.primary.opacity(0.06))
                    )
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 14)
    }

    // MARK: Hero

    private var heroArea: some View {
        ZStack {
            switch step {
            case .welcome: WelcomeHero(accent: accent, pulse: heroPulse)
            case .defaultBrowser: DefaultBrowserHero(accent: accent, isDefault: permissions.isJunctionDefaultBrowser, pulse: heroPulse)
            case .permissions: PermissionsHero(accent: accent, pulse: heroPulse)
            case .appSchemes: AppSchemesHero(accent: accent, pulse: heroPulse)
            case .hotkeys: HotkeysHero(accent: accent, pulse: heroPulse)
            case .done: DoneHero(accent: accent, pulse: heroPulse)
            }
        }
        .id(step)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity
        ))
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: step)
    }

    // MARK: Content

    private var contentArea: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 8) {
                Text(step.headline)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.caption)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)
            .padding(.bottom, 18)

            stepInteractions
                .padding(.horizontal, 40)
        }
    }

    @ViewBuilder
    private var stepInteractions: some View {
        switch step {
        case .welcome:
            EmptyView()
        case .defaultBrowser:
            defaultBrowserAction
        case .permissions:
            permissionsActions
        case .appSchemes:
            appSchemesPicker
        case .hotkeys:
            hotkeysList
        case .done:
            EmptyView()
        }
    }

    private var defaultBrowserAction: some View {
        VStack(spacing: 10) {
            Button {
                let bid = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
                LSSetDefaultHandlerForURLScheme("http" as CFString, bid as CFString)
                LSSetDefaultHandlerForURLScheme("https" as CFString, bid as CFString)
                permissions.refresh()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: permissions.isJunctionDefaultBrowser ? "checkmark.circle.fill" : "arrow.up.right.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(permissions.isJunctionDefaultBrowser ? "Junction is your default" : "Set Junction as default")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .frame(minWidth: 240)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(permissions.isJunctionDefaultBrowser)

            if !permissions.isJunctionDefaultBrowser {
                Text("If macOS doesn't ask, open Settings > Desktop & Dock and pick Junction.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionsActions: some View {
        HStack(spacing: 12) {
            permissionTile(
                icon: "hand.raised.fill",
                title: "Accessibility",
                granted: permissions.isAccessibilityTrusted,
                actionLabel: "Grant",
                action: { permissions.requestAccessibility() }
            )
            permissionTile(
                icon: "bell.badge.fill",
                title: "Notifications",
                granted: permissions.notificationStatus == .granted,
                actionLabel: permissions.notificationStatus == .notDetermined ? "Grant" : "Settings",
                action: {
                    if permissions.notificationStatus == .notDetermined {
                        permissions.requestNotificationAuthorization()
                    } else {
                        permissions.openNotificationSettings()
                    }
                }
            )
        }
    }

    private func permissionTile(
        icon: String,
        title: String,
        granted: Bool,
        actionLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(granted ? Color.green.opacity(0.18) : accent.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: granted ? "checkmark" : icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(granted ? .green : accent)
            }
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            if granted {
                Text("Granted")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.green)
                    .frame(height: 22)
            } else {
                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var appSchemesPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(settings.settings.appSchemes) { rewrite in
                    appSchemeChip(rewrite: rewrite)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 80)
    }

    private func appSchemeChip(rewrite: AppSchemeRewrite) -> some View {
        let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rewrite.bundleID) != nil
        let active = rewrite.enabled && installed
        return Button {
            settings.setAppSchemeEnabled(id: rewrite.id, enabled: !rewrite.enabled)
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(active ? accent.opacity(0.22) : Color.primary.opacity(0.06))
                        .frame(width: 26, height: 26)
                    Image(systemName: active ? "checkmark" : "app.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(active ? accent : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(rewrite.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(installed ? (active ? "On" : "Off") : "Not installed")
                        .font(.system(size: 10))
                        .foregroundColor(installed ? (active ? accent : .secondary) : .secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(active ? accent.opacity(0.10) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        active ? accent.opacity(0.45) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!installed)
        .opacity(installed ? 1 : 0.55)
    }

    private var hotkeysList: some View {
        VStack(spacing: 10) {
            onboardingHotkeyRow(
                icon: "rectangle.stack.fill",
                title: "Open picker",
                detail: "Show the picker for the link on your clipboard.",
                binding: Binding(
                    get: { settings.settings.hotkeys.summonPicker },
                    set: { settings.setHotkey($0, for: \.summonPicker) }
                )
            )
            onboardingHotkeyRow(
                icon: "bolt.fill",
                title: "Paste & open",
                detail: "Skip the picker. Route the clipboard link instantly.",
                binding: Binding(
                    get: { settings.settings.hotkeys.pasteAndOpen },
                    set: { settings.setHotkey($0, for: \.pasteAndOpen) }
                )
            )
        }
    }

    private func onboardingHotkeyRow(
        icon: String,
        title: String,
        detail: String,
        binding: Binding<HotkeyBinding>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 12)

            HotkeyRecorderView(binding: binding)
                .frame(width: 150, height: 32)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button("Back") { goBackStep() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.primary.opacity(0.05))
                )
                .opacity(visibleStepIndex == 0 ? 0 : 1)
                .disabled(visibleStepIndex == 0)
                .keyboardShortcut(.leftArrow, modifiers: [.command])

            Spacer()

            Button(action: {
                if step == .done { onFinish() } else { advanceStep() }
            }) {
                HStack(spacing: 6) {
                    Text(step == .done ? "Get started" : "Continue")
                        .font(.system(size: 13, weight: .semibold))
                    if step != .done {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 22)
        .padding(.top, 8)
    }

    private func advanceStep() {
        if let i = visibleSteps.firstIndex(of: step), i + 1 < visibleSteps.count {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                step = visibleSteps[i + 1]
            }
            return
        }
        if let next = visibleSteps.first(where: { $0.rawValue > step.rawValue }) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                step = next
            }
        }
    }

    private func goBackStep() {
        if let i = visibleSteps.firstIndex(of: step), i > 0 {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                step = visibleSteps[i - 1]
            }
            return
        }
        if let previous = visibleSteps.last(where: { $0.rawValue < step.rawValue }) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                step = previous
            }
        }
    }
}

// MARK: - Hero illustrations

private struct HeroFrame<Content: View>: View {
    let accent: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.18), accent.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: accent.opacity(0.18), radius: 24, y: 10)

            content()
                .padding(20)
        }
        .frame(maxWidth: 520, maxHeight: 200)
        .padding(.horizontal, 40)
        .padding(.top, 4)
    }
}

private struct WelcomeHero: View {
    let accent: Color
    let pulse: Bool

    var body: some View {
        HeroFrame(accent: accent) {
            HStack(spacing: 0) {
                routePill(icon: "link", label: "link", color: .primary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)

                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.45), lineWidth: 2)
                        .frame(width: 72, height: 72)
                        .scaleEffect(pulse ? 1.08 : 1.0)
                        .opacity(pulse ? 0.6 : 1.0)
                    Circle()
                        .fill(LinearGradient(
                            colors: [accent, accent.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 56, height: 56)
                        .shadow(color: accent.opacity(0.5), radius: 14, y: 4)
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)

                VStack(spacing: 8) {
                    routePill(icon: "briefcase.fill", label: "Work", color: accent)
                    routePill(icon: "person.fill", label: "Personal", color: .pink)
                    routePill(icon: "eyeglasses", label: "Private", color: .indigo)
                }
            }
        }
    }

    private func routePill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            ))
        )
        .shadow(color: color.opacity(0.35), radius: 6, y: 2)
    }
}

private struct DefaultBrowserHero: View {
    let accent: Color
    let isDefault: Bool
    let pulse: Bool

    var body: some View {
        HeroFrame(accent: accent) {
            HStack(spacing: 24) {
                ForEach(["safari", "globe", "globe.americas.fill"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: [accent, accent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .frame(width: 84, height: 84)
                        .shadow(color: accent.opacity(0.5), radius: 18, y: 6)
                        .scaleEffect(pulse ? 1.05 : 1.0)

                    Image(systemName: isDefault ? "checkmark" : "arrow.triangle.branch")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }

                ForEach(["network", "globe.badge.chevron.backward", "macwindow"], id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
        }
    }
}

private struct PermissionsHero: View {
    let accent: Color
    let pulse: Bool

    var body: some View {
        HeroFrame(accent: accent) {
            HStack(spacing: 28) {
                shieldIcon(
                    symbol: "hand.raised.fill",
                    label: "Accessibility",
                    color: accent,
                    delay: 0
                )
                shieldIcon(
                    symbol: "bell.badge.fill",
                    label: "Notifications",
                    color: .orange,
                    delay: 0.4
                )
            }
        }
    }

    private func shieldIcon(symbol: String, label: String, color: Color, delay: Double) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.35), lineWidth: 2)
                    .frame(width: 88, height: 88)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .opacity(pulse ? 0.4 : 0.9)

                Circle()
                    .fill(LinearGradient(
                        colors: [color, color.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 72, height: 72)
                    .shadow(color: color.opacity(0.45), radius: 14, y: 4)

                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }
}

private struct AppSchemesHero: View {
    let accent: Color
    let pulse: Bool

    private let apps: [(String, Color)] = [
        ("message.fill", .purple),
        ("paintpalette.fill", .pink),
        ("note.text", .gray),
        ("video.fill", .blue),
        ("music.note", .red)
    ]

    var body: some View {
        HeroFrame(accent: accent) {
            HStack(spacing: 14) {
                ForEach(Array(apps.enumerated()), id: \.offset) { index, item in
                    appTile(symbol: item.0, color: item.1, lift: pulse && index % 2 == 0)
                }
            }
        }
    }

    private func appTile(symbol: String, color: Color, lift: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 64, height: 64)
                .shadow(color: color.opacity(0.4), radius: 10, y: 4)

            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)
        }
        .offset(y: lift ? -6 : 0)
    }
}

private struct HotkeysHero: View {
    let accent: Color
    let pulse: Bool

    var body: some View {
        HeroFrame(accent: accent) {
            HStack(spacing: 8) {
                keycap(label: "⌃", glow: pulse)
                keycap(label: "⌥", glow: pulse)
                keycap(label: "⌘", glow: pulse)
                Text("+")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                keycap(label: "V", wide: true, accent: true, glow: pulse)
            }
        }
    }

    private func keycap(label: String, wide: Bool = false, accent useAccent: Bool = false, glow: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(useAccent
                      ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.primary.opacity(0.08)))
                .frame(width: wide ? 78 : 56, height: 60)
                .shadow(color: useAccent ? accent.opacity(glow ? 0.6 : 0.3) : Color.black.opacity(0.18), radius: useAccent && glow ? 14 : 6, y: 3)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                .frame(width: wide ? 78 : 56, height: 60)

            Text(label)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(useAccent ? .white : .primary)
        }
    }
}

private struct DoneHero: View {
    let accent: Color
    let pulse: Bool

    var body: some View {
        HeroFrame(accent: accent) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(accent.opacity(0.25 - Double(i) * 0.07), lineWidth: 2)
                        .frame(width: CGFloat(110 + i * 36), height: CGFloat(110 + i * 36))
                        .scaleEffect(pulse ? 1.05 : 0.95)
                        .opacity(pulse ? 0.4 : 1.0)
                }

                Circle()
                    .fill(LinearGradient(
                        colors: [accent, accent.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: 96, height: 96)
                    .shadow(color: accent.opacity(0.5), radius: 22, y: 8)

                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}
