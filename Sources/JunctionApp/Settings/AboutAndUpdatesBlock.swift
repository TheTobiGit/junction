import SwiftUI

struct AboutAndUpdatesBlock: View {
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PrefsBlock(title: "Updates") {
                PrefsRow(title: "Junction \(updater.currentVersion)") {
                    Button(action: { updater.check(silent: false) }) {
                        if case .checking = updater.state {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 14, height: 14)
                        } else {
                            Text("Check for Updates")
                        }
                    }
                    .controlSize(.regular)
                    .disabled(isChecking)
                }
                PrefsHairline()
                statusRow
            }

            PrefsBlock(title: "Onboarding") {
                PrefsRow(title: "Show the welcome flow again") {
                    Button("Run Onboarding") {
                        NotificationCenter.default.post(name: .junctionShowOnboarding, object: nil)
                    }
                }
            }
        }
    }

    private var isChecking: Bool {
        if case .checking = updater.state { return true }
        return false
    }

    @ViewBuilder
    private var statusRow: some View {
        switch updater.state {
        case .idle:
            statusLine(
                icon: "arrow.clockwise.circle",
                tint: .secondary,
                title: "Not checked yet",
                detail: "Junction will look for updates automatically at launch."
            )
        case .checking:
            statusLine(
                icon: "arrow.clockwise.circle",
                tint: .secondary,
                title: "Checking GitHub Releases…",
                detail: nil
            )
        case .upToDate(let v):
            statusLine(
                icon: "checkmark.seal.fill",
                tint: .green,
                title: "You're on the latest version (\(v))",
                detail: lastCheckedDetail
            )
        case .updateAvailable(let latest, _, _):
            VStack(alignment: .leading, spacing: 8) {
                statusLine(
                    icon: "arrow.down.circle.fill",
                    tint: .accentColor,
                    title: "Update available: \(latest)",
                    detail: "A newer release is on GitHub."
                )
                HStack(spacing: 8) {
                    Button("Download Update") {
                        updater.openLatestRelease()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("View Release Notes") {
                        updater.openLatestRelease()
                    }
                }
                .padding(.leading, 28)
            }
        case .error(let message):
            statusLine(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: "Couldn't check for updates",
                detail: message
            )
        }
    }

    private var lastCheckedDetail: String? {
        guard let date = updater.lastCheckedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Checked \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func statusLine(icon: String, tint: Color, title: String, detail: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
