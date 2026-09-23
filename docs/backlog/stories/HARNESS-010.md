---
id: HARNESS-010
title: Reconcile the two write-target parsers into one
slug: reconcile-the-two-write-target-parsers-i
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-010-reconcile-the-two-write-target-parsers-i
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, .claude/hooks/phase-guard.sh, .claude/tests/phase-guard.test.sh, .claude/tests/lib.test.sh, .claude/tests/floors.conf]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**Two independent rewrites of the same security-critical parser, and neither is
a superset of the other.** Found while porting manga-translator's harness work
back upstream before refreshing it (releases 47 and 48 took the other two
findings; this is the one that could not be ported).

The component is the thing that decides WHICH PATHS a shell command would write
to. The phase lock is only as good as that answer: a target it fails to derive
is a frozen file written unchallenged, and a target it invents is a refusal on a
command that writes nothing. `CLAUDE.md` law 5 says never to route around the
lock, which makes this the one parser in the tree where both error directions
are expensive.

**What upstream has** (`.claude/hooks/phase-guard.sh`, inline `CANDIDATES`):

  * redirect clauses stripped once, so every later rule reads text with no `>`
    in it - the fix for a family of false positives that had survived nine
    enumerated shapes;
  * `sed -i` decided PER WORD: a single-dash word is in-place when the letters
    after its `-` include an `i` (`-i`, `-i.bak`, `-ni`, `-Ei`, `-rin`). The
    substring test it replaced refused `sed -n '1,5p'
    tests/guards/layer-imports.test.ts` - a pure read - because the FILENAME
    contains `-i`, while missing `-ni` entirely, so `sed -ni 's/a/b/'
    src/main.ts` rewrote frozen source unchallenged. Same bug from two ends.
  * `--in-place` as a PREFIX test, because GNU getopt_long honours any
    unambiguous abbreviation and `--i` is unambiguous for GNU sed 4.9.

**What manga-translator has** (`write_candidates`, factored into
`.claude/hooks/lib.sh`, one awk):

  * a named function in `lib.sh` rather than an inline pipeline in the hook, so
    the answer can be asked for rather than re-derived - which is the same rule
    `rules.md` states for `classify.sh`;
  * ROLES. Each candidate carries the part it played, tab-separated, so a
    denial can say `operand: destination` instead of naming a path with no
    account of why it is a write target;
  * `cp`/`mv`/`rm`/`touch` handled by operand position, with `mv -t DIR` /
    `--target-directory` INVERTING the roles - DIR is the destination and every
    positional is a source, whatever its position. Measured there against GNU
    coreutils 8.32;
  * `no_candidate()`: a write command from which NO target could be parsed is
    logged to `.claude/state/phase-guard-declined.log` rather than passing
    silently. Upstream has that log file and writes it from elsewhere, but has
    no equivalent of this specific "a write parsed to nothing" record.

**Neither side can simply take the other.** Upstream's `sed` analysis is
strictly better and downstream lacks it. Downstream's role tracking and `mv -t`
semantics are strictly better and upstream lacks them. They are the same
function, evolved apart for about thirty-five releases, and the role reporting
in denials cannot be lifted out of the parser it rests on.

**Why this is a story and not a port.** The two other findings from the same
round were additive - a new branch test in a hook, a new fingerprint check in
`gates.sh` - and each landed with its downstream tests in an afternoon. This one
replaces the decision procedure of the phase lock. Doing it by copying one side
over the other loses real defences in whichever direction it is done, and doing
it by hand without a corpus drawn from both sides is how a parser that refuses
reads and permits writes gets shipped green.

**The corpus already exists on both sides and is the main asset.** Upstream's
`.claude/tests/phase-guard.test.sh` runs 188 assertions; manga-translator's runs
289. Neither suite's cases were written from the other's failures. The union is
the specification this story is really about, and the first job is to run each
suite's cases against the other's parser and record which fail - because those
are precisely the behaviours one side knows about and the other does not.
## Acceptance criteria

