---
id: HARNESS-076
title: Host-load reads a day-old Git Bash run
slug: host-load-reads-a-day-old-git-bash-run
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-076-host-load-reads-a-day-old-git-bash-run
depends_on: [HARNESS-074]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/host-load.sh, .claude/tests/host-load.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

HARNESS-074 made `scripts/selftest.sh` warn when other harness test runs share
the host, by reading `ps -ef` in `scripts/host-load.sh`. Its diff review
(finding 2, 2026-10-26) noticed that `host_load_others` takes the command from
the header's field number: if Git Bash prints STIME as two words for a process
over a day old, every field after it shifts by one, the day number is read as
the command's first word, the interpreter rule fails on it, and the row is
never reported. The row that case describes is exactly the orphaned run
HARNESS-074's Context names as the thing the warning exists to catch. The user
chose to take findings 1 and 3 in 074 and file this one on main.

**The premise was unconfirmed when filed, and is confirmed now - from the
source, not from a live row.** The `ps` Git for Windows ships on this host
reports `ps (cygwin) 3.6.10`; its source is `winsup/utils/ps.cc` in
msys2-runtime (branch `msys2-3.6.11`, fetched 2026-10-26 during planning, same
function as upstream Cygwin). `start_time()` is:

    strncpy (stime, ctime (&st) + 4, 15);   /* "Oct 26 14:51:03" */
    if ((t - st) < (24 * 3600))
      return (stime + 7);                    /* "14:51:03"        */
    stime[6] = '\0';
    return stime;                            /* "Oct 26"          */

So a process started less than 24 hours ago prints `HH:MM:SS`, one word; one
started 24 hours or more ago prints `Mon DD` - two words, and because `ctime`
pads a single-digit day with a space, `Oct  5` for the 5th, still two words
after a whitespace split. Two more facts from the same file bear on the fix:

- The `-f` row format is `ffmt = "%8.8s%8d%8d%4s%10s %s"`: STIME is
  right-aligned in a 10-column field, so the command starts at character 39 of
  every row while the header `     UID     PID    PPID  TTY        STIME COMMAND`
  puts `COMMAND` at character 43. Reading the command at the header's character
  offset is not a fix on MSYS either, which agrees with GREEN's measurement on
  the Linux fixture (header 52, rows 56) recorded in 074's `## Notes`.
- When `ps` cannot open a process (`OpenProcess` fails - another user's, or an
  elevated one) it uses the **boot time** as that process's start time. On a
  host that has been up more than a day, every such row has the two-word
  shape, whatever the process's real age. The case is therefore more common
  than "a harness run left running for a day".

What was NOT observed: a live two-word row. On 2026-10-26 `ps -ef` on this
host had 17 rows, all `HH:MM:SS`, and the host had been up 3.7 hours, so
nothing was old enough and the boot-time fallback could not produce one. The
fixtures below reproduce the shape from the source; `## Deferred
verifications` DV-2 is the real-host check and says what to do if the host
still has no such row at GATES.

The defect, read from `host_load_others` as shipped by 074: with the header's
`COMMAND` at field 6, a day-old row `   ryanc    5001    3999 ?        Oct 25 bash scripts/selftest.sh`
has `$6 = "25"`, `interp("25")` is false, `"25"` holds no separator, so
`run[n] = 0` and the row is silent. The 074 suite's `listing` helper writes
`12:07:33` on every row, which is why 48 assertions could not see it.

Required gate: none is configured for this repository (`gates.sh` reports every
gate UNCONFIGURED); the self-test suite `host-load` is what CI runs over this
file, through `bash scripts/selftest.sh`, and its floor in `floors.conf` is
what fails if the new assertions stop executing. `required_gates` stays empty.

## Acceptance criteria

The world is HARNESS-074's: this run is S, launched by P, by G, by GG; another
tree's `bash scripts/selftest.sh` is X with its suite
`/usr/bin/bash /d/other/.claude/tests/plan.test.sh` as Y (parent X). "Two-word
STIME" means the `Mon DD` shape `ps.cc` prints at 24 hours, rendered as the
real `ffmt` does (right-aligned in ten columns): `Oct 25` and, for a
single-digit day, `Oct  5` with two spaces.

