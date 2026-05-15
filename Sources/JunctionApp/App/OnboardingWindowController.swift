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
        window.setContentSize(NSSize(width: 640, height: 520))
        window.minSize = NSSize(width: 640, height: 520)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome, defaultBrowser, permissions, appSchemes, hotkeys, done

    var title: String {
        switch self {
        case .welcome: return "Route links to the right browser"
        case .defaultBrowser: return "Make Junction your default"
        case .permissions: return "Grant permissions"
        case .appSchemes: return "Open native apps instead of web"
        case .hotkeys: return "Set up a hotkey (optional)"
        case .done: return "You're ready"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "Junction intercepts every link click and lets you pick the browser, profile, or app. Nothing leaves your Mac."
        case .defaultBrowser:
            return "macOS will ask you to confirm. Without this, Junction can't catch links from other apps."
        case .permissions:
            return "For source app + focus awareness, Junction needs Accessibility access. This is optional but recommended."
        case .appSchemes:
            return "Send matching links straight to the desktop app when it's installed."
        case .hotkeys:
            return "Trigger the picker for any link on your clipboard, no matter which app you're in."
        case .done:
            return "Visit Preferences to fine-tune rules, rewrites, and browser profiles whenever you want."
        }
    }
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var step: OnboardingStep = .welcome
    @ObservedObject private var settings = SettingsStore.shared

    private var visibleSteps: [OnboardingStep] {
        if DefaultWebBrowserStatus.isJunctionDefaultForHTTPAndHTTPS {
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
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.2)
            footer
        }
        .frame(width: 640, height: 520)
        .tint(settings.settings.accentPreset.swiftUIColor)
        .background(
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Array(visibleSteps.enumerated()), id: \.element) { index, _ in
                    Circle()
                        .fill(index <= visibleStepIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
                Spacer()
                Button("Skip setup") {
                    onFinish()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }

            Text(step.title)
                .font(.system(size: 22, weight: .semibold))
                .padding(.top, 4)
            Text(step.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 32)
        .padding(.top, 26)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            Group {
                switch step {
                case .welcome: welcomeStep
                case .defaultBrowser: defaultBrowserStep
                case .permissions: permissionsStep
                case .appSchemes: appSchemesStep
                case .hotkeys: hotkeysStep
                case .done: doneStep
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var footer: some View {
        HStack {
            Button("Back") {
                goBackStep()
            }
            .disabled(visibleStepIndex == 0)
            .keyboardShortcut(.leftArrow, modifiers: [.command])

            Spacer()

            if step == .done {
                Button("Finish") { onFinish() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Continue") {
                    advanceStep()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
    }

    private func advanceStep() {
        if let i = visibleSteps.firstIndex(of: step), i + 1 < visibleSteps.count {
            step = visibleSteps[i + 1]
            return
        }

        if let next = visibleSteps.first(where: { $0.rawValue > step.rawValue }) {
            step = next
        }
    }

    private func goBackStep() {
        if let i = visibleSteps.firstIndex(of: step), i > 0 {
            step = visibleSteps[i - 1]
            return
        }

        if let previous = visibleSteps.last(where: { $0.rawValue < step.rawValue }) {
            step = previous
        }
    }

    // MARK: Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            bullet(icon: "arrow.triangle.branch", title: "Per-site routing",
                   detail: "Keep personal and work profiles separate. github.com goes to Work, drive.google.com goes to Personal.")
            bullet(icon: "eyeglasses", title: "Private / incognito on demand",
                   detail: "Hold Option when picking, or save an incognito rule for sensitive hosts.")
            bullet(icon: "sparkles", title: "Automatic URL cleanup",
                   detail: "Strip utm_*, fbclid, and other trackers before the browser sees them.")
        }
    }

    private var defaultBrowserStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Click the button below. macOS will ask you to confirm the change.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button {
                let bid = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
                LSSetDefaultHandlerForURLScheme("http" as CFString, bid as CFString)
                LSSetDefaultHandlerForURLScheme("https" as CFString, bid as CFString)
            } label: {
                Label("Set Junction as default browser", systemImage: "checkmark.circle.fill")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Text("If nothing happens, open System Settings > Desktop & Dock > Default web browser and choose Junction.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            permissionRow(
                title: "Accessibility",
                detail: "Needed to detect the frontmost app so Junction can route links differently based on where they came from.",
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                },
                actionLabel: "Open Privacy > Accessibility"
            )
            permissionRow(
                title: "Notifications",
                detail: "Used for the Undo banner after opening a link so you can switch browsers quickly.",
                action: {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                },
                actionLabel: "Open Notifications settings"
            )
            Text("These are optional. Junction still works without them.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    private var appSchemesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(settings.settings.appSchemes) { rewrite in
                HStack(spacing: 10) {
                    Toggle("", isOn: Binding(
                        get: { rewrite.enabled },
                        set: { settings.setAppSchemeEnabled(id: rewrite.id, enabled: $0) }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(rewrite.name)
                                .font(.system(size: 13, weight: .semibold))
                            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: rewrite.bundleID) == nil {
                                Text("Not installed")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.secondary.opacity(0.18)))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(rewrite.rules.map { $0.host }.joined(separator: ", "))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }

    private var hotkeysStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            HotkeyRowView(
                title: "Open clipboard link in picker",
                detail: "Great for triggering the picker when a link is in your clipboard.",
                binding: Binding(
                    get: { settings.settings.hotkeys.summonPicker },
                    set: { settings.setHotkey($0, for: \.summonPicker) }
                )
            )
            HotkeyRowView(
                title: "Reroute last link",
                detail: "Shows the picker for the most recently routed link so you can pick a different browser.",
                binding: Binding(
                    get: { settings.settings.hotkeys.rerouteLast },
                    set: { settings.setHotkey($0, for: \.rerouteLast) }
                )
            )
            HotkeyRowView(
                title: "Paste & open",
                detail: "Routes the clipboard link immediately using your rules.",
                binding: Binding(
                    get: { settings.settings.hotkeys.pasteAndOpen },
                    set: { settings.setHotkey($0, for: \.pasteAndOpen) }
                )
            )
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            bullet(icon: "command", title: "Menu bar",
                   detail: "Preferences (including rules) are available from the menu bar arrow icon.")
            bullet(icon: "questionmark.circle", title: "Picker tips",
                   detail: "↩ opens, ⌘↩ remembers the choice, ⌥↩ opens private, ⌘C copies the cleaned URL, 1-9 opens a specific tile.")
            bullet(icon: "terminal", title: "CLI",
                   detail: "Install the junction CLI and run junction open <url> from scripts or shortcuts.")
        }
    }

    private func bullet(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }

    private func permissionRow(title: String, detail: String, action: @escaping () -> Void, actionLabel: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(actionLabel, action: action)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
