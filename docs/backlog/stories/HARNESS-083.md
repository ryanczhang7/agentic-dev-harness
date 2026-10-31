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

*Amended at GATES -> REVIEW (2026-10-31), approved by the user ("Fix all 5"),
after the diff review below; no acceptance criterion changes.* Each of these
makes the table read `project.conf` as `gates.sh` reads it, where the first
cut did not:

- **Severity.** `required -> optional` becomes `required -> <after>` for
  **any** after severity that is not exactly `required`, because `gates.sh`
  treats every such value as optional (`[ "$req" = "required" ]`) and
  `--audit` does not reject an unknown one. The pinned string for the
  `optional` case is unchanged; `advisory`, `Required` and an empty field
  print `required -> advisory`, `required -> Required`, `required -> ` (the
  empty after value, nothing after the space).
- **Evidence.** Replaces "the gate has that kind if any line of it exists"
  for evidence: compare the **first** evidence line on each side, as
  `gates.sh`'s `table_get` does. Before's first is a real regex and after's
  first is `-` or absent, so `evidence line removed`. A second evidence line
  added below the first is no finding. `floor` already compares first lines.
- **Threshold flags.** Replaces "compare the first occurrence of each flag
  name on each side" for the after side: the before value is the first
  occurrence; a finding is `threshold lowered <flag> <before> -> <after>`
  where `<after>` is the **lowest** value of that flag name on the after side,
  when it is below the before value. Argument parsers disagree on whether the
  first or last repeat wins (argparse, under pytest-cov, takes the last), so
  any lower repeat is refused. `threshold removed` is unchanged: no occurrence
  after.
- **Deleted file.** A commit that deletes `project.conf` (a rename included)
  is compared against an empty after side: one `gate removed` per gate and
  `discovery line removed` per discovery id, in before-file order. GREEN
  chose this; it is now pinned and tested.

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

**DV-1 result (GATES, 2026-10-31, orchestrator).** Run against the narrowest
suite holding AC-2: the scratchpad subset `sub083n.test.sh` (lines 1-109,
1985-2091 and 2879-end of the frozen `boundaries.test.sh`, line 9 rewritten to
the absolute `_lib.sh` path), not the full self-test. `<` became `!=` on line
968; AC-2's raised-floor control went red, AC-2's refusal (`40 -> 12`) and the
`40 -> 40.0` control stayed green; restored and verified byte-for-byte.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 968s/FLR\[2, id\] + 0 < FLR\[1, id\] + 0/FLR[2, id] + 0 != FLR[1, id] + 0/) ===
  HARNESS-083 AC-2: a floor lowered is refused with both numbers; raised or newly added, it is not
    FAIL HARNESS-083 AC-2 control: floor | unit 40 -> 60 (tightening is silent): not refused - rc|FAIL lines
    FAIL HARNESS-083 AC-2 control: floor | unit 40 -> 60 (tightening is silent): and 3j counts the project.conf commit as judged
boundaries: 82 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261031T160845Z.1992.bak) ===
```

Green run on the restored tree: the orchestrator's full `boundaries.test.sh`
at GREEN commit f9b1969, `boundaries: 442 passed, 0 failed` (rc 0, 2407 s);
`git diff --quiet scripts/check-boundaries.sh` clean after the restore.

**DV-2 result (GATES, 2026-10-31, orchestrator).** Run, not waived. A scratch
worktree `/d/adh-probe083` on branch `story/HARNESS-999-dv2-probe` off f9b1969,
with a fixture story HARNESS-999 (this story's file, id/branch changed, phase
GREEN) committed. Probe 1 used `mutate.sh` on the real line 311 of
`.claude/harness/project.conf`, committed it, and ran `check-boundaries.sh
main`. Probe 2 is the control: one commit dropped the real line 328
(`ondemand | mutation ...`, set-up only, with `sed -i` in the scratch tree,
which had no active lock and was discarded), and the next commit restored it
verbatim. That re-adds the real line on the `optional` mutation gate, which
must not be a finding. Worktree and branch were then removed.

```
### probe 1: real 'gate | lint | required' line -> optional
ac340a3
-gate | lint      | required | . |
+gate | lint      | optional | . |
FAIL  story HARNESS-999: commit ac340a3 (GREEN) loosened a gate in '.claude/harness/project.conf' [gate-loosened]: lint: required -> optional. A gate is never loosened to reach green; if this is deliberate, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason.
=== mutate: command exited 0; restored (verified byte-for-byte against /d/adh-probe083/.claude/state/mutations/.claude_harness_project.conf.20261031T161607Z.12371.bak) ===
### probe 2: real 'ondemand | mutation' line added on the optional mutation gate
d501129
+ondemand | mutation | per-story cost the user declined (HARNESS-015); run it with /audit-mutations
ok    GREEN/GATES added no suppression (2 commit(s) judged)
scratch worktree and branch discarded
```

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
- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-30), per its handoff; no override.
- GREEN - `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-30), per its handoff; no override. Orchestrator re-ran the full `boundaries` suite and `gates.sh --fast` itself.

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

