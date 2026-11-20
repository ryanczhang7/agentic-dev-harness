---
id: HARNESS-118
title: The Stop hook sees a gate run in flight
slug: stop-hook-sees-a-gate-run-in-flight
epic: 
type: fix
status: in-progress
phase: GATES
branch: story/HARNESS-118-stop-hook-sees-a-gate-run-in-flight
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/gate-reminder.sh, .claude/tests/gate-reminder.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the gate-reminder suite under its selftest floor, which CI runs in full on the PR
---

## Context

Field report, `fantasy-world-builder`, story WORLD-055: during one full
`bash scripts/gates.sh` run (10-15 minutes) the Stop hook,
`.claude/hooks/gate-reminder.sh`, fired six times, and each time returned
`{"decision":"block"}` demanding `bash scripts/gates.sh`, while that run was
already in progress and held `.claude/state/run.lock`. The orchestrator had
to decline six times with evidence. A second run would have been refused by
the run lock with exit 2, so the hook was demanding something that already
existed and could not be started twice.

The cause is visible in the hook as it stands (release 135). Its blocks
read only the gate stamp `.claude/state/last-gate-run`, and `gates.sh`
writes that stamp at the END of a run. While a run is in flight the stamp
is missing ("has not been run ... at all"), older than the phase change
("happened before the story entered PHASE"), or, in GATES, a previous
partial run's ("was a partial one"). Nothing in the hook reads the run lock.

`scripts/run-lock.sh` (HARNESS-034) is the record of a run in flight:
`gates.sh` takes `<root>/.claude/state/run.lock` before any gate runs and
before the stamp is written, holds it for the whole run, and releases it on
EXIT. The lock is three TAB-separated lines, `pid`, `started`, `command`,
and `command` is `scripts/gates.sh` plus its arguments. `--list` and
`--audit` never take it. `run-lock.sh` already has the readers this needs:
`run_lock_field <file> <key>` and `run_lock_alive <pid>` (`kill -0`), and
`run_lock_full <command>`. Sourcing it defines functions and two globals and
does nothing else.

## Acceptance criteria

In all of these the story is active in GREEN or GATES, the checkout is on
the story's branch, and "a gates lock" is `.claude/state/run.lock` in the
tree the hook judges, whose `command` is `scripts/gates.sh` with or without
arguments.

- **AC-1 (reproduces the report)** - Given GREEN and no gate stamp, when a
  gates lock records a pid that is running, then the hook does not block: it
  prints `"continue":true` with a `systemMessage`, and no `"decision"`. The
  message says a gate run is in flight and names the lock's pid, its
  `started` value and its command, and says its record lands when it exits.
  *(Today the hook blocks with "has not been run".)*
- **AC-2** - Given GATES and a stamp older than the phase change, when a
  gates lock with a running pid exists, then the hook does not block and
  says the run is in flight. The same holds when the stamp is a partial run
  (`FULL=no`).
- **AC-3 (a partial run in flight in GATES)** - Given GATES and a running
  gates lock whose command is `scripts/gates.sh --fast`, then the hook does
  not block, and the message also says that this run is partial and will not
  discharge GATES.
- **AC-4 (dead pid)** - Given GREEN and no stamp, when the gates lock
  records a pid that is not running, then the hook blocks exactly as today
  ("has not been run").
- **AC-5 (another command)** - Given GREEN and no stamp, when the lock
  records a running pid whose command is `scripts/selftest.sh`, then the
  hook blocks exactly as today.
- **AC-6 (unreadable lock)** - Given GREEN and no stamp, when the lock
  exists but records no numeric pid, then the hook blocks exactly as today.
- **AC-7 (no lock)** - Given GREEN and no stamp, with no lock file, the hook
  blocks exactly as today.
- **AC-8 (only blocks are narrowed)** - Given GREEN and a passing stamp
  newer than the phase change, with a running gates lock, the hook is silent
  exactly as it is without the lock: a lock is never a reason to say
  something the hook would not otherwise say.
