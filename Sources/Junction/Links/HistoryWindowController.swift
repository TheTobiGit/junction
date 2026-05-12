import AppKit
import SwiftUI

final class HistoryWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = HistoryView()
        let host = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: host)
        window.title = "Junction History"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 760, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct HistoryView: View {
    @State private var entries: [LinkLogEntry] = []
    @State private var inbox: [InboxEntry] = []
    @State private var query: String = ""
    @State private var tab: Tab = .history

    enum Tab: String, CaseIterable, Identifiable {
        case history = "History"
        case inbox = "Inbox"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            TextField("Search host, URL, or source…", text: $query)
                .textFieldStyle(.roundedBorder)

            switch tab {
            case .history: historyList
            case .inbox: inboxList
            }
        }
        .padding(16)
        .frame(minWidth: 720, minHeight: 520)
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(for: .junctionInboxChanged)) { _ in reload() }
    }

    private var filteredHistory: [LinkLogEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return entries }
        return entries.filter {
            $0.url.lowercased().contains(q)
            || ($0.host ?? "").lowercased().contains(q)
            || ($0.sourceName ?? "").lowercased().contains(q)
            || $0.targetLabel.lowercased().contains(q)
        }
    }

    private var filteredInbox: [InboxEntry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return inbox }
        return inbox.filter {
            $0.url.lowercased().contains(q)
            || ($0.sourceName ?? "").lowercased().contains(q)
        }
    }

    private var historyList: some View {
        Group {
            if entries.isEmpty {
                emptyState(title: "No history yet", detail: "Links you open through Junction will appear here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredHistory) { entry in
                            historyRow(entry)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Clear history") {
                    LinkLog.shared.clear()
                    reload()
                }
                .foregroundColor(.red)
            }
        }
    }

    private func historyRow(_ entry: LinkLogEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.url)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    if let source = entry.sourceName {
                        Text("from \(source)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text("→ \(entry.targetLabel)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if entry.cleaned {
                        Text("cleaned").font(.system(size: 10)).foregroundColor(.accentColor)
                    }
                }
            }
            Spacer()
            Text(relative(entry.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Button {
                if let u = URL(string: entry.url) { NSWorkspace.shared.open(u) }
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.03)))
    }

    private var inboxList: some View {
        Group {
            if inbox.isEmpty {
                emptyState(title: "Inbox is empty", detail: "Send links here when you want to read them later.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredInbox) { entry in
                            inboxRow(entry)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Clear inbox") {
                    LinkInbox.shared.clear()
                }
                .foregroundColor(.red)
            }
        }
    }

    private func inboxRow(_ entry: InboxEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.url)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    if let source = entry.sourceName {
                        Text("from \(source)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text(relative(entry.savedAt))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Open") {
                if let u = URL(string: entry.url) { NSWorkspace.shared.open(u) }
                LinkInbox.shared.remove(id: entry.id)
            }
            .buttonStyle(.borderedProminent)
            Button {
                LinkInbox.shared.remove(id: entry.id)
            } label: {
                Image(systemName: "trash").foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.03)))
    }

    private func emptyState(title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 14, weight: .medium))
            Text(detail).font(.callout).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() {
        entries = LinkLog.shared.load()
        inbox = LinkInbox.shared.entries
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
