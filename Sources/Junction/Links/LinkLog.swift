import Foundation

struct LinkLogEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let url: String
    let host: String?
    let targetKey: String
    let targetLabel: String
    let sourceBundleID: String?
    let sourceName: String?
    let cleaned: Bool

    init(
        url: URL,
        target: LaunchOption,
        source: URLSource?,
        cleaned: Bool
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.url = url.absoluteString
        self.host = RulesStore.normalizedHost(for: url)
        self.targetKey = target.target.storageKey
        self.targetLabel = target.displayName
        self.sourceBundleID = source?.bundleID
        self.sourceName = source?.name
        self.cleaned = cleaned
    }
}

final class LinkLog {
    static let shared = LinkLog()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "dev.gideonsarfo.Junction.linklog")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Junction", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("history.jsonl")
    }

    func record(_ entry: LinkLogEntry) {
        queue.async { [weak self] in self?.append(entry) }
    }

    private func append(_ entry: LinkLogEntry) {
        guard var data = try? encoder.encode(entry) else { return }
        data.append(0x0A)

        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            try? data.write(to: fileURL)
            return
        }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }

    func load(limit: Int = 500) -> [LinkLogEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        var entries: [LinkLogEntry] = []
        var start = data.startIndex
        while start < data.endIndex {
            guard let nl = data[start...].firstIndex(of: 0x0A) else {
                let slice = data[start..<data.endIndex]
                if !slice.isEmpty,
                   let entry = try? decoder.decode(LinkLogEntry.self, from: slice) {
                    entries.append(entry)
                }
                break
            }
            let slice = data[start..<nl]
            if !slice.isEmpty,
               let entry = try? decoder.decode(LinkLogEntry.self, from: slice) {
                entries.append(entry)
            }
            start = data.index(after: nl)
        }
        return Array(entries.suffix(limit).reversed())
    }

    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            try? FileManager.default.removeItem(at: self.fileURL)
        }
    }
}
