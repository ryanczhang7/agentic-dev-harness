---
id: HARNESS-091
title: The RUNNING stand-in in mutate.test.sh lives until its block kills it
slug: the-running-stand-in-in-mutate-test-sh-l
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-091-the-running-stand-in-in-mutate-test-sh-l
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/_lib.sh, .claude/tests/mutate.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
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

## Contract

**Writes:** `.claude/tests/_lib.sh`, `.claude/tests/mutate.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

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
    while kill -0 "$parent" 2>/dev/null; do sleep 1 & s=$!; wait "$s"; done ) &
  printf -v "$1" '%s' "$!"
}
```

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
- Every new assertion executes unconditionally (the floor is the executed
  count). Expected: 1 (AC-1) + about 5 (AC-2/AC-3); RED reads the real number
  off `bash scripts/selftest.sh mutate` and raises `floor | mutate | 308` in
  `floors.conf` and the hand copy `mutate 308` in `selftest.test.sh` (line
  542) to it.

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

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched, and which AC each test covers
       * the EXPORT SHAPE the tests already pin: every module they import, the
         exact exported names and signatures, and the types the assertions
         destructure. Not a suggestion - a test already imports them, so a
         wrong guess is a compile error. Say what the tests do NOT constrain
         too, so it stays the implementer's choice.
       * any test that passed on arrival, and the probe or negative control
         that earns it
       * the EXPECTED VALUE of every negative control, as a table: threshold,
         candidate range, and the number the control measured. In RED the
         suite fails at import, so no assertion in it has run - the controls
         are claims until GREEN confirms them against the shipped module
       * anything discovered that changes the approach -->

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

