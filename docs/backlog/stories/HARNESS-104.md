---
id: HARNESS-104
title: mutate.sh counts the lines a bracketed path changed
slug: mutate-sh-counts-the-lines-a-bracketed-p
epic: 
type: fix
status: in-review
phase: REVIEW
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

  **DV-2 result (RED, 2026-11-13, Git Bash on Windows, local, tree
  `937d74e`).** Run as written. The runner copy was at
  `.claude/state/selfmut/scripts/mutate.sh`, checked with `cmp` against
  `scripts/mutate.sh` (identical) and `git check-ignore`d. The mutation hit
  line 484, the intended line. Both HARNESS-104 names failed: assertion 2
  (exit 90) and assertion 6 (the file was left mutated, so the hash differs).
  The other four HARNESS-104 assertions failed as well, as they do in RED.
  Runner output, then the two FAIL lines and the summary line from the suite
  it ran:

      === mutate: /d/agentic-dev-harness/scripts/mutate.sh (1 line(s) changed by s/^cp "\$BAK" "\$FILE" 2>\/dev\/null$/: no restore/) ===
        484 - cp "$BAK" "$FILE" 2>/dev/null
        484 + : no restore

          FAIL HARNESS-104 AC-1: the command saw the mutated line (exit 0)
               expected: 0
               actual:   90
          FAIL HARNESS-104 AC-2: the bracketed file is byte-identical afterwards
               expected: 7fb43a8c791b6ef0485d6a4d153259157f28cf95
               actual:   629c01db6accf0d61d1167e0cfc1c171ae3a9329

      mutate: 280 passed, 42 failed

      === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harness_scripts_mutate.sh.20261113T042943Z.12954.bak) ===
        484: cp "$BAK" "$FILE" 2>/dev/null

  Afterwards `git diff --quiet -- scripts/mutate.sh` succeeded (no change),
  `bash scripts/mutate.sh --check` printed `mutate: no stranded mutation;
  nothing of a previous run is in the tree.` (rc 0), and
  `.claude/state/selfmut` was removed.

  **DV-1 result (GATES, 2026-11-13, Git Bash on Windows, local, tree at
  `1df1bbe`).** Run by the orchestrator, with the runner copy at
  `.claude/state/selfmut/scripts/mutate.sh` (`cmp` identical to
  `scripts/mutate.sh`), the expression as written, and the test run by its
  absolute path (`bash /d/agentic-dev-harness/.claude/tests/mutate.test.sh`)
  instead of `bash -c "cd $ROOT && ..."`, which is the same command without a
  shell string. A first try with a relative test path exited 127: the copy
  runs from its own root, so the suite was not found; nothing was judged and
  the file was restored. The mutation changed one line, and exactly the four
  owed assertions failed:

      === mutate: /d/agentic-dev-harness/scripts/mutate.sh (1 line(s) changed by s|-- "\${BAK##\*/}" "\${NEW##\*/}"|-- "$BAK" "$NEW"|) ===
      === mutate: running bash /d/agentic-dev-harness/.claude/tests/mutate.test.sh ===
          FAIL HARNESS-104 AC-1: the header reports 1 line changed, as a whole line
          FAIL HARNESS-104 AC-1: the preview lists the removed and the added line
          FAIL HARNESS-104 AC-1: the log records 1 line(s), not 0
          FAIL HARNESS-104 AC-2: the restore listing names the line it put back
      mutate: 318 passed, 4 failed
      === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harness_scripts_mutate.sh.20261113T045254Z.28994.bak) ===

  Afterwards `bash scripts/mutate.sh --check` printed `mutate: no stranded
  mutation; nothing of a previous run is in the tree.`, `scripts/mutate.sh`
  is unchanged, and `.claude/state/selfmut` was removed.

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

One block, at integration level: it runs the real `scripts/mutate.sh` inside
the suite's `make_project_fixture` project against a real bracketed path. The
defect sits in how a native program (`git.exe`) receives an argument, so
nothing short of running the script would show it. The block is TCF's
`HARNESS-089` block, taken from
`D:/trump-crime-family/.claude/tests/mutate.test.sh` lines 1173-1204 by line
range rather than retyped. Changes from TCF: `HARNESS-089` became
`HARNESS-104` throughout, the comment's first line names this story and its
TCF origin, and the final `clear_strays` became `h59_clear`, to match the
neighbouring blocks. A `diff` of the inserted lines against the extracted and
renamed text was empty.

