---
id: HARNESS-016
title: Drift reads the paths a Contract writes, not every path it mentions
slug: drift-reads-the-paths-a-contract-writes
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-016-drift-reads-the-paths-a-contract-writes
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/plan.sh, .claude/tests/plan.test.sh, scripts/new-story.sh, .claude/tests/new-story.test.sh, .claude/skills/story-authoring/SKILL.md, CLAUDE.md]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

No epic. The harness maintaining itself. Follows HARNESS-006 (release 56).

**HARNESS-006 shipped a warning that is wrong every time it fires on this
repository.** `plan.sh conflicts` prints a `DRIFT` line when a story's
`## Contract` names a path its `touches:` does not cover. Its GATES probe against
the real backlog printed 15 DRIFT lines, and 0 of them were real. After
`touches:` was filled for HARNESS-001..005 the count was 9, all on HARNESS-007
and HARNESS-009, and again 0 were real:

    DRIFT     HARNESS-007   contract names phase.sh, touches: does not
    DRIFT     HARNESS-007   contract names rules.md, touches: does not
    DRIFT     HARNESS-009   contract names check-boundaries.sh, touches: does not
    DRIFT     HARNESS-009   contract names lead-po.md, touches: does not
    ...

**The drift rule is right; what it reads is not.** `contract_paths` extracts
every token in the Contract prose that looks like a path. That includes:
- files the story only reads, such as a helper it calls or a script it cites;
- bare basenames of files `touches:` already lists in full (`plan.sh` next to
  `scripts/plan.sh`);
- directory prefixes (`.claude/skills/stack-profiles/reference/`);
- tokens that are not paths at all (`AC-1..AC`).

That precision was tolerable for `conflicts`' old fallback, where a false
CONFLICT is loud and gets read. It is not tolerable for a warning: a signal that
is false 15 times out of 15 teaches the reader to skip it, and HARNESS-007 is
about to build the planner on it.

**Why this is its own story and not a fix inside HARNESS-006.** `contract_paths`
has a second reader: `contract_unenforced`, which decides whether RED runs on
the weaker model. HARNESS-006's Contract froze it for that reason. Changing what
it returns changes the model plan, and that has to be decided rather than
happen as a side effect.

**Required gate.** `BOOTSTRAPPED=no`, so every `gates.sh` gate is unconfigured
here. The binding check is `bash scripts/selftest.sh`, specifically the `plan`
suite, which is a required CI step (`gates` job).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given a story whose `touches:` lists every file its Contract says it
  WRITES, and whose Contract prose also mentions files it only reads (a helper
  it calls, a script it cites, the bare basename of a file `touches:` lists in
  full), when `bash scripts/plan.sh conflicts` runs, then no DRIFT line is
  printed for that story. *Control:* the same story with one written file
  removed from `touches:` still gets exactly one DRIFT line, naming that file.
- **AC-2** — Given a Contract containing tokens that are not repository paths
  (`AC-1..AC`, `e.g.`, a version like `1.2`) and a directory prefix ending in
  `/`, when `conflicts` runs, then none of them appears on a DRIFT line or as a
  shared path on a CONFLICT row. *Control:* a real path in the same Contract
  that the story writes and `touches:` omits is still reported.
- **AC-3** — Given every story in this repository's backlog at the commit this
  story starts from, when `bash scripts/plan.sh models <id>` runs before and
  after the change, then the RED row is the same for every story, unless
  `## Amendments` records a deliberate change to the RED model policy with the
  stories it moves.
- **AC-4** — Given a story with no `touches:` and a written Contract, when
  `conflicts` runs, then the pair is still judged on the Contract's paths, so
  the fallback HARNESS-006 kept does not regress. *Control:* the existing
  `plan.test.sh` conflict and UNKNOWN assertions stay green unchanged.

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

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **Checking `touches:` or the Contract against the actual diff.** HARNESS-006
  named this gap and did not schedule it. This story does not either.
- **Glob-against-path overlap in `conflicts`.** Paths are still compared as
  literal text, as HARNESS-006 pinned.
- **Filling `touches:` for stories that lack it.** That is backlog upkeep, not
  a behaviour.

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

Filed 2026-09-30 at the user's request, from HARNESS-006's GATES result (its
`## Deferred verifications`, "AC-4's drift case against the REAL backlog").

**Open for PLANNED: how a Contract says what it writes.** The ACs fix the
behaviour, not the mechanism. The PO decides the mechanism before RED:
- **An explicit declaration inside `## Contract`**, such as a `**Writes:**` line
  or a fenced list, read instead of the prose. It is precise, but it is a third
  place a story names its files, next to `touches:` and the prose. The template
  comment in `new-story.sh` and `story-authoring` would have to ask for it.
- **A stricter extractor**, for example: only tokens containing a `/`, and none
  ending in `/`; a bare basename counts as covered when `touches:` lists a path
  ending in it. It needs no new convention, but it is still a guess about
  prose, and a written file cited by its bare name would silently stop
  drifting.

Whichever is chosen, AC-3 decides whether `contract_unenforced` moves with it.
Record which, and why, in the Contract.

**This story is itself a candidate conflict.** It declares `scripts/plan.sh` and
`.claude/tests/plan.test.sh`, as do HARNESS-007 and HARNESS-009. Run it before
007, which builds on the signal it repairs.
