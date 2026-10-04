#!/usr/bin/env bash
# Tests for scripts/mutate.sh - the sanctioned diagnostic mutation.
#
# The harness requires mutations it did not provide a way to make. A test
# written or corrected while the implementation already exists passes on its
# first run and every run after, whether or not it asserts anything, and the
# only way to earn it is to break the production behaviour it claims to pin and
# watch that one assertion go red. rules.md demands that. rules.md also says
# never to route around the phase lock, and production source is frozen in RED,
# which is exactly when a corrected test needs earning.
#
# Every agent resolved that privately with `sed -i`, which the lock let through
# because it discarded any target containing `$`. Three source files were
# mutated that way in one corrective RED pass. And the one mutation done in a
# phase where source WAS writable lost its backup, because the shell it ran in
# had no $TMPDIR, so the restore depended on the substitution happening to be an
# exact inverse of a single-occurrence match. It was. That is the whole reason
# this script exists: the restore must be a fact, not a coincidence.

. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

FIX="$(make_project_fixture)"
# W holds what HARNESS-029's blocks record outside the fixture: what a command
# saw, and bash -x traces. Outside src/ so that nothing it writes is a source
# write, and removed with the fixture.
W="$(mktemp -d 2>/dev/null || mktemp -d -t h029.XXXXXX)"
trap 'chmod 644 "$FIX/src/main.ts" 2>/dev/null; rm -rf "$FIX" "$W"' EXIT

SRC="$FIX/src/main.ts"
ORIGINAL='export const clamp = (v) => Math.min(90, v)'

reset_src() { printf '%s\n' "$ORIGINAL" > "$SRC"; }

mutate() { ( cd "$FIX" && bash scripts/mutate.sh "$@" 2>&1 ); }

sha() { git -C "$FIX" hash-object "$1"; }

# ---------------------------------------------------------------------------
describe "the command sees the mutation"

reset_src
before="$(sha "$SRC")"
out="$(mutate src/main.ts 's/90/-90/' -- grep -c -- '-90' src/main.ts)"; rc=$?
assert_contains "the mutated file is what the command reads" "1" "$out"
assert_eq "and the command's exit code is passed through" "0" "$rc"
assert_eq "and the file is byte-identical afterwards" "$before" "$(sha "$SRC")"
assert_contains "and it says the restore was verified" "restored" "$out"
assert_contains "and prints the line it put back" "Math.min(90, v)" "$out"

# ---------------------------------------------------------------------------
describe "a failing command is the point, not an error"

# This is the shape the harness actually asks for: mutate the behaviour, watch
# the one assertion that pins it go red, revert. The red is the evidence, so a
# non-zero exit must not be treated as the script failing.
reset_src
before="$(sha "$SRC")"
out="$(mutate src/main.ts 's/90/-90/' -- sh -c 'exit 1')"; rc=$?
assert_eq "the command's failure is reported as its own" "1" "$rc"
assert_eq "and the file is still restored"               "$before" "$(sha "$SRC")"
assert_contains "and the exit code is stated plainly"    "exited 1" "$out"

# A command that cannot even start is not a reason to leave the tree mutated.
reset_src
before="$(sha "$SRC")"
mutate src/main.ts 's/90/-90/' -- no-such-command-here >/dev/null 2>&1
assert_eq "restored after a command that never ran" "$before" "$(sha "$SRC")"

# ---------------------------------------------------------------------------
describe "a mutation that mutates nothing proves nothing"

# An expression that matches nothing leaves the file identical, the command
# green, and the agent with a passing test it believes it has earned. That is
# worse than no probe at all, so it is refused before the command runs.
reset_src
before="$(sha "$SRC")"
rm -f "$FIX/ran-marker"
out="$(mutate src/main.ts 's/NOT_IN_THE_FILE/x/' -- touch ran-marker)"; rc=$?
assert_contains "it says the expression changed nothing" "changed nothing" "$out"
assert_eq "and exits 3"                                  "3" "$rc"
assert_eq "and the file is untouched"                    "$before" "$(sha "$SRC")"
if [ -e "$FIX/ran-marker" ]; then
  _bad "and the command never ran" "ran-marker exists"
else _ok "and the command never ran"; fi

