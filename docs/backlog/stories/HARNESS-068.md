---
id: HARNESS-068
title: A diff review reads the change and its callers before the PR opens
slug: a-diff-review-reads-the-change-and-its-c
epic: 
type: feature
status: in-review
phase: REVIEW
branch: story/HARNESS-068-a-diff-review-reads-the-change-and-its-c
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/skills/diff-review/SKILL.md, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/tests/procedure.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Today the GATES → REVIEW paragraph of `.claude/commands/advance-story.md` runs,
in order: the full self-test, `phase.sh set REVIEW`, a commit,
`check-boundaries.sh`, then push and open the PR. Every step judges the code
through something that executes: tests, gates, the commit's shape. **No step
reads the code for bugs that live outside the diff.** Examples are a caller
broken by a changed return value, a fix applied in one caller while the shared
function stays wrong, or an error swallowed on a write path. A green suite
cannot see a defect no test was written for, and law 4 only covers the
behaviour the story *claims*. `complete-story.md` repeats the same sequence in
its `- **GATES → REVIEW` bullet.

The source is a comparison with **ponytail** (github.com/DietrichGebert/ponytail,
MIT licence, commit 09c434a, 2026-10-18), whose `skills/ponytail-review/SKILL.md`
reviews a change by reading the diff, then the code connected to it. Every
finding needs a concrete case. Findings are grouped by severity and each one is
written in four parts. Its benchmark (`benchmarks/results/2026-10-07-agentic.md`)
claims 100% of planted problems found, against 87% for a plain review prompt.
That is the source's own claim, measured without a shell and outside a TDD loop.
Nothing here depends on the number.

**Decisions this story implements (settled at PLANNED):**

- **Where it lives:** a new skill, `.claude/skills/diff-review/SKILL.md`. A skill
  is loaded by name, so both commands point at one text rather than each
  carrying a copy. Neither existing skill fits: `quality-gates` is about gate
  commands, and `tdd-cycle` is loaded by the Test Developer.
- **When it runs:** the **first** numbered step of GATES → REVIEW, before the
  full self-test. A Must-fix finding changes the tree. Before the self-test it
  costs a fix and a gate run. After the self-test, that run (about 25 minutes on
  a Windows host) is wasted and has to happen again.
- **Who runs it, on which model:** a **fresh** `feature-developer` dispatch, not
  the one that wrote the code, on the GATES row of `models.conf`: `opus`. The
  story is still at GATES. Reading code for bugs is judging code, which
  `rules.md` assigns to `opus`. A fresh context is used because a reviewer that
  carries the author's reasoning repeats the author's blind spots. The reviewer
  **changes no file**. It returns its report to the orchestrator, and the
  orchestrator records the resolved model of that dispatch in `## Model guidance`
  like any other.
- **Where its output goes:** the orchestrator (lead-po, which owns
  `docs/backlog/**`) pastes the report into a `## Diff review` section of the
  story, directly above `## Gate results`. No role's ownership changes. The
  reviewer writes nothing, and the story file is already the orchestrator's.
- **What a Must-fix does:** it routes through the phase rules, never around the
  lock. A code fix is made in GATES by a feature-developer dispatch. Then
  `bash scripts/gates.sh` runs again and the GATES → REVIEW steps start over,
  with a review of the fix. A finding that needs a test changed or added is a
  return to RED (`bash scripts/phase.sh set <id> RED`) with a `## Regressions`
  entry, earned by a mutation as the non-negotiables require. A finding that
  says an acceptance criterion is wrong is an `## Amendments` question for the
  user. The steps go on only once the review's last line is `Verdict: Ship.`.
- **`check-boundaries.sh` does not learn about it in this story.** See Out of
  scope.

**The required gate holding this story's artefact** is the harness self-test:
`procedure.test.sh` already pins the GATES → REVIEW step order of both commands
(HARNESS-032), and this story extends it. It is the existing selftest that
checks command step ordering, and the `procedure_problems <root>` /
compliant-fixture pattern is reused unchanged.

## Acceptance criteria

- **AC-1** — The review is a numbered GATES → REVIEW step, before the self-test.
  Given the repository, when `procedure_problems` runs over it, then
  `advance-story.md`'s GATES → REVIEW paragraph has a numbered step containing
  the fixed string `` the `diff-review` skill ``, and that step's number is
  lower than the number of the `` `bash scripts/selftest.sh` `` step. Every
  existing check (selftest < phase < boundaries) still holds. *Negative
  controls:* a fixture whose review step comes after the self-test step prints
  exactly one C-4 out-of-order line naming both step numbers. A fixture that
  names the skill only in the paragraph's prose, in no numbered step, prints
  exactly one "do not name" line.
- **AC-2** — The step says how a finding routes. Given the repository, when
  `procedure_problems` runs, then the review step (its line plus continuation
  lines) contains each C-3 routing word. *Negative control:* a fixture whose
  review step omits `bash scripts/gates.sh` prints exactly one "does not say"
  line for it.
- **AC-3** — `complete-story` names the review before the self-test. Given the
  repository, when `procedure_problems` runs, then `complete-story.md`'s
  `- **GATES → REVIEW` bullet contains `` `diff-review` ``, at a position
  before its first `` `bash scripts/selftest.sh` ``. *Negative controls:* a
  fixture bullet without `` `diff-review` `` prints exactly the "does not name"
  line. A fixture bullet that names it only after the self-test prints exactly
  the "names … after" line.
