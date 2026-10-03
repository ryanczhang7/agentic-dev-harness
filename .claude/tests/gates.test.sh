#!/usr/bin/env bash
# Tests for scripts/gates.sh - the liveness machinery, not any real toolchain.
#
# Every gate command here is a `printf`, so the suite runs in a second and
# tests exactly one thing: whether gates.sh can tell a gate that did work from
# one that only exited 0.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_project_fixture)"
trap 'rm -rf "$FIX"' EXIT

gates() { ( cd "$FIX" && bash scripts/gates.sh "$@" 2>&1 ); }

# ---------------------------------------------------------------------------
describe "evidence: a gate that exits 0 having done nothing"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
# project.conf is gated (harness, not markdown) and write_conf creates it
# UNTRACKED. HARNESS-014 makes a full run with an active story refuse to record
# while any untracked gated file exists, so the fixture's conf is tracked once,
# here; every later write_conf is then an edit to a tracked file, which the
# stamp covers and the refusal ignores. Its content still changes per block.
git -C "$FIX" add -A >/dev/null 2>&1
git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm "track project.conf" >/dev/null 2>&1
out="$(gates)"
assert_contains "a live gate passes" "PASS         unit" "$out"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'No test files found, exiting with code 0\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(gates)"
assert_contains "a vacuous gate fails" "no evidence of work" "$out"
assert_contains "and the run fails"    "1 required gate(s) failed" "$out"

# ---------------------------------------------------------------------------
describe "--gate names a gate that exists"

# `--gate untt` ran nothing and printed "All required gates passed (0 ran)",
# exit 0. A typo is not a pass.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(gates --gate untt)"; rc=$?
assert_contains "a typo is refused" "no gate named 'untt'" "$out"
assert_eq "and exits non-zero" "2" "$rc"

# ---------------------------------------------------------------------------
describe "floor: a gate that started doing much less"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
floor    | unit | 40
EOF
out="$(gates)"
assert_contains "above the floor passes"   "PASS         unit" "$out"
assert_contains "and reports the count"    "observed 47, floor 40" "$out"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  3 passed (3)\n'
evidence | unit | Tests +[1-9][0-9]* passed
floor    | unit | 40
EOF
out="$(gates)"
assert_contains "below the floor fails"     "below the floor of 40" "$out"
assert_contains "naming what it observed"   "did 3 units of work" "$out"

# An optional gate below its floor warns rather than blocking, like any other
# optional failure.
write_conf "$FIX" <<'EOF'
gate     | integration | optional | . | printf 'Tests  1 passed (1)\n'
evidence | integration | Tests +[1-9][0-9]* passed
floor    | integration | 10
EOF
out="$(gates)"
assert_contains "an optional gate below its floor warns" "WARN         integration" "$out"

describe "floor: a floor that cannot be evaluated is a manifest error"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
floor    | unit | 40
EOF
out="$(gates --audit)"
assert_contains "a floor without an evidence line" "floor needs an evidence regex" "$out"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
floor    | unit | lots
EOF
out="$(gates --audit)"
assert_contains "a floor that is not a number" "is not a number" "$out"

describe "floor: an evidence regex that uses alternation"

# `a|b` at the top level would otherwise bind the trailing `.*` to the last
# branch alone, so a count that follows the matched text is invisible.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests passed: 47\n'
evidence | unit | Tests passed:|Examples passed:
floor    | unit | 40
EOF
out="$(gates)"
assert_contains "counts what follows the branch that matched" "observed 47" "$out"
assert_contains "so the gate passes" "PASS         unit" "$out"

describe "the count is reported even with no floor"

write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Checked 132 files in 400ms\n'
evidence | lint | Checked [1-9][0-9]* files
EOF
out="$(gates)"
assert_contains "observed count in the summary" "observed 132" "$out"

# ---------------------------------------------------------------------------
describe "required_gates: a story can escalate an optional gate for itself"

write_conf "$FIX" <<'EOF'
gate     | unit        | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit        | Tests +[1-9][0-9]* passed
gate     | integration | optional | . | printf 'boom\n'; exit 1
evidence | integration | [1-9][0-9]* passed
EOF

story "$FIX" T-1 GATES </dev/null
set_phase "$FIX" GATES
out="$(gates)"
assert_contains "optional by default: it warns" "WARN         integration" "$out"
assert_contains "and the run still passes"      "All required gates passed" "$out"

story "$FIX" T-1 GATES <<'EOF'
required_gates: [integration]
EOF
out="$(gates)"
assert_contains "escalated: it fails"      "FAIL         integration" "$out"
assert_contains "naming the story"         "required by story T-1" "$out"
assert_contains "and the run fails"        "1 required gate(s) failed" "$out"

# A waiver cannot silence a gate the story requires - that is a bypass, the
# same one waivers are already refused for on repo-required gates.
write_conf "$FIX" <<'EOF'
gate     | integration | optional | . | printf 'boom\n'; exit 1
evidence | integration | [1-9][0-9]* passed
waiver   | integration | the service is not up in CI
EOF
out="$(gates)"
assert_contains "a waiver on a story-required gate is refused" "waiver" "$out"
assert_contains "and it fails"                                 "1 required gate(s) failed" "$out"

set_phase "$FIX" ""


# ---------------------------------------------------------------------------
describe "--fast: the subset that judges whether tests are admissible"

# The field report this came from: RED and GREEN only ever ran the plain test
# command, so a suite that passed both, and passed sixteen local gates, still
# failed a REQUIRED gate in CI - the same tests under coverage instrumentation,
# where one property test crossed the 5s timeout. --fast is the primitive that
# lets RED and GREEN ask the gates the question, without paying for a bundle.
write_conf "$FIX" <<'EOF'
gate     | lint     | required | . | printf 'Checked 12 files\n'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | coverage | required | . | printf 'Tests  47 passed (47)\n'
gate     | build    | required | . | printf 'Bundled 3 targets\n'
evidence | lint     | Checked [1-9][0-9]* files
evidence | unit     | Tests +[1-9][0-9]* passed
evidence | coverage | Tests +[1-9][0-9]* passed
evidence | build    | Bundled [1-9][0-9]* targets
slow     | build    | a Tauri release bundle; RED has no use for it
EOF
out="$(gates --fast)"
assert_contains "a fast gate runs"          "PASS         lint" "$out"
assert_contains "the instrumented one runs" "PASS         coverage" "$out"
case "$out" in
  *"PASS         build"*) _bad "a slow gate is skipped" "build ran anyway: $out" ;;
  *) _ok "a slow gate is skipped" ;;
esac
assert_contains "and is named"        "--fast skipped: build" "$out"
assert_contains "with the caveat"     "This is a subset, not a verdict" "$out"

# A subset is not evidence, for the same reason --gate and --required are not.
story "$FIX" T-1 GATES <<'EOF'
EOF
set_phase "$FIX" GATES
out="$(gates --fast)"
assert_contains "a fast run is never recorded" "not recorded in the story" "$out"
out="$(gates)"
assert_contains "a full run still is"          "recorded in docs/backlog/stories/T-1.md" "$out"
assert_contains "and points at CI's other script" "check-boundaries.sh" "$out"
set_phase "$FIX" ""

# With nothing marked slow, --fast is a full run in everything but the record,
# and says so rather than letting anyone believe they bought speed.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(gates --fast)"
assert_contains "no slow lines is reported" "--fast skipped nothing" "$out"

# ---------------------------------------------------------------------------
describe "slow: a line that excludes nothing is a manifest error"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
slow     | unit |
EOF
out="$(gates --audit)"
assert_contains "slow without a reason fails the audit" "marked slow with no reason" "$out"

write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
slow     | unti | a typo, so `build` never leaves the fast subset
EOF
out="$(gates --audit)"
assert_contains "slow naming no gate fails the audit" "names no configured gate" "$out"

# ---------------------------------------------------------------------------
describe "covers: is what this story changed exercised by a required gate"

