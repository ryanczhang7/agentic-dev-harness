---
id: HARNESS-112
title: The run-queue suite reaches the exit for a queue lock that cannot be removed
slug: the-run-queue-suite-reaches-the-exit-for
epic: 
type: chore
status: in-progress
phase: GATES
branch: story/HARNESS-112-the-run-queue-suite-reaches-the-exit-for
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/run-queue.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the run-queue suite under its selftest floor, which CI runs in full on the PR
---

## Context

A follow-up HARNESS-108 recorded and did not take (its diff review round 2,
"Should fix" 1; HARNESS-111 lists it under Out of scope). This story adds the
missing test and changes no behaviour.

**The exit.** `run_queue_acquire` in `scripts/run-queue.sh` reclaims a queue
lock whose recorded pid is not running, or which records no numeric pid: it
prints one `reclaimed` line, removes the lock and tries again. If the lock is
still there afterwards, with the same pid, it gives up on the queue instead
(lines 228-233 on `a349761`):

    rm -f "$lock" 2>/dev/null
    if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then
      # It could not be removed; trying again would print that line for ever.
      run_queue_without "cannot use $dir" "$self"
      return 0
    fi

**What is missing.** No case in `.claude/tests/run-queue.test.sh` reaches
those lines. With them deleted, a run that meets a lock it cannot remove
prints the reclaim line again and again and never starts, which breaks
HARNESS-108's AC-9 ("a queue it cannot use: one line, and the run runs as it
would have"), and the suite stays green at its floor of 337. The real trigger
is narrow - a lock file the OS will not delete, or one in a directory the
user cannot write - but the cost when it happens is a full run that never
runs, and a later edit can drop the exit unnoticed.

**Why HARNESS-108's first attempt did not reach it.** A directory at the lock
path was tried (HARNESS-108, R-2) and does not get there: `run_queue_link`
now refuses a lock path that is not a regular file before the reclaim code is
reached. The input that does reach it is a regular lock file that `rm` cannot
delete, and the portable way to make one is an `rm` earlier on `PATH` that
refuses that one path (Contract C-2 has why not a read-only directory).

**Measured at PLANNED** (2026-11-16, `a349761`, this Windows host, the shipped
module sourced and `run_queue_acquire /some/root scripts/gates.sh` called
directly, an `rm` shim first on `PATH`). Both ways into the exit are
reachable, and they differ only in the reclaim line printed first:

    lock holds `junk` (no pid):
      run-queue: reclaimed an unreadable queue lock (no pid recorded in <Q>/run-queue.lock).
      run-queue: cannot use <Q>; scripts/gates.sh runs without the machine-wide queue.
      rc=0 held=0, the lock still there and byte-identical

    lock holds a full record whose pid has exited:
      run-queue: reclaimed a stale queue lock from pid <pid> (scripts/selftest.sh ghost, in /ghost/tree); that process is no longer running.
      run-queue: cannot use <Q>; scripts/gates.sh runs without the machine-wide queue.
      rc=0 held=0, the lock still there and byte-identical

With the `if` on line 229 replaced by `if false; then`, the same two inputs
never return: three reclaim lines and nothing else in 30 s for the first, the
call still running when it was killed. Note the rate: one pass round the loop
took about 10 s on this host under load, so "for ever" is a slow repeat, not
a flood (C-4 says which assertions that makes certain).

**Both variants are in scope** (AC-1 and AC-2). They share the exit but not
the way to it: the comparison on line 229 is `"" = ""` for a lock with no
pid and `<pid> = <pid>` for a stale one, and the stale one is the likelier
real case (a dead holder's lock in a directory that has since become
unwritable). The second costs one more fixture run.

**Type and phases.** A `chore`, test-only, as HARNESS-093 and HARNESS-021
were: the tests are written against code that already exists, so they pass
the moment they are written, and DV-1 earns them at GATES. The phase path is
RED (the tests and the floor), a verified no-op GREEN plus the `VERSION`
bump, GATES, REVIEW. SCAFFOLD is not used.

**The required gate.** Every gate is unconfigured in this repository
(`bash scripts/gates.sh --list`), so `required_gates` stays empty, as on
HARNESS-102 to 111. The artifact is judged by the `run-queue` suite under its
self-test floor, which CI runs in full on the PR; the `selftest` suite must
pass unchanged apart from its one floor copy (C-5).

**The epic.** `epic:` is empty, as on every HARNESS story.
**Architecture.** `docs/wiki/architecture.md` does not exist here; the
constraints are `rules.md`, Portability (bash, awk and coreutils, no python)
and bash 3.2 compatibility.

## Acceptance criteria

