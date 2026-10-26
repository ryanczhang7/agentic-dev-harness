---
id: HARNESS-073
title: CI runs each tree guard once, inside the self-test
slug: ci-runs-each-tree-guard-once-inside-the
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-073-ci-runs-each-tree-guard-once-inside-the
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.github/workflows/gates.yml, scripts/doctor.sh, .claude/tests/doctor.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/grep-count.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

`.github/workflows/gates.yml` runs, on every pull request: `bash
scripts/selftest.sh` (about 200 s on ubuntu-latest for HARNESS-067..071),
then `bash scripts/check-sigpipe.sh` (about 4.5 s), `bash
scripts/check-grep-count.sh` (about 4.8 s), `gates.sh --list`, `--audit` and
`gates.sh`. The two guard steps were added in releases 36 and 37 with the
comment that the SIGPIPE guard "belongs in CI rather than the self-test"
because the defect it hunts is a race that shows on the runner and not on a
Windows checkout.

**PO decision 2 - the two steps are duplicates in verdict, checked rather than
assumed (2026-10-23).** What each side judges:

- The CI step runs `bash scripts/check-sigpipe.sh` with no pathspec from the
  checkout root; the guard enumerates `harness_shell_files` through
  `classify.sh --list harness` over the whole tree, prints one line per
  finding plus a census line, and exits 1 on any finding, 0 otherwise
  (`check-sigpipe.sh:442-443`). `check-grep-count.sh` has the same shape.
- `sigpipe.test.sh` runs `run_guard "$REPO_ROOT"` (line 497): `cd` to the
  checkout root, the same script, no pathspec - the same population - and
  asserts the census names exactly the files `classify.sh` lists (C-3), that
  the finding count in that census is **0** (added in release 37 for exactly
  this reason: "a new instance in this tree would pass selftest and be caught
  only by the CI step"), and that the guard exits **0** against the tree.
  `grep-count.test.sh` runs `run_guard "$REPO_ROOT"` (line 272) and asserts
  the census line is present, the finding count is 0 and the exit is 0
  (AC-4), with the two live `|| true` instances counted so the clean result
  is not vacuous.
- Both guards are static scans of the files' text. The runner matters for the
  *defect* (a pipe-buffer race at run time), not for the *guard*, and the
  self-test step runs on the same ubuntu-latest runner in the same job as the
  guard steps, so both sides read the same tree with the same tool.

So a finding in the tree fails the self-test step before the guard step is
reached, and no outcome of the guard step can differ from the suite's
verdict. Two things the steps have that the suite assertions do not, and both
are kept rather than lost:

- **Legibility.** The step prints the guard's findings as the step's own
  failure. The suite's `assert_eq "...finding count in that census is zero"`
  prints `expected: 0 / actual: N` and nothing about which line. AC-3 makes
  the suite print the findings on that failure.
- **A project whose CI does not run the self-test.** `doctor.sh`'s want-list
  (line 180) names both guards so a consuming project hears when a workflow
  lacks them; it also names `selftest.sh`, and once the self-test carries the
  guards' verdict the want-list entries for the guards are the duplicate at
  the next level. AC-2 drops them from the want-list; `selftest.sh`,
  `gates.sh` and `check-boundaries.sh` stay.

**What this saves, honestly.** About 9 s of a 205-223 s job on ubuntu-latest,
which crosses no billed-minute boundary at today's duration. The saving that
matters is for a consuming project whose `gates` job is `windows-latest`,
where process spawn is about 40x slower (`gates.yml` header); unmeasured, and
`.github/workflows/**` is project-owned, so a refresh cannot remove the steps
there - the project does it by hand, and `doctor.sh` no longer tells it to
keep them. The other gain is one verdict in one place instead of two
reporting sites for the same fact.

**Pinned line numbers nearby.** `sigpipe.test.sh`'s C-5 freshness list pins
`scripts/doctor.sh:68` and `:140` by content; the want-list edit at line 180
is below both and must not shift them. `gates.yml` is not pinned by line
anywhere; `ci-local.test.sh` derives its step list from the workflow files,
so removing a step from `gates.yml` removes it from `ci-local.sh`'s run
without any change to either (`ci-local.sh --dry-run` shows the result).
`doctor.test.sh:212-240` pins the want-list and inverts under AC-2.

The required gate that fails if this story's artifact breaks: the self-test
(`doctor`, `sigpipe`, `grep-count` suites), run by CI on every pull request.

## Acceptance criteria

- **AC-1** — Given this repository, when `bash scripts/ci-local.sh --dry-run`
  runs, then its output lists neither `bash scripts/check-sigpipe.sh` nor
  `bash scripts/check-grep-count.sh`, and still lists `bash
  scripts/selftest.sh`, `bash scripts/gates.sh --list`, `bash scripts/gates.sh
  --audit`, `bash scripts/gates.sh` and the boundaries check, in that order.
  (Verified by the pasted `--dry-run` output in `## Gate probes`, not by a
  suite: `ci-local.test.sh` is deliberately project-agnostic, and an exact
  step list would fail in every consuming project.)
- **AC-2** — Given a fixture whose workflows run `scripts/selftest.sh`,
  `scripts/gates.sh` and `scripts/check-boundaries.sh` and neither guard,
  when `bash scripts/doctor.sh` runs, then the CI block prints
  `ok       ci           runs the self-test, the gates and the boundaries check`
  and no `MISSING  ci` line, and doctor's exit status is 0 (today: two
  `MISSING` lines and exit 1).
  *Controls:* the same fixture without `scripts/selftest.sh` in any workflow
  prints `MISSING  ci           no workflow runs scripts/selftest.sh` and
  exits 1; without `scripts/check-boundaries.sh`, the matching line, exit 1.
