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
            case "inspect":
                try handleInspect(rest)
            case "history":
                try handleHistory(rest)
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
                let suffix: String
                switch rule.cleanOverride {
                case .none:        suffix = ""
                case .some(true):  suffix = "  [clean: always]"
                case .some(false): suffix = "  [clean: never]"
                }
                print("\(rule.hostKind.padded(8)) \(rule.hostValue.padded(32))  →  \(rule.action)\(suffix)")
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
        var block = false
        var incognitoTarget: String? = nil
        var scheme: String? = nil
        var cleanOverride: Bool? = nil

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
            case "--incognito":
                guard i + 1 < args.count else { throw CLIError(message: "--incognito requires a target key") }
                incognitoTarget = args[i + 1]; i += 2
            case "--scheme":
                guard i + 1 < args.count else { throw CLIError(message: "--scheme requires a scheme name") }
                scheme = args[i + 1]; i += 2
            case "--block":
                block = true; i += 1
            case "--ask":
                ask = true; i += 1
            case "--clean":
                cleanOverride = true; i += 1
            case "--no-clean":
                cleanOverride = false; i += 1
            default:
                if hostValue == nil { hostValue = a } else {
                    throw CLIError(message: "unexpected argument: \(a)")
                }
                i += 1
            }
        }

        guard let value = hostValue else {
            throw CLIError(message: "missing host (usage: junction rules add <host> [--suffix|--equals|--regex] [--in <target>|--ask|--block|--incognito <target>|--scheme <name>] [--clean|--no-clean])")
        }

        let resolvedTarget: String?
        let chosen = [ask, block, incognitoTarget != nil, scheme != nil, target != nil].filter { $0 }.count
        guard chosen == 1 else {
            throw CLIError(message: "specify exactly one of --in, --ask, --block, --incognito, --scheme")
        }
        if ask {
            resolvedTarget = nil
        } else if block {
            resolvedTarget = "__block__"
        } else if let incognitoTarget {
            resolvedTarget = "incognito:\(incognitoTarget)"
        } else if let scheme {
            resolvedTarget = "scheme:\(scheme)"
        } else {
            resolvedTarget = target
        }

        let response = try sendRequest(.addRule(
            hostKind: hostKind,
            hostValue: value,
            target: resolvedTarget,
            cleanOverride: cleanOverride
        ))
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

    private static func handleInspect(_ args: [String]) throws {
        var jsonOutput = false
        var positional: [String] = []
        for a in args {
            switch a {
            case "--json": jsonOutput = true
            default: positional.append(a)
            }
        }
        guard let raw = positional.first else {
            throw CLIError(message: "missing URL (usage: junction inspect <url> [--json])")
        }
        var input = raw
        if !input.contains("://"), input.contains(".") {
            input = "https://" + input
        }
        let response = try sendRequest(.inspect(url: input))
        switch response {
        case .inspectResult(let result):
            if jsonOutput {
                printJSON(result)
                return
            }
            print("Original:  \(result.original)")
            print("Cleaned:   \(result.cleaned)")
            if !result.steps.isEmpty {
                print("")
                print("Pipeline:")
                for (idx, step) in result.steps.enumerated() {
                    print("  \(idx + 1). \(URLPipelineStepLabel.label(for: step.identifier))")
                    print("     → \(step.after)")
                }
            } else {
                print("")
                print("Pipeline: (no transformers fired)")
            }
            if !result.flags.isEmpty {
                print("")
                print("Risk flags:")
                for flag in result.flags {
                    print("  [\(flag.level)] \(flag.title)")
                    print("    \(flag.detail)")
                }
            }
            if !result.strippedTrackerParams.isEmpty {
                print("")
                print("Removed query parameters:")
                print("  " + result.strippedTrackerParams.joined(separator: ", "))
            }
        case .error(let m):
            throw CLIError(message: m)
        default:
            throw CLIError(message: "unexpected response")
        }
    }

    private static func handleHistory(_ args: [String]) throws {
        var limit = 20
        var jsonOutput = false
        var i = 0
        while i < args.count {
            let a = args[i]
            switch a {
            case "--limit", "-n":
                guard i + 1 < args.count, let n = Int(args[i + 1]), n > 0 else {
                    throw CLIError(message: "--limit requires a positive integer")
                }
                limit = n
                i += 2
            case "--json":
                jsonOutput = true
                i += 1
            default:
                throw CLIError(message: "unexpected argument: \(a)")
            }
        }
        let response = try sendRequest(.listHistory(limit: limit))
        switch response {
        case .history(let entries):
            if jsonOutput {
                printJSON(entries)
                return
            }
            if entries.isEmpty {
                print("(no recent activity)")
                return
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            for entry in entries {
                let when = formatter.string(from: entry.timestamp)
                let target = entry.targetBundleID ?? "—"
                let cleaned = entry.originalURL == entry.cleanedURL ? "" : " *cleaned*"
                print("\(when)  \(entry.outcome.padded(18))  \(target.padded(36))  \(entry.cleanedURL)\(cleaned)")
            }
        case .error(let m):
            throw CLIError(message: m)
        default:
            throw CLIError(message: "unexpected response")
        }
    }

    /// Pretty-prints an `Encodable` value as JSON to stdout, suitable for piping
    /// to `jq`. ISO8601 dates so the output is interoperable with anything else.
    private static func printJSON<T: Encodable>(_ value: T) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(value)
            if let s = String(data: data, encoding: .utf8) {
                print(s)
            }
        } catch {
            FileHandle.standardError.write(Data("error encoding JSON: \(error)\n".utf8))
        }
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
          junction rules add <host> [--suffix|--equals|--regex]
                            (--in <target> | --ask | --block
                             | --incognito <target> | --scheme <name>)
                            [--clean|--no-clean]
          junction rules remove <host>
          junction targets
          junction ping
          junction inspect <url> [--json]
          junction history [--limit N] [--json]

        examples:
          junction open https://github.com
          junction open https://example.com --in app:com.google.Chrome
          junction rules add github.com --in profile:com.google.Chrome:Default
          junction rules add "^.*slack\\.com" --regex --ask
          junction rules add reddit.com --block
          junction rules add twitter.com --incognito app:com.apple.Safari
          junction rules add slack.com --scheme slack
          junction rules add myinternal.example.com --in app:com.apple.Safari --no-clean
          junction rules remove github.com
          junction targets   # list known target keys
          junction inspect "https://l.facebook.com/l.php?u=https%3A%2F%2Fexample.com%3Futm_source%3Demail"
          junction history --limit 5

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
