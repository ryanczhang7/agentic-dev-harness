---
id: HARNESS-083
title: A gate loosened in project.conf during GREEN or GATES is refused unless the story declares it
slug: a-gate-loosened-in-project-conf-during-g
epic: 
type: feature
status: in-progress
phase: RED
branch: story/HARNESS-083-a-gate-loosened-in-project-conf-during-g
depends_on: [HARNESS-081]      # reuses 3j's commit walk and the ## Suppressions escape hatch
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/harness/VERSION, .claude/skills/quality-gates/SKILL.md]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

GitHub issue #132, third cut. The issue's third family is "a coverage or
other gate threshold lowered in config, or a gate's `evidence` line removed
from `project.conf`". That is not a needle over added lines: a lowered number
is only visible by comparing the line **before** with the line **after**, the
way 3i compares a manifest's two sides, and the file it lives in is one the
classifier calls `harness`, which HARNESS-081's rule deliberately never
reads.

`project.conf` is where this harness keeps every gate's command, severity,
`evidence`, `floor`, `covers`, `discovery`, `slow` and `ondemand` lines, so
for the gates themselves the question has one answer regardless of stack - and
in this harness most numeric thresholds are flags on the gate command line in
that same file (`--fail-under-lines 80`, `--cov-fail-under=80`,
`--coverage.thresholds.lines=80`). `project.conf`'s own comments already say
"never lower [a floor] to make a gate pass"; `gates.sh --audit` refuses a
waiver on a required gate; nothing refuses a GREEN or GATES commit that
deletes the `evidence` line, lowers the floor, or turns `required` into
`optional`. This story makes those loud, in the same block and with the same
escape hatch as HARNESS-081.

Thresholds that live in a stack's own configuration - `vitest.config.*`
(classified `test` by `paths.conf`), `fail_under` in `pyproject.toml`
(`manifest`), `.coveragerc`, a `[lints]` table in `Cargo.toml` - are **not**
in this story; which of them are judgeable, and in which category, is a
question put to the user in the planning report. The gate that fails if this
story breaks is `bash scripts/selftest.sh boundaries`.

## Acceptance criteria

- **AC-1** — Given a GREEN commit that deletes an `evidence | unit | ...` line
  from `.claude/harness/project.conf`, when `bash scripts/check-boundaries.sh
  main` runs, then it exits non-zero and prints one `FAIL` line naming the
  rule id `gate-loosened`, the short commit, the phase, the gate id `unit`,
  and what changed (`evidence line removed`). The same at `GATES`, and the
  same for a deleted `floor`, `covers` or `discovery` line, each named by
  kind.
- **AC-2** — Given a GREEN commit that lowers `floor | unit | 40` to `floor |
  unit | 12`, when `check-boundaries.sh` runs, then it is refused with
  `floor lowered 40 -> 12`. *Control:* the same commit **raising** it to `60`
  is not refused (tightening is silent), and neither is a commit that adds a
  `floor` line where none existed.
- **AC-3** — Given a GREEN commit that changes `gate | coverage | required |`
  to `gate | coverage | optional |`, or deletes a `gate |` line outright, when
  `check-boundaries.sh` runs, then it is refused naming the gate and
  `required -> optional` or `gate removed`. *Control:* `optional -> required`
  and a newly added gate line are not refused.
- **AC-4** — Given a GREEN commit that edits a gate's command so that a
  threshold flag's number goes down - any of `--fail-under[-a-z]*[ =]N`,
  `--cov-fail-under[ =]N`, `--coverage.thresholds.[a-z]*[ =]N`,
  `--min-coverage[ =]N`, `--threshold[ =]N` - when `check-boundaries.sh` runs,
  then it is refused naming the gate, the flag and `N_before -> N_after`.
  *Controls:* the number going up, a flag added where none was, and a command
  change that leaves every such number equal (a renamed package, a new `--`
  option) are not refused.
