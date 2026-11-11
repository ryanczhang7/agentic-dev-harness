---
id: HARNESS-101
title: Opus runs the story loop; fable plans, reviews the diff and reads review feedback
slug: opus-runs-the-story-loop-fable-plans-rev
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-101-opus-runs-the-story-loop-fable-plans-rev
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/commands/security-audit.md, .claude/harness/models.conf, .claude/harness/rules.md, .claude/skills/diff-review/SKILL.md, .claude/agents/lead-po.md, .claude/tests/plan.test.sh, .claude/tests/dispatch.test.sh, .claude/tests/procedure.test.sh, .claude/tests/security-audit.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the suites named in Context under their selftest floors, which CI runs in full on the PR
---

## Context

The user's decision of 2026-11-11, made in chat: fable usage is outrunning
overall usage, so the split between `fable` and `opus` is cut again. The
principle: `fable` keeps the highest-leverage judgement - planning, the diff
review, reading review feedback against the contract - and the high-volume,
mostly mechanical work moves to `opus`: the session that orchestrates a story
through its phases, and the security audit.

What this replaces is release 78's split (`rules.md`, "The model each agent
runs on"; the header of `.claude/harness/models.conf`), under which the
orchestrating commands themselves ran on `fable`. An orchestrating session
re-sends its whole context every turn for the length of a story, and most of
what it does is run a script, check a record and dispatch.

Seven things were decided. This story carries five of them; HARNESS-102
carries the two about adjudicating a claim that the contract is wrong
(decisions 5 and 6).

1. `/advance-story` and `/complete-story` declare `model: opus`.
2. PLANNED work still runs on `fable`: the opus orchestrator dispatches it to a
   `lead-po` subagent on the PLANNED row instead of doing it inline.
   `/plan-story`, `/plan-product` and `/create-product` stay on `fable`.
3. The diff review moves to `fable`, on a row of its own in `models.conf`.
4. The diff reviewer labels each finding with its route, and the orchestrator
   follows the label and checks it instead of choosing the route.
7. `/security-audit` declares `model: opus`.

Unchanged, by the same decision: `lead-designer` and `lead-po` declare `fable`;
the REVIEW row stays `fable`; the RED, GREEN, GATES and SCAFFOLD rows stay
`opus`; the RED → GREEN admissibility check stays with the orchestrator.

One consequence the decision implies and does not spell out, written here as
AC-6 so the user can strike it before the story leaves PLANNED: a REVIEW row
that says `fable` means nothing when the session reading the PR's feedback is
`opus`, so that reading becomes a `lead-po` dispatch on the REVIEW row.

**The required gate.** Every gate is unconfigured in this repository. The
artifact is judged by the `plan`, `dispatch`, `procedure` and `security-audit`
suites under their self-test floors, which CI runs in full on the PR.

## Acceptance criteria

- **AC-1** — Given the tree, when the `model:` line of each command's
  frontmatter under `.claude/commands/` is read, then it is: `advance-story`
  `opus`, `complete-story` `opus`, `security-audit` `opus`, `create-product`
  `fable`, `plan-product` `fable`, `plan-story` `fable`. The `model:` each
  agent under `.claude/agents/` declares is what it is today (`lead-po` and
  `lead-designer` `fable`; `test-developer`, `feature-developer` and
  `mutation-tester` `opus`).
- **AC-2** — Given the shipped `.claude/harness/models.conf` and an ordinary
  story, when `bash scripts/plan.sh models <id>` runs, then it prints exactly
  seven rows: today's six, unchanged in phase, agent and model, and
  `DIFF-REVIEW`, `lead-po`, `fable`, placed after the GATES row and before the
  REVIEW row. The same seven are printed for a story with no contract, for one
  whose contract names only paths the lock does not freeze, and for a
  bootstrap story. `bash scripts/plan.sh write <id>` puts the row
  ``| DIFF-REVIEW | `lead-po` | `fable` |``, with its reason, in the story's
  `## Model guidance` table.
- **AC-3** — Given `.claude/commands/advance-story.md`, when its
  **PLANNED → RED** region is read, then it says that the PLANNED work
  (confirming the criteria are testable, naming the required gate, pinning the
  `## Contract`, listing the callers of a changed signature, naming the
  deferred verifications, checking the epic's done-when, and running
  `bash scripts/plan.sh write`) is done by a `lead-po` dispatch on the
  `PLANNED row` of `models.conf`, not by the orchestrator inline; that a
  question the dispatch has for the user comes back to the orchestrator, which
  puts it to the user; and that the orchestrator reads what came back before it
  commits the story at PLANNED. `.claude/commands/complete-story.md` says the
  same in its **PLANNED → RED** bullets. The region as it reads today, with no
  dispatch, is reported as a problem.
