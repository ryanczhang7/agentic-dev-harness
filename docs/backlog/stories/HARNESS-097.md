---
id: HARNESS-097
title: check-boundaries refuses to run without its scratch directory, and cleans it up on exit
slug: check-boundaries-refuses-to-run-without
epic: 
type: bug
status: done
phase: DONE
branch: story/HARNESS-097-check-boundaries-refuses-to-run-without
depends_on: [HARNESS-089]      # this story edits the lines HARNESS-089 wrote; merged as #181, DONE on main at dd97d6b
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION, docs/backlog/stories/HARNESS-097.md]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

The three should-fix findings of HARNESS-089's diff review (its `## Diff
review`, verdict Ship, 2026-11-06), deferred there to one follow-up story.
All three are in `scripts/check-boundaries.sh` at release 110 (`main` at
`dd97d6b`, where PR #181 is merged; the branch and `main` differ only in the
story file, so the line numbers below are the same on both):

1. **Line 29**, `mkdir -p "$ROOT/.claude/state/check-boundaries"`, ignores its
   exit status. When the directory cannot be created, every
   `git show ... > "$cp"` after it fails (`Not a directory`), the reads find
   an empty or absent copy, and the script judges the criteria against an
   empty baseline. The reviewer put a plain file at that path in a throwaway
   clone and saw `ok    acceptance criteria changed, with an ## Amendments
   entry`; suppression commits were only `note`d, never failed. A run that
   cannot read its own evidence must refuse, not report a verdict.
2. **The comment above `criteria_baseline`** (lines 322-325) still says each
   copy is "read into a variable and fed by here-string". `txt` in its `local`
   (line 327) and `crit_txt=""` (line 362) are dead since HARNESS-089.
3. **Line 31**, the `trap ... EXIT` that removes `copy-$$.md` and
   `diff-$$.txt`, is pinned by no test. Deleting it turns nothing red.

Findings 1 and 3 each get a test and an acceptance criterion. Finding 2 has no
behaviour to test: it is a comment and two dead names, taken as a refactor
under the existing `boundaries` suite, and it is not an acceptance criterion
(Contract, Out of scope).

**The gate that fails if this story breaks:** every gate in this repository's
`project.conf` is unconfigured. The artifact is judged by
`bash scripts/selftest.sh boundaries`, which CI runs, and by CI's own
`boundaries` job, which runs `check-boundaries.sh` itself. Both run on Linux
and both see finding 1 and finding 3, so nothing here is host-bound.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given a repository in which `.claude/state/check-boundaries`
  exists as a plain file, so the scratch directory cannot be created, when
  `bash scripts/check-boundaries.sh <base>` runs on a story branch whose story
  would otherwise get a criteria verdict, then it prints a `FAIL` line that
  names `.claude/state/check-boundaries`, exits non-zero, and prints no
  criteria verdict at all: no line containing `acceptance criteria`, neither
  the `ok    acceptance criteria ...` lines nor the `## Acceptance criteria
  differ` refusal. *Control (the defect):* on release 110 the same fixture
  exits with its ordinary status and prints `ok    acceptance criteria
  changed, with an ## Amendments entry` (the reviewer's observation); that is
  RED's red, and DV-2 puts it back at GATES. *Twin:* with the plain file
  removed, the same fixture gets its ordinary criteria line again, so the
  refusal is specific to the directory and not to the fixture.
