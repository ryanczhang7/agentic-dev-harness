---
id: HARNESS-121
title: One command lists every run waiting in the machine queue
slug: one-command-lists-every-run-waiting-in-t
epic: 
type: feature
status: in-progress
phase: GREEN
branch: story/HARNESS-121-one-command-lists-every-run-waiting-in-t
depends_on: [HARNESS-120]  # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/run-queue.sh, scripts/run-status.sh, CLAUDE.md, .claude/tests/run-queue.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the run-queue suite under its selftest floor, which CI runs in full on the PR
---

## Context

Asked for by the user on 2026-11-21, when deciding HARNESS-120: "we will want
to plan the shared queue as well". HARNESS-120 adds `bash scripts/run-status.sh`,
which answers for the tree it is run in (idle, running, queued, left over) and
names the one holder of the machine-wide run queue (HARNESS-108, release 127;
HARNESS-111, release 129; `scripts/run-queue.sh`). Its planner put the question
"is a per-tree answer plus the one queue holder enough, or do you want a
machine-wide list of every waiting tree?", and the user took the per-tree
answer for 120 and this story for the list.

The case, observed that day: manga-translator held the queue, and
clean_calendar and the fantasy-world-builder worktree `fwb-WORLD-172` both
waited behind it. After HARNESS-120 each waiting tree can say "I am queued
behind manga-translator". Neither can say that the other is waiting too, and
the user, asking from any one tree, cannot see the line. Nothing records it:
a waiter's `run.queued` marker lives in its own tree, and the queue directory
holds only the holder's lock.

**What this story adds.** A waiter list beside the queue lock: each run that
begins to wait writes one small record there and removes it when it starts or
is stopped. `bash scripts/run-status.sh --all`, from any tree, prints what the
no-argument form prints and then every run waiting on the machine: pid, since
when, tree root, command. A record is evidence only while its pid is alive and
still holds its tree's run lock; a file alone lists nothing.

**What it changes in HARNESS-120, which must be DONE first** (`depends_on`).
120's Out of scope says "A machine-wide list of waiters ... is not recorded
anywhere and is not added"; this story adds it. 120's C-2 says any argument is
a usage error; `--all` becomes the one argument accepted, and the usage line
becomes `usage: bash scripts/run-status.sh [--all]`. The no-argument answer
does not change by a byte, and "no `--tree` or `--root` argument" stands.
This story was first planned while 120 was at RED. 120 is now DONE (PR #210,
release 139, `main` at b30f2b6), and every line number, count and floor below
was re-read on that tree on 2026-11-21; the Contract says what moved.

**It does not run beside HARNESS-122.** `bash scripts/plan.sh conflicts`
reports `CONFLICT HARNESS-121 + HARNESS-122`: both write
`.claude/harness/VERSION`, `.claude/tests/floors.conf` and
`.claude/tests/selftest.test.sh`. They run one after the other. This story
takes release 140 if it reaches GATES first; whichever goes second takes the
next free number when it merges `main` (C-6).

**No epic.** `epic:` is empty, as it is for the other HARNESS stories, so
there is no epic done-when to check this story against.

**The queue itself does not change.** Which runs queue, the poll, the
heartbeat, reclaim, nesting, and the order waiters get through in (HARNESS-108
AC-2: unspecified, whichever polls first) are as they are. The list shows the
order runs began to wait and says in its own output that this is not the order
they start in.