- **AC-9 (the hook takes nothing)** - After every case above, the lock file
  is byte-for-byte what the test wrote: the hook never takes, rewrites or
  releases the run lock.

## Contract

**Writes:** `.claude/hooks/gate-reminder.sh`, `.claude/tests/gate-reminder.test.sh`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

All three paths classify as `harness`, so the lock permits each in every
phase; who writes what is by role. RED (Test Developer):
`gate-reminder.test.sh`. GREEN (Feature Developer): `gate-reminder.sh` and
`VERSION` (the next free release number when GREEN runs; 136 at PLANNED,
and HARNESS-117, planned in parallel, also bumps it, so whichever merges
second takes the next number).

**C-1. Where the check lives.** Inside `block()`, first, before the
other-branch narrowing: if a gate run is in flight, `warn()` with the
in-flight message followed by the reason the hook would otherwise have
blocked with, and return. Because it lives in `block()`, it covers all three
blocks (missing stamp, stamp older than the phase, partial run in GATES) and
cannot reach any path that does not block (AC-8). The order of the three
blocks, their text and every warn path are unchanged.

**C-2. What counts as in flight.** A function `gate_run_in_flight` in the
hook, returning 0 and setting the pid, started and command it read, only
when all of these hold, else 1:

1. `$HARNESS_ROOT/.claude/state/run.lock` is a regular file;
2. `scripts/run-lock.sh` of the hook's own tree
   (`<dir of the hook>/../../scripts/run-lock.sh`) exists and sources
   cleanly. Sourcing defines functions only; nothing calls
   `run_lock_acquire` or `run_lock_release`;
3. `run_lock_field <lock> pid` is non-empty and all digits;
4. `run_lock_field <lock> command` is `scripts/gates.sh` or starts with
   `scripts/gates.sh ` (a space);
5. `run_lock_alive <pid>`.

Any failure is "not in flight", and the hook blocks as today (AC-4..AC-7).
The lock path is the tree the hook judges (`HARNESS_ROOT`), the helpers come
from the hook's own tree, so a fixture tree needs no copy of `scripts/`.

**C-3. The message.** One paragraph naming the pid, the started value and
the command verbatim, saying its record lands in the story when it exits and
that a second run would be refused by the run lock; when the phase is GATES
and `run_lock_full <command>` is false, one more sentence saying the run is
partial and will not discharge GATES, so a full run is still owed once it
exits. Then a blank line and the reason `block()` was given.

**C-4. Portability.** bash, awk, coreutils. No pipeline in the new code (no
SIGPIPE shape for `check-sigpipe.sh`), no `grep -c`.

**Oracle partition.** All mechanical: block or not, needles in the message,
the lock's bytes.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one defect put back for
the central claim, and one probe against a real line of the tree for the
changed rule. RED cannot run either: the condition does not exist until
GREEN.

- **DV-1, the defect put back (AC-1, AC-2, AC-3).** With the call to
  `gate_run_in_flight` in `block()` made to always fail, the `gate-reminder`
  suite **must** go red on the AC-1, AC-2 and AC-3 assertions and nowhere
  else. Run with `bash scripts/mutate.sh .claude/hooks/gate-reminder.sh
  'EXPR' -- bash scripts/selftest.sh gate-reminder`, expression written at
  GATES against the hook as built. **Owner: GATES.**

  **DV-1 result (GATES, 2026-11-20, run by the orchestrator): PASSED.**
  `gate-reminder` went red on the 14 AC-1..AC-3 assertions and nowhere
  else; the file was restored and verified.

    bash scripts/mutate.sh .claude/hooks/gate-reminder.sh 's/^  if gate_run_in_flight; then$/  if false \&\& gate_run_in_flight; then/' -- bash scripts/selftest.sh gate-reminder
      98 -   if gate_run_in_flight; then
      98 +   if false && gate_run_in_flight; then
        FAIL warns: AC-1: no stamp, a live gates lock
        FAIL continues: AC-1: no stamp, a live gates lock
        FAIL AC-1: the message names the pid
        FAIL AC-1: and when it started
        FAIL AC-1: and its command
        FAIL AC-1: and that its record lands when it exits
        FAIL AC-1: and what it would otherwise have said
        FAIL warns: AC-2: a stamp older than GATES, a live gates lock
        FAIL continues: AC-2: a stamp older than GATES, a live gates lock
        FAIL warns: AC-2: a partial stamp in GATES, a live full run
        FAIL warns: AC-3: a live --fast run in GATES
        FAIL AC-3: and it says that run will not discharge GATES
        FAIL AC-3: and names the command with its argument
        FAIL AC-3: in GREEN a --fast run is not called partial
    gate-reminder: 46 passed, 14 failed
    === mutate: command exited 1; restored (verified byte-for-byte against .../.claude_hooks_gate-reminder.sh.20261120T045544Z.1608897.bak) ===