In both criteria, "the queue" is `$HARNESS_RUN_QUEUE_DIR/run-queue.lock` in
the suite's own temp queue directory (never the host's), "cannot be removed"
means that every attempt the run makes to delete that file fails and leaves
it as it was, "a full run" is the fixture tree's `scripts/gates.sh` with the
queue on, and "the status the same run has alone" is the one the suite
already measures with the queue off. The run is waited for with a bound; a
run that outlives it fails the case and does not hang the suite. The two
`reclaimed` lines and the `cannot use` line are HARNESS-108's, unchanged, and
are compared whole.

- **AC-1** — Given a queue lock that records no pid and cannot be removed,
  when a full run starts, then its stderr carries exactly two lines beginning
  `run-queue:`, in this order: the `reclaimed an unreadable queue lock (no
  pid recorded in <lock>).` line, once, then `run-queue: cannot use <dir>;
  scripts/gates.sh runs without the machine-wide queue.`, once, with `<dir>`
  the queue directory as `HARNESS_RUN_QUEUE_DIR` gives it; the run does its
  work and exits, within the bound, with the status the same run has alone;
  its work saw the lock as it was planted, not a record of its own; and
  afterwards the queue directory holds that lock, byte for byte as planted,
  and nothing else, and the tree holds no run lock.
- **AC-2** — Given a queue lock that records the pid of a process that has
  exited, with a command and a tree root, and cannot be removed, when a full
  run starts, then everything AC-1 says holds, with the first of the two
  lines being instead the `reclaimed a stale queue lock from pid <pid>
  (<command>, in <root>); that process is no longer running.` line naming
  that pid, command and root, once.

