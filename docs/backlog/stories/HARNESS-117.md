---
id: HARNESS-117
title: A changed paths, phases or models conf selects every suite
slug: conf-change-selects-every-suite
epic: 
type: fix
status: in-progress
phase: GATES
branch: story/HARNESS-117-conf-change-selects-every-suite
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/commands/advance-story.md, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the selftest-needed suite under its selftest floor, which CI runs in full on the PR
---

## Context

`bash scripts/selftest-needed.sh --suites` picks the suites
`selftest.sh --changed` runs before a PR. It selects by mention (R3): a
suite is chosen for a changed path when its source names the path. That is
sound only while a suite that never names a path does not read it.

`make_fixture` in `.claude/tests/_lib.sh` (`:120`-`:122`) breaks that for
three files: it copies the REAL `.claude/harness/paths.conf`,
`phases.conf` and `models.conf` into every fixture, and
`make_project_fixture` builds on it. 24 of the 35 suites call one or the
other, and most never name the confs. Unlike `VERSION` (HARNESS-116), the
content matters here: these are the classification rules, the phase
permissions and the model plan that the suites assert on. HARNESS-116
recorded this as a finding from `grep -l` only (its Notes, Q-2), and the
user asked for a story.

This story measures it, and then makes a change to one of the three confs
select every suite, the way a change to `_lib.sh` already does.

**The measurement, PLANNED, 2026-11-19, release 135 (`da9d4bb`), worktree
`D:\adh-HARNESS-117`.**

*Table 1. Who gets the real file.* All 24 helper suites get all three (the
helper copies them unconditionally): attest, boundaries, ci-local,
classify, doctor, gate-reminder, gates, grep-count, host-load, lib, mutate,
phase-guard, phase, plan, profiles, run-lock, run-queue, selftest-needed,
selftest, settings, sigpipe, spawns, story, worktree. Reads that do not go
through the helper: `selftest-needed.test.sh:204` and `:703` (`cp -r` of the
real `.claude/harness`), `lib.test.sh:1205`-`:1206` (the real `paths.conf`
and `phases.conf` into a stand-in root), `boundaries.test.sh:3930`-`:3931`
and `dispatch.test.sh:980` (the real `models.conf`). The other 11 suites
(briefs, dispatch, new-story, policy, procedure, refresh, reporting,
rules-trim, security-audit, shipped-docs, tidy) build no helper fixture;
`refresh` writes confs of its own (`:40`, `:44`, `:90`).

Which suites can depend on the content, read from the scripts each one
names (an upper bound on candidates, not a proof; the runs
below are the evidence):

| Conf | Read by | Helper suites whose source names a reader (`grep -l`) |
|---|---|---|
| `paths.conf` | `.claude/hooks/lib.sh` (`classify`, so the guard hook, `gates.sh`, `check-boundaries.sh`, `classify.sh`, `selftest-needed.sh`), `doctor.sh` | 19 name `gates.sh`; 13 name `check-boundaries.sh` |
| `phases.conf` | `.claude/hooks/lib.sh` (`phase_allows`), `phase.sh:20`, `plan.sh:29`, `check-boundaries.sh:156`, `doctor.sh` | 9 set a phase (boundaries, gate-reminder, gates, mutate, phase-guard, phase, plan, spawns, worktree) |
| `models.conf` | `plan.sh:28`, `check-boundaries.sh:1219`, `doctor.sh:133` (presence) | 5 name `plan.sh` (grep-count, host-load, phase-guard, phase, plan); 13 name `check-boundaries.sh` |

*Table 2. What `--suites` selects today.* A scratch clone at `da9d4bb`, one
comment line appended to one conf and committed on a branch,
`bash scripts/selftest-needed.sh --suites da9d4bb`:

| Changed | Selected (all by `(mentioned)`) | Helper suites NOT selected |
|---|---|---|
| `paths.conf` | 8 of 35: attest, classify, lib, phase-guard, refresh, selftest-needed, sigpipe, spawns | 17: boundaries, ci-local, doctor, gate-reminder, gates, grep-count, host-load, mutate, phase, plan, profiles, run-lock, run-queue, selftest, settings, story, worktree |
| `phases.conf` | 3 of 35: lib, plan, refresh | 22: every helper suite but lib and plan; `phase-guard` and `phase` among them |
| `models.conf` | 4 of 35: boundaries, dispatch, plan, rules-trim | 22: every helper suite but boundaries and plan |

    selftest-needed: suites — 3 of 35 selected from 1 harness path(s) changed against da9d4bb (merge-base da9d4bb)
      lib      .claude/harness/phases.conf (mentioned)
      plan     .claude/harness/phases.conf (mentioned)
      refresh  .claude/harness/phases.conf (mentioned)

The same change made in this worktree and not committed (DV-2's command)
prints the same three names.
(`lib` is there since HARNESS-116: its stand-in root names two of the
(`lib` is there since HARNESS-116: its stand-in root names two of the
confs. HARNESS-116's Q-2 list predates that.)

*Table 3. The runs.* One plausible content change per conf, each one
`SELFTEST_JOBS=4 bash scripts/mutate.sh <conf> '<expr>' -- bash
scripts/selftest.sh <every suite table 2 does not select for that conf>`,
the 11 non-helper suites included; restore verified by `mutate.sh`. Other
gate runs shared the host.

| | Conf, mutation | Suites run | Result |
|---|---|---|---|
| M-1 | `phases.conf`: `/^RED /s/test,manifest,/test,/` (RED may no longer write a manifest) | 32 | **`phase-guard` red**, 383 passed, 5 failed: "allows: RED may write Cargo.toml", "... package.json", "... pyproject.toml", "... the lockfile", "... pnpm-lock.yaml". The other 31 green, 6148 assertions. Exit 1, 56 min |
| M-2 | `paths.conf`: `s/^manifest \| package\.json$/config \| package.json/` (one file moves category) | 27 | **`boundaries` red**, 684 passed, 3 failed, all under "RED may add a test dependency, and only a test dependency": "the same in package.json", "and a production dependency in package.json", "and production AFTER the dev block is still read". The other 26 green. Exit 1, 26 min |
| M-3 | `models.conf`: `/^model /s/\| fable \|/\| opus  \|/` (the four `fable` rows become `opus`) | 31 | **all 31 green**, 5758 assertions, exit 0, 17 min |
| M-4 | `models.conf`: `/^model  \| GREEN /d` (the GREEN row deleted) | the same 31 | **all 31 green**, 5758 assertions, exit 0, 20 min |

    phase-guard: 383 passed, 5 failed
    1 of 32 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/.claude_harness_phases.conf.20261120T025805Z.997062.bak) ===
    boundaries: 684 passed, 3 failed
    1 of 27 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/.claude_harness_paths.conf.20261120T035419Z.1209880.bak) ===
    31 harness suite(s) passed.
    === mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/.claude_harness_models.conf.20261120T042038Z.1353181.bak) ===
    31 harness suite(s) passed.
    === mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/.claude_harness_models.conf.20261120T043748Z.1475095.bak) ===
    mutate: no stranded mutation; nothing of a previous run is in the tree.

