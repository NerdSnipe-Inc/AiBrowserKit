#!/usr/bin/env bash
# Fail if the repo attributes Cursor / cursoragent as a contributor.
# Scans tracked files and commit messages on main.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SELF="scripts/check-no-cursor-attribution.sh"
failed=0

fail() {
  echo "check-no-cursor-attribution: $1" >&2
  failed=1
}

if git ls-files -- '.cursor' '.cursor/**' | grep -q .; then
  fail "'.cursor/' must not be tracked in this repository"
fi

if git grep -n -i -E 'cursoragent@cursor\.com|Co-authored-by:[[:space:]]*Cursor|Cursor Agent' -- . ":!${SELF}" >/tmp/aibrowser-cursor-grep.txt 2>/dev/null; then
  fail "forbidden attribution found in tracked files:"
  cat /tmp/aibrowser-cursor-grep.txt >&2
fi

if git log main --format='%B' | rg -i -q 'cursoragent|Co-authored-by:[[:space:]]*Cursor'; then
  fail "forbidden attribution found in git commit messages on main"
fi

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi

echo "check-no-cursor-attribution: OK"
