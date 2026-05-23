import AppKit
import ApplicationServices
import Combine
import UserNotifications

/// Live snapshot of every permission/state the onboarding flow asks the user
/// to flip. Polls on a short timer while observed and refreshes immediately
/// when the app becomes active (i.e. the user just came back from System
/// Settings), so rows update without restarting onboarding.
@MainActor
final class PermissionStatusModel: ObservableObject {
    enum NotificationStatus {
        case notDetermined
        case denied
        case granted

        var isGranted: Bool { self == .granted }
    }

    @Published private(set) var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    @Published private(set) var notificationStatus: NotificationStatus = .notDetermined
    @Published private(set) var isJunctionDefaultBrowser: Bool = DefaultWebBrowserStatus.current.isJunctionDefaultForHTTPAndHTTPS

    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?

    init() {
        refresh()
    }

    deinit {
        if let token = activationObserver {
            NotificationCenter.default.removeObserver(token)
        }
        timer?.invalidate()
    }

    func startObserving() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stopObserving() {
        timer?.invalidate()
        timer = nil
        if let token = activationObserver {
            NotificationCenter.default.removeObserver(token)
            activationObserver = nil
        }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityTrusted {
            isAccessibilityTrusted = trusted
        }
        let isDefault = DefaultWebBrowserStatus.current.isJunctionDefaultForHTTPAndHTTPS
        if isDefault != isJunctionDefaultBrowser {
            isJunctionDefaultBrowser = isDefault
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let status: NotificationStatus = {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: return .granted
                case .denied: return .denied
                case .notDetermined: return .notDetermined
                @unknown default: return .notDetermined
                }
            }()
            Task { @MainActor [weak self] in
                guard let self else { return }
                if status != self.notificationStatus {
                    self.notificationStatus = status
                }
            }
        }
    }

    /// Triggers the system Accessibility prompt the first time. After the user
    /// answers once, this just opens the panel for them to flip the toggle.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
