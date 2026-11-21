---
id: HARNESS-120
title: A queued run answers when asked, and the briefs say to ask
slug: a-queued-run-answers-when-asked-and-the
epic: 
type: fix
status: in-progress
phase: GATES
branch: story/HARNESS-120-a-queued-run-answers-when-asked-and-the
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/run-status.sh, scripts/run-queue.sh, scripts/gates.sh, scripts/selftest.sh, CLAUDE.md, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/feature-developer.md, .claude/state/README.md, .claude/tests/run-queue.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the run-queue suite under its selftest floor, which CI runs in full on the PR
---

## Context

Reported by the user on 2026-11-21: "I still have to manually do it or stop
runs and tell them to queue up". The machine-wide run queue (HARNESS-108,
release 127; HARNESS-111, release 129; `scripts/run-queue.sh`, joined inside
`scripts/run-lock.sh`) works. What fails is everything around it: a queued
run is invisible to the session that dispatched it and to the user, and an
agent asked about it concludes there is no queue. Two cases, both measured
that day, both in trees new enough to queue:

1. **clean_calendar (release 130), CAL-080.** A feature-developer ran
   `bash scripts/attest.sh -- bash scripts/gates.sh` detached. Its attest log
   began with the three `run-queue: queued:` lines, behind pid 2720221 in
   `/d/manga-translator`. The user asked whether two full gate runs were going
   at once. The orchestrator answered that they were and that "the harness
   doesn't queue them. I searched `gates.sh` and found no lock or wait of any
   kind." `grep -i queue scripts/gates.sh` prints nothing: the queue is reached
   through `run-lock.sh`, and the comment at the lock site in `gates.sh` says
   "it never waits". The user said "Stop and requeue"; the session killed the
   queued run and went back to watching processes by hand.
2. **fantasy-world-builder (release 137), WORLD-172.** Same dispatch, queued
   behind manga-translator, its `gates.sh` in the queue's `sleep 5` loop. The
   orchestrator reported the run "still in progress". The user said to stop it
   and queue it; only then did the session find it was already queued.

**Two gaps, one story.**

- **Nothing can be asked.** The `run-queue:` lines go to the run's own
  stderr, which under `attest.sh` is a log file. Whether a tree's run is
  queued or running can be worked out today only by reading that log, or by
  comparing two lock files and guessing. This story adds one read-only
  command, `bash scripts/run-status.sh`, that answers for the tree it is run
  in: idle, running, or queued, behind what, since when; and what holds the
  machine's queue.
- **Nothing an agent reads first says the queue exists.** `CLAUDE.md`'s
  "Running things", the lock comments in `gates.sh` and `selftest.sh`, the
  GATES-row brief in `/advance-story` and the feature-developer's
  `## Run and report` never mention it. This story puts it in each, with the
  command to ask and one instruction: a queued run is never stopped to be
  "requeued".

**Why it is not split.** The prose names the command, so it cannot land
first; the command without the prose leaves both observed failures exactly
as they are, because neither session knew there was anything to ask. The
code is small (one new script, a marker written at one place in
`run-queue.sh` and removed at two) and the prose is five sites pinned by
fixed strings in the suite that already owns the queue, as HARNESS-111 (C-6)
and HARNESS-117 (AC-5) carried their own text pins. If RED finds the text
pins need fixture files of their own to fail for the right reason, that is
still one suite and one cycle.

**What judges it.** Every gate in this repository is unconfigured, so no
gate fails if this breaks. The judge is the `run-queue` self-test suite
(`bash .claude/tests/run-queue.test.sh`) under its floor in
`.claude/tests/floors.conf`, which CI runs with every other suite on the PR.
`dispatch`, `procedure`, `reporting`, `settings` and `sigpipe` read files
this story edits and must stay green unchanged.

**Known, and not this story's to fix.** A tree on a release older than 127
neither queues nor holds the queue (first-roblox 30, `D:/mt-MT-157` 118,
`D:/adh-TCF-043` 109 on 2026-11-21): its runs go beside everything, and the
remedy is a refresh. A run that does not queue by design - `gates.sh --fast`,
`--gate`, `--skip`, `--required`, a named-suite `selftest.sh`, any test
command (HARNESS-108 AC-10) - still does not. And nothing here makes an
agent follow the prose: the suite pins that the instruction is where it will
be read, as `dispatch` and `procedure` do for theirs.

## Acceptance criteria

"The queue" is HARNESS-108's lock file, and every case gives it a directory
of its own through `HARNESS_RUN_QUEUE_DIR`. "A run that queues" is what
`run_lock_queues` says it is (HARNESS-111 C-2): a full `gates.sh` or
`selftest.sh`, or `selftest.sh --changed`. "Asked in tree T" means
`bash scripts/run-status.sh` run from T's own copy, with no argument. The
lines it prints are Contract C-2's, compared whole.

- **AC-1** — Given a run that queues in tree A that holds the queue, and a
  run that queues in tree B that has printed its `run-queue: queued:` line,
  when it is asked in tree B, then stdout is exactly C-2's `queued` line
  naming B's pid, the time B began waiting and B's command; the `behind` line
  naming A's pid, start time, root and command as the queue lock records
  them; the `waiting, not hanging` line; and the `machine queue: held` line
  for A - with exit 0 and nothing on stderr. Asked in tree A at the same
  moment, it prints the `running` line for A and the same `machine queue:
  held` line. B's work has still not started after both answers.
- **AC-2** — Given AC-1's two runs, when A finishes and B has started its
  work, then asked in B it prints the `running` line for B and `machine
  queue: held` naming B, and `.claude/state/run.queued` is absent from B.
  When B has finished, asked in either tree it prints the `idle` line and
  `machine queue: free`, and neither tree holds a `run.queued`.
- **AC-3** — *The control: "queued" means a live waiter, not a file.* (a)
  Given B waiting as in AC-1, when B is sent `TERM`, then it exits 143 and
  `run.queued` is absent from B. (b) Given a `run.queued` in a tree whose
  recorded pid is not running, or is running but is not the pid the tree's
  `run.lock` records, or a tree with a `run.queued` and no `run.lock`, when
  asked there, then the first line is never the `queued` line: it is the
  `idle`, `left over` or `running` line, as the `run.lock` alone decides. (c)
  Given a `run.lock` whose pid is not running, the first line is C-2's
  `left over` line naming that pid.
- **AC-4** — *The control: a run beside the holder is not called queued.*
  Given a run that queues in tree A that holds the queue, when (a) a
  `gates.sh --fast` run, or (b) a full `gates.sh` run with
  `HARNESS_RUN_QUEUE=off`, is in progress in tree B, then asked in B the
  first line is the `running` line for B's pid and command, the last line is
  `machine queue: held` naming A, and B holds no `run.queued`.
- **AC-5** — Asking changes nothing and never waits. Given a held queue and
  a held `run.lock`, when it is asked, then it returns within the suite's
  bound with exit 0, and the queue directory and the tree's `.claude/state`
  hold exactly the files, byte for byte, that they held before. Given an
  absent queue directory, it prints `machine queue: free` and does not
  create the directory. Given neither `HARNESS_RUN_QUEUE_DIR` nor `HOME`,
  the last line is C-2's `cannot be located` line and the exit is still 0.
  Given any argument, it prints a usage line on stderr and exits 2.