*Control, for both.* With the exit taken out of `run_queue_acquire` (the
condition on line 229 made false), the same two arrangements must fail these
criteria: no `cannot use` line, and the run still going at the bound (DV-1).
And in each case the arrangement must show that a removal of the lock was
attempted and refused, so that a case in which `rm` simply succeeded cannot
be read as this one (C-2, the refusal record).

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `.claude/tests/run-queue.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**C-1. Who writes which, and what is not written.** Every path above
classifies as `harness`, so the lock divides nothing and this block does. RED
(test-developer) writes `.claude/tests/run-queue.test.sh`, the suite's new
floor in `floors.conf` and its hand-copied line in `selftest.test.sh` (C-5).
GREEN writes `.claude/harness/VERSION` and nothing else (C-6).
**Not written: `scripts/run-queue.sh`, `scripts/run-lock.sh`,
`scripts/gates.sh`, `scripts/selftest.sh`, `.claude/tests/_lib.sh`,
`docs/backlog/stories/HARNESS-108.md`.** The module is correct as measured;
if RED finds it is not, that is a finding to report, not a line to change
(C-4). `_lib.sh` untouched keeps this story's pre-REVIEW `--changed` run from
resolving to every suite.

**C-2. The `rm` shim.** One file the suite writes into its own temp
directory, in a directory that holds nothing else (suggested `$W/shim/rm`),
executable:

    #!/usr/bin/env bash
    for a in "$@"; do
      case "$a" in */run-queue.lock) printf '%s\n' "$a" >> '<W>/shim/refused'; exit 1 ;; esac
    done
    exec '<real rm>' "$@"

- `<real rm>` is what `command -v rm` answers in the suite's own shell
  before anything is put on `PATH` (`/usr/bin/rm` on this host), written into
  the shim as an absolute path. Every other removal the run makes - its
  temporary record `run-queue.lock.<pid>`, the tree's `run.lock`, the gate
  logs - goes through to it untouched: the pattern ends at `run-queue.lock`,
  so `run-queue.lock.<pid>` does not match.
- It refuses by exiting 1 having removed nothing and printed nothing; the
  module calls `rm -f "$lock" 2>/dev/null` and reads only whether the lock is
  still there.
- **The refusal record** (`refused`, one line per refused call) is the
  case's precondition: each case asserts it holds at least one line naming
  the lock before it asserts anything about the output. Without it, a host
  where the shim was not picked up would show an ordinary reclaim and the
  case would fail for a reason that is not this story's. Whether to pin the
  count at exactly one is RED's choice; the shipped module tries once.
- The shim is on `PATH` **only for the run under test**: prepended in
  `rq_run`'s subshell, never in the suite's own shell, so `new_case`,
  `cleanup` and every other case remove files with the real `rm`. Suggested:
  one more knob beside `RQ_MODE` and its neighbours, `RQ_PATH`, empty by
  default and reset by `rq_defaults`, prepended to `PATH` in `rq_run` when
  set. Adding it changes no existing case. Not constrained: the knob's name,
  or doing it another way that keeps the suite's own `PATH` as it is.
- *Why a shim and not a read-only queue directory.* `chmod` does not stop a
  deletion under Git Bash on Windows, and does not stop root in a CI
  container; a directory at the lock path no longer reaches the exit
  (Context). The shim behaves the same on all three.
- No new dependency: bash and coreutils.

**C-3. The two cases.** Through the fixture tree's `scripts/gates.sh`, as the
`reclaim_case` and `noq_case` cases beside them are, in tree B, queue on,
`RQ_DIR` the suite's `$Q`. One helper taking the label, the pid to plant and
the expected first line is the natural shape (compare `reclaim_case`, line
573). Each case, in order:

1. `new_case`; plant the lock; keep a copy of its bytes and of `qsnap`.
   - AC-1: a lock that records no pid. `qplant ""` (a record with no pid
     line) or a file holding `junk`; either reaches the exit, RED picks one
     and says which. Expected first line: `unread_line "$QL"`.
   - AC-2: `qplant "$DEAD" "$PLANT_STARTED" "scripts/selftest.sh ghost"
     "/ghost/tree"`, the suite's existing dead pid, with its existing
     precondition that `$DEAD` is gone. Expected first line: `stale_line
     "$DEAD" "scripts/selftest.sh ghost" /ghost/tree`.
2. Start `scripts/gates.sh` with the shim on its `PATH`; `wait_bounded` it.
3. Assert, in this order: the refusal record (precondition); `WTO` is `no`;
   the first line, whole, count 1; `cannot_line "$Q" scripts/gates.sh`,
   whole, count 1; exactly 2 lines matching `^run-queue:`; the first of them
   is the reclaim line and the last the `cannot use` line (`rq_lines`); `WRC`
   and `m/k/finished` are `"$SOLO_GATES present"`; the work's copy of the
   lock (`m/k/qlock`) is byte-identical to the planted one; `qsnap` afterwards
   equals `qsnap` before; `leftovers "$B"` is empty.

**The semantics behind each number.**
- *Exactly 2 `run-queue:` lines*: one reclaim line because the module tries
  once, one `cannot use` line because it then stops; a queued or `starting`
  line would mean it waited, a third line that it went round again.
- *The bound, 60 s* (`wait_bounded "$p" 60`, as `noq_case` and
  `reclaim_case` use for the same kind of run): long enough for one fixture
  `gates.sh` on a loaded host, and the whole cost of a case when the exit is
  missing, since nothing else ends that run. RED may raise it with a
  measurement; it is never a claim that the run took N seconds.
- *`<dir>` in the `cannot use` line is `$Q` verbatim*, the value of
  `HARNESS_RUN_QUEUE_DIR`, not the lock's path.
- *`qsnap` unchanged* says three things at once: the lock was not removed,
  not rewritten, and no temporary record was left beside it. No waiter is
  alive when it is read, so `qsnap` and not `qlock` is the right instrument.

Placement, suggested: one `describe` headed `HARNESS-112 AC-1, AC-2  a queue
lock that cannot be removed: the reclaim line once, then one line, and the
run runs`, after HARNESS-111's cases and before the closing "shipped pieces"
describe. Labels begin `HARNESS-112 AC-1` and `HARNESS-112 AC-2`. No matrix
beyond the two cases: not `selftest.sh` as well, not `--changed`; both reach
the same function by the same call.

**C-4. What RED should see, and what is certain under DV-1.** Every new
assertion passes on arrival: `run-queue: <337 + N> passed, 0 failed`. A new
assertion that is red in RED means the fixture is wrong or the module does
not behave as Context measured; RED says which and stops, and does not
change the expectation to match. Under DV-1's mutation, per case, three
assertions are **certain** red: the `cannot use` count (0), `WTO` (`yes`),
and status-and-finished (the run is killed at the bound having run no work).
"Reclaim line exactly once" and "exactly 2 lines" are **likely** red and not
certain: one pass of the loop took about 10 s here under load, so a slow
host may print the line only a few times in 60 s. RED's handoff predicts the
count as a range with the certain ones named.

**C-5. The pin, the floor.** One new source pin in the closing describe, so
that DV-1's expression cannot rot silently: `grep -cxF` of the line

        if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then

(four leading spaces) in `scripts/run-queue.sh` is 1. `run-queue` is floored
at 337 (`floors.conf` line 63, copied by hand at `selftest.test.sh` line
554). RED raises both to the executed count it measures, with a dated
comment at the end of `floors.conf` in the form HARNESS-111's entry uses,
saying that every new assertion is unconditional and passes in RED. No other
floor moves: `selftest` stays 366.

**C-6. GREEN and the release.** GREEN is a verified no-op plus the `VERSION`
bump: `git diff --stat origin/main...HEAD -- scripts/` is empty, `bash
scripts/selftest.sh run-queue` is green at the new floor, and
`.claude/harness/VERSION` goes from `130 (2026-11-16)` to the next free
number with the real date (131 today; whatever follows the file's number if
`main` has moved, re-taken on merging `main` before REVIEW).
`check-boundaries.sh` refuses a harness change that does not bump it.

**C-7. Oracle partition.** Both criteria are **mechanical**: whole lines
(`grep -cxF` through `count_line`), exact counts, exact status, byte
comparisons. The message texts are **settled** by HARNESS-108: read them out
of the suite's existing `unread_line`, `stale_line` and `cannot_line`
helpers, do not restate them. Nothing is oracle-free, and no assertion may
claim how long anything took or how many times a defective loop went round.

**C-8. Changed signatures: none.** No export changes; `rq_run` and
`rq_defaults` are suite-local and gain at most one knob.

**C-9. Commands.**

    bash scripts/selftest.sh run-queue
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue
    bash scripts/selftest.sh selftest          # the floor copy; slow, GATES-side
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/gates.sh --fast

A named-suite run does not queue. The `run-queue` suite takes about 13
minutes on a loaded host; the two new cases add two fixture runs.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". Both new cases are
tests written against code that already exists, and one mutation is both
their earning and the story's "defect put back": the exit removed. No rule
over the tree changes, so no real-line probe is owed beyond it - the
mutation is itself made on the real line.

- **DV-1, the exit taken out (AC-1, AC-2).** With the condition on line 229
  made false, a run that cannot remove the lock goes round the reclaim loop
  until something kills it. `mutate.sh` must report 1 line changed (dry-run
  at PLANNED against `a349761`: line 229 only; the similar line 222, which
  has no `if`, is not matched). The `run-queue` suite **must** fail, and
  among the failures must be, for AC-1's case **and** AC-2's: the `cannot
  use` line's count, the within-the-bound assertion, and the
  status-and-finished assertion. If either case stays green, it does not
  reach the exit and that criterion is unmet. Every assertion outside the
  two cases is expected green, the new source pin excepted (it reads the
  mutated line). The run costs two bounds on top of the suite's usual time.
  RED cannot earn these by watching them fail: the exit already exists, so
  they pass on arrival, and source is frozen in RED. **Owner: GATES.**

      bash scripts/mutate.sh scripts/run-queue.sh 's/^    if \[ -e "\$lock" \] && \[ "\$(run_queue_pid "\$lock")" = "\$pid" \]; then$/    if false; then/' -- bash scripts/selftest.sh run-queue

  **Result (GATES, 2026-11-18, run by the orchestrator, Windows host under load):** both cases go red, as required. `mutate.sh` changed exactly line 229, the run-queue suite failed 15 assertions (7 per case plus the source pin, matching RED's "15 expected"; the certain ones - cannot-use count, within the bound, status-and-finished - red in both cases), and the file was restored and verified byte for byte. Every other assertion stayed green. Output, trimmed to the mutate frame and the failures:

```
=== mutate: scripts/run-queue.sh (1 line(s) changed by s/^    if \[ -e "\$lock" \] \&\& \[ "\$(run_queue_pid "\$lock")" = "\$pid" \]; then$/    if false; then/) ===
  229 -     if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then
  229 +     if false; then
    FAIL HARNESS-112 AC-1 no pid: exits within the bound: it does not go round the reclaim loop
    FAIL HARNESS-112 AC-1 no pid: prints the reclaim line, exactly once
    FAIL HARNESS-112 AC-1 no pid: then gives up on the queue: the cannot-use line naming the queue directory, exactly once
    FAIL HARNESS-112 AC-1 no pid: and prints no other run-queue: line
    FAIL HARNESS-112 AC-1 no pid: the last run-queue: line is the cannot-use line
    FAIL HARNESS-112 AC-1 no pid: runs its work, with the status it has alone (0)
    FAIL HARNESS-112 AC-1 no pid: its work saw the lock as planted, not a record of its own
    FAIL HARNESS-112 AC-2 stale pid: exits within the bound: it does not go round the reclaim loop
    FAIL HARNESS-112 AC-2 stale pid: prints the reclaim line, exactly once
    FAIL HARNESS-112 AC-2 stale pid: then gives up on the queue: the cannot-use line naming the queue directory, exactly once
    FAIL HARNESS-112 AC-2 stale pid: and prints no other run-queue: line
    FAIL HARNESS-112 AC-2 stale pid: the last run-queue: line is the cannot-use line
    FAIL HARNESS-112 AC-2 stale pid: runs its work, with the status it has alone (0)
    FAIL HARNESS-112 AC-2 stale pid: its work saw the lock as planted, not a record of its own
    FAIL scripts/run-queue.sh tests for a lock it could not remove on exactly the one line HARNESS-112 DV-1 mutates
