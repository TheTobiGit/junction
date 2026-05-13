import Foundation
import Darwin
import JunctionCore

final class AgentServer {
    static let shared = AgentServer()

    private let queue = DispatchQueue(label: "dev.gideonsarfo.Junction.agent", qos: .userInitiated)
    private var listeningSocket: Int32 = -1
    private var listenSource: DispatchSourceRead?

    var onRequest: ((AgentRequest) -> AgentResponse)?

    private init() {}

    func start() {
        queue.async { [weak self] in self?.startOnQueue() }
    }

    private func startOnQueue() {
        let socketURL = AgentConstants.socketURL
        let dir = socketURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: socketURL)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            NSLog("Junction agent: socket() failed")
            return
        }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socketURL.path
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
        guard path.utf8.count <= maxLen else {
            NSLog("Junction agent: socket path too long")
            close(fd)
            return
        }

        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: maxLen + 1) { cptr in
                _ = path.withCString { src in
                    strncpy(cptr, src, maxLen)
                }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(fd, sockaddrPtr, addrLen)
            }
        }
        guard bindResult == 0 else {
            NSLog("Junction agent: bind failed: \(errno)")
            close(fd)
            return
        }
        _ = chmod(path, 0o600)

        guard listen(fd, 16) == 0 else {
            NSLog("Junction agent: listen failed: \(errno)")
            close(fd)
            return
        }

        listeningSocket = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.setCancelHandler { close(fd) }
        source.resume()
        listenSource = source

        NSLog("Junction agent listening at \(path)")
    }

    private func acceptConnection() {
        var clientAddr = sockaddr()
        var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
        let client = accept(listeningSocket, &clientAddr, &addrLen)
        guard client >= 0 else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.handleClient(fd: client)
        }
    }

    private func handleClient(fd: Int32) {
        defer { close(fd) }

        var buffer = Data()
        var readBuf = [UInt8](repeating: 0, count: 4096)

        while true {
            let n = read(fd, &readBuf, readBuf.count)
            if n <= 0 { return }
            buffer.append(contentsOf: readBuf.prefix(n))

            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)

                let response: AgentResponse
                do {
                    let request = try AgentCodec.decode(AgentRequest.self, from: line)
                    response = self.onRequest?(request) ?? .error("no handler")
                } catch {
                    response = .error("decode failed: \(error.localizedDescription)")
                }

                if let data = try? AgentCodec.encode(response) {
                    _ = data.withUnsafeBytes { raw in
                        write(fd, raw.baseAddress, data.count)
                    }
                }
            }
        }
    }

    func stop() {
        listenSource?.cancel()
        listenSource = nil
        try? FileManager.default.removeItem(at: AgentConstants.socketURL)
    }
}
