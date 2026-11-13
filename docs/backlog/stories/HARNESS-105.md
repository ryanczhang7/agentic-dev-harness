---
id: HARNESS-105
title: mutate.sh counts lines past the Windows path limit
slug: mutate-sh-counts-lines-past-the-windows
epic: 
type: fix
status: in-progress
phase: RED
branch: story/HARNESS-105-mutate-sh-counts-lines-past-the-windows-path-limit
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/mutate.sh, .claude/tests/mutate.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the mutate suite under its selftest floor, which CI runs in full on the PR
---

## Context

A follow-up to HARNESS-104 (PR #194). Its diff review found a second way for
the same line to report nothing, filed it as a Should-fix and deferred it
(HARNESS-104, `## Diff review`, finding 1). The defect is older than
HARNESS-104 and that story did not change it.

**The defect.** `scripts/mutate.sh` prints, and logs, how many lines a
mutation changed. The count is evidence pasted into story files. When the
backup's path is longer than 260 characters it says `0 line(s) changed`
although the mutation applied and the command ran against the mutated file. A
real mutation then reads as a no-op.

**Cause, reproduced on this tree at PLANNED (2026-11-13, `910a395`, Git Bash
on Windows, git 2.55.0.windows.5), on inputs that are not the review's.** The
count comes from `git ... diff --no-index` run inside `$MUTDIR` on the two
basenames (`scripts/mutate.sh` lines 387-388). Its exit status is not used
and its stderr goes to `/dev/null`. `git.exe` refuses a path over 260
characters unless `core.longpaths` is on. The backup's name is `$SAFE`, the
target path as it was given with `/` turned into `_`, plus a stamp; for a
target given by absolute path that is the whole path, and it sits under
`$MUTDIR`, which is itself under the root. So a deep root, or a long absolute
target, puts the backup past the limit. git cannot open it, the diff is empty
and the awk summary counts no hunk.

In a fixture from `make_project_fixture` (root `/tmp/tmp.IcF44NdYRW`, which
is `C:\Users\<user>\AppData\Local\Temp\tmp.IcF44NdYRW`), a three-line file
whose absolute path is padded to exactly 200 characters, the same file at
`src/b.txt`, expression `s/narrow/wide/`. `$FIX` stands for the root and
`<172 a>` for 172 letters `a`; nothing else is edited:

```
longpaths in fixture: []
long target: 200 chars
--- long absolute target (MSYS form)
rc=0
=== mutate: $FIX/src/<172 a>.txt (0 line(s) changed by s/narrow/wide/) ===

=== mutate: running grep -c width: wide; $FIX/src/<172 a>.txt ===
1

=== mutate: command exited 0; restored (verified byte-for-byte against $FIX/.claude/state/mutations/_tmp_tmp.IcF44NdYRW_src_<172 a>.txt.20261113T064021Z.3368.bak) ===
backup path: 270 chars as printed; 303 as Windows
--- short absolute target (MSYS form)
rc=0
=== mutate: $FIX/src/b.txt (1 line(s) changed by s/narrow/wide/) ===
  2 -   width: narrow;
  2 +   width: wide;

=== mutate: running grep -c width: wide; $FIX/src/b.txt ===
1

=== mutate: command exited 0; restored (verified byte-for-byte against $FIX/.claude/state/mutations/_tmp_tmp.IcF44NdYRW_src_b.txt.20261113T064023Z.3423.bak) ===
  2:   width: narrow;
backup path: 99 chars as printed; 128 as Windows
--- log
20261113T064021Z	$FIX/src/<172 a>.txt	s/narrow/wide/	0 line(s)	command: grep -c width: wide; $FIX/src/<172 a>.txt	exited 0	restored (verified)
20261113T064023Z	$FIX/src/b.txt	s/narrow/wide/	1 line(s)	command: grep -c width: wide; $FIX/src/b.txt	exited 0	restored (verified)
```

The long run loses the same three things the bracketed run lost in
HARNESS-104, all built from the one diff: the count in the header and the
log, the preview, and the restore listing. The mutation and the restore work
(`grep -c` printed 1; `cmp`, `cp` and `sed` are MSYS programs and were not
stopped by the length).

The same kind of pair diffed directly, same host: two files with
230-character names in that `$MUTDIR` (311 characters as a Windows path),
from inside the directory by basename, the names shortened here to `ppp...p`:

```
$ git -c core.autocrlf=false diff --no-index --no-color -U0 -- "$a" "$b"
error: Could not access 'ppp...p.bak'
status=1
$ git -c core.longpaths=true -c core.autocrlf=false diff --no-index --no-color -U0 -- "$a" "$b"
diff --git a/ppp...p.bak b/ppp...p.new
index b77b4eb..206b378 100644
--- a/ppp...p.bak
+++ b/ppp...p.new
@@ -2 +2 @@ x
-y
+z
status=1
```

**The fix, tried at PLANNED** on a fixture's own copy of the script (the
option added to that one command, nothing else), the same targets, each run
reduced to its count:

