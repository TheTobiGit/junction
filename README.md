# Junction

Route every link you click to the right browser, profile, or private window.

Junction lives in the macOS menu bar. Click a link anywhere — email, Slack, Notion — and Junction shows a picker: pick a browser, or set a rule so the same host always opens in the same place.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Install

Download the latest release: [Releases page](https://github.com/TheTobiGit/junction/releases/latest)

```
Junction-<version>.dmg            Junction.app, drag-to-install
Junction-<version>-macos.zip      Junction.app, zipped
junction-cli-<version>-macos.zip  junction CLI
```

Open the DMG and drag `Junction.app` into `Applications`, or unzip the `.app` directly. Open it once and follow the onboarding to make Junction the default browser. The CLI is optional — drop `junction` into `/usr/local/bin/` if you want it.

Releases are signed with a Developer ID certificate and notarized by Apple, so Gatekeeper opens them without prompting.

## Use

Once Junction is the default browser, every link opens its picker. Keys:

| Key | Action |
|---|---|
| `1`–`9` | Open in that browser |
| `↵` | Open in highlighted browser |
| `⌥` (hold) | Switch to private/incognito |
| `␣` | Preview the URL |
| `⌘C` | Copy the (cleaned) URL |
| `?` | Show the keyboard cheat sheet |
| `esc` | Cancel |

Pin a browser to slot 1 from the Targets tab or right-click a picker tile. The picker remembers its size and position between sessions. The footer overflow has a Send to phone action that renders the cleaned URL as a QR code.

Browsers with multiple profiles or spaces (Chrome, Brave, Edge, Arc) collapse into a single tile that expands to show the profiles.

### Rules

Add a rule once and Junction skips the picker for that host:

```
junction rules add github.com --in profile:com.google.Chrome:Default
junction rules add slack.com  --scheme slack
junction rules add reddit.com --block
```

Rules can match more than just the host. The `--path-prefix`, `--path-contains`, `--path-regex`, and `--path-glob` flags scope a rule to a path pattern. Repeat `--from <bundleID>` to limit the rule to specific source apps, e.g. only fire when the link comes from Slack. The same options live in the Add Rule sheet.

The Rules tab flags any rule shadowed by an earlier first-match-wins entry. Every Activity row has a Promote button that opens the Add Rule sheet pre-filled with the host and target.

`junction --help` lists every command.

### URL handling

Junction strips trackers (`utm_*`, `fbclid`, …) from URLs before opening them. Preferences > Trackers lets you add custom params and disable built-in defaults; rules can override the tracker list per-host. Shortener expansion is cached per session.

The picker flags Punycode and mixed-script hosts as a homograph warning. Press `␣` for a preview, then toggle Reader mode to render the page through Mozilla Readability.

### Activity

The History tab logs recent routes. Search the list and promote any entry to a rule from the row actions.

## Build from source

Requires Xcode 15+ on macOS 13+.

```
git clone https://github.com/TheTobiGit/junction
cd junction
./scripts/setup.sh          # activates commit hooks — run once per clone
./build-app.sh release
open build/Junction.app
```

> **Why `scripts/setup.sh`?** Junction enforces Conventional Commits via a tracked git hook (`.githooks/commit-msg`). The setup script points `core.hooksPath` at it. Skipping this step means your commits won't be validated locally and release-please may reject them.

Local builds are ad-hoc signed by default. macOS may prompt the first time you run a hand-built `Junction.app` — right-click → Open to bypass Gatekeeper. Set `JUNCTION_CODESIGN_IDENTITY` to a Developer ID certificate in your keychain to produce a fully signed local build.

## Contributing

Issues and pull requests are welcome. A few ground rules:

- Commits must follow [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `chore:`…). The `commit-msg` hook installed by `scripts/setup.sh` enforces this.
- Open an issue first for non-trivial changes so we can agree on the approach before you spend time on a PR.
- Keep PRs focused. Mixing unrelated refactors and features makes review slow.
- The codebase has zero third-party Swift dependencies and the project intends to keep it that way.

## Security

Found something exploitable? Don't open a public issue — see [SECURITY.md](./SECURITY.md) for the private disclosure process.

## License

MIT. See [LICENSE](./LICENSE).
