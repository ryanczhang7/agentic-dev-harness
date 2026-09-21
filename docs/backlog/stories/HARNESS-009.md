---
id: HARNESS-009
title: lead-po dispatches into more than one worktree
slug: lead-po-dispatches-into-more-than-one-wo
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-009-lead-po-dispatches-into-more-than-one-wo
depends_on: [HARNESS-008]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/agents/lead-po.md, scripts/plan.sh, .claude/tests/plan.test.sh]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

No epic. The harness maintaining itself, and the last of the four.

**HARNESS-008 makes two phase locks possible. Something still has to decide to
use them.** `lead-po` holds the loop: it reads the board, picks a story, and
dispatches `test-developer` for RED and `feature-developer` for GREEN and GATES.
It dispatches one at a time because one is all `current-story.env` could express.
Once that is per-worktree, the orchestrator is the remaining constraint.

**This is a different orchestrator, not a modified one**, and that is why it is
last. Dispatching into N worktrees means holding N phase states, deciding which
stories may pair, choosing a merge order, and - the part with no equivalent
today - deciding what happens when one of the N goes red while the others are
mid-phase. `lead-po.md` has no vocabulary for any of that: grepped at release
45, it mentions parallelism zero times.

**The pieces it can lean on already exist**, which is the argument for doing it
rather than inventing a scheduler:

- `plan.sh conflicts` (release 45, sharpened by HARNESS-006) says which pairs
  are safe, and says UNKNOWN rather than guessing when it cannot tell.
- `plan.sh next` says what to run a story with, and returns `blocked` when
  `depends_on` is unmet.
- `phase.sh set` refuses to advance a story on the wrong branch, which is the
  per-worktree invariant already enforced.
- HARNESS-008 gives each worktree its own lock, gate record and doctor line.

**What has no answer yet, and this story must give one.** Two stories that both
go green still merge into one `main` sequentially, and `gates.sh` never saw them
together. Two green PRs can be individually correct and jointly wrong - the
"one machine" limit `CLAUDE.md` already warns about, moved to "one branch". An
orchestrator that dispatches in parallel without a position on that is shipping
the problem it was built to manage.
## Acceptance criteria

- **AC-1** - Given a backlog and `n` worktrees, when the orchestrator selects
  what to run, then it selects only pairs `plan.sh conflicts` reports as
  `clear`. *Control:* a pair reported `CONFLICT` is never selected, and a pair
  reported `UNKNOWN` is never selected either - unknown is not permission.
- **AC-2** - Given a story selected for a worktree, when it is dispatched, then
  the worktree is on that story's `branch` and its own phase lock names that
  story. *Control:* dispatching a second story into a worktree that already has
  one active is refused, naming the story already there.
- **AC-3** - Given `n` stories in flight, when one fails a gate, then the others
  continue to their next phase boundary and stop there, and the orchestrator
  reports which stopped where. *Control:* nothing is left mid-phase with no
  record of why - the failure of one is not silent in the others.
- **AC-4** - Given two stories that have both reached REVIEW, when the
  orchestrator reports, then it states a merge order and the reason for it, and
  states that the second PR's gates ran against a tree without the first.
  *Control:* it does not claim the two were verified together, because they were
  not.
- **AC-5** - Given a single worktree, when the orchestrator runs, then behaviour
  is identical to today's - one story, dispatched as now. Parallelism is a
  capability, not a new default, and a project that never creates a second
  worktree must not be able to tell this story landed.
- **AC-6** - `lead-po.md` documents the selection rule, the failure behaviour of
  AC-3, and the merge-order position of AC-4. *Verified by review* - see
  `## Deferred verifications`.
## Contract

**`.claude/agents/lead-po.md`** is where this lives. It is an agent definition -
prose the orchestrator follows - not a scheduler in bash. The harness has no
daemon and this story must not introduce one: what changes is what `lead-po` is
instructed to do, and the machine-readable inputs it is instructed to consult.

**The selection rule, stated once and referenced:**

    candidates = stories where `plan.sh next` is not `blocked`
    pairs      = those where `plan.sh conflicts` says `clear`
    UNKNOWN is not a candidate pair

