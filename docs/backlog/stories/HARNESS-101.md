---
id: HARNESS-101
title: Opus runs the story loop; fable plans, reviews the diff and reads review feedback
slug: opus-runs-the-story-loop-fable-plans-rev
epic: 
type: feature
status: in-progress
phase: GREEN
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
| `complete-story.md`, the **PLANNED → RED** bullets (each from a line beginning `- **PLANNED → RED` to the next `- ` line or blank line) | `lead-po` and `PLANNED row`, both in the same one of them *(RED amendment A-1)* | - |
| `advance-story.md`, step 1 of **GATES → REVIEW** (from `1. ` to `2. `) | `lead-po`, `DIFF-REVIEW row`, `bash scripts/plan.sh models`, `Route`, `bash scripts/classify.sh`, `follows the label` *(A-2)* | `GATES row` |
| `complete-story.md`, the **GATES → REVIEW** bullet | `lead-po`, `DIFF-REVIEW row` | `fresh feature-developer` |
| `diff-review/SKILL.md`, frontmatter `description` | `lead-po` | `feature-developer` |
| `diff-review/SKILL.md`, `## Who runs it` (to the next `## `) | `lead-po`, `DIFF-REVIEW row` | `feature-developer`, `GATES row` |
| `diff-review/SKILL.md`, output section (from the `## ` heading ending `Output` to the next `## `) | `**Route:**`; each of `` `GATES` ``, `` `RED` ``, `` `AMEND` `` as a backticked span *(A-3)*; inside the four-space-indented example, a line that trimmed is exactly `- **Route:** GATES`, `- **Route:** RED` or `- **Route:** AMEND`, after the example's `- **If we skip it:**` line *(A-3)* | `all four parts` *(A-4)* |
| `diff-review/SKILL.md`, what happens to a finding (from the `## ` heading containing `What happens to a finding` to the next `## `) | `follows the label`, `bash scripts/classify.sh`, `DIFF-REVIEW row` | - |
| `advance-story.md`, the REVIEW statement of AC-6: the **REVIEW → DONE** region, from the line beginning `**REVIEW → DONE.**` to just before the next paragraph that begins `**` *(A-5)* | `lead-po`, `REVIEW row` (matched with every `DIFF-REVIEW row` taken out first), `Route`; and, staying the orchestrator's own, `bash scripts/phase.sh clear`, `bash scripts/plan.sh after`, `read the timings` *(A-5)* | - |
| `rules.md`, `# The model each agent runs on` (to the next `# `) | `advance-story`, `complete-story`, `security-audit`, `DIFF-REVIEW`, `2026-11-11` | `and the orchestrating commands`, `PLANNED and REVIEW on` *(A-6)* |
| `models.conf`, the header comment (every line beginning `#`, the `#` removed) *(A-7)* | `DIFF-REVIEW` | `The orchestrating commands and the planning agents` |
| `lead-po.md` | `DIFF-REVIEW row` | - |

**RED amendments to C-3 and C-9 (test-developer, 2026-11-11).** Each is in
place above or below; GREEN builds what the amended block says.

- *Matching.* Every region is flattened before it is searched - its lines
  trimmed and joined by one space - so a needle GREEN wraps across a line
  break still counts, and a forbidden phrase wrapped across one is still
  present. The "each needle sits on one line" sentence above is therefore no
  longer a requirement on GREEN; keeping needles whole is still the safer
  prose.
- *A-1.* "in at least one of them" read as: one bullet carries both needles.
  Two bullets each carrying one would let the PLANNED dispatch and its row be
  said in unrelated sentences.
- *A-2.* AC-5 says step 1 states that the orchestrator follows the label; C-3
  listed `Route` and `classify.sh` for step 1 but not `follows the label`.
  The procedure suite pins it there, as it does in the skill.
- *A-3.* "as a route value" made exact. A bare `GATES` or `RED` is in half
  the prose of any file here (`GATES → REVIEW`, `a return to RED`) and would
  float, so the values are backticked spans in the output section, and the
  example's line is matched whole, so `- **Route:** GATES or RED` is not a
  route and nothing may follow the value (C-4: "nothing after it on the line").