- **AC-4** — Given the tree, when the first step of **GATES → REVIEW** in
  `advance-story.md`, the **GATES → REVIEW** bullet of `complete-story.md`, and
  the `## Who runs it` section and frontmatter `description` of
  `.claude/skills/diff-review/SKILL.md` are read, then each names a fresh
  `lead-po` dispatch on the `DIFF-REVIEW row`, and none says the review itself
  runs on a `feature-developer` or on the `GATES row`. The step says the model
  is read from `bash scripts/plan.sh models <id>`, so a story planned before
  the row existed still gets it. The dispatches that run the full gates and
  the self-test stay on the `GATES row`, and so does the feature-developer
  that makes a code fix.
- **AC-5** — Given `.claude/skills/diff-review/SKILL.md`, when its output
  format is read, then every finding has a fifth part, `**Route:**`, whose
  value is exactly one of `GATES` (a code fix, made in GATES by a
  feature-developer dispatch), `RED` (a test added or changed: a return to RED
  with a `## Regressions` entry) or `AMEND` (a question about an acceptance
  criterion, for the user, recorded under `## Amendments`), and the worked
  example carries one. Its section on what happens to a finding, and step 1 of
  **GATES → REVIEW** in `advance-story.md`, say that the orchestrator follows
  the label and does not choose the route; that it checks the label before
  acting, by asking `bash scripts/classify.sh` about each path the fix names
  and reading the answer against what the phase the label names may write; and
  that a label it cannot follow goes back to a fresh `DIFF-REVIEW row`
  dispatch to be relabelled, never relabelled by the orchestrator.
