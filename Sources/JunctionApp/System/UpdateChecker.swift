import AppKit
import Combine
import Foundation
import Sparkle

/// Thin app-facing wrapper around Sparkle 2.
///
/// Sparkle owns the update feed parsing, EdDSA signature validation,
/// installer helper flow, automatic check scheduling, and user-facing update
/// UI. Keep app code limited to starting Sparkle and forwarding explicit
/// "Check for Updates…" actions.
@MainActor
final class UpdateChecker: NSObject, ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var canCheckForUpdates = false

    private let updaterController: SPUStandardUpdaterController
    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    override private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        updaterController.updater.publisher(for: \.canCheckForUpdates, options: [.initial, .new])
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var automaticChecksEnabled: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticDownloadsEnabled: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        updaterController.startUpdater()
    }

    func checkForUpdates() {
        start()
        NSApp.activate(ignoringOtherApps: true)
        updaterController.checkForUpdates(nil)
    }

    /// Backward-compatible entry point for older call sites.
    /// Sparkle schedules background checks itself, so silent launch checks are
    /// intentionally no-ops after ensuring the updater has started.
    func check(silent: Bool = false) {
        if silent {
            start()
        } else {
            checkForUpdates()
        }
    }
}