**What it shows.** The gap is real for two of the three files. A story
that took `manifest` out of RED's row in `phases.conf` and changed nothing else would select `lib`,
`plan` and `refresh` locally, pass, and fail CI in `phase-guard`, the suite
that tests the phase lock (M-1). A story that moved `package.json` out of
`manifest` would select 8 suites, pass, and fail CI in `boundaries` (M-2).
Both red suites call the helper and hold the conf's path nowhere: each
says the bare file name in comments, which is not a mention. No suite that
builds no fixture
went red in any run.

For `models.conf` no unselected suite went red under either mutation: the
four suites that mention it (`boundaries`, `dispatch`, `plan`, `rules-trim`)
are where its content is asserted today. It is in this story's rule all
the same, because the helper copies it by the same line and a suite that
runs `plan.sh` in a fixture reads it without naming it (Notes, Q-2).

A green suite under one mutation shows only that this mutation did not
reach it. One mutation per conf is a lower bound on who depends on the
content, not a list: `phase` was green under M-1 and still sets phases in
every case it runs.

**How often.** `git log --oneline -- <file> | wc -l` at `da9d4bb`:
`paths.conf` 9, `phases.conf` 6, `models.conf` 5; 15 distinct commits out
of 1115, 4 of them on or after 2026-10-05 (`2856bca`, `46790ed`, HARNESS-101,
HARNESS-102), against 135 for `VERSION`. A story changes one of them about
twice a month at the recent rate, not every time.

**The required gate.** Every gate in `project.conf` is unconfigured here.
The artifact is judged by the `selftest-needed` suite under its floor in
`floors.conf`, which CI runs in full on the PR and the local `--changed`
run selects by R1 (the suite itself changes).

## Acceptance criteria

"The three confs" are `.claude/harness/paths.conf`,
`.claude/harness/phases.conf` and `.claude/harness/models.conf`, compared as
whole repo-relative paths. "The conf answer for `<path>`" is: `bash
scripts/selftest-needed.sh --suites` exits 0, stdout is exactly the one line
`all`, and stderr is exactly the one line

    selftest-needed: suites — all: <path> is copied into every fixture make_fixture builds

"The real suites" means this repository's `.claude/tests/*.test.sh` as the
story's tree holds them, copied from `$REPO_ROOT` into a fixture checkout
whose base holds them unchanged (HARNESS-115, Contract C-5). Every answer is
asserted from the fixture root and from `src/`.

- **AC-1 (the gap, reproduced on the real suites)** — Given the real suites,
  when exactly one of the three confs is changed, then the answer is the
  conf answer for that path. One case per conf. *(Today each prints a list:
  8, 3 and 4 of 35 at PLANNED, Context table 2. `phase-guard` is in none
  of the three lists for `phases.conf`, and run M-1 turns it red.)*
- **AC-2 (no mention and no declaration narrows it)** — Given stub suites
  in a fixture: (a) when one stub names `.claude/harness/phases.conf` and
  that path is changed, alone and also beside a second changed path that
  another stub names, the answer is the conf answer for
  `.claude/harness/phases.conf`; (b) when two stubs name
  `.claude/harness/models.conf`, one of them on a column-0 line
  `# fixture-only: .claude/harness/models.conf`, and that path is changed,
  the answer is the conf answer for it, and stderr holds no
  `not selected (fixture-only):` line. *(Today (a) prints the naming stub,
  or both stubs, and (b) prints the undeclared stub and the not-selected
  line.)*
- **AC-3 (control: only those three whole paths)** — Given stub suites, one
  of which names `.claude/harness/h117/phases.conf` and one of which names
  `.claude/harness/paths.conf.bak`: when `.claude/harness/h117/phases.conf`
  is changed, stdout is exactly the stub that names it, with the reason
  `.claude/harness/h117/phases.conf (mentioned)`; and the same for
  `.claude/harness/paths.conf.bak` and its stub. Neither answers `all`.
  And the lists HARNESS-115's AC-1 and AC-2 pin for
  `.claude/harness/VERSION` and `.claude/tests/floors.conf` do not change:
  those assertions stay as they are and stay green.
- **AC-4 (the rule covers what the helper copies)** — Given the real
  `.claude/tests/_lib.sh`, the set of repo-relative paths on its lines of the
  form `cp "$REPO_ROOT/<path>" ...` (a single-file copy: no `-r`) is exactly
  the three confs; and for each path of that extracted set, changed alone
  in a stub fixture whose suites do not name it, the answer is the conf
  answer for that path. *(Today the set is the three confs, and each
  answers `all` only through R5, with the reason `<path> is mapped by no
  rule; defaulting to every suite`: the stderr comparison is what fails.)*
  A fourth single-file copy added to the helper later turns the set
  assertion red until the rule, or the helper, is changed.
- **AC-5 (the rule is written where it is read)** — The header of
  `scripts/selftest-needed.sh` and step 2 of GATES → REVIEW in
  `.claude/commands/advance-story.md` each state the rule, in the texts
  Contract C-4 pins.

## Contract

**Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/commands/advance-story.md`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

Every path above classifies as `harness`, so the lock permits each in every
phase; who writes what is by role. RED (Test Developer):
`selftest-needed.test.sh`, the `selftest-needed` floor in `floors.conf` and
its entry in `selftest.test.sh`'s COUNTS table. GREEN (Feature Developer):
`scripts/selftest-needed.sh`, `advance-story.md`, `VERSION` (the next free
release number when the branch is cut; 136 at PLANNED).

**C-1. The rule.** In `scripts/selftest-needed.sh`, `--suites` mode, the
per-path loop already answers `all` for four paths before any other rule is
read (R2: `.claude/tests/_lib.sh`, `.claude/tests/_spawns.sh`,
`scripts/selftest.sh`, `.claude/hooks/lib.sh`; the `case` with
`why_all="$p is read by every suite"` and `continue`). The three confs join
that step with a reason of their own:

    why_all="$p is copied into every fixture make_fixture builds"

set only when `why_all` is still empty, then `continue`, exactly as R2 does.
What follows from sitting there, and is meant:

- The match is the whole repo-relative path, by `case` with no glob. Not a
  basename, not a prefix: `.claude/harness/h117/phases.conf` and
  `.claude/harness/paths.conf.bak` are ordinary paths (AC-3).
- R3 is never asked about a conf, so no mention maps it and no
  `# fixture-only:` line narrows it (AC-2). `refresh.test.sh`,
  `lib.test.sh` and the others that name a conf need no declaration and
  get none.
- When several changed paths answer `all`, the first in sort order gives
  the reason, as today. `.claude/harness/...` sorts before
  `.claude/hooks/lib.sh`, `.claude/tests/_lib.sh` and `scripts/selftest.sh`,
  so a conf changed beside one of those gives the conf's reason.
- Why `all` and not "the 24 suites that call the helper": Notes, D-1.
  Why not the wording `is read by every suite`: 11 of the 35 suites build no
  fixture, so that sentence would be false for these paths.

stdout's format, the exit statuses, the header line, every existing reason
and every existing `all` line are byte for byte as they are. The run/skip
mode (no `--suites`) is not touched: a changed conf already answers `run`.

