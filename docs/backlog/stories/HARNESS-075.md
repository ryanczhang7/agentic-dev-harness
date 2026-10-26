---
id: HARNESS-075
title: The pre-REVIEW self-test runs only when the diff touches a harness path
slug: the-pre-review-self-test-runs-only-when
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-075-the-pre-review-self-test-runs-only-when
depends_on: [HARNESS-072, HARNESS-073, HARNESS-074]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/tests/procedure.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, CLAUDE.md] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Step 2 of GATES → REVIEW in `.claude/commands/advance-story.md` (and the
matching bullet in `.claude/commands/complete-story.md`) runs
`SELFTEST_JOBS=4 bash scripts/selftest.sh` - every harness suite - for
**every** story. Its stated reason: CI runs every suite, and a suite the
story never touched can fail on the story's change (a line number another
suite pins, a floor, a value an upstream suite asserts). That reason holds
only when the story changes a file a harness suite reads. In a consuming
project most stories change `source`, `test` and `docs` paths and nothing
else, and the self-test costs about 6 minutes at `SELFTEST_JOBS=4` on the
Windows host this harness is developed on, and hours while other test runs
share it (HARNESS-050..068: 2,894-17,015 s serial). CI's run costs 2-4
minutes on ubuntu and keeps running on every PR regardless, so a skipped
local run is a run deferred to CI, not a run lost.

**PO decision 1 - the trigger is `classify.sh`'s `harness` category, not
"was there a refresh" (2026-10-25).** "Only after a harness refresh" is too
narrow: several suites read files a project edits on its own.
`ci-local.test.sh` derives its expected step list from the real
`.github/workflows/`; `settings.test.sh` reads the real
`.claude/settings.json`; a project adds `.claude/tests/project-*.test.sh`
and `project-floors.conf`; `project.conf` and `paths.conf` change what the
lock and the gates do; `CLAUDE.md` is pinned by `shipped-docs`. Checked
against `bash scripts/classify.sh` on this tree: every one of those is
`harness`, as are `scripts/*.sh` (existing or not - classification is by
path, so a deleted or renamed script still counts), `.claude/commands/*.md`,
`.claude/tests/**` and `.gitignore`; `src/app.ts` is `source`,
`src/app.test.ts` is `test`, `docs/wiki/x.md` is `docs`, `package.json` is
`manifest`, `.dockerignore` is `config`. A harness refresh writes
`scripts/*.sh`, `.claude/**` and `CLAUDE.md`, so the refresh case is covered
by the same rule without naming it. So the decision is one line:

    changed paths of the story  |  classify.sh --only harness   non-empty  ->  run

**PO decision 2 - the decision lives in a script, not in prose.** A rule
written only into a command file cannot be tested; `procedure.test.sh` can
pin that the command names the script, and the script's own suite pins both
branches, the base-ref resolution and the fail-toward-run case. The
enumeration of "changed paths" already exists in `scripts/gates.sh:984-993`
(the `covers` check): base = first of `origin/main`, `main` that
`git rev-parse --verify -q` resolves; `mb = git merge-base <base> HEAD`;
changed = `git diff --name-only <mb>` (committed on the branch, staged and
unstaged, since GATES edits are not yet committed when step 2 runs) plus
`git ls-files --others --exclude-standard` (untracked), `sort -u`, piped
through `classify_stdin`. The new script uses the same enumeration, so the
two cannot disagree about what "the story's diff" is.

**PO decision 3 - when in doubt, run.** No base branch, no merge base
(depth-1 clone), not a git checkout, `git diff` failing: each prints why and
answers `run`. The cost of a wrong `run` is minutes; the cost of a wrong
`skip` is a red CI the story could have seen locally - the asymmetry the
step exists for.

**In this repository nothing changes in practice.** Every story here edits
`scripts/`, `.claude/` or `CLAUDE.md`, so the script answers `run` on every
harness story, this one included (DV-1 shows it). The behaviour this story
adds is for consuming projects, where it is the common case.

**Pinned nearby.** `procedure.test.sh` (HARNESS-072) pins the step 2 needle
`` `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``, the words `detached`,
`Windows`, `## Notes`, `other test runs`, the diff-review step before it and
the phase change after it, and the `allowed-tools` entries for
`scripts/selftest.sh` and `scripts/ci-local.sh`. All of those stay true;
this story adds a needle in front of them. `selftest.test.sh`'s C-3 table
lists every suite with its floor, so a new suite is a row there and a line
in `floors.conf`. `refresh-harness.sh` copies `scripts/*.sh` wholesale, so
the new script ships to consuming projects with no manifest edit.

The required gate that fails if this story's artifact breaks: the self-test
(`selftest-needed`, `procedure`, `selftest` suites), run by CI on every pull
request.

## Acceptance criteria

