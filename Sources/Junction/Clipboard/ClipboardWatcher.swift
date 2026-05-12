import AppKit
import SwiftUI

final class ClipboardWatcher {
    static let shared = ClipboardWatcher()

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastURL: URL?
    private let hud = ClipboardHUDController()

    private init() {}

    func updateEnabledState() {
        if SettingsStore.shared.settings.clipboardWatcherEnabled {
            start()
        } else {
            stop()
        }
    }

    private func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        let t = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        guard let raw = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let url = parseURL(from: raw),
              url != lastURL
        else { return }
        lastURL = url
        hud.present(url: url)
    }

    private func parseURL(from raw: String) -> URL? {
        guard raw.count < 2048 else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return URL(string: raw)
        }
        return nil
    }
}
