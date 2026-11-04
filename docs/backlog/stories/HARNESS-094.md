---
id: HARNESS-094
title: The pre-PR self-test runs only the suites the story's diff can break
slug: the-pre-pr-self-test-runs-only-the-suite
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-094-the-pre-pr-self-test-runs-only-the-suite
depends_on: []      # nothing: this is the first of the pair; HARNESS-095 and HARNESS-089..093 wait for it
touches: [scripts/selftest-needed.sh, scripts/selftest.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/selftest.test.sh, .claude/tests/floors.conf, CLAUDE.md, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

At GATES → REVIEW, step 2 of `.claude/commands/advance-story.md` (and the
same bullet in `complete-story.md`) runs the **whole** harness self-test,
`SELFTEST_JOBS=4 bash scripts/selftest.sh`, whenever
`scripts/selftest-needed.sh` answers `run`. On the Windows/Git Bash host this
harness is developed on that took 11,419 s for HARNESS-088
(`.claude/state/attest-logs/20261104T014702Z.396343.log`, which opens by
reporting four other `gates.sh` runs on the host), 9,375 s and 3,845 s for
the two stories before it. CI runs the same full self-test on every PR
(`.github/workflows/gates.yml`, the `Harness self-test` step) in about 4-5
minutes: PR #177's `gates` job took 4m35s. So the local full run repeats CI
at roughly 40x the cost, and what it buys is one thing: catching, before the
PR opens, a break in a suite the story never touched. That is real -
HARNESS-088 shifted `scripts/gates.sh` lines and broke a line pin in
`.claude/tests/sigpipe.test.sh` (its `## Regressions` R-1), and the floors in
`.claude/tests/floors.conf` are a second cross-suite dependency - but it is
a property of a handful of suites, not of all 34.

This story is the **mechanism**: a way to ask which suites a diff can
break, mechanically, and a way to run exactly those with the same floors
discipline as a full run. HARNESS-095 (depends on this one) switches the two
commands and `lead-po.md` to it and says when the full run is still
warranted. The split is a true ordering, not a collision: 095's step text
names a command that does not exist until this story merges, and each half is
demonstrable on its own (this one on fixtures, 095 through the `procedure`
and `dispatch` guards).

**The gate that fails if this story breaks:** every gate in this repository's
`project.conf` is unconfigured, so `bash scripts/gates.sh` judges nothing
here. The artifact is judged by `bash scripts/selftest.sh selftest-needed`
and `bash scripts/selftest.sh selftest`, both of which CI runs (the full
`selftest.sh` in `.github/workflows/gates.yml`). `required_gates` stays empty.

**CI is not a required check (verified 2026-11-04).** `gh api
repos/ryanczhang7/agentic-dev-harness/branches/main/protection` answers
`Branch not protected` (404), and the one ruleset on `main` (`Do not delete`,
id 25853685) carries only `deletion` and `non_fast_forward`. So the `gates`
job - the full self-test - is **advisory**: nothing stops a PR merging with
it red or unfinished. The safety argument of this story and of HARNESS-095
("the local run covers what the diff can break; CI's full run on the PR is
the full check") leans on the user reading the check before merging, as the
house practice already is (the user merges every PR by hand). Making `gates`
and `boundaries` required status checks in a ruleset is a repository setting
the user can change in a minute; it is recorded here and in the report as a
risk, not done by this story (Out of scope).

## Acceptance criteria

All eight are **mechanical** (see the Contract's oracle partition): exact
exit statuses, exact stdout lines, exact suite lists. Nothing here is a
measurement; the one number this story produces - how much wall time the
selection saves on its own diff - is DV-2, recorded in `## Notes`, and no
criterion depends on it.

- **AC-1 (mention selects)** — Given a checkout where the changed set against
  the base (committed or not, as `selftest-needed.sh` enumerates it today)
  holds harness paths each of which appears, as a literal repo-relative
  substring, in the source of one or more `.claude/tests/*.test.sh` suites
  (and none of which any other rule of the Contract maps - the fixture uses
  paths like `.claude/harness/x.conf`), when `bash scripts/selftest-needed.sh --suites` runs, then it prints on
  stdout exactly the names of those suites, one per line, in `sort` order,
  no duplicates, nothing else, and exits 0; and a suite whose source does not
  mention any changed path is **not** printed (the control). The same
  enumeration prints the same list from a subdirectory of the checkout.
- **AC-2 (a suite selects itself; the library selects everything)** — Given
  a changed `.claude/tests/<name>.test.sh`, when `--suites` runs, then
  `<name>` is printed whether or not any suite mentions that path. Given a
  changed `.claude/tests/_lib.sh`, `.claude/tests/_spawns.sh` or
  `scripts/selftest.sh`, then stdout is exactly the one line `all` and
  stderr says which path made it so.
- **AC-3 (fail safe)** — Given a changed harness path that no rule of the
  Contract maps to any suite (the control: a new `.claude/harness/x.conf`),
  when `--suites` runs, then stdout is exactly `all`, exit 0, and stderr
  names that path as the reason. Given any of `selftest-needed.sh`'s
  fail-toward-run conditions (no base, no merge base, not a git checkout, the
  library or `paths.conf` not loading), then stdout is exactly `all`, exit 0,
  and stderr carries the existing reason text. A path the rules **can** map
  never widens the answer to `all` (the control for the control).
- **AC-4 (scanners)** — Given a changed path matched by a row of the
  Contract's scanner table, when `--suites` runs, then that row's suite is
  printed even though its source never mentions the path: any `*.sh` under
  `scripts/` or `.claude/hooks/` prints `lib`, `sigpipe` and `grep-count`;
  any `*.sh` elsewhere under `.claude/` prints `sigpipe` and `grep-count`
  and not `lib`; any path under `.claude/skills/stack-profiles/reference/`
  prints `profiles`; any `*.md` under `.claude/commands/`, `.claude/agents/`
  or `.claude/skills/` prints `shipped-docs`. A changed `.md` under
  `.claude/skills/` that no suite mentions prints `shipped-docs` (and
  `policy` if mentioned there) and **not** `all` (the control: the table is a
  mapping, so the path is not unmapped).
- **AC-5 (nothing to run, and usage)** — Given a changed set with no harness
  path, when `--suites` runs, then stdout is empty, exit 1, and stderr
  carries the existing `selftest-needed: skip — ...` line. `--suites` with a
  base ref (`--suites <ref>`) uses that base; any other `-`-prefixed argument,
  or more than two arguments, is still the usage error, exit 2, nothing on
  stdout. Without `--suites` the script's run/skip output and exit statuses
  are byte for byte what they are today (every existing case in
  `selftest-needed.test.sh` keeps its verdict).
- **AC-6 (several named suites)** — Given `bash scripts/selftest.sh a b`
  naming two existing suites, when it runs, then exactly those two run, in
  glob order, each floor enforced, printed in the same per-suite blocks a
  one-name run prints, and the run is otherwise a single-suite run (no
  whole-file floors audit). Given a name that matches no suite among several,
  then nothing runs, the existing `No suites matched` line names it, exit 1.
  One name behaves exactly as today.
- **AC-7 (`--changed`)** — Given `bash scripts/selftest.sh --changed [ref]`,
  when `selftest-needed.sh --suites [ref]` prints names, then **first** the
  whole-file floors audit of a full run is performed (a `floors.conf` fault
  fails the run before any suite runs, even when the faulted suite is not
  selected - the control), then exactly the printed suites run as AC-6 runs
  them, after one stdout line `selftest: --changed — N of M suite(s)
  selected: <names>` that precedes the first suite block, and the last line
  is the full run's `N harness suite(s) passed.` or `N of M harness suite(s)
  FAILED.` with N and M counting the selected suites. When `--suites` prints
  `all`, the run is a full run and its stdout from the header line down is
  byte for byte a full run's. When `--suites` prints nothing (exit 1), the
  run prints `selftest: --changed selected no suite — <the skip line>`,
  runs nothing, and exits 1. `SELFTEST_JOBS` applies as it does to a full
  run.
- **AC-8 (the command list)** — Given `CLAUDE.md`'s "Running things" block,
  when read, then it names `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
  with a comment saying it runs the suites this story's diff can break, and
  `bash scripts/selftest-needed.sh --suites` with a comment saying it prints
  those suites, both directly after the existing `selftest-needed.sh` line.
  The `procedure` and `dispatch` guards are **untouched** by this story: the
  step text they pin still names the full run until HARNESS-095.

## Contract

**Writes:** `scripts/selftest-needed.sh`, `scripts/selftest.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/selftest.test.sh`, `.claude/tests/floors.conf`, `CLAUDE.md`, `.claude/harness/VERSION`

**Oracle partition.** AC-1..AC-8 *mechanical*: pin exit statuses, whole
stdout where the fixture makes it deterministic, and the named stderr pieces
exactly. Nothing is a measurement and nothing is calibrated. The selection
counts in "Baseline" below are *settled* - read them out as the expected
output of the real-tree probe in DV-1, do not re-derive the rule from them.

**Two existing surfaces, both read, neither re-derived (settled):**
`selftest-needed.sh`'s changed-set enumeration (base = first of
`origin/main`, `main`; `git diff -z --no-renames --name-only <merge-base>`
plus `git ls-files -z --others --exclude-standard`; the fail-toward-run
fallbacks; `classify_stdin` to keep only `harness` paths) and
`selftest.sh`'s floors machinery (`load_floors`, `floor_of`,
`executed_count`, the full-run audit, `report_suite`, the one-at-a-time and
concurrent loops). The new code is a second output mode on the first and a
different way of building `SUITES` on the second.

**`scripts/selftest-needed.sh --suites [base-ref]` (new mode).**
Arguments: `--suites` must be `$1`; `$2` is the optional base, as today's
`$1` is. Everything else that starts with `-`, or a third argument, is the
existing usage error (exit 2, usage on stderr, nothing on stdout). The
existing one-argument form is unchanged in every byte and status.

- *Enumeration.* The same as the run/skip mode, including every
  fail-toward-run fallback. In `--suites` a fallback prints `all` on stdout,
  exit 0, and the fallback's existing one-line text on **stderr**. No harness
  path: nothing on stdout, exit 1, the existing `skip` line on stderr.
- *The rules.* For each harness path `p`, in this order; every rule that
  matches contributes, and `all` wins over everything:
  - **R1, itself.** `p` matches `.claude/tests/<name>.test.sh` → `<name>`.
  - **R2, read by every suite.** `p` is `.claude/tests/_lib.sh`,
    `.claude/tests/_spawns.sh` or `scripts/selftest.sh` → `all`. (Every suite
    sources `_lib.sh`; `_spawns.sh` is its tracer; `selftest.sh` is the
    runner and the subject of the `selftest` suite's goldens.)
  - **R3, mentioned.** `p` occurs as a fixed-string substring
    (`grep -qF -- "$p"`) in the source of `.claude/tests/<name>.test.sh` →
    `<name>`, for every suite in `.claude/tests/*.test.sh` (so a consuming
    project's `project-*.test.sh` are enumerated too). Comments count: a
    mention in a comment selects, which over-selects and never under-selects.
    The prototype measured comment stripping and it changed the count on one
    of five diffs by four suites; not worth a rule with a limit.
  - **R4, scanners.** A table in the script, one row per suite that reads
    the tree by glob rather than by name, each with the evidence line:

        scans | lib          | scripts/*.sh .claude/hooks/*.sh
        scans | sigpipe      | *.sh
        scans | grep-count   | *.sh
        scans | profiles     | .claude/skills/stack-profiles/reference/*
        scans | shipped-docs | .claude/commands/*.md .claude/agents/*.md .claude/skills/*.md

    Patterns match the whole repo-relative path with `*` crossing `/`
    (a bash `case` pattern does exactly that), so `.claude/skills/*.md`
    covers any depth under `.claude/skills/`, and `scripts/*.sh` covers
    `scripts/probes/x.sh` too; the AC-4 cases pin it. Evidence: `lib.test.sh:434` lists every
    `scripts/*.sh` and `.claude/hooks/*.sh` for its portability block;
    `sigpipe.test.sh:113` and `grep-count.test.sh:272` run their guards over
    `classify.sh --list harness` filtered to `.sh`; `profiles.test.sh:18`
    globs the reference directory; `shipped-docs.test.sh:51-55` globs the
    three directories. A row is a declaration like a floor: a new suite that
    globs the tree adds its row, and the header of `selftest-needed.sh` says
    so. Nothing checks that declaration mechanically (Out of scope).
  - **R5, fail safe.** A harness `p` that R1-R4 all miss → `all`, with
    stderr naming `p`. This is the rule the user asked for: a path the
    mapping cannot place selects more, never fewer.
- *Output.* stdout: the sorted unique suite names, one per line, or the
  single line `all`. stderr, one header line then one line per selected
  suite with the first path and rule that selected it, in these shapes:

      selftest-needed: suites — 6 of 34 selected from 2 harness path(s) changed against origin/main (merge-base a1b2c3d)
        boundaries    .claude/harness/VERSION (mentioned)
        lib           scripts/foo.sh (scans scripts/*.sh)
        foo           .claude/tests/foo.test.sh (itself)
      selftest-needed: suites — all: .claude/tests/_lib.sh is read by every suite
      selftest-needed: suites — all: .claude/harness/x.conf is mapped by no rule; defaulting to every suite
      selftest-needed: suites — all: cannot compute the diff: no merge base with origin/main; defaulting to every suite

  `34` is the count of `.claude/tests/*.test.sh` in the tree the script runs
  in, not a constant. The em dash and the `selftest-needed: ` prefix are the
  existing ones. The suite's assertions on stderr pin the header's first
  token after `suites — ` (`6 of 34`, `all:`) and the reason words; the
  per-suite lines are pinned by one case each for `(mentioned)`, `(itself)`
  and `(scans ...)`.
- *Portability.* bash/awk/grep/coreutils/git only; no process per
  (path × suite) pair where a single `grep -lF -f` over the suite files
  will do - a fork costs ~150 ms on this host and 34 suites × 10 paths is
  340 of them (`selftest.sh`'s DV-5 note).

**`scripts/selftest.sh [--changed [base-ref] | <name>...]`.**

- *Several names.* `SUITES` is every `.claude/tests/*.test.sh`, in glob
  order, whose name is among the arguments. Before the lock, any argument
  naming no suite prints the existing `No suites matched '<name>'. Looked in
  .claude/tests/*.test.sh` line to stderr and exits 1 with nothing run. One
  name keeps today's path, including the single-suite floor rule (own floor
  only, WARNING when it has none) - a multi-name run applies that same rule
  per named suite and performs no whole-file audit.
- *`--changed`.* `$1` is `--changed`; `$2` an optional base passed through to
  `bash "$ROOT/scripts/selftest-needed.sh" --suites`. The selection runs
  **before** the floors audit and the lock (it takes no lock and is
  seconds). Then, by its answer: names → the full-run audit (`ONLY` empty
  semantics: every suite floored, file well-formed), then the header line,
  then the named suites exactly as the multi-name path runs them; `all` →
  header line, then a full run; nothing (exit 1) → the `selected no suite`
  line with the skip text appended, exit 1, no lock taken, nothing run; exit
  2 or anything else → `selftest: --changed cannot select: <stderr of
  --suites>`, exit 2. The header line:

      selftest: --changed — 6 of 34 suite(s) selected: boundaries doctor grep-count lib refresh sigpipe
      selftest: --changed — every suite: .claude/tests/_lib.sh is read by every suite
      selftest: --changed selected no suite — selftest-needed: skip — no harness path among 3 changed path(s) against origin/main (merge-base a1b2c3d); CI runs the self-test on the PR

  The second shape carries `--suites`'s reason after `every suite: `. The
  per-suite reason lines from `--suites` stderr are passed through to
  stderr. Totals and the last line count the suites that ran, so a selected
  run and a full run are told apart by the header, never by the summary.
- *`SELFTEST_JOBS`.* Unchanged: read first, applies to whatever `SUITES`
  holds.
- *The lock, host-load, buffers.* Unchanged; `--changed` is one run holding
  one lock like any other.

**`.claude/tests/selftest-needed.test.sh`.** Built on the existing fixture
(`make_project_fixture`, a `main`, a story branch, changes). New cases write
their own throwaway suites into the fixture's `.claude/tests/` - e.g.
`a.test.sh` that mentions `scripts/x.sh`, `b.test.sh` that does not - so
every AC-1..AC-4 list is deterministic and `34` above is the fixture's
count. One case per rule, one control per AC as named, the three `all`
shapes, the skip and the usage cases, and a subdirectory run. `assert_eq` on
whole stdout where deterministic. Floor: RED records the executed count in
`floors.conf` and in `selftest.test.sh`'s hand-copied table, in the RED
commit.

**`.claude/tests/selftest.test.sh`.** Uses the existing `FIX` and `selftest`
helper. New cases: two names (blocks for both, floors for both, a third
suite untouched), one unknown among two, `--changed` on a fixture with a
`main` ref and a diff that selects a subset (header line, audit first - a
malformed floors line fails before any suite), `--changed` that resolves to
`all` (compared against a plain full run's stdout from the header down),
`--changed` with no harness change (exit 1, the line), and `--changed` at
`SELFTEST_JOBS=3` printing the same as serial. The HARNESS-036 goldens are
untouched. Floor rises; RED records it.

**`CLAUDE.md`, "Running things".** Two lines after the `selftest-needed.sh`
line:

    bash scripts/selftest-needed.sh --suites   # which suites that diff can break, one per line, or `all`
    SELFTEST_JOBS=4 bash scripts/selftest.sh --changed   # run exactly those; the local self-test before a PR (HARNESS-095 switches the procedure to it)

`shipped-docs`, `reporting`, `rules-trim` and `lib` read `CLAUDE.md`;
none pins the command block's line count (checked: `lib.test.sh` reads
`CLAUDE.md` for the `@.claude/harness/rules.md` import, `rules-trim` for its
cap, `reporting` for its section). RED confirms by running those four.

**Baseline (settled; measured 2026-11-04 with a scratchpad prototype of
R1-R5 over five merged diffs, `.claude/tests` holding 34 suites).**
Selected: HARNESS-088 (gates.sh, check-boundaries.sh, two suites, floors,
VERSION, a skill) 23 of 34; HARNESS-075 24; HARNESS-087 (rules.md,
tdd-cycle, cases.md) 18; HARNESS-086 (story.sh and its callers) 29;
HARNESS-085 21. A lone `.claude/skills/story-authoring/SKILL.md` change: 4
(`grep-count policy shipped-docs sigpipe`); a lone `VERSION` bump: 6; a lone
`floors.conf` change: 6; a lone `CLAUDE.md` change: 8. The saving in suite
count is modest for a story that edits `gates.sh` (it is mentioned by 20
suites) and large for a docs story; the saving in **wall time** is decided
by whether `phase-guard` and `lib`, the two slowest (HARNESS-036: `phase-guard`
sets the floor; `lib.test.sh` header: "the forty minutes those two take on a
slow-forking host"), are selected - 088's selection drops `phase-guard`.
DV-2 measures it on this story's own diff.

**Callers.** No existing export changes signature. `selftest.sh`'s `ONLY`
is read in five places (`grep -n '\$ONLY' scripts/selftest.sh`: the suite
loop, the full-run audit guard, the fault filter, the serial loop, the
no-match message); each becomes a test against the selected set, and the
`selftest` suite's HARNESS-036 goldens pin that a one-name and a zero-name
run print what they printed. `selftest-needed.test.sh`'s usage case (line
245) stays: a second **non-`--suites`** argument is still exit 2.
`procedure.test.sh` and `dispatch.test.sh` pin the commands' step text,
which this story does not touch (AC-8).

**Known limit, declared.** A suite that exercises a changed script only
through another script - `boundaries` runs `check-boundaries.sh`, which runs
`story.sh`, and never names `story.sh` - is not selected by R3 for a
`story.sh` change. The transitive closure over textual mentions was
prototyped and rejected: `gates.sh` is mentioned by ten scripts, so one level
of expansion from it already selects nearly every suite, which is the full
run with extra steps. CI's full run is the backstop for the indirect case,
and HARNESS-095 names it as one of the conditions under which the full local
run is still warranted.

**RED may amend any block above in place, with a reason; GREEN builds what the amended block says.**

## Deferred verifications

**DV-1 (defect put back; the story's central claim; and the probe against
the real tree). Owner: GATES.** On the story branch, with the GATES edits in
the working tree, run `bash scripts/selftest-needed.sh --suites` and paste
stdout and stderr. This branch changes `scripts/selftest.sh`, which is R2,
so the real-tree answer **must** be `all` with stderr naming
`scripts/selftest.sh`. Then run it once more with the base set to a commit
of this branch in which `scripts/selftest.sh` is already changed and the
later edits are not (name the SHA), so the diff holds the other files only;
that answer **must** be a list, not `all`, holding `selftest-needed` and
`selftest` (R1, the two changed suites), `lib`, `sigpipe` and `grep-count`
(R4, `scripts/selftest-needed.sh`), the suites that mention `CLAUDE.md`
(R3, expected from the Baseline's prototype: `attest lib mutate refresh
reporting selftest-needed shipped-docs story`) and those that mention
`.claude/tests/floors.conf` and `.claude/harness/VERSION`. Paste both. A
mismatch between the second list and the rules is a finding about the rules
or about the prototype, and is written up, not adjusted away. Then put the defect back
- the one the story must never ship, an unmapped path judged as nothing:
`bash scripts/mutate.sh scripts/selftest-needed.sh '<expression that makes R5 print nothing instead of all>' -- bash scripts/selftest.sh selftest-needed`
(name the line GREEN wrote). AC-3's unmapped case **must** go red and AC-1's
cases stay green; paste the red lines and `mutate.sh`'s restore lines. One
mutation, one run, one restore.

**DV-2 (the number the procedure switch will rest on). Owner: GATES.** After
the full `SELFTEST_JOBS=4 bash scripts/selftest.sh` that GATES → REVIEW
still requires has been attested, and alone on the host as that run is, run
`bash scripts/attest.sh -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed
<sha>` with `<sha>` the commit named in DV-1 (so the answer is a list, not
`all`), and paste both records' `duration:` and `last:` lines, and the
header line. The claim that could come out either way: the `--changed` run
selects fewer suites than 34 and takes less wall time than the full run made
in the same conditions. If it does not, HARNESS-095 is re-planned before it
starts, and this story still merges: the mechanism is correct whether or
not it is cheap, and the number is what decides the next story, not this
one.

## Amendments

<!-- none yet -->

## Suppressions

<!-- none -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-094` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`: `fable` (Fable 5.1, `claude-fable-5-1`), the agent's own `model:`; no override was reported to the dispatch. 2026-11-04.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **Switching the procedure.** `advance-story.md`, `complete-story.md`,
  `lead-po.md`, and the `procedure` and `dispatch` guards that pin them, are
  HARNESS-095's. This story leaves the full run as the step-2 command and
  AC-8 says so; the two guards must stay green untouched.
- **Making `gates` a required status check.** A repository setting (a
  ruleset on `main` with required status checks), the user's to change, and
  the one thing that would make CI's full run unskippable. Recorded in
  Context and in the planning report as a risk.
- **CI's workflows.** Unchanged; `ci-local.sh` still runs the full self-test
  as the workflow does, and `ci-local.test.sh` keeps deriving its steps from
  the workflow files.
- **Transitive selection** through scripts that invoke a changed script
  (the Known limit). Rejected on measurement; CI is the backstop.
- **Checking the scanner table against the suites** - a guard that finds a
  suite globbing the tree with no `scans` row. A follow-up if a row is ever
  found missing; today the five rows are the five suites found by
  `grep -n 'for .* in .*\*\|ls "\$REPO_ROOT\|find \|classify.sh --list' .claude/tests/*.test.sh`.
- **A consuming project's scanning suites.** R1 and R3 enumerate
  `project-*.test.sh` like any other; a project suite that globs its tree
  would need a `project-scans.conf` the way floors have `project-floors.conf`.
  Not built until a project asks.
- **Making `sigpipe`'s line pins less brittle** (they pin real line numbers in
  five scripts, `sigpipe.test.sh:574-585`, and move whenever those scripts
  do). A possible follow-up story; this one only makes sure `sigpipe` is
  always selected for a script change.
- **HARNESS-091's flake** (`mutate` failing one assertion under the full
  concurrent run and passing alone) stays HARNESS-091's.
- **Exempting `.claude/harness/VERSION` or `floors.conf`** from R3, though
  nearly every story bumps both and each selects six suites. They are read
  by the suites that mention them (`make_fixture` copies the real VERSION;
  the `selftest` suite reads the real floors), so the selection is right;
  the cost is six cheap suites.

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