**Why it is not split.** The writer (two functions in `run-queue.sh`, the
ones that write and remove 120's marker) and the reader (one flag in `run-status.sh`) are one behaviour:
a list nobody writes prints nothing, and records nobody reads are exhaust. One
suite, one cycle.

**What judges it.** Every gate in this repository is unconfigured, so no gate
fails if this breaks; `required_gates` stays `[]`. The judge is the
`run-queue` self-test suite (`bash .claude/tests/run-queue.test.sh`) under its
floor in `.claude/tests/floors.conf`, which CI runs with every other suite on
the PR.

**Known limits, stated rather than fixed.** A tree on a release older than
this one queues (if 127 or newer) but writes no record, so it waits without
being listed; the list says so in its last line. A tree older than 127 neither
queues nor holds the queue. `kill -0` has HARNESS-108's limits: a recycled pid
reads alive, and a waiter in another pid namespace (WSL, a container) reads
gone.

## Acceptance criteria

"The queue", "a run that queues" and "asked in tree T" are HARNESS-120's
terms; every case gives the queue a directory of its own through
`HARNESS_RUN_QUEUE_DIR`. "Asked with `--all` in T" is
`bash scripts/run-status.sh --all` run from T's own copy. "The no-argument
lines" are what HARNESS-120's C-2 prints for T at that moment. A "record" is
Contract C-1's file; the lines are C-2's, compared whole.

- **AC-1** — Given a run that queues in tree A that holds the queue, and runs
  that queue in trees B and then C, each having printed its
  `run-queue: queued:` line, when it is asked with `--all` in A, in B, in C
  and in a fourth tree D where nothing runs, then each answer is exactly that
  tree's no-argument lines, then the `waiting` line for B, then the `waiting`
  line for C - each naming that run's pid, the time it began to wait, its
  tree root and its command - then the `2 runs are waiting` line and the
  `predates this list` line, with exit 0 and nothing on stderr. The `since`
  on B's `waiting` line is the `since` on B's own no-argument `queued` line.
  Neither B's nor C's work has started after all four answers.
- **AC-2** — Given AC-1's runs, when A finishes and one of B and C has
  started its work, then asked with `--all` in D the queue line is
  `machine queue: held` naming the one that started, the only `waiting` line
  is the other's, the count line is `1 run is waiting.`, and the queue
  directory holds no record for the one that started. When all three have
  finished, asked with `--all` in any tree the answer ends
  `machine queue: free`, `nothing is waiting`, `predates this list`, and the
  queue directory holds no record at all - each record having been seen
  there while its run waited.
- **AC-3** — *The control: listed means a live waiter, not a file.* (a) Given
  B waiting as in AC-1 and its record seen in the queue directory, when B is
  sent `TERM`, then it exits 143, its record is absent, and `--all` no longer
  lists it. (b) Given a queue directory holding a record whose pid is not
  running; a record whose pid is running but is not the pid its tree's
  `run.lock` records; a record whose tree has no `run.lock`; a record naming
  the pid that holds the queue; a record with no numeric pid; a record whose
  file name and recorded pid differ; and a `.tmp` record - when asked with
  `--all`, then no `waiting` line is printed for any of them and the count
  line is `nothing is waiting`. (c) Given a record whose pid is not running
  and the record of a live waiter, when another run begins to wait, then the
  first record is gone, the live waiter's is byte for byte what it was, and
  no `run-queue:` line says anything about either.
- **AC-4** — *The control: a run that does not wait is never listed.* Given a
  run that queues in tree A that holds the queue, when (a) a `gates.sh --fast`
  run, or (b) a full `gates.sh` run with `HARNESS_RUN_QUEUE=off`, is in
  progress in tree B, then asked with `--all` in B the first line is the
  `running` line for B, the queue line names A, and the count line is
  `nothing is waiting`; and A, which took the queue without waiting, has
  written no record. (c) Given a run waiting in tree B behind a live holder,
  its record seen in the queue directory, when the queue lock becomes a
  directory and B prints its `runs without the machine-wide queue` line and
  starts its work, then B's record is absent, and asked with `--all` in B the
  first line is the `running` line for B, no `waiting` line is printed and
  the count line is `nothing is waiting`.
- **AC-5** — Asking changes nothing and never waits. Given a held queue, two
  live waiters and one record whose pid is not running, when asked with
  `--all`, then it returns within the suite's bound with exit 0, and the
  queue directory and every tree's `.claude/state` hold exactly the files,
  byte for byte, that they held before - the dead record included. Given an
  absent queue directory, it ends `machine queue: free`, `nothing is
  waiting`, `predates this list`, and does not create the directory. Given
  neither `HARNESS_RUN_QUEUE_DIR` nor `HOME`, the last line is the `cannot be
  located` line, with no count line, and the exit is 0. Given any argument
  other than exactly `--all`, or `--all` with a second argument, it prints
  `usage: bash scripts/run-status.sh [--all]` on stderr, nothing on stdout,
  and exits 2.
- **AC-6** — The list is named where an agent reads first: the fenced block
  under `## Running things` in `CLAUDE.md` has a line beginning
  `bash scripts/run-status.sh --all` followed by a `#` comment, and it is a
  different line from the one HARNESS-120's AC-6 (a) pins.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/run-queue.sh`, `scripts/run-status.sh`, `CLAUDE.md`, `.claude/tests/run-queue.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/run-queue.test.sh`, the suite's floor in `floors.conf` and its
hand-copied line in `selftest.test.sh` (C-6). GREEN (feature-developer) writes
everything else and touches no suite.

**Not written: `scripts/run-lock.sh`, `scripts/gates.sh`, `scripts/selftest.sh`,
`scripts/attest.sh`, `.claude/tests/_lib.sh`, `.claude/state/README.md`,
`.claude/commands/*`, `.claude/agents/*`, `.claude/harness/rules.md`,
`.claude/settings.json`.** The list lives outside every tree, so the state
table gains no row. `allowed-tools` already carries
`Bash(bash scripts/run-status.sh:*)` from HARNESS-120, which covers `--all`.

**Confirmed on `main` at b30f2b6 (HARNESS-120 merged), 2026-11-21.** This
story was first planned against 120's Contract while 120 was at RED, and
asked for four things to be read once it merged. They were, and this is what
was found and what it changed here:

- `scripts/run-status.sh` exists (95 lines) and prints the lines 120's C-2
  lists. Its usage test is lines 37-40 (`if [ "$#" -gt 0 ]`), the tree's
  state 57-80, the queue line 82-94. It reads the queue lock's pid once into
  `QPID` (line 55). One thing 120's Contract did not say: it exits 1, with
  one line on stderr, when `scripts/run-queue.sh` is missing. That stays, for
  `--all` too, and no criterion here covers it.
- **The marker is written in one place and removed in four, not two.**
  `run_queue_mark <root> <command>` (lines 127-135) is called once, at line
  258, directly before the `run-queue: queued:` line. `run_queue_unmark`
  (139-144) is called at 239 (the take), at 245 and 284 (the two exits where
  a waiter goes on "without the machine-wide queue": the lock path stopped
  being usable, or a stale lock could not be removed), and at 296 (in
  `run_queue_release`). This plan knew only the take and the release. A
  waiter that leaves by 245 or 284 is alive, holds its tree's run lock and is
  not the holder, so every belief rule of C-2 would pass and it would be
  listed while it works. **Changed for that reason:** C-1 now has the record
  written inside `run_queue_mark` and removed inside `run_queue_unmark`, so
  all four sites carry it without a new call, and AC-4 gained (c), which
  reaches line 245 the way 120's R-1 case does.
- The queue-directory function is `run_queue_dir` (lines 114-122): prints
  the directory, returns 1 with neither variable set. C-2 names it.
- The `run-queue` floor is 583 (`.claude/tests/floors.conf:63`, mirrored at
  `.claude/tests/selftest.test.sh:554`), not the 361 this plan was written
  beside. C-6 names it.
- 120's AC-6 (a) needle was read (C-4): the new `--all` line cannot match it,
  so RED tightens nothing and DV-3 lost its part (b).

**C-1. The record: `<queue dir>/run-queue.waiter.<pid>`.** `<queue dir>` is
the directory of the queue lock, by HARNESS-108's rule, unchanged
(`$HARNESS_RUN_QUEUE_DIR` when non-empty, else `$HOME/.cache/agentic-harness`).
`<pid>` is the waiting script's `$$`. Four TAB-separated lines, the queue
lock's convention with `since` for `started`:

    pid<TAB><the waiting script's $$>
    since<TAB><UTC, to the second>
    command<TAB>scripts/gates.sh
    root<TAB><the tree root, absolute>

- **Written once per wait**, inside `run_queue_mark <root> <command>`, which
  `run_queue_acquire` calls once (line 258) directly before its
  `run-queue: queued:` line. `since` is the same string the marker gets: one
  `date` call serves both (AC-1), where today the call sits inside the
  marker's `printf`. `command` and `root` are `run_queue_mark`'s two
  arguments, the strings the queue lock would record. The record does not
  depend on the marker: one that cannot be written does not stop the other,
  and each is tracked by a variable of its own (`RUN_QUEUE_MARK` exists; the
  record's is GREEN's to name).
- **Written whole or not at all.** The record goes to
  `run-queue.waiter.<pid>.tmp` and is moved into place with `mv -f`, a rename
  within one directory, so a reader never sees half a record, and a record
  left by an earlier process of the same pid is replaced. No `ln` contest is
  needed: the name carries the pid, so no two live writers share a name.
- **Removed** inside `run_queue_unmark`, so wherever 120's marker is removed
  and by no new call: when the run takes the queue, before the
  `run-queue: starting` line (line 239); on the two exits where a waiter goes
  on without the queue (245, 284; AC-4 c reaches 245); and in
  `run_queue_release` (296), which the callers' EXIT trap reaches through
  `run_lock_release` (AC-3 a: `TERM` and `INT`). Only the process that wrote
  it removes it: `run_queue_unmark` removes the record iff this process
  wrote one and the file still records `$$`, the test it applies to the
  marker, and `run_queue_release` keeps its `BASHPID` test. The `.tmp` goes
  with it. Removing the record is not conditional on a marker having been
  written: today `run_queue_unmark` returns at once when `RUN_QUEUE_MARK` is
  empty, and that early return must not skip the record.
- **Never written** by a run that does not wait: an uncontended take, a
  nested pass-through, a run that does not queue (`--fast`, `--gate`, a named
  suite: `run_lock_queues` says no before `run-queue.sh` is sourced),
  `HARNESS_RUN_QUEUE=off`, a run that proceeds "without the machine-wide
  queue" before it ever waits (AC-4 a, b). One that waited first and then
  goes on without the queue wrote a record and removes it (AC-4 c).
- **The sweep.** Immediately before writing its own record, in
  `run_queue_mark`, and at no other time, a waiter removes every file in `<queue dir>` named
  `run-queue.waiter.<n>` or `run-queue.waiter.<n>.tmp` whose `<n>` is not all
  digits or is not alive (`run_queue_alive`). It judges by the name, reads no
  record and never removes a file whose `<n>` is alive (AC-3 c). This is what
  bounds the exhaust of waiters killed with `SIGKILL`; nothing else cleans
  them, and the reader never does (AC-5). A waiter in another pid namespace
  reads gone and can be swept: the queue does not span namespaces either
  (HARNESS-108).
- **Silent.** Writing, removing and sweeping print nothing. No existing
  `run-queue:` line changes by a byte. A record that cannot be written or
  moved is not an error and is not reported: the run waits exactly as it
  does today and is not listed. That limit goes in the script's header.

**C-2. `bash scripts/run-status.sh --all`.** The script takes no argument, as
today, or exactly one, `--all`. Anything else - another word, an empty
argument, `--all` plus a second argument - prints
`usage: bash scripts/run-status.sh [--all]` on stderr, nothing on stdout, and
exits 2. HARNESS-120's three usage cases (`--help`, a tree path, an empty
argument) take their expected string from one line of the suite's
`usage_case` helper (`.claude/tests/run-queue.test.sh:1570`); RED changes
that string to this one. The three are then red against 120's script, so
they are watched to fail in the ordinary way. The script's test today is
`if [ "$#" -gt 0 ]` at lines 37-40, and its header's "any argument is a
usage error" sentence is GREEN's to correct.

With no argument the script reads and prints exactly what HARNESS-120's C-2
says. Every other existing assertion of the suite keeps its expected value:
120's AC-1 case has a waiter registered once this story lands, and its
whole-stdout comparisons are what show the no-argument form prints no
`waiting` line.

With `--all` it prints the no-argument lines for its own tree, unchanged and
first, then the list. It reads, in addition, the records in `<queue dir>` and
`<R>/.claude/state/run.lock` of each record's `root`; it writes nothing,
creates nothing, removes nothing (no sweep), takes no lock and never sleeps.
stdout only; exit 0 on every answer. It resolves the queue directory through
`run_queue_dir`, as the no-argument form already does (line 53), and `Q`
below is the `QPID` it already reads once (line 55). Bash 3.2, awk and
coreutils only.

**A record is believed** - its run is listed - only when all of these hold,
with `<n>` the digits of its file name, `P` its recorded `pid`, `R` its
recorded `root`, and `Q` the pid the queue lock records:

1. the name is `run-queue.waiter.<n>` with `<n>` all digits (a `.tmp` is
   never read);
2. `P` is numeric and equals `<n>`;
3. `P` is alive (`run_queue_alive`);
4. `P` is not `Q`, when the queue lock records a numeric, alive `Q`: a run
   that has just taken the queue is the holder, not a waiter, in the instant
   before it removes its record;
5. `R/.claude/state/run.lock` is a file whose `pid` is `P`. A waiter holds
   its tree's run lock for the whole wait (HARNESS-108, lock order), so a
   live pid that does not hold it is some other process.

Rule 3 is the one that matters after `SIGKILL`; rule 5 is what stops a
recycled pid being listed once that tree has run again. A killed waiter whose
pid has been recycled, in a tree that has not run since, is listed until the
next waiter anywhere sweeps or that tree runs: `kill -0`'s limit, in the
header.