```
unfixed:                             long (0 line(s) changed)  short-abs (1 line(s) changed)  C:/ (0 line(s) changed)
unfixed, global longpaths=true:      long (1 line(s) changed)
unfixed, global=/dev/null nosystem:  long (0 line(s) changed)  short-abs (1 line(s) changed)
fixed, global=/dev/null nosystem:    long (1 line(s) changed)  short-abs (1 line(s) changed)  C:/ (0 line(s) changed)
--- fixed, long, preview+listing
  2 -   width: narrow;
  2 +   width: wide;
  2:   width: narrow;
```

Two things in that table shape the story:

- **The host's own git config decides the unfixed answer.** The diff runs
  inside `$MUTDIR`, so git reads the config of the repository that holds it,
  and the user's global and system config. Line 2: with `core.longpaths=true`
  in a global config the unfixed script reports 1. This worktree has it in
  `config.worktree`; the suite's fixture, a separate repository under the temp
  directory, does not, and this host has it in no global or system file. A
  host that does would never show the defect, so the test takes host config
  out of the question (Contract, C-3).
- **A `C:/...` target reports 0 by a different cause, and this fix does not
  change it.** See Out of scope.

**Windows only.** A git that is not on Windows has no 260-character limit and
ignores `core.longpaths`. So on Linux CI the new long-path assertions pass
before and after the fix. They discriminate on Git Bash, which is where RED,
GREEN and DV-1 run. This is accepted, as it was for HARNESS-104 (Out of
scope), and must be said in the PR body.

**Is it already delivered?** No: the reproduction above is against `910a395`,
which is `origin/main` with HARNESS-104 merged.

**The required gate.** Every gate is unconfigured in this repository, so
`required_gates` stays empty, as on every HARNESS story. The artifact is
judged by the `mutate` suite under its self-test floor, which CI runs in full
on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story.

## Acceptance criteria

- **AC-1** — Given a project in which a file under `src/` whose absolute
  path, as it is passed to the script, is exactly 200 characters long is
  exactly the one line `container-type: inline-size;`, and a run in which no
  git configuration outside the script turns `core.longpaths` on, when
  `bash scripts/mutate.sh <that absolute path> 's/inline-size/normal/' -- <command>`
  is run from the project root with a command that exits 0, then the backup
  path the run names in its `restored (verified byte-for-byte against ...)`
  line is more than 260 characters long, the output has exactly one line
  reading
  `=== mutate: <that absolute path> (1 line(s) changed by s/inline-size/normal/) ===`,
  the preview before the command is exactly the two lines
  `  1 - container-type: inline-size;` and `  1 + container-type: normal;`,
  the last record of `.claude/state/mutations/log` names that path and that
  expression with `1 line(s)`, and the restore listing after the
  `restored (verified` line is exactly the one line
  `  1: container-type: inline-size;`.
  *Negative control:* the same run against the script as it stands at
  `910a395`, on Git Bash, prints `(0 line(s) changed by ...)`, no preview
  line, logs `0 line(s)` and prints no restore listing (measured at PLANNED
  on a three-line file; Context has the output). On Linux the unfixed script
  already reports 1; the control exists on Git Bash only.
