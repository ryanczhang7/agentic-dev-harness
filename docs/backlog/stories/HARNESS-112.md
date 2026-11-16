---
id: HARNESS-112
title: The run-queue suite reaches the exit for a queue lock that cannot be removed
slug: the-run-queue-suite-reaches-the-exit-for
epic: 
type: chore
status: todo
phase: PLANNED
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


- **PLANNED, 2026-11-16.** Planned by `lead-po` on `fable` (resolved
  claude-fable-5-2). The review finding this story follows was reproduced
  before the contract was written, on inputs of the planner's own (Context,
  "Measured at PLANNED"): both variants reach the exit, and with the
  condition false neither returns. `mutate.sh` dry-run of DV-1's expression
  with `-- true`: line 229 only, restored and verified. The request named
  `VERSION` as 129; `main` holds `130 (2026-11-16)`, and C-6 says so.