Believed records are printed in ascending order of `since`, ties in ascending
numeric `pid`: `since` is ISO 8601 UTC, so text order is time order. With `P`,
`S`, `R`, `C` a record's `pid`, `since`, `root`, `command`, printed verbatim:

    run-status: waiting: pid <P>, since <S>, in <R>: <C>

then one **count line**:

| Believed records | Count line |
|---|---|
| 0 | `run-status: nothing is waiting in the machine queue.` |
| 1 | `run-status: 1 run is waiting.` |
| N ≥ 2 | `run-status: <N> runs are waiting, listed in the order they began to wait. Whichever polls first after the holder ends starts next; that need not be the first listed.` |

then, always last:

    run-status: a run in a tree whose harness predates this list waits without appearing in it.

When the queue line is `cannot be located`, it stays last and nothing follows
it: no `waiting` line, no count line, no `predates` line. In every other
queue-line state (free, held, stale, unreadable) the list is read and
printed; waiters can exist beside a stale lock or, for an instant, a free
one.

AC-1's order needs B's `since` strictly before C's. The suite starts C only
after B's record is in the queue directory and the UTC second has changed,
waiting on that condition with a bound, not on a fixed sleep (HARNESS-111's
DV-2 lost an attempt to one).

**One rule per planted record.** Each record AC-3 (b) plants fails exactly
one of the five rules and passes the other four, or the case shows nothing
about the rule it is named for. In particular the record naming the queue
holder's pid sits beside a `run.lock`, in its recorded root, that records
that same live pid, so that only rule 4 keeps it out; and the record whose
name and pid differ names a live pid that holds its tree's run lock. The
suite already plants believed waiters for HARNESS-120 (its "three planted
waiters that ARE believed"); the same means serve here.

*Amended in RED (2026-11-21, reason: measured by the test-developer, see the
handoff's "Finding: one planted record cannot fail exactly one rule").* One
record is the exception: the record with no numeric pid fails rules 2, 3 and
5 read on its recorded pid, because a non-numeric pid is never alive and never
equals a `run.lock` pid, and no planting avoids that. The suite plants it so
that, read by the digits of its file name, it passes rules 1, 3, 4 and 5; rule
2 alone is isolated by the record whose name and pid differ. No criterion
changes, and DV-2 is unaffected. GREEN builds what this block now says.

**Presence before absence.** Every assertion that a record is absent (AC-2,
AC-3 a, AC-4 c) is made only for a record the same case first saw present,
and AC-4 (a) and (b)'s "has written no record" is paired with the
`nothing is waiting` line from the same moment. An absence nothing ever contradicted passes against a
tree that never writes records at all.

Suites run with `HARNESS_RUN_QUEUE=off` and may inherit the host's `HOME`.
Every call the suite makes sets `HARNESS_RUN_QUEUE_DIR` to its own temp
directory, except AC-5's "neither" case. No case may read or write
`$HOME/.cache`.

**C-3. What `run-queue.sh` does not change.** Every `run-queue:` line, the
four-line lock record, lock order, the poll, the heartbeat, reclaim, nesting,
who gets through first, and 120's marker: byte for byte and step for step.
`run_queue_acquire <root> <command>`, `run_queue_release`,
`run_queue_mark <root> <command>` and `run_queue_unmark` keep their
arguments, return values (always 0) and output (none); the last two each do
one more silent thing. `run_queue_acquire`'s body is not edited: its one
`run_queue_mark` call and four `run_queue_unmark` calls stay where they are.
The suite pins two lines of this file whole, which must survive as they are:
`run_queue_alive() { kill -0 "$1" 2>/dev/null; }` and the
`if [ -e "$lock" ] && [ "$(run_queue_pid "$lock")" = "$pid" ]; then` of the
reclaim (`.claude/tests/run-queue.test.sh:1184-1189`). The header gains the list under a
heading of its own - the record, the sweep, the belief rules by reference to
`run-status.sh`, the limits - and the `WAIT, NEVER REFUSE` paragraph's
sentence about `bash scripts/run-status.sh` gains `--all`. Its sentence
"Waiters are not first-come-first-served" stays.

**C-4. `CLAUDE.md`.** One line in the fenced block under `## Running things`,
directly after 120's `bash scripts/run-status.sh` line:

    bash scripts/run-status.sh --all     # that, and every run waiting in the machine queue, from any tree

GREEN may reword the comment; the needle is the line's beginning,
`bash scripts/run-status.sh --all`, then spaces and `#`. Nothing else in the
file changes: it is in context on every turn, and 120's six-line paragraph is
the budget for prose about the queue. 120's line is `CLAUDE.md:167`.
**The two pins do not satisfy each other; read on `main`, not assumed.**
120's AC-6 (a) is, at `.claude/tests/run-queue.test.sh:1611-1612`,

    count_span "bash scripts/run-status.sh" '^ +# [^ ]' "$W/rt.fence"

expected `1`: a line of the block that begins with that string and whose
remainder is spaces, `#`, a space and a non-space. The new line's remainder
begins ` --all`, which that expression does not match, so 120's count stays
1 and its needle is left alone. AC-6's own pin is the same helper with
`bash scripts/run-status.sh --all` as the prefix, expected `1`; the
no-argument line does not begin with that prefix. Each can fail without the
other (DV-3).

**C-5. Oracle partition.** All six criteria are **mechanical**: pin them
exactly. There is no statistic and no threshold; the only numbers are exit
statuses (0, 2, 143), the counts in the count line, and the suite's existing
bounds. C-1's record and C-2's lines are **settled**: read them out, do not
reword them in the test. The controls are AC-3 (b) and AC-4, and each must be
able to fail: AC-3 (b) if a record is believed because it is there, AC-4 (a)
and (b) if a record is written by a run that is not waiting, or a `running`
tree is inferred to be waiting from the two locks, AC-4 (c) if a waiter that
stopped waiting keeps its record. AC-4 (c) is built as HARNESS-120's R-1
case is (`.claude/tests/run-queue.test.sh:1507` on: a planted live holder,
B queued, `run-queue.lock` replaced by a directory); the queue line it then
gets is 120's `unreadable lock` line, which the case reads out and does not
restate.

**C-6. The floor and the release.** `run-queue` is floored in
`.claude/tests/floors.conf` and copied by hand in
`.claude/tests/selftest.test.sh`; HARNESS-120 left it at 583
(`floors.conf:63`, `selftest.test.sh:554`), and
`run-queue: 583 passed, 0 failed` is the baseline RED starts from. RED
raises both to the executed count it measures, with a dated comment in
`floors.conf` in the form the HARNESS-120 entries use (`floors.conf:1330`). Every new case fails **one** assertion per expected
line whether `--all` is supported or not, so the executed count is the same
in RED and GREEN; GREEN re-measures, and if it differs the handoff was wrong
and GREEN reports it instead of moving the number. No other floor moves.
`.claude/harness/VERSION` becomes `140 (<the real date of the GATES commit>)`;
139 is HARNESS-120's, and `main` reads `139 (2026-11-21)`. If another story
(HARNESS-122 also bumps it) takes 140 first, this one takes the next free
number when it merges `main`.

**C-7. Callers of everything whose shape or behaviour changes.** No
function's arguments or return value change. Grepped on `main` at b30f2b6
(`grep -rn` over `*.sh`, `*.md`, `*.json`, `*.conf`, story files left out).
RED's handoff states that it ran the same greps on its own tree and that the
lists still hold, or says what differs.

- **The command line of `scripts/run-status.sh`** (the usage line and exit 2
  change; the no-argument answer does not). Nothing in the tree passes it an
  argument except the suite's usage cases.
  - Runs it: `.claude/tests/run-queue.test.sh` - `rs_ask` (line 1257), the
    `RS` path (1205), `ASK_SCRIPT` (1470), and `usage_case` (1565-1575),
    whose line 1570 holds the one expected usage string. That line is the
    only caller that changes.
  - Names it in prose or a comment, no argument, unchanged:
    `CLAUDE.md:167`; `.claude/commands/advance-story.md:5` (`allowed-tools`),
    `:220`, `:222`, `:226`; `.claude/commands/complete-story.md:5`
    (`allowed-tools`); `.claude/agents/feature-developer.md:106-107`;
    `.claude/state/README.md:24`, `:153`; `scripts/gates.sh:281`;
    `scripts/selftest.sh:430`; `scripts/run-queue.sh:59`, `:73-74`, `:113`;
    `.claude/tests/floors.conf:1337`. The `allowed-tools` entry
    `Bash(bash scripts/run-status.sh:*)` already covers `--all`.
  - Pins text about it: `.claude/tests/run-queue.test.sh:1611-1631` (120's
    AC-6 a to d). None reads the usage line; (a) is the needle C-4 quotes.
- **`run_queue_mark`** (now also sweeps and writes the record): one caller,
  `scripts/run-queue.sh:258`. No suite calls it by name.
- **`run_queue_unmark`** (now also removes the record): four callers,
  `scripts/run-queue.sh:239`, `:245`, `:284`, `:296`. No suite calls it by
  name.
- **`run_queue_acquire`**: one caller, `scripts/run-lock.sh:141`.
  **`run_queue_release`**: one caller, `scripts/run-lock.sh:214`. Neither
  changes shape; listed because their bodies reach the two functions above.
- **`run_queue_dir`, `run_queue_pid`, `run_queue_field`, `run_queue_alive`**
  are unchanged and gain call sites in `scripts/run-status.sh` only.

**C-8. Commands.**

    bash .claude/tests/run-queue.test.sh                       # the suite that judges this story
    bash scripts/attest.sh -- bash .claude/tests/run-queue.test.sh
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
    SELFTEST_JOBS=4 bash scripts/selftest.sh --changed         # before REVIEW, by dispatch

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one "defect put back"
mutation for the central claim (DV-1), and one probe against a real line of
the tree for the text pin AC-6 adds over it (DV-3). DV-2 is the story's main
control, which fails in RED only because `--all` does not exist and so has
not been seen to fail for its own reason. DV-4 is not a mutation: it is the
claim checked once outside the fixtures, where a record's `root` is a real
path. Each mutation runs through `scripts/mutate.sh` against the one suite
that holds its assertion, `bash .claude/tests/run-queue.test.sh`. None can
run before GREEN: there is no record write to remove, no liveness test to
drop and no pinned line to break.

- **DV-1, the defect put back (AC-1).** With the record never put in place,
  the `mv` into `run-queue.waiter.<pid>` in `run_queue_mark` made a no-op,
  the machine is as it is today: runs wait and nothing lists them.
  `mutate.sh` must report 1 line changed, and the suite must go red on AC-1's
  two `waiting` lines and its `2 runs are waiting` line in each of the four
  trees (the answer then says `nothing is waiting`), and on AC-2's, AC-3
  (a)'s and AC-4 (c)'s "record seen" assertions, while every HARNESS-108,
  HARNESS-111 and HARNESS-120 assertion and AC-4 (a) and (b) stay green. RED's handoff predicts the
  count. **Owner: GATES.**

- **DV-2, a file believed without a live pid (AC-3 b).** With rule 3 of C-2
  removed - the listing's own liveness test in `scripts/run-status.sh`
  replaced by `true`; GREEN keeps that test on a line of its own so one `sed`
  expression reaches it and nothing else - AC-3 (b)'s dead-pid record must be
  listed and its `nothing is waiting` assertion must go red, and AC-1 must
  stay green. `mutate.sh` must report 1 line changed. Not
  `run_queue_alive` itself in `run-queue.sh`: the queue's own stale-lock
  cases wait for ever behind a dead holder with that mutated.
  **Owner: GATES.**

- **DV-3, a real line of the tree (AC-6).** The pin reads the real
  `CLAUDE.md`. With the `bash scripts/run-status.sh --all` line of its
  "Running things" block mutated through `mutate.sh` (`--all` respelled
  `--every`), AC-6's assertion must go red, reading 0, and HARNESS-120's
  AC-6 (a) pin for the no-argument line must stay green, reading 1.
  `mutate.sh` must report 1 line changed. The reverse direction is not owed:
  120's needle is not edited (C-4 quotes it, and shows the `--all` line
  cannot match it), so no assertion of 120's is written or corrected here.
  If RED did edit that needle after all, it says why in the handoff and the
  reverse mutation - the no-argument line respelled, 120's pin red, AC-6
  green - becomes owed in GATES. **Owner: GATES.**

- **DV-4, the real tree, listed while queued (AC-1).** Not a fixture: in
  this repository, with `HARNESS_RUN_QUEUE_DIR` pointing at a scratch
  directory whose `run-queue.lock` names a live pid of the prober's own (a
  `sleep`), start `bash scripts/gates.sh` detached with the queue on, wait -
  bounded, for the `run-queue: queued:` line, not for a fixed time - and run
  `bash scripts/run-status.sh --all` with the same variable, once from this
  repository and once from another worktree of it if one exists (else say
  none did). Each must print a `waiting` line naming the `gates.sh` pid and
  this repository's root as the record holds it, and `1 run is waiting.`.
  That is rule 5 read through a real recorded root on this host, which the
  fixtures' temp paths do not show. Then remove the planted lock: the run
  must start by itself, and after it exits `--all` must end `machine queue:
  free`, `nothing is waiting`, with no `run-queue.waiter.*` left in the
  scratch directory. Paste the answers. The host's own queue under
  `$HOME/.cache` is never touched. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-121` from `.claude/harness/models.conf`.
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
- PLANNED, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-21, dispatched for `/plan-story`, while HARNESS-120 was at RED; no override was stated in the dispatch. (Restored: `plan.sh write` re-rendered this section on the re-plan and dropped the line.)
- PLANNED, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-21, dispatched by `/advance-story` to re-plan on `main` at b30f2b6 after HARNESS-120 merged; no override was stated in the dispatch. Wrote only this file.
- RED, `test-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-21; no override.
- GREEN, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-21; no override. Orchestrator checked both records with `attest.sh check`: `selftest.sh run-queue` fresh, exit 0, 898 passed 0 failed; `gates.sh --fast` fresh, exit 0. Neither re-run by hand.

