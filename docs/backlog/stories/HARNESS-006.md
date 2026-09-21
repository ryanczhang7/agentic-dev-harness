---
id: HARNESS-006
title: A story declares the files it touches, so the harness can say which may run together
slug: a-story-declares-the-files-it-touches-so
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-006-a-story-declares-the-files-it-touches-so
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/plan.sh, scripts/new-story.sh, .claude/tests/plan.test.sh, .claude/skills/story-authoring/SKILL.md]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

No epic. The harness maintaining itself.

**Two stories can run at once only if neither is blocked and neither writes the
files the other writes.** `depends_on` has always answered the first half -
`plan.sh next` returns `blocked`, `phase.sh board` shows it. Release 45 added
`plan.sh conflicts` for the second half, reading the paths a story's
`## Contract` declares and intersecting them pairwise.

**That check cannot do its job, and the reason is a lifecycle problem rather
than a defect.** A `## Contract` is written by the Lead PO *before RED* - which
is *after* planning. So at the moment `/plan-product` decides how to cut the
backlog, the information `conflicts` needs does not exist yet. Measured on this
repository's own backlog at release 45:

    STATUS    PAIR                      DETAIL
    UNKNOWN   HARNESS-001 + HARNESS-002 no Contract paths declared yet
    ... ten pairs, all UNKNOWN, zero judgeable

Ten of ten. The check is honest about it - UNKNOWN is deliberately not `clear` -
but an honest "I cannot tell you" every single time is not a working feature.

**And detection is the wrong half of the problem.** A lint over a decomposition
says which of the planner's choices were unfortunate. It cannot make the
planner choose differently, because nothing in `create-product.md`,
`plan-product.md`, `lead-po.md` or `story-authoring/SKILL.md` mentions
simultaneous development at all - grepped at release 45, zero hits in all four.
Stories are cut for size and ordering. Whether their file footprints partition
is not a consideration anyone has been asked to weigh.

So this story moves the declaration EARLIER, to where the planner can use it:
a story states the files it expects to touch when it is authored, in
frontmatter, and `conflicts` reads that. The `## Contract` keeps its job - it is
the precise agreement RED sharpens - and gains a cross-check against what the
story said it would touch when it was cut.

**Sizing.** The whole idea - footprints, a planner organised around producing
disjoint waves, worktrees, an orchestrator running N stories - is four
behaviours and fails this harness's own sizing rule on every line of it. This
story is the first behaviour only: **the declaration exists, is machine-read,
and shrinks UNKNOWN.** The rest are named in `## Out of scope` with the order
they have to happen in.
## Acceptance criteria

- **AC-1** - Given a story whose frontmatter declares `touches:` with one or
  more paths, when `bash scripts/plan.sh conflicts` runs, then those paths are
  what the story is judged on. *Control:* a story declaring `touches: []` is
  judged as declaring nothing, not as touching everything.
- **AC-2** - Given two startable stories whose `touches:` sets intersect, when
  `conflicts` runs, then the pair is CONFLICT, the shared path is named, and the
  command exits non-zero. *Control:* two whose sets are disjoint are `clear` and
  it exits 0.
- **AC-3** - Given a story with `touches:` and an EMPTY `## Contract`, when
  `conflicts` runs, then it is judged rather than UNKNOWN. This is the whole
  point: at planning time no contract exists yet. *Control:* a story with
  neither `touches:` nor Contract paths is still UNKNOWN, and UNKNOWN is still
  never reported as clear.
- **AC-4** - Given a story that declares BOTH `touches:` and `## Contract`
  paths, when `conflicts` runs, then a Contract path absent from `touches:` is
  reported as a drift warning naming both. The contract is the sharper document;
  a story that turned out to touch more than it said should say so out loud
  rather than being silently overruled in either direction.
- **AC-5** - Given `bash scripts/new-story.sh <id> "<title>"`, when it creates a
  story, then the file carries a `touches:` key with a comment saying what it is
  for. *Control:* a story file missing `touches:` entirely is accepted by
  `check-boundaries.sh` - this is a new field, and refusing every story that
  predates it would make the backlog unmergeable.
- **AC-6** - `story-authoring/SKILL.md` documents how to fill `touches:` and
  states the rule that makes it worth filling: a decomposition whose footprints
  partition is one that can be worked in parallel. *Verified by review, not by
  assertion* - see `## Deferred verifications`.
## Contract

**`touches:` in story frontmatter.** A YAML list of repo-relative paths and
globs the story expects to write. Empty list means "declared, and it is empty" -
distinct from the key being absent, which means "not declared".

    touches: [scripts/plan.sh, .claude/tests/plan.test.sh]

**`scripts/plan.sh`** gains `story_touches <file>`, returning the declared paths
one per line, sorted and unique, empty when the key is absent or the list is
empty. It reads frontmatter through `frontmatter_list` from `lib.sh` - the same
reader `depends_on` uses - and does not parse YAML itself.

`cmd_conflicts` changes its source of paths to, in order:
  1. `story_touches` when the key is present
  2. `contract_paths` otherwise
  3. neither - UNKNOWN, exactly as today

