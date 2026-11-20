---
id: HARNESS-116
title: Fixtures carry their own harness stamp
slug: fixtures-carry-their-own-harness-stamp
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-116-fixtures-carry-their-own-harness-stamp
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/_lib.sh, .claude/tests/lib.test.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/doctor.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the lib and doctor suites under their selftest floors, which CI runs in full on the PR
---

## Context

`bash scripts/selftest-needed.sh --suites` picks the suites
`selftest.sh --changed` runs before a PR, and its rule R3 selects by
mention: a suite is selected for a changed path when its source names the
path (HARNESS-115 added the `# fixture-only:` declaration). That is sound
only while a suite that never names a path does not read it.

`make_fixture` in `.claude/tests/_lib.sh` (line 124 at release 134) breaks
that for one file: it copies the REAL `.claude/harness/VERSION` into every
fixture, and `make_project_fixture` builds on it. 24 of the 35 suites call
one or the other. Two of them (`doctor`, `worktree`) also name the path and
are selected; the other 22 carry the real file's bytes in their fixtures
and are never selected for it. Every harness story changes `VERSION`.
HARNESS-115's planning recorded this as a finding and did not measure it.

This story measures it, and then removes the read: the helper writes a
fixed stamp of its own, so no fixture's content depends on the real file.

**The measurement, PLANNED, 2026-11-19, release 134 (`0e52de3`), worktree
`D:\adh-HARNESS-116`.**

*Who gets the real file, and who reads its content.* Three scripts read
`VERSION`: `scripts/doctor.sh:68` (`release_of`, printed and compared with
the main checkout's), `scripts/refresh-harness.sh:147-148` (printed) and
`scripts/check-boundaries.sh:270-271` (the base's bytes against the tree's,
equality only). No hook reads it; nothing parses it.

| Suite | How it gets the real `VERSION` | Runs a script that reads it, in that fixture? | Selected for `VERSION` today |
|---|---|---|---|
| doctor | `make_project_fixture`; and reads the real file directly at `:102` and `:340` | `doctor.sh` | yes (mention) |
| worktree | `make_project_fixture` x2 (`:68`, `:69`) | `doctor.sh` x6, `refresh-harness.sh` x1; `num` at `:343` is the copied stamp | yes (mention) |
| boundaries | `make_fixture`, `make_project_fixture`; overwrites it with its own at `:1129`, `:1136` | `check-boundaries.sh` (equality only) | no (declared `fixture-only`) |
| attest, ci-local, classify, gates, grep-count, host-load, mutate, phase, plan, profiles, run-lock, run-queue, selftest, selftest-needed, sigpipe, story | `make_project_fixture` | `check-boundaries.sh` in some (equality only); none runs `doctor.sh` or `refresh-harness.sh` | no |
| gate-reminder, lib, phase-guard, settings, spawns | `make_fixture` | none | no |
| selftest-needed | also `cp -r "$REPO_ROOT/.claude/harness"` at `:204` and `:703`, not through the helper | none (`selftest-needed.sh` does not read it) | no |
| security-audit | no helper; runs the real `refresh-harness.sh` with this checkout as the upstream (`:495`), which prints the real stamp | `refresh-harness.sh`, on the real tree | no |
| refresh | no helper; writes its own upstreams | `refresh-harness.sh` | no (declared `fixture-only`) |

HARNESS-115's note that `story` "runs `doctor.sh` in such a fixture once"
is wrong: `story.test.sh:457` prints the words `bash scripts/doctor.sh`
into a fixture `CLAUDE.md` and runs nothing. The only suites that execute
`doctor.sh` are `doctor` and `worktree` (`grep -n 'bash [^|;]*doctor\.sh'`
over `.claude/tests/*.test.sh`).

*The runs.* Each is one `mutate.sh` run, restore verified by `mutate.sh`;
`SELFTEST_JOBS=4`; four other gate runs were on the host.

| | Mutation | Suites | Result |
|---|---|---|---|
| A | real `VERSION`, `$s/.*/135 (2026-11-20)/` (a plausible next release) | the 24 helper suites, `security-audit`, `refresh` | **all 26 green**, 6227 assertions, exit 0, 41 min |
| B | real `VERSION`, `$d` (the stamp line deleted: unstamped) | the same 26 | **25 green; `doctor` red**, 67 passed, 2 failed: "the shipped version starts with a release number", "and carries the real release date" (its direct reads of the real file at `:340`). Exit 1, 21 min |
| C | `_lib.sh` line 124 replaced by a `printf` of `1 (2000-01-01)` into the fixture (this story's fix, prototyped) | doctor, lib, story, worktree | **`doctor` red**, 68 passed, 1 failed: "and it is the one in the file" (`:102`, expects the real stamp in the fixture's output); lib 324, story 97, worktree 73, all green |
| D | real `VERSION`, `$s/.*/44 (2026-09-01)/` (HARNESS-115's M-2, repeated at 134) | worktree | **red**, 70 passed, 3 failed: "a linked worktree behind the main checkout is MISSING, naming both releases", "and is not also reported ok", "and doctor exits 1 on the mismatch" |

    === mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-116/.claude/state/mutations/.claude_harness_VERSION.20261119T215204Z.17336.bak) ===
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-116/.claude/state/mutations/.claude_harness_VERSION.20261119T223256Z.231350.bak) ===
    mutate: no stranded mutation; nothing of a previous run is in the tree.

**What it shows.** No unselected suite fails under either mutation of the
real file: the 22 unselected helper suites, `security-audit` and
`selftest-needed` are green under A and B. A local `--changed` run cannot
today pass a release bump that CI's full run then fails. A green run under
a mutation shows only that this mutation did not reach the suite; the
result also rests on the reading above (no unselected suite runs a script
that prints or parses the stamp). Run A is also what every merged PR has
already shown: CI ran all suites over each release bump.

What the helper's copy does do, all of it in selected suites:

- `worktree` depends on the real stamp only through the helper (run D): it
  fails when the real file says `44 (2026-09-01)`, the value the suite
  writes into a linked worktree to make it "behind". A real release cannot
  take that value again; the dependency is real and inert.
- `doctor.test.sh:102` compares `doctor.sh`'s output in the fixture with the
  real file, which only works because the fixture holds a copy. Under run
  B both were empty and that assertion passed on an empty needle: it
  cannot tell "doctor printed the stamp" from "there was no stamp to
  print". A fixture stamp that differs from the real one lets the
  assertion show that `doctor.sh` reads the tree it runs in.
- Nothing stops the next suite from running `doctor.sh` in a helper fixture
  and asserting on the stamp without naming the path. It would be
  unselected and would read the real file.