**C-2. Callers.** No signature or output format changes. The one consumer
of the answer is `scripts/selftest.sh --changed` (`:312`-`:320`): on `all`
it runs every suite and prints `selftest: --changed — every suite: <the
text after "all: ">`, so for a conf change its header reads `... every
suite: .claude/harness/phases.conf is copied into every fixture
make_fixture builds`. `selftest.sh` is not edited, and no test of it pins a
reason text for a conf (`grep -n 'harness/\(paths\|phases\|models\)\.conf'
.claude/tests/selftest.test.sh`: no line, at PLANNED).

**C-3. The tests,** in `selftest-needed.test.sh`, in a block of their own
at the end under `describe` lines that start `HARNESS-117`. They reuse the
suite's helpers as they are: `h115_real` and `h115_edit` for AC-1 (the real
suites, C-5 of HARNESS-115); a stub builder of their own for AC-2, AC-3 and
AC-4, as `h096_fixture` does, so the `9` in the existing `hdr ... 9 ...`
pins does not move. Every `all` answer is asserted with `expect_suites ...
"all" whole "<the whole stderr line>" --suites`: the needle is the WHOLE
stderr, because R5 gives the same stdout with a different reason (the
needle rule; HARNESS-094 AM-1 has the precedent).

- AC-1: three cases, one conf each, `h115_real` then `h115_edit <conf>`.
  The suite may spell the three confs whole. Its own copy in the fixture
  then mentions them, which changes nothing: R2 never reads a mention.
- AC-2 (b) also asserts `h115_ns_count` is 0.
- AC-3: `expect_suites` with the one stub name as stdout, `first` and the
  `hdr 1 <m> 1` header, and `reason_lines <stub> <path> mentioned` is 1.
  The two controls pass on arrival in RED and after GREEN; DV-3 earns
  them. HARNESS-115's AC-1 and AC-2 blocks are not edited.
- AC-4: the extraction reads `"$REPO_ROOT/.claude/tests/_lib.sh"`, CR
  stripped, and takes from each line matching
  `^[[:space:]]*cp "\$REPO_ROOT/` the text between `"$REPO_ROOT/` and the
  next `"`. Sorted, it is compared as a whole string with the three confs,
  one per line (`paths.conf` is at `_lib.sh:120`, `phases.conf` at `:121`,
  `models.conf` at `:122`, release 135). `cp -r "$REPO_ROOT/scripts"` and
  `cp -r "$REPO_ROOT/.claude/hooks"` (`:161`, `:162`) do not match the
  pattern and are out of scope. Then one stub-fixture case per extracted
  path, driven by the extracted list and not by a second literal list, so
  a path added to the helper is asked about without editing the loop.
- AC-5: whole lines counted with `==`, and position by the lines around
  them, as HARNESS-115's AC-8 does (`snh_count`, the `AS_STEP2` join).

**C-4. The two texts (AC-5).**

*`scripts/selftest-needed.sh`, header.* Every line HARNESS-096 AC-4 and
HARNESS-115 AC-8 pin stays byte for byte, the three R2 lines included. A
new block goes directly after the line `# CI's full run is the backstop.`
(the last line of the `Known limit:` paragraph) and before the blank line
that precedes `set -uo pipefail`:

    #
    # R2, for the fixture confs (HARNESS-117). `make_fixture` in
    # .claude/tests/_lib.sh copies the real .claude/harness/paths.conf,
    # phases.conf and models.conf into every fixture it builds, so a suite
    # reads them without naming them. A change to one of the three answers
    # `all`, like an R2 path, with the reason
    # `<path> is copied into every fixture make_fixture builds`. No mention
    # and no `# fixture-only:` line narrows that.

*`.claude/commands/advance-story.md`, step 2 of GATES → REVIEW.* One
clause, on the line it already sits on (line 310 at release 135), so no
line number in the file moves:

- before: `suite when a path cannot be placed or the library changed; the full run's`
- after: `suite when a path cannot be placed or the library or a fixture conf changed; the full run's`

The test matches the clause `every suite when a path cannot be placed or
the library or a fixture conf changed;` once in the joined step
(`AS_STEP2`), and the old clause `or the library changed;` zero times.
`CLAUDE.md` is not edited: its `--suites` paragraph names no R2 path.

**C-5. Floors.** `selftest-needed` rises from 976 by the number of
assertions C-3 adds, in `floors.conf` and in `selftest.test.sh`'s COUNTS
table (`:557`). No other literal pins that floor (`grep -n 976
.claude/tests/selftest.test.sh`: that one line).

**Oracle partition.** AC-1 is settled: the answer is `all` and the reason
is the pinned line; the "today" lists in the Context are a record, not an
expected value, and no test asserts them. AC-2 to AC-5 are mechanical: pin
stdout whole, stderr whole, lines whole. Nothing is derived or calibrated.

**Baselines the story may read out** (release 135, `da9d4bb`): 35 suites;
24 call `make_fixture` or `make_project_fixture`; today's selections for
one changed conf are Context table 2; `_lib.sh` holds exactly three
single-file copies from `$REPO_ROOT`.

**How a test changes a conf.** By appending one comment line to the
fixture's own copy (`h115_edit`, `# edited on the story branch`), never by
editing the real file: a comment keeps the fixture's `paths.conf` valid for
the classify step that runs before any rule.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": DV-1 is the defect put
back for the central claim; DV-2 is the probe against a real line of the
tree that a story changing a rule over the tree owes; DV-3 is the one
mutation that earns the controls of AC-3, which pass on arrival. RED cannot
run any of them: the rule does not exist until GREEN. Each runs against the
one suite or the one command named, never the full self-test.

- **DV-1, the defect put back (AC-1, AC-2, AC-4).** With the three confs
  taken out of the `--suites` step that C-1 adds them to (the expression is
  written at GATES against the script as built; it must change code, not a
  comment, and is recorded with the result), the `selftest-needed` suite
  **must** fail, in the HARNESS-117 block and nowhere else, and AC-1's
  `phases.conf` case must show a list of suite names as its actual stdout
  where `all` is expected. Run against
  `bash scripts/selftest.sh selftest-needed`. **Owner: GATES.**

  **Result (GATES, 2026-11-20): passed — the suite went red where it should.**
  Run by the orchestrator with `scripts/mutate.sh`, against
  `bash scripts/selftest.sh selftest-needed`. The mutation removes the conf
  arm's pattern, so no path reaches it. 42 failures, every one in the
  HARNESS-117 block (AC-1 ×18, C-1 ×2, AC-2(a) ×10, AC-2(b) ×6, AC-4 ×6);
  AC-5's four text pins stay green, as they should, since the text is not
  mutated. AC-1's `phases.conf` case shows a list where `all` is expected.
  File restored and verified; `mutate.sh --check` clean.

    === mutate: scripts/selftest-needed.sh (1 line(s) changed by s#^      \.claude/harness/paths\.conf|\.claude/harness/phases\.conf|\.claude/harness/models\.conf)$#      __h117_dv1_removed__)#) ===
      283 -       .claude/harness/paths.conf|.claude/harness/phases.conf|.claude/harness/models.conf)
      283 +       __h117_dv1_removed__)
        FAIL AC-1: .claude/harness/phases.conf changed over the real suites answers all, saying it is copied into every fixture [from root]: stdout is exactly the pinned list
             expected: all
             actual:   lib
             plan
             refresh
             selftest-needed
        FAIL AC-1: .claude/harness/phases.conf changed over the real suites answers all, saying it is copied into every fixture [from root]: stderr is exactly the pinned text
             expected: selftest-needed: suites — all: .claude/harness/phases.conf is copied into every fixture make_fixture builds
             actual:   selftest-needed: suites — 4 of 35 selected from 1 harness path(s) changed against main (merge-base 9254643)
    selftest-needed: 1049 passed, 42 failed
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/scripts_selftest-needed.sh.20261120T135805Z.1844862.bak) ===

