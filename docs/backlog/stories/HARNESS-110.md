---
id: HARNESS-110
title: The docs-read rule names the direct spellings it does not see
slug: the-docs-read-rule-names-the-direct-spel
epic: 
type: fix
status: in-progress
phase: GATES
branch: story/HARNESS-110-the-docs-read-rule-names-the-direct-spel
depends_on: [HARNESS-109]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/shipped-docs.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the shipped-docs suite under its selftest floor, which CI runs in full on the PR
---

## Context

No epic, as HARNESS-106, HARNESS-107 and HARNESS-109, whose rule this story
documents. Line numbers below are `origin/main` at `51239f3`; HARNESS-109
moves them (see "Depends on HARNESS-109").

**Where it comes from.** HARNESS-107's diff review, Nice-to-have finding 1
(`bash scripts/story.sh section HARNESS-107 'Diff review'`), routed RED and
not taken into that story.

**The defect.** `.claude/tests/shipped-docs.test.sh` holds the rule
`suite_docs_reads` (comment 156-191, pattern `SDR_RE` 192): no upstream suite
line may read under the real checkout's `docs/`. The comment's "Written
limit" paragraph (183-185) tells a reader what the rule cannot see, and names
only data-flow cases: a path built in a variable first, a `cd` followed by a
relative path, and `git -C ... show HEAD:docs/...`. A reader takes from that
that every *direct* spelling, root and `docs` on one line, is caught. It is
not. Measured at PLANNED (2026-11-14, Git Bash, the pattern of line 192 run
by `awk` over lines of my own):

| Line | `SDR_RE` at `51239f3` |
|---|---|
| `cat "$REPO_ROOT/docs/a"` | seen |
| `rm -rf "${REPO_ROOT:?}/docs/x"` | not seen |
| `cat "$REPO_ROOT/./docs/a"` | not seen |
| `cat "$REPO_ROOT"/"docs"/a` | not seen |

So the comment is wrong by omission, and nothing in the suite says what the
rule does with these three lines: a later change to the pattern could start
or stop seeing them with every assertion still green.

**The fix, and the decision behind it (D-1 in the Contract).** The pattern is
not widened. The "Written limit" paragraph names the three spellings, and one
new assertion pins the limit as behaviour: over a fixture holding the three
lines and one plain read, the rule reports the plain read and only it. The
suite already asserts a written limit this way (its AC-5(d), "a path under a
written directory is covered whatever its basename: the limit", comment at
line 29).