It sits in `.claude/tests/mutate.test.sh` after the last `HARNESS-059 AC-4`
block (which ends `h59_clear`) and before `summary "mutate"`.

| # | Assertion name | AC | Needle / oracle |
|---|---|---|---|
| 1 | `HARNESS-104: control - the hash helper can read the bracketed file` | instrument | `${#before}` = 40 |
| 2 | `HARNESS-104 AC-1: the command saw the mutated line (exit 0)` | AC-1 | rc = 0 |
| 3 | `HARNESS-104 AC-1: the header reports 1 line changed, as a whole line` | AC-1 | `whole_lines` (`grep -cxF`) of the full header = 1 |
| 4 | `HARNESS-104 AC-1: the preview lists the removed and the added line` | AC-1 | `preview_of` = exactly `  1 - container-type: inline-size;` / `  1 + container-type: normal;` |
| 5 | `HARNESS-104 AC-1: the log records 1 line(s), not 0` | AC-1 | `last_log` contains `TAB src/[slug].txt TAB s/inline-size/normal/ TAB 1 line(s) TAB` (tab on both sides, so `0`/`11 line(s)` cannot match) |
| 6 | `HARNESS-104 AC-2: the bracketed file is byte-identical afterwards` | AC-2 | `brk_sha` before = after |
| 7 | `HARNESS-104 AC-2: the restore listing names the line it put back` | AC-2 | `listing_of` = exactly `  1: container-type: inline-size;` |

## Handoff: RED -> GREEN

**Command.**

    bash scripts/selftest.sh mutate

(About 4.5 minutes on this host. It has to run on Git Bash on Windows to
discriminate. On Linux the four assertions pass without the fix; see Out of
scope.)

**Attested RED run** (local, Git Bash on Windows, 2026-11-13):

    command:  bash scripts/selftest.sh mutate
    tree:     937d74edd9cc905bc9552dbceb2f1d516cba790d
    exit:     1
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261113T042418Z.9768.log

Verbatim failure (from that log):

      HARNESS-104: a target path with [brackets] reports the lines it really changed
        FAIL HARNESS-104 AC-1: the header reports 1 line changed, as a whole line
             expected: 1
             actual:   0
        FAIL HARNESS-104 AC-1: the preview lists the removed and the added line
             expected:   1 - container-type: inline-size;
               1 + container-type: normal;
             actual:   
        FAIL HARNESS-104 AC-1: the log records 1 line(s), not 0
             expected to contain: 	src/[slug].txt	s/inline-size/normal/	1 line(s)	
             actual:               20261113T042848Z	src/[slug].txt	s/inline-size/normal/	0 line(s)	command: grep -c container-type: normal; src/[slug].txt	exited 0	restored (verified)
        FAIL HARNESS-104 AC-2: the restore listing names the line it put back
             expected:   1: container-type: inline-size;
             actual:   

    mutate: 318 passed, 4 failed

    assertion floors: all 1 suite(s) met their declared floor (318 assertions executed, 315 declared).
    1 of 1 harness suite(s) FAILED.

This matches C-4's prediction: 322 assertions ran, 318 passed and 4 failed,
and the four are assertions 3, 4, 5 and 7. **One point on wording, for C-5.**
The floor line's "assertions executed" is `executed_count` in
`scripts/selftest.sh`, which takes the **passed** count. In RED it therefore
reads 318, not 322. In GREEN it should read 322, and 322 is the number C-5
raises both floors to. These are the right failures. The mutation applied and
the command saw it (assertion 2 passes, and the log shows `exited 0` and
`restored (verified)`), so only the evidence built from the diff is empty:
the count, the preview and the listing. That is the defect C-1 fixes.

**Attested fast gates** (local):

    command:  bash scripts/gates.sh --fast
    tree:     937d74edd9cc905bc9552dbceb2f1d516cba790d
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261113T043357Z.15930.log

