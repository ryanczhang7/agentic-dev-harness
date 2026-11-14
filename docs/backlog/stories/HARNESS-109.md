---
id: HARNESS-109
title: The shipped-docs rule leaves a project's own suites alone
slug: the-shipped-docs-rule-leaves-a-project-s
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-109-the-shipped-docs-rule-leaves-a-project-s
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/shipped-docs.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the shipped-docs suite under its selftest floor, which CI runs in full on the PR
---

## Context

No epic, as HARNESS-106 and HARNESS-107, whose rule this story corrects. Line
numbers below are `origin/main` at `51239f3`.

**The defect, reproduced on a consumer.** HARNESS-106 gave
`.claude/tests/shipped-docs.test.sh` the rule `suite_docs_reads` (comment
156-191, pattern 192, functions 193-212): no suite line may read under the
real checkout's `docs/`, because `docs/` is the project's own and a refresh
ships none of it, so an upstream suite that reads there reads, in a consumer,
a file that is absent or somebody else's. The rule's file list,
`suite_docs_files` (193-198), is every top-level `.claude/tests/*.sh`.

A consumer's `.claude/tests/` also holds the consumer's own suites. Upstream
does not ship them, `refresh-harness.sh` reports each as `KEPT ... (upstream
does not ship it - yours)`, and the harness's name for them is
`project-*.test.sh` (`scripts/selftest.sh` 104-112 and
`.claude/tests/floors.conf` 23-27: their floors go in `project-floors.conf`).
Those suites read the consumer's own `docs/` legitimately: it is their
project. The rule scans them all the same.

Refreshing `D:/fantasy-world-builder` from release 119 to 125 failed its full
self-test on exactly one assertion, `HARNESS-106 AC-3: suite_docs_reads over
the real tree prints nothing` (354-355). Log
`D:/fantasy-world-builder/.claude/state/attest-logs/20261114T022024Z.225569.log`,
lines 1311-1321:

    expected:
    actual:   .claude/tests/project-handoff.test.sh:37
              .claude/tests/project-handoff.test.sh:38
              .claude/tests/project-sections.test.sh:69
              .claude/tests/project-sections.test.sh:70
    shipped-docs: 17 passed, 1 failed
    FAIL shipped-docs  did 17 units of work, below the floor of 18 in .claude/tests/floors.conf

The four lines are `DOC="$REPO_ROOT/docs/wiki/harness-feedback-world-080.md"`,
`HANDOFF="$REPO_ROOT/docs/wiki/handoff"` and the same two shapes in
`project-sections.test.sh`. Every consumer that has a `project-*.test.sh`
reading its own docs fails its self-test from release 125 on, and cannot fix
it: the suite that fails is upstream's and is replaced by the next refresh.

**The fix.** `suite_docs_files` leaves out a file named `project-*.test.sh`.
Why the name and not another signal is C-1.

**The gate that would fail if this broke.** `bash scripts/gates.sh --list`
shows every gate `<unconfigured>` in this repository, so no gate, required or
optional, exercises this and `required_gates` stays empty, as in HARNESS-106
and HARNESS-107. The artifact is judged by the `shipped-docs` self-test suite
under its floor in `.claude/tests/floors.conf`, which `selftest.sh --changed`
runs locally at GATES and CI runs in full on the PR, and by
`check-boundaries.sh` (the `VERSION` bump, the deferred verifications' pasted
results).

## Acceptance criteria

- **AC-1** — Given a tree whose `.claude/tests/` holds one file,
  `project-x.test.sh`, with the lines `DOC="$REPO_ROOT/docs/wiki/x.md"` and
  `HANDOFF="$REPO_ROOT/docs/wiki/handoff"`, when the `shipped-docs` suite's
  rule `suite_docs_reads` runs over that tree, then it prints nothing.
  *The bug this reproduces:* at `51239f3` it prints
  `.claude/tests/project-x.test.sh:2` and `.claude/tests/project-x.test.sh:3`,
  which is the consumer's failure above on a fixture. *Control:* with the
  exclusion removed from `suite_docs_files`, this must fail with those two
  lines (DV-1).
