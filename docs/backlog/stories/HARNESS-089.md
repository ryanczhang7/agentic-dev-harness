---
id: HARNESS-089
title: check-boundaries never deadlocks on a story copy near 64 KiB
slug: check-boundaries-never-deadlocks-on-a-st
epic: 
type: bug
status: todo
phase: PLANNED
branch: story/HARNESS-089-check-boundaries-never-deadlocks-on-a-st
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/harness/VERSION]  # provisional, from the field report; the PO confirms at PLANNED
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

**A field report from fantasy-world-builder (FWB), measured on harness
release 99 and re-checked in the source of release 107 (`b65e2f4`), where
the code is unchanged.** Draft acceptance criteria from the report; the PO
refines them, writes the Contract and confirms `touches:` before RED.

On the Windows host FWB is developed on (Git for Windows, `GNU bash 5.3.15
x86_64-pc-cygwin`), `bash scripts/check-boundaries.sh` hung for **about five
hours** on WORLD-148's branch (2026-11-03), with no child process, printing
nothing after the `branch matches the story's frontmatter` line. It had to be
killed with `kill -9`, and FWB used CI's boundaries job (Linux) as the run of
record.

What was measured, and nothing beyond it:

- The hang is in `criteria_baseline` (check-boundaries.sh, around line 321).
  It reads every committed copy of the story, oldest first, up to the first
  copy that is not PLANNED, and feeds each one through
  `frontmatter_value - phase <<< "$txt"` (line 330 in release 107; the same
  shape on the base copy a few lines above).
- On WORLD-148 the first non-PLANNED copy (its RED commit) was **65,566
  bytes**.
- Reproduced alone, outside the script: a here-string of **65,565 bytes**
  blocked forever. `timeout 10 bash -c '... <<< "$1"'` did not return either.
  A here-string of about **30 KB** was fine.
- A 133 KB story passed check-boundaries on FWB's WORLD-046. That does not show
  a 133 KB here-string is fine, because only the copies up to the first
  non-PLANNED one are fed through, and those may have been small.

**Cause, as a hypothesis only.** Since bash 5.1, a here-string small enough to
fit in a pipe is written to a pipe rather than a temp file. A size near 64 KiB
hanging, with smaller ones fine, fits the pipe-size test going wrong on Cygwin.
That is not proven. The fix should not depend on it: reading a story copy any
way other than a here-string removes the question.

The here-string was a deliberate choice. The comment above `criteria_baseline`
says `git show | section -` was a pipeline into an early-exiting awk (the
SIGPIPE class `has_content` documents). Whatever replaces it has to avoid both
traps: no pipe into an awk that exits early, and no here-string of unbounded
size. A temp file under `.claude/state/` (never `$TMPDIR`, which is unset in
some of these shells), or awk reading the `git show` output to its end, both
qualify.

**Size of the class.** Release 107 has 75 `<<< "` here-strings across 13
files: check-boundaries.sh 15, gates.sh 18, plan.sh 13, refresh-harness.sh 6,
tidy.sh 5, lib.sh 5, and 1 to 3 in each of seven others. Most are fed short
values, such as a frontmatter field or a list of paths. This story covers only
the ones that can carry a whole story copy or a `git show` result. The rest
are listed under `## Out of scope`.

**The gate that fails if this story breaks:** every gate in this repository's
`project.conf` is unconfigured. The artifact is judged by `bash
scripts/selftest.sh boundaries`, which CI runs. CI is Linux, where the
deadlock does not happen. So no CI run can show the original failure, and AC-3
is a deferred verification on a Windows host.

## Acceptance criteria

<!-- Draft from the field report - the PO refines before RED. -->

- **AC-1** — Given a branch whose story has a committed PLANNED copy and a
  first non-PLANNED copy of 65,566 bytes (and, separately, one over 130 KB),
  when `check-boundaries.sh` runs, then the criteria check reaches the same
  baseline (`first`, `base` or `planned`, and the same rev) as it does for the
  same history with small copies. The change must not alter any verdict.
- **AC-2** — Given `scripts/check-boundaries.sh`, then no here-string in it is
  fed a value read from a story copy, a `git show`, or a file's whole contents.
  A test enumerates the script's `<<<` lines and fails on such a source. The
  negative control is the current line 330 put back, which must be refused.
- **AC-3** — Given the Windows host the report came from, when
  `check-boundaries.sh` runs over a fixture branch with a 65,566-byte
  PLANNED-to-RED story copy, then it exits within two minutes. With the current
  `criteria_baseline` put back it hangs, which is the defect-put-back control.
  This cannot run on CI and is owned by a deferred verification on that host.

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

<!-- FILLED BY A TOOL, not by hand: `bash scripts/plan.sh write <id>`, as the
     last step of PLANNED once the ## Contract exists. It renders the per-phase
     plan from .claude/harness/models.conf with the reason for each row. Run it
     again after amending the contract; it replaces the section rather than
     appending to it.

     Not at story creation: the plan depends on the contract, and the "no
     contract, so RED stays on the stronger model" exception would be baked in
     before anybody had a chance to write one.

     What you add BY HAND is the other half - a departure from the plan, and
     the model each dispatch RESOLVED to. Make a departure falsifiable rather
     than folklore:
       * which phase, which model, and why that phase specifically
       * THE RESOLVED MODEL ACTUALLY DISPATCHED, by name - never the word
         "default". An agent definition's `model:` field, or the session's
         setting, or an override: the orchestrator cannot see which won unless
         it records it. Two stories once compared "the default model" against a
         stronger one, and neither could say what the default had resolved to,
         so the comparison may have been the stronger model against itself
       * what the orchestrator should stay on
       * HOW to brief it differently - a model chosen for judgement wants the
         criteria and the constraints, not a pre-decided test design
       * the ORACLE PARTITION of the criteria: which are settled (read the
         numbers out, do not calibrate), which are oracle-free (invent the
         metric and demand a negative control that fires hard), which are
         mechanical (pin exactly). Measured to matter more than the model
       * a success condition that could come out either way
     Then record the VERDICT against that condition when the phase ends, with
     evidence. The verdict is the part that gets skipped, and without it a model
     choice becomes a habit nobody can argue with. -->

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- The other 60 or so here-strings across the tree, which are fed short values
  such as a frontmatter field, a path list or a gate line. Any of them that can
  carry a whole file belongs in a follow-up story with the same AC-2 shape.
  Candidates to read first are gates.sh (18), plan.sh (13) and lib.sh (5).
- Proving the Cygwin mechanism. The fix removes the dependency on it.

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

- Filed 2026-11-04 from FWB, where the harness is vendored at release 107
  (PR 113 there). The FWB-side workaround, until this lands: if
  check-boundaries prints nothing for more than about two minutes after
  `branch matches`, run `git show <rev>:<story> | wc -c` on the branch's
  commits and suspect a copy near 65,536 bytes. Kill the hung run and let CI's
  boundaries job judge the commit.
