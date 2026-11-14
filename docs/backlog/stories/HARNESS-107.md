---
id: HARNESS-107
title: The changed-suites self-test runs the shipped-docs rule over a changed suite
slug: the-changed-suites-self-test-runs-the-sh
epic: 
type: fix
status: done
phase: DONE
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

**Results, GATES (2026-11-13, orchestrator; one `mutate.sh` run each, no other self-test or gates run on the host).** All three as predicted; every file restored and verified by `mutate.sh`.

DV-1 - 1 line changed; `selftest-needed` 13 failed, exactly the 13 named; the four AC-2 cases pass:

```
=== mutate: scripts/selftest-needed.sh (1 line(s) changed by /^shipped-docs add /d) ===
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stdout is exactly the pinned list
    FAIL ... [from root]: stdout has exactly 4 line(s)
    FAIL ... [from root]: stderr's first line is exactly the pinned header
    FAIL ... the same three [from subdir]
    FAIL HARNESS-107 AC-1: stderr names shipped-docs' path and the pattern that matched: (scans .claude/tests/*.sh)
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from root]: stdout is exactly the pinned list
    FAIL ... the same stdout, line count and header, from root and from subdir (6 in all)
selftest-needed: 608 passed, 13 failed
=== mutate: command exited 1; restored (verified byte-for-byte against .../.claude/state/mutations/scripts_selftest-needed.sh.20261114T011448Z.77560.bak) ===
  185: shipped-docs add .claude/tests/*.sh
```

DV-2 - 1 line changed (line 872); `shipped-docs` exactly 1 failed, the real-tree assertion naming that line:

```
    FAIL HARNESS-106 AC-3: suite_docs_reads over the real tree prints nothing: no suite line reads the project's own docs, which a consumer does not share
         expected: 
         actual:   .claude/tests/selftest-needed.test.sh:872
shipped-docs: 17 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against .../.claude/state/mutations/.claude_tests_selftest-needed.test.sh.20261114T011406Z.76365.bak) ===
  872: CM="$REPO_ROOT/CLAUDE.md"
```