- **AC-2** — Given the same tree with the same three lines also under
  `x.test.sh` (an upstream-named suite), `project-x.sh` (the prefix without
  the `.test.sh` suffix) and `my-project-x.test.sh` (the prefix not at the
  start of the name), when the rule runs, then `suite_docs_reads` reports
  lines 2 and 3 of each of those three files as `<file>:<line number>`, and
  `suite_docs_files` lists those three files and not `project-x.test.sh`.
  Only a top-level file whose whole name is `project-<anything>.test.sh` is
  left out.
- **AC-3** — Given this repository's own tree, which holds no
  `project-*.test.sh`, when the `shipped-docs` suite runs, then the rule
  still scans at least 30 files and still reports nothing, and every
  assertion the suite holds at `51239f3` is unchanged and still passes.
  *Control, against a real line of this tree and not only the fixture:* with
  one line of a real upstream suite rewritten to read `"$REPO_ROOT/docs/..."`,
  the real-tree assertion must fail naming that file and line (DV-2): the
  exclusion has not blinded the rule to the suites it exists for.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `.claude/tests/shipped-docs.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**C-0. Who writes which.** All four paths classify as `harness`
(`bash scripts/classify.sh <path>`, checked at PLANNED), so the phase lock
divides nothing and this block does.

- **RED (test-developer):** `.claude/tests/shipped-docs.test.sh` only. The
  defect is *in* a suite, so its fix is a test-file change and is RED's, in
  two steps (C-3), as in HARNESS-106 and HARNESS-107.
- **GREEN (feature-developer):** the floor records in
  `.claude/tests/floors.conf` and in `.claude/tests/selftest.test.sh`'s
  `COUNTS` list, and `.claude/harness/VERSION` (C-4). GREEN touches no
  assertion and no line of `shipped-docs.test.sh`.

RED ends with `shipped-docs` green at 21 executed, above its recorded floor
of 18. GREEN records 21 and bumps the release.

**C-1. The signal is the file name `project-*.test.sh`, and why.** Three
candidates were weighed at PLANNED:

- *What `refresh-harness.sh` uses to decide KEPT.* It compares the project's
  file against the upstream checkout it was handed (`[ -e "$UP/.claude/$d/$rel" ]`,
  line 280). That is the authoritative answer and it is not available: the
  rule runs inside one tree, in a self-test, with no upstream beside it.
- *A floor line in `project-floors.conf`.* In-tree and refresh-proof, but it
  makes a rule about what a suite reads depend on parsing a second file's
  grammar, it says nothing for a tree with no `project-floors.conf` yet, and
  a single-suite run does not audit floors at all.
- *The name.* `project-*.test.sh` is the convention the harness already
  states in the two places a consumer reads it (`scripts/selftest.sh`
  104-112, `floors.conf` 23-27) and the one the consumer in the report
  follows for all five of its suites. It needs no second file and is one
  `case` arm.

The name is chosen. Its limit is written into the rule's comment (C-2) and
is not hidden: the rule trusts the name, so an upstream suite named
`project-*.test.sh` would escape it. Upstream ships none (measured: 0 of 36)
and nothing checks that; a check is out of scope here and named there.

The pattern is the suite pattern, not `project-*.sh` and not `*project*`:
a project helper that is not a suite, and a suite that merely contains the
word, are still scanned (AC-2). A consumer whose helper reads its docs moves
the path into the `project-*.test.sh` that uses it.

**C-2. `suite_docs_files` (AC-1, AC-2), `.claude/tests/shipped-docs.test.sh`
193-198.** Same name, same argument, same output format (paths relative to
`<root>`, `LC_ALL=C` name order). It becomes:

    suite_docs_files() {
      local root="$1" f
      for f in "$root"/.claude/tests/*.sh; do
        [ -f "$f" ] || continue
        case "${f##*/}" in project-*.test.sh) continue ;; esac
        printf '%s\n' "${f#"$root"/}"
      done | LC_ALL=C sort
    }

The exclusion is one line of its own, so that DV-1 can delete exactly it.
`suite_docs_reads` (199-212) and `SDR_RE` (192) are not edited: the reads
function takes its files from `suite_docs_files`, so the exclusion reaches it
with no change.

*The comment* (156-191). Two edits, no rewrite. The `suite_docs_files`
paragraph (164-166) says what is left out and why: a top-level
`project-*.test.sh` is a consuming project's own suite, upstream does not
ship it, a refresh keeps it, and it may read its own project's `docs/`. The
"Written limit" paragraph gains the limit of C-1 in one sentence: the rule
trusts the name. The sentence "no file is exempted by name" (in the paragraph
about this suite scanning itself) is now false as written and is narrowed to
say what it meant: no *upstream* file is exempted, this suite included.

The lines `SDR_RE=` (192) and `# --- a compliant fixture, by construction`
(214) keep their first words: DV-3's command cuts the rule out of the suite
between them.