- **AC-3** — Given the real-tree run in `sigpipe.test.sh` (C-3) reports one
  or more findings, when the "finding count in that census is zero" assertion
  fails, then its failure detail contains every finding line the guard printed
  (`<path>:<line>: pipeline into an early-exit reader ...`), so the reader
  learns the file and line from the suite output alone. The same for
  `grep-count.test.sh`'s AC-4 finding-count assertion. *Control:* with no
  findings, the assertions pass and print nothing (unchanged).
  *How it is seen to work:* only by planting a finding in a real line of the
  tree and running the one suite - DV-1 below owns it; RED cannot make the
  real tree carry a finding.
- **AC-4** — Given `gates.yml` after this story, when it is read, then it has
  no `run:` step for either guard, and the comment above the self-test step
  says that the two guards run inside it (`sigpipe` C-3 and `grep-count` AC-4
  assert zero findings over the checkout) - the comment that said the SIGPIPE
  guard belongs in CI rather than the self-test is gone. Reviewed at REVIEW;
  the step list itself is AC-1.

## Contract

**Writes:** `.github/workflows/gates.yml`, `scripts/doctor.sh`, `.claude/tests/doctor.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/grep-count.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Oracle partition.** AC-1, AC-2, AC-4 *mechanical* - pin the exact lines.
AC-3 *mechanical* in shape, but its only honest run is the mutation in DV-1.

**doctor.sh (settled).** Line 180's list becomes
`for want in selftest.sh gates.sh check-boundaries.sh; do`. The `ok` line
reads `runs the self-test, the gates and the boundaries check`; the three
`MISSING` explanation lines are unchanged. No other edit to `doctor.sh`; in
particular nothing above line 140 moves (sigpipe C-5 pins `doctor.sh:68` and
`:140` by content).

**doctor.test.sh.** The case at lines 212-240 inverts: the set
`selftest.sh + gates.sh + check-boundaries.sh` is complete (AC-2), and the
guard-bearing set is still `ok` (a workflow may run more than doctor asks
for). AC-2's two controls are new cases. The comment that says the guards
"joined the want-list in release 36/37" is rewritten to say they left it here
and why (the self-test carries their verdict).

**sigpipe.test.sh / grep-count.test.sh (AC-3).** The real-tree finding-count
assertion becomes an `if/else` with `_ok` / `_bad`, where `_bad`'s detail is
the guard's finding lines - `awk 'index($0, "check-sigpipe: ") != 1' <<<
"$REAL_OUT"` or equivalent - so the count of executed assertions does not
change. No other assertion in either suite moves; the C-3 census and C-5
freshness assertions are untouched.

**gates.yml.** The two `- name:` / `run:` blocks for the guards are removed
with their comments; the self-test step's comment gains the sentence in AC-4.
The header's cost paragraph stays as measured (release 42) - do not invent a
new number; `## Notes` may record the first post-merge CI duration.