- **AC-6** — The queue is named where an agent reads first, each needle a
  fixed string found inside the region C-5 names and not merely somewhere in
  the file: (a) `CLAUDE.md`'s "Running things" command block has a line
  beginning `bash scripts/run-status.sh`, and that section names
  `run-queue.lock` and carries C-5's `Never stop a queued run` sentence; (b)
  `/advance-story`'s GREEN → GATES brief names `bash scripts/run-status.sh`
  and carries that sentence; (c) `feature-developer.md`'s `## Run and report`
  names the command and carries that sentence; (d) the `allowed-tools` line
  of `/advance-story` and of `/complete-story` each carry
  `Bash(bash scripts/run-status.sh:*)`; (e) the run-lock comment in
  `scripts/gates.sh` and the one in `scripts/selftest.sh` each name
  `scripts/run-queue.sh`, and neither says `it never waits` of the take as a
  whole.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/run-status.sh`, `scripts/run-queue.sh`, `scripts/gates.sh`, `scripts/selftest.sh`, `CLAUDE.md`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/agents/feature-developer.md`, `.claude/state/README.md`, `.claude/tests/run-queue.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/run-queue.test.sh`, the suite's new floor in `floors.conf` and
its hand-copied line in `selftest.test.sh` (C-7). GREEN (feature-developer)
writes everything else and touches no suite.

**Not written: `scripts/run-lock.sh`, `scripts/attest.sh`, `scripts/phase.sh`,
`.claude/tests/_lib.sh`, `.claude/settings.json`, `.claude/agents/lead-po.md`,
`.claude/harness/rules.md`, `.github/workflows/*`.** `_lib.sh` in particular:
a change to it makes this story's own pre-REVIEW `--changed` run resolve to
every suite.

**C-1. The marker: `<root>/.claude/state/run.queued`.** `<root>` is the tree
root `run_queue_acquire` is given, the one whose `run.lock` the waiter already
holds. Three TAB-separated lines, the run lock's convention:

    pid<TAB><the waiting script's $$>
    since<TAB><UTC, to the second>
    command<TAB>scripts/gates.sh

- **Written once per wait**, at the point `run_queue_acquire` prints its
  `run-queue: queued:` line and nowhere else. `since` is the time of that
  line, so it is when the run began waiting, not when it was started.
  `command` is the `<command>` argument, the string the queue lock would
  record.
- **Removed** when the run takes the queue, before the `run-queue: starting`
  line is printed, and in `run_queue_release`, which the callers' EXIT trap
  reaches through `run_lock_release`: that is what removes it when a waiter
  is sent `TERM` or `INT` (AC-3 a). Only the process that wrote it removes it.
- **Never written** by a run that does not wait: an uncontended take, a
  nested pass-through, a run that does not queue, `HARNESS_RUN_QUEUE=off`,
  a run that proceeds "without the machine-wide queue".
- **Silent.** Writing and removing it print nothing; no existing
  `run-queue:` line changes by a byte, and all 361 existing assertions of the
  suite keep their expected values. A marker that cannot be written is not an
  error and is not reported: the run waits exactly as it does today, and
  `run-status.sh` will call it `running`. That limit goes in the script's
  header.
- **A marker left by `SIGKILL`** is not cleaned up by anything and does not
  need to be: C-2 believes a marker only when its pid is the live pid the
  tree's `run.lock` records. It is exhaust, `yes` in the state table (C-6).

Why a marker and not inference from the two locks: "this tree's `run.lock`
is held, and the queue is held by someone else" is also true of a `--fast`
run, of a run started with the queue off and of a run that could not use the
queue directory, all of which are running beside the holder. Case 1 in
Context was exactly the question "are two runs going at once?", and an
inferred `queued` would answer it wrongly in the cases where the answer is
yes. AC-4 is the control for that.

**C-2. `scripts/run-status.sh`.** Executed, never sourced. No arguments: any
argument prints `usage: bash scripts/run-status.sh` on stderr and exits 2.
Its root is its own (`$(dirname "${BASH_SOURCE[0]}")/..`), never `$PWD` and
never `CLAUDE_PROJECT_DIR`, as `gates.sh` does it; to ask about another
worktree, run that worktree's copy. It reads `<root>/.claude/state/run.lock`,
`<root>/.claude/state/run.queued` and the queue lock, and writes nothing,
creates nothing (not the queue directory), takes no lock and never sleeps.
Everything it prints goes to stdout; exit 0 on every answer. Bash 3.2, awk
and coreutils only.

The queue lock's path is HARNESS-108's rule, unchanged:
`$HARNESS_RUN_QUEUE_DIR/run-queue.lock` when that variable is non-empty, else
`$HOME/.cache/agentic-harness/run-queue.lock`. It is read whatever
`HARNESS_RUN_QUEUE` is set to in the asker's shell: `off` is about joining,
and this joins nothing. **The rule must exist once.** GREEN moves it into a
function in `scripts/run-queue.sh` that `run_queue_acquire` and
`run-status.sh` both call (`run-status.sh` sources `run-queue.sh` for it and
for `run_queue_field`, `run_queue_pid`, `run_queue_alive`), without changing
anything `run_queue_acquire` prints or returns. RED does not pin the
function's name.

"Alive" is `kill -0`, with HARNESS-108's limits (a recycled pid reads alive;
a holder in another pid namespace reads gone).

It prints the **state lines**, then exactly one **queue line**. With `P`,
`T`, `C` the tree's `run.lock` `pid`, `started`, `command`, and `Q`, `T2`,
`R2`, `C2` the queue lock's `pid`, `started`, `root`, `command`:

| The tree | State lines |
|---|---|
| no `run.lock` | `run-status: idle: no harness run holds <root>.` |
| `run.lock`, `P` numeric and not alive | `run-status: idle: .claude/state/run.lock is left over from pid <P>, which is no longer running; the next run reclaims it.` |
| `run.lock`, no numeric pid | `run-status: idle: .claude/state/run.lock records no pid; the next run reclaims it.` |
| `P` alive, and no `run.queued` whose `pid` equals `P` | `run-status: running: pid <P>, started <T>: <C>` |
| `P` alive, and `run.queued` whose `pid` equals `P` | the three `queued` lines below |

    run-status: queued: pid <P>, waiting since <since>: <C>
    run-status:   behind pid <Q>, started <T2>, in <R2>: <C2>
    run-status: this is waiting, not hanging: it starts by itself when that run ends. Never stop a queued run to requeue it.

`<since>` is the marker's. The second line is as shown when the queue lock
records a numeric, alive `Q` other than `P`; otherwise - the holder ended in
the instant between the waiter's polls - it is
`run-status:   behind nothing at this instant: it takes the queue at its next poll.`
RED need not construct that instant through real runs; a planted marker and
`run.lock` naming one live pid, with no queue lock, is that state.

| The queue lock | Queue line (always last) |
|---|---|
| neither variable set | `run-status: machine queue: cannot be located: neither HARNESS_RUN_QUEUE_DIR nor HOME is set.` |
| absent (or its directory is) | `run-status: machine queue: free (<lock path>)` |
| numeric `Q`, alive | `run-status: machine queue: held by pid <Q>, started <T2>, in <R2>: <C2>` |
| numeric `Q`, not alive | `run-status: machine queue: stale lock from pid <Q>, which is no longer running; the next run that queues reclaims it (<lock path>)` |
| no numeric pid | `run-status: machine queue: unreadable lock, no pid recorded; the next run that queues reclaims it (<lock path>)` |