# ---------------------------------------------------------------------------
describe "how much it changed is reported, because one line is the useful case"

reset_src
printf 'const a = 90\nconst b = 90\n' >> "$SRC"
out="$(mutate src/main.ts 's/90/-90/g' -- true)"
assert_contains "it counts the changed lines" "3 line(s)" "$out"
reset_src

# ---------------------------------------------------------------------------
describe "usage errors happen before anything is touched"

rm -f "$FIX/ran-marker"
out="$(mutate src/nope.ts 's/a/b/' -- touch ran-marker)"; rc=$?
assert_contains "a file that does not exist" "no such file" "$out"
assert_eq "exits 2"                          "2" "$rc"

out="$(mutate src/main.ts 's/90/-90/')"; rc=$?
assert_contains "no -- and no command" "-- <command>" "$out"
assert_eq "exits 2"                    "2" "$rc"

out="$(mutate src/main.ts 's/90/-90/' --)"; rc=$?
assert_contains "-- with nothing after it" "-- <command>" "$out"
assert_eq "exits 2"                        "2" "$rc"

out="$(mutate src/main.ts '' -- true)"; rc=$?
assert_contains "an empty expression" "expression" "$out"
assert_eq "exits 2"                   "2" "$rc"

if [ -e "$FIX/ran-marker" ]; then
  _bad "no command ran on any usage error" "ran-marker exists"
else _ok "no command ran on any usage error"; fi

# ---------------------------------------------------------------------------
describe "a restore that cannot be verified is loud, and keeps the backup"

# The one failure mode that must never be quiet. If the file cannot be put back
# byte-for-byte, an agent that reads "restored" and moves on has left a mutation
# in the tree with a green suite ahead of it.
reset_src
out="$(mutate src/main.ts 's/90/-90/' -- sh -c 'rm -f .claude/state/mutations/*.bak')"; rc=$?
assert_contains "it says the restore failed" "COULD NOT RESTORE" "$out"
assert_eq "and exits 90, whatever the command did" "90" "$rc"

# ---------------------------------------------------------------------------
describe "it refuses to mutate the script that is running"

# Found by using this script on this repository. bash reads a script
# incrementally rather than loading it whole, so rewriting mutate.sh while
# mutate.sh is executing changes what the interpreter reads next: the run dies
# somewhere in the middle and the restore - the last thing it does - never
# happens. The mutation is then left in the tree with nothing to say so, which
# is the exact failure this script exists to make impossible.
before="$(sha "$FIX/scripts/mutate.sh")"
out="$(mutate scripts/mutate.sh 's/ROOT=/R00T=/' -- true)"; rc=$?
assert_contains "it says why" "cannot mutate itself" "$out"
assert_eq "and exits 2"                   "2" "$rc"
assert_eq "and the script is untouched"   "$before" "$(sha "$FIX/scripts/mutate.sh")"

# The same by absolute path, which is how it would arrive from a script.
out="$(mutate "$FIX/scripts/mutate.sh" 's/ROOT=/R00T=/' -- true)"; rc=$?
assert_eq "an absolute path is the same file" "2" "$rc"
assert_eq "and still untouched"               "$before" "$(sha "$FIX/scripts/mutate.sh")"

# ---------------------------------------------------------------------------
describe "the log is what the story quotes"

reset_src
LOG="$FIX/.claude/state/mutations/log"
rm -f "$LOG"
mutate src/main.ts 's/90/-90/' -- sh -c 'exit 1' >/dev/null 2>&1
log="$(cat "$LOG" 2>/dev/null)"
assert_contains "the file"            "src/main.ts" "$log"
assert_contains "the expression"      "s/90/-90/"   "$log"
assert_contains "the command"         "exit 1"      "$log"
assert_contains "the command's code"  "exited 1"    "$log"
assert_contains "and the restore"     "restored"    "$log"

# ---------------------------------------------------------------------------
describe "it works with the phase lock on, in every phase"

# The point of the script. In RED source is frozen and this is still allowed,
# because the file it names is put back before the command that follows it.
for ph in RED GREEN GATES REVIEW; do
  set_phase "$FIX" "$ph"
  reset_src
  before="$(sha "$SRC")"
  mutate src/main.ts 's/90/-90/' -- true >/dev/null 2>&1
  assert_eq "restored in $ph" "$before" "$(sha "$SRC")"