**The required gate.** Every gate in `project.conf` is unconfigured here.
The artifact is judged by the `lib` and `doctor` suites under their floors
in `floors.conf`, which CI runs in full on the PR. Locally, `_lib.sh` is an
R2 path, so `selftest-needed.sh --suites` answers `all` for this story.

## Acceptance criteria

In all of these, "the fixture stamp" is the one line `1 (2000-01-01)`, and
"the real stamp" is the first line of the real `.claude/harness/VERSION`
that is neither blank nor a comment (`134 (2026-11-19)` at PLANNED).

- **AC-1 (reproduces the read)** — Given the real tree, when `make_fixture`
  builds a fixture, then the fixture's `.claude/harness/VERSION` is exactly
  the fixture stamp followed by one newline and nothing else, and the
  fixture stamp is not the real stamp. *(Today the file is a byte copy of
  the real one, comments included.)*
- **AC-2** — Given the real tree, when `make_project_fixture` builds a
  fixture, then its `.claude/harness/VERSION` is the same single line, and
  it is in the fixture's commit: `git show HEAD:.claude/harness/VERSION`
  prints it, and `git status --porcelain` names no path.
- **AC-3 (the stamp does not follow the tree)** — Given a stand-in root
  holding its own `paths.conf` and `phases.conf` and a `VERSION` that says
  `999 (2099-12-31)`, when `make_fixture` runs with `REPO_ROOT` set to that
  root, then the fixture's `.claude/harness/VERSION` is the fixture stamp
  and `999` appears nowhere in it. *(Today the fixture gets `999
  (2099-12-31)`; that RED failure is also what shows the stand-in root
  reaches the helper.)*
- **AC-4 (`doctor.sh` reads the tree it runs in)** — Given a project
  fixture and a real stamp that is not empty, when `doctor.sh` runs in the
  fixture, then its `harness ver` row carries the fixture stamp, and the
  real stamp appears nowhere in its output. An empty real stamp fails the
  test instead of matching everything. *(Today the row carries the real
  stamp.)*
- **AC-5 (control: the suite that reads the real file still does)** —
  Given the real `VERSION`, when the `doctor` suite runs, then it still
  asserts on the real file that the stamp starts with a release number and
  carries a date in brackets, by reading
  `"$REPO_ROOT/.claude/harness/VERSION"`, so `selftest-needed.sh --suites`
  still selects `doctor` for a `VERSION` change by plain mention. No
  assertion is removed from `doctor.test.sh`.

## Contract

**Writes:** `.claude/tests/_lib.sh`, `.claude/tests/lib.test.sh`, `.claude/tests/doctor.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

Every path above classifies as `harness`, so the lock permits each in every
phase; who writes what is by role. RED (Test Developer): `lib.test.sh`,
`doctor.test.sh`, the `lib` and `doctor` floors in `floors.conf` and their
entries in `selftest.test.sh`. GREEN (Feature Developer): `_lib.sh` (the
helper is the thing under test here) and `VERSION` (the next free release
number when the branch is cut; 135 at PLANNED).

**C-1. The helper.** In `make_fixture`, the line

    cp "$REPO_ROOT/.claude/harness/VERSION"     "$d/.claude/harness/VERSION" 2>/dev/null

and the two comment lines above it are replaced by a write of the fixture
stamp: the file `$d/.claude/harness/VERSION` holds the 14 characters
`1 (2000-01-01)` and a newline, with no comment lines. The value is a
literal in `_lib.sh`; no variable is exported for it, and a suite that
wants the stamp reads the fixture's file. Why this value: it has the
shipped shape (`<number> (<date>)`), so `doctor.sh` and `worktree.test.sh`'s
`harness $num([^0-9]|$)` treat it as they treat a real one; `1` is lower
than every number a real release can take from here, so a fixture never
looks newer than the harness; and it is none of the values a suite writes
for itself (`44 (2026-09-01)`, `99 (2099-01-01)`, `2026-09-16`,
`2026-01-01`). The comment that replaces the old one says that the stamp is
the fixture's own, on purpose, and that `paths.conf`, `phases.conf` and
`models.conf` are still copies of the real ones (unchanged, and stated at
the top of the function). `make_project_fixture` is not edited: it calls
`make_fixture` and commits what it finds.

No signature changes. `make_fixture` and `make_project_fixture` keep their
names, arguments and output. The callers are the 24 suites of the Context
table; runs A, B and C say which of them notice the content:
`doctor.test.sh:102`, and nothing else.

**C-2. `lib.test.sh`** holds AC-1, AC-2 and AC-3, in a block of their own
at the end, under `describe` lines that start `HARNESS-116`. Each compares
with the literal `1 (2000-01-01)`, written out in the test, never with a
value read back from `_lib.sh` or from the fixture. AC-1's "exactly" is a
whole-file comparison (the file's content against the literal), not a
`grep`. AC-3 builds its stand-in root under a temp directory of the
suite's own and calls the helper in a subshell,
`( REPO_ROOT="$stand"; make_fixture )`, so the suite's own `REPO_ROOT` is
untouched; the stand-in's `paths.conf` and `phases.conf` may be copies of
the real ones. Every fixture and directory the block makes is removed
when the suite exits.

**C-3. `doctor.test.sh`.**

- `:102`, "and it is the one in the file": the expected value becomes the
  literal `1 (2000-01-01)`, on the `harness ver` row, and an assertion is
  added that the real stamp (read as `:102` reads it today) is not in the
  output. Before that one, the test fails with `_bad` if the real stamp is
  empty.
- `:340`-`:351`, the two shape assertions on the real file: unchanged
  (AC-5). They are the suite's real read and the reason it stays selected.
- `:362`, the restore after the legacy-date block: writes the fixture
  stamp back, not `$first`, so the fixture never carries the real stamp.
- The suite gets no `# fixture-only:` line.

**C-4. Floors.** `lib` rises by the number of assertions C-2 adds and
`doctor` by the number C-3 adds; both in `floors.conf` and in the COUNTS
table of `selftest.test.sh`. `selftest.test.sh:575-576` also pins `lib`'s
floor as the literal `324`, in the assertion's name and in its expected
value; both move with it.

**C-5. Docs.** No document outside `_lib.sh` states that fixtures hold the
real stamp (`grep -rn "real stamp\|COPIES OF THE REAL"` at PLANNED:
`_lib.sh:112` and `:122`, and `selftest.test.sh:56`, which is about
`paths.conf` and stays). `scripts/selftest-needed.sh` is not edited: no
rule changes.

**Oracle partition.** All five criteria are mechanical: pin the literal,
the whole file, the row. Nothing is to be derived or calibrated.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". DV-1 is the defect put
back for the central claim. DV-2 is one run more than the default, and the
reason is that it is the only observation of the claim on the real file:
the suites' own assertions use fixtures and a stand-in root, and run D is a
measured red to set it against. RED cannot run either: the helper still
copies the real file until GREEN.