**C-3. The fixture and the three assertions (AC-1, AC-2), RED, in two
steps.** A new `describe` block, placed after the twin assertion (394-398)
and before `summary "shipped-docs"`, titled
`a project's own suites are not scanned (HARNESS-109)`. It reuses `$SDR_R`
from the block above, so that the root name is spelled in pieces and no line
of this suite is itself an offending line (the suite scans itself; the
real-tree assertion is the check that this was done).

The fixture root is a new directory under `$WORK` holding `.claude/tests/`.
Each fixture file holds exactly these three lines:

| Line | Text as the fixture file holds it |
|---|---|
| 1 | `#!/usr/bin/env bash` |
| 2 | `DOC="$REPO_ROOT/docs/wiki/x.md"` |
| 3 | `HANDOFF="$REPO_ROOT/docs/wiki/handoff"` |

Lines 2 and 3 are the two shapes of the consumer's four lines.

The three assertions, in this order, each `assert_eq` on the whole output:

1. *(AC-1)* With `project-x.test.sh` the only file: `suite_docs_reads` over
   the fixture is the empty string.
2. *(AC-2)* After copying the same bytes to `x.test.sh`, `project-x.sh` and
   `my-project-x.test.sh`: `suite_docs_reads` is, exactly, one per line:
   `.claude/tests/my-project-x.test.sh:2`,
   `.claude/tests/my-project-x.test.sh:3`, `.claude/tests/project-x.sh:2`,
   `.claude/tests/project-x.sh:3`, `.claude/tests/x.test.sh:2`,
   `.claude/tests/x.test.sh:3`.
3. *(AC-1, AC-2)* On the same four-file fixture: `suite_docs_files` is,
   exactly: `.claude/tests/my-project-x.test.sh`,
   `.claude/tests/project-x.sh`, `.claude/tests/x.test.sh`.

Assertion 1 expects an empty string, which a rule that scanned nothing would
also give. Assertions 2 and 3 are what keep it honest: the same function,
over the same directory, with the same bytes, reports the three neighbours.
Each assertion's name starts `HARNESS-109 AC-<n>:` and says in words what it
pins.

Measured at PLANNED (2026-11-13, Git Bash, the suite's own functions cut out
of `51239f3` and run on a scratch fixture of exactly this shape). These are
**settled**: read them out.

| | at `51239f3` | with C-2 |
|---|---|---|
| assertion 1 actual | `.claude/tests/project-x.test.sh:2`, `:3` | empty |
| assertion 2 actual | the six lines plus `project-x.test.sh:2`, `:3` (eight) | the six lines |
| assertion 3 actual | the three files plus `project-x.test.sh` (four) | the three files |
| this repository: files scanned, lines reported | 36, none | 36, none |
| `D:/fantasy-world-builder`: files scanned, lines reported | 41, the four lines of Context | 36, none |

