#!/usr/bin/env bash
# One-shot setup for contributors after cloning.
# Activates the repo's tracked git hooks (`.githooks/`).
#
# Run once per clone:
#     ./scripts/setup.sh
#
# Idempotent — safe to run again.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Use git itself to verify the location — `.git` may be a file (worktrees,
# submodules) rather than a directory, so `[ -d .git ]` is wrong.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "✖ Not inside a git working tree (cwd: $REPO_ROOT)" >&2
  exit 1
fi

if [ ! -d .githooks ]; then
  echo "✖ .githooks/ directory missing — repo state is broken" >&2
  exit 1
fi

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

echo "✓ Git hooks activated (core.hooksPath = .githooks)"
echo "  Conventional Commits now enforced on every git commit."
echo "  Bypass an individual commit with: git commit --no-verify"