`<root>` and `<lock path>` are printed as the script resolved them. A queue
line that says `held` by the pid the state line calls `running` is the
ordinary case of a full run in progress in this tree (AC-1, tree A); a
`running` state with the queue held by another pid is AC-4.

Suites run with `HARNESS_RUN_QUEUE=off` and may inherit the host's `HOME`.
Every call the suite makes sets `HARNESS_RUN_QUEUE_DIR` to its own temp
directory, except AC-5's "neither" case, which unsets `HOME` with it, as the
existing AC-9 does. No case may read `$HOME/.cache`.

**C-3. What `run-queue.sh` does not change.** The three `queued` lines, the
`still queued` heartbeat, the `starting` line, the reclaim lines and the
"without the machine-wide queue" lines stay byte for byte (HARNESS-108 C-3;
the suite compares them whole). The lock record stays four lines. Lock order
stays run lock, then queue. The file's header gains the marker under a
heading of its own, and its `WAIT, NEVER REFUSE` paragraph gains one
sentence naming `bash scripts/run-status.sh` as the way to ask.

**C-4. `gates.sh` and `selftest.sh`: comments only, and no line added or
removed.** `scripts/gates.sh` is 1315 lines and `scripts/selftest.sh` 728 on
`main` at `fcf3835`, and both stay that. `sigpipe.test.sh` pins `gates.sh`
lines 93, 428, 432 and 801 by number, and the lock comment is at 276-284,
above three of them. So the two comment blocks are **reworded in place**:
`gates.sh` 276-284 ("THE RUN LOCK (HARNESS-034) ...") and `selftest.sh`
424-433 ("the run lock (HARNESS-034) ..."). Each must come to say, in the
same number of lines: the run lock refuses and is never waited on; a run
that queues then waits in the machine-wide queue, `scripts/run-queue.sh`,
for any other such run on the machine; `bash scripts/run-status.sh` says
which. The words `it never waits` go, because of the take as a whole they
are now false, and they are what the orchestrator in case 1 read. No code
line of either file changes. GREEN confirms both counts with `wc -l` and
runs `bash .claude/tests/sigpipe.test.sh` before handing back.

**C-5. The prose, its regions and its needles.** One sentence is shared by
three sites, exactly:

    Never stop a queued run to requeue it

(the status script prints the same words, C-2). Each site below is a
**region**, extracted by the suite, and a needle counts only inside it.

| Site | Region | Must contain |
|---|---|---|
| `CLAUDE.md` | the fenced block under `## Running things` | a line beginning `bash scripts/run-status.sh` followed by a `#` comment |
| `CLAUDE.md` | from `## Running things` to the next `## ` heading | `run-queue.lock`; `Never stop a queued run to requeue it` |
| `.claude/commands/advance-story.md` | from the line beginning `**GREEN → GATES.**` to the line beginning `**GATES → REVIEW.**` | `bash scripts/run-status.sh`; `Never stop a queued run to requeue it`; `queued behind` |
| `.claude/agents/feature-developer.md` | `## Run and report`, to the next `## ` heading | `bash scripts/run-status.sh`; `Never stop a queued run to requeue it` |
| `advance-story.md`, `complete-story.md` | the frontmatter `allowed-tools:` line | `Bash(bash scripts/run-status.sh:*)` |
| `scripts/gates.sh`, `scripts/selftest.sh` | the comment block that holds the `HARNESS-034` run-lock heading, to the first non-comment line | `scripts/run-queue.sh`; and not `it never waits` |

What the prose must say, in GREEN's words around those needles:

- **`CLAUDE.md`, "Running things".** One line in the command block, next to
  `attest.sh`: `bash scripts/run-status.sh` with a comment saying it answers
  whether this tree's run is running or queued, and behind what. And one
  paragraph of **at most six lines** after the block's existing paragraphs:
  a full `gates.sh` or `selftest.sh` and every `selftest.sh --changed` waits
  in a machine-wide queue for any other such run, in any tree, on this
  machine; the lock is
  `${HARNESS_RUN_QUEUE_DIR:-$HOME/.cache/agentic-harness}/run-queue.lock`; it
  is reached through `scripts/run-lock.sh`, so it is not in `gates.sh`;
  `--fast`, `--gate` and a single suite do not queue; a queued run starts by
  itself; never stop a queued run to requeue it. This file is in context on
  every turn: six lines is the budget, and the detail stays in
  `scripts/run-queue.sh`'s header.
- **`/advance-story`, GREEN → GATES.** A new paragraph directly after the one
  beginning `The brief, here and for the self-test`, which is itself not
  reflowed (`dispatch.test.sh` reads it). It tells the orchestrator: the run
  it dispatched may be waiting in the machine-wide queue; before telling the
  user a long run is "running" or "still in progress", run
  `bash scripts/run-status.sh` in that worktree and say what it says -
  `queued behind <tree> since <time>` when it is queued; never stop a queued
  run to requeue it, and never start a second one beside it; a wait in the
  queue is not the stall the orphan advice at GATES → REVIEW is about. The
  brief it hands the feature-developer gains the same instruction in one
  clause.
- **`feature-developer.md`, `## Run and report`.** Added sentences, existing
  ones left as they are (`dispatch.test.sh` pins needles in this section): a
  full run may print `run-queue: queued:` and wait behind another tree's run;
  that is waiting, `bash scripts/run-status.sh` says behind what, and you
  wait for it as for any long run; never stop a queued run to requeue it;
  the report adds how long the run was queued when it was (the
  `run-queue: starting ... after waiting` line of the log).
- **`allowed-tools`.** `Bash(bash scripts/run-status.sh:*)` appended to both
  lines, so the orchestrator can ask without a permission prompt.
  `procedure.test.sh` reads these lines for other entries and is not changed.

`.claude/agents/lead-po.md` and `rules.md` are left alone: the orchestrator
reads `/advance-story` at every phase, and `rules.md` is paid for on every
turn.

**C-6. `.claude/state/README.md`.** One row in the table, after
`run.lock.<pid>`:

    | `run.queued` | `scripts/run-queue.sh`, while a run waits in the machine-wide queue | `scripts/run-status.sh` | yes |

and a short paragraph after the `run.lock` one: what it holds, that it is
removed when the run starts or is stopped, that one left behind means a
waiter was killed outright and is safe to delete, and that `run-status.sh`
believes it only for the live pid `run.lock` records. `yes` needs no
`settings.json` rule, so `settings.test.sh` passes unchanged and
`.claude/settings.json` is not written; GREEN runs
`bash .claude/tests/settings.test.sh` to confirm.

**C-7. The floor and the release.** `run-queue` is floored at 361
(`floors.conf` line 63, copied by hand at `selftest.test.sh` line 554). RED
raises both to the executed count it measures, with a dated comment in
`floors.conf` in the form the HARNESS-111 and HARNESS-117 entries use. In RED
`scripts/run-status.sh` does not exist: every case that asks tests for the
file first and fails **one** assertion per expected line in the if and the
else alike, so the executed count is the same in RED and GREEN. GREEN
re-measures; if it differs, the handoff was wrong and GREEN reports it
instead of moving the number. No other floor moves.
`.claude/harness/VERSION` is `138 (2026-11-20)` on `main`; this story makes
it `139 (<the real date of the GATES commit>)`. If another story takes 139
first, this one takes the next free number when it merges `main`.