- **DV-1, the defect put back (AC-1, AC-2, AC-3).** With the helper's write
  of the fixture stamp replaced by the old copy of
  `"$REPO_ROOT/.claude/harness/VERSION"`, `lib` **must** fail, in the
  HARNESS-116 block and nowhere else, and AC-3's assertion must show
  `999 (2099-12-31)` as its actual value. The expression is written at
  GATES against the helper as built, must change code and not a comment,
  and is recorded with the result. Run against
  `bash scripts/selftest.sh lib`. **Owner: GATES.**

  **DV-1 result (GATES, 2026-11-19, run by the orchestrator): PASSED.**
  `lib` went red in the HARNESS-116 block only, AC-3 showing
  `999 (2099-12-31)`; the file was restored and verified.

    bash scripts/mutate.sh .claude/tests/_lib.sh '/printf .1 (2000-01-01)/c\  cp "$REPO_ROOT/.claude/harness/VERSION"     "$d/.claude/harness/VERSION" 2>/dev/null' -- bash scripts/selftest.sh lib
    === mutate: .claude/tests/_lib.sh (1 line(s) changed by ...) ===
        126 -   printf '1 (2000-01-01)\n' > "$d/.claude/harness/VERSION"
        126 +   cp "$REPO_ROOT/.claude/harness/VERSION"     "$d/.claude/harness/VERSION" 2>/dev/null
          FAIL HARNESS-116 AC-1: make_fixture's VERSION is exactly '1 (2000-01-01)' and one newline
          FAIL HARNESS-116 AC-2: make_project_fixture's VERSION is exactly '1 (2000-01-01)' and one newline
          FAIL HARNESS-116 AC-2: git show HEAD:.claude/harness/VERSION prints the fixture stamp
          FAIL HARNESS-116 AC-3: under a stand-in root saying 999, the fixture's VERSION is exactly '1 (2000-01-01)'
               expected: 1 (2000-01-01)
               x
               actual:   999 (2099-12-31)
          FAIL HARNESS-116 AC-3: and 999 appears nowhere in the fixture's VERSION
    lib: 327 passed, 5 failed
    === mutate: command exited 1; restored (verified byte-for-byte against .../.claude_tests__lib.sh.20261120T001610Z.480290.bak) ===

- **DV-2, run D repeated on the built tree (the story's claim, on the real
  file).** At PLANNED, with the real stamp set to `44 (2026-09-01)`,
  `worktree` is red: 70 passed, 3 failed (Context, run D). On the GREEN
  commit the same run **must** be green, 73 passed and 0 failed, because
  no fixture holds the real stamp any more. If `worktree`'s assertion
  count has moved by then for another reason, the condition is "0 failed,
  and the three assertions named in run D pass". **Owner: GATES.**

    bash scripts/mutate.sh .claude/harness/VERSION '$s/.*/44 (2026-09-01)/' -- bash scripts/selftest.sh worktree

  **DV-2 result (GATES, 2026-11-19, run by the orchestrator): PASSED.**
  Measured red at PLANNED (70 passed, 3 failed); on the GREEN commit:

    worktree: 73 passed, 0 failed
    === mutate: command exited 0; restored (verified byte-for-byte against .../.claude_harness_VERSION.20261120T001658Z.483650.bak) ===

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

Planned by `bash scripts/plan.sh write HARNESS-116` from `.claude/harness/models.conf`.
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
- RED: `test-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- GREEN: `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- GATES (full gates): `feature-developer`, planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- DIFF-REVIEW round 1: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override.

## Out of scope

- **`scripts/selftest-needed.sh` and its rules.** No rule changes; the
  story removes a read instead of teaching the selection to see it.
- **A `# fixture-only:` line for `worktree`.** After this story `worktree`
  no longer reads the real stamp, so it could declare the path and drop
  out of every later story's `--changed` run. That changes the lists
  HARNESS-115's AC-1 and AC-2 pin in `selftest-needed.test.sh` and is a
  second behaviour; it is a follow-up for the user to ask for (Notes, Q-1).
  Until then `worktree` is selected when it need not be, which is the safe
  direction.
- **`paths.conf`, `phases.conf` and `models.conf`.** `make_fixture` still
  copies the real ones, on purpose: the rules under test are the shipped
  ones. Whether every suite that reads them through the helper is selected
  when they change is a separate question (Notes, Q-2).
- **`selftest-needed.test.sh`'s `cp -r` of the real `.claude/harness`** and
  **`security-audit`'s use of this checkout as the upstream.** Both reach
  the real `VERSION` without the helper; both were green under runs A and
  B; neither is edited.
- **`scripts/doctor.sh`, `scripts/refresh-harness.sh`,
  `scripts/check-boundaries.sh`.** Not edited.
- **Any other suite.** Runs A, B and C say no other suite notices the
  stamp's content. If the full self-test at GATES shows one that does,
  that is a finding to record and route, not a licence to edit it here.
- **An exported variable for the fixture stamp.** Not added.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

Level: shell unit tests in the harness's own suites. The helper is a bash
function, so `lib.test.sh` calls it directly (AC-1..AC-3); `doctor.test.sh`
runs the copied `doctor.sh` in a project fixture (AC-4, AC-5). Every
assertion is unconditional, so the executed count is fixed. All criteria are
mechanical: each pins the literal `1 (2000-01-01)`, written out in the test.

| AC | Suite | Assertion (exact name) | Red in RED? |
|---|---|---|---|
| AC-1 | lib | `HARNESS-116 AC-1: make_fixture's VERSION is exactly '1 (2000-01-01)' and one newline` | **red** |
| AC-1 | lib | `HARNESS-116 AC-1: the real stamp is not empty and is not the fixture stamp` | green (precondition) |
| AC-2 | lib | `HARNESS-116 AC-2: make_project_fixture's VERSION is exactly '1 (2000-01-01)' and one newline` | **red** |
| AC-2 | lib | `HARNESS-116 AC-2: git show HEAD:.claude/harness/VERSION prints the fixture stamp` | **red** |
| AC-2 | lib | `HARNESS-116 AC-2: and the project fixture's git status --porcelain names no path` | green (guard) |
| AC-3 | lib | `HARNESS-116 AC-3: the fixture was built from the stand-in root (its paths.conf)` | green (reach control) |
| AC-3 | lib | `HARNESS-116 AC-3: under a stand-in root saying 999, the fixture's VERSION is exactly '1 (2000-01-01)'` | **red** |
| AC-3 | lib | `HARNESS-116 AC-3: and 999 appears nowhere in the fixture's VERSION` | **red** |
| AC-4 | doctor | `HARNESS-116 AC-4: the real stamp is not empty` | green (precondition) |
| AC-4 | doctor | `and it is the one in the file` (`:102`, respelled: `assert_eq` on the whole `harness ver` row, `  ok       harness ver  1 (2000-01-01)`) | **red** |
| AC-4 | doctor | `HARNESS-116 AC-4: and the real stamp appears nowhere in doctor's output` | **red** |
| AC-5 | doctor | `the shipped version starts with a release number`, `and carries the real release date` (unchanged, still read `"$REPO_ROOT/.claude/harness/VERSION"`) | green (control) |

