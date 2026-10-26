#!/usr/bin/env bash
# Does this story's diff touch a harness path?
#
#   bash scripts/selftest-needed.sh [base-ref]
#
#   exit 0  run   - a changed path is one `classify.sh` calls `harness`, or the
#                   diff could not be computed (when in doubt, run)
#   exit 1  skip  - no changed path is `harness`; CI still runs the self-test
#   exit 2  usage
#
# Step 2 of GATES -> REVIEW asks this before spending minutes (hours on a busy
# Windows host) on `SELFTEST_JOBS=4 bash scripts/selftest.sh`. The harness
# suites read harness paths - scripts, `.claude/**`, `CLAUDE.md`, the workflows
# - so a story that changes none of them cannot break one, and CI's own run on
# the PR is the backstop either way (HARNESS-075).
#
# "The story's diff" is the same enumeration as the `covers` check in
# `gates.sh`: base = first of origin/main, main that resolves; changes against
# `git merge-base <base> HEAD`, committed or not, plus untracked files. It is
# duplicated rather than shared because `sigpipe.test.sh` pins `gates.sh` line
# numbers. One deliberate difference: with no merge base, `gates.sh` falls back
# to the base itself, and this answers `run`.

set -uo pipefail

usage() {
  printf 'usage: bash scripts/selftest-needed.sh [base-ref]\n' >&2
  exit 2
}
[ "$#" -le 1 ] || usage
case "${1-}" in -*) usage ;; esac

D='—'
fallback() {
  printf 'selftest-needed: run %s cannot compute the diff: %s; defaulting to run\n' "$D" "$1"
  exit 0
}

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || fallback "not a git checkout"
[ -n "$TOP" ] || fallback "not a git checkout"
cd "$TOP" || fallback "not a git checkout"

SELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CLAUDE_PROJECT_DIR="$SELF_ROOT"
. "$SELF_ROOT/.claude/hooks/lib.sh"

base="${1-}"
if [ -z "$base" ]; then
  for b in origin/main main; do
    if git rev-parse --verify -q "$b" >/dev/null 2>&1; then base="$b"; break; fi
  done
  [ -n "$base" ] || fallback "no origin/main or main to compare against"
fi

mb="$(git merge-base "$base" HEAD 2>/dev/null)" && [ -n "$mb" ] \
  || fallback "no merge base with $base"
short="$(git rev-parse --short "$mb" 2>/dev/null)"

changed="$( { git diff --name-only "$mb" 2>/dev/null
              git ls-files --others --exclude-standard 2>/dev/null; } | sort -u)"
n=0; [ -n "$changed" ] && n="$(printf '%s\n' "$changed" | awk 'END { print NR }')"

harness="$(printf '%s\n' "$changed" | classify_stdin | awk -F'\t' '$1 == "harness" { print $2 }')"

if [ -z "$harness" ]; then
  printf 'selftest-needed: skip %s no harness path among %s changed path(s) against %s (merge-base %s); CI runs the self-test on the PR\n' \
    "$D" "$n" "$base" "$short"
  exit 1
fi

list="$(printf '%s\n' "$harness" | awk '
  NR <= 3 { out = (NR == 1 ? $0 : out ", " $0) }
  END { if (NR > 3) out = out ", +" (NR - 3) " more"; printf "%s|%d", out, NR }')"
printf 'selftest-needed: run %s %s harness path(s) changed against %s (merge-base %s): %s\n' \
  "$D" "${list##*|}" "$base" "$short" "${list%|*}"
exit 0