#### GREEN - feature-developer

**Model.** Dispatched as `feature-developer`, which declares `opus`; ran as
claude-opus-5-5. No override.

**What was built.**

- `scripts/check-boundaries.sh`, 3j. `project_conf_loosenings <before-file>
  <after-file>`, one awk, C-2's table; the side is decided by
  `FILENAME == ARGV[1]` (handoff note 1), the flag ERE uses `[.]` (note 2), the
  findings walk the before file's lines in END after both sides are read, so
  a removed gate suppresses its own evidence/floor/covers lines (note 3), and
  `#` lines are skipped before the `|` test (note 4). The walk adds
  `.claude/harness/project.conf` to `sup_paths` by an exact-path `if` on the
  line AFTER the `classify` case line, which is byte-for-byte unchanged
  (HARNESS-082's DV-2 mutates it); a path both classified `source|config` and
  equal to project.conf is added once. The per-path loop sends project.conf
  to the new branch: `git cat-file -e "$c^:$f"` fails (the commit created the
  file, or there is no parent) -> no findings; otherwise the two sides reach
  awk as process substitutions `<(git show ...)`, files with no temp
  directory (lib.test.sh refuses `mktemp`/`$TMPDIR` in a shipped script, and
  two 18.7 KB texts through ARGV would exceed Windows' 32 K command line).
  A commit that DELETES project.conf is compared with `/dev/null` as the after
  side, so every gate in it is `gate removed` - not constrained by any test;
  chosen because deleting the file is the largest loosening there is.
- The declared / partial-entry / refused logic of HARNESS-081's loop moved
  into one function, `sup_verdict <path> <rule id> <refusal>`, which both
  branches call; it is the old block verbatim (same `ok` dedupe key, same
  `$sup_more` suffix, same `sup_refused=1`). All 359 pre-existing assertions
  pass on it (subset below, and the full run).
- One consequence worth knowing: a commit touching project.conf whose story
  is unreadable at that commit now gets 3j's existing `note`. The first commit
  of every `conf_story` (RED, parent on main with no T-1 story) prints it;
  it is a note, never a FAIL, and no assertion reads it.
- `.claude/skills/quality-gates/SKILL.md`: triage rule 5a (C-5).
- `.claude/harness/VERSION`: `102 (2026-10-30)`.

**Subsets, never in the tree.** Both are under the session scratchpad
`C:\Users\ryanc\AppData\Local\Temp\claude\D--agentic-dev-harness\4326bddd-3530-40cd-9f72-26679346bd6b\scratchpad\`:
`sub083g.test.sh` = suite lines 1-109 + 1985-end (the whole 3j section), and
`sub083n.test.sh` = 1-109 + 1985-2091 (3j's helpers, baseline and premise) +
2879-end (HARNESS-083), the narrowest command holding every control, used
for the mutations. Each `diff` against the frozen suite's same lines shows
only line 9:

    9c9
    < . "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
    ---
    > . /d/agentic-dev-harness/.claude/tests/_lib.sh

    sub083g: boundaries: 301 passed, 0 failed   rc=0   (11m55s)
    sub083n: boundaries: 84 passed, 0 failed    rc=0   (3m19s)

**Controls, measured against the shipped code.** Every control's expected
value holds on the shipped module (`0|` and `want_3j_ok 1`; the gate-removed
control `1|1` with the one line `coverage: gate removed`); no divergence
from RED's candidate column. Each mutation went through
`bash scripts/mutate.sh scripts/check-boundaries.sh '<expr>' -- bash .../sub083n.test.sh`,
dry-run first with `diff <(sed "$expr" ...)` to confirm the lines it changes.
RED's table names mutations against its candidate's shape; where my code has
a different shape I mutated the equivalent behaviour and say which. DV-1
(floor `<` -> `!=`, the AC-2 raise control) is GATES' and was NOT run.

| # | Control | Changed line(s) | Red (of 84) | Restore |
|---|---|---|---|---|
| M1s | AC-2 new `floor \| coverage` | after-only loop also takes `floor`, presence by `(1, id) in FLR` (an added line reads as a finding) | 2: exactly that control | exited 1; restored (verified byte-for-byte) |
| M2 | AC-2 40 -> 40.0 | `FLR[2, id] + 0 < FLR[1, id] + 0` -> `FLR[2, id] != FLR[1, id]` | 4: that control and 40 -> 60 | same |
| M3 | AC-3 integration optional -> required | `SEV[1]=="required" && SEV[2]=="optional"` -> `SEV[1, id] != SEV[2, id]` | 2: exactly that control | same |
| M4 | AC-3 new typecheck gate | walk the after file's lines too (`if (s == 1)` -> `if (1)`) and `gone` symmetric (`!=`) | 8: that control, plus the 3 AC-5 refusals (the `else` that records after lines no longer runs) | same |
| M5 | AC-4 80 -> 90 | flag `FV[2] + 0 < b + 0` -> `!=` | 2: exactly that control | same |
| M6s | AC-4 `--coverage.thresholds.lines` added | names kept for both sides, and a name absent before reported | 17: that control, plus refusals doubled by names listed twice | same |
| M7 | AC-4 renamed package; AC-7 command without threshold | store `CMD[s, id]`, and the severity test -> `CMD[1, id] != CMD[2, id]` | 23: both controls, 80 -> 90, added, 80.0 -> 80, and the refusals whose command changed | same |
| M9 | AC-4 80.0 -> 80 | flag `FV[2] + 0 < b + 0` -> `FV[2, id, nm] != b` | 4: that control and 80 -> 90 | same |
| M10 | threshold-removed control: coverage gate removed | `out(id, "gate removed", ...); continue` -> no `continue` | 1: exactly that control's `1\|1` | same |
| M11 | AC-5 `ondemand \| mutation` on optional | `if (SEV[1, id] == "required") out(` -> `if (1) out(` | 2: exactly that control | same |
| M12 | AC-7 comment + commented `covers` example | `#` skip -> strip a leading `#` and parse | 2: exactly that control | same |
| M13s | AC-7 `task \| dev` added | after-only loop also takes `task` (recorded in XL), required test bypassed for it | 2: exactly that control | same |
| M14 | C-2 created file | BOTH the caller's `cat-file -e ... \|\| continue` -> `\|\| :` AND the side by `FNR == 1` | 2: exactly that control | same |

The broad first cuts, kept because they are measurements too: **M1** and
**M13** (drop the after-only loop's kind filter, M13 also its required test)
turned 53 of 84 red, the premise included - XL is the only presence record,
so every unchanged line read as added. They turn the controls red, but too
broadly to earn them alone, hence M1s and M13s. **M6** (names for both sides,
plus `|| !((1, id, nm) in FV)`) did NOT turn its control red: reading
`b = FV[1, id, nm]` on the line before creates the element, so the mutant's
own presence test passed. A defect in the mutant, not in the code; M6s tests
presence before reading.

**The created-file control is guarded twice**, and no single mutation turns
it red. Measured:

    M14a  `git cat-file -e "$c^:$f" 2>/dev/null || continue` -> `|| :`
          boundaries: 84 passed, 0 failed   (the awk sees an empty before file, decides the side by name: no findings)
    M14b  `s = (FILENAME == ARGV[1]) ? 1 : 2` -> `if (FNR == 1) side++; s = side`
          boundaries: 84 passed, 0 failed   (the caller never runs the awk for a created file)
    M14   both
          FAIL HARNESS-083 C-2: project.conf created by the GREEN commit, nothing before it: not refused - rc|FAIL lines
               actual:   1|FAIL  story T-1: commit 9bdc2ff (GREEN) loosened a gate in '.claude/harness/project.conf' [gate-loosened]: format: gate removed. ...
               (then lint, unit, coverage, integration, build, mutation: gate removed; platform: discovery line removed)
          FAIL HARNESS-083 C-2: project.conf created by the GREEN commit, nothing before it: and 3j counts the project.conf commit as judged
          boundaries: 82 passed, 2 failed
          === mutate: command exited 1; restored (verified byte-for-byte) ===

RED's measured "7 x `gate removed` + 1 discovery" for the FNR candidate is
exactly what the shipped code prints under M14: the base's 7 gates (format,
lint, unit, coverage, integration, build, mutation) and `platform`. Logs:
`...\scratchpad\g83\mut-<id>.log`. `bash scripts/mutate.sh --check` after the
batch: `mutate: no stranded mutation; nothing of a previous run is in the tree.`

A representative red, M10, whole:

    === mutate: scripts/check-boundaries.sh (1 line(s) changed by s/out(id, "gate removed", "", ""); continue/out(id, "gate removed", "", "")/) ===
        FAIL HARNESS-083 AC-4 threshold removed control: gate | coverage removed outright, flag and all: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   1|2
    boundaries: 83 passed, 1 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261030T215854Z.66728.bak) ===

**mawk.** `project_conf_loosenings`, extracted from the script by
`sed -n '/^project_conf_loosenings() {/,/^}/p'`, run over 38 before/after
pairs rebuilt with the suite's own `GL_BASE`/`gl_swap`/`gl_after` and its AC-4
row table (every pair the HARNESS-083 describes build, plus a CRLF pair and a
deleted-after case), under Git Bash gawk 5.4.1, WSL gawk 5.2.1 and WSL
`/usr/bin/mawk` 1.3.4 20240123 (WSL's `awk` is gawk there, not mawk, so mawk
was called by path):

    35df1ec8cabaff411cf673e250dd787c98b90baf  gawk.out       (Git Bash, gawk 5.4.1)
    35df1ec8cabaff411cf673e250dd787c98b90baf  gawk-wsl.out   (WSL, gawk 5.2.1)
    35df1ec8cabaff411cf673e250dd787c98b90baf  mawk.out       (WSL, mawk 1.3.4)
    cmp mawk gawk: identical

Every refusing pair printed exactly its pinned finding, the two-finding pairs
both, in before-line order for the order case, and every control nothing.
`<(cat ...)` as the two files also works under mawk on Linux (the order pair
printed both findings). Files: `...\scratchpad\g83\{fn.sh,pairs.sh,run.sh,fx\}`.

**The full suite and the checks**, with the tree restored (no mutation in
flight; the full run started after the last `mutate.sh --check`):

    bash .claude/tests/boundaries.test.sh
    boundaries: 442 passed, 0 failed
    rc=0 elapsed=2561s

    bash scripts/gates.sh --fast       rc=0 - 0 ran, 5 unconfigured, mutation ON REQUEST; --fast skipped integration build; not recorded
    bash scripts/check-sigpipe.sh      check-sigpipe: scanned 56 shell file(s), 51 with pipefail, 0 finding(s)
    bash scripts/check-grep-count.sh   check-grep-count: scanned 56 shell file(s), 0 finding(s)
    bash scripts/mutate.sh --check     mutate: no stranded mutation; nothing of a previous run is in the tree.

**For GATES.** DV-1 and DV-2 are yours and were not run. DV-1's expression
should target the shipped line
`else if (FLR[2, id] + 0 < FLR[1, id] + 0) out(id, "floor lowered " ...`
(one match in the file; M2 above used the same anchor). The full selftest
(`bash scripts/selftest.sh`) was not run here; only `boundaries` was.

#### RED return 1

Test Developer, return 1 (GATES -> RED). Dispatched as `test-developer`
(declares `opus`); ran as **claude-opus-5-5**, no override. Remit: the four
missing tests of `## Regressions`, Return 1; no existing assertion was touched.

**Command.** `bash .claude/tests/boundaries.test.sh` (full, ~45 min locally).
For iteration, the subset `...\scratchpad\sub083r1.test.sh` - the suite's
lines 1-109, 1985-2091 and 2879-end, line 9 rewritten to the absolute
`_lib.sh` path - runs the HARNESS-081 fixture and every HARNESS-083 describe
(108 assertions, ~11 min).

**Files touched.** `.claude/tests/boundaries.test.sh` (one new describe,
"HARNESS-083 return 1: ...", after the C-1/C-2 describe and before
`summary`); `.claude/tests/floors.conf` (boundaries 442 -> 466, with a
comment); `.claude/tests/selftest.test.sh` (its copy, 442 -> 466); this story
(`## Handoff`, `## Regressions`).

**Export shape.** Unchanged and not constrained beyond what C-1/C-2 already
pin: `project_conf_loosenings <before-file> <after-file>` printing
`<id>\t<what>\t<before>\t<after>`; the tests read only `check-boundaries.sh`'s
output, through the existing helpers (`want_gl`, `gl_refused`, `gl_clean`,
`gl_fails`). How the awk picks the first evidence line or the lowest repeat
is the implementer's choice.

**The new cases and what each asserts** (all GREEN commits; `gl_refused` =
whole line + `rc|FAIL lines` = `1|1`; `gl_clean` = `rc|FAIL lines` = `0|` +
`ok    GREEN/GATES added no suppression (1 commit(s) judged)`):

| # | case | expected | on shipped a6f648c |
|---|---|---|---|
| 1 | `gate \| coverage \| required` -> `advisory` | refused `coverage: required -> advisory` | RED (0 / `0\|0`) |
| 2 | -> `Required` | refused `coverage: required -> Required` | RED |
| 3 | -> empty field (`gate \| coverage  \|  \| . \| ...`) | refused `coverage: required -> ` - the finding ends in a space, so the whole line reads `...[gate-loosened]: coverage: required -> . A gate is never...` | RED |
| 4 | control: `gate \| integration` optional -> advisory | silent, judged | passes |
| 5 | control: `required` re-padded `\|   required   \|` | silent, judged | passes |
| 6 | `evidence \| unit        \| -` inserted ABOVE the unchanged real line | refused `unit: evidence line removed` | RED |
| 7 | control: a second real line `evidence \| unit \| [1-9][0-9]* tests? passed` added BELOW | silent, judged | passes |
| 8 | control: `evidence \| unit \| -` added BELOW the real line | silent, judged | passes |
| 9 | `--cov-fail-under=90` -> `--cov-fail-under=90 --cov-fail-under=10` | refused `coverage: threshold lowered --cov-fail-under 90 -> 10` | RED |
| 10 | control: `--cov-fail-under=90` -> `... =90 --cov-fail-under=95` | silent, judged | passes |
| 11 | `--fail-under-lines 80` -> `... 80 --fail-under-lines 30 --fail-under-lines 90` | refused `coverage: threshold lowered --fail-under-lines 80 -> 30` (lowest, in the middle: neither first-wins 80 nor last-wins 90 finds it) | RED |
| 12 | `git rm .claude/harness/project.conf` in a GREEN commit | `gl_fails` equals, in order: `format`, `lint`, `unit`, `coverage`, `integration`, `build`, `mutation: gate removed`, then `platform: discovery line removed` (each a whole `want_gl` line); `rc\|FAIL lines` = `1\|8` | passes on arrival (GREEN built it); earned by mutation, `## Regressions` Return 1 |

The existing `coverage: required -> optional` (AC-3), `optional -> required`
control (AC-3) and every other HARNESS-083 assertion are unchanged and must
stay green.

**Negative controls - expected values.** Every control's expected value is
`rc|FAIL lines` = `0|` (exit 0, no FAIL line at all) and exactly one
`ok    GREEN/GATES added no suppression (1 commit(s) judged)` line. Unlike
the first RED, these were **observed**, not claimed: the suite loads, so
every control executed against the shipped code, and all five measured
`0|` and the judged line (10 assertions green). GREEN re-measures them
against its own code; the risk they guard is an over-broad fix:

| control | the over-broad fix it catches |
|---|---|
| 4 optional -> advisory | `SEV[2] != "required"` without `SEV[1] == "required"` |
| 5 `required` re-padded | comparing untrimmed severities |
| 7 real line added below | "any line differs" / "the last line wins" |
| 8 `-` added below | "any `-` line means no evidence" |
| 10 higher repeat | "a repeat of a flag is a finding" / "last differs" |

**Failure output** (subset, against shipped a6f648c, local):

    boundaries: 96 passed, 12 failed

The 12 reds are cases 1-3, 6, 9 and 11, both assertions each, every one
`expected: 1 / actual: 0` (whole line) and `expected: 1|1 / actual: 0|0`;
the full listing is in `## Regressions`, Return 1.

**New floor.** `boundaries` 466 (442 + 24), in `floors.conf` and
`selftest.test.sh`. Until GREEN lands the suite executes 466 and passes 454 -
below its floor, expected in RED.

**For GREEN.** Change `project_conf_loosenings` only (C-2's amended block):
(a) `SEV[1, id] == "required" && SEV[2, id] != "required"` printing
`"required -> " SEV[2, id]` - case 3's trailing space survives
`read -r sup_gid sup_what _` with `IFS=$'\t'`, since space is not in IFS;
(b) record per side only the **first** evidence line's value and compare
"first is a real regex before, `-` or absent after"; (c) in `flags()`, keep
the first occurrence on side 1 but the **minimum** on side 2 (today the
`if ((s, id, nm) in FV) continue` keeps the first on both).

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

### Return 1 (GATES -> RED, 2026-10-31)

- **What was wrong.** No test was wrong; four behaviours were missing a
  test, and three of those are holes in the code that the tests did not
  demand. (1) A required gate's severity changed to anything but `optional`
  (`advisory`, `Required`, empty) was silent, while `gates.sh` reads it as
  optional. (2) An `evidence | g | -` line added **above** the real one was
  silent; `gates.sh` uses the first. (3) A threshold flag repeated with a
  lower value (`--cov-fail-under=90 --cov-fail-under=10`) was silent.
  (4) Deleting `project.conf` reports every gate removed, but no test pins it.
- **How found.** The fresh diff review at GATES -> REVIEW (`## Diff review`,
  findings 1-4). The orchestrator reproduced 1-3 on its own inputs: GREEN's
  function, extracted from `scripts/check-boundaries.sh` at a6f648c, prints
  nothing for each pair, where each needs a finding:

```
== b1 -> a1:      (gate | unit | required -> advisory)
== b1 -> a2:      (evidence | unit | - inserted above evidence | unit | ok [0-9]+)
== b3 -> a3:      (pytest --cov-fail-under=90 -> --cov-fail-under=90 --cov-fail-under=10)
```

  and confirmed from `scripts/gates.sh` lines 306-313 (`table_get`: first
  match wins) and 530/821 (`[ "$req" = "required" ]`) that each pair weakens
  what `gates.sh` enforces.
- **What the new tests assert.** The amended C-2 bullets above: `required ->
  <after>` for any non-`required` after severity, with `optional -> required`
  and `required -> required` still silent; first-evidence-line comparison,
  with a second real line added below silent; the lowest repeat of a flag
  name compared, with a higher repeat silent; a deletion refused with one
  `gate removed` per gate.
- **What earns them.** (1)-(3) fail on arrival against GREEN's code, so RED
  watches them fail. (4) passes on arrival and is earned by `mutate.sh`
  replacing the deleted-file branch with `continue`, pasted below by RED.
- **GREEN after this return** changes `project_conf_loosenings` only.


#### RED (return 1) - test-developer

Ran as **claude-opus-5-5** (`test-developer`, declares `opus`; no override).
One new describe in `.claude/tests/boundaries.test.sh`, "HARNESS-083 return
1: ...", 24 assertions; nothing existing edited. The cases, the controls and
their expected values are tabled in `## Handoff`, "RED return 1".

**(1)-(3) fail on arrival, for the right reason** - no finding printed, so
neither the whole refusal line (`expected: 1 / actual: 0`) nor the exit
(`expected: 1|1 / actual: 0|0`) appears; not an error, not a fixture bug (no
`FIXTURE BUG` line in the run). The subset `...\scratchpad\sub083r1.test.sh`
(the HARNESS-081 fixture and every HARNESS-083 describe, from the edited
suite) against the shipped `scripts/check-boundaries.sh` at a6f648c, local,
2026-10-31; this describe's output, whole:

      HARNESS-083 return 1: project.conf read as gates.sh reads it - any non-required severity, the first evidence line, the lowest repeated flag, a deleted file
        FAIL HARNESS-083 return 1: gate | coverage required -> 'advisory': refused by the whole line naming 'coverage: required -> advisory'
             expected: 1
             actual:   0
        FAIL HARNESS-083 return 1: gate | coverage required -> 'advisory': and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   0|0
        FAIL HARNESS-083 return 1: gate | coverage required -> 'Required': refused by the whole line naming 'coverage: required -> Required'
             expected: 1
             actual:   0
        FAIL HARNESS-083 return 1: gate | coverage required -> 'Required': and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   0|0
        FAIL HARNESS-083 return 1: gate | coverage required -> '': refused by the whole line naming 'coverage: required -> '
             expected: 1
             actual:   0
        FAIL HARNESS-083 return 1: gate | coverage required -> '': and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   0|0
        FAIL HARNESS-083 return 1: evidence | unit | - inserted above the unchanged real evidence line: refused by the whole line naming 'unit: evidence line removed'
             expected: 1
             actual:   0
        FAIL HARNESS-083 return 1: evidence | unit | - inserted above the unchanged real evidence line: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   0|0
        FAIL HARNESS-083 return 1: --cov-fail-under=90 repeated as --cov-fail-under=10: refused by the whole line naming 'coverage: threshold lowered --cov-fail-under 90 -> 10'
             expected: 1
             actual:   0
        FAIL HARNESS-083 return 1: --cov-fail-under=90 repeated as --cov-fail-under=10: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   0|0
        FAIL HARNESS-083 return 1: --fail-under-lines 80 repeated as 30 then 90 - the lowest, in the middle: refused by the whole line naming 'coverage: threshold lowered --fail-under-lines 80 -> 30'
             expected: 1
             actual:   0
        FAIL HARNESS-083 return 1: --fail-under-lines 80 repeated as 30 then 90 - the lowest, in the middle: and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
             expected: 1|1
             actual:   0|0

    boundaries: 96 passed, 12 failed

The five controls and the deleted-file pair in the same run passed (12 green
of this describe's 24; 84 earlier HARNESS-081/083 assertions green, as before).

**(4) passes on arrival and is earned by a mutation.** The deleted-file branch
of 3j - the one line comparing the before text with `/dev/null` - replaced by
`sup_hits=""` (the brief said `continue`; an empty hit list is the same
no-op without leaving the `for` loop's control flow in question). Dry run
first, without writing: `sed -e '<expr>' scripts/check-boundaries.sh | diff
scripts/check-boundaries.sh -` changed exactly line 1050. Then, against a
narrow subset `...\scratchpad\sub083del.test.sh` (suite lines 1-109,
1985-2091, the HARNESS-083 helpers 2879-3015, and this describe's deleted
case to the end):

    bash scripts/mutate.sh scripts/check-boundaries.sh '/ \/dev\/null)"$/s/sup_hits=.*/sup_hits=""/' -- bash .../scratchpad/sub083del.test.sh

    === mutate: scripts/check-boundaries.sh (1 line(s) changed by / \/dev\/null)"$/s/sup_hits=.*/sup_hits=""/) ===
      1050 -         sup_hits="$(project_conf_loosenings <(git show "$c^:$f" 2>/dev/null) /dev/null)"
      1050 +         sup_hits=""

    === mutate: running bash /c/Users/ryanc/AppData/Local/Temp/claude/D--agentic-dev-harness/4326bddd-3530-40cd-9f72-26679346bd6b/scratchpad/sub083del.test.sh ===

      GREEN and GATES add no suppression to source (HARNESS-081): the fixture

      HARNESS-083: a gate loosened in project.conf during GREEN or GATES - the fixture
        FAIL HARNESS-083 return 1: project.conf deleted by a GREEN commit - every gate removed and the discovery line, whole lines in the before file's order
             expected: FAIL  story T-1: commit 7a1c572 (GREEN) loosened a gate in '.claude/harness/project.conf' [gate-loosened]: format: gate removed. A gate is never loosened to reach green; if this is deliberate, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason.
             [7 further expected lines elided: lint, unit, coverage, integration, build, mutation: gate removed; platform: discovery line removed]
             actual:   
        FAIL HARNESS-083 return 1: project.conf deleted - rc|FAIL lines (seven gates, one discovery id)
             expected: 1|8
             actual:   0|0

    boundaries: 1 passed, 2 failed

    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261031T165137Z.12589.bak) ===
      1050:         sup_hits="$(project_conf_loosenings <(git show "$c^:$f" 2>/dev/null) /dev/null)"

Both assertions of case (4) go red and nothing else does; the restore is
verified by `cmp`, and afterwards:

    bash scripts/mutate.sh --check
    mutate: no stranded mutation; nothing of a previous run is in the tree.

**The full suite**, edited, against the shipped `check-boundaries.sh`
(a6f648c), local, 2026-10-31, tree clean of mutations:

    bash .claude/tests/boundaries.test.sh
    boundaries: 454 passed, 12 failed
    real	49m5.956s

466 executed = 442 + 24. The 12 failures are exactly the 12 above (cases
1-3, 6, 9, 11, two assertions each); no existing assertion moved.
`bash scripts/gates.sh --fast`: rc 0, `0 ran, 5 unconfigured`, not recorded.
`check-sigpipe`: 56 files, 0 findings. `check-grep-count`: 56 files, 0
findings. `bash scripts/mutate.sh --check`: no stranded mutation.

## Diff review

### Round 1 (2026-10-31, at a6f648c)

Fresh `feature-developer` dispatch (declares `opus`), resolved
**claude-opus-5-5**, no override; changed no file. Report, as returned:

- Checked: the awk extracted and fed before/after pairs under gawk (Git
  Bash) and mawk 1.3.4 20240123 (WSL), identical on CRLF, tabs, no-space `|`,
  all five flag spellings, decimals; created, deleted and renamed
  `project.conf` in a real repo (rename = deletion, every gate `gate
  removed`); `sup_verdict` equivalent to the code it replaced, its only
  callers the two in 3j; subset `sub083n.test.sh` 84 passed, 0 failed on HEAD.
- **Must fix 1.** `SEV[1, id] == "required" && SEV[2, id] == "optional"`:
  any other non-`required` after value (`Required`, `advisory`, a typo,
  empty) makes the gate optional in `gates.sh` and is silent here. Sandbox:
  `gate | coverage | Required | . | echo ran; false` gave `WARN coverage
  (1s, exit 1, optional)`, rc 0; `--audit` passed it. Fix: test `!=
  "required"`, print `"required -> " SEV[2, id]`.
- **Should fix 2.** Evidence "any non-`-` line" vs `gates.sh`'s first line:
  `evidence | unit | -` inserted above an unchanged real line turns `FAIL
  unit (... no evidence of work ...)` into `PASS unit`; no finding. Fix:
  compare the first evidence line per side.
- **Should fix 3.** `flags()` keeps the first occurrence: `--fail-under-lines
  80` -> `--fail-under-lines 80 --fail-under-lines 0` and the vitest
  equivalent give no finding; argparse takes the last. Fix: compare every or
  the last after occurrence.
- **Should fix 4.** The deleted-file branch (`/dev/null` after side) has no
  test; replacing it with `continue` leaves the suite green. Fix: one RED
  case expecting `1|<gate count>`.
- **Nice to have 5.** SKILL.md rule 5a ends "a gate or line added - is never
  refused", contradicting the refused added `slow`/`ondemand`/`waiver` line.
- Checked and fine: non-numeric floor reported loudly; a doubled space before
  a flag's number reads as `threshold removed` (loud); `#` lines skipped
  first; merge commits skipped.
- `Verdict: fix 1 first.`

Orchestrator: 1-3 reproduced on its own inputs (see `## Regressions`,
Return 1); user chose "Fix all 5". 1-4 go through RED; 5 is a docs fix in
GREEN.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-31T16:18:43Z
    commit: f9b1969
    tree:   aacc5571a00b2944621c6c4be3776ca523cd758f
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
