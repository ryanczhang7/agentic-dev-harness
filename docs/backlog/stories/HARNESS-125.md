---
id: HARNESS-125
title: The CI self-test runs four suites at a time, largest first
slug: the-ci-self-test-runs-four-suites-at-a-t
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-125-the-ci-self-test-runs-four-suites-at-a-t
depends_on: [HARNESS-124]  # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest.sh, .claude/tests/selftest.test.sh, .claude/tests/floors.conf, .github/workflows/gates.yml, .github/workflows/boundaries.yml, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

The audit `docs/wiki/audits/runtime-cut-2026-11-25.md` found that the
harness's own CI spends 98% of its `gates` job in one step, the self-test,
run one suite at a time on a 4-vCPU runner (findings ST-1 and CI-3), that
on the concurrent path suites start in glob order, which leaves the longest
suite late (ST-2), and that a push to an open PR does not cancel the run it
replaced (CI-6). Its `## Decided` items 1 and 2 are what this story
implements: the CI self-test runs four suites at a time, the concurrent
path starts the largest suites first while still printing in suite order,
and both PR workflows cancel a superseded run.

**The decision is the audit's; its numbers are not.** Re-measured for this
story on run 45223333374 (2026-11-23, main, `ubuntu-latest`), from the
timestamps of the 35 summary lines of the plain `Harness self-test` step:

| Measure | Audit | Re-measured |
|---|---|---|
| The step, one suite at a time | 438 s | 429 s (sum of 35 suites) |
| Longest suites | run-queue 96, boundaries 79, selftest 51 | run-queue 96, boundaries 77, selftest 51, gates 32 |
| Four at a time, glob start order (simulated) | 145 s | 144 s |
| Four at a time, longest first (simulated) | 110 s | 108 s |
| Four at a time, largest FILE first (simulated) | not measured | 112 s |
| Four at a time, largest FLOOR first (simulated) | not measured | 112 s |

The simulation is a greedy four-slot schedule over the measured durations;
it is not a run. No run at `SELFTEST_JOBS=4` has been made on a runner:
DV-2 makes one before the PR opens. No workflow sets `SELFTEST_JOBS` today
(`grep -rn SELFTEST_JOBS .github/` prints nothing).

**The weight is the suite file's size in bytes.** It needs no new file and
no new grammar, it exists for a consumer's `project-*.test.sh` suites as
for upstream's, and on the measured durations it schedules as well as the
floor value does (112 s both) and within 4 s of the true optimum. HARNESS-036
left this open on purpose: its C-2 says "Start order is free; print order
is not. Suites may start in glob order or largest file first", and
`selftest.test.sh`'s `held` helper already has `PAD=<n>` "so that size
order and glob order agree" for the cases whose meaning depends on which
suites start first.

**The weekly colour-forced step stays one suite at a time.** It is the
control: after this story it is the only place the one-at-a-time path runs
over the real 35 suites in CI, and on a scheduled or manual run both steps
run in the same job on the same runner, so their per-suite counts can be
compared directly. That comparison needs the colour step to pass, which it
has not since 2026-11-02; HARNESS-124 fixes it, hence `depends_on`.

The required gate that fails if this breaks is `selftest`: AC-1 to AC-5
are cases in `.claude/tests/selftest.test.sh`. The workflow text (AC-7) has
no suite: an upstream suite that pinned this repository's workflow files
would fail in every consumer, whose workflows are their own. It is read at
REVIEW, as HARNESS-073's AC-4 was, and DV-2 runs it.

## Acceptance criteria

- **AC-1 (largest first)** — Given a fixture of four suites whose file sizes
  rank them in the reverse of glob order, when `selftest.sh` runs them with
  `SELFTEST_JOBS=2`, then no suite is started while a larger suite has not
  yet been started: the two largest are the first two started, and the
  smallest is the last.
  *Control:* the same four suites padded so that size order equals glob
  order start in glob order, so the assertion distinguishes the two orders
  rather than passing on both.
- **AC-2 (ties)** — Given suites of equal size, when they run with
  `SELFTEST_JOBS=2`, then they start in glob order among themselves.
