#!/usr/bin/env bash
# Render one version's CHANGELOG section as standalone HTML for Sparkle.
#
# Usage:
#     ./scripts/changelog-to-html.sh <VERSION> [CHANGELOG_PATH]
#
# Example:
#     ./scripts/changelog-to-html.sh 0.12.0 > build/sparkle-feed/Junction-0.12.0-macos.html
#
# Prints HTML to stdout. Place the output next to the update archive as
# "<archive-basename>.html" so Sparkle's generate_appcast embeds it as the
# update <description>. The release-notes pane then renders instantly from the
# appcast instead of spinning while it loads the remote GitHub release page.

set -euo pipefail

VERSION="${1:?usage: changelog-to-html.sh <VERSION> [CHANGELOG_PATH]}"
CHANGELOG="${2:-CHANGELOG.md}"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "changelog-to-html: $CHANGELOG not found" >&2
  exit 1
fi

# Pull the lines under "## [<VERSION>] ..." up to the next "## [" header.
# index(...)==1 is a literal, start-anchored match so dotted versions are not
# treated as a regex.
section="$(
  awk -v ver="$VERSION" '
    index($0, "## [" ver "]") == 1 { capture = 1; next }
    capture && index($0, "## [") == 1 { exit }
    capture { print }
  ' "$CHANGELOG"
)"

# Never emit empty notes — fall back to a minimal blurb so the pane still fills.
if [[ -z "${section//[[:space:]]/}" ]]; then
  printf '<h2>Junction %s</h2>\n<p>See the full release notes for details.</p>\n' "$VERSION"
  exit 0
fi

printf '<h2>What'\''s new in %s</h2>\n' "$VERSION"

printf '%s\n' "$section" | awk '
  function esc(s) {
    gsub(/&/, "\\&amp;", s)
    gsub(/</, "\\&lt;", s)
    gsub(/>/, "\\&gt;", s)
    return s
  }
  function inline(s,   out, chunk, txt, url, inner) {
    out = esc(s)
    # [text](url) -> <a href="url">text</a>
    while (match(out, /\[[^]]+\]\([^)]+\)/)) {
      chunk = substr(out, RSTART, RLENGTH)
      txt = chunk; sub(/^\[/, "", txt); sub(/\].*$/, "", txt)
      url = chunk; sub(/^[^(]*\(/, "", url); sub(/\)$/, "", url)
      out = substr(out, 1, RSTART - 1) "<a href=\"" url "\">" txt "</a>" substr(out, RSTART + RLENGTH)
    }
    # **text** -> <strong>text</strong>
    while (match(out, /\*\*[^*]+\*\*/)) {
      chunk = substr(out, RSTART, RLENGTH)
      inner = substr(chunk, 3, length(chunk) - 4)
      out = substr(out, 1, RSTART - 1) "<strong>" inner "</strong>" substr(out, RSTART + RLENGTH)
    }
    return out
  }
  function closelist() { if (inlist) { print "</ul>"; inlist = 0 } }
  BEGIN { inlist = 0 }
  /^[[:space:]]*$/ { next }
  /^###[[:space:]]+/ {
    closelist()
    line = $0; sub(/^###[[:space:]]+/, "", line)
    print "<h3>" esc(line) "</h3>"
    next
  }
  /^[*-][[:space:]]+/ {
    if (!inlist) { print "<ul>"; inlist = 1 }
    line = $0; sub(/^[*-][[:space:]]+/, "", line)
    print "<li>" inline(line) "</li>"
    next
  }
  {
    closelist()
    print "<p>" inline($0) "</p>"
  }
  END { closelist() }
'
