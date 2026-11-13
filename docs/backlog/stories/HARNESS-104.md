---
id: HARNESS-104
title: mutate.sh counts the lines a bracketed path changed
slug: mutate-sh-counts-the-lines-a-bracketed-p
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-104-mutate-sh-counts-the-lines-a-bracketed-p
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/mutate.sh, .claude/tests/mutate.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the mutate suite under its selftest floor, which CI runs in full on the PR
---

## Context

A port. The consuming project trump-crime-family (TCF) found this defect in
its own story TCF-038 (DV-3), and fixed it locally as a story it numbered
HARNESS-089: RED commit `57caa01`, GREEN commit `2d00f6e`, merged there as PR
#15. That id collides with upstream's unrelated HARNESS-089, so upstream takes
the fix as HARNESS-104. A fix that lives only downstream is overwritten by the
next refresh; after this merges, trump-crime-family and clean_calendar are
refreshed to release 123.

**The defect.** `scripts/mutate.sh` prints, and logs, how many lines a
mutation changed. The count is evidence pasted into story files. For a target
whose path holds `[` and `]` it says `0 line(s) changed` although the mutation
applied and the command ran against the mutated file. A real mutation then
reads as a no-op.

**Cause, reproduced on this tree at PLANNED (2026-11-12, `7925009`, Git Bash
on Windows, git 2.55.0.windows.5), on inputs that are not TCF's.** The count
comes from `git diff --no-index -- "$BAK" "$NEW"` (`scripts/mutate.sh` lines
380-381). Both names are absolute MSYS paths under `$MUTDIR`
(`/d/.../.claude/state/mutations/`, or `/tmp/...` in a fixture) and carry
`$SAFE`, the target path with `/` turned into `_`, which keeps the brackets.
`git.exe` is a native Windows program: the MSYS runtime rewrites a POSIX-path
argument to `D:/...` for it, but leaves an argument alone when it holds a glob
character. git cannot open the unconverted path, its error goes to
`/dev/null`, the diff is empty and the awk summary counts no hunk. In a
fixture from `make_project_fixture`, a three-line file at `src/[id].css` and
the same file at `src/id.css`, expression `s/narrow/wide/`:

```
--- src/[id].css
=== mutate: src/[id].css (0 line(s) changed by s/narrow/wide/) ===

=== mutate: running grep -c width: wide; src/[id].css ===
1

=== mutate: command exited 0; restored (verified byte-for-byte against /tmp/tmp.0dMmGA4oWh/.claude/state/mutations/src_[id].css.20261113T041302Z.1811.bak) ===
--- src/id.css
=== mutate: src/id.css (1 line(s) changed by s/narrow/wide/) ===
  2 - width: narrow;
  2 + width: wide;

=== mutate: running grep -c width: wide; src/id.css ===
1

=== mutate: command exited 0; restored (verified byte-for-byte against /tmp/tmp.0dMmGA4oWh/.claude/state/mutations/src_id.css.20261113T041303Z.1842.bak) ===
  2: width: narrow;
--- log
20261113T041302Z	src/[id].css	s/narrow/wide/	0 line(s)	command: grep -c width: wide; src/[id].css	exited 0	restored (verified)
20261113T041303Z	src/id.css	s/narrow/wide/	1 line(s)	command: grep -c width: wide; src/id.css	exited 0	restored (verified)
```

The bracketed run loses three things, all built from the same diff: the count
in the header and the log, the preview, and the restore listing. The mutation
and the restore themselves work (`grep -c` printed 1; the restore was verified
with `cmp`, which is not a native program handed a path it cannot convert).

The same kind of pair diffed directly, same host: with absolute paths, 0
hunks; from inside the directory by basename, `@@ -2 +2 @@`. That is the fix
TCF shipped, and it is what this story ports.

**Windows only.** On Linux nothing converts paths and the bracketed target
diffs correctly today. So on CI the new assertions pass before and after the
fix. They discriminate on Git Bash, which is where RED, GREEN and DV-1 run.
This is accepted (Out of scope) and must be said in the PR body.

**Is it already delivered upstream?** No. `scripts/mutate.sh` at `7925009`
differs from TCF's fixed copy in exactly this one hunk, and the reproduction
above is against this tree.

**The required gate.** Every gate is unconfigured in this repository, so
`required_gates` stays empty, as on every HARNESS story. The artifact is
judged by the `mutate` suite under its self-test floor, which CI runs in full
on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story.

## Acceptance criteria

