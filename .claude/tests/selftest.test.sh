#!/usr/bin/env bash
# Tests for scripts/selftest.sh's ASSERTION FLOORS.
#
# PORTED FROM A CONSUMING PROJECT, manga-translator's MT-039, which built this
# and shipped it downstream while upstream had nothing like it. It came back
# because a refresh would have deleted it: `scripts/selftest.sh` and
# `.claude/tests/_lib.sh` are REPLACED by refresh-harness.sh while
# `floors.conf` and this suite are KEPT, so the implementation would have gone
# and its configuration and tests would have stayed - the H26 shape the refresh
# script's own header warns about. Ported rather than overwritten.
#
# The problem it solves: selftest.sh runs each harness suite and reads its exit
# status and nothing else. A suite that executed zero assertions exits 0; a
# suite replaced by a single `printf` exits 0. So each suite declares in
# .claude/tests/floors.conf how much work it is worth, and a suite that does
# less fails the run even when it exits 0. It is the `evidence`/`floor` idea
# project.conf already applies to GATES, turned on the harness's own tests.
#
# Two things about this file are worth knowing before changing it.
#
# 1. The floor is the EXECUTED assertion count - the `N` of summary()'s
#    `<name>: N passed, M failed` line - and not the number of `assert_` call
#    sites in the source. They are different numbers, and measured on THIS
#    tree rather than inherited: `profiles` is ONE call site inside a loop and
#    37 executed assertions; `lib` is 50 call sites and 139. A call-site floor
#    for `profiles` would be 1, and deleting 36 of its 37 assertions would
#    satisfy it. Every fixture suite below is generated in that same shape -
#    one call site, a loop - so the distinction is live in every case rather
#    than argued about in a comment.
#
# 2. Every fixture runs against a THROWAWAY tree, never this checkout. The
#    fixture gets its own .claude/tests with its own suites and its own
#    floors.conf, so nothing here depends on - or disturbs - the real suites
#    whose counts the shipped floors.conf records.
#
# The one real-tree assertion block reads .claude/tests/floors.conf itself and
# checks it against the counts measured from a full run of this repository.
# Those are read out, not re-derived.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_project_fixture)"
trap 'rm -rf "$FIX"' EXIT

mkdir -p "$FIX/.claude/tests"
# The REAL _lib.sh, for the same reason make_fixture copies the real paths.conf:
# the summary() format string this story reads is the one the repository ships.
cp "$REPO_ROOT/.claude/tests/_lib.sh" "$FIX/.claude/tests/_lib.sh"

# --- fixture helpers ---------------------------------------------------------

