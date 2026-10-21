---
id: HARNESS-069
title: A failing log with an unexplained signature outlives later failures
slug: a-failing-log-with-an-unexplained-signat
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-069-a-failing-log-with-an-unexplained-signat
depends_on: []      # HARNESS-027 (the <id>.failed.log step this extends) is DONE
touches: [scripts/gates.sh, .claude/harness/project.conf, .claude/state/README.md, .claude/skills/quality-gates/reference/configuring.md, .claude/tests/gates.test.sh, .claude/tests/settings.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf]
required_gates: []  # deliberate: no gate here reads scripts/** or .claude/tests/**; CI's selftest step judges it (PO-3)
---

## Context

**Port of manga-translator's MT-053** (filed there 2026-09-29, DONE 2026-10-15
against its vendored release-82 harness). manga-translator wrote it as a
harness change; upstream never received it, so the next refresh of that
project would delete it. The downstream story and its patches are the
specification: `/d/mt-harness-refresh-95/docs/backlog/stories/MT-053.md` and
`docs/wiki/handoff/part-MT-053-{gates,gates.test,settings.test,README,sigpipe.test}.patch`
there. Upstream has moved from release 82 to 95 since (HARNESS-052, -055,
-056, -057, -060, -061 all touched `scripts/gates.sh`), so nothing is copied
blind; every line number below was re-measured on `8ac522d`.

[[HARNESS-027]] made `scripts/gates.sh` keep `.claude/state/gate-logs/<id>.failed.log`:
the **last** non-passing run of each gate, stamped, left alone by a pass. That
fixed the case where a passing re-run destroyed the only copy of a failure. It
does not fix the case that happened next, twice, in the consuming project:
every story's RED run fails `unit` by design, so `unit.failed.log` lasts only
until the next story reaches RED. On 2026-09-29 the one record of a recurring
`cv2.error: Unknown C++ exception from OpenCV code` intermittent - the only
copy of the faulthandler report that two open audit questions needed - was
replaced four hours later by an ordinary `ZeroDivisionError` RED failure.

This story adds a manifest line kind, `keep-when | <gate id> | <extended
regex>`. When a gate runs, does not pass, and a cleaned line of its log matches
one of its `keep-when` regexes, `gates.sh` *also* copies the log to
`.claude/state/gate-logs/kept/<id>.<seq>.<stamp>.log` with a header. A kept
file is never rewritten; at most 5 per gate id are held, the lowest `<seq>`
evicted. It changes what `gates.sh` **keeps**, never what it **judges**
(AC-10).

**What the upstream port adds beyond the downstream code.** On release 95 a
consumer's `keep-when` lines are **silently ignored**: the parser's kind
allow-list (`gates.sh:158`) drops an unknown kind, and `--audit` says nothing.
So besides the retention itself, this story makes the kind known everywhere a
kind is listed or validated in this tree: the parser, `--audit`, `--list`, the
shipped `project.conf`'s comment blocks, and
`.claude/skills/quality-gates/reference/configuring.md`'s table of kinds
(grep for `skipped-when` on `8ac522d` finds exactly those sites, plus the
manifest fixture goldens, which stay unchanged - AC-7). Whether `--audit`
should report an *unknown* kind at all is a separate question with a wider
blast radius, and is out of scope here (PO-4).

**Which required gate would fail if this story's artifact broke?** None, by
design (PO-3, as for HARNESS-027): no gate in this repository's `project.conf`
reads `scripts/**` or `.claude/tests/**`. The judge is CI's `Harness self-test`
step, which runs `scripts/selftest.sh`, which runs `.claude/tests/gates.test.sh`,
`settings.test.sh` and `sigpipe.test.sh`.

## Acceptance criteria

Terms are HARNESS-027's. **"Did not pass"** means any outcome other than `pass`
(`fail`, `noevidence`, `environment`, `blocked`), required or optional. **"A
gate that ran"** means a gate whose command was executed. **"Matches a
signature"** means a line of the gate's log, cleaned by `clean_log`, matches
the extended regex of a `keep-when` line for that gate in
`.claude/harness/project.conf` (`grep -E` semantics, case-sensitive).