Every gate is unconfigured in this repository, so `--fast` judges nothing
here. The suite is the judge, and it holds no timeouts to budget.

**Files touched in RED.** `.claude/tests/mutate.test.sh` (34 lines added,
nothing else changed). This story file: `## Test plan`, this section, and
the DV-2 result under `## Deferred verifications`.

**Shape the tests pin.** There is no module and no export. What is pinned is
`scripts/mutate.sh`'s observable output for a target path holding brackets,
run from the project root:
- exit status = the command's (0 here);
- exactly one line `=== mutate: src/[slug].txt (1 line(s) changed by s/inline-size/normal/) ===`;
- a preview of exactly `  1 - container-type: inline-size;` and `  1 + container-type: normal;` before `=== mutate: running`;
- the last log record has the tab-separated fields `src/[slug].txt`, `s/inline-size/normal/`, `1 line(s)`;
- exactly one indented line `  1: container-type: inline-size;` after `restored (verified`;
- the file is byte-identical afterwards.

**Not constrained:** how the diff is made to work. C-1's subshell with
basenames is the contracted fix, but the tests would accept any change that
produces the right diff. They do not read the diff's `---`/`+++` header lines.

**Passed on arrival, and what earns each.**

| # | Earned by | Result |
|---|---|---|
| 1 (instrument control) | pointed at `sha "$BRK"` (the absolute-path helper) for one full suite run, then put back | **failed as expected**: `expected: 40 / actual: 0`, with git's `fatal: could not open '/tmp/tmp.A0rbGX3Qkv/src/[slug].txt' for reading: No such file or directory`. `brk_sha` was restored and the block re-diffed against the port: identical |
| 2 (exit 0) | DV-2 | failed under the mutation (`actual: 90`), see DV-2 |
| 6 (byte-identical) | DV-2 | failed under the mutation (hash differs), see DV-2 |

Control run output (suite run directly with `bash .claude/tests/mutate.test.sh`,
not attested; it was a diagnostic edit, since reverted):

      HARNESS-104: a target path with [brackets] reports the lines it really changed
    fatal: could not open '/tmp/tmp.A0rbGX3Qkv/src/[slug].txt' for reading: No such file or directory
        FAIL HARNESS-104: control - the hash helper can read the bracketed file
             expected: 40
             actual:   0
        [... assertions 3, 4, 5, 7 failed as in RED ...]
        FAIL HARNESS-104 AC-2: the bracketed file is byte-identical afterwards
             expected: 
             actual:   7fb43a8c791b6ef0485d6a4d153259157f28cf95
    mutate: 316 passed, 6 failed

(Assertion 6 also failed in that run because `before` was the empty
absolute-path hash and `after` was `brk_sha`'s. That run tells us nothing
about assertion 6; DV-2 is what earns it.)

**Expected values for GREEN** (Git Bash on Windows):

| What | RED measured | GREEN must measure |
|---|---|---|
| `${#before}` (control) | 40 | 40 |
| header whole-line count | 0 | 1 |
| preview | empty | `  1 - container-type: inline-size;` / `  1 + container-type: normal;` |
| log count field | `0 line(s)` | `1 line(s)` |
| restore listing | empty | `  1: container-type: inline-size;` |
| bracketed file hash before = after | `7fb43a8c...cf95` both | equal |
| suite summary | `mutate: 318 passed, 4 failed` | `mutate: 322 passed, 0 failed` |
| floor line "executed" (passed count) | 318 | 322 |

DV-1 (owner GATES) is not mine to run. The fix does not exist yet, so there
is nothing to revert. I am leaving it to GATES, and its expected result is
C-3's: exactly 4 failed, assertions 3, 4, 5 and 7.

