---
id: HARNESS-075
title: The pre-REVIEW self-test runs only when the diff touches a harness path
slug: the-pre-review-self-test-runs-only-when
epic: 
type: chore
status: in-progress
phase: GATES
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
  `bash scripts/selftest-needed.sh` runs, then it answers `run`, and
  `scripts/selftest-needed.sh` is among the harness paths it counts, shown by
  `classify.sh --only harness` over the same enumeration, pasted beside the
  line (amended 2026-10-26, see `## Amendments`; the statement in
  `## Context` that behaviour here does not change, made checkable; pasted in
  DV-1, not asserted by a suite, because the answer depends on which branch
  the suite runs on).

## Amendments

- **AC-5, 2026-10-26, approved by the user in chat.** Was: "then it answers
  `run` and names `scripts/selftest-needed.sh` among the harness paths". Now:
  "then it answers `run`, and `scripts/selftest-needed.sh` is among the
  harness paths it counts, shown by `classify.sh --only harness` over the same
  enumeration, pasted beside the line". Why: the Contract pins the line to the
  first three harness paths in `sort -u` order then `, +N more` (the suite
  asserts it with `assert_eq`), and `.claude/` and `CLAUDE.md` sort before
  `scripts/`, so on this branch the script is path 8 of 8 and the old wording
  could never be observed. Found by GREEN, reproduced by the orchestrator
  (`## Notes`, "Open: AC-5"). DV-1's first reading follows the amended AC.

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

*Amended in RED (2026-10-26, test-developer), three points the block left
open; the fault-line texts above are unchanged:*
- *complete-story's bullet* gets its own "does not name" line,
  `` .claude/commands/complete-story.md: its GATES → REVIEW bullet does not name `bash scripts/selftest-needed.sh` ``,
  in the existing bullet style. Reason: the pinned `its step 2 does not name`
  wording is false for a bullet, which has no step 2. Its "after" line is the
  generic `` <file>: names `bash scripts/selftest-needed.sh` after ... `` above.
  The bullet check runs only when the bullet names the self-test at all (else
  the existing "does not name `SELFTEST_JOBS=4 ...`" line already reports it).