- **AC-5** — Given a GREEN commit adding a `slow |`, `ondemand |` or `waiver |`
  line naming a gate that is `required` on the **before** side, when
  `check-boundaries.sh` runs, then it is refused naming the gate and the line
  kind. *Control:* the same line on an optional gate is not refused by this
  rule (it is `--audit`'s business, and already is).
- **AC-6** — Given the AC-1 commit and a `## Suppressions` line carrying
  `.claude/harness/project.conf`, `[gate-loosened]` and `approved by`, when
  `check-boundaries.sh` runs, then it is accepted through HARNESS-081's
  mechanism with its `ok` line.
- **AC-7** — Given a GREEN commit touching `project.conf` in none of the ways
  above - a comment edited, a `task |` line added, a gate command changed with
  no threshold in it - when `check-boundaries.sh` runs, then 3j prints no
  `FAIL` and its `ok` line counts the commit as judged.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/harness/VERSION`, `.claude/skills/quality-gates/SKILL.md`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says.

**C-1. Where.** Inside HARNESS-081's 3j walk, a second per-path branch:
when `"$f"` is `.claude/harness/project.conf` (by **path**, not by category -
it is `harness`, and 3j's category test stays as HARNESS-081 wrote it), the
before and after texts come from `git show "$c^:$f"` and `git show "$c:$f"`
as 3i reads a manifest, and `project_conf_loosenings()` compares them.

*Pinned at PLANNED -> RED (2026-10-30) against the shipped 3j:* today the
walk builds `sup_paths` from `classify` = `source|config` only and
`continue`s a commit with none, **before** it reads the phase, so a commit
touching only `project.conf` is never reached. GREEN adds the path to
`sup_paths` by an exact-path test **beside** the `classify` case line (that
line is left byte-for-byte, because HARNESS-082's DV-2 mutates it), and the
per-path loop sends `project.conf` to `project_conf_loosenings` instead of
`suppression_hits`. Consequences pinned: a GREEN/GATES commit that touches
only `project.conf` is a **judged** commit (counted in 3j's `ok ... (N
commit(s) judged)` line - AC-7); a commit whose story is not readable gets
3j's existing `note`; the parent-phase arm (`REVIEW, after GATES`) applies
as it does to source. A merge commit has no `--name-only` paths and is
skipped, as today. RED checks that no existing assertion counting judged
commits moves because of this (no existing GREEN/GATES fixture commit
touches `project.conf` is the expectation; if one does, say so).

One `problem` per finding, rule id `gate-loosened`, exactly:

    FAIL  story <sid>: commit <7> (<PHASE>) loosened a gate in '.claude/harness/project.conf' [gate-loosened]: <finding>. A gate is never loosened to reach green; if this is deliberate, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason.

followed, as HARNESS-081's refusal is, by ` The ## Suppressions line naming
'.claude/harness/project.conf' is missing <...>.` when a partial entry names
the path. `<finding>` is `<id>: <what>` with the exact `<what>` per C-2. A
declared finding prints HARNESS-081's `ok    suppression [gate-loosened] in
'.claude/harness/project.conf' is declared in ## Suppressions`, once per
path and id as today.

**C-2. `project_conf_loosenings <before-file> <after-file>`**, one awk, prints
one line per finding, `<gate id>\t<what>\t<before>\t<after>`. It parses only
the line kinds `project.conf`'s header documents, with the same field
splitting `gates.sh` uses (`|`, fields trimmed). Findings:

| what | condition |
|---|---|
| `evidence line removed` | gate had an `evidence` line before, has none after |
| `floor line removed` / `covers line removed` / `discovery line removed` | likewise, per kind; `covers` per glob, `discovery` per id |
| `floor lowered` | both sides have `floor \| g \| N`, and N_after < N_before (numeric) |
| `required -> optional` | severity field changed that way |
| `gate removed` | a `gate \| g` line before, none after |
| `threshold lowered` | the gate's command on both sides has the same flag from AC-4's list and its number went down; several flags are several findings |
| `threshold removed` | the gate exists on both sides and its command had a flag from AC-4's list before and has no such flag (by name) after; a flag present only **after** (added) is no finding |
| `slow added on required gate` / `ondemand added on required gate` / `waiver added on required gate` | the line is on the after side only, and the gate is `required` on the **before** side |

*Amended in RED (2026-10-30), approved by the user ("Refuse it"):* the first
cut said "a flag present on one side only is no finding", so deleting
`--fail-under-lines 80` from a gate command outright was silent - the same
weakening as deleting a `floor` line, which is refused. The test-developer
raised it. No acceptance criterion changes: AC-4 refuses a lowered number
and its controls (a flag added, numbers equal) stand; AC-7's "a gate command
changed with no threshold in it" has no threshold on either side.

Nothing else is a finding (AC-7). A `-` evidence line (`evidence | g | -`)
replacing a real regex **is** `evidence line removed` - the declaration that
no evidence exists is the same weakening - and RED pins that case. Numbers
are compared as numbers; `80.0 -> 80` is not a lowering. A missing
`project.conf` on the before side (the commit created it) produces no
findings.

*Pinned at PLANNED -> RED (2026-10-30):*

- **Parsing**, as `gates.sh` does (lines 170-200): skip blank lines and
  lines whose trimmed text starts `#`; strip a trailing CR; a line without
  `|` is skipped (`BOOTSTRAPPED=...`); `kind` = field 1 and `id` = field 2,
  each trimmed; the value is **the rest from field 3**, `|`s kept, trimmed
  (a regex may contain `|`). For `gate` lines, severity = field 3 and the
  command = the rest from field 5. `discovery`'s field 2 is a discovery id,
  not a gate id; its `<id>` in a finding is that discovery id.
- **The `<what>` strings, exactly** (`<id>:` precedes each):
  `evidence line removed`; `floor line removed`;
  `covers line removed <glob>` (one per glob gone); `discovery line removed`;
  `floor lowered <before> -> <after>`; `required -> optional`;
  `gate removed`; `threshold lowered <flag> <before> -> <after>` (flag as
  written, e.g. `--cov-fail-under`); `threshold removed <flag> <before>`
  (e.g. `coverage: threshold removed --fail-under-lines 80`); `slow added on required gate`,
  `ondemand added on required gate`, `waiver added on required gate`.
- **A gate removed reports only `gate removed`** for that id - its evidence,
  floor and covers lines go with it and are not reported again.
- **Several lines of one kind for one gate** (evidence, floor): the gate
  "has" that kind if any line of it exists; `floor` compares the first line
  on each side. A `-` evidence line counts as no evidence.
- **Threshold flags**: the flag name is the matched spelling up to the
  `[ =]` (`--fail-under-lines`, `--cov-fail-under`,
  `--coverage.thresholds.lines`, `--min-coverage`, `--threshold`), the number
  `[0-9]+(\.[0-9]+)?`; compare the first occurrence of each flag name on
  each side; one finding per flag name lowered.
- **Order** of findings: the after-file's gate order is not meaningful;
  findings print in the order of the **before** file's lines, so the output
  is deterministic.
- **Severity**: a gate is "required" on a side when that side's `gate`
  line's field 3 trimmed is exactly `required`.

**C-3. What the escape hatch names.** The entry's path is
`.claude/harness/project.conf` and the rule id is `gate-loosened`, so one
declared line covers every loosening in that file in the PR - deliberate: a
story that genuinely splits a suite in two lowers a floor and changes an
evidence regex together, and is approved as one decision. The reason on the
line is where it says which.

**C-4. Oracle partition.** All **mechanical**. The table in C-2 is
**settled** as to which kinds are findings; the flag list in AC-4 is settled
and RED may add a spelling it finds in a stack profile
(`.claude/skills/stack-profiles/reference/*.md`) with a note, not remove one.

**C-5. Docs.** `quality-gates` SKILL.md's triage section gains one paragraph:
a lowered floor or removed evidence in GREEN or GATES is refused by CI and
declared in `## Suppressions`, never done quietly. `VERSION` bumps in GREEN.

**C-6. Self-test.** A `conf_story <phase> <before> <after>` helper in
`boundaries.test.sh` in the shape of `manifest_story`, and one `describe`
per AC. The finding table in C-2 is tested one row per case with its control
on the same fixture. Floor raised in RED.

**C-7. Callers of what changes.** No exported name or signature changes.
`suppression_declared` is reused as is; the 3j loop body gains the
`project.conf` branch; `project_conf_loosenings` is new and called only from
3j. `grep -rn "sup_paths\|suppression_declared" --include=*.sh` (checked
2026-10-30) finds them only in `scripts/check-boundaries.sh`. The suite
drives the script, never the functions.

**Test-only dependencies:** none.

## Deferred verifications

**DV-1 (defect put back; central claim; AC-2). Owner: GATES.** With GREEN in
the tree, `bash scripts/mutate.sh scripts/check-boundaries.sh '<expr>' --
bash scripts/selftest.sh boundaries`, where `<expr>` flips the floor
comparison from `<` to `!=` - the mutant that makes **raising** a floor loud
too, which is the exact opposite of "tightening is silent". AC-2's control
**must** go red and AC-2's refusal stay green. Paste the red, the restore, a
green run.

**DV-2 (the rule against a real line; needle rule). Owner: GATES.** The
real `project.conf` of this repository has `ondemand | mutation | ...` on an
`optional` gate and no `floor` line. Build the real-tree probe from it rather
than a fixture: in a scratch branch of **this** repository with a fixture
story committed at GREEN, use `mutate.sh` on the real
`.claude/harness/project.conf` to change the real `gate | lint | required`
line to `optional`, commit under that story, run `check-boundaries.sh`
against `main`, and paste that it names `lint` and `required -> optional`;
then the same with the real `ondemand | mutation` line, which **must not** be
a finding (the gate is optional on the before side). Restore and discard the
scratch branch; paste both runs. If the scratch-branch mechanics turn out
heavier than a fixture, say so and WAIVE this one with the reason - the
fixture corpus in C-6 is copied from the real file's lines, which is the
second-best form of the same probe.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-083` from `.claude/harness/models.conf`.
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

- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1** (2026-10-28). The story was cut and the Contract, Deferred verifications and Out of scope written in this dispatch; no override reported.
- PLANNED -> RED refinement - `lead-po` (the orchestrating session), resolved **claude-opus-5-5** (2026-10-30): C-1 pinned against the shipped 3j walk and message, C-2's parsing and `<what>` strings, C-7 added.

**Oracle partition:** every criterion is mechanical (an exact message, an exit status, a table row); the needle/finding tables are settled and RED may tighten but not drop a row. See the Contract.

## Out of scope

- **Thresholds in stack configuration** - `vitest.config.*` `thresholds`
  (classified `test`), `fail_under` under `[tool.coverage.report]` in
  `pyproject.toml` (`manifest`), `.coveragerc`, `.nycrc`, `stryker.conf.*`
  `thresholds.break`, `Cargo.toml` `[lints]` levels, an ESLint rule set to
  `off`. Each is a different file format and a different category, and two of
  the categories (`test`, `manifest`) are ones GREEN cannot even write under the
  lock, so the real exposure is GATES and SCAFFOLD. Open question for the
  user in the planning report; a follow-up story per format if wanted.
- **`project.conf` changes in SCAFFOLD** (the bootstrap story, which writes
  the whole file) and in RED, REVIEW, DONE. The walk is HARNESS-081's and
  judges GREEN and GATES only.
- **`covers` globs narrowed, `evidence` regexes weakened, `ci-factor`
  changed.** A regex that still matches is not comparable mechanically; a
  removed line is. `gates.sh --audit` and the quality-gates skill carry the
  prose rule for the rest.
- **`BOOTSTRAPPED`, `task |`, `blocked-when`, `skipped-when`, `keep-when`
  lines.** None of them lowers what a gate demands; `blocked-when` is the one
  a reader might expect here, and `project.conf`'s own header already refuses
  adding one to silence a failure - in prose. Making that mechanical means
  deciding what a "silencing" pattern looks like, which this story does not.
- **The `gates.sh` runtime.** Nothing here changes how gates run or how
  `--audit` judges the file; this is CI's read of the commit.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

One level: integration, through `bash scripts/check-boundaries.sh main` in a
real two-branch fixture repository (`.claude/tests/boundaries.test.sh`), as
every 3j case is. The suite drives the script, never the function (C-7).

Nine new describes, all marked HARNESS-083, appended after HARNESS-082's last
3j describe and before `summary` (the ninth, `AC-4, threshold removed`, added in
RED after the user approved C-2's `threshold removed` row):

| Describe | AC / clause | Cases |
|---|---|---|
| `HARNESS-083: ... - the fixture` | premise | a spike branch whose GREEN commit edits a project.conf comment exits 0 with no FAIL |
| `HARNESS-083 AC-1` | AC-1, C-2 rows 1-2 | `evidence \| unit` deleted at GREEN and at GATES; `floor \| unit` deleted; one of unit's two `covers` globs deleted (named by glob); `discovery \| platform` deleted (named by discovery id); `evidence \| unit \| <regex>` -> `-` |
| `HARNESS-083 AC-2` | AC-2, C-2 row 3 | floor 40 -> 12 refused; controls 40 -> 60, a new `floor \| coverage`, 40 -> 40.0 |
| `HARNESS-083 AC-3` | AC-3, C-2 rows 4-5 | coverage required -> optional; unit gate removed with its evidence, floor and both covers lines (only `gate removed`); controls integration optional -> required, a new `typecheck` gate |
| `HARNESS-083 AC-4` | AC-4, C-2 row 6 | one row per flag spelling (5); two flags lowered in one command (2 findings); controls raised, flag added where none was, renamed package + new option with equal numbers, 80.0 -> 80 |
| `HARNESS-083 AC-4, threshold removed` | AC-4, C-2 `threshold removed` row (amended in RED) | `--fail-under-lines 80` deleted from the rust coverage gate; `--cov-fail-under=100` deleted from the python profile's gate verbatim; one flag deleted and the other lowered in one command (2 findings, `1\|2`, relative order not pinned); control: the coverage gate removed outright, flag and all, reports only `coverage: gate removed` (`1\|1`) |
| `HARNESS-083 AC-5` | AC-5, C-2 row 7 | `slow \| unit`, `ondemand \| coverage`, `waiver \| build` added on gates required before; control: this repository's own `ondemand \| mutation` line on the optional mutation gate |
| `HARNESS-083 AC-6` | AC-6, C-3 | the AC-1 commit with a whole `## Suppressions` entry (rc 0, ok line once); an entry naming the path with `[noqa]` (refused, whole line with HARNESS-081's partial-entry suffix) |
| `HARNESS-083 AC-7` | AC-7, C-1, C-2 | a comment edited plus a commented example `covers` line deleted; a `task \| dev` line added; a gate command changed with no threshold; project.conf created by the GREEN commit (missing before) |
| `HARNESS-083 C-1/C-2` | C-2 order, C-1 parent-phase arm | two findings in one commit print in the before-file's order; evidence deleted by the commit that sets REVIEW after GATES is refused naming `REVIEW, after GATES` |

Every fixture project.conf is `GL_BASE` or a one-line edit of it, and
`GL_BASE` is built from real lines: this repository's header and
`slow`/`ondemand`/`task` lines, the node profile's gate commands, evidence,
`floor`, `covers` and `discovery` lines, the rust profile's coverage gate
(`--fail-under-lines`, rust-cargo.md line 12) and the python profile's
(`--cov-fail-under=`, python-uv.md line 11). The stack profiles carry no other
spelling of AC-4's flags, so C-4's list is unchanged; `--min-coverage`,
`--coverage.thresholds.lines` and `--threshold` fixtures use plausible tool
lines (`diff-cover`, `vitest`, `jscpd`), and the two-flag case uses
`--fail-under-functions`, which AC-4's `--fail-under[-a-z]*` covers.

**Existing judged counts do not move.** Checked before writing: no GREEN or
GATES fixture commit in the 3j describes touches `.claude/harness/project.conf`
(they write `src/`, the story, `scripts/x.sh` and `tests/a.test.ts`), and main's
project.conf at that point is `BOOTSTRAPPED=no`. The full run confirms it: all
359 pre-existing assertions pass.

## Handoff: RED -> GREEN

**Model.** Dispatched as `test-developer`, which declares `opus`; ran as
claude-opus-5-5. No override.

**Command.**

    bash .claude/tests/boundaries.test.sh      # or: bash scripts/selftest.sh boundaries

The whole suite took 50m51s locally with the ninth describe (38m41s for the first pass; host under load). For iteration, a
scratch subset (lines 1-109 with line 9 pointed at the real `_lib.sh`, then the
3j fixture describe up to its premise, then the HARNESS-083 section) ran in
about 4 min.

**Red on arrival, against the shipped check-boundaries.sh (release 101):**

    boundaries: 375 passed, 67 failed
    rc=1

All 67 failures are HARNESS-083 assertions (`grep "^    FAIL" | grep -vc HARNESS-083`
= 0); all 359 pre-existing assertions pass; no bash error and no `FIXTURE BUG`
line in the output. The shape of each red is the right one - the rule is
absent, so no refusal is printed, the run exits 0, and 3j never counts a
project.conf-only commit:

    HARNESS-083 AC-1: a removed evidence, floor, covers or discovery line is refused, by kind, in GREEN and GATES
      FAIL HARNESS-083 AC-1 (GREEN): evidence | unit deleted: refused by the whole line naming 'unit: evidence line removed'
           expected: 1
           actual:   0
      FAIL HARNESS-083 AC-1 (GREEN): evidence | unit deleted: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
           expected: 1|1
           actual:   0|0
      ...
    HARNESS-083 AC-2: a floor lowered is refused with both numbers; raised or newly added, it is not
      FAIL HARNESS-083 AC-2: floor | unit 40 -> 12: refused by the whole line naming 'unit: floor lowered 40 -> 12'
      FAIL HARNESS-083 AC-2: floor | unit 40 -> 12: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
      FAIL HARNESS-083 AC-2 control: floor | unit 40 -> 60 (tightening is silent): and 3j counts the project.conf commit as judged
           expected: 1
           actual:   0
      ...
    HARNESS-083 AC-4, threshold removed: a threshold flag deleted from a gate command is refused, with the number it had
      FAIL HARNESS-083 AC-4 threshold removed: --fail-under-lines 80 deleted from the rust coverage gate: refused by the whole line naming 'coverage: threshold removed --fail-under-lines 80'
           expected: 1
           actual:   0
      FAIL HARNESS-083 AC-4 threshold removed: --fail-under-lines 80 deleted from the rust coverage gate: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
           expected: 1|1
           actual:   0|0
      FAIL HARNESS-083 AC-4 threshold removed: --cov-fail-under=100 deleted from the python coverage gate: refused by the whole line naming 'coverage: threshold removed --cov-fail-under 100'
      FAIL HARNESS-083 AC-4 threshold removed: --cov-fail-under=100 deleted from the python coverage gate: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
      FAIL HARNESS-083 AC-4 threshold removed: one flag deleted, one lowered - --fail-under-lines is removed
      FAIL HARNESS-083 AC-4 threshold removed: one flag deleted, one lowered - --fail-under-functions is lowered
      FAIL HARNESS-083 AC-4 threshold removed: one flag deleted, one lowered - rc|FAIL lines
           expected: 1|2
           actual:   0|0
      FAIL HARNESS-083 AC-4 threshold removed control: gate | coverage removed outright, flag and all: refused by the whole line naming 'coverage: gate removed'
      FAIL HARNESS-083 AC-4 threshold removed control: gate | coverage removed outright, flag and all: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
           expected: 1|1
           actual:   0|0
    HARNESS-083 AC-6: a loosening declared in ## Suppressions is accepted by HARNESS-081's hatch, and only a whole declaration
      FAIL HARNESS-083 AC-6: and the rule says project.conf's [gate-loosened] is declared, once
      FAIL HARNESS-083 AC-6: an entry naming the path with another rule id is refused, saying what it is missing
      FAIL HARNESS-083 AC-6: the partial entry - rc|FAIL lines
    HARNESS-083 AC-7: a project.conf change that loosens nothing is not refused, and the commit is judged
      FAIL HARNESS-083 AC-7: a comment edited, and a commented example covers line deleted: and 3j counts the project.conf commit as judged
      FAIL HARNESS-083 AC-7: a task | dev line added: and 3j counts the project.conf commit as judged
      FAIL HARNESS-083 AC-7: a gate command changed with no threshold in it: and 3j counts the project.conf commit as judged
      FAIL HARNESS-083 C-2: project.conf created by the GREEN commit, nothing before it: and 3j counts the project.conf commit as judged
    HARNESS-083 C-1/C-2: two findings in one commit print in the before-file's line order; the parent-phase arm applies
      FAIL HARNESS-083 order: required -> optional, then floor lowered - both whole lines, in the before file's order
      FAIL HARNESS-083 order: rc|FAIL lines
      FAIL HARNESS-083 C-1: evidence | unit deleted by the commit that sets REVIEW after GATES: refused by the whole line naming 'unit: evidence line removed'
      FAIL HARNESS-083 C-1: evidence | unit deleted by the commit that sets REVIEW after GATES: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines

    boundaries: 375 passed, 67 failed

The full output is reproducible with the command above; the 67 are: 26
refusal whole lines, 25 refusing `rc|FAIL lines` pairs (`1|1`, or `1|2` for the
two-flag, removed-plus-lowered and order cases), AC-6's ok line, the order case's two-line compare,
and the 14 controls' "judged" halves.

**`bash scripts/gates.sh --fast`** runs nothing here: every gate in this
repository's project.conf is UNCONFIGURED, mutation is ON REQUEST, `--fast`
skipped integration and build, rc 0, not recorded. The artifact is judged by
`bash scripts/selftest.sh boundaries`. `check-sigpipe.sh` (56 files, 0 findings)
and `check-grep-count.sh` (56 files, 0 findings) are clean over the tree with
the new test code in it.

**Files touched.**

- `.claude/tests/boundaries.test.sh` - the nine describes and their helpers
  (`GL_PATH`, `GL_BASE`, `GL_COV`, `GL_EVID`, `GL_FLOOR`, `GL_SLOWB`, `GL_TASK`,
  `gl_swap`, `gl_after`, `GL_ABSENT`, `conf_story`, `GL_TAIL`, `want_gl`,
  `gl_fails`, `gl_refused`, `gl_clean`).
- `.claude/tests/floors.conf` - `boundaries` 359 -> 442, with its comment entry.
- `.claude/tests/selftest.test.sh` - the hand-copied table, `boundaries 442`.
- this story: `## Test plan`, `## Handoff: RED -> GREEN`.

**One line per test** (each `gl_refused` is two assertions: the whole line,
then `rc|FAIL lines` = `1|1`; each `gl_clean` is two: `rc|FAIL lines` = `0|`,
then `want_3j_ok 1` as a whole line):

- premise - the spike fixture with a comment-only GREEN edit exits 0, no FAIL (fixture claim).
- AC-1 (GREEN), AC-1 (GATES) - `unit: evidence line removed`.
- AC-1 floor - `unit: floor line removed`.
- AC-1 covers - `unit: covers line removed src/platform/**`; the other glob, still present, is no finding.
- AC-1 discovery - `platform: discovery line removed`.
- AC-1 `-` - `unit: evidence line removed` for a regex replaced by `-`.
- AC-2 - `unit: floor lowered 40 -> 12`; controls 40 -> 60, new `floor | coverage`, 40 -> 40.0.
- AC-3 - `coverage: required -> optional`; `unit: gate removed` and nothing else for that id; controls integration optional -> required, new typecheck gate.
- AC-4 - `coverage: threshold lowered --fail-under-lines 80 -> 70`, `... --cov-fail-under 80 -> 70`, `... --coverage.thresholds.lines 80 -> 75`, `... --min-coverage 90 -> 85`, `lint: threshold lowered --threshold 5 -> 3`; two flags in one command give `--fail-under-lines 80 -> 75` and `--fail-under-functions 70 -> 60`, rc|FAIL lines `1|2`; controls raised, added, equal numbers, 80.0 -> 80.
- AC-4, threshold removed - `coverage: threshold removed --fail-under-lines 80` (rust gate, flag deleted); `coverage: threshold removed --cov-fail-under 100` (python gate verbatim, `=` spelling deleted); one command with `--fail-under-lines 80` deleted and `--fail-under-functions 70 -> 60` gives both `coverage: threshold removed --fail-under-lines 80` and `coverage: threshold lowered --fail-under-functions 70 -> 60`, each a whole line, rc|FAIL lines `1|2`; control: the coverage gate removed with its evidence and covers lines gives only `coverage: gate removed`, rc|FAIL lines `1|1` (a `threshold removed` beside it would be a second FAIL).
- AC-5 - `unit: slow added on required gate`, `coverage: ondemand added on required gate`, `build: waiver added on required gate`; control the real `ondemand | mutation` line.
- AC-6 - declared: rc|refusals `0|` and the ok line once; partial `[noqa]` entry: the whole refusal with the suffix, rc|FAIL lines `1|1`.
- AC-7 - three non-loosening edits and the created-file case, each `gl_clean`.
- order - `gl_fails` equals exactly the two whole lines, `coverage: required -> optional` then `unit: floor lowered 40 -> 12`; rc|FAIL lines `1|2`.
- C-1 parent arm - `want_gl <c> "REVIEW, after GATES" 'unit: evidence line removed'`.

**Export shape the tests pin.** There is no module import; the tests pin
printed lines and exit status.

- The refusal, exactly (one per finding, through `problem`, so it starts `FAIL  `):

      FAIL  story T-1: commit <7> (<PHASE>) loosened a gate in '.claude/harness/project.conf' [gate-loosened]: <id>: <what>. A gate is never loosened to reach green; if this is deliberate, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason.

  with `<PHASE>` = `GREEN`, `GATES` or `REVIEW, after GATES`, and, when a
  partial entry names the path, the suffix appended directly after `reason.`:

      " The ## Suppressions line naming '.claude/harness/project.conf' is missing the rule id [gate-loosened]."

  (a leading space, as HARNESS-081's `$sup_more`).
- The `<id>: <what>` strings, exactly: `unit: evidence line removed`,
  `unit: floor line removed`, `unit: covers line removed src/platform/**`,
  `platform: discovery line removed`, `unit: floor lowered 40 -> 12`,
  `coverage: required -> optional`, `unit: gate removed`,
  `<gate>: threshold lowered <flag> <before> -> <after>` with the flag up to the
  `[ =]` (`--fail-under-lines`, `--cov-fail-under`,
  `--coverage.thresholds.lines`, `--min-coverage`, `--threshold`,
  `--fail-under-functions`),
  `<gate>: threshold removed <flag> <before>` with the same flag naming and
  the before side's number as written (`coverage: threshold removed
  --fail-under-lines 80`, `coverage: threshold removed --cov-fail-under 100`),
  `<gate>: slow|ondemand|waiver added on required gate`.
- A gate removed outright reports `gate removed` and **no** `threshold removed`
  for the flags its command carried: the row's condition is "the gate exists on
  both sides", and the test counts exactly one FAIL.
- The declared line, exactly once:
  `ok    suppression [gate-loosened] in '.claude/harness/project.conf' is declared in ## Suppressions`.
- The 3j summary, now counting a project.conf-only GREEN commit:
  `ok    GREEN/GATES added no suppression (1 commit(s) judged)` on every clean
  case. Note the wording stays HARNESS-081's; the tests pin it as is.
- Exit 1 with exactly one `^FAIL` line on each single-finding branch (so the
  rule must not also print a second, differently worded refusal), and exit 0
  with no `^FAIL` on every control.
- Order: two findings from one commit print in the before file's line order
  (a `gate` line before a `floor` line).

**Not constrained** (the implementer's choice): the name, arguments and output
format of `project_conf_loosenings` - C-2's `<gate id>\t<what>\t<before>\t<after>`
is the contract's, but no test sees it; how before/after reach the awk (temp
files or here-strings); the order of two findings from ONE line (both two-flag
cases - two lowered, and one removed plus one lowered - assert each whole line
and the count, not their order; C-2's Order bullet fixes before-file LINE
order only); where an
"added on required gate" finding prints relative to before-line findings (no
case has both); what happens when GREEN deletes project.conf outright (after
side missing); several declared findings in one PR printing the ok line once
(only single-finding declared case is tested).

**Passed on arrival (16), and what earns each.** No assertion here imports a
missing module, so all of them ran - but the rule they constrain does not exist,
so the 16 green ones pass vacuously today. The premise is a fixture claim and
earns itself by the reds around it (the same fixture exits 1 the moment a rule
fires). AC-6's `rc|refusals` = `0|` is earned by the partial-entry case beside
it, which must go red. The 14 controls' `rc|FAIL lines` halves are earned by a
mutation each, which GREEN or the orchestrator runs with `scripts/mutate.sh`
against the shipped `project_conf_loosenings`:

| Control | Expected (rc\|FAIL lines; judged) | Measured on a scratch candidate of C-2 (gawk --posix) | Mutation that must turn it red |
|---|---|---|---|
| AC-2 floor 40 -> 60 | `0\|`; `want_3j_ok 1` | no findings | floor compare `<` -> `!=` (DV-1) |
| AC-2 new `floor \| coverage` | `0\|`; 1 | no findings | floor-removed test reads the AFTER side as before (an added line reads as removed) |
| AC-2 floor 40 -> 40.0 | `0\|`; 1 | no findings | compare floors as strings with `!=` |
| AC-3 integration optional -> required | `0\|`; 1 | no findings | severity test `before==required && after==optional` -> `before!=after` |
| AC-3 new typecheck gate | `0\|`; 1 | no findings | gate-removed test iterates the after file's gates |
| AC-4 --fail-under-lines 80 -> 90 | `0\|`; 1 | no findings | flag compare `<` -> `!=` |
| AC-4 --coverage.thresholds.lines added | `0\|`; 1 | no findings | report a flag present on one side only |
| AC-4 renamed package, equal numbers | `0\|`; 1 | no findings | compare the whole command string instead of the flag numbers |
| AC-4 80.0 -> 80 | `0\|`; 1 | no findings | compare flag numbers as strings with `!=` |
| AC-4 --coverage.thresholds.lines added (re-measured with `threshold removed` in the candidate) | `0\|`; 1 | no findings | report a flag present on the AFTER side only |
| AC-4 threshold removed control: coverage gate removed outright | `1\|1`, the one line `coverage: gate removed` (a refusal, so not a "judged" control) | `coverage: gate removed` only; **with** the gate-removed `continue` dropped from the candidate (`cand_gone_mut.awk`), `coverage: gate removed` **and** `coverage: threshold removed --fail-under-lines 80` (measured: fires) | report `threshold removed` without requiring the gate on the after side |
| AC-5 `ondemand \| mutation` on optional | `0\|`; 1 | no findings | drop the "required on the before side" test |
| AC-7 comment + commented `covers` example deleted | `0\|`; 1 | no findings; **with** the mutant below, `integration: covers line removed src/render/**` | strip a leading `#` and parse comment lines as data (measured: fires) |
| AC-7 `task \| dev` added | `0\|`; 1 | no findings | report any kind added on the after side |
| AC-7 gate command, no threshold | `0\|`; 1 | no findings | compare the whole command string |
| C-2 project.conf created | `0\|`; 1 | no findings; **with** `FNR == 1 { side++ }` (an empty before file has no record), 7 x `gate removed` + 1 discovery | side counting by `FNR == 1` instead of by file name (measured: fires) |

The "measured" column is a scratch candidate of `project_conf_loosenings`
written outside the tree (a plain awk run over each fixture pair that the test
helpers build, never through the suite) to check that every expected value is
reachable by one awk and that every control is silent: it printed exactly the
expected finding for every refusing fixture pair (the REVIEW-after-GATES
case was not driven separately: it is the AC-1 pair), both lines in the expected
order for the order case, and nothing for each of the 14 controls. Those
numbers are claims about a candidate, not the shipped code: confirming each
against the shipped `check-boundaries.sh` is GREEN's job, and the "judged" half
of every control is red until GREEN adds project.conf to `sup_paths`.

**Discovered, for the implementation.**

1. An empty before side is a trap. `git show "$c^:$f"` fails when the commit
   created the file; if that becomes an empty temp file, `FNR == 1` never fires
   for it and the after file is read as the before side - the candidate printed
   7 `gate removed` findings for a commit that loosened nothing. Decide the side
   by file name (`FILENAME == ARGV[1]`) or skip the comparison when the before
   side is unreadable. The created-file control catches it.
2. Inside a string regex, `\.` warns under gawk and is fragile across awks; the
   candidate used `[.]` for `--coverage.thresholds.` and the decimal part. CI's
   awk is mawk 1.3.4; the candidate ran under gawk 5.4 `--posix` (no mawk here).
3. A gate removed must suppress its own evidence/floor/covers findings even
   though those lines come AFTER the gate line in the before file: compute the
   removed set first, then walk the before lines.
4. A commented example line (`#   covers | integration | src/render/**`, the
   header shape of this repository's own file) contains `|`; skipping by
   "trimmed text starts `#`" must come before the `|` test, as `gates.sh` does.

**Doubt raised in the first RED pass, now resolved.** C-2 first said "a flag
present on one side only is no finding", so deleting `--fail-under-lines 80`
from a gate command outright was silent. Put to the orchestrator; the user
approved refusing it ("Refuse it"), C-2 gained the `threshold removed` row (see
its amendment note), and the ninth describe, `AC-4, threshold removed`, pins
it. A flag present only on the after side is still no finding, and the AC-4
"flag added where none was" control is unchanged.

**Contract amendments:** none by RED (C-2's `threshold removed` row is the
orchestrator's amendment, user-approved). One thing GREEN should know: in C-2's
table the amendment note sits between the `threshold removed` row and the
`slow/ondemand/waiver added on required gate` row, so in rendered markdown that
last row is outside the table. Its text is unchanged and still binding.

**Deferred verifications.** DV-1 and DV-2 are owned by GATES and are **not
runnable in RED**: both mutate or exercise the shipped `project_conf_loosenings`,
which does not exist yet. I did not run them. The AC-2 raise control above is
the assertion DV-1 must turn red.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return:
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

**PO decisions at PLANNED -> RED (2026-10-30):**

1. **Stack-config thresholds stay out of scope**, as the user accepted when
   HARNESS-081..083 were planned ("Accept, push", 2026-10-28). Out of scope
   lists them; a follow-up story per format if wanted.
2. **The `<what>` strings carry no parentheses** (`floor lowered 40 -> 12`)
   so AC-2's and AC-4's quoted text appears in the refusal verbatim; C-1's
   first cut had `(<before> -> <after>)`.
3. **Gate:** every gate is unconfigured on this repository; the artifact is
   judged by `bash scripts/selftest.sh boundaries`, which CI runs.
   `required_gates` stays empty. `epic:` is empty: no done-when to check.
4. **Lessons carried from HARNESS-082** into the RED brief: a refusal is
   pinned by its whole line including any partial-entry suffix, and one
   commit carrying two findings expects both.


**Phase-lock report from RED's second pass (2026-10-30), not reproduced.**
The test-developer reported the guard refusing `cd "C:/Users/.../scratchpad"
&& awk ... > candidate.awk` (a write outside the repository) as `source`.
The orchestrator fed `.claude/hooks/phase-guard.sh` that shape directly, in
both the `C:/...` (quoted) and `/c/...` spellings, with cwd
`D:\agentic-dev-harness` at phase RED: both returned rc 0 with no decision,
i.e. allowed. The agent's exact command was not recorded, so the refusal is
unexplained, not confirmed; if it recurs, capture the command verbatim and
add it to `.claude/tests/phase-guard.test.sh` as CLAUDE.md says.