- **AC-2** — Given a fixture whose scratch directory could be created, when
  `bash scripts/check-boundaries.sh <base>` has exited, with whatever status,
  then `.claude/state/check-boundaries/` exists and is empty: no `copy-*.md`,
  no `diff-*.txt`, nothing. *Control:* with the `trap ... EXIT` line removed,
  the same run leaves `copy-<pid>.md` behind and this assertion fails, naming
  it (DV-1). The trap exists before this story, so the assertion passes on
  arrival and is earned by that mutation, as rules.md requires of a test
  written against existing code.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
       * the files it WRITES, on one line at column 0 that starts
         `**Writes:**`, each path backticked and repository-relative:
           **Writes:** `src/core/world.ts`, `tests/world.test.ts`
         `bash scripts/plan.sh conflicts` compares it with `touches:` and prints
         DRIFT for a written file `touches:` does not cover. Without the line
         there is no DRIFT at all, and files the prose merely cites never count
       * module paths and exported names, exactly
       * exact signatures, and the types the assertions will destructure
       * THE SEMANTICS BEHIND EACH NUMBER - not clamp(latitude) but "latitude
         clamps at +/-85, and dragging DOWN brings the north into view". One
         sentence per number settles a sign error in one line
       * the accessible markup for anything user-facing: roles, labels, what is
         a sibling of what
       * the oracle partition of the criteria (settled / oracle-free /
         mechanical - see story-authoring)
       * baseline measurements the story may read out rather than re-derive,
         each with what it was measured on
       * TEST-ONLY DEPENDENCIES this story is likely to need, by name. RED
         may add them itself, but only inside the dev block - so a library
         production will ALSO use is a GREEN change and is better decided
         here than discovered mid-phase. Where the ecosystem has no dev
         block at all (go.mod, requirements.txt, *.csproj), RED cannot
         declare one and the phase round trip is yours to plan for
       * FOR EVERY EXISTING EXPORT WHOSE SIGNATURE THIS STORY CHANGES: every
         caller, source and test, grep-listed here before dispatch. RED cannot
         find these itself - the old signature still exists during RED, so a
         caller of it still compiles and is absent from RED's typecheck. One
         such file went missing and took 25 tests with it, silently, at GREEN. -->

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`, `docs/backlog/stories/HARNESS-097.md`

**Oracle partition.** Both criteria are mechanical: pin the exact lines and
the exit status, invent nothing. Settled facts to read out, measured by the PO
on this host (Git for Windows bash) on 2026-11-06: `mkdir -p` over an existing
plain file exits 1 (`mkdir: cannot create directory 'plain': File exists`),
and a redirect into `plain/x` exits 1 with `Not a directory`. So a plain file
at the path is a sufficient fixture for "the directory cannot be created", and
it needs no permission tricks, which would not survive a Windows host anyway.

**The defect, by line, in `scripts/check-boundaries.sh` at release 110
(`dd97d6b`).** Line 27 `fail=0`; lines 28-29 the HARNESS-089 comment and the
bare `mkdir -p "$ROOT/.claude/state/check-boundaries"`; line 30 `cp=`/`dp=`;
line 31 the `trap 'rm -rf "$ROOT/.claude/state/check-boundaries/"*-$$.*' EXIT`;
lines 32-34 define `note`, `problem`, `ok`. The comment at 322-325 ends "Each
copy is read into a variable and fed by here-string: `git show | section -`
was a pipeline into an early-exiting awk (see has_content above)". Line 327
`local f="$1" txt cph rev ...`; line 362 `crit_label=""; crit_txt=""`.

**The fix (GREEN), and only this:**

- **Finding 1.** The `mkdir -p` refuses on failure, through `problem` so the
  prefix is the one spelling (`FAIL  `), then `exit 1`:
  `mkdir -p "$ROOT/.claude/state/check-boundaries" || { problem "cannot
  create .claude/state/check-boundaries (something is in the way, a plain
  file at that path for instance): every story copy is read from a scratch
  file there, so without it the criteria would be judged against nothing";
  exit 1; }`. `problem` is defined at line 33, after the call, so the three
  helper definitions (`note`, `problem`, `ok`, lines 32-34) move up to sit
  right after `fail=0` and before the HARNESS-089 comment. The `exit 1` is
  deliberate rather than `fail=1` and carrying on: nothing after that line can
  read its evidence. The trap is set after the `mkdir` succeeds, as now; on
  the refusal path there is nothing to clean up and no trap has been set.
  Exact wording is GREEN's; the needle RED pins is the path
  `.claude/state/check-boundaries` on a `FAIL` line.
- **Finding 2.** The comment's last sentence becomes, in substance: each copy
  is written to the scratch file `$cp` and read from there, because a
  here-string of a story copy blocked on Cygwin bash near 64 KiB
  (HARNESS-089) and `git show | section -` was a pipeline into an
  early-exiting awk (see `has_content` above). `txt` leaves the `local` on
  line 327; `crit_txt=""` leaves line 362, leaving `crit_label=""`. No test
  demands this and none is written for it: it is a comment and two names
  nothing reads, and the existing suite staying green is its whole cover.
- **Nothing else in the script changes.** Not the trap, not the scratch
  paths, not the suppression block, not `section`/`frontmatter_value`.
- **`.claude/harness/VERSION`** goes 110 to 111 in GREEN, as HARNESS-089's
  GREEN took it 109 to 110. The script's own stamp rule fires only off story
  branches, so this is the convention a vendored copy depends on, not a
  refusal to satisfy.

**AC-1 and AC-2 fixtures (RED), in `boundaries.test.sh`.** One new describe
marked HARNESS-097, placed after the two HARNESS-089 describes (after the
`here_string_sources` block, before "a BLOCKED gate can reach REVIEW").
It reuses what is there: `story_on_branch` (a `T-1` story at REVIEW on a fresh
branch) or the `crit_*` helpers, whichever gives a run that reaches the
criteria check; `run_boundaries` (sets `$out` and `$rc`); `refused` (asserts
the needle AND a non-zero exit, which is both halves of AC-1's refusal);
`assert_not_contains`; `assert_eq`. The sequence:

1. Precondition: `rm -rf "$FIX/.claude/state/check-boundaries"`, then
   `: > "$FIX/.claude/state/check-boundaries"`. `make_fixture` creates
   `$FIX/.claude/state`, so the parent exists.
2. `run_boundaries`. AC-1: `refused "..." ".claude/state/check-boundaries"`,
   and `assert_not_contains "..." "acceptance criteria" "$out"`. On release
   110 both are red: the first because the exit is the fixture's ordinary one
   with no such FAIL line, the second because the `ok    acceptance criteria
   changed, with an ## Amendments entry` line is there. RED pastes both.
3. Remove the plain file (`rm -f`), `run_boundaries` again. AC-1's twin: the
   ordinary criteria line is back (`assert_contains` on `acceptance
   criteria`). AC-2: `[ -d "$FIX/.claude/state/check-boundaries" ]` and
   `ls -A "$FIX/.claude/state/check-boundaries"` prints nothing, asserted
   with `assert_eq` against the empty string so a failure names what was
   left. Green on arrival; DV-1 earns it.
4. The plain file is gone before the describe ends, or every later run in the
   suite is refused for AC-1's reason. Say so in a comment at the cleanup.

If the fixture's untracked plain file trips any other rule of the script,
that is a finding to record in the handoff, not a reason to ignore the path
in the fixture: AC-1's refusal is to be the mkdir one and no other, which the
needle already pins.

**The narrowest command.** The `boundaries` suite has no per-case filter and
takes about 45 minutes on this Windows host (HARNESS-089's GREEN run:
`boundaries settings`, 2968 s). So RED, GREEN and GATES work on a subset: a
copy of `boundaries.test.sh` cut down to the `_lib.sh` preamble, the helpers
the HARNESS-097 describe uses and that describe, written under
`.claude/state/` (ignored, never committed; HARNESS-083 and HARNESS-089 did
the same, as `floors.conf` records), and run as `bash <that file>`. The full
suite runs once per phase, through `bash scripts/attest.sh -- bash
scripts/selftest.sh boundaries`, dispatched as `/advance-story` says for long
runs, and its count is what `floors.conf` records. Both mutations below run
against the subset.

**Floors.** `boundaries` rises from 538 by the number of assertions the new
describe adds; RED records the measured full-suite count in `floors.conf`
with the usual comment and in `selftest.test.sh`'s table (`boundaries 538`
today). `sigpipe` stays 91.

