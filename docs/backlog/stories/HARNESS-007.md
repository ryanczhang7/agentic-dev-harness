---
id: HARNESS-007
title: The planner cuts stories into waves that can be worked together
slug: the-planner-cuts-stories-into-waves-that
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-007-the-planner-cuts-stories-into-waves-that
depends_on: [HARNESS-006]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/commands/plan-product.md, .claude/skills/story-authoring/SKILL.md, scripts/plan.sh, .claude/tests/plan.test.sh]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

No epic. The harness maintaining itself, and the one that answers the original
criticism rather than working around it.

**The planner has never been asked to produce a parallelisable backlog.**
`plan-product.md` step 5 says "features in dependency order" and
`story-authoring` sizes a story by one RED to GREEN cycle. Grepped at release
45: `create-product.md`, `plan-product.md`, `lead-po.md` and
`story-authoring/SKILL.md` mention simultaneous development ZERO times between
them. Stories are cut for size and order. Whether their file footprints
partition is not something anyone has been asked to weigh.

**So everything downstream of planning is repair work.** `plan.sh conflicts`
(release 45) reports which of the planner's choices were unfortunate. It cannot
make the planner choose differently. HARNESS-006 moves the declaration early
enough to be usable; this is the story that makes it *used*.

**`depends_on` is doing two jobs and only admits to one.** It is enforced as
"A must be DONE before B may start", which is true ordering - B builds on what A
decided. It is also, in practice, where a planner puts "these two would tread on
each other", because it is the only tool available. Those are different
constraints: the first is about knowledge, the second about files. Conflating
them is why a backlog looks more sequential than it is - stories are chained
that could have run side by side, and nothing records which chains were real.

Once `touches:` exists, collision has its own expression, and `depends_on` can
mean only what it says.

**What this story adds, concretely.** A planner needs a tool as well as an
instruction, or the instruction is advice. `plan.sh waves` groups the startable
stories into waves: within a wave, every pair is `clear`; a story that cannot be
placed without a conflict starts the next wave. It is the same pairwise data
`conflicts` already computes, arranged the way a planner actually thinks.

**And it must stay honest about not knowing.** A story declaring nothing cannot
be placed, and a wave that quietly includes it would be worse than no waves at
all. UNKNOWN keeps the disposition it has everywhere else in this harness: not
clear, not a permission, reported in its own right.
## Acceptance criteria

- **AC-1** - Given startable stories whose `touches:` sets are pairwise
  disjoint, when `bash scripts/plan.sh waves` runs, then all of them appear in
  wave 1. *Control:* two whose sets intersect never share a wave.
- **AC-2** - Given three stories where A conflicts with B, B conflicts with C,
  and A does not conflict with C, when `waves` runs, then A and C share a wave
  and B is in another. A wave is a set of MUTUALLY disjoint stories, not a chain
  of pairwise-checked neighbours.
- **AC-3** - Given a story that declares nothing, when `waves` runs, then it is
  listed as unplaceable with the reason, and is in no wave. *Control:* it does
  not silently land in wave 1, and the exit status distinguishes "there are
  waves" from "nothing could be judged".
- **AC-4** - Given a story blocked by `depends_on`, when `waves` runs, then it
  appears in no wave and is reported as blocked. Ordering and collision are
  different constraints and the output names which one applies.
- **AC-5** - `plan-product.md` step 5 instructs the planner to fill `touches:`
  when cutting each story, and to prefer a decomposition whose footprints
  partition - stating that `depends_on` is for true ordering only, now that
  collision has its own expression. *Verified by review* - see
  `## Deferred verifications`.
- **AC-6** - `story-authoring/SKILL.md` gains the second sizing axis beside "one
  RED to GREEN cycle": a story that cannot state its footprint is not ready to
  be cut, and two stories that must share a file are one story or two waves.
  *Verified by review* - see `## Deferred verifications`.
## Contract

**`scripts/plan.sh`** gains `cmd_waves`, reached as `plan.sh waves`.

    WAVE 1   HARNESS-002  HARNESS-005
    WAVE 2   HARNESS-003
    BLOCKED  HARNESS-009  depends_on HARNESS-008 (PLANNED)
    UNKNOWN  HARNESS-001  declares no paths - cannot be placed

    2 wave(s), 1 blocked, 1 unplaceable.

