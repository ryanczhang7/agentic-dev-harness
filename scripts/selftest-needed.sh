#!/usr/bin/env bash
# Does this story's diff touch a harness path?
#
#   bash scripts/selftest-needed.sh [base-ref]
#
#   exit 0  run   - a changed path is one `classify.sh` calls `harness`, or the
#                   diff could not be computed, or `lib.sh` could not be loaded
#                   (when in doubt, run)
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
# numbers. Deliberate differences: with no merge base, `gates.sh` falls back
# to the base itself, and this answers `run`; a failing `git diff` or
# `git ls-files` answers `run` rather than an empty set; a rename counts under
# both names (`--no-renames`); and a non-ASCII name is listed unquoted
# (`core.quotePath=false`). `lib.sh` is probe-loaded in a subshell first, so a
# library that will not load answers `run` and its error reaches stderr, and a
# missing `paths.conf` or a failing classify step answers `run` too (HARNESS-077).
# Known limit: names containing `"`, `\` or a tab are still C-quoted by git
# despite `core.quotePath=false`, so they classify `source`; POSIX hosts only
# (Windows cannot create them), and `-z` output is the fix if it is ever needed.

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

# Resolved before the `cd` below: BASH_SOURCE may be relative to the caller's
# directory (`bash ../scripts/selftest-needed.sh`).
SELF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)" \
  || fallback "cannot locate the harness this script belongs to"

TOP="$(git rev-parse --show-toplevel 2>/dev/null)" || fallback "not a git checkout"
[ -n "$TOP" ] || fallback "not a git checkout"
cd "$TOP" || fallback "not a git checkout"

export CLAUDE_PROJECT_DIR="$SELF_ROOT"
LIB="$SELF_ROOT/.claude/hooks/lib.sh"
# Probe first: a `set -u` trip or an `exit` in a sourced file ends the whole
# script, so it is sourced in a subshell (stderr kept, so the error is seen)
# before the real source, which then cannot fail that way.
[ -f "$LIB" ] || fallback "cannot load $LIB"
( . "$LIB" ) >/dev/null || fallback "cannot load $LIB"
. "$LIB"
declare -F classify_stdin >/dev/null || fallback "$LIB defines no classify_stdin"
# Without its rules classify_stdin calls every path `source`, so a `skip` from
# here would be wrong by construction. On disk, not the index.
RULES="${HARNESS_DIR:-$SELF_ROOT/.claude/harness}/paths.conf"
[ -r "$RULES" ] || fallback "cannot classify the changed paths: no $RULES"

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

# --no-renames lists both sides of a rename; quotePath=false names a non-ASCII
# path as the filesystem does, not C-quoted.
tracked="$(git -c core.quotePath=false diff --no-renames --name-only "$mb" 2>/dev/null)" \
  || fallback "git diff against $base failed"
untracked="$(git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null)" \
  || fallback "git ls-files failed"
changed="$(printf '%s\n%s\n' "$tracked" "$untracked" | awk 'length' | sort -u)"
n=0; [ -n "$changed" ] && n="$(printf '%s\n' "$changed" | awk 'END { print NR }')"

harness="$(printf '%s\n' "$changed" | classify_stdin | awk -F'\t' '$1 == "harness" { print $2 }')" \
  || fallback "cannot classify the changed paths: classify_stdin failed"

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
