---
id: HARNESS-107
title: The changed-suites self-test runs the shipped-docs rule over a changed suite
slug: the-changed-suites-self-test-runs-the-sh
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-107-the-changed-suites-self-test-runs-the-sh
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/shipped-docs.test.sh, .claude/tests/boundaries.test.sh, .claude/tests/selftest.test.sh, .claude/tests/floors.conf, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the selftest-needed, shipped-docs and boundaries suites under their selftest floors, which CI runs in full on the PR
---

## Context

No epic. This story takes the three findings of HARNESS-106's diff review
(`docs/backlog/stories/HARNESS-106.md`, `## Diff review`, Review 1): the one
"should fix", which that story could not take because both files are outside
its **Writes:**, and the two "nice to have", which the orchestrator has
decided to take alongside it. Line numbers below are `origin/main` at
`a8e7b66` (the merge of #196); `2934b16`, the DONE commit above it, changes
only the story file.

**1. The local changed-suites run does not select the new rule (the central
claim).** HARNESS-106 gave `.claude/tests/shipped-docs.test.sh` a second
rule, `suite_docs_reads` (lines 155-205, asserted at 345-382): it scans every
top-level `.claude/tests/*.sh` - the suites, `_lib.sh`, `_spawns.sh` - for a
line that reads under the real checkout's `docs/`. `scripts/selftest-needed.sh
--suites` decides which suites `SELFTEST_JOBS=4 bash scripts/selftest.sh
--changed` runs, and a suite that reads the tree by glob is invisible to its
mention rule (R3), so such suites are declared in the `SCANS` table (comment
157-173, table 174-178, read by the loop at 179-187, applied at 248-256).
The table's only `shipped-docs` row is
`shipped-docs map .claude/commands/*.md .claude/agents/*.md .claude/skills/*.md`
(line 178). Nothing says the suite now also scans the suites. So a story that
adds a `docs/` read to some suite gets, from the local run, that suite,
`grep-count` and `sigpipe` - not `shipped-docs` - and the rule first runs in
CI's full run on the PR. Measured in the suite's own fixture: an edited
`.claude/tests/gamma.test.sh` prints `gamma`, `grep-count`, `sigpipe`
(`.claude/tests/selftest-needed.test.sh:624-629`).

**2. The rule's pattern misses three spellings.** `SDR_RE`
(`shipped-docs.test.sh:186`) ends in `(["'/ ]|$)` and admits only `}` and `"`
between the root name and a single `/`. Measured at PLANNED with the suite's
own awk program: `n=$(ls $REPO_ROOT/docs)` (the tail is `)`),
`"${REPO_ROOT%/}/docs/a"` and `"$REPO_ROOT//docs/a"` are not reported. None
is in the tree today; the comment at 177-179 states only the data-flow limit.

**3. The `boundaries` suite's exit trap removes one of its four temp paths.**
`.claude/tests/boundaries.test.sh:12` is `trap 'rm -rf "$FIX"' EXIT`. The
suite also makes `KB` (3907, a file), `K_NS_COPY` (4093, a file) and
`K_DECOY` (4225, a directory, HARNESS-106), each removed by a plain `rm` at
4103 and 4460-4461 - which an interrupted run never reaches. No other `trap`
and no other `mktemp` is in the file.

**The gate that would fail if this broke.** `bash scripts/gates.sh --list`
shows every gate `<unconfigured>` in this repository, so no gate, required or
optional, exercises any of this and `required_gates` stays empty, as in
HARNESS-106. The artifact is judged by three self-test suites under their
floors in `.claude/tests/floors.conf` - `selftest-needed`, `shipped-docs`,
`boundaries` - which `selftest.sh --changed` runs locally at GATES and CI
runs in full on the PR, and by `check-boundaries.sh` (the `VERSION` bump, the
deferred verifications' pasted results).

## Acceptance criteria

- **AC-1** — Given a harness tree that holds a `shipped-docs` suite, and a
  story branch whose only change is a top-level `.claude/tests/<name>.test.sh`
  (a tracked suite edited, or a new untracked one), when
  `bash scripts/selftest-needed.sh --suites` runs, then stdout is the changed
  suite, `grep-count`, `shipped-docs` and `sigpipe`, sorted, one per line and
  nothing else; the stderr header counts four selected; and stderr holds one
  reason line for `shipped-docs` naming the changed path and the rule
  `(scans .claude/tests/*.sh)`.
  *The bug this reproduces:* at `a8e7b66` the same change prints three
  suites, without `shipped-docs`. *Control:* with the new `SCANS` row removed
  from `scripts/selftest-needed.sh`, these assertions must fail (DV-1).
- **AC-2** — Given the same tree, when the only changed path is a
  `.claude/tests/*.sh` that no other rule places - an untracked helper no
  suite mentions, or a suite deleted on the branch - then `--suites` still
  prints the one line `all` and stderr still says the path `is mapped by no
  rule; defaulting to every suite`; and when it is `.claude/tests/_lib.sh` or
  `.claude/tests/_spawns.sh`, it still prints `all` and says the path `is
  read by every suite`. The new row adds a suite to a list; it never turns
  `all` into a list.
- **AC-3** — Given a fixture tree whose suite holds the lines
  `n=$(ls $REPO_ROOT/docs)`, `f="${REPO_ROOT%/}/docs/a"` and
  `f="$REPO_ROOT//docs/a"`, when the `shipped-docs` suite's rule
  `suite_docs_reads` runs over it, then it reports each of the three as
  `<file>:<line number>`, beside the four spellings HARNESS-106 AC-3 already
  names; and it reports nothing for `$REPO_ROOT/docs-shipped.conf`,
  `$REPO_ROOT/docsy/a`, `$REPO_ROOT/docs_old/a` or `$REPO_ROOT/docs.bak/a`,
  where `docs` is not a whole path component; and over this repository's own
  tree it still reports nothing.
  *Controls:* (a) against a real line of this tree, not only the fixture:
  with a line of a real suite rewritten to the first spelling, the real-tree
  assertion must fail naming that file and line (DV-2); (b) with the
  pattern's tail loosened to any character, the four `docs`-prefixed names
  above must be reported (DV-3).
- **AC-4** — Given the `boundaries` suite, when it reports the `EXIT` trap in
  force at its end (`trap -p EXIT`), then the trap removes all four temp
  paths the suite makes - `$FIX`, `$KB`, `$K_NS_COPY` and `$K_DECOY` - and
  tolerates any of the last three being unset, so that a run stopped at any
  point leaves none behind when the trap runs.
  *The bug this reproduces:* at `a8e7b66` the trap is `rm -rf "$FIX"` alone.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/shipped-docs.test.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/selftest.test.sh`, `.claude/tests/floors.conf`, `.claude/harness/VERSION`

**C-0. Who writes which.** Every path above classifies as `harness`
(`bash scripts/classify.sh <path>`, checked at PLANNED for all seven), so the
phase lock divides nothing and this block does.

- **RED (test-developer):** the three suites -
  `.claude/tests/selftest-needed.test.sh` (C-2),
  `.claude/tests/shipped-docs.test.sh` (C-3) and
  `.claude/tests/boundaries.test.sh` (C-4). Findings 2 and 3 are defects *in*
  a suite, so their fix is a test-file change and is RED's, in two steps each
  (C-3, C-4), as in HARNESS-106.
- **GREEN (feature-developer):** `scripts/selftest-needed.sh` (C-1), the one
  production change; then the floor records in `.claude/tests/floors.conf`
  and in `.claude/tests/selftest.test.sh`'s `COUNTS` list, and
  `.claude/harness/VERSION` (C-5). GREEN touches no assertion.

RED ends with `shipped-docs` and `boundaries` green and `selftest-needed`
red; GREEN turns `selftest-needed` green by adding one row.

**C-1. The `SCANS` row (AC-1, AC-2), `scripts/selftest-needed.sh`.** One new
line in the table, directly above the existing `shipped-docs map` row, so
that the table reads, exactly:

    SCANS='lib          add scripts/*.sh .claude/hooks/*.sh
    sigpipe      add *.sh
    grep-count   add *.sh
    profiles     map .claude/skills/stack-profiles/reference/*
    shipped-docs add .claude/tests/*.sh
    shipped-docs map .claude/commands/*.md .claude/agents/*.md .claude/skills/*.md'

(In the file the rows after the first start at column 0, as today.) The new
row is `shipped-docs add .claude/tests/*.sh`: suite name, one space, kind,
one space, pattern. It is above the `map` row, not last, so that it is a
whole line of its own and DV-1 can delete it without touching the closing
quote.

What each word is for:

- **`add`, not `map`.** The comment above the table (A-5) says why the `*.sh`
  scanners are `add`: a row that maps every shell file would keep any shell
  file from reaching R5. The same holds here. With `map`, an untracked helper
  under `.claude/tests/` that no suite mentions would print a list of three
  scanners, where today it prints `all`; AC-2 is that it must not.
- **Two rows for one suite name.** The loop at 179-187 stores one
  (name, pattern, kind) triple per *pattern*, and the existing `lib` and
  `shipped-docs` rows already hold several patterns each. A second row with
  the same name is more triples; the selection awk keeps the first record per
  suite, so `shipped-docs` is printed once. No path matches both rows (`.sh`
  against `.md`), so the reason line is never ambiguous. No loop change.
- **A-1 still applies, by construction.** The existence check
  (`[ -f ".claude/tests/$sc_suite.test.sh" ] || continue`, line 181) is per
  row, so in a tree with no `shipped-docs.test.sh` the new row contributes
  nothing. Not separately pinned by a new test: `selftest.test.sh`'s `cf_new`
  fixtures hold no `shipped-docs` suite and must come through unchanged.
- **The pattern over-selects, and that is accepted.** A `SCANS` pattern is a
  bash `case` pattern over the whole path, where `*` crosses `/`, so
  `.claude/tests/*.sh` also matches `.claude/tests/fixtures/<dir>/x.sh`,
  which the rule (top level only) does not scan. A `case` pattern cannot stop
  `*` at a `/` without `extglob`, which this script does not use. The cost is
  one small suite (18 assertions) run when a fixture script changes, and
  because the row is `add` it never maps such a path: measured at PLANNED in
  a scratch clone with the row in place, an untracked
  `.claude/tests/fixtures/h107/p.sh` still printed `all`, "mapped by no
  rule". No test pins the over-selection; a later narrowing is free to remove
  it.

The evidence comment above the table gains the second half of the
`shipped-docs` entry. GREEN words it; it must say: the `add` row, that
`suite_docs_reads` in `shipped-docs.test.sh` scans every top-level
`.claude/tests/*.sh` (HARNESS-106, HARNESS-107), and that the pattern also
matches a `.sh` in a subdirectory, which the rule does not scan, and why that
is harmless. The script's header (lines 34-70) is **not** changed: its R4
line already says "a row of the SCANS table below", and
`selftest-needed.test.sh` (HARNESS-096 AC-4) pins the header lines around it
byte for byte.

**C-2. `.claude/tests/selftest-needed.test.sh` (AC-1, AC-2), RED.** The
fixture's nine stub suites (`SUITE_STUBS`, line 509) already include
`shipped-docs`; no stub changes. `expect_suites` compares stdout whole, its
line count, and (mode `first`) the stderr header, from the root and from
`src/`: four assertions per directory.

Cases whose pinned values change (two):

| Line | Change on the branch | stdout at `a8e7b66` | stdout now | header |
|---|---|---|---|---|
| 625 | `gamma.test.sh` edited | `gamma`, `grep-count`, `sigpipe` | `gamma`, `grep-count`, `shipped-docs`, `sigpipe` | `hdr 4 9 1` (was `hdr 3 9 1`) |
| 634 | `delta.test.sh` new, untracked | `delta`, `grep-count`, `sigpipe` | `delta`, `grep-count`, `shipped-docs`, `sigpipe` | `hdr 4 10 1` (was `hdr 3 10 1`) |

Their labels say "(and the *.sh scanners)" / name the count; reword them to
name `shipped-docs` too.

One new assertion (AC-1), directly after the existing `reason_lines gamma ...
itself` assertion (630-631). In the gamma case no `.md` changed and no stub
mentions gamma's path, so the row is the only thing that can select
`shipped-docs`, and the needle names the rule:

    assert_eq "HARNESS-107 AC-1: stderr names shipped-docs' path and the pattern that matched: (scans .claude/tests/*.sh)" 1 \
      "$(reason_lines shipped-docs .claude/tests/gamma.test.sh 'scans .claude/tests/*.sh')"

Cases that change a `.claude/tests/*.sh` and must stay **exactly as they
are** (AC-2; they are the controls on `add`, and each compares stderr whole):

| Line | Change | Pinned |
|---|---|---|
| 641 | `_lib.sh` beside a mapped `n.conf` | `all`, "`.claude/tests/_lib.sh` is read by every suite" |
| 646 | `_spawns.sh` | `all`, "... is read by every suite" |
| 788 | untracked `_h096_fixture_helper.sh` | `all`, "... is mapped by no rule; defaulting to every suite" |
| 861 | `gamma.test.sh` deleted | `all`, "... is mapped by no rule; defaulting to every suite" |

Lines 788 and 861 are what fails if the row is written `map`: both would
print a list. They pass before and after, unchanged, so nothing is owed for
them.

Every other case is untouched by the row and must not be edited: the
`.sh` cases at 754-776 and the HARNESS-096 cases (`scripts/x.sh`,
`scripts/new`) change no path under `.claude/tests/` on the branch - the
HARNESS-096 edit to gamma is committed on `main` before the branch is cut -
and the `.md` cases (798-817) match only the `map` row. The HARNESS-078
cases use the run/skip mode.

`hdr` (590-594) and `reason_lines` (571-580) are unchanged. What moves on
stderr is only what the table says: the count in two headers, and one more
reason line in those two runs.

Expected at the end of RED, on this Windows host:
`selftest-needed: 608 passed, 13 failed` - 621 executed (620 today plus the
one new assertion); the 13 are the two cases' stdout, line count and header
from each directory (12) and the new reason-line assertion. On Linux the
HARNESS-078 cases run too and the executed count is higher; the failures are
the same 13.

**C-3. `.claude/tests/shipped-docs.test.sh` (AC-3), RED, in two steps.**

*The pattern.* Line 186 becomes, exactly:

    SDR_RE='(REPO''_ROOT|TESTS''_DIR/[.][.]/[.][.])(%/)?[}"]*/+docs([^A-Za-z0-9_.-]|$)'

What each change is for, one per spelling:

- `(%/)?` admits `${REPO_ROOT%/}`: the root with one trailing slash
  stripped, which is still the root. Nothing else may follow `%` - `%/*`
  (the parent directory) does not match, and is not pinned.
- `/+` admits `$REPO_ROOT//docs`: the shell collapses repeated slashes.
- `([^A-Za-z0-9_.-]|$)` replaces `(["'/ ]|$)`: after `docs` comes end of
  line or any character that cannot continue a file name, so `)`, `;`, `|`
  and a backtick end it as a quote or a slash does. The five excluded classes
  are the point of the tail: letters and digits (`docsy`, `docs2`), `_`
  (`docs_old`), `.` (`docs.bak`) and `-` (`docs-shipped.conf`) continue the
  name, and none of those is `docs`.

It still passes through `awk -v`, which processes backslash escapes: the new
pattern holds no backslash, and keeps `[.]` for that reason. The quoting no
longer needs `'\''`, since the tail names no single quote. The two root
names stay spelled in pieces (`REPO''_ROOT`), on this line and in every
fixture line: the suite scans itself.

Measured at PLANNED (2026-11-13, Git Bash gawk 5.4.1) with the suite's own
awk program and this pattern: over the real tree's 36 `.claude/tests/*.sh`
files, no line is reported; over a file of sample lines, the seven positive
spellings below and `X="$REPO_ROOT/docs"` are reported and the four
`docs`-prefixed negatives and the two other roots are not. These are
**settled**: read them out.

*The comment* (155-185). Rewrite the description of the pattern to match
(what may sit between the root name and `/docs`, the tail as "end of line or
a character that cannot continue a file name"). The written limit stays the
data-flow one, word for word in substance; the three spellings are no longer
a limit and are not listed as one.

*The fixture* (the `a.test.sh` built at 362-371). Lines 1-8 unchanged. Seven
lines are appended, each written with `$SDR_R` in pieces as lines 2-7 are:

| Line | Text as the fixture file holds it | Reported |
|---|---|---|
| 9 | `n=$(ls $REPO_ROOT/docs)` | yes |
| 10 | `f="${REPO_ROOT%/}/docs/a"` | yes |
| 11 | `f="$REPO_ROOT//docs/a"` | yes |
| 12 | `cat "$REPO_ROOT/docs-shipped.conf"` | no |
| 13 | `ls "$REPO_ROOT/docsy/a"` | no |
| 14 | `ls "$REPO_ROOT/docs_old/a"` | no |
| 15 | `ls "$REPO_ROOT/docs.bak/a"` | no |

Existing line 7 reads `docs-shipped.conf` under `.claude/harness/`, where no
`/docs` follows the root at all; line 12 is the control that tests the tail.

*The two assertions, corrected in place* (no new assertion; the suite still
executes 18):

- the fixture assertion (372-377) expects, exactly, one per line:
  `.claude/tests/_lib.sh:1`, `.claude/tests/a.test.sh:3`,
  `.claude/tests/a.test.sh:4`, `.claude/tests/a.test.sh:5`,
  `.claude/tests/a.test.sh:8`, `.claude/tests/a.test.sh:9`,
  `.claude/tests/a.test.sh:10`, `.claude/tests/a.test.sh:11`;
- the twin (378-382) removes lines 3, 4, 5, 8, 9, 10 and 11 (so 2, 6, 7 and
  12-15 stay) and expects nothing.

The real-tree assertion (348-349) and the "at least 30 files" check are
unchanged.

*Step 1, the fixture, with line 186 still as it is.* Run
`bash scripts/selftest.sh shipped-docs`. Expected, and pasted into the
handoff with the actual value: `shipped-docs: 17 passed, 1 failed` - the
fixture assertion, its actual value lacking the three lines `:9`, `:10`,
`:11`. The twin passes on arrival; DV-3 earns it.
*Step 2, the fix.* Replace line 186 and the comment. Same command:
`shipped-docs: 18 passed, 0 failed`.

**C-4. `.claude/tests/boundaries.test.sh` (AC-4), RED, in two steps.**

*The trap.* Line 12 becomes, exactly:

    trap 'rm -rf "$FIX" "${KB:-}" "${K_NS_COPY:-}" "${K_DECOY:-}"' EXIT

All four temp paths the file makes, not `K_DECOY` alone: `KB` and
`K_NS_COPY` have the same shape (made mid-file, removed by a plain `rm` an
interrupted run does not reach) and one line covers them. `${X:-}` because
`_lib.sh` sets `-u` and the trap can fire before a name is assigned;
`rm -rf ""` exits 0 and prints nothing (measured at PLANNED). The plain `rm`
lines at 4103 and 4460-4461 stay: removing early is still right, and the
trap is for the run that never gets there.

*The assertion.* One new `assert_eq`, directly before `summary "boundaries"`
(so that it reports the trap in force at the end, and a later `trap` that
replaced line 12's would be caught):

    assert_eq "HARNESS-107 AC-4: the exit trap in force at the end of the suite removes every temp path the suite makes" \
      "trap -- 'rm -rf \"\$FIX\" \"\${KB:-}\" \"\${K_NS_COPY:-}\" \"\${K_DECOY:-}\"' EXIT" "$(trap -p EXIT)"

`trap -p` inside a command substitution reports the parent shell's traps;
measured at PLANNED on this host's bash 5.3, where it printed the expected
string above byte for byte. The name carries no head-shaped text, no comment
opener and no fence marker (HARNESS-106 C-6 applies to this file).

This pins what the trap *is*, read from the running shell rather than from
the source. It does not start a run and interrupt it; that would be a
35-minute suite killed on a timer to check one `rm`, and it is out of scope.

*Step 1.* Add the assertion with line 12 unchanged; run
`bash scripts/selftest.sh boundaries`. Expected, pasted into the handoff:
`boundaries: 686 passed, 1 failed`, the actual value
`trap -- 'rm -rf "$FIX"' EXIT`. *Step 2.* Replace line 12; same command:
`boundaries: 687 passed, 0 failed`.

`boundaries` is slow on a loaded host (HARNESS-106 C-10: over 35 minutes
with another self-test running). These two runs are the only ones RED owes
it; start each in the background and work on C-2 and C-3 meanwhile. Do not
substitute an extract of the file for the suite.

**C-5. The floors and the release (GREEN).** At `a8e7b66`:
`floor | boundaries    | 686` (`floors.conf` line 40) and `boundaries 686`
(`selftest.test.sh` line 531); `floor | selftest-needed | 620` (line 64) and
`selftest-needed 620` (line 556); `floor | shipped-docs  | 18` (line 66) and
`shipped-docs 18` (line 558). GREEN raises the first two pairs, in one
commit, to the executed counts it measures with
`bash scripts/selftest.sh selftest-needed shipped-docs boundaries`: expected
`boundaries` 687 and `selftest-needed` 621 on this host. `shipped-docs`
stays 18: two assertions are corrected, none added, and GREEN confirms the
count rather than touching the row. If RED added or dropped an assertion,
the measured count is the floor and the handoff says which. A dated comment
at the end of `floors.conf`, in the form the HARNESS-106 entry (1202-1208)
uses, records both raises and says in one clause that `shipped-docs` is
unchanged at 18. `.claude/harness/VERSION` goes from `125 (2026-11-13)` to
`126` with the real calendar date of the change.

**C-6. Oracle partition.** All four criteria are **mechanical**: pin the
lists, the header counts, the reported lines and the trap string exactly;
invent no metric. Within them, C-3's measurements and the table of C-2 are
**settled** - read out, not re-derived to fit. If a value RED observes
differs from one pinned here, stop and report it; do not edit the
expectation to match.

**C-7. Changed signatures: none; the readers of what changes.**

- `SCANS` is read only inside `scripts/selftest-needed.sh` (179-187,
  248-256).
- `--suites` output: `scripts/selftest.sh:312` (`--changed`) runs what it
  prints and passes its stderr through; it needs no change, and
  `selftest.test.sh`'s `--changed` cases build fixtures with no `shipped-docs`
  suite (A-1), so their pinned lists stand. `.claude/commands/advance-story.md`
  (line 307, "the five tree-scanning suites for the paths they scan") and
  `CLAUDE.md` (161, 190-192) describe `--suites` without listing rows; both
  stay true and neither is edited - `CLAUDE.md` lines 160-162 are pinned by
  line number. No workflow under `.github/` calls `--suites`.
- `suite_docs_reads <root>`, `suite_docs_files <root>` and `SDR_RE` keep
  their names, arguments and output format. Callers: `shipped-docs.test.sh`
  349, 350, 377 and 382 only (`SDR_RE` at 197 only).
- The `boundaries` trap has no caller.

**C-8. Commands.**

    bash scripts/selftest.sh shipped-docs
    bash scripts/selftest.sh selftest-needed
    bash scripts/selftest.sh boundaries
    bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed shipped-docs boundaries
    bash scripts/selftest-needed.sh --suites
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/gates.sh --fast

`selftest-needed` alone took several minutes at PLANNED on this host. RED
records what `selftest-needed.sh --suites` prints for its own diff: three
changed suites select themselves, `grep-count`, `sigpipe` and whatever
mentions them; `all` is not a failure, and the handoff says which path
caused it.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". Three entries, each one
`mutate.sh` run against the one suite that holds its assertion: DV-1 is the
defect put back for the central claim; DV-2 is the probe the law owes a
changed rule over the tree, against a real line of it; DV-3 earns the one
corrected assertion that passes on arrival (the twin of C-3), and is there
because the widened tail is exactly the kind of change that can quietly
become "match anything". Every expression is restated by RED's handoff
against the files as built. Line numbers in results are pasted, not
predicted.

- **DV-1, the defect put back (AC-1).** With the new row deleted from
  `SCANS`, a changed suite again does not select `shipped-docs`.
  `mutate.sh` must report 1 line changed. `selftest-needed` **must** report
  exactly 13 failed: for the edited-`gamma` case and the new-`delta` case,
  the whole stdout, its line count and the stderr header, from the root and
  from `src/` (12), and the `HARNESS-107 AC-1` reason-line assertion, actual
  `0`. The four AC-2 cases still pass. RED cannot run this: in RED the row
  does not exist, and the same 13 are red for that reason - an observation
  of the unfixed tree, not a mutation of the fixed one. **Owner: GATES.**

      bash scripts/mutate.sh scripts/selftest-needed.sh '/^shipped-docs add /d' -- bash scripts/selftest.sh selftest-needed

- **DV-2, the widened pattern against a real line of this tree (AC-3,
  control a).** One line of a real suite, rewritten to the unquoted
  command-substitution spelling the old pattern could not see, must be
  reported. `mutate.sh` must report 1 line changed. `shipped-docs` **must**
  report exactly 1 failed: the real-tree assertion (`suite_docs_reads over
  the real tree prints nothing`), its actual value the one line
  `.claude/tests/selftest-needed.test.sh:<n>`. The mutated suite is only
  read as text by this run, never executed. Under the pattern as it stands
  at `a8e7b66` this same mutation leaves the suite green (the tail is `)`),
  which is what makes the result a statement about the new pattern. RED
  could run it after its step 2, but the tree it would run on is not the
  committed one and the selection row is not in yet; one run at GATES covers
  the story as built. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/selftest-needed.test.sh 's|^CM="\$REPO_ROOT/CLAUDE\.md"$|CM="$(ls $REPO_ROOT/docs)"|' -- bash scripts/selftest.sh shipped-docs

  (`CM="$REPO_ROOT/CLAUDE.md"` is line 868 at `a8e7b66` and occurs once in
  `.claude/tests/*.sh`.)

- **DV-3, the tail still excludes what it must (AC-3, control b).** With the
  tail's bracket expression replaced by `.` (any character), `docs` followed
  by `-`, `y`, `_` or `.` matches. `mutate.sh` must report 1 line changed.
  `shipped-docs` **must** report exactly 2 failed: the fixture assertion, its
  actual value the eight expected lines plus `.claude/tests/a.test.sh:12`,
  `:13`, `:14` and `:15`; and the twin, its actual value those four lines.
  The real-tree assertion still passes (measured at PLANNED: under this
  loosened pattern no line of the 36 files is reported). RED cannot earn the
  twin by watching it fail: it passes in step 1 and in step 2, whatever the
  tail is. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s/\[^A-Za-z0-9_\.-\]/./' -- bash scripts/selftest.sh shipped-docs

Not owed, and stated so that nobody adds one: a mutation for the `boundaries`
trap assertion (it is red in C-4's step 1, the ordinary way); one per fixture
line of C-3; one for the four AC-2 cases (unchanged tests); and a run of
`boundaries` under any mutation.

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

Planned by `bash scripts/plan.sh write HARNESS-107` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`, resolved Fable 5.2 (`claude-fable-5-2`), as planned; no override.
## Out of scope

- **Data-flow reads in the rule.** A path built in a variable first, a `cd`
  to the root followed by a relative `docs/...`, `git -C <root> show
  HEAD:docs/...`: still the rule's written limit. So are a root reached
  through a third name, and `${REPO_ROOT%/*}` and other expansions beyond
  the one C-3 names.
- **Narrowing the `SCANS` pattern to the top level.** Accepted as
  over-selection (C-1). No `extglob`, no second table column.
- **Checking a `SCANS` row against what its suite really reads.** A row is
  still a declaration nobody verifies; this story adds the row the review
  found missing and no mechanism that would have found it.
- **Checking a story's `touches:` or `**Writes:**` against its diff.**
- **The script's header, `CLAUDE.md`, `advance-story.md`, the skills.** No
  prose changes; C-7 says why each stays true.
- **Starting and interrupting a real `boundaries` run** to watch the trap
  clean up. AC-4 pins the trap's text as the shell reports it.
- **The plain `rm` lines in `boundaries.test.sh`** (4103, 4460-4461) and
  every other case of that suite: unchanged.
- **Temp paths in other suites.** Only `boundaries.test.sh`'s trap is in the
  review's finding; no sweep of the other 33 suites.
- **Reads of the real tree outside `docs/`**, as in HARNESS-106.
- **A test pinning A-1 for the new row**, or the fixture-subdirectory
  over-selection (C-1).

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

- **Planned 2026-11-13** in worktree
  `.claude/worktrees/loving-elbakyan-3fe420`, on the story branch, based on
  `origin/main` at `2934b16` (HARNESS-106 merged as #196 at `a8e7b66`). The
  story file was created by `new-story.sh` in the orchestrating session,
  which owns the check that the id was free.
- **Source.** HARNESS-106 `## Diff review`, Review 1: finding 1 (should fix,
  routed RED, deferred to a follow-up because its files were outside that
  story's **Writes:**), findings 2 and 3 (nice to have), both taken here by
  the orchestrator's decision.
- **Decisions made at PLANNED, each open to RED's amendment with a reason:**
  the row is `add` and sits above the `map` row (C-1); the pattern's
  over-selection of `.sh` files in subdirectories is accepted, not narrowed
  (C-1); the trap names `KB` and `K_NS_COPY` as well as `K_DECOY` (C-4); the
  trap is evidenced by one `trap -p` assertion rather than by an interrupted
  run (C-4); `shipped-docs` gains no assertion and its floor stays 18 (C-5).
- **`.claude/tests/selftest.test.sh` is in the footprint** although the brief
  did not list it: its `COUNTS` list (531, 556) pins the same floors as
  `floors.conf`, and HARNESS-106's GREEN commit (`b4f19c2`) changed both.
- **Measured at PLANNED, not assumed:** the new `SDR_RE` over the real tree's
  36 files and over sample lines, and the loosened DV-3 pattern over the real
  tree (C-3, DV-3); the old pattern missing the three spellings; the new row
  in a scratch clone of this branch - an edited real suite selected
  `shipped-docs` with the reason `(scans .claude/tests/*.sh)`, and a `.sh`
  under `.claude/tests/fixtures/` still printed `all` (C-1); `trap -p EXIT`
  in a command substitution and `rm -rf ""` on this host (C-4); all seven
  paths classify `harness`; every gate is `<unconfigured>`; `plan.sh
  conflicts` reports fewer than two startable stories.
  Also measured, in that clone: the unchanged `selftest-needed.test.sh` run
  against the row failed exactly 12 assertions through every HARNESS-094
  block - the six of the edited-`gamma` case and the six of the new-`delta`
  case, with the values C-2's table pins - and the four AC-2 cases passed.
  The run was read up to the start of the HARNESS-096 block and not to its
  summary line; those cases change only paths under `scripts/`.
  **Not measured:** the `boundaries` count on this tree today (686 is the
  floor and HARNESS-106's record); `trap -p` on the CI runner's bash; the
  awk on the CI runner (the pattern uses only `?`, `+` and a negated bracket
  expression, which POSIX ERE defines).

