---
id: HARNESS-085
title: The full gate run and the self-test run in an opus dispatch that returns a verdict
slug: the-full-gate-run-the-self-test-and-chec
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-085-the-full-gate-run-the-self-test-and-chec
depends_on: [HARNESS-084]      # the dispatch's verdict is checked with attest.sh, which 084 builds
touches: [.claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/lead-po.md, .claude/agents/feature-developer.md, .claude/tests/dispatch.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Second of four (HARNESS-084..087). Today the orchestrator, on `fable`, runs
the two longest commands of a story itself and waits: the full `bash
scripts/gates.sh` at GREEN → GATES, and `SELFTEST_JOBS=4 bash
scripts/selftest.sh` at GATES → REVIEW step 2 (336 s at best on this host,
1-5 hours beside other runs, HARNESS-036/050..068). A run spends no tokens
while it executes, but the turn that follows it re-sends the orchestrator's
whole context, and a multi-hour wait outlasts the prompt cache, so the next
turn re-reads everything uncached. The user's decision: these two run in a
**feature-developer** dispatch on the GATES
row of `.claude/harness/models.conf` (`opus`, a fresh and small context),
which returns a verdict - exit status, last line, duration, log path - and the
orchestrator checks that verdict with `bash scripts/attest.sh check`
(HARNESS-084) rather than running the command.

`bash scripts/check-boundaries.sh` at step 5 stays the orchestrator's own run.
It takes seconds, so a dispatch would cost more tokens than the wait it
saves; the user decided to keep it inline (see `## Notes`), and AC-3 pins
that it is not dispatched.

The precedent is the diff review (HARNESS-068): a fresh feature-developer
dispatched on the GATES row that changes no file and returns a report. This
story gives that shape a name in feature-developer.md, so a dispatch "only to
run" has written rules rather than an implied remit - an agent given no work
will find some, and the harness says so.

What does not change: `## Gate results` is written by `gates.sh` and by
nobody else, whoever invokes it; the self-test runs detached and alone in
the worktree, and the orchestrator runs nothing in that tree while the
dispatch is out; the step order procedure.test.sh pins (diff review, then
self-test, then `phase.sh set REVIEW`, then commit, then check-boundaries)
holds, with each step's needle still in its step. A gate failure takes its
existing route: the same feature-developer, already dispatched in GATES,
fixes it under GATES' rules.

The gate that fails if this breaks is `bash scripts/selftest.sh dispatch` (a
new suite, modelled on `procedure.test.sh`), and `bash scripts/selftest.sh
procedure` must stay green unchanged.

## Acceptance criteria

- **AC-1** — Given advance-story.md, when the `**GREEN → GATES.**` region is
  read, then the sentence that runs the full gates names a `feature-developer`
  dispatch on the `GATES row`, says the subagent runs `bash scripts/attest.sh
  -- bash scripts/gates.sh` and returns `exit status`, `last line`,
  `duration` and `log`, and says the orchestrator checks it with `bash
  scripts/attest.sh check -- bash scripts/gates.sh`. *Control:* a fixture whose
  region says `Then run `bash scripts/gates.sh`.` with no dispatch is
  reported with exactly one line.
- **AC-2** — Given advance-story.md's GATES → REVIEW numbered steps, when the
  step holding `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` is read, then
  it names `feature-developer`, the words `detached`, `alone` and `verdict`,
  and `bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh`;
  it still carries every word `procedure.test.sh` pins (`detached`,
  `Windows`, `## Notes`, `other test runs`, `skip`) and still comes after
  the diff-review step and before `bash scripts/phase.sh set $1 REVIEW`.
  *Control:* the step as it reads today (the orchestrator runs it) is
  reported with exactly one line.
- **AC-3** — Given the same steps, when the step holding
  `` `bash scripts/check-boundaries.sh` `` is read, then it does not name
  `feature-developer`, so the orchestrator still runs it itself, and it still
  comes after the commit step. *Control:* a fixture whose step dispatches it
  to a `feature-developer` is reported with exactly one line.
- **AC-4** — Given complete-story.md and lead-po.md, when they are read, then
  complete-story.md's GATES → REVIEW bullet names the `feature-developer`
  dispatch and `verdict`, and lead-po.md's `## Orchestrating` section names
  `SELFTEST_JOBS=4 bash scripts/selftest.sh` and `feature-developer` in the
  same paragraph, with the sentence `every rung is something you run` gone
  and `bash scripts/attest.sh check` present (HARNESS-084 put it there).
- **AC-5** — Given feature-developer.md, when it is read, then it carries a
  section headed exactly `## Run and report` that names `bash scripts/attest.sh
  --`, the four verdict fields, the words `change nothing` and `alone`, and
  says a required gate that fails in GATES is fixed under this file's GATES
  rules. *Control:* a fixture without the heading, and one with the heading
  and no `change nothing`, are each reported with exactly one line.

Every criterion can only be checked structurally: the sites are prose,
nothing executes them, and the suite pins that the instruction is present
where the orchestrator and the subagent read it - not that either follows it.
The story says so here rather than pretending otherwise.

## Contract

**Writes:** `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/agents/lead-po.md`, `.claude/agents/feature-developer.md`, `.claude/tests/dispatch.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says.

**C-1. The dispatch brief, as advance-story.md will state it.** One shape,
used twice. Dispatch a **feature-developer** on the GATES row of
`models.conf`, with: the worktree's absolute path and "run every command
from there"; exactly one command to run, through `bash scripts/attest.sh --
<command>`; "change nothing unless the command is `bash scripts/gates.sh`
and a required gate fails, in which case fix it under your GATES rules and
run the command again"; "run nothing else in this worktree while it runs";
for the self-test, "run it detached (`run_in_background` with the longest
timeout, or `nohup`), and wait for it; `SELFTEST_JOBS=4`". It returns the
verdict: `exit:`, `last:`, `duration:`, `log:` - the four fields of the attest
record (HARNESS-084 C-3) - and the model it resolved to. The orchestrator
then runs `bash scripts/attest.sh check -- <command>`, requires `fresh`,
reads `exit:` and `last:` from the record, and records the resolved model in
`## Model guidance`. A `stale` or `none` answer means the subagent did not run
what it says it ran on the tree that is there: send it back, and say so in
`## Notes`.

**C-2. The two sites in advance-story.md, and the one that stays.**

- `**GREEN → GATES.**` region: `Then run `bash scripts/gates.sh`.` becomes
  the C-1 dispatch for `bash scripts/gates.sh`. The paragraphs that follow
  (`## Gate results` written by the script; on failure dispatch the
  feature-developer, or return to RED; the stamp covers tracked and staged
  files; `BLOCKED`) keep their text; the first of them now describes what the
  dispatched run did.
- GATES → REVIEW step 2: `selftest-needed.sh` is still the orchestrator's
  (seconds, and its `skip` line goes into `## Notes` as today). On `run`, the
  C-1 dispatch for `SELFTEST_JOBS=4 bash scripts/selftest.sh`; the
  orchestrator pastes the record's `exit:`, `last:` (`N harness suite(s)
  passed.`) and `duration:` into `## Notes`, as the step asks today for the
  exit status, last line and duration. The timing history in the step
  (336 s, 1,135 s, 2,894-17,015 s) stays as the subagent's expectation.
- Step 5 is unchanged: the orchestrator runs `bash
  scripts/check-boundaries.sh` itself after the commit and fixes what it
  reports before pushing. No dispatch: it takes seconds.

Needles, so GREEN and RED agree on the strings (settled, read out):
`feature-developer`, `GATES row`, `bash scripts/attest.sh -- bash
scripts/gates.sh`, `bash scripts/attest.sh check -- bash scripts/gates.sh`,
`bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh`,
`exit status`, `last line`, `duration`, `log`, `detached`, `alone`, `verdict`.
`procedure.test.sh`'s needles (`STEP_SELFTEST`, `STEP_PHASE`,
`STEP_BOUNDARIES`, `STEP_NEEDED`, `STEP_REVIEW`, `STEP_WORDS`) are untouched
and in the same steps and order; its `allowed-tools` entries stay, because the
orchestrator may still run any of them when a check answers `stale`.

