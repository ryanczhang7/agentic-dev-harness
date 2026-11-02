---
id: HARNESS-085
title: The full gate run and the self-test run in an opus dispatch that returns a verdict
slug: the-full-gate-run-the-self-test-and-chec
epic: 
type: feature
status: in-progress
phase: GATES
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

**C-5 amended in RED (test-developer, opus, 2026-11-01).** GREEN builds what
this block says; the table above is the first cut. Each change has its reason.

1. **Line format.** Every line is `<relative-path>: <reason>`, as in
   `procedure_problems`, and at most one line per site (per needle only in
   `## Run and report`). The exact lines, in print order:
   - `.claude/commands/advance-story.md: GREEN → GATES does not dispatch the full gate run`
   - `.claude/commands/advance-story.md: the self-test step does not dispatch the run`
   - `.claude/commands/advance-story.md: the check-boundaries step dispatches a run that takes seconds`
   - `.claude/commands/advance-story.md: the check-boundaries step does not come after the commit step` (new, item 4)
   - `.claude/commands/complete-story.md: its GATES → REVIEW bullet does not name the dispatch`
   - `.claude/agents/lead-po.md: does not dispatch long runs`
   - `.claude/agents/lead-po.md: still runs every rung itself`
   - ``.claude/agents/lead-po.md: does not name `bash scripts/attest.sh check` `` (new, item 5; the line ends at the closing backtick)
   - `.claude/agents/feature-developer.md: has no ## Run and report section`
   - ``.claude/agents/feature-developer.md: ## Run and report does not say `<needle>` `` (needle in backticks, line ends at the closing one)
   - `<path>: file is missing` for any of the four files.
   So DV-1's expected output is the whole line
   `.claude/commands/advance-story.md: the self-test step does not dispatch the run`.
2. **Row 1 carries every needle AC-1 names**, not three: `feature-developer`,
   `GATES row`, `` bash scripts/attest.sh -- bash scripts/gates.sh` ``,
   `` bash scripts/attest.sh check -- bash scripts/gates.sh` ``, `exit status`,
   `last line`, `duration`, `log`. Reason: AC-1 requires the sentence to say
   the subagent runs the attest command and returns the four fields; the first
   cut left that half of AC-1 with no test.
3. **The three command needles end with their code span's closing backtick**
   (`` ...gates.sh` `` twice, `` ...SELFTEST_JOBS=4 bash scripts/selftest.sh` ``),
   as `procedure.test.sh`'s `STEP_SELFTEST` does. Reason: without it
   `attest.sh check -- bash scripts/gates.sh --fast` and a targeted
   `... selftest.sh dispatch` satisfy them, and `check` is keyed by the exact
   words (`## Notes`, PO decision 4), so those are different records. GREEN
   must write each command as a whole code span, e.g.
   `` `bash scripts/attest.sh check -- bash scripts/gates.sh` ``.
