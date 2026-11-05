---
id: HARNESS-094
title: The pre-PR self-test runs only the suites the story's diff can break
slug: the-pre-pr-self-test-runs-only-the-suite
epic: 
type: feature
status: in-progress
phase: RED
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
  changed `.claude/tests/_lib.sh`, `.claude/tests/_spawns.sh`,
  `.claude/hooks/lib.sh` or `scripts/selftest.sh`, then stdout is exactly
  the one line `all` and stderr says which path made it so. *[Amended at
  GATES, AM-1: `.claude/hooks/lib.sh` added.]*
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
  printed even though its source never mentions the path: a `*.sh` under
  `scripts/` or `.claude/hooks/` that R1 or R3 also maps prints `lib`,
  `sigpipe` and `grep-count` beside what R1 or R3 selected; such a `*.sh`
  elsewhere under `.claude/` prints `sigpipe` and `grep-count` and not
  `lib`; any path under `.claude/skills/stack-profiles/reference/` prints
  `profiles`; any `*.md` under `.claude/commands/`, `.claude/agents/` or
  `.claude/skills/` prints `shipped-docs`. A changed `.md` under
  `.claude/skills/` that no suite mentions prints `shipped-docs` (and
  `policy` if mentioned there) and **not** `all` (the control: those rows
  are a mapping, so the path is not unmapped). A changed `*.sh` that only
  the `*.sh` rows match (the control: a new `.claude/tests/_helpers.sh`
  that no suite mentions) prints exactly `all`, with stderr naming it as
  mapped by no rule: those rows are additive, a portability scan that says
  nothing about who runs the file. *[Amended at GATES, AM-2: the `*.sh`
  rows no longer count as mapping a path.]*
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
  exit 0, and the fallback's existing reason text on **stderr**, in the
  `all:` shape of *Output* below:
  `selftest-needed: suites — all: cannot compute the diff: <the existing reason>; defaulting to every suite`.
  No harness path: nothing on stdout, exit 1, the existing `skip` line on
  stderr.
  *[Amended in RED, A-2: this bullet said "the fallback's existing one-line
  text", which is `selftest-needed: run — cannot compute the diff: ...;
  defaulting to run`, while *Output* shows the `suites — all: ...; defaulting
  to every suite` shape for the same case. The two contradict, and only the
  second composes with `selftest.sh --changed`, whose every-suite header
  carries "`--suites`'s reason after `every suite: `" - i.e. the text after
  `all: `. The tests pin the *Output* shape: whole line for no base, no merge
  base and not a git checkout; prefix `selftest-needed: suites — all: cannot
  compute the diff: ` and suffix `; defaulting to every suite` for the
  library and `paths.conf` fallbacks, whose reason embeds a fixture path.]*
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
  - **A-1, a rule names only a suite that exists** *[amended in RED]*. R1, R3
    and R4 contribute `<name>` only when `.claude/tests/<name>.test.sh`
    exists in the working tree the script runs in; a harness `p` for which no
    rule contributes an existing suite is R5's (`all`). Reason: a suite
    deleted on the branch matches R1 by its path, and a scanner row names its
    suite whatever the tree holds; printing either hands
    `selftest.sh --changed` a name that its multi-name path must refuse with
    `No suites matched` (AC-6), so a story that deletes a suite could never
    run `--changed` at all. Pinned by the A-1 case in
    `selftest-needed.test.sh`: a committed deletion of the fixture's
    `gamma.test.sh` prints `grep-count` and `sigpipe` (R4 `*.sh`, both
    present), not `gamma`, and counts 8 suites. The scanner-row half (a row
    whose suite is absent) follows from the same sentence and has no case of
    its own. *[Superseded in part by A-5: under it, that deletion is
    `all`, because only the additive `*.sh` rows match it.]*
  - **A-4, the harness library is read by every suite** *[amended at
    GATES, AM-1]*. R2 also names `.claude/hooks/lib.sh`. It is sourced by 11
    files in `scripts/` and `.claude/hooks/` (`gates.sh`, `phase.sh`,
    `plan.sh`, `story.sh`, `classify.sh`, `check-boundaries.sh` among them),
    and most suites run one of those. Before this amendment, one comment line
    added to it selected 15 of 34 suites (`## Diff review`, finding 1).
  - **A-5, the `*.sh` scanner rows are additive** *[amended at GATES,
    AM-2]*. The rows `lib`, `sigpipe` and `grep-count` still add their suite
    for every path they match, but they no longer count as mapping the
    path. A harness `p` that R1, R3 and the remaining rows (`profiles`,
    `shipped-docs`) all miss is R5's `all`, whatever the `*.sh` rows added.
    `profiles` and `shipped-docs` stay mapping rows: each one names the one
    suite that reads its directory. Reason: the `*.sh` rows are portability
    scans over every shell file and say nothing about which suite runs the
    file. Before this amendment, a new `.claude/tests/_helpers.sh` sourced
    by relative name selected 2 of 34 suites, while `_helpers.conf` in the
    same place selected `all` (`## Diff review`, finding 2). The `A-1` case
    (a committed deletion of `gamma.test.sh`) is now `all`. Its old
    expectation was a consequence of the `*.sh` rows mapping, and it changes
    with them.
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
  stderr. *[Amended in RED, A-3: streams. The header line (both shapes) and
  the `selected no suite` line go to **stdout** - AC-7 calls the header "one
  stdout line", and the no-suite line is the same kind of answer; the test
  pins stdout as exactly that one line and does not pin stderr there. The
  `cannot select` line goes to **stderr**, nothing on stdout; the test pins
  exit 2, empty stdout and the prefix `selftest: --changed cannot select: `
  of stderr's first line, not the usage text after it.]* Totals and the last line count the suites that ran, so a selected
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

**DV-1 result (GATES, 2026-11-04, orchestrator).**

1. Real tree, branch tip `de27810` plus this story file:

```
$ bash scripts/selftest-needed.sh --suites
selftest-needed: suites — all: scripts/selftest.sh is read by every suite
all
exit=0
```

2. Narrow base. **Finding: the commit DV-1 asks for does not exist on this
branch.** GREEN changed `scripts/selftest.sh` in the same commit (`950aa5e`)
as `selftest-needed.sh`, `CLAUDE.md` and `VERSION`. `--suites` diffs against
`git merge-base <base> HEAD`, so the base must be an ancestor. I built one in
a throwaway `--no-hardlinks` clone in the session scratchpad, not in this
worktree:

- C1 `c967d65` = merge-base `cb6a5cb` + the tip's `scripts/selftest.sh` only;
- C2 `5cd48b3` = C1 + the rest of the tip.

`git diff de27810 C2` was empty: C2's tree is the branch tip's.

```
$ git diff --name-only C1 C2
.claude/harness/VERSION
.claude/tests/floors.conf
.claude/tests/selftest-needed.test.sh
.claude/tests/selftest.test.sh
CLAUDE.md
docs/backlog/stories/HARNESS-094.md
scripts/selftest-needed.sh
$ bash scripts/selftest-needed.sh --suites c967d652dd579f2909a4fb4c99c45d2aa828ce66
selftest-needed: suites — 21 of 34 selected from 6 harness path(s) changed against c967d652dd579f2909a4fb4c99c45d2aa828ce66 (merge-base c967d65)
  attest           CLAUDE.md (mentioned)
  boundaries       .claude/harness/VERSION (mentioned)
  dispatch         scripts/selftest-needed.sh (mentioned)
  doctor           .claude/harness/VERSION (mentioned)
  grep-count       .claude/tests/selftest-needed.test.sh (scans *.sh)
  host-load        .claude/tests/floors.conf (mentioned)
  lib              CLAUDE.md (mentioned)
  mutate           CLAUDE.md (mentioned)
  phase-guard      CLAUDE.md (mentioned)
  plan             CLAUDE.md (mentioned)
  procedure        scripts/selftest-needed.sh (mentioned)
  refresh          .claude/harness/VERSION (mentioned)
  reporting        CLAUDE.md (mentioned)
  rules-trim       CLAUDE.md (mentioned)
  run-lock         .claude/tests/floors.conf (mentioned)
  selftest         .claude/tests/floors.conf (mentioned)
  selftest-needed  .claude/tests/selftest-needed.test.sh (itself)
  shipped-docs     CLAUDE.md (mentioned)
  sigpipe          .claude/tests/selftest-needed.test.sh (scans *.sh)
  story            CLAUDE.md (mentioned)
  worktree         .claude/harness/VERSION (mentioned)
(stdout: the same 21 names, one per line; exit=0)
```

Every expected suite is in the list: `selftest-needed`, `selftest`, `lib`,
`sigpipe`, `grep-count`, and the Baseline's eight `CLAUDE.md` suites. A suite
selected by several rules is shown with the first reason found.

**Finding: the prototype under-counted the `CLAUDE.md` mentions.** It listed
`attest lib mutate refresh reporting selftest-needed shipped-docs story`.
`grep -lF CLAUDE.md .claude/tests/*.test.sh` on this tree also finds:

- `phase-guard`, `plan`, `rules-trim`, `sigpipe` and `worktree`;
- every one of them a mention in a comment (for example `phase-guard.test.sh:8`,
  `plan.test.sh:2129`, `rules-trim.test.sh:4`).

R3 is a fixed-string mention by contract, so comments count. That is the safe
direction: it over-selects, it never under-selects. This is not adjusted away.
It is recorded as a cost that DV-2 will measure.

3. Defect put back. R5 is line 229, as GREEN wrote it:
`[ "$hit" = 1 ] || [ -n "$why_all" ] || why_all="$p is mapped by no rule; defaulting to every suite"`.

```
$ bash scripts/mutate.sh scripts/selftest-needed.sh '229s/.*/    : # R5 removed/' -- bash scripts/selftest.sh selftest-needed
=== mutate: scripts/selftest-needed.sh (1 line(s) changed by 229s/.*/    : # R5 removed/) ===
    FAIL the control: a new .claude/harness/x.conf that no rule maps, beside a mapped m.conf, prints all and names x.conf [from root]: stdout is exactly the pinned list
    FAIL the control: a new .claude/harness/x.conf that no rule maps, beside a mapped m.conf, prints all and names x.conf [from root]: stdout has exactly 1 line(s)
    FAIL the control: a new .claude/harness/x.conf that no rule maps, beside a mapped m.conf, prints all and names x.conf [from root]: stderr is exactly the pinned text
    FAIL the control: a new .claude/harness/x.conf that no rule maps, beside a mapped m.conf, prints all and names x.conf [from subdir]: stdout is exactly the pinned list
    FAIL the control: a new .claude/harness/x.conf that no rule maps, beside a mapped m.conf, prints all and names x.conf [from subdir]: stdout has exactly 1 line(s)
    FAIL the control: a new .claude/harness/x.conf that no rule maps, beside a mapped m.conf, prints all and names x.conf [from subdir]: stderr is exactly the pinned text
selftest-needed: 452 passed, 6 failed
FAIL selftest-needed  did 452 units of work, below the floor of 458 in .claude/tests/floors.conf
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_selftest-needed.sh.20261105T024435Z.1403.bak) ===
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

Only AC-3's unmapped control went red, from the repository root and from a
subdirectory. The other 452 assertions passed, AC-1's cases among them.

The run took about 25 minutes, against 71 to 676 s before. A
`manga-translator` gate run under pytest coverage was sharing the host at the
time. DV-1 is discharged.

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

- **AM-1 (AC-2), 2026-11-04, approved by the user ("Fix both").**
  - **What changes:** AC-2's list of paths that give `all` gains
    `.claude/hooks/lib.sh`.
  - **Before:** "Given a changed `.claude/tests/_lib.sh`,
    `.claude/tests/_spawns.sh` or `scripts/selftest.sh`, then stdout is
    exactly the one line `all` ..."
  - **After:** the same sentence, with `.claude/hooks/lib.sh` added to the
    list.
  - **Why:** the GATES diff review, finding 1, reproduced by the
    orchestrator. A change to the library that 11 harness scripts source
    selected 15 of 34 suites, which would let a `lib.sh` change that breaks
    `plan.sh` pass `--changed`. Contract A-4.
- **AM-2 (AC-4), 2026-11-04, approved by the user ("Fix both").**
  - **What changes:** the `*.sh` scanner rows (`lib`, `sigpipe`,
    `grep-count`) become additive: they add their suite but do not map a
    path.
  - **Before:** "any `*.sh` under `scripts/` or `.claude/hooks/` prints
    `lib`, `sigpipe` and `grep-count`; any `*.sh` elsewhere under `.claude/`
    prints `sigpipe` and `grep-count` and not `lib`; ... (the control: the
    table is a mapping, so the path is not unmapped)."
  - **After:** those prints hold for a `*.sh` that R1 or R3 also maps. A
    `*.sh` matched only by the `*.sh` rows is `all`, with a new control (an
    unmentioned `.claude/tests/_helpers.sh`). The `.md` and `profiles`
    clauses, and the `.md` control, are unchanged.
  - **Why:** the GATES diff review, finding 2, reproduced by the
    orchestrator. No shell file could ever reach R5, so a new helper sourced
    by relative name selected 2 of 34 suites. The user chose this over
    filing it as a separate story because HARNESS-095 makes `--changed` the
    pre-PR run. Contract A-5.

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
- GATES, `feature-developer` (full `gates.sh`): `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own `model:`; no override. 2026-11-04. `attest.sh check` returned `fresh` with exit 0 and `All required gates passed (0 ran, 7 unconfigured, 0 known).` This repository has `BOOTSTRAPPED=no`, so the self-test is the verification that counts.

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

All shell, at the level the contract lives: each case runs the fixture's
copy of the real script in a throwaway git repository and compares exit
status, whole stdout and pinned stderr. No unit level exists below that for
a bash script. Everything is mechanical, so there are no thresholds.

**`.claude/tests/selftest-needed.test.sh`**, seven describes marked
`HARNESS-094` before `summary`. Fixture: `suites_stubs` writes nine one-line
stub suites into the fixture's `.claude/tests` and commits them on `main`:
alpha and beta mention `.claude/harness/m.conf`, beta also `n.conf`, alpha also
`scripts/probes/x.sh`, `.claude/hooks/x.sh` and `.claude/foo/x.sh` (added on
the return from GATES, R-2), policy
mentions `.claude/skills/foo/SKILL.md`, and gamma, grep-count, lib, profiles,
shipped-docs and sigpipe mention nothing. `expect_suites` runs from the root
and from `src/`, four assertions each.

| AC | Case (assertion label, abridged) | Pinned stdout |
|---|---|---|
| AC-1 | committed `n.conf` mentioned only by beta; controls: alpha and gamma absent | `beta` |
| AC-1 | STAGED `m.conf` + UNTRACKED `n.conf`; `(mentioned)` reason lines for alpha and beta (beta's FIRST path, m.conf) | `alpha` `beta` |
| AC-2 | edited `.claude/tests/gamma.test.sh`; `(itself)` reason line | `gamma` `grep-count` `sigpipe` |
| AC-2 | new untracked `delta.test.sh`; header counts 10 suites | `delta` `grep-count` `sigpipe` |
| AC-2 | `_lib.sh` beside a mapped `n.conf` (all wins) | `all` + whole stderr |
| AC-2 | `_spawns.sh` | `all` + whole stderr |
| AC-2 | edited `scripts/selftest.sh` | `all` + whole stderr |
| AC-2 | **AM-1**: edited `.claude/hooks/lib.sh` | `all` + whole stderr `... is read by every suite` |
| AC-3 | **control**: unmapped `x.conf` beside mapped `m.conf` | `all`, stderr names x.conf |
| AC-3 | **control for the control**: `m.conf` alone | `alpha` `beta` |
| AC-3 | no origin/main or main; no merge base; not a git checkout | `all`, whole stderr line |
| AC-3 | lib.sh trips `set -u`; paths.conf missing (prefix+suffix of the fallback line) | `all` |
| AC-4 | `scripts/probes/x.sh` (depth), which alpha mentions (AM-2 rework); `(scans scripts/*.sh)` reason line | `alpha` `grep-count` `lib` `sigpipe` |
| AC-4 | `.claude/hooks/x.sh`, which alpha mentions (AM-2 rework) | `alpha` `grep-count` `lib` `sigpipe` |
| AC-4 | `.claude/foo/x.sh`, which alpha mentions (AM-2 rework); control: lib absent | `alpha` `grep-count` `sigpipe` |
| AC-4 | **AM-2 control**: untracked `.claude/tests/_helpers.sh`, no mention | `all`, whole stderr `... is mapped by no rule; ...` |
| AC-4 | **AM-2**: new `scripts/newtool.sh`, no mention | `all`, whole stderr `... is mapped by no rule; ...` |
| AC-4 | `.claude/skills/stack-profiles/reference/x.txt` | `profiles` |
| AC-4 | `.claude/commands/x.md` + `.claude/agents/x.md` | `shipped-docs` |
| AC-4 | **control**: `.claude/skills/bar/deep/notes.md`, no mention | `shipped-docs` (not `all`) |
| AC-4 | `.claude/skills/foo/SKILL.md`, which policy mentions | `policy` `shipped-docs` |
| AC-5 | source-only diff | empty, exit 1, whole skip line on stderr |
| AC-5 | `--suites release`; control: `--suites` on the same fixture | `beta`; empty, exit 1 |
| AC-5 | `--suites -x`, `--suites main extra`, `main --suites` | exit 2, empty, stderr non-empty |
| AC-5 | no `--suites`, a fixture with suites: the unchanged run line (existing `expect`) | the run line |
| A-1 | committed DELETION of `gamma.test.sh` (changed by A-5: was `grep-count` `sigpipe`, 8 suites) | `all`, whole stderr `... gamma.test.sh is mapped by no rule; ...` |
| AC-8 | the two lines directly after the existing `selftest-needed.sh` line of the real `CLAUDE.md`, each exactly once | - |

**`.claude/tests/selftest.test.sh`**, seven describes marked `HARNESS-094`
before `summary`. AC-6 runs in `$FIX` via `passing_suite`/`jrun`; AC-7 builds a
fresh fixture per case with `cf_new` (alpha 3 and gamma 1 mention `m.conf`,
beta 2 mentions nothing; committed on `main`, `.claude/state/` ignored) and
runs it with `crun`.

| AC | Case | What is pinned |
|---|---|---|
| AC-6 | `selftest.sh gamma alpha`, beta unfloored, a non-floor line in the file | exit 0, whole stdout golden (alpha block, then gamma's, floors line, `2 harness suite(s) passed.`), empty stderr; **controls**: no beta block; a full run over the same file exits 1 with `2 fault(s) ...` |
| AC-6 | `selftest.sh alpha beta` | exit 0; stderr exactly beta's two WARNING lines; floors line `all 1 suite(s) ... (3 ... 3 ...)`; last line `2 harness suite(s) passed.` |
| AC-6 | `selftest.sh alpha gamma`, both below floor | exit 1; both `FAIL <name>  did ...` lines; `2 of 2 harness suite(s) FAILED.` |
| AC-6 | `selftest.sh alpha nosuch` | exit 1; stderr exactly `No suites matched 'nosuch'. ...`; empty stdout; no lock left |
| AC-7 | `--changed`, new `m.conf` | exit 0; whole stdout golden with the header line first; **control** no beta block; alpha's `(mentioned)` line on stderr; `SELFTEST_JOBS=3` exits 0 with byte-identical stdout |
| AC-7 | **control**: `--changed`, beta's floor `lots` committed on main, beta not selected | exit 1; stdout exactly the full-run fault report; `selftest.sh alpha gamma` on the same fixture exits 0 |
| AC-7 | `--changed`, unmapped `x.conf` | exit 0; line 1 is the every-suite header; lines 2.. byte-identical to a plain full run (which exits 0, precondition) |
| AC-7 | `--changed`, source-only diff | exit 1; stdout exactly the `selected no suite — <skip line>` line; no lock left |
| AC-7 | `--changed release`; control `--changed` | exit 0, header selects alpha gamma, last line `2 harness suite(s) passed.`; control exit 1 |
| AC-7 | `--changed -x` | exit 2; empty stdout; stderr line 1 begins `selftest: --changed cannot select: ` |

## Handoff: RED -> GREEN

Model: this RED ran on **Opus 5.5 (`claude-opus-5-5`)**, the agent's own
`model:` (`opus`); no override was reported to the dispatch.

**Commands.**

    bash scripts/selftest.sh selftest-needed
    bash scripts/selftest.sh selftest

Attested in RED (tree `f6819294ec31854b4bef4ae031d0c9c2329594e3`, local
Windows/Git Bash host):

    bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed
      exit: 1   duration: 474s   last: 1 of 1 harness suite(s) FAILED.
      log:  .claude/state/attest-logs/20261104T205156Z.173145.log
    bash scripts/attest.sh -- bash scripts/selftest.sh selftest
      exit: 1   duration: 285s   last: 1 of 1 harness suite(s) FAILED.
      log:  .claude/state/attest-logs/20261104T205957Z.184706.log
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
      exit: 0   duration: 4s     last: All required gates passed (0 ran, 5 unconfigured, 0 known).
      log:  .claude/state/attest-logs/20261104T210509Z.194663.log

`gates.sh --fast` runs no gate here (all unconfigured), as expected; its
shape says nothing about the suites. `check-sigpipe.sh` and
`check-grep-count.sh` were also run over the tree with the new files: 0
findings each.

**The failure, and why it is the right one.** Every pre-existing assertion
in both suites passes (0 FAIL before the first `HARNESS-094` describe in
either log). Every new failure is the absent mode or flag: `--suites` is a
`-`-prefixed argument today, so `selftest-needed.sh` exits 2 with its usage
line; `selftest.sh` reads only `$1`, so a second name is ignored and
`--changed` is a suite name that matches nothing.

```
  HARNESS-094 AC-1: --suites prints the suites whose source mentions a changed path
    FAIL a committed .claude/harness/n.conf, mentioned only by beta, prints beta [from root]: exits 0
         expected: 0
         actual:   2
    FAIL a committed .claude/harness/n.conf, mentioned only by beta, prints beta [from root]: stdout is exactly the pinned list
         expected: beta
         actual:   
    FAIL a committed .claude/harness/n.conf, mentioned only by beta, prints beta [from root]: stderr's first line is exactly the pinned header
         expected: selftest-needed: suites — 1 of 9 selected from 1 harness path(s) changed against main (merge-base 207d52d)
         actual:   usage: bash scripts/selftest-needed.sh [base-ref]
...
  HARNESS-094 AC-8: CLAUDE.md's command list names both, directly after the selftest-needed.sh line
    FAIL the two lines directly after it are the --suites line, then the --changed line
         expected: bash scripts/selftest-needed.sh --suites   # which suites that diff can break, one per line, or `all`
         SELFTEST_JOBS=4 bash scripts/selftest.sh --changed   # run exactly those; the local self-test before a PR (HARNESS-095 switches the procedure to it)
         actual:   bash scripts/gates.sh            # all gates
         bash scripts/gates.sh --fast     # every gate not marked `slow` — for RED and GREEN

selftest-needed: 259 passed, 199 failed
FAIL selftest-needed  did 259 units of work, below the floor of 458 in .claude/tests/floors.conf
```

```
  HARNESS-094 AC-6  two names run exactly those two, in glob order, with no whole-file audit
    FAIL and its stdout is alpha's block then gamma's (glob order, not argument order), one floors line, 2 passed
         expected: identical
         actual:   differ:
         2,5d1
         < === alpha ===
         ...
         > assertion floors: all 1 suite(s) met their declared floor (1 assertions executed, 1 declared).
         > 1 harness suite(s) passed.
  HARNESS-094 AC-7  --changed runs the selected suites after one header line
    FAIL `selftest.sh --changed` with a new m.conf exits 0
         expected: 0
         actual:   1
  HARNESS-094 AC-7  --changed whose selection fails is exit 2
    FAIL `--changed -x` (a usage error from --suites) exits 2
         expected: 2
         actual:   1
    FAIL and stderr's first line says it cannot select
         expected: selftest: --changed cannot select: 
         actual:   No suites matched '--changed'. Look

selftest: 288 passed, 21 failed
FAIL selftest  did 288 units of work, below the floor of 309 in .claude/tests/floors.conf
```

**Files touched.** `.claude/tests/selftest-needed.test.sh`,
`.claude/tests/selftest.test.sh` (a new block, plus `selftest 309` and
`selftest-needed 458` in the hand-copied COUNTS table),
`.claude/tests/floors.conf` (the two floors and a HARNESS-094 note), and this
story (`## Contract` amendments A-1..A-3, `## Test plan`, this handoff).
`CLAUDE.md` is classified `harness`, so RED could have written it. It is left
to GREEN as instructed, which is why AC-8's three assertions are red now.

**Floors, and how they were derived.** Both are the executed counts of the
RED runs above. Both suites are unconditional (every case runs, and every
assertion executes whatever the result), so RED's count is GREEN's.
- `selftest-needed` 216 -> **458**. The floor lagged the suite: 226 executed
  before this story on this host (`selftest-needed: 226 passed, 0 failed` in
  six earlier attest logs). +232 new, measured: 259 passed + 199 failed = 458.
  Per describe: AC-1 20, AC-2 41, AC-3 60, AC-4 58, AC-5 41, A-1 8, AC-8 4.
  The HARNESS-078 AC-5 block is skipped on MINGW, so on CI (Linux) the suite
  executes more than 458. The floor is this host's count, as before.
- `selftest` 268 -> **309**. 268 executed before (13 earlier logs, `268
  passed, 0 failed`). +41 (AC-6 18, AC-7 23), counted statically first and
  confirmed by the run: 288 passed + 21 failed = 309.

**Callers, checked against the tree.** `grep -n '\$ONLY' scripts/selftest.sh`
gives five reads, as the Contract says: line 262 (suite list), 270 (full-run
audit guard), 292 (fault filter), 411 (serial loop), 485 (no-match message),
plus the assignment at 96. `selftest-needed.test.sh`'s usage case is the
describe at line 245 (`run_sn "$d" main extra` at 248). It is untouched and
passes in RED. `procedure.test.sh`, `dispatch.test.sh` and
`.claude/commands/` are unchanged against `main` (`git diff --stat main --`
over them is empty). Of the four suites the Contract says read `CLAUDE.md`,
none pins the command block's line count (static check: `shipped-docs` writes
its own fixture `CLAUDE.md`; `reporting` reads its `## Reporting to the user`
section; `rules-trim` caps `rules.md`, not `CLAUDE.md`; `lib` reads the
`@.claude/harness/rules.md` import). The Contract's "RED confirms by running
those four" cannot apply while `CLAUDE.md` is unedited, so **GREEN runs
`shipped-docs`, `reporting`, `rules-trim` and `lib` after adding the two
lines.**

**Contract amendments made in RED** (in place, each with its reason):
- **A-1**: a rule names a suite only when `.claude/tests/<name>.test.sh`
  exists. A path no rule maps to an existing suite is R5's `all`. Pinned by
  the deleted-gamma case.
- **A-2**: a `--suites` fallback's stderr is the *Output* `all:` shape,
  `selftest-needed: suites — all: cannot compute the diff: <reason>;
  defaulting to every suite`, not the run-mode line. The Enumeration bullet
  and the Output block contradicted each other.
- **A-3**: streams for `--changed`. The header lines and the `selected no
  suite` line go to stdout; `cannot select` goes to stderr with nothing on
  stdout.

**What the tests pin: the interface GREEN must build.**

`scripts/selftest-needed.sh --suites [base-ref]`:
- stdout: sorted unique names one per line, or exactly `all`, or nothing.
  Exit 0 for a list or `all`, exit 1 for nothing, exit 2 for usage.
- stderr header for a list, whole line:
  `selftest-needed: suites — <k> of <m> selected from <p> harness path(s) changed against <base> (merge-base <short>)`,
  where `<m>` is the count of `.claude/tests/*.test.sh` in the tree and `<p>`
  the count of harness paths.
- one stderr line per selected suite: two spaces, the name, one or more
  spaces, then exactly `<path> (<rule>)`. `<rule>` is one of `mentioned`,
  `itself`, `scans <the matched pattern>` (e.g. `scans scripts/*.sh`), and
  `<path>` is the suite's first selecting path in sort order. **Not pinned:**
  the padding width, and the exact rule word for R4's `*.sh` rows (only lib's
  `scans scripts/*.sh` is pinned).
- `all` stderr, whole and alone:
  `selftest-needed: suites — all: <path> is read by every suite` (R2),
  `selftest-needed: suites — all: <path> is mapped by no rule; defaulting to every suite` (R5),
  `selftest-needed: suites — all: cannot compute the diff: <existing reason>; defaulting to every suite` (fallbacks: whole for no base, no merge base and not a git checkout; prefix and suffix for lib.sh and paths.conf).
- no harness path: stderr exactly the existing `selftest-needed: skip — ...` line.
- usage, exit 2, nothing on stdout: `--suites -x`, `--suites main extra`,
  `main --suites`. **Not pinned:** the usage text.
- the run/skip mode: unchanged, all existing cases.

`scripts/selftest.sh`:
- `<a> <b>...`: glob order, the single-suite floor rule per suite, no audit.
  An unknown name gives stderr exactly `No suites matched '<name>'. Looked in
  .claude/tests/*.test.sh`, exit 1, empty stdout, no lock left. **Not
  pinned:** what is printed for two unknown names at once.
- `--changed [ref]`:
  - a list: stdout line 1 is
    `selftest: --changed — <k> of <m> suite(s) selected: <names space-joined>`,
    then the multi-name run.
  - `all`: `selftest: --changed — every suite: <text after "all: ">`, then a
    byte-identical full run.
  - nothing: `selftest: --changed selected no suite — <the skip line>` alone
    on stdout, exit 1.
  - the full-run floors audit comes first: on a fault, the fault report,
    exit 1, no header.
  - `cannot select`: on stderr line 1, exit 2.
  **Not pinned:** stderr in the `all` and nothing cases, and whether the
  `--suites` header line is passed through (only alpha's reason line is
  pinned on stderr).

**Passed on arrival, and what earns each.**

| Suite | Assertions | Why green in RED | What earns it |
|---|---|---|---|
| selftest-needed | 9 usage (exit 2, empty stdout, stderr non-empty) | `--suites` itself is the usage error today | the `--suites release` case in the same describe, which must exit 0 in GREEN; GREEN confirms all 9 stay green beside it |
| selftest-needed | 8, run/skip unchanged with suites present | existing behaviour | regression guard; its control is the `m.conf`-alone `--suites` case, same fixture shape, different answer |
| selftest-needed | AC-5 skip and its release control: stdout empty, 0 lines (8) | stdout is empty on a usage error too | the paired exit-1 and whole-stderr assertions, which are red |
| selftest-needed | controls `out_has` alpha, gamma, lib (3); four preconditions; AC-8 anchor (1) | absent from an empty stdout; fixture facts | the whole-stdout assertion beside each, which is red |
| selftest | AC-6: exit 0, empty stderr, no beta, full-run control (2); `alpha beta` exit and floors line; `alpha gamma` exit 1 and alpha's FAIL; `alpha nosuch` exit 1 (alpha is short of the floor 4 there) and no lock | today's one-name run happens to give them | the whole-stdout / whole-stderr assertion in the same case, which is red |
| selftest | AC-7: no beta block; JOBS=3 stdout identical; audit exit 1 and the `alpha gamma` control; full-run precondition; nothing-case exit 1 and no lock; ref control exit 1; `-x` empty stdout | `--changed` is an unmatched name (exit 1, empty stdout) | the golden / header assertions in the same case, which are red |

None of these needs a mutation in RED. Each sits beside a red assertion in
its own case that GREEN must turn green.

**Negative controls: expected values.** There are no thresholds; each
control is an exact value. Every value below is the fixture's, by
construction. None of them could be measured against a `--suites` that does
not exist, so they are claims until GREEN runs them.

| Control | Expected | Measured in RED |
|---|---|---|
| AC-1: alpha / gamma in the n.conf list | 0 lines each | 0 (vacuous: stdout empty) |
| AC-3: x.conf unmapped beside m.conf | stdout `all`, exit 0, stderr `... x.conf is mapped by no rule; ...` | exit 2, usage |
| AC-3 control for the control: m.conf alone | stdout `alpha` `beta`, exit 0, header `2 of 9 ... 1 harness path(s)` | exit 2, usage |
| AC-4: `.claude/foo/x.sh` has no lib | lib lines 0, stdout `grep-count` `sigpipe` | 0 (vacuous) |
| AC-4: `.claude/skills/bar/deep/notes.md` | stdout `shipped-docs`, not `all` | exit 2, usage |
| AC-5: `--suites` (no ref) on the release fixture | exit 1, empty, skip line | exit 2, usage |
| AC-6: unnamed beta's block | 0 | 0 (vacuous: one suite ran) |
| AC-6: full run over the faulted floors file | exit 1, last `2 fault(s) in .claude/tests/floors.conf. Nothing was run.` | exit 1, that line (green) |
| AC-7: beta block under `--changed` | 0 | 0 (vacuous) |
| AC-7: audit with unselected beta `lots` | exit 1, stdout exactly the 4-line, 2-fault report (`not a number` for beta, `beta  no floor line ...`, blank, `2 fault(s) ...`); corrected under R-1, it said "the 3-line fault report", one fault, which is not what a full run's audit prints | exit 1, empty stdout |
| AC-7: `alpha gamma` over that file | exit 0 | 0 (green) |
| AC-7: `--changed` (no ref) on the release fixture | exit 1 | 1 (vacuous: unmatched name) |

**Deferred verifications.** **DV-1 and DV-2 are owned by GATES, and RED
declines both.** DV-1's defect-put-back mutates `selftest-needed.sh`'s R5
line, which does not exist yet, and DV-2 times a `--changed` run that cannot
run yet. Neither was attempted.

**Found in RED that GREEN and GATES should know.**
- **The Baseline's CLAUDE.md count looks low.** The Contract and DV-1 expect a
  lone `CLAUDE.md` change to select 8 suites (`attest lib mutate refresh
  reporting selftest-needed shipped-docs story`). A fixed-string search of
  `main`'s suites (`git show main:<suite> | grep -qF CLAUDE.md`) finds **13**:
  those eight plus `phase-guard`, `plan`, `rules-trim`, `sigpipe` and
  `worktree`. No test here changes because of it (every list is the
  fixture's). But DV-1's expected real-tree list should be written from R3 as
  specified, not from the Baseline, and the difference recorded as DV-1 says.
- This story's own `selftest-needed.test.sh` now mentions `scripts/selftest.sh`,
  `CLAUDE.md`, `.claude/tests/_lib.sh` and many fixture paths, which widens
  what R3 selects for those paths in the real tree. That over-selection is
  correct. It is noted so that DV-1's list is not a surprise.
- R4's `*.sh` row matches `.claude/tests/<name>.test.sh` too, so a changed
  suite also selects `grep-count` and `sigpipe` (the AC-2 cases pin that).
- Keep R3 to one `grep -lF -f <paths-file>` over the suite files. An empty
  line in the patterns file matches every suite, so strip empty lines.
- In the fixture `selftest.test.sh` uses for AC-7, the scanner suites do not
  exist, so under A-1 a `.sh` change there would be R5's `all`. No case relies
  on that.

**Addendum, return from GATES (R-2, AM-1 / AM-2, 2026-11-05).** RED ran on
Opus 5.5 (`claude-opus-5-5`), the agent's own `model:`; no override was
reported. Only `selftest-needed.test.sh` changed (plus the floor, 482, in
`floors.conf` and `selftest.test.sh`'s table); `selftest.sh` and its suite are
unaffected. Command: `bash scripts/selftest.sh selftest-needed`. RED state:
`selftest-needed: 458 passed, 24 failed`, log
`.claude/state/attest-logs/20261105T033336Z.21603.log` (record: `exit: 1`,
`last: 1 of 1 harness suite(s) FAILED.`); the failing output is in
`## Regressions`, R-2. GREEN changes `scripts/selftest-needed.sh` only:

1. **R2 (`case` near line 207):** add `.claude/hooks/lib.sh` to the
   alternatives, so its reason is `.claude/hooks/lib.sh is read by every suite`
   (the whole stderr line is pinned; reaching `all` via R5 fails). Update the
   header comment that lists R2's files.
2. **R4 loop (near line 222):** a match on a row whose suite is `lib`,
   `sigpipe` or `grep-count` still appends its record but must **not** set
   `hit=1`; `profiles` and `shipped-docs` matches still do. Then a harness
   `.sh` matched by nothing else falls to the existing R5 line,
   `<p> is mapped by no rule; defaulting to every suite`. Any way of telling
   the rows apart is GREEN's choice (a flag column in `SCANS`, or the suite
   name); the tests do not see it. Update the R4 comment to say the `*.sh`
   rows are additive (A-5).
3. Nothing else. The deleted-`gamma.test.sh` case then gives `all` with no
   further change (R1 contributes nothing for an absent file, per A-1).

Expected after GREEN: `selftest-needed: 482 passed, 0 failed`. The cases
pinned: `.claude/hooks/lib.sh` → `all` (R2 reason); untracked
`.claude/tests/_helpers.sh`, new `scripts/newtool.sh`, deleted
`gamma.test.sh` → `all` (R5 reason, naming the path); `scripts/probes/x.sh`
and `.claude/hooks/x.sh`, mentioned by `alpha` → `alpha grep-count lib
sigpipe`; `.claude/foo/x.sh`, mentioned by `alpha` → `alpha grep-count
sigpipe`; a changed `gamma.test.sh` / new `delta.test.sh` (R1) still add
`grep-count sigpipe`. Negative controls, exact values: `_helpers.sh` gives
`all` and not `grep-count sigpipe` (old code measured: `grep-count`
`sigpipe`, `2 of 9`); the `.md` control still gives `shipped-docs`, not
`all` (unchanged, passes today). Note for DV-1: on the real tree the A-5
change makes any `.sh` path no suite names by full path `all`, so DV-1's
expected selections for a diff that touches such a file change with it.

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

### R-1 (GREEN → RED, 2026-11-04): `golden.ac7-audit` expected one fault where the full-run audit reports two

- **Which test:** `.claude/tests/selftest.test.sh`, describe "HARNESS-094 AC-7  --changed audits the whole floors file first". Its assertion "and its stdout is the full run's fault report and nothing else: no header, no suite" compares stdout with `golden.ac7-audit`.
- **What it asserted:** a non-numeric floor for the unselected `beta` gives a one-fault report: `floor for 'beta' is not a number: 'lots'`, then `1 fault(s) in .claude/tests/floors.conf. Nothing was run.`
- **What was wrong:** a full run's audit has always reported two faults in that case. A floor that is not a number is not loaded, so the every-suite loop also reports `beta  no floor line ...`. AC-7 asks for "the whole-file floors audit of a full run", so the golden contradicted its own criterion.
- **How it was found:** GREEN's feature-developer measured it against `HEAD`'s `selftest.sh`. The orchestrator reproduced it independently on a clone of `main`, with a different suite (`doctor`) and value (`many`); `## Notes` holds both. The failing assertion, from `.claude/state/attest-logs/20261104T224009Z.19729.log`:

      FAIL and its stdout is the full run's fault report and nothing else: no header, no suite
           expected: identical
           actual:   differ:
           1a2
           > FAIL beta  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)
           3c4
           < 1 fault(s) in .claude/tests/floors.conf. Nothing was run.
           ---
           > 2 fault(s) in .claude/tests/floors.conf. Nothing was run.

- **What it asserts now:** (test-developer, claude-opus-5-5) `golden.ac7-audit` is the full run's two-fault report, the text `selftest.sh`'s audit prints at lines 212 and 379 and the summary at 402: `FAIL .claude/tests/floors.conf:2  floor for 'beta' is not a number: 'lots'`, then `FAIL beta  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)`, a blank line, then `2 fault(s) in .claude/tests/floors.conf. Nothing was run.` The assertion, its label and its comparison (`h_same`, byte-identical) are unchanged; only the expected value moved. The handoff's control-table row for this case is corrected in place to match. No assertion was added or removed, so the count stays 309 and neither `floors.conf` nor `selftest.test.sh`'s floor table changed.
- **What earns it:** one `mutate.sh` probe of the behaviour the corrected golden pins and the old one denied, the every-suite missing-floor report for a suite that already has a fault. The mutation reintroduces exactly the one-fault-per-suite behaviour the old golden described: line 377 of `scripts/selftest.sh`, the audit loop's `floor_of "$name"`, is preceded by a skip for any suite already named in `$FAULTS`. Against the corrected test file it turns exactly this one assertion red (308 passed, 1 failed; the floor line is the consequence of that failure, not a second one), and the restore is verified byte-for-byte. Command: `bash scripts/mutate.sh scripts/selftest.sh '377s/^    floor_of "\$name"$/    case "$FAULTS" in *"$name$US"*) continue ;; esac; floor_of "$name"/' -- bash scripts/selftest.sh selftest`, exit 1. Output, with the passing describes elided:

    === mutate: scripts/selftest.sh (1 line(s) changed by 377s/^    floor_of "\$name"$/    case "$FAULTS" in *"$name$US"*) continue ;; esac; floor_of "$name"/) ===
      377 -     floor_of "$name"
      377 +     case "$FAULTS" in *"$name$US"*) continue ;; esac; floor_of "$name"

    === mutate: running bash scripts/selftest.sh selftest ===
    ...
        FAIL and its stdout is the full run's fault report and nothing else: no header, no suite
             expected: identical
             actual:   differ:
             2d1
             < FAIL beta  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)
             4c3
             < 2 fault(s) in .claude/tests/floors.conf. Nothing was run.
             ---
             > 1 fault(s) in .claude/tests/floors.conf. Nothing was run.
    ...
    selftest: 308 passed, 1 failed
    FAIL selftest  did 308 units of work, below the floor of 309 in .claude/tests/floors.conf

    assertion floors: 0 of 1 suite(s) met their declared floor.
    1 of 1 harness suite(s) FAILED.

    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_selftest.sh.20261104T232537Z.64949.bak) ===
      377:     floor_of "$name"

  Afterwards `bash scripts/mutate.sh --check` printed `mutate: no stranded mutation; nothing of a previous run is in the tree.` An observation, not acted on (outside this remit): no other assertion in `selftest` went red under this mutation, including the AC-6 full-run case whose control row expects `2 fault(s) ...`, so that case's two faults evidently do not come from one suite carrying both a value fault and a missing-floor fault.