**C-3. complete-story.md and lead-po.md.** complete-story's `GATES → REVIEW
opens with a review` bullet gains: the full gates and the self-test each run
in a `feature-developer` dispatch that returns a
`verdict` the orchestrator checks with `bash scripts/attest.sh check`.
lead-po.md `## Orchestrating`: the sentence `Verification is a ladder, and
every rung is something you run, not something you are told` becomes one
that says every rung is something you run **or have run under
`scripts/attest.sh` and check**, and a new paragraph says the long runs -
`bash scripts/gates.sh` and `SELFTEST_JOBS=4 bash scripts/selftest.sh` - go
to a `feature-developer` on the GATES row, with the C-1 brief, while
`bash scripts/check-boundaries.sh` stays the orchestrator's own run. `reporting.test.sh` reads `## Orchestrating` for its
reference to the reporting rule, which stays; `phase.test.sh` needs `bash
scripts/plan.sh after` in the file, which stays.

**C-4. feature-developer.md `## Run and report`.** A new section after
`## Method`: when the brief names one command and nothing to build, run it
through `bash scripts/attest.sh -- <command>` from the worktree named, `alone`
(nothing else in that tree while it runs; the self-test detached), `change
nothing` - except a required gate that fails under `bash scripts/gates.sh`,
which is fixed under this file's GATES rules and then re-run - and return the
`exit:`, `last:`, `duration:` and `log:` fields of the record plus the model
you resolved to; never the whole output. `briefs.test.sh` pins `## Method`
step 2 and `## Reuse before you write`, neither of which moves.