**C-8. Oracle partition.** All six criteria are **mechanical**: pin them
exactly, leave nothing open-ended. There is no statistic and no threshold;
the only numbers are exit statuses (0, 2, 143) and the suite's existing
bounds. C-2's lines and C-5's needles are **settled**: read them out, do not
reword them in the test. The two controls are AC-3 (b) and AC-4, and each
must be able to fail: AC-3 (b) fails if "queued" is decided by the marker
file existing, AC-4 if it is inferred from the two locks.

**C-9. Changed signatures: none.** `run_queue_acquire <root> <command>` and
`run_queue_release` keep their arguments, return values and output;
`run_lock_acquire`, `run_lock_release`, `run_lock_join`, `run_lock_queues`
and `run_lock_full` are not touched. Callers checked on `fcf3835`:
`run_queue_acquire` is called only from `run_lock_join`
(`scripts/run-lock.sh`), `run_queue_release` only from `run_lock_release`;
no suite calls either directly. `scripts/run-status.sh` is
new and has no caller.

**C-10. Commands.**

    bash .claude/tests/run-queue.test.sh                       # the suite that judges this story
    bash scripts/attest.sh -- bash .claude/tests/run-queue.test.sh
    bash .claude/tests/sigpipe.test.sh                         # C-4: gates.sh line numbers
    bash .claude/tests/dispatch.test.sh                        # C-5: the brief and Run and report
    bash .claude/tests/procedure.test.sh                       # C-5: allowed-tools
    bash .claude/tests/settings.test.sh                        # C-6: the state table
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
    SELFTEST_JOBS=4 bash scripts/selftest.sh --changed         # before REVIEW, by dispatch

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one "defect put back"
mutation for the central claim (DV-1), and one probe against a real line of
the tree for the rule the story adds over it, the text pins of AC-6 (DV-2).
DV-3 is not a mutation: it is the story's claim checked once outside the
fixtures, on this tree's real `gates.sh`. No test here is written against
code that already exists - `scripts/run-status.sh` and the marker are new,
and every needle of AC-6 is absent from the tree today - so no
passes-on-arrival mutation is owed; if RED finds an assertion that passes on
arrival, it adds the entry. Each mutation runs against the one suite that
holds its assertion, `bash .claude/tests/run-queue.test.sh`, through
`scripts/mutate.sh`. None can run before GREEN: there is no marker write to
remove, no pinned line to break and no status script to ask.

- **DV-1, the defect put back (AC-1).** With the marker never written - the
  one write in `run_queue_acquire` removed or made a no-op - a queued run is
  again indistinguishable from a running one, which is the tree as it is
  today. `mutate.sh` must report 1 line changed, and the suite must go red on
  AC-1's `queued`, `behind` and `waiting, not hanging` lines for tree B (the
  status then prints `running`), while AC-4's `running` assertions and every
  HARNESS-108 and HARNESS-111 assertion stay green. RED's handoff predicts
  the count. **Owner: GATES.**

  **Result (GATES, 2026-11-21): passed, as predicted (17).** Run by the
  orchestrator:

```
=== mutate: scripts/run-queue.sh (1 line(s) changed by s/^        run_queue_mark "\$root" "\$self"$/        :/) ===
    FAIL HARNESS-120 C-1: while B waits, B's tree holds .claude/state/run.queued
    FAIL HARNESS-120 C-1: the marker is three TAB-separated lines: pid, since, command
    FAIL HARNESS-120 C-1: the marker records the waiting script's pid
    FAIL HARNESS-120 C-1: the marker records when it began waiting, UTC to the second
    FAIL HARNESS-120 C-1: the marker records the command the queue lock would record
    FAIL HARNESS-120 C-1: the holder, which never waited, writes no marker in A
    FAIL HARNESS-120 AC-1 asked in B (queued): prints exactly 4 line(s) on stdout
    FAIL HARNESS-120 AC-1 asked in B (queued): stdout line 1
    FAIL HARNESS-120 AC-1 asked in B (queued): stdout line 2
    FAIL HARNESS-120 AC-1 asked in B (queued): stdout line 3
    FAIL HARNESS-120 AC-1 asked in B (queued): stdout line 4
    FAIL HARNESS-120 AC-2: once B has started its work, its run.queued is gone
    FAIL HARNESS-120 AC-2: neither tree holds a run.queued afterwards
    FAIL HARNESS-120 AC-3 (a) gates.sh waiter: it wrote a marker while queued, exits 143 on TERM, and the marker is gone
    FAIL HARNESS-120 AC-3 (a) selftest.sh waiter: it wrote a marker while queued, exits 143 on TERM, and the marker is gone
    FAIL HARNESS-120 AC-4 (a) gates.sh --fast beside the holder: B holds no run.queued
    FAIL HARNESS-120 AC-4 (b) full gates.sh, HARNESS_RUN_QUEUE=off, beside the holder: B holds no run.queued
run-queue: 562 passed, 17 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-120/.claude/state/mutations/scripts_run-queue.sh.20261121T212325Z.2940687.bak) ===
dv1 rc=1
```

- **DV-2, a real line of the tree (AC-6).** The text pins read the real
  `CLAUDE.md`, command and agent files. With the `bash scripts/run-status.sh`
  line of `CLAUDE.md`'s "Running things" block mutated through `mutate.sh`
  (the script name respelled), AC-6 (a)'s assertion for that line must go
  red and no other AC-6 assertion may: the sentence and the lock path in the
  same section are separate needles. A pin that stays green here was
  satisfied by some other line of the file. **Owner: GATES.**

  **Result (GATES, 2026-11-21): passed, as predicted (1).** Only AC-6 (a)
  went red; every other AC-6 pin stayed green.

