---
id: HARNESS-121
title: One command lists every run waiting in the machine queue
slug: one-command-lists-every-run-waiting-in-t
epic: 
type: feature
status: todo
phase: PLANNED
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

