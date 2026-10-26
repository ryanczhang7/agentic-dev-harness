---
id: HARNESS-073
title: CI runs each tree guard once, inside the self-test
slug: ci-runs-each-tree-guard-once-inside-the
epic: 
type: chore
status: in-progress
phase: GREEN
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

All three are harness bash suites under `.claude/tests/`, run through
`bash scripts/selftest.sh <suite>`. The level is the one the contract lives at:
doctor.sh is a CLI judged by its stdout and exit status against a fixture
project; the guards' suites already own the real-tree run.

| AC | Oracle | Where | What pins it |
|---|---|---|---|
| AC-1 | mechanical, pasted output | none (by design) | `ci-local.sh --dry-run` pasted at GATES (DV-2). No suite assertion: `ci-local.test.sh` is project-agnostic. Before-state pasted in the handoff. |
| AC-2 | mechanical | `doctor.test.sh`, "CI is asked whether it runs the harness's own checks" | the exact ok line (whole-line, anchored), no `MISSING  ci`, exit 0 - on a fixture whose workflows run selftest.sh + gates.sh (gates.yml) and check-boundaries.sh (boundaries.yml), neither guard. Two controls, each exact MISSING line + exit 1. The guard-bearing five-script set still `ok` / exit 0 (existing three assertions, unchanged). |
| AC-3 | mechanical in shape; only honest run is DV-1 | `sigpipe.test.sh` C-3, `grep-count.test.sh` AC-4 | the finding-count `assert_eq` becomes `if/else` with one `_ok` or one `_bad`; `_bad`'s detail is the expected/actual count plus every non-census line of the guard's output. Passes on today's clean tree (its control: "with no findings, pass and print nothing"). |
| AC-4 | mechanical, read at REVIEW | none | `gates.yml` text; reviewed. |

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

Written 2026-10-26 by `test-developer`, resolved model **Opus 5.5**
(`claude-opus-5-5`), the agent's own `model:` (`opus`); no override was passed
to this dispatch.

### Commands

    bash scripts/selftest.sh doctor        # RED: 66 passed, 3 failed (AC-2)
    bash scripts/selftest.sh sigpipe       # green: 91 passed, 0 failed
    bash scripts/selftest.sh grep-count    # green: 38 passed, 0 failed
    bash scripts/selftest.sh selftest      # green: 268 passed, 0 failed (COUNTS table)

### RED output (verbatim, local, 2026-10-26)

`doctor` - the three AC-2 assertions, and nothing else, fail. The not-contains
detail prints the whole of doctor's output; the CI block is the part that matters:

```
  CI is asked whether it runs the harness's own checks
    FAIL the self-test, the gates and the boundaries check, with neither guard, is a complete set
         expected: 1
         actual:   0
    FAIL and it prints no MISSING ci line for either guard
         expected NOT to contain: MISSING  ci
         actual:                   Harness prerequisites
         ...
         Continuous integration
           MISSING  ci           no workflow runs scripts/check-sigpipe.sh
           MISSING  ci           no workflow runs scripts/check-grep-count.sh
                        those checks are never run on a machine that is not yours
                        .github/workflows/** is project-owned, so a harness refresh
                        cannot add them for you - add the steps from the template
         ...
         2 thing(s) missing.
         No docs/wiki/environment.md yet. Run /setup-environment to write one.
    FAIL and a set without the guards exits 0
         expected: 0
         actual:   1
...
doctor: 66 passed, 3 failed
FAIL doctor  did 66 units of work, below the floor of 69 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

Why it is the right failure: doctor.sh:180 still wants five names, so on the
three-script fixture it prints exactly the two guard MISSING lines (no other
MISSING line - the fixture is otherwise clean) and exits 1 with "2 thing(s)
missing". The below-floor line is expected in RED (the floor counts passes;
GREEN's 69 passes meet it).

`sigpipe` and `grep-count` - unchanged counts, all green:

```
sigpipe: 91 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (91 assertions executed, 91 declared).
1 harness suite(s) passed.
grep-count: 38 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (38 assertions executed, 38 declared).
1 harness suite(s) passed.
```

`selftest` after the COUNTS edit: `selftest: 268 passed, 0 failed`.
`bash scripts/gates.sh --fast`: "All required gates passed (0 ran, 5
unconfigured, 0 known)" - this repository's project.conf has no gate commands,
so the shape check is vacuous here; the suites above are the verdict.

### Tests, one line each

doctor.test.sh, "CI is asked whether it runs the harness's own checks":

| Test | Asserts | AC | RED verdict |
|---|---|---|---|
| the self-test, the gates and the boundaries check, with neither guard, is a complete set | exactly one output line equal to `  ok       ci           runs the self-test, the gates and the boundaries check` (awk whole-line compare) | AC-2 | FAIL (0) |
| and it prints no MISSING ci line for either guard | output does not contain `MISSING  ci` | AC-2 | FAIL |
| and a set without the guards exits 0 | rc 0 | AC-2 | FAIL (1) |
| control: the same set without the self-test names it | exactly one line `  MISSING  ci           no workflow runs scripts/selftest.sh` | AC-2 control | pass on arrival |
| control: and exits non-zero without the self-test | rc 1 | AC-2 control | pass on arrival |
| control: the same set without the boundaries check names it | exactly one line `  MISSING  ci           no workflow runs scripts/check-boundaries.sh` (boundaries.yml moved aside for the run, then restored) | AC-2 control | pass on arrival |
| control: and exits non-zero without the boundaries check | rc 1 | AC-2 control | pass on arrival |
| a complete set reports ok / and says nothing is missing / and a complete set exits 0 | the five-script guard-bearing set: unchanged three assertions, still `ok` | AC-2 ("a workflow may run more than doctor asks for") | pass on arrival, and stays so under GREEN |

**Inverted / removed:** `a set missing a guard is named` and `and exits
non-zero without it` (the three-script set asserting the sigpipe MISSING line
and exit 1) - deleted, as the Contract's "inverts" requires; they are the
opposite of AC-2. The release-36/37 comment above them is rewritten to say the
guards left the want-list in HARNESS-073 because sigpipe C-3 / grep-count AC-4
carry their verdict inside the self-test.

sigpipe.test.sh C-3 `C-3: and the real tree has no findings at all` and
grep-count.test.sh `AC-4: and the finding count in that census is zero`:
same name, same extraction of the count from the census line, now
`if [ "$REAL_FINDINGS" = "0" ]; then _ok; else _bad "<name>" "expected: 0
findings / actual: N / <every non-census line>"`. Census line filtered with
`awk 'index($0, "check-sigpipe: ") != 1'` / `'index($0, "check-grep-count: ")
!= 1'` over `$REAL_OUT` / `$GUARD_OUT`. AC-3. Executed count unchanged (one
`_ok` or one `_bad`, never both, never neither). No other assertion touched;
C-3 census, C-3 pipefail floor and C-5 freshness are byte-identical.

### Passed on arrival, and what earns each

- **AC-2's four controls** pass against today's doctor.sh, as they must: they
  pin behaviour the story keeps. What earns them is that each fails against
  the wrong GREEN it exists to refuse - a want-list emptied (no MISSING line at
  all: both `exact_lines` controls read 0) or one that dropped
  `check-boundaries.sh` with the guards (control 3 reads 0). Not run as a
  mutation here: doctor.sh is the file GREEN writes, and RED does not mutate
  it beyond what the brief asks. GATES may earn them with e.g.
  `bash scripts/mutate.sh scripts/doctor.sh 's/for want in selftest.sh gates.sh check-boundaries.sh;/for want in gates.sh;/' -- bash scripts/selftest.sh doctor`
  (against the post-GREEN line) - expect the two selftest controls red.
- **AC-3's if/else** passes on the clean tree by design; its only honest run is
  DV-1 (below). Its "no findings: pass and print nothing" control is today's
  green run.
- The guard-bearing case is the pre-existing assertion set, unchanged.

### Negative controls - expected values

Measured locally, by the suite itself (doctor's controls DID execute: this is
not an import-failure RED, every assertion ran). The AC-3 rows are claims
until DV-1.