- **DV-2, the command condition (AC-5).** With C-2's command test widened to
  accept any command, the AC-5 assertion **must** go red. Same command
  shape. **Owner: GATES.**

  **DV-2 result (GATES, 2026-11-20, run by the orchestrator): PASSED.**
  A probe against the real line of the hook: with the command test
  accepting anything, both AC-5 assertions went red and nothing else.

    bash scripts/mutate.sh .claude/hooks/gate-reminder.sh "s/^  case \"\$INFLIGHT_COMMAND\" in scripts\/gates.sh|'scripts\/gates.sh '\*) ;; \*) return 1 ;; esac$/  case \"\$INFLIGHT_COMMAND\" in *) ;; esac/" -- bash scripts/selftest.sh gate-reminder
      91 -   case "$INFLIGHT_COMMAND" in scripts/gates.sh|'scripts/gates.sh '*) ;; *) return 1 ;; esac
      91 +   case "$INFLIGHT_COMMAND" in *) ;; esac
        FAIL blocks: AC-5: a live lock held by selftest.sh
        FAIL blocks: AC-5: a command that only starts with the gates name
    gate-reminder: 58 passed, 2 failed
    === mutate: command exited 1; restored (verified byte-for-byte against .../.claude_hooks_gate-reminder.sh.20261120T045709Z.1615454.bak) ===
    mutate: no stranded mutation; nothing of a previous run is in the tree.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-118` from `.claude/harness/models.conf`.
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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |
| ADJUDICATE | `lead-po` | `fable` | a claim that an acceptance criterion, a threshold or a frozen test is wrong is judged against the contract by a fresh dispatch on different inputs, never by the orchestrator that wants the answer; needed in any phase, so it is last |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
- PLANNED, RED, GREEN, GATES: run inline by the orchestrating session, not dispatched; resolved Opus 5.5 (`claude-opus-5-5`). PLANNED was planned for `lead-po` on `fable` and ran on `opus` instead: the story was cut from a precise field-report brief, and the fresh `fable` judgement was spent on the diff review.
- DIFF-REVIEW round 1: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override.
- DIFF-REVIEW round 2: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override.
## Out of scope

- `scripts/run-lock.sh`, `scripts/gates.sh`: not edited.
- A self-test run in flight (`selftest.sh` holding the lock) is not a gate
  run, writes no stamp, and keeps blocking (AC-5).
- Downstream copies: they pick this up with `bash scripts/refresh-harness.sh`.

## Design notes

## Test plan

Level: the hook's own suite, `.claude/tests/gate-reminder.test.sh`, block
`HARNESS-118`, running the real hook over the suite's fixture. The live pid
is a background `sleep 600` the suite owns (killed at the end and in the
EXIT trap); the dead pid is a `sleep 0` already reaped with `wait`. The lock
is written as `run-lock.sh` writes it, three TAB-separated lines.

| AC | Assertions (name prefix) | Red in RED? |
|---|---|---|
| AC-1 | `warns: AC-1`, `continues: AC-1`, `AC-1: the message names the pid` / `when it started` / `its command` / `when it exits` / `what it would otherwise have said` | **red** (7) |
| AC-2 | `warns: AC-2` x2, `continues: AC-2` | **red** (3) |
| AC-3 | `warns: AC-3`, `AC-3: ... will not discharge GATES`, `... command with its argument`, `AC-3: in GREEN a --fast run is not called partial` | **red** (4) |
| AC-4 | `blocks: AC-4: a gates lock whose pid is not running` | green (unchanged behaviour; earned at GATES only through DV-1's restore, see Handoff) |
| AC-5 | `blocks: AC-5` x2 (selftest.sh; `scripts/gates.shx`) | green (unchanged; earned by DV-2) |
| AC-6 | `blocks: AC-6` x3 (empty pid, non-numeric pid, garbage) | green (unchanged) |
| AC-7 | `blocks: AC-7: no lock file` | green (unchanged) |
| AC-8 | `silent: AC-8` | green (unchanged) |
| AC-9 | `the hook left the lock as written: AC-1/2/4/5/8`, `AC-9: the hook created no lock` | green (no code reads the lock yet) |

## Handoff: RED -> GREEN

Written by the orchestrating session (Opus 5.5, `claude-opus-5-5`), acting
as Test Developer.

**Command.** `bash scripts/selftest.sh gate-reminder` (about one minute).

**Failure, RED, 2026-11-19:** `gate-reminder: 46 passed, 14 failed`. Every
failure is an AC-1, AC-2 or AC-3 assertion, and each fails because the hook
blocks with today's text; that is the right failure: the hook does not read
the lock.

    FAIL warns: AC-1: no stamp, a live gates lock
         it blocked instead: The gate suite has not been run for story T-1 at all. ...
    FAIL continues: AC-1: no stamp, a live gates lock
         it carries a decision: {"decision":"block","reason":"The gate suite has not been run for story T-1 at all. ..."}
    FAIL AC-1: the message names the pid
    FAIL AC-1: and when it started
    FAIL AC-1: and its command
    FAIL AC-1: and that its record lands when it exits
    FAIL AC-1: and what it would otherwise have said
    FAIL warns: AC-2: a stamp older than GATES, a live gates lock
         it blocked instead: The last gate run for story T-1 happened before the story entered GATES, ...
    FAIL continues: AC-2: a stamp older than GATES, a live gates lock
    FAIL warns: AC-2: a partial stamp in GATES, a live full run
         it blocked instead: The last gate run for story T-1 was a partial one - ...
    FAIL warns: AC-3: a live --fast run in GATES
    FAIL AC-3: and it says that run will not discharge GATES
    FAIL AC-3: and names the command with its argument
    FAIL AC-3: in GREEN a --fast run is not called partial
         no in-flight message:
    gate-reminder: 46 passed, 14 failed

**What the tests pin for GREEN.** Needles, in the `systemMessage`: `in
flight`, `pid <pid>`, the `started` value verbatim, the command verbatim,
`when it exits`, and the original block reason (`has not been run`). In
GATES with a non-full command: `will not discharge GATES`; that phrase must
NOT appear in GREEN. Raw output: `"continue":true` and no `"decision"`. The
lock's bytes are compared whole after the hook runs. Not constrained:
function names, wording beyond those needles, where the helpers are sourced
from (C-2 says the hook's own tree).

**Passed on arrival.** AC-4..AC-9 describe today's behaviour and pass now.
They are controls against GREEN over-widening the condition; DV-2 earns
AC-5 by widening the command test and watching it go red. The floor is not
raised (32; the suite now executes 60).
## Regressions

- **R-1 (2026-11-20), from diff review round 1, finding 1 (Route RED).**
  No assertion checked that a FULL run in flight in GATES is not called
  partial; deleting `&& ! run_lock_full "$INFLIGHT_COMMAND"` left the suite
  green. Added `AC-2: a full run in flight in GATES is not called partial`
  in `.claude/tests/gate-reminder.test.sh`. Written against a hook that
  already exists, so earned by one mutation of the line it pins:

    bash scripts/mutate.sh .claude/hooks/gate-reminder.sh 's/^    if \[ "\$PHASE" = GATES \] \&\& ! run_lock_full "\$INFLIGHT_COMMAND"; then$/    if [ "$PHASE" = GATES ]; then/' -- bash scripts/selftest.sh gate-reminder
      100 -     if [ "$PHASE" = GATES ] && ! run_lock_full "$INFLIGHT_COMMAND"; then
      100 +     if [ "$PHASE" = GATES ]; then
        FAIL AC-2: a full run in flight in GATES is not called partial
    gate-reminder: 60 passed, 1 failed
    === mutate: command exited 1; restored (verified byte-for-byte against .../.claude_hooks_gate-reminder.sh.20261120T050334Z.1625259.bak) ===
    mutate: no stranded mutation; nothing of a previous run is in the tree.

## Diff review

### Round 1 (2026-11-20)

`lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2
(`claude-fable-5-2`); no override reported. Changed no file.