- **DV-2, the rule on the real tree (the story's claim, on the real
  file).** In the story's worktree, with one comment line appended to the
  real `.claude/harness/phases.conf`, the real script **must** print the one
  line `all` and the reason `.claude/harness/phases.conf is copied into
  every fixture make_fixture builds`. Measured at PLANNED on `da9d4bb`
  (Context, table 2) the same change prints `lib`, `plan`, `refresh`. At
  GATES the story's own changed paths are in the diff as well; `all` wins
  over them. **Owner: GATES.**

  The command: `bash scripts/mutate.sh .claude/harness/phases.conf '$a# HARNESS-117 probe' -- bash scripts/selftest-needed.sh --suites`

  **Result (GATES, 2026-11-20): passed.** Run by the orchestrator, the
  command above, in the story's worktree. The real script printed `all` with
  the conf reason; the real `phases.conf` was restored and verified.

    === mutate: .claude/harness/phases.conf (1 line(s) changed by $a# HARNESS-117 probe) ===
      26 + # HARNESS-117 probe
    === mutate: running bash scripts/selftest-needed.sh --suites ===
    selftest-needed: suites — all: .claude/harness/phases.conf is copied into every fixture make_fixture builds
    all
    === mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/.claude_harness_phases.conf.20261120T135750Z.1844688.bak) ===

- **DV-3, the controls of AC-3 earned.** With the rule's match for one conf
  widened from the whole path to a pattern (for example
  `.claude/harness/paths.conf` to `.claude/harness/paths.conf*`; written at
  GATES against the script as built and recorded), AC-3's
  `.claude/harness/paths.conf.bak` case **must** fail, its actual stdout
  being `all`. Run against `bash scripts/selftest.sh selftest-needed`.
  **Owner: GATES.**

  **Result (GATES, 2026-11-20): passed — the control went red.** Run by the
  orchestrator against `bash scripts/selftest.sh selftest-needed`. 5
  failures, all AC-3's `paths.conf.bak` case (both directories, plus its
  reason count); the `h117/phases.conf` control, not widened, stayed green.
  File restored and verified; `mutate.sh --check` clean.

    === mutate: scripts/selftest-needed.sh (1 line(s) changed by s#^      \.claude/harness/paths\.conf|#      .claude/harness/paths.conf*|#) ===
      283 -       .claude/harness/paths.conf|.claude/harness/phases.conf|.claude/harness/models.conf)
      283 +       .claude/harness/paths.conf*|.claude/harness/phases.conf|.claude/harness/models.conf)
        FAIL AC-3: .claude/harness/paths.conf.bak, named by stub backup, prints backup, not all [from root]: stdout is exactly the pinned list
             expected: backup
             actual:   all
        FAIL AC-3: backup's reason is exactly `.claude/harness/paths.conf.bak (mentioned)`
             expected: 1
             actual:   0
    selftest-needed: 1086 passed, 5 failed
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/scripts_selftest-needed.sh.20261120T140558Z.1876040.bak) ===
    mutate: no stranded mutation; nothing of a previous run is in the tree.

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

Planned by `bash scripts/plan.sh write HARNESS-117` from `.claude/harness/models.conf`.
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

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
- PLANNED: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override reported.
- RED: `test-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override reported.
- GREEN: `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override reported.
- GATES (full gates): `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override reported.
- DIFF-REVIEW round 1: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override reported. Verdict: Ship.
- RED (R-1): `test-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override reported.
- DIFF-REVIEW round 2: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override reported. Verdict: fix 1 first (GATES).
- GATES (round 2 fix 1, VERSION 138, gates): `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override reported.

## Out of scope

- **`.claude/tests/_lib.sh`.** Not edited. `make_fixture` keeps copying the
  real three confs on purpose: the rules under test are the shipped ones
  (Notes, D-1, option 3).
- **Any other suite.** No suite gains or loses a line, a mention or a
  `# fixture-only:` declaration. `refresh` names all three confs only to
  write its own copies and stays selected by the rule like every other
  suite; a declaration could not narrow it (AC-2).
- **Selecting only the suites that call the helper.** Not built (Notes,
  D-1, option 2).
- **The helper's directory copies.** `make_project_fixture` also copies
  `scripts/` and `.claude/hooks/` whole. A changed script is placed by
  mention, by a `SCANS` row or by R5, and a suite that reaches it only
  through another script is HARNESS-094's declared limit. Not changed here.
- **Other files under `.claude/harness/`.** `VERSION` (HARNESS-116),
  `project.conf`, `rules.md`: selected as today.
- **`scripts/selftest.sh`, `CLAUDE.md`, `selftest-needed.sh`'s run/skip
  mode.** Not edited.
- **`phase-guard`, `boundaries` or any suite the Context shows red under a
  mutation.** They are red because the mutation is wrong, which is what
  they are for. Nothing in them is a defect of this story.
- **A suite the full self-test at GATES shows red.** A finding to record
  and route, not a licence to edit it here.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

