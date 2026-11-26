---
id: HARNESS-125
title: The CI self-test runs four suites at a time, largest first
slug: the-ci-self-test-runs-four-suites-at-a-t
epic: 
type: feature
status: in-progress
phase: GATES
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

**DV-1 result (GATES, 2026-11-26): PASS.** Run by the orchestrator:
`bash scripts/mutate.sh scripts/selftest.sh 's/start_suite "\${ORDER\[\$started\]}"/start_suite "$started"/' -- bash .claude/tests/selftest.test.sh`.
AC-1's three start-order assertions went red; AC-1's control, AC-2 and AC-5
stayed green; AC-3's byte comparison stayed green (only its start-order
precondition, which exists to make that comparison non-vacuous, went red); AC-4
went red. 396 passed, 8 failed, the same eight RED watched fail. The file was
restored and verified byte-for-byte.

```
=== mutate: scripts/selftest.sh (1 line(s) changed by s/start_suite "\${ORDER\[\$started\]}"/start_suite "$started"/) ===
  717 -       if start_suite "${ORDER[$started]}"; then
  717 +       if start_suite "$started"; then
  HARNESS-125 AC-1  the largest suite files start first: four suites whose sizes run against glob order
    FAIL AC-1: the two largest, s3-more and s4-most, are the first two started: neither saw a smaller suite started
         expected: s3-more saw [] s4-most saw []
         actual:   s3-more saw [s1-least s2-less] s4-most saw [s1-least s2-less]
    FAIL AC-1: s2-less, third in size, is started third: it saw exactly the two largest started
         expected: s3-more s4-most
         actual:   
    FAIL AC-1: s1-least, the smallest, is started last: it saw every other suite started
         expected: s2-less s3-more s4-most
         actual:   
  HARNESS-125 AC-1  control: the same four suites, padded so that size order is glob order, start in glob order
  HARNESS-125 AC-2  suites of equal size start in glob order among themselves
  HARNESS-125 AC-3  print order is glob order whatever the start order: SELFTEST_JOBS=2 prints SELFTEST_JOBS=1's bytes
    FAIL precondition: at SELFTEST_JOBS=2, s5-exits3, fifth in glob order and largest, is among the first two started
         expected: 
         actual:   s1-least s2-less s3-more
  HARNESS-125 AC-4  TERM while the two largest run: the first two in glob order are named never started
    FAIL precondition: and s1-least and s2-less have not been started
         expected: s1-least=absent s2-less=absent
         actual:   s1-least=present s2-less=present
    FAIL AC-4: only the two largest ran (the TERM started no more)
         expected: s3-more s4-most
         actual:   s1-least s2-less s3-more s4-most
    FAIL AC-4: every started suite's block is printed, once each, in glob order
         expected: s3-more s4-most
         actual:   s1-least s2-less s3-more s4-most
    FAIL AC-4: the run ends with the ended-before line and a never-started line naming exactly s1-least s2-less
         expected: 
         selftest: ended before its summary: 2 of 4 suite(s) reported (status 143).
         selftest: never started: s1-least s2-less
         actual:   s4-most: 2 passed, 0 failed
         selftest: ended before its summary: 4 of 4 suite(s) reported (status 143).
  HARNESS-125 AC-5  one at a time is unchanged: the reversed fixture starts and prints in glob order
selftest: 396 passed, 8 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-125/.claude/state/mutations/scripts_selftest.sh.20261126T214354Z.1651247.bak) ===
  717:       if start_suite "${ORDER[$started]}"; then
```

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

**DV-2 result (GATES, 2026-11-26): PASS.** Run by the orchestrator: the story
branch pushed at `680f6ae`, then `gh workflow run gates.yml --ref
story/HARNESS-125-the-ci-self-test-runs-four-suites-at-a-t`, run
45900075305 (`workflow_dispatch`, `ubuntu-latest`), job `gates` success.
https://github.com/ryanczhang7/agentic-dev-harness/actions/runs/45900075305

| Step | Mode | Started | Ended | Duration | Suites | Floors line |
|---|---|---|---|---|---|---|
| `Harness self-test` | `SELFTEST_JOBS=4` | 21:43:35Z | 21:46:09Z | **154 s** | 36 passed | 7951 executed, 7853 declared |
| `Harness self-test, with colour forced` | one at a time | 21:46:09Z | 21:53:30Z | 441 s | 36 passed | 7951 executed, 7853 declared |

    gates	Harness self-test	assertion floors: all 36 suite(s) met their declared floor (7951 assertions executed, 7853 declared).
    gates	Harness self-test	36 harness suite(s) passed.
    gates	Harness self-test, with colour forced	assertion floors: all 36 suite(s) met their declared floor (7951 assertions executed, 7853 declared).
    gates	Harness self-test, with colour forced	36 harness suite(s) passed.

