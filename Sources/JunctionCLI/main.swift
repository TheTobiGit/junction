import Foundation
import Darwin
import JunctionCore

struct CLIError: Error {
    let message: String
}

enum JunctionCLI {
    static func run() -> Int32 {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            return 1
        }

        let command = args[1]
        let rest = Array(args.dropFirst(2))

        do {
            switch command {
            case "open":
                try handleOpen(rest)
            case "rules":
                try handleRules(rest)
            case "targets":
                try handleTargets()
            case "ping":
                try handlePing()
            case "help", "--help", "-h":
                printUsage()
            default:
                FileHandle.standardError.write(Data("unknown command: \(command)\n\n".utf8))
                printUsage()
                return 1
            }
            return 0
        } catch let err as CLIError {
            FileHandle.standardError.write(Data("error: \(err.message)\n".utf8))
            return 1
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    private static func handleOpen(_ args: [String]) throws {
        var urls: [String] = []
        var target: String? = nil
        var ask = false
        var clean: Bool? = nil

        var i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "--in":
                guard i + 1 < args.count else { throw CLIError(message: "--in requires a value") }
                target = args[i + 1]; i += 2
            case "--ask":
                ask = true; i += 1
            case "--clean":
                clean = true; i += 1
            case "--no-clean":
                clean = false; i += 1
            default:
                urls.append(a); i += 1
            }
        }

        guard !urls.isEmpty else {
            throw CLIError(message: "missing URL (usage: junction open <url> [--in <target>] [--ask])")
        }

        for url in urls {
            let response = try sendRequest(.open(url: url, inTarget: target, ask: ask, clean: clean))
            switch response {
            case .ok: break
            case .error(let m): throw CLIError(message: m)
            default: throw CLIError(message: "unexpected response")
            }
        }
    }

    private static func handleRules(_ args: [String]) throws {
        let sub = args.first ?? "list"
        let rest = Array(args.dropFirst())
        switch sub {
        case "list":
            let response = try sendRequest(.listRules)
            guard case .rules(let list) = response else {
                throw CLIError(message: "unexpected response")
            }
            if list.isEmpty {
                print("no rules")
                return
            }
            for rule in list {
                print("\(rule.hostKind.padded(8)) \(rule.hostValue.padded(32))  →  \(rule.action)")
            }
        case "add":
            try handleRulesAdd(rest)
        case "remove", "rm":
            try handleRulesRemove(rest)
        default:
            throw CLIError(message: "unknown rules subcommand: \(sub)")
        }
    }

    private static func handleRulesAdd(_ args: [String]) throws {
        var hostKind: String = "suffix"
        var hostValue: String? = nil
        var target: String? = nil
        var ask = false

        var i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "--equals": hostKind = "equals"; i += 1
            case "--suffix": hostKind = "suffix"; i += 1
            case "--regex": hostKind = "regex"; i += 1
            case "--in":
                guard i + 1 < args.count else { throw CLIError(message: "--in requires a value") }
                target = args[i + 1]; i += 2
            case "--ask":
                ask = true; i += 1
            default:
                if hostValue == nil { hostValue = a } else {
                    throw CLIError(message: "unexpected argument: \(a)")
                }
                i += 1
            }
        }

        guard let value = hostValue else {
            throw CLIError(message: "missing host (usage: junction rules add <host> [--suffix|--equals|--regex] [--in <target>|--ask])")
        }
        if !ask && target == nil {
            throw CLIError(message: "either --in <target> or --ask is required")
        }

        let response = try sendRequest(.addRule(hostKind: hostKind, hostValue: value, target: ask ? nil : target))
        switch response {
        case .ok(let m): if let m { print(m) }
        case .error(let m): throw CLIError(message: m)
        default: throw CLIError(message: "unexpected response")
        }
    }

    private static func handleRulesRemove(_ args: [String]) throws {
        guard let value = args.first else {
            throw CLIError(message: "missing host (usage: junction rules remove <host>)")
        }
        let response = try sendRequest(.removeRule(hostValue: value))
        switch response {
        case .ok(let m): if let m { print(m) }
        case .error(let m): throw CLIError(message: m)
        default: throw CLIError(message: "unexpected response")
        }
    }

    private static func handleTargets() throws {
        let response = try sendRequest(.listTargets)
        guard case .targets(let list) = response else {
            throw CLIError(message: "unexpected response")
        }
        for t in list {
            print("\(t.key.padded(48))  \(t.displayName)")
        }
    }

    private static func handlePing() throws {
        let response = try sendRequest(.ping)
        guard case .pong = response else {
            throw CLIError(message: "no pong")
        }
        print("pong")
    }

    private static func sendRequest(_ request: AgentRequest) throws -> AgentResponse {
        let socketPath = AgentConstants.socketURL.path

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw CLIError(message: "socket() failed") }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
        guard socketPath.utf8.count <= maxLen else {
            throw CLIError(message: "socket path too long")
        }
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: maxLen + 1) { cptr in
                _ = socketPath.withCString { src in strncpy(cptr, src, maxLen) }
            }
        }

        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, addrLen)
            }
        }
        guard result == 0 else {
            throw CLIError(message: "Junction is not running (connect failed). Start the app first.")
        }

        let data = try AgentCodec.encode(request)
        _ = data.withUnsafeBytes { raw in
            write(fd, raw.baseAddress, data.count)
        }

        var buffer = Data()
        var readBuf = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &readBuf, readBuf.count)
            if n <= 0 { break }
            buffer.append(contentsOf: readBuf.prefix(n))
            if buffer.contains(0x0A) { break }
        }

        guard let nl = buffer.firstIndex(of: 0x0A) else {
            throw CLIError(message: "no response from agent")
        }
        let line = buffer.subdata(in: buffer.startIndex..<nl)
        return try AgentCodec.decode(AgentResponse.self, from: line)
    }

    private static func printUsage() {
        let text = """
        junction — route links to the right browser

        usage:
          junction open <url> [--in <target>] [--ask] [--clean|--no-clean]
          junction rules list
          junction rules add <host> [--suffix|--equals|--regex] [--in <target>|--ask]
          junction rules remove <host>
          junction targets
          junction ping

        examples:
          junction open https://github.com
          junction open https://example.com --in app:com.google.Chrome
          junction rules add github.com --in profile:com.google.Chrome:Default
          junction rules add "^.*slack\\.com" --regex --ask
          junction rules remove github.com
          junction targets   # list known target keys

        """
        print(text)
    }
}

private extension String {
    func padded(_ width: Int) -> String {
        if count >= width { return self }
        return self + String(repeating: " ", count: width - count)
    }
}

exit(JunctionCLI.run())