One level: the `selftest-needed` suite, driving the fixture's copy of
`scripts/selftest-needed.sh --suites` in throwaway git fixtures (the
contract is the script's stdout, stderr and exit status), plus whole-line
text pins over the real `_lib.sh`, `selftest-needed.sh` header and
`advance-story.md`. All new cases are one block at the end of
`.claude/tests/selftest-needed.test.sh`, under `describe` lines starting
`HARNESS-117`. 115 assertions, all unconditional; 123 after R-1 (one C-1
case, +8, written against the shipped script and earned by a mutation in
`## Regressions`).

Helpers. `h117_conf <label> <path>` is `expect_suites <label> 0 "all"
whole "selftest-needed: suites — all: <path> is copied into every fixture
make_fixture builds" --suites`: from the root and from `src/`, exit 0,
stdout exactly `all`, its line count 1, and the WHOLE stderr (8
assertions). `h117_fixture "name|line" ...` is a stub builder of its own
(one `.claude/tests/<name>.test.sh` per argument, committed on `main`), so
the `hdr ... 9 ...` pins of HARNESS-094/096 do not move. AC-1 reuses
`h115_real`/`h115_edit` as they are; AC-2 (b) reuses `h115_expect` with an
empty not-selected argument (expect_suites's four assertions plus "stderr
holds 0 not-selected line(s)", per directory).

| Case | Oracle | Assertions | AC |
|---|---|---|---|
| paths.conf, phases.conf, models.conf each changed over the real suites -> conf answer | settled | 3 x 8 | AC-1 |
| phases.conf changed beside `.claude/tests/_lib.sh` -> conf answer with phases.conf's reason (first in sort order) | mechanical | 8 | C-1 |
| R-1: unmapped `.claude/aaa-h117-unmapped.txt` (sorts first) beside phases.conf -> `all` with the unmapped path's R5 reason, the conf's guard kept | mechanical | 8 | C-1 |
| stub `named` names phases.conf; phases.conf alone -> conf answer | mechanical | 8 | AC-2 (a) |
| control: `.claude/harness/h117-other.conf` alone -> exactly `other`, `hdr 1 2 1`, reason `(mentioned)` | mechanical | 9 | AC-2 (a) |
| phases.conf beside h117-other.conf -> conf answer, not both stubs | mechanical | 8 | AC-2 (a) |
| `plain` names models.conf, `decl` declares it fixture-only at column 0; models.conf changed -> conf answer, 0 not-selected lines | mechanical | 10 | AC-2 (b) |
| `.claude/harness/h117/phases.conf` -> exactly `nested`, `hdr 1 2 1`, reason line | mechanical (control) | 9 | AC-3 |
| `.claude/harness/paths.conf.bak` -> exactly `backup`, `hdr 1 2 1`, reason line | mechanical (control) | 9 | AC-3 |
| the sorted `cp "$REPO_ROOT/<path>"` set from the real `_lib.sh` is exactly the three confs | mechanical | 1 | AC-4 |
| per EXTRACTED path, stub fixture naming nothing -> conf answer (not R5's reason) | mechanical | 3 x 8 | AC-4 |
| header: backstop line once; fixture-conf block opens once; the 10 lines after the backstop are `#`, C-4's seven lines, blank, `set -uo pipefail` | mechanical | 3 | AC-5 |
| advance-story.md step 2 (`AS_STEP2`): new clause once, `or the library changed;` zero times | mechanical | 2 | AC-5 |

HARNESS-115's AC-1 and AC-2 blocks are not edited (AC-3's second half).

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

RED, 2026-11-20, Test Developer, dispatched as `test-developer` (declared
`opus`); resolved to Opus 5.5 (`claude-opus-5-5`), no override reported.

**Command.** `bash scripts/selftest.sh selftest-needed` (the whole suite;
the new cases are the `HARNESS-117` describe blocks at its end). Run as
`bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed`.

**Files touched (RED).** `.claude/tests/selftest-needed.test.sh` (the new
block, appended before `summary`; nothing above it edited),
`.claude/tests/floors.conf` (`floor | selftest-needed | 976` -> `1091`, plus
a log paragraph at the end), `.claude/tests/selftest.test.sh` (COUNTS row
`selftest-needed 976` -> `selftest-needed 1091`, `:557`), and this story's
`## Test plan` and this section. No Contract amendment.

**The run (local, Windows host, final RED tree; the failure
output below is quoted from that log).**

    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261120T063135Z.1770676.log
    selftest-needed: 1045 passed, 46 failed
    FAIL selftest-needed  did 1045 units of work, below the floor of 1091 in .claude/tests/floors.conf

1091 executed = the new floor. All 46 failures are in the HARNESS-117
block (the first FAIL in the log is the first assertion after the
`HARNESS-117 AC-1` describe line); every assertion above it is green,
HARNESS-115 AC-1/AC-2 included.

Verbatim, representative (from the log):

    FAIL AC-1: .claude/harness/phases.conf changed over the real suites answers all, saying it is copied into every fixture [from root]: stdout is exactly the pinned list
         expected: all
         actual:   lib
         plan
         refresh
         selftest-needed
    FAIL AC-1: .claude/harness/phases.conf changed over the real suites answers all, saying it is copied into every fixture [from root]: stderr is exactly the pinned text
         expected: selftest-needed: suites — all: .claude/harness/phases.conf is copied into every fixture make_fixture builds
         actual:   selftest-needed: suites — 4 of 35 selected from 1 harness path(s) changed against main (merge-base 28d26ea)
           lib              .claude/harness/phases.conf (mentioned)
           plan             .claude/harness/phases.conf (mentioned)
           refresh          .claude/harness/phases.conf (mentioned)
           selftest-needed  .claude/harness/phases.conf (mentioned)
    FAIL AC-2(b): models.conf, named by plain and declared fixture-only by decl, answers all, with no not-selected line [from root]: stderr is exactly the pinned text
         expected: selftest-needed: suites — all: .claude/harness/models.conf is copied into every fixture make_fixture builds
         actual:   selftest-needed: suites — 1 of 2 selected from 1 harness path(s) changed against main (merge-base 924cfcd)
           plain  .claude/harness/models.conf (mentioned)
           not selected (fixture-only): decl
    FAIL AC-4: .claude/harness/models.conf, copied by _lib.sh and named by no stub, changed alone answers all with the conf's reason, not R5's [from root]: stderr is exactly the pinned text
         expected: selftest-needed: suites — all: .claude/harness/models.conf is copied into every fixture make_fixture builds
         actual:   selftest-needed: suites — all: .claude/harness/models.conf is mapped by no rule; defaulting to every suite
    FAIL the header's fixture-conf block opens exactly once
    FAIL step 2 says every suite is chosen when the library or a fixture conf changed, once
         expected: 1
         actual:   0
    FAIL step 2 no longer says only `or the library changed;`
         expected: 0
         actual:   1

(AC-1 today selects 4, not table 2's 3, for `phases.conf`: this suite now
spells the conf whole, so its own copy is a mention. Expected; C-3 says so.)

**The 46 failures, by case** (per directory = root and src/):

| Case | Fails | Which assertions, and why that is the right failure |
|---|---|---|
| AC-1 paths/phases/models over the real suites | 3 x 6 = 18 | stdout, its line count, whole stderr: a mention list where `all` is expected |
| C-1 phases.conf beside `_lib.sh` | 2 | stderr only: today phases.conf sorts first and R5 gives `... is mapped by no rule; ...` (stdout is already `all`) |
| AC-2 (a) phases.conf alone | 4 | stdout (`named`) and stderr; the line count is 1 either way |
| AC-2 (a) phases.conf beside h117-other.conf | 6 | stdout (`named`, `other`), line count, stderr |
| AC-2 (b) models.conf, plain + declaring decl | 6 | stdout (`plain`), stderr, and the not-selected count (1, want 0) |
| AC-4, one per extracted path (3) | 3 x 2 = 6 | stderr only: stdout is `all` today, through R5 - exactly the case the whole-stderr needle exists for |
| AC-5 header | 2 | the block's first line (0 times), and the 10-line position pin |
| AC-5 advance-story.md step 2 | 2 | new clause 0 times, old `or the library changed;` once |

**Passing on arrival (69 of the 115), and what earns them.**

- AC-3's two controls (18): `.claude/harness/h117/phases.conf` prints
  exactly `nested`, `.claude/harness/paths.conf.bak` exactly `backup`, each
  with `hdr 1 2 1` and its `(mentioned)` reason line. They pass today
  because no conf step exists; after GREEN they pass only if the step
  matches whole paths. **Earned by DV-3 at GATES** (widen one arm to a
  glob, the `.bak` case must go red with stdout `all`). Not earned in RED.
- AC-2 (a)'s control (9): `.claude/harness/h117-other.conf` alone prints
  exactly `other` with its reason. It exists so the "beside a second changed
  path another stub names" case is provably beside a MAPPED path. It does
  not depend on the conf step; nothing GREEN does should move it.
- AC-4's set assertion (1): the sorted single-file `cp "$REPO_ROOT/..."`
  set of the real `_lib.sh` is the three confs today, as the AC's own
  "Today" says. Probe it (not done in RED; GATES' or an audit's choice):
  `bash scripts/mutate.sh .claude/tests/_lib.sh '122s/models\.conf"/models.conf.x"/' -- bash scripts/selftest.sh selftest-needed`
  would change the extracted set and must turn it red.
- AC-5's precondition (1): `# CI's full run is the backstop.` appears once
  in the header today, and must stay once.
- The other 40: every exit-status assertion of the conf cases (0 today
  and after), the line counts where today's list is one line (AC-2 (a)
  alone, AC-2 (b)), and the stdout/line-count halves of the C-1 and AC-4
  cases, which are already `all` through R5. In each such case the stderr
  assertion beside them is the one that discriminates, and it is red.

**Negative controls, expected values.** The suite does not fail at import:
every assertion above RAN in RED, against the shipped script, so these are
measured, not claims.

| Control | Threshold (pinned) | Measured in RED (log above) | Must hold after GREEN |
|---|---|---|---|
| AC-3 `.claude/harness/h117/phases.conf` | stdout exactly `nested`, header `1 of 2 ... 1 harness path(s)`, reason line once | passed, 9/9 | 9/9 |
| AC-3 `.claude/harness/paths.conf.bak` | stdout exactly `backup`, header `1 of 2`, reason line once | passed, 9/9 | 9/9 |
| AC-2 (a) `.claude/harness/h117-other.conf` | stdout exactly `other`, header `1 of 2`, reason line once | passed, 9/9 | 9/9 |
| HARNESS-115 AC-1 / AC-2 (unchanged) | their lists, as pinned | passed | passed |

**The shape the tests pin (GREEN builds exactly this).**

- `scripts/selftest-needed.sh --suites`: for a changed path exactly
  `.claude/harness/paths.conf`, `.claude/harness/phases.conf` or
  `.claude/harness/models.conf` (whole repo-relative path), stdout is the
  one line `all`, exit 0, and stderr is the one line
  `selftest-needed: suites — all: <path> is copied into every fixture make_fixture builds`
  - nothing else on stderr (no header, no not-selected line), from the root
  and from `src/`. When it is first in sort order among the paths that
  answer `all`, its reason wins (C-1 case: beside `.claude/tests/_lib.sh`).
  No mention, no `# fixture-only:` line changes that.
- `.claude/harness/h117/phases.conf` and `.claude/harness/paths.conf.bak`
  stay ordinary R3 paths.
- Header: the 10 lines directly after `# CI's full run is the backstop.`
  are exactly `#`, C-4's seven `# ...` lines in order, an empty line, and
  `set -uo pipefail`. C-4's opening line appears once in the file.
- `advance-story.md` step 2, joined with single spaces: `every suite when a
  path cannot be placed or the library or a fixture conf changed;` once,
  `or the library changed;` zero times. HARNESS-115's step-2 pins (the
  `fixture-only` clause, the step head line) must still hold.
- Not constrained: where in the loop the arm sits (as long as no rule ahead
  of it can set a different reason first for the conf itself), whether it
  shares R2's `case` or has its own, the variable names, the VERSION number.

**Attest records.**

    selftest-needed: last: 1 of 1 harness suite(s) FAILED.  log: .claude/state/attest-logs/20261120T063135Z.1770676.log
    selftest:        last: 1 harness suite(s) passed.  log: .claude/state/attest-logs/20261120T062746Z.1756905.log   (366 passed, floor met)
    gates --fast:    last: All required gates passed (0 ran, 5 unconfigured, 0 known).  log: .claude/state/attest-logs/20261120T063954Z.1786633.log

All three on tree `ca2b2ee7d7056ca101042ef073508996411d9a98`, the final RED tree. (An earlier selftest-needed run, `20261120T060457Z.1683477.log`, gave the identical 1045/46 on the tree before the floors.conf log comment.)

`gates.sh --fast` shape: every gate is UNCONFIGURED in this repository
(`BOOTSTRAPPED=no`), so it runs nothing and says so; there is no lint or
coverage gate that could refuse the test file. The suite's real judge is its
floor, which CI runs in full.

**Deferred verifications.** DV-1, DV-2 and DV-3 I cannot run: each mutates
or probes the conf step of `scripts/selftest-needed.sh`, which does not exist
until GREEN. Declined in RED, left to their owner, GATES.

**For GREEN.**

- The header block adds 8 lines above `set -uo pipefail`. No suite pins a
  `selftest-needed.sh:<line>` number (`grep -rn "selftest-needed.sh:[0-9]"
  .claude/tests/`: none), but `check-sigpipe.sh`/`check-grep-count.sh` scan
  the file; run them.
- Expected after GREEN: `selftest-needed: 1091 passed, 0 failed`.

**R-1 return (2026-11-20, Test Developer, `test-developer` declared `opus`,
resolved Opus 5.5 `claude-opus-5-5`, no override).** One case added after
the C-1 case: unmapped `.claude/aaa-h117-unmapped.txt` (sorts first)
beside phases.conf answers `all` with the unmapped path's R5 reason - pins
the conf arm's `[ -n "$why_all" ] ||` guard (C-1). +8 assertions; floor
1091 -> 1099 (`floors.conf`, `selftest.test.sh` COUNTS). Same command;
expected now `selftest-needed: 1099 passed, 0 failed`, measured so on the
shipped script. Passed on arrival; earned by the mutation in
`## Regressions` R-1. GREEN has nothing to build: no source change.

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

### R-1 (the conf arm's first-reason guard)

- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2), diff-review round 1 dispatch on the DIFF-REVIEW row: finding 1 routed RED, the guard on `scripts/selftest-needed.sh:284` unpinned; upheld by that dispatch, no separate ADJUDICATE needed.