Every condition holds: both steps end `36 harness suite(s) passed.`; the
executed totals are equal as numbers (7951 = 7951); the four-at-a-time step
took 154 s, under the 215 s threshold and 35% of the 441 s the one-at-a-time
step took in the same job (the story's baseline was 429 s, on 35 suites). No
suite failed in either step. The step's simulated optimum was 108-112 s; the
measured 154 s is above it, and the saving is claimed at the measured value
only. The whole job, with both steps, took 601 s; a pull-request run executes
only the first step.

At REVIEW, not as a verification: record in `## Notes` the duration of the
`Harness self-test` step and of the whole `gates` job on the PR's own run,
beside the 429 s and 7.5 min they replace, and, if a second push happened
while a run was in progress, whether the first run was cancelled.

**DV-3. Ties reversed (diff review round 1, finding 1).** With the sort's
`-lt` made `-le`, so that an equal-sized suite moves ahead of the one before
it, AC-2's three start-order assertions **must** fail. Added at GATES on the
diff review's GATES finding; it earns AC-2, which passed on arrival in RED.
**Owner: GATES.**

**DV-3 result (GATES, 2026-11-26): PASS.** Run by the orchestrator against
`bash .claude/tests/selftest.test.sh`: exactly AC-2's three assertions went
red, nothing else; 401 passed, 3 failed. The file was restored and verified
byte-for-byte.

```
=== mutate: scripts/selftest.sh (1 line(s) changed by s/-lt "\${SIZES\[\$i\]}" \]; do/-le "${SIZES[$i]}" ]; do/) ===
  699 -     while [ "$j" -gt 0 ] && [ "${SIZES[${ORDER[$((j-1))]}]}" -lt "${SIZES[$i]}" ]; do
  699 +     while [ "$j" -gt 0 ] && [ "${SIZES[${ORDER[$((j-1))]}]}" -le "${SIZES[$i]}" ]; do
    FAIL AC-2: q1-tie and q2-tie, first in glob order, are the first two started
         expected: q1-tie saw [] q2-tie saw []
         actual:   q1-tie saw [q3-tie q4-tie] q2-tie saw [q3-tie q4-tie]
    FAIL AC-2: q3-tie is started third
         expected: q1-tie q2-tie
         actual:   
    FAIL AC-2: q4-tie, last in glob order, is started last
         expected: q1-tie q2-tie q3-tie
         actual:   
selftest: 401 passed, 3 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-125/.claude/state/mutations/scripts_selftest.sh.20261126T221210Z.1672115.bak) ===
```

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
- RED, `test-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-26; no override. Orchestrator checked all three attest records `fresh` itself on tree `c45cf62` (`selftest: 396 passed, 8 failed` exit 1, `floors: 9 passed, 0 failed`, `--fast` exit 0, vacuous), read the eight FAIL lines in the log (AC-1 x3, the AC-3 start-order precondition x2, AC-4 x3; every one shows glob start order), checked that every removed line of selftest.test.sh comes back with only `PAD=` added, and ran none of them again.
- GREEN, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-26; no override. Orchestrator checked all three attest records `fresh` itself on tree `8d1e060` (`selftest: 404 passed, 0 failed`, `ci-local: 52 passed, 0 failed`, `--fast` exit 0, vacuous), read the selftest.sh and workflow diffs against C-1 to C-4, and ran none of them again.
- GATES, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-26; no override. Ran `bash scripts/gates.sh` only: exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).`, 16 s, not queued; orchestrator checked the record `fresh`. DV-1 (local, mutate.sh) and DV-2 (run 45900075305) were run by the orchestrator, results under `## Deferred verifications`; VERSION 145.
- DIFF-REVIEW, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-26; no override. Round 1: one Should-fix routed GATES (run as DV-3, passed), one Should-fix routed RED and one Nice-to-have routed AMEND, both declined and recorded; `Verdict: Ship.`

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

One level: fixture runs of the real `scripts/selftest.sh` in
`.claude/tests/selftest.test.sh`, on the throwaway tree the suite already
builds, with the `held` synthetic suites. That is where the contract lives
(the scheduler's start and print order, the EXIT handler's lines); no unit
level exists for a bash script's main loop, and an end-to-end run over the
real 35 suites is DV-2's.

**Observing start order (C-6).** Every new suite carries `SEEN_REC` ahead of
`_held.sh`, so its first act lists `mk/started/` into `mk/seen/<name>` before
its own start marker exists. The first two suites started in one pass race
to write markers, so only the pair is pinned ("neither saw a third suite
started"). Every later start is forced by a hold: with two slots, a third
suite starts only when a slot frees, and one of the first two holds
(`WAIT_START`) until the suite meant to start third has started. None of the
holds can deadlock under glob order or size order, so a wrong order fails an
assertion rather than timing out. No hook was added to `selftest.sh`.

**Fixtures.** `order_fixture <pad1..pad4>` builds `s1-least s2-less s3-more
s4-most`; `0 2 4 6` is the reversed fixture (sizes 268 < 329 < 429 < 567
bytes), `6 4 2 0` its control (568 > 429 > 329 > 267). The holds are the same
in both: `s1-least` waits for `s3-more` to start, `s4-most` for `s2-less`.
Each fixture states its size order as a precondition with `h_rank`, which
reads `wc -c` exactly as C-1 does.

| Case (describe) | AC | Asserts |
|---|---|---|
| `HARNESS-125 AC-1  the largest suite files start first...` | AC-1 | sizes grow in glob order; rc 0, no timeouts; `s3-more`/`s4-most` saw no smaller suite started; `s2-less` saw exactly `s3-more s4-most`; `s1-least` saw `s2-less s3-more s4-most`; blocks printed in glob order |
| `HARNESS-125 AC-1  control: ...start in glob order` | AC-1 control | sizes shrink in glob order; rc 0; `s1-least`/`s2-less` first pair; `s3-more` saw `s1-least s2-less`; `s4-most` saw `s1-least s2-less s3-more` |
| `HARNESS-125 AC-2  suites of equal size...` | AC-2 | four 265-byte files (`h_rank equal`); rc 0; `q1-tie`/`q2-tie` first pair; `q3-tie` third; `q4-tie` last |
| `HARNESS-125 AC-3  print order is glob order...` | AC-3 | reversed fixture plus `s5-exits3` (741 bytes, exits 3, floor met) and `s6-short` (below its floor); precondition that `s5-exits3` was among the first two started at JOBS=2; equal exit status (1, 1); stdout and stderr byte-identical between JOBS=1 and JOBS=2 (`h_same`, `cmp`); six blocks in glob order; `2 of 6 harness suite(s) FAILED.` |
| `HARNESS-125 AC-4  TERM while the two largest run...` | AC-4 | sizes grow; `s3-more`/`s4-most` running and held; `s1-least`/`s2-less` not started; rc 143; started set `s3-more s4-most`; blocks `s3-more s4-most`; each block's summary line; the whole 3-line tail ending `selftest: never started: s1-least s2-less`; no `unreported:` line; no buffers or lock left |
| `HARNESS-125 AC-5  one at a time is unchanged...` | AC-5 | for SELFTEST_JOBS unset and 1: rc 0; start order (by seen-count) `s1-least s2-less s3-more s4-most`; print order the same |
| 7 C-5 preconditions in existing cases | C-5, AC-6 | `precondition (HARNESS-125 C-5): <fixture> are padded so that size order is glob order` - `h_rank down` over b, c, the HARNESS-090 e, k, g and the R-1 d, h fixtures |

AC-6 and AC-7 have no suite, per the oracle partition: they are read at REVIEW.

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

Written by the Test Developer (dispatched as `opus`; ran as Claude Opus 5.5,
`claude-opus-5-5`, no override).

### Commands

    bash scripts/attest.sh -- bash .claude/tests/selftest.test.sh
    bash scripts/attest.sh -- bash .claude/tests/floors.test.sh
    bash scripts/attest.sh -- bash scripts/gates.sh --fast

The selftest suite took 7 to 23 minutes on this Windows host (local), depending
on host load: 978 s for the final run, and 1382 s for a run that overlapped
the floors suite.

### Result, on the final tree

    selftest.test.sh   tree: c45cf62d56ff78d7fa99cb3d1498051e6f017bfe  status: ok  exit: 1
                       last: selftest: 396 passed, 8 failed
                       log:  .claude/state/attest-logs/20261126T062829Z.1609414.log
    floors.test.sh     tree: c45cf62d56ff78d7fa99cb3d1498051e6f017bfe  status: ok  exit: 0
                       last: floors: 9 passed, 0 failed
                       log:  .claude/state/attest-logs/20261126T061204Z.1602482.log
    gates.sh --fast    tree: c45cf62d56ff78d7fa99cb3d1498051e6f017bfe  status: ok  exit: 0
                       last: All required gates passed (0 ran, 5 unconfigured, 0 known).
                       log:  .claude/state/attest-logs/20261126T061122Z.1601854.log

`gates.sh --fast` is vacuous, as expected: every gate in this repository
is unconfigured (BOOTSTRAPPED=no).

The 8 failures (verbatim from the log), each the right one: today's
scheduler starts in glob order.

```
  HARNESS-125 AC-1  the largest suite files start first: four suites whose sizes run against glob order
    FAIL AC-1: the two largest, s3-more and s4-most, are the first two started: neither saw a smaller suite started
         expected: s3-more saw [] s4-most saw []
         actual:   s3-more saw [s1-least s2-less] s4-most saw [s1-least s2-less]
    FAIL AC-1: s2-less, third in size, is started third: it saw exactly the two largest started
         expected: s3-more s4-most
         actual:   
    FAIL AC-1: s1-least, the smallest, is started last: it saw every other suite started
         expected: s2-less s3-more s4-most
         actual:   

  HARNESS-125 AC-3  print order is glob order whatever the start order: SELFTEST_JOBS=2 prints SELFTEST_JOBS=1's bytes
    FAIL precondition: at SELFTEST_JOBS=2, s5-exits3, fifth in glob order and largest, is among the first two started
         expected: 
         actual:   s1-least s2-less s3-more

  HARNESS-125 AC-4  TERM while the two largest run: the first two in glob order are named never started
    FAIL precondition: and s1-least and s2-less have not been started
         expected: s1-least=absent s2-less=absent
         actual:   s1-least=present s2-less=present
    FAIL AC-4: only the two largest ran (the TERM started no more)
         expected: s3-more s4-most
         actual:   s1-least s2-less s3-more s4-most
    FAIL AC-4: every started suite's block is printed, once each, in glob order
         expected: s3-more s4-most
         actual:   s1-least s2-less s3-more s4-most
    FAIL AC-4: the run ends with the ended-before line and a never-started line naming exactly s1-least s2-less
         expected: 
         selftest: ended before its summary: 2 of 4 suite(s) reported (status 143).
         selftest: never started: s1-least s2-less
         actual:   s4-most: 2 passed, 0 failed
         
         selftest: ended before its summary: 4 of 4 suite(s) reported (status 143).
```

- AC-1 x3: `s1-least` and `s2-less` (smallest) were started first and saw
  nothing (empty `actual`); `s3-more` and `s4-most` started after them. That
  is glob order, the thing C-1 removes.
- AC-3 precondition: `s5-exits3`, the largest file, started fifth. It is
  the precondition that keeps AC-3's byte comparison from passing on a run
  whose start order was glob order anyway; the byte comparison itself passes
  (as it must, and as DV-1 requires after GREEN).
- AC-4 x4: under glob order both slots went to `s1-least` and `s2-less`
  first, so by the time `s3-more`/`s4-most` held, all four had started, and
  the handler reported `4 of 4` with no never-started line. Under C-1 the two
  held suites take both slots and the first two in glob order wait; that is
  also the case the old handler (index below `${#PIDS[@]}` = started) gets
  wrong, which is C-3.

No other assertion fails: every pre-existing case passes with its padding,
which is what C-5 required.

### Passed on arrival, and what earns each

| Case | Why it passes today | What earns it, and who |
|---|---|---|
| AC-1 control (5) | today's order is glob order, and the control's size order equals it | The reversed fixture is its pair: the same four suites and holds, only PAD differs, and the reversed one fails today. After GREEN, DV-1 (glob order put back) must leave the control green and turn AC-1 red: owner GATES. |
| AC-2 ties (5) | glob order today | A GATES mutation that reverses the tie-break in GREEN's sort (for example, a secondary key on the glob index sorted descending, or a reversed sort of the whole size+index list): AC-2's three "started first/third/last" assertions must go red. The exact expression depends on GREEN's code; owner GATES. |
| AC-3 byte comparison, block order, exit status, last line (5) | print order is glob order today, and so is start order | After GREEN, the precondition makes the comparison non-vacuous (start order is not glob order). A mutation of GREEN's print loop that prints in start order instead of glob order must turn the byte comparison and the block-order line red. Budget: not in DV-1; `/audit-mutations` if wanted. |
| AC-5 (6) | the one-at-a-time loop iterates the glob | After GREEN: `bash scripts/mutate.sh scripts/selftest.sh 's/if \[ "\$JOBS" -lt 2 \] || \[ "\$NSUITES" -lt 2 \]; then/if false; then/' -- bash .claude/tests/selftest.test.sh` sends SELFTEST_JOBS=1 down the concurrent path, which then starts largest first one at a time; AC-5's start-order assertion must go red (`s4-most s3-more s2-less s1-least`). Not owed by the budget; offered. |
| The 7 C-5 preconditions | the paddings are correct | Their failing branch was probed outside the suite, against scratch copies of the fixtures written by a copy of `held()` (the function extracted from the test file with awk); output below. The probe found that a missing file read as size 0 and could satisfy `down`; `h_rank` now reports `<name>=missing` and fails. |

The `h_rank` probe (scratch fixtures; `sz3` holds the padded files, `sz` the
pre-story ones):

```
glob: down
missing last: not down: b1-last=690 nosuch=missing
missing first: not down: nosuch=missing b6-plain=122
reversed: not down: b6-plain=122 b5-stderr=241
b unpadded: not down: b1-last=190 b2-exits3=161 b3-short=122 b4-silent=127 b5-stderr=141 b6-plain=122
```

The last line is the pre-story `b` fixture: without its padding, the new
precondition fails by name.

### Padded fixtures (C-5; the only change to existing fixtures is an added `PAD=`)

| Fixture | PAD per suite, glob order | Bytes after, glob order | Why it needed it |
|---|---|---|---|
| HARNESS-036 AC-2 `b1`..`b6` | 10 8 6 4 2 0 | 690 561 422 327 241 122 | `b5-stderr` (141) outsized `b3`/`b4` (122/127), so size order started it before them |
| HARNESS-036 AC-2 `c1`..`c4` | 6 4 2 0 | 470 322 241 122 | `c3-stderr` (141) outsized `c2-plain` (122) |
| HARNESS-090 `e1`..`e5` | 8 6 4 2 0 | 541 459 341 223 123 | `e2-done` (159) outsized `e1-held` (141), so it would start first |
| HARNESS-090 `k1`..`k5` | 8 6 4 2 0 | 496 and down to 123 | `k4-held` (141) outsized `k3-later` (122): it would have taken `k3-later`'s turn, and `k3-later` is the suite the case is about |
| HARNESS-090 `g1`..`g4` | 6 4 2 0 | 422 324 222 122 | `g2-nostart` (124) outsized `g1-first` (122), so the failed start would come first rather than between |
| HARNESS-090 R-1 `d1`..`d4` | 6 4 2 0 | 441 359 241 123 | `d2-done` (159) outsized `d1-held` (141) |
| HARNESS-090 R-1 `h1`..`h4` | 6 4 2 0 | 441 324 241 123 | `h3-held` (141) outsized `h2-nostart` (124): `h2-nostart`'s failed slot would have gone to `h4-queued`, breaking "h4-queued never started" |

One PAD line is 50 bytes, so a step of 2 is 100 bytes, more than any two
unpadded files of one fixture differ by (largest: 74). Each padded fixture
gained one `precondition (HARNESS-125 C-5): ... size order is glob order`
assertion; no assertion was removed and no expected value changed.

Not padded, and why:
- HARNESS-036 AC-1 `a1`..`a5`: sizes 153 141 133 122 127. Only `a4`/`a5`
  differ from glob, and at JOBS=3 the first three are `a1 a2 a3` either way;
  nothing it asserts depends on `a4`/`a5` order (peak >= 2, buffer seen, exit
  1). The golden is a sequential run.
- `d1-quick d2-held d3-held`, `f1..f3` (both variants): three suites at JOBS=3,
  all start in the first pass.
- `peak_case` `e1..e5`: identical sizes, so ties keep glob order.
- `work_case`: already padded (40/10/10/0); `w2`/`w3` tie.
- `t1-held t2-held t3-queued`: already 147 147 123.
- refusal cases (`h1`, `h2`), `c5-nofloor` and the HARNESS-094 cases: nothing
  runs concurrently, or one suite.

### What GREEN must build (Contract C-1 to C-3; nothing is amended)

- **C-1.** On the concurrent path only, start suites in descending order of
  `wc -c` of `.claude/tests/<name>.test.sh`; equal sizes keep glob order; a
  size that cannot be read counts as 0. Sizes read once, before the first
  start, in a bounded number of processes (one `wc -c` over all selected
  files). Keep `suite_status() { wait "$1"; }` on one line, the slot refill
  on any exit, the poll delays.
- **C-2.** `NAMES`/`PIDS`/`RCS`/`STARTERR` stay indexed by glob position. The
  scheduler keeps its own start order; the print loop walks glob indices and
  stops at the first index with neither a collected status nor a start error,
  whether or not it has started. (Today's `while [ "$i" -lt "$started" ]`
  collect loop and `while [ "$printed" -lt "$started" ]` print loop both
  assume "started" is a glob prefix; both have to change.)
- **C-3.** `selftest_exit`: "started" means `start_suite` was entered for it.
  Today it treats every index below `${#PIDS[@]}` as started. In AC-4's run
  under C-1, `start_suite` has set `PIDS[3]` and `PIDS[2]` (`s4-most`,
  `s3-more`); bash's `${#PIDS[@]}` counts set elements, so it is 2, and the
  handler as written would treat indices 0 and 1 (`s1-least`, `s2-less`) as
  started and name `s3-more s4-most` never started - exactly reversed. The
  handler prints started suites' blocks in glob
  order, names unprintable started ones under `selftest: unreported:`, and
  every never-entered one under `selftest: never started:`, both in glob
  order. AC-4 pins the whole tail:

      (empty line)
      selftest: ended before its summary: 2 of 4 suite(s) reported (status 143).
      selftest: never started: s1-least s2-less

  The `N of M reported` count is the printed blocks (2), M the selected
  suites (4). Wording of every line unchanged; `SELFTEST_FAIL_START`
  unchanged (the existing `g` and R-1 `h` cases pin it, now padded).
- The one-at-a-time path is untouched (AC-5).

Not constrained by the tests: how the order is held (an array of glob
indices, a sorted list), how sizes are parsed out of `wc -c`, where the
sort happens, the 0-for-unreadable mechanism (no case makes a size
unreadable; it is in C-1 only), and the header comment wording (C-4).

### Export shape

No module is imported. The tests drive `scripts/selftest.sh` as a command:
`SELFTEST_JOBS=<n>` (or unset), `VERBOSE=` empty, `SELFTEST_FAIL_START`
(existing). They read stdout, stderr and exit status, and the files the held
suites write. No new environment variable, flag or output line is expected.

### Expected values of the controls

The suite did not fail at import: every assertion ran in RED, against the
shipped (glob-order) `selftest.sh`. So the "measured" column is a real run,
local, Windows host.

| Control | Expected after GREEN | Measured in RED |
|---|---|---|
| AC-1 control, first pair | `s1-least saw [] s2-less saw []` | the same (passed) |
| AC-1 control, third | `s1-least s2-less` | the same (passed) |
| AC-1 control, last | `s1-least s2-less s3-more` | the same (passed) |
| AC-1 control sizes | `down` (568 429 329 267) | `down` |
| AC-1 reversed sizes | `up` (268 329 429 567) | `up` |
| AC-2 ties sizes | `equal` (265 x4) | `equal` |
| AC-3 status, JOBS=1 vs 2 | `jobs1=1 jobs2=1` | the same (passed) |
| AC-5 start order, unset and 1 | `s1-least s2-less s3-more s4-most` | the same (passed) |
| DV-1 (GATES), glob order put back | AC-1's three assertions red, AC-1 control and AC-3 byte comparison green; also AC-3's precondition and AC-4's four red (this RED run is that state) | not runnable in RED: the size ordering does not exist yet |

### Timings

All local, this Windows host: the whole suite 7 to 23 minutes. New cases add
no hold that waits on a timeout in a correct run; each bounded hold is
BOUND=60 / LONELY=30, as the HARNESS-090 cases use. Nothing here comes from
CI.

### Deferred verifications

DV-1 and DV-2 are GATES's. I cannot run DV-1: it mutates the size ordering,
which does not exist until GREEN. I cannot run DV-2: it needs the finished
workflow file on a pushed branch.

### Files touched

- `.claude/tests/selftest.test.sh` - `h_rank`, the `held` comment, the C-5
  paddings and their 7 preconditions, the HARNESS-125 block (`SEEN_REC`,
  `h_besides`, `h_seen`, `h_order`, `order_fixture`, AC-1 to AC-5).
- `.claude/tests/floors.conf` - selftest 357 -> 404, with a note at the foot.
- `.claude/tests/floors.test.sh` - the COUNTS row `selftest 404`.
- This story: `## Test plan`, this handoff.

### Floor

selftest 404 (357 + 47: 7 C-5 preconditions, 40 AC-1..AC-5). Until GREEN
lands, `selftest.sh` reads 396 passes and the suite sits 8 below its floor -
expected in RED.

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

## Diff review

### Round 1

Reviewer: fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved
Fable 5.2 (`claude-fable-5-2`), 2026-11-26; no override. No file in the
worktree was changed. Experiments ran on a scratch copy of `scripts/` in the
reviewer's scratchpad.

What this change does: when the self-test runs several suites at once, it now
starts the largest suite files first (one `wc -c` over all selected files, a
stable sort, a separate start-order list) while still printing blocks in
file-name order. The exit handler decides "started" per suite instead of by
position. CI's `Harness self-test` step runs four suites at a time, and both
workflows cancel a pull request's older run when a new push arrives.

Load assumed: 36 suites, `SELFTEST_JOBS=4` on a hosted runner, and the
Windows host at 1 to 4 jobs.

Checked and found sound:

- **Size read.** One subshell and one `wc`, whatever the suite count. On Git
  Bash a scratch fixture with suites named `a b`, `-dash`, `c[1]`, `e`,
  `total` and a directory `zdir.test.sh` started at `SELFTEST_JOBS=2` in the
  order `total e c[1] -dash "a b"`, then zdir (size 0, last), and printed in
  glob order. The `--` guards the leading dash, the match is a literal string
  compare, wc's `total` line cannot equal a `*.test.sh` name, right-aligned
  padding is trimmed, a CR is stripped, and `wc -c` prints plain digits in any
  locale. `set -e` is not on, so wc's non-zero exit on an unreadable file does
  nothing.
- **Collect loop.** A pid is non-empty only between a successful start and its
  collection, and is emptied in the same step that collects it, so walking
  `printed..NSUITES` can neither skip nor double-collect.
- **EXIT handler.** TERM at 3 s on five reversed-size suites with
  `SELFTEST_FAIL_START` naming the largest gave: blocks r3, r4, then r5's
  `not started: fork: simulated`, `3 of 5 suite(s) reported (status 143)`,
  `never started: r1 r2`, buffer directory removed. A signal before
  `PIDS[$1]=""` lists the suite as never started; one between that line and
  the fork lists it as unreported and keeps the buffers, as HARNESS-090 did.
- **`SELFTEST_FAIL_START`.** A failed start takes a position in the start
  order and no slot; its block prints at its glob position. Unchanged.
- **Other callers.** Nothing else reads `${#PIDS[@]}`. `--changed` reaches the
  same scheduler. No document still says CI leaves the variable unset.
- **AC-6: holds.** `floors.conf` changes one floor, 357 to 404 (up). Every
  removed line of `selftest.test.sh` (24 `held` lines across the b, c, e, k,
  g, d, h fixtures) returns identical with only `PAD=<n>` added.
- **AC-7: holds as text.** Both `concurrency:` blocks and the step-level
  `env:` match C-4 character for character; the `run:` line is still
  `bash scripts/selftest.sh`; the colour-forced step is not in the diff;
  everything else changed in the two files is comment.

**Should fix:**

1. **The tie rule has never been seen to fail** (`.claude/tests/selftest.test.sh:1889-1915`, `scripts/selftest.sh:699`)
   - **What this is:** AC-2's three assertions that equal-sized suites start in file-name order, and the `-lt` in the sort that makes it so.
   - **Problem:** Those assertions passed in RED and pass now, and DV-1 leaves them green. The RED handoff assigned a tie-break mutation to GATES; none is recorded. On a scratch copy, `-lt` to `-le` started four equal suites as `t4 t3 t2 t1`.
   - **Fix:** Run one mutation and paste its output in the story: `bash scripts/mutate.sh scripts/selftest.sh 's/-lt "\${SIZES\[\$i\]}" \]; do/-le "${SIZES[$i]}" ]; do/' -- bash .claude/tests/selftest.test.sh`. AC-2's three start-order assertions must go red. No test or source file changes.
   - **If we skip it:** AC-2 rests on assertions nobody has seen red.
   - **Route:** GATES

2. **"An unreadable size counts as 0" has no test** (`scripts/selftest.sh:669-692`)
   - **What this is:** The C-1 clause that a suite whose size wc cannot give starts last and is not an error.
   - **Problem:** No case makes a size unreadable. If the `SIZES[$i]=0` default were dropped, the sort would hit an unset variable under `set -u` and the run would end in the exit handler with no summary. Seen to work by hand (a directory `zdir.test.sh` read as 0 and started last), but nothing in the suite would notice it break.
   - **Fix:** One case in `.claude/tests/selftest.test.sh` with a selected `*.test.sh` wc gives no size for, asserting it starts last and the run still prints its summary; earn it with one mutation; raise the floor in `.claude/tests/floors.conf` and the row in `.claude/tests/floors.test.sh`.
   - **If we skip it:** A contract clause ships unpinned. Low stakes: a suite file that cannot be read fails its own run anyway.
   - **Route:** RED

**Nice to have:**

3. **Manual and scheduled runs on one branch now queue, and a third cancels the waiting second** (`.github/workflows/gates.yml:32-34`)
   - **What this is:** The `concurrency` group for non-PR runs, which falls back to the branch name.
   - **Problem:** With `cancel-in-progress: false`, GitHub keeps one running and one pending run per group, and a newer pending run cancels the older pending one. Case: the Monday scheduled run is in progress; two `workflow_dispatch` runs on `main` start; the first of them is cancelled without running. Before this change all three ran side by side.
   - **Fix:** C-4's exact text, which AC-7 requires, so it is a question about AC-7: accept it and say so in the comment, or use `github.run_id` as the fallback so non-PR runs never share a group.
   - **If we skip it:** A manual run started twice in quick succession on one branch loses its first copy. Rare, and nothing wrong is reported as right.
   - **Route:** AMEND

Not checked by the reviewer: the runner's vCPU count (hosted runners give 4
to public repositories, 2 to private), a Linux `wc` (read only from DV-2's
passing run), and `concurrency` on a live second push.

Verdict: Ship.

**Orchestrator's disposition, round 1:**

- Labels checked with `classify.sh`: finding 1's Fix names only
  `docs/backlog/stories/HARNESS-125.md` (`docs`) and a mutate.sh run, so
  GATES is followable; finding 2 names `.claude/tests/selftest.test.sh`
  (`harness`, a test file); finding 3 names AC-7. All three labels stand.
- **Finding 1: done in GATES**, result pasted under `## Deferred
  verifications` as DV-3. No file changed, so the tree and the gate record
  are unchanged and the review need not be re-run.
- **Finding 2: declined in this story.** It is a Should-fix, the verdict is
  Ship, the reviewer saw the clause hold by hand, and a return to RED costs a
  full cycle for a clause whose failure is loud (the run ends without a
  summary, which fails CI). Left for a story of its own.
- **Finding 3: declined, AC-7 unchanged.** A Nice-to-have; the only lost run
  is a pending duplicate on one branch, and changing it means amending AC-7.
  Reported to the user, who may ask for the `github.run_id` fallback as its
  own story.
- **Runner vCPUs:** the repository is `PUBLIC`
  (`gh repo view --json visibility`), so `ubuntu-latest` gives it 4 vCPUs;
  the value of C-4 stands.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-26T21:56:31Z
    commit: 680f6ae
    tree:   f123d67a201e75657645458651029238d3c1ff39
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

### GREEN

Feature Developer, dispatched as `opus`; ran as Claude Opus 5.5
(`claude-opus-5-5`), no override.

What was built:

- `scripts/selftest.sh`, concurrent path only (C-1, C-2). After `NAMES` is
  built, one `wc -c -- <every selected file>` runs inside a `cd` to the tests
  directory, so there is one subshell and one `wc` whatever the suite count.
  Its lines are matched back to glob indices by file name into `SIZES`,
  which starts every suite at 0. A file wc cannot read prints no line and
  stays 0, and the `total` line matches no file. `ORDER`, a list of glob
  indices, comes from a stable insertion sort: a suite moves ahead only of
  a strictly smaller one, so ties keep glob order. The scheduler starts
  `ORDER[$started]`. The collect loop now walks glob indices from `printed`
  to `NSUITES`. The print loop walks glob indices to `NSUITES` and stops at
  the first one with neither a collected status nor a start error.
  `suite_status() { wait "$1"; }` is still on one line, and the poll delays
  and slot refill are unchanged.
- `selftest_exit` (C-3). "Started" now means `${PIDS[$i]+set}`.
  `start_suite` now sets `PIDS[$1]=""` as its first act, before its
  `local`s. The handler walks every glob index below `NSUITES`. A suite
  `start_suite` was never entered for goes on the `never started:` list.
  The other suites are judged as before: a start error, a printable block,
  or `unreported`. Both lists come out in glob order, and every printed
  wording is unchanged.
- The header comment (C-4). "CI leaves it unset" and "Suites start in suite
  order, so the slowest one (phase-guard) still sets the floor" are
  replaced: CI's `Harness self-test` step sets 4, and the colour-forced
  step and ci-local's replay leave it unset. The concurrent path starts
  largest file first, and one at a time is unchanged. The comments on the
  EXIT handler and the concurrent loop are updated to match.
- The workflows (C-4). `gates.yml` gets the `concurrency:` block after `on:`
  and `env: SELFTEST_JOBS: 4` on `Harness self-test`, with its `run:`
  still `bash scripts/selftest.sh`. `boundaries.yml` gets its `concurrency:`
  block. Apart from that, both files change only in comments. The
  colour-forced step is untouched.
- The one-at-a-time path is not touched.

Controls confirmed against the shipped code:

- I regenerated the fixtures in a scratch directory with the test file's
  own `held()`, extracted with awk, and measured them with `wc -c`. They
  match RED's numbers exactly:
  - AC-1 control: 568 429 329 267 (`down`).
  - AC-1 reversed: 268 329 429 567 (`up`).
  - AC-2 ties: 265 x4 (`equal`).
  - AC-3 extras: s5-exits3 741, larger than every s1..s4, and s6-short 230.
- `selftest.test.sh` on the final tree: 404 passed, 0 failed. So every
  control in the handoff's table held at its recorded expected value:
  - AC-1 control: first pair `s1-least saw [] s2-less saw []`, third
    `s1-least s2-less`, last `s1-least s2-less s3-more`.
  - AC-2 ties: in glob order.
  - AC-3: `jobs1=1 jobs2=1`, and the stdout and stderr byte comparisons
    pass.
  - AC-5: start order `s1-least s2-less s3-more s4-most` for both unset
    and 1.
  - The 8 RED failures (AC-1 x3, the AC-3 precondition, AC-4 x4) all pass.
    AC-4's tail is exactly `2 of 4 suite(s) reported (status 143)` /
    `never started: s1-least s2-less`.
- The handoff's claim about today's handler holds. In bash, with
  `PIDS[3]=""; PIDS[2]=""`, `${#PIDS[@]}` is 2, and
  `${PIDS[0]+set}`/`${PIDS[1]+set}` are empty while `[2]`/`[3]` are `set`.
  So the old bound (index < 2 means started) would have named indices 0
  and 1 as started, the reverse of the truth. The new handler reads the
  set element instead.
- `bash scripts/ci-local.sh --dry-run`: I captured the output before the
  workflow edits and again after, and `cmp` says the two are identical
  (AC-7's dry-run clause).
- DV-1 and DV-2 are not run here; GATES owns them. For DV-1, a single
  expression that puts glob order back is `s/start_suite "\${ORDER\[\$started\]}"/start_suite "$started"/`
  on `scripts/selftest.sh`. It starts glob index `$started` again, while
  the print, collect and handler changes stay in.