Greedy placement, first fit: walk the startable stories in id order, put each in
the first wave where it conflicts with nothing already there, else open a new
wave. Greedy is not minimal and must not claim to be - the comment says so,
because the next reader will wonder. Minimal graph colouring is NP-hard, the
input is a backlog of tens, and a planner wants a defensible grouping rather
than an optimal one.

**It reuses, and does not reimplement.** The pairwise question is already
answered by the same helpers `cmd_conflicts` uses - `story_touches` then
`contract_paths` (HARNESS-006), with UNKNOWN when neither declares. `waves`
calls those. Two answers to "do these collide" is the failure `rules.md` names.

**Exit status:** 0 when at least one wave was formed, 1 when nothing could be
placed. A backlog of entirely undeclared stories is not a success.

**`.claude/tests/plan.test.sh`** carries AC-1 to AC-4. The existing assertions
stay green: this adds a command, it does not change `conflicts`.

**No change to** `depends_on` semantics, `phase.sh`, or the frontmatter schema.
This story reads what HARNESS-006 writes and instructs the planner to write it;
it does not add a field.

**Test-only dependencies:** none.

**Callers of anything whose signature changes:** none. `waves` is new.
## Deferred verifications

**AC-5 and AC-6, the two documentation criteria. Owner: REVIEW.**

`plan-product.md` and `story-authoring/SKILL.md` are instructions a Lead PO
follows. A shell suite cannot assert that prose instructs well, and a test that
greps either for a sentence pins the sentence rather than the instruction - a
failure already on this harness's record, and the reason AC-6 of HARNESS-006
and HARNESS-008 are deferred the same way.

REVIEW reads both and records here that they answer the two questions a planner
will actually hit, neither of which this story's own prose settles:

  * what granularity to declare - a file, or a directory glob - and what to do
    about a story that will touch "some of `src/core/`" without knowing which;
  * what to do when two stories genuinely must share a file. The instruction
    says "one story or two waves", and REVIEW should confirm the document says
    which to prefer and why, rather than leaving it as a coin toss.

**Result:** <!-- filled at REVIEW -->

**AC-1 to AC-3 against the REAL backlog. Owner: GATES.**

Release 41: probed against the tree it judges, not only against fixtures.
HARNESS-006's probe earned this the hard way - dropping `strip_comments` turned
this backlog's ten pairs into ten false CONFLICTs on `go.mod` and
`requirements.txt`, paths that exist only in the story template's own HTML
comment, which no fixture would have contained.

GATES runs `bash scripts/plan.sh waves` over `docs/backlog/stories/` and pastes
it. The expected result depends on how far HARNESS-006 has spread: stories
carrying `touches:` should be placed, and every story that predates it should
appear under UNKNOWN. If everything lands in wave 1, something is wrong -
that is the shape of a placement rule that is not reading the declarations at
all.

**Result:** <!-- filled at GATES -->
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

- **HARNESS-008 and HARNESS-009**, the per-worktree lock and the orchestrator
  that dispatches into it. This story produces a plan that CAN be worked in
  parallel. Nothing here makes anything run in parallel, and a wave is a
  suggestion until 008 lands.
- **Re-planning an existing backlog.** The instruction applies when stories are
  cut. Retrofitting `touches:` onto stories written before HARNESS-006 is a
  separate job, and `waves` reporting them as UNKNOWN is the correct behaviour
  rather than a gap to paper over.
- **Minimal waves.** Greedy first-fit, explicitly. A story that wants optimal
  grouping is proposing graph colouring over a backlog of tens, which is a cost
  with no reader.
- **Checking a declaration against the diff a story produced.** Named in
  HARNESS-006, still not scheduled, and it matters more here: `waves` is only
  as good as the declarations, and a story that strays outside its footprint
  strays into another wave member's files.

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

Filed 2026-09-21, completing the set 006 named. The user's criticism of release
45 was that it was a lint over a decomposition rather than a capability, and
that the planner is where parallelism has to be decided. 006 made the data
exist; this is the half that answers the criticism directly.

**`depends_on: [HARNESS-006]`, and it is real rather than tidy.** `waves` can be
built without it - it would fall back to `contract_paths` - but every story
would report UNKNOWN, because a Contract is written before RED and a backlog
being planned has none. The command would be correct and useless.

**The distinction this story is really about.** `depends_on` currently answers
"must A finish before B" and is used for "would A and B collide", because
nothing else could express the second. Separating them is most of the value:
after this, a chain in the backlog means someone decided B needs what A learned,
and that is worth knowing on its own.
