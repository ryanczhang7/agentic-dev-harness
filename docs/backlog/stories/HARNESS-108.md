---
id: HARNESS-108
title: Harness runs queue machine-wide instead of running side by side
slug: harness-runs-queue-machine-wide-instead
epic: 
type: feature
status: in-progress
phase: RED
branch: story/HARNESS-108-harness-runs-queue-machine-wide-instead
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/run-queue.sh, scripts/run-lock.sh, .claude/tests/run-queue.test.sh, .claude/tests/_lib.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/state/README.md, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the run-queue suite under its selftest floor, and by run-lock, gates and selftest unchanged, which CI runs in full on the PR
---

## Context

Requested by the user on 2026-11-13. Full self-test runs and full gate runs
must never run at the same time on one machine: a second run started anywhere
on it waits for the running one and then runs. That holds across repositories,
worktrees and sessions, for the harness itself and for every project built on
it. The waiting run says that it is queued and behind what, so that an agent
does not take waiting for hanging.

**The measurement behind it.** Two consumer refresh self-tests, each with
`SELFTEST_JOBS=4`, ran beside another session's runs of the `boundaries` suite
and took over three hours. The same self-test takes three to four minutes on
CI, where it has the machine to itself. HARNESS-106's contract records a
single `boundaries` run that had not finished after 35 minutes beside another
session's self-test.

**What exists, and what it does not do.**

- `scripts/run-lock.sh` (HARNESS-034) is one lock per tree,
  `<root>/.claude/state/run.lock`. A second run in the *same* tree is refused
  with exit 2. It never waits, and it knows nothing about any other tree.
- `scripts/host-load.sh` (HARNESS-074) reads `ps -ef` and *warns* a self-test
  about other harness-shaped runs on the host. It never refuses and never
  waits. The three-hour runs above printed that warning.

So nothing stops two runs in two trees, and the only instrument that sees them
is a warning. This story adds the missing piece: one lock per user per
machine, outside every repository, that a run **waits** on.

**The central risk is a run waiting on its own parent.** `gates.sh` runs gate
commands, and a gate command may run `selftest.sh`; the self-test's suites run
`gates.sh` and `selftest.sh` in fixture trees by the hundred. A queue that
those inner runs join is a deadlock: the child waits for the parent, the
parent waits for the child. AC-6 and AC-7 pin the two ways this story avoids
it (a nested run passes through; the harness's own suites never join the
queue), and the Contract (C-7) says which of the two each case relies on.

**The required gate.** Every gate is unconfigured in this repository, so
`required_gates` stays empty, as on HARNESS-102 to 107. The artifact is judged
by the new `run-queue` suite under its self-test floor, and by the `run-lock`,
`gates` and `selftest` suites, which must pass unchanged; CI runs all of them
in full on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story.

**Architecture.** `docs/wiki/architecture.md` does not exist in this
repository (`docs/wiki/` holds `README.md`, `audits/` and `design/`). The
constraints are `rules.md`, Portability (bash, awk and coreutils, no python),
and bash 3.2 compatibility, as for every harness script.

## Acceptance criteria

In every criterion except AC-10, "a run" is a **full run**: `scripts/gates.sh`
with none of `--fast`, `--gate`, `--skip`, `--required`, `--list`, `--audit`,
or `scripts/selftest.sh` with no argument, which runs every suite (Contract
C-5 has the whole table). Every other invocation is a non-full run and never
joins the queue (AC-10). "The queue" is the lock file of C-1, and two trees
are two separate fixture roots sharing one queue directory. A holder is held
open and released by the test (a gate command or a suite that waits for a
marker file), never by timing. Every wait a test makes is bounded.

- **AC-1** — Given a run in tree A that holds the queue and is still running,
  when a run is started in tree B, then B's gate command (or first suite) has
  not started for as long as A's run lasts, observed over at least two of B's
  poll intervals; and when A's run ends, B's run starts without anything else
  being done, runs to its own result and exits with the status it would have
  had alone. B's gate command itself records that A's had finished before it
  began. This holds for `gates.sh` behind `gates.sh`, `selftest.sh` behind
  `gates.sh`, and `gates.sh` behind `selftest.sh`.
  *Control:* the same arrangement with `HARNESS_RUN_QUEUE=off` on B must show
  B's gate command starting while A's is still held (AC-7 asserts it), so the
  arrangement is one that can see two runs side by side; and with the
  liveness check made to read every holder as gone, AC-1's "has not started"
  assertion must fail (DV-1).
- **AC-2** — Given a holder in tree A and two more runs started in trees B and
  C while it holds, when A's run ends, then B and C both run to completion and
  no two of the three gate commands are ever running at the same time (each
  records, as it starts and as it ends, whether either of the others was in
  progress). Which of B and C goes first is not specified.
- **AC-3** — Given a run in tree B that finds the queue held by a run in tree
  A, then B prints to stderr, once, before it waits, three lines (C-3) that
  between them state that B is queued, name A's tree root, A's pid, when A
  started and A's command line as A's lock record gives them, and say that
  this is waiting and how to clear the lock by hand; while it waits it prints
  a `still queued` line (C-3) at each heartbeat interval, naming the holder as
  the lock records it at that moment and how long B has waited; and when it
  gets through it prints one `starting` line with the total wait. With a
  heartbeat interval of 1 second and a holder held for at least 3 seconds, at
  least one `still queued` line appears. None of this goes to stdout.
- **AC-4** — Given an empty queue directory, when a run starts, runs and
  ends, then it prints no line beginning `run-queue:` on either stream, its
  stderr is byte-for-byte what the same run prints with
  `HARNESS_RUN_QUEUE=off`, and afterwards the queue directory holds neither
  the lock nor a temporary record. While that run's gate command is running,
  the lock exists and records the run's pid, its tree root and its command.
- **AC-5** — Given a queue lock whose recorded pid is not running, when a run
  starts, then it prints one `reclaimed a stale queue lock` line (C-3) naming
  that pid, command and tree, takes the queue and runs, without waiting. Given
  a lock that records no pid, the same with the `unreadable` line. Given a
  lock whose recorded pid belongs to a live process that is not a harness run
  at all, the run waits exactly as in AC-1 and the lock is not removed: a
  live pid is never reclaimed.
- **AC-6** — Given a full `gates.sh` run in tree A that holds the queue, when its
  gate command runs a full `selftest.sh` in tree A and then one in tree B,
  then both inner runs start at once, print no `run-queue:` line, and finish;
  the outer run finishes with its own status; and the queue lock still
  records the outer run's pid after each inner run has ended (an inner run
  neither takes nor releases the queue). The whole arrangement completes
  within the test's bound: it does not wait on itself.
  *Not a bypass:* given a live holder in tree A and a run in tree B that is
  **not** its descendant but has `HARNESS_RUN_QUEUE_LOCK` and
  `HARNESS_RUN_QUEUE_PID` set by hand - to the right path with a pid that is
  not the one the lock records, and to the recorded pid with a path that is
  not this queue's - then B waits as in AC-1.
- **AC-7** — Given `HARNESS_RUN_QUEUE=off`, when a run starts while another
  tree's run holds the queue, then it starts at once, prints no `run-queue:`
  line, and creates, changes and removes nothing in the queue directory. Any
  other value, and `CI=true` on its own, leaves the queue on. And given any
  harness suite, sourcing `.claude/tests/_lib.sh` leaves
  `HARNESS_RUN_QUEUE=off` exported, so no fixture run a suite starts joins the
  host's queue, whether the suite runs under `selftest.sh` or by itself.
- **AC-8** — Given a run waiting in the queue, when it receives `TERM`, then it
  exits 143 within a bound of a few poll intervals,
  having run nothing; afterwards the queue directory holds only the holder's
  lock, unchanged, and the waiter's tree holds no `run.lock`. And given a run
  that holds the queue and receives `TERM`, then once it has exited the queue
  lock is gone and a run waiting behind it starts.
- **AC-9** — Given a queue directory that cannot be created or written (its
  path lies under a regular file), or neither `HARNESS_RUN_QUEUE_DIR` nor
  `HOME` set, or a tree with no `scripts/run-queue.sh`, when a run starts,
  then it prints the one line of C-3 for that case to stderr and runs as it
  would have without the queue, with its own exit status. The queue never
  turns a run that could have run into one that did not.