Found sound: sourcing `run-lock.sh` collides with nothing in the hook or
`lib.sh`; helpers from the hook's own tree, lock from `HARNESS_ROOT`; a
consumer without `run-lock.sh` gets the old block; the three blocks, their
order and text, and every warn path are unchanged; no pipeline, `set -u`
safe, bash 3.2; pid, started and command go through `json_escape`;
`run_lock_full` matches how `gates.sh` computes `FULL=no`; the test's
background sleep cannot hold the output pipe and is killed by the trap;
every "any doubt" path blocks as before.

1. **Should fix: nothing fails if a full run in GATES is called partial**
   (`gate-reminder.test.sh`, AC-2; `gate-reminder.sh:100`). The suite
   checked the partial sentence present for `--fast` in GATES and absent in
   GREEN, never absent for a full run in GATES. Fix: one assertion, earned
   by one mutation. **Route: RED.** Done: R-1.
2. **Nice to have: a stale lock whose pid was reused switches the block
   off** (`gate-reminder.sh:92,102`). `kill -0` answers "some process of
   this user has that number". After a hard kill plus pid reuse the hook
   would say "nothing to run now" on every stop. `check-boundaries.sh` still
   refuses a PR with no gate record. Fix: add the sentence
   `run_lock_refuse` uses, if pid N is not that run, delete
   `.claude/state/run.lock`. **Route: GATES.**