- **AC-1** - Given a gate with a `keep-when` line, when that gate runs, does
  not pass, and its log matches the signature, then `scripts/gates.sh` writes a
  new file under `.claude/state/gate-logs/kept/`, named
  `<id>.<seq>.<stamp>.log` as the Contract specifies. After its eight header
  lines the file holds that run's log byte-for-byte identical to `<id>.log`.
  When the same gate later runs and does not pass again, with or without a
  signature, that file is byte-for-byte unchanged and still present; the only
  exception is eviction by the bound (AC-5). A log of 20,000 lines whose
  **first** line is the signature (about 349 KB) is kept like any other: the
  decision never rests on the exit status of a `clean_log | grep -m1` pipeline
  (Contract, "Matching").
- **AC-2** - The kept file's header carries the same stamp as HARNESS-027's
  `<id>.failed.log` from the same run, computed the same way: the gate id, the
  outcome, the UTC start time, the commit (with the uncommitted-changes note
  when it applies) and the gate tree hash. It also names the signature: the
  `keep-when` regex verbatim, and the whole first cleaned log line it matched.
  When more than one `keep-when` line for the gate matches, the header names
  the first in manifest order, and the run produces exactly one kept file.
- **AC-3** - Given a gate that ran and did not pass, and whose log matches no
  signature, when `gates.sh` finishes, then `<id>.failed.log` and the `failing
  log kept:` line are exactly what HARNESS-027 specifies, `kept/` gains no file,
  every file already in it is byte-for-byte unchanged, and no `signature log
  kept:` line is printed. A run that *does* match also writes `<id>.failed.log`
  and prints `failing log kept:` exactly as before. Every HARNESS-027 assertion
  in `gates.test.sh` and `settings.test.sh` passes unmodified.
- **AC-4** - Given a gate that passes, including a pass whose log contains a
  line matching a signature, when `gates.sh` finishes, then no file under
  `kept/` is created, changed or removed, and no `signature log kept:` line is
  printed. The same holds for every gate a run does not execute: not selected
  by `--gate`, left out by `--fast` as `slow`, and every gate under `--list`
  and `--audit`.
- **AC-5** - `kept/` holds at most **5** files per gate id. Given 5 kept files
  for a gate, when a sixth run of that gate is kept, then the lowest-`<seq>`
  file of that gate is removed, and only that one; the other four and the new
  one remain byte-for-byte. Kept files of every other gate id are untouched,
  including an id that shares a prefix: evicting `coverage` never removes a
  `coverage-core` file.
  *Control:* 6 kept runs of `coverage` with distinct output, and 5 of
  `coverage-core`, leave exactly 5 + 5 files; the first `coverage` run's output
  is in no file; all 5 `coverage-core` files are unchanged.
- **AC-6** - The signatures come from `keep-when` lines and from nowhere else.
  With no `keep-when` line for a gate, its failing log keeps nothing under
  `kept/`, whatever it contains, and another gate's `keep-when` line never
  keeps it. A `keep-when` line with an arbitrary regex (`ZEBRA-[0-9]+`) keeps a
  failing log that matches it; a regex containing `|` survives the manifest
  whole and is named verbatim in the header; a line differing only in case
  does not match. `scripts/gates.sh` contains no regex of its own: the only
  patterns it tries are the manifest's.