*Step 1, the fixture and the assertions, with `suite_docs_files` still as it
is.* Run `bash scripts/selftest.sh shipped-docs`. Expected, and pasted into
the handoff with the actual values: `shipped-docs: 18 passed, 3 failed` -
the three new assertions, with the actual values of the table's first
column. All three are observed failing; none passes on arrival.
*Step 2, the fix.* Replace the function and edit the comment (C-2). Same
command: `shipped-docs: 21 passed, 0 failed`.

The real-tree assertion (354-355), the "at least 30 files" check (356-361),
the HARNESS-106/107 fixture and its twin (363-398) are not edited (AC-3).

**C-4. The floor and the release (GREEN).** At `51239f3`:
`floor | shipped-docs  | 18` (`floors.conf` line 66) and `shipped-docs 18`
(`selftest.test.sh` line 558, in the `COUNTS` list). GREEN raises both, in
one commit, to the executed count it measures with
`bash scripts/selftest.sh shipped-docs`: expected 21. If RED added or dropped
an assertion, the measured count is the floor and the handoff says which. A
dated comment at the end of `floors.conf`, in the form the HARNESS-107 entry
uses (1210-1217), records the raise and what the three are.
`.claude/harness/VERSION` goes from `126 (2026-11-13)` to `127` with the real
calendar date of the change. HARNESS-108, in flight, also takes 127 and also
edits these two floor files: see `## Notes` for what the second to merge
does.

**C-5. Oracle partition.** All three criteria are **mechanical**: pin the
reported lines and the file lists exactly; invent no metric. C-3's table is
**settled** - read out, not re-derived to fit. If a value RED observes
differs from one pinned here, stop and report it; do not edit the
expectation to match.

**C-6. Changed signatures: none; the readers of what changes.**
`suite_docs_files <root>` keeps its name, argument and output format; what
changes is which files it lists. Its callers, grep-listed at `51239f3`:
`shipped-docs.test.sh` 209 (inside `suite_docs_reads`) and 356 (the "at
least 30" count, 36 before and after). No other file calls either function.
`scripts/selftest-needed.sh` 168-173 describes the rule in a comment and its
`SCANS` row `shipped-docs add .claude/tests/*.sh` (185) still selects
`shipped-docs` for a changed `project-*.test.sh`; that is over-selection of
one cheap suite, accepted, and the script is not edited (Out of scope).

**C-7. Commands.**

    bash scripts/selftest.sh shipped-docs
    bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs
    bash scripts/selftest-needed.sh --suites
    bash scripts/check-sigpipe.sh && bash scripts/check-grep-count.sh
    bash scripts/gates.sh --fast

`shipped-docs` alone took 33 seconds at PLANNED on this host, under
`mutate.sh`. GREEN's change to `selftest.test.sh` selects the `selftest`
suite as well; RED and GREEN each record what
`selftest-needed.sh --suites` prints for their own diff.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": DV-1 is the defect put
back for the central claim, and DV-2 is the probe the law owes a changed rule
over the tree, against a real line of it. Both are one `mutate.sh` run
against the one suite that holds the assertion. DV-3 is one entry over the
default, and the reason is that the default cannot reach the thing this
story changes: upstream's tree holds no `project-*.test.sh`, so no mutation
of a real upstream line can show the exclusion working on a real line. The
only real tree that holds one is the consumer the defect was found in. DV-3
reads it and writes nothing, so it costs seconds and no mutation. No
assertion of this story passes on arrival (C-3, step 1), so nothing else is
owed. Every expression is restated by RED's handoff against the file as
built. Line numbers in results are pasted, not predicted.

- **DV-1, the defect put back (AC-1).** With the exclusion line deleted from
  `suite_docs_files`, a project's own suite is scanned again. `mutate.sh`
  must report 1 line changed. `shipped-docs` **must** report exactly 3
  failed, `shipped-docs: 18 passed, 3 failed`: the three `HARNESS-109`
  assertions, with the actual values of C-3's `51239f3` column (the two
  `project-x.test.sh` lines; the eight lines; the four files). The real-tree
  assertion still passes, because this tree holds no such suite. RED sees
  the same three red in its step 1, but that is an observation of the
  unfixed tree, not a mutation of the fixed one, and it is not the committed
  tree. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/project-\*\.test\.sh) continue ;;/d' -- bash scripts/selftest.sh shipped-docs

