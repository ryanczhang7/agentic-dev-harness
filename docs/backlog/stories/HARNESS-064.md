---
id: HARNESS-064
title: gates.sh --story refuses an id that is not one path component, and a test says so
slug: gates-sh-story-refuses-an-id-that-is-not
epic: 
type: chore
status: done
phase: DONE
branch: story/HARNESS-064-gates-sh-story-refuses-an-id-that-is-not
depends_on: [HARNESS-059, HARNESS-060] # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/gates.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(survivor A13). The required gate is the harness self-test (`gates` suite).

`scripts/gates.sh --story ID` validates the id with `valid_story_id` before the
id is joined into `docs/backlog/stories/$ID.md` and the gate record is written
there (line 90). Replacing `valid_story_id "$STORY" ||` with `true ||` survives
`gates.test.sh` (671 passed, 0 failed). The defence exists; no test has seen it
refuse anything. `new-story.sh` has the same check and its suite pins it; this
entry point's does not.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — `bash scripts/gates.sh --story ../x` and `--story a/b` each exit 2,
  print the "is not one path component" error, and write nothing under
  `docs/backlog/stories/` or `.claude/state/`. Passes today; earned by mutant
  A13 going red, recorded in `## Regressions`. *Negative control:*
  `--story T-1` on a fixture with that story is accepted.

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

Any change to `gates.sh` itself: the code is right, the test is missing.

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

### Closed as already delivered (2026-10-19)

1. **PO decision, approved by the user:** closed without a RED→GREEN cycle.
   The criterion was delivered on 2026-10-09 by HARNESS-046 (RED commit
   `97ff105`), whose block `describe "HARNESS-046 AC-3  gates.sh --story
   refuses an id that is not one path component, before any gate runs"` in
   `.claude/tests/gates.test.sh` (`:2000-2047` today) runs `--story ../EXIST`
   and asserts exit 2, the grammar message once as a whole line, no gate run,
   and the file outside the stories directory byte-for-byte unchanged. Its
   second half pins the same refusal for an id read from `current-story.env`.
   A cycle would re-write tests that exist. No source or test file changes in
   the closing commit.
2. **Why A13 survived, measured before closing.** `gates.sh` checks the id
   twice: at `:90` while parsing `--story`, and again at `:367` for whatever
   id it ends up with (flag or state file), with the same message and exit 2.
   Removing the first check leaves the second to refuse the same ids the same
   way, so no test of the refusal can go red under A13. The one observable
   difference is ordering: with a run lock already held, the first check
   refuses with the grammar message, and without it the run lock refuses
   first, with a different message and also exit 2. The user chose not to pin
   that. Orchestrator probe, a fresh fixture with one `printf` gate, run
   through `scripts/mutate.sh` so the file was restored and checked:

```
##### unmutated
no lock,   --story ../x  rc=2  first line: error: story id '../x' is not one path component: an id is letters, di
           stories dir:    state: gate-logs
no lock,   --story a/b   rc=2  first line: error: story id 'a/b' is not one path component: an id is letters, dig
           stories dir:    state: gate-logs
lock held, --story ../x rc=2  first line: error: story id '../x' is not one path component: an id is letters, digits, '.', '_' or '-
##### A13
=== mutate: scripts/gates.sh (1 line(s) changed by 90s#valid_story_id "$STORY" ||#true ||#) ===
no lock,   --story ../x  rc=2  first line: error: story id '../x' is not one path component: an id is letters, di
           stories dir:    state: gate-logs
no lock,   --story a/b   rc=2  first line: error: story id 'a/b' is not one path component: an id is letters, dig
           stories dir:    state: gate-logs
lock held, --story ../x rc=2  first line: run-lock: refusing to start scripts/gates.sh --story ../x: another harness run holds this
=== mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261018T193606Z.8186.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

   `state: gate-logs` is the directory `gates.sh` creates on start; nothing
   is written under `docs/backlog/stories/` and no record, stamp or log file
   appears in `.claude/state/`.
3. **AC-1 against the tree.** Exit 2 and the message for `../x`: the
   HARNESS-046 block (`../EXIST`). `a/b`: shown by the probe above, not
   asserted separately in the suite. Nothing written: the block's unchanged
   file and "no gate header" assertions. The negative control, `--story T-1`
   accepted on a fixture with that story: the HARNESS-026 AC-4 case at
   `gates.test.sh:1752` (`_label="AC-4 (--story T-1)"`). There the id is
   accepted and every gate runs (`RESULT=pass` in the stamp); the record is
   refused for an unrelated reason, the run being on the wrong branch, and
   that refusal is what the case asserts. It is the nearest existing control,
   not a dedicated one.
4. `phase.sh set HARNESS-064 DONE --force` was run on `main`, overriding the
   branch check: there is no story branch because there is no code change.

