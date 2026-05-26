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
                PrefsRow(title: "Download updates automatically") {
                    Toggle("", isOn: automaticDownloadsBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
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
}
