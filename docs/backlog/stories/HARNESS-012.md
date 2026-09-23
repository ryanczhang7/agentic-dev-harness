---
id: HARNESS-012
title: The LOCAL alarm asks whether a blob is reachable, not whether it exists
slug: the-local-alarm-asks-whether-a-blob-is-r
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-012-the-local-alarm-asks-whether-a-blob-is-r
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/refresh-harness.sh, .claude/tests/refresh.test.sh, .claude/tests/floors.conf]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**The alarm that justified four stories of work can be silenced by a deleted
branch, and it silenced itself during those four stories.**

`refresh-harness.sh` warns before it overwrites a downstream file that upstream
has never shipped - the LOCAL report. Its own header explains why it exists
(H26): a project vendors the harness, fixes a defect locally WITH TESTS, and the
next refresh removes the fix and the assertions that pin it in one operation,
leaving a green self-test and nothing said.

It decides by hashing the downstream file and asking upstream's object store
about that blob:

    scripts/refresh-harness.sh:249, :270, :277
      git -C "$UP" cat-file -e "$h" 2>/dev/null && continue

`cat-file -e` answers **"does this object exist"**, not **"has upstream ever
shipped this"**. Those differ for every blob that entered the store without
being on a branch: a deleted branch, a `git stash`, a fetched PR ref, an
abandoned rebase, a CI experiment. Until `git gc` runs - which it may not for
weeks - the blob exists, and the alarm concludes upstream shipped it.

**Measured on this repository, 2026-09-23, at release 50:**

    $ git fsck --dangling --no-progress | grep -c '^dangling blob'
    9

    $ h=$(git hash-object ../manga-translator/.claude/hooks/lib.sh)
    632dc4e6d35c78a82e44ce93cb472c054a6be2a6
      cat-file -e (existence):  YES  -> refresh stays silent
      log --find-object (reachable): NO -> no commit contains it

That file is manga-translator's own reconciled-away parser. It is not in any
upstream release, and the refresh no longer warns about it.

**How the blobs got there is the sharp part: this round put them there.**
HARNESS-010's RED phase ran a union-corpus cross-comparison on CI, which meant
committing manga-translator's hooks onto a throwaway branch of THIS repository.
The branch was deleted afterwards, correctly. Its blobs stayed. So the story
that reconciled the two parsers is the reason the alarm stopped reporting the
two parsers - and the LOCAL list for manga-translator fell from eleven files to
nine for that reason rather than because anything was fixed.

Nothing was lost this time: HARNESS-010 made upstream's parser the union of
both, so overwriting downstream's copies is now correct. That is luck. The next
project to fix a harness defect locally, in a repository where somebody once
pushed an experiment, gets the H26 failure with the alarm switched off.

## Acceptance criteria

- **AC-1** - Given a downstream file whose content exists in upstream's object
  store only as an UNREACHABLE object, when the refresh reports, then that file
  is listed as LOCAL. *Control:* the same file, after its blob becomes
  reachable from a commit, is NOT listed.
- **AC-2** - Given a downstream file whose content IS reachable from upstream
  history - an older release the project is simply behind on - then it is NOT
  listed as LOCAL. **This is the quiet half and it is load-bearing:** across
  fifteen releases nearly every harness file differs because upstream moved on,
  and an alarm that fires for all of them is one nobody reads. `refresh.test.sh`
  already asserts both halves; keep it that way.
- **AC-3** - All three call sites use the corrected question. *Control:* a test
  that would pass with only one of the three fixed must fail.
- **AC-4** - Given an upstream with no history to answer from - a shallow or
  single-commit checkout - the refresh still reports that it CANNOT judge,
  rather than reporting a clean result. The existing `up_has_history` branch
  covers this; the criterion is that the change does not weaken it.
- **AC-5** - `.claude/tests/floors.conf` records the raised count for
  `refresh`. *Control:* the floor is the executed assertion count.

## Out of scope

- **Making `refresh-harness.sh` run `git gc`**, or otherwise mutating the
  upstream checkout. It is somebody else's repository and the refresh only reads
  it.
- **The cost of the reachability question on a large history.** If
  `--find-object` over `--all` turns out to be slow enough to matter, say so
  and propose the alternative; do not silently pick a cheaper question that
  answers something else, which is the defect being fixed.
- **Anything about WHICH files are replaced.** This story changes what the
  report SAYS, never what the copy loop DOES.
## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
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
         reason. check-boundaries.sh refuses a PR that has neither
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. Do THREE mutations rather
     than one, and make one of them a wrong VALUE rather than a missing field: a
     suite that catches an omission can be blind to a corruption, and a codec
     that is uniformly wrong round-trips through itself perfectly. -->

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


Filed 2026-09-23, the fifth and last finding of the port-before-refresh round
(releases 47-50, plus HARNESS-010 and HARNESS-011). Unlike the other four this
one is not a port from manga-translator - it is a defect in upstream's own
refresh tool, found while checking whether the refresh was finally safe.

**The `## Contract` is left for PLANNED.** What follows is the evidence so that
PLANNED reads numbers rather than re-deriving them.

**The three call sites**, at release 50:

    scripts/refresh-harness.sh:249   the .claude/{agents,commands,skills,hooks,tests} walk
    scripts/refresh-harness.sh:270   the scripts/*.sh walk
    scripts/refresh-harness.sh:277   the named single files

All three ask `git -C "$UP" cat-file -e "$h"`. All three want the other
question.

**A candidate answer, not a decision.** `git log --all --find-object=<hash>`
returns nothing for a dangling blob and at least one commit for a reachable one
- that is the query used to diagnose this, and it is the obvious first thing to
try. PLANNED should check its cost on a real history before pinning it: the
alternative shapes are `git rev-list --objects --all` piped to a lookup, or
`git cat-file --batch-check` with `--batch-all-objects` filtered by
reachability. The criterion is the QUESTION, not the command.

**What makes this worth a story rather than a one-line fix.** The quiet half.
`refresh.test.sh` already asserts that the alarm does NOT fire for a file whose
content is an older upstream release, and the whole value of the report is that
it stays silent for the dozens of files a behind-by-fifteen-releases project
carries. A fix that makes the alarm correct about dangling blobs and noisy about
everything else is worse than the defect, because an alarm nobody reads protects
nothing. Both halves are already pinned in that suite; keep them pinned.

**Provenance, and it is uncomfortable.** The dangling blobs in this repository
were created by HARNESS-010's own RED phase, which pushed manga-translator's
hooks onto a throwaway branch of this repository to run the union-corpus
cross-comparison on CI. Deleting the branch was right; the objects survived it.
So the story that reconciled the two parsers is why the alarm stopped reporting
the two parsers. Measured: manga-translator's LOCAL list fell from eleven files
to nine between the start and end of the round, and two of those two were
suppressed rather than resolved.