- **GREEN after the return:** a no-op. No source changed after the return: the code was committed at 950aa5e, before it. The orchestrator verified it on the GREEN tree (f385c38). `bash scripts/attest.sh check -- bash scripts/selftest.sh selftest` answered `fresh`, `exit: 0`, `last: 1 harness suite(s) passed.`, for 309 of 309, from the test-developer's attested run on the corrected tree. The orchestrator ran `bash scripts/selftest.sh selftest-needed` and `bash scripts/gates.sh --fast` directly (the record was stale after the test edit):

      selftest-needed: 458 passed, 0 failed
      1 harness suite(s) passed.
      All required gates passed (0 ran, 5 unconfigured, 0 known).

### R-2 (GATES → RED, 2026-11-04/05): AM-1 and AM-2 change AC-2 and AC-4

- **Why the story returned:** the GATES diff review (`## Diff review`, findings 1 and 2, both reproduced by the orchestrator) led to two criteria amendments the user approved ("Fix both"): **AM-1** adds `.claude/hooks/lib.sh` to AC-2's `all` list (Contract A-4); **AM-2** makes the `*.sh` scanner rows (`lib`, `sigpipe`, `grep-count`) additive, so a `*.sh` that only they match is R5's `all` (Contract A-5). No test was *wrong* against the criteria as they stood; the criteria moved, and four existing expectations moved with them. The source (`scripts/selftest-needed.sh`) was not touched in this phase.
- **What changed in `.claude/tests/selftest-needed.test.sh`** (test-developer, claude-opus-5-5):
  - **Fixture:** `suites_stubs` appends one comment line to the `alpha` stub mentioning `scripts/probes/x.sh`, `.claude/hooks/x.sh` and `.claude/foo/x.sh`. Nothing else in the fixture changed: still nine stubs, so every `hdr ... 9 ...` count elsewhere is unchanged, and no other case changes any of those three paths.
  - **Added (AC-2, AM-1):** "AM-1: an edited `.claude/hooks/lib.sh` prints all, and says it is read by every suite" - stdout exactly `all`, exit 0, whole stderr `selftest-needed: suites — all: .claude/hooks/lib.sh is read by every suite`. 8 assertions.
  - **Added (AC-4, AM-2, the new control):** "AM-2 control: an untracked `.claude/tests/_helpers.sh` that no suite mentions prints all, and names it as mapped by no rule" - whole stderr `... all: .claude/tests/_helpers.sh is mapped by no rule; defaulting to every suite`. 8 assertions.
  - **Added (AC-4, AM-2):** "a new `scripts/newtool.sh` that no suite mentions prints all, though lib, sigpipe and grep-count scan it" - whole stderr `... all: scripts/newtool.sh is mapped by no rule; ...`. 8 assertions.
  - **Changed (AC-4, reworked so R3 maps the path):** `scripts/probes/x.sh` and `.claude/hooks/x.sh` now expect `alpha grep-count lib sigpipe`, header `4 of 9`; `.claude/foo/x.sh` expects `alpha grep-count sigpipe`, header `3 of 9`, and still asserts no `lib`. The `(scans scripts/*.sh)` reason-line assertion is unchanged. Under the old code each of these passes on arrival (the old code also prints `alpha` by R3); earned by the mutation below.
  - **Changed (A-1, per Contract A-5):** a committed deletion of `gamma.test.sh` expects stdout `all` and whole stderr `... all: .claude/tests/gamma.test.sh is mapped by no rule; defaulting to every suite`, where it expected `grep-count sigpipe` and `2 of 8`. Same 8 assertions.
  - **Unchanged:** the `.md`, `profiles` and `shipped-docs` cases, the `.md` control, the `gamma`/`delta` R1 cases (R1 maps them, so the `*.sh` rows stay additive beside it).
  - **Floor:** 458 → 482 (+24) in `.claude/tests/floors.conf` and in `selftest.test.sh`'s hand-copied table, with a note at the foot of `floors.conf`.