**Why.** Diff review round 1, finding 1 (Nice to have, routed RED). The
orchestrator first left it; the user asked for it on 2026-11-20, so the
story returned from GATES to RED for this one test. No existing test was
wrong: the defect is a missing one. The conf arm
(`scripts/selftest-needed.sh:283-285`) sets its reason only when `why_all`
is still empty (`[ -n "$why_all" ] ||`), and the only HARNESS-117
sort-order case (C-1, phases.conf beside `.claude/tests/_lib.sh`) puts the
conf FIRST, so deleting the guard changed nothing any test saw.

**What was added.** One case in `.claude/tests/selftest-needed.test.sh`,
directly after the C-1 case (inside the `HARNESS-117 AC-1` describe
block): a stub fixture (`h117_fixture "quiet|reads nothing"`), phases.conf
edited (`h115_edit`), and an unmapped `.claude/aaa-h117-unmapped.txt`
written beside it, which sorts before `.claude/harness/`. Asserted with
`expect_suites ... 0 "all" whole "${SUITES_ALL}.claude/aaa-h117-unmapped.txt
is mapped by no rule; defaulting to every suite" --suites`, from the root
and from the subdirectory: +8 assertions. Floor `selftest-needed` 1091 ->
1099 in `.claude/tests/floors.conf` (with a log paragraph) and in
`.claude/tests/selftest.test.sh`'s COUNTS row. No production file edited.