- **AC-3 (print order is unchanged)** — Given the reversed fixture of AC-1,
  extended with one suite that exits non-zero and one that is under its
  floor, when it runs with `SELFTEST_JOBS=2` and with `SELFTEST_JOBS=1`,
  then the two runs' stdout are byte-identical, their stderr are
  byte-identical, and their exit statuses are equal: blocks are printed in
  glob order whatever order the suites started in.
- **AC-4 (an early end names what was not started)** — Given the reversed
  fixture and `SELFTEST_JOBS=2`, when the run receives TERM while the two
  largest suites are running and the two smallest have not been started,
  then every started suite's block is printed, in glob order, and the
  `selftest: never started:` line names exactly the two suites that were
  never started, in glob order. Those two are the FIRST two in glob order,
  which the handler as written today would report as started.
- **AC-5 (one at a time is unchanged)** — Given the reversed fixture, when
  it runs with `SELFTEST_JOBS` unset, and with `SELFTEST_JOBS=1`, then the
  suites start, and print, in glob order.
- **AC-6 (nothing is loosened)** — Given this story's diff, when it is
  read, then no line of `.claude/tests/floors.conf` lowers a floor, no
  assertion that `selftest.test.sh` held before the story is removed or has
  its expected value changed, and the only change to an existing fixture is
  added `PAD=`.
- **AC-7 (the workflows)** — Given `.github/workflows/gates.yml` and
  `boundaries.yml` after this story, when they are read, then: the step
  named `Harness self-test` sets `SELFTEST_JOBS: 4` in a step-level `env:`
  and its `run:` line is still exactly `bash scripts/selftest.sh`; the step
  named `Harness self-test, with colour forced` is unchanged; each workflow
  has a top-level `concurrency:` block as Contract C-4 gives it; and
  `bash scripts/ci-local.sh --dry-run` prints the same lines it printed
  before the story.

## Contract

**Writes:** `scripts/selftest.sh`, `.claude/tests/selftest.test.sh`, `.claude/tests/floors.conf`, `.github/workflows/gates.yml`, `.github/workflows/boundaries.yml`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

**C-1. Start order, concurrent path only.** In `scripts/selftest.sh`, the
branch taken when `JOBS >= 2` and two or more suites are selected (today
lines 637-702) starts suites in descending order of the size in bytes of
`.claude/tests/<name>.test.sh`; equal sizes keep glob order. The sizes are
read once, before the first suite starts, in a bounded number of processes
that does not grow with the number of suites (one `wc -c` over all the
selected files is enough); never one process per suite. A size that cannot
be read counts as 0, so that suite starts last; it is not an error.
Everything else about the path is as it is: at most `JOBS` alive, a slot
refilled when any suite exits, `suite_status() { wait "$1"; }` on exactly
one line, the poll delays.

**C-2. Print order.** Unchanged: glob order, each block as soon as it and
every suite before it in glob order have finished or failed to start.
`NAMES`, `PIDS`, `RCS` and `STARTERR` stay indexed by glob position. What
changes is that "started" is no longer a prefix of that index: the
scheduler holds the start order separately, and the print loop stops at the
first glob index that has neither a collected status nor a start error,
whether or not it has been started.

**C-3. The EXIT handler (HARNESS-090).** `selftest_exit` today treats every
index below `${#PIDS[@]}` as started and every index from there to
`NSUITES` as never started. With C-1 that is wrong whenever size order and
glob order differ. After this story: a suite is "started" when
`start_suite` was entered for it, whatever its glob index; the handler
prints the blocks of started suites in glob order, lists the started ones
it could not print under `selftest: unreported:` in glob order, and lists
every selected suite `start_suite` was never entered for under `selftest:
never started:` in glob order. The wording of every line it prints is
unchanged. `SELFTEST_FAIL_START` is unchanged.

**C-4. The workflows.** Exactly this, and nothing else in either file
except the comments that explain it:

```yaml
# gates.yml, top level, after `on:`
concurrency:
  group: gates-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

# gates.yml, the existing step
      - name: Harness self-test
        env:
          SELFTEST_JOBS: 4
        run: bash scripts/selftest.sh

# boundaries.yml, top level, after `on:`
concurrency:
  group: boundaries-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

The semantics behind each value: `4` is the runner's vCPU count
(`ubuntu-latest`), and the measured schedule gains nothing above it because
the longest suite alone is 96 s of a 108 s optimum. `cancel-in-progress` is
conditional in `gates.yml` because that workflow also runs on `schedule`
and `workflow_dispatch`, where `github.ref` is the branch and a second run
must not cancel the first; `boundaries.yml` runs only on `pull_request`.
The group is per PR, so two PRs never cancel each other. The
`SELFTEST_JOBS` value goes in a step-level `env:` and not on the `run:`
line: `ci-local.sh` replays `run:` lines only (`workflow_steps`), so the
local replay stays one at a time unless the caller sets the variable, and
`ci-local.test.sh`'s derivation, which greps the same `run:` lines, is
untouched. The comment in `scripts/selftest.sh`'s header that says "CI
leaves it unset" and "Suites start in suite order, so the slowest one
(phase-guard) still sets the floor" is corrected to what is now true.

**C-5. Existing cases that assume which suites start first.** RED reads
every concurrent-path case in `.claude/tests/selftest.test.sh` and, where
its meaning depends on which suites start first, pads the fixture with
`PAD=` so that size order equals glob order. Known to need a look, by the
line numbers at main `d495ae7`: the `held` helper and its comment (989-1003),
the AC-2 fixtures `b1`..`b6` and `c1`..`c4` (1237-1308), `work_case`
(1398-1412, already padded), and every HARNESS-090 case from 1594 on whose
expectation names a suite that "has none" or was "never started" (the `e`,
`k` and `g` fixtures, the second-TERM case near 1827). A `held` file's size
already varies with its arguments, so two fixtures that look alike are not
necessarily tied. No expected value changes. If a case cannot be kept by
padding alone, RED stops and reports it; it does not edit the assertion.
RED's handoff lists each fixture it padded.

**C-6. How RED observes start order.** The `held` suites already record
what they saw at start and finish under the fixture's marker directory
(`alive`, `finished`, `finbefore`, `WAIT_START`). Start rank is observed
the same way: each held suite records, as its first act, which suites'
start markers already exist, and holds until released or until the suites
it waits for have started, so that the order is decided by the scheduler
and not by a race between two children writing markers. No test hook is
added to `scripts/selftest.sh` for this.

**C-7. Baselines the story may read out.** The table in `## Context`,
measured on run 45223333374: 429 s one at a time; simulated four-slot
schedules of 144 s (glob), 112 s (file size), 108 s (true longest-first).
Suite sizes at `d495ae7`, largest first: gates 247,589 bytes; boundaries
246,147; plan 126,575; run-queue 116,911; dispatch 106,774; procedure
102,745; phase-guard 97,228; selftest 94,474.

**Oracle partition.**

| AC | Kind | Instruction to RED |
|---|---|---|
| AC-1, AC-2, AC-5 | mechanical | Pin the start rank of each suite exactly, on fixtures; the control of AC-1 is part of the criterion. |
| AC-3 | mechanical | Byte comparison of two runs, as HARNESS-036 AC-2 does it; include the failing and the under-floor suite. |
| AC-4 | mechanical | Pin the whole `never started:` line and the order of the printed blocks. |
| AC-6 | mechanical, read at REVIEW | No suite; the diff review reads `floors.conf` and the removed lines of `selftest.test.sh`. |
| AC-7 | mechanical, read at REVIEW | No suite can pin this repository's workflow text without failing in a consumer. `ci-local.test.sh`'s existing derivation covers the `--dry-run` clause; DV-2 runs the rest. |
| Context table | settled | Read the numbers out. Do not re-derive or tune them. |

No existing export changes its signature. No test-only dependency.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". DV-1 is the defect put
back for the central claim. DV-2 is not a mutation: it is the run the audit
says has never been made (ST-1, "simulated, not run"), and it is the only
thing that executes AC-7. Neither runs the full self-test locally.

**DV-1. Glob start order put back.** With the size ordering of C-1 removed
from `scripts/selftest.sh` (one `scripts/mutate.sh` expression that makes
the start order the glob order again), AC-1's "the two largest are the
first two started" assertion **must** fail, and AC-1's control and AC-3's
byte comparison must still pass. Run against
`bash .claude/tests/selftest.test.sh` only. RED cannot run it: the ordering
does not exist until GREEN. **Owner: GATES.**