- **AC-1** — Given a project in which the file `src/[slug].txt` (a repository
  path holding `[` and `]`) is exactly the one line
  `container-type: inline-size;`, when
  `bash scripts/mutate.sh 'src/[slug].txt' 's/inline-size/normal/' -- <command>`
  is run from the project root with a command that exits 0 only if it finds
  the mutated line in that file, then the run exits 0, its output has exactly
  one line reading
  `=== mutate: src/[slug].txt (1 line(s) changed by s/inline-size/normal/) ===`,
  the preview before the command is exactly the two lines
  `  1 - container-type: inline-size;` and `  1 + container-type: normal;`,
  and the last record of `.claude/state/mutations/log` names that path and
  that expression with `1 line(s)`.
  *Negative control:* the same run against the script as it stands at
  `7925009`, on Git Bash, prints `(0 line(s) changed by ...)`, no preview
  line, and logs `0 line(s)` (measured at PLANNED; Context has the output).
  On Linux the unfixed script already reports 1; the control exists on Git
  Bash only.
- **AC-2** — Given the same file and the same run, when the command has
  finished, then the restore listing after the `restored (verified` line is
  exactly the one line `  1: container-type: inline-size;`, and the file is
  byte-identical to what it was before the run.
  *Negative control:* against the script at `7925009`, on Git Bash, the
  restore listing is empty (measured at PLANNED). Byte-identity holds before
  and after the fix; it is earned by DV-2, not by the fix.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/mutate.sh`, `.claude/tests/mutate.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/mutate.test.sh` only. GREEN (feature-developer) writes
`scripts/mutate.sh`, the two floor records and `VERSION`.

**C-1. The fix (GREEN).** One edit to `scripts/mutate.sh`, at the
`git ... diff --no-index` that fills `$DIFF` (lines 380-381 at `7925009`; find
it by `diff --no-index --no-color`). The command runs inside a subshell that
has changed into `$MUTDIR`, and is given the two basenames instead of the two
absolute paths. As TCF shipped it (`2d00f6e`), with the story id changed:

    #
    # Run from inside $MUTDIR on the two basenames (HARNESS-104). git.exe is a
    # native program on Git Bash, and MSYS converts a /d/... argument to D:/... for
    # it - except when the argument holds a glob character, which $SAFE keeps from
    # a path like src/pages/[slug].astro. git then could not open the backup, the
    # diff came out empty, and a mutation that applied reported 0 lines changed.
    # A relative name needs no conversion.
    ( cd "$MUTDIR" && git -c core.autocrlf=false -c core.quotepath=off -c diff.noprefix=false \
      diff --no-index --no-color --no-ext-diff --no-textconv -U0 -- "${BAK##*/}" "${NEW##*/}" ) > "$DIFF" 2>/dev/null

The seven comment lines continue the comment block that already sits above the
command; the two command lines replace the two that are there. The git options
do not change. What each part is for:

- *the subshell* - the `cd` must not move the script's own working directory:
  the command the caller passed runs later, from where it does today.
- *`"${BAK##*/}"`, `"${NEW##*/}"`* - the names without their directory. `$BAK`
  and `$NEW` are both directly under `$MUTDIR` (lines 232-233), so the
  basenames name the same two files from inside it. A relative name is not
  path-converted, whatever characters it holds.
- *`> "$DIFF"` outside the subshell* - `$DIFF` is an absolute path used by a
  shell redirect, which bash opens itself; it needs no conversion and does not
  move.
- *`2>/dev/null` on the subshell* - a `cd` that fails gives an empty diff and a
  count of 0, the same degraded answer as today, never a diff of other files.
  `$MUTDIR` exists by this point: the backup was already copied into it.

The diff's `---`/`+++` header lines now name the basenames. Nothing reads
them: the awk below takes only `Binary files` and `@@` lines and the `-`/`+`
body lines.

The edit adds seven lines to `scripts/mutate.sh`, all below line 381. Nothing
pins a line number of this script below that point (searched at `7925009`:
the only line references are `mutate.sh:191` in a comment in
`.claude/tests/mutate.test.sh` and `mutate.sh:122` and `:191` in
`docs/wiki/audits/harness-mutants-2026-10-15.md`, all above the edit).

**C-2. What does not change.** `$SAFE` and the names of `.bak`, `.new`,
`.diff` and `.active` files (`--check` and the sentinel read them); the log
format; the awk summary; the no-op refusal (it uses `cmp`, not the diff); the
restore; every message. No run that reports a correct count today reports a
different one.

**C-3. The test (RED).** One new block in `.claude/tests/mutate.test.sh`,
after the last existing block (`HARNESS-059 AC-4: a command with no -- before
it is refused, and FILE is unchanged`, which ends with `h59_clear`) and before
`summary "mutate"`. Port TCF's block from
`D:/trump-crime-family/.claude/tests/mutate.test.sh` (its `describe
"HARNESS-089: a target path with [brackets] reports the lines it really
changed"`, around line 1174 there), with every `HARNESS-089` in the describe
and the assertion names renamed `HARNESS-104`, and the comment naming this
story. Read the block from that file; do not retype it from this section.
Its shape, for reference:

- `BRK="$FIX/src/[slug].txt"`, written as the one line
  `container-type: inline-size;`.
- `brk_sha() { ( cd "$FIX" && git hash-object 'src/[slug].txt' ); }` - the
  suite's own `sha` helper (`git -C "$FIX" hash-object <absolute path>`) has
  the same defect on a bracketed path: git cannot open it, both hashes are
  empty and a byte-identity assertion passes comparing nothing. So the block
  hashes by relative path and asserts first that the hash is 40 characters.
- the run: `mutate 'src/[slug].txt' 's/inline-size/normal/' -- grep -c
  'container-type: normal;' 'src/[slug].txt'`.
- seven assertions, every one unconditional, none in a loop:

  | # | Assertion | AC | At RED on Git Bash |
  |---|---|---|---|
  | 1 | control: `brk_sha` returns 40 characters | instrument | passes |
  | 2 | the command exits 0 | AC-1 | passes |
  | 3 | the whole header line, counted with `whole_lines`, is 1 | AC-1 | **fails** (0) |
  | 4 | `preview_of` is exactly the `1 -` / `1 +` pair | AC-1 | **fails** (empty) |
  | 5 | `last_log` contains `<TAB>src/[slug].txt<TAB>s/inline-size/normal/<TAB>1 line(s)<TAB>` | AC-1 | **fails** (`0 line(s)`) |
  | 6 | the file's hash equals the hash before | AC-2 | passes |
  | 7 | `listing_of` is exactly `  1: container-type: inline-size;` | AC-2 | **fails** (empty) |

- cleanup: `rm -f "$BRK"`, `reset_src`, and the stray-clearing helper the
  surrounding blocks use at this point in the file. TCF's block ends with
  `clear_strays`; here the block before it ends with `h59_clear` (which calls
  `clear_strays` and also removes dot-named strays). Either leaves this block
  clean; use `h59_clear` to match the neighbours unless RED sees a reason not
  to.

Helpers the block uses, all present here at `7925009` with the meaning they
have in TCF: `mutate` (line 34), `TAB` (270), `clear_strays` (278), `last_log`
(280), `whole_lines` (284, `grep -cxF`, so the header needle is anchored and
fixed-string - the brackets are not a pattern), `preview_of` (287),
`listing_of` (291), `reset_src` (32), `h59_clear` (1038). `$MUTDIR` in the
suite is the fixture's. No helper changes.

Assertion 5's needle sits between tabs on both sides, so `0 line(s)` cannot
match it and neither can `11 line(s)`.

**The three that pass on arrival.** Assertion 1 is a control on the
instrument, not on `mutate.sh`: RED watches it fail once by pointing it at
`sha "$BRK"` (the absolute-path helper; expected length 0 on Git Bash), pastes
that output in the Handoff, and puts `brk_sha` back before committing.
Assertions 2 and 6 pin behaviour that exists today and are earned by DV-2,
which RED runs.