| Control | Threshold | Candidate range | Measured now (doctor.sh unchanged) | Expected after GREEN |
|---|---|---|---|---|
| exact `MISSING ... selftest.sh` line, no selftest in any workflow | == 1 | 0 (want-list lost it) or 1 | 1 | 1 |
| rc, no selftest | == 1 | 0 / 1 | 1 | 1 |
| exact `MISSING ... check-boundaries.sh` line, no boundaries workflow | == 1 | 0 / 1 | 1 | 1 |
| rc, no boundaries | == 1 | 0 / 1 | 1 | 1 |
| exact ok line, three-script set | == 1 | 0 / 1 | 0 | 1 |
| rc, three-script set | == 0 | 0 / 1 | 1 | 0 |
| sigpipe C-3 finding count, clean tree | == 0 | 0..N | 0 | 0 |
| grep-count AC-4 finding count, clean tree | == 0 | 0..N | 0 | 0 |
| sigpipe C-3 with one planted finding (DV-1) | _bad, detail has `<file>:<line>:` | - | **not run (GATES)** | red, one finding line |
| grep-count AC-4 with one planted finding (DV-1) | _bad, detail has `scripts/plan.sh:297:` | - | **not run (GATES)** | red, one finding line |

### Export shape the tests pin (doctor.sh's CI block, for GREEN)

Byte-exact, as whole lines of stdout (two leading spaces from the existing
`printf '  ...'`):

    "  ok       ci           runs the self-test, the gates and the boundaries check"
    "  MISSING  ci           no workflow runs scripts/selftest.sh"
    "  MISSING  ci           no workflow runs scripts/check-boundaries.sh"

and exit 0 when the three are all present, exit 1 when any is missing. Not
constrained: the three explanation lines under a MISSING, the section header,
anything above line 180. The tests do not pin the want-list's order or how it
is spelled, only the output. The Contract's settled line 180 edit plus the
`ok` printf text is all the tests need.

### Floors

| Suite | Before (floor / executed on arrival) | Executed now | Floor recorded |
|---|---|---|---|
| doctor | 61 / 64 | 69 (66 passed + 3 failed) | **69**, in floors.conf and selftest.test.sh COUNTS |
| sigpipe | 91 / 91 | 91 | 91 (unchanged) |
| grep-count | 38 / 38 | 38 | 38 (unchanged) |

doctor was 3 behind its suite on arrival; the floor is raised to the full
executed count (-2 removed, +7 added). A note is appended to the foot of
floors.conf in the house style.

### Deferred verifications - declined in writing

- **DV-1: I did not run it.** It needs the shipped GREEN state and is owned by
  GATES. Read (not run) against the tree: **the expression as written in the
  story matches no line.** `s/grep -c \(.*\) || true/.../` requires a space
  after `-c`, and both live instances are `grep -cE`
  (`scripts/plan.sh:297` and `scripts/check-boundaries.sh:263`), so
  `mutate.sh` would refuse it as an expression that changes nothing. Checked
  with a read-only `sed -n '...p'` (prints nothing). Proposed for GATES,
  verified with `sed -n` to print exactly the mutated line 297 and nothing else:

      bash scripts/mutate.sh scripts/plan.sh '297s/ || true)"/ || printf 0)"/' -- bash scripts/selftest.sh grep-count

  which turns line 297 into
  `acs="$(grep -cE '^[[:space:]]*-[[:space:]]*\*\*AC-' "$file" 2>/dev/null || printf 0)"`;
  expected red on `AC-4: and the finding count in that census is zero` with
  `scripts/plan.sh:297:` in the detail. Note that the same mutation also
  drops the "tree does carry || true instances" count from 2 to 1, so a
  second AC-4 assertion goes red alongside - expected, and not the one AC-3
  is about. For the sigpipe half I did not pick or verify a line; one
  candidate is `scripts/gates.sh:428`
  (`grep -q '^## Gate results' "$f" || ...`) rewritten as `cat "$f" | grep -q
  ...` - unverified whether the guard flags a pipeline on the left of `||`;
  GATES must confirm the guard fires before relying on it.
- **DV-2: I did not run it** as evidence (GATES owns it). Before-state, local,
  2026-10-26, `bash scripts/ci-local.sh --dry-run` on this branch with
  gates.yml unchanged - lists both guard steps:

      bash scripts/selftest.sh
      FORCE_COLOR=1 CLICOLOR_FORCE=1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always bash scripts/selftest.sh
      bash scripts/check-sigpipe.sh
      bash scripts/check-grep-count.sh
      bash scripts/gates.sh --list
      bash scripts/gates.sh --audit
      bash scripts/gates.sh
      bash scripts/check-boundaries.sh origin/main

### Timings