done
set_phase "$FIX" ""


# ---------------------------------------------------------------------------
describe "a reader that leaves early does not strand the backup"

# FOUND IN USE, not by review. `bash scripts/mutate.sh ... | head -12` is how
# this script is actually invoked when the command under it is chatty - it is
# how the orchestrator invoked it a dozen times during releases 37-45. `head`
# closes the pipe after its count, the script takes SIGPIPE while printing the
# restore confirmation, and dies AFTER restoring but BEFORE `rm -f $NEW $BAK`
# and before the log append.
#
# The file is fine. What is left behind is a `.bak` and no log line - and
# `rules.md` tells the reader, in as many words, that a `.bak` left under
# `mutations/` means a restore FAILED and the script exited 90 saying so. So
# the one artefact that is supposed to mean "something went wrong" is produced
# routinely by something that went right, and the log that would contradict it
# is missing for the same reason.
#
# Three stale backups sat in this repository's own mutations directory when
# this was found, all benign, all from piping into `head`.
#
# The trap covered EXIT INT TERM and not PIPE, which is why none of the
# cleanup ran. This is the SIGPIPE class of check-sigpipe.sh, in the tool the
# non-negotiables name as the sanctioned way to probe.
reset_src
rm -f "$FIX"/.claude/state/mutations/*.bak "$FIX"/.claude/state/mutations/*.new 2>/dev/null
before_baks="$(ls "$FIX"/.claude/state/mutations/*.bak 2>/dev/null | wc -l | tr -d ' ')"
log_before="$(awk 'END { print NR + 0 }' "$FIX/.claude/state/mutations/log" 2>/dev/null || printf 0)"

# The pipeline is the point: a reader that stops after two lines while mutate
# is still printing. `seq` is chatty enough to guarantee that and STOPS ON ITS
# OWN - the first draft used `yes | head`, a writer that only ends when
# something kills it, which hung this suite for hours during a probe. A test
# for a SIGPIPE defect is the last place to put an unbounded writer.
# BOUNDED WITH `timeout`, because the thing this pins can HANG rather than
# misbehave: without the cleanup in on_exit, each SIGPIPE re-enters the trap,
# finds the backup still there, and the cycle never ends. Measured - the probe
# for that line times out rather than failing. A suite that hangs is a worse
# signal than one that fails, so the bound turns it into a failure.
# THE WHOLE PIPELINE IS BOUNDED, not just mutate.sh. A first attempt put
# `timeout` on the script alone and left the subshell and `head` unbounded -
# it passed standalone and hung the FULL selftest, which is the difference
# between a bound on the part you suspect and a bound on the thing you run.
timeout 60 bash -c "cd \"$FIX\" && bash scripts/mutate.sh src/main.ts 's/90/-90/' -- sh -c 'seq 1 200' 2>&1 | head -2" >/dev/null 2>&1 || true

after_baks="$(ls "$FIX"/.claude/state/mutations/*.bak 2>/dev/null | wc -l | tr -d ' ')"
log_after="$(awk 'END { print NR + 0 }' "$FIX/.claude/state/mutations/log" 2>/dev/null || printf 0)"

assert_eq "no backup is stranded when the reader leaves early" \
  "$before_baks" "$after_baks"

# The other half, and the one that makes the first meaningful: the file really
# was restored. A cleanup that ran because the restore never happened would
# satisfy the assertion above and be much worse.
assert_eq "and the source is back to what it was" \
  "$ORIGINAL" "$(cat "$SRC")"

# And the run is still recorded. Losing the log entry is how a stranded backup
# becomes unexplainable: no line saying the command ran, no line saying it
# failed.
# And the run is still recorded. Losing the log entry is how a stranded backup
# becomes unexplainable: no line saying the command ran, no line saying it
# failed. Counted as a DELTA, because the log accumulates across this suite and
# an absolute count would pass or fail on what ran before it.
assert_eq "and the run still reaches the log" "1" \
  "$((log_after - log_before))"

# The control that stops this being satisfied by never writing a backup at all:
# an ordinary run, no pipe, still cleans up and still restores.
reset_src
out="$(mutate src/main.ts 's/90/-90/' -- true)"
assert_eq "an ordinary run leaves no backup either" \
  "0" "$(ls "$FIX"/.claude/state/mutations/*.bak 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "and restores the source" "$ORIGINAL" "$(cat "$SRC")"

# THE CONTROL THAT MATTERS MOST is not written here: it is the existing
# "COULD NOT RESTORE" case above, which deletes the backup mid-command so the
# restore genuinely cannot happen. Fixing this false alarm must not silence
# that real one, and that test asserting exit 90 is what says so. Clobbering
# the file does NOT make a restore fail - mutate.sh copies the backup over it
# regardless - which is a thing this suite already knew and the first draft of
# this block did not.
reset_src

# ===========================================================================
# HARNESS-029: mutate.sh counts what changed, cleans up on every path, and
# survives an early reader. EVERY BLOCK BELOW IS BOUNDED - a pipeline under
# `timeout`, a background run under a polling limit that kills it - because the
# AC-2 block reproduces a HANG on Git Bash, and the warning above about
# unbounded writers applies twice over to a suite about a hang.

MUTDIR="$FIX/.claude/state/mutations"
TAB="$(printf '\t')"

# strays_of <ext>   How many *.<ext> files sit in the mutations directory.
strays_of() { ls "$MUTDIR"/*."$1" 2>/dev/null | wc -l | tr -d ' '; }
strays() { echo $(( $(strays_of bak) + $(strays_of new) )); }
clear_strays() { rm -f "$MUTDIR"/*.bak "$MUTDIR"/*.new "$MUTDIR"/*.diff 2>/dev/null; }
log_count() { awk 'END { print NR + 0 }' "$MUTDIR/log" 2>/dev/null || printf 0; }
last_log() { tail -n 1 "$MUTDIR/log" 2>/dev/null; }

# whole_lines <line> <text>   How many lines of <text> are exactly <line>.
# Anchored on purpose: a floating `1 line(s)` is satisfied by `31 line(s)`.
whole_lines() { grep -cxF -- "$1" <<< "$2"; }
# preview_of <output>   The numbered `  N - ` / `  N + ` lines printed before
# the command runs.
preview_of() { awk '/^=== mutate: running/ { exit } /^  [0-9]+ [-+] / { print }' <<< "$1"; }
# listing_of <output>   Every indented line after the restore verdict - the
# restore listing, and `  ... and K more` when there is one. The commands these
# blocks run print nothing, so nothing else can be indented there.
listing_of() { awk 'f && /^  / { print } /restored \(verified/ { f = 1 }' <<< "$1"; }

# ---------------------------------------------------------------------------
describe "HARNESS-029 AC-1: a target it cannot write is left as it was, with nothing stranded"

# THE METHOD, PROVED BEFORE IT IS RELIED ON: chmod 444 after the fixture is
# written. On Git Bash that sets the Windows read-only attribute and `cp` onto
# the file fails with "Permission denied" (measured 2026-10-04); on a Linux
# runner it fails for any non-root user. A root runner would ignore it, so the
# precondition is an assertion, not an assumption: if `cp` can still write the
# file, this block says so rather than passing for the wrong reason. The
# precondition copies the file's own bytes back onto it, so it changes nothing
# even when it succeeds.
reset_src
clear_strays
before="$(sha "$SRC")"
rm -f "$FIX/ran-marker"
chmod 444 "$SRC"
cp "$SRC" "$W/probe-copy"
if cp "$W/probe-copy" "$SRC" 2>/dev/null; then pre=writable; else pre=refused; fi
assert_eq "AC-1 precondition: after chmod 444, cp onto the target fails on this host" \
  "refused" "$pre"
out="$(mutate src/main.ts 's/90/-90/' -- touch ran-marker)"; rc=$?
chmod 644 "$SRC"
assert_eq "AC-1: a target it cannot write exits 2" "2" "$rc"
assert_eq "AC-1: and says, as a whole line, that the file is unchanged and verified against the backup" 1 \
  "$(whole_lines 'mutate: cannot write src/main.ts; it is unchanged, verified against the backup' "$out")"
assert_eq "AC-1: the file is byte-identical to before" "$before" "$(sha "$SRC")"
assert_eq "AC-1: no .bak is left behind by a run that wrote nothing" 0 "$(strays_of bak)"
assert_eq "AC-1: no .new is left behind by a run that wrote nothing" 0 "$(strays_of new)"
if [ -e "$FIX/ran-marker" ]; then
  _bad "AC-1: the command is not run against a file that was never mutated" "ran-marker exists"
else _ok "AC-1: the command is not run against a file that was never mutated"; fi
rm -f "$FIX/ran-marker"
clear_strays

# ---------------------------------------------------------------------------
describe "HARNESS-029 AC-2: a reader that leaves after one line neither voids the probe nor hangs"

# Reproduced on Git Bash at 3fcd706 (the story's ## Context). The PIPE trap ran
# the restore when the first printf after the mutation hit the closed pipe, so
# the command ran against the ORIGINAL while the log said "exited 0  restored
# (verified)" - and then the run hung in a pipeline writing to the dead reader
# until `timeout` killed it. The two are asserted separately: what the command
# SAW (recorded outside src/, under $W), and timeout's status, where 124 means
# "timeout killed it" and anything else means the pipeline finished.
# THE WHOLE PIPELINE IS UNDER `timeout`, as in the block above and for the same
# reason: a bound on mutate.sh alone left `head` and the subshell unbounded.
reset_src
clear_strays
SEEN="$W/seen.txt"
rm -f "$SEEN"
log_before="$(log_count)"
timeout 60 bash -c "cd \"$FIX\" && bash scripts/mutate.sh src/main.ts 's/90/-90/' -- sh -c 'cat src/main.ts > \"$SEEN\"' 2>&1 | head -1" >/dev/null 2>&1
trc=$?
log_after="$(log_count)"
assert_eq "AC-2: the command saw the MUTATED file, not the original" \
  'export const clamp = (v) => Math.min(-90, v)' "$(cat "$SEEN" 2>/dev/null)"
if [ "$trc" = 124 ]; then
  _bad "AC-2: the pipeline finishes before the 60s timeout" "timeout killed it (status 124): mutate.sh hung after its reader left"
else _ok "AC-2: the pipeline finishes before the 60s timeout"; fi
assert_eq "AC-2: the file is restored" "$ORIGINAL" "$(cat "$SRC")"
assert_eq "AC-2: no .bak or .new is left" 0 "$(strays)"
assert_eq "AC-2: exactly one log line is added" 1 "$((log_after - log_before))"
assert_contains "AC-2: and it records one changed line, exit 0 and a verified restore" \
  "${TAB}src/main.ts${TAB}s/90/-90/${TAB}1 line(s)${TAB}command: sh -c cat src/main.ts > \"$SEEN\"${TAB}exited 0${TAB}restored (verified)" \
  "$(last_log)"
rm -f "$SEEN"

# ---------------------------------------------------------------------------
describe "HARNESS-029 AC-3: TERM while the command runs restores, logs, and leaves nothing"

# bash defers a trapped TERM until its foreground child exits, so the command
# is a short `sleep 3`, not a long one. The TERM goes to mutate.sh's OWN pid,
# read from its backup's name (<safe>.<stamp>.<pid>.bak): on Git Bash the `$!`
# of a backgrounded command is not always the bash running it - measured, a
# backgrounded `bash -c ... > file` was a wrapper whose CHILD was the bash, and
# a TERM to the wrapper reached nothing that had a trap.
# Bounded twice: 20s for the mutation to land, 30s for the run to end once
# signalled. Past either, the run is KILLed and reported, never waited on.
reset_src
clear_strays
log_before="$(log_count)"
( cd "$FIX" && exec bash scripts/mutate.sh src/main.ts 's/90/-90/' -- sh -c 'sleep 3' ) > "$W/term.out" 2>&1 &
wrapper=$!
i=0
while [ "$i" -lt 200 ] && ! grep -qF -- '-90' "$SRC" 2>/dev/null; do sleep 0.1; i=$((i + 1)); done
mpid=""
for b in "$MUTDIR"/*.bak; do
  [ -e "$b" ] || continue
  mpid="${b%.bak}"; mpid="${mpid##*.}"
done
if [ "$i" -lt 200 ] && [ -n "$mpid" ]; then
  _ok "AC-3 precondition: the file was mutated, and mutate.sh's pid known, before TERM"
  kill -TERM "$mpid" 2>/dev/null
else
  _bad "AC-3 precondition: the file was mutated, and mutate.sh's pid known, before TERM" \
    "mutated within 20s: $([ "$i" -lt 200 ] && printf yes || printf no); pid: ${mpid:-unknown}"
  kill -TERM "$wrapper" 2>/dev/null
fi
target="${mpid:-$wrapper}"
j=0
while [ "$j" -lt 300 ] && kill -0 "$target" 2>/dev/null; do sleep 0.1; j=$((j + 1)); done
if [ "$j" -ge 300 ]; then
  kill -KILL "$target" "$wrapper" 2>/dev/null
  _bad "AC-3: the run ends after TERM" "still running 30s after TERM; killed. Output:
$(cat "$W/term.out")"
else _ok "AC-3: the run ends after TERM"; fi
wait "$wrapper" 2>/dev/null
log_after="$(log_count)"
assert_eq "AC-3: the file is restored" "$ORIGINAL" "$(cat "$SRC")"
assert_eq "AC-3: no .new is left" 0 "$(strays_of new)"
assert_eq "AC-3: no .bak is left, because the restore was verified" 0 "$(strays_of bak)"
assert_eq "AC-3: the run writes exactly one log line" 1 "$((log_after - log_before))"
assert_contains "AC-3: and that line records a verified restore" \
  "${TAB}restored (verified)" "$(last_log)"
clear_strays

# ---------------------------------------------------------------------------
describe "HARNESS-029 AC-3 control: a restore that really fails still exits 90 and keeps its backup"

# The cleanup must not silence the one real alarm. The existing COULD NOT
# RESTORE case above deletes the backup itself, so it cannot say whether a
# backup that IS there survives the new cleanup. This one makes the restore
# fail with the backup intact: the command makes the target read-only - AC-1's
# method, whose precondition is asserted above - so `cp` from the backup
# cannot put it back.
reset_src
clear_strays
out="$(mutate src/main.ts 's/90/-90/' -- chmod 444 src/main.ts)"; rc=$?
chmod 644 "$SRC"
assert_eq "control: a restore that cannot happen exits 90" "90" "$rc"
assert_contains "control: and says COULD NOT RESTORE" "COULD NOT RESTORE src/main.ts" "$out"
assert_eq "control: and keeps exactly one .bak" 1 "$(strays_of bak)"
kept=""
for b in "$MUTDIR"/*.bak; do [ -e "$b" ] && kept="$(cat "$b")"; done
assert_eq "control: and that .bak holds the original" "$ORIGINAL" "$kept"
reset_src
clear_strays

# ---------------------------------------------------------------------------
describe "HARNESS-029 AC-4: the count is the lines that changed, not the lines that moved"

# Count rule (the story's AC-4): per hunk, the larger of lines removed and
# lines added, summed over hunks. Each case pins the whole header line, the
# whole preview, and the count in the log line.
FORTY="$FIX/src/forty.txt"
count_case() { # <expr> <count> <preview, newline-joined>
  local expr="$1" n="$2" pv="$3" out
  seq 1 40 > "$FORTY"
  out="$(mutate src/forty.txt "$expr" -- true)"
  assert_eq "AC-4: $expr reports $n line(s) changed, as a whole header line" 1 \
    "$(whole_lines "=== mutate: src/forty.txt ($n line(s) changed by $expr) ===" "$out")"
  assert_eq "AC-4: $expr previews only removed (old number) and added (new number) lines" \
    "$pv" "$(preview_of "$out")"
  assert_contains "AC-4: $expr logs the same count" \
    "${TAB}src/forty.txt${TAB}${expr}${TAB}${n} line(s)${TAB}" "$(last_log)"
}
# One insertion is one line, not every line after it (reported 39 before).
count_case '2s/$/\ninserted/' 1 '  3 + inserted'
# One deletion is one line, not every line after it (reported 35 before).
count_case '5d' 1 '  5 - 5'
# Deleting the last line is one line, not none (reported 0 before).
count_case '$d' 1 '  40 - 40'
# A one-line substitution, which was already right.
count_case 's/^1$/one/' 1 '  1 - 1
  1 + one'
# CONTROL: three separate hunks sum to 3, and the 9 unchanged lines between
# them never count. "Count 1 always" fails here.
count_case 's/^\(10\|20\|30\)$/&x/' 3 '  10 - 10
  10 + 10x
  20 - 20
  20 + 20x
  30 - 30
  30 + 30x'
# CONTROL: two lines joined into one is max(2, 1) = 2 - not the sum (3), and
# not the added side alone (1).
count_case '5{N;s/\n/+/}' 2 '  5 - 5
  6 - 6
  5 + 5+6'
rm -f "$FORTY"

# The existing three-line case, pinned as a whole header line rather than the
# floating `3 line(s)` above, which `13 line(s)` would satisfy.
reset_src
printf 'const a = 90\nconst b = 90\n' >> "$SRC"
out="$(mutate src/main.ts 's/90/-90/g' -- true)"
assert_eq "AC-4: s/90/-90/g on three matching lines still reports 3, as a whole header line" 1 \
  "$(whole_lines '=== mutate: src/main.ts (3 line(s) changed by s/90/-90/g) ===' "$out")"
reset_src
clear_strays

# ---------------------------------------------------------------------------
describe "HARNESS-029 AC-5: the restore listing is capped, and costs the same however much changed"

# 30 separate one-line hunks: every odd line of 60 (GNU sed's first~step
# address, checked on Git Bash's sed 4.9; CI is ubuntu-latest, also GNU).
# The story's Contract said a 40-line file; 1~3 on 40 lines changes 14, and 30
# SEPARATE lines need at least 59 - see the C-3 amendment.
SIXTY="$FIX/src/sixty.txt"
seq 1 60 > "$SIXTY"
out="$(mutate src/sixty.txt '1~2s/$/x/' -- true)"
assert_eq "AC-5: 30 separate changed lines report 30, as a whole header line" 1 \
  "$(whole_lines '=== mutate: src/sixty.txt (30 line(s) changed by 1~2s/$/x/) ===' "$out")"
pv="$(preview_of "$out")"
assert_eq "AC-4: the preview is capped at 20 lines" 20 "$(awk 'END { print NR + 0 }' <<< "$pv")"
exp="$(for n in 1 3 5 7 9 11 13 15 17 19; do printf '  %s: %s\n' "$n" "$n"; done; printf '  ... and 20 more')"
assert_eq "AC-5: the listing is ten restored lines, then exactly '  ... and 20 more'" \
  "$exp" "$(listing_of "$out")"
assert_eq "AC-5: the '  ... and 20 more' line appears once, compared whole" 1 \
  "$(whole_lines '  ... and 20 more' "$out")"

# A pure insertion restores no line, so it lists none.
seq 1 40 > "$FORTY"
out="$(mutate src/forty.txt '2s/$/\ninserted/' -- true)"
assert_eq "AC-5: a pure insertion lists no restored lines" "" "$(listing_of "$out")"
rm -f "$FORTY"

# "Reads the restored file once, not once per line", stated as what it costs:
# the external processes mutate.sh starts, read from a `bash -x` trace
# (_lib.sh's trace_externals), are the same for 1 changed line and for 30.
# Before this story the listing started one awk per changed line.
seq 1 60 > "$SIXTY"
c1="$(trace_script "$FIX" "$W/one" mutate.sh src/sixty.txt 's/^1$/one/' -- true)"
c30="$(trace_script "$FIX" "$W/thirty" mutate.sh src/sixty.txt '1~2s/$/x/' -- true)"
t1="$(ext_count "$c1" TOTAL)"; t30="$(ext_count "$c30" TOTAL)"
if [ -n "$t1" ] && [ "$t1" != 0 ] && [ "$t1" = "$t30" ]; then
  _ok "AC-5: 30 changed lines start no more processes than 1"
else
  _bad "AC-5: 30 changed lines start no more processes than 1" "1 line: $t1 processes; 30 lines: $t30
by command, 1 line:
$c1
by command, 30 lines:
$c30"
fi
rm -f "$SIXTY"
clear_strays

summary "mutate"