**What earns it.** It passed on arrival against the shipped script, so one
mutation dropping the guard on the conf arm only (line 284, and nothing
else), through `scripts/mutate.sh`. Exactly the new case's two stderr
assertions went red; everything else stayed green; the restore was
verified byte for byte. Local, Windows host:

    $ bash scripts/mutate.sh scripts/selftest-needed.sh 's#\[ -n "\$why_all" \] || why_all="\$p is copied#why_all="$p is copied#' -- bash scripts/selftest.sh selftest-needed
    === mutate: scripts/selftest-needed.sh (1 line(s) changed by s#\[ -n "\$why_all" \] || why_all="\$p is copied#why_all="$p is copied#) ===
      284 -         [ -n "$why_all" ] || why_all="$p is copied into every fixture make_fixture builds"
      284 +         why_all="$p is copied into every fixture make_fixture builds"

    === mutate: running bash scripts/selftest.sh selftest-needed ===
    ...
      HARNESS-117 AC-1: one conf changed over the real suites answers all, with the conf's reason
        FAIL C-1: an unmapped .claude/aaa-h117-unmapped.txt, first in sort order, keeps its reason when phases.conf changes beside it [from root]: stderr is exactly the pinned text
             expected: selftest-needed: suites — all: .claude/aaa-h117-unmapped.txt is mapped by no rule; defaulting to every suite
             actual:   selftest-needed: suites — all: .claude/harness/phases.conf is copied into every fixture make_fixture builds
        FAIL C-1: an unmapped .claude/aaa-h117-unmapped.txt, first in sort order, keeps its reason when phases.conf changes beside it [from subdir]: stderr is exactly the pinned text
             expected: selftest-needed: suites — all: .claude/aaa-h117-unmapped.txt is mapped by no rule; defaulting to every suite
             actual:   selftest-needed: suites — all: .claude/harness/phases.conf is copied into every fixture make_fixture builds
    ...
    selftest-needed: 1097 passed, 2 failed
    FAIL selftest-needed  did 1097 units of work, below the floor of 1099 in .claude/tests/floors.conf

    assertion floors: 0 of 1 suite(s) met their declared floor.
    1 of 1 harness suite(s) FAILED.

    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-117/.claude/state/mutations/scripts_selftest-needed.sh.20261120T152402Z.2064788.bak) ===
      284:         [ -n "$why_all" ] || why_all="$p is copied into every fixture make_fixture builds"

Those were the only two FAIL lines in the run. 1097 + 2 = 1099 executed,
which is the new floor. The case's stdout and exit assertions pass under the
mutant too: stdout is `all` either way, as the finding said.

**Unmutated, the same tree (attest).** 768 s and 436 s (local,
Windows host, under load from other sessions):

    selftest-needed: 1099 passed, 0 failed  (floor 1099 met)
      exit: 0  last: 1 harness suite(s) passed.  log: .claude/state/attest-logs/20261120T164016Z.2145225.log
    selftest: 366 passed, 0 failed  (floor 366 met)
      exit: 0  last: 1 harness suite(s) passed.  log: .claude/state/attest-logs/20261120T165327Z.2181347.log

Both on tree `86a94a8c4fcf6386dac2e07d5e267b40c20d6255`, recorded before this
entry was written. **GREEN is a no-op**: `scripts/selftest-needed.sh` is
unchanged (`git status --short scripts/` empty after the restore).

## Diff review

### Round 1 (2026-11-20) — `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`)

Reviewed `git diff origin/main...HEAD` after the merge of `origin/main`
(4bb0f54). No file changed.

What I checked:
- The rule (`scripts/selftest-needed.sh:283-285`) sits inside the
  `if [ "$MODE" = suites ]` block, a whole-path `case` arm with R2's
  guard-and-`continue` shape. Run/skip mode is not touched.
- In a scratch clone: a conf edited, deleted (staged), renamed, edited beside
  an earlier-sorting mapped path, and run from `scripts/` all print `all`,
  exit 0, with the pinned reason; run/skip mode prints `run`, exit 0, for
  each. Controls: `.claude/harness/project.conf` and `rules.md` still print
  their by-mention lists (6 and 8 of 35).
- The caller, `scripts/selftest.sh --changed` (`:312-320`), takes `rc=0` and
  stdout `all` and builds its header from the text after `all: `; the new
  reason has that shape. No change needed there.
- All three confs classify as `harness`; `_lib.sh` has exactly three
  single-file copies from `$REPO_ROOT` (`:120-122`), matching AC-4.
- Floor arithmetic: 976 + 115 = 1091 in `floors.conf` and the COUNTS table;
  DV-1's run executed 1049 + 42 = 1091. 35 suites after the merge.
- `advance-story.md:310` changed in place; no other suite pins the old
  clause; no other document lists the R2 paths.

**Nice to have:**

1. **The conf arm's "first reason wins" guard has no test that fails without
   it** (`scripts/selftest-needed.sh:284`; `selftest-needed.test.sh:1539-1543`).
   The only sort-order case puts the conf first. With an unmapped
   `.claude/aaa-h117-unmapped.txt` and `phases.conf` both changed, the script
   prints the unmapped path's R5 reason; with the guard deleted it prints the
   conf's. Stdout is `all` either way and `selftest.sh --changed` runs every
   suite either way; only which true reason line prints changes.
   Fix: one case beside the C-1 case, floor raised, earned by one mutation.
   **Route:** RED

