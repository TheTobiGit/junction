import Foundation

struct InboxEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let url: String
    let savedAt: Date
    let sourceBundleID: String?
    let sourceName: String?
    let note: String?

    init(url: URL, source: URLSource?, note: String? = nil) {
        self.id = UUID()
        self.url = url.absoluteString
        self.savedAt = Date()
        self.sourceBundleID = source?.bundleID
        self.sourceName = source?.name
        self.note = note
    }
}

final class LinkInbox {
    static let shared = LinkInbox()

    private let fileURL: URL
    private(set) var entries: [InboxEntry] = []

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("inbox.json")
        load()
    }

    func add(url: URL, source: URLSource?) {
        let entry = InboxEntry(url: url, source: source)
        entries.insert(entry, at: 0)
        persist()
        NotificationCenter.default.post(name: .junctionInboxChanged, object: nil)
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
        NotificationCenter.default.post(name: .junctionInboxChanged, object: nil)
    }

    func clear() {
        entries.removeAll()
        persist()
        NotificationCenter.default.post(name: .junctionInboxChanged, object: nil)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        entries = (try? decoder.decode([InboxEntry].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

extension Notification.Name {
    static let junctionInboxChanged = Notification.Name("junctionInboxChanged")
}