# reset_suites   Empties the fixture's test directory and BOTH floors files.
# HARNESS-020 added project-floors.conf; a block that writes one and a later
# block that assumes it absent would otherwise be coupled through the fixture.
reset_suites() {
  rm -f "$FIX"/.claude/tests/*.test.sh "$FIX/.claude/tests/floors.conf" \
        "$FIX/.claude/tests/project-floors.conf"
}

# passing_suite <name> <n>   A suite with exactly ONE `assert_` call site,
# executed <n> times. That shape is AC-7's subject, not an accident of writing.
passing_suite() {
  {
    printf '#!/usr/bin/env bash\n'
    printf '. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"\n'
    printf 'i=0\n'
    printf 'while [ $i -lt %d ]; do\n' "$2"
    printf '  assert_eq "case $i" x x\n'
    printf '  i=$((i+1))\n'
    printf 'done\n'
    printf 'summary "%s"\n' "$1"
  } > "$FIX/.claude/tests/$1.test.sh"
}

# floors   floors.conf body on stdin.
floors() { cat > "$FIX/.claude/tests/floors.conf"; }

# selftest [args...]   Runs the fixture's copy of scripts/selftest.sh. Sets
# `out` and `RC` as globals rather than echoing, so that $? survives.
selftest() { out="$( cd "$FIX" && bash scripts/selftest.sh "$@" 2>&1 )"; RC=$?; }

# shortfall   The floor-shortfall line out of the last run, or empty. Empty is
# never treated as a match by the assertions below: a preceding assert_contains
# on the WHOLE output reports what was printed instead.
#
# ONE awk over a here-string, not `grep | head -1`. The ported original was
# `printf | grep -F | head -1`, and check-sigpipe.sh flagged it on arrival:
# `head` exits on its first line, the writer upstream takes SIGPIPE and dies
# 141, and under `pipefail` that corpse becomes the status. Fixed here rather
# than waived - the guard was right, and the downstream copy it came from has
# the same latent defect because its own guard predates the rule.
shortfall() {
  awk 'index($0, "below the floor") { print; exit }' <<SHORTFALL_OUT
$out
SHORTFALL_OUT
}

# ---------------------------------------------------------------------------
describe "AC-1  a suite below its floor fails the run, though the suite exits 0"

reset_suites
passing_suite new-story 21
floors <<'FLOORS'
floor | new-story | 22
FLOORS

# The premise, asserted rather than assumed: there is nothing wrong with the
# suite. 21 passing assertions, no failures, exit 0. That is precisely the
# state the existing exit-status check cannot see.
( cd "$FIX" && bash .claude/tests/new-story.test.sh >/dev/null 2>&1 )
assert_eq "the shrunken suite itself still exits 0" 0 "$?"

selftest new-story
assert_eq "but the self-test run exits non-zero" 1 "$RC"
assert_contains "and reports a floor shortfall" "below the floor" "$out"
line="$(shortfall)"
assert_contains "the shortfall names the suite" "new-story" "$line"
assert_contains "and both numbers, in the words gates.sh already uses" \
  "did 21 units of work, below the floor of 22" "$line"
assert_not_contains "the run does not also claim everything passed" \
  "harness suite(s) passed." "$out"

# ---------------------------------------------------------------------------
describe "AC-2  floors that match reality pass everything, and pass silently"

# The negative control for AC-1. A mechanism that satisfies AC-1 by failing
# always, or by failing any suite whose count it cannot parse, dies here.
reset_suites
passing_suite alpha 3
passing_suite beta  7
passing_suite gamma 1
floors <<'FLOORS'
# floors for the fixture suites
floor | alpha | 3
floor | beta  | 7
floor | gamma | 1
FLOORS
selftest
assert_eq "the run exits 0" 0 "$RC"
assert_contains "and says every suite passed" "3 harness suite(s) passed." "$out"
assert_not_contains "no suite is reported short" "below the floor" "$out"
assert_not_contains "and nothing is reported as a fault at all" "FAIL" "$out"

# ---------------------------------------------------------------------------
describe "AC-3  a floor is a floor, not an equality"

# Without this the mechanism becomes a tax on every future story: a story that
# ADDS an assertion would have to edit floors.conf to stay green. One that
# REMOVES one must.
reset_suites
passing_suite new-story 23
floors <<'FLOORS'
floor | new-story | 22
FLOORS
selftest new-story
assert_eq "a suite above its floor exits 0" 0 "$RC"
assert_contains "and the run says it passed" "1 harness suite(s) passed." "$out"
assert_not_contains "no shortfall is reported for a suite that grew" \
  "below the floor" "$out"

# ---------------------------------------------------------------------------
describe "AC-4  the floor does not displace the check that already exists"

# 22 passing assertions and one failing: the floor of 22 is MET, and the run
# must fail anyway. A mechanism that reduces to "is the count high enough"
# passes a suite whose assertions are red.
reset_suites
{
  printf '#!/usr/bin/env bash\n'
  printf '. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"\n'
  printf 'i=0\n'
  printf 'while [ $i -lt 22 ]; do\n'
  printf '  assert_eq "case $i" x x\n'
  printf '  i=$((i+1))\n'
  printf 'done\n'
  printf 'assert_eq "the one that is wrong" want got\n'
  printf 'summary "new-story"\n'
} > "$FIX/.claude/tests/new-story.test.sh"
floors <<'FLOORS'
floor | new-story | 22
FLOORS
selftest new-story
assert_eq "a failing assertion still fails the run" 1 "$RC"
assert_contains "the suite's own summary shows the floor was met" \
  "new-story: 22 passed, 1 failed" "$out"
assert_contains "and the run reports the suite as failed" \
  "harness suite(s) FAILED" "$out"
assert_not_contains "the floor is not what is blamed, because it was met" \
  "below the floor" "$out"

# ---------------------------------------------------------------------------
describe "AC-5  a malformed floors line is named, with its line and its fault"

# gates.sh:112 drops any `kind` it does not recognise, so a one-character typo
# switches a gate's evidence off in silence. A floors mechanism that inherits
# that silence is a floor a typo turns off with no output.

# (a) a floor naming a suite that does not exist.
reset_suites
passing_suite alpha 3
# Line 1 is the comment, 2 is blank, 3 is alpha's floor, and the fault is on
# line 4. The comment and the blank line are there so that a mechanism
# reporting a count of PARSED lines rather than a file line number gets the
# wrong answer here.
floors <<'FLOORS'
# a comment, and a blank line, before the fault

floor | alpha | 3
floor | ghost | 12
FLOORS
selftest
assert_eq "an unmatched floor fails the run" 1 "$RC"
assert_contains "it says which file and line" "floors.conf:4" "$out"
assert_contains "it names the suite it could not find" "ghost" "$out"
assert_contains "and which of the two faults this is" "does not exist" "$out"

# (b) a floor whose value is not a number.
reset_suites
passing_suite alpha 3
floors <<'FLOORS'
# the fault is on line 2
floor | alpha | lots
FLOORS
selftest
assert_eq "a non-numeric floor fails the run" 1 "$RC"
assert_contains "it says which file and line" "floors.conf:2" "$out"
assert_contains "it names the suite" "alpha" "$out"
assert_contains "and which of the two faults this is" "is not a number" "$out"
assert_not_contains "it is not quietly read as zero and passed" \
  "harness suite(s) passed." "$out"

# ---------------------------------------------------------------------------
describe "AC-6  a suite with no floor line fails the run"

# Twelve suites exist today and none has a floor, so this criterion is what
# makes C-3's table exhaustive rather than a sample. The friction is the point:
# a thirteenth suite must declare what it is worth, because a suite with no
# floor is a suite that can be emptied.
reset_suites
passing_suite alpha  3
passing_suite orphan 5
floors <<'FLOORS'
floor | alpha | 3
FLOORS
selftest
assert_eq "an undeclared suite fails the run" 1 "$RC"
assert_contains "it says a floor is missing" "no floor line" "$out"
miss="$(printf '%s\n' "$out" | grep -F 'no floor line' | head -1)"
assert_contains "and names the suite that has none" "orphan" "$miss"
assert_not_contains "and not the suite that has one" "alpha" "$miss"

# ---------------------------------------------------------------------------
describe "AC-7  the count read is the EXECUTED count, not the call sites"

# The failure this criterion exists to prevent: `grep -c assert_` over the
# source is the obvious reading of "assertion count" and it is the wrong
# quantity. profiles is 1 call site and 44 executed.
reset_suites
passing_suite loopy 5
assert_eq "the fixture suite really does have exactly one assert_ call site" \
  1 "$(grep -cE '^[[:space:]]*assert_' "$FIX/.claude/tests/loopy.test.sh")"
assert_contains "and really does execute five" "loopy: 5 passed, 0 failed" \
  "$( cd "$FIX" && bash .claude/tests/loopy.test.sh 2>&1 )"
floors <<'FLOORS'
floor | loopy | 5
FLOORS
selftest loopy
assert_eq "one call site executing five times meets a floor of five" 0 "$RC"

# The discriminating half. Four executions against a floor of five must fail
# reporting FOUR - an implementation counting call sites would report ONE, and
# would be wrong here in a way the pass above cannot show.
reset_suites
passing_suite loopy 4
floors <<'FLOORS'
floor | loopy | 5
FLOORS
selftest loopy
assert_eq "four executions against a floor of five fails" 1 "$RC"
line="$(shortfall)"
assert_contains "and the observed number is the executed count, not the call site" \
  "did 4 units of work, below the floor of 5" "$line"

# ---------------------------------------------------------------------------
describe "C-4  the summary line is matched anchored, by name, and the last wins"

# Three decoys, each defeating a different sloppy read: an anchored,
# correctly-named line EARLY (first-match), an indented one LATE (unanchored),
# and an anchored one under another name LATE (no name key). The real count is
# 3 against a floor of 5, so any read that takes a decoy passes and is caught.
reset_suites
cat > "$FIX/.claude/tests/decoy.test.sh" <<'DECOY'
#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
printf 'decoy: 99 passed, 0 failed\n'
i=0
while [ $i -lt 3 ]; do
  assert_eq "case $i" x x
  i=$((i+1))
done
summary "decoy"
printf '    decoy: 77 passed, 0 failed\n'
printf 'other: 88 passed, 0 failed\n'
DECOY
floors <<'FLOORS'
floor | decoy | 5
FLOORS
selftest decoy
assert_eq "the decoys do not rescue a suite below its floor" 1 "$RC"
line="$(shortfall)"
assert_contains "the count comes from the anchored, correctly named, last line" \
  "did 3 units of work, below the floor of 5" "$line"

# ---------------------------------------------------------------------------
describe "C-4  a suite that prints no summary line at all is a failure"

# The strongest form of the defect this story closes: a suite replaced by
# `exit 0` prints nothing, and must not be read as meeting its floor. An
# implementation that treats a missing summary as "no floor to check" is
# defeated by a one-line edit.
reset_suites
{
  printf '#!/usr/bin/env bash\n'
  printf 'printf "silent: did some work, honest\\n"\n'
  printf 'exit 0\n'
} > "$FIX/.claude/tests/silent.test.sh"
floors <<'FLOORS'
floor | silent | 7
FLOORS
selftest silent
assert_eq "a suite that prints no summary fails the run" 1 "$RC"
assert_contains "it names the suite" "silent" "$out"
assert_contains "and says no count could be read" "no summary line" "$out"
assert_not_contains "it is not excused as having no floor to check" \
  "harness suite(s) passed." "$out"

# ---------------------------------------------------------------------------
describe "C-4  the suite's own output still reaches the reader"

# The mechanism needs the suite's stdout, and the cheap way to get it swallows
# it. A failing suite whose output is captured and dropped makes every failure
# a second command to reproduce.
reset_suites
cat > "$FIX/.claude/tests/talky.test.sh" <<'TALKY'
#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
describe "a section heading"
assert_eq "a passing case" x x
assert_eq "a failing case" want got
summary "talky"
TALKY
floors <<'FLOORS'
floor | talky | 1
FLOORS
selftest talky
assert_eq "the failing suite fails the run" 1 "$RC"
assert_contains "the section heading survives" "a section heading" "$out"
assert_contains "the failing assertion's name survives" "FAIL a failing case" "$out"
assert_contains "and the detail under it" "expected: want" "$out"

out="$( cd "$FIX" && VERBOSE=1 bash scripts/selftest.sh talky 2>&1 )"
assert_contains "VERBOSE=1 still names every passing assertion" \
  "ok   a passing case" "$out"

# ---------------------------------------------------------------------------
describe "C-7  summary()'s format string is now load bearing for selftest.sh"

# The one genuine coupling this story introduces, pinned at this end so that a
# change to _lib.sh cannot break the floor read in silence.
# The haystack is summary() alone, not the whole file: a failure here should
# read like a bug report about one function, not print 200 lines of helpers.
assert_contains "the format string selftest.sh reads is unchanged" \
  "printf '\n%s: %d passed, %d failed\n'" \
  "$(sed -n '/^summary() {/,/^}/p' "$REPO_ROOT/.claude/tests/_lib.sh")"

# And live, rather than by grep: what summary() actually emits matches C-4's
# anchored regex exactly.
reset_suites
passing_suite shape 2
assert_eq "summary() emits exactly the anchored line C-4 matches" \
  "shape: 2 passed, 0 failed" \
  "$( cd "$FIX" && bash .claude/tests/shape.test.sh 2>&1 | grep -E '^shape: [0-9]+ passed, [0-9]+ failed$' )"

# ---------------------------------------------------------------------------
describe "C-2  the floors file uses project.conf's grammar"

reset_suites
passing_suite sloppy 3
# Written through printf rather than a heredoc on purpose: the floor line has
# TRAILING space, which is half of what "leading/trailing space trimmed" means,
# and an editor or a formatter that strips it from this file would silently
# delete the case. Generated at run time, nothing can strip it.
printf '%s\n' \
  '' \
  '# a comment, ignored - including one that looks exactly like a floor:' \
  '# floor | sloppy | 999' \
  '' \
  '   floor   |   sloppy   |   9   ' | floors
selftest sloppy
assert_eq "a sloppily spaced floor is still read" 1 "$RC"
line="$(shortfall)"
assert_contains "space is trimmed and the commented-out floor ignored" \
  "did 3 units of work, below the floor of 9" "$line"

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
boundaries 79
ci-local 28
classify 55
doctor 50
gate-reminder 32
gates 470
grep-count 20
lib 217
mutate 189
new-story 29
phase 33
phase-guard 310
plan 42
policy 17
profiles 50
refresh 122
reporting 27
selftest 100
settings 27
sigpipe 82
spawns 69
worktree 73
COUNTS
assert_eq "and each records the executed count measured on this tree" "" "$wrong"

# Named individually, because these two are the reason AC-7 is a criterion
# rather than a note: a call-site implementation records 1 and 104. HARNESS-010
# moved lib from 139 to 197 and phase-guard from 188 to 288 - both floors are
# recorded in RED, so both suites sit BELOW them until the reconciled parser
# lands. See the note at the foot of floors.conf.
assert_eq "profiles is floored at its 50 executed assertions, not its call-site count" \
  50 "$(floor_of profiles "$REAL")"
assert_eq "lib is floored at its 217 executed assertions, not its call-site count" \
  217 "$(floor_of lib "$REAL")"

# ===========================================================================
# HARNESS-020: a project declares its own suites' floors in
# .claude/tests/project-floors.conf, which upstream never ships and the refresh
# keeps. Every needle below is a WHOLE LINE of selftest.sh's output, compared
# with `grep -cxF`, because the fault strings are mechanical (the story's
# Contract pins them byte for byte) and a floating substring is satisfied by
# the wrong file's name in the right sentence.
# ===========================================================================

# project_floors   project-floors.conf body on stdin.
project_floors() { cat > "$FIX/.claude/tests/project-floors.conf"; }

# exact_lines <line>   How many lines of the last run's output are EXACTLY
# <line>. A here-doc rather than a pipe, for check-sigpipe.sh; no `|| echo 0`
# fallback, for check-grep-count.sh - grep -c already prints 0.
exact_lines() {
  grep -cxF -- "$1" <<EXACT_OUT
$out
EXACT_OUT
}

PF=".claude/tests/project-floors.conf"
MISSING_TAIL="no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)"

# ---------------------------------------------------------------------------
describe "HARNESS-020 AC-1  a suite floored only in project-floors.conf passes the full-run audit"

# alpha is upstream's (floors.conf), project-mine is the project's own. The
# full run is the one CI invokes, and the one FWB's refresh broke.
reset_suites
passing_suite alpha 3
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
# a project's own suites
floor | project-mine | 4
FLOORS
selftest
assert_eq "a full run with a project-floored suite exits 0" 0 "$RC"
assert_eq "and says both suites passed" 1 "$(exact_lines "2 harness suite(s) passed.")"
assert_eq "and counts both floors as met, the project's included" 1 \
  "$(exact_lines "assertion floors: all 2 suite(s) met their declared floor (7 assertions executed, 7 declared).")"
# Prefix, not the new whole line: this must fail under the OLD wording too.
assert_eq "and the project suite is not reported as missing a floor" 0 \
  "$(printf '%s\n' "$out" | grep -c '^FAIL project-mine  no floor line')"
assert_not_contains "and no fault of any kind is printed" "FAIL" "$out"

describe "HARNESS-020 AC-1  and that floor is enforced, not merely accepted"

# The same declaration with the suite one assertion short. An implementation
# that satisfies the audit by treating project-floors.conf as "these suites
# need no floor" passes the block above and dies here.
reset_suites
passing_suite alpha 3
passing_suite project-mine 3
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
floor | project-mine | 4
FLOORS
selftest
assert_eq "a project suite below its project floor fails the full run" 1 "$RC"
# Contract amendment (RED): the shortfall names the file the floor came FROM.
# Saying `in .claude/tests/floors.conf` here would send the reader to edit the
# upstream file the refresh wipes - the very defect this story removes.
assert_eq "the shortfall names the suite, both numbers and project-floors.conf" 1 \
  "$(exact_lines "FAIL project-mine  did 3 units of work, below the floor of 4 in $PF")"
assert_eq "while upstream's suite, which met its floor, is not blamed" 0 \
  "$(printf '%s\n' "$out" | grep -c '^FAIL alpha ')"
assert_not_contains "and the run does not also claim everything passed" \
  "harness suite(s) passed." "$out"

describe "HARNESS-020 AC-1  a floors.conf floor's shortfall still names floors.conf"

# The control for the amendment above: the file a floor came from is reported
# per floor, not swapped wholesale for the new name.
reset_suites
passing_suite alpha 2
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
floor | project-mine | 4
FLOORS
selftest
assert_eq "an upstream suite below its floor fails the full run" 1 "$RC"
assert_eq "and its shortfall line names floors.conf, byte for byte as before" 1 \
  "$(exact_lines "FAIL alpha  did 2 units of work, below the floor of 3 in .claude/tests/floors.conf")"

# ---------------------------------------------------------------------------
describe "HARNESS-020 AC-2  a suite floored in neither file names both files"

# No project-floors.conf at all: exactly the tree FWB had after the refresh,
# and the case where the old message pointed only at the upstream file.
reset_suites
passing_suite alpha 3
passing_suite project-orphan 5
floors <<'FLOORS'
floor | alpha | 3
FLOORS
selftest
assert_eq "an unfloored suite fails the full run" 1 "$RC"
assert_eq "the fault names both files and where a project's own floor belongs" 1 \
  "$(exact_lines "FAIL project-orphan  $MISSING_TAIL")"
assert_eq "the old one-file wording is gone" 0 \
  "$(exact_lines "FAIL project-orphan  no floor line in .claude/tests/floors.conf; every suite must declare one")"

# The same with a project-floors.conf present that floors something else: the
# message does not depend on whether the project file exists.
reset_suites
passing_suite alpha 3
passing_suite project-mine 2
passing_suite project-orphan 5
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
floor | project-mine | 2
FLOORS
selftest
assert_eq "with a project file present, an unfloored suite still fails" 1 "$RC"
assert_eq "and the fault names both files, the same words" 1 \
  "$(exact_lines "FAIL project-orphan  $MISSING_TAIL")"
assert_eq "and only the unfloored suite is named" 1 \
  "$(printf '%s\n' "$out" | grep -c '^FAIL ')"

# ---------------------------------------------------------------------------
describe "HARNESS-020 AC-3  a project-floors.conf fault is named, with its file, line and fault"

# Each fault on a line number that a count of PARSED lines would get wrong: a
# comment and a blank line come first.

# (a) malformed line.
reset_suites
passing_suite alpha 3
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
# a comment, and a blank line, before the fault

floor | project-mine | 4
this is not a floor
FLOORS
selftest
assert_eq "a malformed project-floors.conf line fails the full run" 1 "$RC"
assert_eq "named with project-floors.conf, line 4, and the fault" 1 \
  "$(exact_lines "FAIL $PF:4  is not a floor line: 'this is not a floor'")"

# (b) a floor naming a suite that does not exist.
reset_suites
passing_suite alpha 3
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
# the fault is on line 3

floor | project-ghost | 12
floor | project-mine | 4
FLOORS
selftest
assert_eq "a project floor naming a missing suite fails the full run" 1 "$RC"
assert_eq "named with project-floors.conf, line 3, the suite, and the missing file" 1 \
  "$(exact_lines "FAIL $PF:3  floor names 'project-ghost', but .claude/tests/project-ghost.test.sh does not exist")"

# (c) a suite floored in BOTH files. Without this, a project could quietly
# lower an upstream suite's floor from the file the refresh never replaces.
reset_suites
passing_suite alpha 3
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
floor | project-mine | 4
floor | alpha | 1
FLOORS
selftest
assert_eq "a suite floored in both files fails the full run" 1 "$RC"
assert_eq "named against project-floors.conf's line 2, naming floors.conf" 1 \
  "$(exact_lines "FAIL $PF:2  floor for 'alpha' is already declared in .claude/tests/floors.conf; a suite has one floor")"
assert_eq "and the floors.conf line is not the one blamed" 0 \
  "$(printf '%s\n' "$out" | grep -c '^FAIL \.claude/tests/floors\.conf')"

# (d) the remaining two faults of the shared grammar, against the project file.
reset_suites
passing_suite alpha 3
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
# two faults
flor | project-mine | 4
floor | project-mine | lots
FLOORS
selftest
assert_eq "a non-numeric or unknown-kind project floor fails the full run" 1 "$RC"
assert_eq "an unknown kind is named with project-floors.conf and its line" 1 \
  "$(exact_lines "FAIL $PF:2  unknown kind 'flor'; the only kind is 'floor'")"
assert_eq "a non-number is named with project-floors.conf and its line" 1 \
  "$(exact_lines "FAIL $PF:3  floor for 'project-mine' is not a number: 'lots'")"

describe "HARNESS-020 AC-3  a fault that names no suite is reported, not dropped"

# Found in RED, and the reason (a) above cannot pass by reuse alone. A fault
# that carries no suite name - `is not a floor line`, `does not exist` - is
# queued as "<TAB><message>", and the report loop reads it back with
# IFS=<TAB>. TAB is an IFS WHITESPACE character, so read strips the leading
# one, the message lands in the name field, the message field is empty, and
# `[ -n "$fmsg" ] || continue` drops it. Measured on the shipped selftest.sh:
# a floors.conf holding `this is not a floor` passes the full run, exit 0. So
# the malformed-line fault has never been printed, for either file, and the
# missing-floors.conf fault is printed only by accident - every suite then
# also lacks a floor. These two pin the shared report path for floors.conf;
# (a) pins it for project-floors.conf.
reset_suites
passing_suite alpha 3
floors <<'FLOORS'
floor | alpha | 3
this is not a floor
FLOORS
selftest
assert_eq "a malformed floors.conf line fails the full run" 1 "$RC"
assert_eq "named with floors.conf, its line, and the fault" 1 \
  "$(exact_lines "FAIL .claude/tests/floors.conf:2  is not a floor line: 'this is not a floor'")"

reset_suites
passing_suite alpha 3
selftest
assert_eq "a missing floors.conf fails the full run" 1 "$RC"
assert_eq "and says so in its own words, not only through each suite's missing floor" 1 \
  "$(exact_lines "FAIL .claude/tests/floors.conf  does not exist; every suite must declare its assertion floor there")"

describe "HARNESS-020 AC-3  control: no project-floors.conf is not a fault"

# An upstream tree - this repository - ships no project-floors.conf, and must
# pass exactly as before. The needle is the file's NAME anywhere in the output:
# every fault above prints it, so a mechanism that makes absence a fault (or so
# much as mentions the file when it is absent) is caught here.
reset_suites
passing_suite alpha 3
passing_suite beta  7
floors <<'FLOORS'
floor | alpha | 3
floor | beta  | 7
FLOORS
selftest
assert_eq "with no project-floors.conf the full run exits 0" 0 "$RC"
assert_eq "and says both suites passed" 1 "$(exact_lines "2 harness suite(s) passed.")"
assert_not_contains "and project-floors.conf is not mentioned at all" "project-floors.conf" "$out"
assert_eq "and no line is a fault" 0 "$(printf '%s\n' "$out" | grep -c '^FAIL')"

# ---------------------------------------------------------------------------
describe "HARNESS-020 AC-4  a single-suite run enforces a project-floors.conf floor"

reset_suites
passing_suite alpha 3
passing_suite project-mine 3
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
floor | project-mine | 4
FLOORS
selftest project-mine
assert_eq "a project suite below its project floor fails its single-suite run" 1 "$RC"
assert_eq "naming the suite, both numbers and project-floors.conf" 1 \
  "$(exact_lines "FAIL project-mine  did 3 units of work, below the floor of 4 in $PF")"
assert_not_contains "and it is not waved through as having no floor" \
  "WARNING: no floor line for project-mine" "$out"

# The passing half: at its floor, the single-suite run is clean and counts
# the floor as met - not "passed, with a warning that no floor exists".
reset_suites
passing_suite alpha 3
passing_suite project-mine 4
floors <<'FLOORS'
floor | alpha | 3
FLOORS
project_floors <<'FLOORS'
floor | project-mine | 4
FLOORS
selftest project-mine
assert_eq "at its project floor the single-suite run exits 0" 0 "$RC"
assert_eq "and the floor is counted as met" 1 \
  "$(exact_lines "assertion floors: all 1 suite(s) met their declared floor (4 assertions executed, 4 declared).")"
assert_not_contains "with no missing-floor warning" "WARNING: no floor line" "$out"

summary "selftest"