- **AC-10** — Given a full run in tree A that holds the queue, when a
  non-full run is started in tree B - `gates.sh --fast`, `gates.sh --gate X`,
  `gates.sh --skip X`, `gates.sh --required`, and `selftest.sh` with one
  suite named - then each starts at once, while A still holds, prints no
  `run-queue:` line, and creates, changes and removes nothing in the queue
  directory; and given a non-full run still running in tree B and an empty
  queue, a full run started in tree A takes the queue and starts at once.
  A non-full run in a tree that A's run already holds is refused with exit 2
  by the run lock, as today. And `run_lock_full` answers as Contract C-5's
  table says for every row of it, `scripts/selftest.sh --changed` and
  `scripts/gates.sh --story T-1` (full) and `scripts/gates.sh --story T-1
  --fast` (not full) included.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/run-queue.sh`, `scripts/run-lock.sh`, `.claude/tests/run-queue.test.sh`, `.claude/tests/_lib.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/state/README.md`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/run-queue.test.sh`, the one export in `.claude/tests/_lib.sh`
(C-7), and the new suite's floor in `floors.conf` and in the hand-copied table
of `selftest.test.sh` (C-10), in the RED commit, as HARNESS-034 and
HARNESS-074 did for their suites. GREEN (feature-developer) writes
`scripts/run-queue.sh`, the change to `scripts/run-lock.sh`, the paragraph in
`.claude/state/README.md` and `VERSION`, and touches no suite.

**Not written: `scripts/gates.sh`, `scripts/selftest.sh`, `.github/workflows/*`,
`scripts/selftest-needed.sh`, `scripts/host-load.sh`.** The queue is joined
inside `run_lock_acquire` and left inside `run_lock_release` (C-4), which both
scripts already call at the right moments. That is deliberate:
`sigpipe.test.sh` pins `scripts/gates.sh:801` by line number, the whole-run
goldens of `gates.test.sh` and `selftest.test.sh` pin both scripts' output,
and HARNESS-107 is in flight on `scripts/selftest-needed.sh`. The comments in
`gates.sh` and `selftest.sh` that say the run lock "never waits" stay true of
the run lock and are left alone.

**C-1. Where the queue lives (decision 1).** One lock file per user per
machine, outside every repository:

    ${HARNESS_RUN_QUEUE_DIR:-$HOME/.cache/agentic-harness}/run-queue.lock

