#!/usr/bin/env bash
# Tests for the SHIPPED floors file, .claude/tests/floors.conf: the real tree
# has a floor for every suite, and each floor is the executed count measured
# on this tree, recorded a second time in the hand-copied table below.
#
# MOVED, NOT WRITTEN (HARNESS-131). Every assertion here was the real-tree
# block of selftest.test.sh (`AC-6/AC-7  the shipped floors file covers every
# suite, at its count`, with HARNESS-021's suites_without_floor cases), moved
# word for word. It moved so that a story raising a floor - which edits this
# table - selects this suite before a PR, not the whole `selftest` suite: the
# selection reads a changed path's mentions, and this is now the one suite
# that reads the real floors.conf. selftest.test.sh tests selftest.sh's floor
# MECHANISM over fixtures of its own and declares floors.conf fixture-only.
#
# The scratch directory is named FIX so that floor_root's body, which built
# under selftest.test.sh's fixture, is byte-identical here; this suite needs
# no project fixture, only a directory to hold the throwaway roots.
#
# A FLOOR IS RECORDED TWICE: in floors.conf and in the COUNTS table below.
# Raise one and raise the other in the same commit, or this suite fails with
# `and each records the executed count measured on this tree`.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(mktemp -d 2>/dev/null || mktemp -d -t harness.XXXXXX)"
trap 'rm -rf "$FIX"' EXIT

# ---------------------------------------------------------------------------
describe "AC-6/AC-7  the shipped floors file covers every suite, at its count"

# The real tree, not a fixture. AC-6 makes C-3's table exhaustive; AC-7's own
# control is that `profiles` is recorded at 44 and not at its 1 call site.
REAL="$REPO_ROOT/.claude/tests/floors.conf"

# One awk over the file, for the same reason as shortfall() above: `sed | head -1`
# is a pipeline into an early-exit reader, and check-sigpipe.sh flagged it.
floor_of() { # <suite> <file>   the value recorded for a suite in <file>, or empty
  awk -v want="$1" '
    { line = $0; sub(/#.*/, "", line) }
    { n = split(line, f, "|") }
    n < 3 { next }
    { for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t]+$/, "", f[i]) } }
    f[1] == "floor" && f[2] == want && f[3] ~ /^[0-9]+$/ { print f[3]; exit }
  ' "$2" 2>/dev/null
}

