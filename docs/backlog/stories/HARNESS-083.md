---
id: HARNESS-083
title: A gate loosened in project.conf during GREEN or GATES is refused unless the story declares it
slug: a-gate-loosened-in-project-conf-during-g
epic: 
type: feature
status: todo
phase: PLANNED
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
| `threshold lowered` | the gate's command on both sides has the same flag from AC-4's list and its number went down; several flags are several findings; a flag present on one side only is no finding |
| `slow added on required gate` / `ondemand added on required gate` / `waiver added on required gate` | the line is on the after side only, and the gate is `required` on the **before** side |

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
  written, e.g. `--cov-fail-under`); `slow added on required gate`,
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

