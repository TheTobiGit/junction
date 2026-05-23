import AppKit
import UserNotifications

final class UndoNotifier: NSObject {
    static let shared = UndoNotifier()

    private var pending: (url: URL, option: LaunchOption, id: String)?
    private var didRequestAuthorization = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func announce(url: URL, option: LaunchOption, alternatives: [LaunchOption]) {
        ensureAuthorizationRequested()
        let id = UUID().uuidString
        pending = (url, option, id)

        let content = UNMutableNotificationContent()
        content.title = "Opened in \(option.displayName)"
        content.body = url.absoluteString
        content.sound = nil

        let top = alternatives.prefix(3).filter { $0.target != option.target }
        var actions: [UNNotificationAction] = []
        for alt in top.prefix(2) {
            actions.append(UNNotificationAction(
                identifier: "switch:\(alt.target.storageKey)",
                title: "Switch to \(alt.displayName)",
                options: []
            ))
        }
        let category = UNNotificationCategory(
            identifier: "junction.opened",
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "junction.opened"

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.pending?.id == id else { return }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
            self.pending = nil
        }
    }
}

extension UndoNotifier: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let pending,
              pending.id == response.notification.request.identifier
        else { return }

        let action = response.actionIdentifier
        if action.hasPrefix("switch:") {
            let key = String(action.dropFirst("switch:".count))
            if let option = LaunchOptionDiscovery.options().first(where: { $0.target.storageKey == key }) {
                URLOpener.open(pending.url, with: option)
            }
        }
        self.pending = nil
    }
}

private extension UndoNotifier {
    func ensureAuthorizationRequested() {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