# The failure this exists for: a renderer's tests lived in a browser-only
# project, that project ran in an `optional` integration gate, and the
# coverage include skipped the same directory. Each decision was right on its
# own. Together they put every test of the story's artifact where nothing
# could block on it, and "All required gates passed" printed underneath.
# gates.sh could not notice, because nothing said which paths a gate reads.
# `covers` lines say. Then the story's changed source paths - the diff against
# main, committed or not - are checked against them after every run.

git -C "$FIX" -c user.email=t@t -c user.name=t branch -M main >/dev/null 2>&1
git -C "$FIX" checkout -q -b story/T-1-fixture 2>/dev/null
mkdir -p "$FIX/src/render" "$FIX/src/core" "$FIX/src/shaders"
story "$FIX" T-1 GATES <<'EOF'
EOF
set_phase "$FIX" GATES

# No covers lines: the check does not exist, and says nothing.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
printf 'export const m = 1\n' > "$FIX/src/render/mesh.ts"
out="$(gates)"
case "$out" in
  *"changed source"*|*"covers"*) _bad "no covers lines means no check" "spoke anyway: $out" ;;
  *) _ok "no covers lines means no check" ;;
esac

# A changed path that only an OPTIONAL gate reads fails the run, and the
# message names the fix, which is the story's to make.
write_conf "$FIX" <<'EOF'
gate     | unit        | required | . | printf 'Tests  47 passed (47)\n'
gate     | integration | optional | . | printf 'Tests  25 passed (25)\n'
evidence | unit        | Tests +[1-9][0-9]* passed
evidence | integration | Tests +[1-9][0-9]* passed
covers   | unit        | src/core/**
covers   | integration | src/render/**
EOF
out="$(gates)"
assert_contains "only an optional gate reads it" "FAIL         changes: src/render/mesh.ts is exercised only by optional gate(s): integration" "$out"
assert_contains "and names the fix"              "required_gates: [integration]" "$out"
assert_contains "and the run fails"              "required gate(s) failed" "$out"

# The story escalates the gate, and the same change is covered.
story "$FIX" T-1 GATES <<'EOF'
required_gates: [integration]
EOF
out="$(gates)"
assert_contains "escalated, it counts as required" "changed source path(s), all exercised by a required gate" "$out"
assert_contains "and the run passes" "All required gates passed" "$out"

# A change a required gate reads is fine without any escalation.
story "$FIX" T-1 GATES <<'EOF'
EOF
rm -f "$FIX/src/render/mesh.ts"
printf 'export const c = 1\n' > "$FIX/src/core/thing.ts"
out="$(gates)"
assert_contains "a required gate reads it" "1 changed source path(s), all exercised by a required gate" "$out"

# A change NO gate claims is a warning: the manifest may be incomplete, or the
# file may genuinely be ungated, and only a person can tell which.
printf 'void main() {}\n' > "$FIX/src/shaders/sky.glsl"
out="$(gates)"
assert_contains "no gate claims it" "WARN         changes: src/shaders/sky.glsl is exercised by no gate with a covers line" "$out"
assert_contains "and the run still passes" "All required gates passed" "$out"

# Committed changes count the same as uncommitted ones: the diff is against
# main, not against HEAD.
git -C "$FIX" add -A >/dev/null 2>&1
git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm "story work" >/dev/null 2>&1
out="$(gates)"
assert_contains "committed changes are still the story's" "WARN         changes: src/shaders/sky.glsl" "$out"

# Test files are not the artifact; a changed test in a gated directory is not
# reported even when no covers line names the tests directory.
rm -f "$FIX/src/shaders/sky.glsl"
printf 'test("y", () => {})\n' > "$FIX/tests/other.test.ts"
out="$(gates)"
# Anchored to the changes report (`WARN         changes: …` / `FAIL         changes: …`).
# The file is untracked and classifies as test, so AC-4 (HARNESS-014) REQUIRES
# `    UNTRACKED  tests/other.test.ts` in this same output; a needle floating
# over the whole output was satisfied by that line and could only pass by
# breaking AC-4 (R-1b).
changes_lines="$(printf '%s\n' "$out" | grep -E '^(WARN|FAIL) +changes: ')" || changes_lines=""
case "$changes_lines" in
  *"tests/other.test.ts"*) _bad "a test file is not a changed source path" "reported it: $out" ;;
  *) _ok "a test file is not a changed source path" ;;
esac

# --fast runs the check too: GREEN is where the source first exists, and
# GREEN ends with --fast.
printf 'export const m = 1\n' > "$FIX/src/render/mesh.ts"
out="$(gates --fast)"
assert_contains "--fast checks it as well" "FAIL         changes: src/render/mesh.ts" "$out"

# --list shows the lines; --audit refuses one naming no gate.
out="$(gates --list)"
assert_contains "--list shows covers" "covers:   src/render/**" "$out"
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
covers   | unti | src/**
EOF
out="$(gates --audit)"
assert_contains "covers naming no gate fails the audit" "a \`covers\` line names no configured gate" "$out"
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(gates --audit)"
assert_contains "no covers lines is noted by the audit" "no \`covers\` lines" "$out"

rm -f "$FIX/src/render/mesh.ts" "$FIX/tests/other.test.ts"
set_phase "$FIX" ""
git -C "$FIX" checkout -q -- . 2>/dev/null
git -C "$FIX" checkout -q main 2>/dev/null

# ---------------------------------------------------------------------------
describe "ci-factor: a measurement, or nothing"

# The number is how much slower ONE TEST is on CI under this gate. It is worth
# recording because the obvious way to derive it - the gate's own wall time,
# most of which is fixed overhead - overestimates it several-fold and sends
# somebody optimising a test that was already fast enough.
write_conf "$FIX" <<'EOF'
gate      | coverage | required | . | printf 'Tests  47 passed (47)\n'
evidence  | coverage | Tests +[1-9][0-9]* passed
ci-factor | coverage | 3.4 | actions run 412, AC-4 file 1,262 ms instrumented
EOF
out="$(gates --audit)"
assert_contains "a measured factor passes the audit" "ci-factor: 3.4" "$out"

write_conf "$FIX" <<'EOF'
gate      | coverage | required | . | printf 'Tests  47 passed (47)\n'
evidence  | coverage | Tests +[1-9][0-9]* passed
ci-factor | coverage | about 14x | eyeballed it
EOF
out="$(gates --audit)"
assert_contains "a factor that is not a number fails" "is not a number" "$out"

write_conf "$FIX" <<'EOF'
gate      | coverage | required | . | printf 'Tests  47 passed (47)\n'
evidence  | coverage | Tests +[1-9][0-9]* passed
ci-factor | coverage | 3.4
EOF
out="$(gates --audit)"
assert_contains "a factor with no source fails" "has no source" "$out"

write_conf "$FIX" <<'EOF'
gate      | coverage | required | . | printf 'Tests  47 passed (47)\n'
evidence  | coverage | Tests +[1-9][0-9]* passed
ci-factor | covrage  | 3.4 | actions run 412
EOF
out="$(gates --audit)"
assert_contains "a factor naming no gate fails the audit" "names no configured gate" "$out"


# ---------------------------------------------------------------------------
describe "BLOCKED: the environment would not let the gate run"

# H16. A required gate failed eight consecutive runs on one machine with this,
# and nothing about it was a test failure:
#
#   error: failed to run custom build command for `the-project v0.1.0`
#   Caused by: could not execute process `...build-script-build` (never executed)
#   Caused by: An Application Control policy has blocked this file. (os error 4551)
#
# The runner reported FAIL, because a gate's result was a boolean derived from an
# exit code. The Stop hook then refused every report with "fix it or move the
# story back to RED", and neither applied: there was nothing to fix and the code
# was fine - the same command passed on CI three times that day. An hour and a
# user decision went into inventing the third path. BLOCKED is that path, named.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'error: could not execute process (never executed)\nCaused by: An Application Control policy has blocked this file. (os error 4551)\n'; exit 101
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(gates)"; rc=$?
assert_contains "a launch failure is BLOCKED, not FAIL" "BLOCKED      unit" "$out"
assert_contains "and says the environment refused it"   "could not launch" "$out"
assert_contains "and it is not reported as a pass"      "1 required gate(s) could not run" "$out"
assert_eq "and exits 3, distinct from a failure"        "3" "$rc"
assert_contains "and names the third path"              "pending CI" "$out"
assert_contains "RESULT=blocked in the stamp" "RESULT=blocked" \
  "$(cat "$FIX/.claude/state/last-gate-run")"

# The distinction has to cut both ways, or it is just a wider FAIL. An ordinary
# failure - the gate ran, the gate complained - is still a failure.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  2 failed, 45 passed (47)\nAssertionError: expected 3 to be 4\n'; exit 1
evidence | unit | Tests +[1-9][0-9]* passed
EOF
out="$(gates)"; rc=$?
assert_contains "a real failure is still FAIL" "FAIL         unit" "$out"
assert_eq "and still exits 1"                  "1" "$rc"
assert_contains "RESULT=fail in the stamp" "RESULT=fail" \
  "$(cat "$FIX/.claude/state/last-gate-run")"

# A blocked gate must never hide a broken one. When both happen the run is a
# failure: there is something to fix, and that decides what happens next.
write_conf "$FIX" <<'EOF'
gate     | unit  | required | . | printf 'Tests  2 failed, 45 passed (47)\n'; exit 1
gate     | types | required | . | printf 'error: could not execute process (never executed)\n'; exit 101
evidence | unit  | Tests +[1-9][0-9]* passed
evidence | types | Tests +[1-9][0-9]* passed
EOF
out="$(gates)"; rc=$?
assert_contains "a failure alongside a block is reported as both" "BLOCKED      types" "$out"
assert_eq "and a real failure decides the exit code" "1" "$rc"
assert_contains "RESULT=fail wins in the stamp" "RESULT=fail" \
  "$(cat "$FIX/.claude/state/last-gate-run")"

# An OPTIONAL gate the environment blocked is nobody's decision to make: it was
# never going to stop the story. It warns, like any other optional failure.
write_conf "$FIX" <<'EOF'
gate     | unit  | required | . | printf 'Tests  47 passed (47)\n'
gate     | e2e   | optional | . | printf 'error: could not execute process (never executed)\n'; exit 101
evidence | unit  | Tests +[1-9][0-9]* passed
evidence | e2e   | Tests +[1-9][0-9]* passed
EOF
out="$(gates)"; rc=$?
assert_contains "an optional blocked gate warns" "WARN         e2e" "$out"
assert_contains "and says why"                   "could not launch" "$out"
assert_eq "and the run still passes"             "0" "$rc"

# The built-in patterns describe a process that never started. They cannot
# describe every runner, so a project adds its own - and, like every other line
# in the manifest, an unusable one is refused rather than sitting there looking
# like protection.
write_conf "$FIX" <<'EOF'
gate         | unit | required | . | printf 'FATAL: emulator device offline\n'; exit 7
evidence     | unit | Tests +[1-9][0-9]* passed
blocked-when | unit | emulator device offline
EOF
out="$(gates)"; rc=$?
assert_contains "a project pattern is honoured" "BLOCKED      unit" "$out"
assert_eq "and exits 3"                         "3" "$rc"

write_conf "$FIX" <<'EOF'
gate         | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence     | unit | Tests +[1-9][0-9]* passed
blocked-when | untt | emulator device offline
EOF
out="$(gates --audit)"
assert_contains "a blocked-when naming no gate fails the audit" "names no configured gate" "$out"

write_conf "$FIX" <<'EOF'
gate         | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence     | unit | Tests +[1-9][0-9]* passed
blocked-when | unit |
EOF
out="$(gates --audit)"
assert_contains "a blocked-when with no pattern fails the audit" "has no pattern" "$out"

# ---------------------------------------------------------------------------
describe "the stamp says whether the run was a full one"

# The Stop hook decides whether a phase's gate obligation was met from this
# stamp, and `--fast` and `--gate` write it too. Without this line a `--gate
# unit` could discharge GATES, whose entire job is the full suite.
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
slow     | unit | it is the whole suite under instrumentation
EOF
gates >/dev/null
assert_contains "a full run records FULL=yes" "FULL=yes" "$(cat "$FIX/.claude/state/last-gate-run")"
gates --fast >/dev/null
assert_contains "--fast records FULL=no"      "FULL=no"  "$(cat "$FIX/.claude/state/last-gate-run")"
gates --gate unit >/dev/null
assert_contains "--gate records FULL=no"      "FULL=no"  "$(cat "$FIX/.claude/state/last-gate-run")"

# ---------------------------------------------------------------------------
describe "the manifest must not change under the run"

# PORTED from manga-translator (MT-032 AC-1/AC-2), reported there off a --fast
# run. Upstream had no backstop for it.
# gates.sh parses project.conf into its evidence/floor/waiver/slow tables ONCE
# at start-up and runs the gate commands afterwards. Anything that edits the
# file in between produces a summary whose numbers are each real and whose
# PAIRING never existed - `PASS lint (0s, observed 5, floor 1)` printed as a
# clean pass while the file on disk says `floor | lint | 5`. It was reported off
# a --fast run, which is never recorded, so nothing downstream ever compares it
# to anything: its only consumer is whoever reads the summary and decides the
# phase is healthy.
#
# The race is made deterministic with no sleeps and no second process by letting
# the fixture's own gate command do the editing. That is the same interleaving
# with the timing taken out, and it is why this is testable at all.
set_phase "$FIX" ""

conf_edits_itself() {
  write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Contracts: 5 kept\n'; printf 'floor    | lint | 5\n' >> .claude/harness/project.conf
evidence | lint | Contracts: [1-9][0-9]* kept
floor    | lint | 1
EOF
}

conf_edits_itself
out="$(gates)"; rc=$?
assert_contains "a full run says the manifest changed under it" \
  "config: .claude/harness/project.conf changed while the gates were running" "$out"
assert_contains "and it is a FAIL, not a footnote under a pass" \
  "FAIL         config:" "$out"
assert_contains "and says the summary's pairings may be of no single state" \
  "may not correspond to any single state" "$out"
assert_eq "and the run exits non-zero" "1" "$rc"
case "$out" in
  *"All required gates passed"*) _bad "and does not call it a pass" "it passed anyway: $out" ;;
  *) _ok "and does not call it a pass" ;;
esac

# It was OBSERVED on a --fast run downstream. A check that only ran in full mode would fix
# nothing that was actually reported.
conf_edits_itself
out="$(gates --fast)"; rc=$?
assert_contains "--fast catches it too" \
  "config: .claude/harness/project.conf changed while the gates were running" "$out"
assert_eq "and --fast exits non-zero as well" "1" "$rc"

# Asserted where it can actually regress: these two lines live in
# the same summary/record block the new failure path lands in, so a check that
# exits early takes them with it.
assert_contains "the subset caveat survives the new failure path" \
  "This is a subset, not a verdict. The full run before REVIEW is what judges the story." "$out"
assert_contains "and so does the not-recorded line" \
  "(not recorded in the story: a partial run is not evidence of anything)" "$out"

# A run that was already failing must still report it. The manifest changing is
# a fact about the whole summary, not an alternative to the gates' own verdict.
write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Contracts: 5 kept\n'; printf 'floor    | lint | 5\n' >> .claude/harness/project.conf
gate     | unit | required | . | printf 'Tests  2 failed, 45 passed (47)\n'; exit 1
evidence | lint | Contracts: [1-9][0-9]* kept
evidence | unit | Tests +[1-9][0-9]* passed
floor    | lint | 1
EOF
out="$(gates)"; rc=$?
assert_contains "an already-failing run still reports the manifest change" \
  "config: .claude/harness/project.conf changed while the gates were running" "$out"
assert_contains "and still reports the gate that failed" "FAIL         unit" "$out"
assert_eq "and still exits 1" "1" "$rc"

describe "and it does not fire on a run that changed nothing"

# The false-positive control, and the one that matters: a check that fired
# on every run would satisfy every assertion above and be worth nothing. Nothing
# here touches project.conf after gates.sh has read it, and both modes must stay
# green - including on CI, where these are the only runs that ever happen.
write_conf "$FIX" <<'EOF'
gate     | lint | required | . | printf 'Contracts: 5 kept\n'
evidence | lint | Contracts: [1-9][0-9]* kept
floor    | lint | 1
EOF
out="$(gates)"; rc=$?
assert_contains "an ordinary full run passes" "All required gates passed" "$out"
assert_eq "and exits 0"                       "0" "$rc"
case "$out" in
  *"project.conf changed"*) _bad "an ordinary full run is not accused" "it fired anyway: $out" ;;
  *) _ok "an ordinary full run is not accused" ;;
esac

out="$(gates --fast)"; rc=$?
assert_contains "an ordinary --fast run passes" "All required gates passed" "$out"
assert_eq "and --fast exits 0"                  "0" "$rc"
case "$out" in
  *"project.conf changed"*) _bad "an ordinary --fast run is not accused" "it fired anyway: $out" ;;
  *) _ok "an ordinary --fast run is not accused" ;;
esac

# ---------------------------------------------------------------------------
describe "untracked gated files are named, whole-line, in every run (HARNESS-014, AC-4)"

# The stamp now describes the tree `git commit -a` would make, so a file the
# working tree holds and the commit will not - a stray .patch, a new test nobody
# staged - is judged by the gates and absent from the record. gates.sh names each
# one as `    UNTRACKED  <path>`: four spaces, the word, two spaces, the path,
# nothing after. Matched WHOLE here, by grep -cx, never by the bare word - a
# needle of `UNTRACKED` would be satisfied by the sentence explaining it.
count_line() { printf '%s\n' "$2" | grep -cxF -- "$1"; }   # <exact line> <text>
count_re()   { awk 'BEGIN { re = ARGV[1]; ARGV[1] = "" } $0 ~ re { n++ } END { print n + 0 }' "$1" <<< "$2"; }
fix_commit() { git -C "$FIX" add -A -- . ':!.claude/state' >/dev/null 2>&1
               git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm "$1" >/dev/null 2>&1; }

set_phase "$FIX" ""
git -C "$FIX" checkout -q -- . 2>/dev/null
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
story "$FIX" T-1 GATES </dev/null
fix_commit "clean tree, story in GATES"        # nothing untracked, nothing dirty
set_phase "$FIX" GATES

# One untracked file per class the specimen had, plus the two the rule must
# leave alone: a root docs file and a harness markdown file.
mkdir -p "$FIX/handoff" "$FIX/.claude/commands"
printf 'diff --git a/x b/x\n' > "$FIX/handoff/x.patch"          # source
printf 'test("stray", () => {})\n' > "$FIX/tests/stray.test.ts"  # test
printf '# stray notes\n' > "$FIX/notes.md"                       # docs
printf '# a prompt\n' > "$FIX/.claude/commands/x.md"             # harness markdown

out="$(gates --fast)"; rc=$?
assert_eq "--fast names the stray patch, whole line" 1 "$(count_line '    UNTRACKED  handoff/x.patch' "$out")"
assert_eq "--fast names the stray test, whole line"  1 "$(count_line '    UNTRACKED  tests/stray.test.ts' "$out")"
assert_eq "and exactly those two: one UNTRACKED line per untracked gated file" 2 "$(count_re '^    UNTRACKED  ' "$out")"
assert_eq "AC-4 control: the root docs file is not named"       0 "$(count_re 'UNTRACKED.*notes\.md' "$out")"
assert_eq "AC-4 control: the harness markdown file is not named" 0 "$(count_re 'UNTRACKED.*\.claude/commands/x\.md' "$out")"
assert_contains "and says, in words, that they are not part of the recorded tree" "not part of the recorded tree" "$out"
assert_contains "and names the remedy for a file the story owns: stage it" "git add" "$out"
assert_contains "and the remedy for a stray the user keeps: .git/info/exclude" ".git/info/exclude" "$out"
assert_eq "a --fast run is partial, so it is NOT refused: exit is the gates' own" 0 "$rc"
assert_eq "and its not-recorded line is the ordinary partial-run one" 1 \
  "$(count_re '^\(not recorded in the story: a partial run is not evidence of anything\)$' "$out")"
assert_eq "not a refusal for untracked files" 0 "$(count_re '^\(not recorded: .*untracked gated file' "$out")"

# ---------------------------------------------------------------------------
describe "a full run with an active story refuses to record while anything is named (HARNESS-014, AC-5, Option R)"

# The record says "the gates ran against exactly this tree". While the working
# tree holds a gated file the stamp cannot describe, that sentence is false, so
# the run leaves ## Gate results byte-for-byte alone, says why on one line, and
# exits 1 even though every gate passed. The user's decision, 2026-09-24 (PO-E).
cp "$FIX/docs/backlog/stories/T-1.md" "$FIX/.claude/state/T-1.before"
out="$(gates)"; rc=$?
assert_eq "the full run still names each file" 2 "$(count_re '^    UNTRACKED  ' "$out")"
assert_eq "AC-5: ## Gate results is byte-for-byte unchanged" yes \
  "$(cmp -s "$FIX/.claude/state/T-1.before" "$FIX/docs/backlog/stories/T-1.md" && printf yes || printf no)"
assert_eq "AC-5: nothing claims to have recorded" 0 "$(count_re '^recorded in docs/backlog/stories/T-1\.md' "$out")"
assert_eq "AC-5: one line beginning '(not recorded: ' gives the reason - N untracked gated file(s)" 1 \
  "$(count_re '^\(not recorded: .*2 untracked gated file' "$out")"
assert_eq "AC-5: and the run exits 1 although every gate passed" 1 "$rc"
assert_contains "the gates' own verdict is still printed - the refusal is about the record, not the code" \
  "All required gates passed" "$out"
# PO-F, a contract pin rather than an AC: a refused run must not discharge GATES.
assert_eq "C-4: the stamp of a refused run says FULL=no" 1 \
  "$(count_re '^FULL=no$' "$(tr -d '\r' < "$FIX/.claude/state/last-gate-run")")"

# Precedence: a BLOCKED run that is refused exits 1, not 3 - nothing was recorded
# for a PO decision to stand on.
write_conf "$FIX" <<'EOF'
gate     | unit  | required | . | printf 'Tests  47 passed (47)\n'
gate     | types | required | . | printf 'error: could not execute process (never executed)\n'; exit 101
evidence | unit  | Tests +[1-9][0-9]* passed
evidence | types | Tests +[1-9][0-9]* passed
EOF
out="$(gates)"; rc=$?
assert_contains "a blocked gate is still reported as BLOCKED" "BLOCKED      types" "$out"
assert_eq "C-4: but a refused run exits 1, not 3" 1 "$rc"
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
git -C "$FIX" add .claude/harness/project.conf >/dev/null 2>&1   # the conf only; the strays stay untracked
git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm "conf back to one passing gate" >/dev/null 2>&1

# AC-5: with NO active story - CI, and ci-local.sh's gates step - there is no
# refusal. The files are still named; the exit is the gates' own.
set_phase "$FIX" ""
out="$(gates)"; rc=$?
assert_eq "no active story: the files are still named" 2 "$(count_re '^    UNTRACKED  ' "$out")"
assert_eq "no active story: exit is the gates' own, 0" 0 "$rc"
assert_eq "no active story: the not-recorded line is the ordinary no-story one" 1 \
  "$(count_re '^\(not recorded: no active story' "$out")"
assert_eq "no active story: and there is no refusal for untracked files" 0 \
  "$(count_re '^\(not recorded: .*untracked gated file' "$out")"
set_phase "$FIX" GATES

# AC-5 control (i): once the named files are STAGED, the same run records and
# exits 0, and names nothing.
git -C "$FIX" add handoff/x.patch tests/stray.test.ts >/dev/null 2>&1
out="$(gates)"; rc=$?
assert_eq "AC-5 control: staged, nothing is named"        0 "$(count_re 'UNTRACKED' "$out")"
assert_eq "AC-5 control: staged, the run records"         1 "$(count_re '^recorded in docs/backlog/stories/T-1\.md' "$out")"
assert_eq "AC-5 control: staged, the run exits 0"         0 "$rc"
assert_eq "AC-5 control: and ## Gate results now carries a tree stamp" 1 \
  "$(count_re '^    tree:   [0-9a-f]{40}$' "$(tr -d '\r' < "$FIX/docs/backlog/stories/T-1.md")")"
assert_eq "C-4: the stamp of a recorded run says FULL=yes" 1 \
  "$(count_re '^FULL=yes$' "$(tr -d '\r' < "$FIX/.claude/state/last-gate-run")")"
git -C "$FIX" reset -q -- handoff/x.patch tests/stray.test.ts 2>/dev/null   # untracked again
git -C "$FIX" checkout -q -- docs/backlog/stories/T-1.md 2>/dev/null           # record wiped

# AC-5 control (ii) and AC-6: excluded through .git/info/exclude, the same run
# records and exits 0. This is the remedy the refusal points a user to for a
# stray they mean to keep, so it has to actually work.
cp "$FIX/.git/info/exclude" "$FIX/.claude/state/exclude.before"
printf 'handoff/x.patch\ntests/stray.test.ts\n' >> "$FIX/.git/info/exclude"
out="$(gates)"; rc=$?
assert_eq "AC-6: excluded via .git/info/exclude, nothing is named" 0 "$(count_re 'UNTRACKED' "$out")"
assert_eq "AC-5 control: excluded, the run records"            1 "$(count_re '^recorded in docs/backlog/stories/T-1\.md' "$out")"
assert_eq "AC-5 control: excluded, the run exits 0"            0 "$rc"
git -C "$FIX" checkout -q -- docs/backlog/stories/T-1.md 2>/dev/null

# AC-6 control: with the exclude rule removed, the same files are named again
# and the run is refused again.
cp "$FIX/.claude/state/exclude.before" "$FIX/.git/info/exclude"
out="$(gates)"; rc=$?
assert_eq "AC-6 control: exclude rule removed, both files are named again" 2 "$(count_re '^    UNTRACKED  ' "$out")"
assert_eq "AC-6 control: and the run is refused again" 1 "$rc"

# AC-6, the other ignore file: a .gitignore rule for one stray silences that one
# and only that one. .gitignore is itself gated and tracked, so editing it is an
# ordinary edit the stamp covers - and the record is still refused, because the
# other stray is still there.
printf 'handoff/\n' >> "$FIX/.gitignore"
out="$(gates)"; rc=$?
assert_eq "AC-6: a .gitignore'd stray is not named"      0 "$(count_line '    UNTRACKED  handoff/x.patch' "$out")"
assert_eq "AC-6: while the other stray still is"          1 "$(count_line '    UNTRACKED  tests/stray.test.ts' "$out")"
assert_eq "and the count in the reason says 1, not 2" 1 "$(count_re '^\(not recorded: .*1 untracked gated file' "$out")"
assert_eq "and one stray is enough to refuse"             1 "$rc"
git -C "$FIX" checkout -q -- .gitignore 2>/dev/null

# AC-4 control: with no untracked GATED file - the docs and the prompt still
# untracked - no UNTRACKED line appears at all, and the run records.
rm -rf "$FIX/handoff" "$FIX/tests/stray.test.ts"
out="$(gates)"; rc=$?
assert_eq "AC-4 control: no untracked gated file, no UNTRACKED anywhere in the output" 0 "$(count_re 'UNTRACKED' "$out")"
assert_eq "AC-4 control: and no untracked: lead line either" 0 "$(count_re 'not part of the recorded tree' "$out")"
assert_eq "and the run records" 1 "$(count_re '^recorded in docs/backlog/stories/T-1\.md' "$out")"
assert_eq "and exits 0"         0 "$rc"

rm -f "$FIX/notes.md" "$FIX/.claude/commands/x.md" "$FIX/.claude/state/T-1.before" "$FIX/.claude/state/exclude.before"
git -C "$FIX" checkout -q -- . 2>/dev/null
set_phase "$FIX" ""

# ---------------------------------------------------------------------------
describe "ondemand: a gate marked on request is left out of a full run and of --fast (HARNESS-015, AC-1)"

# `slow` only keeps a gate out of --fast, so a `mutation` gate marked slow still
# ran on every full gates.sh run: every story's GATES and every PR's CI job. On
# HARNESS-014 that class of work was 2h20 of a 7.5h story and found nothing.
# `ondemand | <id> | <why>` says the gate runs only when somebody asks for it -
# `--gate <id>`, or a story that names it in `required_gates` - and a run that
# leaves it out says so on ONE whole line, with the reason and the command.
#
# The gate command writes a MARKER. Whether the command ran is then a fact about
# the filesystem rather than a reading of the summary, and it is asserted on
# both sides: absent after a full run and after --fast, present after --gate and
# after a story escalation.
MARKER="$FIX/.claude/state/mutation-ran"
ONREQ='ON REQUEST   mutation (not run: per-story cost the user declined; bash scripts/gates.sh --gate mutation)'
marker_state() { if [ -e "$MARKER" ]; then printf present; else printf absent; fi; }

write_conf "$FIX" <<'EOF'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | build    | required | . | printf 'Bundled 3 targets\n'
gate     | mutation | optional | . | touch .claude/state/mutation-ran; printf 'Killed 12 of 12 mutants\n'
evidence | unit     | Tests +[1-9][0-9]* passed
evidence | build    | Bundled [1-9][0-9]* targets
evidence | mutation | Killed [0-9]+ of
slow     | build    | a release bundle, which RED and GREEN have no use for
ondemand | mutation | per-story cost the user declined
EOF
story "$FIX" T-1 GATES </dev/null
fix_commit "ondemand fixture: a mutation gate on request"
set_phase "$FIX" GATES

rm -f "$MARKER"
out="$(gates)"; rc=$?
assert_eq "a full run does not execute the on-request gate's command" absent "$(marker_state)"
assert_eq "and reports it once, whole line: ON REQUEST, the reason, and the command that runs it" \
  1 "$(count_line "$ONREQ" "$out")"
assert_eq "it is not reported UNCONFIGURED" 0 "$(count_re '^UNCONFIGURED +mutation' "$out")"
assert_eq "and it is counted in none of ran, unconfigured or known" \
  1 "$(count_re '^All required gates passed \(2 ran, 0 unconfigured, 0 known\)\.$' "$out")"
assert_eq "the run exits 0: the on-request gate does not touch the verdict" 0 "$rc"
assert_eq "and the recorded ## Gate results carries the ON REQUEST line" \
  1 "$(count_line "    $ONREQ" "$(tr -d '\r' < "$FIX/docs/backlog/stories/T-1.md")")"
assert_eq "and the stamp still says FULL=yes: the on-request gate is not part of what a full run judges" \
  1 "$(count_re '^FULL=yes$' "$(tr -d '\r' < "$FIX/.claude/state/last-gate-run")")"

rm -f "$MARKER"
out="$(gates --fast)"; rc=$?
assert_eq "--fast does not execute it either" absent "$(marker_state)"
assert_eq "--fast reports the same ON REQUEST line, once" 1 "$(count_line "$ONREQ" "$out")"
assert_eq "and --fast's skipped list names the slow gate only: on request is reported once, not twice" \
  1 "$(count_line '--fast skipped: build' "$out")"
assert_eq "--fast exits 0" 0 "$rc"

# AC-1 control (i): asked for by name, it runs.
rm -f "$MARKER"
out="$(gates --gate mutation)"; rc=$?
assert_eq "AC-1 control: --gate mutation executes the command" present "$(marker_state)"
assert_eq "and reports it as PASS, with its observed count" 1 "$(count_re '^PASS +mutation \([0-9]+s, observed 12\)$' "$out")"
assert_eq "and prints no ON REQUEST line" 0 "$(count_re '^ON REQUEST ' "$out")"

# AC-1 control (ii): a story that escalates the gate asked for it.
story "$FIX" T-1 GATES <<'EOF'
required_gates: [mutation]
EOF
fix_commit "the story escalates mutation"
rm -f "$MARKER"
out="$(gates)"; rc=$?
assert_eq "AC-1 control: a story with required_gates: [mutation] gets it run on a full run" present "$(marker_state)"
assert_eq "with the existing escalation suffix in the gate header" \
  1 "$(count_line '=== gate: mutation (required (required by story T-1)) ===' "$out")"
assert_eq "and no ON REQUEST line" 0 "$(count_re '^ON REQUEST ' "$out")"
assert_eq "and the run passes with the gate counted as ran" \
  1 "$(count_re '^All required gates passed \(3 ran, 0 unconfigured, 0 known\)\.$' "$out")"
story "$FIX" T-1 GATES </dev/null
fix_commit "the story no longer escalates mutation"

# C-2: on-request is decided before configured-ness. This repository's own
# project.conf declares `mutation` with no command, and after this story it is
# ON REQUEST there rather than UNCONFIGURED.
write_conf "$FIX" <<'EOF'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | mutation | optional | . |
evidence | unit     | Tests +[1-9][0-9]* passed
ondemand | mutation | no tool chosen yet; run it with /audit-mutations
EOF
out="$(gates)"; rc=$?
assert_eq "an on-request gate with no command is ON REQUEST, not UNCONFIGURED" \
  1 "$(count_line 'ON REQUEST   mutation (not run: no tool chosen yet; run it with /audit-mutations; bash scripts/gates.sh --gate mutation)' "$out")"
assert_eq "and UNCONFIGURED does not name it" 0 "$(count_re '^UNCONFIGURED +mutation' "$out")"
assert_eq "and the result counts it in nothing" \
  1 "$(count_re '^All required gates passed \(1 ran, 0 unconfigured, 0 known\)\.$' "$out")"
assert_eq "exit 0" 0 "$rc"

# C-4: --list shows the line beside the gate.
out="$(gates --list)"
assert_contains "--list shows the on-request row with the reason and the command" \
  "on-request: no tool chosen yet; run it with /audit-mutations (run with --gate mutation)" "$out"

# ---------------------------------------------------------------------------
describe "ondemand: an on-request gate cannot be required (HARNESS-015, AC-2)"

# A required gate that no full run ever judges is a hole shaped like a gate.
# The audit refuses the combination, and refuses the two ways an `ondemand`
# line can be empty of meaning - naming no gate, or giving no reason - in the
# words `slow` already uses for the same faults.
write_conf "$FIX" <<'EOF'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | mutation | required | . | printf 'Killed 12 of 12 mutants\n'
evidence | unit     | Tests +[1-9][0-9]* passed
evidence | mutation | Killed [0-9]+ of
ondemand | mutation | per-story cost the user declined
EOF
out="$(gates --audit)"; rc=$?
assert_eq "ondemand on a required gate fails the audit, naming the gate and why" \
  1 "$(count_re '^FAIL +mutation +an on-request gate cannot be required: no full run would ever judge it$' "$out")"
assert_eq "and the audit exits 1" 1 "$rc"
assert_eq "and counts it as a manifest problem" 1 "$(count_re '^1 manifest problem\(s\)\.$' "$out")"

write_conf "$FIX" <<'EOF'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | mutation | optional | . | printf 'Killed 12 of 12 mutants\n'
evidence | unit     | Tests +[1-9][0-9]* passed
evidence | mutation | Killed [0-9]+ of
ondemand | mutatoin | a typo, so the gate it meant runs on every full run
EOF
out="$(gates --audit)"; rc=$?
assert_eq "ondemand naming no configured gate fails the audit" \
  1 "$(count_re '^FAIL +mutatoin +an `ondemand` line names no configured gate$' "$out")"
assert_eq "and exits 1" 1 "$rc"

write_conf "$FIX" <<'EOF'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | mutation | optional | . | printf 'Killed 12 of 12 mutants\n'
evidence | unit     | Tests +[1-9][0-9]* passed
evidence | mutation | Killed [0-9]+ of
ondemand | mutation |
EOF
out="$(gates --audit)"; rc=$?
assert_eq "ondemand with no reason fails the audit" \
  1 "$(count_re '^FAIL +mutation +marked on-request with no reason; say why it is not run per story$' "$out")"
assert_eq "and exits 1" 1 "$rc"

# AC-2 control: the same line on an OPTIONAL gate is what the story asks every
# stack profile to carry, and the audit passes it.
write_conf "$FIX" <<'EOF'
gate     | unit     | required | . | printf 'Tests  47 passed (47)\n'
gate     | mutation | optional | . | printf 'Killed 12 of 12 mutants\n'
evidence | unit     | Tests +[1-9][0-9]* passed
evidence | mutation | Killed [0-9]+ of
ondemand | mutation | per-story cost the user declined
EOF
out="$(gates --audit)"; rc=$?
assert_eq "AC-2 control: the same line on an optional gate passes the audit" 0 "$rc"
assert_eq "and the audit says so" 1 "$(count_re '^Manifest audit passed\.$' "$out")"
assert_eq "and no FAIL names the gate" 0 "$(count_re '^FAIL +mutation' "$out")"

# C-3: "required" means required IN project.conf. A story escalation makes the
# gate required for that story's runs - and runs it, above - without making the
# manifest wrong.
story "$FIX" T-1 GATES <<'EOF'
required_gates: [mutation]
EOF
out="$(gates --audit)"; rc=$?
assert_eq "a story escalation does not make the audit fail: the manifest itself is fine" 0 "$rc"
assert_eq "and no FAIL names the gate" 0 "$(count_re '^FAIL +mutation' "$out")"
story "$FIX" T-1 GATES </dev/null

rm -f "$MARKER"
git -C "$FIX" checkout -q -- . 2>/dev/null
set_phase "$FIX" ""

# ============================================================================
# HARNESS-024: parsing project.conf spawns no process per field
# ============================================================================
#
# gates.sh parsed project.conf with a `sed` trim() and a `cut -d'|'` per field:
# 735 external processes for one `--list` of upstream's own 283-line manifest
# (ea0fba0), 647 of them the same `sed`. The rewrite is pure bash, and it can go
# wrong in four ways, each of which a block below exists to catch:
#
#   * still fork per line, or per padding line        -> AC-1, AC-2 (traces)
#   * parse LESS (skip a table, a kind, a line)       -> AC-3, byte-identity
#   * lose everything after an embedded `|`           -> AC-4, whole values
#   * trim a different character class than [:space:]  -> AC-5, equivalence
#
# Every manifest here is the SYNTHETIC one in fixtures/manifest/ (see _lib.sh),
# never the real .claude/harness/project.conf: this suite ships to consuming
# projects, where an assertion about upstream's manifest values would fail.
# doctor.test.sh holds the doctor.sh and task.sh halves.

_h24="$(mktemp -d 2>/dev/null || mktemp -d -t h024.XXXXXX)"
MFX="$(manifest_fixture)"
trap 'rm -rf "$FIX" "$MFX" "$_h24"' EXIT
crlf_copy "$MANIFEST_FIXTURES/project.conf" "$_h24/crlf.conf"
pad_manifest "$MANIFEST_FIXTURES/project.conf" "$_h24/padded.conf"

describe "HARNESS-024 C-3 instrument: the trace counter counts processes, and only processes"

# The negative control for AC-1's two zeros. A counter that counts nothing
# satisfies "zero sed" and "at most 20" against any implementation, so it is
# first shown counting a trace whose answer is known: three externals (sed, cut,
# tr), a builtin (printf) that must not be counted, and a function (f) that must
# not be counted even though bash -x traces it like a command.
cat > "$_h24/ctl.sh" <<'CTL'
f() { :; }
f
printf 'x\n' | sed 's/x/y/' | cut -c1 >/dev/null
v="$(printf 'ab' | tr a b)"
f
CTL
bash -x "$_h24/ctl.sh" 2> "$_h24/ctl.trace" >/dev/null
_ctl="$(trace_externals "$_h24/ctl.trace" "$_h24/ctl.sh")"
assert_eq "the counter sees the one sed in a trace with one sed" "1" "$(ext_count "$_ctl" sed)"
assert_eq "the counter sees the one cut in a trace with one cut" "1" "$(ext_count "$_ctl" cut)"
assert_eq "a builtin (printf) is not counted as a process"       "0" "$(ext_count "$_ctl" printf)"
assert_eq "a function the script defines is not counted"         "0" "$(ext_count "$_ctl" f)"
assert_eq "and the total is exactly the three externals"         "3" "$(ext_count "$_ctl" TOTAL)"

describe "HARNESS-024 fixtures: the padded copy is the same manifest, 100 lines longer"

# AC-2 compares a manifest with its padded copy. That comparison means nothing
# unless the copy really is 100 lines longer, really carries the tab-indented
# comments AC-2 names, and really means the same thing - checked here by its
# --list output being the golden's, below, in the traced run.
assert_eq "the padded copy is exactly 100 lines longer" \
  "$(( $(awk 'END { print NR }' "$MANIFEST_FIXTURES/project.conf") + 100 ))" \
  "$(awk 'END { print NR }' "$_h24/padded.conf")"
assert_eq "and 20 of the added lines are TAB-indented comments" \
  "$(( $(awk '/^\t#/ { n++ } END { print n + 0 }' "$MANIFEST_FIXTURES/project.conf") + 20 ))" \
  "$(awk '/^\t#/ { n++ } END { print n + 0 }' "$_h24/padded.conf")"
assert_eq "and padding precedes the manifest's last line" \
  "#	gate | pad99 | required | . | exit 1" \
  "$(awk '{ prev = cur; cur = $0 } END { print prev }' "$_h24/padded.conf")"

describe "HARNESS-024 AC-1: --list over the synthetic manifest spawns no sed, no cut, and at most 20 processes"

use_manifest "$MFX" "$MANIFEST_FIXTURES/project.conf"
_list_plain="$(trace_script "$MFX" "$_h24/t.list.plain" gates.sh --list)"
assert_eq "the traced --list exits 0" "0" "$(cat "$_h24/t.list.plain.rc")"
assert_eq "AC-1: tracing --list over the synthetic manifest records zero sed processes" \
  "0" "$(ext_count "$_list_plain" sed)"
assert_eq "AC-1: tracing --list over the synthetic manifest records zero cut processes" \
  "0" "$(ext_count "$_list_plain" cut)"
_total="$(ext_count "$_list_plain" TOTAL)"
if [ "$_total" -le 20 ]; then
  _ok "AC-1: tracing --list over the synthetic manifest records at most 20 external processes"
else
  _bad "AC-1: tracing --list over the synthetic manifest records at most 20 external processes" \
    "counted $_total; by command:
$_list_plain"
fi

describe "HARNESS-024 AC-2: gates.sh spawns no more processes for a longer manifest"

# Each invocation traced over the manifest and over its padded copy. The counts
# must be EQUAL: a parser that still forks per line pays for every padding line.
# The shipped parser fails all three, because each padding line costs a `sed`.
use_manifest "$MFX" "$_h24/padded.conf"
_list_pad="$(trace_script "$MFX" "$_h24/t.list.pad" gates.sh --list)"
same_count "AC-2: gates.sh --list spawns as many processes over the padded manifest as over the plain one" \
  "$_list_plain" "$_list_pad"
printf '%s\nrc=%s\n' "$(cat "$_h24/t.list.pad.out")" "$(cat "$_h24/t.list.pad.rc")" > "$_h24/t.list.pad.golden"
golden_check "and the padded copy lists exactly what the plain one does (the padding means nothing)" \
  "$MANIFEST_FIXTURES/project.list.golden" "$_h24/t.list.pad.golden"

use_manifest "$MFX" "$MANIFEST_FIXTURES/project.conf"
_audit_plain="$(trace_script "$MFX" "$_h24/t.audit.plain" gates.sh --audit)"
use_manifest "$MFX" "$_h24/padded.conf"
_audit_pad="$(trace_script "$MFX" "$_h24/t.audit.pad" gates.sh --audit)"
same_count "AC-2: gates.sh --audit spawns as many processes over the padded manifest as over the plain one" \
  "$_audit_plain" "$_audit_pad"
printf '%s\nrc=%s\n' "$(cat "$_h24/t.audit.pad.out")" "$(cat "$_h24/t.audit.pad.rc")" > "$_h24/t.audit.pad.golden"
golden_check "and the padded copy audits exactly as the plain one does" \
  "$MANIFEST_FIXTURES/project.audit.golden" "$_h24/t.audit.pad.golden"

use_manifest "$MFX" "$MANIFEST_FIXTURES/project.conf"
_run_plain="$(trace_script "$MFX" "$_h24/t.run.plain" gates.sh)"
use_manifest "$MFX" "$_h24/padded.conf"
_run_pad="$(trace_script "$MFX" "$_h24/t.run.pad" gates.sh)"
same_count "AC-2: a full gates.sh run spawns as many processes over the padded manifest as over the plain one" \
  "$_run_plain" "$_run_pad"

describe "HARNESS-024 AC-3: gates.sh prints what it printed before the rewrite, byte for byte"

# Goldens captured from the unchanged gates.sh (ea0fba0) through the same
# _lib.sh functions, over the same fixture: the well-formed manifest, the
# broken one (every --audit failure path), and a CRLF copy of the well-formed
# one. Output and exit status; the full run's `(<N>s` is the only thing
# normalised. This is what stops "parse faster" being done by "parse less".
for _c in project broken crlf; do
  case "$_c" in crlf) _conf="$_h24/crlf.conf" ;; *) _conf="$MANIFEST_FIXTURES/$_c.conf" ;; esac
  use_manifest "$MFX" "$_conf"
  for _m in list audit run; do
    gates_golden "$MFX" "$_m" > "$_h24/$_c.$_m"
    golden_check "AC-3: gates.sh $([ "$_m" = run ] && printf 'full run' || printf -- '--%s' "$_m") over $_c.conf is byte-identical to the pre-rewrite golden" \
      "$MANIFEST_FIXTURES/$_c.$_m.golden" "$_h24/$_c.$_m"
  done
done

describe "HARNESS-024 AC-4: a value containing | is the whole remainder of its line"

# Read out of the AC-3 runs over the well-formed manifest. Each needle is the
# WHOLE value, so a split that stops at the first embedded pipe (`field` where
# `rest` belongs, or `IFS='|' read`) leaves a prefix and fails the match.
_l="$(cat "$_h24/project.list")"; _a="$(cat "$_h24/project.audit")"; _r="$(cat "$_h24/project.run")"
assert_contains "AC-4 -f3-: an evidence regex keeps its alternation" \
  "evidence: Tests +[1-9][0-9]* passed|Checks [0-9]+ ok" "$_l"
assert_contains "AC-4 -f3-: a blocked-when regex keeps all three alternations" \
  "blocked-when: alpha launch failed|beta refused to start|no device here" "$_l"
assert_contains "AC-4 -f3-: a slow reason containing | is kept whole" \
  "slow:     instrumented | about 3x the plain run (left out of --fast)" "$_l"
assert_contains "AC-4 -f3-: a waiver containing | is kept whole" \
  "waiver:   docs build needs a renderer this machine lacks | issue 12" "$_l"
assert_contains "AC-4 -f3-: an ondemand reason containing | is kept whole" \
  "on-request: minutes per mutant | run with --gate mutation (run with --gate mutation)" "$_l"
assert_contains "AC-4 -f3-: a ci-factor whose source contains | is kept whole" \
  "ci-factor: 1.5 | actions run 412 | lint job | step 3" "$_l"
assert_contains "AC-4 -f3-: a ci-factor with an empty second field is kept whole" \
  "ci-factor: 2.5 |  | measured in actions run 413" "$_l"
assert_contains "AC-4 -f5-: a gate command with | and || is listed whole" \
  "lint         required  .      printf 'Checked 5 files|ok\n' | while IFS= read -r l; do printf '%s\n' \"\$l\"; done || exit 1" "$_l"
assert_contains "AC-4 -f5-: and is echoed whole before it runs" \
  "=== gate: lint (required) ===
printf 'Checked 5 files|ok\n' | while IFS= read -r l; do printf '%s\n' \"\$l\"; done || exit 1" "$_r"
assert_contains "AC-4 -f5-: and runs whole, so its evidence is observed and floored" \
  "PASS         lint (Ns, observed 5, floor 3)" "$_r"
assert_contains "AC-4 -f3-: a blocked-when regex matched on its THIRD alternation still names the launch failure" \
  "WARN         e2e (Ns, could not launch: no device here, optional)" "$_r"
# The second level: a ci-factor value re-split into its number (-f1) and its
# source (-f2-). A number taken with `rest` is `1.5 | actions run ...`, not a
# number; a source taken with `field` after an empty second field is empty.
assert_eq "AC-4 second level: the audit accepts every ci-factor (number -f1, source -f2-), and exits 0" \
  "not-a-number:0 no-source:0 rc=0:1" \
  "not-a-number:$(count_re 'is not a number' "$_a") no-source:$(count_re 'has no source' "$_a") rc=0:$(count_re '^rc=0$' "$_a")"
assert_contains "AC-4 second level: a source after an empty second field is still a source" \
  "ci-factor: 2.5 |  | measured in actions run 413" "$_a"

describe "HARNESS-024 C-1: gates.sh's from_field, rest and field are cut's -fN-, trimmed -fN- and trimmed -fN"

# The helpers gates.sh ships, lifted out of it, against `cut -d'|'` itself as
# the oracle, for n = 1..5 over every data line of the manifest and a handful
# of shapes the manifest does not have: no pipe at all (cut returns the line
# whole), fewer fields than n (empty), empty fields, a leading and a trailing
# pipe. AC-6 then holds doctor.sh and task.sh to the same definitions.
{ awk '/\|/ && !/^[[:space:]]*#/' "$MANIFEST_FIXTURES/project.conf"
  printf '%s\n' 'no pipe here' 'a|b' 'a||c' ' x | | y |' '|lead' 'trail|' '  |  '
} > "$_h24/split.in"
: > "$_h24/split.from.oracle"; : > "$_h24/split.rest.oracle"; : > "$_h24/split.field.oracle"
for _n in 1 2 3 4 5; do
  cut -d'|' -f"$_n"- "$_h24/split.in" >> "$_h24/split.from.oracle"
  cut -d'|' -f"$_n"- "$_h24/split.in" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' >> "$_h24/split.rest.oracle"
  cut -d'|' -f"$_n"  "$_h24/split.in" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' >> "$_h24/split.field.oracle"
done
# The result variable is `_got`, not `_v`: bash scopes `local` dynamically, so a
# caller passing the name of one of the helpers' own locals (`_v`, `_t`, `_r`,
# `_i`) has its result assigned to the helper's local and lost. No call site in
# the three scripts uses those names; neither may this test.
_helpers="$(for _f in trim from_field rest field; do extract_fn "$REPO_ROOT/scripts/gates.sh" "$_f"; done)"
for _k in from rest field; do
  ( eval "$_helpers"
    for _n in 1 2 3 4 5; do
      while IFS= read -r _line || [ -n "$_line" ]; do
        _got="<unassigned>"
        case "$_k" in
          from)  from_field "$_n" "$_line" _got ;;
          rest)  rest "$_n" "$_line" _got ;;
          field) field "$_n" "$_line" _got ;;
        esac
        printf '%s\n' "$_got"
      done < "$_h24/split.in"
    done
  ) > "$_h24/split.$_k" 2>/dev/null
done
assert_eq "from_field <n> behaves as cut -d'|' -f<n>- on every input, n = 1..5" \
  "0" "$(disagreements "$_h24/split.from.oracle" "$_h24/split.from")"
assert_eq "rest <n> behaves as the trimmed cut -d'|' -f<n>- on every input, n = 1..5" \
  "0" "$(disagreements "$_h24/split.rest.oracle" "$_h24/split.rest")"
assert_eq "field <n> behaves as the trimmed cut -d'|' -f<n> on every input, n = 1..5" \
  "0" "$(disagreements "$_h24/split.field.oracle" "$_h24/split.field")"

describe "HARNESS-024 AC-5: gates.sh's trim() agrees with the shipped sed form"

trim_inputs "$_h24/trim.in"
trim_oracle "$_h24/trim.in" "$_h24/trim.oracle"
assert_eq "the input set is every manifest line and the six edge cases" \
  "$((TRIM_EDGE + 6))" "$(awk 'END { print NR }' "$_h24/trim.in")"
# Read with bash, not awk or sed: MSYS awk and sed read in text mode and drop
# a carriage return before any pattern sees it, so they cannot tell.
_cr=0; while IFS= read -r _line; do case "$_line" in *$'\r') _cr=$((_cr+1)) ;; esac; done < "$_h24/trim.in"
assert_eq "and exactly one input, the last edge case, ends in a carriage return" "1" "$_cr"
assert_contains "gates.sh defines trim()" "trim()" "$(extract_fn "$REPO_ROOT/scripts/gates.sh" trim)"
apply_trim "$REPO_ROOT/scripts/gates.sh" "$_h24/trim.in" "$_h24/trim.gates"
_d="$(disagreements "$_h24/trim.oracle" "$_h24/trim.gates")"
assert_eq "AC-5: gates.sh trim, printing form, agrees with the sed form on every input" "0" "$_d"
apply_trim "$REPO_ROOT/scripts/gates.sh" "$_h24/trim.in" "$_h24/trim.gates.assign" assign
_d="$(disagreements "$_h24/trim.oracle" "$_h24/trim.gates.assign")"
assert_eq "C-1: gates.sh trim, assigning form (trim \"\$x\" var), agrees with the sed form on every input" "0" "$_d"

# The control that makes the input set mean something: a space-only trim must
# DISAGREE with the oracle on the tab case and the multi-space case. If it did
# not, these inputs could not tell `[:space:]` from a literal space.
( naive() { local s="$1"; s="${s## }"; printf '%s' "${s%% }"; }
  while IFS= read -r l || [ -n "$l" ]; do printf '%s\n' "$(naive "$l")"; done < "$_h24/trim.in"
) > "$_h24/trim.naive"
_differs() { [ "$(line_of "$1" "$2")" != "$(line_of "$1" "$3")" ] && echo differs || echo agrees; }
assert_eq "control: the space-only trim disagrees on the tab-padded input" \
  "differs" "$(_differs "$((TRIM_EDGE + 4))" "$_h24/trim.oracle" "$_h24/trim.naive")"
assert_eq "control: the space-only trim disagrees on the multi-space input" \
  "differs" "$(_differs "$((TRIM_EDGE + 3))" "$_h24/trim.oracle" "$_h24/trim.naive")"

describe "HARNESS-024 AC-6: one parser, in three identical copies, and no sed trim or cut -d'|' left"

# Scoped to the three scripts AC-6 names: lib.sh's own copy of the sed trim is
# the next story's (MT-041), and selftest.sh's trim is already pure bash.
assert_eq "AC-6: no copy of the sed trim body in gates.sh, doctor.sh or task.sh" \
  "gates.sh:0 doctor.sh:0 task.sh:0" \
  "$(for _s in gates doctor task; do printf '%s.sh:%s ' "$_s" "$(grep -cF -- "$TRIM_SED_BODY" "$REPO_ROOT/scripts/$_s.sh")"; done | awk '{ sub(/ $/, ""); print }')"
assert_eq "AC-6: no cut -d'|' in gates.sh, doctor.sh or task.sh" \
  "gates.sh:0 doctor.sh:0 task.sh:0" \
  "$(for _s in gates doctor task; do printf '%s.sh:%s ' "$_s" "$(grep -cF -- "cut -d'|'" "$REPO_ROOT/scripts/$_s.sh")"; done | awk '{ sub(/ $/, ""); print }')"
for _f in trim from_field field rest; do
  _g="$(extract_fn "$REPO_ROOT/scripts/gates.sh" "$_f")"
  _verdict="$([ -n "$_g" ] && printf defined || printf missing)"
  for _s in doctor task; do
    if [ "$(extract_fn "$REPO_ROOT/scripts/$_s.sh" "$_f")" = "$_g" ]; then _verdict="$_verdict same"; else _verdict="$_verdict differs"; fi
  done
  assert_eq "AC-6: $_f() is defined in gates.sh, and doctor.sh and task.sh define it byte-identically" \
    "defined same same" "$_verdict"
done

summary "gates"