**Callers of the removed steps.** `ci-local.sh` (derives: no change),
`ci-local.test.sh` (derives from the workflow files: no change; its fixture
workflows never carried the guards), `doctor.sh:180` (this story),
`doctor.test.sh:212-240` (this story), `CLAUDE.md` "Running things" (lists
the two commands as commands: unchanged), the audit docs that mention the
steps (history: unchanged).

**Floors.** `doctor` 61, `sigpipe` 91, `grep-count` 38 today. RED records the
executed counts it measures in both files.

## Deferred verifications

**DV-1 (defect put back; the story's central claim, and the probe against a
real line of the tree). Owner: GATES.** Plant one finding in a real harness
shell file and run the one suite:
`bash scripts/mutate.sh scripts/plan.sh 's/grep -c \(.*\) || true/grep -c \1 || printf 0/' -- bash scripts/selftest.sh grep-count`
(the two `|| true` instances `grep-count.test.sh` counts are in `plan.sh` and
`check-boundaries.sh`; pick one line, name it). The suite **must** go red on
the AC-4 finding-count assertion, and the failure detail **must** contain the
`scripts/plan.sh:<line>:` finding line (AC-3). Then the same for
`check-sigpipe.sh`: mutate a real line into the class it refuses (a
`| grep -q` as a function's last command under pipefail, e.g. in
`scripts/gates.sh`, naming the line) and run `bash scripts/selftest.sh
sigpipe`: red on C-3's finding count, detail carries the `<file>:<line>:`
line. Paste both suites' red lines and `mutate.sh`'s restore lines. This is
the evidence that dropping the CI steps dropped no check: the self-test fails
on the same tree the steps would have failed on.

**DV-2 (the step list). Owner: GATES.** Paste `bash scripts/ci-local.sh
--dry-run` on the story branch into `## Gate probes` (AC-1), and the `ok ci`
line of `bash scripts/doctor.sh` run on this repository.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-073` from `.claude/harness/models.conf`.
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

- PLANNED — `lead-po` — resolved: **fable** (Fable 5.1, the agent's own `model:`; the dispatching session attributes its commits to Opus 5.5 and passed no model override that this dispatch could see). Verdict on the plan: n/a - no row departed from `models.conf`.
## Out of scope

- Removing the guard steps from any consuming project's workflow
  (`.github/workflows/**` is project-owned; `refresh-harness.sh` never
  touches it). The user may do that by hand in manga-translator,
  fantasy-world-builder and clean_calendar once this merges; `doctor.sh`
  will then stop asking for them.
- Deleting `scripts/check-sigpipe.sh` or `scripts/check-grep-count.sh`, or
  their `CLAUDE.md` entries: they remain the commands a person runs, and the
  suites run them.
- The colour-forced self-test step and the `on:` triggers in `gates.yml`.
- Dropping the suites' real-tree runs instead (the other half of the user's
  "or"): they run in every consuming project's self-test, carry C-3's census
  check, and are the stronger of the two sides. Decided above.
- `SELFTEST_JOBS` anywhere - HARNESS-072; host-load detection - HARNESS-074.

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


- Planned 2026-10-23 as one of three from a single request ("SELFTEST_JOBS=4
  in the self-test step, drop the duplicate guard CI steps, warn when other
  test runs share the host"). Split because each is its own behaviour with
  its own test, and together they would touch ten files across three
  mechanisms. Their footprints are disjoint except `floors.conf` and
  `selftest.test.sh` (each adds or raises a floor, recorded twice), so
  `plan.sh conflicts` reports every pair as CONFLICT on those two files and
  `plan.sh waves` places them in three waves: 072, then 073, then 074. Run
  them one after another; 072 first, because it makes every later full
  self-test on this host cheaper.