- **DV-2, the narrowed scan against a real line of this tree (AC-3).** One
  line of a real upstream suite, rewritten to read under `docs/`, must still
  be reported. `mutate.sh` must report 1 line changed. `shipped-docs`
  **must** report exactly 1 failed, `shipped-docs: 20 passed, 1 failed`: the
  real-tree assertion (`suite_docs_reads over the real tree prints
  nothing`), its actual value the one line
  `.claude/tests/selftest-needed.test.sh:<n>`. The mutated suite is only read
  as text by this run, never executed. Baseline, run at PLANNED on `51239f3`
  with this same command: `17 passed, 1 failed`, actual
  `.claude/tests/selftest-needed.test.sh:872`, restore verified
  byte-for-byte. The result after the fix must name the same file: an
  exclusion written too wide (`*.test.sh`, `*-*`) would leave the suite
  green here. RED cannot own it: the tree RED would run it on is not the
  committed one. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/selftest-needed.test.sh 's|^CM="\$REPO_ROOT/CLAUDE\.md"$|CM="$REPO_ROOT/docs/wiki/x.md"|' -- bash scripts/selftest.sh shipped-docs

  (`CM="$REPO_ROOT/CLAUDE.md"` is line 872 at `51239f3` and occurs once in
  `.claude/tests/*.sh`.)

- **DV-3, the exclusion against the real lines that failed (AC-1).** The
  rule as built, cut out of this branch's `shipped-docs.test.sh` and run
  over the consumer's tree, read-only, **must** print no reported line and
  a file count of 36, where at `51239f3` it prints the four lines of Context
  and 41 (measured at PLANNED, C-3). The first command is the guard against
  a vacuous pass: it must still print the consumer's reading lines
  (`project-handoff.test.sh` 37 and 38, `project-sections.test.sh` 69 and
  70 at PLANNED), or the result says nothing. `<scratch>` is any directory
  outside both repositories. Nothing is written to the consumer. It cannot
  run before the fix exists, and it reads a checkout that only this machine
  has, so it is the orchestrator's run and no suite's. If
  `D:/fantasy-world-builder` is absent, or its project suites no longer hold
  such a line, record `WAIVED` with that reason: AC-1's fixture and DV-1
  stand without it. **Owner: GATES.**

      grep -n 'REPO_ROOT/docs' /d/fantasy-world-builder/.claude/tests/project-*.test.sh
      sed -n '/^SDR_RE=/,/^# --- a compliant fixture/p' .claude/tests/shipped-docs.test.sh > <scratch>/sdr.sh
      bash -c '. "$1"; suite_docs_reads "$2"; suite_docs_files "$2" | awk "END { print NR }"' _ <scratch>/sdr.sh /d/fantasy-world-builder

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