Whole-file comparison (AC-1, AC-2, AC-3): `h116_file f` is `cat f; printf x`,
compared with `$'1 (2000-01-01)\nx'`, so trailing newlines are not stripped
the way a bare `$(cat f)` strips them. A missing newline, an extra line or a
kept comment header each change the compared string. AC-2's `git show` is
compared the same way.

AC-3's stand-in root is `$h116_work/stand` (the block's own `mktemp -d`),
holding copies of the real `paths.conf` and `phases.conf`, the stand-in's
`paths.conf` carrying one extra line `# HARNESS-116 stand-in root`, and
`VERSION` = `999 (2099-12-31)`. The fixture is made by
`h116_sfix="$( ( REPO_ROOT="$h116_stand"; make_fixture ) )"`. The marker
assertion is what keeps AC-3 meaningful after GREEN: without it, a helper
that ignored `REPO_ROOT` altogether would satisfy the stamp assertions.

The C-3 restore at `doctor.test.sh` (after the legacy-date block) writes
`1 (2000-01-01)` back, not `$first`. No `# fixture-only:` line was added to
`doctor.test.sh`; the `:340`-`:351` block is untouched.

Cleanup: `lib.test.sh`'s single `trap ... EXIT` is re-set in the block to
remove `$FIX`, `$h116_work` (and the stand-in in it), `$h116_fix`,
`$h116_pfix` and `$h116_sfix`. `doctor.test.sh` makes no new fixture.

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

**R-1 return (2026-11-20): GREEN on re-entry is a no-op.** The return
corrected three HARNESS-115 pins in `.claude/tests/selftest-needed.test.sh`
(`lib` now selected for a VERSION change, because `lib.test.sh:1176` reads
the real stamp) and raised the selftest-needed floor 970 -> 976 in
`.claude/tests/floors.conf` and `selftest.test.sh`. No source file changed
and none needs to: `bash scripts/selftest.sh selftest-needed selftest lib`
is green as handed over. See `## Regressions`, R-1.

Written by the Test Developer, dispatched on `opus`; resolved model
`claude-opus-5-5` (Opus 5.5), no override.

**Command.** `bash scripts/selftest.sh lib doctor` (both suites, about 3.5
min locally). `bash scripts/selftest.sh lib` alone for DV-1.

**Attested run on the final test tree** (Windows host, local):

    run:      2026-11-20T00:06:12Z
    command:  bash scripts/selftest.sh lib doctor
    tree:     50eedd6ad81735c7469971c072fd58ba232d52d2
    exit:     1
    last:     2 of 2 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261120T000612Z.462584.log

Also on this tree: `bash scripts/selftest.sh selftest` (the COUNTS table and
the `lib is floored at its 332` pin moved): exit 0, `last: 1 harness suite(s)
passed.`, `selftest: 366 passed, 0 failed`, log
`.claude/state/attest-logs/20261120T000938Z.467417.log`. And
`bash scripts/gates.sh --fast`: exit 0, `last: All required gates passed (0
ran, 5 unconfigured, 0 known).`, log
`.claude/state/attest-logs/20261120T001217Z.473415.log`. Vacuous, as
expected: format, lint, typecheck, unit and coverage are UNCONFIGURED
(BOOTSTRAPPED=no), mutation ON REQUEST, integration build skipped by
`--fast`. The suites under their floors are what judges this story.

**Counts.** `doctor: 69 passed, 2 failed` (71 executed); `lib: 327 passed,
5 failed` (332 executed). Both are below their new floors, as they must be
in RED: `FAIL doctor  did 69 units of work, below the floor of 71`, `FAIL lib
did 327 units of work, below the floor of 332`. Before this story: doctor 69
executed, 69 passed; lib 324 executed, 324 passed.

**The failure, verbatim from the log** (the real VERSION's 30-odd comment
lines are elided where marked `[...]`; the log has them in full):

```
    FAIL and it is the one in the file
         expected:   ok       harness ver  1 (2000-01-01)
         actual:     ok       harness ver  134 (2026-11-19)
    FAIL HARNESS-116 AC-4: and the real stamp appears nowhere in doctor's output
         expected NOT to contain: 134 (2026-11-19)
         actual:                   Harness prerequisites
           ok       git          /mingw64/bin/git
           ok       bash         /usr/bin/bash
           ok       bash ver     5.3.15
           ok       harness ver  134 (2026-11-19)
           ok       worktree     main checkout, harness 134 (2026-11-19)
         [...]
doctor: 69 passed, 2 failed
FAIL doctor  did 69 units of work, below the floor of 71 in .claude/tests/floors.conf

  HARNESS-116 AC-1: make_fixture writes a harness stamp of its own
    FAIL HARNESS-116 AC-1: make_fixture's VERSION is exactly '1 (2000-01-01)' and one newline
         expected: 1 (2000-01-01)
         x
         actual:   # The upstream harness version this tree was taken from. One line, first
         # non-comment: a release NUMBER, monotonically increasing, with the real
         # calendar date of that release beside it in brackets.
         [...]
         #   * no file at all - from before stamping entirely.
         134 (2026-11-19)
         x

  HARNESS-116 AC-2: make_project_fixture commits the same stamp
    FAIL HARNESS-116 AC-2: make_project_fixture's VERSION is exactly '1 (2000-01-01)' and one newline
         expected: 1 (2000-01-01)
         x
         actual:   # The upstream harness version this tree was taken from. One line, first
         [...]
         134 (2026-11-19)
         x
    FAIL HARNESS-116 AC-2: git show HEAD:.claude/harness/VERSION prints the fixture stamp
         expected: 1 (2000-01-01)
         x
         actual:   # The upstream harness version this tree was taken from. One line, first
         [...]
         134 (2026-11-19)
         x

  HARNESS-116 AC-3: the stamp does not follow the tree it was built from
    FAIL HARNESS-116 AC-3: under a stand-in root saying 999, the fixture's VERSION is exactly '1 (2000-01-01)'
         expected: 1 (2000-01-01)
         x
         actual:   999 (2099-12-31)
         x
    FAIL HARNESS-116 AC-3: and 999 appears nowhere in the fixture's VERSION
         expected NOT to contain: 999
         actual:                   999 (2099-12-31)
         x

lib: 327 passed, 5 failed
FAIL lib  did 327 units of work, below the floor of 332 in .claude/tests/floors.conf
```

