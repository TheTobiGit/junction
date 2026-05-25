import SwiftUI

struct AboutAndUpdatesBlock: View {
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PrefsBlock(title: "Updates") {
                PrefsRow(title: "Junction \(updater.currentVersion)") {
                    Button("Check for Updates…") {
                        updater.checkForUpdates()
                    }
                    .controlSize(.regular)
                    .disabled(!updater.canCheckForUpdates)
                }
                PrefsHairline()
                PrefsRow(title: "Check automatically") {
                    Toggle("", isOn: automaticChecksBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PrefsHairline()
                PrefsRow(title: "Download and install automatically") {
                    Toggle("", isOn: automaticDownloadsBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                PrefsHairline()
                statusLine(
                    icon: "sparkles",
                    tint: .accentColor,
                    title: "Updates are handled by Sparkle",
                    detail: "Sparkle verifies signed appcasts and signed update archives, then safely installs and relaunches Junction."
                )
            }

            PrefsBlock(title: "Onboarding") {
                PrefsRow(title: "Show the welcome flow again") {
                    Button("Run Onboarding") {
                        NotificationCenter.default.post(name: .junctionShowOnboarding, object: nil)
                    }
                }
            }
        }
        .onAppear { updater.start() }
    }

    private var automaticChecksBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticChecksEnabled },
            set: { updater.automaticChecksEnabled = $0 }
        )
    }

    private var automaticDownloadsBinding: Binding<Bool> {
        Binding(
            get: { updater.automaticDownloadsEnabled },
            set: { updater.automaticDownloadsEnabled = $0 }
        )
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