**Planned return to RED (R-1), and why.** `sigpipe.test.sh` pins three
`scripts/check-boundaries.sh` lines by NUMBER in `DISCARDED` (lines 574-576:
`:399:res=$(printf`, `:438:rec=$(printf`, `:630:ph_at="$(git show`), with a
freshness check (C-5) that fails as a stale fixture when a line moves. Any net
line added or removed above line 399 by GREEN's edits moves all three. GREEN
cannot edit a test, so GREEN runs `bash scripts/selftest.sh sigpipe` (about
four minutes) on its committed tree and pastes C-5's red into
`## Regressions` as R-1; the story then returns to RED once, with one remit:
re-pin those three numbers, as HARNESS-089's R-1 did. The red that earns the
re-pin is GREEN's own sigpipe run and the green after it is the same suite.
RED's first pass does **not** touch `sigpipe.test.sh`: the numbers are not
known until GREEN has written the lines. If GREEN's edits net to zero lines
above 399, sigpipe stays green, R-1 is not needed, and `## Notes` records the
sigpipe run that shows it. The comment headers at `sigpipe.test.sh` 1127,
1174, 1202 and 1232 that name check-boundaries lines are prose and stay.

**Callers.** No signature changes. `note`, `problem` and `ok` keep their
shapes; moving their definitions up changes no call. `section`,
`frontmatter_value`, `suppression_hits`, `has_content` are untouched.

**RED's amendments to this block (2026-11-06, test-developer), with reasons.**
GREEN builds what this paragraph says where it differs from the fixture
sequence above.

- **The AC-1 needle is a whole `FAIL  ` line, not `refused` with the bare
  path.** On release 110 bash's own redirect error,
  `scripts/check-boundaries.sh: line 334: <FIX>/.claude/state/check-boundaries/copy-<pid>.md: Not a directory`,
  goes to stderr, which `run_boundaries` captures (`2>&1`). So
  `refused "..." ".claude/state/check-boundaries"` has its needle satisfied by
  the defect itself; and after the fix `mkdir`'s own `cannot create directory
  '<FIX>/.claude/state/check-boundaries': File exists` would satisfy it too.
  The assertion is `grep -E '^FAIL  .*\.claude/state/check-boundaries'` on
  `$out`, non-empty, which only `problem`'s prefix can produce. Observed on
  this host, in the red pasted in the handoff.
- **The non-zero exit is its own assertion, on a fixture whose ordinary exit
  is 0.** Every `story_on_branch`/`crit_commit` fixture exits 1 whatever the
  scratch directory does: a feature story at REVIEW is refused by 3e (no
  `## Gate results`), and at any other phase by "a PR should be opened from
  REVIEW or DONE" (observed: a GREEN fixture printed that FAIL and exited 1).
  So the fixture is a **spike at REVIEW** that changes no source (HARNESS-081's
  device): base copy `T-43` at PLANNED on main via `crit_base`, branch
  `story/T-43-fixture` via `crit_branch`, the branch's story written directly
  as `type: spike`, `phase: REVIEW`, the same `- **AC-1** - criteria v1.` and
  an `## Amendments` entry. The twin asserts that fixture exits 0, so the
  non-zero exit with the plain file in place is the refusal's own. On release
  110 the plain-file run exits **0** with `ok    acceptance criteria changed,
  with an ## Amendments entry` - the reviewer's observation, reproduced.
- **"No line containing `acceptance criteria`" is matched case-insensitively**
  (`grep -i`), so the `## Acceptance criteria differ` refusal counts too, as
  the AC says. GREEN's refusal text must therefore not contain "acceptance
  criteria" in any case; the wording proposed above does not.
- **The twin's ordinary line is `ok    acceptance criteria unchanged since
  main`**, pinned as a whole line (`whole_line`), and its exit 0.
- **DV-2 reads against these three AC-1 assertions**, where its text says
  `refused` and `assert_not_contains`: "a FAIL line names that path", "the
  run exits non-zero" (red as `actual: 0`) and "no line mentions acceptance
  criteria" (red naming the `ok    acceptance criteria changed, with an
  ## Amendments entry` line). The red RED pasted in the handoff is exactly
  that shape.

**RED may amend any block above in place, with a reason; GREEN builds what the amended block says.**

## Deferred verifications

<!-- REQUIRED when a verification this story depends on provably cannot run in
     the phase that wants it; omit the section otherwise. Written by the Lead PO
     at PLANNED, and the phase that owns it pastes the result in.
     The case this exists for: a negative control for a round trip, a threshold
     or a codec has to break the real implementation to mean anything, and in
     RED there is no implementation to break. RED naming the control and saying
     it could not run it is the honest answer; RED claiming a verification it
     did not do is the failure. One block per entry:
       * what it verifies, as a falsifiable condition - "with one field dropped
         from the encoder, AC-1's property test MUST fail"
       * why the phase that wants it cannot run it
       * THE PHASE THAT OWNS IT, declared as `Owner: GATES` (or RED, GREEN,
         REVIEW). check-boundaries.sh refuses a PR
         whose block names no phase
       * the RESULT, pasted, once that phase runs it: what was mutated, what
         failed, and that the file was restored - or the word WAIVED with the
         reason. check-boundaries.sh refuses a PR that has neither. A result
         counts only as a block: a line beginning with three backticks or
         three tildes (a fence), or a line indented by exactly four spaces.
         Prose does not count, nor inline code in backticks, nor a tab, nor
         anything inside an HTML comment
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

**DV-1 (AC-2, a test written against existing code; rules.md "earn it by
mutation"). Owner: RED.** With the `trap ... EXIT` line deleted from
`scripts/check-boundaries.sh` by
`bash scripts/mutate.sh scripts/check-boundaries.sh '<expr deleting the one line matching ^trap .*check-boundaries.*EXIT$>' -- bash <the HARNESS-097 subset>`,
AC-2's empty-directory assertion **must** fail, and its `actual:` must name a
`copy-<pid>.md`; with the file restored (`mutate.sh` verifies it byte for
byte) it passes again. RED owns it because the trap exists before this story
begins, so the assertion is green on its first run and would be green if it
asserted nothing; `mutate.sh` is sanctioned in every phase; and the handoff
has to list this assertion as passed-on-arrival with the probe that earns it.
Paste the red line, the restore line, and the green after.

*Result (RED, 2026-11-06, test-developer, this Windows host, local).* Run as
`VERBOSE=1 bash scripts/mutate.sh scripts/check-boundaries.sh '/^trap .*check-boundaries.*EXIT$/d' -- bash .claude/state/harness-097-subset.sh`.
The expression matches exactly one line (line 31; `grep -n` found only it).
The output below is mutate.sh's verbatim, with the indented echo of the
fixture's own check-boundaries lines inside AC-1's first `actual:` filtered
out (`grep -v`) for length; nothing else removed. AC-2's emptiness assertion
goes red naming `copy-4385.md`; the three AC-1 reds are RED's ordinary red
(the fix does not exist yet), not caused by the mutation.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by /^trap .*check-boundaries.*EXIT$/d) ===
  31 - trap 'rm -rf "$ROOT/.claude/state/check-boundaries/"*-$$.*' EXIT