- **AC-1** — Given a git checkout with a `main` branch and a story branch
  whose changes against it (committed, staged, unstaged or untracked) include
  at least one path `classify.sh` calls `harness`, when
  `bash scripts/selftest-needed.sh` runs with no argument, then it exits 0
  and its first stdout line begins `selftest-needed: run` and names the
  resolved base and the harness path(s). Covered inputs, each its own case:
  a committed `scripts/x.sh`; an uncommitted `.claude/tests/project-x.test.sh`;
  an untracked `.github/workflows/ci.yml`; `CLAUDE.md`; a deleted
  `scripts/y.sh`; and a mixed diff where the only harness path sits beside
  `source`, `test` and `docs` paths.
- **AC-2** — Given the same checkout and a branch whose changes are all
  `source`, `test`, `docs`, `manifest`, `config` or `vendor`/`ignored` paths
  (none `harness`), when it runs, then it exits 1 and its single stdout line
  begins `selftest-needed: skip`, states the count of changed paths and the
  base, and ends `; CI runs the self-test on the PR`. *Control:* the AC-1
  mixed diff - one `harness` path among the same `source`/`test`/`docs` paths
  - answers `run`, so the skip is decided by category and not by count. A
  branch with no changes at all answers `skip` with `0 changed path(s)`.
- **AC-3** — Given a checkout where neither `origin/main` nor `main`
  resolves, or `git merge-base` fails (an unrelated-history base), or the
  working directory is not a git checkout, when it runs with no argument,
  then it exits 0 and its first line begins `selftest-needed: run` and says
  why the diff could not be computed (`no origin/main or main to compare
  against`, `no merge base with <base>`, `not a git checkout`). Given an
  explicit base ref as `$1`, it is used in place of the resolution, and
  `origin/main` is preferred over `main` when both exist (two cases, each
  fixture arranged so the two refs give different answers).
- **AC-4** — Given `.claude/commands/advance-story.md` after this story, when
  `procedure.test.sh` reads it, then step 2 of GATES → REVIEW names
  `` `bash scripts/selftest-needed.sh` `` **before**
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` in the same step, says that
  `skip` is pasted into `## Notes`, and every needle HARNESS-072 pinned still
  holds (the step is still step 2, still before the phase change, still after
  the diff review); `complete-story.md`'s GATES → REVIEW bullet names
  `` `bash scripts/selftest-needed.sh` `` before the full self-test; and both
  commands' `allowed-tools` carry `Bash(bash scripts/selftest-needed.sh:*)`.
  *Controls:* a fixture command whose step 2 runs the self-test with no
  `selftest-needed` call is one "does not name" line; one that names it in a
  later step than the self-test is one "names ... after" line; one whose
  `allowed-tools` lacks the entry is one line naming the file and the entry.
- **AC-5** — Given this repository on the story branch, when
  `bash scripts/selftest-needed.sh` runs, then it answers `run` and names
  `scripts/selftest-needed.sh` among the harness paths (the statement in
  `## Context` that behaviour here does not change, made checkable; pasted in
  DV-1, not asserted by a suite, because the answer depends on which branch
  the suite runs on).

## Contract

**Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/tests/procedure.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `CLAUDE.md`

**Oracle partition.** AC-1..AC-4 *mechanical*: pin the exit status, the
first token after `selftest-needed: `, and the pieces of the line the AC
names, exactly. AC-5 *mechanical* but branch-dependent, so it is DV-1's
pasted output and no suite asserts it. Nothing here is a measurement.

**`scripts/selftest-needed.sh [base-ref]` (new).** `set -uo pipefail`,
sources `.claude/hooks/lib.sh` for `classify_stdin`, bash/awk/coreutils/git
only (`rules.md`, Portability). Arguments: zero or one; a second argument or
a `-`-prefixed one is a usage error on stderr, exit 2 (the only exit that is
neither `run` nor `skip`; the commands call it with no argument).

- *Base.* `$1` if given, else the first of `origin/main`, `main` that
  `git rev-parse --verify -q` resolves - the same loop and order as
  `gates.sh:984`. Not configurable from `project.conf` in this story (Out of
  scope).