**C-7 "no callers", checked against the tree (tree `937d74e`).** In
`scripts/`, `.claude/hooks/` and `.github/`, `scripts/mutate.sh` is invoked
only by `scripts/gates.sh:268` and `scripts/attest.sh:161`, both as
`mutate.sh --check`, which reads `.active` sentinels and not the diff or the
count. `.claude/hooks/lib.sh` and `phase-guard.sh` only recognise a
`mutate.sh` invocation in order to exempt its FILE argument. None of them
reads the `$DIFF` content, the `---`/`+++` lines or the count. A grep for
`mutate\.sh:[0-9]+` across the tree finds one live pin,
`.claude/tests/mutate.test.sh:1215` (`mutate.sh:191`, a comment, above the
edit at 381). The rest are historical citations in closed stories and in
`docs/wiki/audits/harness-mutants-2026-10-15.md`. Some of those cite lines
below 381 (`mutate.sh:462` in HARNESS-034, `:497` in HARNESS-045). They
describe the script as it stood when those stories ran and are not
assertions, so the seven added lines break nothing. C-1's search mentions
only the lines above the edit; I am noting the older citations here, not
correcting them.

**Discovered.** Nothing changes the approach. The only point to carry
forward is the floor-line wording above: it reports passed assertions, so
GREEN should take 322 from the `mutate: N passed, 0 failed` line and check
that the floor line agrees.

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

## Diff review

### Review 1 — the whole diff against main at 7925009 (resolved claude-fable-5-2)

A fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved claude-fable-5-2, no override; head reviewed `88f0b3b`. It changed no file and ran neither the self-test nor `gates.sh`; experiments ran in scratch fixtures on Git Bash, git 2.55.0.windows.5.

What this change does: `mutate.sh` runs the `git diff` that counts and lists the changed lines from inside the mutations directory on the two bare names, instead of two absolute paths an MSYS shell does not translate for `git.exe` when they hold `[`. One test block (7 assertions) pins the bracketed case; the `mutate` floor goes 315 → 322 in both places; VERSION goes to 123.

1. **The subshell is correct on every path tried.** Against HEAD's script in a fixture, each reported the right count, preview, log record and listing, exit 0: targets `src/[slug].txt`, `src/[[...all]].astro`, `src/{a,b}.txt`, `src/@resp.txt`, `src/~t.txt`, `src/x=y;z.txt`, `src/!b$c.txt`, `src/sp ace.txt`, `src/it's.txt`, `src/#h%20.txt`, `.env`; names beginning with `-` (`src/-dash.txt`, `./-dash.txt`, `-top.txt`); a project root named `a [b] c` (also wrong before the fix, right now); `CDPATH`, `GIT_DIR`, `GIT_WORK_TREE` and `diff.relative=true` (same at main and HEAD); a binary file and CRLF (same at main and HEAD). `$MUTDIR` cannot be relative (line 81). The caller's command still runs from `$ROOT`. Nothing reads the diff's `---`/`+++` lines. The `git diff` is the script's only native-program call; `gates.sh`, `attest.sh`, `lib.sh` and `phase-guard.sh` only call `--check`, read the sentinel or parse the command string. The suite's `sha` helper has the same defect, but no existing block passes it a bracketed path, and the new block uses `brk_sha` behind a 40-character control.
2. **The ported block is faithful,** differing from TCF's only in the id, the provenance comment and `h59_clear`; `scripts/mutate.sh` is byte-identical to TCF's but for the id. Needles: the header by `grep -cxF`; preview and listing by exact equality; the log needle tab-bounded and literal in `case`. All seven assertions have been seen red (DV-1: 3, 4, 5, 7; DV-2: 2, 6; the Handoff: 1).
3. **Linux CI: acceptable as stated.** The defect cannot occur on Linux; both criteria's negative controls say so, and a fake-`git` shim would pin the argument shape, not the behaviour.
4. **Floors and VERSION consistent:** 322 in both places, 315 + 7; the `selftest` floor rightly unchanged.

**Should fix:**

1. **A long backup path still reports `0 line(s) changed`, by a second cause** (`scripts/mutate.sh:387-388`)
   - **What this is:** the same `git diff` call; its status and error output are discarded, so whenever git cannot open the backup the count is 0.
   - **Problem:** `git.exe` refuses paths over 260 characters unless `core.longpaths` is on, and the backup name is the whole flattened target path. Reproduced with a 110-character root: a 281-character backup path, `error: Could not access '_c_Users_..._crlf.txt.<stamp>.bak'`, header `(0 line(s) changed ...)`, no preview. Identical at main and HEAD; `git -c core.longpaths=true diff --no-index` diffs the same files correctly.
   - **Fix:** add `-c core.longpaths=true` to that command's options, with its own test; cut as a follow-up story, since it is outside AC-1 and AC-2 and Out of scope defers other path defects.
   - **If we skip it:** a probe run by absolute path from a deeply nested worktree can again report 0 lines; the mutation, command and restore are unaffected.
   - **Route:** GATES