- **AC-1** - Given the union corpus (every case from upstream's
  `phase-guard.test.sh` and every case from manga-translator's), when the
  reconciled parser is asked for each command's write targets, then every case
  from BOTH suites passes. *Control:* the corpus is recorded BEFORE the parser
  is written, with each side's current pass/fail against the other's parser
  named per case - a case no existing parser fails is a case that proves
  nothing about the reconciliation.
- **AC-2** - Given `sed` invoked with `-n`, `-i`, `-i.bak`, `-ni`, `-Ei`,
  `-rin`, `--i`, `--in-pl` and `--in-place`, when targets are derived, then the
  in-place forms yield the file as a write target and the read-only forms yield
  none. *Control:* a filename containing `-i` (the real
  `tests/guards/layer-imports.test.ts` case) under `sed -n` yields NO target.
- **AC-3** - Given `mv a b DEST`, `mv X d/`, `mv -t DIR a b` and
  `mv --target-directory DIR a b`, when targets are derived, then each operand
  carries the role it actually plays, and `-t`/`--target-directory` inverts
  which operand is the destination. *Control:* the same token is reported as a
  source in one form and a destination in the other.
- **AC-4** - Given a command the parser classifies as a write but from which no
  target can be derived, when the guard runs, then the attempt is recorded in
  `.claude/state/phase-guard-declined.log` and the command is not silently
  permitted. *Control:* a command from which targets ARE derived writes nothing
  to that log.
- **AC-5** - Given a denial, when the guard reports it, then the message names
  the operand's role alongside the path. *Control:* a denial for a path with no
  meaningful role does not invent one.
- **AC-6** - The parser lives in one place, and every caller asks it rather than
  re-deriving. *Verified by review* - see `## Deferred verifications`.
- **AC-7** - `.claude/tests/phase-guard.test.sh` executes at least as many
  assertions as the two suites did separately for the behaviours both covered,
  and `.claude/tests/floors.conf` records the new count. *Control:* the floor is
  the executed count, not the call-site count.

## Out of scope

- **Any new shell construct.** This reconciles two parsers over the constructs
  they already handle between them. A twelfth false-positive shape discovered
  during the work is a finding to record, not a criterion to add.
- **`classify.sh` and the category rules.** What a path IS remains
  `paths.conf`'s answer; this story is only about which paths a command WRITES.
- **manga-translator's refresh.** That is what this unblocks, not what it does.
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


Filed 2026-09-23, out of the port-before-refresh round that produced releases
47 and 48. That round found three things manga-translator had and upstream did
not; two were additive and shipped the same day. This is the third, and it was
deliberately NOT attempted there.

**Why it was not just done.** The other two were a new branch test in a hook and
a new fingerprint check in `gates.sh` - each landed with its downstream tests
and neither changed a decision procedure. This one replaces the phase lock's
own. Copying either side over the other loses real defences in whichever
direction it is done: upstream's per-word `sed -i` analysis closed a hole that
let `sed -ni` rewrite frozen source, and downstream's role tracking is what lets
a denial say which operand it is talking about. Attempting the merge inside a
port round, with no corpus reconciling the two, is how a parser that refuses
reads and permits writes gets shipped green.

**It blocks a refresh.** `manga-translator` is on a bare-date stamp
(`2026-09-11`, pre-numbering) and cannot be refreshed losslessly until this
lands: `refresh-harness.sh` REPLACES `.claude/hooks/**` and `scripts/*.sh`, so a
refresh today overwrites `write_candidates`, the role machinery and
`no_candidate` with upstream's versions, and takes the downstream suite that
pins them at the same time. That is the H26 shape, and it is the third time this
round has had to be stopped for it.

**The first task is measurement, not design.** Run each suite's cases against
the other's parser and record which fail. Upstream's suite is 188 executed
assertions, downstream's 289, and neither was written from the other's failures
- so that table IS the specification, and it is cheap to produce before anyone
argues about implementation. AC-1's control exists because a case both parsers
already pass proves nothing about the reconciliation.

**Where the two parsers are**, for whoever picks this up:

  * upstream: `.claude/hooks/phase-guard.sh`, the inline `CANDIDATES` block
    (search for `NOREDIR=`), plus its long comment on the nine/eleven shapes;
  * downstream: `manga-translator/.claude/hooks/lib.sh`, `write_candidates()`,
    one awk with `emit`/`emitr`/`allops`/`lastop`, and `no_candidate()` in that
    project's `phase-guard.sh`.

Do not read either as authoritative. They disagree, and the disagreement is the
story.