=== mutate: running bash .claude/state/harness-097-subset.sh ===

  no scratch directory, no verdict; the scratch directory is left empty (HARNESS-097)
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, a FAIL line names that path
         expected a line starting 'FAIL  ' that names .claude/state/check-boundaries
         actual:   mkdir: cannot create directory '/tmp/tmp.dOSw4bNb4W/.claude/state/check-boundaries': File exists
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, no line mentions acceptance criteria
         expected: 
         actual:   ok    acceptance criteria changed, with an ## Amendments entry
    ok   AC-1 twin: with the plain file gone, the same fixture reports its criteria unchanged since main
    ok   AC-1 twin: with the plain file gone, the same fixture exits 0
    ok   AC-2: after a run, .claude/state/check-boundaries exists as a directory
    FAIL AC-2: after a run, .claude/state/check-boundaries is empty
         expected: 
         actual:   copy-4385.md

boundaries-097-subset: 3 passed, 4 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/zealous-hermann-1ed224/.claude/state/mutations/scripts_check-boundaries.sh.20261106T062130Z.4213.bak) ===
  31: trap 'rm -rf "$ROOT/.claude/state/check-boundaries/"*-$$.*' EXIT
```

The green after, same subset, file restored (`git status --short scripts/`
printed nothing): AC-2 is green again; AC-1 stays red until GREEN.

```
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, a FAIL line names that path
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, the run exits non-zero
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, no line mentions acceptance criteria
    ok   AC-1 twin: with the plain file gone, the same fixture reports its criteria unchanged since main
    ok   AC-1 twin: with the plain file gone, the same fixture exits 0
    ok   AC-2: after a run, .claude/state/check-boundaries exists as a directory
    ok   AC-2: after a run, .claude/state/check-boundaries is empty
boundaries-097-subset: 4 passed, 3 failed
```

Only `copy-<pid>.md` is left behind, not `diff-<pid>.txt`: this fixture's
run never writes `$dp` (no RED-phase manifest or GREEN/GATES source commit
to diff). AC-2 asserts "empty", so a stray `diff-*.txt` would fail it too;
the mutation simply cannot show one on this fixture.

**DV-2 (AC-1, defect put back; the story's central claim). Owner: GATES.**
With the exit check removed from the `mkdir -p` line, restoring release 110's
bare `mkdir -p "$ROOT/.claude/state/check-boundaries"` by
`bash scripts/mutate.sh scripts/check-boundaries.sh '<expr>' -- bash <the HARNESS-097 subset>`
(name the line GREEN wrote), AC-1 **must** go red on both halves: `refused`
reports no FAIL line naming the path and an exit that is the fixture's
ordinary one, and the `assert_not_contains` reports the
`ok    acceptance criteria changed, with an ## Amendments entry` line, which
is the reviewer's original observation reproduced. The twin and AC-2 stay
green. GATES owns it because the check does not exist in RED (that absence is
RED's red, pasted in the handoff) and the mutation is of GREEN's line. Paste
the red lines and the restore line.

**Result (GATES, 2026-11-06, run by the orchestrator, Fable 5.1), at GREEN's
commit `07d121e`.** The expression replaced GREEN's line 32 with release
110's bare `mkdir -p`; the subset went red on exactly the three AC-1
assertions, the twin and AC-2 stayed green (`4 passed, 3 failed`), and the
file was restored and verified. Pasted from the run:

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s|^mkdir -p "\$ROOT/.claude/state/check-boundaries" \|\| { problem .*; exit 1; }$|mkdir -p "$ROOT/.claude/state/check-boundaries"|) ===
  32 - mkdir -p "$ROOT/.claude/state/check-boundaries" || { problem "cannot create .claude/state/check-boundaries (...)"; exit 1; }
  32 + mkdir -p "$ROOT/.claude/state/check-boundaries"

=== mutate: running bash .claude/state/harness-097-subset.sh ===
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, a FAIL line names that path
         expected a line starting 'FAIL  ' that names .claude/state/check-boundaries
         actual:   mkdir: cannot create directory '/tmp/tmp.ltoN7xVCRJ/.claude/state/check-boundaries': File exists
           spike story; gate record not required
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, no line mentions acceptance criteria
         expected: 
         actual:   ok    acceptance criteria changed, with an ## Amendments entry
boundaries-097-subset: 4 passed, 3 failed

=== mutate: command exited 1; restored (verified byte-for-byte against .claude/state/mutations/scripts_check-boundaries.sh.20261106T143225Z.1935.bak) ===
  32: mkdir -p "$ROOT/.claude/state/check-boundaries" || { problem "cannot create .claude/state/check-boundaries (...)"; exit 1; }
```

After the restore: `boundaries-097-subset: 7 passed, 0 failed`;
`bash scripts/mutate.sh --check`: no stranded mutation.

Nothing beyond these two: rules.md "Mutation work per story" is the budget,
and exhaustive earning of HARNESS-089's assertions belongs to
`/audit-mutations`.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-097` from `.claude/harness/models.conf`.
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
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
- RED, test-developer, claude-opus-5-5 (Opus 5.5; as planned, no override)
- GREEN, feature-developer, claude-opus-5-5 (Opus 5.5; as planned, no override)
- GATES (DV-2), orchestrator lead-po, claude-fable-5-1 (Fable 5.1; ran DV-2 itself with mutate.sh)
- GATES (full gates), feature-developer, claude-opus-5-5 (Opus 5.5; as planned, no override)
- GATES (diff review), feature-developer (fresh), claude-opus-5-5 (Opus 5.5; as planned, no override)
- GATES (self-test --changed), feature-developer, claude-opus-5-5 (Opus 5.5; as planned, no override)

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Any other change to `scripts/check-boundaries.sh`: the here-string handling
  (HARNESS-089, done), the suppression block, `section`, `frontmatter_value`,
  `suppression_hits`, `has_content`, or any refactor beyond finding 2's
  comment and two dead names.