- **AC-6** — Given `advance-story.md`, when what it says about a story at
  REVIEW is read, then it says that feedback on the open PR that asks for a
  change (a reviewer's comment, a CI failure) is read against the contract by a
  `lead-po` dispatch on the `REVIEW row`, which labels each item with a
  `Route` as AC-5 defines, and that the orchestrator follows and checks that
  label the same way. Setting the phase, clearing the lock, reading the CI
  timings and relaying `bash scripts/plan.sh after <id>` stay the
  orchestrator's own.
- **AC-7** — Given `.claude/harness/rules.md`, when the section
  `# The model each agent runs on` is read, then it states the split of
  2026-11-11 and the reason for it: `/advance-story`, `/complete-story` and
  `/security-audit` declare `opus`; the planning commands, `lead-po` and
  `lead-designer` declare `fable`; inside a story `fable` is reached by
  dispatch, on the PLANNED, DIFF-REVIEW and REVIEW rows; GREEN and GATES never
  move to a model judged weaker at the work. It no longer says that the
  orchestrating commands declare `fable`, nor that every row but PLANNED and
  REVIEW is `opus`. The header comment of `models.conf` and
  `.claude/agents/lead-po.md` say the same and nothing that contradicts it.
  The section keeps its heading, the paragraph that opens
  ``**The per-phase plan is `.claude/harness/models.conf`, not a judgement made``
  and its pointer to `reference/cases.md`, so `rules-trim.test.sh` passes
  without being edited.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/commands/security-audit.md`, `.claude/harness/models.conf`, `.claude/harness/rules.md`, `.claude/skills/diff-review/SKILL.md`, `.claude/agents/lead-po.md`, `.claude/tests/plan.test.sh`, `.claude/tests/dispatch.test.sh`, `.claude/tests/procedure.test.sh`, `.claude/tests/security-audit.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, which the lock
permits in every phase, so this block is the only thing dividing RED from
GREEN. RED (test-developer) writes the four `.claude/tests/*.test.sh` suites
and nothing else. GREEN (feature-developer) writes the commands, `models.conf`,
`rules.md`, the skill, `lead-po.md`, `VERSION`, and the two floor records
(`floors.conf` and the mirror table in `selftest.test.sh`, raised to the
executed counts GREEN measures, as HARNESS-095 and HARNESS-100 did).

**C-1. The frontmatter (AC-1).** One line each, nothing else in the
frontmatter changes: `model: opus` in `advance-story.md`, `complete-story.md`
and `security-audit.md`. `create-product.md`, `plan-product.md`,
`plan-story.md` and every file under `.claude/agents/` are not edited for
their `model:`.

**C-2. The row (AC-2).** One line in `models.conf`, in the existing `model |`
grammar, between the GATES row and the REVIEW row:

    model  | DIFF-REVIEW | lead-po | fable | <why>

The reason says what the user decided: reading a whole diff for the defect no
test was written for is judgement against the contract, and it is where a
wrong call ships.

- *Why a row in the phase column and not a new row kind.* `plan.sh` does not
  check that column against `phases.conf`: `cmd_models` prints every `model`
  row as it stands, `plan.sh <id>` lists it and `plan.sh write` renders it
  into the story's table. Measured at PLANNED on a scratch copy of this tree
  at `5e52301`, with the row added: `plan.sh models` printed
  `DIFF-REVIEW<TAB>lead-po<TAB>fable<TAB>...` between GATES and REVIEW, and
  `plan.sh write` wrote ``| DIFF-REVIEW | `lead-po` | `fable` | ... |``. So
  **`scripts/plan.sh` is not changed by this story.** A new kind (`step |`)
  would need a parser change, a renderer change and a second vocabulary, for
  the same table.
- *The one cost, accepted.* `plan.sh <id>` pads the first column to nine
  characters and `DIFF-REVIEW` is eleven, so that one line of the human
  listing sits two columns right of the others. Nothing parses that listing.
- *The format comment in the file's header* says the second field is a phase
  of `phases.conf` or a named step inside one, and names `DIFF-REVIEW` as the
  step that opens GATES → REVIEW.
- *Why `lead-po` and not `feature-developer`.* `feature-developer` declares
  `opus`. A dispatch that loses its explicit model falls back to the agent's
  own `model:`, silently, so a diff review planned for `fable` on that agent
  would land on `opus` with nothing saying so. `lead-po` declares `fable`, so
  the plan and the fallback agree. It is also the role that never writes
  source or tests (`rules.md`, "Path ownership"), which is what the review
  requires of its reviewer, in a phase (GATES) where a feature-developer may
  write source.

**C-3. Where each statement goes, and its needles.** Each needle sits on one
line of the file, so a fixed-string match can find it. GREEN wraps its prose
to keep them whole.

| Region | Must contain | Must not contain |
|---|---|---|
| `advance-story.md`, **PLANNED → RED** region (from that marker to the next `**X → Y.**` marker) | `lead-po`, `PLANNED row` | - |
| `complete-story.md`, the **PLANNED → RED** bullets | `lead-po`, `PLANNED row` in at least one of them | - |
| `advance-story.md`, step 1 of **GATES → REVIEW** (from `1. ` to `2. `) | `lead-po`, `DIFF-REVIEW row`, `bash scripts/plan.sh models`, `Route`, `bash scripts/classify.sh` | `GATES row` |
| `complete-story.md`, the **GATES → REVIEW** bullet | `lead-po`, `DIFF-REVIEW row` | `fresh feature-developer` |
| `diff-review/SKILL.md`, frontmatter `description` | `lead-po` | `feature-developer` |
| `diff-review/SKILL.md`, `## Who runs it` (to the next `## `) | `lead-po`, `DIFF-REVIEW row` | `feature-developer`, `GATES row` |
| `diff-review/SKILL.md`, output section | `**Route:**`, and each of `GATES`, `RED`, `AMEND` as a route value; a `**Route:**` line inside the indented example | - |
| `diff-review/SKILL.md`, what happens to a finding | `follows the label`, `bash scripts/classify.sh`, `DIFF-REVIEW row` | - |
| `advance-story.md`, the REVIEW statement of AC-6 | `lead-po`, `REVIEW row`, `Route` | - |
| `rules.md`, `# The model each agent runs on` (to the next `# `) | `advance-story`, `complete-story`, `security-audit`, `DIFF-REVIEW`, `2026-11-11` | `and the orchestrating commands` |
| `lead-po.md` | `DIFF-REVIEW row` | - |

Step 1 of GATES → REVIEW still says a code fix is made by a feature-developer
dispatch; that word is allowed there. What may not be there is `GATES row`.
The dispatches for the full gates and the self-test keep `GATES row`, and
`dispatch.test.sh`'s HARNESS-085 and HARNESS-095 needles for them are not
edited. Fixtures in `dispatch.test.sh` and `procedure.test.sh` that quote step
1 or the bullet in today's words are updated to the new words.

**C-4. The route label (AC-5).** A fifth part on every finding, after
`**If we skip it:**`, in every severity group, a Nice-to-have included:

       - **Route:** GATES

Exactly one of three values, nothing after it on the line:

| Value | Means | The orchestrator then |
|---|---|---|
| `GATES` | the fix is in production code or config | dispatches a feature-developer in GATES; gates run again and the GATES → REVIEW steps start over |
| `RED` | a test has to be added or changed | sets the phase back to RED, with a `## Regressions` entry |
| `AMEND` | an acceptance criterion is in question; the finding names it (`AC-<n>`) | stops and puts it to the user; the outcome goes under `## Amendments` |

A Missing-test finding is `RED` by definition. The verdict line is unchanged.

**C-5. Following and checking a label (AC-5, AC-6).** The orchestrator does
not choose a route. Before acting on one it runs `bash scripts/classify.sh` on
each path the finding's Fix names and reads the category against the phase
table in `rules.md`: a `GATES` label whose fix names a `test` path, or a `RED`
label whose fix names only `source` or `config` paths, is a label the phase
lock would refuse, so it cannot be followed. An `AMEND` label with no `AC-<n>`
in the finding cannot be followed either. Such a finding goes back to a fresh
dispatch on the row that produced it, with the classification pasted, to be
relabelled. In a repository where the paths classify as `harness` (this one)
the lock permits both phases and the check passes; the text says so rather
than pretending the check decides there.

**C-6. PLANNED by dispatch (AC-3).** The dispatch gets the story id and file
path and the PLANNED → RED checklist that is in `advance-story.md` today; it
writes the story's sections and runs `bash scripts/plan.sh write <id>` last.
It cannot ask the user anything, so it returns its questions and the
orchestrator relays them. When it returns, the orchestrator reads the
`Contract`, `Deferred verifications` and `Model guidance` sections with
`bash scripts/story.sh section`, records the model the dispatch resolved to,
and only then commits at PLANNED and sets the phase. The checklist text stays
in `advance-story.md`, as the brief the orchestrator pastes.

**C-7. `rules.md` (AC-7).** The section is rewritten, not appended to. It
keeps: its heading; the sentence that every definition declares `model:`; the
asymmetry (GREEN and GATES never on a model judged weaker at the work); the
half-rule in bold that `lead-po` records the resolved model of every dispatch;
and the whole paragraph beginning
``**The per-phase plan is `.claude/harness/models.conf`, not a judgement made``
with its `reference/cases.md` pointer, changed only where it lists which rows
are `fable`. `rules-trim.test.sh` pins the heading, that paragraph's opening
line and two pointer texts; run `bash scripts/selftest.sh rules-trim` and keep
it green without editing it. If one of its needles turns out to quote the old
split, that is a RED amendment to this block, with the needle named.

**C-8. `lead-po.md`.** `model: fable` stays. It gains a short statement of the
work that reaches it as a dispatch from an opus orchestrator - planning on the
PLANNED row, the diff review on the DIFF-REVIEW row, PR feedback on the REVIEW
row - and that in those dispatches it reports back and does not orchestrate.
The sentence "you are declared `fable` and SCAFFOLD runs you on `opus`" stays
true and stays. The paragraph pinned by `dispatch.test.sh` (`LONG_NEEDLES`,
the long runs on the GATES row) is not reworded.

**C-9. Where the assertions live.**

| Suite | Holds |
|---|---|
| `plan.test.sh` | AC-1 (the command set, now six commands with `security-audit`, and the unchanged agent set) and AC-2 (`SHIP_EXPECTED` with seven rows, for all four story shapes; the rendered table row) |
| `dispatch.test.sh` | AC-3, AC-4 and AC-6: the regions and needles of C-3 that say who is dispatched on which row, checked over the real tree by its existing `dispatch_problems` pattern, each with a fixture that fails it and a compliant twin |
| `procedure.test.sh` | AC-5: the `**Route:**` part, its three values, the example, and the follow-and-check wording, beside the diff-review needles it already holds |
| `security-audit.test.sh` | the `F	model: fable` needle becomes `model: opus` |

AC-7's needles go in `dispatch.test.sh` or `procedure.test.sh`, RED's choice,
stated in the handoff.

**Oracle partition.** Every criterion is **mechanical**: a frontmatter value,
a row, a fixed string in a named region. Pin each exactly, anchor the region,
and prefer a needle whose absence is also checked (C-3's third column). Nothing
here is oracle-free and nothing carries a number to derive.

**Callers.** No export changes signature. The existing assertions that pin
today's values, and so go red when RED rewrites their expectations: in
`plan.test.sh`, `SHIP_EXPECTED` (lines 104-111) and "each orchestrating
command runs on fable" (lines 150-157); in `security-audit.test.sh`, the
`model: fable` needle (line 90); in `dispatch.test.sh` and
`procedure.test.sh`, the fixtures quoting step 1 (`S1`, line 425 and line
482). RED's handoff states it grepped `fable`, `GATES row` and
`feature-developer` across `.claude/tests/` and lists any other.

**Test-only dependencies.** None.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one defect put back, one
probe against a real line of the tree, and one mutation per assertion that
passes on arrival. Each runs through `scripts/mutate.sh` against the one suite
that holds the assertion.

- **DV-1, the defect put back (AC-1).** With `advance-story.md` back on
  `model: fable`, the command-set assertion in the `plan` suite must fail.
  RED cannot run this: in RED the file still says `fable` and the assertion is
  red for that reason. **Owner: GATES.**

      bash scripts/mutate.sh .claude/commands/advance-story.md 's/^model: opus$/model: fable/' -- bash scripts/selftest.sh plan

- **DV-2, a real line of the tree (AC-4).** The region check is a rule over
  the tree, and its fixtures are written from the same reading as the rule.
  With `DIFF-REVIEW row` changed back to `GATES row` in step 1 of
  GATES → REVIEW in the real `advance-story.md`, the `dispatch` suite's
  real-tree assertion must fail, naming that step. The expression is written
  against GREEN's wording, so RED cannot run it. **Owner: GATES.**

- **DV-3, assertions that pass on arrival.** RED lists in its handoff every
  assertion it wrote that was green on its first run - a candidate is any
  "stays as it is" check not folded into a whole-set comparison - with the
  mutation that would turn it red. Each is run once. If RED lists none, write
  `WAIVED: no assertion passed on arrival` here with the handoff line that
  says so. **Owner: GATES.**

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
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-101` from `.claude/harness/models.conf`.
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

- PLANNED (2026-11-11, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the session that ran `/plan-story`; no override was reported to it, and the agent declares `model: fable`.
- No departure from the plan. Note for the orchestrator: the DIFF-REVIEW row does not exist until this story merges, so this story's own diff review runs as today, on a fresh `feature-developer` on the GATES row; record what it resolved to.
## Out of scope

- **Adjudicating a claim that the contract is wrong** (decisions 5 and 6): the
  `ADJUDICATE` row, the rewrite of the "reproduce independently" rule and the
  `check-boundaries.sh` refusal are HARNESS-102. The rule in
  `advance-story.md`'s "Rules for you as orchestrator", in `complete-story.md`
  and in `lead-po.md` is left word for word as it is here.
- **`scripts/plan.sh`.** Not changed; C-2 says why. No column is widened and
  the table header stays `Phase`.
- **`scripts/check-boundaries.sh`.** Not changed. Nothing checks that a
  `## Diff review` section carries routes; the label is procedure here.
- **The other rows and agents.** RED, GREEN, GATES, REVIEW and SCAFFOLD keep
  their agent and model. No agent's `model:` changes. `lead-designer` is not
  touched.
- **`/plan-story`, `/plan-product`, `/create-product`, `/audit-mutations`,
  `/setup-environment`, `/status`.** Not edited.
- **The RED → GREEN admissibility check**, the mutation-table check and every
  `attest.sh check` stay with the orchestrator, on `opus`.
- **`/security-audit` beyond its `model:` line.** Its subagent types, budget
  and report format are untouched.
- **`CLAUDE.md`.** Read at PLANNED: it states no model split, so it is not
  edited.
- **Past stories' `## Model guidance`** and
  `docs/wiki/audits/model-split-2026-10-05.md`. They record what was planned
  and resolved at the time.
- **`story-authoring`'s account of the brief-against-model measurement.** It
  is history and still true as history.
- **Measuring whether fable usage fell.** The harness cannot see usage; the
  user reads that from their account.

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


- Planned 2026-11-11 from the user's seven decisions of that day, on `main` at `5e52301`. Split in two: this story is the re-assignment (decisions 1-4 and 7), HARNESS-102 the adjudication rule and its `check-boundaries.sh` trigger (5 and 6). Not split further: decisions 1-4 and 7 edit the same seven files, so two stories cut from them would collide on every one and each would pay for its own self-test run.
- The id was checked free at planning: no `HARNESS-101.md` or `HARNESS-102.md` in `docs/backlog/stories/`, and `git ls-remote --heads origin 'story/HARNESS-10*'` printed nothing.
- AC-6 (PR feedback read by a `lead-po` dispatch on the REVIEW row) is an inference from "the REVIEW row stays fable", not one of the seven decisions. It is reported to the user for a yes or no before this story leaves PLANNED.
- C-2's measurement was made on a scratch copy of the tree outside the repository, then deleted; nothing in the tree was changed to make it.
- **User answer, 2026-11-11:** AC-6 confirmed — PR feedback is read by a fresh `lead-po` dispatch on the REVIEW row. Asked in chat before the story left PLANNED; no criterion changed.