**The gate that would fail if this broke.** `bash scripts/gates.sh --list`
shows every gate `<unconfigured>` in this repository (checked at PLANNED), so
no gate, required or optional, exercises this and `required_gates` stays
empty, as in HARNESS-106, HARNESS-107 and HARNESS-109. The artifact is judged
by the `shipped-docs` self-test suite under its floor in
`.claude/tests/floors.conf`, which `selftest.sh --changed` runs locally at
GATES and CI runs in full on the PR, and by `check-boundaries.sh` (the
`VERSION` bump, the deferred verification's pasted result).

**Depends on HARNESS-109.** HARNESS-109 (phase RED on 2026-11-14, main
checkout) writes the same four files. Its Contract C-2 adds a sentence to the
same "Written limit" paragraph, narrows the sentence "no file is exempted by
name" in the same comment, and its C-3 adds a `describe` block before
`summary "shipped-docs"`, which is where this story's block goes too. This
story builds on that text and on the count HARNESS-109 leaves (18 becomes
21), so the order is real and `depends_on` carries it. HARNESS-109 does not
edit `SDR_RE` or `suite_docs_reads`; its `suite_docs_files` leaves out only
`project-*.test.sh`, which this story's fixture file is not.

## Acceptance criteria

- **AC-1** — Given a tree whose `.claude/tests/` holds one file, `b.test.sh`,
  with these five lines in this order: `#!/usr/bin/env bash`,
  `rm -rf "${REPO_ROOT:?}/docs/x"`, `cat "$REPO_ROOT/./docs/a"`,
  `cat "$REPO_ROOT"/"docs"/a`, `cat "$REPO_ROOT/docs/a"`; when the
  `shipped-docs` suite's rule `suite_docs_reads` runs over that tree, then it
  prints exactly one line, `.claude/tests/b.test.sh:5`. The plain read is
  reported, so the rule is live on that file; the three spellings of the
  written limit are not.
  *Control:* with `SDR_RE` changed so that a `:?` expansion of the root is
  admitted, the same run must print `.claude/tests/b.test.sh:2` as well, and
  the assertion must fail (DV-1). The criterion pins what the rule does
  today; it is not a claim that missing these lines is desirable.
- **AC-2** — Given this repository's own tree, when the `shipped-docs` suite
  runs, then every assertion the suite holds before this story is unchanged
  and still passes, the rule still reports nothing over the real tree, and
  the suite's passed count is exactly one higher than before this story.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `.claude/tests/shipped-docs.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Everything below is pinned against `origin/main` at `51239f3`. RED re-reads
lines 156-212 and the end of `.claude/tests/shipped-docs.test.sh` after
HARNESS-109 has merged, before writing anything, and amends C-2 and C-3 in
place where the text moved.** What is expected to have moved is listed in
C-2 and C-3.

**D-1. PO decision: name the limit and pin it; do not widen the pattern.**
Returned to the orchestrator to report to the user before GREEN. The two
options weighed:

**Approved by the user, 2026-11-14:** "Yes, name them" - D-1 as written (name the three spellings in the limit and pin them with one assertion; the pattern is not widened, not even for `${REPO_ROOT:?}` alone).

- *(b) Widen `SDR_RE`* to see some or all of the three, as HARNESS-107 did
  for three earlier spellings. Measured at PLANNED: one candidate,
  `(%/|:[?][^}]*)?[}"]*/+([.]/+)*["']?docs`, sees all three and adds no
  false positive on ten lines of my own. Rejected, for three reasons. (1) No
  line of the tree uses any of them: of 187 references to the two root names
  in `.claude/tests/*.sh`, none has an expansion operator after the name,
  none a `/./`, none a quote between the root's slash and `docs`. (2) The
  family is open. The same measurement found five more direct spellings that
  the *widened* pattern or the current one still misses or would need its
  own arm: `"${REPO_ROOT:-/x}/docs/a"`, `"${REPO_ROOT%%/}/docs/a"`,
  `"${REPO_ROOT/#x/y}/docs/a"`, `"$REPO_ROOT/"docs/a`, `$REPO_ROOT/'docs'/a`.
  HARNESS-107 widened for three and its review found three more; a second
  round buys a third. (3) Each arm owes a fixture line, negatives and a probe
  against a real line of the tree (`rules.md`, the non-negotiable on rules
  over the tree, and "Mutation work per story"), for a line nobody has
  written. The rule is a text heuristic for the spellings people use; what
  keeps it honest is a limit that is written and true.
- *(a) Name them in the limit.* Chosen, with one addition to the review's
  suggested fix: the limit is also asserted (C-3). A comment alone has no
  behaviour, so nothing can fail when it goes stale, in either direction: the
  pattern could later be widened and the comment left saying "not seen", or
  loosened and nobody told. The assertion ties the pattern to the statement.
  A later story that widens the pattern meets a red assertion, moves the line
  from this fixture to the reads fixture and corrects the comment.

*How the law applies to a comment.* "A test that has never been observed to
fail is not a test" is about assertions; a comment asserts nothing and owes
no failure. What it owes is being true, and that is what C-3's assertion
checks. That assertion is written against code that already exists and
passes on its first run, so it is the case `rules.md` names: it is earned by
one mutation of the behaviour it pins (DV-1).

*No assertion pins the comment's wording, and none is to be added.* Checked
at PLANNED: no assertion in `.claude/tests/` reads the "Written limit"
paragraph. An assertion on comment text would be a needle on wording, would
pass over a comment that is present and false, and would have to spell the
root names beside `/docs` in the one file that scans itself. The comment's
content is checked once, by the diff review against C-2.

**C-0. Who writes which.** All four paths classify as `harness`
(`bash scripts/classify.sh <path>`, checked at PLANNED), so the phase lock
divides nothing and this block does.

- **RED (test-developer):** `.claude/tests/shipped-docs.test.sh` only: the
  comment sentence (C-2) and the fixture and assertion (C-3). One step, not
  two: there is no unfixed state in which the assertion fails, and RED says
  so in the handoff instead of contriving one.
- **GREEN (feature-developer):** the floor records in
  `.claude/tests/floors.conf` and `.claude/tests/selftest.test.sh`, and
  `.claude/harness/VERSION` (C-4). GREEN touches no line of
  `shipped-docs.test.sh`.

**C-1. `SDR_RE`, `suite_docs_reads` and `suite_docs_files` are not edited.**
Not the pattern (192), not either function (193-212). A diff that changes
any of them is outside this story.

*RED amendment, 2026-11-16 (line numbers only).* After HARNESS-109 merged
the pattern is line 199 and the functions 200-221; after this story's comment
lines they are 205 and 206-227. Unchanged, byte for byte.

*RED amendment to C-2, 2026-11-16, re-read on the merged tree (`082e171`).*
Reason: HARNESS-109 moved the paragraph and added to it, as the block below
foresaw. On the merged tree the "Written limit" paragraph is lines 187-191:
the three data-flow lines quoted below (187-189), then HARNESS-109's two
lines "And it trusts the name: an upstream suite named project-*.test.sh
would escape it, and nothing checks that upstream ships none (HARNESS-109,
C-1)." (190-191), which is now the paragraph's last sentence. The new
sentence goes after it, as lines 192-197, inside the same paragraph (no
blank comment line between). One wording change, within the latitude below:
the last line ends "(HARNESS-110, D-1)." to match the story-id citation
HARNESS-109's sentence ends with. Everything else is the text below, verbatim.
The "no file is exempted by name" paragraph HARNESS-109 narrowed is now
lines 199-203 ("no upstream file is exempted by name, this suite included")
and is not touched. Measured: none of the 464 lines of the edited suite,
comments included, matches `SDR_RE` (the pattern of line 205 run by `awk`
over the whole file printed nothing).

**C-2. The comment (the "Written limit" paragraph, 183-185).** At `51239f3`
it reads:

    # Written limit: the rule reads text, not data flow. A path built in a variable
    # first (d="$REPO_ROOT", then "$d/docs/..."), a cd "$REPO_ROOT" followed by a
    # relative docs/..., and git -C "$REPO_ROOT" show HEAD:docs/... are not seen.

Nothing in it is removed or reworded. This is appended to the same
paragraph, after its last sentence (after HARNESS-109's "the rule trusts the
name" sentence if that is now the last):

    # Nor is every direct spelling seen. Three are not: an expansion of the root
    # other than `%/` ("${REPO_ROOT:?}/docs/x"), a `/./` between the root and
    # docs ("$REPO_ROOT/./docs/a"), and a docs quoted on its own
    # ("$REPO_ROOT"/"docs"/a). None occurs in the tree. The assertion headed
    # HARNESS-110 below pins all three, so widening the pattern means moving its
    # line and correcting this sentence.

Wording may be adjusted by RED to fit what HARNESS-109 left, provided it
still names the three spellings by example, says none occurs in the tree and
points at the assertion. Every line of it is a whole-line comment, which the
rule skips, and none of the three spellings matches `SDR_RE` in any case, so
writing the root names in full here does not make this suite report itself;
the real-tree assertion (354-355) is the check.

The sentence "nothing else may follow the `%`" (172-173) stays as it is: it
is true, and the new sentence is what says where that leaves `:?`.

*RED amendment to C-3, 2026-11-16, re-read on the merged tree (`082e171`).*
Reason: line numbers moved, nothing else. HARNESS-109's block `a project's
own suites are not scanned (HARNESS-109)` is the last before `summary` (416-
436 after this story's comment lines), so the new block follows it as
444-462, with `summary "shipped-docs"` at 464. `$SDR_R` is defined at line
380 (374 before the comment lines; 365 at `51239f3`). The real-tree assertion
cited in C-2 is 369-370 (363-364 before; 354-355 at `51239f3`). The fixture
root is `$WORK/suite-limit` in variable `q` (`g` and `p` are taken by the
two blocks above it). The count N on the merged tree, measured before any
edit: `shipped-docs: 21 passed, 0 failed`, so N+1 = 22; the floor in
`floors.conf` line 67 (66 at `51239f3`) is 21.

**C-3. The fixture and the one assertion (AC-1).** A new `describe` block,
the last before `summary "shipped-docs"` (so after HARNESS-109's block
`a project's own suites are not scanned (HARNESS-109)`), titled
`the written limit: direct spellings the rule does not see (HARNESS-110)`.
It reuses `$SDR_R` from the HARNESS-106 block (line 365), so the root name
is spelled in pieces in this suite's own source.

The fixture root is a new directory under `$WORK` (`$WORK/suite-limit`)
holding `.claude/tests/b.test.sh`, exactly these five lines:

| Line | Text as the fixture file holds it | Rule |
|---|---|---|
| 1 | `#!/usr/bin/env bash` | not a read |
| 2 | `rm -rf "${REPO_ROOT:?}/docs/x"` | limit: not seen |
| 3 | `cat "$REPO_ROOT/./docs/a"` | limit: not seen |
| 4 | `cat "$REPO_ROOT"/"docs"/a` | limit: not seen |
| 5 | `cat "$REPO_ROOT/docs/a"` | seen |

Written as the block above writes its fixture, one `printf '%s\n'` per line,
for example `printf '%s\n' "rm -rf \"\${$SDR_R:?}/docs/x\""`.

One `assert_eq` on the whole output of `suite_docs_reads` over that root.
Expected, exactly: `.claude/tests/b.test.sh:5`. Its name starts
`HARNESS-110 AC-1:` and says in words that an expansion other than `%/`, a
`/./` and a separately quoted docs are the written limit and are not
reported, while the plain read beside them is.

Line 5 is why this is one assertion and not an "expects nothing" one: an
empty expectation is also what a rule that scanned nothing would give. With
line 5 the same output shows the file was scanned and the rule fired.

The file name is not `project-*.test.sh`, so HARNESS-109's exclusion does
not apply to it.

Measured at PLANNED (the pattern of line 192 run by `awk` over these five
lines). **Settled: read it out.**

| | Lines reported |
|---|---|
| `SDR_RE` at `51239f3` | 5 |
| `SDR_RE` with `(%/)?` replaced by `(%/|:[?])?` (DV-1's mutation) | 2, 5 |

*RED's run.* `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs`.
Expected: `shipped-docs: <N+1> passed, 0 failed`, where N is the count on
`main` when RED starts (18 at `51239f3`; 21 once HARNESS-109 has merged, so
22). The new assertion **passes on arrival**. The handoff says so in those
words, names DV-1 as what earns it, and does not claim a watched failure.
The suite stays above its recorded floor of N, so nothing is red at the end
of RED.

**C-4. Floors and the release (GREEN).**

- `.claude/tests/floors.conf`: the line `floor | shipped-docs  | <N>`
  (line 66 at `51239f3`, value 18) becomes `<N+1>`, the count GREEN measures
  passing, and the dated history comment at the end of the file gains a
  paragraph in the form of the HARNESS-107 one (1210-1217): story id, phase
  and local calendar date, the measured line `shipped-docs: <N+1> passed,
  0 failed`, and "+1 (the HARNESS-110 written-limit assertion)".
- `.claude/tests/selftest.test.sh`: the `COUNTS` entry `shipped-docs <N>`
  (line 558 at `51239f3`) becomes `shipped-docs <N+1>`.
- `.claude/harness/VERSION`: the next release number after whatever `main`
  holds when GREEN runs, with that day's local calendar date in brackets.
  It is 126 at `51239f3`; HARNESS-108 and HARNESS-109 each take one before
  this story, so the number is not pinned here. `check-boundaries.sh`
  refuses a harness change without the bump.

**Callers.** No export changes signature. `SDR_RE`, `suite_docs_files` and
`suite_docs_reads` are defined and used only in
`.claude/tests/shipped-docs.test.sh` (grep at PLANNED), and none is edited.

**Oracle partition.** AC-1 is **settled**: the expected output is the
measured table in C-3, read out, not derived. AC-2 is **mechanical**: the
count is N+1 and no existing assertion's text changes.

**Test-only dependencies.** None.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". One entry. It is both
the mutation that earns the assertion written against existing code and the
one for the story's central claim, which is that the suite now says what the
rule does with these spellings.

- **DV-1, the limit assertion can fail (AC-1).** With `SDR_RE`'s `(%/)?`
  replaced by `(%/|:[?])?`, so that `${REPO_ROOT:?}` is admitted as the root,
  `mutate.sh` must report 1 line changed, and `shipped-docs` **must** report
  exactly 1 failed: the `HARNESS-110 AC-1` assertion, its actual value the
  two lines `.claude/tests/b.test.sh:2` and `.claude/tests/b.test.sh:5`.
  Every other assertion still passes: no line of the real tree and no other
  fixture line has `:?` after a root name (measured at PLANNED: 0 of 187
  references). The mutated file is the suite itself, which holds the rule;
  `(%/)?` occurs on one line of it (192 at `51239f3`). RED cannot earn the
  assertion by watching it fail, because it passes on its first run; RED
  could run this mutation, but one run at GATES covers the story as
  committed. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#(%/)?#(%/|:[?])?#' -- bash scripts/selftest.sh shipped-docs

  **Result, GATES, 2026-11-16 (orchestrator, this worktree, at b1218a3):**
  as predicted. One line changed, exactly the AC-1 assertion went red with
  the two predicted lines, every other assertion passed, and the file was
  restored byte-for-byte. The floor line is the expected consequence of one
  failed assertion against a floor of 22, not a second defect.
  `mutate.sh --check` afterwards: clean.

  ```
  === mutate: .claude/tests/shipped-docs.test.sh (1 line(s) changed by /^SDR_RE=/s#(%/)?#(%/|:[?])?#) ===
    205 - SDR_RE='(REPO''_ROOT|TESTS''_DIR/[.][.]/[.][.])(%/)?[}"]*/+docs([^A-Za-z0-9_.-]|$)'
    205 + SDR_RE='(REPO''_ROOT|TESTS''_DIR/[.][.]/[.][.])(%/|:[?])?[}"]*/+docs([^A-Za-z0-9_.-]|$)'
  === mutate: running bash scripts/selftest.sh shipped-docs ===
      FAIL HARNESS-110 AC-1: the written limit: an expansion of the root other than %/, a /./ before docs and a separately quoted docs are not reported, while the plain read beside them in the same file is
           expected: .claude/tests/b.test.sh:5
           actual:   .claude/tests/b.test.sh:2
           .claude/tests/b.test.sh:5
  shipped-docs: 21 passed, 1 failed
  FAIL shipped-docs  did 21 units of work, below the floor of 22 in .claude/tests/floors.conf
  1 of 1 harness suite(s) FAILED.
  === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/loving-elbakyan-3fe420/.claude/state/mutations/.claude_tests_shipped-docs.test.sh.20261116T175548Z.1388233.bak) ===
  ```

Not owed, and stated so that nobody adds one: a probe against a real line of
the tree (the rule over the tree is not changed by this story; HARNESS-107's
DV-2 and HARNESS-109's DV-2 hold that evidence for the pattern and the file
list as they stand); a mutation per limit spelling (lines 3 and 4 are pinned
by the same whole-output comparison, and earning each is `/audit-mutations`
work); and anything for the comment, which has no behaviour.

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

Planned by `bash scripts/plan.sh write HARNESS-110` from `.claude/harness/models.conf`.
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
- RED, `test-developer`, declared `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override.
- GREEN, `feature-developer`, declared `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override. Orchestrator's `attest.sh check` on both records (selftest shipped-docs selftest; gates --fast): `fresh`, exit 0, not re-run.
- GATES, `feature-developer`, declared `opus`, resolved Opus 5.5 (`claude-opus-5-5`); no override. Ran `bash scripts/gates.sh` once; orchestrator's `attest.sh check`: `fresh`, exit 0, verdict `All required gates passed (0 ran, 7 unconfigured, 0 known).` DV-1 was run by the orchestrator before it.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Widening `SDR_RE` to see any of the three spellings, or any other direct
  spelling (D-1 lists five more that were measured). If one ever appears in
  a suite, that is the story that widens the pattern, with that real line as
  its probe.
- Any edit to `suite_docs_reads` or `suite_docs_files`.
- Listing every direct spelling the rule misses. The comment names three by
  example and says the rule reads text; it is not an inventory.
- An assertion on the comment's wording (D-1).
- A check that no suite uses a `:?` expansion, a `/./` or a split quote
  after a root name. Measured once at PLANNED (none of 187); not enforced.
- Data-flow reads (a variable, a `cd`, `git -C`): already the written limit,
  unchanged.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One suite, `.claude/tests/shipped-docs.test.sh`, at the level the rule lives:
the rule is a shell function in that suite, so it is called directly over a
fixture tree under `$WORK`. One new assertion; no other line of the suite's
code changes.

| AC | Test | Where |
|---|---|---|
| AC-1 (settled) | `HARNESS-110 AC-1: the written limit: an expansion of the root other than %/, a /./ before docs and a separately quoted docs are not reported, while the plain read beside them in the same file is` - one `assert_eq` of the whole output of `suite_docs_reads "$WORK/suite-limit"` against exactly `.claude/tests/b.test.sh:5`, over the five-line fixture of the AC | `.claude/tests/shipped-docs.test.sh:444-462` (fixture 453-460, assertion 461-462) |
| AC-1, the written statement | the "Written limit" paragraph names the three spellings (no assertion, by D-1; checked by diff review against C-2) | `.claude/tests/shipped-docs.test.sh:192-197` |
| AC-2 (mechanical) | every prior assertion untouched (the diff adds lines only: 6 comment lines, one block); the real-tree assertion `HARNESS-106 AC-3: suite_docs_reads over the real tree prints nothing` still passes with the new comment and fixture code in the scanned file; count 21 -> 22 | `.claude/tests/shipped-docs.test.sh:369-370`; the run below |

Level choice: unit over the rule's function is the cheapest level that can
falsify AC-1, and the whole-output comparison (not "expects nothing") is what
makes it falsifiable: line 5 shows the file was scanned and the rule fired,
so a rule that scanned nothing fails it too. AC-1's control is DV-1, owned by
GATES.

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

**RED, 2026-11-16, test-developer dispatch.** Declared `model: opus` in
`.claude/agents/test-developer.md`; dispatched with no override reported to
me; ran as Opus 5.5 (`claude-opus-5-5`). The orchestrator records the
resolved model.

**What changed.** `.claude/tests/shipped-docs.test.sh` only, lines added,
none removed or edited (`git diff --stat`: 26 insertions, 0 deletions):

- lines 192-197: six whole-line comment lines appended to the "Written limit"
  paragraph, after HARNESS-109's "And it trusts the name" sentence (C-2 as
  amended above);
- lines 444-462: the new last `describe` block, `the written limit: direct
  spellings the rule does not see (HARNESS-110)`, a fixture
  `$WORK/suite-limit/.claude/tests/b.test.sh` of exactly the AC's five lines,
  written one `printf '%s\n'` per line with the root spelled as `$SDR_R`, and
  one `assert_eq` (C-3 as amended above).

`SDR_RE` (205), `suite_docs_files` (206-213) and `suite_docs_reads` (214-227)
are byte-identical to the merged tree (C-1). The story file: this section,
`## Test plan`, and the dated RED amendments to C-1 (line numbers), C-2 and
C-3 in `## Contract`.

**The test, one line.** `HARNESS-110 AC-1: the written limit: an expansion of
the root other than %/, a /./ before docs and a separately quoted docs are not
reported, while the plain read beside them in the same file is` - asserts the
whole output of `suite_docs_reads` over the five-line fixture equals exactly
`.claude/tests/b.test.sh:5`. Covers AC-1; its presence and the untouched
rest of the suite cover AC-2.

**It passes on arrival.** It is written against code that already exists, so
there is no unfixed state in which it fails, and none was contrived (C-0). No
watched failure is claimed. What earns it is DV-1, owned by GATES.

**The command and the run (attested, after the edit).**

    bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs

```
run:      2026-11-16T15:27:56Z
command:  bash scripts/selftest.sh shipped-docs
tree:     f8deecc71b0c5908619e5e6852014fa56e8adbdc
after:    f8deecc71b0c5908619e5e6852014fa56e8adbdc
status:   ok
exit:     0
duration: 61s
last:     1 harness suite(s) passed.
log:      .claude/state/attest-logs/20261116T152756Z.1292470.log

  a project's own suites are not scanned (HARNESS-109)

  the written limit: direct spellings the rule does not see (HARNESS-110)

shipped-docs: 22 passed, 0 failed

assertion floors: all 1 suite(s) met their declared floor (22 assertions executed, 21 declared).
1 harness suite(s) passed.
```

Count before the edit, on the merged tree (`082e171` plus the orchestrator's
uncommitted phase change to this story file only), unattested:

```
shipped-docs: 21 passed, 0 failed

assertion floors: all 1 suite(s) met their declared floor (21 assertions executed, 21 declared).
1 harness suite(s) passed.
```

So 21 -> 22, exactly one higher (AC-2). The real-tree assertion (369-370)
is among the 22 passing: the new comment lines and fixture code, in a file
the rule scans, report nothing. At the end of RED the suite executes 22
against a declared floor of 21; that is expected, GREEN raises the floor.

**Fast gates (attested).**

    bash scripts/attest.sh -- bash scripts/gates.sh --fast

```
run:      2026-11-16T15:30:56Z
command:  bash scripts/gates.sh --fast
tree:     f8deecc71b0c5908619e5e6852014fa56e8adbdc
after:    f8deecc71b0c5908619e5e6852014fa56e8adbdc
status:   ok
exit:     0
duration: 4s
last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
log:      .claude/state/attest-logs/20261116T153056Z.1296281.log
```

Every gate is `UNCONFIGURED` in this repository (BOOTSTRAPPED=no), as the
Context says, so the shape check has nothing to judge; the suite above is
the artifact's judge. `bash scripts/check-sigpipe.sh`: `scanned 64 shell
file(s), 58 with pipefail, 0 finding(s)`, exit 0. `bash
scripts/check-grep-count.sh`: `scanned 64 shell file(s), 0 finding(s)`, exit
0. `bash -n` on the suite: exit 0.

**Measured outside the framework (Git Bash, `awk` with the pattern of line
205 with `''` removed, over the fixture as the new code writes it).** The
fixture bytes, via `cat -A`, are exactly the AC's five lines:

```
#!/usr/bin/env bash$
rm -rf "${REPO_ROOT:?}/docs/x"$
cat "$REPO_ROOT/./docs/a"$
cat "$REPO_ROOT"/"docs"/a$
cat "$REPO_ROOT/docs/a"$
```

| Pattern | Lines of `b.test.sh` reported |
|---|---|
| `SDR_RE` as shipped (line 205) | 5 |
| DV-1's mutant, `(%/)?` -> `(%/|:[?])?` | 2, 5 |

Also measured: the shipped pattern over every line of the edited suite,
comments included, matches nothing; DV-1's mutant pattern over every
non-comment line of the real `.claude/tests/*.sh` matches nothing, so under
the mutation no other assertion should move.

**DV-1: expected value, declined in RED as GATES-owned.** I did not run DV-1.
It is owned by GATES and runs against the story as committed. Expected:

| | Expected |
|---|---|
| `mutate.sh` lines changed | 1 (line 205, `SDR_RE=`) |
| `shipped-docs` | 21 passed, 1 failed |
| the failing assertion | `HARNESS-110 AC-1: ...` |
| its actual value | `.claude/tests/b.test.sh:2` and `.claude/tests/b.test.sh:5` |

The sed expression was checked on a scratch copy of the merged and edited
suite, without `mutate.sh`: `sed '/^SDR_RE=/s#(%/)?#(%/|:[?])?#'` changes
exactly one line, 205, to
`SDR_RE='(REPO''_ROOT|TESTS''_DIR/[.][.]/[.][.])(%/|:[?])?[}"]*/+docs([^A-Za-z0-9_.-]|$)'`.
DV-1's command needs no amendment:

    bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#(%/)?#(%/|:[?])?#' -- bash scripts/selftest.sh shipped-docs

The 21/1 and the actual value are claims until GATES measures them.

**Export shape.** Not applicable as modules: the test calls
`suite_docs_reads <root>` defined in the same file, which prints one
`<file relative to root>:<line>` per reported line, in `suite_docs_files`
order. It also uses `$SDR_R` (line 380) and `$WORK`. GREEN changes none of
these.

**GREEN's exact edits (C-4), and nothing in `shipped-docs.test.sh`.**

1. `.claude/tests/floors.conf` line 67: `floor | shipped-docs  | 21` ->
   `floor | shipped-docs  | 22`, and a dated history paragraph after the
   HARNESS-109 one at the end of the file (1239-...), in its form: story id,
   GREEN, the local date, `shipped-docs: 22 passed, 0 failed`, and "+1 (the
   HARNESS-110 written-limit assertion)".
2. `.claude/tests/selftest.test.sh` line 559: `shipped-docs 21` ->
   `shipped-docs 22`.
3. `.claude/harness/VERSION`: the release after the one `main` holds when
   GREEN runs (`128 (2026-11-15)` here now; HARNESS-108 may take 129 first),
   with GREEN's local date.

Then run, one at a time, checking no other self-test or gates run is going:

    bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs selftest
    bash scripts/attest.sh -- bash scripts/gates.sh --fast

Expected: `shipped-docs: 22 passed, 0 failed` meeting a floor of 22, and
`selftest` green with its COUNTS entry at 22.

**Timings.** The 61 s `shipped-docs` run is a local Windows run on a host with
other sessions' self-tests running alongside or just before; no timeout was
added or changed, and the new block adds one `suite_docs_reads` call over one
five-line file.

**Discovered.** Nothing that changes the approach. One note on the machine
rule: a `ps -ef | grep -E 'selftest\.sh|gates\.sh'` check can match another
session's command line that merely *mentions* `attest.sh check -- bash
scripts/gates.sh` (a check, not a run); I excluded `attest.sh check` lines
when waiting.

### GREEN complete

**GREEN, 2026-11-16, feature-developer dispatch.** Declared `model: opus` in
`.claude/agents/feature-developer.md`; no override reported to me; ran as
Opus 5.5 (`claude-opus-5-5`). The orchestrator records the resolved model.

**Edits (C-4 exactly), nothing in any test file's assertions:**

- `.claude/tests/floors.conf`: line 67 `floor | shipped-docs  | 21` -> `22`,
  and a dated HARNESS-110 history paragraph after the HARNESS-109 one at the
  end of the file.
- `.claude/tests/selftest.test.sh`: COUNTS line 559 `shipped-docs 21` ->
  `shipped-docs 22` (the lock allowed it: `harness`).
- `.claude/harness/VERSION`: `128 (2026-11-15)` -> `129 (2026-11-16)`.

**Runs (attested, one at a time with respect to every other self-test or gates
run on the machine).**

    bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs selftest

```
run:      2026-11-16T17:01:55Z
tree:     5113ac8f5718f2360b31654da214fa354ee68395
status:   ok
exit:     0
duration: 320s
last:     2 harness suite(s) passed.
log:      .claude/state/attest-logs/20261116T170155Z.1371319.log

shipped-docs: 22 passed, 0 failed

assertion floors: all 2 suite(s) met their declared floor (388 assertions executed, 388 declared).
2 harness suite(s) passed.
```

388 = shipped-docs 22 + selftest 366, both at their floors.

    bash scripts/attest.sh -- bash scripts/gates.sh --fast

```
run:      2026-11-16T17:37:30Z
tree:     5113ac8f5718f2360b31654da214fa354ee68395
status:   ok
exit:     0
duration: 1s
last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
log:      .claude/state/attest-logs/20261116T173730Z.1384811.log
```

(It was run a second time, back to back, by a batching slip of mine, with the
same result: `.claude/state/attest-logs/20261116T173743Z.1384992.log`.) The tree
hash above is from before this subsection was written; it changes only this
story file.

**Negative controls.** The story records none to confirm beyond DV-1. The new
assertion is a pass-on-arrival test and measured green as RED recorded.

**DV-1, not run (GATES-owned), still consistent with the tree as built.**
`shipped-docs.test.sh` is untouched since the RED commit (`git diff HEAD` on
it is empty), and line 205 is still the only `^SDR_RE=` line, still
containing `(%/)?`. So the sed expression still changes exactly one line, and
the expected `21 passed, 1 failed` with actual `.claude/tests/b.test.sh:2` and
`.claude/tests/b.test.sh:5` holds. One consequence of GREEN: the floor is now
22, so under the mutant `selftest.sh` will ALSO report shipped-docs below its
floor (21 < 22). That is expected and is not a second defect.

**Unexpected.** One process slip of mine, recorded here. My first attested
suite run started while other sessions' runs were active: I had chained the
busy check and the run without gating on the check. I killed it before it
finished, and it left no attest record and no mutation (`mutate.sh --check`
was clean). Background-task completion notices then arrived before the jobs
had ended, so I misread several wait-then-run jobs as dead. I killed two that
were still alive. A third, which I did not kill, waited correctly and started
the suite run above at 11:01:54, once nothing else was running. The `--fast`
run was gated on a foreground idle check. Waiting for the machine took about
an hour, because other sessions ran run-queue mutations and another repo ran
a gates run.

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

### R-1 (the written limit reads as a complete list)

- **Adjudicated R-1:** `fable` (resolved Fable 5.2, `claude-fable-5-2`), 2026-11-16, diff review round 1, finding 1
- **Which test, and what was wrong:** no assertion. The "Written limit"
  comment in `.claude/tests/shipped-docs.test.sh` (lines 192-197) said "Three
  are not:" and "pins all three". That reads as a complete list of the direct
  spellings the rule misses. It is not one: the reviewer measured six more
  that the shipped `SDR_RE` also misses, and D-1's reason 2 already said the
  family is open.
- **How it was found:** diff review round 1, finding 1, routed RED. The path
  classifies `harness`, so the label decides.
- **What it says now:** the same three spellings are introduced as examples
  ("Among those that are not:"), and the assertion "pins these three". No
  assertion, fixture or pattern changes.
- **What earns it:** a comment has no behaviour, so there is nothing to
  mutate (DV-1 already earns the assertion, and it is unchanged). The evidence
  is that the diff touches comment lines only and the suite's count and
  verdict are unchanged. Both are pasted below by the orchestrator.
  RED was done by a `test-developer` dispatch, declared `opus`, which resolved
  to Opus 5.5 (`claude-opus-5-5`).

  ```
  $ git diff -U0 -- .claude/tests/shipped-docs.test.sh | grep -E '^[+-][^+-]' | grep -vE '^[+-]#'; echo "noncomment-rc=$?"
  noncomment-rc=1
  -# Nor is every direct spelling seen. Three are not: an expansion of the root
  -# other than `%/` ("${REPO_ROOT:?}/docs/x"), a `/./` between the root and
  -# docs ("$REPO_ROOT/./docs/a"), and a docs quoted on its own
  +# Nor is every direct spelling seen. Among those that are not: an expansion of
  +# the root other than `%/` ("${REPO_ROOT:?}/docs/x"), a `/./` between the root
  +# and docs ("$REPO_ROOT/./docs/a"), and a docs quoted on its own
  -# HARNESS-110 below pins all three, so widening the pattern means moving its
  +# HARNESS-110 below pins these three, so widening the pattern means moving its
  $ bash scripts/attest.sh check -- bash scripts/selftest.sh shipped-docs
  exit:     0
  last:     1 harness suite(s) passed.
  fresh
  (log .claude/state/attest-logs/20261116T202201Z.1522421.log)
  shipped-docs: 22 passed, 0 failed
  ```

- **GREEN:** a no-op. No source changed, and the suite above passes on the
  corrected tree. The fast gates were run by the orchestrator at GREEN and
  are recorded under `## Notes`.

## Diff review

Round 1, 2026-11-16. Reviewer: fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override. No file changed.

What this change does: It adds six comment lines to the "Written limit" paragraph in `.claude/tests/shipped-docs.test.sh`, naming three ways of writing a read under the real checkout's `docs/` that the suite's text rule (`SDR_RE`, a pattern matched line by line) does not notice. It adds one assertion that pins that behaviour over a five-line fixture, raises the suite's declared assertion count 21 -> 22 in `floors.conf` and `selftest.test.sh`, and takes release 130. The pattern and the two functions are untouched.

What I checked: the whole `git diff origin/main...HEAD`; the rule (lines 156-227) read against the new comment; the pattern run by `awk` on 16 lines of my own; the real `.claude/tests/*.sh` searched for any non-comment line holding a root name and a `docs` path component in a non-plain spelling (none outside this suite); `bash scripts/selftest.sh shipped-docs` (no other self-test or gates run was going): `shipped-docs: 22 passed, 0 failed`, floor 22 met. Both floor records agree at 22. DV-1's pasted result matches its prediction (1 line changed, only the AC-1 assertion red, actual `:2` and `:5`). "None occurs in the tree" is true. The diff only adds lines to the suite, so AC-2 holds.

**Should fix:**

1. **The new sentence reads as a full list, and it is not one** (`.claude/tests/shipped-docs.test.sh:192-193`)
   - **What this is:** The sentence the story exists to add: the written statement of which direct spellings the rule misses.
   - **Problem:** "Nor is every direct spelling seen. Three are not:" says exactly three are unseen. Measured with the shipped pattern, these are also missed and fit none of the three descriptions: `cat "$REPO_ROOT/"docs/a` (the quote closes after the slash), `cat $REPO_ROOT/\docs/a`, `cat "$REPO_ROOT"/d"ocs"/a`, and for the second root name `cat "${TESTS_DIR}/../../docs/a"`, `cat "$TESTS_DIR"/../../docs/a`, `cat "$TESTS_DIR/../.././docs/a"`. The story's own D-1 (reason 2) says the family is open; the comment says the opposite.
   - **Fix:** In `.claude/tests/shipped-docs.test.sh`, comment only: replace "Three are not:" with wording that does not count, for example "Among those that are not:", and "pins all three" with "pins these three". No assertion, fixture or pattern changes; a comment owes no mutation.
   - **If we skip it:** Someone writes `"${TESTS_DIR}/../../docs/x"` in a suite, reads the limit, sees it is not one of the three, and trusts a rule that stays silent. The story's stated purpose is "a limit that is written and true", and this review is the only check the Contract gives the comment.
   - **Route:** RED

Not a finding against this diff, for the orchestrator to put to the user as a possible follow-up story: the braced and quoted spellings of the second root name (`"${TESTS_DIR}/../../docs/a"`, `"$TESTS_DIR"/../../docs/a`) are missed, while the header at lines 176-177 says "the braced and the quoted-root spellings count". That is true only for `REPO_ROOT`. It predates this story (HARNESS-106/107), no line of the tree uses either today, and D-1 forbids widening here.

Not checked: the `selftest` suite (which holds the COUNTS table) was not run; I read that its `shipped-docs 22` line agrees with `floors.conf` line 67. The full self-test and `gates.sh` were not run, as instructed.

Verdict: fix 1 first.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-16T20:24:16Z
    commit: acc2e0a
    tree:   df3f203f0032a1c5018805a3907f4abf568cc884
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

- **PLANNED, 2026-11-14.** Planned by a `lead-po` dispatch on the PLANNED
  row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override
  was reported to it. D-1 (name and pin the limit, do not widen) is a PO
  decision for the orchestrator to put to the user before GREEN.
- **`depends_on: [HARNESS-109]` is ordering, not only collision.** Both
  stories append to the same "Written limit" paragraph and add a `describe`
  block at the same place, and this story's count is HARNESS-109's plus one.
  The Contract is pinned against `51239f3`; RED re-reads the region after
  HARNESS-109 merges and amends C-2 and C-3 in place.
- **HARNESS-108** (worktree `laughing-shirley-5afc9b`, GATES on 2026-11-14)
  also writes `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`
  and `.claude/harness/VERSION`. That is a collision, not a dependency, so
  it is not in `depends_on`: it touches other floor lines and takes its own
  release number. If it has not merged when this story starts, the two must
  not run side by side; whichever merges second merges `main` and re-runs.
- **`bash scripts/plan.sh conflicts`, 2026-11-14, this worktree:**
  `fewer than two startable stories; nothing to compare` (exit 0). It judged
  no pair, so it is not evidence that any pair is clear. The overlaps above
  were read by hand from the three stories' `touches:`.
- **GATES, 2026-11-16: merged `main` (HARNESS-111, #200) before the diff
  review.** It merged without conflict, but `main` had already taken release
  `129 (2026-11-16)` on the same line, so this story's VERSION is now
  `130 (2026-11-16)`. floors.conf and COUNTS kept their shipped-docs 22, and
  HARNESS-111's run-queue line is 337 in both. The full gates were run again
  on the merged tree.
- **R-1 GREEN, 2026-11-16 (a no-op).** The orchestrator ran
  `bash scripts/gates.sh --fast` directly on the corrected tree, with no
  other run on the machine: `All required gates passed (0 ran, 5 unconfigured,
  0 known).` The story then moved back to GATES, the full gates ran again, and
  diff review round 2 reviewed the fix.