Why it is the right failure: each red assertion is the stamp comparison
itself, and each actual value is the real file's bytes (or the stand-in's
`999 (2099-12-31)`): the helper copies `$REPO_ROOT/.claude/harness/VERSION`.
AC-3's actual value also shows the stand-in root reached the helper. No
syntax error, no missing file, no other assertion in either suite went red.

**Per test** (assertion name: what it asserts, AC):

- lib `HARNESS-116 AC-1: make_fixture's VERSION is exactly ...`: the whole
  file is `1 (2000-01-01)` + one newline. AC-1.
- lib `HARNESS-116 AC-1: the real stamp is not empty and is not the fixture
  stamp`: precondition on the real file, so the comparison above can tell a
  write from a copy. AC-1.
- lib `HARNESS-116 AC-2: make_project_fixture's VERSION is exactly ...`: the
  same, through `make_project_fixture`. AC-2.
- lib `HARNESS-116 AC-2: git show HEAD:.claude/harness/VERSION prints the
  fixture stamp`: the committed blob, whole. AC-2.
- lib `HARNESS-116 AC-2: and the project fixture's git status --porcelain
  names no path`: committed, nothing left dirty. AC-2.
- lib `HARNESS-116 AC-3: the fixture was built from the stand-in root (its
  paths.conf)`: the stand-in's marker line is in the fixture's `paths.conf`.
  AC-3 (reach control).
- lib `HARNESS-116 AC-3: under a stand-in root saying 999, ...`: whole file.
  AC-3.
- lib `HARNESS-116 AC-3: and 999 appears nowhere in the fixture's VERSION`.
  AC-3.
- doctor `HARNESS-116 AC-4: the real stamp is not empty`: `_bad` when the
  first non-blank, non-comment line of the real VERSION is empty. AC-4.
- doctor `and it is the one in the file` (respelled `:102`): `assert_eq` of
  the `harness ver` row (`grep 'harness ver'` over doctor's output) against
  `  ok       harness ver  1 (2000-01-01)`. AC-4.
- doctor `HARNESS-116 AC-4: and the real stamp appears nowhere in doctor's
  output`: `assert_not_contains` the real stamp (an empty real stamp is
  replaced by a sentinel needle, so it cannot match vacuously; the `_bad`
  above has already failed the run). AC-4. This also covers the `worktree`
  row, which prints `main checkout, harness <stamp>`.
- doctor `the shipped version starts with a release number`, `and carries the
  real release date`: unchanged. AC-5.

**Files touched.** `.claude/tests/lib.test.sh` (new block at the end),
`.claude/tests/doctor.test.sh` (`:102` respelled with two assertions added;
the restore after the legacy-date block writes the fixture stamp),
`.claude/tests/floors.conf` (lib 324 -> 332, doctor 69 -> 71, history note),
`.claude/tests/selftest.test.sh` (COUNTS `doctor 71`, `lib 332`; the named
`lib is floored at its 332 executed assertions` assertion, name and value),
this story (`## Test plan`, this section).

**Export shape pinned.** None new. The tests call `make_fixture` and
`make_project_fixture` from `.claude/tests/_lib.sh` with no arguments and
read the path each prints on stdout, as every suite does today. AC-3 also
pins that `make_fixture` reads `REPO_ROOT` at call time (for the copy of
`paths.conf`). Fixed by the tests: the fixture's
`.claude/harness/VERSION` is exactly the 15 bytes `1 (2000-01-01)\n`, in
both helpers, and committed in `make_project_fixture`'s fixture with a clean
status afterwards. Not constrained: how the helper writes it (`printf`,
heredoc), the comment wording above it, and whether `models.conf` is
copied.

**Passed on arrival (green in RED), and what earns each.**

| Assertion | Why green today | What earns it |
|---|---|---|
| lib AC-1 real stamp precondition | real file says `134 (2026-11-19)` | a control on the input, not on the helper. Fires if the real VERSION is unstamped or holds `1 (2000-01-01)` (that is PLANNED run B's shape, applied to this assertion: `$d` makes the first line empty) |
| lib AC-2 `git status --porcelain` empty | the helper commits its copy today | a guard that the fix stays committed: a GREEN that wrote VERSION after the `git add -A` would turn it red. Not probed in RED (no source mutation owed in RED) |
| lib AC-3 stand-in marker | the helper copies `paths.conf` from `$REPO_ROOT` today | the red AC-3 stamp assertions are themselves the proof the stand-in reached the helper in RED (actual `999 (2099-12-31)`); the marker carries that proof past GREEN |
| doctor AC-4 real stamp not empty | real file stamped | same as lib's precondition; fires under PLANNED run B's `$d` mutation |

**Negative controls, expected values.** All mechanical; no thresholds.

| Control | Expected now (RED, measured) | Expected after GREEN |
|---|---|---|
| lib AC-3 actual VERSION under the stand-in | `999 (2099-12-31)\n` (measured, log above) | `1 (2000-01-01)\n` |
| lib/doctor real-stamp preconditions | `134 (2026-11-19)`, non-empty, not the fixture stamp (measured: pass) | the release GREEN writes, `135 (...)`: still pass |
| doctor `harness ver` row | `  ok       harness ver  134 (2026-11-19)` (measured) | `  ok       harness ver  1 (2000-01-01)` |

Unlike an import-failing suite, every assertion in both files executed in
this run, so the values in the "now" column are measured, not claimed.

**DV-1 / DV-2: declined in RED.** I cannot run either: both need the helper
as GREEN builds it (DV-1 puts the old copy back into the new helper; DV-2
needs a tree where no fixture holds the real stamp). Both are GATES's, per
the story. Predicted outcome of DV-1 (replace the stamp write with the old
`cp "$REPO_ROOT/.claude/harness/VERSION" "$d/.claude/harness/VERSION"`,
`bash scripts/selftest.sh lib`), against this RED run:

| Assertion | DV-1 prediction |
|---|---|
| AC-1 whole file (make_fixture) | red, actual = real VERSION with comments |
| AC-1 real stamp precondition | green |
| AC-2 whole file (make_project_fixture) | red |
| AC-2 `git show HEAD:` | red |
| AC-2 porcelain empty | green |
| AC-3 stand-in marker | green |
| AC-3 whole file | red, actual `999 (2099-12-31)` |
| AC-3 no `999` | red |
| total | `lib: 327 passed, 5 failed`, every failure in the HARNESS-116 block |

A DV-1 mutant that changes only the comment must be refused as the story
says; a mutant that writes `1 (2000-01-01)` without a newline would also go
red on the three whole-file assertions (not run; prediction).

**For the implementer.**

- The C-1 write must land before `git add -A` in `make_fixture`, so that
  `make_project_fixture`'s commit holds it and the porcelain stays empty.
- `doctor.test.sh` does not touch `make_fixture`; its two red assertions go
  green purely through the helper. `worktree.test.sh` was not edited; PLANNED
  run C measured it green with the prototype.
- The `lib` and `doctor` floors (332, 71) equal the executed counts, so GREEN
  must reach `lib: 332 passed, 0 failed` and `doctor: 71 passed, 0 failed`.

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

- **R-1 (selftest-needed pins, HARNESS-115 AC-1/AC-2/AC-5).**

- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2), 2026-11-19, upheld: in a scratch clone of ed6a1b2, a VERSION-only change prints `doctor lib worktree` with `lib .claude/harness/VERSION (mentioned)`, and with origin/main's lib.test.sh in the base prints `doctor worktree`; a floors.conf-only change prints `selftest` either way; a `# fixture-only:` declaration added to lib is overridden (`mentioned under $REPO_ROOT, despite fixture-only`) because line 1176 reads the real stamp. lib's selection is this story's own real read and a correct R3 mention; the three HARNESS-115 pins (AC-1, AC-2, AC-5 doctor copy) lack `lib` and are wrong; the floors.conf-only pin is unaffected.

  * **Which tests, and what was wrong.** Three `h115_expect` blocks in
    `.claude/tests/selftest-needed.test.sh` pin the exact `--suites` output
    over a copy of the real `.claude/tests/*.test.sh`: AC-1 (four paths
    changed: "six suites", header `6 of 35`), AC-2 (VERSION and floors.conf:
    `doctor selftest worktree`, `3 of 35`) and AC-5's doctor copy (VERSION
    only: `doctor worktree`, `2 of 35`). This story's `lib.test.sh:1176` reads
    `"$REPO_ROOT/.claude/harness/VERSION"`, so `lib` now mentions VERSION and
    is correctly selected for it. The pins predate that read.
  * **How it was found.** The changed-suite self-test before REVIEW
    (`.claude/state/attest-logs/20261120T002159Z.492541.log`):
    `selftest-needed: 952 passed, 18 failed`.
  * **What they assert now.** `lib` in each stdout list in sorted position,
    headers `7 of 35`, `4 of 35`, `3 of 35`, and a `lib|$H115_V|mentioned`
    reason spec in each block. Wording corrected: AC-1's describe ("select 7
    real suites") and label ("the seven suites"), AC-2's label ("doctor, lib,
    selftest and worktree"). The floors.conf-only pin (AC-5, selftest copy) is
    unchanged. Executed count 970 -> 976 (one new reason assertion per block,
    from root and from src/); `floors.conf` and `selftest.test.sh`'s COUNTS
    set to 976.
  * **What earns it: a probe.** Every `harness/VERSION` mention in
    `lib.test.sh` spelled away (line 1176 alone is not enough: the fixture-path
    mentions also match R3). Exactly the 24 corrected assertions go red, 8 per
    block, and nothing else in the suite does; the restore is verified:

```
=== mutate: .claude/tests/lib.test.sh (8 line(s) changed by s#harness/VERSION#harness/VERSIOX#g) ===
  1170 - x" "$(h116_file "$h116_fix/.claude/harness/VERSION")"
  1170 + x" "$(h116_file "$h116_fix/.claude/harness/VERSIOX")"
  1176 - h116_real="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$REPO_ROOT/.claude/harness/VERSION" | head -1)"
  1176 + h116_real="$(grep -vE '^[[:space:]]*#|^[[:space:]]*$' "$REPO_ROOT/.claude/harness/VERSIOX" | head -1)"
  1187 - x" "$(h116_file "$h116_pfix/.claude/harness/VERSION")"
  1188 - assert_eq "HARNESS-116 AC-2: git show HEAD:.claude/harness/VERSION prints the fixture stamp" \
  1187 + x" "$(h116_file "$h116_pfix/.claude/harness/VERSIOX")"
  1188 + assert_eq "HARNESS-116 AC-2: git show HEAD:.claude/harness/VERSIOX prints the fixture stamp" \
  1190 - x" "$(git -C "$h116_pfix" show HEAD:.claude/harness/VERSION 2>&1; printf x)"
  1190 + x" "$(git -C "$h116_pfix" show HEAD:.claude/harness/VERSIOX 2>&1; printf x)"
  1208 - printf '999 (2099-12-31)\n' > "$h116_stand/.claude/harness/VERSION"
  1208 + printf '999 (2099-12-31)\n' > "$h116_stand/.claude/harness/VERSIOX"
  1215 - x" "$(h116_file "$h116_sfix/.claude/harness/VERSION")"
  1215 + x" "$(h116_file "$h116_sfix/.claude/harness/VERSIOX")"
  1217 -   "999" "$(h116_file "$h116_sfix/.claude/harness/VERSION")"
  1217 +   "999" "$(h116_file "$h116_sfix/.claude/harness/VERSIOX")"

=== mutate: running bash scripts/selftest.sh selftest-needed ===
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from root]: stdout is exactly the pinned list
         expected: doctor
         grep-count
         lib
         selftest
         shipped-docs
         sigpipe
         worktree
         actual:   doctor
         grep-count
         selftest
         shipped-docs
         sigpipe
         worktree
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from root]: stdout has exactly 7 line(s)
         expected: 7
         actual:   6
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from root]: stderr's first line is exactly the pinned header
         expected: selftest-needed: suites — 7 of 35 selected from 4 harness path(s) changed against main (merge-base f711f2c)
         actual:   selftest-needed: suites — 6 of 35 selected from 4 harness path(s) changed against main (merge-base f711f2c)
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from root]: stderr's reason line for lib is exactly `.claude/harness/VERSION (mentioned)`, once
         expected: 1
         actual:   0
    [the remaining 20 FAIL lines of the run follow; their expected/actual detail is elided here]
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from subdir]: stdout is exactly the pinned list
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from subdir]: stdout has exactly 7 line(s)
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from subdir]: stderr's first line is exactly the pinned header
    FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the seven suites that read or scan them [from subdir]: stderr's reason line for lib is exactly `.claude/harness/VERSION (mentioned)`, once
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from root]: stdout is exactly the pinned list
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from root]: stdout has exactly 4 line(s)
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from root]: stderr's first line is exactly the pinned header
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from root]: stderr's reason line for lib is exactly `.claude/harness/VERSION (mentioned)`, once
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from subdir]: stdout is exactly the pinned list
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from subdir]: stdout has exactly 4 line(s)
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from subdir]: stderr's first line is exactly the pinned header
    FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, lib, selftest and worktree [from subdir]: stderr's reason line for lib is exactly `.claude/harness/VERSION (mentioned)`, once
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from root]: stdout is exactly the pinned list
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from root]: stdout has exactly 3 line(s)
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from root]: stderr's first line is exactly the pinned header
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from root]: stderr's reason line for lib is exactly `.claude/harness/VERSION (mentioned)`, once
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from subdir]: stdout is exactly the pinned list
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from subdir]: stdout has exactly 3 line(s)
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from subdir]: stderr's first line is exactly the pinned header
    FAIL AC-5: a copy of the real doctor.test.sh declaring VERSION is still printed when VERSION changes [from subdir]: stderr's reason line for lib is exactly `.claude/harness/VERSION (mentioned)`, once
selftest-needed: 952 passed, 24 failed
FAIL selftest-needed  did 952 units of work, below the floor of 976 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-116/.claude/state/mutations/.claude_tests_lib.test.sh.20261120T011319Z.726971.bak) ===
```

    (The block lists every FAIL line of the run; expected/actual detail is
    shown for the first four, from the run's log.)
  * **GREEN is a no-op.** No source changes; the R-1 diff is three test-path
    files (`selftest-needed.test.sh`, `floors.conf`, `selftest.test.sh`) and
    this story file. The post-correction run, below, is all green.

    $ bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed selftest lib
    lib: 332 passed, 0 failed
    selftest-needed: 976 passed, 0 failed
    selftest: 366 passed, 0 failed
    assertion floors: all 3 suite(s) met their declared floor (1674 assertions executed, 1674 declared).
    last:     3 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261120T011831Z.738862.log

    $ bash scripts/attest.sh -- bash scripts/gates.sh --fast
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261120T012538Z.758540.log

## Diff review

Round 1, 2026-11-19. `lead-po` on the DIFF-REVIEW row, planned `fable`,
resolved Fable 5.2 (`claude-fable-5-2`); no override. Reviewed HEAD 44b096d
against `origin/main`. No file changed.

- **Diff against criteria and Contract:** C-1 to C-4 built as written;
  `make_project_fixture` untouched and commits the stamp; the two shape
  assertions on the real file (`doctor.test.sh:355-366`) unchanged (AC-5).
- **Every reader of a fixture's stamp** (`VERSION` across `.claude/tests/*.sh`,
  `VERSION|release_of` across `scripts/` and `.claude/hooks/`): `worktree`
  reads the number from the fixture itself with anchored patterns;
  `doctor.sh` compares stamps for equality only; `boundaries` writes its own
  baseline; `refresh` and `security-audit` build their own upstreams;
  `sigpipe.test.sh:240` is quoted test data. No suite compares a fixture's
  stamp with the real one or expects the real header in a fixture.
