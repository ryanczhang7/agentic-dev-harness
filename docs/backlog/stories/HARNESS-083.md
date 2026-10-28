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
as 3i reads a manifest, and `project_conf_loosenings()` compares them. One
`problem` per finding, in the HARNESS-081 shape with rule id `gate-loosened`:

    FAIL  story <sid>: commit <7> (<PHASE>) loosened a gate in '.claude/harness/project.conf' [gate-loosened]: <gate id>: <what> (<before> -> <after>). A gate is never loosened to reach green; if this is deliberate, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason.

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