## Out of scope

- **Making the queue first-come-first-served.** Waiters still get through in
  whatever order they poll (HARNESS-108 AC-2). The list shows the order runs
  began to wait and says that it is not the order they start in. Nothing
  reads the list to decide who goes next. Whether the order should become
  guaranteed is a question for the user (Notes), and would be its own story:
  it changes `run_queue_acquire`'s take, not what is displayed.
- **Cancel, priority, "jump the queue", pausing a waiter.** The list is read
  only. The one manual remedy stays the one the queued message names.
- **Changing the no-argument answer.** `bash scripts/run-status.sh` prints
  what HARNESS-120 made it print, byte for byte; it does not gain a
  "and 2 others are waiting" line or a pointer to `--all`.
- **Asking about another tree by path.** Still no `--tree` or `--root`. The
  list names every waiting tree's root; for that tree's full state, run its
  own copy.
- **Marking the asker's own line**, or printing a position ("2nd of 3").
  There is no order of service to have a position in.
- **Listing runs that do not wait**: the holder beyond the queue line it
  already has, `--fast`, `--gate`, a named suite, `HARNESS_RUN_QUEUE=off`, a
  run that could not use the queue directory. Runs in progress beside the
  holder are not discoverable from here and are not looked for.
- **Trees on an older release.** One between 127 and this release waits
  without a record and is not listed; one older than 127 does not queue.
  The remedy is a refresh. Nothing detects another tree's release, and
  nothing infers an unlisted waiter from process tables.
- **Cleaning up from the reader.** `--all` never removes a dead record; the
  next waiter's sweep does. No separate "prune" command.
- **Spanning pid namespaces or users.** One user, one MSYS runtime or one
  Linux pid namespace, as the queue itself.
- **More prose.** One line in `CLAUDE.md`'s command block. `/advance-story`,
  `/complete-story`, `feature-developer.md`, `lead-po.md`, `rules.md`, the
  skills, `.claude/state/README.md` and `.claude/settings.json` are not
  edited; neither are `scripts/run-lock.sh`, `scripts/gates.sh`,
  `scripts/selftest.sh`, `scripts/attest.sh` or `scripts/phase.sh`.
- **A structured (JSON, TSV) output.** The lines are for a person or an
  agent to read; nothing parses them.
