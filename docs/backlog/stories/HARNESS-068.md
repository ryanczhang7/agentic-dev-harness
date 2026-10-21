---
id: HARNESS-068
title: A diff review reads the change and its callers before the PR opens
slug: a-diff-review-reads-the-change-and-its-c
epic: 
type: feature
status: todo
phase: PLANNED
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

**DV-2, the skill rule against a real line.** Delete the REAL skill's line
holding `No case, no finding.` with `mutate.sh` (expression
`'/No case, no finding\./d'`), then run `bash scripts/selftest.sh procedure`. It
**must** fail with exactly that one "does not say" line, and the file must be
restored. **Owner: GATES.**

**DV-3, the review runs once on this story's own diff.** At this story's GATES
→ REVIEW, the orchestrator follows the new step 1 on HARNESS-068's own diff and
pastes the report into `## Diff review`. This is the first real use, and it is
evidence the procedure is followable, not a test of the review's quality.
**Owner: GATES.**

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

## Handoff: RED -> GREEN

## Gate results

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