- *A-4.* AC-5: every finding has a FIFTH part. The section today says "Every
  finding has all four parts"; left as it is, it contradicts the criterion.
- *A-5.* C-3 named "the REVIEW statement of AC-6" without a region. It is
  pinned to the REVIEW → DONE region, the existing place advance-story
  speaks about a story at REVIEW; the statement must therefore not open a
  paragraph with `**`, which would end the region. `REVIEW row` is a
  substring of `DIFF-REVIEW row`, so it is matched only after every
  `DIFF-REVIEW row` is removed. AC-6's "stay the orchestrator's own" is
  pinned as presence of the three duties in that same region (green on
  arrival; see the handoff's DV-3 list).
- *A-6.* AC-7: the section "no longer says ... that every row but PLANNED and
  REVIEW is `opus`". Today's sentence is "PLANNED and REVIEW on `fable`";
  C-3 had no needle for it.
- *A-7.* AC-7: "The header comment of `models.conf` ... say[s] the same and
  nothing that contradicts it", and C-2 asks the format comment to name
  `DIFF-REVIEW`. C-3 had no row for it. Only comment lines are read, so the
  new `model | DIFF-REVIEW | ...` row cannot stand in for the header. The
  must-not is today's header sentence "The orchestrating commands and the
  planning agents (`lead-po`, `lead-designer`) declare `fable`".
- *C-9, `security-audit.test.sh`.* The `F` needle `model: fable` becomes
  `F	model: opus` as written, but an `F` row is a fixed string anywhere in the
  file, and that command's body already says `` `model: opus` `` twice (the
  hunters' and research agents' lines). Alone it would be green on arrival and
  green with the frontmatter still on `fable`. The suite also reads the
  frontmatter `model:` value of the real command and compares it whole with
  `opus`.

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

All seven criteria are mechanical (a frontmatter value, a row, a fixed string
in a named region), so every check is a structural read of the shipped files:
the shape `tdd-cycle` calls "code no machine you have can execute: grep for the
shape". Each guard runs three ways: over the real tree (must be silent / equal
the pinned value), over a fixture compliant by construction (silent), and over
fixtures with one thing regressed (exactly the pinned lines). Needles are
anchored to a region, a forbidden phrase is checked wherever C-3 gives one, and
every region is flattened so reflowed prose neither hides a needle nor hides a
forbidden phrase.

