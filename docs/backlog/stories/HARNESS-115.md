---
id: HARNESS-115
title: A fixture-only mention selects no suite
slug: a-fixture-only-mention-selects-no-suite
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-115-a-fixture-only-mention-selects-no-suite
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/boundaries.test.sh, .claude/tests/host-load.test.sh, .claude/tests/refresh.test.sh, .claude/tests/run-lock.test.sh, .claude/tests/run-queue.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION, CLAUDE.md, .claude/commands/advance-story.md]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the selftest-needed suite under its selftest floor, which CI runs in full on the PR
---

## Context

`bash scripts/selftest-needed.sh --suites` picks the suites
`selftest.sh --changed` runs before a PR. Its rule R3 selects a suite
whenever the suite's source holds a changed path, test data included
(HARNESS-094's declared limit; HARNESS-096 made the mention map the path).
Every harness story changes `.claude/harness/VERSION`,
`.claude/tests/floors.conf` and `.claude/tests/selftest.test.sh` (25 of the
last 25 merges on `origin/main`), so every small harness story selects the
suites that name those two files, including the ones that only write a
fixture copy of their own. Measured on HARNESS-114's path set (below): 11
of 35, about 3 hours locally under host load.

This story adds a per-suite declaration, `# fixture-only: <path>`, that R3
honours: the suite is not selected for that path. Selecting by mention stays
the default for every suite and path with no declaration. Selecting too few
is the dangerous direction (CI runs every suite, but the local run is what
is relied on before a PR), so a declaration is ignored whenever the suite's
own source also names the path under `$REPO_ROOT/`, and a path left with no
selecting suite answers `all`.

**Reproduced at PLANNED, 2026-11-19, release 132 (`9fa2dfb`), this
worktree,** with one line appended to each of HARNESS-114's four paths
(`.claude/harness/VERSION`, `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh`, `.claude/tests/shipped-docs.test.sh`) and
the files restored afterwards:

    selftest-needed: suites — 11 of 35 selected from 4 harness path(s) changed against origin/main (merge-base 9fa2dfb)
      boundaries    .claude/harness/VERSION (mentioned)
      doctor        .claude/harness/VERSION (mentioned)
      grep-count    .claude/tests/selftest.test.sh (scans *.sh)
      host-load     .claude/tests/floors.conf (mentioned)
      refresh       .claude/harness/VERSION (mentioned)
      run-lock      .claude/tests/floors.conf (mentioned)
      run-queue     .claude/tests/floors.conf (mentioned)
      selftest      .claude/tests/floors.conf (mentioned)
      shipped-docs  .claude/tests/selftest.test.sh (scans .claude/tests/*.sh)
      sigpipe       .claude/tests/selftest.test.sh (scans *.sh)
      worktree      .claude/harness/VERSION (mentioned)

With only `VERSION` and `floors.conf` changed: 8 of 35 (the same list less
grep-count, shipped-docs and sigpipe).

**The measurement: which suite reads the real file.** All 35 suites, both
paths. "Names" is a literal occurrence of the whole path in the suite's
source, which is what R3 sees; the prefix is the text directly before it.
The other 26 suites for `VERSION` and the other 30 for `floors.conf` name
the path nowhere, so R3 never selects them for it, before or after this
story.

| Suite | Path | How it names the path | Reads the real file? | Evidence |
|---|---|---|---|---|
| doctor | VERSION | `$REPO_ROOT/` x2, `$FIX/` x6 | **yes** | `doctor.test.sh:102` and `:340` read `"$REPO_ROOT/.claude/harness/VERSION"`. Mutation M-1: red |
| worktree | VERSION | `$1/`, `$UP/`, `$WA/`, 2 in comments | **yes**, through `_lib.sh` | `FIX="$(make_project_fixture)"` (`:68`); `make_fixture` copies the real file in (`_lib.sh:124`); `num` is read from that copy (`:343`) and compared with the fixture's own `44` and `99`. Mutation M-2: red |
| boundaries | VERSION | `$FIX/` x2 | no | `:1126` and `:1133` write the fixture's own; `check-boundaries.sh:271` only compares the base's bytes with the tree's. Mutation M-9 |
| refresh | VERSION | `$UP/` x2, `$UP2/` | no | `:36`, `:834`, `:917` write its own upstream; no `make_fixture` in the suite. Mutation M-7 |
| selftest | floors.conf | `$REPO_ROOT/` x1, fixture and bare spellings x28 | **yes** | `:420` `REAL="$REPO_ROOT/.claude/tests/floors.conf"`; `:457` `suites_without_floor "$REPO_ROOT"`. Mutation M-3: red |
| host-load | floors.conf | `$FIX/` x1 | no | `:265` writes the fixture's own. Mutation M-5 |
| run-lock | floors.conf | `$t/` x1 | no | `:108` writes the fixture's own. Mutation M-4 |
| run-queue | floors.conf | `$t/` x2 | no | `:145`, `:213` write the fixture's own. Mutation M-6 |
| refresh | floors.conf | `$UP/` x2, `$PROJ/` x3, 1 bare in an expected output line | no | `:1073`-`:1127`, its own upstream and project. Mutation M-8 |
| the other suites | either | not named | not by name | see "Two reads R3 cannot see" |

The mutations, each one `bash scripts/mutate.sh <real file> '<expr>' --
bash scripts/selftest.sh <suite>`, restore verified by `mutate.sh`:

| | Real file, mutation | Suite | Result |
|---|---|---|---|
| M-1 | `VERSION`: `132 (2026-11-18)` to `2026-09-19` | doctor | **red**, 67 passed, 2 failed: "the shipped version starts with a release number", "and carries the real release date" |
| M-2 | `VERSION`: to `44 (2026-09-01)` | worktree | **red**, 70 passed, 3 failed, all in AC-4 ("a linked worktree behind the main checkout is MISSING, naming both releases" and the two after it) |
| M-3 | `floors.conf`: the `lib` floor line deleted | selftest | **red**, 363 passed, 3 failed: "every suite in .claude/tests has a floor" (actual `lib`) and two in HARNESS-021 AC-3 |
| M-4 | `floors.conf`: as M-3 | run-lock | green, 141 passed, 0 failed |
| M-5 | `floors.conf`: as M-3 | host-load | green, 72 passed, 0 failed |
| M-6 | `floors.conf`: as M-3 | run-queue | green, 361 passed, 0 failed |
| M-7 | `VERSION`: as M-2 | refresh | green, 215 passed, 0 failed |
| M-8 | `floors.conf`: as M-3 | refresh | green, 215 passed, 0 failed |
| M-9 | `VERSION`: as M-2 | boundaries | green, 687 passed, 0 failed |

A green run under a mutation shows only that this mutation did not reach
the suite; the "no" rows rest on the lines cited, with the mutation as a
second reading. M-4 to M-9 use the same mutation that turns a real reader
red, so they are a like-for-like control. Single-suite wall times, with
four other gate runs on the host: 80 s, 114 s, 114 s, 23 s, 9 s, 137 s,
84 s, 83 s, 923 s. `mutate.sh --check` afterwards: nothing stranded.

**Two reads R3 cannot see, today or after this story** (neither is changed
here; both are the declared limit "a suite that exercises a changed script
only through another script, and never names it, is not selected"):

- `make_fixture` in `.claude/tests/_lib.sh:124` copies the real `VERSION`
  into the fixture of every suite that calls it or `make_project_fixture`:
  24 suites. Only `doctor` and `worktree` also name the path, so only they
  are selected for it; `story` runs `doctor.sh` in such a fixture once and
  is not selected today.
- `scripts/selftest.sh` itself reads the real `floors.conf` for every suite
  it runs, and `--changed` runs the full floors audit whatever it selected
  (`selftest.sh:387`). A malformed floors file is refused by the runner
  before any suite starts; no suite needs selecting for that.

**The required gate.** Every gate in `project.conf` is unconfigured here.
The artifact is judged by the `selftest-needed` suite under its floor in
`floors.conf`, which CI runs in full on the PR and the local `--changed` run
selects by R1 (the suite itself changes).

## Acceptance criteria

"The real suites" below means this repository's `.claude/tests/*.test.sh`
as the story's tree holds them, declarations of Contract C-4 included, read
from `$REPO_ROOT` into a fixture checkout whose base holds them unchanged.
`m` is the number of those suites (35 at PLANNED). Every list is the whole
of stdout, sorted, one name per line.

- **AC-1 (the over-selection, reproduced and removed)** — Given the real
  suites, when exactly `.claude/harness/VERSION`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` and
  `.claude/tests/shipped-docs.test.sh` are changed (HARNESS-114's path set)
  and `bash scripts/selftest-needed.sh --suites` is run, then it exits 0 and
  prints exactly `doctor`, `grep-count`, `selftest`, `shipped-docs`,
  `sigpipe`, `worktree`, under the header `... 6 of <m> selected from 4
  harness path(s) changed ...`. On `main` today the same input prints 11:
  those six and `boundaries`, `host-load`, `refresh`, `run-lock`,
  `run-queue`.
- **AC-2 (the control: a suite that reads the real file stays selected)** —
  Given the real suites, when exactly `.claude/harness/VERSION` and
  `.claude/tests/floors.conf` are changed, then `--suites` prints exactly
  `doctor`, `selftest`, `worktree` (8 today), and stderr holds the reason
  lines `doctor  .claude/harness/VERSION (mentioned)`, `worktree
  .claude/harness/VERSION (mentioned)` and `selftest
  .claude/tests/floors.conf (mentioned)`, once each.
- **AC-3 (the declaration)** — Given two fixture suites whose sources both
  hold a changed path, one of which also holds, at column 0, the line
  `# fixture-only: <that path>`, when `--suites` is run, then the suite
  without the line is printed and the suite with it is not. *Control:* the
  same fixture with that one line removed prints both.
- **AC-4 (mention stays the default)** — A declaration covers only the
  suite that holds it and only the paths it names, compared as whole
  strings. Given the declaring suite of AC-3: (a) when a second path its
  source holds and its line does not name is changed, it is printed for
  that path with `(mentioned)`; (b) when its own `.test.sh` is among the
  changed paths, it is printed with `(itself)`; (c) when the line is not
  the pinned grammar (indented, `#fixture-only:`, no colon, or naming only a
  prefix of the path), it is printed with `(mentioned)`, as today.
- **AC-5 (a declaration the suite's own source contradicts is ignored)** —
  Given a suite that declares a path fixture-only and whose source also
  holds that path directly after `$REPO_ROOT/` or `${REPO_ROOT}/`, when
  that path is changed, then the suite is printed, with the reason
  `<path> (mentioned under $REPO_ROOT, despite fixture-only)`. This holds
  for the real spellings: a copy of the real `doctor.test.sh` given the
  line `# fixture-only: .claude/harness/VERSION` is still printed when
  `VERSION` changes, and a copy of the real `selftest.test.sh` given
  `# fixture-only: .claude/tests/floors.conf` is still printed when
  `floors.conf` changes.
- **AC-6 (never fewer when nothing is left to select)** — Given a changed
  path that every suite naming it declares fixture-only, and that no other
  rule maps, when `--suites` is run, then it prints the one line `all`,
  exit 0, and stderr is exactly `selftest-needed: suites — all: <path> is
  named only as fixture data by the suites that mention it; defaulting to
  every suite`.
- **AC-7 (what was left out is said)** — Given a run that prints a list and
  in which at least one suite went unselected because of a declaration,
  then stderr ends, after the last reason line, with exactly one line
  `  not selected (fixture-only): <names>`, the names sorted and separated
  by one space, holding only suites absent from stdout. Given a run in
  which no declaration left a suite out, or one that answers `all`, stderr
  holds no such line. For AC-1's input the names are `boundaries host-load
  refresh run-lock run-queue`.
- **AC-8 (the rule is written where it is read)** — The header of
  `scripts/selftest-needed.sh`, the `--suites` paragraph of `CLAUDE.md` and
  step 2 of `.claude/commands/advance-story.md` each state the declaration,
  in the texts Contract C-6 pins.

## Contract

**Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/host-load.test.sh`, `.claude/tests/refresh.test.sh`, `.claude/tests/run-lock.test.sh`, `.claude/tests/run-queue.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`, `CLAUDE.md`, `.claude/commands/advance-story.md`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

Every path above classifies as `harness`, so the lock permits each in every
phase; who writes what is by role. RED (Test Developer):
`selftest-needed.test.sh`, the declaration lines of C-4 in the five suites,
the `selftest-needed` floor in `floors.conf` and its entry in
`selftest.test.sh`'s COUNTS table. GREEN (Feature Developer):
`scripts/selftest-needed.sh`, `CLAUDE.md`, `advance-story.md`, `VERSION`
(the next free release number when the branch is cut; see Notes for
HARNESS-114).

**C-1. The declaration line.** In a suite file `.claude/tests/<name>.test.sh`,
a line that is, from column 0 and after one trailing carriage return is
dropped, exactly `# fixture-only:` followed by one or more repo-relative
paths, each preceded by one or more spaces, and nothing else. A suite may
hold several such lines; the suite's declared set is every path on any of
them. A path is declared when it equals the changed path as a whole string:
no globs, no prefixes. Anything else (leading whitespace, `#fixture-only:`,
`# fixture-only` without the colon) is an ordinary comment and declares
nothing. The line may sit anywhere in the file; put it in the header
comment, with one comment line under it saying what the suite does with the
path. (CR is dropped because this machine's `autocrlf` checks suites out
CRLF.)

**C-2. R3, amended.** For a changed harness path `P` and a suite `S` whose
source holds `P` as a clean hit (HARNESS-096's boundary, unchanged):

1. `S` does not declare `P`: as today. `S` is selected, reason
   `P (mentioned)`, and `P` is mapped.
2. `S` declares `P`, and some line of `S` holds `P` as a clean hit directly
   after `$REPO_ROOT/` or `${REPO_ROOT}/` (comments count, as they do for a
   mention): the declaration is ignored. `S` is selected, reason
   `P (mentioned under $REPO_ROOT, despite fixture-only)`, and `P` is
   mapped.
3. `S` declares `P` and (2) does not hold: R3 contributes nothing for the
   pair. `S` is not selected by it and `P` is not mapped by it.

The declaration line itself is a mention of `P` in `S`; it falls under (3)
like any other and never under (1). R1, R2 and R4 do not read
declarations: a declaring suite that changed selects itself, an R2 path
answers `all`, a `SCANS` row applies. After every rule, a path that R1,
R3 cases 1-2 and R4's `map` rows all missed is R5's, as today, with one
difference in the reason: when at least one suite fell under (3) for it,
the `all` line names it as in C-3. When several paths would answer `all`,
the first in sort order gives the reason, as today.

The semantics behind the two safety choices. (2) exists because the
commonest way a declaration goes stale is somebody adding a direct read of
the real file, and that spelling is `"$REPO_ROOT/<path>"` in every suite
that does it today (`doctor.test.sh:102`, `:340`; `selftest.test.sh:420`).
(3) does not map because a path nobody is selected for must not quietly
select nothing: "a path the mapping cannot place selects more, never
fewer".

**C-3. Output.** stdout's format and the exit statuses do not change. On
stderr, with `—` the em dash already used:

- the new reason, in a suite's reason line:
  `<path> (mentioned under $REPO_ROOT, despite fixture-only)`
- the new `all` line, whole:
  `selftest-needed: suites — all: <path> is named only as fixture data by the suites that mention it; defaulting to every suite`
- the new last line of a list answer, present only when its name list is
  not empty: two spaces, then `not selected (fixture-only): `, then the
  names of the suites that fell under C-2 (3) for at least one changed path
  and are not in stdout, sorted, separated by single spaces. It is not
  counted in the header's `k of m` and is not printed on an `all` answer.

The header line, the `(mentioned)`, `(itself)` and `(scans ...)` reasons
and the existing `all` lines are byte for byte as they are.

**C-4. The declarations this story ships,** each on evidence in the
Context table. Seven pairs, five suites:

| Suite | Line |
|---|---|
| `boundaries.test.sh` | `# fixture-only: .claude/harness/VERSION` |
| `refresh.test.sh` | `# fixture-only: .claude/harness/VERSION .claude/tests/floors.conf` |
| `host-load.test.sh` | `# fixture-only: .claude/tests/floors.conf` |
| `run-lock.test.sh` | `# fixture-only: .claude/tests/floors.conf` |
| `run-queue.test.sh` | `# fixture-only: .claude/tests/floors.conf` |

`doctor`, `worktree` and `selftest` get none: they read the real file
(M-1, M-2, M-3). `selftest-needed.test.sh` itself: the new cases will name
both paths, and it must not read the real ones (C-5), so it carries
`# fixture-only: .claude/harness/VERSION .claude/tests/floors.conf` too;
AC-1's pinned list, which does not hold `selftest-needed`, is what forces
it. That is an eighth and ninth pair, in the suite the story already
writes.

**C-5. The real-tree cases (AC-1, AC-2, AC-5).** Built in a
`make_project_fixture` checkout: copy `"$REPO_ROOT"/.claude/tests/*.test.sh`
into the fixture's `.claude/tests/`, write the fixture's own
`.claude/tests/floors.conf` (any content; `--suites` never reads it),
commit on `main`, cut the story branch, change the named paths, run the
fixture's copy of the script. `VERSION` is already there:
`make_project_fixture` copies it. The suite must not spell either path
after `$REPO_ROOT/`: by C-2 (2) that would select `selftest-needed` and
break AC-1's own pin. `m` is counted from the real directory, not written
as 35. AC-5's real cases append the declaration line to the fixture's copy
of `doctor.test.sh` / `selftest.test.sh`, never to the real file. The
synthetic cases (AC-3, AC-4, AC-6, AC-7 and AC-5's first half) use stub
suites in a builder of their own, as `h096_fixture` does, so that the
`9` in the existing `hdr ... 9 ...` pins does not move.

A pin on the real tree's exact selection is deliberate: a suite that later
starts naming `VERSION` or `floors.conf` turns AC-1 red, and whoever added
it decides, in that story, whether it reads the real file.

**C-6. The three texts (AC-8).**

*`scripts/selftest-needed.sh`, header.* The four R3 lines and the R4 row
that HARNESS-096 AC-4 pins stay byte for byte. A new block goes directly
after the line `# absent, contributes nothing - and a path left with no
existing suite is R5's.` and before the `#` line that precedes
`# Known limit:`:

    #
    # R3, narrowed by declaration (HARNESS-115). A suite that names a path only
    # to write its own fixture copy says so on a line of its own, at column 0:
    #   # fixture-only: <path> [<path> ...]
    # R3 then does not select that suite for that path, and that mention does
    # not map it: a path named only by declaring suites is R5's. A declaration
    # is ignored, and the suite selected, when the suite's source also holds the
    # path directly after `$REPO_ROOT/` or `${REPO_ROOT}/`. Nothing else checks
    # that a declaration is true: a read through a helper or by a composed path
    # is the declaring suite's to know.

*`CLAUDE.md`, the `--suites` paragraph in `## Running things`.* Its three
lines stay byte for byte and three follow them in the same paragraph:

    `--suites` maps a changed path to every suite whose source names it, ending
    where the path ends, comments and test data included. A path a suite names
    only as test data counts as mentioned, never as unmapped (which gives `all`).
    A suite's `# fixture-only: <path>` line says it only writes its own copy of
    that path: the suite is then not selected for it, unless its source also
    names the path under `$REPO_ROOT/`.

It stays its own paragraph directly before the one beginning `gates.sh`
judges the **code**. Lines 160-162 of `CLAUDE.md` do not move (the new
lines are below them).

*`.claude/commands/advance-story.md`, step 2 of GATES → REVIEW.* The clause
"a suite that mentions a changed path," becomes "a suite that mentions a
changed path and does not declare it `fixture-only`,", reflowed as the file
is. The backticked word `fixture-only` appears in step 2 exactly once.

**C-7. Oracle partition.**

| Criterion | Kind | Instruction to RED |
|---|---|---|
| AC-1, AC-2 | settled | Read the lists out of this story; they were measured at PLANNED. Do not re-derive them from the script. `m` is counted from the directory |
| AC-3, AC-4, AC-5, AC-6, AC-7 | mechanical | Pin stdout whole and the stderr lines of C-3 byte for byte, with `assert_eq`, from the root and from `src/` as `expect_suites` does |
| AC-8 | mechanical | Whole lines, counted with `==`, as HARNESS-096 AC-4 does |

No criterion is oracle-free and none names a threshold. The controls are
AC-2 (real readers stay), AC-3's removed line, and AC-5.

**C-8. Callers and existing pins.** No option, exit status or stdout format
changes. What reads the output or the texts:

- `scripts/selftest.sh:312-331` (`--changed`): captures stderr whole and
  reprints it; takes the text after `all: ` on stderr's first line into its
  own header. The new `all` reason flows through unchanged. No edit.
- `.claude/tests/selftest.test.sh`, the `HARNESS-094 AC-7` blocks
  (`:2095`-`:2140`): fixture stubs with no declaration; unchanged. Its
  COUNTS table (`:557`, `selftest-needed 621`) takes the new count.
- `.claude/tests/selftest-needed.test.sh`: the HARNESS-094 and HARNESS-096
  cases hold no declaration and must pass untouched, as written. **One
  existing assertion is superseded:** HARNESS-096 AC-4's "the declaration
  is its own paragraph directly before the one beginning ...", which pins
  the paragraph as three lines; it becomes six (C-6). It is corrected in
  RED and is red there on its own, because the three new lines do not exist
  yet; say so in the handoff, as HARNESS-098 did for C-5's line. The pins
  on `CM_P1`-`CM_P3`, on the header's `SNH_N1`-`SNH_N4` and their order
  before `SNH_R4`, and on `CLAUDE.md` lines 160-162 all still hold as
  written and are controls for C-6.
- `.claude/tests/procedure.test.sh`, `dispatch.test.sh`,
  `reporting.test.sh`: read `advance-story.md`; none pins the clause C-6
  changes (grep for `mentions a` and `chooses them` over `.claude/tests`:
  no hit, 2026-11-19). RED confirms against the tree.
- `.claude/commands/complete-story.md`: its GATES → REVIEW bullet names the
  `--changed` run and does not state the rule. No edit.
- `attest.test.sh`, `boundaries.test.sh`, `run-queue.test.sh`: name the
  script only.
- No suite pins a line number inside any of the five suites of C-4 (grep
  for `<suite>.test.sh:<n>`: no hit), so a header line may be added.

**C-9. Baselines the story may read out.** The 11-line and 8-line lists of
the Context (release 132, `9fa2dfb`); 35 suites; `selftest-needed` executes
621 assertions today (`floors.conf`); the mutations M-1 to M-9.

**Test-only dependencies:** none. bash, awk, git and coreutils, as
`rules.md` "Portability" requires.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". Two entries, each one
`mutate.sh` run against the one suite that holds its assertion,
`bash scripts/selftest.sh selftest-needed`: DV-1 is the defect put back for
the central claim; DV-2 is the probe the law owes a changed rule over the
tree, against a real line of it. RED cannot run either: the script does not
read declarations until GREEN.

- **DV-1, the defect put back (AC-1).** With the one place in
  `scripts/selftest-needed.sh` that recognises a `# fixture-only:` line made
  to match nothing, the rule is the one `main` has today. `selftest-needed`
  **must** fail, and AC-1's list assertion must show as its actual value
  the eleven names of the Context: `boundaries`, `doctor`, `grep-count`,
  `host-load`, `refresh`, `run-lock`, `run-queue`, `selftest`,
  `shipped-docs`, `sigpipe`, `worktree`. AC-2, AC-3, AC-6 and AC-7 are
  expected red with it; the HARNESS-094 and HARNESS-096 cases must stay
  green. The expression is written at GATES against the script as built,
  must change code and not the header comment, and is recorded with the
  result. **Owner: GATES.**

- **DV-2, the contradiction check against the real spelling (AC-5).**
  AC-5's real cases claim the script sees a direct read as the tree really
  spells it. With the two real reads in `doctor.test.sh` respelled as
  fixture reads, the copy that AC-5 gives a declaration has nothing left to
  contradict it, so `doctor` must drop out of that case. `mutate.sh` must
  report 2 lines changed (`doctor.test.sh:102` and `:340` at PLANNED).
  `selftest-needed` **must** fail in AC-5's `doctor` case and nowhere else:
  AC-1 and AC-2 stay green, because the real `doctor.test.sh` carries no
  declaration and is selected by plain mention either way. The mutated
  suite is only read as text here; it is not executed. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/doctor.test.sh 's#"\$REPO_ROOT/\.claude/harness/VERSION"#"$FIX/.claude/harness/VERSION"#' -- bash scripts/selftest.sh selftest-needed

  (Checked at PLANNED with `sed -n ...p`: the expression rewrites exactly
  those two lines of the suite at `9fa2dfb`.)

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

Planned by `bash scripts/plan.sh write HARNESS-115` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`, resolved Fable 5.2 (`claude-fable-5-2`), as planned; no override.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **No change to R1, R2, R4 or R5**, to the `SCANS` table, to the run/skip
  mode, or to the enumeration of changed paths. `grep-count`, `sigpipe` and
  `shipped-docs` stay selected for any changed `.sh`; whether those three
  scanners are worth their cost on every story is a different question.
- **No transitive selection.** A suite that reads a real file only through
  a helper or a script it runs, and never names it, is not selected today
  and is not selected after this story (`make_fixture`'s copy of `VERSION`
  into 24 suites' fixtures; the Context has it). HARNESS-094 measured and
  rejected transitive selection; this story does not reopen it.
- **No automatic classification of mentions.** The script does not decide
  from a prefix such as `$FIX/` that a mention is fixture data. The only
  spelling it interprets is `$REPO_ROOT/` and `${REPO_ROOT}/`, and only to
  select MORE. D-1 has why.
- **No declaration beyond the seven pairs of C-4.** In particular `doctor`,
  `worktree` and `selftest` get none, and no suite declares a path it does
  not name today.
- **No change to `scripts/selftest.sh`**, to `--changed`, to the floors
  audit, or to `.claude/commands/complete-story.md` (its bullet names the
  `--changed` run and does not state the rule).
- **No check that a declaration is true** beyond AC-5. A suite that reads
  the real file by a composed path, through a helper, or under another root
  variable, and declares the path anyway, is believed. C-4's evidence and
  the diff review are what stand behind a declaration.
- **`project-*.test.sh` suites in consuming projects** may use the line;
  nothing here adds one or documents it for them beyond the three texts of
  C-6.
- **No audit of the selection rule as a whole**, and no mutation of every
  new assertion; `rules.md`, "Mutation work per story" is the budget.

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

- **PLANNED, 2026-11-19.** Planned by a `lead-po` dispatch on the PLANNED
  row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override
  was reported to it. Planned in the worktree `D:\adh-HARNESS-115` on the
  temporary branch `story/HARNESS-115-plan`, cut from `origin/main` at
  release 132 (`9fa2dfb`); the story's own `branch:` is the one in the
  frontmatter and is not created yet. Id checked free by the orchestrator
  on `origin/main`, the remote branches and PR titles the same day.
- **Type: `feature`, not `fix`.** Selecting on a test-data mention is the
  behaviour HARNESS-094 declared and HARNESS-096 and `CLAUDE.md` state, and
  no test or document says otherwise; nothing is broken. The story adds a
  declaration and a rule that reads it. AC-1 still reproduces the
  over-selection on HARNESS-114's path set and pins the list, as a `fix`
  would.
- **D-1, the mechanism. A PO decision for the user before the story leaves
  PLANNED; the story is written for option 1.**
  **Approved by the user, 2026-11-19: option 1, the declaration line in the suite.**
  1. *A per-suite declaration in the suite itself, `# fixture-only:
     <path>`, honoured by R3 (recommended).* The exemption is per suite and
     per path, so a new suite, or a new path, is selected by mention until
     somebody says otherwise: the default stays the safe one. The line sits
     in the file it describes, so whoever makes that suite read the real
     file is looking at it, and changing it selects the suite by R1. The
     script ignores it when the suite's own source reads the path under
     `$REPO_ROOT/`. Cost: five suites gain a comment line; a false
     declaration that reads the real file some other way is believed.
  2. *A table in `scripts/selftest-needed.sh`, like `SCANS`, of (suite,
     path) pairs.* The same rule with the declarations in one place, and no
     edit to the five suites. Rejected as the recommendation because the
     row lives away from the suite it describes, so the suite can change
     without the row being read; and a consuming project's
     `project-*.test.sh` could not declare anything without editing a
     shipped script that every refresh replaces.
  3. *Decide automatically from the spelling,* counting a mention only when
     it is not prefixed by a fixture variable (`$FIX/`, `$t/`, `$UP/`).
     Rejected: it under-selects on the tree as it is. `worktree` names
     `VERSION` only as `$1/`, `$UP/` and `$WA/` and in two comments, yet
     reads the real file through `make_project_fixture` (M-2 is red); under
     this option whether it stays selected would rest on those two
     comments. `selftest` reads the real `floors.conf` at `:457` through a
     composed path. A prefix is not evidence of what a suite reads.
  4. *A narrow exception: for `VERSION` and `floors.conf` only, select a
     fixed list of readers* (`doctor`, `worktree`; `selftest`). Smallest
     change and the same result today. Rejected: it inverts the default for
     those two paths, so a new suite that reads the real `VERSION` is
     silently unselected until someone remembers the list, which is the
     dangerous direction; and it does nothing for the next path of this
     kind.
  A fifth shape, a positive `reads:` list per suite that replaces mention
  for that suite, was not written up as an option: it makes every suite's
  selection depend on a list nothing checks, for the sake of two paths.
- **D-2, a path only declaring suites name answers `all` (C-2 case 3). A
  **Approved by the user, 2026-11-19: answer `all`.**
  declared mention still maps the path, as an undeclared test-data mention
  does since HARNESS-096, and the run selects nothing for it. Neither real
  path is affected (each keeps a real reader), so this only decides what
  happens to a future path, and `all` is the answer that cannot select too
  few. If the user prefers the other, AC-6 and C-2 (3) change and nothing
  else does.
  smaller PO decision, written as recommended.** The alternative is that a
- **What this buys, measured.** HARNESS-114's path set: 11 suites become 6.
  The five that drop are `boundaries` (687 assertions, the largest floor in
  the file), `refresh`, `run-queue`, `run-lock` and `host-load`. A story
  that changes only one suite, its floor, the COUNTS table and `VERSION`
  goes from 11 or 12 to 6 or 7: that suite, `selftest`, `doctor`,
  `worktree` and the three `*.sh` scanners. No wall-clock figure is
  claimed: the 3 hours measured on HARNESS-114 were under host load, and
  the single-suite times in the Context are too.
- **This story's own `--changed` run gets no benefit** and should not be
  read as the measure: it changes five more suites (each selected by R1),
  the selection script and `CLAUDE.md`. The benefit starts with the story
  after it.
- **HARNESS-114 collides, read by hand.** It is open on
  `origin/story/HARNESS-114-docs-read-rule-pins-brace-with-quote`, not
  merged, mid-cycle in the worktree `D:\adh-HARNESS-114`, and its
  `touches:` names `.claude/tests/shipped-docs.test.sh`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` and
  `.claude/harness/VERSION`; the last three are this story's too. That is a
  collision, not a dependency, so it is not in `depends_on`: it changes the
  `shipped-docs` floor line and COUNTS entry, this story the
  `selftest-needed` ones, and each takes its own release number. The two
  must not be treated as a clear pair; whichever merges second merges
  `main`, takes the next release number and has its gates run again. If
  HARNESS-114 merges first, AC-1's path set is still valid: it is a set of
  paths, not of that story's contents.
- **`bash scripts/plan.sh conflicts`, 2026-11-19, this worktree:** `fewer
  than two startable stories; nothing to compare`. It judged no pair, so it
  is not evidence that any pair is clear: HARNESS-114's story file is not
  on `origin/main`.
- **Not already delivered.** Reproduced at PLANNED on `9fa2dfb` (Context):
  11 of 35 for the four paths, 8 for the two.
- **Not split.** One behaviour (R3 reads a declaration), one script, one
  suite; the five declaration lines are data for AC-1 and cannot ship in a
  separate story without AC-1 being unpinnable in this one. The three texts
  are one sentence each.
- **A finding outside this story, for the user.** `make_fixture` copies the
  real `VERSION` into the fixtures of 24 suites, and `story` runs
  `doctor.sh` in one; none of them but `doctor` and `worktree` is selected
  for a `VERSION` change, today or after this story. Whether any of them
  can fail on a release bump was not measured here (it would take the full
  self-test under a mutated `VERSION`). CI's full run is the backstop, as
  for every transitive read.