Planned by `bash scripts/plan.sh write HARNESS-109` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po`, planned `fable`, resolved `claude-fable-5-2` (Fable 5.2), 2026-11-13. No override was reported to the dispatch.

## Out of scope

- **A check that upstream ships no `project-*.test.sh`.** The exclusion
  trusts the name (C-1). A guard that the upstream `floors.conf` floors no
  suite of that name would close it, and holds in a consumer too, since a
  refresh replaces that file. It is a second rule with its own probe, so a
  second story if wanted; this one writes the limit down and stops.
- **Any other signal of "upstream ships this"**: reading
  `project-floors.conf`, a manifest of shipped files, asking
  `refresh-harness.sh`. C-1 says why not.
- **A project's files that are not `project-*.test.sh`.** A consumer helper
  such as `project-lib.sh`, or a consumer suite under another name, is still
  scanned. No second pattern, no configuration knob.
- **`scripts/selftest-needed.sh`.** Its `SCANS` row still selects
  `shipped-docs` when a `project-*.test.sh` changes, and its comment
  (168-173) still says the rule scans every top-level `.claude/tests/*.sh`.
  Over-selection of one 30-second suite, accepted; neither is edited.
- **`SDR_RE` and `suite_docs_reads`.** The pattern, the spellings it sees and
  its data-flow limit are HARNESS-107's and unchanged.
- **The consumer.** No file of `D:/fantasy-world-builder` is written. Its
  refresh to the release this story ships is a separate piece of work, done
  through a PR there once this one is merged.
- **`refresh-harness.sh`, `scripts/selftest.sh`, `project-floors.conf`
  handling, `CLAUDE.md`, the skills.** No prose and no script changes: the
  `project-*.test.sh` convention is already stated where a consumer reads it.
- **The other tree-scanning suites** (`sigpipe`, `grep-count`, and the
  `shipped-docs` map rule over commands, agents and skills). Whether any of
  them should also leave a project's own files alone is not asked here; only
  the rule that failed in the report is changed.
- **Checking a story's `touches:` or `**Writes:**` against its diff.**

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


- **Planned 2026-11-13** in the main checkout `D:/agentic-dev-harness`, on
  `main` at `51239f3` (equal to `origin/main`), by a `lead-po` dispatch. No
  branch was created, no phase set and nothing committed by that dispatch.
  The id was re-checked free at planning: no `HARNESS-109.md` under
  `docs/backlog/stories/`, no local or remote branch naming it, and no pull
  request naming it.
- **Source.** A field report from a consumer: refreshing
  `D:/fantasy-world-builder` from release 119 to 125 failed its full
  self-test on HARNESS-106 AC-3 alone (Context has the log path and lines).
- **HARNESS-108 is in flight and shares three of this story's four files.**
  Branch `story/HARNESS-108-harness-runs-queue-machine-wide-instead` also
  writes `.claude/harness/VERSION` (to `127`, read from that branch at
  planning), `.claude/tests/floors.conf` and `.claude/tests/selftest.test.sh`.
  `plan.sh conflicts` judges startable stories and may not show the pair.
  Whichever of the two merges second merges the updated `main` into its
  branch and redoes those lines: `VERSION` becomes `128`, its dated comment
  goes below the other story's at the end of `floors.conf`, and its `COUNTS`
  line is re-applied beside the other's. The rows do not overlap (`run-lock`
  and whatever else HARNESS-108 raises against `shipped-docs` here), so the
  conflict is textual, in `VERSION` and at the end of `floors.conf`. Then
  the gates are run again on the merged tree before the PR is called ready.
- **Decisions made at PLANNED, each open to RED's amendment with a reason:**
  the signal is the file name `project-*.test.sh`, not a floor line and not
  a wider glob (C-1); the exclusion lives in `suite_docs_files`, one line of
  its own, and `suite_docs_reads` is untouched (C-2); three new assertions,
  so the floor goes 18 to 21 (C-3, C-4); the check that upstream ships no
  suite under that name is left out and written down as the rule's limit
  (Out of scope).
- **Measurements taken at PLANNED** are in C-3's table and in DV-2's
  baseline. The DV-2 baseline was a real `mutate.sh` run on the main
  checkout; `mutate.sh` reported the restore verified byte-for-byte and
  `git status --short` was empty afterwards.