- *Changed set.* `{ git diff --name-only <mb>; git ls-files --others
  --exclude-standard; } | sort -u`, where `mb = git merge-base <base> HEAD`.
  Paths are repo-relative as git prints them; run from any directory inside
  the checkout (`git rev-parse --show-toplevel`, `cd` there first, like
  `gates.sh`'s `-C "$ROOT"`).
- *Decision.* `harness = changed | classify_stdin | awk -F'\t' '$1=="harness"
  {print $2}'`. Non-empty → `run`, exit 0. Empty → `skip`, exit 1. So
  `bash scripts/selftest-needed.sh && SELFTEST_JOBS=4 bash scripts/selftest.sh`
  is the whole step as one line, and a `skip` is the non-zero of "nothing to
  do", not of failure.
- *Output, stdout, exactly one line each, in these shapes:*

      selftest-needed: run — 3 harness path(s) changed against origin/main (merge-base a1b2c3d): scripts/plan.sh, .claude/tests/plan.test.sh, CLAUDE.md
      selftest-needed: run — 7 harness path(s) changed against origin/main (merge-base a1b2c3d): scripts/plan.sh, .claude/tests/plan.test.sh, CLAUDE.md, +4 more
      selftest-needed: skip — no harness path among 5 changed path(s) against origin/main (merge-base a1b2c3d); CI runs the self-test on the PR
      selftest-needed: run — cannot compute the diff: no origin/main or main to compare against; defaulting to run
      selftest-needed: run — cannot compute the diff: no merge base with origin/main; defaulting to run
      selftest-needed: run — cannot compute the diff: not a git checkout; defaulting to run

  The first three harness paths are listed in `sort -u` order, then
  `, +N more`; the short SHA is `git rev-parse --short <mb>`. The dash is
  an em dash, as in `gates.sh`'s notes; the words `run` / `skip` directly
  after `selftest-needed: ` are the token both the suite and a reader key
  on. When the base was given as `$1` the line says `against <that ref>`.
  Nothing on stderr on the `run`/`skip` paths; the fail-toward-run paths may
  carry git's own stderr through.

**`.claude/tests/selftest-needed.test.sh` (new suite).** Built on
`make_project_fixture` (which copies `scripts/` and `.claude/hooks/` and
commits once); each case makes a `main` branch there, a story branch, the
change the AC names, and runs the script from the fixture root and once from
a subdirectory. One case per AC-1 input, the AC-2 skip and its control, the
AC-3 fail-toward-run trio, the explicit-base case and the `origin/main`-over-
`main` case (arrange `origin/main` as a plain ref via `git update-ref
refs/remotes/origin/main <sha>`; no network). Assert exit status and the
line's named pieces, with `assert_eq` on the whole first line where the
fixture makes it deterministic (fixed SHA read back with `rev-parse --short`).
Floor: RED records the executed count it measures in `floors.conf` and in
`selftest.test.sh`'s C-3 table, in the RED commit, as `floors.conf`'s header
says.

**`procedure.test.sh` (AC-4).** New needle `STEP_NEEDED='`bash
scripts/selftest-needed.sh`'` and tool pattern `TOOL_NEEDED='Bash(bash
scripts/selftest-needed.sh:*)'`. `procedure_problems` gains: step 2 must
contain `STEP_NEEDED` and it must precede `STEP_SELFTEST` within the step;
the step must contain the word `skip` and (already) `## Notes`; both
commands' `allowed-tools` must contain `TOOL_NEEDED`; `complete-story`'s
bullet must name `STEP_NEEDED` before the full self-test. Fault lines, in
the existing style: `` <file>: its step 2 does not name `bash
scripts/selftest-needed.sh` ``, `` <file>: names `bash scripts/selftest-
needed.sh` after `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``, `` <file>:
allowed-tools lacks `Bash(bash scripts/selftest-needed.sh:*)` ``.
`compliant_fixture`, `GOOD_STEPS`, `GOOD_BULLET`, `GOOD_TOOLS` carry the new
text; every HARNESS-068/072 case keeps its verdict. The floor rises; RED
records the new count in both files.

**The step text (advance-story, step 2 of GATES → REVIEW).** Still one
numbered step, now beginning `` `bash scripts/selftest-needed.sh` — ``: it
says the script answers `run` when the story's changes (committed or not)
include a path `classify.sh` calls `harness` - the files the harness suites
read - and `skip` otherwise; on `run`, `SELFTEST_JOBS=4 bash
scripts/selftest.sh`, with every sentence HARNESS-072's step has (detached,
alone in the worktree, exit status and last line and duration pasted into
`## Notes`, the orphan check, the host-load sentence, the failure routes);
on `skip`, paste the script's line into `## Notes` as

      - Self-test skipped at GATES → REVIEW (<date>): selftest-needed: skip — no harness path among N changed path(s) against <base> (merge-base <sha>); CI runs the self-test on the PR

  and go on to step 3; CI runs the self-test on the PR either way. One
  sentence says the fail-toward-run cases answer `run`. `complete-story`'s
  bullet gains `` `bash scripts/selftest-needed.sh` decides whether the full
  ... `` before the self-test clause. Both `allowed-tools` lines gain
  `Bash(bash scripts/selftest-needed.sh:*)` after the `selftest.sh` entry.

**`CLAUDE.md`, "Running things".** One line after `scripts/selftest.sh`:
`bash scripts/selftest-needed.sh   # does this story's diff touch a harness
path? exit 0 run / 1 skip`. `shipped-docs.test.sh` pins nothing in that
block that this moves (checked: it does not read the command list).

**Callers.** No existing export changes signature. `gates.sh:984-993` is
read, not edited (duplicating twelve lines is cheaper than a shared helper
that would move `gates.sh` line numbers `sigpipe.test.sh` C-5 pins; if GREEN
prefers a `lib.sh` function, `.claude/hooks/lib.sh` joins `touches:` and
`lib.test.sh` covers it - say so in the handoff). `ci-local.sh` runs the
self-test unconditionally and is untouched (it mirrors CI). `doctor.sh`'s
want-list is untouched.

## Deferred verifications

**DV-1 (defect put back; the story's central claim; AC-5; and the probe
against the real tree). Owner: GATES.** On the story branch, with the GATES
edits in the working tree, run `bash scripts/selftest-needed.sh` and paste
the line: it **must** say `run` and name `scripts/selftest-needed.sh`. Then
put the defect back - the one the story must never ship, a harness change
judged `skip`:
`bash scripts/mutate.sh scripts/selftest-needed.sh 's/"harness"/"docs"/' -- bash scripts/selftest.sh selftest-needed`
(adjust the expression to the line GREEN wrote; name it). The suite **must**
go red on the AC-1 cases and the AC-2 control, and stay green on the plain
AC-2 skip; paste the red lines and `mutate.sh`'s restore lines. Under the
same mutation, run the script once more on the real branch and paste that
it now says `skip` - the real tree, not a fixture, seen to be misjudged by
the mutant and judged correctly by the restored file. One mutation, two
readings, one restore.

**DV-2 (the fail-toward-run default, on a real clone). Owner: GATES.**
`git clone --depth 1 --branch <story branch> file://$PWD <scratch>` and run
the script there: with no `origin/main` fetched it **must** answer `run`
with `no origin/main or main to compare against` (or, if the shallow clone
carries the ref, `no merge base with origin/main`), exit 0. Paste the line.
This is AC-3 against a tree git made, not a fixture the suite arranged.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-075` from `.claude/harness/models.conf`.
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

- PLANNED — `lead-po` — resolved: **fable** (Fable 5.1, the agent's own `model:`; dispatched by a lead-po session with no model override visible to this dispatch). Verdict on the plan: n/a - no row departed from `models.conf`.
## Out of scope

- CI: `.github/workflows/gates.yml` keeps `bash scripts/selftest.sh` on
  every PR, and `ci-local.sh` keeps running it unconditionally - that script
  mirrors CI, and the point of the skip is that CI still runs it.
- The value `SELFTEST_JOBS=4` and the step's duration prose (HARNESS-072);
  the guard CI steps (HARNESS-073); host-load detection (HARNESS-074).
- A `project.conf` key to widen or narrow the trigger (extra paths a
  project's own suites read outside `harness`). A project whose
  `project-*.test.sh` reads a `source` path can say so in a later story;
  today it runs the self-test by hand or lets CI catch it.
- `check-boundaries.sh` verifying that a skipped story recorded the skip, or
  that a `run` story pasted a result. The note is for the reader; CI's own
  run is the enforcement.
- Skipping any part of the self-test *within* a run (named suites,
  "only the suites that read the changed files"). Decided against in
  HARNESS-072: keep the whole run when it runs.
- `doctor.sh` learning about the new script; `refresh-harness.sh` already
  ships it as part of `scripts/*.sh`.

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


- Planned 2026-10-25 from the request "run the pre-REVIEW self-test only
  when the story's diff touches a harness path; CI unchanged". `depends_on`:
  HARNESS-072 is a true dependency - this story rewrites the step 2 text and
  the `procedure.test.sh` needles 072 introduced, so it must start from a
  `main` that carries 072. HARNESS-073 and HARNESS-074 are collision-only
  (`floors.conf` and `selftest.test.sh`, where each story adds or raises a
  floor); they are listed on the dispatching session's instruction to depend
  on any story `plan.sh conflicts` reports a CONFLICT with, and because the
  three are already sequenced 072 → 073 → 074 (HARNESS-073 `## Notes`). If
  the user would rather run 075 beside 073 or 074, drop those two ids: the
  merge is a one-line floor each.
- Checked before cutting: `.claude/tests/*.test.sh`, `.claude/tests/floors.conf`,
  `.claude/harness/*.conf`, `.github/workflows/*.yml`, `.claude/settings.json`,
  `CLAUDE.md`, `.gitignore` and `scripts/*.sh` (present or not) all classify
  `harness` on this tree; `src/*.ts` `source`/`test`, `docs/**` `docs`,
  `package.json` `manifest`, `.dockerignore` `config`.
