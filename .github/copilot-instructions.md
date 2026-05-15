# Copilot Instructions — Junction

Read these before reviewing any PR. Apply them to every comment.

## Project

Junction is a macOS menu-bar app that routes URLs to the right browser/profile. SwiftUI + AppKit, Swift 5.9, macOS 13+. Two executables (`Junction.app`, `junction` CLI) + shared `JunctionCore`. Builds via SwiftPM (`build-app.sh release`). No third-party Swift dependencies — keep it that way.

## Architecture

- `Sources/Junction` — app entry point. Tiny.
- `Sources/JunctionApp` — SwiftUI views, AppKit glue, browser discovery, URL opening, settings. UI + behaviour live here.
- `Sources/JunctionCore` — types shared with CLI (agent protocol, etc.). No AppKit, no SwiftUI.
- `Sources/JunctionCLI` — `junction` binary. Talks to running `Junction.app` over local agent protocol.
- `Resources/Info.plist` — bundle metadata. `CFBundleShortVersionString` is rewritten in release CI; don't pin it in PRs.

## Coding standards

- Swift API Design Guidelines. Types `UpperCamel`, methods/properties `lowerCamel`, enums singular nouns.
- Prefer `struct` + value semantics. Use `final class` when reference identity matters.
- No force-unwraps (`!`) on optionals outside tests; prefer `guard let`, `if let`, `??`, or `assertionFailure` with a message.
- No `try!` outside tests. No `as!` unless the cast is provably safe and commented.
- `@MainActor` on anything that touches AppKit/SwiftUI from async contexts.
- Use `Logger` (os.log) or stderr `FileHandle`, not `print`, in shipping code.
- Pin SwiftUI views' frame sizes only when AppKit hosting needs it.

## Security (flag these)

- Any new `Process` / `NSAppleScript` / `osascript` invocation must escape user-controlled input. URL strings → `appleScriptString(...)` helper.
- No shell concatenation of `URL.absoluteString` into bash. Use `arguments:` arrays.
- Don't widen `Info.plist` URL scheme handlers or entitlements without justification.
- New network calls: HTTPS only. No credentials in URLs or query strings.
- File reads outside the app sandbox/container: read-only, fail closed.

## Performance

- Picker must stay responsive: keep `body` cheap, avoid `GeometryReader` chains, prefer `@StateObject` over `@ObservedObject` for owned models.
- Favicon / preview fetches: cache, debounce, never block the main actor.
- Cold launch budget: under 250ms before menu bar icon is interactive. Flag work in `AppDelegate.applicationDidFinishLaunching` that exceeds this.

## URL routing rules

- New browser additions go in `BrowserDiscovery.knownBrowserBundleIDs` (sorted).
- New Chromium-family browsers also need entries in `ChromiumProfileDiscovery.vendors`.
- Skip nested `.app` bundles via `isNestedHelperApp(url:)` — don't reintroduce duplicates.

## Testing

- Tests live in `Tests/JunctionTests`, XCTest only.
- Pure logic (URL parsing, rules matching, browser dedup) must have unit tests. UI views are exempt.
- New `LaunchOption`/`Browser` discovery code needs a snapshot test in `ChromiumVendorSnapshotTests` if applicable.

## CI / release hygiene

- Workflows are in `.github/workflows/`. SHA-pin every third-party action. Reject PRs that downgrade to tag refs (`@v4`).
- Don't add `pull_request_target`. Don't interpolate `${{ github.event.* }}` into `run:` blocks — pass through `env:` instead.
- Commit messages must follow Conventional Commits (enforced by `.githooks/commit-msg`). Release-please reads them.

## Review style

- Be specific. Cite file paths and line numbers. Quote the offending snippet.
- Distinguish blocking issues (security, crash, correctness) from suggestions (style, naming, minor refactor). Label them.
- Skip nitpicks already handled by SwiftFormat or compiler warnings.
- Don't recommend dependencies. Don't propose npm/Node/Homebrew tooling. Don't propose `print` for logging.
- If a PR adds files outside `Sources/`, `Tests/`, `Resources/`, `.github/`, `scripts/`, `.githooks/`, ask why.