**Nice to have:**

2. **VERSION is dated by UTC, the last entries by local date** (`.claude/harness/VERSION:34`, `.claude/tests/floors.conf:1190`)
   - **What this is:** the release stamp.
   - **Problem:** `123 (2026-11-13)` from a commit at 2026-11-12 22:52 -0600; release 122 was stamped `2026-11-12` from 00:14 UTC on the 13th.
   - **Fix:** nothing required; for consistency, `2026-11-12` in both places.
   - **If we skip it:** nothing breaks; no script reads the date.
   - **Route:** GATES

Not checked: Linux (reasoned, not run); a `C:/...` absolute target reported 0, but that fixture was over the 260-character limit too, so a colon cause could not be separated from finding 1; on a CRLF file a one-line edit reports 3 lines changed, identically at main and HEAD, cause not examined.

Verdict: Ship.

**Orchestrator (2026-11-13):** verdict Ship, so GATES → REVIEW goes on. Finding 1 is deferred to a follow-up story, as the review itself recommends; finding 2 is not made (nothing reads the date, and a change would restart these steps). Both are offered to the user.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-13T04:54:56Z
    commit: 1df1bbe
    tree:   b2c1e328d37f37c53b1291c49948e49445b6d320
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

- **RED verified by the orchestrator, 2026-11-13.** `test-developer`, planned `opus`, resolved claude-opus-5-5. Changed: `mutate.test.sh` (34 lines, TCF's block by line range, renamed) and this story. `attest.sh check -- bash scripts/selftest.sh mutate` `fresh`, exit 1, `mutate: 318 passed, 4 failed`, log `20261113T042418Z.9768`: the four are assertions 3, 4, 5, 7 of the HARNESS-104 block; `--fast` `fresh`, exit 0. DV-2 run in RED, both owed names red.
- **GREEN, 2026-11-13.** `feature-developer`, planned `opus`, resolved claude-opus-5-5 (no override). Changed: `scripts/mutate.sh` (C-1, TCF `2d00f6e`'s edit with the id renamed: the `git diff --no-index` runs in a subshell inside `$MUTDIR` on `"${BAK##*/}"` and `"${NEW##*/}"`, seven comment lines added), `.claude/tests/floors.conf` and `.claude/tests/selftest.test.sh` (`mutate` 315 -> 322, with the dated comment), `.claude/harness/VERSION` (`123 (2026-11-13)`). Measured: `mutate: 322 passed, 0 failed`. Every Handoff control confirmed by running the block's scenario by hand against the shipped script in a fresh fixture: `${#before}` 40; header line `=== mutate: src/[slug].txt (1 line(s) changed by s/inline-size/normal/) ===`; preview `  1 - container-type: inline-size;` / `  1 + container-type: normal;`; log field `1 line(s)` with `exited 0` and `restored (verified)`; listing `  1: container-type: inline-size;`; hash `7fb43a8c791b6ef0485d6a4d153259157f28cf95` before and after; exit 0. No divergence from RED's numbers.
- **GATES, 2026-11-13.** DV-1 run by the orchestrator (result under `## Deferred verifications`): exactly the four owed assertions red, file restored and verified. Full run by the orchestrator directly (2 s, no gate configured): `attest.sh check -- bash scripts/gates.sh` `fresh`, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).`, log `20261113T045455Z.32033`.
- **Self-test at GATES → REVIEW, 2026-11-13.** `selftest-needed: run` (5 harness paths); dispatched to a `feature-developer` (planned `opus`, resolved claude-opus-5-5). `attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `fresh`, exit 0, `17 harness suite(s) passed.`, 3176 s, log `20261113T045948Z.34573`; floors met (4313 executed, 4309 declared). Deferred to a follow-up: diff review finding 1 (`core.longpaths`).