`$HOME`, not `$TMPDIR`: a temp directory can differ between two sessions of
one user, and can be unset (`tdd-cycle`, `reference/cases.md`, "A backup that
went to an unset $TMPDIR"); two runs that resolve different directories do not
queue at all, silently. `HARNESS_RUN_QUEUE_DIR` is the override, and what the
suite uses. The directory is created with `mkdir -p` on first use. With
neither variable set, or the directory not creatable or writable, the run
proceeds without the queue and says so (AC-9, C-3).

**C-2. The mechanism (decisions 2, 3).** The take is `run-lock.sh`'s: write
the record to `run-queue.lock.<pid>` in the same directory, hard-link it into
place with `ln` (no `-f`), which fails when the lock exists, so exactly one
contender wins and no reader sees a half-written record. The record is four
TAB-separated lines:

    pid<TAB><the taking script's $$>
    started<TAB><UTC, to the second, as run.lock writes it>
    command<TAB><the string run_lock_acquire was given, e.g. scripts/gates.sh --fast>
    root<TAB><the tree root run_lock_acquire was given, absolute>

Where `run-lock.sh` refuses, this **waits**: it removes its temporary record,
sleeps one poll interval, and tries again, for as long as it takes. The
temporary record exists only for the duration of one attempt, so a waiter
killed outright between attempts leaves nothing behind.

- *Not first-come-first-served.* Several waiters poll; whichever attempts
  first after the release wins. AC-2 pins that no two run together and that
  all finish, not the order.
- *No maximum wait.* The runs this is for have been measured at over three
  hours; no bound chosen today would be right. A waiter ends by getting the
  queue or by being signalled.
- *Stale locks* are reclaimed by pid, as `run.lock` is: a lock whose pid is
  not running (`kill -0`), or which records no numeric pid, is removed with
  one line (C-3) and taken. Immediately before removing, the record is read
  again and removed only if it still names the same pid. A residual window
  remains (two waiters reclaim the same dead holder in the same instant, and
  the second removes the first's fresh lock): its cost is one pair of
  concurrent runs after a crash, and it is recorded, not closed (Out of
  scope).
- *The limits of `kill -0`, stated in the script's header.* A recycled pid
  reads alive: the run waits behind a process that is not a harness run, and
  the queued message (C-3) says which file to delete. A holder in a different
  pid namespace (WSL, a container, another MSYS runtime sharing `$HOME`)
  reads gone and is reclaimed: the queue does not span them.
- **Evidence for the liveness check, measured, not assumed** (2026-11-13,
  this machine, Git Bash on Windows, bash 5.3.15, `HOME=/c/Users/ryanc`,
  `TMPDIR=/c/Users/ryanc/AppData/Local/Temp`): a `sleep` started in one bash
  invocation (pid 487184) read alive via `kill -0` from a separate, unrelated
  bash invocation (pid 487312); pid 999999 read gone; a second `ln` onto an
  existing name was refused, in `$TMPDIR` and under `$HOME/.cache` alike. The
  orchestrating session measured the same before dispatch. **Settled** for
  this host; CI (Linux) is covered by the suite itself.

**C-3. The messages (decision 9).** All on **stderr**, as `run-lock.sh`'s are,
each a whole line, compared by the suite as whole lines (`grep -cxF`, or an
anchored pattern where a line holds a duration). `<self>` is the waiting
run's command string, `<pid> <started> <command> <root>` are read from the
holder's record, `<lock>` is the lock's absolute path, `<span>` is C-6's.
*Amended in RED (2026-11-13), a clarification:* `<dir>` is C-1's directory
as resolved - `HARNESS_RUN_QUEUE_DIR` verbatim when it is set, else
`$HOME/.cache/agentic-harness` - and `<lock>` is `<dir>/run-queue.lock`.
Neither is canonicalised: the suite passes an absolute, already-canonical
`HARNESS_RUN_QUEUE_DIR` and compares the lines against `$Q/run-queue.lock`
and, for a directory that cannot be created, against the value it gave.

Queued, three lines, once, before the first sleep:

    run-queue: queued: <self> waits for another harness run on this machine to finish.
    run-queue:   behind pid <pid>, started <started>, in <root>: <command>
    run-queue: this is waiting, not hanging: it starts by itself when that run ends. If pid <pid> is not that run, delete <lock> and it starts.

Heartbeat, one line each time the heartbeat interval has passed since the
last line this waiter printed, reading the record again each time (the holder
may have changed):

    run-queue: still queued behind pid <pid> in <root>: <command> (waited <span>)

Through, one line, printed if and only if the queued lines were:

    run-queue: starting <self> after waiting <span>.

Reclaim, one line (either may precede a silent take, or follow a wait):

    run-queue: reclaimed a stale queue lock from pid <pid> (<command>, in <root>); that process is no longer running.
    run-queue: reclaimed an unreadable queue lock (no pid recorded in <lock>).

Proceeding without the queue (AC-9), one line, the one that applies:

    run-queue: cannot use <dir>; <self> runs without the machine-wide queue.
    run-queue: neither HARNESS_RUN_QUEUE_DIR nor HOME is set; <self> runs without the machine-wide queue.
    run-queue: scripts/run-queue.sh is missing; <self> runs without the machine-wide queue.

An uncontended take and every release print nothing (AC-4): the whole-run
goldens of other suites depend on it, and so does every consumer's log.

**C-4. Module, names, wiring (decisions 4, 10).** New file
`scripts/run-queue.sh`, sourced, never executed, bash 3.2, awk and coreutils
only, with a header in the style of `run-lock.sh`'s that states C-1, C-2's
limits and C-5.

    RUN_QUEUE_HELD=0            # 1 while this process holds the queue
    RUN_QUEUE_FILE=""           # the lock's absolute path, once resolved
    run_queue_alive <pid>       # 0 if running. ONE LINE, exactly:
                                #   run_queue_alive() { kill -0 "$1" 2>/dev/null; }
                                # DV-1's expression targets it
    run_queue_span <seconds>    # prints <M>m<SS>s (C-6)
    run_queue_acquire <root> <command>
                                # returns 0 ALWAYS: took it, nested, off, or
                                # proceeding without it. It never refuses.
    run_queue_release           # removes the lock iff this process took it
                                # and it still records $$; a no-op otherwise,
                                # including in a subshell; never fails

Taking exports `HARNESS_RUN_QUEUE_LOCK` (the lock's absolute path) and
`HARNESS_RUN_QUEUE_PID` (`$$`).

`scripts/run-lock.sh` changes in two places and nowhere else:

- *Join.* On every path of `run_lock_acquire` that returns 0 **having taken**
  the run lock (three call sites of `run_lock_taken` today), the queue is
  joined before returning, by three tests in this order:
  (a) `HARNESS_RUN_QUEUE` is `off`: return 0;
  (b) `run_lock_full "$self"` (C-5) says the run is not full: return 0;
  (c) source `run-queue.sh` from the directory `run-lock.sh` itself is in
  (resolved from `BASH_SOURCE`, not `$PWD`, not `<root>`: the sourcing
  script's own copy) and call `run_queue_acquire "$root" "$self"`; a missing
  file prints C-3's line and returns 0.
  (a) and (b) come before the file is looked for and before anything is
  read or written outside the tree, so a run with the queue off and every
  non-full run print nothing and touch nothing, whatever the tree and the
  queue directory hold. The nested path, step (1), returns as it does today
  and never joins: a run nested under a run-lock holder in the same tree is
  covered by its holder.
- *Leave.* `run_lock_release` removes `run.lock` as today and then calls
  `run_queue_release` if it is defined. The queue goes last, so the next run
  starts only after this one has nothing left held.

**Lock order, and why it cannot deadlock.** Run lock first, then the queue.
Same-tree contention is therefore still HARNESS-034's fast refusal with exit
2, unchanged; the queue is the only lock anything waits on, and nothing waits
while trying to take a second lock it does not already hold. One consequence
to state in the header: a run waiting in the queue already holds its own
tree's `run.lock`, so a third run started in that tree is refused, naming the
waiter. That is HARNESS-034 behaving as specified.

**Signals.** Both callers set `trap ... EXIT`, `trap 'exit 130' INT` and
`trap 'exit 143' TERM` before `run_lock_acquire`, and their EXIT handlers
call `run_lock_release`. A waiter signalled in the queue therefore exits
through that path: its `run.lock` is removed, it holds no queue lock, and its
temporary record does not exist between attempts. Bash runs a trap only when
the foreground command returns, so a plain `sleep` delays the exit by up to
one poll interval; AC-8's bound allows for it, and GREEN may wait on a
background `sleep` instead if it reaps it. `selftest_exit` already releases
last, after its suites have exited. `INT` takes the same path as `TERM`, but
a background job of a non-interactive shell starts with `INT` ignored and an
ignored signal cannot be trapped, so AC-8 names `TERM`; RED tests `INT` only
if it can deliver one, and says which in the handoff.

**C-5. Which runs queue (decision 7; the user's answer of 2026-11-13: "Only
full runs").** A run joins the queue if and only if it is a **full run**:

| Run | Full | Queues |
|---|---|---|
| `gates.sh` with none of `--fast`, `--gate`, `--skip`, `--required` (alone, or with `--story <id>`): the run of every gate, the one whose `last-gate-run` stamp says `FULL=yes` (amended in RED, below) | yes | yes |
| `gates.sh --fast`, `--gate X`, `--skip X`, `--required` | no | no |
| `gates.sh --list`, `--audit` | no | no - they take no run lock either |
| `selftest.sh` with no argument at all: every suite | yes | yes |
| `selftest.sh <suite>...` | no | no |
| `selftest.sh --changed`, whatever it resolves to | no | no - a known gap, below |
| `selftest-needed.sh`, `check-boundaries.sh`, `ci-local.sh` itself, `attest.sh` itself | - | no - each full run they start queues by itself |

**A non-full run keeps today's behaviour exactly** (AC-10): its tree's run
lock and nothing else. It does not wait behind a full run, a full run does
not wait behind it, and it neither reads nor writes the queue directory.

**How `run-lock.sh` learns it, without either caller being edited.** From
the command string both callers already pass to `run_lock_acquire`
(`scripts/gates.sh${*:+ $*}` and `scripts/selftest.sh${*:+ $*}`, their
arguments verbatim). One function, in `run-lock.sh` and not in
`run-queue.sh`, so that a non-full run is recognised before `run-queue.sh`
is looked for:

    run_lock_full <command>     # 0 if <command> is a full run, 1 otherwise

- first word `scripts/gates.sh`: full unless one of the remaining words is
  exactly `--fast`, `--gate`, `--skip`, `--required`, `--list` or
  `--audit`. A `--story` value cannot be mistaken for one: `valid_story_id`
  requires a letter or digit first.
- exactly `scripts/selftest.sh`, with no further word: full.
- anything else, an empty string included: not full.

The function's opening line is exactly `run_lock_full() {`, alone on its
line, with the body on the lines after it: DV-3's one-line `sed` expression
targets that line, and the suite pins it with `grep -cxF`.

Words are split on spaces, with no globbing (`set -f`, or a `case` over the
padded string). The suite pins it as a table, directly, beside the runs.
`--required` is in the list because `gates.sh` itself calls it a subset
("the other three are already subsets", line 114); RED checks which
invocations write `last-gate-run` and amends this block if that reading is
wrong.

*Amended in RED (2026-11-13, test-developer), three changes, no criterion
touched.* (1) **Every** `gates.sh` mode that runs a gate writes
`last-gate-run` - `--fast`, `--gate`, `--skip` and `--required` included
(`gates.sh` lines 1184-1189 and 1232-1243) - so "the one that writes
`last-gate-run`" did not single out a full run. What does is the stamp's
`FULL=` field: `FULLRUN=no` exactly when `--gate`, `--required`, `--fast`
or `--skip` was given, which is this block's list. The classification is
unchanged; only the table's wording was wrong. (2) `--list` and `--audit`
are added to the word list. The table says they are not full, and AC-10
requires `run_lock_full` to answer as the table says for every row; the
word rule as written would have called `scripts/gates.sh --list` full.
They never reach `run_lock_acquire`, so no run changes behaviour. (3) The
opening line is pinned, so that DV-3's expression has one line to target
(handoff).

**The `--changed` gap, and why it is left.** The self-test before a PR is
`selftest.sh --changed`, and when it resolves to every suite it is as heavy
as a full run. Whether it did is known only inside `selftest.sh`, after the
selection (today the variable `CHANGED_HDR`), and HARNESS-107 is changing
`--changed` in another worktree. Reading that state from `run-lock.sh`
would tie this story to internals in flight, and passing it as an argument
would mean editing `selftest.sh`. So `--changed` never queues here, and
closing the gap is a follow-up story once HARNESS-107 has merged (Out of
scope). Until then the user's rule for `--changed` runs is the one in force
today: do not start one beside another run.

**C-6. The numbers.**

- `HARNESS_RUN_QUEUE_POLL`, seconds between attempts, default **5**: the
  longest a free machine stays idle before a waiter notices, and the longest
  a signalled waiter takes to exit. Passed to `sleep` as given.
- `HARNESS_RUN_QUEUE_HEARTBEAT`, seconds between `still queued` lines,
  default **60**: one line a minute is visibly alive in a log and is 180
  lines over the three-hour case. Compared against elapsed whole seconds
  (bash's `SECONDS`), so the suite's value of 1 with a poll of 1 yields a line
  on every attempt after the first second.
- `<span>` is `run_queue_span <seconds>`: whole minutes, `m`, two-digit
  seconds, `s`. `0` gives `0m00s`, `65` gives `1m05s`, `10800` gives
  `180m00s`. No hours: one unit boundary, one place to be wrong.

**C-7. Nesting, and the harness's own suites (decisions 5, 6, 8).** Two
separate mechanisms, and each case relies on one of them:

- *A run in the holder's process tree passes through.* At the top of
  `run_queue_acquire`: if `HARNESS_RUN_QUEUE_LOCK` equals this run's own lock
  path, the lock exists, the pid it records equals `HARNESS_RUN_QUEUE_PID`,
  and that pid is alive, return 0 having taken, released and printed nothing.
  The path stops a run adopting the queue of some other directory it
  inherited variables from; the recorded pid stops a stale or hand-set
  variable being a bypass (AC-6). This is what covers a gate command that
  runs `selftest.sh`, in the same tree (where step (1) of `run_lock_acquire`
  already returned) and in **another** tree (where only this check stands
  between the inner run and waiting on its own ancestor).
  *The limit, for the header:* a gate command that scrubs its environment
  (`env -i`) and then runs a harness script in another tree waits on its
  ancestor for ever, with the heartbeat naming it. Not detected (Out of
  scope).
- *The harness's suites never join the queue.* `.claude/tests/_lib.sh`
  exports `HARNESS_RUN_QUEUE=off`, unconditionally, directly after its
  `HARNESS_PS_LISTING` export and with a comment in the same style. This
  departs from the dispatch's suggestion of a per-test temporary queue
  directory, for a reason: `_lib.sh` owns no EXIT trap (each suite sets its
  own), so a directory made there has no owner to remove it, and "off" is the
  exact analogue of `HARNESS_PS_LISTING=/dev/null` - every fixture run sees
  no queue, and only the suite that is about the queue turns it on, per call.
  It is also what makes a suite run by hand (`bash .claude/tests/x.test.sh`)
  independent of the host.
- *`run-queue.test.sh` turns it on per call*, never for the suite's own
  shell: `HARNESS_RUN_QUEUE= HARNESS_RUN_QUEUE_DIR="$Q" HARNESS_RUN_QUEUE_POLL=1 ...`
  on the command, with `$Q` a temp directory the suite removes. Under the
  real `selftest.sh` the suite inherits `HARNESS_RUN_QUEUE_LOCK` and
  `HARNESS_RUN_QUEUE_PID` naming the host's queue; no case may depend on
  their being absent, and the cases that are about them set them explicitly.
  The suite must give the same result run directly and under `selftest.sh`.
- *Values.* `off` disables. Unset, empty and every other value leave the
  queue on. `CI=true` does **not** disable it: many tools and some local
  shells set `CI`, and a lock that a common variable switches off is one
  nobody can rely on.
- *No change to `.github/workflows/`.* This departs from the dispatch's
  suggestion of setting the opt-out there. On a hosted runner one job is one
  machine: the queue is never contended, an uncontended take is silent
  (AC-4), and a runner without a usable `$HOME` proceeds (AC-9). On a
  self-hosted runner that takes several jobs, the queue is wanted. Switching
  it off buys nothing in the first case and loses the feature in the second,
  and `ci-local.test.sh` derives its step list from those files. The variable
  exists for whoever needs it.

**C-8. The fixture and how waiting is proven.** `make_project_fixture` copies
the whole of `scripts/`, so a fixture has `run-queue.sh` once GREEN has
written it. Reuse `run-lock.test.sh`'s arrangement: a gate command (and a
suite) that touches `m/started`, waits for `m/release` with a bound, and
writes `m/finished` last. For this story each also records, as it starts,
whether the other trees' `m/started` exists without their `m/finished`
(another run in progress), which is AC-1's "A had finished before B began"
and AC-2's "no two at once", observed by the runs themselves and not by the
test's clock. "Has not started" is asserted after the waiter's queued line
has appeared in its stderr (a bounded wait for the line, then at least two
poll intervals), never after a bare sleep. Every background pid is reaped on
EXIT, and the holder for AC-5's live foreign pid is `hold_until_killed`.

RED: `scripts/run-queue.sh` does not exist, so cases that source it directly
(`run_queue_span`) test for the file first and fail one assertion each in
the if and the else alike, as HARNESS-074 did, so that the executed count is
the same in RED and GREEN. Cases through `gates.sh` and `selftest.sh` fail
for the right reason on their own: B starts beside A.
`run_lock_full` does not exist in RED either, and its table cases use the same
if and else. **AC-10's "starts at once" assertions pass on arrival in RED**,
because nothing queues yet: the handoff lists them as green on arrival, and
DV-3 earns them at GATES.

A full `selftest.sh` in a fixture runs every suite the fixture holds
(`run-lock.test.sh`'s fixture has three, one of them failing by design), so
its exit status alone is not 0; compare it with the same run's status with
the queue off.

**C-9. Oracle partition.** All ten criteria are **mechanical**: pin the
lines of C-3 whole, the exit statuses exactly (0, 130, 143 - never
"non-zero"), the record's four fields, the variable names. Within them the
defaults and the span format of C-6 are **settled**: read out, not tuned.
Nothing here is oracle-free; the one measured quantity is time, and no
criterion asserts a duration beyond "bounded" and "at least two poll
intervals". Do not add an assertion that a wait took N seconds.

**C-10. The floor and the release.** RED adds `floor | run-queue | <N>` to
`floors.conf` in suite-name order, with a dated comment in the form the
HARNESS-034 and HARNESS-074 entries use, and `run-queue <N>` to the table in
`selftest.test.sh` (line 553 holds `run-lock 141`), where `<N>` is the
executed count RED measures. GREEN re-measures; if it differs, the handoff
was wrong and GREEN reports it instead of moving the number. No other floor
moves: `run-lock` stays 141, `gates` 1002, `selftest` 366, `host-load` 72. If
any suite pins a count of suites or of harness shell files exactly, RED finds
it with one grep and says so (the one known count, `sigpipe.test.sh`'s, is an
"at least").
`.claude/harness/VERSION` goes to the next free release number with the real
calendar date of the change. `125` is HARNESS-106's and `126` is claimed by
HARNESS-107, in flight on
`story/HARNESS-107-the-changed-suites-self-test-runs-the-sh`; whichever of
the two stories merges second takes the number after the first's.

**C-11. `.claude/state/README.md` (GREEN).** One paragraph after the
`run.lock` paragraph: the machine-wide queue lock is **not** under
`.claude/state` and not in the table (the table is the tree's own state
files, and `settings.test.sh` checks its rows against `settings.json`); where
it is (C-1), what it records, that a waiting run prints `run-queue: queued`,
that one left behind by a killed run is reclaimed by pid, and that deleting
it by hand is the remedy for a recycled pid. RED confirms before GREEN that
prose outside the table is not read by `settings.test.sh`.

**C-12. Changed signatures: none.** `run_lock_acquire <root> <command>` and
`run_lock_release` keep their names, arguments and return values (0, or 2 on
refusal). Their callers, grep-listed 2026-11-13: `scripts/gates.sh` lines
285-289 and `scripts/selftest.sh` lines 472, 507, 511-515; the suites call
them only through those two scripts. `run_queue_*` and `run_lock_full` are
new.

**C-13. Commands.**

    bash scripts/selftest.sh run-queue
    bash scripts/selftest.sh run-queue run-lock
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue run-lock
    bash scripts/selftest-needed.sh --suites
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/gates.sh --fast

`_lib.sh` is read by every suite, so `selftest-needed.sh --suites` is
expected to print `all` for this story's diff and the self-test before the PR
is the full one. Run it once, and never beside another session's run: until
this story ships, nothing queues them for you.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one "defect put back"
mutation for the central claim (DV-1), and one that earns the assertions
which pass on arrival in RED (DV-3). DV-2 is not a mutation: it is the
probe against the real tree, which this story owes because its fixtures are
all trees the suite built for itself.

- **DV-1, the defect put back (AC-1).** With the liveness check reading every
  holder as gone, a waiter reclaims a live holder's lock and runs beside it,
  which is the machine as it is today. `mutate.sh` must report 1 line
  changed. The `run-queue` suite **must** fail, and among the failures must
  be AC-1's assertion that B's gate command had not started while A held;
  AC-5's "a live pid is never reclaimed" is expected red too. RED's handoff
  predicts the exact count and names the assertions; the orchestrator
  compares. If AC-1's assertion stays green under this mutation, the suite
  is not observing concurrency and AC-1 is unmet. RED cannot run this:
  `scripts/run-queue.sh` does not exist until GREEN. **Owner: GATES.**

      bash scripts/mutate.sh scripts/run-queue.sh 's|^run_queue_alive() { kill -0 "\$1" 2>/dev/null; }$|run_queue_alive() { false; }|' -- bash scripts/selftest.sh run-queue

  RED's handoff restates this expression against C-4 as amended.

- **DV-2, the real tree against a held queue (AC-1, AC-3, AC-10).** Not a
  fixture: this checkout's own `scripts/selftest.sh` and `scripts/gates.sh`,
  with the queue directory pointed at a temp directory (never the host's
  real queue, which another session may be in) holding a lock whose recorded
  pid is a live process the prober started, and `HARNESS_RUN_QUEUE_POLL=1`.
  Four runs, the cheapest set that shows both halves of the rule on the real
  callers:
  - *Full runs wait.* `bash scripts/selftest.sh` and `bash scripts/gates.sh`,
    each started in the background: each **must** print C-3's three queued
    lines naming that pid and no suite or gate output. The prober then sends
    each `TERM` while it is still queued: each **must** exit 143 having run
    nothing, leaving `.claude/state/run.lock` gone, the temp lock unchanged
    and, for `gates.sh`, the story's `## Gate results` and
    `.claude/state/last-gate-run` untouched. Neither full run is paid for:
    that a queued run starts after the release is the fixtures' claim (AC-1),
    and this probe's is that the real callers reach the queue at all.
  - *Non-full runs do not.* `bash scripts/selftest.sh policy` and
    `bash scripts/gates.sh --fast`, with the same lock still held: each
    **must** run at once, print no `run-queue:` line, and exit with the
    status it has with `HARNESS_RUN_QUEUE=off` (measured first, not assumed
    to be 0: every gate here is unconfigured).
  The prober pastes the four runs' stderr and exit statuses, and confirms the
  holder process was killed and the temp directory removed. This cannot run
  before GREEN, and it is the only check that the wiring in `run-lock.sh` is
  reached by the real callers of this tree and not only by a fixture's copy
  of them. **Owner: GATES.**

- **DV-3, the non-full rule earned (AC-10).** AC-10's assertions that a
  non-full run starts at once beside a held queue pass in RED, when nothing
  queues at all, so nothing has watched them fail. With `run_lock_full`
  answering "full" for every command, `gates.sh --fast` and a named-suite
  `selftest.sh` join the queue: those assertions **must** go red (the run
  waits, prints the queued lines, writes a temporary record), and the
  `run_lock_full` table rows for non-full commands with them. RED's handoff
  gives the one-line `sed` expression against `run_lock_full` as built and
  predicts the count. RED cannot run it: the function does not exist until
  GREEN. **Owner: GATES.**

      bash scripts/mutate.sh scripts/run-lock.sh '<expression from the handoff>' -- bash scripts/selftest.sh run-queue

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

Planned by `bash scripts/plan.sh write HARNESS-108` from `.claude/harness/models.conf`.
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

- PLANNED (2026-11-13, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the orchestrating session; no override was reported to it, and the agent declares `model: fable`.
- PLANNED, the scope change (2026-11-13, same dispatch continued): `lead-po`, resolved **claude-fable-5-2**. Rewrote the criteria and C-5 for the user's "Only full runs".
- No departure from the plan. All ten criteria are mechanical, with the defaults and the span format settled (Contract, C-9).

## Out of scope

- **First-come-first-served.** Waiters poll and one of them wins. No ticket
  numbers, no ordering, no priority for a short run over a long one.
- **A maximum wait, or giving up.** A waiter waits until it gets the queue or
  is signalled (C-2).
- **Detecting a run that waits on its own ancestor.** The nested pass-through
  (C-7) covers a descendant that inherits its environment. One that does not
  is not detected; the heartbeat names what it waits behind.
- **Closing the reclaim race entirely** (C-2). Two waiters reclaiming one
  dead holder in the same instant can both run. Recorded, not fixed.
- **Queues across users, WSL, containers or a second MSYS runtime.** One
  user, one pid namespace, one `$HOME`.
- **Queueing anything that is not `gates.sh` or `selftest.sh`.** A project's
  own `npm test` run by hand, `check-boundaries.sh`, `mutate.sh` with a test
  command that is not one of the two, `ci-local.sh` as a whole (its steps
  queue one by one, and another run may get in between them).
- **`selftest.sh --changed`.** It never queues, even when it resolves to
  every suite and is as heavy as a full run (C-5). A known gap: closing it
  needs `selftest.sh` to say what `--changed` resolved to, and HARNESS-107 is
  changing that code. A follow-up story after HARNESS-107 merges.
- **Non-full runs.** `--fast`, `--gate`, `--skip`, `--required` and
  named-suite runs neither wait nor are waited for (AC-10). Several of them
  side by side, or one beside a full run, is today's behaviour and stays.
- **Same-tree waiting.** A second run in the same tree is still refused with
  exit 2 by the run lock (HARNESS-034). Turning that refusal into a wait is a
  different decision with its own history, and not this story.
- **`scripts/host-load.sh`.** Its warning is unchanged. It will list a queued
  run as another run on the host, since a waiter is a `selftest.sh` process in
  `ps`; teaching it the difference is a separate story if it proves noisy.
- **`scripts/gates.sh`, `scripts/selftest.sh`, `scripts/selftest-needed.sh`,
  `.github/workflows/*`.** Not edited, not even their comments (Contract,
  "Not written").
- **`CLAUDE.md`, `rules.md`, the commands and the skills.** No new prose. The
  queued message is the documentation an agent meets at the moment it needs
  it; the only prose is the script's header and one paragraph in
  `.claude/state/README.md`.
- **A command to show or clear the queue.** The message names the file.
- **Fixing the consumers.** They get the queue by refreshing to the release
  this story ships.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One new suite, `.claude/tests/run-queue.test.sh` (225 executed assertions),
plus the one export in `.claude/tests/_lib.sh`. Level: integration through
the real callers - this tree's `scripts/` copied into three fixture trees
A, B, C (`make_project_fixture`), each run as `bash scripts/gates.sh` or
`bash scripts/selftest.sh` from inside its tree with the queue turned on per
call (`HARNESS_RUN_QUEUE=` empty, `HARNESS_RUN_QUEUE_DIR=$W/q`, `POLL=1`,
`HEARTBEAT=1`). Unit level only where the logic lives in one function:
`run_lock_full` (table) and `run_queue_span` (table), sourced from this
checkout's `scripts/`.

The instrument (C-8): every gate command and every fixture suite is
`m/work.sh`, which makes `$SH/run.<tree>` BEFORE looking for the others,
then records `overlap-start` (other trees in progress), `done-before`
(trees already finished) and, if `HARNESS_RUN_QUEUE_DIR` is set, a copy of
the queue lock as it stands (`qlock`); holds on `m/k/release` if
`m/k/hold` existed; records `overlap-end`; marks itself done. Overlap is
therefore observed by the runs themselves, never by the clock. "Has not
started" is asserted only after the waiter's queued line (or its own start)
appeared, plus >= 2 poll intervals (2.5-3.5 s). Every wait is bounded.

| Describe block | Tests (each a sentence in the suite) | AC |
|---|---|---|
| AC-1 (`pair_case` x3: gates behind gates, selftest behind gates, gates behind selftest) | B has not started while A holds, over two poll intervals after queuing; A still alive then (precondition); A exits 0; B gets through within the bound; B's work finishes; B's status equals the same run's alone with the queue off (measured at the top, `SOLO_GATES`/`SOLO_SELF`); B's work records A finished before it began; B saw no run in progress at start; A saw none at end; queue dir empty afterwards (11 each) | AC-1 |
| AC-3 | queued lines 1, 2, 3 each exactly once, whole-line, line 2 from A's record (pid, started, root, command); first `run-queue:` line is line 1; >= 1 `still queued` line (prefix + `^[0-9]+m[0-5][0-9]s\)$`); exactly one `starting` line, and it is the last `run-queue:` line; none on stdout; a queued selftest.sh names itself; a gates.sh behind a selftest.sh names `scripts/selftest.sh` | AC-3 |
| AC-2 | A, B, C exit 0; B and C finish; for each of A, B, C: no other run in progress at start and at end (6); queue dir empty | AC-2 |
| AC-4 (`ac4_case` for gates.sh and selftest.sh) | lock existed while the work ran; records pid = the run's `$!`, `started` UTC to the second, command, root (absolute); exactly four TAB lines `pid started command root`; no `run-queue:` line on either stream; stderr `cmp`-identical to the same run with `HARNESS_RUN_QUEUE=off`; same exit status; queue dir empty afterwards | AC-4 |
| AC-5 (`reclaim_case` x3: dead pid, no pid line, non-numeric pid) | the reclaim line exactly once; no queued line; work runs, exit 0; its work saw a lock recording its own pid; queue dir empty | AC-5 |
| AC-5 live (a plain `sleep 600` holds the pid) | not started over two poll intervals; queued line 2 names the sleep's pid; no reclaim line; lock byte-identical; then, sleep killed: reclaims, runs, exit 0; stale line naming that pid once; starting line once; dir empty | AC-5 |
| AC-6 nested | outer full gates.sh in A whose gate runs a full selftest.sh in A, then in B: completes within bound; outer exit 0; both inner exit 0; no inner `run-queue:` line; queue lock records the outer pid after each inner run; dir empty after | AC-6 |
| AC-6 not a bypass (`bypass_case` x2: right path + wrong live pid; recorded pid + another queue's path, that queue holding the same record) | B queues; not started over two poll intervals; holder's lock byte-identical | AC-6 |
| AC-7 / AC-10 beside a held queue (`beside_case`) | `HARNESS_RUN_QUEUE=off` full gates.sh, `--fast`, `--gate unit`, `--skip lint`, `--required`, `selftest.sh work`: each starts its work at once while A holds; A alive then; exit 0; no `run-queue:` line; queue dir byte-identical. Plus the AC-7 control (B's work saw A in progress). Plus a non-full run in A's own tree: exit 2, run-lock refusal line 1 | AC-7, AC-10 |
| AC-10 non-full in progress | B's `--gate unit` holding wrote nothing in the queue dir; A's full run starts at once beside it (`present B`) and its work saw a lock recording A's pid; both exit 0; dir empty | AC-10 |
| AC-10 table | `run_lock_full` for 19 rows: 3 full, 16 not full, incl. `--story T-1`, `--story T-1 --fast`, `--changed`, `--list`, `--audit`, `''` | AC-10 |
| AC-7 values (`value_case` x4: unset, `OFF`, `no`, `CI=true` with it unset) | queues behind a live planted holder; has not started | AC-7 |
| AC-7 `_lib.sh` | sourcing leaves `off` when unset; still `off` when the environment says `on`; exported to a child | AC-7 |
| AC-8 (`term_waiter` x2: gates.sh, selftest.sh) | queued (precondition); TERM: exits within 10 s; status 143; ran nothing; queue dir holds only the holder's lock, unchanged; the waiter's tree holds no `run.lock` | AC-8 |
| AC-8 holder | A, sent TERM, exits 143; the lock no longer records A; the waiter runs, exit 0; its work began only after A's ended; dir empty | AC-8 |
| AC-9 (`noq_case` x4: dir under a regular file for gates.sh and selftest.sh; neither variable nor HOME; a tree without `run-queue.sh`) | the C-3 line exactly once; no other `run-queue:` line; work runs with the status it has with the queue off (for the no-HOME case measured with HOME unset too). Plus: the tree without run-queue.sh writes nothing in the queue dir | AC-9 |
| C-4, C-6 | `run_queue_alive` is the exact one-liner DV-1 mutates; `run_lock_full() {` is the exact line DV-3 mutates; `run_queue_span` 0, 59, 60, 65, 10800 | C-4, C-5, C-6 (DV-1, DV-3 targets) |

`INT` is not tested: a background job of a non-interactive shell starts with
INT ignored and an ignored signal cannot be trapped (C-4, Signals).

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

Written by `test-developer` (RED, 2026-11-13). Dispatched without a model
override; the agent declares `model: opus` and ran as Opus 5.5
(`claude-opus-5-5`).

**Command.**

    bash scripts/selftest.sh run-queue
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue     # the recorded form

**The record** (attested, this tree; the orchestrator checks it with
`attest.sh check`):

    run:      2026-11-14T02:06:54Z
    command:  bash scripts/selftest.sh run-queue
    tree:     fea1ab624cc0ba454303498852be8e7cb8e85966
    after:    fea1ab624cc0ba454303498852be8e7cb8e85966
    status:   ok
    exit:     1
    duration: 278s
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261114T020654Z.201701.log

    run-queue: 122 passed, 103 failed
    FAIL run-queue  did 122 units of work, below the floor of 225 in .claude/tests/floors.conf

The bookkeeping edits (the `_lib.sh` export, the `selftest.test.sh` table
row) do not break their suites, and the fast gates are admissible - on the
same tree:

    command:  bash scripts/selftest.sh selftest
    tree:     fea1ab624cc0ba454303498852be8e7cb8e85966   status: ok   exit: 0   duration: 332s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261114T021138Z.210686.log

    command:  bash scripts/selftest.sh lib
    tree:     fea1ab624cc0ba454303498852be8e7cb8e85966   status: ok   exit: 0   duration: 129s
    last:     1 harness suite(s) passed.     (lib: 324 passed, 0 failed)
    log:      .claude/state/attest-logs/20261114T021716Z.219459.log

    command:  bash scripts/gates.sh --fast
    tree:     fea1ab624cc0ba454303498852be8e7cb8e85966   status: ok   exit: 0   duration: 2s
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261114T021927Z.223828.log

`gates.sh --fast` has nothing to say about this suite: every gate is
unconfigured in this repository (Context, "The required gate"), so it ran
none, and the red is carried by the self-test alone. Its shape is right
(exit 0, no config error); the only note is the new suite being untracked.
`bash scripts/check-sigpipe.sh` (63 files, 0 findings) and
`bash scripts/check-grep-count.sh` (63 files, 0 findings) are clean over
the tree with the new suite in it.

The earlier attested run on the tree before the floors comment was
finalised (`20261114T015749Z.185140.log`, tree `6cfa918e...`) reported the
identical 103 FAIL lines (`diff` of the two FAIL lists: empty).

**Why this is the right failure.** `scripts/run-queue.sh` does not exist and
`scripts/run-lock.sh` defines no `run_lock_full`, so nothing queues: every
fixture run still takes only its own tree's `run.lock`. Every one of the 103
reds is one of three things, and nothing else:
(a) a run that should have waited started beside the holder - its work
recorded the holder in `overlap-start`, did not find the holder in
`done-before`, or started inside two poll intervals of queuing;
(b) a `run-queue:` line that should exist does not (queued, heartbeat,
starting, reclaim, cannot-use, missing), or a queue lock that should exist
does not (AC-4's record, AC-6's "still records the outer pid", AC-10's
"taken the queue"), or a planted stale lock is left in place;
(c) the direct cases' "scripts/run-queue.sh does not exist" / "defines no
run_lock_full", one per row, and the two static pins.
No red is a syntax error, a fixture bug or a timeout: every case completed
inside its bound (no `WTO=yes` path was taken; the suite ran 4m48s), and the
three fixture trees' baseline runs with the queue off exit 0 (`SOLO_GATES=0`,
`SOLO_SELF=0`). Failure output, by case, from the log above (the full text
of each is in the log; every FAIL there is one of these):

    AC-1  ac1-gg, ac1-gs, ac1-sg: 3 each - "B's full <s> has not started its work while A holds the queue"
          (actual: present); "B's work records, as it starts, that A's had finished" (expected: A,
          actual: ""); "B's work saw no other run in progress as it started" (expected: "", actual: A)
    AC-3  9 - queued lines 1/2/3 (expected: 1, actual: 0); "the first run-queue: line is the queued line"
          (actual: ""); "at least one still-queued line" (no (0)); "one starting line" (0); "the
          starting line is the last" (0); selftest.sh names itself (0); behind scripts/selftest.sh (0)
    AC-2  4 - B at start (A), B at end (A C), C at start (A B), C at end (A B)
    AC-4  6 each for gates.sh and selftest.sh - lock existed (absent); pid, started, command, root,
          four-line shape (all empty)
    AC-5  ac5-stale / ac5-nopid / ac5-nonnumeric: 3 each - the reclaim line (0); "its work saw a lock
          recording its own pid" (actual: the planted pid, or empty); "leaves the queue directory
          empty" (the planted record is still there)
    AC-5 live  5 - not started (present); queued line 2 names the sleep (0); stale line once (0);
          starting line once (0); dir empty afterwards (the planted record)
    AC-6  2 - "after the inner run in A/B has ended, the queue lock still records the outer run's pid"
          (actual: "")
    AC-6 bypass  ac6-wrong-pid, ac6-wrong-path: 2 each - queues (0); not started (present)
    AC-10 1 - "has taken the queue: its work saw a lock recording its pid" (actual: "")
    AC-10 table  19 - "scripts/run-lock.sh defines no run_lock_full"
    AC-7  values: 2 each x4 - queues (0); not started (present)
    AC-8  gates.sh waiter 2 - queued (0); ran nothing (present)
          selftest.sh waiter 3 - queued (0); status 143 (actual: 0); ran nothing (present)
          holder 1 - "its work began only after A's had ended" (actual: A)
    AC-9  2 each x4 - the one line (0); no other run-queue: line (0)
    C-4/C-6  run_queue_alive one-liner (""); run_lock_full() { line (0); run_queue_span x5
          ("scripts/run-queue.sh does not exist")

Before the `_lib.sh` export was written, the same suite was run once
(2026-11-13, not attested; `run-queue: 118 passed, 107 failed`): the three
AC-7 `_lib.sh` assertions were red then (actual `<unset>`, `on`, `<unset>`),
and are green now - watched to fail, then made to pass by the one line RED
owns. (The other +1 between the two runs is a fixture-name bug fixed in
between: the AC-9 missing-file case's label held a `/`, so its output file
could not be created and its run never started; renamed, it now runs.)

**Every test, one line each.** The table in `## Test plan` lists every
assertion by case and AC; it is the per-test list, and the suite's own
sentences are the names a failure prints.

**Files touched (RED).**

- `.claude/tests/run-queue.test.sh` - new, the suite.
- `.claude/tests/_lib.sh` - `export HARNESS_RUN_QUEUE=off` with its comment,
  directly after the `HARNESS_PS_LISTING` export (C-7).
- `.claude/tests/floors.conf` - `floor | run-queue | 225`, after `run-lock`,
  and a dated comment at the foot.
- `.claude/tests/selftest.test.sh` - `run-queue 225` in the hand-copied
  table, after `run-lock 141`. Nothing in any suite pins the number of suites
  or harness shell files exactly (`grep` over `.claude/tests/*.sh`; the one
  count, `sigpipe.test.sh`'s, is "at least 36").
- `docs/backlog/stories/HARNESS-108.md` - this handoff, `## Test plan`, and
  the three Contract amendments below.

**The shape the suite pins - stated as fact.**

- `scripts/run-queue.sh` exists, is sourceable by `bash` with `set -u`
  in effect (the suite's `_lib.sh` sets `-uo pipefail`), and defines:
  - `run_queue_alive`, on exactly this one line (`grep -cxF`):
    `run_queue_alive() { kill -0 "$1" 2>/dev/null; }`
  - `run_queue_span <seconds>` printing `<M>m<SS>s` with no newline required
    (read through `$( )`): `0 -> 0m00s`, `59 -> 0m59s`, `60 -> 1m00s`,
    `65 -> 1m05s`, `10800 -> 180m00s`.
- `scripts/run-lock.sh` defines `run_lock_full <command>`, returning 0 for
  full and 1 for not full, opening on exactly the line `run_lock_full() {`
  (`grep -cxF`), callable after a plain `. scripts/run-lock.sh` with `set -f`
  in the caller. Its 19 rows are the suite's `FULL_ROWS`; full: 
  `scripts/gates.sh`, `scripts/gates.sh --story T-1`, `scripts/selftest.sh`;
  every other row not full, `''` included.
- The variables, by exact name: `HARNESS_RUN_QUEUE` (`off` disables; unset,
  empty, `OFF`, `no`, and `CI=true` with it unset leave it on),
  `HARNESS_RUN_QUEUE_DIR`, `HARNESS_RUN_QUEUE_POLL`,
  `HARNESS_RUN_QUEUE_HEARTBEAT`, `HARNESS_RUN_QUEUE_LOCK`,
  `HARNESS_RUN_QUEUE_PID`. The lock is `$HARNESS_RUN_QUEUE_DIR/run-queue.lock`.
- The record: exactly four lines `pid\t<$$>`, `started\t<UTC
  YYYY-MM-DDTHH:MM:SSZ>`, `command\t<the string given to run_lock_acquire>`,
  `root\t<the root given, absolute>`, in that order (`rec_keys` reads the
  first field of each line and requires exactly two TAB fields per line).
- Every C-3 line, whole, on stderr only. `<self>` is `scripts/gates.sh` or
  `scripts/selftest.sh` (a full run's command string has no arguments).
  `<lock>` is `$HARNESS_RUN_QUEUE_DIR/run-queue.lock` and `<dir>` is
  `$HARNESS_RUN_QUEUE_DIR` as given (C-3 as amended). The heartbeat line is
  matched as the fixed prefix `run-queue: still queued behind pid <pid> in
  <root>: <command> (waited ` followed by `^[0-9]+m[0-5][0-9]s\)$`; the
  starting line as `run-queue: starting <self> after waiting ` followed by
  `^[0-9]+m[0-5][0-9]s\.$`.
- Exit statuses: a waiter sent TERM exits 143 within 10 s (10 poll intervals
  at `POLL=1`; the bound is wide for Windows process cost, and C-4's
  "a plain `sleep` delays the exit by up to one poll interval" fits inside it).
- What the suite reads from a run's own work: a copy of the queue lock taken
  by the gate command / suite while it runs. So the lock must exist, with
  the run's own record, **before** the first gate command or suite starts,
  and must still exist (unchanged) while it runs.

**Not constrained - the implementer's choice.** How the waiter sleeps
(plain `sleep` or a reaped background `sleep`); the temporary record's exact
name (only that none is left in the directory afterwards, and none exists
after a TERM); whether the heartbeat count is >1; the order of the reclaim
and `starting` lines after a wait (both must appear once); how
`run_lock_full` splits words; whether `run_queue_span` prints a trailing
newline.

**Passed on arrival in RED (122), and what earns them.**

- **AC-10's "starts at once" block (green on arrival by design, C-8).** For
  each of `gates.sh --fast`, `--gate unit`, `--skip lint`, `--required`,
  `selftest.sh work`: started at once, A alive, exit 0, no `run-queue:` line,
  queue dir byte-identical (25); the second part's "B wrote nothing in the
  queue dir", "A starts at once beside B", "both exit 0", "dir empty" (4 of
  6). **Earned by DV-3 at GATES** - predicted count below.
- **AC-7's queue-off control** (`HARNESS_RUN_QUEUE=off` beside a held queue:
  started at once, alive, exit 0, no line, dir unchanged, and B's work saw
  A's in progress). This is the negative control for AC-1's arrangement and
  it CAN be observed in RED: measured `overlap-start = A` (table below).
- **AC-10 same-tree refusal** (exit 2 and the run-lock refusal line): a
  regression guard for HARNESS-034, green on arrival; `run-lock.test.sh`
  pins the same behaviour and its own DV earned it. Not re-earned here.
- **Silence and cleanliness on uncontended runs** (AC-4: no `run-queue:`
  line, stderr byte-identical with the queue off, same exit status, dir
  empty - 4 per script; AC-9's "runs its work with its own exit status"
  x4 and the missing-file tree's empty dir; AC-1/AC-2/AC-8's "exits 0",
  "within the bound", "dir empty"): these pass in RED because nothing queues
  and nothing is written. They are not earned by a mutation in this story's
  budget (rules.md, "Mutation work per story"); they become meaningful in
  GREEN in the same runs whose lock assertions turn green, which is the only
  evidence offered. Listed so nobody mistakes them for observed reds.

**Negative controls - expected values.** Every number in the "measured"
column was observed in the RED run above unless it says otherwise; the
rest are claims until GREEN measures them against the shipped
`run-queue.sh`.

| Control | Asserts | Expected in GREEN | Measured in RED |
|---|---|---|---|
| AC-7 queue-off beside a held queue (control for AC-1's arrangement) | B's `overlap-start` | `A` | `A` (green, as designed: two runs CAN be seen side by side) |
| AC-1 x3, the arrangement without a queue | B's `started` 2+ polls after queuing; `done-before`; `overlap-start` | `absent`; `A`; `""` | `present`; `""`; `A` (the RED failure is the control) |
| AC-2 | the six overlap records | all `""` | B start `A`, B end `A C`, C start `A B`, C end `A B`; A's two `""` |
| AC-5 live pid never reclaimed | lock bytes before/after; B started | identical; `absent` | not observed (nothing queues in RED); B `present` |
| AC-6 bypass, wrong pid / wrong path | queued line count; B started; lock bytes | `1`; `absent`; identical | `0`; `present`; identical (trivially: nothing touched it) |
| AC-8 waiter TERM | status | `143` | gates.sh `143` (TERM landed while gates.sh was still running after its work - accidental green), selftest.sh `0` |
| AC-7 values (unset, `OFF`, `no`, `CI=true`) | queued line count | `1` each | `0` each |

**DV-1, restated against C-4 (unchanged - C-4 pins the line it targets):**

    bash scripts/mutate.sh scripts/run-queue.sh 's|^run_queue_alive() { kill -0 "\$1" 2>/dev/null; }$|run_queue_alive() { false; }|' -- bash scripts/selftest.sh run-queue

Predicted (reasoned against the Contract, not run - RED cannot run it):
`mutate.sh` reports 1 line changed; the suite reports **52 failed** (173
passed), +-1 on AC-8's gates.sh waiter status (see below). By case:

| Case | Red under DV-1 | Why |
|---|---|---|
| AC-1 x3 | 3 each = 9: not started; `done-before = A`; `overlap-start = ""` | B reclaims A's live lock and runs beside it |
| AC-3 | 9: every line except "none on stdout" | B never queues; it prints a stale-reclaim line instead |
| AC-2 | 4: B and C start and end beside A | as AC-1 |
| AC-5 live | 5: not started; queued line 2; no reclaim line; lock unchanged; one starting line | the live sleep reads gone; stale line once and exit 0 stay green |
| AC-6 nested | 2: no inner `run-queue:` line; queue lock after the inner B run records the outer pid | the pass-through's liveness test fails, so inner B reclaims the outer lock, then releases it |
| AC-6 bypass x2 | 3 each = 6: queues; not started; lock unchanged | |
| AC-7 values x4 | 2 each = 8 | |
| AC-8 waiters | gates.sh 3 (queued, ran nothing, dir unchanged) and selftest.sh 4 (the same and status 143) = 7 | the 143 for gates.sh is timing: it was green in RED |
| AC-8 holder | 1: B began only after A ended | |
| C-4 pin | 1: the `run_queue_alive` one-liner no longer matches | the mutation itself |
| everything else | 0 | AC-4, AC-5's dead/unreadable reclaims, AC-9, AC-10, the tables do not reach `run_queue_alive` with a live pid |

If AC-1's "has not started its work while A holds the queue" stays green
under it, the suite is not observing concurrency and AC-1 is unmet.

**DV-3, the expression against `run_lock_full` as C-5 (amended) pins it:**

    bash scripts/mutate.sh scripts/run-lock.sh 's/^run_lock_full() {$/run_lock_full() { return 0/' -- bash scripts/selftest.sh run-queue

It turns the opening line into `run_lock_full() { return 0`, so the body
below it never runs and every command is full. `mutate.sh` reports 1 line
changed. Predicted (reasoned, not run): **35 failed** (190 passed):

| Case | Red under DV-3 |
|---|---|
| AC-10 table | 16: every "not full" row |
| C-5 pin | 1: `run_lock_full() {` no longer matches |
| AC-10 beside a held queue, `--fast`, `--gate unit`, `--skip lint`, `--required`, `selftest.sh work` | 3 each = 15: starts at once (it queues); exits 0 (TERM: 143); no `run-queue:` line (it printed the queued lines). "A alive" and "dir unchanged" stay green |
| AC-10 non-full in progress | 3: B's `--gate unit` wrote nothing in the queue dir (it took it); A starts at once beside B (A queued behind B); A's work saw its own lock (it had not run yet) |
| everything else | 0: the off control, AC-1..AC-9 are full runs already, and the same-tree refusal is the run lock's |

**Contract amendments made in RED** (in place, each with its reason in the
block): C-5 table wording - every `gates.sh` mode that runs a gate writes
`last-gate-run`, and a full run is the one whose stamp says `FULL=yes`
(classification unchanged); C-5 word list - `--list` and `--audit` added so
`run_lock_full` answers as the table says (AC-10 requires it); C-5 - the
opening line `run_lock_full() {` pinned for DV-3; C-3 - `<dir>` and `<lock>`
defined (verbatim from C-1, not canonicalised). No criterion was touched.

**Changed signatures: none.** `run_lock_acquire <root> <command>` and
`run_lock_release` keep their names, arguments and return values (C-12), so
no caller list applies. `run_lock_full` and `run_queue_*` are new.

**Deferred verifications - declined in RED, in those words.** DV-1, DV-2
and DV-3 each need `scripts/run-queue.sh` or `run_lock_full`, which do not
exist until GREEN; RED cannot run them. They are GATES'. The predictions
above are what GATES compares against.

**Discovered, for GREEN.**

- The suite's waiter is started as `( cd tree; export ...; exec bash
  scripts/<s> ) &` - `exec` keeps the pid on MSYS as on Linux (measured:
  lock pid = `$!`), so the queue record's pid and the TERM target are the
  script's own `$$`.
- AC-8's holder case sends TERM while A is inside its gate command; `gates.sh`
  waits for the gate command before running its trap (HARNESS-034), so the
  suite releases A's work right after the TERM. The queue must therefore be
  released by `run_lock_release` from the EXIT trap, after that.
- Every `still queued` and `starting` line is matched by fixed prefix plus a
  span pattern; any change of wording around the span is a red.
- Runtime: the suite is integration-heavy (about 50 fixture runs of the real
  scripts). Measured locally on this Windows host, **beside another
  session's `selftest.sh --changed` that was running `boundaries`** (the
  very condition this story fixes, so the number is inflated): 4m36s and
  4m48s in RED (sys 2m46s of it is process creation). GREEN adds roughly 25 s
  of deliberate waits (3.5 s x 3 pairs, 2-2.5 s in eight more cases, and the
  1 s polls). No CI measurement exists yet; Linux process creation is an
  order of magnitude cheaper, so expect well under the 3-4 minute CI
  self-test, but GATES should read the CI log for the real figure.

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

- **2026-11-13, PLANNED (lead-po).** Planned from the user's request of the
  same day, relayed with ten decision points by the orchestrating session.
  Departures from its recommendations, each with its reason in the Contract:
  the suites get `HARNESS_RUN_QUEUE=off` from `_lib.sh` and not a per-test
  temp directory (C-7); `.github/workflows/` is not changed and `CI=true`
  does not disable the queue (C-7); the queue is joined inside
  `run-lock.sh`, so `gates.sh` and `selftest.sh` are not edited (C-4).
- **2026-11-13, the user's answer on scope: "Only full runs".** Asked whether
  `--fast` and named-suite runs should queue, the user chose the narrow
  reading. The criteria and C-5 were rewritten before the story left PLANNED,
  so no `## Amendments` entry is owed: only a full run queues (C-5), a
  non-full run keeps today's behaviour exactly (AC-10), and
  `selftest.sh --changed` never queues, which is a known gap (Out of scope).
- **Two questions for the user, neither of which blocks RED as planned.**
  (1) A second run in the *same* tree is still refused with exit 2 and does
  not wait (Out of scope); "started anywhere on the machine waits" could be
  read to include it.
  (2) A queued run started in the foreground by an agent will be killed by
  that agent's own command timeout; nothing here changes how agents start
  long runs.
- **Bookkeeping conflict with HARNESS-107.** Both stories write
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` and
  `.claude/harness/VERSION`: a new suite needs a floor and a harness change
  needs a release number. `plan.sh conflicts` will call the pair a CONFLICT
  and it is one. The two are already in separate worktrees; the second to
  reach REVIEW merges `main` first and takes the next release number (C-10).
  The story keeps clear of `scripts/selftest-needed.sh`.
- **The id.** HARNESS-108 was free on 2026-11-13: no branch, local or
  remote, and no story file carried it.