- **AC-7** - `bash scripts/gates.sh --audit` prints
  `FAIL <id> a `keep-when` line names no configured gate` for a `keep-when`
  line whose id is no `gate` line's, and `FAIL <id> a `keep-when` line has no
  pattern` for one with an empty regex, in the exact form and padding of the
  `blocked-when` checks, each counted as a manifest problem and failing the
  audit. The shipped `.claude/harness/project.conf` documents the kind under a
  comment block, after the `skipped-when` block, that contains the whole line
  `# Format:  keep-when | <gate id> | <extended regex>` and an example in a
  comment, and carries **no live `keep-when` line** (this repository's gates
  are unconfigured; signatures are a project's own - PO-5). Its `--audit`
  still prints `Manifest audit passed.` with no `FAIL` line. The manifest
  fixture `project.conf` carries no `keep-when` line, and
  `.claude/tests/fixtures/manifest/project.audit.golden`, `project.list.golden`
  and `broken.audit.golden` are byte-for-byte unchanged (pinned by blob hash).
- **AC-8** - `bash scripts/gates.sh --list` prints, under a gate that has
  `keep-when` lines, one line per regex in manifest order, in the same column
  layout as its `blocked-when:` and `skipped-when:` lines:
  `<12 blanks> <9 blanks> <6 blanks> keep-when: <regex>`. A gate with none
  gets no such line.
- **AC-9** - Given a run that keeps a file, `gates.sh`'s stdout contains
  exactly one line
  `signature log kept: .claude/state/gate-logs/kept/<file> (matched: <regex>)`
  for it, after that gate's `failing log kept:` line and before the next
  gate's `=== gate:` header. A run that keeps nothing for a gate prints no
  such line for it. Eviction prints nothing on stdout.
- **AC-10** - For the same gate commands and outputs, the following are
  identical whether or not a `keep-when` line matches, and whether or not an
  eviction happens: `gates.sh`'s exit status; every summary line;
  `last-gate-run`'s `RESULT=` and `FULL=`; and the `## Gate results` block
  written with `--story`, compared with its `run:` time masked.
- **AC-11** - `.claude/state/README.md`'s state-file table has a row for
  `gate-logs/kept/*.log`: written by `scripts/gates.sh`, hand-editable `yes`;
  `settings.test.sh`'s cross-check of the table against `settings.json` still
  reports no disagreement. `.claude/skills/quality-gates/reference/configuring.md`'s
  list of line kinds has a `keep-when    | <gate id> | <regex ...>` row beside
  `blocked-when` and `skipped-when`.

## Contract

**RED may amend any block below, in place, with a reason, and GREEN builds what
the amended block says.** The acceptance criteria do not inherit that licence.

**Writes:** `scripts/gates.sh`, `.claude/harness/project.conf`, `.claude/state/README.md`, `.claude/skills/quality-gates/reference/configuring.md`, `.claude/tests/gates.test.sh`, `.claude/tests/settings.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`

### Files

| File | Change | Phase | Writer |
|---|---|---|---|
| `.claude/tests/gates.test.sh` | one new `describe` block for AC-1..AC-10, own fixture (pattern: the HARNESS-027 block at `:2048-2518`, helpers `count_line`/`count_re` at `:768-769`, `kept_line`, `same`, `lineno` at `:2090-2114`). Appended before the final `summary "gates"` (`:3227`); the EXIT `trap` at `:2519` must add the new fixture | RED | Test Developer |
| `.claude/tests/settings.test.sh` | one assertion for AC-11's row, with the `failed_row` reader at `:223` | RED | Test Developer |
| `scripts/gates.sh` | parse `keep-when`; keep, stamp, evict, print; `--list` line; `--audit` checks; comment on the kind | GREEN | Feature Developer |
| `.claude/state/README.md` | table row and a paragraph under "The exhaust" (AC-11) | GREEN | Feature Developer |
| `.claude/tests/sigpipe.test.sh` | re-pin the two `scripts/gates.sh:` lines in C-5's `DISCARDED` block (`:567-568`) to where GREEN's edit leaves them - the HARNESS-057 convention, see "Line pins" | GREEN | Feature Developer |
| `.claude/harness/project.conf` | the `keep-when` comment block (AC-7) | GREEN | **Lead PO** (PO-6) |
| `.claude/skills/quality-gates/reference/configuring.md` | the kinds table row and one paragraph (AC-11) | GREEN | **Lead PO** |
| `.claude/tests/floors.conf` | optional: raise `gates` (682) and `settings` (70) to the measured counts. Floors are minimums, so the run passes without it | GATES | orchestrator |

Not changed: `.claude/settings.json` (the row is `yes`), the three manifest
fixture goldens (AC-7), `.github/workflows/gates.yml` (uploads `gate-logs/` as
a directory, so `kept/` rides along), `.gitignore` (`.claude/state/*` already
ignores `kept/`). Every file above classifies as `harness`
(`bash scripts/classify.sh`, measured 2026-10-21), which every phase permits:
the lock enforces nothing here and the table is honoured by the agents (PO-1).

### The `keep-when` line

```
keep-when | <gate id> | <extended regex>
```

- Parsed like `blocked-when`: added to the allow-list at `gates.sh:158`, a
  `keep-when)` arm in the per-kind `case` at `:162-181` (after
  `skipped-when)` at `:179`), into a new `KEEPWHEN` table declared with the
  others at `:143`. `rest 3` for the regex, so `|` survives.
- Tried in manifest order; the first match wins (AC-2).
- Read only after the `case "$outcome"` block has run; it never changes an
  outcome, `$results`, the exit status or anything `record_in_story` writes
  (AC-10).

### Matching

`grep -E`, case-sensitive, over `clean_log "$log"`; the header's `# line:` is
the whole matched line (`-m1`, not `-o`). **The decision must not rest on the
status of `clean_log | grep -Em1`**: under `set -o pipefail`, once `grep -m1`
exits, `sed` dies of SIGPIPE writing the rest and the pipeline reports 141 -
measured downstream at 0 of 10 matches on a 20,000-line log, 5 of 5 at 6,000.
Capture the line and decide on its value:
`kline="$(clean_log "$log" | grep -Em1 -- "$kre")"`, keep when non-empty
(inside `$(...)` no status is read, and `check-sigpipe.sh` is content with it -
the HARNESS-057 pins are of that shape). Not awk: mawk has no interval
expressions (HARNESS-025) and a `keep-when` regex is a user's ERE. AC-1's
large-log case pins this.

### The kept file

Directory `$LOGDIR/kept/`, `mkdir -p` on first use. Name
`<id>.<seq>.<stamp>.log`:

- `<seq>`: six digits, zero-padded, one more than the highest `<seq>` among
  this gate's existing kept files, `000001` if none. This makes "oldest"
  well defined when two runs start within one second, which the suite does.
- `<stamp>`: `$started` with `-` and `:` removed (`YYYYMMDDTHHMMSSZ`); Windows
  file names cannot hold `:`.
- "This gate's kept files" are the names matching exactly
  `^<id>\.[0-9]{6}\.[0-9]{8}T[0-9]{6}Z\.log$`, matched by a bash glob of that
  shape - never `<id>*`, which takes `coverage-core`'s files for `coverage`'s
  (AC-5's control).

Content: eight header lines, then the log exactly as `tee` wrote `<id>.log`:

```
# gates.sh: failing run of gate '<id>' kept for a signature
# outcome: <fail|noevidence|environment|blocked>
# run:     <YYYY-MM-DDTHH:MM:SSZ>
# commit:  <commit_with_note output>
# tree:    <gate_tree_hash output>
# matched: <the keep-when regex, verbatim after trimming>
# line:    <the first cleaned log line it matched>
# ----
<the log, byte-identical to <id>.log from the same run>
```

Lines 2-5 use the same values as HARNESS-027's header, computed once in the
`<id>.failed.log` step (`gates.sh:742-756`; the print is `:755`) and held in
variables so both files carry the very same stamp. Testable as
`tail -n +9 <kept> | cmp - <id>.log`. Written once, never rewritten; only
eviction removes it.

### When it is written, and eviction

Immediately after the `failing log kept:` print at `:755`, inside the same
`if [ "$outcome" != pass ]`, and only when a `keep-when` line for `$id`
matches. After writing, while the gate has more than `KEEP_PER_GATE` kept
files, remove the lowest `<seq>` one. `KEEP_PER_GATE=5` is a named constant
beside `LOGDIR` (`:53`) with a comment pointing here; it bounds disk use and
is not a property of the project, so it is not a `project.conf` line. Why 5:
PO-2. Eviction may print a note to stderr; nothing pins it.

### The output line (AC-9)

```
signature log kept: .claude/state/gate-logs/kept/<id>.<seq>.<stamp>.log (matched: <regex>)
```

On stdout, once per kept file, after `failing log kept:`. Not added to
`$results`.

### `--list` (AC-8) and `--audit` (AC-7)

- `--list`: a loop over `KEEPWHEN` beside the `BLOCKEDWHEN` and `SKIPPEDWHEN`
  loops at `:480-485`, same `printf '%-12s %-9s %-6s keep-when: %s\n'` shape.
- `--audit`: a loop beside the `blocked-when` one (`:809-819`; `skipped-when`'s
  follows at `:821-836`) printing
  `FAIL %-12s a `keep-when` line names no configured gate` and
  `FAIL %-12s a `keep-when` line has no pattern`, each incrementing `fails`.
  This is the only new `FAIL` path; it fires only on the new kind, so no
  manifest `--audit` passes today can fail it.

### The shipped `project.conf` block (AC-7, written by the Lead PO)

After the `skipped-when` block (`:277-289`), before `BOOTSTRAPPED=no`:

```
# Format:  keep-when | <gate id> | <extended regex>
#
# <id>.failed.log is the LAST run of a gate that did not pass, and the next
# failure replaces it - every story's RED fails `unit` by design, so the one
# log of a failure nobody has explained can be gone within hours. A gate that
# ran, did not pass, and whose cleaned log matches one of its keep-when lines
# is also copied to .claude/state/gate-logs/kept/<id>.<seq>.<stamp>.log, never
# rewritten; at most 5 per gate, the oldest evicted. It changes what is kept,
# never what is judged. Add a line only for a failure nobody has explained,
# and remove it once the failure is. grep -E, case-sensitive, first match in
# manifest order wins. `--audit` refuses a line naming no gate, and one with no
# pattern. See HARNESS-069.
#
#   keep-when | integration | SEGFAULT in worker [0-9]+
```

The example is a comment and is not a line `--audit` sees; the manifest
carries no live `keep-when` line (PO-5).

### `configuring.md` (AC-11, written by the Lead PO)

The "Eight more kinds" table at `:21-30` gains
`    keep-when    | <gate id> | <regex of a failure nobody has explained yet>`
after `skipped-when`, the count word becomes nine, and one paragraph beside
the `skipped-when` one (`:51-60`) says what it keeps, where, the bound, and
that it never changes a verdict.

### Line pins that this story moves

`.claude/tests/sigpipe.test.sh` C-5's `DISCARDED` block pins
`scripts/gates.sh:77:BOOTSTRAPPED="$(grep` and
`scripts/gates.sh:651:why="could not launch: $(` (`:567-568`) and fails as
stale when either drifts. `KEEP_PER_GATE` beside `LOGDIR` at `:51` moves the
first by the lines inserted there; the parser arm and the keep function move
the second. **GREEN pins both to what `grep -n 'BOOTSTRAPPED="\$(grep\|could
not launch: \$(' scripts/gates.sh` prints**, changes nothing else in that
file, runs `bash scripts/selftest.sh sigpipe` and pastes the summary in
`## Notes` - exactly as HARNESS-057 did (its GREEN commit `3e22256` is the
precedent). The "12 lines, none stale" count does not change.

### How the tests run

Fixture only, as HARNESS-027: `make_project_fixture` and `write_conf` from
`_lib.sh`, gate commands that are `printf`s or `cat`s of a marker file. The
downstream block (`part-MT-053-gates.test.patch`) is the model, with these
upstream differences: fixture and marker directory named for this story
(`F69`, `.claude/state/h69/`), the `describe` labelled `HARNESS-069`, every
`MT-` reference reduced to a provenance remark, and the shipped-manifest
assertions rewritten for AC-7 as stated here (format line present, no live
line, `--audit` passes, goldens hash-pinned) - the downstream eight-line
check does not apply. Its fixture lists `project.conf` and `.claude/state/`
in `.git/info/exclude` so AC-10's two runs differ in the manifest only, not in
`tree:`/`commit:`. No test `rm`s a variable path; each scenario uses its own
gate ids. The lower-case decoy, the `|` regex, the 20,000-line log and the
`coverage`/`coverage-core` control all carry over.

```bash
bash scripts/selftest.sh gates      # AC-1..AC-10 (the suite ran ~90 s downstream; this adds gates.sh invocations)
bash scripts/selftest.sh settings   # AC-11
bash scripts/selftest.sh sigpipe    # after GREEN's re-pin
bash scripts/gates.sh --audit       # AC-7 against the shipped manifest
bash scripts/selftest.sh            # everything, before GATES
```

### Oracle partition

- **Mechanical:** AC-1 to AC-4 and AC-6 to AC-11. A file exists or does not,
  bytes match or do not, a line is printed or is not. *Precision beats
  invention; pin exactly, leave nothing open-ended.*
- **Settled:** AC-5's number, **5** (PO-2). RED reads it out and does not tune
  it; its negative control is written into the criterion.

### Existing exports whose signature changes

None. `commit_with_note`, `gate_tree_hash`, `clean_log`, `record_in_story`
and `table_get` keep their signatures and outputs; the new code only calls
them.

## Deferred verifications

Budget per `rules.md`, "Mutation work per story": one defect-put-back for the
central claim, one earning the assertions that pass on arrival, one probe of
the new rule against a real line of this tree. Each runs through
`bash scripts/mutate.sh <file> '<sed expr>' -- <narrowest command>`; RED
predicts a red count for each in its handoff and GATES compares.

**DV-1 (defect put back): the kept-file step never runs.** With the call to
the keep step neutralised in `scripts/gates.sh`, AC-1, AC-2 and AC-9's
assertions **must** go red (downstream measured 61 of 592). RED cannot run
this: there is no keep step to remove. Command: `bash scripts/selftest.sh
gates`. **Owner: GATES.**

**DV-2 (earning what passes on arrival): keep on a pass.** AC-4's "a pass
whose log matches a signature leaves `kept/` unchanged" and "prints no
signature line" pass in RED with no code at all. With the keep step also
called for a passing gate, both **must** go red (downstream: 6, the two named
among them). RED cannot run it for the same reason as DV-1. Command: `bash
scripts/selftest.sh gates`. **Owner: GATES.**

**DV-3 (the rule against the real tree): `--audit` sees a bad `keep-when` line
in the shipped manifest.** With one line `keep-when | nosuch | x` appended to
`.claude/harness/project.conf` (`mutate.sh` on that file, `$a` expression),
`bash scripts/gates.sh --audit` **must** print
`FAIL nosuch       a `keep-when` line names no configured gate` and exit 1,
and must print `Manifest audit passed.` again once restored. Fixtures say the
check is right about a manifest RED wrote; only this says it is right about
the one that ships. **Owner: GATES.**

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-069` from `.claude/harness/models.conf`.
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

- PLANNED (2026-10-21, dispatched as a subagent into worktree
  `D:/adh-HARNESS-069`): `lead-po` resolved to **Fable 5.1**
  (`claude-fable-5-1`), which is what `lead-po.md` declares; no override was
  passed. No departure from the plan is proposed: RED is briefed with the
  Contract, PO-7 and the oracle partition, and AC-3's "HARNESS-027 unmodified"
  half and AC-4 pass on arrival and are earned by DV-1 and DV-2.

## Out of scope

- **Any change to what a gate is judged to be.** No verdict, command, evidence
  line, floor, waiver, `slow`, `covers`, `blocked-when` or `skipped-when`
  changes; nothing changes the `## Gate results` record, `last-gate-run`, the
  summary or `record_in_story` (AC-10). The one new `FAIL` path is `--audit`'s
  check of the new kind (AC-7).
- **Any change to HARNESS-027's `<id>.failed.log`**: name, header, replacement
  rule or output line (AC-3).
- **`--audit` reporting an unknown manifest kind.** Today an unknown kind is
  dropped silently by `gates.sh:158`, which is how a consumer's `keep-when`
  lines vanished on release 95. Fixing that generally means an allow-list
  spanning every reader of `project.conf` (`gates.sh`, `doctor.sh`'s `gate`,
  `task` and `discovery`, `task.sh`), a new golden for `broken.conf`, and a
  decision on WARN against FAIL for forward compatibility. Its own story
  (PO-4).
- **Shipping any live `keep-when` line in this repository's `project.conf`**,
  and the downstream project's eight lines (`Windows fatal exception`,
  `Unknown C\+\+ exception` on four gates): project-owned (PO-5).
- **Re-refreshing manga-translator** onto this release: the orchestrator does
  that after the merge.
- **Keeping a passing log that contains a signature**, **keeping the last N
  failing logs regardless of signature** (declined downstream, PO-2), **a
  wildcard gate id**, **atomic writes or locking between concurrent runs**
  (`gates.sh` detects rather than locks; two concurrent runs could pick one
  `<seq>` - file separately if it ever bites), **a gate id containing `.`**
  (none exists), **any automatic re-run or suppression** of a flaky gate.
- **Python, or any dependency beyond bash, awk and coreutils** (`rules.md`,
  "Portability").

## Design notes

Not user-facing; no design notes.

## Test plan

<!-- Filled by the Test Developer during RED. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. -->

## Gate results

<!-- Written by scripts/gates.sh itself. -->

## Notes

**PO-1: the phase lock enforces nothing in this story.** Every path in
`touches:` classifies as `harness` (`bash scripts/classify.sh`, 2026-10-21 on
`8ac522d`), which every phase permits. The Files table is honoured by the
agents and checked by the orchestrator against the diff: RED writes only the
three test files; GREEN writes `gates.sh`, the README and the sigpipe re-pin;
the Lead PO writes `project.conf` and `configuring.md` in GREEN. No
`## Scaffold inventory` is needed: nothing classifies as `source`.

**PO-2: why signature-triggered, and why 5.** Last-N measures a log's lifetime
in ordinary failures, which this loop produces on a schedule (every RED fails
`unit`); to survive a week it would need N of 20-30 per gate, holding 20-30
explained failures to keep one unexplained one. A signature keeps exactly what
an audit asked for, and adding one is one manifest line - the right moment to
decide a failure is worth keeping. Its weakness is the failure nobody has
named yet, which `<id>.failed.log` still catches until the next non-pass. Five
holds the next several recurrences of one gate side by side (the downstream
audit learned most from comparing two incidents), and bounds the directory at
5 x the gate count; at the measured 23-29 KB a log that is under 2 MB for this
manifest's 7 gates. Adopted from MT-053 PO-2 without re-litigating.

**PO-3: `required_gates: []` is a decision**, the same as HARNESS-027 PO-3: no
gate here reads the harness; CI's selftest step is the judge.

**PO-4: unknown kinds stay silent in this story.** Decided at PLANNED: AC-7
makes `--audit` refuse a `keep-when` naming no gate or no pattern, as every
per-gate kind already is; reporting an *unrecognised kind* is a separate story
with a wider footprint (Out of scope). Candidate title: "`--audit` names a
manifest line kind no script reads".

**PO-5: the shipped manifest documents the kind and carries no live line.**
This repository's gates are unconfigured (`BOOTSTRAPPED=no`); the signatures
that justified MT-053 are faulthandler's and OpenCV's, which belong to
manga-translator's `project.conf`, not to the template every consumer starts
from. The comment block, with an example, is what a consumer copies; the
`stack-profiles` skill lists no `blocked-when` or `skipped-when` either, so no
profile snippet gains a `keep-when`.

**PO-6: `project.conf` and `configuring.md` are the Lead PO's to write**
(`rules.md`, path ownership). The orchestrator writes both during GREEN, once
`gates.sh` parses the kind; they can go in earlier, because today's `gates.sh`
skips an unknown kind and the block is all comment.

**PO-7: what differs from the downstream code, deliberately.** (1) The
matching idiom is the SIGPIPE-safe capture the downstream RED amended in, not
the one its Contract first proposed. (2) `--list` shows `keep-when:` lines,
which downstream declined to avoid golden churn; upstream's fixture carries no
`keep-when` line (nor a `skipped-when`), so no golden moves. (3) No live
lines ship (PO-5), so the shipped-manifest assertions differ. (4) Both sigpipe
pins move here, not only the second: `KEEP_PER_GATE` goes beside `LOGDIR`
(`:53`), above `:77`. (5) Marker and fixture names are this story's. Everything else -
header shape, name shape, bound, eviction order, output line, audit wording,
README row - is carried over unchanged so the consumer's refresh lands on an
identical feature.