run-queue: 346 passed, 15 failed
FAIL run-queue  did 346 units of work, below the floor of 361 in .claude/tests/floors.conf
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_run-queue.sh.20261118T213909Z.38410.bak) ===
  229:     if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then
```

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Head each entry AM-<n> (`- **AM-1 (AC-2).** ...`), and give it its
     adjudication record, a line of its own in this section, outside any
     comment or fence - check-boundaries.sh refuses a new entry without one:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A claim that a criterion is wrong is also what an agent says when it
     wants to stop failing, so it is judged by a fresh `fable` dispatch - a
     `lead-po` on the ADJUDICATE row of models.conf, on different inputs, not
     the claimant's code - and that dispatch writes the judgement and the
     record line; the judgement is never the orchestrator's. An entry that
     follows a diff-review or PR-feedback finding routed RED or AMEND was
     judged by that review, so the orchestrator writes its record, naming the
     round and finding (or the PR-feedback item) and the model the review was
     planned on and resolved to:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Its being upheld does not replace the user's approval; both go in the
     entry. A change
     the user asked for unprompted is not a claim: `- **Adjudicated AM-<n>:**
     requested by the user, <date>`. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-112` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po`, planned `fable`, resolved claude-fable-5-2 (2026-11-16); no override.
- RED: `test-developer`, planned `opus`, resolved claude-opus-5-5 (2026-11-18); no override.
- GREEN: done inline by the orchestrator (`lead-po` session, claude-opus-5-5), not dispatched: C-6 makes it a verified no-op plus the one-line VERSION bump; no test or script was written.
- GATES: `feature-developer`, planned `opus`, resolved claude-opus-5-5 (2026-11-18); no override. DV-1 run by the orchestrator through mutate.sh.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

## Out of scope

- **Any change to `scripts/run-queue.sh`.** The exit is right as measured.
  Not its wording, not a second attempt at removal, not a message that says
  why the lock could not be removed.
- **What a later run does with the lock that is still there.** Every full
  run prints the same two lines until someone deletes the file; whether that
  should be said differently is a product question nobody has asked.
- **The third way round that loop**: the lock replaced by another run's
  between the read and the removal, where the module tries again. It needs a
  race the suite cannot arrange without the clock.
- **The other HARNESS-108 follow-ups**, each its own story if wanted: an
  empty `--gate` argument, the `mutate.sh --check` refusal coming after the
  queue wait instead of before it, and `TERM` arriving during the winning
  `ln`.
- **`selftest.sh` and `--changed` through the same exit.** They reach
  `run_queue_acquire` by the same call; one caller is enough.
- **A real unremovable file** (another user's lock in a sticky directory, a
  file held open on Windows). The shim stands in for all of them.
- **Exhaustive earning of the suite's other assertions.** That is
  `/audit-mutations`.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

Level: integration, through fixture tree B's real `scripts/gates.sh` (queue
on, `HARNESS_RUN_QUEUE_DIR=$Q`), which is where the contract lives: the exit
is only observable as "a full run that meets a lock it cannot remove still
runs". One helper, `unremovable_case <label> <pid-or-empty> <expected reclaim
line>`, in a new describe `HARNESS-112 AC-1, AC-2 ...` placed after
HARNESS-111's pins and before the closing "shipped pieces" describe (C-3).

The arrangement (C-2): an `rm` shim at `$W/shim/rm`, written once by the
suite with the real `rm` (`command -v rm` in the suite's shell, `/usr/bin/rm`
here) as an absolute path; it refuses any argument ending `/run-queue.lock`
(exit 1, removes nothing, appends the path to `$W/shim/refused`) and execs the
real rm otherwise. It is on PATH only inside `rq_run`'s subshell, through a
new knob `RQ_PATH` (empty by default, reset by `rq_defaults`, set and cleared
around the one `rq_run` in the helper). No other case sets it.

| Case | Planted lock | Expected first line | AC |
|---|---|---|---|
| `HARNESS-112 AC-1 no pid` | `qplant ""` - a record with started/command/root and no pid line | `unread_line "$QL"` | AC-1 |
| `HARNESS-112 AC-2 stale pid` | `qplant "$DEAD" ... "scripts/selftest.sh ghost" /ghost/tree` | `stale_line "$DEAD" "scripts/selftest.sh ghost" /ghost/tree` | AC-2 |

Each case asserts, in this order (11 each), bound 60 s (`wait_bounded "$p" 60`):

1. precondition: `$W/shim/refused` holds at least one line equal to `$QL`
   (`at_least 1`, not exactly 1 - the precondition is "the shim was picked
   up and refused", kept separate from the behaviour assertions);
2. `WTO` is `no` - the run ended within the bound;
3. the reclaim line, whole, count 1;
4. `cannot_line "$Q" scripts/gates.sh`, whole, count 1 (`<dir>` is `$Q`);
5. exactly 2 lines matching `^run-queue:`;
6. the first `run-queue:` line is the reclaim line;
7. the last `run-queue:` line is the cannot-use line;
8. `"$WRC $(present m/k/finished)"` is `"$SOLO_GATES present"`;
9. `m/k/qlock` (the work's copy of the queue lock) is byte-identical
   (`cmp -s`) to the copy taken right after planting;
10. `qsnap` after equals `qsnap` before (the lock not removed, not
    rewritten, no `run-queue.lock.<pid>` left beside it);
11. `leftovers "$B"` is `0` (the helper prints a count; C-3's "empty" read
    as 0).

Plus one unconditional `HARNESS-112 AC-2: precondition: the dead pid is not
running`, and in the closing describe the C-5 source pin: `grep -cxF` of
`    if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then` in
`scripts/run-queue.sh` is 1. Total new: 24. run-queue floor 337 -> 361.

Message texts are read from the suite's existing `unread_line`,
`stale_line`, `cannot_line` (settled by HARNESS-108); none is restated. No
assertion claims a duration or a loop count.

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

Written by test-developer, resolved model **Opus 5.5** (`claude-opus-5-5`),
as `.claude/agents/test-developer.md` declares (`opus`); no override.

**Command.**

    bash scripts/selftest.sh run-queue
    bash scripts/attest.sh check -- bash scripts/selftest.sh run-queue   # the recorded run, instead of a re-run

**The run (C-4: every new assertion passes on arrival - the correct RED for
a test-only chore written against existing code).** Recorded by attest on
the final tree, floors raised:

    run:      2026-11-18T21:20:05Z
    command:  bash scripts/selftest.sh run-queue
    tree:     1e60e85ae339823e7361cceb78818af8852f8f84
    status:   ok
    exit:     0
    duration: 487s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261118T212005Z.19940.log

    run-queue: 361 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (361 assertions executed, 361 declared).
    1 harness suite(s) passed.

An earlier run on the same test file before the floor edit (tree
`84cf04b3...`, log `.claude/state/attest-logs/20261118T211008Z.9921.log`,
548 s) gave `run-queue: 361 passed, 0 failed` against the old floor of 337:
the 24 new assertions are 361 - 337. Both runs local, Windows host, loaded
(another session's full `gates.sh` was running beside the first).

`bash scripts/check-sigpipe.sh` -> `0 finding(s)`, rc 0;
`bash scripts/check-grep-count.sh` -> `0 finding(s)`, rc 0.

    run:      2026-11-18T21:28:21Z
    command:  bash scripts/gates.sh --fast
    tree:     1e60e85ae339823e7361cceb78818af8852f8f84
    status:   ok
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261118T212821Z.28647.log

Every gate is UNCONFIGURED (format, lint, typecheck, unit, coverage;
mutation on request), as Context says; `--fast` judges nothing here. The
artifact is judged by the `run-queue` suite under its floor.

**Tests, one line each** (labels as they appear; every one in the
`HARNESS-112 AC-1, AC-2` describe except the pin):

- `HARNESS-112 AC-2: precondition: the dead pid is not running` - `$DEAD` is gone (AC-2 setup).
- `<case>: precondition: the run tried to remove the queue lock and the rm shim refused it` - refusal record has >= 1 line `$QL` (AC-1, AC-2; the AC's control clause).
- `<case>: exits within the bound: it does not go round the reclaim loop` - `WTO=no` at 60 s (AC-1, AC-2 "within the bound").
- `<case>: prints the reclaim line, exactly once` - whole-line count 1 (AC-1 unread / AC-2 stale).
- `<case>: then gives up on the queue: the cannot-use line naming the queue directory, exactly once` - `cannot_line "$Q" scripts/gates.sh` count 1.
- `<case>: and prints no other run-queue: line` - `^run-queue:` count 2 ("exactly two lines").
- `<case>: the first run-queue: line is the reclaim line` - order.
- `<case>: the last run-queue: line is the cannot-use line` - order.
- `<case>: runs its work, with the status it has alone (<SOLO_GATES>)` - `$WRC` + `m/k/finished` ("does its work and exits with the status the same run has alone").
- `<case>: its work saw the lock as planted, not a record of its own` - `cmp -s` planted copy vs `m/k/qlock`.
- `<case>: the queue directory afterwards holds the planted lock, byte for byte, and nothing else` - `qsnap` before == after.
- `<case>: and the tree holds no run lock` - `leftovers "$B"` is 0.
- `scripts/run-queue.sh tests for a lock it could not remove on exactly the one line HARNESS-112 DV-1 mutates` - C-5 pin, count 1.

`<case>` is `HARNESS-112 AC-1 no pid` and `HARNESS-112 AC-2 stale pid`.

**Files touched.**

- `.claude/tests/run-queue.test.sh` - `RQ_PATH` knob (declaration,
  `rq_defaults`, one line in `rq_run`'s subshell), the shim, the helper,
  two cases, the dead-pid precondition, the source pin.
- `.claude/tests/floors.conf` - `run-queue` 337 -> 361 (line 63) and a dated
  HARNESS-112 entry at the end.
- `.claude/tests/selftest.test.sh` - the hand copy, `run-queue 361` (line 554).
- `docs/backlog/stories/HARNESS-112.md` - `## Test plan`, this section.