- Tolerating a plain file by falling back to another directory or `$TMPDIR`.
  Refusing is the decision: a scratch location chosen at run time is what
  HARNESS-089 excluded, and `$TMPDIR` is unset in some of these shells.
- Renaming or relocating the scratch directory or its files; the
  `.claude/state/README.md` row stays as it is.
- No new gate, no `project.conf` change, no `required_gates`.
- A test for finding 2. It has no behaviour; the existing suite is its cover,
  and the story says so rather than inventing a source-text assertion for a
  comment.
- Pinning the trap's quoting or its `$$` separator: the diff review found
  those sound.
- The `sigpipe.test.sh` comment headers that name check-boundaries line
  numbers (1127, 1174, 1202, 1232): prose, untouched, as in HARNESS-089.
- Exhaustive earning of HARNESS-089's assertions, or any mutation beyond
  DV-1 and DV-2: `/audit-mutations`.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One describe, `no scratch directory, no verdict; the scratch directory is left
empty (HARNESS-097)`, in `.claude/tests/boundaries.test.sh` after the two
HARNESS-089 describes and before "a BLOCKED gate can reach REVIEW". Level:
integration - the real `scripts/check-boundaries.sh`, copied into a real
two-branch fixture repository by `make_project_fixture`, run through
`run_boundaries`. That is the cheapest level that can see either criterion:
both are about what the whole script prints and leaves on disk.

Fixture: `T-43`, base copy at PLANNED on main (`crit_base`), branch
`story/T-43-fixture` (`crit_branch`) holding the story as a **spike at
REVIEW** with the same criteria and an `## Amendments` entry - the one shape
whose ordinary exit is 0 and whose empty-baseline verdict is the reviewer's
`ok ... changed`. See the Contract's RED amendments for why not
`story_on_branch`.

| # | Assertion | AC | On release 110 |
|---|---|---|---|
| 1 | with a plain file at the path, a line matching `^FAIL  .*\.claude/state/check-boundaries` exists | AC-1 | red |
| 2 | with the plain file, `$rc` is non-zero | AC-1 | red (`actual: 0`) |
| 3 | with the plain file, `grep -i 'acceptance criteria'` over `$out` is empty | AC-1 | red (names the `ok ... changed` line) |
| 4 | plain file gone: `ok    acceptance criteria unchanged since main` is a whole line, once | AC-1 twin | green |
| 5 | plain file gone: `$rc` is 0 | AC-1 twin | green |
| 6 | after that run `.claude/state/check-boundaries` is a directory | AC-2 | green |
| 7 | after that run `ls -A` on it is empty (`assert_eq ""`) | AC-2 | green on arrival; earned by DV-1 |

Edges: the "cannot create" edge is the plain file (the only one portable to a
Windows host); "any status" in AC-2 is covered by the twin's exit-0 run, and
the trap is `EXIT` so a non-zero run takes the same path. Finding 2 has no
test (Out of scope). The plain file is removed before the twin run and before
the describe ends, with a comment saying why.

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

Written by the test-developer (claude-opus-5-5), 2026-11-06, on this Windows
host (Git for Windows bash). Every timing below is local; nothing here came
from CI.

**Commands.**

- Narrowest, for iterating and for DV-1/DV-2: `bash .claude/state/harness-097-subset.sh`
  (about 5 s). It is gitignored and never committed: lines 1-108 of
  `boundaries.test.sh` (preamble and helpers through `whole_line`, with the
  `_lib.sh` source path rewritten to `../tests/_lib.sh`), lines 335-375 (the
  `crit_*` helpers and `crit_main_before`), the HARNESS-097 describe verbatim,
  and `summary boundaries-097-subset`. Rebuild it the same way if it is gone:

      W=$PWD; T=.claude/tests/boundaries.test.sh
      s=$(grep -n 'describe "no scratch directory' $T | cut -d: -f1); e=$(grep -n 'describe "a BLOCKED gate' $T | cut -d: -f1)
      { sed -n 1,108p $T | awk '{ if ($0 == ". \"$(dirname \"${BASH_SOURCE[0]}\")/_lib.sh\"") print ". \"$(dirname \"${BASH_SOURCE[0]}\")/../tests/_lib.sh\""; else print }'
        sed -n 335,375p $T; sed -n "$((s-1)),$((e-2))p" $T; printf '\nsummary boundaries-097-subset\n'; } > .claude/state/harness-097-subset.sh

- Full suite, once: `bash scripts/attest.sh -- bash scripts/selftest.sh boundaries`
  (1049 s here this time - faster than the 45 min HARNESS-089 saw).
- `bash scripts/attest.sh -- bash scripts/gates.sh --fast`.

**Attest records.**

    run:      2026-11-06T06:24:37Z
    command:  bash scripts/selftest.sh boundaries
    tree:     2162a2172b6fe75dfe6d5f8d68219e62c890dcd8
    after:    2162a2172b6fe75dfe6d5f8d68219e62c890dcd8
    status:   ok
    exit:     1
    duration: 1049s
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261106T062437Z.14898.log

    run:      2026-11-06T06:42:38Z
    command:  bash scripts/gates.sh --fast
    tree:     2162a2172b6fe75dfe6d5f8d68219e62c890dcd8
    after:    2162a2172b6fe75dfe6d5f8d68219e62c890dcd8
    status:   ok
    exit:     0
    duration: 1s
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261106T064238Z.104884.log

`gates.sh --fast` ran nothing: every gate in `project.conf` is UNCONFIGURED
(BOOTSTRAPPED=no) and `mutation` is ON REQUEST, so its exit 0 says nothing
about these tests, as HARNESS-089 recorded. The suite that judges this story
is `selftest.sh boundaries`, above.

**The red, verbatim from the full-suite log** (lines 27-46; line 40 is
`           spike story; gate record not required`, part of the first
`actual:`). These are the only FAIL lines in the whole suite:

```
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, a FAIL line names that path
         expected a line starting 'FAIL  ' that names .claude/state/check-boundaries
         actual:   mkdir: cannot create directory '/tmp/tmp.OSjvx12gPt/.claude/state/check-boundaries': File exists
         ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-43 is in REVIEW
         ok    branch matches the story's frontmatter
         scripts/check-boundaries.sh: line 334: /tmp/tmp.OSjvx12gPt/.claude/state/check-boundaries/copy-23590.md: Not a directory
         awk: fatal: cannot open file `/tmp/tmp.OSjvx12gPt/.claude/state/check-boundaries/copy-23590.md' for reading: Not a directory
         scripts/check-boundaries.sh: line 376: /tmp/tmp.OSjvx12gPt/.claude/state/check-boundaries/copy-23590.md: Not a directory
         awk: fatal: cannot open file `/tmp/tmp.OSjvx12gPt/.claude/state/check-boundaries/copy-23590.md' for reading: Not a directory
         ok    acceptance criteria changed, with an ## Amendments entry
           spike story; gate record not required
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL AC-1: with a plain file at .claude/state/check-boundaries, no line mentions acceptance criteria
         expected: 
         actual:   ok    acceptance criteria changed, with an ## Amendments entry
...
boundaries: 542 passed, 3 failed
FAIL boundaries  did 542 units of work, below the floor of 545 in .claude/tests/floors.conf
```

Why it is the right failure: the run reaches every check, the `mkdir -p`
failure is ignored, both `git show > "$cp"` redirects fail with `Not a
directory`, and the criteria are judged against an empty baseline - the
reviewer's `ok    acceptance criteria changed, with an ## Amendments entry`,
with exit **0**: a PR CI would have merged on evidence it never read. The
twin (same fixture, directory creatable) prints `ok    acceptance criteria
unchanged since main` and exits 0, so the red is the directory's.
542 + 3 = **545 executed** = 538 before + 7 new; the floor is raised to
545, and boundaries sits 3 below it until GREEN, as expected in RED.

**Files touched.**

- `.claude/tests/boundaries.test.sh` - the HARNESS-097 describe (7 assertions;
  AC-1 3, AC-1 twin 2, AC-2 2 - see `## Test plan` for one line each).
- `.claude/tests/floors.conf` - `floor | boundaries | 538` -> `545`, with the
  HARNESS-097 comment at the end of the file.