**`scripts/plan.sh`** gains `conflicts --pairs`, printing only the `clear`
pairs, one per line, `<id>\t<id>` - a machine-readable form of the table
`conflicts` already prints. The human table stays exactly as it is; this adds a
shape an orchestrator can read without parsing columns.

**No change to** `phase.sh`, `phase-guard.sh`, `gates.sh` or
`check-boundaries.sh`. If this story finds it needs one, that is a sign the
per-worktree work of HARNESS-008 was incomplete and belongs there, not here.

**`.claude/tests/plan.test.sh`** covers `--pairs`: that it lists exactly the
`clear` pairs, omits `CONFLICT` and omits `UNKNOWN`. The prose criteria of AC-2
through AC-4 are verified by review and by the deferred probe below, because an
agent definition is not assertable by a shell suite - and writing a test that
greps `lead-po.md` for a sentence would pin the sentence, not the behaviour.

**Test-only dependencies:** none.

**Callers of anything whose signature changes:** none. `--pairs` is a new flag;
`conflicts` with no flag is unchanged, and `phase.sh board` does not call it.
## Deferred verifications

**AC-6, and the prose half of AC-2 to AC-4. Owner: REVIEW.**

`lead-po.md` is an agent definition. A shell suite cannot assert that prose
instructs correctly, and a test that greps it for a phrase pins the phrase
rather than the instruction - a failure already on this harness's record.
REVIEW reads it and records here that it answers three questions without
needing this story to be re-read: how a pair is chosen, what happens to the
others when one goes red, and what the report says about merge order.

**Result:** <!-- filled at REVIEW -->

**AC-1's selection rule against the REAL backlog. Owner: GATES.**

Release 41: probed against the tree it judges, not only against fixtures.
GATES runs `plan.sh conflicts --pairs` over `docs/backlog/stories/` and pastes
it. The expected result at time of writing is EMPTY - most stories in this
backlog declare no `touches:` and no Contract paths, so every pair is UNKNOWN
and none is selectable. That is the correct answer and it is the one worth
pasting: an orchestrator that found pairs here would be selecting on
information that does not exist.

**Result:** <!-- filled at GATES -->

**The joint-correctness question of AC-4. Owner: REVIEW, as a decision rather
than a measurement.**

Two stories that pass separately can fail together, and no gate in this harness
runs against both. REVIEW records which position this story took - report and
proceed, serialise the second PR's gates behind the first merge, or something
else - and why. A story that ships parallel dispatch without recording a
position here has shipped the problem silently.

**Result:** <!-- filled at REVIEW -->
## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from the base branch without an entry here. Omit the section if unused.
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

- **Merging anything.** The orchestrator reports a merge order; it does not
  merge. The user merges, which is this project's standing convention and is
  load-bearing rather than habitual: every defect this harness shipped in
  releases 37-45 was one its own suite was green on, and the reviewer being a
  different process from the author is what caught them.
- **A gate that runs two branches together.** AC-4 requires the orchestrator to
  SAY that the second PR's gates did not see the first. Building a gate that
  would is a different story and a much larger one.
- **More than two worktrees, as a tested claim.** The design should not assume
  two, but the acceptance criteria are written for a pair because that is what
  HARNESS-008 will have demonstrated.
- **Any change to the phase model.** If parallel dispatch appears to need a new
  phase, or a story in two phases at once, the answer is no: that is the lock
  being routed around, and law 5 covers it.

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
         or Gate probes section describes a failure without showing one
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
     it guards, run the gate, paste the failure, revert. One block per gate:
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

Filed 2026-09-21 with HARNESS-008, after the user asked what HARNESS-006
enables and then asked about making the loop more automatic.

**`depends_on: [HARNESS-008]`, and that one IS mechanical.** Dispatching into
worktrees that do not have independent phase locks would corrupt both. 006 and
007 are not dependencies - without them the selection rule simply finds fewer
`clear` pairs, which is a smaller capability rather than a broken one.

**On automation generally, since that is the question behind this story.** An
orchestrator that dispatches more work in parallel is a different thing from an
orchestrator that also reviews and merges it. This story does the first
deliberately and rules out the second in `## Out of scope`. The separation is
not caution for its own sake: releases 37-45 produced a phase-lock hole, two
blind guards and a rule that needed correcting, every one of them green in the
suite that was supposed to catch it, and every one found by something that had
not written it.