**DV-2. One manual run on a runner, before the PR opens.** Push the story
branch and start the workflow on it by hand
(`gh workflow run gates.yml --ref <branch>`; a manual run executes both
self-test steps, which a pull request run does not). It **must** show, in
the one job: the `Harness self-test` step at `SELFTEST_JOBS=4` and the
colour-forced step, one at a time, both ending `<n> harness suite(s)
passed.` with the same n; the same `assertion floors:` executed total in both, compared as
numbers; and the first step taking less than 215 s, half of the 429 s
measured one at a time. Paste both steps' durations, both floors lines and
the run id. If a suite fails in the first step and passes in the second,
the story stops there and the failing suite is reported with its output:
that is the timing sensitivity the audit says "would have to be true"
(ST-1), and it is not fixed by lowering the job count in this story
without the user's decision. If the step takes 215 s or more, the story
says so and does not claim the saving. RED and GREEN cannot run it: it
needs the finished workflow file on a pushed branch. **Owner: GATES.**

At REVIEW, not as a verification: record in `## Notes` the duration of the
`Harness self-test` step and of the whole `gates` job on the PR's own run,
beside the 429 s and 7.5 min they replace, and, if a second push happened
while a run was in progress, whether the first run was cancelled.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Head each entry AM-<n> (`- **AM-1 (AC-2).** ...`), and give it its
     adjudication record, a line of its own in this section, outside any
     comment or fence - check-boundaries.sh refuses a new entry without one:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A claim that a criterion is wrong is also what an agent says when it
     wants to stop failing, so it is judged by a fresh `fable` dispatch - a
     `lead-po` on the ADJUDICATE row of models.conf, on different inputs, not
     the claimant's code - and that dispatch writes the judgement and the
     record line; the judgement is never the orchestrator's. An entry that
     follows a diff-review or PR-feedback finding routed RED or AMEND was
     judged by that review, so the orchestrator writes its record, naming the
     round and finding (or the PR-feedback item) and the model the review was
     planned on and resolved to:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Its being upheld does not replace the user's approval; both go in the
     entry. A change
     the user asked for unprompted is not a claim: `- **Adjudicated AM-<n>:**
     requested by the user, <date>`. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-125` from `.claude/harness/models.conf`.
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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |
| ADJUDICATE | `lead-po` | `fable` | a claim that an acceptance criterion, a threshold or a frozen test is wrong is judged against the contract by a fresh dispatch on different inputs, never by the orchestrator that wants the answer; needed in any phase, so it is last |

**Resolved:**

- PLANNED, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-25; no override reported. Planned by `/plan-story` in a batch of four (HARNESS-124 to 127). The oracle partition is in `## Contract`: AC-1 to AC-5 mechanical, AC-6 and AC-7 read at REVIEW.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- The colour-forced step: it stays one suite at a time, unconditional on
  `schedule` and `workflow_dispatch`, with its `run:` line as it is.
- The one-at-a-time path of `selftest.sh`, the default of `SELFTEST_JOBS`
  (unset means 1), and `scripts/ci-local.sh`.
- A weight other than file size: measured durations, a new kind of line in
  `floors.conf`, a per-suite declaration. If DV-2 shows file size schedules
  badly on a runner, that is a finding for a new story, with the numbers.
- Making any suite faster: the run-queue suite's poll (audit ST-7), the
  floor table's third copy (ST-3), `fixture-only` declarations (ST-4).
- Skipping the self-test on a pull request (audit CI-2, HARNESS-126) and
  the push skip (CI-1, HARNESS-127).
- Any consumer's workflow files. `.github/workflows/**` is project-owned
  and a refresh does not touch it; a consumer copies the two blocks of C-4
  in its own story.
- `timeout-minutes`, runner images, or a matrix.

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
     and the next person needs to know why. One block per return, headed
     R-<n> (`### R-1 (the count test)`), and carrying its adjudication
     record - a line of its own, outside any comment or fence, written by
     the fresh `fable` dispatch (a `lead-po` on the ADJUDICATE row of
     models.conf) that judged the claim the test is wrong; the judgement is
     never the orchestrator's. check-boundaries.sh refuses a new entry
     without one:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A return that follows a diff-review or PR-feedback finding routed RED
     or AMEND was judged by that review, so the orchestrator writes the
     record, naming the round and finding (or the PR-feedback item) and the
     model the review was planned on and resolved to:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Then:
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