- **The three things HARNESS-120 left open on these lines.** Weighed on
  2026-11-21 because this story edits the same two files; none is taken.
  (1) *`run-status.sh` reads the queue lock once for the pid and again for
  `started`, `root` and `command`* (120's diff review, round 1, finding 3):
  a holder change between the reads gives one mixed line, which corrects
  itself on the next ask. Fixing it rewrites how the no-argument lines are
  produced, which this story promises not to change and has no criterion to
  demand. The list is not exposed to it: rule 4 uses the pid read once.
  (2) *A queue lock that is not a regular file is described as one the next
  run reclaims* (finding 4): it is not reclaimed, runs go on without the
  queue. Saying so needs a new queue line, which is a change to the
  no-argument answer. AC-4 (c) meets that state and reads out the line as it
  is. (3) *The `run_queue_unmark` at `scripts/run-queue.sh:284`*, the exit
  for a stale lock that cannot be removed, is pinned by no assertion.
  Because the record is removed inside `run_queue_unmark`, this story adds
  no call there and no new unpinned line; but deleting that one call would
  now leave a record as well as a marker, and a run listed as waiting while
  it works. Pinning it needs the suite's fake-`rm` shim (`RQ_PATH`) and one
  more earning mutation, for a call HARNESS-120 wrote. It is one follow-up
  story with (2), covering the marker and the record together.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

One level: integration, in `.claude/tests/run-queue.test.sh`, a new block
headed `HARNESS-121` after HARNESS-120's, before `summary`. Real
`scripts/gates.sh` / `scripts/selftest.sh` runs in the suite's fixture trees
(A, B, C; D is the `--changed` tree Z, where nothing runs) for every case
that is about a run waiting, and records planted by hand for the belief
rules, exactly as HARNESS-120's block does for `run.queued`. Every answer is
compared whole, line by line, against C-2's text through 120's `rs_expect`
(bound, exit 0, empty stderr, line count, each line); every record-absent
assertion carries the same case's sighting of that record in one value
(`seen absent`), and every "left alone" assertion carries the evidence that
the reader answered or the sweep ran (`answered same`, `seen same`). No
timing: C starts only after B's record is seen and the UTC second has moved
past B's `since`, both bounded waits on the condition.

| Case (describe line) | Asserts | AC |
|---|---|---|
| `HARNESS-121 AC-1 ...` preconditions | A holds; B then C queued; B's since < C's; run.locks and the queue lock name the right pids | AC-1 |
| `HARNESS-121 C-1: ...` (5) | B's record is seen while B waits; its keys are `pid since command root`; pid is B's `$$`; since equals B's `run.queued` since; command and root are `scripts/gates.sh` and B's root | AC-1, C-1 |
| `HARNESS-121 AC-1 --all in A / B / C / D` | the whole answer: that tree's no-argument lines, then B's and C's `waiting` lines, `2 runs are waiting ...`, `predates` | AC-1 |
| `... the since on B's waiting line is the since on B's own no-argument queued line` | read out of the two answers, not derived | AC-1 |
| `... neither B's nor C's work has started after all four answers` | `absent absent alive` | AC-1 |
| `HARNESS-121 AC-2 --all in D, one waiter through` | `held by` the one that started, the other's `waiting` line, `1 run is waiting.`, `predates` | AC-2 |
| `AC-2: ... no record for the one that started` / `... no record at all` | `seen absent`; `seen seen none` | AC-2 |
| `HARNESS-121 AC-2 --all in D / in B after all three ended` | idle, `free`, `nothing is waiting`, `predates` | AC-2 |
| `HARNESS-121 AC-3 (a) gates.sh waiter` / `selftest.sh waiter` | listed while it waits (whole answer); `seen 143 absent` after TERM; whole answer afterwards says nothing is waiting | AC-3 (a) |
| `HARNESS-121 AC-3 (b) rule 3 / rule 5 (x2) / rule 4 / rule 2 (x2) / rule 1` | each planted record alone in the planted world: whole answer ends `nothing is waiting`, `predates` | AC-3 (b) |
| `HARNESS-121 AC-3 (b) all seven together` | the same, with all seven at once | AC-3 (b) |
| `HARNESS-121 C-2 the control record alone is listed` / `the seven and the control` | the record that passes all five rules is listed, alone and among the seven: the control for the controls | AC-3 (b), C-2 |
| `HARNESS-121 C-2 two waiters, the larger pid earlier` / `in the same second` | since order, not pid order; ties by ascending numeric pid | C-2 (AC-1's order) |
| `HARNESS-121 AC-3 (c): ...` (7) | after a new waiter's record is seen: dead record, dead `.tmp` and a non-digit name gone; a live record and a live pid's `.tmp` byte for byte; B's `run-queue:` lines are only q1/q2/q3/heartbeat | AC-3 (c), C-1 sweep |
| `HARNESS-121 AC-4 (a) --fast` / `(b) queue off` beside the holder | whole answer: `running` for B, `held by` A, `nothing is waiting`, `predates`; and at that moment `<count line>|none` for the queue directory's records | AC-4 (a), (b) |
| `HARNESS-121 AC-4 (c) ...` | R-1's construction; B's record `seen absent` once it goes on; whole `--all` answer = the no-argument lines read out, `nothing is waiting`, `predates` | AC-4 (c) |
| `HARNESS-121 AC-5 --all with a held queue, two live waiters and a dead record` | whole answer, then `answered same` for the queue directory, `answered same` for four trees' `.claude/state`, `answered present` for the dead record | AC-5 |
| `HARNESS-121 AC-5 --all with an absent queue directory` | whole answer ends `free`, `nothing`, `predates`; directory still absent | AC-5 |
| `HARNESS-121 AC-5 --all with neither ...` | exactly two lines, the last `cannot be located`; exit 0 | AC-5 |
| `HARNESS-121 AC-5 --all twice / --all and a tree path / a tree path and --all / --ALL / --all= / all, without dashes` | `usage_case`: exit 2, the new usage line on stderr, nothing on stdout | AC-5 |
| `HARNESS-120 AC-5 an argument (--help) / (a tree path) / an empty argument` | the same helper, its one expected string changed at line 1570 | AC-5, C-2 |
| `HARNESS-121 AC-6: ...` (2) | one fence line beginning `bash scripts/run-status.sh --all` then spaces and `# x`; that line and 120's are two different lines | AC-6 |

Out of scope pinned cheaply: "the reader never cleans up" (AC-5's dead
record still there), "no `run-queue:` line changes" (AC-3 c), "the
no-argument answer does not change" (every HARNESS-120 assertion untouched,
and AC-4 (c) reads its first two lines out of the no-argument answer).

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

Written by the test-developer, RED, 2026-11-22, in `D:\adh-HARNESS-121`.
Planned `opus`; this dispatch resolved to Opus 5.5 (`claude-opus-5-5`), with
no override stated in the dispatch.

### Commands

    bash .claude/tests/run-queue.test.sh                       # the suite; ~6-11 min locally
    bash scripts/attest.sh -- bash scripts/selftest.sh run-queue
    bash scripts/attest.sh -- bash scripts/gates.sh --fast

### The runs this handoff describes (attest records, final tree)

    run:      2026-11-22T00:50:02Z
    command:  bash scripts/selftest.sh run-queue
    tree:     08bd0e90d92e7bb7c2c37549e6c656f32548f595
    exit:     1
    duration: 361s
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261122T005002Z.3372879.log

    run:      2026-11-22T00:56:21Z
    command:  bash scripts/gates.sh --fast
    tree:     08bd0e90d92e7bb7c2c37549e6c656f32548f595
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261122T005621Z.3391589.log

Counts: before (this tree's `main`, the suite unedited, local) `run-queue:
583 passed, 0 failed`; after `run-queue: 640 passed, 258 failed` = **898
executed**, measured twice (00:27 and 00:50 runs, identical). The new
floor is 898 (`floors.conf:63`, mirror `selftest.test.sh:554`), so the
floor audit says `0 of 1 suite(s) met their declared floor` in RED, as
expected. `gates.sh --fast` is green because every gate is unconfigured
here; it says nothing about this suite. GREEN must see `run-queue: 898
passed, 0 failed`; if the executed count differs, this handoff was wrong -
report it rather than moving the floor.

Of the 258 failures, exactly **3 are pre-existing assertions**: HARNESS-120's
three `usage_case` stderr assertions, red on their own needle (old string
`usage: bash scripts/run-status.sh` against the new `... [--all]`). Every
other HARNESS-108 / 111 / 112 / 120 assertion passed. The other 255 are new.

### Verbatim failure (excerpt from the 00:50 log; full list in the log)

```
    FAIL HARNESS-120 AC-5 an argument (--help): prints exactly the usage line on stderr
         expected: usage: bash scripts/run-status.sh [--all]
         actual:   usage: bash scripts/run-status.sh
    FAIL HARNESS-121 C-1: while B waits, the queue directory holds run-queue.waiter.<B's pid>
         expected: seen
         actual:   never-written
    FAIL HARNESS-121 AC-1 --all in D (nothing runs there): exits 0
         expected: 0
         actual:   2
    FAIL HARNESS-121 AC-1 --all in D (nothing runs there): prints nothing on stderr
         expected: 
         actual:   usage: bash scripts/run-status.sh
    FAIL HARNESS-121 AC-1 --all in D (nothing runs there): stdout line 3
         expected: run-status: waiting: pid 3384374, since 2026-11-22T00:53:34Z, in /tmp/tmp.JuUpBRTfJb: scripts/gates.sh
         actual:   
    FAIL HARNESS-121 AC-1 --all in D (nothing runs there): stdout line 5
         expected: run-status: 2 runs are waiting, listed in the order they began to wait. Whichever polls first after the holder ends starts next; that need not be the first listed.
         actual:   
    FAIL HARNESS-121 AC-3 (b) rule 3: a record whose pid is not running: stdout line 3
         expected: run-status: nothing is waiting in the machine queue.
         actual:   
    FAIL HARNESS-121 AC-3 (c): the new waiter wrote its record, and the dead pid's record is gone
         expected: seen absent
         actual:   never-written present
    FAIL HARNESS-121 AC-4 (a) gates.sh --fast beside the holder: at that moment the count line says nothing is waiting, and the queue directory holds no record (A's or B's)
         expected: run-status: nothing is waiting in the machine queue.|none
         actual:   |none
    FAIL HARNESS-121 AC-4 (c): B's record, seen while it waited, is gone once it goes on without the queue
         expected: seen absent
         actual:   never-written absent
    FAIL HARNESS-121 AC-5: it answered, and the queue directory holds exactly the files, byte for byte, it held before
         expected: answered same
         actual:   not-answered same
    FAIL HARNESS-121 AC-5 --all twice: prints exactly the usage line on stderr
         expected: usage: bash scripts/run-status.sh [--all]
         actual:   usage: bash scripts/run-status.sh
    FAIL HARNESS-121 AC-6: the Running things command block has one line beginning bash scripts/run-status.sh --all, then a # comment
         expected: 1
         actual:   0
    FAIL HARNESS-121 AC-6: it and HARNESS-120's no-argument line are two different lines of that block
         expected: 2
         actual:   1

run-queue: 640 passed, 258 failed
assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

**Why it is the right failure, and where it is only the usage error.**
Two kinds of red. (1) *On their own needle*: the 5 C-1 record assertions,
every `seen absent` / `seen same` / `answered same` assertion (nothing writes
a record, so `never-written`; `--all` does not answer, so `not-answered`),
the 9 usage-line assertions (the old string), and AC-6's two (no `--all`
line in `CLAUDE.md`). (2) *Only because `--all` is a usage error today*:
every `rs_expect` assertion about an `--all` answer - `exits 0` (actual 2),
`prints nothing on stderr` (actual the usage line), the line count (actual
0) and each `stdout line N` (actual empty). Their **expected** values are
C-2's lines, built by the suite's helpers (`s_wait`, `S_NONE`, `S_ONE`,
`s_many`, `S_PRED`, with 120's `s_idle`, `s_held`, `s_run`, `s_q1..3`,
`s_free`, `s_unread`, `S_NOHOME`); the log prints each expected line in
full. GREEN confirms the measured answer equals them. The mutation run below
(the arg test disabled, so `--all` falls through to the no-argument answer)
measured `743 passed, 155 failed`: with `--all` answering, every line-1/2
and exit/stderr assertion goes green and the list lines are what is left,
which is the split C-2 predicts.

Single-suite checks on the final tree, local: `bash scripts/selftest.sh
selftest sigpipe` - `sigpipe: 91 passed, 0 failed`, `assertion floors: all
2 suite(s) met their declared floor (457 assertions executed, 457
declared)`, `2 harness suite(s) passed` (the `selftest` suite checks the
COUNTS mirror against `floors.conf`); `bash scripts/check-sigpipe.sh` - `0
finding(s)`; `bash scripts/check-grep-count.sh` - `0 finding(s)`. The full
self-test and full gates were not run (out of this dispatch).

### Files touched

- `.claude/tests/run-queue.test.sh` - the HARNESS-121 block (end of file,
  before `summary`); one changed line in HARNESS-120's `usage_case` (line
  1570: expected `usage: bash scripts/run-status.sh [--all]`). No other
  existing line changed.
