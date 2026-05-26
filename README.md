# Junction

Route every link you click to the right browser, profile, or private window.

Junction lives in the macOS menu bar. Click a link anywhere and Junction shows a picker, or routes it automatically with a rule.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)

## Install

Download the latest [release](https://github.com/TheTobiGit/junction/releases/latest).

## Use

Once Junction is the default browser, every link opens its picker.

| Key | Action |
|---|---|
| `1`–`9` | Open in that browser |
| `↵` | Open highlighted |
| `⌥` (hold) | Private/incognito |
| `␣` | Preview URL |
| `⌘C` | Copy URL |
| `?` | Cheat sheet |
| `esc` | Cancel |

Add a rule to skip the picker for a host:

```
junction rules add github.com --in profile:com.google.Chrome:Default
```

`junction --help` lists every command.

## Build from source

Requires Xcode 15+ on macOS 13+.

```
git clone https://github.com/TheTobiGit/junction
cd junction
./scripts/setup.sh
./build-app.sh release
open build/Junction.app
```

`scripts/setup.sh` installs the commit-msg hook that enforces [Conventional Commits](https://www.conventionalcommits.org/).

## Contributing

Issues and PRs welcome. Open an issue first for non-trivial changes. Commits must follow Conventional Commits.

## Security

See [SECURITY.md](./SECURITY.md) for private disclosure.

## License

MIT. See [LICENSE](./LICENSE).