```
=== mutate: CLAUDE.md (1 line(s) changed by s/^bash scripts\/run-status\.sh /bash scripts\/run-statuz.sh /) ===
    FAIL HARNESS-120 AC-6 (a): CLAUDE.md's Running things command block has one line beginning bash scripts/run-status.sh, then a # comment
run-queue: 578 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-120/.claude/state/mutations/CLAUDE.md.20261121T212946Z.2957657.bak) ===
dv2 rc=1
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

- **DV-3, the real tree, asked while queued (AC-1).** Not a fixture: in this
  repository, with `HARNESS_RUN_QUEUE_DIR` pointing at a scratch directory
  whose `run-queue.lock` names a live pid of the prober's own (a `sleep`),
  start `bash scripts/gates.sh` detached with the queue on, wait - bounded,
  for the `run-queue: queued:` line in its output, not for a fixed time
  (HARNESS-111's DV-2 lost its first attempt to a fixed sleep) - and run
  `bash scripts/run-status.sh` with the same variable. It must print the
  three `queued` lines naming the `gates.sh` pid and the planted holder, and
  `machine queue: held`. Then remove the planted lock: the run must start by
  itself, `run-status.sh` must say `running`, and after it exits, `idle` and
  `machine queue: free`, with no `.claude/state/run.queued` left. Paste the
  three answers. This is the check case 1 and case 2 in Context would have
  needed, made on a real run. The host's own queue under `$HOME/.cache` is
  never touched. **Owner: GATES.**

  **Result (GATES, 2026-11-21): passed.** Real `bash scripts/gates.sh` in
  D:\adh-HARNESS-120, `HARNESS_RUN_QUEUE_DIR` a scratch directory whose lock
  named a live `sleep` (pid 2977069); waited for the `queued:` line (bounded
  poll, no fixed sleep), asked, removed the lock, polled until `running`,
  waited for exit, asked again. The host queue under `$HOME/.cache` was not
  touched.

```
--- gates.sh pid 2977078, planted holder pid 2977069
--- ask 1 (queued)
run-status: queued: pid 2977078, waiting since 2026-11-21T21:40:36Z: scripts/gates.sh
run-status:   behind pid 2977069, started 2026-11-21T21:40:28Z, in /dv3/planted: dv3 planted holder (sleep)
run-status: this is waiting, not hanging: it starts by itself when that run ends. Never stop a queued run to requeue it.
run-status: machine queue: held by pid 2977069, started 2026-11-21T21:40:28Z, in /dv3/planted: dv3 planted holder (sleep)
--- ask 2 (after the planted lock was removed)
run-status: running: pid 2977078, started 2026-11-21T21:40:32Z: scripts/gates.sh
run-status: machine queue: held by pid 2977078, started 2026-11-21T21:40:41Z, in /d/adh-HARNESS-120: scripts/gates.sh
--- gates.sh exited 0
--- ask 3 (after it exited)
run-status: idle: no harness run holds /d/adh-HARNESS-120.
run-status: machine queue: free (<scratch>/dv3-queue/run-queue.lock)
ls: cannot access '.claude/state/run.queued': No such file or directory
--- queue lines from gates.sh
run-queue: queued: scripts/gates.sh waits for another harness run on this machine to finish.
run-queue: starting scripts/gates.sh after waiting 0m10s.
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

Planned by `bash scripts/plan.sh write HARNESS-120` from `.claude/harness/models.conf`.
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
- PLANNED (2026-11-21): `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override. Dispatched by `/plan-story`; wrote Context, the criteria, the Contract, the deferred verifications and Out of scope, then ran `plan.sh write`.
- RED (2026-11-21): `test-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- GREEN (2026-11-21): `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- GATES (2026-11-21): `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override. Ran `bash scripts/attest.sh -- bash scripts/gates.sh`; `attest.sh check` `fresh`, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).` (log `.claude/state/attest-logs/20261121T214154Z.2978100.log`). It did not wait: `run-status.sh` showed it holding the machine queue.
- DIFF-REVIEW round 1 (2026-11-21): `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override. Verdict: fix 1 and 2 first.
- GATES (round 1 fix 2, 2026-11-21): `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- RED (R-1, 2026-11-21): `test-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.

## Out of scope

- **Changing what the queue does.** Which runs queue, the wait, the poll and
  heartbeat, the order waiters get through in, stale-lock reclaim, nesting:
  all as HARNESS-108 and HARNESS-111 left them. No existing `run-queue:` or
  `run-lock:` line changes, and `scripts/run-lock.sh` is not edited.
- **A queue for runs that do not queue.** `gates.sh --fast`, `--gate`,
  `--skip`, `--required`, a named-suite `selftest.sh` and plain test commands
  still neither wait nor are waited for (HARNESS-108 AC-10). `run-status.sh`
  reports them as `running`, which is what they are.
- **Trees on a release older than 127**, which neither queue nor hold the
  queue, and trees older than this release, which queue but have no
  `run-status.sh` and write no marker. The remedy is a refresh. Nothing here
  detects another tree's release or warns about it.
- **A machine-wide list of waiters.** `run-status.sh` answers for the tree it
  is run in, plus the one holder of the queue. Who else is waiting, in which
  trees and in what order, is not recorded anywhere and is not added: the
  marker lives in each tree, and there is no first-come order to report.
- **Asking about another tree by path.** No `--tree` or `--root` argument;
  run that tree's own copy.
- **`attest.sh` and `phase.sh` reporting the queue.** `attest.sh check` still
  answers `none` for a run in flight, queued or not, and `phase.sh show` and
  `board` are unchanged. Their output is pinned by other suites, and the
  question has one place to be asked.
- **Stopping or reordering a queued run.** No cancel, no priority, no "jump
  the queue". The remedy the queued message already names - delete the lock
  if the pid is not that run - stays the only manual one.
- **Making an agent follow the prose.** The suite pins that the instruction
  is where the orchestrator and the feature-developer read it, as `dispatch`
  and `procedure` do. Whether a session then asks before saying "running" is
  observed in the field, not here.
- **`rules.md`, `lead-po.md`, `.claude/settings.json`, the stack profiles and
  the skills.** Not edited (C-5, C-6).
- **Rewording the three `queued` lines** to add "do not stop it". They are
  compared whole by 361 assertions and say "waiting, not hanging" already;
  the new sentence is in `run-status.sh`'s answer and the briefs.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One suite, `.claude/tests/run-queue.test.sh`, a new block headed
`HARNESS-120` at its end, before `summary`. Level: integration through the
fixture trees A and B the suite already builds (`make_project_fixture`
copies the real `scripts/`, so each fixture gets GREEN's `run-status.sh` and
`run-queue.sh`), plus text pins over the real repository files for AC-6.
218 new assertions; floor 361 -> 579 (`floors.conf` line 63 and
`selftest.test.sh` line 554, with a dated comment at the end of
`floors.conf`).

| Describe block | Assertions | AC |
|---|---|---|
| AC-1 a real queued pair: A's full `gates.sh` held, B's full `gates.sh` queued behind it | 24 | AC-1, C-1 |
| AC-2 the same pair: A released, B through and held, then B released | 23 | AC-2, C-1 |
| AC-3 (a) a queued `gates.sh` and a queued `selftest.sh`, each sent TERM | 4 | AC-3 (a) |
| AC-3 (b), (c) nine planted tree states, empty queue directory | 55 | AC-3 (b), (c), C-2 state table |
| the planted waiter that IS believed (behind a live holder; no queue lock; the queue lock naming the waiter) | 24 | C-2, the positive half of AC-3 (b)'s control |
| the queue line for each queue-lock state (live, dead, no pid, non-numeric) | 24 | C-2 queue table |
| the root is the script's own (B's copy run from A's cwd with `CLAUDE_PROJECT_DIR=A`) | 6 | C-2 |
| AC-4 `gates.sh --fast`, and full `gates.sh` with `HARNESS_RUN_QUEUE=off`, beside the holder | 18 | AC-4 |
| AC-5 nothing changes; absent queue dir; neither variable nor `HOME`; three argument cases | 26 | AC-5 |
| AC-6 text pins, each inside C-5's region | 14 | AC-6 (a)-(e) |

Every answer is compared whole by `rs_expect`: within a 20 s bound, exit 0,
stderr empty, exactly N stdout lines, then each line compared whole against
C-2's text. One helper change outside the block: `new_case` also removes
`.claude/state/run.queued` in every tree, so no marker leaks between cases.

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

Model: test-developer resolved to **Opus 5.5** (`claude-opus-5-5`), as its
definition declares; no override.

**Command.**

    bash .claude/tests/run-queue.test.sh
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue   # what RED ran

**RED runs (Windows host, local).**

    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue
      exit:     1
      last:     1 of 1 harness suite(s) FAILED.
      log:      .claude/state/attest-logs/20261121T192003Z.2849520.log
      run-queue: 374 passed, 205 failed      (579 executed; floor now 579)
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
      exit:     0
      last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
      log:      .claude/state/attest-logs/20261121T193303Z.2863362.log

