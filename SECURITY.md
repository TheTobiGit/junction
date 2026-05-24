# Security Policy

## Supported Versions

Junction is distributed as signed, notarized macOS releases. Security fixes are
applied to the latest released version only. Older versions do not receive
backports.

## Reporting a Vulnerability

Please report security issues privately. Do **not** open a public GitHub issue
for anything you suspect is exploitable.

- Preferred: use GitHub's private vulnerability reporting at
  <https://github.com/TheTobiGit/junction/security/advisories/new>.
- Alternative: email **aemonsarfo@outlook.com** with the subject line
  `[junction] security report`.

When reporting, include:

- A description of the issue and the impact you believe it has.
- Steps to reproduce, or a minimal proof of concept.
- The Junction version (`Junction.app` > Preferences > About) and macOS version.
- Whether you intend to disclose publicly, and on what timeline.

You can expect:

- An acknowledgement within 3 business days.
- A triage decision (accepted / needs more info / not a vulnerability) within
  7 business days.
- A fix or mitigation plan for accepted reports, with a target release window.

## Scope

In scope:

- The `Junction.app` macOS application and the `junction` CLI.
- The local agent protocol used between `junction` and `Junction.app`.
- Build, signing, and release tooling under `scripts/` and
  `.github/workflows/`.

Out of scope:

- Third-party browsers Junction launches. Report those to their vendors.
- Issues that require a pre-compromised local account or physical access.
- Self-XSS or social-engineering scenarios with no code path in this repo.

## Disclosure

Coordinated disclosure is preferred. Once a fix ships in a tagged release,
the corresponding GitHub Security Advisory will be published with credit to
the reporter (unless anonymity is requested).