- **AC-4** — The skill carries the review's rules. Given the repository, when
  `procedure_problems` runs, then `.claude/skills/diff-review/SKILL.md` exists,
  has the frontmatter line `name: diff-review`, contains every C-3 skill
  needle, and contains neither C-3 ponytail test needle. *Negative controls:* a
  fixture skill without `No case, no finding.` prints exactly one "does not say"
  line. A fixture skill without `**If we skip it:**` prints exactly one. A
  fixture skill carrying `One good test, not coverage` prints exactly one
  "carries ponytail's" line. A missing skill file prints only `file is missing`
  for it.

## Contract

**Writes:** `.claude/skills/diff-review/SKILL.md`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/tests/procedure.test.sh`

RED may amend any block below, in place, with a reason; GREEN then builds what
the amended block says. The acceptance criteria above are frozen and change only
through `## Amendments`.

**C-1. The suite.** `.claude/tests/procedure.test.sh`, extended in place. Its
helpers (`load`, `gates_steps`, `first_step`, `gates_bullet`), its byte-for-byte
fault-line style and its pure-bash matching (no grep or awk fork per needle) stay
as they are. The compliant fixture (`GOOD_STEPS`, `GOOD_BULLET`, plus a new
`GOOD_SKILL` written by `compliant_fixture`) gains the review, built by
construction and never copied from the real tree. Every existing assertion keeps
its meaning. Where inserting step 1 renumbers a fixture, RED updates the expected
step numbers in place and says so in the handoff. `procedure_problems` gains a
third file, `SKILL=".claude/skills/diff-review/SKILL.md"`, judged after the two
commands.

**C-2. Step and bullet needles, settled.**
- `STEP_REVIEW='the \`diff-review\` skill'`: a GATES → REVIEW numbered step
  contains it as a fixed string. Order: `SN[review] < SN[selftest]`.
- complete-story: the bullet contains `` `diff-review` `` and its first
  occurrence is before the first occurrence of `` `bash scripts/selftest.sh` ``.
  Compare string offsets in bash: the prefix up to each needle, `${R%%needle*}`,
  and its length.

**C-3. Word lists, settled. Read them out; do not reword them.**
- *Routing words,* in the review step: `## Diff review`, `Must fix`,
  `bash scripts/gates.sh`, `Verdict: Ship.`
- *Skill needles,* fixed strings anywhere in the skill file:
  `callers of every changed function`, `No case, no finding.`,
  `**Must fix:**`, `**Should fix:**`, `**Nice to have:**`,
  `Number findings across all groups`, `**What this is:**`, `**Problem:**`,
  `**Fix:**`, `**If we skip it:**`, `Verdict: Ship.`, `Verdict: fix `,
  `bash scripts/gates.sh`, `` `bash scripts/phase.sh set <id> RED` ``,
  `## Regressions`, `## Amendments`, `changes no file`
- *Frontmatter:* the skill's frontmatter (line 1 `---` to the next `---`) has a
  line exactly `name: diff-review`.
- *Ponytail test needles,* which must be absent from the skill: `One good test,
  not coverage`, `one small test`. Ponytail's "Missing test" category is adapted
  to the harness's law: a finding is a behaviour or branch with no test that
  fails when it breaks. Its fix routes to RED. It is never "one good test is
  enough".

Needle notes, for rules.md "an assertion's needle is part of the assertion".
`Verdict: Ship.` is not matched by its negation (`Verdict: fix 1 first.`), which
is why the verdict needle carries the full stop. `Verdict: fix ` ends in a space,
so it cannot match prose such as "verdict: fixed". Absence needles are satisfied
by any other spelling, a known limit. The presence needles are the strong half.

**C-4. Output lines, byte for byte.** `A`, `C`, `S` = the advance-story,
complete-story and skill paths. Existing lines are unchanged. New ones:
- `A: its GATES → REVIEW steps do not name the \`diff-review\` skill`
- `A: its GATES → REVIEW steps are out of order: the \`diff-review\` skill is step <n>, \`bash scripts/selftest.sh\` is step <m>`
  (existing `disorder` shape, with `STEP_REVIEW` as the first needle)
- `A: its \`diff-review\` step does not say \`<word>\``
- `C: its GATES → REVIEW bullet does not name \`diff-review\``
- `C: its GATES → REVIEW bullet names \`diff-review\` after \`bash scripts/selftest.sh\``
- `S: file is missing` (no other line for S)
- `S: has no \`name: diff-review\` line in its frontmatter`
- `S: does not say \`<needle>\``
- `S: carries ponytail's \`<needle>\``

Order within A: the existing checks first, then the review-missing line, then
the review order line, then the routing words in C-3 order. The order check runs
only when both steps exist; the word check only when the review step exists.
Within C: the existing selftest line, then the review lines. Within S: missing,
then frontmatter, then needles in C-3 order, then ponytail needles.