| AC | Suite | Assertion(s) |
|---|---|---|
| AC-1 | `plan` | "HARNESS-101 AC-1: the story loop and the security audit run on opus, the planning commands on fable" - one whole-set compare of six commands' frontmatter `model:` (replaces "each orchestrating command runs on fable"). "each agent declares the model of its kind of work" - unchanged, the agent half of AC-1. |
| AC-1 | `security-audit` | NEEDLES row 2 is now `M	model: opus` (a frontmatter line, compared whole); "command_problems over the real command prints nothing" reads it; "HARNESS-101 AC-1 control: a frontmatter on `model: fable` with `model: opus` in the body gives exactly the frontmatter line"; the existing "with needle 2 removed ..." loop entry now exercises the M kind. |
| AC-2 | `plan` | `SHIP_EXPECTED` gains `DIFF-REVIEW lead-po fable`, so the four whole-set compares (ordinary, no contract, unenforced contract, bootstrap) each demand exactly seven rows; "HARNESS-101 AC-2: the plan lists DIFF-REVIEW after GATES and before REVIEW ..." (unsorted phase order, all four shapes); "HARNESS-101 AC-2: plan.sh write puts exactly one `\| DIFF-REVIEW \| ...` row ..., with a reason". |
| AC-3 | `dispatch` | `row_problems` real-tree assertion (PLANNED → RED region; complete-story's PLANNED → RED bullets); fixtures `pl-today` (control), `pl-without-*` (each needle), `pl-after-marker`, `pl-none`, `cb-pl-today` (control), `cb-pl-split`, `cb-pl-next-bullet`. |
| AC-4 | `dispatch` | `row_problems` real-tree assertion (step 1 needles + `GATES row` absent; complete-story's GATES → REVIEW bullet; SKILL description; `## Who runs it`); fixtures `step1-today` (control), `step1-without-*`, `step1-gates-row`, `step1-in-step2`, `step1-none`, `cb-gr-today` (control), `cb-gr-without-*`, `cb-gr-fresh-wrapped`, `sk-today` (control), `sk-desc-body`, `sk-desc-fd`, `sk-desc-none`, `sk-who-without-*`, `sk-who-with-*`, `sk-who-none`. The HARNESS-085/095 needles for the long runs on the GATES row (`dispatch_problems`, `LONG_NEEDLES`, `BULLET_NEEDLES`) are not edited and still hold. |
| AC-5 | `procedure` | `route_problems` real-tree assertion; fixtures `example-AMEND`/`example-RED` (other values pass), `output-today` (control), `output-without-GATES/RED/AMEND`, `output-without-part`, `output-four-parts`, `example-no-route`, `example-two-values`, `example-other-value`, `example-unindented`, `example-route-first`, `output-none`, `what-today` (control), `what-without-*`, `what-none`, `step1-today` (control), `step1-without-*`, `step1-none`, missing files. |
| AC-6 | `dispatch` | `row_problems` real-tree assertion (REVIEW → DONE region: `lead-po`, `REVIEW row` with `DIFF-REVIEW row` removed first, `Route`, and the three duties that stay the orchestrator's); fixtures `rd-today` (control), `rd-without-*` (six needles), `rd-only-diff-review`, `rd-bold-paragraph`, `rd-none`. |
| AC-7 | `dispatch` (RED's choice) | `row_problems` real-tree assertion (rules.md section needles and the two must-nots; models.conf header; lead-po.md); fixtures `ru-today` (control), `ru-without-*`, `ru-with-*`, `ru-none`, `mc-today` (control), `lp-without`. `rules-trim.test.sh` is not edited; none of its needles quotes the old split (read at RED: its WHOLE/PREFIXES/NEEDLES/POINTED lists), so C-7 needs no amendment. |
| all | `dispatch` | "a tree with today's wording in all six files prints all 31 lines, file by file in C-3's order" - the today-shaped fixture prints exactly the 31 lines the real tree printed in RED. |

## Handoff: RED -> GREEN

Written by the test-developer, 2026-11-11. Model resolved: `opus`
(claude-opus-5-5), the agent's own declaration; no override in the dispatch.

**Command.**

    bash scripts/selftest.sh plan dispatch procedure security-audit

Run through attest as
`bash scripts/attest.sh -- bash scripts/selftest.sh plan dispatch procedure security-audit`.
Record: `exit: 1`, `last: 4 of 4 harness suite(s) FAILED.`, `duration: 338s`
(local, a loaded Windows host), tree `1446ed528101f154e8b0fed62552c59cd7d163f1`,
log `.claude/state/attest-logs/20261111T173709Z.139081.log`;
`attest.sh check -- <same words>` answered `fresh` after the run.

`bash scripts/attest.sh -- bash scripts/gates.sh --fast`: `exit: 0`,
`last: All required gates passed (0 ran, 5 unconfigured, 0 known).`, log
`.claude/state/attest-logs/20261111T174248Z.167459.log`. Every gate is
UNCONFIGURED here (lint, typecheck, unit, coverage; mutation ON REQUEST;
integration and build skipped by `--fast`), so `--fast` has nothing to judge:
no timeout, config error or lint rule is in play. The harness's own judge is
the self-test, above.

**Files written (RED's four, per Contract "Who writes which").**
`.claude/tests/plan.test.sh`, `.claude/tests/dispatch.test.sh`,
`.claude/tests/procedure.test.sh`, `.claude/tests/security-audit.test.sh`; and
this story (`## Contract` C-3/C-9 amendments, `## Test plan`, this section).
Nothing else. Not touched: the commands, `models.conf`, `rules.md`, the skill,
`lead-po.md`, `VERSION`, `floors.conf`, `selftest.test.sh`.

**The failure, and why it is the right one.** Every red assertion is a
real-tree read that still finds today's text; every fixture assertion (the
guard against twins compliant and regressed) is green, and no suite failed to
load. Per suite, executed = passed + failed:

| Suite | Result in RED | Executed | Floor now | Floor GREEN writes |
|---|---|---|---|---|
| `plan` | 279 passed, 7 failed | 286 | 284 | 286 |
| `dispatch` | 144 passed, 1 failed | 145 | 83 | 145 |
| `procedure` | 182 passed, 1 failed | 183 | 154 | 183 |
| `security-audit` | 51 passed, 1 failed | 52 | 51 | 52 |

The floor counts PASSED units, so `plan` also prints
`FAIL plan  did 279 units of work, below the floor of 284` until GREEN lands -
expected in RED, as HARNESS-065 recorded. GREEN raises the four values in
`.claude/tests/floors.conf` and the mirror table in
`.claude/tests/selftest.test.sh` to the executed counts it measures (the right
column is what RED measured; with the probe tree below all four were green at
exactly those counts).

`plan` (7 failures, log lines 82-150):

```
FAIL an ordinary story: fable plans and reviews, opus writes and tests the code
     expected: DIFF-REVIEW lead-po fable / GATES ... / SCAFFOLD lead-po opus  (seven rows)
     actual:   GATES feature-developer opus / ... / SCAFFOLD lead-po opus     (six rows, no DIFF-REVIEW)
FAIL with no contract, the plan is the same                      (same seven vs six)
FAIL with a contract the lock cannot police, the plan is the same (same)
FAIL for a bootstrap story, the plan is the same                 (same)
FAIL HARNESS-101 AC-2: the plan lists DIFF-REVIEW after GATES and before REVIEW, the other six in today's order, for all four story shapes
     expected: S-1: PLANNED RED GREEN GATES DIFF-REVIEW REVIEW SCAFFOLD (x4)
     actual:   S-1: PLANNED RED GREEN GATES REVIEW SCAFFOLD (x4)
FAIL HARNESS-101 AC-2: plan.sh write puts exactly one `| DIFF-REVIEW | `lead-po` | `fable` | <why> |` row in ## Model guidance, with a reason
     expected: 1 row-with-reason
     actual:   0 not the row: []
FAIL HARNESS-101 AC-1: the story loop and the security audit run on opus, the planning commands on fable
     expected: advance-story opus / complete-story opus / create-product fable / plan-product fable / plan-story fable / security-audit opus
     actual:   advance-story fable / complete-story fable / create-product fable / plan-product fable / plan-story fable / security-audit fable
```

(The four set compares are abbreviated with `/` here; the log has them one row
per line.)

`dispatch` (1 failure, the real-tree `row_problems`; actual, verbatim):

```
.claude/commands/advance-story.md: PLANNED → RED does not say `lead-po`
.claude/commands/advance-story.md: PLANNED → RED does not say `PLANNED row`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `lead-po`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `DIFF-REVIEW row`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `bash scripts/plan.sh models`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `Route`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `bash scripts/classify.sh`
.claude/commands/advance-story.md: GATES → REVIEW step 1 still says `GATES row`
.claude/commands/advance-story.md: REVIEW → DONE does not say `lead-po`
.claude/commands/advance-story.md: REVIEW → DONE does not say `REVIEW row`
.claude/commands/advance-story.md: REVIEW → DONE does not say `Route`
.claude/commands/complete-story.md: no PLANNED → RED bullet says both `lead-po` and `PLANNED row`
.claude/commands/complete-story.md: its GATES → REVIEW bullet does not say `lead-po`
.claude/commands/complete-story.md: its GATES → REVIEW bullet does not say `DIFF-REVIEW row`
.claude/commands/complete-story.md: its GATES → REVIEW bullet still says `fresh feature-developer`
.claude/skills/diff-review/SKILL.md: its description does not say `lead-po`
.claude/skills/diff-review/SKILL.md: its description still says `feature-developer`
.claude/skills/diff-review/SKILL.md: ## Who runs it does not say `lead-po`
.claude/skills/diff-review/SKILL.md: ## Who runs it does not say `DIFF-REVIEW row`
.claude/skills/diff-review/SKILL.md: ## Who runs it still says `feature-developer`
.claude/skills/diff-review/SKILL.md: ## Who runs it still says `GATES row`
.claude/harness/rules.md: # The model each agent runs on does not say `advance-story`
.claude/harness/rules.md: # The model each agent runs on does not say `complete-story`
.claude/harness/rules.md: # The model each agent runs on does not say `security-audit`
.claude/harness/rules.md: # The model each agent runs on does not say `DIFF-REVIEW`
.claude/harness/rules.md: # The model each agent runs on does not say `2026-11-11`
.claude/harness/rules.md: # The model each agent runs on still says `and the orchestrating commands`
.claude/harness/rules.md: # The model each agent runs on still says `PLANNED and REVIEW on`
.claude/harness/models.conf: its header comment does not say `DIFF-REVIEW`
.claude/harness/models.conf: its header comment still says `The orchestrating commands and the planning agents`
.claude/agents/lead-po.md: the file does not say `DIFF-REVIEW row`
```

`procedure` (1 failure, the real-tree `route_problems`; actual, verbatim):

```
.claude/skills/diff-review/SKILL.md: its output section does not say `**Route:**`
.claude/skills/diff-review/SKILL.md: its output section does not name the route value `GATES`
.claude/skills/diff-review/SKILL.md: its output section does not name the route value `RED`
.claude/skills/diff-review/SKILL.md: its output section does not name the route value `AMEND`
.claude/skills/diff-review/SKILL.md: its output section still says `all four parts`
.claude/skills/diff-review/SKILL.md: its example has no `- **Route:** GATES`, `RED` or `AMEND` line
.claude/skills/diff-review/SKILL.md: what happens to a finding does not say `follows the label`
.claude/skills/diff-review/SKILL.md: what happens to a finding does not say `bash scripts/classify.sh`
.claude/skills/diff-review/SKILL.md: what happens to a finding does not say `DIFF-REVIEW row`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `follows the label`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `bash scripts/classify.sh`
.claude/commands/advance-story.md: GATES → REVIEW step 1 does not say `DIFF-REVIEW row`
```

`security-audit` (1 failure):

```
FAIL command_problems over the real command prints nothing
     expected:
     actual:   security-audit.md: its frontmatter has no line `model: opus`
```

**What each new or rewritten assertion pins (one line each).**

- plan, the four `SHIP_EXPECTED` compares - `plan.sh models` prints exactly the seven (phase, agent, model) rows, DIFF-REVIEW/lead-po/fable added, for ordinary / no-contract / unenforced / bootstrap stories (AC-2).
- plan, "the plan lists DIFF-REVIEW after GATES and before REVIEW ..." - the unsorted phase column is `PLANNED RED GREEN GATES DIFF-REVIEW REVIEW SCAFFOLD` for all four shapes (AC-2).
- plan, "plan.sh write puts exactly one ... row" - the written story holds one line beginning ``| DIFF-REVIEW | `lead-po` | `fable` | `` with a non-blank reason cell (AC-2).
- plan, "the story loop and the security audit run on opus ..." - six commands' frontmatter `model:`, one whole-set compare (AC-1).
- security-audit, NEEDLES row 2 `M	model: opus` and the real-tree `command_problems` - the command's frontmatter has the line `model: opus`, compared whole (AC-1).
- security-audit, "HARNESS-101 AC-1 control" - a frontmatter on `fable` with `model: opus` in the body prints exactly the M line (the float the F row had).
- dispatch, `row_problems` over the real tree - every C-3 region and needle of AC-3, AC-4, AC-6, AC-7, as amended (silent once GREEN lands).
- dispatch, the HARNESS-101 fixture cases - each region's needles, forbidden words and boundaries, one line per regression (AC-3, AC-4, AC-6, AC-7); see `## Test plan` for the list.
- procedure, `route_problems` over the real tree - the Route part, its three values, the example line, and the follow-the-label wording in the skill and step 1 (AC-5).
- procedure, the HARNESS-101 AC-5 fixture cases - see `## Test plan`.

**Interface GREEN must meet - the "export shape" of a prose story.** No code
module is imported; what the tests pin is file paths, regions and strings:

- Paths read: `.claude/commands/{advance-story,complete-story,security-audit,create-product,plan-product,plan-story}.md`, `.claude/agents/{lead-po,lead-designer,test-developer,feature-developer,mutation-tester}.md`, `.claude/skills/diff-review/SKILL.md`, `.claude/harness/rules.md`, `.claude/harness/models.conf`.
- Frontmatter: the first `model:` line between the first two `---` lines, its second whitespace field; `advance-story`, `complete-story`, `security-audit` must be exactly `opus`; `security-audit.md` must have a frontmatter line exactly `model: opus`.
- `models.conf`: a `model` row whose second field is `DIFF-REVIEW`, agent `lead-po`, model `fable`, a non-blank reason, placed between the GATES row and the REVIEW row (the plan's printed order follows the file's). `plan.sh` is not changed (C-2), and the probe below shows it renders the row as is. Its comment lines (beginning `#`) must contain `DIFF-REVIEW` and must not contain `The orchestrating commands and the planning agents` (today's header line 18 reads "...the contract). The orchestrating commands and the planning agents").
- Regions, exactly as C-3 (amended) defines them. Two that GREEN must not trip over: the **PLANNED → RED** region ends at the next line that begins `**`, contains ` → ` and then `.**` (so `**Pin the ...**` inside it is fine, `**RED → GREEN.**` ends it); the **REVIEW → DONE** region ends at the first paragraph after a blank line that begins `**` - put the AC-6 statement in a paragraph that does NOT open with bold, anywhere before `**Returning to RED from GREEN or GATES.**`. Step 1 is the GATES → REVIEW step numbered `1.` plus its whitespace-indented continuation lines; a blank line ends it.
- Output section of the skill: a line beginning `## ` and ending `Output` (today `## 4. Output`); the example is the block of lines indented by four spaces inside it; the route line, trimmed, must be exactly one of `- **Route:** GATES`, `- **Route:** RED`, `- **Route:** AMEND` and come after the example's `- **If we skip it:**` line. Today's example indents its parts by seven spaces; any indent of four or more counts.
- "What happens to a finding": a line beginning `## ` containing `What happens to a finding` (today `## 5. What happens to a finding`).
- Matching is a fixed-string search over the region flattened (lines trimmed, joined by one space), case-sensitive. `Route` matches `**Route:**` too.

Not constrained (GREEN's choice): the wording around every needle; where in
each region the needles sit; whether the route table of C-4 is a table or
prose; the reason text of the DIFF-REVIEW row; the rest of the `rules.md`
section beyond its needles, its must-nots and what `rules-trim` pins; the
order of sections in the skill; anything in `lead-po.md` beyond containing
`DIFF-REVIEW row` (C-8's other content is not checked by these suites).

**Contract amendments made in RED.** In place in `## Contract`, under C-3's
table, A-1 to A-7 plus the C-9 note, each with its reason: one bullet carrying
both PLANNED needles (A-1); `follows the label` in step 1 (A-2); backticked
route values and a whole-line example route after `**If we skip it:**` (A-3);
must-not `all four parts` (A-4); the AC-6 region pinned to REVIEW → DONE, with
`REVIEW row` matched after `DIFF-REVIEW row` is removed and the three
orchestrator duties present (A-5); must-not `PLANNED and REVIEW on` in
`rules.md` (A-6); a models.conf header row (A-7); and the security-audit model
row as an `M` (frontmatter) row rather than `F`, because `model: opus` already
floats in that command's body. No acceptance criterion changed. Also: C-3's
sentence "each needle sits on one line" is relaxed - the guards flatten.

**The callers grep.** Grepped `fable`, `GATES row` and `feature-developer`
across `.claude/tests/` at RED (after the Contract's list was handled). Beyond
the Contract's Callers list, nothing else pins the old values:
`plan.test.sh`'s remaining `fable` hits are MECHANISM_POLICY fixture rows and
comments; `dispatch.test.sh`'s `GATES row` / `feature-developer` hits are the
HARNESS-085/095 long-run needles and fixtures, which stay true; `story.test.sh:448`
writes a lead-po fixture with `model: fable`, which stays true;
`attest.test.sh` and `briefs.test.sh` name `feature-developer.md` as a file.
The Contract's list was right: `SHIP_EXPECTED`, the command-model assertion,
the security-audit needle, and the two step-1 fixtures (`S1` in dispatch,
`RV` in procedure) - all four updated. `procedure.test.sh`'s other step-1
fixtures (the `needed-earlier-step` case and the HARNESS-094 historical
`changed-all-absent` tree) are left: they do not quote today's dispatch words
and the second is a record of an earlier tree. One header comment in
`dispatch.test.sh` ("The orchestrator runs on `fable`") was made historical.

Other suites read the files GREEN rewrites and may pin other words in them:
attest, boundaries, gate-reminder, gates, lib, mutate, new-story,
phase-guard, phase, policy, refresh, reporting, rules-trim, settings,
shipped-docs, sigpipe, story. None of them was found to pin a word this story
changes, but that is a grep, not a run; GATES' `--changed` self-test is what
will say.

**Positive control (the probe tree), local.** On a scratch copy of this tree
outside the repository (`git archive HEAD` plus these four suites), with a
minimal compliant edit of each file GREEN owns - the three `model:` lines, the
DIFF-REVIEW row between GATES and REVIEW, one sentence per C-3 region - the
suites ran: `plan: 286 passed, 0 failed`, `security-audit: 52 passed, 0
failed`, `dispatch: 145 passed, 0 failed`, `procedure: 183 passed, 0 failed`,
`rules-trim: 50 passed, 0 failed`. So every new assertion can be satisfied by
prose in the shapes the Contract asks for, `plan.sh` needs no change, the
regions parse the real files as intended, and the existing HARNESS-085/095
assertions survive a compliant rewrite. That copy was discarded; it is not
GREEN's text.

**Negative controls and their expected values.** Unlike a code story these
suites loaded in RED and every assertion executed, controls included; the
values below were MEASURED in the RED run, not predicted.

| Control | Expected | Measured in RED |
|---|---|---|
| dispatch `today` fixture (today's wording in all six files) | exactly 31 lines, in C-3 order | 31, and identical line-for-line to what the real tree printed |
| dispatch `step1-today` (today's step 1, verbatim) | 5 "does not say" + 1 `GATES row` line | 6 |
| dispatch `rd-only-diff-review` (`DIFF-REVIEW row` only, in REVIEW → DONE) | 1 line, `REVIEW row` | 1 |
| dispatch `sk-today` | 6 lines | 6 |
| dispatch `ru-today` | 5 + 2 lines | 7 |
| dispatch `mc-today` (header still old; the DIFF-REVIEW row present) | 2 lines | 2 |
| procedure `output-today` | 6 lines | 6 |
| procedure `example-two-values` (`- **Route:** GATES or RED`) | the example line | 1 |
| procedure `example-route-first` | the order line | 1 |
| security-audit `HARNESS-101 AC-1 control` | exactly the M line | 1 |
| real tree, `row_problems` | 31 lines today, 0 after GREEN | 31 |
| real tree, `route_problems` | 12 lines today, 0 after GREEN | 12 |

GREEN's job is the last two rows' right-hand value: 0 against the shipped
files.

**Deferred verifications.** DV-1 (`advance-story.md` back on `model: fable`,
the `plan` command-set assertion must fail) and DV-2 (`DIFF-REVIEW row` put
back to `GATES row` in the real step 1, the `dispatch` real-tree assertion must
fail naming step 1) are owned by GATES. I cannot run them: both mutate the
implementation, which in RED does not exist, and DV-2's expression is written
against GREEN's wording. I decline both and claim neither. (The probe tree
above is not DV-2: it was my text, not the shipped one.)

**DV-3, assertions green on their first run.** One, and it is folded into a
real-tree whole-output compare, so it is listed out of caution rather than
because the DV-3 rule strictly requires it: the AC-6 "stays the
orchestrator's own" needles (`bash scripts/phase.sh clear`,
`bash scripts/plan.sh after`, `read the timings` in the REVIEW → DONE region).
They are present today, so in RED they add no line to the real-tree output.
After GREEN, this mutation must make the dispatch real-tree assertion print
exactly one line, `.claude/commands/advance-story.md: REVIEW → DONE does not say \`bash scripts/phase.sh clear\``:

    bash scripts/mutate.sh .claude/commands/advance-story.md 's/lock with `bash scripts\/phase.sh clear`/lock/' -- bash scripts/selftest.sh dispatch

(It reads advance-story.md at 9a10054, line 354: "lock with `bash scripts/phase.sh clear`, and relay the report that". If GREEN rewords that line, write the expression against the new line.) Every other assertion I wrote or rewrote was red on its first run against
the real tree, or is a fixture assertion seen both silent and firing. The
pre-existing "each agent declares the model of its kind of work" (`plan`, the
agent half of AC-1) is unchanged and green, as it was before this story; it is
not mine to earn, and a mutation of `lead-po.md`'s `model: fable` to `opus`
turns it red.

**For GREEN, discovered here.**

- `DIFF-REVIEW row` contains `REVIEW row`. The tests handle it; the prose
  should still say `REVIEW row` plainly in the AC-6 statement.
- The diff-review frontmatter `description` must lose `feature-developer`
  entirely; it today also says "a four-part explanation", which no assertion
  checks, but AC-5's fifth part makes it stale.
- The AC-6 paragraph must not begin with `**`; see the regions above.
- `security-audit.md`'s body keeps its two `` `model: opus` `` lines; only its
  frontmatter line changes (C-1).

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
- RED verified by the orchestrator (2026-11-11): `attest.sh check` answered `fresh` for both `bash scripts/selftest.sh plan dispatch procedure security-audit` (exit 1, `4 of 4 harness suite(s) FAILED.`, log `20261111T173709Z.139081`) and `bash scripts/gates.sh --fast` (exit 0, every gate unconfigured), so neither was re-run. Read from the log: every red assertion is a real-tree read finding the old text (31 `row_problems` lines, 12 `route_problems` lines, the six-command model set, the seven-row plan, the security-audit frontmatter line); no load error; every fixture green. RED resolved to **claude-opus-5-5** (test-developer, planned `opus`).
- GREEN verified by the orchestrator (2026-11-11): the four RED suites are byte-identical to `ec3df9e`; `attest.sh check` answered `fresh` for `bash scripts/selftest.sh plan dispatch procedure security-audit rules-trim` (exit 0, `5 harness suite(s) passed.`, log `20261111T180018Z.213909`) and `bash scripts/gates.sh --fast` (exit 0, every gate unconfigured), so neither was re-run. The six commands' `model:` lines and the seven `models.conf` rows read as AC-1/AC-2 say. GREEN resolved to **claude-opus-5-5** (feature-developer, planned `opus`). Its own notes: `rules.md` is now exactly at `rules-trim`'s 370-line cap; floors raised to dispatch 145, plan 286, procedure 183, security-audit 52; `VERSION` 120 (2026-11-11). `selftest-needed --suites` selects 24 of 34 suites, `selftest` among them, for GATES → REVIEW.