- **The failing run, which earns the added and changed expectations.** `bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed`, against the unchanged source:

      exit:     1
      duration: 498s
      last:     1 of 1 harness suite(s) FAILED.
      log:      .claude/state/attest-logs/20261105T033336Z.21603.log

  Exactly 24 failures, all in the four cases above, six per case (the two `exits 0` assertions per case pass: the old code also exits 0). Every other assertion, including the three reworked `*.sh` cases, passed. Excerpt (the `[from subdir]` twins and the two `newtool`/`DELETED` blocks have the same shape and are elided):

      HARNESS-094 AC-2: a changed suite selects itself; _lib.sh, _spawns.sh, hooks/lib.sh and selftest.sh select all
        FAIL AM-1: an edited .claude/hooks/lib.sh prints all, and says it is read by every suite [from root]: stdout is exactly the pinned list
             expected: all
             actual:   grep-count
             lib
             sigpipe
        FAIL AM-1: an edited .claude/hooks/lib.sh prints all, and says it is read by every suite [from root]: stdout has exactly 1 line(s)
             expected: 1
             actual:   3
        FAIL AM-1: an edited .claude/hooks/lib.sh prints all, and says it is read by every suite [from root]: stderr is exactly the pinned text
             expected: selftest-needed: suites — all: .claude/hooks/lib.sh is read by every suite
             actual:   selftest-needed: suites — 3 of 9 selected from 1 harness path(s) changed against main (merge-base 2f2aeec)
               grep-count  .claude/hooks/lib.sh (scans *.sh)
               lib         .claude/hooks/lib.sh (scans .claude/hooks/*.sh)
               sigpipe     .claude/hooks/lib.sh (scans *.sh)
      HARNESS-094 AC-4: the scanner rows select suites that read the tree by glob
        FAIL AM-2 control: an untracked .claude/tests/_helpers.sh that no suite mentions prints all, and names it as mapped by no rule [from root]: stdout is exactly the pinned list
             expected: all
             actual:   grep-count
             sigpipe
        FAIL AM-2 control: an untracked .claude/tests/_helpers.sh that no suite mentions prints all, and names it as mapped by no rule [from root]: stderr is exactly the pinned text
             expected: selftest-needed: suites — all: .claude/tests/_helpers.sh is mapped by no rule; defaulting to every suite
             actual:   selftest-needed: suites — 2 of 9 selected from 1 harness path(s) changed against main (merge-base 83aa67f)
               grep-count  .claude/tests/_helpers.sh (scans *.sh)
               sigpipe     .claude/tests/_helpers.sh (scans *.sh)
        FAIL AM-2: a new scripts/newtool.sh that no suite mentions prints all, though lib, sigpipe and grep-count scan it [from root]: stdout is exactly the pinned list
        FAIL a DELETED .claude/tests/gamma.test.sh prints all, not gamma, and names it as mapped by no rule [from subdir]: stderr is exactly the pinned text
             expected: selftest-needed: suites — all: .claude/tests/gamma.test.sh is mapped by no rule; defaulting to every suite
             actual:   selftest-needed: suites — 2 of 8 selected from 1 harness path(s) changed against main (merge-base 909f7cf)
               grep-count  .claude/tests/gamma.test.sh (scans *.sh)
               sigpipe     .claude/tests/gamma.test.sh (scans *.sh)

      selftest-needed: 458 passed, 24 failed
      FAIL selftest-needed  did 458 units of work, below the floor of 482 in .claude/tests/floors.conf
      1 of 1 harness suite(s) FAILED.

  The right failure in each: the old code answers with the `*.sh` scanner list where `all` is now required, and for `lib.sh` the reason is `(scans ...)`, not `is read by every suite`. Because stderr is compared whole, an implementation that reached `all` for `lib.sh` through R5 (`is mapped by no rule`) would still fail the AM-1 case.
- **What earns the reworked `*.sh` cases** (they pass on arrival): one `mutate.sh` probe that drops the `sigpipe *.sh` row by making its pattern match nothing, run once against the suite. Command: `bash scripts/mutate.sh scripts/selftest-needed.sh '166s/^sigpipe      \*\.sh$/sigpipe      *.nomatch/' -- bash scripts/selftest.sh selftest-needed`, exit 1. All three reworked cases go red, on the missing `sigpipe` (excerpt; the other two cases and the `[from subdir]` twins are the same shape):

      === mutate: scripts/selftest-needed.sh (1 line(s) changed by 166s/^sigpipe      \*\.sh$/sigpipe      *.nomatch/) ===
        166 - sigpipe      *.sh
        166 + sigpipe      *.nomatch

      === mutate: running bash scripts/selftest.sh selftest-needed ===
      ...
        HARNESS-094 AC-4: the scanner rows select suites that read the tree by glob
          FAIL a new scripts/probes/x.sh (a deeper scripts/*.sh) that alpha mentions prints alpha, and grep-count, lib and sigpipe beside it [from root]: stdout is exactly the pinned list
               expected: alpha
               grep-count
               lib
               sigpipe
               actual:   alpha
               grep-count
               lib
          FAIL a new scripts/probes/x.sh (a deeper scripts/*.sh) that alpha mentions prints alpha, and grep-count, lib and sigpipe beside it [from root]: stdout has exactly 4 line(s)
               expected: 4
               actual:   3
          FAIL a new scripts/probes/x.sh (a deeper scripts/*.sh) that alpha mentions prints alpha, and grep-count, lib and sigpipe beside it [from root]: stderr's first line is exactly the pinned header
               expected: selftest-needed: suites — 4 of 9 selected from 1 harness path(s) changed against main (merge-base 9a9f9d0)
               actual:   selftest-needed: suites — 3 of 9 selected from 1 harness path(s) changed against main (merge-base 9a9f9d0)
          FAIL a new .claude/hooks/x.sh that alpha mentions prints alpha, and grep-count, lib and sigpipe beside it [from root]: stdout is exactly the pinned list
          FAIL a new .claude/foo/x.sh that alpha mentions prints alpha, and grep-count and sigpipe beside it [from root]: stdout is exactly the pinned list
      ...
      selftest-needed: 432 passed, 50 failed
      FAIL selftest-needed  did 432 units of work, below the floor of 482 in .claude/tests/floors.conf
      1 of 1 harness suite(s) FAILED.

      === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_selftest-needed.sh.20261105T034224Z.27807.bak) ===
        166: sigpipe      *.sh

  `bash scripts/mutate.sh --check` afterwards: `mutate: no stranded mutation; nothing of a previous run is in the tree.` The 50 failures are the 24 above (20 of them: under the mutation `_helpers.sh` and the deleted `gamma.test.sh` give the one line `grep-count`, so their `1 line(s)` assertions pass by coincidence; their stdout and stderr assertions still fail) plus 30 from the mutation: the three reworked cases (18) and the R1 `gamma`/`delta` cases (12), which also pin `sigpipe`.
- **GREEN after the return:** not a no-op this time. See the handoff's R-2 addendum.

## Diff review

The reviewer was a fresh `feature-developer` using the `diff-review` skill:
Opus 5.5, `claude-opus-5-5`, the GATES row's `opus`, with no override.
2026-11-04. The report is pasted below, edited only for line wrapping.

> What this change does: `selftest-needed.sh --suites [base]` turns the
> branch's changed harness paths into a list of the test suites that could
> break, using five rules:
>
> - R1: the suite itself;
> - R2: shared files that give `all`;
> - R3: suites that mention the path;
> - R4: a table of suites that scan the tree;
> - R5: `all` for any path no rule maps.
>
> `selftest.sh` now takes several suite names, and `--changed [base]`, which
> asks `--suites` and runs what it names. If the answer is `all` it does a full
> run; if it is nothing, it exits 1.
>
> What I checked:
>
> - Every caller of `selftest.sh`. `gates.yml:79` and `:111` call it with no
>   arguments, and `ci-local.sh`, `attest.sh`, `doctor.sh` and
>   `refresh-harness.sh` only name it in comments or messages. With no
>   arguments the code keeps the old full-run path: `AUDIT=1`, an empty
>   `WANT`, and an audit over `ALL_SUITES`, which equals the old `SUITES`. The
>   fault filter passes everything. Nothing changes for CI.
> - A one-name run: the floors audit is still skipped, faults are still
>   filtered to that one name, and the no-match message is unchanged. A single
>   empty argument (`selftest.sh ""`) still gives a full run, as before.
> - Parsing:
>   - `--suites` must come first. `--suites --suites`, `--suites a b` and
>     `a --suites` each give exit 2.
>   - `--changed a b` passes the extra argument through. `--suites` refuses
>     it, and the caller exits 2 with `cannot select`.
>   - `SELFTEST_JOBS` is still checked before the selection runs.
>   - `run_lock_acquire` still records the full argument list.
> - The fd-3 capture in `--changed` that splits stderr, exit code and stdout.
>   The unit separator cannot appear in that output, and an exit 0 with empty
>   stdout falls through to exit 2.
> - In `--suites`, the path counter `i` and the awk counter `np` count the
>   same non-empty lines, so R3's mentions line up with the right path.
> - I reproduced the two findings below on the real tree, in a throwaway
>   clone at `de27810` in the scratchpad.
> - I assumed the load the repository states: one developer per worktree, and
>   a diff of tens of paths. Nothing here is a scale problem at that size.
>
> **Should fix:**
>
> 1. **A change to the main harness library selects fewer than half the
>    suites** (`scripts/selftest-needed.sh:207-211`, the R2 `case`).
>    - **What this is:** R2 is the list of files that "every suite reads", and
>      changing any of them gives `all`. It names `_lib.sh`, `_spawns.sh` and
>      `scripts/selftest.sh`.
>    - **Problem:** `.claude/hooks/lib.sh` is missing from that list, although
>      15 harness scripts source it, including `gates.sh`, `phase.sh`,
>      `plan.sh`, `story.sh`, `classify.sh` and `check-boundaries.sh`.
>      Reproduced: appending one comment line to `.claude/hooks/lib.sh` and
>      running `--suites HEAD` printed `15 of 34 selected`, and `plan`,
>      `doctor`, `refresh`, `worktree` and 15 other suites were left out.
>      `plan.test.sh` runs `plan.sh`, which sources `lib.sh`, so a `lib.sh`
>      change that breaks `plan.sh` passes `--changed` locally.
>    - **Fix:** Add `.claude/hooks/lib.sh` to the R2 `case` and to the header
>      comment, plus one AC-2-style case in `selftest-needed.test.sh`, which
>      makes this a short return to RED. R2's list is written in the
>      Contract, so the change needs a Contract amendment. It contradicts no
>      acceptance criterion.
>    - **If we skip it:** This falls under the declared "Known limit"
>      (reaching a file through another script), but it is the worst instance
>      of that limit: the one file under R2's own reason, "read by every
>      suite". Once HARNESS-095 makes `--changed` the pre-PR run, a `lib.sh`
>      story reaches CI with about half its suites unrun locally.
> 2. **No shell file can ever trigger the "unmapped, so run all" safety net**
>    (`scripts/selftest-needed.sh:162-163` and `:225-229`).
>    - **What this is:** The scanner table rows `sigpipe *.sh` and
>      `grep-count *.sh` match every harness `.sh` path, so R5 can never fire
>      for a shell file.
>    - **Problem:** The same kind of new file gets opposite answers depending
>      on its extension. Reproduced: an untracked
>      `.claude/tests/_helpers.conf` gives `all` ("mapped by no rule"), but
>      `.claude/tests/_helpers.sh` gives `grep-count` and `sigpipe` only, 2 of
>      34. A new helper that suites source by a relative name
>      (`"$HERE/_helpers.sh"`, the way they source `_lib.sh`) is never
>      mentioned by its full repo path, so R3 cannot see it. The same is true
>      of a new `.sh` fixture under `.claude/tests/fixtures/`. Shell files are
>      the files most often used through another script, and they are exactly
>      the ones the fail-safe never covers.
>    - **Fix:** Do not let the two `*.sh` rows set `hit`, so they add their
>      suites but a `.sh` path matched by nothing else still falls to R5. This
>      conflicts with AC-3's control ("a path the rules can map never widens
>      the answer to all") as AC-4 reads for `.sh`. So it is a question for
>      the product owner under `## Amendments`, not a GATES fix. The smaller
>      option is to add the `.claude/tests/*` helpers (anything outside
>      `*.test.sh`) to R2.
>    - **If we skip it:** Today the only shell helpers under `.claude/tests`
>      are `_lib.sh` and `_spawns.sh`, both in R2, so nothing is
>      under-selected yet. The first story that adds a third helper will be
>      under-selected without any warning.
>
> Not checked: whether R3's plain substring match lets a path count as
> "mapped" only because it is the start of a longer path that a suite
> mentions, which would also keep R5 from firing. My real-tree scan for this
> used a broken regular expression and its output is not usable.
>
> Verdict: Ship.

**Orchestrator's reproduction (2026-11-04).** I ran this in my own scratch
clone at C2 (`5cd48b3`, the branch tip's tree), with different inputs from
the reviewer's:

- inserting `# probe` after line 1 of `.claude/hooks/lib.sh` gave `15 of 34 selected`;
- an untracked `.claude/tests/_helpers.sh` holding a function gave
  `2 of 34 selected` (`grep-count`, `sigpipe`);
- an untracked `.claude/tests/_helpers.conf` gave `all: ... mapped by no rule`.

Both findings are confirmed. `grep -lE 'hooks/lib\.sh' scripts/*.sh
.claude/hooks/*.sh` names 11 files. The clone's tree was clean afterwards.

Finding 2 contradicts AC-4's control as written: a scanner match is "not
`all`". That makes it the user's decision under `## Amendments`, and it is
put to them before anything changes.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-05T03:10:27Z
    commit: de27810
    tree:   aa37e34f242d1171ec4dc67e87343d5c4be188c5
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

- **RED verification (orchestrator, 2026-11-04):** the test-developer resolved to claude-opus-5-5. `attest.sh check` answered `fresh` for all three runs:
  - `bash scripts/selftest.sh selftest-needed`: exit 1, 259 passed and 199 failed. The log `.claude/state/attest-logs/20261104T205156Z.173145.log` shows 0 FAILs before the first HARNESS-094 describe. The first failure is `--suites` rejected with the usage line (exit 2).
  - `bash scripts/selftest.sh selftest`: exit 1, 288 passed and 21 failed. The log `20261104T205957Z.184706.log` shows 0 FAILs before the first HARNESS-094 describe. The failures are a multi-name run running only one suite.
  - `bash scripts/gates.sh --fast`: exit 0, 0 ran.
  - None ran directly.
- **GREEN finding (feature-developer, claude-opus-5-5, 2026-11-04): one frozen golden contradicts the full-run audit it names.** `selftest.test.sh`, describe "HARNESS-094 AC-7  --changed audits the whole floors file first", pins `golden.ac7-audit` as one fault (`floor for 'beta' is not a number: 'lots'`, then `1 fault(s) ...`). A full run's audit over that floors file reports **two**: a non-numeric floor is not loaded, so the audit's every-suite loop also reports `beta  no floor line ...`. Measured against `selftest.sh` as it stands on `HEAD` (before this story), full run over `alpha 3 / beta lots / gamma 1`:

      FAIL .claude/tests/floors.conf:2  floor for 'beta' is not a number: 'lots'
      FAIL beta  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)

      2 fault(s) in .claude/tests/floors.conf. Nothing was run.
      rc=1

  AC-7 and the Contract both say `--changed` performs "the whole-file floors audit of a full run", and the assertion's own label says "the full run's fault report", so the shipped code prints those two faults and the golden's expected value is the thing that is wrong. Not worked around: making `--changed`'s audit differ from a full run's would contradict AC-7. The one failing assertion, from `.claude/state/attest-logs/20261104T224009Z.19729.log`:

      FAIL and its stdout is the full run's fault report and nothing else: no header, no suite
           expected: identical
           actual:   differ:
           1a2
           > FAIL beta  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)
           3c4
           < 1 fault(s) in .claude/tests/floors.conf. Nothing was run.
           ---
           > 2 fault(s) in .claude/tests/floors.conf. Nothing was run.

  The control the handoff table records ("AC-7: audit with unselected beta `lots` | exit 1, stdout exactly the 3-line fault report") therefore measured exit 1 (as expected) and a 4-line, 2-fault report (diverges). Every other assertion in both suites passes.
- **Orchestrator's independent reproduction of the GREEN finding (2026-11-04).** I used different inputs and none of the developer's fixture: a `--no-hardlinks` clone of `main` (scratchpad `repro`), with the real `floors.conf` line `floor | doctor        | 69` changed to `many`, and a plain full run `bash scripts/selftest.sh`:

      FAIL .claude/tests/floors.conf:45  floor for 'doctor' is not a number: 'many'
      FAIL doctor  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)

      2 fault(s) in .claude/tests/floors.conf. Nothing was run.
      rc=1

  The full run's audit has always reported two faults for one non-numeric floor, so `golden.ac7-audit` is wrong and the code is right. Decision: return to RED (Regressions R-1). A first attempt at this reproduction ran in the real worktree because the clone failed. It changed nothing: `git status` and `git diff -- .claude/tests/floors.conf` were clean afterwards, and no run.lock was left. Its timed-out `selftest.sh` produced no record.
