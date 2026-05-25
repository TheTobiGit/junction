import Foundation

/// Release gates for features that ship in the binary but are not ready for all users.
///
/// Flip `shipClipboardLinkHUD` to `true` before a release when the clipboard link bar
/// should appear in Preferences and work for users who turn it on.
///
/// Local testing while the flag is `false`:
/// ```bash
/// JUNCTION_CLIPBOARD_HUD=1 open build/Junction.app
/// ```
enum FeatureFlags {
    /// Master switch — `false` hides the HUD and its Preferences toggle from everyone.
    static let shipClipboardLinkHUD = false

    /// Clipboard link bar is available when shipped and the user enables it in Preferences.
    static var clipboardLinkHUD: Bool {
        clipboardLinkHUD(environment: ProcessInfo.processInfo.environment)
    }

    static func clipboardLinkHUD(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["JUNCTION_CLIPBOARD_HUD"] == "1" {
            return true
        }
        return shipClipboardLinkHUD
    }

    static func clipboardLinkHUDEnabled(
        userPreference: Bool,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        clipboardLinkHUD(environment: environment) && userPreference
    }
}