`gates.sh --fast` has nothing to judge here (every gate is unconfigured,
`BOOTSTRAPPED=no`); the judge is the suite. Neighbours, single-suite, local,
unchanged: `dispatch: 205 passed, 0 failed`, `procedure: 183 passed, 0
failed`, `settings: 71 passed, 0 failed`, `sigpipe: 91 passed, 0 failed`,
`selftest: 366 passed, 0 failed` (it checks the COUNTS row against `floors.conf`). `check-sigpipe.sh` and `check-grep-count.sh`: 0
findings with the new suite in.

**Why it is the right failure.** Every one of the 361 pre-existing
assertions passes (no `FAIL` line in the log lacks `HARNESS-120`). The 205
new failures are, exactly:

- 179 answers of `run-status.sh`, each `scripts/run-status.sh does not exist
  (expected: <C-2's line>)` - the file is absent; the if/else emits one
  assertion either way (C-7).
- 5 marker fields of C-1 (present, keys, pid, since, command): failing on
  their own - nothing writes `run.queued`.
- 5 marker-absent assertions (`mk_eq`): `no run.queued was ever seen while a
  run was queued (AC-1); its absence here proves nothing`. They count only
  once AC-1 has seen a marker, so they cannot pass on a tree that writes none.
- 2 AC-3 (a): `expected: seen 143 absent / actual: never-written 143 absent` -
  the TERM exit is already right (HARNESS-108); the marker is what is missing.
- 14 AC-6 text pins, failing on their own assertion against the real files.

Excerpts, verbatim from the log:

```
    FAIL HARNESS-120 C-1: while B waits, B's tree holds .claude/state/run.queued
         expected: present
         actual:   absent
    FAIL HARNESS-120 AC-2: once B has started its work, its run.queued is gone
         no run.queued was ever seen while a run was queued (AC-1); its absence here proves nothing
    FAIL HARNESS-120 AC-3 (a) gates.sh waiter: it wrote a marker while queued, exits 143 on TERM, and the marker is gone
         expected: seen 143 absent
         actual:   never-written 143 absent
    FAIL HARNESS-120 AC-3 (b) marker and run.lock both name a dead pid: stdout line 1
         scripts/run-status.sh does not exist (expected: run-status: idle: .claude/state/run.lock is left over from pid 2792431, which is no longer running; the next run reclaims it.)
    FAIL HARNESS-120 AC-4 (a) gates.sh --fast beside the holder: stdout line 1
         scripts/run-status.sh does not exist (expected: run-status: running: pid 2819843, started 2026-11-21T18:59:29Z: scripts/gates.sh --fast)
    FAIL HARNESS-120 AC-4 (a) gates.sh --fast beside the holder: stdout line 2
         scripts/run-status.sh does not exist (expected: run-status: machine queue: held by pid 2819654, started 2026-11-21T18:59:23Z, in /tmp/tmp.2Sbu7QdOCm: scripts/gates.sh)
    FAIL HARNESS-120 AC-6 (a): CLAUDE.md's Running things command block has one line beginning bash scripts/run-status.sh, then a # comment
         expected: 1
         actual:   0
    FAIL HARNESS-120 AC-6 (a): CLAUDE.md's Running things section names run-queue.lock
         expected: yes
         actual:   no
    FAIL HARNESS-120 AC-6 (b): /advance-story's GREEN → GATES brief tells it to report queued behind
         expected: yes
         actual:   no
    FAIL HARNESS-120 AC-6 (d): /complete-story's allowed-tools line carries the entry Bash(bash scripts/run-status.sh:*), exactly once
         expected: 1
         actual:   0
    FAIL HARNESS-120 AC-6 (e): the run-lock comment in scripts/gates.sh is there and no longer says it never waits
         expected: found no
         actual:   found yes

run-queue: 374 passed, 205 failed
```

**Passed on arrival: 13, all preconditions, none a claim of this story.**
A's full run holds (AC-1, AC-4: 2), B printed its queued line, B's run.lock
and the queue lock record B and A, A finishes, B started its work once
through, B's status, the two AC-3 (a) "is queued" checks, the dead/live pid
check, the two AC-4 "B in progress beside A" checks, and A finishing in AC-4.
Each pins queue behaviour HARNESS-108/111 built and that suite's own
assertions already pin; they are there so a broken fixture fails as itself.
No story claim passes on arrival, so none is owed a mutation.

**What the tests pin (fact, not suggestion).**

- `scripts/run-status.sh`, run as `bash scripts/run-status.sh` with cwd = the
  tree, and once as `bash <B>/scripts/run-status.sh` with cwd = A and
  `CLAUDE_PROJECT_DIR=A` (must answer for B). The root it prints is compared
  with `$(cd <tree> && pwd)`, the same form the queue lock's `root` already
  takes from `gates.sh`: resolve it the way `gates.sh` resolves `ROOT`.
- The lock path it prints is compared with `$HARNESS_RUN_QUEUE_DIR/run-queue.lock`
  verbatim (the suite passes an absolute, `pwd`-resolved directory).
- Every ask runs with `HARNESS_RUN_QUEUE=off` (C-2: reading ignores it), with
  `HARNESS_RUN_QUEUE_DIR` set to the suite's own directory except AC-5's
  "neither" case, which unsets it and `HOME`.
- stdout is compared line by line and by line count; stderr must be empty on
  every answer; exit 0 on every answer; within 20 s. Lines are C-2's text
  exactly, including the two spaces in `run-status:   behind` and the
  trailing `.` on the `idle` lines and none on the `free`, `held`, `stale`,
  `unreadable` lines.
- Usage: any argument, including one empty argument `""`, gives exactly
  `usage: bash scripts/run-status.sh` on stderr, nothing on stdout, exit 2.
- The marker `<root>/.claude/state/run.queued`: exactly the three
  TAB-separated keys `pid since command`, in that order and nothing else;
  `pid` = the waiting script's `$$` (the pid `rq_run` gets from `exec`);
  `since` matches `^YYYY-MM-DDTHH:MM:SSZ$`; `command` = `scripts/gates.sh`.
  The suite waits for the queued stderr line, then **at most 5 s** for the
  marker: write it at the queued line, as C-1 says. It must be gone once the
  run has started its work (removed at the take), gone after TERM, and never
  written by the holder, by `--fast`, or with the queue off.
- AC-6 regions and needles, all fixed strings:
  - `CLAUDE.md`: section = from the line `## Running things` to the next line
    beginning `## `; block = the first ```` ``` ```` fence in it. Exactly one
    block line = `bash scripts/run-status.sh`, then one or more spaces, `# `,
    a non-space. The section must contain `run-queue.lock` and
    `Never stop a queued run to requeue it` (capital N).
  - `advance-story.md`: from the line beginning `**GREEN → GATES.**` to the
    line beginning `**GATES → REVIEW.**`: `bash scripts/run-status.sh`,
    `Never stop a queued run to requeue it`, `queued behind`.
  - `feature-developer.md`: `## Run and report` to the next `## `:
    `bash scripts/run-status.sh`, `Never stop a queued run to requeue it`.
  - the frontmatter `allowed-tools:` line of `advance-story.md` and
    `complete-story.md`, split on `,` + spaces: exactly one entry equal to
    `Bash(bash scripts/run-status.sh:*)`.
  - `gates.sh`, `selftest.sh`: from the first `#` line matching
    `run lock (HARNESS-034)` (any case) to the first line not starting `#`,
    `#` prefixes stripped: must contain `scripts/run-queue.sh` and must not
    contain `it never waits`. Keep `(HARNESS-034)` and the words `run lock`
    on the heading line, or the region is not found and both fail.
  - Prose needles are matched after joining the region's lines with one
    space (leading/trailing whitespace trimmed), so a sentence wrapped across
    two lines still counts - and `it never` / `waits` split across two
    comment lines still counts as present.

