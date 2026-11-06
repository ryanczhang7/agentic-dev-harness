---
id: HARNESS-097
title: check-boundaries refuses to run without its scratch directory, and cleans it up on exit
slug: check-boundaries-refuses-to-run-without
epic: 
type: bug
status: todo
phase: PLANNED
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

