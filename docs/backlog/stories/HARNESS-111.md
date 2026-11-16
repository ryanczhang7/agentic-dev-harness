---
id: HARNESS-111
title: A --changed self-test joins the machine-wide run queue
slug: a-changed-self-test-joins-the-machine-wi
epic: 
type: feature
status: in-review
phase: REVIEW
branch: story/HARNESS-111-a-changed-self-test-joins-the-machine-wi
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/run-lock.sh, scripts/run-queue.sh, .claude/tests/run-queue.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/state/README.md, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the run-queue suite under its selftest floor, and by run-lock and selftest unchanged, which CI runs in full on the PR
---

## Context

Requested by the user on 2026-11-14, as the follow-up HARNESS-108 recorded.
HARNESS-108 made a **full** `gates.sh` or `selftest.sh` run wait for any other
full run on the machine instead of running beside it (`scripts/run-queue.sh`,
joined inside `scripts/run-lock.sh`). It left one run out on purpose:
`selftest.sh --changed`, which "never queues, even when it resolves to every
suite" (HARNESS-108, Contract C-5 and Out of scope).

**Why that gap matters.** `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
is the self-test the PR procedure runs before REVIEW. When a story's diff
touches `.claude/tests/_lib.sh`, or a path no rule maps, `--changed` resolves
to every suite and is a full run in everything but its command line.
HARNESS-108's own pre-REVIEW run was one of these: 35 suites, 9657 s, on a
host shared with other sessions, and nothing queued it. The run the procedure
asks for most often is the one the queue cannot see.

**Why it was left, and why it can be closed now.** HARNESS-108 could not read
what `--changed` had resolved to without editing `selftest.sh`, and
HARNESS-107 was changing that code in another worktree. HARNESS-107 has
merged (release 126). This story does not need the resolved selection at all:
it queues **every** `--changed` run that gets as far as running a suite
(Contract C-1 has the rule and the reason), and that is decided from the
command string `run-lock.sh` is already given. `scripts/selftest.sh` is still
not edited.

**The central risk is unchanged from HARNESS-108: a run waiting on its own
parent.** A gate command may run `selftest.sh --changed`, and a `--changed`
run nested under a holder must pass through exactly as a nested full run does
(AC-3). The harness's own suites still export `HARNESS_RUN_QUEUE=off`, so no
fixture run joins the host's queue.

**The required gate.** Every gate is unconfigured in this repository, so
`required_gates` stays empty, as on HARNESS-102 to 108. The artifact is judged
by the `run-queue` suite under its self-test floor, and by the `run-lock` and
`selftest` suites, which must pass unchanged apart from the one floor copy
(C-7); CI runs all of them in full on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story.
**Architecture.** `docs/wiki/architecture.md` does not exist here; the
constraints are `rules.md`, Portability (bash, awk and coreutils, no python)
and bash 3.2 compatibility.

## Acceptance criteria

In every criterion, "the queue" is HARNESS-108's lock file
(`$HARNESS_RUN_QUEUE_DIR/run-queue.lock`), two trees are two separate fixture
roots sharing one queue directory, and "a `--changed` run" is
`scripts/selftest.sh --changed [base-ref]` in a tree whose selection is stated
in the criterion. A holder is held open and released by the test (its work
waits for a marker file), never by timing. "Has not started" is observed over
at least two of the waiter's poll intervals after its queued line appeared.
Every wait a test makes is bounded. The three queued lines, the `starting`
line and the stale and "without the queue" lines are HARNESS-108's, unchanged
(Contract C-3); only the command they name is new.

- **AC-1** — Given a full `gates.sh` run in tree A that holds the queue and is
  still running, when a `--changed` run is started in tree B, then no suite of
  B's has started for as long as A's run lasts; B prints to stderr, once, the
  three queued lines, naming B's command as `scripts/selftest.sh --changed`
  and A's pid, start time, tree root and command as A's lock record gives
  them; and when A's run ends, B's run starts without anything else being
  done, prints the one `starting` line, runs the suites it selected and exits
  with the status the same run has alone. B's work itself records that A's
  had finished before it began. This holds both for a `--changed` run that
  resolves to **every suite** and for one that resolves to a **proper subset**
  of the tree's suites, and in each case B's stdout carries the `--changed`
  header line for that selection, so the test cannot be measuring a different
  selection from the one it names.
  *Control:* the same arrangement with `HARNESS_RUN_QUEUE=off` on B must show
  B's suite starting while A's work is still held, so the arrangement is one
  that can see the two side by side; and with the rule put back to "full runs
  only", this criterion's "has not started" assertion must fail (DV-1).
- **AC-2** — Given an empty queue directory, when a `--changed` run starts,
  runs and ends, then it prints no line beginning `run-queue:` on either
  stream, its stderr is byte-for-byte what the same run prints with
  `HARNESS_RUN_QUEUE=off`, and afterwards the queue directory holds neither
  the lock nor a temporary record; while its suite is running, the lock
  exists and records the run's pid, its tree root and its command,
  `scripts/selftest.sh --changed`. And given a `--changed` run in tree B that
  holds the queue and is still running, when a full `gates.sh` run is started
  in tree A, then A's gate command has not started while B's run lasts, A's
  queued lines name B's pid, tree root and `scripts/selftest.sh --changed`,
  and A runs once B ends. A `--changed` run is waited for as well as waiting.
- **AC-3** — Given a full `gates.sh` run in tree A that holds the queue, when
  its gate command runs `selftest.sh --changed` in tree A and then in tree B,
  then both inner runs start at once, print no `run-queue:` line, and finish
  with the status each has alone; the outer run finishes with its own status;
  and the queue lock still records the outer run's pid after each inner run
  has ended. The whole arrangement completes within the test's bound: a
  nested `--changed` run does not wait on its own ancestor.
- **AC-4** — Given a full run in tree A that holds the queue, when a
  `--changed` run is started in tree B whose selection is **no suite** (its
  diff holds no harness path), then it exits 1 at once, while A still holds,
  with its `selftest: --changed selected no suite` line on stdout; it prints
  no `run-queue:` line, creates, changes and removes nothing in the queue
  directory, and leaves no `run.lock` in tree B. A run with nothing to run
  never waits.
- **AC-5** — `run_lock_queues` answers as Contract C-2's table says for every
  row of it: it queues every command `run_lock_full` calls full, and
  `scripts/selftest.sh --changed` with or without a base ref; it does not
  queue `scripts/selftest.sh <suite>...`, a `--changed` that is not the first
  argument, `scripts/gates.sh --fast` / `--gate` / `--skip` / `--required` /
  `--list` / `--audit`, any other script, or an empty string. `run_lock_full`
  answers exactly as before for every row of HARNESS-108's table,
  `scripts/selftest.sh --changed` (not full) included. And every run
  HARNESS-108's AC-10 says starts at once beside a held queue -
  `gates.sh --fast`, `--gate X`, `--skip X`, `--required` and `selftest.sh`
  with one suite named - still does, with no `run-queue:` line and nothing
  written in the queue directory.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/run-lock.sh`, `scripts/run-queue.sh`, `.claude/tests/run-queue.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/state/README.md`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/run-queue.test.sh`, the suite's new floor in `floors.conf` and
its hand-copied line in `selftest.test.sh` (C-7). GREEN (feature-developer)
writes the change to `scripts/run-lock.sh`, the comment-only change to
`scripts/run-queue.sh`, the paragraph in `.claude/state/README.md` and
`VERSION`, and touches no suite.

**Not written: `scripts/selftest.sh`, `scripts/gates.sh`,
`scripts/selftest-needed.sh`, `.claude/tests/_lib.sh`, `.github/workflows/*`,
`docs/backlog/stories/HARNESS-108.md`.** The rule is decided from the command
string `selftest.sh` already passes to `run_lock_acquire`
(`scripts/selftest.sh${*:+ $*}`, line 515), so the script, its whole-run
goldens in `selftest.test.sh` and the line number `sigpipe.test.sh` pins in
`gates.sh` are all left alone. `_lib.sh` is not touched, which is what keeps
this story's own pre-REVIEW `--changed` run from resolving to every suite.

**C-1. Which `--changed` runs queue: every one that takes the run lock.**

| `selftest.sh --changed [base-ref]` resolves to | What happens today, before the run lock | Queues |
|---|---|---|
| every suite (`--suites` answers `all`) | goes on to the run lock | **yes** |
| a list of suites, however short | goes on to the run lock | **yes** |
| no suite (`--suites` exits 1) | prints `selected no suite`, exits 1 at `selftest.sh` line 329 | no - it never reaches the run lock, so it never reaches the queue |
| cannot select (`--suites` fails) | prints `cannot select`, exits 2 at line 332 | no - the same |
| a selected name that is no suite | exits 1 at line 370 | no - the same |

*Why every one, and not "only when it resolves to every suite" or "more than
N suites".* Three reasons, in order of weight:

1. **The size of a `--changed` run is not the count of its suites.** One
   selected suite can be `boundaries`, which HARNESS-106 recorded unfinished
   after 35 minutes beside another session's self-test. Any threshold N is a
   number with no measurement behind it, and it would be wrong for the first
   story whose two suites are the two slowest.
2. **The caller does not choose the size.** A named-suite run is somebody
   deciding to run one suite; a `--changed` run is the procedure's run, and
   whoever starts it learns what it resolved to only from its header line. A
   rule the caller cannot predict ("it queues if your diff happened to touch
   `_lib.sh`") is a rule nobody can plan a wait around.
3. **It is the only rule that needs no edit to `selftest.sh`.** What
   `--changed` resolved to is known only inside `selftest.sh`. Every
   `--changed` run that survives selection has the same command string up to
   the base ref, and `run-lock.sh` already has it.

*The cost, stated.* A `--changed` run that selected one quick suite now waits
behind another session's full run instead of starting beside it. That is the
intended trade: the pre-REVIEW run is not on a clock, and a developer who
wants one suite now names it (`selftest.sh <suite>`), which does not queue.

**C-2. The predicate.** One new function in `scripts/run-lock.sh`, directly
after `run_lock_full`:

    run_lock_queues <command>     # 0 if <command> joins the machine-wide queue, 1 otherwise

- 0 when `run_lock_full <command>` is 0;
- 0 when `<command>` is exactly `scripts/selftest.sh --changed`, or begins
  `scripts/selftest.sh --changed ` (a space, then the base ref and anything
  after it);
- 1 for everything else, an empty string included.

Matched in a `case` over the string, no globbing, as `run_lock_full` is. Its
opening line is exactly `run_lock_queues() {`, alone on its line; the suite
pins it with `grep -cxF`, as it pins `run_lock_full() {`.

| Command string | `run_lock_full` | `run_lock_queues` |
|---|---|---|
| `scripts/gates.sh` | 0 | 0 |
| `scripts/gates.sh --story T-1` | 0 | 0 |
| `scripts/selftest.sh` | 0 | 0 |
| `scripts/selftest.sh --changed` | 1 | **0** |
| `scripts/selftest.sh --changed origin/main` | 1 | **0** |
| `scripts/selftest.sh --changedx` | 1 | 1 |
| `scripts/selftest.sh run-queue --changed` | 1 | 1 |
| `scripts/selftest.sh run-queue` | 1 | 1 |
| `scripts/selftest.sh run-queue run-lock` | 1 | 1 |
| `scripts/gates.sh --fast` | 1 | 1 |
| `scripts/gates.sh --gate unit` | 1 | 1 |
| `scripts/gates.sh --skip unit` | 1 | 1 |
| `scripts/gates.sh --required` | 1 | 1 |
| `scripts/gates.sh --story T-1 --fast` | 1 | 1 |
| `scripts/gates.sh --list`, `scripts/gates.sh --audit` | 1 | 1 |
| `scripts/gates.sh --changed` | 0 | 0 - `gates.sh` has no such flag; the row only says `--changed` means something after `scripts/selftest.sh` and nowhere else |
| `scripts/selftest-needed.sh --suites`, `scripts/check-boundaries.sh`, `scripts/ci-local.sh`, `scripts/attest.sh -- bash scripts/selftest.sh --changed` | 1 | 1 |
| the empty string | 1 | 1 |

RED checks the `scripts/gates.sh --changed` row against `run_lock_full` as it
is and amends the row if the function answers otherwise; it is the one row
here not read out of HARNESS-108's table.

**`run_lock_full` is not changed, and that is the decision about
HARNESS-108's AC-10.** The alternative was to make `run_lock_full` answer 0
for `--changed` and flip the two rows of its table in the suite
(`1|scripts/selftest.sh --changed`, `1|scripts/selftest.sh --changed
origin/main`). That makes a function called "full" say yes to a run that may
be one suite, and it changes the expected value of two existing assertions
against existing code. With a second predicate, **no existing assertion in
`.claude/tests/run-queue.test.sh` changes its expected value**: the 19-row
`run_lock_full` table stays byte for byte, "`--changed` is not a full run"
stays true, the five `beside_case` rows of AC-10 never ran `--changed`, and
the `grep -cxF 'run_lock_full() {'` pin and HARNESS-108's DV-3 expression
still have their line. What changes is prose: the suite's header comment and
its `describe` lines say "only a full run queues", and RED rewords them. RED
confirms this claim by grep before writing anything and reports any assertion
that does change value; if one does, it is a corrected test against existing
code and owes its own mutation (rules.md), which this plan has not budgeted
because it found none.

**C-3. The wiring.** One line of `run_lock_join` changes:

      run_lock_full "$2" || return 0        # today
      run_lock_queues "$2" || return 0      # this story

The new line is exactly two spaces, then `run_lock_queues "$2" || return 0`,
alone on its line: DV-1's expression targets it and the suite pins it with
`grep -cxF`. Nothing else in `run_lock_join`, `run_lock_acquire` or
`run_lock_release` changes, and `scripts/run-queue.sh` changes only in its
header comment. So everything a queued `--changed` run prints is what a
queued full run prints, with `scripts/selftest.sh --changed[ <base-ref>]` as
the command: the three queued lines, `still queued`, `starting`, the stale
and unreadable reclaim lines, and the "runs without the machine-wide queue"
lines, all read out of `scripts/run-queue.sh` as it stands and none reworded.
The lock record's `command` field is that same string.

**What a queued `--changed` run prints before the queued lines.** Selection
happens before the run lock (`selftest.sh` lines 307-333), and the header
line goes to stdout at line 422, also before it. So a waiting `--changed`
run has already printed `--suites`' reason lines on stderr and its
`selftest: --changed — ...` header on stdout, and then the three queued lines
on stderr. "Has not started" therefore means no `=== <suite> ===` block and
no suite's work, never "no output".

**A limit, recorded and not closed.** The selection is computed when the run
is started, not when it gets through the queue. A run that waits an hour
runs the suites its diff selected an hour ago, against the tree as it is
when it starts running. Nobody should be editing a tree whose pre-REVIEW run
is queued (the run holds that tree's `run.lock` the whole time, so no other
harness run can start there); the limit is written in the `run-queue.sh`
header (C-6) and nothing enforces it.

**C-4. Nesting, and the harness's own suites.** Unchanged mechanisms, newly
reachable by `--changed`:

- A `--changed` run started by a holder's gate command inherits
  `HARNESS_RUN_QUEUE_LOCK` and `HARNESS_RUN_QUEUE_PID` and passes through
  `run_queue_acquire`'s nested check (AC-3), in the holder's tree and in
  another.
- A `--changed` run that itself holds the queue exports the same two
  variables, so the suites it runs, and anything they start, pass through or
  (being harness suites, with `HARNESS_RUN_QUEUE=off` from `_lib.sh`) never
  look.
- `.claude/tests/selftest.test.sh` runs `--changed` in fixtures many times.
  Every one inherits `HARNESS_RUN_QUEUE=off`, so none joins the host's queue
  and none changes; RED confirms with one grep that no suite other than
  `run-queue` turns the queue on.

**C-5. The fixtures, and how a selection is made to be what the test says.**
`--changed` needs what the existing trees A, B and C do not have: a `main`,
a story branch, and a diff that `scripts/selftest-needed.sh --suites` maps.
`.claude/tests/selftest.test.sh` lines 1949-1988 (`cf_suite`, `cf_new`,
`cf_story`) is the working recipe; the three selections it produces are the
three this story needs:

| Selection | Recipe (from `selftest.test.sh`) | Header line the test asserts as its precondition |
|---|---|---|
| every suite | a new `.claude/harness/x.conf`, mapped by no rule | `selftest: --changed — every suite: ...` |
| a proper subset | two suites, one whose source mentions `.claude/harness/m.conf`; a new `m.conf` | `selftest: --changed — 1 of 2 suite(s) selected: <name>` |
| no suite | a committed source-only change | `selftest: --changed selected no suite — ...` |

- Build **new** trees for these (or new helpers), so that A, B and C and
  every existing case stay byte for byte as they are. The selected suite's
  work is the same `m/work.sh` the existing fixtures use, so the overlap,
  `done-before` and `qlock` instruments are reused, not rewritten.
- The run's marker directory (`m/k/`) and `.claude/state/` must not be read
  as changed paths, or the selection drifts as the test runs: ignore them in
  the fixture's `.gitignore` and commit that on `main`, as `cf_new` does for
  `.claude/state/`.
- **Every case asserts the header line it expects before it asserts anything
  about the queue.** A fixture whose selection silently became "every suite",
  or "none", would otherwise pass or fail for a reason that is not this
  story's.
- The status a `--changed` run has alone is measured with the queue off,
  not assumed to be 0, as `SOLO_GATES` and `SOLO_SELF` are today.
- The suite already takes about 13 minutes on a loaded host and each waiting
  case costs a 3.5 s sleep plus two harness runs. Add the cases the criteria
  name and no matrix beyond them: one waiter per selection (AC-1), one
  uncontended run and one reverse pair (AC-2), one nested arrangement
  (AC-3), one no-suite run (AC-4), the table (AC-5).

**C-6. Prose that says "only a full run", and who rewords it.**

- `scripts/run-lock.sh` (GREEN): the header paragraph "THE MACHINE-WIDE
  QUEUE" and the comments on `run_lock_full` and `run_lock_join`.
- `scripts/run-queue.sh` (GREEN, comments only): the "WHICH RUNS" paragraph,
  whose last sentence today is the gap this story closes; it gains the limit
  of C-3. "WHY" may keep the word "full" where it describes the measurement.
- `.claude/state/README.md` (GREEN): the paragraph beginning "The
  machine-wide queue lock is not in this directory", where it says which runs
  take the queue and which run reclaims a stale lock.
- `.claude/tests/run-queue.test.sh` (RED): the header comment and the
  `describe` lines.
- Not reworded: `docs/backlog/stories/HARNESS-108.md` (a closed story is a
  record), `CLAUDE.md`, `rules.md`, the commands and the skills, none of
  which says which runs queue.

**C-7. The floor and the release.** `run-queue` is floored at 229
(`floors.conf` line 63, copied by hand at `selftest.test.sh` line 554). RED
raises both to the executed count it measures, with a dated comment in
`floors.conf` in the form HARNESS-108's entries use. A table row that fails
because `run_lock_queues` does not exist yet fails **one** assertion in the
if and the else alike, as the `run_lock_full` table does, so the executed
count is the same in RED and GREEN. GREEN re-measures; if it differs, the
handoff was wrong and GREEN reports it instead of moving the number. No other
floor moves: `run-lock` stays 141 and `selftest` 366.
`.claude/harness/VERSION` is `127 (2026-11-13)` on `main`. HARNESS-109 and
HARNESS-110 are in flight and each will take a number; this story takes the
next free one when it merges `main` before REVIEW, with the real date.

**C-8. Oracle partition.** All five criteria are **mechanical**: pin the
queued, `starting` and header lines whole (`grep -cxF`, or a fixed prefix
plus the anchored span pattern the suite already has), the exit statuses
exactly (0, 1, 2, 143 - never "non-zero"), the record's fields, the two
pinned source lines. The message texts, the poll and heartbeat defaults and
the span format are **settled** by HARNESS-108: read them out of
`scripts/run-queue.sh` and the suite's existing `q1`/`q2`/`q3` helpers, do
not restate or tune them. Nothing here is oracle-free, and no assertion may
claim a wait took N seconds.

**C-9. Changed signatures: none.** `run_lock_acquire <root> <command>`,
`run_lock_release`, `run_lock_join <root> <command>` and
`run_lock_full <command>` keep their names, arguments and answers.
`run_lock_queues` is new. Callers of `run_lock_full`, grep-listed
2026-11-14 on `99c5ca9`: `scripts/run-lock.sh` line 117 (`run_lock_join`,
the one line this story changes) and `.claude/tests/run-queue.test.sh` lines
643-651 and 777-778 (the table and the opening-line pin, both kept). No
other script or suite names it.

**C-10. Commands.**

    bash scripts/selftest.sh run-queue
    bash scripts/selftest.sh run-queue run-lock
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue run-lock
    bash scripts/selftest-needed.sh --suites
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/gates.sh --fast

Named-suite runs do not queue, before or after this story, so RED and GREEN
are never held up by another session's full run. The pre-REVIEW
`SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` on this branch is the
first real `--changed` run to queue: if another session's run holds the
queue it will print the queued lines and wait, which is the story working,
not a hang. It is dispatched detached, as the procedure says.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one "defect put back"
mutation for the central claim (DV-1), one probe against the real tree
(DV-2), and one mutation for each of the two tests that pass on arrival in
RED because the code they are about already exists (DV-3, DV-4). No existing
assertion changes its expected value (C-2), so no corrected test is owed a
mutation; if RED finds one, it adds the entry. Each mutation runs against the
one suite that holds its assertion. None can run before GREEN:
`run_lock_queues` does not exist in RED, and DV-3 and DV-4 need a `--changed`
run that queues before breaking nesting or the early exit can show anything.

- **DV-1, the defect put back (AC-1).** With `run_lock_join` asking
  `run_lock_full` again, a `--changed` run takes no queue and starts beside
  the holder, which is the tree as it is today. `mutate.sh` must report 1
  line changed. The `run-queue` suite **must** fail, and among the failures
  must be AC-1's assertion that B's suite had not started while A held, for
  both selections; AC-2's lock-record and reverse-pair assertions are
  expected red too, and the `run_lock_queues` table rows are expected to
  stay green (the function is untouched). RED's handoff predicts the exact
  count and names the assertions; the orchestrator compares. If AC-1's
  assertion stays green, the suite is not observing concurrency for
  `--changed` and AC-1 is unmet. **Owner: GATES.**

      bash scripts/mutate.sh scripts/run-lock.sh 's/^  run_lock_queues "\$2" || return 0$/  run_lock_full "$2" || return 0/' -- bash scripts/selftest.sh run-queue

- **DV-2, the real tree against a held queue (AC-1).** Not a fixture: this
  checkout's own `scripts/selftest.sh --changed`, on the story branch at
  GATES, where the diff against `main` holds harness paths and the selection
  is therefore not empty (the prober pastes the header line to show it). The
  queue directory is a temp directory, never the host's real queue, holding
  a lock whose recorded pid is a live process the prober started;
  `HARNESS_RUN_QUEUE` is not `off`, `HARNESS_RUN_QUEUE_DIR` is the temp
  directory and `HARNESS_RUN_QUEUE_POLL=1`. `bash scripts/selftest.sh
  --changed`, started in the background, **must** print the three queued
  lines naming that pid and `scripts/selftest.sh --changed`, and no
  `=== <suite> ===` line. The prober then sends it `TERM` while it is still
  queued: it **must** exit 143 having run no suite, leaving
  `.claude/state/run.lock` gone and the temp lock byte for byte unchanged.
  The run is never paid for: that a queued run starts after the release is
  the fixtures' claim (AC-1), and this probe's is that the real `--changed`
  caller of this tree reaches the queue at all. The prober pastes the run's
  stdout, stderr and exit status, and confirms the holder process was killed
  and the temp directory removed. The other half of the rule on the real
  tree - a named-suite run and `gates.sh --fast` start at once beside a held
  queue - was HARNESS-108's DV-2, ran then, and is pinned by AC-5's
  unchanged cases; it is not repeated. **Owner: GATES.**

- **DV-3, the nested pass-through earned for `--changed` (AC-3).** AC-3's
  assertions pass on arrival in RED: nothing queues a `--changed` run, so a
  nested one cannot wait on its ancestor. With the nested check in
  `run_queue_acquire` never matching, a nested `--changed` run **must** wait
  behind its own ancestor until the test's bound, and AC-3's "both inner runs
  start at once" and "completes within the bound" assertions **must** go red.
  HARNESS-108's AC-6 cases (nested full runs) are expected red with them and
  will cost their bounds too; that is one slow run, not a reason to narrow
  the mutation. `mutate.sh` must report 1 line changed (dry-run at PLANNED
  against `99c5ca9`: line 167 only). RED's handoff predicts which assertions
  and how many. **Owner: GATES.**

      bash scripts/mutate.sh scripts/run-queue.sh 's/\[ "\$pid" = "\${HARNESS_RUN_QUEUE_PID:-}" \]/false/' -- bash scripts/selftest.sh run-queue

- **DV-4, "nothing to run never waits" earned (AC-4).** AC-4's assertions
  pass on arrival in RED: a no-suite `--changed` exits at `selftest.sh` line
  329 today, and nothing would queue it if it did not. With that `exit 1`
  removed, the run falls through to the run lock as `scripts/selftest.sh
  --changed` with every suite selected, and so into the queue behind the
  holder: AC-4's "exits 1 at once, while A still holds" **must** go red.
  `mutate.sh` must report 1 line changed (dry-run at PLANNED against
  `99c5ca9`: line 329 only). This is the one mutation of a file the story
  does not write; it earns a test of where the story's rule stops.
  **Owner: GATES.**

      bash scripts/mutate.sh scripts/selftest.sh '/--changed selected no suite/{n;s/^    exit 1$/    :/;}' -- bash scripts/selftest.sh run-queue

**Results at GATES (2026-11-16, run by the orchestrator, one at a time, each against `bash scripts/selftest.sh run-queue` alone).** `mutate.sh` restored and verified every file; `mutate.sh --check` was clean afterwards.

- **DV-1 result: as predicted.** 1 line changed; the suite went 311 passed / 26 failed (handoff predicted exactly 26): all 16 AC-1 assertions across both selections, including "has not started ... while A holds", the 4 AC-2 lock-record and 5 AC-2 reverse-pair assertions, and the wiring pin. The `run_lock_queues` table rows stayed green.

    === mutate: scripts/run-lock.sh (1 line(s) changed by s/^  run_lock_queues "\$2" || return 0$/  run_lock_full "$2" || return 0/) ===
        FAIL AC-1 every suite: X's --changed run has not started its work while A holds the queue, over two poll intervals after it queued
        FAIL AC-1 subset: Y's --changed run has not started its work while A holds the queue, over two poll intervals after it queued
        FAIL AC-2 --changed: while its suite ran, the queue lock existed
        FAIL AC-2 reverse: A's full gates.sh has not started its gate command while X's --changed run holds, over two poll intervals after it queued
        FAIL run_lock_join asks run_lock_queues, on exactly the one line DV-1 mutates
    run-queue: 311 passed, 26 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/laughing-shirley-5afc9b/.claude/state/mutations/scripts_run-lock.sh.20261116T160030Z.1315059.bak) ===

- **DV-2 result: queues.** The first attempt sent `TERM` at a fixed 10 s, before this tree's `--changed` had finished selecting: stdout and stderr were empty, exit 143, nothing ran. That attempt showed nothing either way, so the probe was re-run waiting (bounded at 900 s) for the queued line instead. The re-run output, with the per-suite listing cut:

    ##### DV-2 (re-run) 2026-11-16T17:01:57Z
    holder pid 1371425
    queued line seen after 7s
    exit: 143
    --- stdout:
    selftest: --changed — 15 of 35 suite(s) selected: attest boundaries doctor grep-count host-load lib mutate refresh run-lock run-queue selftest settings shipped-docs sigpipe worktree
    --- stderr:
    selftest-needed: suites — 15 of 35 selected from 7 harness path(s) changed against origin/main (merge-base 99c5ca9)
    run-queue: queued: scripts/selftest.sh --changed waits for another harness run on this machine to finish.
    run-queue:   behind pid 1371425, started 2026-11-16T00:00:00Z, in /dv2/holder: dv2-holder
    run-queue: this is waiting, not hanging: it starts by itself when that run ends. If pid 1371425 is not that run, delete C:/Users/ryanc/AppData/Local/Temp/claude/260c78d56515c372/1be6b863-0a72-4201-95ae-56cb1c81a9e2/scratchpad/dv111q/run-queue.lock and it starts.
    suite blocks on stdout: 0
    run.lock: gone
    temp lock: unchanged
    holder: killed
    temp dir: removed

- **DV-3 result: as predicted.** 1 line changed (line 167); the suite went 327 passed / 10 failed (handoff predicted 10-12): five AC-3 and five HARNESS-108 AC-6 assertions, all about the inner run in the other tree, "completes within the bound" first among them.

    === mutate: scripts/run-queue.sh (1 line(s) changed by s/\[ "\$pid" = "\${HARNESS_RUN_QUEUE_PID:-}" \]/false/) ===
        FAIL AC-6: the whole arrangement completes within the bound: it does not wait on itself
        FAIL AC-3: the whole arrangement completes within the bound: a nested --changed run does not wait on its ancestor
    run-queue: 327 passed, 10 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/laughing-shirley-5afc9b/.claude/state/mutations/scripts_run-queue.sh.20261116T163107Z.1337936.bak) ===

- **DV-4 result: as predicted.** 1 line changed; the suite went 333 passed / 4 failed (handoff predicted 2 certain, up to 7): the two certain AC-4 assertions, plus two AC-1 control assertions reddened by `release_all` after the AC-4 bound, as the handoff warned.

    === mutate: scripts/selftest.sh (1 line(s) changed by /--changed selected no suite/{n;s/^    exit 1$/    :/;}) ===
        FAIL AC-4: Z's --changed run that selects no suite exits 1 at once, within the bound, while A holds
        FAIL AC-4: it prints no run-queue: line on stdout or stderr
    run-queue: 333 passed, 4 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/laughing-shirley-5afc9b/.claude/state/mutations/scripts_selftest.sh.20261116T165029Z.1358043.bak) ===

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

Planned by `bash scripts/plan.sh write HARNESS-111` from `.claude/harness/models.conf`.
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

- PLANNED (2026-11-14, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the orchestrating session; no override was reported to it, and the agent declares `model: fable`.
- RED (2026-11-15, `/advance-story`): `test-developer`, planned `opus`, resolved **claude-opus-5-5** (Opus 5.5), no override reported. The orchestrator checked both attest records `fresh` on tree `2dd2fd39` (not re-run): `selftest.sh run-queue` exit 1, 288 passed / 49 failed, every failure in the new cases and none in HARNESS-108's 229; `gates.sh --fast` exit 0 (all gates unconfigured).
- GREEN (2026-11-16, `/advance-story`): `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (Opus 5.5), no override reported. The orchestrator checked the attest records `fresh` on tree `37aa8a0b` (not re-run): `selftest.sh run-queue` exit 0, 337 passed / 0 failed, floor met; `selftest.sh run-lock` exit 0 (141/0); `gates.sh --fast` exit 0. Every control value in the handoff measured as RED recorded it. VERSION is 129 because main had reached 128.
- GATES (2026-11-16, `/advance-story`): `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (Opus 5.5), no override reported. `attest.sh check -- bash scripts/gates.sh` answered `fresh`: exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).` DV-1..DV-4 were run by the orchestrator before it.
- No departure from the plan. All five criteria are mechanical, with the messages and defaults settled by HARNESS-108 (Contract, C-8).

## Out of scope

- **A size rule for `--changed`.** No "only when it resolves to every suite",
  no threshold of N suites, no reading of the resolved selection (C-1). Every
  `--changed` run that takes the run lock queues.
- **Named-suite runs and `gates.sh --fast`, `--gate`, `--skip`,
  `--required`.** They neither wait nor are waited for, exactly as
  HARNESS-108's AC-10 left them. They are the RED and GREEN loop, where a
  wait behind another session's full run would stall the work the queue
  exists to protect, and whoever starts one chose its size.
- **Renaming or changing `run_lock_full`.** It keeps its name, its answers
  and its line (C-2).
- **Editing `scripts/selftest.sh`**, its comments included. In particular,
  passing what `--changed` resolved to into the lock record or the queued
  message: the record's `command` is the command line, as for every run.
- **Re-selecting after the wait.** A queued `--changed` run runs the
  selection it computed when it was started (C-3). Recorded, not closed.
- **The four follow-ups HARNESS-108 left**, none of which is this story:
  - the untested "lock cannot be removed" exit of `run_queue_acquire`
    (HARNESS-108, R-2);
  - an empty `--gate` value misclassified as not full by `run_lock_full`;
  - `gates.sh` running its `mutate.sh --check` before the queue wait rather
    than after it;
  - `TERM` arriving during the winning `ln` of the queue lock.
- **Everything HARNESS-108 put out of scope stays out:** first-come-first-
  served ordering, a maximum wait, a run that waits on an ancestor after
  `env -i`, the reclaim race, queues across users or pid namespaces,
  same-tree waiting (still a refusal with exit 2), `scripts/host-load.sh`,
  a command to show or clear the queue.
- **A `TERM`, stale-lock, heartbeat or "cannot use the directory" case for
  `--changed`.** Those paths are in `run_queue_acquire`, which does not know
  what command it was given beyond printing it, and HARNESS-108's suite pins
  them. Repeating them per command is the matrix C-5 rules out; DV-2 sends
  one real `TERM`.
- **`ci-local.sh`, `attest.sh`, `check-boundaries.sh`.** Not edited. A
  `--changed` run they start queues by itself.
- **`CLAUDE.md`, `rules.md`, the commands and the skills.** No new prose; the
  queued message is the documentation an agent meets when it needs it.
- **Fixing the consumers.** They get this by refreshing to the release this
  story ships.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One suite, `.claude/tests/run-queue.test.sh`, extended in place (C-5: no new
suite). Every new case is an integration case through the real
`scripts/selftest.sh` and `scripts/gates.sh` of a fixture tree, except AC-5's
table and the two source pins, which call `scripts/run-lock.sh` directly.

**Fixtures (C-5).** Three new trees beside A, B and C, built by
`changed_setup`: each is `fixture_setup` (the same `m/work.sh` instruments)
plus a second suite `other`, a `work` suite whose source mentions
`.claude/harness/m.conf`, a gate `unit` that is `m/gate.sh` (which is
`m/work.sh` unless `m/k/nest` exists, then `m/nest.sh`), `m/k/` and
`.claude/state/` ignored, everything committed on `main`, then a story
branch with one committed change:

| Tree | Change | Selection | Header asserted first |
|---|---|---|---|
| X | `.claude/harness/x.conf` | every suite (`other`, `work`) | `selftest: --changed — every suite: .claude/harness/x.conf is mapped by no rule; defaulting to every suite` |
| Y | `.claude/harness/m.conf` | `work` only (1 of 2) | `selftest: --changed — 1 of 2 suite(s) selected: work` |
| Z | `src/app.ts` | no suite | `selftest: --changed selected no suite — selftest-needed: skip — no harness path among 1 changed path(s) against main (merge-base <main>); CI runs the self-test on the PR` |

The work tree is clean after setup (confirmed by a prototype run: `git
status --short` empty in all three after a `--changed` run and a `gates.sh`
run), so the selection does not drift while the cases run. A, B, C and every
existing case are byte for byte as they were; the only edits to existing
code are the tree loops of `release_all`, `cleanup` and `new_case`, which now
include X, Y and Z, and prose (header comment, two `describe` lines).

| Case | Level | AC | What it asserts |
|---|---|---|---|
| `solo-cx`, `solo-cy` | integration | AC-1..3 | the status each `--changed` run has alone, queue off (measured, not assumed); `solo-cx.err` is AC-2's byte-for-byte reference |
| `changed_pair "AC-1 every suite"` (X) and `"AC-1 subset"` (Y) | integration | AC-1 | A's full `gates.sh` holds; the `--changed` run's header line is present; over 3.5 s after it queued its work has not started and no `=== ` line is printed; the three queued lines whole, naming `scripts/selftest.sh --changed` and A's pid, `started`, root and command from A's record; after A's release it gets through within the bound, its work finishes, its status is the solo one, its work records `done-before` = `A` and saw nobody, one `starting` line, the `=== work ===` block once and `=== other ===` 1 (X) or 0 (Y) times; queue dir empty |
| AC-2 uncontended (X) | integration | AC-2 | header; the lock existed during the suite and recorded the run's pid, `scripts/selftest.sh --changed` and root X; no `run-queue:` line on either stream; stderr `cmp`-identical to `solo-cx.err`; status = solo; queue dir empty afterwards |
| AC-2 reverse (holder X `--changed`, waiter A `gates.sh`) | integration | AC-2 | header; A's work has not started over 3.5 s after it queued; A's queued lines 1 and 2 name A's own command and X's pid, `started`, root and `scripts/selftest.sh --changed`; after X's release A gets through, finishes with `SOLO_GATES`, its work records `done-before` = `X` and saw nobody; queue dir empty |
| AC-3 nested (`gates.sh` in X, gate command `m/nest.sh`: `--changed` in X, then in Y) | integration | AC-3 | both inner headers; the arrangement completes within 120 s; outer exits 0; inner X status = `SOLO_CX`; inner Y status = `SOLO_CY` and Y's work finished; no `run-queue:` line in any inner stream; the queue lock records the outer pid after each inner run; queue dir empty at the end |
| AC-4 (A holds, Z `--changed`) | integration | AC-4 | within 60 s and while A holds, exit 1; stdout is exactly the selected-no-suite line; no `run-queue:` line; `qsnap` byte-identical before and after; no `run.lock` left in Z; Z's work never started; A still alive |
| AC-1 control (A held, X `--changed` with `HARNESS_RUN_QUEUE=off`) | integration | AC-1 | header; X's work starts while A holds and its `overlap-start` is `A`; status = solo |
| `run_lock_queues` table, 22 rows | unit | AC-5 | every row of C-2's table, the empty string included; one `_ok`/`_bad` per row whether or not the function exists |
| two source pins | unit | C-2, C-3 | `run_lock_queues() {` alone on its line once; `  run_lock_queues "$2" || return 0` once (DV-1's target) |
| HARNESS-108's existing `beside_case` rows and `run_lock_full` table | integration / unit | AC-5 | unchanged: `gates.sh --fast`, `--gate unit`, `--skip lint`, `--required`, `selftest.sh work` start at once beside a held queue; `run_lock_full`'s 19 rows, `--changed` not full |

**C-2's claim confirmed by grep** (2026-11-14, `3665c3e`): the only
`--changed` in the suite before this story was two rows of the
`run_lock_full` table (`git show HEAD:.claude/tests/run-queue.test.sh | grep
-n -- '--changed'` gives lines 636 and 637, both `1|...`), and they are kept.
No existing assertion changed its expected value, so no `## Regressions`
entry is owed. **The `scripts/gates.sh --changed` row** checked against
`run_lock_full` as it is: it answers 0, as the table says, so the row stands
unamended.

    0 scripts/gates.sh --changed
    1 scripts/selftest.sh --changedx
    1 scripts/selftest.sh run-queue --changed
    1 scripts/attest.sh -- bash scripts/selftest.sh --changed

**C-4 confirmed by grep**: `grep -n HARNESS_RUN_QUEUE .claude/tests/*.sh`
outside `run-queue.test.sh` finds only `_lib.sh:33: export
HARNESS_RUN_QUEUE=off`; no other suite turns the queue on.

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

**RED, 2026-11-15, `test-developer`.** Dispatched as a subagent; the
session reports its model as **claude-opus-5-5** (Opus 5.5), and no
override was reported to it.

**Command.**

    bash scripts/selftest.sh run-queue
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue

**Result, in RED.** 337 assertions executed, 288 passed, 49 failed. This was
measured on the tree before the floor, the three `describe` rewordings and
this text were written; the final attested record is pasted at the end of
this section. Expected failure shape (log
`.claude/state/attest-logs/20261115T043543Z.978332.log`, run 2861 s on a host
also running another session's full self-test):

    exit:     1
    last:     1 of 1 harness suite(s) FAILED.
    run-queue: 288 passed, 49 failed

The 49, verbatim names:

    FAIL AC-1 every suite: X's --changed run has not started its work while A holds the queue, over two poll intervals after it queued
    FAIL AC-1 every suite: nor printed a suite block: no === <suite> === line yet
    FAIL AC-1 every suite: queued line 1 names the waiting run as scripts/selftest.sh --changed, exactly once, on stderr
    FAIL AC-1 every suite: queued line 2 names A's pid, start, tree root and command from A's record, exactly once
    FAIL AC-1 every suite: queued line 3 says it is waiting and names the lock to delete, exactly once
    FAIL AC-1 every suite: X's work records, as it starts, that A's had finished
    FAIL AC-1 every suite: X's work saw no other run in progress as it started
    FAIL AC-1 every suite: one starting line naming scripts/selftest.sh --changed, with the total wait
    FAIL AC-1 subset: (the same eight, for Y)
    FAIL AC-2 --changed: while its suite ran, the queue lock existed
    FAIL AC-2 --changed: the lock records the run's pid
    FAIL AC-2 --changed: the lock records the run's command, scripts/selftest.sh --changed
    FAIL AC-2 --changed: the lock records the run's tree root, absolute
    FAIL AC-2 reverse: A's full gates.sh has not started its gate command while X's --changed run holds, over two poll intervals after it queued
    FAIL AC-2 reverse: A's queued line 1 names A's own command, exactly once
    FAIL AC-2 reverse: A's queued line 2 names X's pid, start, tree root and scripts/selftest.sh --changed, exactly once
    FAIL AC-2 reverse: A's work records, as it starts, that X's had finished
    FAIL AC-2 reverse: A's work saw no other run in progress as it started
    FAIL run_lock_queues '<cmd>' queues / does not queue   (all 22 rows: "scripts/run-lock.sh defines no run_lock_queues")
    FAIL scripts/run-lock.sh opens run_lock_queues alone on its line
    FAIL run_lock_join asks run_lock_queues, on exactly the one line DV-1 mutates

16 + 4 + 5 + 22 + 2 = 49. **Why each is the right failure.** The 25 case
failures are the story's absence observed by the runs themselves: in both
selections the `--changed` run's work started beside A's held work (its
`overlap-start` was `A`, its `done-before` empty) and printed no queued or
`starting` line; the uncontended run's work found no queue lock to copy; and
in the reverse pair A's work started beside X's, because X never took the
queue. In every case the header precondition (the selection is the one the
case names) and the "A still running" precondition **passed**, so none of
these is a fixture whose selection drifted or whose holder died. The 24
direct failures are the missing function and the missing wiring line. **No
HARNESS-108 assertion failed**: all 229 pass, so no existing expected value
changed (C-2's claim, also confirmed by grep; see `## Test plan`).

**Passed on arrival, by design, and who earns them.**

- **AC-3** (10 assertions): nothing queues a `--changed` run today, so a
  nested one cannot wait. **Earned by DV-3 at GATES. I decline that mutation
  here**: it cannot show anything until a `--changed` run queues, which is
  GREEN's change.
- **AC-4** (8 assertions, including "A then finishes"): a no-suite run exits
  at `selftest.sh` line 329 today. **Earned by DV-4 at GATES. I decline that
  mutation here**, for the same reason.
- **AC-1's queue-off control** (5 assertions): passes now and must keep
  passing. It is the negative control that proves the arrangement can see two
  runs at once; it measured `overlap-start` = `A` in this run.
- The non-queue halves of AC-1/AC-2 (`A finishes 0`, `gets through within the
  bound`, `work runs to its end`, the solo statuses, `A's work saw no other run
  as it ended`, the `=== work ===` / `=== other ===` block counts, `qsnap`
  empty, no `run-queue:` line, stderr byte-identical to queue-off): these hold
  in RED because nothing queues, and they are what GREEN must not break. DV-1
  earns the AC-1/AC-2 queue halves; the byte-identical and silent halves are
  the same mechanism HARNESS-108 earned for full runs.
- **AC-5's unchanged rows**: HARNESS-108's five `beside_case` rows and its
  19-row `run_lock_full` table, untouched, all green.

**Negative controls and measured values** (this RED run, Windows host, local):

| Control | Expected | Measured in RED |
|---|---|---|
| AC-1 control, X `--changed` with `HARNESS_RUN_QUEUE=off` beside held A: X's `overlap-start` | `A` | `A` (pass) |
| `SOLO_CX`, X `--changed` alone, queue off | 0 | 0 |
| `SOLO_CY`, Y `--changed` alone, queue off | 0 | 0 |
| X header (every suite) | the `HDR_X` line, once | once (pass) |
| Y header (subset) | `selftest: --changed — 1 of 2 suite(s) selected: work`, once | once (pass) |
| Z stdout (no suite) | exactly `HDR_Z` | exact (pass) |
| Y runs `=== other ===` | 0 times | 0 (pass); X: 1 (pass) |

These ran in RED. Unlike HARNESS-108's RED, the suite did not fail at
import. GREEN re-measures them against the shipped `run_lock_queues`.

**Predictions for the mutations GATES owns.**

- **DV-1** (`run_lock_join` asks `run_lock_full` again): **26 failures**,
  namely the 25 case failures above, unchanged (16 AC-1, 4 AC-2 uncontended,
  5 AC-2 reverse), plus `run_lock_join asks run_lock_queues, on exactly the
  one line DV-1 mutates`, because the mutation removes that pinned line. The
  22 table rows and the `run_lock_queues() {` pin stay green. AC-1's
  `has not started` assertion must be among them for both selections.
- **DV-3** (nested check never matches): the inner run in the holder's own
  tree is unaffected, because the run lock's same-tree pass-through returns
  before `run_lock_join`. The inner run in the OTHER tree waits behind its
  ancestor until the 120 s bound. These are certain to fail, in both
  HARNESS-108's AC-6 and this story's AC-3: `the whole arrangement completes
  within the bound`, `the outer full gates.sh finishes with its own status`,
  the inner-in-B/Y status-and-finished assertion, `neither inner run prints a
  run-queue: line`, and `after the inner run in B/Y has ended, the queue lock
  still records the outer run's pid`. That is 5 + 5 = 10. The trailing
  `queue directory is empty` assertion of each may also fail, depending on
  whether the KILLed outer run left its lock behind, so the count is
  **10 to 12**. The inner-run-in-own-tree status, its qlock pin and AC-3's
  two header preconditions stay green. The cost is about 2 x 120 s of
  bound.
- **DV-4** (the no-suite `exit 1` removed): Z falls through to the run lock as
  `scripts/selftest.sh --changed` and queues behind A. These are certain:
  `AC-4: Z's --changed run that selects no suite exits 1 at once, within the
  bound, while A holds` (it times out at 60 s), and `AC-4: it prints no
  run-queue: line`. These are likely: `its stdout is exactly the
  selected-no-suite line` (the TERMed run adds its own exit output);
  `AC-4: precondition: A is still running then`, because `wait_bounded`'s
  timeout path runs `release_all`, which releases A; and then both of the AC-1
  control's `A`-dependent assertions (`overlap-start` = `A`, `A is still
  running then`) and possibly `A then finishes, exit 0`. Predicted
  **2 certain, up to 7**.

**Export shape the tests pin.** In `scripts/run-lock.sh`, sourced:

- `run_lock_queues <command>`, returning 0 or 1, defined with the opening
  line exactly `run_lock_queues() {` alone on its line. It is called in a
  subshell after `set -f`, with one argument, for the 22 rows of C-2's table.
- In `run_lock_join`, the line exactly `  run_lock_queues "$2" || return 0`,
  appearing once.
- `run_lock_full` and its `run_lock_full() {` line, unchanged (HARNESS-108's
  pins).

**Not constrained:** the body of `run_lock_queues` (whether it calls
`run_lock_full` or repeats the cases), the comment wording in `run-lock.sh`,
`run-queue.sh` and `.claude/state/README.md`, and `VERSION`.

**Files touched in RED.**

- `.claude/tests/run-queue.test.sh`: new trees X, Y, Z, plus `changed_setup`
  and `cgit`, X's `m/nest.sh`, the HARNESS-111 block (108 assertions), the tree
  loops of `release_all`, `cleanup` and `new_case`, the header comment, and
  two reworded `describe` lines (`every run that does not queue starts at
  once`, `a run in progress that does not queue is not waited for`).
- `.claude/tests/floors.conf`: `run-queue` 229 -> 337, with a dated note.
- `.claude/tests/selftest.test.sh` line 554: `run-queue 337`.
- This story: `## Test plan` and this handoff.

**For GREEN.**

- The executed count is 337 in RED and must be 337 in GREEN. Selftest's floor
  check counts passes, so a RED run sits below 337; GREEN at 337 passed, 0
  failed meets it. If GREEN measures another executed count, report it rather
  than moving the floor (C-7).
- Runtime: about 47 minutes for this suite here, beside another session's
  full self-test. The new block adds two solo runs and six held arrangements,
  each costing a 3.5 s sleep plus harness runs. Every wait is bounded (60, 90
  or 120 s). Nothing in the new cases is a framework timeout, so there is no
  hook budget to size.
- Setup of X, Y and Z was prototyped before the run: `git status --short`
  stays empty in all three after a `--changed` run and a `gates.sh` run, so
  the selection cannot drift. If a header precondition ever fails, look at
  the fixture first (an untracked file in X, Y or Z), not at the queue.
- Nothing found contradicts the Contract. No amendment was made.

**Final attested records** (on the finished RED tree, floor at 337). These
have the same 49 failures as the first run, name for name. The floor line is
now red as well, as expected:

    run:      2026-11-15T05:26:16Z
    command:  bash scripts/selftest.sh run-queue
    tree:     2dd2fd3921433387ee510b363921ecd41c9a232c
    status:   ok
    exit:     1
    duration: 1284s
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261115T052616Z.1030596.log

    run-queue: 288 passed, 49 failed
    FAIL run-queue  did 288 units of work, below the floor of 337 in .claude/tests/floors.conf

    run:      2026-11-15T05:48:38Z
    command:  bash scripts/gates.sh --fast
    tree:     2dd2fd3921433387ee510b363921ecd41c9a232c
    status:   ok
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261115T054838Z.1075427.log

`gates.sh --fast` is green because every gate is unconfigured in this
repository (Context, "The required gate"). The suite is the judge here, and
it is red for the reasons above.

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

### Round 1 (2026-11-16)

Dispatched as a fresh `lead-po` on the DIFF-REVIEW row: planned `fable`, resolved **claude-fable-5-2** (Fable 5.2), no override reported. Reviewed `git diff origin/main...HEAD` after main (HARNESS-109) was merged in as `71454c1`. No file changed. The report, as returned:

**What this change does.** A `selftest.sh --changed` run now joins the machine-wide run queue, so it waits behind another session's full run (and is waited for) instead of running beside it. The rule is a new predicate, `run_lock_queues`, in `scripts/run-lock.sh`; `run_lock_join` asks it instead of `run_lock_full`, which is unchanged. The rest is comments, the state README, the release number, and 108 new assertions in the `run-queue` suite with its floor raised to 337.

**Checked, and nothing to fix:**

- **The predicate, on inputs of the reviewer's own.** Sourced `scripts/run-lock.sh` and called `run_lock_queues` directly. 0 for `scripts/selftest.sh --changed`, with a trailing space, and with a base ref after one or two spaces. 1 for a doubled space before `--changed`, `--changed*` (no globbing), `--Changed`, a tab instead of a space, a `bash ` prefix, `scripts/selftest.sh ` alone, and the empty string. Matches C-2.
- **The command string `run_lock_join` really sees.** `scripts/selftest.sh:515` passes `scripts/selftest.sh${*:+ $*}`, and `--changed` is only honoured as `$1` (line 307), so every `--changed` run that reaches the lock has a string the predicate matches; `SELFTEST_JOBS=4` is environment, not an argument.
- **Runs that must not queue.** The no-suite, cannot-select and unknown-name exits (lines 329, 332, 370) all happen before the lock is sourced.
- **Callers.** `run_lock_full` is named only in `run-lock.sh` and the suite. `scripts/attest.sh` and `scripts/ci-local.sh` take no run lock and name neither predicate; a `--changed` run `attest.sh` starts queues by itself, and `attest.sh` has no timeout a wait could trip.
- **Nesting and the harness's own suites.** `.claude/tests/_lib.sh:33` exports `HARNESS_RUN_QUEUE=off` and no suite but `run-queue` turns it on, so the `--changed` fixture runs in `selftest.test.sh` cannot join the host queue; a holder's children pass through on the exported lock path and pid as before.
- **Stale prose.** No shipped script, command, skill or agent file still says "only a full run queues" or "`--changed` never queues". The README paragraph and both script headers agree with the code.
- **The tests.** Each `--changed` case asserts its header line before any queue assertion; the "has not started" checks have a queue-off control; the 22-row table and both `grep -cxF` pins are anchored; the floor arithmetic (229 + 108 = 337) matches. No assertion found that cannot fail.
- **Load assumed.** A handful of concurrent sessions for one user on one machine, as `run-queue.sh`'s header states.

**Not checked:** the `run-queue` suite and the gates were not re-run. The last full gate run (`bed44dc`) predates the merge of `origin/main`, so the gate stamp needs a fresh run against the merged tree before the PR.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-16T17:58:30Z
    commit: 71454c1
    tree:   be09122c01b82f3b8c1a47618d3c5639dc5a0b9d
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

- **2026-11-14, PLANNED (lead-po, `/plan-story`).** Planned from the user's
  request of the same day, relayed by the orchestrating session with the
  decisions to make. What was decided, each with its reason in the Contract:
  every `--changed` run that takes the run lock queues, and one that selects
  nothing never reaches it (C-1); a second predicate, `run_lock_queues`,
  rather than a changed `run_lock_full`, so no existing assertion of
  HARNESS-108's suite changes its expected value (C-2); named-suite and
  `--fast` runs stay unqueued (Out of scope); nesting needs no new mechanism
  and gets a criterion and a mutation of its own (AC-3, DV-3);
  `scripts/selftest.sh` is not edited (Contract, "Not written").
- **A departure from the brief, to check.** The brief expected HARNESS-108's
  AC-10 assertions about `--changed` to change meaning and asked for the
  mutation that earns the change. The only assertions the suite makes about
  `--changed` are two rows of the `run_lock_full` table, and with a separate
  predicate they stay true and unchanged, so no such mutation is planned.
  RED confirms by grep before writing (C-2). The mutations that are owed are
  for the two new tests that pass on arrival (DV-3, DV-4).
- **Sizing.** One behaviour (which runs join the queue), one changed line and
  one small function in production, comments in two files, and a handful of
  cases in one suite. It fits one RED to GREEN cycle and is not split.
- **The id.** HARNESS-111 was free on 2026-11-14 after `git fetch`: no
  branch, local or remote, and no story file carried it. HARNESS-109 and
  HARNESS-110 have branches in other sessions and no story file on `main`.
- **A question for the user that does not block RED.** A `--changed` run
  that selected one quick suite will now wait behind another session's full
  run (C-1, "The cost, stated"). If that proves annoying in practice, the
  remedy on offer is naming the suite; a size rule was considered and
  rejected for the reasons in C-1.
- **`bash scripts/plan.sh conflicts`, 2026-11-14, in this worktree.** It
  cannot judge the pairs that matter: HARNESS-109 and HARNESS-110 have no
  story file on `main`, so this tree sees one startable story.

      fewer than two startable stories; nothing to compare

  `plan.sh conflicts --pairs` printed nothing. Judged by hand from the
  `touches:` each declares on its own branch (HARNESS-109 at REVIEW,
  HARNESS-110 at PLANNED, both
  `[.claude/tests/shipped-docs.test.sh, .claude/tests/floors.conf,
  .claude/tests/selftest.test.sh, .claude/harness/VERSION]`): **a CONFLICT
  with each, on the three bookkeeping files** `.claude/tests/floors.conf`,
  `.claude/tests/selftest.test.sh` and `.claude/harness/VERSION`. No script
  and no suite body is shared: they write `shipped-docs`, this story writes
  `run-queue`, `run-lock.sh` and `run-queue.sh`. It is the same collision
  HARNESS-108 had with HARNESS-107 (one floor line, its hand copy, the
  release number), and the same remedy: the story that reaches REVIEW later
  merges `main` first, keeps both floor lines and takes the next release
  number (C-7). The pair is not `clear`, so it is the user's call whether
  this story starts beside them or after them.

- **Merged main and re-ran gates (2026-11-16).** HARNESS-109 merged to main as #199 while this story was at GATES, so `origin/main` was merged in (`71454c1`) before the diff review. `.claude/harness/VERSION` and `.claude/tests/floors.conf` conflicted, both `harness`: VERSION keeps 129 (main had 128), and floors.conf keeps both stories' notes (`run-queue 337`, `shipped-docs 21`). Full gates were then re-run on the merged tree by the orchestrator directly (a 4 s run with every gate unconfigured, nothing to fix): `attest.sh -- bash scripts/gates.sh`, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).`, tree `5f5ff948`.

- **Local self-test before REVIEW (2026-11-16).** Dispatched to a `feature-developer` on the GATES row (resolved `claude-opus-5-5`), one command, detached. `attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` answers `fresh` on tree `5f5ff948`:

      selftest: --changed — 15 of 35 suite(s) selected: attest boundaries doctor grep-count host-load lib mutate refresh run-lock run-queue selftest settings shipped-docs sigpipe worktree
      exit:     0
      duration: 7196s
      last:     15 harness suite(s) passed.

  Every selected suite met its floor (3012 assertions executed, 3011 declared). The run printed no `run-queue: queued` line, so it did not wait behind another run.
