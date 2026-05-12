import AppKit
import SwiftUI

final class BatchWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = BatchRouterView()
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Junction Batch"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 720, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct BatchRow: Identifiable, Hashable {
    let id = UUID()
    var raw: String
    var target: LaunchTarget?
    var status: String = ""
}

struct BatchRouterView: View {
    @State private var input: String = ""
    @State private var rows: [BatchRow] = []
    @State private var options: [LaunchOption] = []
    @State private var defaultTargetKey: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Batch mode").font(.headline)
            Text("Paste a list of URLs (one per line) and send each to the target of your choice. Rules still apply to rows that have no target set.")
                .foregroundColor(.secondary)
                .font(.callout)

            pasteArea
            Divider()
            rowsTable
        }
        .padding(16)
        .frame(minWidth: 680, minHeight: 520)
        .onAppear { options = LaunchOptionDiscovery.options() }
    }

    private var pasteArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))

            HStack {
                Menu(defaultTargetLabel) {
                    Button("Use rules (no override)") { defaultTargetKey = nil }
                    Divider()
                    ForEach(options) { o in
                        Button(o.displayName) { defaultTargetKey = o.target.storageKey }
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 260)

                Spacer()

                Button("Parse") { parseInput() }
                Button("Open all") { openAll() }
                    .buttonStyle(.borderedProminent)
                    .disabled(rows.isEmpty)
            }
        }
    }

    private var defaultTargetLabel: String {
        if let key = defaultTargetKey,
           let option = options.first(where: { $0.target.storageKey == key }) {
            return "Default: \(option.displayName)"
        }
        return "Default: use rules"
    }

    private var rowsTable: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach($rows) { $row in
                    HStack(spacing: 8) {
                        Text(row.raw)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Menu(rowTargetLabel(row)) {
                            Button("Use rules (no override)") { $row.target.wrappedValue = nil }
                            Divider()
                            ForEach(options) { o in
                                Button(o.displayName) { $row.target.wrappedValue = o.target }
                            }
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 200)

                        Text(row.status)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)

                        Button {
                            rows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.03)))
                }
            }
        }
        .frame(minHeight: 200)
    }

    private func rowTargetLabel(_ row: BatchRow) -> String {
        if let t = row.target,
           let o = options.first(where: { $0.target == t }) {
            return o.displayName
        }
        if let key = defaultTargetKey,
           let o = options.first(where: { $0.target.storageKey == key }) {
            return o.displayName
        }
        return "Use rules"
    }

    private func parseInput() {
        let lines = input
            .split(whereSeparator: { $0.isNewline })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let urls = lines.compactMap { line -> String? in
            if line.contains("://") { return line }
            return "https://\(line)"
        }

        rows = urls.map { BatchRow(raw: $0) }
    }

    private func openAll() {
        for idx in rows.indices {
            let row = rows[idx]
            guard let url = URL(string: row.raw) else {
                rows[idx].status = "invalid"
                continue
            }
            let target = row.target ?? defaultTargetKey.flatMap { key in
                options.first { $0.target.storageKey == key }?.target
            }
            let finalURL = SettingsStore.shared.settings.cleanURLsBeforeOpening
                ? URLTransformers.default.run(url)
                : url

            if let target,
               let option = options.first(where: { $0.target == target }) {
                URLOpener.open(finalURL, with: option)
                rows[idx].status = "opened"
            } else {
                NSWorkspace.shared.open(finalURL)
                rows[idx].status = "via rules"
            }
        }
    }
}