- `.claude/tests/floors.conf` - `run-queue` 583 -> 898 (line 63), dated
  comment after HARNESS-120's last entry.
- `.claude/tests/selftest.test.sh` - the mirror, line 554, `run-queue 898`.
- this story: `## Test plan`, this section.

### What the tests pin (the export shape - stated as fact)

No module is imported; the surface is the command line, one file format and
the text. GREEN must produce exactly:

- **`bash scripts/run-status.sh --all`** - exit 0, stdout only, nothing on
  stderr. The no-argument lines first, unchanged, then one line per believed
  record, `run-status: waiting: pid <P>, since <S>, in <R>: <C>`, then the
  count line (C-2's three, verbatim), then
  `run-status: a run in a tree whose harness predates this list waits without appearing in it.`
  With the queue `cannot be located`, exactly the two no-argument lines.
- **Any other argument list** - `usage: bash scripts/run-status.sh [--all]`
  on stderr, nothing on stdout, exit 2. Cases: `--help`, a path, `""`,
  `--all --all`, `--all <path>`, `<path> --all`, `--ALL`, `--all=`, `all`.
- **The record** `<queue dir>/run-queue.waiter.<$$>`: exactly four
  TAB-separated lines in the order `pid since command root`; `pid` the
  waiting script's `$$` (the pid `rq_run` gets through `exec`); `since`
  **equal to the `since` of `run.queued`** (the suite compares the two:
  one `date` call); `command` `scripts/gates.sh` (the self string); `root`
  the tree root as `run_queue_acquire` gets it (the suite compares with the
  fixture's `cd && pwd` path, which is what 120's lines already show).
  Written by a run that waits, seen within 5 s of its `queued:` line;
  absent once it takes the queue, goes on without it (line 245), or is
  TERM'd.
- **Order**: ascending `since`; equal `since` in ascending numeric pid.
  Pinned by two planted cases where since order is not pid order.
- **Belief**: C-2's five rules. Each planted record of AC-3 (b) (see the
  table below) must be excluded; the control record, and the control among
  all seven, must be listed. Rule 4 is exercised with the queue lock
  recording a live pid and that pid's root holding a `run.lock` for it.
- **The sweep**, when a waiter writes its record: removes
  `run-queue.waiter.<dead>`, `run-queue.waiter.<dead>.tmp` and
  `run-queue.waiter.abc`; leaves `run-queue.waiter.<live>` and
  `run-queue.waiter.<live>.tmp` byte for byte. The waiter prints nothing
  about it: its `run-queue:` lines are only q1, q2, q3 and heartbeats.
- **The reader** writes, creates and removes nothing: the queue directory and
  four trees' `.claude/state` (recursively, `gate-logs/` included) compared
  byte for byte, a dead record left in place, an absent queue directory left
  absent.
- **`CLAUDE.md`**: in the first fence of `## Running things`, exactly one
  line that begins `bash scripts/run-status.sh --all` and continues
  ` +# [^ ]` (spaces, `#`, a space, a non-space); 120's line stays the only
  one matching its own pin; the two are different lines.

**Not constrained** (GREEN's choice): the record-tracking variable's name;
how the reader sorts (awk, `sort`); where in `run-status.sh` the list code
sits, as long as DV-2's liveness test is on a line of its own; whether the
reader judges rules 3-5 by `P` or by the name's digits (see the finding
below); the header prose of both scripts; whether `run_queue_mark` sweeps
before or after the marker's write (the tests only see the end state once
the record is present).

### Passed on arrival (60 new assertions), and what earns them

| Group | n | Earned by |
|---|---|---|
| preconditions (holders held, waiters queued, since order, pids, A/B/C finished, cannot-use line, no-argument answer in AC-4 c) | 18 | preconditions, not claims; each guards the case it opens |
| `rs_expect`'s "answers within the bound: it never waits" for each `--all` ask | 29 | **not earned in RED**: passes because a usage error exits at once. Same helper HARNESS-120 earned for the no-argument form; a mutation that makes `--all` sleep is `/audit-mutations`' work, not this story's budget |
| the six new `usage_case`s' `exits 2` and `and nothing on stdout` | 12 | **earned in RED**, below: one mutation, red on all 12 (and 120's 6) |
| AC-1 "neither B's nor C's work has started after all four answers" | 1 | HARNESS-108's invariant (a waiter does not start while A holds), earned by 108's own DVs; a regression guard here |

The earning run (RED, against HARNESS-120's script - the rejection these 12
pin already exists there):

```
=== mutate: scripts/run-status.sh (1 line(s) changed by s/if \[ "\$#" -gt 0 \]; then/if [ "$#" -gt 9 ]; then/) ===
  37 - if [ "$#" -gt 0 ]; then
  37 + if [ "$#" -gt 9 ]; then
=== mutate: running bash .claude/tests/run-queue.test.sh ===
    FAIL HARNESS-120 AC-5 an argument (--help): exits 2
         expected: 2
         actual:   0
    FAIL HARNESS-120 AC-5 an argument (--help): and nothing on stdout
         expected: 
         actual:   run-status: idle: no harness run holds /tmp/tmp.yo2q3FRWib.
    FAIL HARNESS-121 AC-5 --all twice: exits 2
         expected: 2
         actual:   0
    FAIL HARNESS-121 AC-5 --all twice: and nothing on stdout
         expected: 
         actual:   run-status: idle: no harness run holds /tmp/tmp.yo2q3FRWib.
    FAIL HARNESS-121 AC-5 --all and a tree path: exits 2
    FAIL HARNESS-121 AC-5 a tree path and --all: exits 2
    FAIL HARNESS-121 AC-5 --ALL: exits 2
    FAIL HARNESS-121 AC-5 --all=: exits 2
    FAIL HARNESS-121 AC-5 all, without dashes: exits 2
         (each with its `and nothing on stdout` likewise: 18 of 18 exit/stdout assertions red)
run-queue: 743 passed, 155 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-121/.claude/state/mutations/scripts_run-status.sh.20261122T004011Z.3353646.bak) ===
  37: if [ "$#" -gt 0 ]; then
```

