import Foundation

// MARK: - Protocol

/// Abstraction over browser process launching.
/// Inject a conforming mock in tests to avoid spawning real processes.
protocol BrowserLaunching {
    func launch(
        appURL: URL,
        profileDirectory: String?,
        incognito: Bool,
        url: URL,
        completion: @escaping (Bool) -> Void
    )
}

// MARK: - Default implementation

/// Resolves the Mach-O executable inside a `.app` bundle and launches it via
/// `Foundation.Process`. The launch method returns synchronously; the process
/// runs on a background queue and the completion is always delivered on the
/// main queue.
struct BrowserLauncher: BrowserLaunching {

    // MARK: Executable resolution

    /// Reads `Contents/Info.plist` → `CFBundleExecutable` and returns the
    /// absolute URL of the Mach-O binary at `Contents/MacOS/<exec>`.
    ///
    /// Returns `nil` — never throws — when:
    /// - `Contents/Info.plist` is absent or unreadable
    /// - `CFBundleExecutable` key is missing or empty
    /// - The resolved binary path does not exist on disk
    static func resolveExecutable(for appURL: URL) -> URL? {
        let plistURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Info.plist")
        guard
            let plist = NSDictionary(contentsOf: plistURL),
            let execName = plist["CFBundleExecutable"] as? String,
            !execName.isEmpty
        else { return nil }

        let execURL = appURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent(execName)
        guard FileManager.default.fileExists(atPath: execURL.path) else {
            return nil
        }
        return execURL
    }

    // MARK: Argument assembly

    /// Assembles the Chromium-style argument array for a browser launch.
    ///
    /// Argument order:
    /// 1. `--profile-directory=<dir>` (omitted when `profileDirectory` is nil;
    ///    directory names containing spaces are preserved as a single element)
    /// 2. `--incognito` (omitted when `incognito` is false)
    /// 3. The URL string
    ///
    /// - Parameters:
    ///   - profileDirectory: Optional Chromium profile directory name.
    ///   - incognito: Whether to append `--incognito`.
    ///   - url: The URL to open.
    /// - Returns: Ordered `[String]` ready to assign to `Process.arguments`.
    static func arguments(
        profileDirectory: String?,
        incognito: Bool,
        url: URL
    ) -> [String] {
        var args: [String] = []
        if let dir = profileDirectory {
            args.append("--profile-directory=\(dir)")
        }
        if incognito {
            args.append("--incognito")
        }
        args.append(url.absoluteString)
        return args
    }

    // MARK: Launch

    /// Launches the browser executable via `Foundation.Process` on a
    /// background queue. Returns synchronously so the caller is never blocked.
    ///
    /// - Parameters:
    ///   - appURL: The `.app` bundle URL.
    ///   - profileDirectory: Optional Chromium profile directory name.
    ///   - incognito: Whether to pass `--incognito`.
    ///   - url: The URL to open.
    ///   - completion: Invoked on the **main queue** with `true` when the
    ///     process was launched successfully, or `false` when the executable
    ///     cannot be resolved or `Process.run()` throws.
    func launch(
        appURL: URL,
        profileDirectory: String?,
        incognito: Bool,
        url: URL,
        completion: @escaping (Bool) -> Void
    ) {
        let args = BrowserLauncher.arguments(
            profileDirectory: profileDirectory,
            incognito: incognito,
            url: url
        )
        BrowserLauncher.run(appURL: appURL, arguments: args, completion: completion)
    }

    /// Spawns the Mach-O binary inside `appURL` with `arguments` on a background
    /// queue. `completion` is always delivered on the main queue.
    static func run(
        appURL: URL,
        arguments: [String],
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let execURL = resolveExecutable(for: appURL) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            let process = Process()
            process.executableURL = execURL
            process.arguments = arguments
            do {
                try process.run()
                DispatchQueue.main.async { completion(true) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
}