- **The new `trap ... EXIT` in `lib.test.sh:1166`** keeps `"$FIX"` from the
  only earlier trap (line 10); no cleanup dropped.
- **Needles:** whole-file comparisons against a literal; AC-3 first shows the
  stand-in root reached the helper; both suites guard an empty real stamp.
- **Suites on HEAD 44b096d:** `lib` 332 passed, 0 failed; `doctor` 71 passed,
  0 failed.
- Not checked by the reviewer: release 135 free against `origin/main`
  (checked by the orchestrator after the review: `origin/main` has no new
  commits); the full self-test.

Verdict: Ship.

Round 2, 2026-11-19, after R-1. `lead-po` on the DIFF-REVIEW row, planned
`fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override. Reviewed
HEAD 84d8e6f: the R-1 diff (`ed6a1b2..HEAD -- .claude/`) and the whole
story diff against `origin/main`. No file changed. No findings.

- `h115_real` (`selftest-needed.test.sh:1180`) is the only place that pins a
  selection over the real suites; its three VERSION uses now carry `lib`, and
  the fourth (floors.conf only, `selftest` alone) is right, since
  `lib.test.sh` names none of floors.conf, selftest.test.sh or
  shipped-docs.test.sh. Every other `hdr` pin runs over stub suites.
- No pin selects over the real suites for `_lib.sh`, `lib.test.sh` or
  `doctor.test.sh`; `host-load`, `run-lock`, `run-queue` and `selftest` copy
  `_lib.sh` only and build stub suites.
- `lib` carries no `# fixture-only:` line, correctly: line 1176 reads the
  real stamp.
- Arithmetic: +2 per pin, +6, 970 to 976; floors.conf and COUNTS agree.
- Evidence: `attest.sh check` on `selftest.sh selftest-needed selftest lib`
  is fresh, exit 0, on tree f317580.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-20T01:27:09Z
    commit: 84d8e6f
    tree:   95eb9c9ded188178d1534f6193f63b208776e10c
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


- **PLANNED, 2026-11-19.** Planned by a `lead-po` dispatch, planned
  `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override was
  reported to it. Planned in the worktree `D:\adh-HARNESS-116` on the
  temporary branch `story/HARNESS-116-plan`, cut from `origin/main` at
  release 134 (`0e52de3`); the story's own `branch:` is the one in the
  frontmatter and is not created yet. Id checked free by the orchestrator
  on `origin/main`, the remote branches and PR titles the same day.
- **The measurement is negative.** No unselected suite fails when the real
  `VERSION` changes, plausibly or not (Context, runs A and B). The risk the
  request named, a local `--changed` run passing a bump that CI then
  fails, was not found on the tree as it is.
- **Type: `fix`.** The thing fixed is a read the selection cannot see: 22
  unselected suites carry the real file's bytes, against the premise
  HARNESS-115 states ("selecting too few is the dangerous direction").
  AC-1 reproduces it and fails today. No suite fails because of it today;
  if the user reads "bug" as "an observed failure", this is a `chore` with
  the same criteria and the same RED to GREEN path, and nothing else in
  the story changes.
- **D-1, what to do with a negative result. A PO decision for the user
  before the story leaves PLANNED; the story is written for option 1.**
  1. *The helper writes its own stamp (recommended; this story).* One
     line of `_lib.sh`, one respelled assertion in `doctor.test.sh`, three
     criteria in `lib.test.sh`. It removes the read, so the selection is
     right about `VERSION` by construction and stays right for suites not
     written yet; `worktree` stops depending on the real file (run D goes
     green); and `doctor.test.sh:102` stops passing on an empty needle
     (run B). Prototyped: run C broke exactly one assertion in the four
     suites it ran. Cost: one story cycle whose own local self-test is the
     full run, because `_lib.sh` is read by every suite.
  2. *Teach `selftest-needed.sh` that a path `_lib.sh` reads reaches every
     suite that calls the helper.* Rejected for `VERSION`: every harness
     story changes it, so 24 of 35 suites would be selected every time and
     HARNESS-115's saving would be gone, to run suites the measurement
     says do not fail. It may be the right shape for the conf files (Q-2).
  3. *Change nothing; keep the measurement as the record and close the
     story.* Defensible: nothing fails today, CI runs every suite on every
     PR, and the worst case of the open door is one CI round trip on some
     later story. Not recommended, because the cost of option 1 is small
     and paid once, while option 3 leaves the selection's soundness for
     `VERSION` resting on nobody ever writing a suite that asserts on a
     fixture's stamp, with nothing that would say so when one does.
  4. *A guard test and no helper change:* an assertion that no suite but
     `doctor` and `worktree` runs `doctor.sh` or `refresh-harness.sh`.
     Rejected: it pins a proxy by a text needle, costs the same cycle as
     option 1, and leaves the read in place.
- **Q-1, for the user.** Declare `worktree` `# fixture-only:` for `VERSION`
  in a follow-up story? It takes one suite (73 assertions) out of every
  later harness story's `--changed` run and edits two pinned lists in
  `selftest-needed.test.sh`.