(Abridged from the scratch log of that run: the `FAIL` lines are verbatim,
the parenthesised line is mine; `grep -c` over that log counted 18 matching
`exits 2|and nothing on stdout` failures. `mutate.sh --check` afterwards:
`no stranded mutation`.)

### Owed: earning the one changed assertion (GREEN, after the usage line exists)

`usage_case`'s stderr assertion (line 1570) is a test changed against code
that already exists. In RED it is red on its own needle - confirmed in the
00:50 log: `expected: usage: bash scripts/run-status.sh [--all]`, `actual:
usage: bash scripts/run-status.sh`, for all three of 120's cases. Once GREEN
prints the new line it goes green, and that alone does not earn it. GREEN
runs, adjusting the expression to the printf it wrote:

    bash scripts/mutate.sh scripts/run-status.sh 's/usage: bash scripts\/run-status.sh \[--all\]/usage: bash scripts\/run-status.sh/' -- bash .claude/tests/run-queue.test.sh

Predicted: `1 line(s) changed`; exactly the **9** `prints exactly the usage
line on stderr` assertions red (120's 3, 121's 6), every other assertion as
in GREEN.

**Run in GREEN, 2026-11-22, by the feature-developer (resolved Opus 5.5,
`claude-opus-5-5`, no override).** The expression above needed no
adjusting. Result as predicted: 1 line changed, exactly the 9 usage-line
assertions red, `889 passed, 9 failed`, restored and verified; `mutate.sh
--check` afterwards: `no stranded mutation`. Output (the `expected/actual`
pair, identical for all nine, shown once):

```
=== mutate: scripts/run-status.sh (1 line(s) changed by s/usage: bash scripts\/run-status.sh \[--all\]/usage: bash scripts\/run-status.sh/) ===
  61 -   printf 'usage: bash scripts/run-status.sh [--all]\n' >&2
  61 +   printf 'usage: bash scripts/run-status.sh\n' >&2
=== mutate: running bash .claude/tests/run-queue.test.sh ===
    FAIL HARNESS-120 AC-5 an argument (--help): prints exactly the usage line on stderr
         expected: usage: bash scripts/run-status.sh [--all]
         actual:   usage: bash scripts/run-status.sh
    FAIL HARNESS-120 AC-5 an argument (a tree path): prints exactly the usage line on stderr
    FAIL HARNESS-120 AC-5 an empty argument: prints exactly the usage line on stderr
    FAIL HARNESS-121 AC-5 --all twice: prints exactly the usage line on stderr
    FAIL HARNESS-121 AC-5 --all and a tree path: prints exactly the usage line on stderr
    FAIL HARNESS-121 AC-5 a tree path and --all: prints exactly the usage line on stderr
    FAIL HARNESS-121 AC-5 --ALL: prints exactly the usage line on stderr
    FAIL HARNESS-121 AC-5 --all=: prints exactly the usage line on stderr
    FAIL HARNESS-121 AC-5 all, without dashes: prints exactly the usage line on stderr
run-queue: 889 passed, 9 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-121/.claude/state/mutations/scripts_run-status.sh.20261122T045038Z.3458421.bak) ===
  61:   printf 'usage: bash scripts/run-status.sh [--all]\n' >&2
```

### GREEN: the suite, and the controls measured (feature-developer, 2026-11-22)

Suite on the GREEN tree: `run-queue: 898 passed, 0 failed`, floor met (898
executed, 898 declared): the executed count RED predicted, unchanged.

    run:      2026-11-22T04:45:04Z
    command:  bash scripts/selftest.sh run-queue
    tree:     5c87681f7cea5475bf28f2f2936fa9576db9fc0c
    exit:     0
    duration: 283s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261122T044504Z.3441842.log

The controls, measured twice: by the suite (every whole-line comparison
green), and once outside it, by a scratch script that rebuilt AC-3 (b)'s
planted world (eight `sleep 300` pids, a reaped dead pid, the same roots and
`run.lock` plantings) and asked the shipped `run-status.sh --all`, and that
called the shipped `run_queue_mark` / `run_queue_unmark` over AC-3 (c)'s
plantings. Every one matched RED's expected value; no divergence.

| Control | Expected | Measured (scratch) |
|---|---|---|
| each of the seven bad records alone | 4 lines, 0 `waiting`, `nothing is waiting` | 4 lines, 0 `waiting`, `nothing is waiting`, for all seven |
| all seven together | same | same |
| the control record alone | 5 lines, its `waiting` line, `1 run is waiting.` | 5 lines, `run-status: waiting: pid <WL3>, since 2026-01-02T03:06:07Z, in <S>/wr/2: scripts/gates.sh ctl`, `1 run is waiting.` |
| the seven + the control | the control's line only, `1 run is waiting.` | 5 lines, 1 `waiting`, `1 run is waiting.` |
| AC-3 (c) sweep | dead, dead `.tmp`, `abc` removed; live record and live `.tmp` byte for byte | after `run_queue_mark`: `run-queue.lock`, the live record, the live `.tmp`, its own record; `cmp` same for both live files; after `run_queue_unmark` its own record gone |
| AC-4 (a)/(b)/(c), AC-5 | as tabled above | suite only (green); not rebuilt outside it |

Design notes for GATES: the record's `.tmp` is removed by
`run_queue_unmark` whenever the run resolved a queue directory in
`run_queue_mark`, whether or not the `mv -f` happened, so DV-1's no-op `mv`
leaves no `.tmp` behind (the caveat above does not arise). DV-2's target is
the line `  run_queue_alive "$WP" || continue                       # rule 3`
in `scripts/run-status.sh`; `run_queue_alive "$WP"` occurs on no other line.
`.claude/harness/VERSION` reads `140 (2026-11-21)`, the local calendar date
of GREEN; C-6 asks for the date of the GATES commit, so GATES corrects it if
that differs.

### Negative controls - expected values (claims until GREEN measures them)

No `--all` answer has been produced, so the reader-side controls are
unverified. What was measured outside the suite: a candidate of C-2's five
rules run over this exact planted world (scratch script, `sleep 300` pids,
same plantings), reporting which rules each record fails.

| Control | Fails rule (designed) | Measured by the candidate | Expected answer (all whole lines) |
|---|---|---|---|
| dead pid, its root's run.lock records it | 3 | `dead fails rules: 3` | idle D, held WL1, `nothing is waiting`, `predates` |
| live WL2, root's run.lock records WL3 | 5 | `notlock fails rules: 5` | same |
| live WL4, root has no run.lock | 5 | `nolock fails rules: 5` | same |
| the holder's pid WL1, its root's run.lock records WL1 | 4 | `holder fails rules: 4` | same |
| name WL5, pid `not-a-pid`, root's run.lock records WL5 | 2 | `nopid fails rules: 2 3 5` (by P) - see finding | same |
| name WL6, pid WL7 (live, recorded by its root) | 2 | `differ fails rules: 2` | same |
| `WL8.tmp`, pid WL8 recorded by its root | 1 | rule 1 only, judging `<n>` by the digits before `.tmp` | same |
| all seven together | - | - | same |
| control: WL3, root WR/2 (whose run.lock records WL3) | none | `ctl fails rules: none` | idle D, held WL1, `waiting: pid WL3 ... scripts/gates.sh ctl`, `1 run is waiting.`, `predates` |
| the seven + the control | - | - | the control's line only, `1 run is waiting.` |
| AC-3 (c) sweep | - | not measurable in RED (nothing sweeps) | `seen absent` x3, `seen same` x2, `seen 1 0` |
| AC-4 (a) `--fast`, (b) queue off beside A | - | not measurable (no `--all`) | whole answer `running` B, held A, `nothing is waiting`, `predates`; `<nothing line>|none` |
| AC-4 (c) waiter going on without the queue | - | not measurable (no record) | `seen absent`; the no-argument lines, `nothing is waiting`, `predates` |
| AC-5 two live waiters + a dead record | - | not measurable | 6 lines, `2 runs are waiting`; `answered same` x2; `answered present` |

### Finding: one planted record cannot fail exactly one rule (C-2 "one rule per planted record")