`contract_paths()` and `contract_unenforced()` keep their current behaviour and
signatures. The RED model policy is not in this story's scope and must not move.

**Drift (AC-4)** is reported per story, not per pair, on its own line:

    DRIFT     HARNESS-006   contract names scripts/new-story.sh, touches: does not

**`scripts/new-story.sh`** emits `touches: []` into the frontmatter it writes,
with a trailing comment in the same style as `depends_on`'s.

**`.claude/tests/plan.test.sh`** carries the assertions. The existing 42 stay
green: this adds a source of paths, it does not change how paths are compared.

**Test-only dependencies:** none. bash, awk and git, as ever.

**Callers of anything whose signature changes:** none - `story_touches` is new,
and `contract_paths` keeps its signature. `cmd_conflicts` is called only from
the `conflicts` case in the dispatcher and from `plan.test.sh`.
## Deferred verifications

**AC-6, the documentation criterion. Owner: REVIEW.**

`story-authoring/SKILL.md` gaining a section is not assertable by this suite
without writing a test that greps a document for a phrase, which pins the phrase
rather than the guidance and goes stale the first time somebody rewrites the
paragraph better. The harness has that failure already recorded: an assertion
whose needle is a presentation rather than a behaviour.

So REVIEW reads it and records, here, that the section exists and answers two
questions a Lead PO will actually have: what granularity to declare (file, or
directory glob) and what to do when a story genuinely cannot know yet.

**Result:** <!-- filled at REVIEW -->

**AC-4's drift case against the REAL backlog. Owner: GATES.**

Release 41 requires a probe against the tree the rule judges, not only against
fixtures, and release 45 earned that the hard way: removing `strip_comments`
from the extractor turned this backlog's ten pairs into ten false CONFLICTs on
`go.mod` and `requirements.txt`, paths that appear only in the story template's
own HTML comment. A fixture corpus has clean contracts and would never have
shown it.

GATES runs `bash scripts/plan.sh conflicts` against `docs/backlog/stories/` with
this story's own `touches:` filled in, and pastes the output. Expected: this
story judged against its declared paths rather than UNKNOWN, and no DRIFT line,
because its `touches:` and its Contract were written together.

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

Three follow-on behaviours, in the order they have to happen. Each is its own
RED to GREEN cycle; together with this one they are the feature.

**HARNESS-007 - the planner is organised around producing disjoint footprints.**
`plan-product.md` step 5 cuts the stories, and `story-authoring` sizes them by
one RED→GREEN cycle. Neither has any notion that a decomposition can be judged
by whether its footprints partition. This story only makes the declaration
possible and machine-readable; 007 makes the planner *aim* for it - emitting
stories in waves that can be worked together, and using `depends_on` for true
ordering rather than for "these would collide", which today it silently doubles
as. Depends on this.

**HARNESS-008 - one phase lock per worktree.** `.claude/state/current-story.env`
holds one `STORY_ID` and one `PHASE` per checkout, so one checkout can work one
story. Git worktrees give each its own working directory and therefore its own
gitignored `.claude/state/`, and `phase.sh set` already refuses to advance a
story while the checkout is on the wrong branch - which is the invariant wanted.
What needs doing is `refresh-harness.sh` per worktree and a decision about
whether `doctor.sh` should notice it is in one. Depends on 007 only in the sense
that running parallel stories before the planner produces parallelisable ones is
premature.

**HARNESS-009 - `lead-po` dispatches into more than one worktree.** The
orchestrator holds the loop and today dispatches one story at a time because
that is all the state file can express. Running N means managing N locks, a
merge order, and what to do when one of the N goes red. This is a different
orchestrator rather than a modified one, and it is deliberately last.

**Not in any of them: checking the contract against the eventual diff.** A
`touches:` list is a declaration of intent. Nothing here verifies that the diff
a story actually produced stayed inside it. That is a `check-boundaries.sh`
concern, it is a real gap, and naming it here is not the same as scheduling it.
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

Filed 2026-09-20 by the user, after reviewing release 45 and observing -
correctly - that `plan.sh conflicts` is a lint over a decomposition rather than
a capability, and that the planner is where parallelism has to be decided.

**This story declares its own `touches:`,** which is both the point and the
first real test of the field: if the list is awkward to write for a story about
writing the list, the design is wrong.

**Why the field is frontmatter and not a new section.** `depends_on` is already
frontmatter, enforced by `phase.sh set`, and read by `frontmatter_list`. A
footprint is the same kind of fact - a machine-readable property of the story
rather than prose for a human - so it goes in the same place and uses the same
reader. A seventh `##` section would need its own parser, and rules.md is
explicit about what happens to a rule that gets a private copy per caller.

**The honest limit of the whole idea,** worth stating before anyone builds on
it: a declaration is intent. `touches:` says what a story expects to write, not
what it wrote. Two stories with disjoint declarations can still collide if one
of them was wrong. AC-4's drift check catches the case where the story's own
contract disagrees with its declaration, which is the cheap half; comparing
either against the actual diff is named in `## Out of scope` and not scheduled.