- *advance-story, which step counts.* The self-test's step (the first step
  holding `STEP_SELFTEST`) is judged. `STEP_NEEDED` in that step before the
  self-test: silent; after it: the "after" line. Absent from that step but in a
  LATER step: the "after" line (AC-4's control). In no step, or only in an
  EARLIER step: the "does not name" line (AC-4: "in the same step"). Judged
  only when the self-test step exists, like the step's words.
- *`skip`* is a fifth entry in `STEP_WORDS`, so its fault line is the existing
  `` its `SELFTEST_JOBS=4 bash scripts/selftest.sh` step does not say `skip` ``.
  Output order inside advance-story: tools (the new `lacks` line after the two
  existing tool lines), the existing step checks, the word lines (`skip`
  last), then the selftest-needed line, then the review checks.

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
the line: it **must** say `run`, and `classify.sh --only harness` over the
same enumeration, pasted beside it, **must** list `scripts/selftest-needed.sh`
(AC-5 as amended). Then
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

*Result (GATES, orchestrator, 2026-10-26).* Expression `s/"harness"/"harnessX"/`
per the PO correction in `## Notes` (the `"docs"` form would also redden the
plain AC-2 skip). The literal occurs once, on line 63, the decision line.

First reading, the restored tree (AC-5 as amended) - the line, then
`classify.sh --only harness` over the same enumeration:

    selftest-needed: run — 8 harness path(s) changed against origin/main (merge-base 1282a65): .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/tests/floors.conf, +5 more
    rc=0
    .claude/commands/advance-story.md
    .claude/commands/complete-story.md
    .claude/tests/floors.conf
    .claude/tests/procedure.test.sh
    .claude/tests/selftest.test.sh
    .claude/tests/selftest-needed.test.sh
    CLAUDE.md
    scripts/selftest-needed.sh

The mutation, the suite under it (red lines abridged to one per case; every
AC-1 case, AC-2's control, the two list-shape cases and the two "run"
base cases went red, four assertions each; the plain AC-2 skip, the
zero-change case and AC-3's fail-toward-run trio stayed green), the real
branch under the same mutant, and the restore:

    === mutate: scripts/selftest-needed.sh (1 line(s) changed by s/"harness"/"harnessX"/) ===
      63 - harness="$(printf '%s\n' "$changed" | classify_stdin | awk -F'\t' '$1 == "harness" { print $2 }')"
      63 + harness="$(printf '%s\n' "$changed" | classify_stdin | awk -F'\t' '$1 == "harnessX" { print $2 }')"
      AC-1: a harness path among the story's changes answers run, exit 0
        FAIL a COMMITTED new scripts/x.sh answers run and names it [from root]: exits 0
        FAIL an UNCOMMITTED (staged) .claude/tests/project-x.test.sh answers run and names it [from root]: exits 0
        FAIL an UNTRACKED .github/workflows/ci.yml answers run and names it [from root]: exits 0
        FAIL an unstaged edit to CLAUDE.md answers run and names it [from root]: exits 0
        FAIL a DELETED scripts/y.sh answers run and names it: classification is by path [from root]: exits 0
        FAIL a mixed diff whose ONLY harness path is scripts/z.sh, beside source, test, docs, manifest, config and vendor paths, answers run (AC-2's control) [from root]: exits 0
        FAIL exactly three harness paths are all listed, in sort order, with no `+N more` [from root]: exits 0
        FAIL four harness paths list the first three in sort order, then `, +1 more` [from root]: exits 0
      AC-2: no harness path among the changes answers skip, exit 1
      AC-3: when the diff cannot be computed, it answers run, exit 0
      AC-3: an explicit base ref is used in place of the resolution
        FAIL `selftest-needed.sh release` diffs against release and says `against release` [from root]: exits 0
      AC-3: origin/main is preferred over main when both resolve
        FAIL with both refs present and no argument, origin/main is the base [from root]: exits 0
    selftest-needed: 99 passed, 40 failed
    --- real branch under the mutant:
    selftest-needed: skip — no harness path among 9 changed path(s) against origin/main (merge-base 1282a65); CI runs the self-test on the PR
    rc=1
    === mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_selftest-needed.sh.20261027T002134Z.6423.bak) ===
      63: harness="$(printf '%s\n' "$changed" | classify_stdin | awk -F'\t' '$1 == "harness" { print $2 }')"

    selftest-needed: run — 8 harness path(s) changed against origin/main (merge-base 1282a65): .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/tests/floors.conf, +5 more
    rc after restore=0

40 failed is exactly the count RED's handoff predicted for this mutant on its
scratch candidate. (The real branch counted 9 paths under the mutant and 8
after: the story file, `docs`, was modified in the working tree during the
mutant run and committed before the final reading.)

**DV-2 (the fail-toward-run default, on a real clone). Owner: GATES.**
`git clone --depth 1 --branch <story branch> file://$PWD <scratch>` and run
the script there: with no `origin/main` fetched it **must** answer `run`
with `no origin/main or main to compare against` (or, if the shallow clone
carries the ref, `no merge base with origin/main`), exit 0. Paste the line.
This is AC-3 against a tree git made, not a fixture the suite arranged.

*Result (GATES, orchestrator, 2026-10-26).* Depth-1 clone of the story branch
into the session scratchpad; the clone carried only the story branch and its
`origin/` tracking ref, no `origin/main`, no `main`:

    * story/HARNESS-075-the-pre-review-self-test-runs-only-when
      remotes/origin/story/HARNESS-075-the-pre-review-self-test-runs-only-when
    selftest-needed: run — cannot compute the diff: no origin/main or main to compare against; defaulting to run
    rc=0

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

Two harness suites, both shell, both run by `bash scripts/selftest.sh <name>`.

**`.claude/tests/selftest-needed.test.sh` (new, 139 executed).** Integration
level: each case is a real git repository built with `make_project_fixture`
(its one commit renamed to `main`), a story branch, and the change the AC
names; the fixture's own copy of `scripts/selftest-needed.sh` is run once from
the fixture root and once from `src/`. Each run asserts the exit status, the
WHOLE first stdout line (`assert_eq`, em dash included, SHA read back with
`git rev-parse --short` on the ref the fixture arranged), exactly one stdout
line, and - on the run/skip paths - empty stderr.

| Case | AC | Expected |
|---|---|---|
| committed new `scripts/x.sh` | AC-1 | run, 1 path, against main |
| staged-not-committed `.claude/tests/project-x.test.sh` | AC-1 | run |
| untracked `.github/workflows/ci.yml` | AC-1 | run |
| unstaged edit to `CLAUDE.md` (committed on main) | AC-1 | run |
| unstaged deletion of `scripts/y.sh` (committed on main) | AC-1 | run |
| mixed: `src/app.ts`, `src/app.test.ts`, `docs/wiki/x.md`, `package.json`, `.dockerignore`, `vendor/lib.js`, `scripts/z.sh` + ignored untracked `node_modules/pkg/index.js` | AC-1, AC-2 control | run, 1 path `scripts/z.sh` |
| exactly three harness paths | Contract (list shape) | three listed, no `+N more` |
| four harness paths | Contract (list shape) | three listed, `, +1 more` |
| the mixed set without `scripts/z.sh` | AC-2 | skip, `6 changed path(s)`, exit 1 |
| no changes | AC-2 | skip, `0 changed path(s)`, exit 1 |
| no `main`/`origin/main` (branch is `trunk`) | AC-3 | run, `no origin/main or main to compare against` |
| `main` an unrelated root commit (plumbing) + precondition | AC-3 | run, `no merge base with main` |
| plain directory, `GIT_CEILING_DIRECTORIES` above it + precondition | AC-3 | run, `not a git checkout` |
| `$1 = release` where main moved past release with a harness commit; control: no argument | AC-3 explicit base | run against release / skip against main |
| `origin/main` (update-ref, one commit behind main) and `main`; control: `$1 = main` | AC-3 origin/main first | run against origin/main / skip against main |
| two arguments; `--help` | Contract (usage) | exit 2, empty stdout, non-empty stderr |

**`.claude/tests/procedure.test.sh` (98 -> 118 executed).** Static, the
existing grep-for-the-shape guard. `procedure_problems` gains the AC-4 checks
(see the Contract amendment for the exact rules). The real-tree assertion is
the AC-4 red; twenty new fixture cases pin each new fault line and its
controls: step 2 without the call; the call in a later step; after the
self-test within the step; only in an earlier step; only in prose; unquoted;
with an argument; first-mention-wins; `skip` missing / in another step; each
command's allowed-tools without the entry, without `:*`, only in the body, the
`lacks` line's order; the bullet without the call, with it after, with it only
elsewhere, with no self-test at all; and the five-line output a tree without
this story's edits prints, in order. Every HARNESS-032/068/072 case keeps its
expected lines byte for byte; only their INPUT fixtures gained the new text.

AC-5 is DV-1's (GATES), not a suite assertion.

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

Written by the test-developer dispatch, RED, 2026-10-26. Model: the agent's own
`model:` (`opus`), resolved to **Opus 5.5** (`claude-opus-5-5`); no override was
given in the dispatch.

**Commands.**

    bash scripts/selftest.sh selftest-needed
    bash scripts/selftest.sh procedure
    bash scripts/selftest.sh selftest       # the C-3 floor table

**Files touched (RED).** `.claude/tests/selftest-needed.test.sh` (new),
`.claude/tests/procedure.test.sh`, `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh` (COUNTS rows only), this story (`## Contract`
amendment, `## Test plan`, this handoff). Not touched: `scripts/selftest-needed.sh`,
`.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`,
`CLAUDE.md`.

**Floors.** `selftest-needed | 139` (new, between `security-audit` and
`settings` in `floors.conf`; after `selftest` in the COUNTS table) and
`procedure | 98 -> 118`, in both files, each the EXECUTED count of the RED run
below. `bash scripts/selftest.sh selftest` after the edit:

    selftest: 268 passed, 0 failed

    assertion floors: all 1 suite(s) met their declared floor (268 assertions executed, 268 declared).
    1 harness suite(s) passed.

**RED output, `selftest-needed`** (local, Windows/Git Bash, 2m42s): every run
exits 127 because the script is missing; first and last lines of the run:

    === selftest-needed ===

      the script exists
        FAIL scripts/selftest-needed.sh exists in this repository
             expected: 
             actual:   missing

      AC-1: a harness path among the story's changes answers run, exit 0
        FAIL a COMMITTED new scripts/x.sh answers run and names it [from root]: exits 0
             expected: 0
             actual:   127
        FAIL a COMMITTED new scripts/x.sh answers run and names it [from root]: the first line is exactly the pinned line
             expected: selftest-needed: run — 1 harness path(s) changed against main (merge-base de7b7d1): scripts/x.sh
             actual:   
        FAIL a COMMITTED new scripts/x.sh answers run and names it [from root]: stdout is exactly one line
             expected: 1
             actual:   0
        FAIL a COMMITTED new scripts/x.sh answers run and names it [from root]: nothing on stderr
             expected: 
             actual:   bash: /tmp/tmp.XXXXXXXXXX/scripts/selftest-needed.sh: No such file or directory
    ...
      Contract: a second argument, or a `-`-prefixed one, is a usage error, exit 2
        FAIL two arguments exit 2
             expected: 2
             actual:   127
        FAIL a `-`-prefixed argument exits 2
             expected: 2
             actual:   127

    selftest-needed: 6 passed, 133 failed
    FAIL selftest-needed  did 6 units of work, below the floor of 139 in .claude/tests/floors.conf

    assertion floors: 0 of 1 suite(s) met their declared floor.
    1 of 1 harness suite(s) FAILED.

(The temp directory name is elided; it differs per run. That capture also
carried HARNESS-074's host-load warning, two other `gates.sh --fast` runs on the
host - not from this suite.)

Why each failure is the right one: every `exits N` reads `actual: 127`, every
first-line assertion reads `actual:` empty, every one-line assertion reads
`actual: 0`, every stderr assertion reads `bash: <fixture>/scripts/selftest-needed.sh:
No such file or directory`. No fixture or setup error: the two preconditions
(unrelated `main`; directory outside any checkout) PASS, and the whole suite
was run against a scratch candidate implementation (below) and went 139/0.

The 6 that pass in RED: the two preconditions, and the four usage-error
companions (`prints nothing on stdout`, `says why on stderr`, for two
arguments and for `--help`), which a missing script also satisfies. Each is
paired with an `exits 2` assertion that is red now, so the pair is not
satisfiable by absence.

**RED output, `procedure`** (local, 2m12s): `procedure: 117 passed, 1 failed`.
The one red is the real-tree assertion, and it prints exactly the five AC-4
lines and nothing else:

    FAIL procedure_problems over the real tree prints nothing: ... and (HARNESS-075 AC-4) both commands permit selftest-needed.sh, step 2 names it before the self-test and says `skip`, and complete-story's bullet names it before the self-test
         expected: 
         actual:   .claude/commands/advance-story.md: allowed-tools lacks `Bash(bash scripts/selftest-needed.sh:*)`
         .claude/commands/advance-story.md: its `SELFTEST_JOBS=4 bash scripts/selftest.sh` step does not say `skip`
         .claude/commands/advance-story.md: its step 2 does not name `bash scripts/selftest-needed.sh`
         .claude/commands/complete-story.md: allowed-tools lacks `Bash(bash scripts/selftest-needed.sh:*)`
         .claude/commands/complete-story.md: its GATES → REVIEW bullet does not name `bash scripts/selftest-needed.sh`

Line by line: (1)/(4) neither command's frontmatter carries the new entry; (2)
the real step 2 never says `skip` - the step text the Contract describes ("on
`skip`, paste the script's line into `## Notes`") clears it; (3) step 2 does
not call the script; (5) complete-story's bullet does not name it. All 117
fixture cases pass, every pre-existing case with its expected lines unchanged.

**What each new test asserts.**

- `selftest-needed` - see `## Test plan`'s table: one row per case, each run
  twice (root, `src/`), 3-4 assertions per run. AC-1: rows 1-6; AC-2: rows 9-10
  with row 6 as its control; AC-3: rows 11-15; Contract-only: rows 7, 8, 16.
- `procedure`, block "HARNESS-075 AC-4" (20 cases, all AC-4): the three
  controls the AC names (`needed-missing`, `needed-later-step`,
  `needed-tool-advance`/`-complete`), and the refinements listed in
  `## Test plan`.

**The interface the tests already pin (stated as fact).**

- `scripts/selftest-needed.sh`, run as `bash <fixture>/scripts/selftest-needed.sh [base-ref]`
  with cwd = fixture root or `<root>/src`. It must find `.claude/hooks/lib.sh`
  relative to ITS OWN location, and the repo through git from the cwd (the
  not-a-checkout case copies `scripts/`, `.claude/hooks/`, `.claude/harness/`
  into a plain directory and sets `GIT_CEILING_DIRECTORIES`).
- stdout: exactly one line, the Contract's shapes byte for byte:
  `selftest-needed: run — N harness path(s) changed against <base> (merge-base <short>): p1, p2, p3[, +K more]`,
  `selftest-needed: skip — no harness path among N changed path(s) against <base> (merge-base <short>); CI runs the self-test on the PR`,
  `selftest-needed: run — cannot compute the diff: <reason>; defaulting to run`.
  `<short>` is compared against `git rev-parse --short <ref>` of the base's
  tip, which here is the merge-base; use `git rev-parse --short <mb>`, not a
  fixed-width `cut`.
- exit 0 run, 1 skip, 2 usage (two args, or one beginning `-`); usage message
  on stderr, stdout empty.
- stderr EMPTY on every run/skip path, including runs where the fixture has
  staged, unstaged, deleted and untracked files - silence git's stderr the way
  `gates.sh:991-992` does. Not asserted on the fail-toward-run paths.
- The changed count `N` in `skip` counts the `sort -u` set, including
  `vendor/lib.js` (tracked) and excluding an ignored untracked file.
- Path order in the list is `sort -u`'s; the fixtures use `scripts/a.sh`..
  `scripts/d.sh`, whose order is locale-independent.

Not constrained: the internals (a `lib.sh` helper vs twelve duplicated lines;
whether `$1` is verified before `merge-base`), the stderr text of the usage
error and of the fail-toward-run paths, and the behaviour with an explicit
base that does not resolve (no case; the Contract does not say).

**Negative controls - expected values.** In RED no assertion in
`selftest-needed` exercised a real script. I measured the controls OUTSIDE the
repository: a candidate `selftest-needed.sh` written in the session scratchpad
(never in this tree), dropped into a scratch copy of `scripts/` + `.claude/`,
with the unchanged suite run from that copy. Candidate: 139 passed, 0 failed.
Each mutation of the candidate, and what the suite measured:

| Mutation of the candidate | Expected | Measured (failed assertions) |
|---|---|---|
| none | 0 red | 139 passed, 0 failed |
| `$1=="harness"` -> `$1=="harnessX"` (no path is harness) | AC-1 cases + AC-2 control + both "run" base cases red; plain skip, zero, AC-3 green | 40 failed: 10 cases x 4; plain skip and zero-change green |
| `$1=="harness"` -> `$1=="docs"` (DV-1's expression as written) | as above | 42 failed: as above, **plus the plain AC-2 skip red** (4), mixed control 2 |
| decide by `changed` empty instead of `harness` empty | the skip cases red | 12 failed: plain skip, explicit-base control, origin/main control |
| no `cd` to the top level | untracked from `src/` red | 2 failed: the untracked case from subdir |
| `for b in main origin/main` | origin/main case red | 4 failed |
| `$1` ignored | explicit-base case + its `$1=main` control red | 8 failed |
| `ls-files --others` dropped | untracked case red | 4 failed |
| `+N more` dropped | four-path case red | 2 failed |

These are claims about the candidate, not the shipped script; GREEN confirms
the unmutated row (139/0) and GATES' DV-1 confirms one mutant row against the
real file. Timings above are local (Windows/Git Bash), none from CI.

**The `procedure` guard's new checks, probed** (`scripts/mutate.sh` on the
test file, restored and verified by it):

    === mutate: .claude/tests/procedure.test.sh (1 line(s) changed by s/  has_entry "\$TOOL_NEEDED" || printf/  true || printf/) ===
        FAIL control: advance-story's allowed-tools without the entry gives exactly one line naming the file and the entry
        FAIL control: complete-story's allowed-tools without the entry gives exactly one line naming the file and the entry
        FAIL the entry spelled without `:*` does not count
        FAIL the entry only in the body, not the allowed-tools line, does not count
        FAIL the lacks line prints after the two existing "do not permit" lines
        FAIL no entry, no call, no `skip` in either command gives five lines: ...
    procedure: 111 passed, 7 failed
    === mutate: command exited 1; restored (verified byte-for-byte ...) ===

    === mutate: ... (s/if \[ "\$K" != "-1" \] \&\& \[ "\${SN\[\$K\]}" -gt "\${SN\[\$ks\]}" \]; then/if false; then/) ===
        FAIL control: selftest-needed.sh named in a LATER step than the self-test gives exactly one "names … after" line
             expected: .claude/commands/advance-story.md: names `bash scripts/selftest-needed.sh` after `SELFTEST_JOBS=4 bash scripts/selftest.sh`
             actual:   .claude/commands/advance-story.md: its step 2 does not name `bash scripts/selftest-needed.sh`
    procedure: 116 passed, 2 failed
    === mutate: command exited 1; restored (verified byte-for-byte ...) ===

(The other red in each is the real-tree assertion, red anyway in RED.)

**Discovered - changes for later phases.**

1. **DV-1's mutation expression, as written, contradicts DV-1's own expected
   reading.** `s/"harness"/"docs"/` makes `docs/wiki/x.md` a "harness" path, and
   the AC-2 skip fixture carries `docs/wiki/x.md` (AC-2 lists docs among the
   skip paths, and its control is "the same source/test/docs paths"). So under
   that mutant the plain AC-2 skip goes RED, not green (measured above). DV-1
   already says "adjust the expression ... name it": GATES should replace
   `"harness"` with a category no path has (e.g. `"harnessX"`), which measured
   exactly the reading DV-1 describes. I did not edit DV-1 (not my section).
2. **The real step 2 needs the word `skip`** - not just the call. The Contract's
   step text has it; the brief's expected RED list did not mention it.
3. The `gates.sh --fast` run: every gate is UNCONFIGURED in this repository
   (`BOOTSTRAPPED=no`); the harness self-test is the judge. It reported the new
   suite as untracked (to be staged with the RED commit). `check-sigpipe.sh`
   and `check-grep-count.sh` tree-wide: 0 findings with the new suite present.

**Deferred verifications.** DV-1 and DV-2 are owned by GATES and need the real
`scripts/selftest-needed.sh`, which RED cannot write; I did not run them and
decline both here, in writing. The candidate measurements above are not DV-1:
they are against a scratch candidate, not the shipped file and not the real
branch.

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

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-27T00:22:51Z
    commit: 80c6543
    tree:   7c3ce47d04b1bc0794a8f13bc23ab1e4e08b7dd7
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
- **PO checks before RED (2026-10-26).** Dependencies HARNESS-072, 073 and 074
  are DONE. Verified against today's tree: `gates.sh:984-993` is the
  enumeration the Contract mirrors (`for b in origin/main main`, `merge-base`,
  `diff --name-only` plus `ls-files --others --exclude-standard`, `sort -u`,
  `classify_stdin`); note that `gates.sh` falls back to the base itself when
  `merge-base` fails, whereas this story's AC-3 answers `run` - a deliberate
  difference, not a copy error. `classify.sh` gives the categories Context
  names (`scripts/x.sh`, `.claude/tests/project-x.test.sh`,
  `.github/workflows/ci.yml`, `CLAUDE.md`, `.claude/settings.json`,
  `.gitignore` all `harness`; `src/app.ts` `source`; `src/app.test.ts`
  `test`; `docs/wiki/x.md` `docs`; `package.json` `manifest`; `.dockerignore`
  `config`). `classify_stdin` is at `.claude/hooks/lib.sh:1257`.
  `scripts/selftest-needed.sh` does not exist. One stale figure in Context:
  the 4-job self-test was planned at "about 6 minutes"; HARNESS-073 and 074
  measured 751 s and 702 s on this host. Gate holding the artefact: the
  harness self-test; `required_gates` stays empty; `epic:` empty; no changed
  signatures.
- **RED verified by the orchestrator (2026-10-26).** Reran both suites:
  `selftest-needed: 6 passed, 133 failed` (every script call exits 127 -
  `scripts/selftest-needed.sh` does not exist; the 6 passing are two fixture
  preconditions and four usage-error companions a missing script also
  satisfies, each paired with a red `exits 2`), and
  `procedure: 117 passed, 1 failed`, the real-tree assertion printing exactly
  five AC-4 lines (both commands lack the `allowed-tools` entry; advance-story's
  step 2 does not name the script and does not say `skip`; complete-story's
  bullet does not name it). Floors `selftest-needed 139` and `procedure 118`
  in both `floors.conf` and `selftest.test.sh`. `scripts/`,
  `.claude/commands/` and `CLAUDE.md` untouched (`git diff --quiet HEAD`);
  `mutate.sh --check` clean. Resolved model: RED `test-developer` on Opus 5.5
  (`claude-opus-5-5`), its declared `opus`, no override.
- **PO correction to DV-1 (2026-10-26), found by RED.** DV-1's mutation
  `s/"harness"/"docs"/` contradicts its own expected result: AC-2's skip
  fixture must hold a `docs` path, so under that mutant the plain skip case
  also answers `run` and goes red. Checked by reasoning against the Contract
  (the skip fixture's `docs/wiki/x.md` would match `$1=="docs"`). GATES uses a
  category no path has instead, e.g. `s/"harness"/"harnessX"/`: every harness
  change is then judged `skip`, the AC-1 cases and the AC-2 control go red,
  and the plain skip and zero-change cases stay green (RED measured 40 failed
  on its scratch candidate; to be confirmed against the shipped script).
- **GREEN verified by the orchestrator (2026-10-26).** Feature-developer
  (resolved: Opus 5.5, `claude-opus-5-5`, its declared `opus`, no override)
  wrote `scripts/selftest-needed.sh`, the two command files and the
  `CLAUDE.md` line; `lib.sh`, `gates.sh` and every test file untouched.
  Orchestrator reran: `selftest-needed: 139 passed, 0 failed` (RED's
  unmutated control row, 139/0, confirmed against the shipped script),
  `procedure: 118 passed, 0 failed`, `shipped-docs` 14/14, floors met.
  DV-1's mutation targets the one `"harness"` literal, in the decision line
  `awk -F'\t' '$1 == "harness" { print $2 }'`; use `s/"harness"/"harnessX"/`
  per the correction above.
- **Resolved (user approved the amendment, 2026-10-26; see `## Amendments`):
  AC-5 as worded cannot be observed (2026-10-26), found by GREEN,
  reproduced by the orchestrator.** AC-5 (and DV-1's first reading) say the
  real-branch line "names `scripts/selftest-needed.sh` among the harness
  paths". The Contract pins the list to the first three paths in `sort -u`
  order then `, +N more`, and the suite pins that with `assert_eq`; `.claude/`
  and `CLAUDE.md` sort before `scripts/`, so on this branch the script is the
  8th of 8 and falls inside `+5 more`. Reproduced independently by feeding the
  same enumeration to `classify.sh --only harness` (not the subagent's probe):

      selftest-needed: run — 8 harness path(s) changed against origin/main (merge-base 1282a65): .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/tests/floors.conf, +5 more
      ... classify.sh --only harness: 8 paths, the last scripts/selftest-needed.sh

  The script counts the path; only the AC's observable is wrong. Proposed
  `## Amendments` entry, awaiting the user: AC-5 to read "answers `run`, and
  `scripts/selftest-needed.sh` is among the harness paths it counts (shown by
  `classify.sh --only harness` over the same enumeration, pasted beside the
  line)". Must be settled before GATES runs DV-1.
