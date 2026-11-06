---
id: HARNESS-091
title: The RUNNING stand-in in mutate.test.sh lives until its block kills it
slug: the-running-stand-in-in-mutate-test-sh-l
epic: 
type: fix
status: in-progress
phase: GREEN
branch: story/HARNESS-091-the-running-stand-in-in-mutate-test-sh-l
depends_on: [HARNESS-094, HARNESS-095]      # the fast pre-PR self-test goes first (user decision, 2026-11-04); both must be DONE
touches: [.claude/tests/_lib.sh, .claude/tests/mutate.test.sh, .claude/tests/run-lock.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

`.claude/tests/mutate.test.sh` (HARNESS-030, "AC-4: a sentinel whose process
is alive is RUNNING", line 889) plants `sleep 30 &` and uses its pid as the
live process behind a RUNNING sentinel. The same process is reused by the AC-6
control and by C-1 (line 901), and killed only after C-1. Its lifetime is a
wall-clock bound the suite never chose: every assertion between the plant and
the kill holds only while 30 s have not passed.

On 2026-11-04 the full `SELFTEST_JOBS=4 bash scripts/selftest.sh` dispatched
at HARNESS-088's GATES took 11,419 s on this Windows host under load and C-1
failed twice (`.claude/state/attest-logs/20261104T014702Z.396343.log`, lines
567-585):

```
    FAIL C-1: HARNESS_MUTATION naming a live sentinel in this tree counts it out, exit 0
         expected: 0
         actual:   1
    FAIL C-1: and says the one in flight is that command's own
         expected: 1
         actual:   0
mutate: 306 passed, 2 failed
```

The AC-6 control just before it still saw the process RUNNING; run alone, the
suite passed 308/308 in 236 s (HARNESS-088 `## Notes`, the self-test entry).
**The cause is not proven.** The candidate, which the log neither confirms nor
rules out, is the 30 s window closing between the AC-4 plant and C-1 under that
load. This story does not need the cause: it removes the window. The stand-in
gets no wall-clock bound at all, lives until the block kills it, reaps itself
if the suite dies without running its EXIT trap, and C-1 states its dependence
on it as a named precondition, so that a stand-in that has gone fails the run
on a line that says so rather than on C-1's own assertion.

This is a defect in a **test**, not in `scripts/mutate.sh`, which is out of
scope. Every path this story writes classifies as `harness`
(`bash scripts/classify.sh .claude/tests/_lib.sh .claude/tests/mutate.test.sh`
prints `harness` for both), so the phase lock permits them in every phase and
the law, not the lock, is what governs the change: assertions written against
code that already exists are earned by mutation (`## Deferred verifications`).

Required gate that would fail if this story's artifact broke: none is
configured in this repository (`project.conf` has no gate lines); the artifact
is judged by the self-test, `bash scripts/selftest.sh mutate`, which CI runs
in full on the PR.

## Acceptance criteria

- **AC-1** — Given the HARNESS-030 block has planted its RUNNING stand-in at
  AC-4 and reused it through the AC-6 control, when the block reaches C-1,
  then an assertion named as C-1's precondition checks that the stand-in is
  still alive (`is_alive` prints `alive`) immediately before C-1's `--check`
  runs. *Control:* with the stand-in made to exit before C-1 (DV-1), that
  precondition is the first red line of the block, ahead of C-1's two
  assertions, and the summary names it.
- **AC-2** — Given a holder started by the new `_lib.sh` helper, when the
  caller inspects it on return, then `kill -0` succeeds; and when the caller
  sends it `kill` and `wait`s, then `kill -0` fails within the test's poll
  bound (10 s, a bound on the observation, not on the holder). *Control:* the
  `kill -0` before the kill succeeds, so "gone" is not the holder never having
  started.
- **AC-3** — Given a holder started from a child shell that then exits
  without killing it (the shape of a suite killed before its EXIT trap runs),
  when the child has exited, then the holder is gone within the same poll
  bound. *Control:* a holder started by the suite itself, whose parent is
  still running, is still alive at the moment the orphaned one is observed
  gone - so "gone" is tied to the parent exiting, not to time passing.
- **AC-4 (run-lock's live holders, added 2026-11-05)** — Given `run-lock.test.sh`
  starts its two live-holder stand-ins (`LIVE1`, `LIVE2`, today `sleep 600 &`
  at lines 225-226) with the AC-2 helper instead of a timed `sleep`, when the
  suite reaches AC-6 "the markers are not a bypass", then an assertion named
  as that block's precondition checks that both are still alive. *Control:*
  with the stand-ins shortened to `sleep 45` through `scripts/mutate.sh`
  (the mutation HARNESS-094 `## Notes` records), the precondition is the
  block's first red line.

## Contract

**Writes:** `.claude/tests/_lib.sh`, `.claude/tests/mutate.test.sh`, `.claude/tests/run-lock.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria do not inherit that: a change to
one of them goes through `## Amendments`.

**C-1. The helper.** `.claude/tests/_lib.sh` gains one function, beside the
existing helpers:

```bash
# hold_until_killed <varname>   Start a process that lives until it is
# signalled or the calling shell ($$) has gone, and put its pid in <varname>.
# No wall-clock bound. The stand-in for a RUNNING mutation (HARNESS-091).
hold_until_killed() {
  local parent=$$
  ( trap 'kill "$s" 2>/dev/null; exit 0' TERM INT
    while kill -0 "$parent" 2>/dev/null; do sleep 1 & s=$!; wait "$s"; done ) </dev/null >/dev/null 2>&1 &
  printf -v "$1" '%s' "$!"
}
```

*Amended in RED (2026-11-06, test-developer):* the subshell's stdin, stdout
and stderr are redirected to `/dev/null`. Measured on this host before the
change: AC-3's `p="$(bash -c '. _lib.sh; hold_until_killed p; printf %s "$p"')"`
took **1,127 ms**, because the holder inherited the command substitution's
pipe and `$( )` returned only once the holder had exited - so the orphan was
already gone before AC-3 could observe it alive or dead, and under DV-2's
mutation (`while :`) the `$( )` would never return and the suite would hang
rather than go red. After the change: 68 ms, the orphan is observably alive on
return and gone 2 s later; under the DV-2 shape, 72 ms, the orphan stays alive
and a `kill` removes it. The helper's comment says why. Everything else in the
block behaves as stated on this host (Git for Windows bash): `$$` in the
subshell is the caller's, `kill` + `wait` reaps it, and an orphan goes within
about a second of its shell exiting.

Semantics pinned: it is called as `hold_until_killed H30_SLEEP`, never in a
`$( )`, so the holder is a direct child of the suite and `wait "$pid"` after
`kill "$pid"` reaps it as today's `kill; wait` does. `$$` inside the subshell
is the suite's pid (bash keeps `$$` across `( )`), so the loop ends within one
second of the suite exiting by any route, EXIT trap or SIGKILL. On `TERM` the
trap kills the current `sleep 1` and exits, so a kill leaves nothing behind;
the one process that can outlive a SIGKILLed holder is a `sleep 1`, for at
most one second, which is the "nothing left behind" this story means. No
`pgrep`/`ps -o ppid` is used anywhere: AC-2 and AC-3 observe the holder's own
pid only, by `kill -0`, because process listing is not portable to Git Bash.

**C-2. The suite.** `.claude/tests/mutate.test.sh`:

- line 889-890, `sleep 30 &` / `H30_SLEEP=$!` become `hold_until_killed
  H30_SLEEP`; the comment at line 536 ("a bounded `sleep 30 &`, killed at the
  end of its block and by the EXIT trap") is rewritten to say the holder has
  no bound and is reaped by the block's `kill`, the EXIT trap (line 546,
  unchanged) and its own loop. Every existing HARNESS-030 assertion is
  unchanged.
- AC-1: immediately before C-1's `out="$( cd "$FIX" && HARNESS_MUTATION=...
  --check 2>&1 )"` (line 901), one new assertion, exactly
  `assert_eq "C-1 precondition: the stand-in planted at AC-4 is still alive" "alive" "$(is_alive "$H30_SLEEP")"`.
- AC-2/AC-3: one new `describe "HARNESS-091 AC-2/AC-3: hold_until_killed
  lives until killed, and reaps itself when its shell has gone"`, placed after
  the HARNESS-030 AC-7 block and before the next `# ====` banner, so it runs
  after the holder's one real use. A local `gone_within <pid> <seconds>`
  polls `kill -0` every 0.2 s up to `<seconds>` and prints `gone` or `alive`.
  AC-3's orphaned holder is started by
  `bash -c '. .claude/tests/_lib.sh; hold_until_killed p; printf %s "$p"'`
  (the child shell's `$$` is the parent that goes away); the control holder is
  started by the suite. The describe kills every holder it started before it
  ends, whatever the assertions said, so a red run strands nothing.
  *Amended in RED (2026-11-06):* the child sources `_lib.sh` by absolute
  path, `bash -c '. "$1"; hold_until_killed p; printf %s "$p"' h91
  "$TESTS_DIR/_lib.sh"`, so it does not depend on the suite's working
  directory; and `gone_within` prints `nopid` for a pid that is not a number,
  so an empty variable cannot pass as a holder that went.
- Every new assertion executes unconditionally (the floor is the executed
  count). Expected: 1 (AC-1) + about 5 (AC-2/AC-3); RED reads the real number
  off `bash scripts/selftest.sh mutate` and raises `floor | mutate | 308` in
  `floors.conf` and the hand copy `mutate 308` in `selftest.test.sh` (line
  542) to it.

**C-2a. Line numbers, refreshed at PLANNED → RED (2026-11-06, tree
`e8845fa`).** The numbers above were taken on 2026-11-04 and the tree has
moved: the plant is `sleep 30 &` / `H30_SLEEP=$!` at **888-889**; C-1's
`--check` is at **916** (C-3's, which this story does not touch, at 926);
the comment is still line 536, the EXIT trap line 546, `is_alive` line 584,
the AC-7 describe 942 and the next `# ====` banner 960. `VERSION` holds
`111 (2026-11-06)`; GREEN takes the next free number when it gets there.

**C-5. The run-lock stand-ins (AC-4).** `.claude/tests/run-lock.test.sh`:

- lines 225-226, `sleep 600 & LIVE1=$!; BG="$BG $LIVE1"` and the `LIVE2`
  twin, become `hold_until_killed LIVE1; BG="$BG $LIVE1"` and
  `hold_until_killed LIVE2; BG="$BG $LIVE2"`. The suite already sources
  `_lib.sh`, and its EXIT cleanup (lines 40-41) kills and waits every pid in
  `BG`, which reaps a holder exactly as it reaped a `sleep`. `DEAD` (line
  227) and `PLANT_STARTED` are untouched. The comment at line 224 says the
  two live ones have no bound.
- AC-4: in the block `describe "AC-6  the markers are not a bypass: the pid
  must be the one the lock records"` (line 513), immediately after
  `reset "$FIX"` and before `plant "$FIX" "$LIVE1" ...` (line 516), one new
  assertion, exactly
  `assert_eq "AC-6 precondition: the two live holders planted at the top are still alive" "alive alive" "$(is_alive "$LIVE1") $(is_alive "$LIVE2")"`.
  `run-lock.test.sh` has no `is_alive`; it gains a local copy of
  `mutate.test.sh`'s one-liner (line 584), placed beside its other helpers,
  rather than a shared one in `_lib.sh`, so `mutate.test.sh`'s own definition
  is not shadowed or duplicated there.
- Every other `run-lock` assertion is unchanged. The floor `run-lock | 140`
  in `floors.conf` and `run-lock 140` in `selftest.test.sh` (line 553) rise
  by the executed count RED measures (expected 141).

**C-3. Typing and phases.** A `fix` whose failing test reproduces the defect:
AC-1's precondition is what the 2026-11-04 run lacked, and DV-1 shows it red
under the defect put back. Test-only, as HARNESS-021 was: RED writes
everything in `**Writes:**` except `VERSION`; **GREEN is a verified no-op**
that the orchestrator checks itself rather than dispatching -
`git diff --stat main...HEAD` names only the five written paths and this story,
and `bash scripts/selftest.sh mutate` is green. The `VERSION` bump is the one
GREEN write: to the number after whatever `.claude/harness/VERSION` holds when
GREEN is reached (107 today, 2026-11-04; HARNESS-092 and HARNESS-093 are
planned alongside and each takes the next free number when it gets there, so
no number is fixed here).

**C-4. Oracle partition.** All **mechanical**: a named assertion line, `alive`
or `gone` from `kill -0`, and an exit status. The 10 s poll bound is settled
(a bound on the observation; a holder loop period of 1 s makes the expected
wait under one second); RED may raise it with a reason, never lower it.

## Deferred verifications

- **DV-1, defect put back (AC-1).** With the holder replaced by a process
  that has already exited, the block MUST go red on the named precondition
  first. Run through `scripts/mutate.sh` against the committed tree:
  `bash scripts/mutate.sh .claude/tests/mutate.test.sh 's/^hold_until_killed H30_SLEEP$/sleep 0 \& H30_SLEEP=$!/' -- bash .claude/tests/mutate.test.sh`.
  Predicted red, in this order: the AC-4 precondition ("the planted pid is a
  live process"), AC-4's RUNNING line, the AC-6 control's two RUNNING lines,
  **"C-1 precondition: the stand-in planted at AC-4 is still alive"**, then
  C-1's two assertions - and the two C-1 lines are the two from the
  2026-11-04 log. The precondition's presence ahead of them is what AC-1
  adds; its absence from the log is the defect. RED cannot own this: the
  suite is what it is writing. **Owner: GATES.**
- **DV-2, earning AC-3.** With the holder's loop condition changed so the
  parent is never checked - `bash scripts/mutate.sh .claude/tests/_lib.sh
  's/while kill -0 "\$parent" 2>\/dev\/null; do/while :; do/' -- bash
  .claude/tests/mutate.test.sh` - AC-3's "orphaned holder is gone" assertion
  MUST go red and AC-2 and the control stay green; the describe's cleanup
  kills the survivor, and `mutate.sh --check` is clean afterwards. Same
  reason RED cannot own it. **Owner: GATES.**

- **DV-3, defect put back (AC-4).** With `run-lock`'s two holders turned
  back into timed sleeps too short for the suite -
  `bash scripts/mutate.sh .claude/tests/run-lock.test.sh 's/^hold_until_killed LIVE\([12]\); BG=/sleep 45 \& LIVE\1=$!; BG=/' -- bash scripts/selftest.sh run-lock` -
  the AC-6 "not a bypass" block MUST go red on **"AC-6 precondition: the two
  live holders planted at the top are still alive"** first, ahead of the
  seven assertions HARNESS-094's `## Notes` records for this mutation (and
  AC-3's live-holder control goes red too, as it did there). The
  precondition's presence ahead of them is what AC-4 adds. RED cannot own
  this: the suite is what it is writing. **Owner: GATES.**
- **Budget.** Three entries, one above `rules.md`'s default: AC-1 and AC-4
  are the same defect put back in two suites, and DV-2 is the law's own
  requirement for AC-3, an assertion written against a helper that exists by
  the time it runs.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-091` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `fable` | planning is the judgement phase - decomposition, the oracle partition, the contract - and planning is what fable is judged best at |
| RED | `test-developer` | `opus` | writing the failing tests, the negative controls and the handoff is development work, and opus is judged the stronger model for it |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |

**Resolved:**

- PLANNED, `lead-po` (orchestrator): Fable 5.1 (`claude-fable-5-1`). RED, `test-developer`: `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own `model:`; no override. 2026-11-06.
- GREEN: no dispatch. A verified no-op plus the VERSION bump, by the orchestrator (Fable 5.1, `claude-fable-5-1`), as C-3 plans. 2026-11-06.
<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1**
  (2026-11-04), dispatched as a `/plan-story` subagent planning HARNESS-091..093
  together; no model override was passed. Context, AC, Contract, Deferred
  verifications and Out of scope were written in this dispatch.

**Oracle partition:** every criterion is mechanical - a named assertion line, `alive`/`gone` from `kill -0`, an exit status. The 10 s poll bound is settled (a bound on the observation, not on the holder); RED may raise it with a reason, never lower it.

## Out of scope

- `scripts/mutate.sh`: the sentinel, `--check`, and their texts are untouched.
- Diagnosing the 11,419 s self-test or the host load behind it; the story
  removes the window, it does not prove the window was the cause.
- Other timed processes in the suite (the SIGPIPE and sixty-line blocks have
  their own bounded commands, and none is reused across blocks). RED notes
  any it finds that is reused the same way, as a candidate follow-up.
- Changing HARNESS-030's assertion texts, which are downstream's verbatim.
- Moving the holder helper into `.claude/hooks/lib.sh` or giving it to
  `scripts/mutate.sh`.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

All shell, in the harness self-test. Level: the suite itself (the defect is
in a test's stand-in process, so the suite is the only level that holds it).

- `mutate.test.sh`, HARNESS-030 AC-4 block: the plant is `hold_until_killed H30_SLEEP` (C-2; no new assertion - AC-4's existing precondition now observes the holder).
- `mutate.test.sh`, before C-1's `--check`: "C-1 precondition: the stand-in planted at AC-4 is still alive" = `alive` (AC-1).
- `mutate.test.sh`, HARNESS-091 describe: "AC-2 precondition: hold_until_killed puts a pid in the variable it is given" - the variable is all digits (AC-2).
- same: "AC-2 control: the holder is alive when hold_until_killed returns" = `alive` (AC-2's control: gone is not never-started).
- same: "AC-2: sent kill and waited for, the holder is gone within 10 s" = `gone` (AC-2).
- same: "AC-3 precondition: the child shell started a holder and printed its pid" - all digits (AC-3).
- same: "AC-3: a holder whose shell exited without killing it is gone within 10 s" = `gone` (AC-3).
- same: "AC-3 control: the suite's own holder, whose shell is still running, is alive at that moment" = `alive` (AC-3's control).
- `run-lock.test.sh`, top: `LIVE1`/`LIVE2` are `hold_until_killed` holders (C-5; observed by the existing AC-3 "live pid really is running" precondition).
- `run-lock.test.sh`, "AC-6 the markers are not a bypass", right after `reset "$FIX"`: "AC-6 precondition: the two live holders planted at the top are still alive" = `alive alive` (AC-4).
- Floors: `mutate` 308 -> 315, `run-lock` 140 -> 141, in `floors.conf` and `selftest.test.sh`'s hand copy.

## Handoff: RED -> GREEN

Written by the test-developer, RED, 2026-11-06. Model: Opus 5.5
(`claude-opus-5-5`), as the agent definition declares; no override.

**GREEN is a verified no-op plus the `VERSION` bump** (C-3). Every test-side
write is done; nothing in `scripts/` was touched. GREEN's only write is
`.claude/harness/VERSION` (it holds `111 (2026-11-06)` today; take the next
free number when you get there).

**Commands.** `bash scripts/selftest.sh mutate run-lock` (both suites, with
the floors audit); `bash .claude/tests/mutate.test.sh` alone for the narrowest
run.

**Files and line ranges** (working tree, uncommitted at hand-off):

- `.claude/tests/_lib.sh` 84-97: new `# --- processes` section with
  `hold_until_killed` and its comment (C-1 as amended: fds to `/dev/null`).
- `.claude/tests/mutate.test.sh` 536-538: the HARNESS-030 header comment
  rewritten (no bound; reaped by the block's kill, the EXIT trap, its own
  loop). 890: `hold_until_killed H30_SLEEP` replaces `sleep 30 &` /
  `H30_SLEEP=$!`. 917: AC-1's precondition, immediately before C-1's
  `--check`. 962-1012: the new describe "HARNESS-091 AC-2/AC-3: ...", after
  the HARNESS-030 AC-7 block and before the HARNESS-059 banner, with
  `gone_within`, the AC-2 holder, the suite-owned control holder, the
  orphaned holder via `bash -c`, and an unconditional cleanup of all three.
- `.claude/tests/run-lock.test.sh` 200-202: local `is_alive`. 227-231:
  comment plus `hold_until_killed LIVE1; BG=...` / `LIVE2`. 521: AC-4's
  precondition right after `reset "$FIX"` in "AC-6 the markers are not a
  bypass".
- `.claude/tests/floors.conf` 51, 62, 1038-1049: floors and the dated note.
- `.claude/tests/selftest.test.sh` 542, 553: the hand copy.

**New assertions and what each pins** (exact texts):

| Assertion | Expected | Pins |
|---|---|---|
| `C-1 precondition: the stand-in planted at AC-4 is still alive` | `alive` | AC-1 |
| `AC-2 precondition: hold_until_killed puts a pid in the variable it is given` | 1 (all digits) | AC-2: the helper sets the named variable |
| `AC-2 control: the holder is alive when hold_until_killed returns` | `alive` | AC-2 control: "gone" is not "never started" |
| `AC-2: sent kill and waited for, the holder is gone within 10 s` | `gone` | AC-2 |
| `AC-3 precondition: the child shell started a holder and printed its pid` | 1 (all digits) | AC-3: the orphan exists |
| `AC-3: a holder whose shell exited without killing it is gone within 10 s` | `gone` | AC-3 |
| `AC-3 control: the suite's own holder, whose shell is still running, is alive at that moment` | `alive` | AC-3 control: gone is tied to the parent exiting |
| `AC-6 precondition: the two live holders planted at the top are still alive` | `alive alive` | AC-4 |

`gone_within <pid> <s>` polls `kill -0` every 0.2 s for up to `<s>` (10, the
settled bound, not raised) and prints `gone`/`alive`; a non-numeric pid prints
`nopid`, so an empty variable cannot pass the two "gone" assertions.

**Measured counts** (local, this Windows host): `mutate` 315 (308 + 7),
`run-lock` 141 (140 + 1), all passed. Floors raised to exactly those.
`bash scripts/selftest.sh lib selftest` also run after the floor edit: 690
executed, all passed (the hand copy agrees with `floors.conf`).

**Attest records.**

    run:      2026-11-06T15:07:38Z
    command:  bash scripts/selftest.sh mutate run-lock
    tree:     48a1f39d5b18ac3075523224bdce89a4bc85955d
    status:   ok
    exit:     0
    duration: 177s
    last:     2 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261106T150738Z.142502.log

    run:      2026-11-06T15:10:59Z
    command:  bash scripts/gates.sh --fast
    tree:     48a1f39d5b18ac3075523224bdce89a4bc85955d
    status:   ok
    exit:     0
    duration: 2s
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261106T151059Z.154552.log

`bash scripts/check-sigpipe.sh`: 0 findings (62 files scanned).
`bash scripts/check-grep-count.sh`: 0 findings.

**Passed on arrival, and RED's one mutation.** Every new assertion passes on
its first run: it is written against a helper written in the same phase. The
one mutation RED owns, predicted to catch exactly one assertion (AC-3's
orphan): the holder records the wrong parent, `$PPID` instead of `$$`. Inside
the suite the parent is then the suite's own parent, still alive, so AC-2 and
the HARNESS-030 / run-lock uses behave as before; the orphan's recorded parent
is the suite, which is alive, so the orphan never goes. Distinct from DV-2
(which removes the parent check entirely). Result: exactly one red, 314/1.

```
$ bash scripts/mutate.sh .claude/tests/_lib.sh 's/local parent=\$\$/local parent=$PPID/' -- bash .claude/tests/mutate.test.sh
=== mutate: .claude/tests/_lib.sh (1 line(s) changed by s/local parent=\$\$/local parent=$PPID/) ===
  92 -   local parent=$$
  92 +   local parent=$PPID

=== mutate: running bash .claude/tests/mutate.test.sh ===
...
  HARNESS-091 AC-2/AC-3: hold_until_killed lives until killed, and reaps itself when its shell has gone
    FAIL AC-3: a holder whose shell exited without killing it is gone within 10 s
         expected: gone
         actual:   alive
...
mutate: 314 passed, 1 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests__lib.sh.20261106T150119Z.114430.bak) ===
  92:   local parent=$$
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**Deferred verifications declined.** DV-1, DV-2 and DV-3 I did not run. Each
mutates the suite or helper written in this phase and is owned by **GATES**
per the story; they stay with GATES. Expected outcomes, as claims for GATES to
confirm: DV-1 - the "C-1 precondition" line red ahead of C-1's two; DV-2 -
only "AC-3: a holder whose shell exited ... is gone within 10 s" red (the
`$( )` returns promptly because of the C-1 amendment, measured 72 ms with the
`while :` shape outside the suite; cleanup kills the survivor), `mutate.sh
--check` clean after; DV-3 - "AC-6 precondition: the two live holders ..." the
first red line of the "not a bypass" block. Note for DV-3: `sleep 45` must
actually expire before that block; on a fast host the run-lock suite reaches
it in roughly 90-120 s (the suite took ~135 s alone here), so it should, but
GATES should read the count off the run rather than assume.

**Contract amendments (in place, in `## Contract`).**

1. C-1: the holder's subshell gets `</dev/null >/dev/null 2>&1`. Measured: as
   written, AC-3's `$(bash -c ...)` took 1,127 ms because the holder held the
   substitution's pipe and `$( )` returned only after the holder exited (so
   AC-3 could not observe it), and under DV-2's mutation it would hang the
   suite instead of going red. With the redirect: 68 ms, orphan observably
   alive on return and gone within 2 s.
2. C-2: the AC-3 child sources `_lib.sh` by absolute path (`"$TESTS_DIR/_lib.sh"`
   passed as `$1`), and `gone_within` prints `nopid` for a non-numeric pid.

No acceptance criterion changed.

**Follow-up candidate.** `.claude/tests/gates.test.sh` line 2794 plants a
`sleep 30 &` (`H30_SLEEP`) as a RUNNING sentinel's process and relies on it
across one full `bash scripts/gates.sh` run before killing it at ~2806. Not
reused across blocks, but the same unchosen 30 s window spans a fixture gates
run, which under host load can exceed it. A one-line move to
`hold_until_killed` would remove it. No other timed background process in
`.claude/tests/` is reused across blocks (`grep -n 'sleep [0-9]* *&'`).

**Observed on Linux only by reasoning, not by run:** `$$` in a `( )`
subshell is the caller's, and an orphaned holder is reparented to init and
reaped, so `kill -0` on it fails once it exits (no zombie). AC-2 `wait`s
before polling, so its holder is reaped and is not a zombie either. CI runs
the full self-test on the PR and is the first Linux observation.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return:
       * which test, what it asserted, and what was wrong with it
       * how the defect was found
       * what it asserts now
       * what earns it, since "watched it fail" cannot apply once the
         implementation exists - the corrected assertion passes on its first
         run and every run after, whether or not it asserts anything: either a
         PROBE (mutate the specific behaviour the test pins, paste the red,
         confirm the revert) or, where the defect was cost rather than
         correctness, a BEFORE/AFTER measurement taken under the gate command -
         not the plain test command, which is the faster one.
         PASTE THE OUTPUT. check-boundaries.sh refuses a PR whose Regressions
         or Gate probes section describes a failure without showing one.
         A result counts only as a block: a line beginning with three
         backticks or three tildes (a fence), or a line indented by exactly
         four spaces. Prose does not count, nor inline code in backticks, nor
         a tab, nor anything inside an HTML comment
       * whether GREEN was a no-op, and the command output proving the source
         was untouched and still passes -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Gate probes

<!-- REQUIRED if this story adds or changes a gate, its command, or its
     evidence line. Omit the section entirely otherwise.
     A gate that has never been observed to fail is not a gate: break the thing
     it guards, run the gate, paste the failure, revert. A result counts
     only as a block: a line beginning with three backticks or three tildes
     (a fence), or a line indented by exactly four spaces. Prose does not
     count, nor inline code in backticks, nor a tab, nor anything inside an
     HTML comment. One block per gate:
       * what was broken, and where
       * the gate output proving it failed
       * confirmation the probe was reverted -->

## Scaffold inventory

<!-- REQUIRED for a bootstrap or chore story that writes production code under
     SCAFFOLD, where nothing forces a test to exist first, and for a spike that
     commits its throwaway code. Omit otherwise.
     One line per production file written, and for anything with behaviour
     rather than configuration, the test that covers it:
       src/core/palette.ts        - src/core/palette.test.ts
       vite.config.ts             - configuration, no behaviour
     check-boundaries.sh refuses the PR if any changed source file is not
     named here. -->

## Notes


- 2026-11-05: scope widened to `run-lock.test.sh` (AC-4, `touches:`), at the
  user's decision while HARNESS-094 was at GATES. That story's full self-test
  failed 7 assertions in run-lock's AC-6 block, and its `## Notes` holds the
  evidence: the suite passes alone (140/140, 87 s), and shortening the
  `sleep 600` stand-ins to 45 s reproduces exactly those 7 failures. The cause
  is not measured. The fix is the same as AC-1..3, and the Contract and DV
  blocks need a line for it when this story is started.
- PO decisions at PLANNED → RED (orchestrator, 2026-11-06):
  1. **AC-4 gets its Contract block (C-5) and its own deferred verification
     (DV-3).** AC-4 was added on 2026-11-05 without either; the `touches:`
     line already named `run-lock.test.sh`, and the `**Writes:**` line now
     does too.
  2. **Line numbers refreshed (C-2a).** HARNESS-089 and HARNESS-090 moved
     nothing in these two suites, but the Contract's numbers were off by one
     at the plant and by fifteen at C-1; they are re-read from tree
     `e8845fa`.
  3. **`is_alive` stays per suite.** `run-lock.test.sh` gets a local copy
     rather than `_lib.sh` gaining one, so `mutate.test.sh`'s definition at
     line 584 is neither shadowed nor duplicated.
  4. **Not already delivered:** `hold_until_killed` appears nowhere in
     `.claude/tests/`, `mutate.test.sh:888` still plants `sleep 30 &`, and
     `run-lock.test.sh:225-226` still plant `sleep 600 &`.
  5. **Required gate:** none is configured; the artifact is judged by the
     `mutate` and `run-lock` suites, which CI runs in full on the PR.
     `required_gates: []` stays, with its note.
  6. `plan.sh conflicts`: CONFLICT with HARNESS-092, 093 and 096 on
     `VERSION`, `floors.conf` and `selftest.test.sh`. Run alone.
  7. **GREEN is planned as a verified no-op plus the VERSION bump** (C-3), so
     it is checked by the orchestrator, not dispatched.
- RED verified by the orchestrator, 2026-11-06.
  - `attest.sh check` said `fresh` for both runs at tree `48a1f39`, so
    neither was re-run. `selftest.sh mutate run-lock`: exit 0,
    `2 harness suite(s) passed.`, 177 s. `gates.sh --fast`: exit 0.
  - Green in RED is this story's planned shape (C-3): it writes only tests,
    and the defect is put back at GATES (DV-1, DV-3).
  - Read the diff: the `_lib.sh` helper, `mutate.test.sh`'s plant, comment,
    C-1 precondition and AC-2/AC-3 describe, and `run-lock.test.sh`'s
    holders, local `is_alive` and AC-6 precondition. All match the Contract
    as amended.
  - Floors: `mutate` 308 → 315, `run-lock` 140 → 141.
  - RED's one mutation (`local parent=$PPID`) turned exactly the one AC-3
    assertion red, `mutate: 314 passed, 1 failed`, restored byte for byte.
    It is pasted in the handoff.
- **C-1 amendment reproduced independently** (2026-11-06). RED said a
  holder started inside `$( )` holds the substitution open until it dies,
  so AC-3 could never see the orphan alive. Checked with a different shape:
  a child shell that starts a holder (a bare `kill -0` loop, no inner
  `sleep`/`wait`) and then lives 3 s. Run in a scratch script.

      plain: substitution returned after 3274 ms (inner child itself lives 3000 ms); orphan pid 168095 alive now? no
      redir: substitution returned after 3208 ms (inner child itself lives 3000 ms); orphan pid 168206 alive now? yes

  Without the redirect, the substitution waited for the holder to die.
  With `</dev/null >/dev/null 2>&1`, it returned when the child exited, and
  the holder was still alive to be observed. The amendment stands.
- Follow-up candidate from RED: `.claude/tests/gates.test.sh:2794` plants
  `sleep 30 &` behind a RUNNING sentinel for one fixture `gates.sh` run. It
  is not reused across blocks, but it is the same unchosen 30 s window.
- GREEN verified by the orchestrator as a no-op, 2026-11-06. Not dispatched
  (C-3). Run directly, not through `attest.sh`, because the orchestrator
  runs a no-op's checks itself.
  - `git diff --stat main...HEAD` before the bump named exactly the five
    test-side paths and this story; nothing under `scripts/` changed.
  - `VERSION`: `111` → `113 (2026-11-06)`. HARNESS-097 merged as #183
    with `112` while this story was in RED, so 112 was taken.

```
mutate: 315 passed, 0 failed
run-lock: 141 passed, 0 failed
assertion floors: all 2 suite(s) met their declared floor (456 assertions executed, 456 declared).
2 harness suite(s) passed.
All required gates passed (0 ran, 5 unconfigured, 0 known).
```

  - **For GATES:** `origin/main` now carries HARNESS-097 (`066c049`), which
    also changed `VERSION`, `floors.conf` and `boundaries.test.sh`. Merge
    `main` into this branch at the start of GATES, before the DVs and the
    gate run, so the records are made on the tree the PR will merge.