# suites_without_floor <root>   The space-joined names of the suites in
# <root>/.claude/tests/*.test.sh that have a floor line in neither
# <root>/.claude/tests/floors.conf nor, when it exists,
# <root>/.claude/tests/project-floors.conf. Empty when every suite is floored.
# HARNESS-021: this loop used to read floors.conf only, so every consuming
# project that floors its project-*.test.sh suites in project-floors.conf (as
# HARNESS-020 designed) failed the assertion below. Taking a root is what lets
# the fixture cases further down point it at a tree that is not this one.
suites_without_floor() {
  _swf_dir="$1/.claude/tests"
  _swf_missing=""
  for _swf_s in "$_swf_dir"/*.test.sh; do
    [ -e "$_swf_s" ] || continue
    _swf_n="$(basename "$_swf_s" .test.sh)"
    [ -n "$(floor_of "$_swf_n" "$_swf_dir/floors.conf")" ] && continue
    if [ -f "$_swf_dir/project-floors.conf" ]; then
      [ -n "$(floor_of "$_swf_n" "$_swf_dir/project-floors.conf")" ] && continue
    fi
    _swf_missing="$_swf_missing $_swf_n"
  done
  printf '%s' "${_swf_missing# }"
}

assert_eq "every suite in .claude/tests has a floor" "" "$(suites_without_floor "$REPO_ROOT")"

# HARNESS-021 fixture cases for suites_without_floor. Each root is a throwaway
# directory under $FIX holding only the .claude/tests files the helper reads:
# empty suite files (it reads names, not contents) and the floors files. Every
# needle is the helper's WHOLE output compared with assert_eq, so a helper that
# reports nothing, or reports the right name among wrong ones, cannot pass.

# floor_root <case> <suite>...   A fresh root with an empty <suite>.test.sh for
# each name. Prints the root. floors.conf / project-floors.conf are written by
# the caller, so "absent" is a case and not an accident.
floor_root() {
  _fr="$FIX/floor-roots/$1"; shift
  rm -rf "$_fr"; mkdir -p "$_fr/.claude/tests"
  for _fr_s in "$@"; do : > "$_fr/.claude/tests/$_fr_s.test.sh"; done
  printf '%s' "$_fr"
}

describe "HARNESS-021 AC-1  a suite floored only in project-floors.conf is not reported missing"

R="$(floor_root ac1 alpha project-mine)"
printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
printf '# a project'"'"'s own suites\nfloor | project-mine | 4\n' > "$R/.claude/tests/project-floors.conf"
assert_eq "a suite floored in project-floors.conf alone is not reported as missing a floor" \
  "" "$(suites_without_floor "$R")"
# The same, beside an unfloored suite: the project floor excuses project-mine
# and nothing else, so the output is exactly the orphan.
R="$(floor_root ac1b alpha project-mine project-orphan)"
printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
printf 'floor | project-mine | 4\n' > "$R/.claude/tests/project-floors.conf"
assert_eq "beside an unfloored suite, only the unfloored one is reported" \
  "project-orphan" "$(suites_without_floor "$R")"

describe "HARNESS-021 AC-2  control: a suite floored in neither file is reported, by name"

# Without this, a helper that reports nothing satisfies AC-1. A project-floors.conf
# EXISTS here (comment only), so this also refuses a helper that treats the
# file's mere presence as excusing every suite. Green under the old and the new
# helper alike - it is the control, not the change.
R="$(floor_root ac2 alpha project-orphan)"
printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
printf '# a project file that floors nothing\n' > "$R/.claude/tests/project-floors.conf"
assert_eq "a suite floored in neither file is reported, and only that suite" \
  "project-orphan" "$(suites_without_floor "$R")"

describe "HARNESS-021 AC-3  with no project-floors.conf the check behaves as before"

R="$(floor_root ac3 alpha beta gamma)"
printf 'floor | alpha | 3\nfloor | gamma | 1\n' > "$R/.claude/tests/floors.conf"
assert_eq "with no project-floors.conf, a suite missing from floors.conf is reported" \
  "beta" "$(suites_without_floor "$R")"
# Two missing, to pin the space-joined shape the real-tree message prints.
R="$(floor_root ac3b alpha beta gamma)"
printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
assert_eq "and several missing suites are reported space-joined, in name order" \
  "beta gamma" "$(suites_without_floor "$R")"
# AC-3's second half - this repository's real tree still passes - is the
# real-tree assertion above. Deliberately NOT asserted: that the real tree has
# no project-floors.conf. This file is copied into consuming projects, which
# do ship one, and there that assertion would be the defect this story removes.

# The counts measured from a full run of THIS repository, read out rather than
# re-derived. MT's numbers were deliberately NOT inherited: its suite set is a
# different one, and a floor copied from another tree is a floor nobody
# measured - which is the exact defect this mechanism exists to catch, pointed
# at itself. Confirmed against the CI run of the same tree, and three of them
# (profiles, mutate, lib) re-run locally at the port.
wrong=""
while read -r n v; do
  [ -z "$n" ] && continue
  got="$(floor_of "$n" "$REAL")"
  [ "$got" = "$v" ] || wrong="$wrong $n=${got:-<none>}(want $v)"
done <<'COUNTS'
attest 179
boundaries 703
briefs 31
ci-local 52
classify 55
dispatch 205
doctor 71
floors 9
gate-reminder 32
gates 1002
grep-count 38
host-load 72
lib 332
mutate 328
new-story 79
phase 73
phase-guard 388
plan 287
policy 17
procedure 183
profiles 132
refresh 215
reporting 27
rules-trim 50
run-lock 141
run-queue 901
security-audit 52
selftest 404
selftest-needed 1165
settings 70
shipped-docs 24
sigpipe 91
spawns 69
story 97
tidy 206
worktree 73
COUNTS
assert_eq "and each records the executed count measured on this tree" "" "$wrong"

# Named individually, because these two are the reason AC-7 is a criterion
# rather than a note: a call-site implementation records 1 and 104. HARNESS-010
# moved lib from 139 to 197 and phase-guard from 188 to 288 - both floors are
# recorded in RED, so both suites sit BELOW them until the reconciled parser
# lands. See the note at the foot of floors.conf.
assert_eq "profiles is floored at its 132 executed assertions, not its call-site count" \
  132 "$(floor_of profiles "$REAL")"
assert_eq "lib is floored at its 332 executed assertions, not its call-site count" \
  332 "$(floor_of lib "$REAL")"

summary "floors"