- **AC-2** — Given the same project, the same one-line content in `src/b.txt`
  and the same kind of run, when `mutate.sh` is given that file by its
  absolute path, so that the backup path is under 260 characters, then the
  output has exactly one line reading
  `=== mutate: <that absolute path> (1 line(s) changed by s/inline-size/normal/) ===`.
  This is the twin: the same shape of target with only the length changed. It
  holds before and after the fix on every host (measured at PLANNED: 1 before,
  1 after), and is earned by DV-2, not by the fix.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/mutate.sh`, `.claude/tests/mutate.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/mutate.test.sh` only. GREEN (feature-developer) writes
`scripts/mutate.sh`, the two floor records and `VERSION`.

**C-1. The fix (GREEN).** One edit to `scripts/mutate.sh`, at the
`git ... diff --no-index` that fills `$DIFF` (lines 387-388 at `910a395`; find
it by `diff --no-index --no-color`). `-c core.longpaths=true` becomes the
first option of that `git`, and six comment lines go directly above the
command, continuing the comment block that is already there:

    #
    # core.longpaths is forced on (HARNESS-105). git.exe refuses a path over 260
    # characters unless it is, and the backup's name is the whole target path
    # flattened - so a target given by absolute path under a deep root put the
    # backup past the limit, git could not open it, the diff came out empty and a
    # mutation that applied reported 0 lines changed. Off Windows it does nothing.
    ( cd "$MUTDIR" && git -c core.longpaths=true -c core.autocrlf=false -c core.quotepath=off -c diff.noprefix=false \
      diff --no-index --no-color --no-ext-diff --no-textconv -U0 -- "${BAK##*/}" "${NEW##*/}" ) > "$DIFF" 2>/dev/null

Nothing else on those two lines changes. Two constraints on the text:

- *the option goes directly after `git`*, as `git -c core.longpaths=true -c`.
  DV-1's expression is anchored on that spelling.
- *the comment does not contain the text `git -c core.longpaths=true`*, for
  the same reason: DV-1 must change exactly one line, the command.

`-c` on the command line outranks every config file, so the answer no longer
depends on the host. Tried at PLANNED on a fixture's copy of the script
(Context, "The fix, tried at PLANNED"): the long target reports 1 with its
preview and listing, the short absolute target still reports 1.

The edit adds six lines to `scripts/mutate.sh`, all below line 386. Nothing
live pins a line number of this script below that point (searched at
`910a395` for `mutate.sh:<number>`: `mutate.sh:191` in a comment in
`.claude/tests/mutate.test.sh`, `mutate.sh:122` and `:191` in
`docs/wiki/audits/harness-mutants-2026-10-15.md`, all above the edit; the
rest are in story files HARNESS-029 to HARNESS-104, which are records and are
not updated).

**C-2. What does not change.** The subshell, the `cd`, the two basenames and
every other git option (HARNESS-104's fix); `$SAFE` and the names of `.bak`,
`.new`, `.diff` and `.active` files; the log format; the awk summary; the
no-op refusal; the restore; every message; the discarded exit status and
stderr (see Out of scope). No run that reports a correct count today reports
a different one.

**C-3. The test (RED).** One new block in `.claude/tests/mutate.test.sh`,
after the HARNESS-104 block (`describe "HARNESS-104: a target path with
[brackets] reports the lines it really changed"`, which ends with
`h59_clear`) and before `summary "mutate"`. Model it on that block. Its shape:

- *the long target.* An absolute path of exactly 200 characters under the
  fixture's `src/`, built from the fixture root so the length does not depend
  on where the temp directory is:

      pre="$FIX/src/"; n=$(( 200 - ${#pre} - 4 ))
      LONG="$pre$(printf '%*s' "$n" '' | tr ' ' 'a').txt"

  written as the one line `container-type: inline-size;`. Why 200: the
  backup's name is that path flattened plus `.<16-character stamp>.<pid>.bak`,
  223 to 229 characters, which stays under the 255-character limit on one
  file name (NTFS and Linux alike); and the backup's whole path is the root,
  `/.claude/state/mutations/` (25 characters), and that name, which is over
  260 for any root of 13 characters or more. Measured at PLANNED with the
  19-character root `/tmp/tmp.XXXXXXXXXX`: 270 characters as printed, 303 as a
  Windows path. The target itself, 200 characters, stays under the limit, so
  `grep` and git can read it. If `n` comes out below 1 the fixture root is too
  long for this construction; RED says so rather than shortening the target.
- *the twin.* `SHORT="$FIX/src/b.txt"`, the same one line.
- *host config taken out.* Both runs are made with `GIT_CONFIG_GLOBAL=/dev/null`
  and `GIT_CONFIG_NOSYSTEM=1` in the environment of `mutate`, so a host whose
  global or system config sets `core.longpaths` cannot make the unfixed
  script pass (measured at PLANNED: with it set globally the unfixed long run
  reports 1; with these two variables it reports 0, and the short run 1). The
  fixture repository's own config does not set it. The variables are set for
  those two calls only, not exported for the suite.
- *the runs.*
  `mutate "$LONG" 's/inline-size/normal/' -- grep -c 'container-type: normal;' "$LONG"`
  and the same for `$SHORT`.
- six assertions, every one unconditional, none in a loop:

  | # | Assertion | AC | At RED on Git Bash |
  |---|---|---|---|
  | 1 | control: the backup path taken from the long run's `restored (verified byte-for-byte against <path>) ===` line is more than 260 characters | AC-1, instrument | passes |
  | 2 | long: the whole header line, counted with `whole_lines`, is 1 | AC-1 | **fails** (0) |
  | 3 | long: `preview_of` is exactly the `1 -` / `1 +` pair | AC-1 | **fails** (empty) |
  | 4 | long: `last_log` contains `<TAB>$LONG<TAB>s/inline-size/normal/<TAB>1 line(s)<TAB>` | AC-1 | **fails** (`0 line(s)`) |
  | 5 | long: `listing_of` is exactly `  1: container-type: inline-size;` | AC-1 | **fails** (empty) |
  | 6 | twin: the whole header line for `$SHORT`, counted with `whole_lines`, is 1 | AC-2 | passes |

  Assertion 1 compares a number, turned into a value the suite's `assert_eq`
  can take (for example `over`/`under`), and its message carries the measured
  length. An empty extraction must not pass it: a length of 0 is `under`.
  Assertion 4 is read after the long run and before the twin's, because
  `last_log` is the last record.
- cleanup: `rm -f "$LONG" "$SHORT"`, `reset_src`, `h59_clear`.

Helpers the block uses, all present at `910a395`: `mutate` (line 34), `TAB`
(270), `last_log` (280), `whole_lines` (284, `grep -cxF`: anchored, fixed
string), `preview_of` (287), `listing_of` (291), `reset_src` (32), `h59_clear`.
No helper changes. The header and log needles hold the 200-character path;
both are fixed strings.

**The two that pass on arrival.** Assertion 1 is a control on the instrument:
RED watches it fail once by building the long target at 100 characters
instead of 200 (expected: `under`, about 170), pastes that output in the
Handoff, and puts 200 back before committing. Assertion 6 pins behaviour that
exists today and is earned by DV-2, which RED runs.

**C-4. Counts, measured on this tree.** `mutate` stands at 322 executed and
322 declared (HARNESS-104's GREEN, Windows host, 2026-11-13; the floor in
`.claude/tests/floors.conf` line 51). Predicted, to be measured and not
assumed:

- RED, on Git Bash: 328 executed, `mutate: 324 passed, 4 failed`, and the four
  are assertions 2, 3, 4 and 5. The floor of 322 is still met in RED.
- GREEN: `mutate: 328 passed, 0 failed`.
- Linux CI, before and after the fix: 328 passed. Not run at PLANNED.

If RED's block has a different number of assertions, the numbers move with it
and RED says so in the Handoff.

**C-5. The floors and the release (GREEN).** `mutate` stands at 322 in
`.claude/tests/floors.conf` (line 51) and in the hand-copied table in
`.claude/tests/selftest.test.sh` (line 542 at `910a395`). GREEN raises both,
in the same commit, to the executed count it measures with
`bash scripts/selftest.sh mutate` (expected 328), with a dated comment at the
end of `floors.conf` in the form the HARNESS-104 entry uses: the old and new
number, what was added, the host, and the measured summary line.
`.claude/harness/VERSION` goes from `123 (2026-11-13)` to `124` with the real
calendar date of the change (`124 (2026-11-13)` if it is made today):
`check-boundaries.sh` refuses an upstream harness change that does not bump
it. The `selftest` suite's own floor does not move: a value in its table
changes, no assertion is added.

**C-6. Oracle partition.** Both criteria are **mechanical**: the count is
exactly 1, the lines are exact, nothing is tuned. The fix text in C-1 is
**settled** by the PLANNED trial - read it out. The 200 and the 260 are
settled too: 260 is Windows' `MAX_PATH`, 200 is derived in C-3. What is not
settled is every count in C-4, which is measured here.

**C-7. Changed signatures: none.** `mutate.sh`'s arguments, exit codes, output
lines and log format are unchanged; one internal command gains an option. So
there are no callers to list. Which suites the diff can break is the output
of `bash scripts/selftest-needed.sh --suites` on the story's branch; do not
copy a list from here.

**C-8. Commands.**

    bash scripts/selftest.sh mutate
    bash scripts/attest.sh -- bash scripts/selftest.sh mutate
    bash scripts/gates.sh --fast

The suite takes several minutes on this host. It must be run on Git Bash on
Windows for RED's reds and for DV-1 to mean anything.

**C-9. Test-only dependencies: none.**

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one defect put back for
the central claim, and one mutation that earns the assertion written against
behaviour that already exists.

`mutate.sh` refuses to mutate itself, so both entries use a runner copy, as
HARNESS-104 did: copy `scripts/mutate.sh` to a directory outside `scripts/`
(`.claude/state/selfmut/scripts/`, which is ignored; remove it afterwards),
check the copy with `cmp`, and run the copy against the real file by its
**absolute** path, because a copy resolves a relative path against its own
root. `$ROOT` below is this repository's root, and `$RUNNER` the copy.

- **DV-1, the defect put back (AC-1).** With `-c core.longpaths=true` taken
  out of C-1's command, git is again unable to open a backup past 260
  characters, and on Git Bash the count, the preview, the log record and the
  restore listing **must** fail: `mutate` reports exactly 4 failed, and they
  are assertions 2, 3, 4 and 5 of the HARNESS-105 block (C-3). RED cannot run
  this: the fix is not there to revert. It must run on Git Bash; on Linux it
  would show nothing. **Owner: GATES.**

      bash "$RUNNER" "$ROOT/scripts/mutate.sh" 's/git -c core\.longpaths=true -c/git -c/' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"

  The expression could not be checked at PLANNED: the line it matches does not
  exist yet. If GREEN's text differs from C-1's, GATES adjusts the expression
  and says so; what is owed is that the diff again runs without the option,
  and that the expression changes exactly one line. Afterwards:
  `bash scripts/mutate.sh --check` is clean and the runner copy is removed.

- **DV-2, the assertion that passes on arrival (assertion 6, AC-2).** A short
  absolute target reports 1 today, so the twin is green the moment it is
  written. With the awk summary made to add nothing per hunk, every count is
  0, and it **must** fail. Many other `mutate` assertions fail with it, in
  every block that checks a count, assertion 2 among them (already red in
  RED); what is owed is that the HARNESS-105 twin's name is among the
  failures. The code this mutates exists in RED, so RED runs it, after
  writing the block, and pastes the twin's FAIL line and the summary line
  here. **Owner: RED.**

      bash "$RUNNER" "$ROOT/scripts/mutate.sh" 's/total += (b > d) ? b : d/total += 0/' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"

  Checked at PLANNED under `sed --sandbox` against `910a395`: the pattern
  matches exactly one line, line 407. If the run shows the twin still green,
  the mutation missed and RED picks the line that sums the hunks and says so.
  Afterwards: `bash scripts/mutate.sh --check` is clean and the runner copy is
  removed.

  **DV-2 result (RED, 2026-11-13, Git Bash on Windows, local, tree hash
  `fa967e2`, on `c95e174` plus the uncommitted RED block).** Run as written,
  with `ROOT=/d/agentic-dev-harness/.claude/worktrees/loving-elbakyan-3fe420`
  and `RUNNER=$ROOT/.claude/state/selfmut/scripts/mutate.sh`. The runner copy
  was checked with `cmp` against `scripts/mutate.sh` (identical) and is
  `git check-ignore`d. The mutation hit line 407, the intended line. The
  HARNESS-105 twin (assertion 6) **failed** with `actual: 0`, so it is earned.
  Assertions 2-5 failed as well, as they do in RED. Runner header, the twin's
  FAIL line, the summary line and the runner's restore:

```
=== mutate: /d/agentic-dev-harness/.claude/worktrees/loving-elbakyan-3fe420/scripts/mutate.sh (1 line(s) changed by s/total += (b > d) ? b : d/total += 0/) ===
  407 -     total += (b > d) ? b : d
  407 +     total += 0

    FAIL HARNESS-105 AC-2: the short absolute twin's header reports 1 line changed, as a whole line
         expected: 1
         actual:   0

mutate: 305 passed, 23 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/loving-elbakyan-3fe420/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harness_.claude_worktrees_loving-elbakyan-3fe420_scripts_mutate.sh.20261113T074041Z.104258.bak) ===
  407:     total += (b > d) ? b : d
```

  Afterwards `git diff --quiet -- scripts/mutate.sh` succeeded (no change),
  `bash scripts/mutate.sh --check` printed `mutate: no stranded mutation;
  nothing of a previous run is in the tree.` (rc 0), and
  `.claude/state/selfmut` was removed.

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

Planned by `bash scripts/plan.sh write HARNESS-105` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po`, planned `fable`, resolved `claude-fable-5-2` (Fable 5.2), 2026-11-13, dispatched by `/plan-story`. As planned; no override was stated in the dispatch.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **A `C:/...` target reporting 0.** HARNESS-104's review saw it and could not
  separate it from the long path. Separated at PLANNED, same fixture: a
  **short** target given as `C:/Users/<user>/AppData/Local/Temp/tmp.X/src/b.txt`
  (backup path 159 characters as a Windows path) reports
  `(0 line(s) changed ...)`, before the fix and after it. The cause is not
  length. `$SAFE` keeps the colon, so the backup is named
  `C:_Users_..._b.txt.<stamp>.bak` (`ls | od -c` shows `C`, `:`, `_`), and
  from inside `$MUTDIR`:

      $ git -c core.longpaths=true diff --no-index --no-color -U0 -- "$b" "${b%.bak}.new"
      error: Could not access 'C:_Users_<user>_AppData_Local_Temp_tmp.sjLiFnkPo6_src_b.txt.20261113T064123Z.4763.bak'

  Why git cannot open that name was not examined further (a relative name
  beginning `C:` is a drive-relative path to a native program; not confirmed
  as the mechanism). The mutation, the command and the restore work. It needs
  its own story, and its fix is probably in `$SAFE`, which this story does not
  touch. The same target in MSYS form (`/tmp/...`) reports 1.
- **A one-line edit to a CRLF file reporting 3 lines changed.** Seen by the
  same review, identical before and after HARNESS-104, cause not examined.
  Not reproduced here. A separate follow-up.
- **Using git's exit status or stderr.** The command still discards both, so
  any other reason git cannot open the pair still reads as 0 lines. Telling
  "git failed" from "nothing changed" is a different change with its own
  message and its own tests.
- **Shortening the backup's name (`$SAFE`).** It would change the names
  `--check` and the sentinel read. A backup name over 255 characters (one file
  name's limit, reached by a target path of about 230) is not this defect and
  was not tried.
- **Setting `core.longpaths` anywhere else**: in the repository's config, in
  `doctor.sh`, in the fixtures, or for any other git call in the harness. Not
  audited here.
- **A Linux-side discriminator.** The limit does not exist on Linux, so on CI
  the long-path assertions pass with or without the fix. No shim is invented
  to fake it.
- **Refreshing the consuming projects to release 124.** After the merge, each
  through its own PR.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

One new block in `.claude/tests/mutate.test.sh`, after the HARNESS-104 block
and before `summary "mutate"`:
`describe "HARNESS-105: a target whose backup path passes 260 characters reports the lines it really changed"`.
Level: the suite's own integration level - the real `scripts/mutate.sh` run in
a `make_project_fixture` copy, its stdout and its log read back. That is the
cheapest level that can falsify the criteria: the defect is git.exe refusing a
path, which no unit below the script can show. Built as C-3 says, unamended:

- `LONG`: `pre="$FIX/src/"; n=$(( 200 - ${#pre} - 4 ))`, `n` letters `a`, `.txt`
  - exactly 200 characters on any root; `SHORT="$FIX/src/b.txt"`. Both hold
  the one line `container-type: inline-size;`.
- Both `mutate` calls carry `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1`
  as a prefix on that call only (checked on this host: a prefix on a shell
  function is exported to its children for the call and gone after).
- Command: `grep -c 'container-type: normal;' <target>`, exits 0 when the
  mutation is seen.

| # | Test name (as it reads in a FAIL) | AC | Needle |
|---|---|---|---|
| 1 | `HARNESS-105: control - the long run's backup path is over 260 characters (measured N; target M)` | AC-1, instrument | backup path pulled from the `restored (verified byte-for-byte against <path>) ===` line with `sed -n`, its length turned into `over`/`under`; empty extraction is length 0, so `under` |
| 2 | `HARNESS-105 AC-1: a long absolute target's header reports 1 line changed, as a whole line` | AC-1 | `whole_lines` (`grep -cxF`) on the full header line, expected 1 |
| 3 | `HARNESS-105 AC-1: a long absolute target's preview lists the removed and the added line` | AC-1 | `preview_of` exactly the `  1 - ` / `  1 + ` pair |
| 4 | `HARNESS-105 AC-1: a long absolute target is logged with 1 line(s), not 0` | AC-1 | `last_log` contains `<TAB>$LONG<TAB>s/inline-size/normal/<TAB>1 line(s)<TAB>` (read before the twin's run) |
| 5 | `HARNESS-105 AC-1: a long absolute target's restore listing names the line it put back` | AC-1 | `listing_of` exactly `  1: container-type: inline-size;` |
| 6 | `HARNESS-105 AC-2: the short absolute twin's header reports 1 line changed, as a whole line` | AC-2 | `whole_lines` on `$SHORT`'s header, expected 1 |

Every assertion unconditional, none in a loop. Cleanup `rm -f "$LONG" "$SHORT"`,
`reset_src`, `h59_clear`. No helper changed. Assertions 1 and 6 pass on
arrival; 1 is earned by the 100-character control (Handoff), 6 by DV-2.

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

Written by the RED test-developer, 2026-11-13, Git Bash on Windows, local.
Dispatched on its declared `opus`; no override was stated in the dispatch.
Every timing and count below is from a local run on this host (loaded by
other sessions' suites); none is from CI.

**Command.** `bash scripts/selftest.sh mutate` (attested form:
`bash scripts/attest.sh -- bash scripts/selftest.sh mutate`). 1110 s here.

**Attested runs (RED, tree hash `fa967e206031c7ff68dd8b3f6dd9a3a6f9e3c220`).**

```
bash scripts/attest.sh -- bash scripts/selftest.sh mutate
last:     1 of 1 harness suite(s) FAILED.
log:      .claude/state/attest-logs/20261113T071956Z.65324.log

bash scripts/attest.sh -- bash scripts/gates.sh --fast
last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
log:      .claude/state/attest-logs/20261113T075841Z.137877.log
```

The fast gates have nothing to judge (every gate is unconfigured, as on every
HARNESS story; `required_gates: []`); the suite is the judge.

**Verbatim failure, from the suite's log.** Exactly the four C-4 predicted,
assertions 2, 3, 4 and 5; no other FAIL in the file (`grep -c FAIL` on the
log is 5: these four plus the `1 of 1 harness suite(s) FAILED.` line):

```
  HARNESS-105: a target whose backup path passes 260 characters reports the lines it really changed
    FAIL HARNESS-105 AC-1: a long absolute target's header reports 1 line changed, as a whole line
         expected: 1
         actual:   0
    FAIL HARNESS-105 AC-1: a long absolute target's preview lists the removed and the added line
         expected:   1 - container-type: inline-size;
           1 + container-type: normal;
         actual:   
    FAIL HARNESS-105 AC-1: a long absolute target is logged with 1 line(s), not 0
         expected to contain: 	/tmp/tmp.nPKpvwdRlo/src/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.txt	s/inline-size/normal/	1 line(s)	
         actual:               20261113T073806Z	/tmp/tmp.nPKpvwdRlo/src/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.txt	s/inline-size/normal/	0 line(s)	command: grep -c container-type: normal; /tmp/tmp.nPKpvwdRlo/src/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.txt	exited 0	restored (verified)
    FAIL HARNESS-105 AC-1: a long absolute target's restore listing names the line it put back
         expected:   1: container-type: inline-size;
         actual:   

mutate: 324 passed, 4 failed

assertion floors: all 1 suite(s) met their declared floor (324 assertions executed, 322 declared).
1 of 1 harness suite(s) FAILED.
```

**Why it is the right failure.** The mutation applied and the command saw it
(the log record says `exited 0`, and `grep -c` exits 0 only on a match), the
restore was verified, and the control (assertion 1) passed, so the backup
path was over 260. What is missing is exactly what the one empty diff feeds:
count, preview, log count, listing. The 100-character control below shows
the same four assertions passing when only the length changes.

**Tests, one line each.**

| # | Asserts | AC | RED on Git Bash |
|---|---|---|---|
| 1 | control: backup path from the long run's `restored (verified byte-for-byte against ...)` line is over 260 characters (empty = 0 = `under`) | AC-1, instrument | pass |
| 2 | long target's full header line with `1 line(s)` occurs exactly once (`whole_lines`) | AC-1 | **FAIL** (0) |
| 3 | long target's preview is exactly `  1 - container-type: inline-size;` / `  1 + container-type: normal;` | AC-1 | **FAIL** (empty) |
| 4 | last log record contains `<TAB>$LONG<TAB>s/inline-size/normal/<TAB>1 line(s)<TAB>` | AC-1 | **FAIL** (`0 line(s)`) |
| 5 | long target's restore listing is exactly `  1: container-type: inline-size;` | AC-1 | **FAIL** (empty) |
| 6 | twin `$FIX/src/b.txt`: full header line with `1 line(s)` occurs exactly once | AC-2 | pass (earned by DV-2, red there) |

**Files touched.** `.claude/tests/mutate.test.sh` (one new block, after the
HARNESS-104 block, before `summary "mutate"`; no helper changed) and this
story (`## Test plan`, this section, DV-2's result).

**Export shape pinned.** No module is imported; the contract is the script's
output. Pinned exactly: the header line
`=== mutate: <target as given> (N line(s) changed by <expr>) ===`, the
`  N - ` / `  N + ` preview lines before `=== mutate: running`, the log record
fields `<TAB><target><TAB><expr><TAB>N line(s)<TAB>`, the
`restored (verified byte-for-byte against <backup path>) ===` verdict (its
path is extracted with
`sed -n 's/.*restored (verified byte-for-byte against \(.*\)) ===$/\1/p'`),
and the `  N: <line>` restore listing. All unchanged by C-1; C-2 says none of
them may change. Not constrained: anything about how the diff is obtained
beyond its result, so C-1's text is checked by DV-1, not by this block.

**Passed on arrival, and what earns each.**

- Assertion 1 (the control). Built the long target at 100 characters instead
  of 200 (`h105_n=$(( 100 - ...`), ran the suite, saw it fail, put 200 back
  (`grep -n 'h105_n='` shows `200` at line 1289 in the tree attested above).
  Plain run, not attested, 21 m 32 s:

```
  HARNESS-105: a target whose backup path passes 260 characters reports the lines it really changed
    FAIL HARNESS-105: control - the long run's backup path is over 260 characters (measured 171; target 100)
         expected: over
         actual:   under

mutate: 327 passed, 1 failed
```

  At 100 characters assertions 2-5 pass on the unfixed script, which is the
  defect's length dependence shown directly.
- Assertion 6 (the twin). DV-2, run in RED; result pasted under
  `## Deferred verifications`: `actual: 0`, `mutate: 305 passed, 23 failed`.

**Negative controls, expected values.** Unlike a suite that fails at import,
every assertion here executed in RED, so these are measured against the real
script, not claims:

| Control | Threshold | Candidate range | Measured |
|---|---|---|---|
| assertion 1, 200-char target | > 260 → `over` | 13-char root or more gives > 260; 19-char `/tmp/tmp.XXXXXXXXXX` root gives about 270 as printed | passed (over); the exact length is printed only on failure. PLANNED measured 270 for the same construction |
| assertion 1, 100-char target (probe) | > 260 | about 170 | 171, `under`, FAIL as intended |
| DV-2 twin under `total += 0` | must be 0 | 0 | 0, FAIL as intended |
| DV-1 (GATES) | 4 failed, assertions 2-5 | - | not run: the fix does not exist in RED. I cannot run this verification; it stays with GATES |

**What GREEN must do.**

1. C-1 exactly: `-c core.longpaths=true` as the first option of the
   `git ... diff --no-index --no-color` command in `scripts/mutate.sh`
   (lines 387-388 at `c95e174`, the option going on 387, the `git -c` line;
   find it by text), plus the six comment lines;
   the comment must not contain `git -c core.longpaths=true` (DV-1's
   expression is anchored on that spelling).
2. Run `bash scripts/attest.sh -- bash scripts/selftest.sh mutate`; expected
   `mutate: 328 passed, 0 failed` on Git Bash.
3. C-5: raise `mutate`'s floor from 322 to the measured executed count
   (expected 328) in `.claude/tests/floors.conf` and in the table in
   `.claude/tests/selftest.test.sh`, with the dated `floors.conf` comment;
   `VERSION` to `124 (<date>)`. Note the floor line counts **passed**
   assertions as "executed": RED's run printed `324 assertions executed`
   for 328 run, and the 100-char run `327`. So read the number off a green
   run.

**Discovered.** Nothing changes the approach. C-3's construction held: with
this host's 19-character fixture root `n` was 172, well above 1. The
`GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1` prefix on the `mutate`
shell function was checked to reach the child (`X=1 f` where `f` runs
`bash -c 'echo $X'` prints 1, and nothing after), and this host has
`core.longpaths` in neither global nor system config. No Contract block was
amended.

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