DV-3 - 1 line changed (line 192); `shipped-docs` exactly 2 failed: the fixture gains `a.test.sh:12`-`:15`, and the twin reports its four docs-prefixed lines (numbered 5-8 in the twin's own, shorter fixture); the real-tree assertion passes:

```
    FAIL HARNESS-106 AC-3, HARNESS-107 AC-3: a fixture holding each spelling, ... none for the comment, the other roots, docs-shipped.conf or a docs-prefixed name
         expected: .claude/tests/_lib.sh:1 .claude/tests/a.test.sh:3 :4 :5 :8 :9 :10 :11
         actual:   .claude/tests/_lib.sh:1 .claude/tests/a.test.sh:3 :4 :5 :8 :9 :10 :11 :12 :13 :14 :15
    FAIL HARNESS-106 AC-3, HARNESS-107 AC-3: twin: the same fixture with only the comment, the other roots, docs-shipped.conf and the docs-prefixed names left prints nothing
         expected: 
         actual:   .claude/tests/a.test.sh:5 .claude/tests/a.test.sh:6 .claude/tests/a.test.sh:7 .claude/tests/a.test.sh:8
shipped-docs: 16 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against .../.claude/state/mutations/.claude_tests_shipped-docs.test.sh.20261114T011424Z.76927.bak) ===
  192: SDR_RE='(REPO''_ROOT|TESTS''_DIR/[.][.]/[.][.])(%/)?[}"]*/+docs([^A-Za-z0-9_.-]|$)'
```

(The multi-line `expected:`/`actual:` values are joined onto one line here; the full output is the run's own, abridged only where marked `...`.)

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
- RED, `test-developer` (two dispatches: the first paused at the user's request while other hosts' self-tests ran, the second resumed from its recorded place), declared `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- GREEN, `feature-developer`, declared `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override. The orchestrator then set VERSION's date to 2026-11-13, the local calendar date of the release (GREEN had used UTC).
- GATES, run by the orchestrator (Opus 5.5, `claude-opus-5-5`): DV-1..DV-3 and `gates.sh` directly, no `feature-developer` dispatch, because no gate is configured here (the run takes a second) and the user's one-run-at-a-time rule made a separate dispatch add nothing.
- DIFF-REVIEW, `lead-po`, declared `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override.
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

All four criteria are mechanical (C-6): every test pins an exact list, count,
line set or string. All tests are bash assertions in the harness's own suites,
the cheapest level that can falsify each criterion: the `--suites` selection
is a pure function of the changed paths in a fixture git repo
(`selftest-needed`), the docs rule is an awk program over a fixture tree and
the real tree (`shipped-docs`), and the trap is read from the running shell
(`boundaries`).

| AC | Test (file:line, as built) | What it asserts | Level |
|---|---|---|---|
| AC-1 | `.claude/tests/selftest-needed.test.sh:626` (`expect_suites`, edited gamma) | stdout exactly `gamma`/`grep-count`/`shipped-docs`/`sigpipe`, 4 lines, header `hdr 4 9 1`, from root and from `src/` (6 assertions) | fixture repo |
| AC-1 | `.claude/tests/selftest-needed.test.sh:638` (`expect_suites`, new untracked delta) | stdout exactly `delta`/`grep-count`/`shipped-docs`/`sigpipe`, 4 lines, header `hdr 4 10 1`, both directories (6) | fixture repo |
| AC-1 | `.claude/tests/selftest-needed.test.sh:633` (`HARNESS-107 AC-1` reason line) | exactly one stderr reason line for `shipped-docs` naming `.claude/tests/gamma.test.sh` and `scans .claude/tests/*.sh` | fixture repo |
| AC-2 | `.claude/tests/selftest-needed.test.sh:647`, `:652` (unchanged) | `_lib.sh`, `_spawns.sh` still print `all`, whole stderr "is read by every suite" | fixture repo |
| AC-2 | `.claude/tests/selftest-needed.test.sh:793`, and the deleted-gamma case after the comment at `:859` (unchanged) | untracked helper / deleted suite still print `all`, whole stderr "is mapped by no rule; defaulting to every suite" - the controls that fail if the row is written `map` | fixture repo |
| AC-3 | `.claude/tests/shipped-docs.test.sh:385` (fixture assertion, corrected in place) | `suite_docs_reads` over the 15-line fixture reports exactly `_lib.sh:1`, `a.test.sh:3,4,5,8,9,10,11` - lines 9-11 are the three new spellings; 12-15 (`docs-shipped.conf`, `docsy`, `docs_old`, `docs.bak`) are absent | fixture tree |
| AC-3 | `.claude/tests/shipped-docs.test.sh:397` (twin, corrected in place) | with the reporting lines removed, the remainder (2, 6, 7, 12-15) prints nothing | fixture tree |
| AC-3 | `.claude/tests/shipped-docs.test.sh:354` (unchanged) | over the real tree, nothing is reported | real tree |
| AC-4 | `.claude/tests/boundaries.test.sh:4463` (`HARNESS-107 AC-4`) | `trap -p EXIT` at the end of the suite is exactly `trap -- 'rm -rf "$FIX" "${KB:-}" "${K_NS_COPY:-}" "${K_DECOY:-}"' EXIT` | running shell |

Out of scope and not pinned: the over-selection of
`.claude/tests/fixtures/**/*.sh` by the new row (C-1); interrupting a real
`boundaries` run to observe the trap fire (C-4).

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

### RED complete (2026-11-13/14, test-developer, model `opus` as declared; no override)

RED ends as C-0 says: `shipped-docs` and `boundaries` green, `selftest-needed`
red on exactly the 13 assertions that need the new `SCANS` row. This dispatch
resumed a paused one; the paused notes are folded in below.

#### Files touched (all uncommitted)

- `.claude/tests/selftest-needed.test.sh` - C-2: the gamma (`:626`) and delta
  (`:638`) cases expect `shipped-docs` and `hdr 4 9 1` / `hdr 4 10 1`, labels
  reworded; new `HARNESS-107 AC-1` reason-line assertion at `:633-634`. The
  four AC-2 cases are untouched.
- `.claude/tests/shipped-docs.test.sh` - C-3 both steps: fixture lines 9-15
  appended (root names in pieces), fixture assertion (`:385`) and twin
  (`:397`) corrected in place, `SDR_RE` replaced (now line **192**, the
  Contract's text exactly), the comment above it rewritten (6 lines longer).
  The written data-flow limit is unchanged.
- `.claude/tests/boundaries.test.sh` - C-4 both steps: `HARNESS-107 AC-4`
  assertion at `:4463-4464`, directly before `summary "boundaries"`; line 12
  is now exactly `trap 'rm -rf "$FIX" "${KB:-}" "${K_NS_COPY:-}" "${K_DECOY:-}"' EXIT`.
- `docs/backlog/stories/HARNESS-107.md` - `## Test plan` and this section.

No production file, no `floors.conf`, no `selftest.test.sh`, no `VERSION`.
No Contract block or criterion amended.

#### Line numbers that moved (for GATES and anyone reading C-7)

- DV-2 target `CM="$REPO_ROOT/CLAUDE.md"`: `selftest-needed.test.sh` line
  **872** (868 at `a8e7b66`); still the only occurrence in
  `.claude/tests/*.sh`.
- C-7 callers of `suite_docs_reads` / `suite_docs_files` in
  `shipped-docs.test.sh`: now **355, 356, 393, 398**. C-7 says 349, 350, 377,
  382; the paused notes said 349, 350, 387, 392, which was before the comment
  grew by 6 lines. `SDR_RE` is defined at 192 and used at 203 only. Names,
  arguments and output format unchanged.
- DV-3 target: the `^SDR_RE=` line, 192.

#### Commands

The per-suite form, each wrapped in `attest.sh`:

    bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed
    bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs
    bash scripts/attest.sh -- bash scripts/selftest.sh boundaries

GREEN, after C-1 and C-5 (C-8's combined run measures all three floors at once):

    bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed shipped-docs boundaries
    bash scripts/selftest-needed.sh --suites
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/attest.sh -- bash scripts/gates.sh --fast

Machine rule from the user: one full self-test or gates run at a time on this
host. Check `ps -ef | grep -E 'selftest|gates' | grep -v grep` before every
run and wait while any other run, in any worktree or repo, is going.

#### Runs, in order

| Step | Command | Record | exit | `last:` |
|---|---|---|---|---|
| C-4 step 1 | `bash scripts/selftest.sh boundaries` (**not attested**: started by the paused dispatch, read after it finished) | scratchpad log `C:\Users\ryanc\AppData\Local\Temp\claude\448abf125ae995ab\ed47c881-7261-48d7-a518-80f814c11e15\scratchpad\boundaries-step1.log` (session-local; output pasted below) | 1 | `1 of 1 harness suite(s) FAILED.` |
| C-3 step 1 | `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs` | `.claude/state/attest-logs/20261113T233858Z.487441.log`, tree `dc274e83` | 1 | `1 of 1 harness suite(s) FAILED.` |
| C-3 step 2 | `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs` | `.claude/state/attest-logs/20261113T233940Z.505.log`, tree `7d9fc814` | 0 | `1 harness suite(s) passed.` |
| C-4 step 2 | `bash scripts/attest.sh -- bash scripts/selftest.sh boundaries` | `.claude/state/attest-logs/20261113T234027Z.2019.log`, tree `9b6bb436`, 2271 s | 0 | `1 harness suite(s) passed.` |
| end of RED | `bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed` | `.claude/state/attest-logs/20261114T001832Z.61.log`, tree `9b6bb436`, 376 s | 1 | `1 of 1 harness suite(s) FAILED.` |
| end of RED | `bash scripts/attest.sh -- bash scripts/gates.sh --fast` | `.claude/state/attest-logs/20261114T002510Z.1418.log`, tree `9b6bb436` | 0 | `All required gates passed (0 ran, 5 unconfigured, 0 known).` |
| end of RED | `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs` (re-run on the final tree; `shipped-docs: 18 passed, 0 failed`) | `.claude/state/attest-logs/20261114T002953Z.525.log`, tree `9b6bb436` | 0 | `1 harness suite(s) passed.` |

Every attested record is `status: ok` (the tree did not move during the run).
The C-3 step-2 record is on an earlier tree (`7d9fc814`) because line 12 of
`boundaries.test.sh` changed after it, so shipped-docs was re-run on the
final tree. `attest.sh check` reports `fresh` on tree `9b6bb436` for the
last four records, after this section was written (the story file is not in
the gated tree hash). `gates.sh --fast` ran no
gate: this repository's `project.conf` is not bootstrapped (5 gates
UNCONFIGURED, warnings only), so the self-test suites are the only test
instrument here and `--fast` has no shape to show.

#### Verbatim failures

C-4 step 1 (boundaries, line 12 unchanged; **not attested**, read from the
log above):

```
    FAIL HARNESS-107 AC-4: the exit trap in force at the end of the suite removes every temp path the suite makes
         expected: trap -- 'rm -rf "$FIX" "${KB:-}" "${K_NS_COPY:-}" "${K_DECOY:-}"' EXIT
         actual:   trap -- 'rm -rf "$FIX"' EXIT

boundaries: 686 passed, 1 failed

assertion floors: all 1 suite(s) met their declared floor (686 assertions executed, 686 declared).
1 of 1 harness suite(s) FAILED.
```

C-3 step 1 (shipped-docs, fixture in, `SDR_RE` unchanged): 17/1 as
predicted, the actual value lacking exactly `:9`, `:10`, `:11`:

```
    FAIL HARNESS-106 AC-3, HARNESS-107 AC-3: a fixture holding each spelling, in a suite and in _lib.sh, gets one file-and-line per reading line - the unquoted command substitution, the %/-stripped root and the doubled slash included - and none for the comment, the other roots, docs-shipped.conf or a docs-prefixed name
         expected: .claude/tests/_lib.sh:1
         .claude/tests/a.test.sh:3
         .claude/tests/a.test.sh:4
         .claude/tests/a.test.sh:5
         .claude/tests/a.test.sh:8
         .claude/tests/a.test.sh:9
         .claude/tests/a.test.sh:10
         .claude/tests/a.test.sh:11
         actual:   .claude/tests/_lib.sh:1
         .claude/tests/a.test.sh:3
         .claude/tests/a.test.sh:4
         .claude/tests/a.test.sh:5
         .claude/tests/a.test.sh:8

shipped-docs: 17 passed, 1 failed
FAIL shipped-docs  did 17 units of work, below the floor of 18 in .claude/tests/floors.conf
```

After C-3 step 2: `shipped-docs: 18 passed, 0 failed`. After C-4 step 2:
`boundaries: 687 passed, 0 failed`, with
`assertion floors: all 1 suite(s) met their declared floor (687 assertions executed, 686 declared).`

End of RED, selftest-needed: `selftest-needed: 608 passed, 13 failed` (621
executed, as C-2 predicts). The 13 are exactly the predicted ones - 6 gamma,
6 delta, 1 reason line - and every one fails because `shipped-docs` is not
selected. Representative, verbatim:

```
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stdout is exactly the pinned list
         expected: gamma
         grep-count
         shipped-docs
         sigpipe
         actual:   gamma
         grep-count
         sigpipe
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stdout has exactly 4 line(s)
         expected: 4
         actual:   3
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stderr's first line is exactly the pinned header
         expected: selftest-needed: suites — 4 of 9 selected from 1 harness path(s) changed against main (merge-base d292bdf)
         actual:   selftest-needed: suites — 3 of 9 selected from 1 harness path(s) changed against main (merge-base d292bdf)
    FAIL HARNESS-107 AC-1: stderr names shipped-docs' path and the pattern that matched: (scans .claude/tests/*.sh)
         expected: 1
         actual:   0
```

All 13 FAIL lines, and the summary:

```
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stdout is exactly the pinned list
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stdout has exactly 4 line(s)
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from root]: stderr's first line is exactly the pinned header
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from subdir]: stdout is exactly the pinned list
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from subdir]: stdout has exactly 4 line(s)
    FAIL an edited .claude/tests/gamma.test.sh, mentioned by no suite, prints gamma (and the *.sh scanners, shipped-docs among them) [from subdir]: stderr's first line is exactly the pinned header
    FAIL HARNESS-107 AC-1: stderr names shipped-docs' path and the pattern that matched: (scans .claude/tests/*.sh)
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from root]: stdout is exactly the pinned list
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from root]: stdout has exactly 4 line(s)
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from root]: stderr's first line is exactly the pinned header
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from subdir]: stdout is exactly the pinned list
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from subdir]: stdout has exactly 4 line(s)
    FAIL a NEW untracked .claude/tests/delta.test.sh prints delta and the *.sh scanners, shipped-docs among them, and the count of suites is the tree's (10) [from subdir]: stderr's first line is exactly the pinned header
selftest-needed: 608 passed, 13 failed
FAIL selftest-needed  did 608 units of work, below the floor of 620 in .claude/tests/floors.conf
```

Why it is the right failure: every red assertion is a missing `shipped-docs`
in the output and nothing else in the suite moved; the four AC-2 controls
(`:647`, `:652`, `:793`, and the deleted-gamma case after `:859`) pass.

#### What the tests pin (the "export shape" of a bash change)

No module is imported. The one production surface pinned is the output of
`bash scripts/selftest-needed.sh --suites`. For a fixture branch changing one
top-level `.claude/tests/<x>.test.sh`: stdout gains `shipped-docs` in sorted
position; the header count rises by one; stderr gains exactly one reason line
matched by `reason_lines shipped-docs <path> 'scans .claude/tests/*.sh'` -
the existing reason-line format for an `add` row, with the row's pattern as
its text. For the AC-2 paths stdout stays `all` and stderr stays
byte-identical. C-1 gives the exact row. The tests do not constrain the row's
position in `SCANS` or the evidence comment's wording (C-1 does: above the
`map` row, so that DV-1 deletes it as one line), and they do not pin the
over-selection of `.claude/tests/fixtures/**/*.sh`.

#### Floors (C-5, for GREEN)

The floor check counts **passed** assertions ("did N units of work"), so the
RED runs show a floor FAIL wherever an assertion failed; that follows from
the red and is not a separate defect. Executed counts measured on this host:
`boundaries` 687, `selftest-needed` 621, `shipped-docs` 18 - as C-5 predicts.
GREEN raises `boundaries` 686 -> 687 and `selftest-needed` 620 -> 621 in both
`floors.conf` and `selftest.test.sh`'s `COUNTS`; `shipped-docs` stays 18.
RED added exactly the two assertions the Contract names and dropped none.

#### `--suites` for this diff (C-8)

    selftest-needed: suites — 5 of 34 selected from 3 harness path(s) changed against origin/main (merge-base 2934b16)
      boundaries       .claude/tests/boundaries.test.sh (itself)
      grep-count       .claude/tests/boundaries.test.sh (scans *.sh)
      selftest-needed  .claude/tests/selftest-needed.test.sh (itself)
      shipped-docs     .claude/tests/shipped-docs.test.sh (itself)
      sigpipe          .claude/tests/boundaries.test.sh (scans *.sh)

Not `all`. `shipped-docs` is selected only as "itself": the changes to
`boundaries.test.sh` and `selftest-needed.test.sh` do not select it yet,
which is this story's bug seen on its own diff; after C-1 they should.
`check-sigpipe.sh` (62 files, 0 findings) and `check-grep-count.sh` (62
files, 0 findings) are clean.

#### Negative controls and deferred verifications

These suites do not fail at import: every assertion above executed, and the
AC-2 controls and the real-tree assertion were observed passing. What RED
cannot observe is the three Deferred verifications, which mutate the fixed
tree. **I did not run DV-1, DV-2 or DV-3, and I decline all three as
GATES-owned**, as the story assigns them: DV-1's row does not exist in RED,
and DV-2 and DV-3 are to run once on the committed tree with the row in.
What I did check, outside the framework, is that each expression still hits
the files as built and that the pattern behaves as the story predicts:

| DV | Expression and target | Lines changed (plain `sed` on a scratch copy) | Expected at GATES | Measured outside the framework (Git Bash awk, the suite's own awk program) |
|---|---|---|---|---|
| DV-1 | `/^shipped-docs add /d` on `scripts/selftest-needed.sh` | 0 in RED (the row is GREEN's); must be 1 after C-1 | `selftest-needed`: exactly **13 failed**, the 13 above; AC-2 cases pass | the unfixed tree is the RED run above: 13 failed, the same list |
| DV-2 | `selftest-needed.test.sh` line 872 -> `CM="$(ls $REPO_ROOT/docs)"` | 1 (`872c872`) | `shipped-docs`: exactly **1 failed**, the real-tree assertion, actual `.claude/tests/selftest-needed.test.sh:872` | new `SDR_RE` over the mutated copy reports `:872`; the old pattern reports nothing |
| DV-3 | `shipped-docs.test.sh` line 192, tail -> `.` | 1 (`192c192`) | `shipped-docs`: exactly **2 failed** - the fixture assertion (the 8 expected lines plus `a.test.sh:12`, `:13`, `:14`, `:15`) and the twin (those 4 lines) | loosened tail over the 15-line fixture: 3 4 5 8 9 10 11 12 13 14 15 (paused dispatch); over the real tree's 36 `.claude/tests/*.sh`: nothing (this dispatch) |

These numbers are claims until GATES runs the three `mutate.sh` commands as
written in `## Deferred verifications`. The expressions need no restatement
against the files as built; only DV-2's prose line number is now 872, not 868.

The twin (`shipped-docs.test.sh:397`) passed on arrival in both steps, as C-3
says it must; DV-3 is what earns it, and DV-3 belongs to GATES.

#### Timings

All local, on this host; none from CI. boundaries step 1 took about
2 h 45 min wall time (pid 95961, 14:52 to about 17:38 CST, ~30 other test
runs on the host when it started); step 2 took 2271 s with no other run on
the host. selftest-needed 376 s; shipped-docs 19-28 s. These suites carry no
timeouts.

#### For GREEN

Nothing found changes the approach. C-1's row is the whole production
change; C-5's floors are 687 / 621 / 18 as predicted.

### GREEN complete (2026-11-14 UTC, feature-developer, model `opus` as declared; no override)

#### Files changed (uncommitted)

- `scripts/selftest-needed.sh` - C-1: `shipped-docs add .claude/tests/*.sh`
  inserted directly above the `shipped-docs map` row (column 0, single
  spaces, as C-1 pins); the `shipped-docs` evidence entry in the comment
  above `SCANS` gains the `add` row: `suite_docs_reads` scans every
  top-level `.claude/tests/*.sh` (HARNESS-106, HARNESS-107), and the pattern
  also matching a subdirectory `.sh` is harmless because an `add` row never
  maps a path. Header (34-70) untouched.
- `.claude/tests/floors.conf` - `boundaries 686 -> 687` (line 40),
  `selftest-needed 620 -> 621` (line 64), `shipped-docs` unchanged at 18;
  dated HARNESS-107 entry appended at the end in the HARNESS-106 form.
- `.claude/tests/selftest.test.sh` - `COUNTS` only: `boundaries 687` (531),
  `selftest-needed 621` (556). Classifies `harness`, writable in GREEN; no
  assertion touched.
- `.claude/harness/VERSION` - line 34 `125 (2026-11-13)` -> `126 (2026-11-14)`.
  The date is the UTC date, as the dispatch specified; the host's local
  (CST) calendar date at the time was still 2026-11-13. Correct it at GATES
  if the house convention is local time.

#### Runs, one at a time, each `status: ok` on tree `6bfba7c9`

| Command | exit | duration | `last:` | log |
|---|---|---|---|---|
| `bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed` | 0 | 249 s | `1 harness suite(s) passed.` | `.claude/state/attest-logs/20261114T003241Z.214.log` |
| `bash scripts/attest.sh -- bash scripts/selftest.sh selftest` | 0 | 176 s | `1 harness suite(s) passed.` | `.claude/state/attest-logs/20261114T003804Z.12751.log` |
| `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs` | 0 | 14 s | `1 harness suite(s) passed.` | `.claude/state/attest-logs/20261114T004109Z.18119.log` |
| `bash scripts/attest.sh -- bash scripts/gates.sh --fast` | 0 | 1 s | `All required gates passed (0 ran, 5 unconfigured, 0 known).` | `.claude/state/attest-logs/20261114T004129Z.18762.log` |
| `bash scripts/attest.sh -- bash scripts/selftest.sh boundaries` | 0 | 1878 s | `1 harness suite(s) passed.` | `.claude/state/attest-logs/20261114T004136Z.18915.log` |

Measured: `selftest-needed: 621 passed, 0 failed` (floor 621 met),
`shipped-docs: 18 passed, 0 failed` (18), `boundaries: 687 passed, 0 failed`
(687). The three suites ran as separate commands, not C-8's combined one.
`check-sigpipe.sh` (62 files, 0 findings) and `check-grep-count.sh` (62
files, 0 findings) clean.

`bash scripts/selftest-needed.sh --suites` on this diff now selects
`shipped-docs` by the new row - `shipped-docs .claude/tests/boundaries.test.sh
(scans .claude/tests/*.sh)` - where at RED it was selected only as "itself";
14 of 34 suites, not `all`.

#### Negative controls (DVs not run; GATES owns them)

- DV-1: `sed '/^shipped-docs add /d'` over a copy of the shipped script
  changes exactly one line (`185d184`), and the result differs from
  `HEAD`'s script only in the 7 comment lines, so the table is the RED
  table and RED's measured 13 failures remain the expected value.
- DV-2 and DV-3 target test files GREEN did not touch; line 872 and line
  192 stand as RED recorded.

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

## Diff review

**Review 1** - 2026-11-13, fresh `lead-po` on the DIFF-REVIEW row, planned
`fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override was reported to
this dispatch. Reviewed `git diff origin/main...HEAD` at `f8ca452` (merge-base
`2934b16`), and the code connected to it: the whole `--suites` branch of
`scripts/selftest-needed.sh` (the `SCANS` loop, the per-path rules, the
selection awk), `suite_docs_files` / `suite_docs_reads` and their fixture in
`.claude/tests/shipped-docs.test.sh`, every `mktemp` and `trap` in
`.claude/tests/boundaries.test.sh`, and the prose that describes `--suites`
(`.claude/commands/advance-story.md:308`, `CLAUDE.md`).

What this change does: When a top-level `.claude/tests/*.sh` changes, the
changed-suites self-test now also runs `shipped-docs`, the suite whose rule
scans those files for reads of the project's own `docs/`. That rule's pattern
now sees three more spellings of such a read and still ignores names that only
start with `docs`. The `boundaries` suite's exit trap now removes all four temp
paths it makes, and the floors and the release number follow.

Load assumed: none stated beyond one developer machine and one CI runner; the
change adds one 18-assertion suite to some `--changed` runs.

What I checked, beyond reading: `bash scripts/selftest-needed.sh --suites` on
this branch prints 14 of 34, `shipped-docs` among them with the reason
`.claude/tests/boundaries.test.sh (scans .claude/tests/*.sh)`, and not `all`.
The new row is `add`, so the loop leaves `hit` alone and the two "mapped by no
rule" controls keep their meaning. The first-record-per-suite awk prints
`shipped-docs` once when both rows match in one run. `KB`, `K_NS_COPY` and
`K_DECOY` are each assigned once (3907, 4093, 4225), there is no other `mktemp`
and no later `trap` in the file, so the trap names every temp path. "The five
tree-scanning suites" in `advance-story.md` is still five. The pattern, run by
hand over lines of my own: `ls $REPO_ROOT/docs*`, `x=$REPO_ROOT/docs$y` and
`"$TESTS_DIR/../..//docs/a"` are reported; the misses are finding 1.

**Nice to have:**

1. **The rule's written limit no longer lists the direct spellings it still misses** (`.claude/tests/shipped-docs.test.sh:181-183`)
   - **What this is:** The comment above `SDR_RE` that tells a reader what the docs-read rule cannot see.
   - **Problem:** It names only data-flow cases. Measured with the pattern as
     built, these one-line reads are also not reported:
     `rm -rf "${REPO_ROOT:?}/docs/x"`, `cat "$REPO_ROOT/./docs/a"` and
     `cat "$REPO_ROOT"/"docs"/a`. The story's `## Out of scope` says other
     expansions stay a limit; the suite's own comment does not.
   - **Fix:** One sentence added to the "Written limit" comment in
     `.claude/tests/shipped-docs.test.sh`, naming an expansion other than
     `%/`, a `/./` and a separately quoted `docs`. No pattern change, no
     assertion change. None of the three occurs in the tree today.
   - **If we skip it:** A later author reads the comment as "every direct
     spelling is caught" and a suite line with `${REPO_ROOT:?}/docs/...`
     passes the rule, then fails in a consumer.
   - **Route:** RED

2. **The floors comment dates GREEN a day later than the release line** (`.claude/tests/floors.conf:1210-1211`)
   - **What this is:** The dated note that records why two floors were raised.
   - **Problem:** It says `GREEN (2026-11-14)`, the UTC date. `VERSION` says
     `126 (2026-11-13)`, the local calendar date the contract (C-5) asks
     for, and the host's clock still reads 2026-11-13. The same change
     carries two dates.
   - **Fix:** `2026-11-14` becomes `2026-11-13` in that one comment line of
     `.claude/tests/floors.conf`. Nothing reads the date.
   - **If we skip it:** Someone matching a floor raise to a release finds the
     dates disagree and has to work out that one is UTC.
   - **Route:** GATES

Not checked: no suite was run by this review (one full run at a time on this
host); the 621/18/687 counts and DV-1..DV-3 are taken from the attested record
and the pasted output. The gate record names commit `5de62a0` while HEAD is
`f8ca452`; whether the stamp still matches is `check-boundaries.sh`'s to say.
`trap -p` and the awk pattern on the CI runner are unmeasured, as `## Notes`
already says.

Verdict: Ship.

**Orchestrator's disposition:** the verdict is Ship. Finding 2 (Route GATES) is taken: the floors comment now says 2026-11-13, matching VERSION. Finding 1 (Route RED) is not taken into this story: it is one comment sentence in a frozen test file and the story's Out of scope already accepts these spellings as limits; it is offered as a follow-up.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-14T01:21:58Z
    commit: f8ca452 (working tree had uncommitted changes)
    tree:   4b630e9627feb94e453aa11171d2eaee979a641d
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


- 2026-11-13 GATES -> REVIEW (orchestrator): `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` run by the orchestrator through `attest.sh`, alone on the host: exit 0, `14 harness suite(s) passed.`, all 14 floors met (3103 assertions executed, 3103 declared), 2928 s, tree a3031486. CI runs the full self-test on the PR. Follow-up offered, not taken: the diff review's finding 1 (three direct spellings `SDR_RE` misses, to be named in its written limit).
