import AppKit
import CryptoKit
import Foundation

/// Two-tier cache (memory + disk) for picker favicons and HTML preview payloads.
actor PreviewCache {
    static let shared = PreviewCache()

    private let faviconMemory = NSCache<NSString, NSData>()
    private let previewMemory = NSCache<NSString, NSData>()
    private let faviconDir: URL
    private let previewDir: URL

    private let faviconTTL: TimeInterval = 7 * 24 * 60 * 60
    private let previewTTL: TimeInterval = 60 * 60
    private let maxDiskBytes = 10 * 1024 * 1024

    /// On-disk favicon: 8-byte big-endian UNIX seconds + raw image bytes (no JSON/base64 overhead).
    private static let faviconHeaderLength = MemoryLayout<UInt64>.size

    struct CachedPreviewPayload: Codable, Equatable {
        let title: String?
        let siteName: String?
        let faviconData: Data?
    }

    private struct DiskEnvelope: Codable {
        let storedAt: Date
        let bytes: Data
    }

    init(rootDirectory: URL? = nil) {
        let bundleID = Bundle.main.bundleIdentifier ?? "dev.gideonsarfo.Junction"
        let base = rootDirectory
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent(bundleID, isDirectory: true)
                .appendingPathComponent("preview-cache", isDirectory: true)
        faviconDir = base.appendingPathComponent("favicons", isDirectory: true)
        previewDir = base.appendingPathComponent("previews", isDirectory: true)
        faviconMemory.countLimit = 200
        previewMemory.countLimit = 100

        try? FileManager.default.createDirectory(at: faviconDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: previewDir, withIntermediateDirectories: true)
    }

    func favicon(for host: String) async -> Data? {
        let key = host.lowercased()
        let nsKey = key as NSString
        if let blob = faviconMemory.object(forKey: nsKey) {
            let data = blob as Data
            if let framed = Self.decodeFaviconMemoryBlob(data),
               Date().timeIntervalSince(framed.storedAt) >= 0,
               Date().timeIntervalSince(framed.storedAt) <= faviconTTL,
               let valid = Self.validImageData(framed.imageData) {
                return valid
            }
            faviconMemory.removeObject(forKey: nsKey)
        }
        return loadFaviconFromDisk(fileKey: key)
    }

    func storeFavicon(_ data: Data, for host: String) async {
        guard Self.validImageData(data) != nil else { return }
        let key = host.lowercased()
        let nsKey = key as NSString
        repopulateFaviconMemory(key: nsKey, storedAt: Date(), imageData: data)

        let fm = FileManager.default
        let blobURL = faviconDir.appendingPathComponent(Self.hexDigest(for: key))
        let legacyURL = faviconDir.appendingPathComponent(Self.legacyFaviconFilename(for: key))
        var prefixed = Data(count: Self.faviconHeaderLength + data.count)
        let stamp = Self.encodeFaviconHeader()
        prefixed.replaceSubrange(..<Self.faviconHeaderLength, with: stamp)
        prefixed.replaceSubrange(Self.faviconHeaderLength..<prefixed.endIndex, with: data)
        try? prefixed.write(to: blobURL, options: .atomic)
        try? fm.removeItem(at: legacyURL)

        trimDiskIfNeeded()
    }

    func previewPayload(for url: URL) async -> CachedPreviewPayload? {
        let key = url.absoluteString
        let nsKey = key as NSString
        if let blob = previewMemory.object(forKey: nsKey) {
            if let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: blob as Data) {
                if Date().timeIntervalSince(envelope.storedAt) <= previewTTL,
                   let payload = try? JSONDecoder().decode(CachedPreviewPayload.self, from: envelope.bytes) {
                    return Self.sanitizedPreview(payload)
                }
            } else {
                // Older in-memory shape had no `storedAt`; drop so disk/network can refresh.
                previewMemory.removeObject(forKey: nsKey)
            }
            previewMemory.removeObject(forKey: nsKey)
        }
        guard let raw = loadPreviewFile(key: key),
              let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: raw),
              let payload = try? JSONDecoder().decode(CachedPreviewPayload.self, from: envelope.bytes)
        else { return nil }

        let sanitized = Self.sanitizedPreview(payload)
        repopulatePreviewMemory(key: nsKey, storedAt: envelope.storedAt, sanitized: sanitized)
        return sanitized
    }

    func storePreview(_ payload: CachedPreviewPayload, for url: URL) async {
        let sanitized = Self.sanitizedPreview(payload)
        let key = url.absoluteString
        let nsKey = key as NSString
        guard let encodedPayload = try? JSONEncoder().encode(sanitized) else { return }
        let storedAt = Date()
        let envelope = DiskEnvelope(storedAt: storedAt, bytes: encodedPayload)
        repopulatePreviewMemory(key: nsKey, envelope: envelope)
        guard let envelopeData = try? JSONEncoder().encode(envelope) else { return }
        let cacheFileURL = previewDir.appendingPathComponent(Self.previewFilename(for: key))
        try? envelopeData.write(to: cacheFileURL, options: .atomic)
        trimDiskIfNeeded()
    }

    /// Writes the same shape as disk (`DiskEnvelope`) so memory hits honor ``previewTTL``.
    private func repopulatePreviewMemory(key: NSString, storedAt: Date, sanitized: CachedPreviewPayload) {
        guard let encodedPayload = try? JSONEncoder().encode(sanitized) else { return }
        repopulatePreviewMemory(key: key, envelope: DiskEnvelope(storedAt: storedAt, bytes: encodedPayload))
    }

    private func repopulatePreviewMemory(key: NSString, envelope: DiskEnvelope) {
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        previewMemory.setObject(data as NSData, forKey: key)
    }

    private func loadFaviconFromDisk(fileKey: String) -> Data? {
        let fm = FileManager.default
        let blobURL = faviconDir.appendingPathComponent(Self.hexDigest(for: fileKey))

        if let raw = try? Data(contentsOf: blobURL), raw.count > Self.faviconHeaderLength {
            guard let storedAt = Self.decodeFaviconHeader(raw.prefix(Self.faviconHeaderLength)),
                  Date().timeIntervalSince(storedAt) <= faviconTTL
            else { return nil }
            let imageBytes = raw.dropFirst(Self.faviconHeaderLength)
            guard let valid = Self.validImageData(Data(imageBytes)) else { return nil }
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: blobURL.path)
            repopulateFaviconMemory(key: fileKey as NSString, storedAt: storedAt, imageData: valid)
            return valid
        }

        return loadLegacyFaviconDiskEnvelope(fileKey: fileKey)
    }

    /// Older builds wrote JSON ``DiskEnvelope`` as `*.cache`; still honored until rewritten by ``storeFavicon``.
    private func loadLegacyFaviconDiskEnvelope(fileKey: String) -> Data? {
        let fm = FileManager.default
        let url = faviconDir.appendingPathComponent(Self.legacyFaviconFilename(for: fileKey))
        guard let raw = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: raw),
              Date().timeIntervalSince(envelope.storedAt) <= faviconTTL,
              let imageData = Self.validImageData(envelope.bytes)
        else { return nil }

        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        repopulateFaviconMemory(key: fileKey as NSString, storedAt: envelope.storedAt, imageData: imageData)
        return imageData
    }

    private func repopulateFaviconMemory(key: NSString, storedAt: Date, imageData: Data) {
        var prefixed = Data(count: Self.faviconHeaderLength + imageData.count)
        prefixed.replaceSubrange(..<Self.faviconHeaderLength, with: Self.encodeFaviconHeader(storedAt: storedAt))
        prefixed.replaceSubrange(Self.faviconHeaderLength..<prefixed.endIndex, with: imageData)
        faviconMemory.setObject(prefixed as NSData, forKey: key)
    }

    nonisolated private static func decodeFaviconMemoryBlob(_ data: Data) -> (storedAt: Date, imageData: Data)? {
        guard data.count > faviconHeaderLength,
              let storedAt = decodeFaviconHeader(data.prefix(faviconHeaderLength)),
              storedAt <= Date().addingTimeInterval(120)
        else { return nil }
        let image = data.dropFirst(faviconHeaderLength)
        return (storedAt, Data(image))
    }

    private func loadPreviewFile(key: String) -> Data? {
        let fm = FileManager.default
        let url = previewDir.appendingPathComponent(Self.previewFilename(for: key))
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(DiskEnvelope.self, from: data),
              Date().timeIntervalSince(envelope.storedAt) <= previewTTL
        else { return nil }

        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return data
    }

    private func trimDiskIfNeeded() {
        Self.trimDirectories([faviconDir, previewDir], maxBytes: maxDiskBytes)
    }

    nonisolated private static func hexDigest(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func legacyFaviconFilename(for key: String) -> String {
        hexDigest(for: key) + ".cache"
    }

    nonisolated private static func previewFilename(for key: String) -> String {
        hexDigest(for: key) + ".cache"
    }

    nonisolated private static func encodeFaviconHeader(storedAt: Date = Date()) -> Data {
        let t = UInt64(storedAt.timeIntervalSince1970)
        var out = [UInt8]()
        out.reserveCapacity(faviconHeaderLength)
        for shift in stride(from: 56, through: 0, by: -8) {
            out.append(UInt8((t >> UInt64(shift)) & 0xFF))
        }
        return Data(out)
    }

    nonisolated private static func decodeFaviconHeader(_ prefix: Data.SubSequence) -> Date? {
        guard prefix.count >= faviconHeaderLength else { return nil }
        var t: UInt64 = 0
        for b in prefix.prefix(faviconHeaderLength) {
            t = (t << 8) | UInt64(b)
        }
        return Date(timeIntervalSince1970: TimeInterval(t))
    }

    nonisolated private static func validImageData(_ data: Data) -> Data? {
        guard NSImage(data: data) != nil else { return nil }
        return data
    }

    nonisolated private static func sanitizedPreview(_ payload: CachedPreviewPayload) -> CachedPreviewPayload {
        let fav = payload.faviconData.flatMap { validImageData($0) }
        return CachedPreviewPayload(title: payload.title, siteName: payload.siteName, faviconData: fav)
    }

    nonisolated private static func trimDirectories(_ dirs: [URL], maxBytes: Int) {
        let fm = FileManager.default
        var entries: [(url: URL, date: Date, size: Int)] = []
        var total = 0

        for dir in dirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in names {
                let url = dir.appendingPathComponent(name)
                guard let vals = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                      let date = vals.contentModificationDate,
                      let size = vals.fileSize
                else { continue }
                entries.append((url, date, size))
                total += size
            }
        }

        guard total > maxBytes else { return }
        entries.sort { $0.date < $1.date }

        var remaining = total
        for entry in entries {
            guard remaining > maxBytes else { break }
            try? fm.removeItem(at: entry.url)
            remaining -= entry.size
        }
    }
}