**Not constrained:** the function name that holds the queue-lock path rule
(C-2 says RED does not pin it), the order of reads, how `run-status.sh`
sources `run-queue.sh`, the header wording, the `.claude/state/README.md`
row (C-6; `settings.test.sh` judges it), the `wc -l` of `gates.sh` and
`selftest.sh` (C-4; `sigpipe.test.sh` pins `gates.sh`'s line numbers -
GREEN checks both by hand), and the prose around the needles.

**Negative controls - expected values.** No assertion about an answer has
run (the script is absent). Measured outside the suite with a scratch
candidate (not shipped) in three modes - `right` (C-2), `file` (queued iff a
`run.queued` exists: the AC-3 (b) defect) and `infer` (queued iff the
run.lock pid is alive and the queue is held by another live pid: the AC-4
defect) - first line's state word:

| Planted state | C-2 expects | `right` | `file` | `infer` | fires on |
|---|---|---|---|---|---|
| marker + run.lock both a dead pid | idle (`left over`) | idle | **queued** | idle | file |
| marker dead, run.lock live | running | running | **queued** | running | file |
| marker live but not the run.lock's pid | running | running | **queued** | running | file |
| marker live, no run.lock | idle (`no harness run holds`) | idle | **queued** | idle | file |
| run.lock dead, no marker (AC-3 c) | idle (`left over`) | idle | idle | idle | - (pins the line) |
| run.lock live, queue held by another, no marker (AC-4) | running | running | running | **queued** | infer |
| marker = run.lock live pid, queue held by another (positive) | queued | queued | queued | queued | - (the control's control) |

So each control can fail (C-8): AC-3 (b) against a marker-existence rule, AC-4
against inference from the two locks. GREEN confirms these against the
shipped script, not merely that the cases pass. In the suite each of those
fires as: the stdout line count (4 vs 2) and lines 1 and 2 of that case.

**Mutation table (predictions, all for GATES; none run in RED).**

| Mutation (through `mutate.sh`, suite `bash .claude/tests/run-queue.test.sh`) | Predicted red | Which |
|---|---|---|
| DV-1: the one marker write in `run_queue_acquire` made a no-op | 17 | C-1's 5 marker fields; AC-1 asked in B: count + lines 1-4 (5); AC-3 (a) both (2); all 5 `mk_eq` (MARKER_SEEN stays no: C-1's A, AC-2 x2, AC-4 x2). AC-1 asked in A, AC-4's `running`/`held` lines, the planted cases and all 361 HARNESS-108/111/112 assertions stay green |
| DV-2: `bash scripts/run-status.sh` respelled on CLAUDE.md's block line | 1 | AC-6 (a) block line only; `run-queue.lock` and the sentence are separate needles |
| `run-status.sh` believes any marker (the `file` mode) | 12 | AC-3 (b) four marker cases x (count, line 1, line 2) |
| `run-status.sh` infers queued from the two locks (the `infer` mode) | 6 | AC-4 (a), (b) x (count, line 1, line 2); AC-1's B still queued, so green |
| marker removal at the take dropped (release still removes) | 4 | AC-2 `mk_eq` once started; AC-2 asked in B: count, lines 1-2 (it reads queued) |
| marker removal in `run_queue_release` dropped (take still removes) | 2 | AC-3 (a) both (TERM leaves it) |

Only DV-1 and DV-2 are owed (rules.md, "Mutation work per story"); the rest
are predictions for `/audit-mutations`.

**Deferred verifications.** RED cannot run DV-1, DV-2 or DV-3: there is no
marker write to remove, no `run-status.sh` line in `CLAUDE.md` to respell
and no status script to ask. All three are left to their owner, GATES.

**For GREEN.**

- The whole suite took **1221 s**, then **776 s** on the final tree, locally under host load (attest
  `duration:`; earlier HARNESS-112 runs of the 361-assertion suite were not
  timed in its story). The new block adds about 45 `run-status.sh` calls,
  each bounded at 20 s, and four real held runs. The suite has no per-suite
  timeout; if GREEN's measured time is far above RED's, say so.
- The floor counts passes: the suite sits below 579 until GREEN lands.
  GREEN re-measures the executed count; if it is not 579, the handoff was
  wrong - report it rather than moving the number (C-7).
- Files touched in RED: `.claude/tests/run-queue.test.sh`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, and this
  story's `## Test plan` and `## Handoff`.

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


### R-1 (the marker is removed when a waiter goes on without the queue)

- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2), 2026-11-21, diff review round 1, finding 1: the `run_queue_unmark` calls on the two "runs without the machine-wide queue" exits of `run_queue_acquire` (`scripts/run-queue.sh:245`, `:284`) are pinned by no assertion; the reviewer reproduced, in a scratch tree, a waiter whose lock path became a directory going on to work while `run-status.sh` still said `queued`. Upheld by that dispatch, routed RED; no separate ADJUDICATE needed.

- **Which test.** None existed: this return adds a case rather than
  correcting one. `.claude/tests/run-queue.test.sh`, HARNESS-120 block, new
  `describe "HARNESS-120 C-1  a waiter that goes on without the queue takes
  its marker with it (R-1)"`, placed between AC-4 and AC-5. Before it, no
  assertion pinned the `run_queue_unmark` on either "runs without the
  machine-wide queue" exit inside `run_queue_acquire`'s wait loop: deleting
  either left 579/579 green.
- **How it was found.** Diff review round 1, finding 1 (Should fix, routed
  RED).
- **Which site the case reaches.** The `2)` arm of the `case $?` after
  `run_queue_link` (`scripts/run-queue.sh:245`, `2) run_queue_unmark`): with
  `run-queue.lock` a directory, `run_queue_link` returns 2 on its first check
  (`[ -e "$2" ] && [ ! -f "$2" ]`). It does not reach `:284`, the
  "could not remove a stale lock" exit; that one is not pinned by this case.
