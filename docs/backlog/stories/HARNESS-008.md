---
id: HARNESS-008
title: One phase lock per worktree, so two stories can be in flight at once
slug: one-phase-lock-per-worktree-so-two-stori
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-008-one-phase-lock-per-worktree-so-two-stori
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/doctor.sh, scripts/refresh-harness.sh, .claude/tests/worktree.test.sh, .claude/tests/doctor.test.sh, CLAUDE.md]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

No epic. The harness maintaining itself, and the story that removes the hard
constraint on parallel work.

**One checkout works one story, and the reason is one file.**
`.claude/state/current-story.env` holds a single `STORY_ID` and a single
`PHASE`. Every hook reads it - `phase-guard.sh` to decide what may be written,
`gate-reminder.sh` to decide what to nag about, `inject-state.sh` to tell the
session where it is. Two stories in one checkout means one file and two truths.

**Most of the work is already done, and this was measured rather than assumed.**
A throwaway worktree at release 45:

    git worktree add -d <tmp> HEAD
    ls <tmp>/.claude/state/     -> README.md
    ls  ./.claude/state/        -> README.md  gate-logs  last-gate-run
    git check-ignore -v .claude/state/current-story.env
      -> .gitignore:2:.claude/state/*

`.claude/state/*` is gitignored, and a git worktree has its own working
directory, so **each worktree already gets its own phase lock**. Nothing is
shared. `phase.sh set` already refuses to advance a story while the checkout is
on the wrong branch, which is exactly the one-story-per-worktree invariant this
needs. The mechanism is not missing; it has never been tried, named, or tested.

**So this story is smaller than it looks and mostly adversarial.** It is not
"build a per-worktree lock" - it is "prove the lock is per-worktree, find what
breaks when two of them are live, and fix or document that". The things most
likely to break are the ones that assume a single tree:
`refresh-harness.sh` (run per worktree, or once?), `gates.sh`'s stamp in
`.claude/state/last-gate-run`, and `doctor.sh`, which says nothing today about
which worktree it is in.

**Why it is the story that matters.** HARNESS-006 makes it possible to ask which
stories could run together. It does not make running them possible. Until this
lands, the answer to "can we work two at once" is no, regardless of how good the
planning gets.
## Acceptance criteria

- **AC-1** - Given two git worktrees of this repository, when a story is set to
  a phase in one, then `phase.sh show` in the other reports no active story and
  the first still reports its own. *Control:* setting a second story in the
  second worktree leaves the first unchanged - neither overwrites the other.
- **AC-2** - Given two worktrees each with a different story active in a
  source-freezing phase, when a write to a source path is attempted in each,
  then each is judged against ITS OWN phase. A RED worktree refuses the write; a
  GREEN worktree beside it allows it, at the same moment.
- **AC-3** - Given a worktree, when `bash scripts/gates.sh` runs in it, then the
  record it writes and the record in the other worktree are independent, and
  `check-boundaries.sh` in each judges its own tree. *Control:* a gate run in
  one worktree does not satisfy `check-boundaries.sh` in the other.
- **AC-4** - Given a worktree that is not the main checkout, when
  `bash scripts/doctor.sh` runs, then it names which worktree it is in and
  whether that worktree's harness is the same release as the main checkout's.
  Two worktrees on different releases is a state the refresh procedure can
  produce and nothing currently reports.
- **AC-5** - `bash scripts/refresh-harness.sh` run inside a worktree either
  works correctly on that worktree alone, or refuses and says why. What it must
  not do is partially update a tree it shares files with. *Control for
  whichever it turns out to be:* the other worktree's `VERSION` is unchanged
  after the run.
- **AC-6** - `CLAUDE.md` documents the worktree workflow: how to create one per
  story, that `plan.sh conflicts` should be consulted before choosing the
  second story, and that the answer is only as good as the `touches:`
  declarations it reads. *Verified by review* - see `## Deferred verifications`.
## Contract

**No new state file, and no change to `current-story.env`'s format.** The lock
is already per-worktree because `.claude/state/*` is gitignored and a worktree
has its own working directory. This story proves that and repairs what assumes
otherwise; a design that adds a registry of active stories is the wrong answer
and is out of scope.

**`scripts/doctor.sh`** gains a worktree line, printed always, in the existing
`ok`/`MISSING` style:

    ok       worktree     main checkout, harness 46
    ok       worktree     linked worktree of <path>, harness 46
    MISSING  worktree     linked worktree, harness 44 - main checkout is 46

Detected with `git rev-parse --git-common-dir` compared to `--git-dir`: they
differ in a linked worktree and match in the main one. No new dependency.

**`scripts/refresh-harness.sh`** gains one refusal or one note, whichever the
RED investigation shows is correct. It already refuses mid-cycle and on a dirty
tree; a worktree case joins those, using the same `die` path.

**`.claude/tests/worktree.test.sh`**, new, carries AC-1 through AC-5. It creates
real worktrees with `git worktree add -d` in a throwaway fixture and removes
them in a trap. It does NOT simulate a worktree by copying a directory: the
whole claim is about what git does with `.git`, and a copy would pass while
proving nothing - the release 41 rule, applied to this story's own fixtures.

**Test-only dependencies:** none. git worktree is git.

**Callers of anything whose signature changes:** none. `doctor.sh` gains
output; nothing parses it except `doctor.test.sh`, which this story updates.

## Deferred verifications

**AC-6, the documentation criterion. Owner: REVIEW.**

A `CLAUDE.md` section is not assertable without pinning its phrasing, which
goes stale the first time somebody rewrites it better. REVIEW reads it and
records here that it answers the question a person will actually have: what to
do when `plan.sh conflicts` says UNKNOWN, which - until every story carries
`touches:` - is most of the time.

**Result:** <!-- filled at REVIEW -->

**AC-2 against a REAL pair of stories. Owner: GATES.**

Release 41 requires a probe against the tree the rule judges. GATES creates two
worktrees, sets a real story from this backlog to RED in one and another to
GREEN in the other, attempts a source write in each, and pastes both outcomes.
Fixture stories would demonstrate the mechanism; this demonstrates it on the
backlog that exists.

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

- **HARNESS-009**, the orchestrator dispatching into these worktrees. This story
  makes two locks possible; something still has to decide to use them.
- **HARNESS-007**, the planner aiming for disjoint footprints. Not a dependency:
  this works without it, you just have fewer safe pairs to choose from.
- **Checking a `touches:` declaration against the diff a story produced.** Named
  in HARNESS-006 and still not scheduled. Parallel work makes it matter more,
  because a story that strays outside its declaration now strays into somebody
  else's worktree.
- **Any shared lock, registry or lease.** If two worktrees need to coordinate
  beyond "different branches, different files", that is a design this story has
  not earned and should not invent.

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

Filed 2026-09-21, with HARNESS-009, after the user asked what HARNESS-006
actually enables. The honest answer was: nothing yet. 006 is the declaration,
007 is the planning, and THIS is the one that removes the constraint.

**`depends_on: []` deliberately.** 006 and 007 make parallel work sensible;
neither makes it possible, and neither is mechanically required to start this.
Pulling this forward is the fastest route to running two stories at once, and
the cost of doing it first is only that you pick the second story by hand
instead of being told which are safe.

**The measurement this story rests on** is in `## Context` and was taken before
the story was written rather than assumed from how worktrees are supposed to
behave. If RED finds it wrong, that is the story failing early and cheaply,
which is the point of taking it.
