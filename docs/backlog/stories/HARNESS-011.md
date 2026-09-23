---
id: HARNESS-011
title: A bare directory name classifies as its category, not as source
slug: a-bare-directory-name-classifies-as-its
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-011-a-bare-directory-name-classifies-as-its
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/harness/paths.conf, .claude/tests/classify.test.sh, .claude/tests/phase-guard.test.sh, .claude/tests/floors.conf]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**In GREEN, deleting one frozen test is refused and deleting all of them is
permitted.** Measured on this checkout at release 48, through the real
`phase-guard.sh`, with a story in GREEN:

    rm -rf tests/a.test.ts   -> BLOCK    one test file: refused, correctly
    echo x > tests/a.test.ts -> BLOCK    writing one: refused, correctly
    rm -rf tests             -> ALLOW    the whole directory: PERMITTED

Law 2 says tests are frozen during GREEN. The lock enforces that per file and
not for the directory that holds them.

**The cause is one missing shape in `paths.conf`, repeated across every category
but one.** A rule is written `docs | docs/**`, and `docs/**` matches paths
UNDER `docs` and never `docs` itself. A bare directory name therefore matches
nothing and falls through to the documented default, `source`:

    docs        -> source      docs/            -> docs
    tests       -> source      tests/           -> test
    test        -> source      tests/a.test.ts  -> test
    spec        -> source
    __tests__   -> source
    .claude     -> source      .claude/hooks    -> harness
    scripts     -> source
    .github     -> source

**Vendor is the exception, and it is the exception because somebody already hit
this.** `paths.conf` carries both forms for every vendor directory, under a
comment that says exactly why:

    # The directories themselves, so that `rm -rf node_modules` and friends are
    # classified as vendor rather than falling through to source.
    vendor | **/node_modules
    vendor | target
    vendor | **/dist

Measured: `node_modules`, `.venv`, `target`, `dist`, `coverage` all classify as
`vendor` correctly. The fix is known, written down, and was applied to one
category out of six.

**Both directions are wrong, and they are wrong in different phases.**

  * *Too permissive* - `source` is writable in GREEN, GATES and SCAFFOLD, so a
    bare `tests`, `test`, `spec` or `__tests__` is writable in exactly the
    phases that freeze tests. That is the measurement above and it is the
    reason this is not cosmetic.
  * *Too restrictive* - `source` is frozen in RED and REVIEW, so a bare `docs`,
    `.claude`, `scripts` or `.github` is refused in phases where those
    categories are writable. Measured: `rm -rf docs` and `rm -rf tests` are
    both BLOCKED in RED, where docs and tests are writable.

**How it was found.** HARNESS-010's RED phase, running manga-translator's
`phase-guard.test.sh` against upstream's parser on CI: twelve of the seventy
failures were not about the parser at all. They were `classify` cases, and
manga-translator had already fixed this downstream. That is the FOURTH finding
from the port-before-refresh round, after assertion floors (release 47), the two
session-safety fixes (release 48) and HARNESS-010's parser reconciliation.

**It is on the refresh's critical path.** `refresh-harness.sh` LEAVES
`paths.conf` for a human to merge - it is one of the two files named "do not
just copy these" - so a refresh will not overwrite the downstream fix the way it
would have overwritten `write_candidates`. But the merge is by hand, and a hand
merge of a rule nobody has written down upstream is a rule that gets dropped.
Landing it here makes the merge mechanical.
## Acceptance criteria

- **AC-1** - Given a bare directory name that a `paths.conf` rule intends to
  cover, when `classify.sh` is asked, then it returns that rule's category and
  not `source`. Covers at least `docs`, `tests`, `test`, `spec`, `__tests__`,
  `.claude`, `scripts`, `.github`. *Control:* `src` still classifies as
  `source`, and an invented `wibble` still classifies as `source` - the fallback
  must survive, because a path about to be authored is source and that is the
  documented default.
- **AC-2** - Given a story in GREEN, when a write to the bare `tests` directory
  is attempted, then the phase lock refuses it. *Control, and it is the point:*
  the same write to `tests/a.test.ts` was already refused, and still is - so the
  criterion is about the DIRECTORY closing a hole the file never had.