Not touched: `scripts/*`, `.claude/tests/_lib.sh`, `.claude/harness/VERSION`
(GREEN's, C-6), HARNESS-108's story. `selftest` floor stays 366.

**Export shape / callers (C-8).** N/A: no signature changes and no exports.
The only shape change is suite-local: `rq_run` and `rq_defaults` gain the
`RQ_PATH` knob; no existing case sets it, so no existing case changes.
GREEN constrains nothing in the module - it writes only `VERSION`.

**Passed on arrival - every one of the 24.** They are earned by DV-1 at
GATES (RED cannot: the exit exists and source is frozen). The refusal-record
precondition is what stops the cases passing for a wrong reason in RED: it
passed in both cases, so the shim was on the run's PATH and did refuse the
lock - a run where `rm` simply succeeded would have failed it and also the
`qsnap` and `qlock` assertions (an ordinary reclaim takes the queue and
leaves a record of its own pid).

**DV-1 prediction** (`bash scripts/mutate.sh scripts/run-queue.sh 's/^    if
\[ -e "\$lock" \] && ...; then$/    if false; then/' -- bash scripts/selftest.sh
run-queue`): the run goes round the reclaim loop until `wait_bounded` sends
TERM at 60 s (gates.sh traps TERM -> exit 143; KILL 10 s later if needed).
Per case:

| Assertion | Under DV-1 | Why |
|---|---|---|
| refusal record >= 1 | green | the shim refuses every pass |
| within the bound (`WTO`) | **certain red** | nothing ends the loop |
| reclaim line exactly once | likely red | one pass ~10 s here under load (Context), so several in 60 s; green only if a host did one pass in 60 s |
| cannot-use line once | **certain red** | count 0 |
| exactly 2 `run-queue:` lines | likely red | equals 2 only if exactly two reclaim lines were printed |
| first line is the reclaim line | green | it is printed first either way |
| last line is the cannot-use line | **certain red** | the last is a reclaim line |
| status and finished | **certain red** | killed (143 or 137), work never ran, `finished` absent |
| work's copy of the lock is the planted one | **certain red** | work never ran, `m/k/qlock` absent |
| `qsnap` unchanged | probably green | refused lock unchanged; each pass removes its `run-queue.lock.<pid>` through the real rm, and the TERM -> EXIT trap releases a tmp left mid-pass; red only if KILL lands mid-pass |
| no run lock left | probably green | gates.sh's EXIT trap releases the run lock on TERM |

Plus the C-5 source pin: **certain red** (count 0 on the mutated line); the
dead-pid precondition and every assertion outside the two cases: green.

Predicted failure count: **certain 11** (5 per case + the pin), **expected
15** (with the two "likely" per case), **range 11-19**. This sharpens C-4's
list: besides the three it names (cannot-use count, `WTO`,
status-and-finished), "last line is the cannot-use line" and "the work's
copy of the lock" are certain too. The mutated run costs about two extra
60-70 s bounds. If either case shows 0 of its certain five red, that case
does not reach the exit.

**Negative controls.** None of the threshold kind; the AC's control is DV-1
above (GATES-owned). Not run in RED: it requires mutating
`scripts/run-queue.sh`, which is DV-1's owner's job at GATES; RED declines
it in writing here.

**Choices within the Contract (no amendment made).**

- AC-1 plants `qplant ""` (a record with no pid line), not a `junk` file -
  both reach the exit (Context); this matches `reclaim_case ac5-nopid`.
- The refusal record is at `$W/shim/refused`, as C-2's snippet writes it;
  the shim directory holds no other executable.
- Refusal count pinned at `>= 1`, not exactly 1 (C-2 leaves it to RED).
- Bound kept at C-3's 60 s; no measurement suggested raising it (both runs
  of the suite finished green at 487 s and 548 s total on a loaded host).