Measured, not argued: **the record with no numeric pid fails rules 2, 3 and
5 when the rules are read on `P`**, as C-2 states rules 3 and 5. A
non-numeric `P` is never alive under `kill -0` and never equals a numeric
`run.lock` pid, so no planting can make it fail rule 2 alone under that
reading. The suite plants it so that read by the file name's digits it
passes rules 1, 3, 4 and 5 (name WL5 alive, not the holder, its root's
`run.lock` recording WL5), the most any planting can do; rule 2 is isolated
under every reading by the name/pid-differ record. The Contract's "fails
exactly one" sentence is therefore not satisfiable for that one record. I
did not amend the Contract (this dispatch limited my story writes to
`## Test plan` and this section); the orchestrator should decide whether
C-2 gets a sentence saying so. No acceptance criterion is affected: AC-3 (b)
only requires that none of the seven is listed.

### Mutation table for GATES (DV-1, DV-2) - predicted catches

| DV | Mutation | Predicted red | Predicted to stay green |
|---|---|---|---|
| DV-1 | the `mv -f` into `run-queue.waiter.<pid>` in `run_queue_mark` made a no-op | **49**: C-1 record 5; AC-1 `--all` in A, B, C, D 5 each (line count, both `waiting` lines, the `2 runs` line, the shifted `predates` line) = 20; AC-1 since-equality 1; AC-2 one-through answer 4 + `seen absent` 1 + `seen seen none` 1; AC-3 (a) 2 x (answer while waiting 4 + `seen 143 absent` 1) = 10; AC-3 (c) 6 (all gated on the record being seen); AC-4 (c) `seen absent` 1 | every HARNESS-108/111/112/120 assertion; AC-3 (b), C-2 order, AC-4 (a)/(b), AC-5, AC-6 |
| DV-2 | the reader's own liveness test (rule 3) replaced by `true` | **18** (17 if WL3 < DEAD numerically): rule-3 case 3 (line count, line 3, line 4); all-seven 3; seven + control 4 (or 3: only if the tie puts WL3 first); AC-5 5 answer lines + 3 `answered` = 8 | AC-1, AC-2, AC-3 (a), the other six single-record cases, the control alone, order, AC-3 (c), AC-4, every 120 assertion |

DV-1 caveat: the prediction assumes the `.tmp` the no-op leaves behind is
removed by `run_queue_unmark` ("the `.tmp` goes with it", C-1). If GREEN
removes the `.tmp` only when the record was moved into place, the leftover
`.tmp` would also redden the older cases' `the queue directory holds
nothing` `qsnap` assertions (HARNESS-108/111), and DV-1 would then fail its
own "every HARNESS-108 ... stays green" condition for a reason that is
GREEN's design, not the suite's.

### Deferred verifications

RED cannot run DV-1, DV-2, DV-3 or DV-4: each mutates or exercises code that
does not exist yet (the record write, the reader's liveness test, the
`--all` line in `CLAUDE.md`, a real `--all`). Owner: GATES, as the story
says. Not performed, not claimed.

### C-7 caller greps, re-run on this tree

I re-ran C-7's greps (`grep -rn` over `*.sh`, `*.md`, `*.json`, `*.conf`,
story files left out) for `run-status.sh` and for
`run_queue_(mark|unmark|acquire|release)` on this worktree (HEAD c24dd7c,
plus this RED diff). The lists hold as C-7 states them: the only caller
passing an argument is the suite (`rs_ask`, `RS`, `ASK_SCRIPT`,
`usage_case`, whose line 1570 is the one changed); prose mentions at
`CLAUDE.md:167`, `advance-story.md:5,220,222,226`, `complete-story.md:5`,
`feature-developer.md:106-107`, `.claude/state/README.md:24,153`,
`gates.sh:281`, `selftest.sh:430`, `run-queue.sh:59,73-74,113`,
`floors.conf:1337`; `run_queue_mark` called once (`run-queue.sh:258`),
`run_queue_unmark` four times (239, 245, 284, 296), `run_queue_acquire` from
`run-lock.sh:141`, `run_queue_release` from `run-lock.sh:214`. Nothing
differed, apart from the suite's own new lines (my block) and the line
numbers of 120's AC-6 pins, which now sit at the same 1611-1631 (my block is
appended after them).

### What GREEN must know

- **D is the `--changed` tree Z** (`D="$Z"`). Nothing runs in it; it answers
  `idle`.
- **The suite never reads the record before seeing its own `queued:` line**,
  and waits at most 5 s for the record after it: write it before the
  `queued:` printf, inside `run_queue_mark` (line 258), as C-1 says.
- **`since` must be one `date` call** shared by marker and record; the suite
  compares them for equality, and AC-1's `since` equality reads B's
  no-argument `queued` line against the `waiting` line.
- **A live pid's `.tmp` is never swept** (AC-3 c asserts it byte for byte):
  the sweep judges `<n>` with the `.tmp` stripped.
- **The reader must not `cat` directories or emit anything on stderr**: every
  `--all` answer asserts an empty stderr.
- **AC-4 (c) reaches line 245**: the record must go in `run_queue_unmark`
  even when `RUN_QUEUE_MARK` is empty (C-1's last removal bullet).
- **The AC-5 state snapshot is recursive** (`find -type f`) because the
  trees' `.claude/state/gate-logs/` is a directory; HARNESS-120's own
  `snapdir` cats it and prints `cat: ...gate-logs: Is a directory` twice per
  run (pre-existing, in the baseline log too; not touched here).
- **Timings** (local, Windows host, other `gates.sh --fast` runs present):
  the suite ran 4m11s before this story's block, 11m18s (678 s) and 6m01s
  (361 s) after, in RED. No new bound was introduced: every new wait reuses
  the suite's existing ones (60 s for a run to queue or start, 5 s for a
  record or a marker, 5 s for the UTC second to change, 20 s per answer,
  10 s after TERM). None was measured on CI.

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

- **Planned 2026-11-21, while HARNESS-120 was at RED** in `D:\adh-HARNESS-120`,
  against 120's Contract as written there (C-1 marker, C-2 lines, C-7 floor).
  The id was checked free on origin/main, the backlog, local and remote
  branches and PR titles that day by the dispatcher, and against the backlog
  and branches again by the planner. Not committed, no branch cut.
- **Decisions the planner took, each with a criterion that can fail.**
  (1) The list lives beside the lock, one record per waiter named by pid,
  moved into place whole (C-1); (2) a record is believed only for a live pid
  that holds its tree's run lock and is not the holder (C-2, AC-3 b);
  (3) it is reached as `run-status.sh --all`, and the no-argument answer is
  untouched (AC-5, 120's assertions); (4) the order shown is the order runs
  began to wait, labelled as not the order of service (AC-1); (5) dead
  records are swept by the next waiter, never by the reader (AC-3 c, AC-5).
- **Questions for the user, put in the planner's report, not answered here.**
  (a) Should waiters start in the order they arrived? Not absorbed: Out of
  scope. (b) `--all` as a flag, rather than the list appearing in every
  `run-status.sh` answer. (c) The always-printed last line about trees whose
  harness predates the list. If the user answers (b) or (c) differently
  before RED, the criteria change here in PLANNED, with no amendment owed.
- **The three questions, settled 2026-11-21 by the user going ahead.** The
  user was told that with no answer the story would go ahead on the
  planner's assumptions, and then ran `/advance-story HARNESS-121` without
  answering. Recorded as their decision on that basis, not as words they
  wrote: (1) no guaranteed start order - the list shows arrival order and
  says start order may differ; (2) `--all` is a flag, and the no-argument
  output stays unchanged; (3) the always-printed last line about older trees
  stays. The criteria already said all three; none changed for this.
- **Re-planned 2026-11-21 on `main` at b30f2b6, after HARNESS-120 merged**
  (PR #210, release 139), by a fresh `lead-po` dispatch on the PLANNED row.
  What moved, each with its reason in the Contract's "Confirmed on `main`"
  block: the record is written in `run_queue_mark` and removed in
  `run_queue_unmark` (four removal sites on `main`, not the two this plan
  knew); AC-4 gained (c), still in PLANNED so no amendment is owed; the
  floor baseline is 583; 120's AC-6 (a) needle was read and does not collide,
  so DV-3 lost its conditional half; C-7 carries the grepped callers.
  120's three open follow-ups were weighed and left out (Out of scope).
- **Gates.** `bash scripts/gates.sh --list` shows every gate
  `<unconfigured>`, so none can fail on this story and `required_gates: []`
  stands. The judge is the `run-queue` suite under its floor of 583 and up.
- **Not checked by this plan:** no code was run. The claim that a waiter
  leaving by line 245 would be listed is read from the belief rules, not
  reproduced; AC-4 (c) is what tests it.