Not checked: the `selftest-needed` suite on the merged tree (left to the
orchestrator's self-test run).

Verdict: Ship.

**Orchestrator, on the Nice to have (2026-11-20):** not taken in this story.
It is a return to RED for a reason-line choice that changes no selection, and
the verdict is Ship. Recorded here; the user was told it was left.

### Round 2 (2026-11-20) — `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`)

Reviewed `git diff dd9038c HEAD -- .claude/tests`, R-1, and the whole story
diff. No file changed; no `selftest.sh` command run.

What I checked:
- R-1's mutation earns the case: whole-stderr `assert_eq`, one line mutated
  (284, the conf arm only), two FAILs, both the new case (root and subdir),
  `1097 passed, 2 failed` = 1099; restore verified.
- Reproduced in a scratch clone with a path of my own: guard present keeps
  the unmapped reason, guard dropped prints the conf's; renamed to sort after
  the conf, the conf's reason prints, so the case depends on sort order.
- Floor: 4 assertions × 2 directories = 8; 1091 + 8 = 1099 in both places.
- The new case builds its own fixture; no earlier pin moves.
- Against today's `origin/main` (HARNESS-119 merged since round 1): a trial
  merge is clean; HARNESS-119's edits to `selftest-needed.test.sh` do not
  touch the HARNESS-117 cases.

**Should fix:**

1. **Two different harness releases would both be numbered 137**
   (`.claude/harness/VERSION`). HARNESS-119 merged and `origin/main` is now
   also `137 (2026-11-20)`; git merges the identical line silently, and the
   VERSION check in `check-boundaries.sh:267` is skipped on story branches.
   Fix: merge `origin/main`, set `VERSION` to `138 (2026-11-20)`, run the gates
   again. If skipped, two consumers on different code both report 137.
   **Route:** GATES

Not checked: the suites on the tree after merging `origin/main`.

Verdict: fix 1 first.

**Orchestrator (2026-11-20):** `classify.sh .claude/harness/VERSION` →
`harness`; a GATES label on a harness path is followable. Taken in GATES:
`origin/main` merged by the orchestrator, `VERSION` set by a
feature-developer dispatch.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-20T18:00:39Z
    commit: 44702dd (working tree had uncommitted changes)
    tree:   77d0813f2908cb4399a48c2b5292ad7fe5f1762a
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

- **Planned 2026-11-19 on release 135 (`da9d4bb`)** in the worktree
  `D:\adh-HARNESS-117`, branch `story/HARNESS-117-plan`. The id was checked
  free on `origin/main`, the remote branches and the PR titles before
  planning. Nothing is committed and the phase is not set. The story's
  `branch:` is `story/HARNESS-117-conf-change-selects-every-suite`; the
  planning branch is renamed or the story branch cut before RED.
- **D-1, a PO decision for the user: what to do about the conf copies.**
  The measurement is in the Context. The options:
  1. *A change to one of the three confs answers `all`* (recommended; the
     story as written). One `case` arm beside R2's. A conf change then
     selects 35 of 35 where it selects 8, 3 and 4 today. The cost is a full
     local self-test on the stories that change a conf: 15 commits in the
     repository's life, 4 on or after 2026-10-05. That is what a change to
     `_lib.sh` already costs. Nothing to maintain, and no suite can make it
     stale.
  2. *Select only the suites that call the helper,* plus the mentions: 24
     of 35 today. It saves the 11 suites that build no fixture, 1011 of
     6983 floored assertions and none of the slow ones (`boundaries`,
     `gates`, `run-queue` and `selftest-needed` all call the helper), so
     the saving in time is small. It costs a second scan of every suite, a
     new reason, and it has a hole: `manifest_fixture` in `_lib.sh:307`
     wraps `make_project_fixture`, and a suite that used only the wrapper
     would not be found by name. Its two callers today (`doctor`, `gates`)
     also name the helper; the next need not. HARNESS-116 rejected this
     shape for `VERSION` because `VERSION` changes every story. That
     objection does not apply here, and the shape is sound; it buys little
     over option 1 for more code.
  3. *Each suite that depends on a conf names it,* so plain mention selects
     it. Up to 22 suites to edit for `phases.conf`, and "depends" cannot be
     read off: `phase` was green under M-1 and sets a phase in every case.
     A new suite forgets. Rejected.
  4. *The helper stops copying and fixtures get fixed confs.* Rejected:
     the confs under test are the shipped rules. `phase-guard` over a
     frozen copy would stay green while the shipped `phases.conf` was
     wrong, so M-1 would be green everywhere, CI included.
  5. *No change; keep the measurement as the record.* Defensible: CI runs
     every suite on every PR, and the gap costs one CI round trip on a rare
     story. Not recommended: M-1 and M-2 show the local run passing a
     break in the phase lock's own rules, and the local run is what is
     relied on before a PR is opened.
- **Q-1, for the user.** Is option 1 the one to build, or option 2? The
  story's criteria are written for option 1; option 2 changes AC-1's
  expected answer from `all` to a pinned list of 24 or more and needs the
  story re-planned before RED.
- **Q-2, for the user.** Keep `models.conf` in the rule? No unselected
  suite went red under M-3 or M-4, so by the measurement alone the four
  suites that mention it are enough today. The story includes it
  (recommended): the helper copies it exactly as it copies the other two,
  AC-4 then holds for everything the helper copies with no exception to
  explain, and the cost is a full run on a file with 5 commits in its
  life. Leaving it out is defensible and changes AC-1 (two cases), AC-2
  (b), AC-4 (the set is three, two of them in the rule and one named as
  left to mention) and the two texts of C-4.
- **A correction to the brief's command.** `bash scripts/mutate.sh <file>
  '<expr>' -- SELFTEST_JOBS=4 bash scripts/selftest.sh ...` does not run:
  `mutate.sh` executes the words after `--` as a command, so the assignment
  is taken for one (`scripts/mutate.sh: line 493: SELFTEST_JOBS=4: command
  not found`, exit 127, file restored). The runs here put the assignment in
  front: `SELFTEST_JOBS=4 bash scripts/mutate.sh ... -- bash
  scripts/selftest.sh ...`. `attest.sh` does accept a leading assignment
  after `--` (its suite pins it); `mutate.sh` does not. Not a defect this
  story fixes.
- **Not already delivered.** Reproduced at PLANNED on `da9d4bb`: table 2,
  M-1 and M-2.
- **Not split.** One behaviour (three paths join one existing step), one
  script, one suite.
- **Collisions, read by hand.** `floors.conf`, `selftest.test.sh` and
  `VERSION` are written by every harness story; any story in flight shares
  them and is a collision, not a dependency. Whichever merges second merges
  `main`, takes the next release number and has its gates run again.
- **The story's own `--changed` run at GATES** will not answer `all`: it
  changes no conf. It selects by mention of `scripts/selftest-needed.sh`,
  `advance-story.md` and the suite files, as any story does.
- **Answers from the user, 2026-11-19.** D-1: option 1, a change to one of
  the three confs answers `all` ("Every suite (Recommended)"). Q-1 is settled
  by that answer: the story stands as written. Q-2: keep `models.conf` in the
  rule ("Include it (Recommended)"). No criterion changes. The planning branch
  was renamed to `story/HARNESS-117-conf-change-selects-every-suite` and the
  story committed at PLANNED as `c9107b1`.
- **Release number (GREEN, 2026-11-20).** HARNESS-118 merged to main while
  this story ran and took release 136, so this story's `VERSION` is
  `137 (2026-11-20)`. HARNESS-118 touched no file this story declares besides
  `VERSION`; `origin/main` is merged into the branch before the PR opens.
- **GREEN verified (orchestrator, 2026-11-20).** `attest.sh check` was `fresh`
  for both `bash scripts/selftest.sh selftest-needed` (exit 0,
  `selftest-needed: 1091 passed, 0 failed`, log
  `.claude/state/attest-logs/20261120T065412Z.1793557.log`) and
  `bash scripts/gates.sh --fast` (exit 0, every gate unconfigured). Not re-run.
  The feature developer confirmed every RED control value against the built
  script; measured equalled expected for all six.
- **GREEN after R-1 (orchestrator, 2026-11-20): a no-op, verified.** R-1
  added a test for code that already existed; nothing to build.
  `attest.sh check -- bash scripts/selftest.sh selftest-needed` was `fresh`,
  exit 0, `selftest-needed: 1099 passed, 0 failed` (log
  `.claude/state/attest-logs/20261120T164016Z.2145225.log`). Not re-run.