- **Q-2, for the user. A finding outside this story.** The same helper
  copies the real `paths.conf`, `phases.conf` and `models.conf` into all 24
  suites' fixtures, and there the content matters. By mention,
  `phases.conf` selects only `plan` and `refresh`; `paths.conf` selects
  `attest`, `classify`, `phase-guard`, `refresh`, `selftest-needed`,
  `sigpipe` and `spawns`; `models.conf` selects `boundaries`, `dispatch`,
  `plan` and `rules-trim`. So a story that changes `phases.conf` would
  not select `phase-guard` or `phase` locally. Read from `grep -l` of each
  path over the suites; no mutation was run and `--suites` was not run on
  such a diff. Those files change rarely and CI runs everything. Should
  it get a story of its own, probably option 2's shape for those three
  paths?
- **User answers, 2026-11-19 (asked by the orchestrator before RED).**
  D-1: "Fix the helper (Recommended)", option 1, the story as written.
  Q-1: "No, leave it"; `worktree` stays selected by `VERSION`, no
  follow-up. Q-2: "Yes, later story (Recommended)"; the conf copies get a
  story of their own after this one. Type stays `fix`.
- **HARNESS-115's note about `story` is corrected in the Context:** it
  does not run `doctor.sh`.
- **Not already delivered.** Reproduced at PLANNED on `0e52de3`: `_lib.sh`
  line 124 copies the real file; run D is red.
- **Not split.** One behaviour (the helper's stamp), one helper line, two
  suites; the `doctor.test.sh` change cannot ship separately, because the
  helper change breaks `:102` (run C).
- **Collisions, read by hand.** `floors.conf`, `selftest.test.sh` and
  `VERSION` are written by every harness story; any story in flight shares
  them and is a collision, not a dependency. Whichever merges second
  merges `main`, takes the next release number and has its gates run again.
- **GREEN, 2026-11-19.** Feature Developer dispatched on `opus`; resolved
  `claude-opus-5-5` (Opus 5.5), no override. `_lib.sh` `make_fixture`: the
  `cp` of the real `VERSION` and its two comment lines replaced by
  `printf '1 (2000-01-01)\n' > "$d/.claude/harness/VERSION"`, before the
  `git add -A`; the function's header comment now says the stamp is the
  fixture's own. `make_project_fixture` not edited. `VERSION`: stamp line
  `134 (2026-11-19)` replaced by `135 (2026-11-19)`. `bash scripts/attest.sh
  -- bash scripts/selftest.sh lib doctor`: exit 0, `doctor: 71 passed, 0
  failed`, `lib: 332 passed, 0 failed`, floors met (403/403), log
  `.claude/state/attest-logs/20261120T001404Z.474911.log`. `gates.sh --fast`:
  exit 0, vacuous as in RED (0 ran, 5 unconfigured), log
  `.claude/state/attest-logs/20261120T001512Z.479558.log`. Controls measured
  against the shipped helper, all as the handoff predicted: fixture VERSION
  is the 15 bytes `1 (2000-01-01)\n`; the AC-3 stand-in root (999) gives
  `1 (2000-01-01)\n`; project fixture `git show HEAD:` gives the fixture
  stamp with empty porcelain; doctor in a project fixture prints
  `  ok       harness ver  1 (2000-01-01)` and `worktree ... harness 1
  (2000-01-01)`; the real-stamp preconditions pass on `135 (2026-11-19)`.
  No divergence.
- **Self-test at GATES → REVIEW, 2026-11-19: failed, 1 of 35.**
  `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` (all suites, because
  `_lib.sh` changed), log `.claude/state/attest-logs/20261120T002159Z.492541.log`:
  `selftest-needed: 952 passed, 18 failed`. Each failure is an extra `lib`
  in HARNESS-115's pinned selections for a `VERSION` change, because this
  story's `lib.test.sh:1176` reads the real `VERSION`. Put to the user, who
  chose "Add lib to the lists (Recommended)" over "Drop the real read from
  lib". Adjudicated upheld (R-1); return to RED; `touches:` gains
  `.claude/tests/selftest-needed.test.sh`.
- **GREEN on re-entry after R-1, 2026-11-19: a no-op, verified by the
  orchestrator.** No source changes. `attest.sh check` on
  `bash scripts/selftest.sh selftest-needed selftest lib` and on
  `bash scripts/gates.sh --fast`: both `fresh`, exit 0 (lib 332/0,
  selftest-needed 976/0, selftest 366/0).
- RED re-entry (R-1): `test-developer`, planned `opus`, resolved Opus 5.5
  (`claude-opus-5-5`); no override. ADJUDICATE R-1: `lead-po`, planned
  `fable`, resolved Fable 5.2 (`claude-fable-5-2`). Self-test round 1:
  `feature-developer`, resolved Opus 5.5.
- GATES round 2 (full gates): `feature-developer`, resolved Opus 5.5
  (`claude-opus-5-5`). DIFF-REVIEW round 2: `lead-po`, resolved Fable 5.2
  (`claude-fable-5-2`).
- **Self-test at GATES → REVIEW, round 2, 2026-11-19: passed.**
  `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` (every suite, because
  `_lib.sh` changed), tree f317580, exit 0, `35 harness suite(s) passed.`,
  1126 s, 6987 assertions executed against 6983 declared, log
  `.claude/state/attest-logs/20261120T013116Z.771308.log`. `feature-developer`,
  resolved Opus 5.5 (`claude-opus-5-5`). A first dispatch of this round was
  refused by the worktree's run lock (exit 2) while the round-2 reviewer's
  `selftest.sh selftest-needed` held it, and was re-dispatched once that ended.