**C-4. Counts, measured on this tree and not carried over from TCF.**
`bash scripts/selftest.sh mutate` at `7925009`, Windows host, local,
2026-11-12: `315 assertions executed, 315 declared`, all passed. (TCF's 308
then 315 are TCF's and mean nothing here; upstream's 315 already includes
HARNESS-091's seven.) Predicted, to be measured and not assumed:

- RED, on Git Bash: 322 executed, `mutate: 318 passed, 4 failed`, and the four
  are assertions 3, 4, 5 and 7. The floor of 315 is still met in RED.
- GREEN: `mutate: 322 passed, 0 failed`.

If RED's block has a different number of assertions, the numbers move with it
and RED says so in the Handoff.

**C-5. The floors and the release (GREEN).** `mutate` stands at 315 in
`.claude/tests/floors.conf` (line 51) and in the hand-copied table in
`.claude/tests/selftest.test.sh` (line 542 at `7925009`). GREEN raises both,
in the same commit, to the executed count it measures with
`bash scripts/selftest.sh mutate` (expected 322), with a dated comment at the
end of `floors.conf` in the form the HARNESS-103 entry uses: the old and new
number, what was added, the host, and the measured summary line.
`.claude/harness/VERSION` goes from `122 (2026-11-12)` to `123` with the real
calendar date of the change: `check-boundaries.sh` refuses an upstream harness
change that does not bump it. The `selftest` suite's own floor (366) does not
move: a value in its table changes, no assertion is added.

**C-6. Oracle partition.** Both criteria are **mechanical**: the count is
exactly 1, the lines are exact, nothing is tuned. The fix text in C-1 and the
test block in C-3 are **settled** by TCF's merged story - read them out. What
is not settled is every count (C-4), which is measured here.

**C-7. Changed signatures: none.** `mutate.sh`'s arguments, exit codes, output
lines and log format are unchanged; one internal command is run from another
directory. So there are no callers to list. Which suites the diff can break is
the output of `bash scripts/selftest-needed.sh --suites` on the story's
branch; do not copy a list from here.

**C-8. Commands.**

    bash scripts/selftest.sh mutate
    bash scripts/attest.sh -- bash scripts/selftest.sh mutate
    bash scripts/gates.sh --fast

The suite takes several minutes on this host. It must be run on Git Bash on
Windows for RED's reds and for DV-1 to mean anything.

**C-9. Test-only dependencies: none.**

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one defect put back for
the central claim, and one mutation that earns the assertions written against
behaviour that already exists.

`mutate.sh` refuses to mutate itself, so both entries use a runner copy, as
HARNESS-029 (C-6) and HARNESS-059 did: copy `scripts/mutate.sh` to a
directory outside `scripts/` (HARNESS-059 used `.claude/state/selfmut/scripts/`,
which is ignored; remove it afterwards), check the copy with `cmp`, and run
the copy against the real file by its **absolute** path, because a copy
resolves a relative path against its own root. `$ROOT` below is this
repository's root, and `$RUNNER` the copy.

- **DV-1, the defect put back (AC-1, and AC-2's listing).** With the two
  basenames in C-1's command turned back into `"$BAK"` and `"$NEW"`, git is
  again handed absolute paths that hold brackets, and on Git Bash the count,
  the preview, the log record and the restore listing **must** fail:
  `mutate` reports exactly 4 failed, and they are assertions 3, 4, 5 and 7 of
  the HARNESS-104 block (C-3). RED cannot run this: the fix is not there to
  revert. It must run on Git Bash; on Linux it would show nothing.
  **Owner: GATES.**

      bash "$RUNNER" "$ROOT/scripts/mutate.sh" 's|-- "\${BAK##\*/}" "\${NEW##\*/}"|-- "$BAK" "$NEW"|' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"

  The expression was checked at PLANNED against TCF's fixed `mutate.sh`, whose
  text C-1 is: under `sed --sandbox` it changes exactly one line, the second
  line of the command. If GREEN's text differs, GATES adjusts the expression
  and says so; what is owed is that the diff is again given the absolute paths.
  Afterwards: `bash scripts/mutate.sh --check` is clean and the runner copy is
  removed.

- **DV-2, the two assertions that pass on arrival (assertions 2 and 6).** The
  mutation applies and the file is restored for a bracketed path today, so
  "the command exits 0" and "byte-identical afterwards" are green the moment
  they are written. One mutation earns both: with the final restore copy
  removed, `mutate.sh` leaves the bracketed file mutated and exits 90, and
  both **must** fail. Many other `mutate` assertions fail with them, in every
  block that checks a restore; what is owed is that both HARNESS-104 names are
  among the failures. The code this mutates exists in RED, so RED runs it,
  after writing the block, and pastes the two FAIL lines and the summary line
  here. **Owner: RED.**

      bash "$RUNNER" "$ROOT/scripts/mutate.sh" 's/^cp "\$BAK" "\$FILE" 2>\/dev\/null$/: no restore/' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"

  At `7925009` that pattern matches one line, line 484 (the other `cp "$BAK"
  "$FILE"` lines are indented). If the run shows the two assertions still
  green, the mutation missed and RED picks the line that performs the restore
  on the ordinary path and records which.

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

Planned by `bash scripts/plan.sh write HARNESS-104` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po`, planned `fable`, resolved `claude-fable-5-2` (Fable 5.2), 2026-11-12, dispatched by `/plan-story`. As planned; no override was stated in the dispatch.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **Renaming backups (`$SAFE`) to drop glob characters.** It would change the
  names `--check` and the sentinel read, for no gain over relative paths.
- **The suite's `sha` helper.** It has the same defect for a bracketed path
  (C-3). No existing block hashes one; the new block uses its own `brk_sha`.
  `sha` is not rewritten.
- **Any other script that hands an absolute MSYS path to a native program.**
  Not audited here. A follow-up if one turns up.
- **A Linux-side discriminator.** The defect does not exist on Linux, so on CI
  the new block passes with or without the fix. No fixture is invented to fake
  the conversion.
- **Other glob characters as separate cases** (`*`, `?`, `{`). The fix removes
  the absolute path altogether, so one bracketed case pins it.
- **The awk summary, the preview's 20-line cap, the log format.** Unchanged.
- **Refreshing trump-crime-family and clean_calendar to release 123.** That
  happens after the merge, each through its own PR, and is not this story.
  TCF's local copy of the fix and its test block are replaced by upstream's at
  that refresh.
- **Renumbering TCF's own HARNESS-089 story.** TCF's record stays as it is.

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