- `.claude/tests/selftest.test.sh` - the table row `boundaries 538` -> `545`.
- `docs/backlog/stories/HARNESS-097.md` - Contract (RED's amendments), DV-1's
  result, Model guidance Resolved line, Test plan, this Handoff.
- Not touched: `scripts/check-boundaries.sh` (only through `mutate.sh`,
  restored and verified), `.claude/tests/sigpipe.test.sh` (R-1, as planned).
- Scratch, ignored: `.claude/state/harness-097-subset.sh`.

**What the tests pin, exactly (GREEN's surface - there are no exports; this
is a script's output).**

- With a plain file at `$ROOT/.claude/state/check-boundaries`, at least one
  stdout/stderr line must match the ERE `^FAIL  .*\.claude/state/check-boundaries`
  - i.e. printed by `problem` (prefix `FAIL` + two spaces) and containing the
  repository-relative path `.claude/state/check-boundaries`. The absolute
  `$ROOT/...` path also matches, since it contains the relative one.
- That run exits non-zero.
- That run prints **no line containing `acceptance criteria` in any case**.
  So the refusal message must not say "acceptance criteria" (the Contract's
  proposed wording says "the criteria", which is fine), and the script must
  stop before 3d - the Contract's `exit 1` does.
- Directory creatable: the run prints the whole line
  `ok    acceptance criteria unchanged since main` exactly once and exits 0 on
  this spike fixture - so nothing GREEN adds may print a `FAIL` or change the
  status on an ordinary run.
- After that run `.claude/state/check-boundaries/` exists and is empty.
- **Not constrained:** the rest of the refusal wording; whether `mkdir`'s
  own stderr line also appears; whether `note`/`problem`/`ok` move (the
  Contract says they do); what else is printed before the refusal (lines from
  checks before the mkdir would be allowed, though there are none today).

**Passed on arrival, and what earns it.** Assertions 4-7 (the twin and AC-2)
are green on release 110. AC-2's emptiness assertion (7) is the one that
pins a pre-existing behaviour and is earned by **DV-1**, run in RED: with the
`trap ... EXIT` line deleted by `mutate.sh`, it went red naming
`copy-4385.md`; restored, verified byte for byte, green again. Output in
`## Deferred verifications`, DV-1. Assertion 6 (is a directory) is a
precondition of 7 and is not separately earned. The twin assertions 4-5 are
controls, not claims about the fix: they are what makes 2 and 3 say
something about the directory rather than the fixture.

**Controls, measured** (by running the subset and the full suite against
the shipped release-110 script; the suite does not fail at import, so these
did execute):

| Control | Expected after GREEN | Measured on release 110 |
|---|---|---|
| fixture's ordinary exit (twin, assertion 5) | 0 | 0 |
| fixture's ordinary criteria line (twin, assertion 4) | `ok    acceptance criteria unchanged since main`, once | same, once |
| plain-file run exit (assertion 2) | non-zero | 0 |
| plain-file run, lines matching `acceptance criteria` (-i) (assertion 3) | none | 1: `ok    acceptance criteria changed, with an ## Amendments entry` |
| plain-file run, lines matching `^FAIL  .*\.claude/state/check-boundaries` (assertion 1) | at least 1 | 0 (the path appears 5 times, all in `mkdir:`/bash/awk stderr lines, none a FAIL) |
| DV-1: trap deleted, `ls -A` after run (assertion 7) | red, names `copy-<pid>.md` | `copy-4385.md` |

**Discovered.**

1. `refused` with the bare path, as the Contract first proposed, has a needle
   the defect satisfies: bash's redirect error and awk's `cannot open file`
   both print `.../.claude/state/check-boundaries/copy-<pid>.md` on stderr,
   which `run_boundaries` captures. Hence the whole-`FAIL`-line needle
   (Contract, RED's amendments).
2. Every feature-story fixture exits 1 whatever this story does (3e at
   REVIEW; "a PR should be opened from REVIEW or DONE" at GREEN, observed), so
   the non-zero-exit half of AC-1 needed the spike-at-REVIEW fixture.
3. The untracked plain file trips no other rule: `ok    harness state not
   tracked` and every other pre-criteria check print `ok` with it in place.
4. sigpipe: not run in RED (R-1 belongs to GREEN). Moving `note`,
   `problem`, `ok` up nets zero lines; the `mkdir ... || { ...; }` refusal
   adds lines above 399 unless it stays on the one line it replaces, and
   finding 2 removes none (it edits lines in place), so expect R-1.
5. `check-sigpipe.sh` and `check-grep-count.sh` are clean over the edited
   suite (62 files, 0 findings).

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return:
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

Fresh `feature-developer` dispatch (claude-opus-5-5, Opus 5.5, as declared; no
override), `diff-review` skill, 2026-11-06, over `git diff origin/main...HEAD`
after main (HARNESS-090, #182) was merged in as `fdb9e51`. It changed no file.

What this change does: `note`/`problem`/`ok` move above the scratch-directory
`mkdir -p`, which now refuses on failure (a `FAIL  ` line naming
`.claude/state/check-boundaries`, exit 1) instead of judging the criteria
against an empty baseline; the `criteria_baseline` comment is corrected and the
dead `txt`/`crit_txt` dropped. One new describe pins the refusal, its twin and
an empty scratch directory. Floors 538 -> 545; VERSION -> 112.

Checked, no findings:

- Helpers defined in time: nothing between `. lib.sh` (line 24) and lines
  27-29 calls `note`/`problem`/`ok`; `lib.sh` neither defines nor calls them.
- The `exit 1` path: no trap set and no scratch file written yet, so nothing
  to clean up; the script is `set -uo pipefail` without `-e`, so the `||`
  branch is the only reaction; `mkdir`'s own stderr line still prints, harmless.
- Normal CI runs: `.claude/state/.gitkeep` and `README.md` are committed, and
  `mkdir -p` creates parents anyway; the refusal fires only when something is
  in the way or the filesystem is read-only, where refusing is correct.
- The needle `^FAIL  .*\.claude/state/check-boundaries` matches only
  `problem`'s prefix, never `mkdir`'s stderr or bash's redirect error (DV-2's
  red shows it); the message contains no "acceptance criteria" in any case.
- Fixture cleanup: `_bad`/`assert_eq` carry on and the suite is not `set -e`,
  so the `rm -f` of the plain file always runs before the twin; `reset --hard`
  would not remove an untracked file, which is why the explicit `rm -f` matters.
- sigpipe pins: net zero lines above 399; 399/438/630 still hold
  `res=$(printf`, `rec=$(printf`, `ph_at="$(git show`. R-1 not needed.
- floors.conf merge keeps HARNESS-090's block and appends HARNESS-097's;
  `boundaries 545` matches `selftest.test.sh`; `selftest 366` unchanged.
- VERSION 112 is right: 111 is HARNESS-090's on main.
- The new comment matches the code; neither `txt` nor `crit_txt` is read.
- `.claude/state/README.md`'s `check-boundaries/*` row says "scratch for a
  `git show` result", narrower than what the directory holds (story copies,
  `diff-*`); pre-existing and out of scope, not raised as a finding.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-06T14:44:26Z
    commit: fdb9e51
    tree:   a7b1aec694c4a50e773ad60df50fca70a12c2026
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

- Cut 2026-11-06 by the PO (Fable 5.1) from HARNESS-089's `## Diff review`.
  PR #181 was merged at 2026-11-06T05:31Z and HARNESS-089 is DONE on `main`
  at `dd97d6b`, so `depends_on` is satisfied from the start.
  `scripts/check-boundaries.sh` on `main` is byte-identical to PR #181's
  head: `git diff --stat origin/main..origin/story/HARNESS-089-...` lists
  only the story file.
- Reproduced at PLANNED, by the PO, on this host: `touch plain; mkdir -p
  plain` exits 1 with `mkdir: cannot create directory 'plain': File exists`;
  `: > plain/x` exits 1 with `Not a directory`. That is finding 1's premise.
  The reviewer's downstream observation (the `ok    acceptance criteria
  changed, with an ## Amendments entry` line) is not reproduced at PLANNED;
  AC-1's red in RED is where it is, and DV-2 puts it back at GATES.
- **Suite cost, for every phase.** `bash scripts/selftest.sh boundaries` is
  about 45 minutes on this Windows host. Do not run it per edit or per
  mutation: work on the subset the Contract describes, and run the full suite
  once per phase through `attest.sh`, dispatched as a long run per
  `/advance-story`. `sigpipe` is about four minutes and is the run GREEN
  needs for R-1.
- `bash scripts/plan.sh conflicts` at PLANNED (2026-11-06): HARNESS-097
  is `CONFLICT` with every other startable story (HARNESS-090, 091, 092, 093,
  096), on the same three paths each time: `.claude/harness/VERSION`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`. Those are
  the bookkeeping files every harness story writes, so every pair among the
  six conflicts the same way; `--pairs` prints nothing, no `UNKNOWN`, no
  `DRIFT`. One story at a time, in the one worktree.

- **RED verified by the orchestrator (2026-11-06, Opus 5.5).** Read the new
  describe (`boundaries.test.sh` 716-797). `attest.sh check` answered `fresh`
  for both `bash scripts/selftest.sh boundaries` (exit 1, 1049 s, log
  `20261106T062437Z.14898.log`) and `bash scripts/gates.sh --fast` (exit 0,
  0 ran, 5 unconfigured), so neither was re-run. The log's only `FAIL` lines
  are AC-1's three assertions plus the expected floor line (`542 units of
  work, below the floor of 545`); the twin and AC-2 are green.
  `mutate.sh --check` is clean.

- **GREEN, by the feature-developer (2026-11-06, claude-opus-5-5, no override).**
  Handoff GREEN -> GATES.
  - **What changed.** `scripts/check-boundaries.sh`: `note`, `problem`, `ok`
    now sit right after `fail=0`. The `mkdir -p` now ends in
    `|| { problem "cannot create .claude/state/check-boundaries (something is
    in the way, a plain file at that path for instance): every story copy is
    read from a scratch file there, so without it the criteria would be judged
    against nothing"; exit 1; }`, still on one line, and the trap still
    follows it. The `criteria_baseline` comment paragraph is reflowed to the
    same six lines, and its last sentence now says each copy is written to
    `$cp` and read from there (the HARNESS-089 here-string hang, plus the
    early-exiting-awk pipeline). `txt` is gone from its `local`, and
    `crit_txt=""` is gone; nothing read either name (grep finds no use).
    `.claude/harness/VERSION`: 110 -> 111. Nothing else changed.
  - **Net line delta above old line 399: 0** (the whole file is unchanged in
    length, 13+/13- by `git diff --stat`). `sed -n '399p;438p;630p'` still
    prints `res=$(printf`, `rec=$(printf`, `ph_at="$(git show`. So **R-1 is
    not needed**: the sigpipe run below is green with `sigpipe.test.sh`
    untouched. RED does not need to re-pin anything.
  - **Controls, measured against the shipped script** (the subset, with
    `rc`/`out` printed after each `run_boundaries`):

        control                                       expected     measured
        twin exit (5)                                 0            0
        twin criteria line (4)                        once         `ok    acceptance criteria unchanged since main`, 1 line
        plain-file run exit (2)                       non-zero     1
        plain-file run, -i `acceptance criteria` (3)  none         0 lines
        plain-file run, `^FAIL  .*check-boundaries` (1) >= 1       1 (the problem line; mkdir's own `File exists` on stderr above it)
        DV-1 trap deleted, `ls -A` (7)                red, names   red: `actual:   copy-9935.md`; restored, verified byte-for-byte

    All match RED's table. One benign observation: with the plain file in
    place the refusal comes before every other check, so its output is just
    mkdir's stderr line plus the FAIL line. AC-1 allows that.
    `bash .claude/state/harness-097-subset.sh`: `7 passed, 0 failed`.
  - **Attest records** (each run on its own in this worktree):

        run:      2026-11-06T06:58:00Z
        command:  bash scripts/selftest.sh boundaries
        tree:     e50de20d51f7482a27f7bf6006de4269d7c60a47
        exit:     0
        duration: 1100s
        last:     1 harness suite(s) passed.
        log:      .claude/state/attest-logs/20261106T065800Z.10916.log
        (boundaries: 545 passed, 0 failed; floor 545 met)

        run:      2026-11-06T07:16:42Z
        command:  bash scripts/selftest.sh sigpipe
        tree:     e50de20d51f7482a27f7bf6006de4269d7c60a47
        exit:     0
        duration: 144s
        last:     1 harness suite(s) passed.
        log:      .claude/state/attest-logs/20261106T071642Z.78508.log
        (sigpipe: 91 passed, 0 failed; floor 91 met)

        run:      2026-11-06T07:19:14Z
        command:  bash scripts/gates.sh --fast
        tree:     e50de20d51f7482a27f7bf6006de4269d7c60a47
        exit:     0
        duration: 1s
        last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
        log:      .claude/state/attest-logs/20261106T071914Z.93684.log

    `gates.sh --fast` ran nothing (every gate is unconfigured), as in RED.
  - DV-2 has not been run; it belongs to GATES. `bash scripts/mutate.sh --check`
    is clean. Nothing is committed.
- **GREEN verified by the orchestrator (2026-11-06, Opus 5.5).** Read the
  diff of `scripts/check-boundaries.sh` (helpers moved up; the one-line
  `mkdir -p ... || { problem ...; exit 1; }`; the comment reflowed to the same
  six lines; `txt` and `crit_txt` gone) and `VERSION` 110 -> 111. `attest.sh
  check` answered `fresh` with exit 0 for `bash scripts/selftest.sh
  boundaries` (`boundaries: 545 passed, 0 failed`), `bash scripts/selftest.sh
  sigpipe` (`sigpipe: 91 passed, 0 failed`) and `bash scripts/gates.sh
  --fast` (0 ran, 5 unconfigured); none was re-run. Net line delta above
  line 399 is 0, so R-1 is not needed: sigpipe's three `DISCARDED` pins
  still hold. `mutate.sh --check` is clean.
- **GATES verified by the orchestrator (2026-11-06).** DV-2 run first
  (result in its block: the three AC-1 assertions red with the fix removed,
  restored and verified). Then the full gates, dispatched: `attest.sh check
  -- bash scripts/gates.sh` answered `fresh`, exit 0, log
  `20261106T143305Z.1703.log`, verdict `All required gates passed (0 ran, 7
  unconfigured, 0 known).` Seven, not the five of `--fast`, because the full
  run includes the two `slow` gates (integration, build); every gate is
  unconfigured while BOOTSTRAPPED=no. Nothing in the tree was changed by the
  run but `## Gate results`.
- **main merged in at GATES (2026-11-06).** HARNESS-090 (#182) landed on main
  while this story ran; merged as `fdb9e51` via the app's base-branch sync.
  One conflict, `.claude/tests/floors.conf`'s trailing comment blocks: both
  kept, HARNESS-090's first. VERSION taken to 112 (111 is HARNESS-090's).
  Because the tree changed, the full gates were re-recorded after the diff
  review, by the orchestrator directly (every gate is unconfigured; the run
  takes a second): `attest.sh check -- bash scripts/gates.sh` -> `fresh`,
  exit 0. The self-test at GATES -> REVIEW runs on the merged tree.
- **Self-test at GATES -> REVIEW (2026-11-06), on the merged tree
  `deb74be`.** `selftest-needed.sh`: run. Dispatched; `attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` -> `fresh`.

      selftest: --changed — 15 of 34 suite(s) selected: boundaries ci-local dispatch doctor grep-count host-load lib plan procedure refresh run-lock selftest sigpipe story worktree
      exit:     0
      last:     15 harness suite(s) passed.
      duration: 1519s

  `boundaries: 545 passed, 0 failed`, `sigpipe: 91 passed, 0 failed`,
  `selftest: 366 passed, 0 failed`; all 15 suites met their floors.