- **What it asserts (4 assertions, run-queue floor 579 -> 583).** In a
  case-private queue (`new_case`'s `$Q`), a live planted holder (`qplant
  "$LIVE1" ...`); B's full `gates.sh` started with its work held; bounded
  waits (`wait_until`, never a fixed sleep) for B's `run-queue: queued:` line
  and its `.claude/state/run.queued`; `run-queue.lock` replaced by a
  directory; bounded waits for B's cannot-use line and for its work to start.
  1. precondition: B's `q1` line exactly once (whole-line `grep -cxF`) and
     the marker present;
  2. precondition: the whole `cannot_line "$Q" scripts/gates.sh` line
     exactly once, and B's work started;
  3. B's `run.queued` is absent;
  4. `bash scripts/run-status.sh` asked in B: line 1, compared whole, is
     `s_run <B's pid> <run.lock started> scripts/gates.sh`. The negation
     (`run-status: queued: pid ...`) cannot match it.
- **What earns it.** One mutation no-opping exactly the reached unmark;
  1 line changed, the two pins red and the two preconditions green, every
  other assertion green, restore verified:

```
=== mutate: scripts/run-queue.sh (1 line(s) changed by s/2) run_queue_unmark/2) :/) ===
  245 -       2) run_queue_unmark
  245 +       2) :

=== mutate: running bash .claude/tests/run-queue.test.sh ===

  HARNESS-120 C-1  a waiter that goes on without the queue takes its marker with it (R-1)
    FAIL HARNESS-120 C-1 R-1: once B goes on without the queue, B's run.queued is gone
         expected: absent
         actual:   present
    FAIL HARNESS-120 C-1 R-1: asked in B, working without the queue, the first line is running for B's pid
         expected: run-status: running: pid 3045865, started 2026-11-21T22:20:20Z: scripts/gates.sh
         actual:   run-status: queued: pid 3045865, waiting since 2026-11-21T22:20:20Z: scripts/gates.sh

run-queue: 581 passed, 2 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-120/.claude/state/mutations/scripts_run-queue.sh.20261121T221538Z.3035331.bak) ===
  245:       2) run_queue_unmark
```

  Unmutated, same tree, local Windows host: `run-queue: 583 passed, 0 failed`
  (about 5 min wall). `bash scripts/mutate.sh --check`: no stranded mutation.
- **GREEN is a no-op.** No source file changed in this return
  (`git status`: only `.claude/tests/run-queue.test.sh`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` and this
  story); the shipped `scripts/run-queue.sh` already satisfies the case.

## Diff review

### Round 1 (b1f3616, against merge-base fcf3835)

Dispatched: `lead-po`, DIFF-REVIEW row, planned `fable`, resolved Fable 5.2
(`claude-fable-5-2`). Every path the findings' fixes name classifies as
`harness` (`classify.sh`), so the lock permits both routes and the labels
are followed as given.

**Should fix:**

1. **The marker's removal on the "runs without the queue" exits has no test**
   (`scripts/run-queue.sh:245`, `:284`; `.claude/tests/run-queue.test.sh`).
   Deleting either `run_queue_unmark` leaves all 579 assertions green. A
   waiter that finds the lock path turned into a directory prints `cannot use
   ...; runs without the machine-wide queue` and starts working; with the line
   gone its marker stays and `run-status.sh` says `queued ... Never stop a
   queued run` for a run working beside the holder, the answer AC-4 exists to
   rule out. Fix: one case in `run-queue.test.sh` (queue B behind a planted
   live holder, wait for the marker, replace `run-queue.lock` with a
   directory, wait for the `without the machine-wide queue` line, assert the
   marker absent and the first status line `running`), earned by one
   `mutate.sh` run dropping the unmark at line 245; floor and its mirror move.
   **Route: RED**
2. **The new paragraph tells the orchestrator to run a command the sentence
   above it forbids** (`.claude/commands/advance-story.md:216-220`; the same
   pair in `.claude/agents/feature-developer.md:104-107`). "While it is out,
   you run nothing in that worktree either" sits directly above the new
   instruction to run `bash scripts/run-status.sh` there. Fix: one clause in
   the new paragraph of each file (not the paragraph `dispatch.test.sh`
   reads): `run-status.sh` only reads, and is the one command allowed there
   while the run is out. No needle moves. **Route: GATES**

**Nice to have:**

3. `run-status.sh` re-reads the queue lock for `started`, `root`, `command`
   after reading the pid once (`:55`, `:70-71`, `:90-91`); a holder change
   between reads gives one mixed line. Read the four fields once. **Route:
   GATES**
4. A `run-queue.lock` that is not a regular file is described as reclaimable
   (`:87-88`); it is not (`run_queue_link` returns 2 and runs go ahead without
   the queue). A separate line would be outside C-2's list: a follow-up, not
   this story. **Route: GATES**

**GREEN's two deviations, judged.** Unmark on the two "without the queue"
exits: correct and necessary (finding 1), agrees with C-1; it only lacks a
test. Exit 1 when `run-queue.sh` is missing: acceptable; not an answer,
mirrors `gates.sh` on a missing `run-lock.sh`.

**Checked and found sound:** wrong-process removal (BASHPID guard, `$$`
check, nested pass-through returns before the mark); signals (EXIT and
`selftest_exit` reach `run_queue_release` while waiting); races (half-written
marker reads `running`; `behind nothing at this instant` pinned); paths
(pids compared, never roots); state listings (`.gitignore:2`, README row
`yes`, no `settings.json` rule owed; `refresh-harness.sh` ships the script);
`gates.sh` 1315 and `selftest.sh` 728 lines unchanged; `settings` 71/0,
`sigpipe` 91/0, `dispatch` 205/0, `procedure` 183/0.

Verdict: fix 1 and 2 first.

**Orchestrator's disposition.** Finding 2 is made first in GATES; finding 1
is a return to RED as R-1, adjudicated by this dispatch. Findings 3 and 4 are
Nice to have and not taken: 3 corrects itself on the next ask, and 4 needs a
line outside C-2, so it is a follow-up.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-21T22:28:59Z
    commit: 8049352
    tree:   02f312bb7fd10c58afc96a3f611e28df8c3ea301
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

- **PO questions answered by the user (2026-11-21).** On "Yes, advance it"
  with both planner assumptions standing: (1) the answer is per tree plus the
  one queue holder; (2) `phase.sh show` and `attest.sh check` do not report
  "queued". The user added: "we will want to plan the shared queue as well".
  A machine-wide list of every waiting tree is therefore a follow-up story
  of its own, to be planned after this one; it stays out of scope here.
- **GREEN verified (orchestrator, 2026-11-21).** feature-developer (opus,
  resolved claude-opus-5-5). `attest.sh check -- bash scripts/selftest.sh
  run-queue` was `fresh`, exit 0, `run-queue: 579 passed, 0 failed`, floor met
  (log `.claude/state/attest-logs/20261121T194212Z.2871176.log`);
  `attest.sh check -- bash scripts/gates.sh --fast` `fresh`, exit 0 (vacuous).
  Every negative-control value the handoff recorded was measured against the
  shipped script and matched (seven states). Deviations reported by GREEN:
  `run_queue_unmark` is also called on the two "without the queue" exits in the
  wait loop; `run-status.sh` exits 1 with one stderr line if its sibling
  `run-queue.sh` is missing (uncovered by the Contract). Live check on the real
  machine queue: `run-status.sh` printed `idle` for this tree and `machine
  queue: held by pid 2923853 ... in /d/fantasy-world-builder: scripts/gates.sh`,
  matching the lock file.
- **GREEN after R-1 (orchestrator, 2026-11-21): a no-op, verified.** R-1
  added a test for code that already existed; `git diff 471b0ac -- scripts/`
  is empty. `attest.sh check -- bash scripts/selftest.sh run-queue` was
  `fresh`, exit 0, `run-queue: 583 passed, 0 failed`, floor met (log
  `.claude/state/attest-logs/20261121T222053Z.3046439.log`). Not re-run.
  R-1 reaches the unmark at `scripts/run-queue.sh:245` only; the one at
  `:284` (a stale lock that cannot be removed) is still pinned by no
  assertion.