**For GREEN.** Nothing changes the approach: verify `git diff --stat
origin/main...HEAD -- scripts/` is empty, bump `.claude/harness/VERSION`
(C-6), and re-run `bash scripts/selftest.sh run-queue` at the new floor.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return, headed
     R-<n> (`### R-1 (the count test)`), and carrying its adjudication
     record - a line of its own, outside any comment or fence, written by
     the fresh `fable` dispatch (a `lead-po` on the ADJUDICATE row of
     models.conf) that judged the claim the test is wrong; the judgement is
     never the orchestrator's. check-boundaries.sh refuses a new entry
     without one:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A return that follows a diff-review or PR-feedback finding routed RED
     or AMEND was judged by that review, so the orchestrator writes the
     record, naming the round and finding (or the PR-feedback item) and the
     model the review was planned on and resolved to:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Then:
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

## Diff review

Round 1, 2026-11-18: a fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved claude-fable-5-2; no override. Report as returned:

**What this change does.** Two cases in `.claude/tests/run-queue.test.sh` put an `rm` shim on the run's `PATH` that refuses to delete the queue lock, so `run_queue_acquire` in `scripts/run-queue.sh` reaches its could-not-remove exit (lines 229-233). One source pin for the line DV-1 mutates. The run-queue floor goes 337 -> 361 in `floors.conf` and its copy in `selftest.test.sh`. `VERSION` goes 130 -> 131. No production script changes.

