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
trap 'rm -rf "$FIX"' EXIT

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

summary "mutate"