**C-5. The suite.** `.claude/tests/dispatch.test.sh`, `dispatch_problems
<root>` in `procedure_problems`' shape: pure bash region extraction, one
line per violation, silent over `REPO_ROOT`, and fixtures compliant by
construction with one thing regressed, each printing exactly one line. The
step parser is `procedure.test.sh`'s (`first_step`, steps as numbered lines
under the GATES → REVIEW ordering); copy the helpers rather than source that
suite, and say so in a comment, since the two suites run under separate
floors. Floors: `floor | dispatch | N` in `floors.conf` and the same N in
`selftest.test.sh`'s table.

| Site | Must hold | Reported as |
|---|---|---|
| advance-story `**GREEN → GATES.**` region | contains `feature-developer`, `GATES row`, `bash scripts/attest.sh check -- bash scripts/gates.sh` | `GREEN → GATES does not dispatch the full gate run` |
| advance-story step holding STEP_SELFTEST | contains `feature-developer`, `detached`, `alone`, `verdict`, `bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh` | `the self-test step does not dispatch the run` |
| advance-story step holding STEP_BOUNDARIES | does not contain `feature-developer` | `the check-boundaries step dispatches a run that takes seconds` |
| complete-story GATES → REVIEW bullet | contains `feature-developer` and `verdict` | `its GATES → REVIEW bullet does not name the dispatch` |
| lead-po `## Orchestrating` | a paragraph contains both `SELFTEST_JOBS=4 bash scripts/selftest.sh` and `feature-developer`; `every rung is something you run, not` absent | `does not dispatch long runs` / `still runs every rung itself` |
| feature-developer.md | a line exactly `## Run and report`; the section contains `bash scripts/attest.sh --`, `exit:`, `last:`, `duration:`, `log:`, `change nothing`, `alone` | `has no ## Run and report section` / `## Run and report does not say <needle>` |

**C-6. Oracle partition.** Every criterion is **mechanical**; the needles
above are settled, read out, and RED amends this block if it needs a
different string rather than inventing one in the test.

**C-7. No signature changes.** No script changes. `attest.sh`'s surface is
HARNESS-084's C-1, cited not copied.

## Deferred verifications

**DV-1 (defect put back, and the rule probed against the tree it judges -
one experiment serves both). Owner: GATES.** With a real line of
`.claude/commands/advance-story.md` mutated so the self-test step no longer
names `feature-developer`, `dispatch_problems "$REPO_ROOT"` **must** print
exactly `the self-test step does not dispatch the run` and nothing else, and
`bash scripts/selftest.sh procedure` must stay green under the same mutation
(the pinned needles are untouched, which is what makes the two suites
independent). RED cannot run this: the step it mutates does not exist yet.
Paste the line, the procedure result and the restore.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-085` from `.claude/harness/models.conf`.
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
## Out of scope

- The attest record itself, its hash and `check`: HARNESS-084.
- A new agent definition. The dispatch reuses `feature-developer` on the
  GATES row, as the diff review does; a tool-less "runner" agent would need a
  `rules.md` ownership row, which HARNESS-087 is reshaping.
- `ci-local.sh`: unchanged. It is the user's single-machine CI rehearsal and
  mirrors the workflow files by construction.
- Dispatching `selftest-needed.sh`, the diff review (already a dispatch),
  `phase.sh` or `check-boundaries.sh`: the orchestrator's, as today.
  `check-boundaries.sh` takes seconds, so a dispatch would cost more than it
  saves.
- Shortening the self-test or changing `SELFTEST_JOBS`.
- Whether the runtime lets a subagent outlast a multi-hour background
  command. The step already says to run it detached; if a dispatch comes back
  before the run ends, the record is `none`, the orchestrator says so in
  `## Notes`, and that is a finding for the user, not something this story
  resolves by prose.

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. -->

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return, with the PASTED probe output. -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run. Do not paste or
     edit it. -->

## Notes

- 2026-10-31, while PLANNED: the first cut also dispatched
  `check-boundaries.sh`. The PO flagged that a seconds-long check costs more
  tokens to dispatch than it saves, and the user decided to keep it as the
  orchestrator's own run. AC-3 was rewritten to pin that, and C-1, C-2, C-3,
  C-5, the title and `## Out of scope` were changed to match. The branch name
  keeps the original slug.