Not checked: whether `kill -0` on Windows sees a `gates.sh` started from a
different Git Bash process tree; if not, the hook blocks as before (the safe
direction).

Verdict: Ship.

### Round 2 (2026-11-20)

`lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2
(`claude-fable-5-2`); no override reported. Changed no file. Reviewed
`a411ab3..a93eca3` and the whole story diff.

Found sound: R-1's needle `will not discharge` occurs only in the partial
sentence, and its three arms make an empty message a failure; it leaves its
neighbours' fixture state alone; the stale-lock sentence breaks no existing
assertion, interpolates only the digit-checked pid, and mirrors
`run_lock_refuse` (`scripts/run-lock.sh:75`); no other file reads the
message. Ran `bash scripts/selftest.sh gate-reminder`: 61 passed, 0 failed.

1. **Nice to have: nothing fails if the stale-lock sentence is deleted**
   (`gate-reminder.sh:103`). Advice text, not a decision. Fix: one
   `assert_contains` beside the AC-1 message assertions. **Route: RED.**
   Not taken: optional, and the hook's decisions are all pinned; left as a
   follow-up (Notes).

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-20T05:09:17Z
    commit: 77bf9da
    tree:   c986d1955c33911031c99fca846b55cea771e9ef
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

## Notes

- **PLANNED, 2026-11-19.** Planned by the orchestrating session itself
  (Opus 5.5, `claude-opus-5-5`), from a field report relayed by the
  fantasy-world-builder session with the user's approval to fix it upstream.
  HARNESS-117 was taken (worktree `D:\adh-HARNESS-117`, PLANNED, unpushed),
  so this is 118; checked against `origin/main`, the remote branches and
  open PRs the same day.
- **Follow-up, not taken (diff review round 2, finding 1).** No assertion
  pins the in-flight message's stale-lock hint. Optional; the hook's
  decisions are all pinned.
- **VERSION.** 136 here; HARNESS-117 (planned in parallel) bumps it too,
  so whichever merges second takes 137.
