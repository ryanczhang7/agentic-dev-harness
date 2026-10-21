---
id: HARNESS-069
title: A failing log with an unexplained signature outlives later failures
slug: a-failing-log-with-an-unexplained-signat
epic: 
type: feature
status: in-progress
phase: RED
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
- RED (2026-10-21, dispatched as a subagent into worktree
  `D:/adh-HARNESS-069`): `test-developer` resolved to **Opus 5.5**
  (`claude-opus-5-5`), which is what `test-developer.md` declares; no override
  was passed. As planned.

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

Written 2026-10-21 by the Test Developer (RED). One level: the harness's
integration level, `scripts/gates.sh` run as a process against a throwaway
fixture whose gate commands are `cat`/`printf`/`awk`. The keep step is inline in
the gate loop; its contract is a file on disk, bytes, a stdout line and an exit
status, so there is no smaller unit to test.

**`.claude/tests/gates.test.sh`** - one new block,
`describe "HARNESS-069 AC-1..AC-11 ..."`, appended last, before `summary "gates"`.
150 `assert_eq` lines, two of them in loops (3 x 5 and 5 x 2), so **168 new
assertions executed: 682 -> 850**. Its own fixture `F69`
(`make_project_fixture`), `project.conf` and `.claude/state/` in its
`.git/info/exclude`, markers under `.claude/state/h69/`. The block's `trap`
line replaces HARNESS-030's to add `"$F69"`; nothing else in the file changed.
Scenarios, in file order:

| Scenario | Gate ids | AC |
|---|---|---|
| failing run, signature on line 2 of 3; full run so the next gate's header bounds the output line | `sig`, `after` | AC-1 (name from the same run's `failed.log` `# run:`, body `tail -n +9 \| cmp`), AC-2 (all 8 header lines; 2-5 against the same run's `sig.failed.log`, 4 and 5 also independently via `rev-parse --short HEAD` and `gate_tree_hash`), AC-3 second half, AC-9 (once; after `failing log kept:`, before `=== gate: after`) |
| both signatures, the C++ one FIRST in the log | `sig` | AC-2 (manifest order wins; `# line:` is the first line *that* regex matched; one file; `<seq>` 000002), AC-1 (first kept file byte-identical) |
| only `Unknown C++ exception` | `sig` | AC-2 (`# matched: Unknown C\+\+ exception` verbatim), AC-9 |
| failing, no signature, a lower-case decoy | `sig` | AC-1 (earlier file unchanged), AC-3 (kept/ byte-identical, no line, HARNESS-027's file and line exactly), AC-6 case |
| noevidence, blocked (`blocked-when`), environment (`floor` + `skipped-when`), each with a signature | `nev`, `blk`, `env` | AC-1 "did not pass" covers every non-pass outcome; AC-2 outcome line equals that run's `failed.log`'s; AC-9 (not in the downstream block) |
| a PASS whose log has the signature | `sig` | AC-4 |
| `--gate after`, `--list`, `--audit`, `--fast` with `slow \| sig` | `sig` | AC-4; `--audit` also AC-7's "well-formed passes" control |
| 20,001-line log, signature on line 1 (349 KB) | `big` | AC-1's SIGPIPE pin (Contract, "Matching") |
| no `keep-when` + every signature used + a ZEBRA line; `ZEBRA-[0-9]+`; `(QUAGGA\|OKAPI) [0-9]+` on an optional gate; `zebra-42`/`Zebra-42` against `ZEBRA-[0-9]+` | `nokw`, `zebra`, `alt`, `lc` | AC-6 (every bullet; no-regex-of-its-own as a grep of `gates.sh` with a reader control per needle), AC-9 |
| 5 x `coverage-core`, then 6 x `coverage`, distinct outputs | `coverage`, `coverage-core` | AC-5 and its written control; AC-9 (eviction prints nothing) |
| keep vs no keep; 5th vs 6th (eviction) kept run, each `--story T-1` | `g10`, `ok10` | AC-10 (rc, summary, `RESULT=`/`FULL=`, `## Gate results` with `run:` masked) |
| two `keep-when` lines and a `blocked-when` on `lst`, none on `none` | `lst`, `none` | AC-8 (whole line in the `%-12s %-9s %-6s keep-when: %s` layout, manifest order, under its gate, none for `none`) |
| `keep-when \| nosuch \| ...`, `keep-when \| sig \|`; control `blocked-when \| nosuch` | `sig` | AC-7 `--audit` FAIL lines, `1 manifest problem(s).`, exit 1 |
| the shipped `project.conf` (read; audited on a copy in F69), the three goldens | - | AC-7 (format line once, after `skipped-when`'s format line, before `BOOTSTRAPPED=`; a commented example between them; no live line; `--audit` passes, exit 0, no FAIL; fixture conf has no `keep-when`; three goldens pinned by blob id) |
| `configuring.md` | - | AC-11 (the Contract's row exactly, on the line after `skipped-when`'s row; "Nine more kinds, ...") |

**`.claude/tests/settings.test.sh`** - one `describe` and one assertion after
HARNESS-027's AC-7 block: `failed_row "$README" 'gate-logs/kept/*.log'` = 1
(70 -> 71 executed). AC-11's "cross-check still reports no disagreement" is
the existing `no disagreements` assertion, unchanged. AC-3's "every HARNESS-027
assertion passes unmodified" is the HARNESS-027 block, unchanged and green.

Not touched: `floors.conf` and `sigpipe.test.sh` (GREEN/GATES, per the Files
table), every golden, every source/doc file.

## Handoff: RED -> GREEN

Written 2026-10-21 by the Test Developer, dispatched as `test-developer`
(declares `opus`); this session ran on **Claude Opus 5.5** (`claude-opus-5-5`).
No override was given in the brief.

### Commands

```bash
bash .claude/tests/gates.test.sh       # AC-1..AC-11's gates.sh half (the HARNESS-069 block is last)
bash .claude/tests/settings.test.sh    # AC-11's README row
bash scripts/selftest.sh gates         # the same, through the runner and its floor check
bash scripts/selftest.sh sigpipe       # after GREEN's re-pin
bash scripts/selftest.sh               # everything, before GATES
```

### Files touched in RED

- `.claude/tests/gates.test.sh` - the HARNESS-069 block before `summary "gates"`;
  its `trap` line replaces HARNESS-030's to add `"$F69"` to the cleanup.
- `.claude/tests/settings.test.sh` - one `describe` + one assertion after
  HARNESS-027's AC-7 block.
- `docs/backlog/stories/HARNESS-069.md` - `## Test plan`, this section, one
  `Resolved:` line under `## Model guidance`.

Not touched: `scripts/gates.sh`, `.claude/state/README.md`,
`.claude/harness/project.conf`, `configuring.md`, `sigpipe.test.sh`,
`floors.conf`, any golden. **No Contract amendment.**

### RED output (measured locally, 2026-10-21, on `f76f368` + these tests)

`bash .claude/tests/gates.test.sh` - **26 min 18 s** wall locally, on a host
with ~36 bash processes from other sessions (user 2m16s, sys 11m19s); the
figure measures the host, not this block. CI's self-test runs on
`ubuntu-latest` with no `timeout-minutes` (gates.yml); bash suites carry no
per-test timeout. The block adds about 45 `gates.sh` invocations. Every one of
the 93 failures is in the HARNESS-069 block (none before its `describe`, line
108 of the output); every HARNESS-027 assertion and every other block is green.

```
gates: 757 passed, 93 failed
settings: 70 passed, 1 failed
```

`settings.test.sh`'s one failure, verbatim:

```
    FAIL AC-11: README has one gate-logs/kept/*.log row, written by scripts/gates.sh, hand-editable yes
         expected: 1
         actual:   0
```

The 93 failing assertions in `gates.test.sh`, verbatim (names only; every
`actual:` is `0`, empty, `no kept file []`, `missing: .../r1.copy`, or a
`no (...)` naming the absent line - checked one by one, none is a fixture
error):

```
FAIL AC-1: a failing run whose log matches a keep-when line leaves exactly one kept file for that gate
FAIL AC-1: the kept file is kept/sig.000001.<the run's start, without - and :>.log
FAIL AC-2 header 1 names the gate and why it was kept
FAIL AC-2 header 2 is the outcome
FAIL AC-2 header 2 is the outcome line of the same run's sig.failed.log
FAIL AC-2 header 3 is a UTC time, YYYY-MM-DDTHH:MM:SSZ
FAIL AC-2 header 3 is the run line of the same run's sig.failed.log
FAIL AC-2 header 4 is the commit line of the same run's sig.failed.log
FAIL AC-2 header 4 is the short HEAD, with the note only when the tree is dirty
FAIL AC-2 header 5 is the tree line of the same run's sig.failed.log
FAIL AC-2 header 5 is gate_tree_hash, computed independently
FAIL AC-2 header 6 is the keep-when regex that matched, verbatim
FAIL AC-2 header 7 is the whole first log line it matched
FAIL AC-2 header 8 closes the header
FAIL AC-1: after eight header lines, the run's sig.log byte for byte
FAIL AC-1: and it is this run's log
FAIL AC-9: the signature line is printed exactly once, naming the file and the regex
FAIL AC-9: and no other signature line is printed
FAIL AC-9: it comes after sig's header and after HARNESS-027's failing log kept line
FAIL AC-9: and before the next gate's header
FAIL AC-2: a run matching two keep-when lines still produces exactly one kept file
FAIL AC-2: the next kept file takes <seq> 000002
FAIL AC-2: the header names the first keep-when line in manifest order
FAIL AC-2: and the first log line THAT regex matched
FAIL AC-2: header 3 is the same run's failed.log run line
FAIL AC-1: the second kept file is the second run's log, byte for byte
FAIL AC-9: one signature line, naming the manifest-first regex
FAIL AC-9: and only one
FAIL AC-1: a later failing run WITH a signature leaves the first kept file byte-identical
FAIL AC-2: a log matching only the second keep-when line is kept
FAIL AC-2: its header names that regex verbatim, backslashes included
FAIL AC-2: and the whole line it matched
FAIL AC-9: the signature line carries the regex verbatim
FAIL AC-3 control: the snapshot holds the three kept sig files
FAIL AC-1: a later failing run WITHOUT a signature leaves the first kept file byte-identical
FAIL AC-1: a run of nev whose outcome is noevidence and whose log matches is kept, once
FAIL AC-2: its header says outcome noevidence
FAIL AC-2: the same outcome line as nev.failed.log
FAIL AC-1: nev's kept file is its log, byte for byte
FAIL AC-9: one signature line for nev
FAIL AC-1: a run of blk whose outcome is blocked and whose log matches is kept, once
FAIL AC-2: its header says outcome blocked
FAIL AC-2: the same outcome line as blk.failed.log
FAIL AC-1: blk's kept file is its log, byte for byte
FAIL AC-9: one signature line for blk
FAIL AC-1: a run of env whose outcome is environment and whose log matches is kept, once
FAIL AC-2: its header says outcome environment
FAIL AC-2: the same outcome line as env.failed.log
FAIL AC-1: env's kept file is its log, byte for byte
FAIL AC-9: one signature line for env
FAIL AC-1: a 20,001-line log whose first line is the signature is kept
FAIL AC-1: after its header, the large log byte for byte
FAIL AC-2: and its header names the line it matched
FAIL AC-6: an arbitrary regex, ZEBRA-[0-9]+, keeps a failing log that matches it
FAIL AC-6: naming it verbatim
FAIL AC-6: and the line it matched
FAIL AC-6: a regex containing | survives the manifest whole, and keeps an optional gate's failure
FAIL AC-6: named verbatim, alternation and all
FAIL AC-6: alt's kept file says outcome fail (printed WARN)
FAIL AC-9: one signature line for zebra
FAIL AC-9: one signature line for alt
FAIL AC-9: and two in all
FAIL AC-6: the earlier kept files are untouched by other gates' runs
FAIL AC-5 control: five kept coverage-core runs
FAIL AC-5 control: five kept coverage runs, and no coverage-core file taken for one
FAIL AC-5 control: five coverage runs leave coverage-core's five alone
FAIL AC-5: the sixth kept run leaves exactly 5 coverage files
FAIL AC-5: the one removed is the lowest <seq>, and the new one is 000006
FAIL AC-5 control: the second run's output is still in exactly one file
FAIL AC-5: the other four are byte-identical to before
FAIL AC-5: the new one is the sixth run's log
FAIL AC-5: kept/ holds exactly 5 + 5 files whose names start with coverage
FAIL AC-9: the eviction run prints one signature line, for the new file
FAIL AC-9: eviction prints nothing else on stdout that names kept/
FAIL AC-10 control: the matching run kept a file
FAIL AC-10 control: and printed its signature line
FAIL AC-10 control: the non-matching run kept nothing
FAIL AC-10 control: the fifth kept run evicts nothing
FAIL AC-10 control: the sixth kept run evicts the first
FAIL AC-8: --list prints the first keep-when line once, in the blocked-when column layout
FAIL AC-8: and the second, | and all
FAIL AC-8: both under lst, in manifest order, before the next gate's line
FAIL AC-8: a gate with no keep-when line gets none: two keep-when lines in all
FAIL AC-7: --audit fails a keep-when line that names no configured gate, naming it
FAIL AC-7: counted as a manifest problem
FAIL AC-7: and exits 1
FAIL AC-7: --audit fails a keep-when line with no pattern
FAIL AC-7: counted as a manifest problem
FAIL AC-7: and exits 1
FAIL AC-7: the shipped project.conf holds the keep-when format line once, after skipped-when's and before BOOTSTRAPPED=
FAIL AC-7: and an example keep-when line in a comment, between the format line and BOOTSTRAPPED=
FAIL AC-11: configuring.md's kinds table has the keep-when row once, straight after skipped-when's
FAIL AC-11: and the count above the table says nine
```

Representative `actual:` values, verbatim from the same run:

```
    FAIL AC-8: both under lst, in manifest order, before the next gate's line
         expected: yes
         actual:   no (lst 1, first absent, second absent, none 4)
    FAIL AC-7: the shipped project.conf holds the keep-when format line once, after skipped-when's and before BOOTSTRAPPED=
         expected: yes
         actual:   no (keep-when format at none, skipped-when format at 277, BOOTSTRAPPED at 292)
    FAIL AC-11: configuring.md's kinds table has the keep-when row once, straight after skipped-when's
         expected: yes
         actual:   no (keep-when row at none, skipped-when row at 30)
    FAIL AC-7: --audit fails a keep-when line that names no configured gate, naming it
         expected: 1
         actual:   0
```

After that run, one helper (`hline69`) was rewritten from `printf | grep -m1 |
cut` to a here-string, because `check-sigpipe.sh` flagged it
(`gates.test.sh:3324: pipeline into an early-exit reader under pipefail`); it
now reports 0 findings over 51 files. The helper's output was checked directly
(`4` for a header on line 4, empty for an absent one). `check-grep-count.sh`:
0 findings.

`bash scripts/gates.sh --fast`: every gate in this repository is
UNCONFIGURED (`BOOTSTRAPPED=no`), `All required gates passed (0 ran, 5
unconfigured, 0 known).`, exit 0 - the shape expected here (PO-3): the
self-test suites are the judge, not a gate.

### One line per test (AC map)

- **AC-1** - kept file exists, exactly one per matching run; name
  `sig.000001.<failed.log's # run: without - and :>.log`; body `tail -n +9` is
  `cmp`-identical to `<id>.log`; earlier kept file byte-identical after a later
  run with and without a signature; noevidence, blocked, environment outcomes
  each kept; 20,001-line log with the signature on line 1 is kept, body
  identical.
- **AC-2** - all eight header lines exactly (Contract shape); lines 2-5 equal
  the same run's `failed.log` lines 2-5; line 4 equals an independent
  `rev-parse --short HEAD` (+ note when dirty); line 5 equals an independent
  `gate_tree_hash`; first-in-manifest-order regex named when two match, one
  file; `# line:` is the first line *that* regex matched; escaped regex verbatim.
- **AC-3** - no-signature failing run: `kept/` byte-identical, no signature
  line, `failing log kept:` once, `failed.log` header and body as HARNESS-027;
  a matching run still writes `failed.log` and prints `failing log kept:`.
- **AC-4** - pass with the signature in its log, `--gate after`, `--list`,
  `--audit`, `--fast` (slow gate): `kept/` unchanged (snapshot compare), no
  signature line.
- **AC-5** - 5 `coverage-core` then 6 `coverage`: exactly `000002..000006`
  for coverage, oldest output in no file, other four byte-identical, all five
  `coverage-core` unchanged (snapshot taken before any coverage run), 10 files
  starting `coverage`.
- **AC-6** - no `keep-when` keeps nothing (and no file of any name); another
  gate's line never keeps it; `ZEBRA-[0-9]+` keeps and is named; `(QUAGGA|OKAPI)
  [0-9]+` survives whole; `zebra-42`/`Zebra-42` against `ZEBRA-[0-9]+` keeps
  nothing; `gates.sh` contains none of `Windows fatal exception`, `Unknown C++
  exception`, `Unknown C\+\+ exception`, `ZEBRA-`, `QUAGGA|OKAPI`.
- **AC-7** - `FAIL %-12s a \`keep-when\` line names no configured gate` /
  `... has no pattern`, each with `1 manifest problem(s).` and exit 1; shipped
  conf: format line once, after `skipped-when`'s format line and before
  `BOOTSTRAPPED=`, a `#   keep-when | <id> | ...` example between them, no live
  line, `--audit` passes with exit 0 and no `FAIL`; the fixture conf has none;
  three goldens pinned by blob (`336b0ed`, `8569947`, `283d6b1`).
- **AC-8** - `--list` prints `printf '%-12s %-9s %-6s keep-when: %s'` once per
  regex, in manifest order, between the gate's line and the next gate's line;
  exactly two such lines in all (none under `none`).
- **AC-9** - exactly one `signature log kept: .claude/state/gate-logs/kept/<file>
  (matched: <regex>)` per kept file, after `failing log kept:`, before the next
  `=== gate:`; none when nothing is kept; the eviction run prints exactly one
  line naming `kept/`.
- **AC-10** - with/without a match, and with/without an eviction: exit status,
  summary (durations normalised), `RESULT=`/`FULL=`, `## Gate results` with
  `run:` masked, all identical.
- **AC-11** - README row via `failed_row` (settings suite); configuring.md row
  `    keep-when    | <gate id> | <regex of a failure nobody has explained yet>`
  on the line after the `skipped-when` row, and the line
  ``Nine more kinds, each explained in the skill and in `project.conf`'s own``.

### What the tests pin (the "export shape" of a bash feature)

Stated as fact - an assertion already compares against each of these:

- stdout line: `signature log kept: .claude/state/gate-logs/kept/<id>.<seq6>.<YYYYMMDDTHHMMSSZ>.log (matched: <regex verbatim>)`.
- file name: `^<id>\.[0-9]{6}\.[0-9]{8}T[0-9]{6}Z\.log$`, stamp = the run's
  `# run:` with `-` and `:` removed, seq from `000001`, max+1, per gate.
- header lines 1-8 exactly as the Contract's block; `# outcome:` is the word
  `fail`, `noevidence`, `blocked` or `environment`.
- `--list`: `printf '%-12s %-9s %-6s keep-when: %s\n' "" "" "" "$regex"`.
- `--audit`: `FAIL %-12s a \`keep-when\` line names no configured gate` and
  `FAIL %-12s a \`keep-when\` line has no pattern`, each incrementing `fails`.
- README: a row matching
  `^\| \`gate-logs/kept/\*\.log\` +\| \`scripts/gates\.sh\` +\|.*\| yes +\|$`.
- shipped `project.conf`: the whole line
  `# Format:  keep-when | <gate id> | <extended regex>` exactly once, after the
  skipped-when format line and before `BOOTSTRAPPED=`; a comment line matching
  `^#[[:space:]]+keep-when[[:space:]]*\|[[:space:]]*[a-z]` between it and
  `BOOTSTRAPPED=`; no line matching `^[[:space:]]*keep-when[[:space:]]*\|`. The
  Contract's block satisfies all three (checked by splicing it into a copy).
- `configuring.md`: the row exactly, directly after the `skipped-when` row, and
  the sentence's first line with `Nine`.

**Not constrained**, so GREEN's choice: where the `keep-when:` lines sit
among a gate's other `--list` lines (only that they are under it, in order);
whatever eviction prints on stderr; the name of `KEEP_PER_GATE` and of the
keep function (nothing greps for them); the README paragraph's wording; how
`<seq>` is computed, provided the anchored glob is used.

### Tests that pass on arrival, and what earns them

75 of the 168 new assertions are green in RED. They are of three kinds:

1. **Controls** that make a red one mean something (`AC-1 control: sig
   failed`, `AC-6 control: the reader finds '<needle>' in this suite`, `AC-7
   control: the blocked-when check this wording copies fires`, `AC-7 control:
   the live-line reader counts two live lines and not the comment`, `AC-8
   control: --list prints lst's blocked-when line`, `AC-10 control: the run was
   recorded into T-1`, `AC-11 control: configuring.md has the skipped-when row`,
   ...). Each was observed green against the condition it controls for.
2. **Absence claims that hold vacuously with no code**: AC-3's
   no-signature-run block, all of AC-4, AC-6's "keeps nothing" and "gates.sh
   contains no ..." lines, AC-5's "oldest output in no file" and
   "coverage-core unchanged" (each paired with a control that is red now and
   must go green), AC-10's eight equality assertions, AC-7's "no live line",
   shipped `--audit` passes, and the blob pins. **These are earned by DV-1 and
   DV-2 (GATES), not in RED** - there is no keep step to mutate yet.
3. **HARNESS-027's block**, unchanged and green, which is AC-3's "every
   HARNESS-027 assertion passes unmodified".

### Negative controls: expected values for GREEN to confirm

The suite does not fail at import - bash - so every control below **ran** in
RED; the "RED measured" column is that run. What GREEN must confirm is the
right-hand column against the shipped `gates.sh`.

| Control | What it guards | RED measured | GREEN must measure |
|---|---|---|---|
| AC-1 large log: `status-based` vs `capture-based` decision on the 20,001-line log, signature line 1 | the SIGPIPE pin | outside the suite, same `clean_log`, `set -o pipefail`: `clean_log \| grep -Em1` status **0/10** match; `clean_log \| grep -Eqm1` **0/10**; `k="$(clean_log \| grep -Em1)"; [ -n "$k" ]` **10/10**; at 6,000 lines also 0/10 vs 10/10. File 348,931 bytes from `awk` directly | `AC-1: a 20,001-line log ... is kept` = 1; an implementation deciding on the pipeline's status keeps nothing and this goes red |
| `AC-1 control: big's log is the 20,001-line log, signature first` | the fixture really is the large log | `20001 Windows fatal exception: code 0x8007000e` (green) | same |
| AC-3 decoy: `windows fatal exception, in lower case` vs `Windows fatal exception` | case-sensitive matching | kept/ `unchanged` (vacuous now) | `unchanged`, and `AC-3 control: the snapshot holds the three kept sig files` = 3 (red now: 0) |
| AC-4 pass with signature | keep only on a non-pass | kept/ `unchanged`, 0 signature lines (vacuous) | `unchanged`, 0; under DV-2's mutation **6** go red |
| AC-5: snapshot of 5 coverage-core taken before any coverage run; prefix control | `<id>*` glob eviction | `same69 core5 coverage-core` = `unchanged` (both empty); `prefix69 coverage` = 0 (red; wants 10) | `unchanged` with 5 names; 10; `seqs69 coverage` = `000002 000003 000004 000005 000006` |
| AC-6 `nokw` (no keep-when, every signature in its log) | signatures from keep-when only | `kn69 nokw` = 0, `prefix69 nokw` = 0 | 0, 0 |
| AC-6 `lc` (`zebra-42`, `Zebra-42` vs `ZEBRA-[0-9]+`) | case-sensitive | 0, 0 | 0, 0 - while `zebra` (same regex, `ZEBRA-42`) = 1 |
| AC-6 reader controls | the gates.sh grep can find a needle | 5/5 `yes` against this suite | same |
| AC-7 live-line reader on a 4-line conf (2 live, 1 indented, 1 comment) | the "no live line" reader | 2 | 2; shipped conf 0 |
| AC-7 blocked-when audit control | the wording/padding reader | 1 | 1; keep-when lines 1 each |
| AC-10 `a10` vs `b10` (match vs none), `c10` vs `d10` (no eviction vs eviction) | keeping changes no verdict | all four `identical` (no keep happens now, so this is vacuous) and rc equal | all four `identical` **with** `kn69 g10` = 1 after a10 and b10, and seqs `000001..000005` then `000002..000006` |

### Deferred verifications: declined in RED

- **DV-1 (keep step neutralised)** - **declined: cannot run in RED**; there is
  no keep step to remove. Owner GATES. Prediction: the assertions that are red
  now, minus the 14 that do not depend on a file being kept (AC-8 x4, AC-7
  audit x6, AC-7 shipped format/example x2, AC-11 configuring.md x2) =
  **79 red of 850** if the neutralisation also skips eviction (it has nothing
  to evict); AC-1, AC-2 and AC-9 are among them.
- **DV-2 (keep also on a pass)** - **declined: cannot run in RED**. Owner
  GATES. Prediction: **6 red** - `AC-4: a pass whose log matches a signature
  leaves kept/ unchanged`, `AC-4: and prints no signature line`, and the four
  later `same69 r5` comparisons (`--gate after`, `--list`, `--audit`,
  `--fast` leave kept/ unchanged), because the snapshot was taken before the
  pass. Downstream measured 6 on the equivalent block.
- **DV-3 (`keep-when | nosuch | x` appended to the shipped manifest)** -
  **declined: cannot run in RED**; `--audit` has no keep-when check yet, so it
  would print `Manifest audit passed.` (that is the defect, not the probe).
  Owner GATES.

### What GREEN must know

- **Sigpipe re-pin.** `sigpipe.test.sh` C-5 pins `scripts/gates.sh:77:BOOTSTRAPPED="$(grep`
  and `scripts/gates.sh:651:why="could not launch: $(`; both move. Re-pin to
  `grep -n 'BOOTSTRAPPED="\$(grep\|could not launch: \$(' scripts/gates.sh`
  as the Contract says. RED did not touch that file.
- **Floors.** `gates` 682 -> **850** executed, `settings` 70 -> **71**.
  `floors.conf` is a minimum, so nothing fails without the raise; the
  Contract leaves it to GATES.
- **AC-6's grep of `gates.sh`.** Any comment GREEN writes on the kind must not
  quote `Windows fatal exception`, `Unknown C++ exception` (either spelling),
  `ZEBRA-` or `QUAGGA|OKAPI` - use the Contract's `SEGFAULT in worker` example
  if one is wanted.
- **The `nev`/`blk`/`env` scenario** is new relative to downstream: AC-1 says
  "did not pass" covers every non-pass outcome, so the keep step must sit
  inside `if [ "$outcome" != pass ]` and read `$outcome`, not only `fail`.
- **Matching** must be the captured-line form (Contract, "Matching"); the large
  log assertion is the one that catches the status form, and on this host the
  status form misses 10 of 10 times.
- The suite is slow on a contended Windows host (26 min locally); run
  `bash .claude/tests/gates.test.sh` once, not per edit, and use
  `settings.test.sh` (seconds) for the README row.

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