- **AC-3** - Given a story in RED, when a write to a bare `docs`, `scripts` or
  `.claude` is attempted, then the lock permits it. *Control:* a write to a bare
  `src` in RED is still refused.
- **AC-4** - `paths.conf` states the rule once, where a reader will meet it.
  The vendor block already carries the explanation; the fix must not leave six
  copies of the same sentence, nor leave the other five categories looking like
  an oversight a future editor will repeat. *Verified by review* - see
  `## Deferred verifications`.
- **AC-5** - `.claude/tests/classify.test.sh` covers every category's bare form,
  and `.claude/tests/floors.conf` records the raised count. *Control:* the floor
  is the executed assertion count, not the number of `assert_` call sites.

## Out of scope

- **Trailing-slash forms.** `docs/` and `tests/` already classify correctly;
  measured. This story is about the bare name.
- **Any change to what the categories MEAN**, or to which phase may write which
  category. `phases.conf` is untouched: this makes the classifier agree with
  rules that already exist.
- **The glob engine.** If the fix turns out to need `**` to match an empty
  segment, that is a change to matching semantics affecting every rule in the
  file, and it is a different story - say so rather than making it here.
- **manga-translator's own copy.** Landing this upstream makes that merge
  mechanical; performing it is the refresh, not this.
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


Filed 2026-09-23 from HARNESS-010's RED phase. The `## Contract` is deliberately
left for PLANNED to pin when this story is started; what follows is the evidence
so that PLANNED reads numbers rather than re-deriving them.

**The measurements, taken by the orchestrator on this checkout at release 48.**
Both through `bash scripts/classify.sh` and through the real `phase-guard.sh`
driven with a JSON payload, against a fixture carrying this repository's own
`paths.conf` and `phases.conf`.

    $ bash scripts/classify.sh tests tests/ tests/a.test.ts docs docs/ .claude .claude/hooks
    source  tests
    test    tests/
    test    tests/a.test.ts
    source  docs
    docs    docs/
    source  .claude
    harness .claude/hooks

    story in GREEN:
      rm -rf tests/a.test.ts   -> BLOCK
      echo x > tests/a.test.ts -> BLOCK
      rm -rf tests             -> ALLOW      <- the hole
    story in RED:
      rm -rf tests             -> BLOCK      <- the false positive
      rm -rf docs              -> BLOCK      <- the false positive

**A caution for whoever writes the fix.** `tests/` (trailing slash) classifies
as `test` correctly, but the guard still ALLOWED `rm -rf tests/` in GREEN in one
probe - the write-target parser appears to hand the classifier the name with the
slash stripped. That is HARNESS-010's territory, not this story's, and it means
**a classify-only fix may not close AC-2 on its own**. Check it end to end
through the hook rather than through `classify.sh` alone, and if the parser is
the remaining cause, say so and let HARNESS-010 carry it.

**Why it is `chore` and not `fix`.** The harness's own types put a defect in
shipped behaviour under `fix`, and this is one. It is filed as `chore` because
the change is to a configuration table and its tests rather than to a project's
product code, which is how the other HARNESS-* stories are typed. If that reads
wrong at PLANNED, retype it then - nothing downstream depends on it.

**Provenance.** The fourth finding of the port-before-refresh round, after
assertion floors (release 47), the two session-safety fixes (release 48) and the
parser reconciliation (HARNESS-010). Found by running manga-translator's
`phase-guard.test.sh` against upstream's parser on CI: twelve of the seventy
failures were `classify` cases rather than parser cases, and manga-translator
had already fixed this downstream.

**Not urgent for the refresh, unlike the other three.** `refresh-harness.sh`
LEAVES `paths.conf` for a human to merge - it is one of the two files the script
names "do not just copy these" - so no refresh will silently overwrite the
downstream fix. The risk is a hand merge dropping a rule nobody wrote down
upstream. Landing this makes that merge mechanical rather than a judgement.