4. **New row, AC-3's second half:** the step holding `STEP_BOUNDARIES` has a
   higher number than the first step whose first line matches
   `^[0-9]+\. Commit`. Reason: AC-3 says "still comes after the commit step",
   and `procedure.test.sh` pins check-boundaries after the phase step, not
   after the commit. Judged only when a check-boundaries step exists (its
   absence is procedure's to report).
5. **New clause, AC-4's last half:** a paragraph of lead-po's
   `## Orchestrating` contains `bash scripts/attest.sh check`. Reason: AC-4
   names it; it is present today (HARNESS-084), so this pins that GREEN's
   rewrite of the rung sentence does not drop it.
6. **Row 6 adds `GATES rules`.** Reason: AC-5 requires the section to say a
   failing required gate is fixed under this file's GATES rules, and C-4 words
   it "fixed under this file's GATES rules".
7. **Regions.** The `**GREEN → GATES.**` region runs to the next *paragraph*
   beginning `**` (a line beginning `**` whose previous line is blank), not
   the next line beginning `**`: the real region has `**value** mutation`
   mid-paragraph at advance-story.md:154, and the line rule would end it
   before `Then run`. Today the region is lines 145-165, ending before
   `**The stamp covers ...`. The GATES → REVIEW steps and the complete-story
   bullet are `procedure.test.sh`'s parser, copied. lead-po's section runs from
   the line exactly `## Orchestrating` to the next `## ` line; a paragraph is a
   run of non-blank lines. feature-developer's section is the same rule for
   `## Run and report`. Every needle is matched against the region's lines
   trimmed and joined by one space, so a reflow across a line break neither
   hides a needle nor hides the old rung sentence.
8. **Case.** Needles are case-sensitive: `verdict` is lowercase, and
   complete-story's `Verdict: Ship.` does not satisfy it. That is why the
   bullet fires today although it already names `feature-developer` (for the
   diff review).

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

Result (GATES, 2026-11-02, orchestrator): as required. Both occurrences of
`feature-developer` in step 2 (lines 253 and 274) replaced; the real-tree
assertion printed exactly the one self-test line, every fixture still passed,
and `procedure` stayed green under the same mutation.

```
  253 -    asserts. Dispatch it to a `feature-developer` on the GATES row, with the
  253 +    asserts. Dispatch it to a `runner` on the GATES row, with the
  274 -    feature-developer, or RED if a test is wrong. A fix changes the tree, so
  274 +    runner, or RED if a test is wrong. A fix changes the tree, so
         actual:   .claude/commands/advance-story.md: the self-test step does not dispatch the run
dispatch: 66 passed, 1 failed
procedure: 118 passed, 0 failed
=== mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261102T150836Z.1326.bak) ===
  253:    asserts. Dispatch it to a `feature-developer` on the GATES row, with the
  274:    feature-developer, or RED if a test is wrong. A fix changes the tree, so
```

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

One new suite, `.claude/tests/dispatch.test.sh` (`bash scripts/selftest.sh
dispatch`), at the only level the criteria allow: structural reads of four
prose files (story, "Every criterion can only be checked structurally"). It
is `procedure.test.sh`'s shape: `dispatch_problems <root>` prints one line per
violation (C-5 as amended in RED) and is asserted silent over `REPO_ROOT`, and
fixtures built compliant by construction each regress one thing and must
print exactly the one line. All comparisons are whole-output `assert_eq`, so a
fixture printing the right line AND a wrong one fails.

| Group | Cases | AC |
|---|---|---|
| real tree | the four files exist; `dispatch_problems "$REPO_ROOT"` is empty | AC-1..AC-5 |
| compliant fixture | silent; silent with three needles reflowed across a line break; silent as CRLF | all (makes every negative mean something) |
| GREEN → GATES | today's region (control) = 1 line; each of 8 needles removed = 1 line each; check only outside the region; a `**`-PARAGRAPH ends the region; no region (ascii arrow); `check` of `gates.sh --fast`; dispatch of `gates.sh --fast` | AC-1 |
| self-test step | today's step (control) = 1 line; each of 5 needles removed; check without `SELFTEST_JOBS=4`; check of a targeted `selftest.sh dispatch`; words in a different step; no self-test step | AC-2 |
| check-boundaries step | dispatched (control) = 1 line; dispatch on a continuation line; feature-developer in the NEXT step = silent; moved before the commit; no `Commit` step; no boundaries step = silent (procedure's) | AC-3 |
| complete-story bullet | today's bullet (control: `Verdict` capital, feature-developer for the review); each of 2 needles removed; `verdict` in the next bullet; no bullet | AC-4 |
| lead-po `## Orchestrating` | today (two lines, order); old rung sentence; old rung sentence wrapped after `run,`; long-run paragraph without `feature-developer`; without the self-test; needles in different paragraphs; only in a later section; no `attest.sh check`; no section heading | AC-4 |
| feature-developer `## Run and report` | no heading (control); heading without `change nothing` (control); each of 8 needles removed; `## Run and report (dispatch)`; needle only in the next section; section with no needles = 8 lines in order | AC-5 |
| files / order | each of four files missing = `file is missing` only; a tree with none of the story's edits = the six lines, in order | all |

Not in this suite, by design: AC-2's "still carries procedure's STEP_WORDS and
keeps its order" and the self-test/phase/boundaries order are
`procedure.test.sh`'s assertions, and the story makes `bash scripts/selftest.sh
procedure` staying green part of the gate.

## Handoff: RED -> GREEN

Written by test-developer, model `opus` (claude-opus-5-5) as declared, no
override. Every timing below is from a local run on this Windows host, with
two other `gates.sh` runs on the host (selftest.sh warned of them); none is
from CI.

### Command

    bash scripts/selftest.sh dispatch      # the new suite; red until GREEN
    bash scripts/selftest.sh procedure     # must stay green, unchanged
    bash scripts/selftest.sh selftest      # the floors table agrees

`selftest.sh` takes ONE suite name per call. Run them through
`bash scripts/attest.sh -- ...` as below. A quick local loop without the floor
audit: `VERBOSE=1 bash .claude/tests/dispatch.test.sh` (about 40 s here).

### Attest records (RED)

    command:  bash scripts/selftest.sh dispatch
    status:   ok
    exit:     1
    duration: 21s
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261101T231856Z.12185.log

    command:  bash scripts/selftest.sh procedure
    status:   ok
    exit:     0
    duration: 19s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261101T231921Z.12717.log

    command:  bash scripts/selftest.sh selftest
    status:   ok
    exit:     0
    duration: 348s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261101T231949Z.13387.log

    command:  bash scripts/gates.sh --fast
    status:   ok
    exit:     0
    duration: 9s
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261101T232547Z.19034.log

`--fast` is green because this repo configures no project gates (PO decision
2); the harness suites are the only verification, and `dispatch` is red as it
should be. `check-sigpipe.sh` (59 files, 0 findings) and `check-grep-count.sh`
(59 files, 0 findings) are clean with the new suite in the tree.

### Verbatim failure (from the dispatch log)

```
=== dispatch ===

  the real tree (AC-1 to AC-5)
    FAIL dispatch_problems over the real tree prints nothing: GREEN → GATES and the self-test step dispatch a feature-developer and check its verdict with attest.sh check, check-boundaries stays the orchestrator's and comes after the commit, complete-story's bullet names the dispatch and its verdict, lead-po's ## Orchestrating dispatches the long runs and no longer says every rung is run by you, and feature-developer.md has ## Run and report
         expected: 
         actual:   .claude/commands/advance-story.md: GREEN → GATES does not dispatch the full gate run
         .claude/commands/advance-story.md: the self-test step does not dispatch the run
         .claude/commands/complete-story.md: its GATES → REVIEW bullet does not name the dispatch
         .claude/agents/lead-po.md: does not dispatch long runs
         .claude/agents/lead-po.md: still runs every rung itself
         .claude/agents/feature-developer.md: has no ## Run and report section
...
dispatch: 66 passed, 1 failed
FAIL dispatch  did 66 units of work, below the floor of 67 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

This is the right failure: one real-tree assertion, naming exactly the six
sites the story has not written, and nothing about the two sites that are
already right today (check-boundaries undispatched and after the commit;
`bash scripts/attest.sh check` in lead-po). The floor line is expected:
`selftest.sh` reads the PASSED count, so the suite sits below its floor
(66 < 67) until GREEN lands.

### What each test asserts

67 executed assertions, every one unconditional (fixed loops only). One line
per test or loop:

- the four files exist in REPO_ROOT - all ACs (green on arrival; a file-exists precondition).
- `dispatch_problems "$REPO_ROOT"` is empty - AC-1..AC-5. **The one red assertion.**
- compliant fixture silent; silent with needles reflowed across a line break; silent as CRLF - all ACs (the base every negative regresses from).
- GREEN → GATES: today's region (control) gives exactly `L_GG` - AC-1.
- GREEN → GATES: each of the 8 needles removed gives exactly `L_GG` (8 assertions) - AC-1.
- GREEN → GATES: check only after REVIEW → DONE; a paragraph beginning `**` ends the region; no region (ascii arrow); `check` of `gates.sh --fast`; dispatch of `gates.sh --fast` - each exactly `L_GG` - AC-1.
- self-test step: today's step (control) gives exactly `L_SELFTEST` - AC-2.
- self-test step: each of the 5 needles removed (5) - AC-2.
- self-test step: check without `SELFTEST_JOBS=4`; check of `selftest.sh dispatch`; words in a different step; no self-test step - each exactly `L_SELFTEST` - AC-2.
- check-boundaries: dispatched (control) and dispatched on a continuation line give exactly `L_BOUND`; feature-developer in the next step is silent - AC-3.
- check-boundaries: moved before the commit, and no `Commit` step, give exactly `L_COMMIT`; no boundaries step is silent - AC-3.
- complete-story: today's bullet (control); each of 2 needles removed (2); `verdict` only in the next bullet; no bullet - each exactly `L_BULLET` - AC-4.
- lead-po: today gives `L_LONG` then `L_RUNG`; old rung sentence, and wrapped after `run,`, give `L_RUNG`; long-run paragraph without `feature-developer`, without the self-test, split over two paragraphs, only in a later section give `L_LONG`; no `attest.sh check` gives `L_CHECK`; no `## Orchestrating` gives `L_LONG` then `L_CHECK` - AC-4.
- feature-developer: no heading (control) and `## Run and report (dispatch)` give `L_NOHEAD`; heading without `change nothing` (control) gives that one line; each of 8 needles removed (8); needle only in the next section; empty-of-needles section gives the 8 lines in order - AC-5.
- each of four files missing gives only `<path>: file is missing` (4); a tree with none of the story's edits gives the six lines in order - all ACs.

### Files touched

- `.claude/tests/dispatch.test.sh` (new; `git add`-ed, not committed)
- `.claude/tests/floors.conf` (`floor | dispatch | 67`, after `classify`, and a HARNESS-085 note at the foot)
- `.claude/tests/selftest.test.sh` (`dispatch 67` in the COUNTS table, after `classify`)
- this story: `## Contract` C-5 amendment, `## Test plan`, this handoff.

### What GREEN must write, file by file (the pinned shape)

There is no module to import: the suite reads four files. The exact lines are
C-5 item 1. Needles are case-sensitive fixed strings, matched against the
region's lines trimmed and joined by one space (so a line break inside a
needle is fine; anything else between its words is not).

1. **`.claude/commands/advance-story.md`, `**GREEN → GATES.**` region** (today
   lines 145-165: from the line beginning `**GREEN → GATES.**` to the blank
   line before `**The stamp covers ...`). Replace `Then run `bash
   scripts/gates.sh`.` (line 159) with the C-1 dispatch. Inside the region it
   must contain all of: `feature-developer`, `GATES row`,
   `` `bash scripts/attest.sh -- bash scripts/gates.sh` ``,
   `` `bash scripts/attest.sh check -- bash scripts/gates.sh` `` (each as a
   whole code span: the closing backtick is part of the needle),
   `exit status`, `last line`, `duration`, `log`. Do not start a new
   paragraph with `**` above the dispatch (a paragraph beginning `**` ends the
   region; a `**` mid-paragraph, like line 154's `**value**`, does not).
2. **advance-story.md, GATES → REVIEW step 2** (today lines 222-252, the step
   holding `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``). Add, within the
   step: `feature-developer`, `detached`, `alone`, `verdict`, and
   `` `bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh` ``.
   `detached` and `alone` ("passed alone") are already there, but write
   `alone` in the dispatch brief rather than relying on the history sentence.
   Keep procedure.test.sh intact: the plain `` `SELFTEST_JOBS=4 bash
   scripts/selftest.sh` `` span stays, `` `bash scripts/selftest-needed.sh` ``
   stays before it, the words `detached`, `Windows`, `## Notes`,
   `other test runs`, `skip` stay, every continuation line stays indented and
   **no blank line inside the step** (a blank line ends a step in both
   parsers).
3. **advance-story.md, steps 4 and 5.** Step 4 must still begin
   `4. Commit`; step 5 (`` `bash scripts/check-boundaries.sh` ``) must not
   contain `feature-developer` on any of its lines.
4. **`.claude/commands/complete-story.md`, the `- **GATES → REVIEW opens with
   a review` bullet** (line 35 to the blank line after it). Add lowercase
   `verdict` (and the dispatch, C-3); `feature-developer` is already there but
   for the diff review. No blank line and no line beginning `- ` inside it.
   procedure.test.sh still needs `` `diff-review` `` before
   `` `bash scripts/selftest-needed.sh` `` before
   `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` in this bullet.
5. **`.claude/agents/lead-po.md`, `## Orchestrating`** (line 88 to
   `## More than one worktree`). Rewrite line 127 so no paragraph of the
   section contains `every rung is something you run, not` (reflow does not
   hide it). Add one paragraph (no blank line inside) containing both
   `SELFTEST_JOBS=4 bash scripts/selftest.sh` and `feature-developer`. Keep
   `bash scripts/attest.sh check` in the section (it is there today), the
   reporting-rule reference (`reporting.test.sh`) and `bash scripts/plan.sh
   after` (`phase.test.sh`).
6. **`.claude/agents/feature-developer.md`, new `## Run and report`** after
   `## Method`, before `## Reuse before you write` (line 90). The heading line
   must be exactly `## Run and report`; the section runs to the next line
   beginning `## `. It must contain: `bash scripts/attest.sh --`, `exit:`,
   `last:`, `duration:`, `log:`, `change nothing`, `alone`, `GATES rules`.
   `briefs.test.sh` pins `## Method` step 2 and `## Reuse before you write`;
   neither moves.

Not constrained, and GREEN's choice: the wording around every needle, where
in a region a needle sits, whether the C-1 brief is written once and referred
to, the `.claude/harness/VERSION` bump, and `allowed-tools` (C-2 says they
stay).

### Passed on arrival

All 66 fixture assertions passed on their first run. They are not regression
guards over production: they test the guard itself, against fixtures this
suite writes, and in this RED nothing failed at import, so every one of them
**executed**. They were earned by three probes of the guard, run on a scratch
copy (`.claude/tests/dispatch.test.sh` itself untouched):

| Probe on a scratch copy of the suite | Result |
|---|---|
| A. region ends at ANY line beginning `**` (procedure's rule) | `dispatch: 17 passed, 50 failed` - the compliant fixture goes red (`the compliant fixture is silent`), and with it every fixture that expects a non-GG line |
| B. command needles without the closing backtick | `dispatch: 63 passed, 4 failed` - exactly the real tree, `gates.sh --fast` check, `gates.sh --fast` dispatch, `selftest.sh dispatch` check |
| C. `flat` joins with newlines instead of spaces | `dispatch: 65 passed, 2 failed` - exactly the real tree and `a needle reflowed across a line break still counts` |

The file-exists precondition and the "no boundaries step is silent" case are
green by design. The real-tree assertion is the only one about production,
and it is red.

### Negative controls, with the values measured in RED

No control here has a threshold: each is a fixture whose whole output must
EQUAL the expected lines. Unlike an import-failing RED, these ran - the values
below are measured by the suite itself on this tree, against the guard as
written. What remains unverified is only that the real files, once written,
are silent.

| Control (AC) | Expected output | Measured in RED |
|---|---|---|
| GREEN → GATES as it reads today (AC-1) | 1 line, `L_GG` | 1 line, `L_GG` (ok) |
| self-test step as it reads today (AC-2) | 1 line, `L_SELFTEST` | 1 line (ok) |
| check-boundaries dispatched (AC-3) | 1 line, `L_BOUND` | 1 line (ok) |
| complete-story bullet as it reads today (AC-4) | 1 line, `L_BULLET` | 1 line (ok) |
| feature-developer without the heading (AC-5) | 1 line, `L_NOHEAD` | 1 line (ok) |
| feature-developer, heading but no `change nothing` (AC-5) | 1 line | 1 line (ok) |
| the real tree today | 6 lines (GG, self-test, bullet, long, rung, no-heading) | the same 6, verbatim above |

### For GATES: DV-1, declined in RED

I did **not** run DV-1, and could not: it mutates the self-test step's
dispatch, which does not exist until GREEN writes it. GATES owns it. Two
notes for whoever runs it: the expected output is the whole line
`.claude/commands/advance-story.md: the self-test step does not dispatch the run`
(C-5 item 1); and today step 2 names `feature-developer` twice (the dispatch
GREEN adds, plus "A failure takes GATES' own routes: the feature-developer"),
so a `mutate.sh` expression that removes only one occurrence leaves the
needle satisfied and the guard rightly silent. Mutate every occurrence in the
step (a `g` flag on a line-range address), or the probe proves nothing.

### Discovered, for the implementation approach

- `log`, `duration` and `alone` are weak needles (substring of `logged`,
  `durations`, `alone` in history prose). They are the settled C-2 strings;
  the fixtures show each is required, not that it is used in the sense meant.
- The complete-story bullet fires today only on `verdict`: `feature-developer`
  is already there for the diff review. That half of AC-4 is satisfied by
  existing text, as the story's AC allows.

### GREEN

Written by feature-developer, model `opus` (claude-opus-5-5) as declared, no
override. No test file touched.

- `advance-story.md` GREEN → GATES: `Then run `bash scripts/gates.sh`.` is now
  the C-1 dispatch (feature-developer, GATES row, attest run, the four verdict
  fields, `attest.sh check`, `stale`/`none` sends it back), plus one paragraph
  stating the brief once for both dispatches. The paragraphs after it keep
  their text; the first now says `gates.sh` writes `## Gate results` "whoever
  runs it" and that a failure the dispatch could not fix goes back to the
  feature-developer.
- `advance-story.md` step 2: on `run`, the self-test goes to a
  feature-developer, run detached and alone through `attest.sh --`, checked
  with `bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh`;
  the timing history stays as the expectation given to it; Notes take the
  record's `exit:`, `last:`, `duration:`. Steps 3-5 untouched.
- `complete-story.md` bullet: one sentence (dispatch, `verdict`, `attest.sh
  check`, check-boundaries stays yours).
- `lead-po.md` `## Orchestrating`: new long-runs paragraph before the ladder;
  rung sentence now "something you run, or have run under `scripts/attest.sh`
  and check - never something you are told".
- `feature-developer.md`: `## Run and report` between `## Method` and
  `## Reuse before you write`.
- `VERSION`: `104 (2026-11-01)`.

Checked: `attest.sh` exports leading `NAME=v` assignments to the command
(scripts/attest.sh:149-182), so `attest.sh -- SELFTEST_JOBS=4 bash
scripts/selftest.sh` runs as the brief says.

Controls: every control in the handoff is a whole-output `assert_eq` in the
suite, and all 67 assertions pass against the finished files, so each measured
value equals RED's (one line each; the real tree now silent). No divergence.

Run records (`attest.sh --`, ATTEST_TAIL unset or 0):

    dispatch   status ok  exit 0  41s   last: 1 harness suite(s) passed.  (67 passed, 0 failed)  log .claude/state/attest-logs/20261101T233825Z.33666.log
    procedure  status ok  exit 0  49s   last: 1 harness suite(s) passed.  log .claude/state/attest-logs/20261101T233927Z.35229.log
    attest     status ok  exit 0  319s  last: 1 harness suite(s) passed.  log .claude/state/attest-logs/20261101T234023Z.36680.log
    briefs     status ok  exit 0  31s   last: 1 harness suite(s) passed.  log .claude/state/attest-logs/20261101T234548Z.41710.log
    reporting  status ok  exit 0  34s   last: 1 harness suite(s) passed.  log .claude/state/attest-logs/20261101T234625Z.43138.log
    phase      status ok  exit 0  208s  last: 1 harness suite(s) passed.  log .claude/state/attest-logs/20261101T234707Z.43876.log
    selftest   status ok  exit 0  318s  last: 1 harness suite(s) passed.  log .claude/state/attest-logs/20261101T235040Z.47861.log
    gates.sh --fast  status ok  exit 0  2s  last: All required gates passed (0 ran, 5 unconfigured, 0 known).  log .claude/state/attest-logs/20261101T235609Z.51949.log

DV-1 is GATES' and not run here. Note for it: step 2 now names
`feature-developer` twice (the dispatch, and "A failure takes GATES' own
routes: the feature-developer"), so mutate every occurrence in the step.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return, with the PASTED probe output. -->

## Diff review

### Round 1 (GATES, 2026-11-02; fresh feature-developer, resolved claude-opus-5-5)

Scope `git diff main...HEAD`. Load assumed: one orchestrator and one runner
per worktree.

**Must fix**

1. **The gate-run check reads the wrong line** (advance-story.md:162-163,
   "require `fresh`, read `exit:` and `last:`"). `attest.sh` sets `last:` to
   the last non-blank output line. For `bash scripts/gates.sh`
   (gates.sh:1253-1287) that line is: on a pass, the check-boundaries tip; on
   BLOCKED (exit 3), "...environment.md are where that gets fixed and written
   down."; on a refused record (exit 1), `All required gates passed (...)`,
   which looks like a pass beside a failing exit; and only on a failure is it
   the verdict `N required gate(s) failed.`. Together with RED → GREEN's "a
   `fresh` record still has to show `exit: 0` and a passing `last:` line"
   (:143), a model rejects a passing run and re-runs the gates itself, which
   is the wait this story removes. This story's own GATES dispatch hit the
   pass case. Fix: read `exit:` (0 passed, 1 failed or not recorded, 3
   BLOCKED) and the verdict in the log; say `last:` is the tip, not the
   verdict. No needle moves; C-7 holds. The self-test step, lead-po:142 and
   complete-story:34 are right as written (those commands end on their
   verdict).

**Nice to have**

2. `void` is missing from the "`stale` or `none`" send-back sentence
   (advance-story.md:164-165); lead-po:142 names all three.
3. lead-po.md's "not yours to wait on" (:127-133) contradicts the unchanged
   "Two PRs at REVIEW" paragraph (:226), "Run `bash scripts/gates.sh` there".
   Fix: scope the new paragraph to a story's GATES phase, or point :226 at
   the dispatch.

Checked and coherent: BLOCKED (exit 3 is outside "a required gate fails",
so the runner reports and the BLOCKED paragraph applies); the stamp paragraph
(`git add` before dispatch is the orchestrator's; a refusal shows as
`exit: 1`); story edits while a run is out (docs are outside the work hash);
GATES → REVIEW ordering; `## Run and report` against the rest of
feature-developer.md; dispatch.test.sh's shape and floors (67 in both).

Verdict: fix 1 first.

Orchestrator: the reading of gates.sh:1253-1287 was reproduced by reading
the source (the tip prints after the verdict only on an unrefused full run;
BLOCKED and refusal exit before or around it, as the review says). PO
decision: fix 1, 2 and 3 in GATES, then a review of the fix.

**Fix (GATES, round 1)** (feature-developer, resolved claude-opus-5-5; no
override). Prose only, no test touched.

1. advance-story.md, GREEN → GATES: "read `exit:` and `last:`" now reads
   `exit:` (0 passed, 1 failed or not recorded, 3 BLOCKED, the paragraph
   below) and the verdict line in the log, `All required gates passed ...` or
   `N required gate(s) failed.`, and says that for this command `last:` is the
   check-boundaries tip printed after the verdict, not the verdict.
2. Same paragraph: "`stale` or `none`" is now "`stale`, `void` or `none`".
3. lead-po.md, "Two PRs at REVIEW": "Run `bash scripts/gates.sh` there" is now
   "Dispatch `bash scripts/gates.sh` there, as above" (the reviewer's second
   option), so the one instruction is the "not yours to wait on" paragraph.

Records (ATTEST_TAIL unset, one suite per call, all `fresh`):

    selftest.sh dispatch   status ok exit 0 last "1 harness suite(s) passed."  .claude/state/attest-logs/20261102T151525Z.6226.log
    selftest.sh procedure  status ok exit 0 last "1 harness suite(s) passed."  .claude/state/attest-logs/20261102T151605Z.6735.log
    selftest.sh attest     status ok exit 0 last "1 harness suite(s) passed."  .claude/state/attest-logs/20261102T151647Z.7421.log
    selftest.sh reporting  status ok exit 0 last "1 harness suite(s) passed."  .claude/state/attest-logs/20261102T152158Z.12621.log
    selftest.sh phase      status ok exit 0 last "1 harness suite(s) passed."  .claude/state/attest-logs/20261102T152231Z.13016.log
    gates.sh               status ok exit 0 last "...very record still matches the tree. Run it after committing, before the PR."
                           .claude/state/attest-logs/20261102T153436Z.16842.log
                           verdict in log (line 17): All required gates passed (0 ran, 7 unconfigured, 0 known).

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-02T15:34:53Z
    commit: 85e77be (working tree had uncommitted changes)
    tree:   891f8370dd1e05eb17f12095c02fc730b31e2f14
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

- 2026-10-31, while PLANNED: the first cut also dispatched
  `check-boundaries.sh`. The PO flagged that a seconds-long check costs more
  tokens to dispatch than it saves, and the user decided to keep it as the
  orchestrator's own run. AC-3 was rewritten to pin that, and C-1, C-2, C-3,
  C-5, the title and `## Out of scope` were changed to match. The branch name
  keeps the original slug.

- 2026-11-01, PLANNED → RED (lead-po, claude-fable-5-1). PO decisions:
  1. Criteria are testable as written: every needle the story reads out was
     checked against main after HARNESS-084 merged (edd7e94). The lines are
     `Then run `bash scripts/gates.sh`.` (advance-story.md:159), `every rung
     is something you run, not` (lead-po.md:127), the complete-story bullet
     `GATES → REVIEW opens with a review` (:35), and feature-developer.md
     having no `## Run and report`. `dispatch.test.sh` does not exist yet.
  2. The gate is `bash scripts/selftest.sh dispatch` (new suite) plus
     `procedure` unchanged. This repo configures no project gates
     (`gates.sh` reports all unconfigured), so the harness suites are the
     only verification, and CI runs every one.
  3. No signature changes (C-7), so there is no caller list. `epic:` is
     empty, so there is no epic done-when to check.
  4. Learned in HARNESS-084 and relevant here: `attest.sh` now passes the
     caller's `CLAUDE_PROJECT_DIR` through to the command (return 4), and
     `check` is keyed by the exact words, so the dispatch brief and the
     orchestrator's `check` must name the command identically, including
     `SELFTEST_JOBS=4`.
- 2026-11-01, RED verified by the orchestrator (claude-opus-5-5, the session
  model by then) without re-running: `attest.sh check` answered `fresh` for
  `bash scripts/selftest.sh dispatch` (exit 1, 66 passed / 1 failed - the
  real-tree assertion, naming exactly the six unwritten sites), `procedure`
  (exit 0), `selftest` (exit 0) and `bash scripts/gates.sh --fast` (exit 0).
  Resolved: RED, test-developer, claude-opus-5-5.
- 2026-11-01, GREEN verified by the orchestrator (claude-opus-5-5) without
  re-running: `attest.sh check` answered `fresh` with `exit: 0` for
  `bash scripts/selftest.sh` dispatch, procedure, attest, briefs, reporting,
  phase and selftest, and for `bash scripts/gates.sh --fast`. Diff read
  against C-1..C-4. Resolved: GREEN, feature-developer, claude-opus-5-5.
- 2026-11-02, GATES full gate run, dispatched per the new C-1 brief
  (feature-developer, resolved claude-opus-5-5). `attest.sh check -- bash
  scripts/gates.sh` answered `fresh`, `exit: 0`; the verdict
  `All required gates passed (0 ran, 7 unconfigured, 0 known).` is log line
  17 of `.claude/state/attest-logs/20261102T150934Z.1894.log`. Observed: the
  record's `last:` is NOT that verdict but gates.sh's trailing
  check-boundaries tip (`...very record still matches the tree. Run it after
  committing, before the PR.`), so "read `exit:` and `last:`" reads the
  wrong line for gates.sh. Put to the diff review.