- **AC-1** — Given an MSYS-shaped listing (header
  `UID PID PPID TTY STIME COMMAND`) in which X's row carries STIME `Oct 25`
  and Y's row carries `Oct  5`, every other row carrying `HH:MM:SS`, when
  `host_load_others S S <listing>` runs, then it prints exactly two lines,
  `X<TAB>bash scripts/selftest.sh` and
  `Y<TAB>/usr/bin/bash /d/other/.claude/tests/plan.test.sh`, in listing
  order: the command text begins at the interpreter and never with the day
  number. *This reproduces the bug:* on the 074 tree the same call prints
  nothing. *Control:* the same listing with `HH:MM:SS` on every row prints
  the identical two lines (074's AC-1, unchanged).
- **AC-2** — Given the AC-2 listing of 074 in which the ancestor GG
  (`bash /d/me/scripts/gates.sh`), the suite D1 (`bash .claude/tests/x.test.sh`,
  parent S) and the fixture run D2 (`bash scripts/selftest.sh`, parent D1)
  all carry `Oct 25`, when `host_load_others S S <listing>` runs, then none of
  GG, D1, D2 is printed and X, Y still are - a shifted row keeps its PID and
  PPID, so ancestry is unaffected. *Control:* D2 with its PPID rewired to an
  unrelated pid, still carrying `Oct 25`, IS printed as
  `D2<TAB>bash scripts/selftest.sh` - the day number is not part of the
  command text in the printed line either.
- **AC-3** — Given an MSYS listing in which every row carries `Oct 25`, when
  `host_load_others` runs over 074's AC-3 commands, then the five negatives
  (`grep -i selftest.sh`, `vim scripts/selftest.sh`,
  `bash scripts/plan.sh conflicts`, `bash C:\x\run-selftest091.sh`,
  `node vitest.test.sh`) are still not printed and the four positives
  (`bash scripts/gates.sh --gate unit`, `sh scripts/selftest.sh`,
  `/usr/bin/bash /x/.claude/tests/a.test.sh`,
  `C:\Program Files\Git\usr\bin\bash.exe scripts/selftest.sh`) each are, with
  their full command text - the shift changes where the command starts, not
  what counts as a test run. *Control:* a Linux-shaped listing (header
  `UID PID PPID C STIME TTY TIME CMD`) with STIME `Oct20` - the one-token
  shape procps prints past 24 hours - on X and Y prints the two AC-1 lines:
  no shift is applied where STIME is one word.
- **AC-4** — Given a project fixture (`make_project_fixture`) and
  `HARNESS_PS_LISTING` naming an MSYS listing with two foreign runs whose rows
  carry `Oct 25`, when `bash scripts/selftest.sh` runs in the fixture, then
  its stderr is exactly the three lines 074's AC-4 specifies -
  `selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:`
  then `selftest:   pid <X>: <command>` for each, the command beginning at
  the interpreter - and its exit status and stdout are byte-identical to the
  run with `HARNESS_PS_LISTING` naming an empty file. *This reproduces the
  bug end to end:* on the 074 tree that stderr is empty.

## Contract

**Writes:** `scripts/host-load.sh`, `.claude/tests/host-load.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Oracle partition.** Every criterion is *mechanical*: pin whole outputs
(`assert_eq` on the full stdout / full stderr, as the 074 suite does; `selftest:`
and `pid 1` are prefixes of other lines). The STIME shapes are *settled*, read
out of `ps.cc`'s `start_time()` quoted in `## Context`: `HH:MM:SS` under 24
hours; `Mon DD` and `Mon  D` at or over. The Linux shape `Oct20` (procps,
`%b%d`, one token) is settled too. Do not derive a third shape, and do not
"calibrate" the rule to anything the host happens to print today.

**`scripts/host-load.sh`** - `host_load_others <self-pid> <root-pid>
<listing-file>` keeps its name, arguments, output format (`<pid><TAB><command>`
per foreign run, listing order) and return codes. The change is inside the awk:

- Header row: alongside `pc`, `ppc`, `cc`, record `stc` - the field index of a
  column named exactly `STIME`. It is optional: a header without one leaves
  `stc` unset and the row parse behaves as it does today. `PID`, `PPID` and
  `COMMAND`/`CMD` stay required (return 1 without them).
- Data row, after 074's AC-8 guard (PID and PPID all digits, else skip): the
  command's first field is `s`, where `s = cc`, except that when `stc` is set
  and `$stc ~ /^[A-Z][a-z][a-z]$/` (a month abbreviation) and
  `$(stc + 1) ~ /^[0-9][0-9]?$/` (a one- or two-digit day), `s = cc + 1`.
  Every use of `cc` in the data-row block - the join `c = $cc; for (i = cc + 1
  ...)`, `interp($cc)`, the separator test, the multi-word-path scan `for (i =
  cc + 1; i < NF; i++)` and the `k < NF` test - reads `s` instead. Nothing
  else in the row (`$pc`, `$ppc`, `par[]`, the OURS sets) moves, because the
  shift happens after PPID.
- Why the month test and not "skip a leading all-digit word": the rule names
  the column that is known to be two words and the two words it is known to
  be. A rule that skipped any bare number would fire on a command it has no
  business touching and would have no fixture row that distinguishes it.
- The header comment's "Known limits" paragraph: remove the two-word STIME
  sentence, keep the UID-with-a-space and multi-line-command sentences, and
  add one sentence naming the rule (STIME `Mon DD` shifts the command one
  field; detected per row by header column name). `shellcheck shell=bash`,
  bash 3.2, awk and coreutils only, no `sed -i`, no `$TMPDIR`, no `mktemp`
  (`lib.test.sh` rules on shipped scripts).

**`.claude/tests/host-load.test.sh`** - the existing `listing <msys|linux>
<file>` helper writes `12:07:33` on every row. RED extends it so a row can
carry its own STIME - a fourth `|` field, defaulting to today's `12:07:33`
when absent, so every existing fixture is unchanged byte for byte - and
renders a two-word MSYS value as `ffmt` does, `%10s` right-aligned: `    Oct 25`,
`    Oct  5` (two spaces inside, as `ctime` pads a single-digit day), the
Linux value as the existing `%5s`. *Amended in RED, 2026-10-27:* the one-word
default keeps the existing `%8s`, because `%10s` on `12:07:33` would add two
spaces to every existing row and break "unchanged byte for byte", and the width
is not load-bearing (`host_load_others` splits on whitespace); and `Oct  5`
under `%10s` has four leading spaces, not the five the text first showed. The four new ACs become new `describe`
blocks alongside 074's, reusing `base_rows`, `ac2_rows` and the AC-3 lists;
074's assertions are not edited. New assertions raise the `host-load` floor
from 48 to the measured count, written in BOTH `floors.conf` (`floor |
host-load | <N>`, with a dated comment) and the table pinned in
`.claude/tests/selftest.test.sh` (`host-load 48` → `host-load <N>`). The
`selftest` floor (268) stays unless RED adds a case there.

**Callers of changed signatures.** None: `host_load_others` keeps its
signature; its only callers are `host_load_warn` (same file) and
`.claude/tests/host-load.test.sh`. `scripts/selftest.sh` and
`.claude/tests/_lib.sh` are not touched.

**The RED shape.** Unlike 074, the function exists in RED, so AC-1..AC-4's new
assertions fail by *output*, not by `command not found`: AC-1 and AC-2 print
nothing where two lines are expected, AC-4's fixture stderr is empty. That is
the right failure, and it is the bug's reproduction; paste it in the handoff.
Any new assertion that passes on arrival (the one-word controls re-asserting
074's behaviour) is earned by 074's DV-1 and needs no extra mutation here;
say which ones they are.

## Deferred verifications

**DV-1 (defect put back; the story's central claim). Owner: GATES.** With the
shift rule disabled - one `sed` through `scripts/mutate.sh` that makes `s`
always `cc` (RED names the expression in the handoff against the final text) -
and `bash scripts/selftest.sh host-load`, the two-word assertions of AC-1,
AC-2 and AC-4 **must** go red, printing nothing or the AC-4 empty stderr,
while every one-word case - 074's 48 and this story's controls - stays green.
RED cannot run it: the rule does not exist in RED. Paste the red lines, the
pass/fail counts (RED predicts them in the handoff) and `mutate.sh`'s restore
line.

*Result (GATES, orchestrator, 2026-10-27).* RED's expression against the
shipped line 82; the five two-word assertions went red, every one-word case
(074's 54 and this story's controls) stayed green; `67 passed, 5 failed` is
exactly RED's predicted count; restored and green again:

    === mutate: scripts/host-load.sh (1 line(s) changed by s/s = cc + 1/s = cc/) ===
      82 -       if (stc && $stc ~ /^[A-Z][a-z][a-z]$/ && $(stc + 1) ~ /^[0-9][0-9]?$/) s = cc + 1
      82 +       if (stc && $stc ~ /^[A-Z][a-z][a-z]$/ && $(stc + 1) ~ /^[0-9][0-9]?$/) s = cc
    === mutate: running bash scripts/selftest.sh host-load ===
        FAIL MSYS, X at 'Oct 25' and Y at 'Oct  5': exactly X and Y are printed, in listing order, no day number in the command
        FAIL every row of the AC-2 world at 'Oct 25': still exactly X and Y - ancestry is unaffected by the shift
        FAIL control - D2 at 'Oct 25' with its PPID rewired to an unrelated pid IS printed, as 'bash scripts/selftest.sh' with no day number
        FAIL every row at 'Oct 25': gates.sh --gate unit, sh selftest.sh, /usr/bin/bash a.test.sh, bash.exe under C:\Program Files - each printed with its full command
        FAIL two foreign runs at 'Oct 25': stderr is exactly the header line and two pid lines, each command from the interpreter on
    host-load: 67 passed, 5 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_host-load.sh.20261027T072204Z.10370.bak) ===

    host-load: 72 passed, 0 failed

**DV-2 (the real host). Owner: GATES.** At the top level, with no
`HARNESS_PS_LISTING` in the environment, run
`ps -ef | awk 'NR > 1 && $5 ~ /^[A-Z][a-z][a-z]$/'` and paste what it prints:
every row on this host whose STIME is two words. If any such row is also a
harness-shaped run outside this tree, run `env -u HARNESS_PS_LISTING bash
scripts/selftest.sh host-load` and paste the `selftest:   pid <pid>: <command>`
line naming it, the command beginning at the interpreter. If rows exist but
none is a test run, the pasted rows are the evidence that the two-word shape
is real on this host and the fixtures are faithful to it; say so. If there is
no such row, paste the row count and the host uptime beside `WAIVED`: the
shape is then confirmed from the source only (`## Context`), and a day-old
process - or a host up more than a day with a process `ps` cannot open - is
what would produce one.

*Result (GATES, orchestrator, 2026-10-27): **WAIVED** - no such row exists on
this host today.* `HARNESS_PS_LISTING` unset in the environment; at the top
level:

    $ ps -ef | awk 'NR > 1 && $5 ~ /^[A-Z][a-z][a-z]$/'
    (no output)
    count: 0 of 15 rows
    $ awk '{printf "uptime: %.1f h\n", $1/3600}' /proc/uptime
    uptime: 15.2 h

The host has been up 15.2 hours, so no process on it can be 24 hours old and
the boot-time fallback cannot produce a two-word row either. The shape stands
confirmed from `ps.cc` alone (`## Context`); the live check is owed by the
first GATES run on a host up more than a day, whichever story that is. (The
15 rows did include two foreign harness runs with one-word STIMEs, from
`/d/clean_calendar` - the case 074 already catches.)

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-076` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`: **Fable 5.1 (`claude-fable-5-1`)**, the agent's declared `fable`; the dispatching brief named no override, and this run saw none. The oracle partition for RED is in `## Contract`: every criterion mechanical, the STIME shapes settled from `ps.cc`.

## Out of scope

- **A UID with a space.** `ffmt`'s `%8.8s` truncates the account name to eight
  characters, so a Windows account such as `Ryan Zhang` prints `Ryan Zha` - two
  words before PID. That shifts PID and PPID, and 074's AC-8 guard (PID/PPID
  all digits) then drops the row silently rather than mis-parsing it. The fix
  is a different anchor (the fixed column widths of `ffmt`, or a user-name
  width read from the header), not this story's STIME rule. It stays a named
  limit in `host-load.sh`'s header; cut a story if a host with such an
  account appears. This host's account is `ryanc`.
- **Continuation rows of a multi-line command** (074 AC-8) and **the real
  `ps -ef` branch** (074 AC-9): delivered in 074, not revisited.
- **Reading the command at a character offset.** Shown not to line up on
  MSYS (header 43, rows 39) or Linux (52 vs 56); do not reintroduce it.
- **Other STIME shapes.** procps prints `Oct20` (one token) past 24 hours and
  the bare year past one year; BSD/macOS prints one token too. No shift is
  applied to one-word STIMEs and no fixture beyond AC-3's Linux control is
  owed. A STIME that is three words does not exist in any `ps` this harness
  names.
- **`scripts/selftest.sh`, `.claude/tests/_lib.sh`, the warning's wording, its
  five-line cap, and anything that would make it a refusal.**
- **Making `ps` itself produce a day-old row in a test** - no fixture may
  sleep for a day, and nothing may depend on the host's uptime.

## Test plan

All in `.claude/tests/host-load.test.sh`, five new `describe` blocks headed
`HARNESS-076`, inserted after 074's AC-4 block and before 074's AC-5/AC-7
blocks (AC-7 deletes the fixture's `host-load.sh`, and AC-4 here needs it).
074's 54 assertions are not edited. Level: unit (`host_load_others` called
directly over a fixture listing) for AC-1..AC-3; end to end (`bash
scripts/selftest.sh` in a `make_project_fixture`) for AC-4. Every comparison is
whole-output `assert_eq`.

Instrument change: `listing <msys|linux> <file>` reads an optional fourth `|`
field, STIME, defaulting to `12:07:33` (MSYS, `%8s`) / `12:07` (Linux, `%5s`);
a two-word MSYS value is rendered `%10s` (`    Oct 25`, `    Oct  5`). Two
filters, `stime_on <pid> <stime>` and `stime_all <stime>`, append it to rows.

| Block | Assertion | AC | Today |
|---|---|---|---|
| fixture rows | X's row is `   ryanc    5001    3999 ?            Oct 25 bash scripts/selftest.sh ` | instrument | pass |
| fixture rows | Y's row carries `Oct  5` (two spaces) | instrument | pass |
| fixture rows | S's row is byte-identical to 074's `12:07:33` row | instrument | pass |
| fixture rows | Linux X row carries the one token `Oct20` | instrument | pass |
| AC-1 | X `Oct 25`, Y `Oct  5`: stdout is exactly `LX\nLY` | AC-1 | **FAIL** (empty) |
| AC-1 | same: rc 0 | AC-1 | pass |
| AC-1 | control: all-`HH:MM:SS` listing prints `LX\nLY` | AC-1 control | pass |
| AC-2 | GG, D1, D2 at `Oct 25`: exactly `LX\nLY` | AC-2 | pass (see below) |
| AC-2 | every row of the AC-2 world at `Oct 25`: exactly `LX\nLY` | AC-2 | **FAIL** (empty) |
| AC-2 | control: D2 rewired to ppid 7777, `Oct 25`: `LX\nLY\nD2<TAB>bash scripts/selftest.sh` | AC-2 control | **FAIL** (D2 missing) |
| AC-3 | five negatives, every row `Oct 25`: empty | AC-3 | pass (see below) |
| AC-3 | same: rc 0 | AC-3 | pass |
| AC-3 | four positives, every row `Oct 25`: the four full-command lines | AC-3 | **FAIL** (empty) |
| AC-3 | control: Linux listing, `Oct20` on X and Y: `LX\nLY` | AC-3 control | pass |
| AC-3 | header with no STIME column: `LX` and rc 0 (Contract: STIME optional) | Contract | pass |
| AC-4 | foreign2 at `Oct 25`: stderr is the header line + two `pid` lines + nothing else | AC-4 | **FAIL** (empty stderr) |
| AC-4 | same: exit status = empty-listing run's | AC-4 | pass |
| AC-4 | same: stdout byte-identical to empty-listing run's | AC-4 | pass |

18 new assertions, 72 executed in all. Floors raised 54 -> 72 in both
`floors.conf` and `selftest.test.sh`'s COUNTS table.

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

Model: this RED ran on **Opus 5.5 (`claude-opus-5-5`)**, the agent's declared
`opus`; the dispatching brief named no override.

**Command.** `bash scripts/selftest.sh host-load` (about 10 s here). Then
`bash scripts/selftest.sh selftest` for the COUNTS row (268 passed, 0 failed).

**Failure output** (2026-10-27, this tree, `scripts/host-load.sh` as 074 shipped it):

    HARNESS-076 AC-1  a run over a day old (STIME 'Oct 25' / 'Oct  5') is still printed, command from the interpreter on
      FAIL MSYS, X at 'Oct 25' and Y at 'Oct  5': exactly X and Y are printed, in listing order, no day number in the command
           expected: 5001	bash scripts/selftest.sh
           5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
           actual:   

    HARNESS-076 AC-2  a shifted row keeps its PID and PPID: this run's own tree is still not printed
      FAIL every row of the AC-2 world at 'Oct 25': still exactly X and Y - ancestry is unaffected by the shift
           expected: 5001	bash scripts/selftest.sh
           5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
           actual:   
      FAIL control - D2 at 'Oct 25' with its PPID rewired to an unrelated pid IS printed, as 'bash scripts/selftest.sh' with no day number
           expected: 5001	bash scripts/selftest.sh
           5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
           4102	bash scripts/selftest.sh
           actual:   5001	bash scripts/selftest.sh
           5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh

    HARNESS-076 AC-3  the shift moves where the command starts, not what counts as a test run
      FAIL every row at 'Oct 25': gates.sh --gate unit, sh selftest.sh, /usr/bin/bash a.test.sh, bash.exe under C:\Program Files - each printed with its full command
           expected: 6101	bash scripts/gates.sh --gate unit
           6102	sh scripts/selftest.sh
           6103	/usr/bin/bash /x/.claude/tests/a.test.sh
           6104	C:\Program Files\Git\usr\bin\bash.exe scripts/selftest.sh
           actual:   

    HARNESS-076 AC-4  selftest.sh warns about two foreign runs over a day old, exactly as about fresh ones
      FAIL two foreign runs at 'Oct 25': stderr is exactly the header line and two pid lines, each command from the interpreter on
           expected: selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:
           selftest:   pid 9100001: bash /d/other1/scripts/selftest.sh
           selftest:   pid 9100002: bash /d/other2/scripts/selftest.sh
           x
           actual:   x

    host-load: 67 passed, 5 failed
    assertion floors: all 1 suite(s) met their declared floor (67 assertions executed, 54 declared).

(That floor line was read against the old floor 54; with the floor now 72 and
the floor counting PASSES, a RED run sits below it, 67 < 72 - expected.)

**Why these are the right failures.** The function exists, so nothing is
`command not found`. Each red is the bug itself: a two-word STIME row is read
with `$cc` = the day number, `interp("25")` is false, and the row is silent -
empty stdout (AC-1, AC-2 all-rows, AC-3 positives), the rewired D2 missing
while X and Y at `HH:MM:SS` still print (AC-2 control: the failure is exactly
one row, the shifted one), empty stderr (AC-4: `actual: x` is the sentinel
only). Every one-word assertion, 074's 54 included, is green, so the fixture
helper change broke nothing.

**Files touched.**
- `.claude/tests/host-load.test.sh` - `listing` takes an optional 4th field;
  `stime_on`, `stime_all` filters; five HARNESS-076 blocks (18 assertions).
- `.claude/tests/floors.conf` - `host-load` 54 -> 72, dated comment.
- `.claude/tests/selftest.test.sh` - COUNTS row `host-load 72`.
- this story - `## Contract` (amended, see below), `## Test plan`, this handoff.

**Contract amendment (in place, `.claude/tests/host-load.test.sh` paragraph).**
One-word default stays `%8s` (`%10s` would add two spaces to every existing
row; width is not load-bearing). Also corrected: `Oct  5` under `%10s` is
`    Oct  5` (four leading spaces), not the five the text first showed. No
acceptance criterion changed.

**What the tests pin about `host_load_others`.** Name, arguments
`<self-pid> <root-pid> <listing-file>`, output `<pid><TAB><command>` per
foreign run in listing order, rc 0 on a parsed listing, rc 1 on a header
missing PID/PPID/COMMAND|CMD (074's), all unchanged. New: on an MSYS row whose
STIME field (header column named `STIME`) is a month abbreviation followed by
a one- or two-digit day, the command begins one field later - both for what is
printed and for the interpreter/script test. A header with NO `STIME` column
must still parse (not return 1). The Linux one-token `Oct20` must not shift.
**Not constrained:** how the shift is coded (the Contract's `s = cc` /
`s = cc + 1` is a recommendation the tests satisfy, measured below, but any
rule that passes is admissible); whether `stc` is required to equal the
column before COMMAND; the header comment's wording (the Contract asks for it;
no test reads it). Fixtures do NOT distinguish the Contract's month rule from
a "skip a leading all-digit word" rule - as the Contract itself says; the
month rule is a design decision, not a tested one.

**Passed on arrival** (13 of the 18): the four fixture-row pins (instrument
checks - they fail if the helper stops writing two words, which would make
the AC reds vacuous); AC-1 rc and the AC-1 all-`HH:MM:SS` control; AC-2's
literal-AC listing (GG/D1/D2 at `Oct 25`, X/Y fresh) - green today *because
of* the bug, it guards against a fix that breaks ancestry and is only
meaningful once the all-rows and rewired cases are green; AC-3 negatives and
rc, the Linux `Oct20` control, the no-STIME-header case; AC-4 rc and stdout.
The one-word controls re-assert 074 behaviour and are earned by 074's DV-1;
the rest are earned by DV-1 below together with the candidate run. None
needed a separate mutation in RED (Contract, "The RED shape").

**Expected values of the controls / DV-1 prediction.** Measured outside the
tree: a copy of the repo in the scratchpad with a Contract-shaped candidate
`host-load.sh` (header `else if ($i == "STIME") stc = i`; row `s = cc` then
`if (stc && $stc ~ /^[A-Z][a-z][a-z]$/ && $(stc + 1) ~ /^[0-9][0-9]?$/) s = cc + 1`;
every data-row `cc` read as `s`). Claims about the shipped module until GREEN
and GATES measure them.

| Run | Prediction | Measured on candidate |
|---|---|---|
| suite, shipped 074 `host-load.sh` (today) | 67 passed, 5 failed | 67 passed, 5 failed (real tree) |
| suite, Contract-shaped fix | 72 passed, 0 failed | 72 passed, 0 failed |
| DV-1: fix with shift disabled, `sed 's/s = cc + 1/s = cc/'` | 67 passed, 5 failed - exactly the five reds above | 67 passed, 5 failed, the same five names |
| AC-2 rewired control under DV-1 | X, Y printed, D2 missing | as predicted |
| Linux `Oct20` control under fix | `LX\nLY` | as predicted |

For DV-1 to be runnable as written, GREEN should keep the shift on ONE line
containing the literal `s = cc + 1` exactly once, so GATES can run
`bash scripts/mutate.sh scripts/host-load.sh 's/s = cc + 1/s = cc/' -- bash scripts/selftest.sh host-load`.
If GREEN codes it differently, it names the replacement expression here.

**Declined, in writing.** DV-1 (defect put back) and DV-2 (the real host) are
owned by GATES. RED cannot run DV-1 against the tree - the rule it disables
does not exist yet; the candidate measurement above is a prediction, not DV-1.
DV-2 was not run.

**Discovered.** Nothing that changes the approach: the Contract's rule passes
the whole suite as written. `bash scripts/gates.sh --fast`: every gate
UNCONFIGURED, nothing failed for a config or timeout reason;
`check-sigpipe.sh` and `check-grep-count.sh`: 0 findings over 56 files.

## Diff review

Fresh `feature-developer` dispatch, `diff-review` skill, 2026-10-27.
Resolved model: **Opus 5.5** (`claude-opus-5-5`), declared `opus`, no
override (GATES row of `models.conf`). Changed no file. Report, condensed to
its checks, finding and verdict:

    What this change does: host_load_others records the STIME column; on a row
    whose STIME is a month abbreviation and a one- or two-digit day it reads the
    command one field later. 18 new assertions; floor 54 -> 72.
    host-load: 72 passed, 0 failed (72 executed, 72 declared).

    Checked in scratch fixtures against the shipped host-load.sh:
    (a) the month test reads only the STIME field: a one-word-STIME row whose
        command is "Jan 5 bash scripts/selftest.sh" is not shifted; a header with
        no STIME column never shifts; Linux "Oct20" / "2024" never shift.
    (b) stc is set only in the NR == 1 block; with no STIME column it stays 0
        and the test is false on every row.
    (c) STIME as the last header column (impossible with ps -ef): no crash,
        same result as before the change.
    (d) short rows ("... Oct 25", "... Oct", "... Oct 25 bash"): $s empty or
        bare interpreter, not reported, no error.
    (e) the boot-time fallback's two-word STIME on a SYSTEM row is handled the
        same way: reported with its full command.
    (f) a UID with a space whose second word is not a number is still skipped.
    (g) the AC-1, AC-2 control, AC-3 positive and AC-4 assertions pin whole
        outputs and were red on the 074 tree; the helper's two-word branch is
        pinned byte for byte for both "Oct 25" and "Oct  5".
    (h) the header comment matches the code for the STIME rule.

    Nice to have:
    1. The header's "Known limits" sentence (host-load.sh:32-33) says a UID
       with a space is skipped by the all-digits test. For a truncated account
       like "Ryan 123" the row passes that test and is read with PID 123 and the
       command from the STIME field: not reported, rc 0 - misread, not skipped.
       Behaviour is 074's and out of scope; only the wording is new. Fix:
       "is skipped, or read with the wrong PID and command; either way it is
       not reported". Comment only.

    Not checked: a live day-old row (DV-2, waived).
    Model: Opus 5.5 (claude-opus-5-5).

    Verdict: Ship.

**PO disposition.** `Verdict: Ship.` - GATES → REVIEW goes on. Nice to have 1
is left as written: correcting it changes the tree, which restarts the review
and the gate run for a comment no test reads. It is recorded in `## Notes`
for whichever story next touches `host-load.sh`'s header.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-27T07:23:00Z
    commit: 7e3a5d4
    tree:   f291f801ab0f2567d44e920dbd56908e32fa5a69
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

- Planned 2026-10-26 on `main` in the worktree `D:/adh-HARNESS-076`, from
  HARNESS-074's diff-review finding 2, at the user's request ("file finding 2
  (two-field STIME) as a follow-up story"). 074 was at GATES on its own branch
  at the time, so `depends_on: [HARNESS-074]`: this story edits
  `scripts/host-load.sh` and `.claude/tests/host-load.test.sh`, which 074
  creates, and raises the `host-load` floor 074 sets at 48.
- **How the premise was confirmed.** The brief called it unverified. Planning
  fetched `winsup/utils/ps.cc` from
  `https://raw.githubusercontent.com/msys2/msys2-runtime/msys2-3.6.11/winsup/utils/ps.cc`
  (the repository's default branch on 2026-10-26; the file is not under
  `mingw/`) and read `start_time()`, `ffmt` and the `boot_time` fallback
  quoted in `## Context`. The host runs `ps (cygwin) 3.6.10` (`ps -V`),
  `MINGW64_NT-10.0-26200 3.6.10`. The same day `ps -ef` here showed 17 rows,
  none with a two-word STIME, and the host had been up 3.7 hours - so the
  reproduction is from the source, and DV-2 owns the live check. Because the
  shape is settled from the source, this is a `fix` with fixture rows in
  both shapes, not a `spike`.
- Type `fix`: AC-1 and AC-4 are the reproduction - on the 074 tree they print
  nothing - and their tests become the permanent regression tests.
- `plan.sh conflicts` will report CONFLICT with any story that touches
  `floors.conf` or `selftest.test.sh` (every story that adds or raises a
  floor does); that is a wave ordering, not a dependency.
- **Carried from HARNESS-074 (2026-10-26, orchestrator), read before RED.**
  1. HARNESS-074 returned to RED after this story was planned and added
     AC-8 and AC-9; its `host-load` floor is now **54**, not 48. Every "48"
     above means 074's floor as it then stood; RED raises from 54.
  2. 074 now skips any row whose PID or PPID is not all digits (its AC-8). A
     UID holding a space therefore moves PID out of field 2 and that user's
     rows are skipped, not shifted. 074's `host-load.sh` header still says
     such a row "shifts the command one field" (its round-2 diff review,
     Nice to have 1); correct that sentence when this story touches the
     header.
- **PO checks before RED (2026-10-27, orchestrator).** HARNESS-074 is DONE;
  `host-load` floor is 54 in both `floors.conf:47` and `selftest.test.sh:538`.
  `scripts/host-load.sh` matches the Contract's reading: header loop sets
  `cc` at line 68, requires `pc`/`ppc`/`cc` at 70, data row reads `$cc` at
  76-81 with no STIME handling. The `listing` helper
  (`host-load.test.sh:49-61`) prints STIME with `%8s`, not `ffmt`'s `%10s`.
  The Contract asks for both `%10s` rendering and existing fixtures unchanged
  byte for byte, which `12:07:33` cannot satisfy under `%10s` (two more
  spaces). The width is not load-bearing - the awk splits on whitespace - so
  RED keeps `%8s` for the one-word default and renders a two-word value as
  the Contract's `    Oct 25` / `     Oct  5` strings; RED may amend that
  Contract block in place with that reason. `ps -ef` on this host today:
  0 rows with a two-word STIME; DV-2 stays with GATES. No epic. Resolved
  model for this planning check: Fable 5.1 (`claude-fable-5-1`).
- **RED verified by the orchestrator (2026-10-27).** Test-developer
  (resolved: Opus 5.5, `claude-opus-5-5`, declared `opus`, no override).
  Reran `bash scripts/selftest.sh host-load`: `67 passed, 5 failed`, the five
  being exactly the new two-word cases (AC-1; AC-2 all-rows and its rewired-D2
  control; AC-3 positives; AC-4 stderr), each red by OUTPUT - empty where X
  and Y are owed, D2 missing, stderr only the sentinel - not by a missing
  function. 74's 54 earlier assertions green; floor 54 -> 72 in both files.
  `scripts/` untouched (`git diff --quiet HEAD -- scripts/`). Correction to
  the PO check above: `printf '%10s' 'Oct  5'` gives FOUR leading spaces
  (`    Oct  5`), as RED found, not five. AC-2 as literally written (only GG,
  D1, D2 shifted) passes on arrival because the bug already hides those rows;
  RED kept it as an ancestry guard and added the all-rows variant, which is
  red - accepted.
- **GREEN verified by the orchestrator (2026-10-27).** Feature-developer
  (resolved: Opus 5.5, `claude-opus-5-5`, declared `opus`, no override)
  changed only `scripts/host-load.sh`: `stc` recorded from a header column
  named `STIME`; `s = cc`, or `s = cc + 1` on a row whose STIME is a month
  abbreviation followed by a one- or two-digit day; the join, `interp`, the
  separator test and the path scan read `s`. The header comment now names the
  rule and says a UID with a space is skipped, not shifted. Orchestrator
  reran: `host-load` 72 assertions executed, 72 declared, `1 harness suite(s)
  passed` (RED's unmutated control row, 72/0, confirmed); `.claude/tests/`
  untouched; `s = cc + 1` occurs once (line 82), so DV-1's expression applies
  as written. The Contract's "`k < NF` test" reads `k`, not `cc`, so nothing
  changed there; `k` follows `s`. shellcheck is not installed on this host,
  so the developer could not run it.
- **Known, not fixed (2026-10-27, from `## Diff review` Nice to have 1).**
  `scripts/host-load.sh:32-33` says a row whose UID holds a space is skipped
  by the all-digits test. That holds only when the account's second word is
  not a number: `Ryan 123` passes the test and is read with PID 123 and the
  command from the STIME field - not reported either way, but misread, not
  skipped. `## Out of scope` above makes the same claim. Reword when the
  header is next touched: "is skipped, or read with the wrong PID and
  command; either way it is not reported".
- **Self-test at GATES → REVIEW (2026-10-27).** `bash scripts/selftest-needed.sh`
  answered `run` (4 harness paths against origin/main, merge-base 825ac69) -
  its first use at this step since HARNESS-075 shipped it.
  `SELFTEST_JOBS=4 bash scripts/selftest.sh`, detached, alone in this
  worktree, no orphaned run found beforehand: exit 0, 1,354 s.

      assertion floors: all 30 suite(s) met their declared floor (4337 assertions executed, 4160 declared).
      30 harness suite(s) passed.
      exit=0 duration=1354s
- **Merged as #163 (2026-10-27, `9ea1345`).** CI on the PR head: `boundaries`
  success, its check step 2 s; `gates` success, its "Harness self-test" step
  3m34s (`30 harness suite(s) passed.`, `host-load: 72 passed, 0 failed`),
  far inside the job's 45-minute limit.
  https://github.com/ryanczhang7/agentic-dev-harness/actions/runs/40517913598
