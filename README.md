# Junction

Route every link you click to the right browser, profile, or private window.

Junction lives in the macOS menu bar. Click a link anywhere — email, Slack, Notion — and Junction shows a picker: pick a browser, or set a rule so the same host always opens in the same place.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Install

Download the latest release: [Releases page](https://github.com/TheTobiGit/junction/releases/latest)

```
Junction-<version>-macos.zip      Junction.app
junction-cli-<version>-macos.zip  junction CLI
```

Unzip `Junction.app` to `/Applications`, open it once, follow the onboarding to make Junction the default browser. The CLI is optional — drop `junction` into `/usr/local/bin/` if you want it.

Builds are ad-hoc signed. The first launch may need a right-click → Open to bypass Gatekeeper.

## Use

Once Junction is the default browser, every link opens its picker. Keys:

| Key | Action |
|---|---|
| `1`–`9` | Open in that browser |
| `↵` | Open in highlighted browser |
| `⌥` (hold) | Switch to private/incognito |
| `␣` | Preview the URL |
| `⌘C` | Copy the (cleaned) URL |
| `esc` | Cancel |

Add a rule once and Junction will skip the picker for that host:

```
junction rules add github.com --in profile:com.google.Chrome:Default
junction rules add slack.com  --scheme slack
junction rules add reddit.com --block
```

`junction --help` lists every command.

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
