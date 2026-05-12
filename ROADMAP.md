# Junction — Build Roadmap

## What this is

Junction is a macOS menu-bar app that sits between a link click and the browser. When anything on the system opens an `http(s)` URL — Terminal, Slack, Mail, a command, a Shortcut — Junction registers as the default handler, catches the URL, and shows a floating picker so you can choose which browser (and which profile or Arc Space) actually opens it.

It also does a few things beyond "just pick a browser":

- Rules engine at `~/.config/junction/rules.json` that routes by host, source app, or Focus mode — with hot-reload.
- URL hygiene pipeline: strip tracking params, collapse AMP, expand short URLs, rewrite to redirects (Nitter, old.reddit, archive.today, …).
- Safe-link checks: Punycode / mixed-script / suspicious-TLD flags before you click through.
- First-class profile & Space support for Chrome / Edge / Brave / Arc, each with its real color.
- A `junction` CLI and `junction://` URL scheme so Shortcuts, Raycast, Alfred, and scripts can drive it.
- History log, "save for later" inbox, batch paste-and-route, clipboard HUD, importable rule recipes.

Built in Swift + SwiftUI on SwiftPM, no Xcode project. Targets macOS 13+. The app runs as `LSUIElement` (no dock icon) and registers itself as an alternate http/https handler via LaunchServices.

## Layout

- `Sources/JunctionCore` — shared protocol types (agent request/response).
- `Sources/Junction` — the app itself (picker, rules, transforms, agent server, UI).
- `Sources/JunctionCLI` — the `junction` binary that talks to the app over a Unix socket.
- `Resources/Info.plist` — URL handler registration, LSUIElement flag.
- `build-app.sh` — builds both targets, bundles the `.app`, ad-hoc codesigns, optionally registers as default and installs the CLI.

---

Sequenced checklist. Each phase only needs the one above it, so we can't skip rungs without backtracking.

---

## Phase 1 — URL transform pipeline
*No dependencies.*

- [x] `URLTransformer` protocol + pipeline runner
- [x] Tracker stripper (`utm_*`, `fbclid`, `gclid`, `yclid`, `mc_eid`, `igshid`, `ref`, `ref_src`)
- [x] Show cleaned URL under original in the picker
- [x] "Copy cleaned link" action (⌘C in picker)
- [x] Toggle in Preferences: "Clean URLs before opening"

Unlocks: everything that talks about URL rewriting, copy-cleaned, and safe-link.

---

## Phase 2 — Profiles & Spaces as first-class targets
*Needs Phase 1 shape for the "Target" abstraction, not the trackers themselves.*

- [x] Introduce a `LaunchTarget` type: `.app(bundleID)` or `.profile(bundleID, profileID, label, color)`
- [x] Chrome / Edge / Brave profile detection (read `~/Library/Application Support/<vendor>/Local State` JSON)
- [x] Arc Spaces detection (read Arc's sidebar state JSON)
- [x] Launch-with-profile via `--profile-directory` (Chromium) / URL scheme (Arc)
- [x] Picker rows show each profile / space individually with its color dot
- [x] `RulesStore` stores `LaunchTarget`, not just bundle ID (migration step)

Unlocks: accurate routing for the way you actually use browsers, and everything downstream that routes to a specific profile.

---

## Phase 3 — Rules engine upgrade
*Needs Phase 2's `LaunchTarget`.*

- [x] Rule matching by host pattern (exact, suffix, regex)
- [x] Rule priority order
- [x] YAML / JSON rules file at `~/.config/junction/rules.json` with schema
- [x] "Open rules file" menu item + live-reload via `FSEventStream`
- [x] Fallback target + "Always ask" override

Unlocks: config-as-code, and later the natural-language rule builder (it just emits this schema).

---

## Phase 4 — CLI + local agent
*Needs stable rules + profile launch.*

- [x] `junction` binary (separate SwiftPM executable target in the same package)
- [x] Unix socket at `~/Library/Application Support/Junction/agent.sock`
- [x] `junction open <url> [--in <target>] [--ask] [--clean]`
- [x] `junction rules list`
- [x] `junction rules add|remove`
- [x] `junction://` URL scheme for Shortcuts / Raycast / Alfred (`junction://open?url=...&target=...&ask=1`)

Unlocks: every automation idea (batch mode, scripts, AI agents, iPhone companion).

---

## Phase 5 — Context-aware signals
*Orthogonal, but needs the rules engine to consume them.*

- [x] Capture frontmost app at the moment of URL arrival (`NSWorkspace.frontmostApplication`)
- [x] Capture current Focus mode (`NSWorkspace` Focus notifications)
- [x] Extend rule conditions: `when.sourceApp`, `when.focus`
- [x] Show "from Slack" badge in the picker

Unlocks: per-source routing, focus-aware defaults, meeting / workflow intelligence.

---

## Phase 6 — URL rewriting content
*Needs Phase 1 pipeline.*

- [x] Short-URL expander (HEAD-follow for `t.co`, `bit.ly`, `lnkd.in`, etc., with 2s timeout)
- [x] Redirect rules: Twitter → Nitter, Reddit → old.reddit, Medium → freedium, AMP → canonical, paywalls → archive.today
- [x] User-editable redirect list in Preferences

---

## Phase 7 — Safe link mode
*Needs Phase 6 short-URL expander.*

- [x] IDN homoglyph / Punycode warning
- [ ] Newly-registered-domain hint (optional, via WHOIS API, opt-in)
- [x] Shortened-URL preview showing the final destination before open
- [x] Risk flags shown inline in the picker header

---

## Phase 8 — Picker polish & power actions
*Needs Phases 1, 2, 6.*

- [ ] OpenGraph preview card (title, favicon, canonical URL)
- [x] Undo-via-notification after open ("Switch to Arc?")
- [ ] Side-by-side multi-open (select two targets with ⇧-click, opens both)
- [x] Batch mode window: paste a list of URLs, route each row
- [x] "Always use this for domain" without the remember toggle — one-key shortcut (⌘↵)

---

## Phase 9 — History & queue
*Needs Phase 5 signals.*

- [x] Link log (JSONL): timestamp, source app, URL, chosen target
- [x] Searchable history window ("link genealogy")
- [x] Link inbox / "open later" bucket grouped by source app
- [ ] Reader-first routing toggle (render article in a native window)

---

## Phase 10 — External integrations
*Needs Phase 4 agent.*

- [x] Clipboard watcher with opt-in HUD
- [ ] iPhone companion Shortcut that pushes links to the Mac agent over local network
- [x] Rules marketplace: importable recipe packs (Developer, Designer, Privacy, Meetings)
- [ ] Natural-language rule builder (LLM → Phase 3 schema)