**Checked, nothing to fix.**
- **The shim.** The unquoted heredoc expands only `$W` and `$REAL_RM`, and `\$@`, `\$a` and `\n` survive as written. The shim refuses only arguments ending `/run-queue.lock`, so `run-queue.lock.<pid>`, `run.lock*` and everything else pass through to the real `rm`.
- **The shim stays inside the run.** `RQ_PATH` applies only inside `rq_run`'s subshell. It is reset after the run and again by `rq_defaults`. `new_case` and `cleanup` use the real `rm`, so the planted lock does not leak into a later case or outlive the temp directory.
- **The precondition can fail.** If the shim is not picked up, there is no `refused` record, `count_line` prints nothing, and `at_least` answers `no ()`.
- **The module path.** For AC-1 the pid is empty and for AC-2 it is dead; either way `run_queue_link` returns 1 and prints one reclaim line, and `rm -f` is refused. Line 229 then holds, and `run_queue_without` prints the cannot-use line with `$dir` as `HARNESS_RUN_QUEUE_DIR` gives it. `RUN_QUEUE_HELD` stays 0, so `run_queue_release` leaves the planted lock alone, which matches the unchanged-directory assertion.
- **The assertions.** Each case has 11 unconditional assertions. 2 x 11, plus the dead-pid precondition and the source pin, makes 24 = 361 - 337. The pin's whole-line match is unique, because line 222 has no `if`.
- **DV-1.** The pasted result shows 7 failures per case plus the pin, 15 in all, including the three the story calls certain. The restore was verified.
- **Helpers.** `qplant`, `qsnap`, `leftovers`, `count_line`, `first_rq`/`last_rq` and `wait_bounded` are used as in AC-5's `reclaim_case`, with the same 60 s bound.

**Load assumed:** one developer machine running several harness sessions, plus CI. Nothing in the change depends on load beyond the 60 s bound.

**Not checked:** the reviewer did not re-run the run-queue suite itself; it relied on the DV-1 paste and the recorded gate run. `check-sigpipe.sh` passed. `check-grep-count.sh` had not finished when it reported.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-18T21:49:41Z
    commit: 6e85024
    tree:   f0f0163bc30500d55d3b64cf68dd7a4ca8912cbf
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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


- **PLANNED, 2026-11-16.** Planned by `lead-po` on `fable` (resolved
  claude-fable-5-2). The review finding this story follows was reproduced
  before the contract was written, on inputs of the planner's own (Context,
  "Measured at PLANNED"): both variants reach the exit, and with the
  condition false neither returns. `mutate.sh` dry-run of DV-1's expression
  with `-- true`: line 229 only, restored and verified. The request named
  `VERSION` as 129; `main` holds `130 (2026-11-16)`, and C-6 says so.