**C-5. The skill's content** (GREEN writes it, in the harness's voice; C-3 pins
only its anchors):
1. *Understand first.* Read the story's diff against the base branch
   (`git diff main...HEAD`, or the worktree's base), then read the callers of
   every changed function and what it calls, and the tests. When a signature,
   return value or behaviour changes, grep every caller. Trace where data comes
   in, what is stored, and what goes out.
2. *Look for*, in this order: bug, risk (security, data loss), scale against
   the load the repo states, missing test (in the law's terms above), speed,
   lean. "Lean" names the helper the repo already has (by path), the standard
   library or platform feature, the dependency added for a few lines. It is
   consistent with HARNESS-067's ladder but does not depend on it.
3. *Check before reporting.* Every finding needs a concrete case: "this input or
   situation leads to this wrong result". No case, no finding. Re-read the lines.
   No style taste, no "consider".
4. *Output.* `What this change does:` in two or three sentences. Then **Must
   fix** (bug, security, data loss, breaks at the stated load), **Should fix**,
   **Nice to have**, skipping empty groups and numbering findings across all
   groups. Each finding has four parts: What this is, Problem, Fix, If we skip
   it. End with `Verdict: Ship.` or `Verdict: fix <n> and <m> first.`, plus
   `Not checked:` when something that mattered could not be checked.
5. *Routing* (the Context's Must-fix decision, restated as instructions).
   Should-fix items the orchestrator declines are recorded in `## Diff review`
   with a one-line reason, never dropped silently. Nice-to-have items are listed
   only.
6. *Who:* a fresh `feature-developer` dispatch on the GATES model. It changes no
   file. The orchestrator pastes its report into `## Diff review` and records
   the resolved model.
7. One credit line: ponytail-review, repo and MIT licence.

The skill names no `docs/` path that `.claude/harness/docs-shipped.conf` neither
ships nor declares written (`shipped-docs.test.sh` scans every skill `.md`).
`docs/backlog/stories/` is declared written, so it may be named. Neither command
gains a per-story mutation count: `policy.test.sh` refuses `(two|three)
mutations` in both.

**C-6. The command text.** advance-story's GATES → REVIEW paragraph gains a new
step 1, which names `` the `diff-review` skill `` and the four routing words. The
old steps 1 to 5 become 2 to 6. Any prose that refers to them by number is
updated to match: today "ends with step 4's check", "can only run after step 3"
and "a substitute for step 1". complete-story's bullet stops saying it runs the
self-test "first" and names the review before it.

**Oracle partition.** Every criterion is **mechanical**: the needles, the order
relations and the output lines are pinned exactly. Read them out; do not improve
their wording.

**Test-only dependencies:** none (bash and coreutils only).

**Changed signatures:** `procedure_problems <root>` keeps its signature and
gains output lines. Its only caller is `procedure.test.sh` itself (checked at
PLANNED: no other file in the tree names `procedure_problems`).

## Deferred verifications

**DV-1, defect put back (the story's central claim).** Remove the review step from
the REAL `advance-story.md` by deleting its line with
`bash scripts/mutate.sh .claude/commands/advance-story.md '<sed expression deleting the line that begins "1. " and contains the diff-review needle>' -- bash scripts/selftest.sh procedure`.
GATES writes the exact expression once the real text exists, and records it.
`procedure` **must** fail with the "do not name the `diff-review` skill" line,
and mutate.sh must report the file restored. RED cannot run this, because the
real step does not exist until GREEN writes it. **Owner: GATES.**

Result (GATES, 2026-10-23, run by the orchestrator; the real line is
advance-story.md:197; ok lines elided):

```
=== mutate: .claude/commands/advance-story.md (1 line(s) changed by /^1\. Review the story.s diff and its callers with the `diff-review` skill\.$/d) ===
=== mutate: running bash scripts/selftest.sh procedure ===
    FAIL procedure_problems over the real tree prints nothing: both commands permit selftest.sh and ci-local.sh, the diff-review step comes before the full self-test, which comes before the phase change, complete-story names the review before the self-test, and the diff-review skill carries its rules
         expected: 
         actual:   .claude/commands/advance-story.md: its GATES → REVIEW steps do not name the `diff-review` skill
procedure: 89 passed, 1 failed
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261023T052651Z.41225.bak) ===
```

Exactly the one C-4 line; the single real-tree assertion went red; file
restored. This is also the orchestrator's one "does the suite discriminate"
mutation (a lone assertion caught it), and `procedure` was 90/0 again after.

**DV-2, the skill rule against a real line.** Delete the REAL skill's line
holding `No case, no finding.` with `mutate.sh` (expression
`'/No case, no finding\./d'`), then run `bash scripts/selftest.sh procedure`. It
**must** fail with exactly that one "does not say" line, and the file must be
restored. **Owner: GATES.**

Result (GATES, 2026-10-23, run by the orchestrator; the real line is
SKILL.md:76, which holds that sentence alone; ok lines elided):

```
=== mutate: .claude/skills/diff-review/SKILL.md (1 line(s) changed by /No case, no finding\./d) ===
=== mutate: running bash scripts/selftest.sh procedure ===
    FAIL procedure_problems over the real tree prints nothing: both commands permit selftest.sh and ci-local.sh, the diff-review step comes before the full self-test, which comes before the phase change, complete-story names the review before the self-test, and the diff-review skill carries its rules
         expected: 
         actual:   .claude/skills/diff-review/SKILL.md: does not say `No case, no finding.`
procedure: 89 passed, 1 failed
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_skills_diff-review_SKILL.md.20261023T052923Z.42165.bak) ===
```

Exactly the one "does not say" line, file restored.

**DV-3, the review runs once on this story's own diff.** At this story's GATES
→ REVIEW, the orchestrator follows the new step 1 on HARNESS-068's own diff and
pastes the report into `## Diff review`. This is the first real use, and it is
evidence the procedure is followable, not a test of the review's quality.
**Owner: GATES.**

Status at GREEN → GATES (2026-10-23): pending. It is step 1 of GATES → REVIEW,
so it runs in the next transition; its result lands in `## Diff review` and a
pointer to it is added here.

Result (GATES → REVIEW step 1, 2026-10-23): run. A fresh feature-developer on
Opus 5.5 followed the skill over `git diff main...HEAD` and returned a report
in the skill's shape, changing no file; the full report is in `## Diff review`.
Its verdict line, last:

```
Verdict: Ship.
```

One Nice-to-have (expected-value helpers fork per assertion), listed only.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-068` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`: resolved to **Opus 5.5 (`claude-opus-5-5`) by explicit override**, not the planned `fable`. The user's Fable usage limit was reached, and the user chose in chat to re-run the lead-po planning for HARNESS-067 and 068 on Opus and to record the override in both stories. What it changes: this PLANNED ran on `opus`, so if RED has to send this contract back, that counts against this planning run, not against `fable`. It is not evidence for or against the PLANNED row of `models.conf`.

## Out of scope

- **`check-boundaries.sh` refusing a PR without a `## Diff review` verdict.**
  That needs a new boundaries check, its fixtures and a floor raise in
  `boundaries.test.sh`, which is a second RED → GREEN cycle. Kept out so this
  story stays one cycle. A candidate follow-up story: "a story at REVIEW whose
  `## Diff review` has no `Verdict:` line is refused".
- **A `## Diff review` section in the story template** (`scripts/new-story.sh`
  and `new-story.test.sh`). The orchestrator adds the section when the review
  runs. Templating it belongs with the boundaries follow-up, which would read it.
- **Raising the `procedure` floor.** Adding assertions to a suite does not
  require touching `floors.conf` (its header says so). Leaving it alone keeps
  this story clear of HARNESS-067, which owns `floors.conf` and
  `selftest.test.sh`. Until someone raises it, the new assertions are deletable
  without the floor noticing. Raise it in whichever of the two stories merges
  second, or in a follow-up.
- **A new agent definition or a `models.conf` row for the reviewer.** It runs as
  a `feature-developer` dispatch on the GATES row. Changing that is a models
  decision with its own success condition.
- **Ponytail's "One good test, not coverage"**, its plain-English reading-level
  rules beyond the four-part shape, and its `shortcut:` comment convention.
- **Reviewing harness changes made outside a story**, or a PR someone else
  opened. The step is for this story's own diff at GATES → REVIEW.
- **The reuse ladder in GREEN.** That is HARNESS-067.

## Test plan

One suite, `.claude/tests/procedure.test.sh`, extended in place (C-1). Every
criterion is mechanical: the needles (C-2, C-3) and the output lines (C-4) are
read out byte for byte. The level is the only one available. The sites are
prose, so the guard reads their shape (`tdd-cycle`, "code no machine you have
can execute"). What it cannot pin is that an orchestrator *follows* the step.
DV-3 is the only evidence of that.

- **Real tree.** `procedure_problems "$REPO_ROOT"` must print nothing. This is
  the RED assertion for AC-1..AC-4 together. A second real-tree assertion says
  the skill file exists, so its absence reads as a bug report on its own.
- **Compliant fixture.** Built by construction (`RV` + `REST` = `GOOD_STEPS`,
  `GOOD_BULLET`, `GOOD_SKILL`), never copied from the tree. It must be silent.
  That is the positive control for every negative below.
- **AC-1 negatives.** Review after self-test (one disorder line, steps 2 and 1).
  Review only in prose (one "do not name"). No review step at all. Review only
  in the REVIEW → DONE paragraph. Review without the backticked needle. Review
  and self-test in one step (disorder, 1 and 1). No self-test step, so the
  review order check is suppressed. C-4 order: an existing line before the
  review's "do not name", and the review's disorder line before its word lines.
- **AC-2 negatives.** Each of the four routing words removed from the step but
  present in prose (four cases, one line each). `Verdict: fix 1 first.` does not
  satisfy `Verdict: Ship.`. `Verdict: Ship` without the stop does not satisfy it.
  All four words in a different step do not count (four lines, C-3 order).
- **AC-3 negatives.** No `` `diff-review` `` in the bullet. Named only after the
  self-test, on the same line and on a continuation line. Present elsewhere in
  the file, or in the next bullet. Unbackticked. The first occurrence of each
  needle is the one judged, in both directions. A bullet with neither prints the
  self-test line, then the review line (C-4 order).
- **AC-4 negatives.** Missing skill gives only `file is missing`. Each of the 17
  skill needles removed (17 cases, one line each, and the story's two named
  controls are among them). Each ponytail needle added (two cases). Frontmatter:
  `name:` line renamed, moved into the body, extended to `diff-review-v2`, or the
  frontmatter removed. Each gives the one frontmatter line. CRLF skill is silent.
  C-4 order within S, and across A, C, S.
- **Pre-existing assertions** keep their meaning. Fixtures that write their own
  step list now carry the review step first and are renumbered (see Handoff).

## Handoff: RED -> GREEN

**Model.** Dispatched as `test-developer`, which declares `opus`. Resolved to
**Opus 5.5 (`claude-opus-5-5`)**. No override was given in the dispatch.

**Command.**

    bash scripts/selftest.sh procedure

**RED output (local, Windows host, 1m18s):**

```
=== procedure ===

  the real tree (AC-1 to AC-4)
    FAIL the diff-review skill exists in this repository (HARNESS-068 AC-4)
         expected: 
         actual:   .claude/skills/diff-review/SKILL.md
    FAIL procedure_problems over the real tree prints nothing: both commands permit selftest.sh and ci-local.sh, the diff-review step comes before the full self-test, which comes before the phase change, complete-story names the review before the self-test, and the diff-review skill carries its rules
         expected: 
         actual:   .claude/commands/advance-story.md: its GATES → REVIEW steps do not name the `diff-review` skill
         .claude/commands/complete-story.md: its GATES → REVIEW bullet does not name `diff-review`
         .claude/skills/diff-review/SKILL.md: file is missing

  [... every fixture section passes; passing assertions print nothing ...]

procedure: 88 passed, 2 failed

assertion floors: all 1 suite(s) met their declared floor (88 assertions executed, 37 declared).
1 of 1 harness suite(s) FAILED.
```

This is the expected shape, in C-4 order: A's "do not name" line, C's "does
not name" line, and `S: file is missing` with nothing else for S. There are no
order or routing-word lines for A, because the review step does not exist.
**90 assertions execute** (37 before this story; the floor of 37 is untouched).
The suite *loads*, so unlike an import-failure RED every negative control below
has already run and passed against the guard.

**What each new test asserts** (all in `.claude/tests/procedure.test.sh`):

| Test | AC |
|---|---|
| the diff-review skill exists in this repository | AC-4 |
| procedure_problems over the real tree prints nothing (extended name) | AC-1..AC-4 |
| the compliant fixture is silent (now with review step, bullet review, skill) | all |
| review step after the self-test gives one out-of-order line naming both step numbers | AC-1 |
| review named only in prose gives one "do not name" line | AC-1 |
| no review step at all gives one "do not name" line; order and word checks suppressed | AC-1 |
| review step only in the REVIEW → DONE paragraph gives one "do not name" line | AC-1 |
| a step naming the skill without the backticked needle does not name it | AC-1 |
| review and self-test in the same step count as out of order | AC-1 |
| with no self-test step the review's order check is suppressed | AC-1 / C-4 |
| existing checks print before the review "do not name" line | AC-1 / C-4 |
| the review's out-of-order line prints before its routing-word lines | AC-1, AC-2 / C-4 |
| each routing word missing from the step but present in prose gives one line (x4) | AC-2 |
| `Verdict: fix 1 first.` does not satisfy `Verdict: Ship.` | AC-2 |
| `Verdict: Ship` without the full stop does not satisfy the needle | AC-2 |
| the four routing words in a different step do not satisfy the review step | AC-2 |
| a bullet naming the self-test but not `diff-review` gives one "does not name" line | AC-3 |
| a bullet naming `diff-review` only after the self-test gives one "names … after" line | AC-3 |
| `diff-review` on a later line, after the self-test, is still after it | AC-3 |
| `diff-review` elsewhere in the file, not in the bullet, gives "does not name" | AC-3 |
| `diff-review` in the next bullet is not in the bullet | AC-3 |
| diff-review without backticks is not the needle | AC-3 |
| the FIRST `diff-review` is judged (before self-test, a later mention does not matter) | AC-3 |
| the FIRST self-test is judged (review before only its second mention is after) | AC-3 |
| a bullet naming neither gives the self-test line, then the review line | AC-3 / C-4 |
| a missing skill file gives only `file is missing` | AC-4 |
| the skill without each C-3 needle gives one "does not say" line (x17) | AC-4 |
| the skill carrying each ponytail needle gives one "carries ponytail's" line (x2) | AC-4 |
| no `name: diff-review` frontmatter line gives that line only | AC-4 |
| `name: diff-review` in the body does not count | AC-4 |
| a frontmatter line only containing `name: diff-review` is not equal to it | AC-4 |
| a `name:` line with no frontmatter around it does not count | AC-4 |
| a CRLF skill file reads the same as an LF one | AC-4 |
| the skill's lines print in C-4 order | AC-4 / C-4 |
| the three files are judged in order: advance-story, complete-story, skill | C-1 / C-4 |

**Pre-existing fixtures renumbered or changed in place** (meaning unchanged:
each still expects exactly the line it expected before):

- `GOOD_STEPS` is now `RV` (new step 1, the review) followed by `REST`, the old
  steps 1..5 renumbered to 2..6.
- Every fixture that writes its own step list is now `with_review "<steps>"`,
  with its steps renumbered +1: `selftest-after-phase` (expected disorder
  `selftest 2, phase 1` → `selftest 3, phase 2`), `selftest-in-prose`,
  `selftest-targeted`, `selftest-other-paragraph` (its REVIEW → DONE step stays
  `1.`, being another paragraph), `boundaries-before-phase` (`phase 3,
  boundaries 2` → `phase 4, boundaries 3`), `same-step` (`1, 1` → `2, 2`),
  `first-step-wins` (`selftest 2, phase 1` → `selftest 3, phase 2`),
  `phase-missing`, `boundaries-missing`, `continuation-counts`,
  `indented-after-blank`, `words-in-next-step`.
- `star-line-ends-region`: the steps after the `**` line are not read, so the
  expected output gains a fourth line, `no_step "$STEP_REVIEW"`, after the
  existing three. It is the same assertion ("no step is read") over one more
  step.
- `GOOD_BULLET` now names `` `diff-review` `` before the self-test and no longer
  says "first". The four complete-story fixtures that write their own bullet
  (`bullet-without`, `bullet-targeted`, `bullet-after-blank`,
  `bullet-next-bullet`) each gain a `` `diff-review` `` on the bullet's first
  line, so they still print only the self-test line.
- `fresh_case` now **sets `d`** instead of echoing it, and makes both fixture
  directories with one `mkdir`. All 65 call sites changed from
  `d="$(fresh_case X)"` to `fresh_case X`. The reason is cost, not behaviour.
  This Windows host measured `fresh_case` at about 800 ms, most of it in four
  forks (one `mkdir -p` alone took about 280 ms). The extended suite took
  **4m24s** before this change and **1m18s** after it. The pre-story suite took
  58s on the same host. All three timings are local; none is from CI.

**Export shape pinned.** There is no module. What GREEN must write is fixed by
the needles, and GREEN does not touch the suite:

- `.claude/commands/advance-story.md`: inside the `**GATES → REVIEW.**`
  paragraph, a numbered step whose text (its `N. ` line plus indented
  continuation lines, up to a blank line) contains `` the `diff-review` skill ``
  and all four of `## Diff review`, `Must fix`, `bash scripts/gates.sh`,
  `Verdict: Ship.`, with a number lower than the `` `bash scripts/selftest.sh` ``
  step.
- `.claude/commands/complete-story.md`: the `- **GATES → REVIEW` bullet (up to a
  blank line or the next `- ` line) contains `` `diff-review` `` before its first
  `` `bash scripts/selftest.sh` ``.
- `.claude/skills/diff-review/SKILL.md`: line 1 `---`, a frontmatter line exactly
  `name: diff-review`, every C-3 skill needle anywhere in the file
  (case-sensitive, fixed strings), and neither `One good test, not coverage`
  nor `one small test` anywhere.
- **Not constrained:** the wording around the needles, the skill's headings and
  order, its `description:`, and anything C-5 says beyond the anchors.

**Traps for GREEN, found while writing the guard:**

1. **The review step must not contain `` `bash scripts/selftest.sh` `` in
   backticks.** `first_step` picks the *first* step holding a needle. If step 1
   says "before `` `bash scripts/selftest.sh` ``", step 1 becomes the self-test
   step. Then the guard reports a review/self-test disorder (`1, 1`), and the
   detached/Windows/`## Notes` words are judged against the review step. Unquoted
   "the self-test" is safe. The same goes for `` `bash scripts/check-boundaries.sh` ``
   and `` `bash scripts/phase.sh set $1 REVIEW` ``. Either in step 1 breaks the
   existing order checks. A routing mention of
   `` `bash scripts/phase.sh set <id> RED` `` is fine, being a different string.
2. **Put the needle on the `1. ` line itself**, not on a continuation line. DV-1
   deletes the step's first line. If the needle sat on a continuation line, that
   deletion would not remove it, and DV-1 would not show what it claims.
3. **In the skill, the line holding `No case, no finding.` must hold no other
   C-3 needle.** DV-2 deletes that whole line and expects exactly one "does not
   say" line.
4. **Ponytail's needles are case-sensitive substrings.** The credit line, or any
   prose about what was left out, must not quote `one small test` or
   `One good test, not coverage`. Write "ponytail's test-sufficiency rule" or
   similar.
5. complete-story's bullet: the needle is `` `diff-review` `` *with backticks*.
   "the diff-review skill" unquoted does not count.

**Negative controls: expected and measured.** All the controls are fixture
assertions that ran in this RED and passed. The guard is test code and exists,
so "measured" here is the guard's actual output in the run above, not a value
taken outside the framework. They are not claims awaiting GREEN, as an
import-failure RED would leave them.

| Control | Expected output | Measured (RED run) |
|---|---|---|
| compliant fixture (positive control) | empty | empty (pass) |
| review after self-test | 1 line: disorder, review step 2, selftest step 1 | that line (pass) |
| review only in prose | 1 line: A "do not name the `diff-review` skill" | that line (pass) |
| review step without `bash scripts/gates.sh` | 1 line: A "`diff-review` step does not say `bash scripts/gates.sh`" | that line (pass) |
| bullet without `diff-review` | 1 line: C "does not name `diff-review`" | that line (pass) |
| bullet names it only after the self-test | 1 line: C "names `diff-review` after …" | that line (pass) |
| skill without `No case, no finding.` | 1 line: S "does not say `No case, no finding.`" | that line (pass) |
| skill without `**If we skip it:**` | 1 line: S "does not say `**If we skip it:**`" | that line (pass) |
| skill carrying `One good test, not coverage` | 1 line: S "carries ponytail's …" | that line (pass) |
| skill missing | 1 line: `S: file is missing` | that line (pass) |
| real tree (RED) | 3 lines: A no-name, C no-name, S missing | exactly those 3 (fail, as intended) |

**Mutation table for GREEN and GATES.** Run against the real files once they
exist, each through `bash scripts/mutate.sh FILE 'EXPR' -- bash scripts/selftest.sh procedure`:

| # | File | Mutation | Expected red line | Owner |
|---|---|---|---|---|
| DV-1 | `advance-story.md` | delete the `1. ` line holding `` the `diff-review` skill `` (expression written by GATES once the text exists) | `A: its GATES → REVIEW steps do not name the \`diff-review\` skill` | GATES |
| DV-2 | `diff-review/SKILL.md` | `'/No case, no finding\./d'` | `S: does not say \`No case, no finding.\`` (exactly one line) | GATES |
| opt | `complete-story.md` | `'s/`diff-review`/diff-review/'` (unquote the first occurrence) | `C: its GATES → REVIEW bullet does not name \`diff-review\`` if it was the only quoted one | optional |
| opt | `diff-review/SKILL.md` | `'s/^name: diff-review$/name: diff-reviewer/'` | `S: has no \`name: diff-review\` line in its frontmatter` | optional |

The two optional rows are beyond the story's mutation budget (`rules.md`,
"Mutation work per story") and are listed only as candidates for
`/audit-mutations`.

**Deferred verifications: declined in RED, in writing.**

- **DV-1:** I cannot run it. The real review step does not exist until GREEN
  writes it, so there is no line to delete. Owner: GATES.
- **DV-2:** I cannot run it. The real skill does not exist. I checked only that
  the expression reads correctly: `/No case, no finding\./d` escapes the full
  stop, so it deletes only a line holding the needle with its stop. GNU sed on
  this host deleted `Every finding needs a concrete case. No case, no finding.`
  and kept `No case, no findingX` (trap 3 above is the precondition for "exactly
  one line"). Owner: GATES.
- **DV-3:** I cannot run it. It is the orchestrator's review of this story's
  own diff at GATES → REVIEW. Owner: GATES.

**Contract blocks amended:** none. C-1..C-4 were buildable as written.

**Files touched:** `.claude/tests/procedure.test.sh`, and this story's
`## Test plan` and `## Handoff: RED -> GREEN`. **Not touched:**
`.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`,
`.claude/skills/diff-review/SKILL.md` (does not exist), `floors.conf`,
`selftest.test.sh`.

**Gates.** `bash scripts/gates.sh --fast` exits 0 with every gate
`UNCONFIGURED` (this repository's `project.conf` is not bootstrapped). The
self-test is the gate that judges this story. `check-sigpipe.sh` and
`check-grep-count.sh` each report 0 findings over 52 shell files.

## Diff review

Run at GATES → REVIEW step 1, 2026-10-23, over `git diff main...HEAD` at
`cefd1df`. Reviewer: a fresh `feature-developer` dispatch, resolved to
**Opus 5.5 (`claude-opus-5-5`)**, its declared `opus`, no override. It changed no
file. This is DV-3. Report as returned, lightly condensed in "What I checked":

What this change does: It adds a `diff-review` skill and makes it step 1 of
advance-story's GATES → REVIEW list, ahead of the full self-test. The old steps
1-5 become 2-6, and the prose that pointed at them by number now says steps 5,
4 and 2. complete-story's GATES → REVIEW bullet now names the review before the
self-test. `procedure.test.sh` gains a guard for all three files, with 53 new
assertions (90 run now), and `fresh_case` was changed from echoing `d` to
setting it, to save forks.

What I checked:
- `fresh_case` refactor: no `$(fresh_case` left; 61 bare call sites, 4 in
  loops; nothing else assigns or `local`s `d`; every fixture writer takes its
  directory as `$1`; `procedure_problems` runs in a subshell and only reads `d`;
  loop-built case names are distinct even case-insensitively.
- `first_step` and the new step 1: the real step 1 (advance-story.md:197-209)
  holds none of the backticked selftest / phase / boundaries needles, so it
  cannot be picked as one of them; its continuation lines are indented with no
  blank line, so the routing words are inside the step.
- `${R%%needle*}` offsets: computed only after both needles are found; `%%`
  leaves the text before the first occurrence; both directions pinned.
- CRLF: the skill goes through the same `load`; `skill-crlf` pins it.
- Needles vs their negation: `Verdict: Ship.` not matched by
  `Verdict: fix 1 first.` or `Verdict: Ship`, both pinned; needles quoted in
  `case` and `${//}`, so `**`, `<id>`, `$1` match literally.
  `bash scripts/gates.sh` also accepts `... --fast`, but C-3 settles it.
- Step references across the tree: only the three updated ones in
  advance-story.md; `lead-po.md:117` and `advance-story.md:315` name GATES →
  REVIEW without a number.
- Readers: `gates.sh` hashes the tree with `:!docs` excluded, so pasting this
  section does not stale the stamp; `check-boundaries.sh` reads
  `## Gate results` by section, unaffected by a section above it;
  `refresh-harness.sh` copies `skills/` whole, so the skill ships with no
  manifest change; `procedure_problems` has no other caller. Ran `procedure`
  90/0 (44 s), and `policy`, `shipped-docs`, `selftest`, `briefs` each passed.
- Load assumed: one developer, one Windows host, CI on Ubuntu.

**Nice to have:**

1. **Expected-value helpers fork once per assertion** (`.claude/tests/procedure.test.sh:450-463`, used at e.g. :838-842, :934-938)
   - **What this is:** The small functions (`no_say`, `no_rword`, `no_step`, `disorder`, ...) that build each assertion's expected line, each called as `"$(no_say "$w")"`.
   - **Problem:** Each `$( )` forks, about 100 ms on this host; the 17-needle and 4-word loops add about 21 such forks, on top of 33 elsewhere.
   - **Fix:** Have the helpers write into a variable with `printf -v`, as `fresh_case` now sets `d`. Test-only; would need a RED pass.
   - **If we skip it:** The suite stays a few seconds slower on Windows. Nothing breaks.

Outside the diff, not a finding against this story: the reviewer saw
`bash scripts/selftest.sh procedure policy shipped-docs` run only `procedure`
and print "1 harness suite(s) passed." without mentioning the other names; it
did not read `selftest.sh`'s argument handling to confirm.

Not checked: `check-boundaries.sh`, which judges the committed phase and so
runs after the REVIEW commit (step 5).

Verdict: Ship.

**Orchestrator's disposition (lead-po):** finding 1 is Nice to have, listed
only, per the skill; no fix this story. The `selftest.sh` multi-name
observation is outside this story's diff and is offered to the user as a
possible follow-up, not acted on here.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-23T05:32:05Z
    commit: 5cbd189
    tree:   32a0b5b4b56ae74646cd3440c9ba5f0dab967027
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

- **Source and credit.** The review method, the finding groups, the four-part
  finding and the verdict line are adapted from ponytail-review,
  github.com/DietrichGebert/ponytail, MIT licence, commit 09c434a (2026-10-18),
  file `skills/ponytail-review/SKILL.md`. Its benchmark figures (100% of planted
  problems found against 87%) are the source's own claims, measured without a
  shell and outside a TDD loop.
- **Planned on Opus 5.5 by explicit override.** PLANNED was dispatched on Opus
  (`claude-opus-5-5`), not lead-po's declared `fable`, because the user's Fable
  usage limit was reached. The user chose in chat to re-run the lead-po planning
  for HARNESS-067 and 068 on Opus and to record the override in both stories.
  The same record is in `## Model guidance`.
- **complete-story duplicates the sequence**, in its `- **GATES → REVIEW`
  bullet (line 28 at PLANNED), so it is in `touches:` and AC-3 covers it.
- **Existing ordering guard:** `procedure.test.sh` (HARNESS-032) pins selftest <
  phase < boundaries in advance-story, and selftest in complete-story's bullet.
  This story extends it rather than adding a suite, which would need a floor
  and would collide with HARNESS-067.
- **PO checks before RED (2026-10-23).** The gate holding the artefact is the
  harness self-test (`procedure`), which CI runs in full; every `gates.sh` gate
  is `<unconfigured>` here, so `required_gates` stays empty. `git grep -l
  procedure_problems` names only `.claude/tests/procedure.test.sh` and two
  story files (HARNESS-032, this one): no other caller. `epic:` is empty.
  `bash scripts/plan.sh conflicts`: "fewer than two startable stories; nothing
  to compare" (HARNESS-067, 069, 070 merged). Baseline before RED:
  `procedure` 37 executed, 37 declared.
- **RED verified by the orchestrator (2026-10-23).** Reran
  `bash scripts/selftest.sh procedure`: `procedure: 88 passed, 2 failed`, the
  real-tree assertion printing exactly the three C-4 lines (A does not name the
  skill, C does not name `diff-review`, S file is missing) and the skill-exists
  precondition failing; the three files GREEN writes are untouched. RED also
  changed `fresh_case` to set `d` rather than echo it (65 call sites), a
  test-only speed change (4m24s to 1m18s locally); fixture contents unchanged.
- Resolved models: RED `test-developer` ran on Opus 5.5 (`claude-opus-5-5`),
  its declared `opus`, no override.
- **GREEN verified by the orchestrator (2026-10-23).** Reran
  `bash scripts/selftest.sh procedure`: 90 assertions executed, 0 failed (RED:
  88 passed, 2 failed); `gates.sh --fast` exit 0. The feature-developer also
  reported `shipped-docs` 14/0 and `policy` 17/0. GREEN wrote only the skill
  and the two commands. It renumbered advance-story's steps 2-6 with one
  `sed -i`; the file classifies as `harness`, writable in GREEN, so this is
  not the lock bypass law 5 names, but the Edit tool would have been the
  cleaner route. Resolved model: GREEN `feature-developer` on Opus 5.5
  (`claude-opus-5-5`), its declared `opus`, no override.
- **For DV-1 at GATES:** the real step-1 line now begins
  ``1. Review the story's diff and its callers with the `diff-review` skill.``
- **Full self-test before REVIEW (2026-10-23, GATES, orchestrator).** After the
  diff review returned `Verdict: Ship.`, `bash scripts/selftest.sh` ran
  detached. A stray `check-boundaries.sh` run the orchestrator had started by
  mistake (it has no `--help`, so it ran the full check; read-only) was waited
  out first; it had already exited. Exit status 0. Last lines:

      assertion floors: all 28 suite(s) met their declared floor (4053 assertions executed, 3825 declared).
      28 harness suite(s) passed.

  Duration: 14243 s (about 3 h 57 min), against ~25 min recorded before on
  this host. Self-test and test runs from other projects (fantasy-world-builder,
  clean_calendar) were running on the same host at the time; that is an
  observation, not a measured cause.
