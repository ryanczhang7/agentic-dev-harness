---
id: HARNESS-076
title: Host-load reads a day-old Git Bash run
slug: host-load-reads-a-day-old-git-bash-run
epic: 
type: fix
status: todo
phase: PLANNED
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
renders the MSYS value as `ffmt` does, `%10s` right-aligned: `    Oct 25`,
`     Oct  5` (two spaces inside, as `ctime` pads a single-digit day), the
Linux value as the existing `%5s`. The four new ACs become new `describe`
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

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

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