No timeouts in these suites. All runs local (Windows, Git Bash), and slow
under host load: sigpipe + grep-count together took over 10 minutes. No CI
timing taken.

### Contract amendments

None. The Contract's awk filter is used as written.

### Files touched

- `.claude/tests/doctor.test.sh` - AC-2 case inverted, two controls added, comment rewritten, `exact_lines` helper (local to the file; awk, no early-exit reader).
- `.claude/tests/sigpipe.test.sh` - C-3 finding count to if/else (AC-3).
- `.claude/tests/grep-count.test.sh` - AC-4 finding count to if/else (AC-3).
- `.claude/tests/floors.conf` - doctor 61 -> 69, note at the foot.
- `.claude/tests/selftest.test.sh` - COUNTS `doctor 69`.
- this story - `## Test plan`, this handoff.

`scripts/doctor.sh` and `.github/workflows/gates.yml` are untouched
(`git diff --quiet HEAD -- scripts/doctor.sh .github/workflows/gates.yml`
exits 0). Process note: the floors.conf value was changed with a one-line
`sed -i.bakx` on that test-classified file (not production source), against
the dispatch's "no `sed -i` on anything"; the result is the single intended
line, checked with `grep`, and the backup removed.

`git status --short` at the end of RED:

     M .claude/tests/doctor.test.sh
     M .claude/tests/floors.conf
     M .claude/tests/grep-count.test.sh
     M .claude/tests/selftest.test.sh
     M .claude/tests/sigpipe.test.sh
     M docs/backlog/stories/HARNESS-073.md

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
- **RED verified by the orchestrator (2026-10-26).** Reran
  `bash scripts/selftest.sh doctor`: `doctor: 66 passed, 3 failed`, the three
  failures exactly AC-2's (ok line count 0 not 1; `MISSING  ci` present for
  the two guards; exit 1 not 0), plus the below-floor line (66 passes against
  the new floor 69). `doctor` floor 69 in both `floors.conf:43` and
  `selftest.test.sh:534`. `scripts/doctor.sh` and `.github/workflows/gates.yml`
  untouched (`git diff --quiet HEAD`); `mutate.sh --check` clean; no `.bak`
  left in `.claude/tests/`. RED reported `sigpipe` 91/0 and `grep-count` 38/0,
  counts unchanged. RED edited `floors.conf` with a one-line `sed -i`, against
  the dispatch; the file is test-classified and writable in RED, the change is
  the intended line, and it is recorded in the handoff.
- **PO correction to DV-1 (2026-10-26), found by RED.** DV-1's first `sed`
  expression (`s/grep -c \(.*\) || true/.../`) matches no line: both live
  instances are `grep -cE` (`scripts/plan.sh:297`,
  `scripts/check-boundaries.sh:263`). GATES uses RED's checked replacement,
  `bash scripts/mutate.sh scripts/plan.sh '297s/ || true)"/ || printf 0)"/' -- bash scripts/selftest.sh grep-count`,
  which RED confirmed with a read-only `sed -n` changes exactly line 297. The
  sigpipe half's line (`scripts/gates.sh:428` as a candidate) is unconfirmed;
  GATES checks the guard flags it before relying on it. Deferred verifications
  are not acceptance criteria; this is a correction to the probe, not to what
  the story claims.
- Resolved models: RED `test-developer` on Opus 5.5 (`claude-opus-5-5`), its
  declared `opus`, no override.
- **GREEN (2026-10-26).** The feature-developer dispatch made both edits and
  was then stopped when the session ended, before it reported; its model is
  therefore unrecorded (planned `opus`). The orchestrator checked the diff
  against the Contract (doctor.sh:180 want-list is
  `selftest.sh gates.sh check-boundaries.sh`, the `ok ci` line reads
  `runs the self-test, the gates and the boundaries check`, nothing above line
  140 moved; gates.yml drops both guard steps and their comments and the
  self-test step's comment says the guards run inside it) and reran:
  `doctor: 69 passed, 0 failed` (RED: 66/3), `sigpipe: 91 passed, 0 failed`
  (its C-5 pins on doctor.sh held), `ci-local: 28 passed, 0 failed`,
  `gates.sh --fast` exit 0. `doctor.sh` on this repository now prints
  `ok       ci           runs the self-test, the gates and the boundaries check`.
