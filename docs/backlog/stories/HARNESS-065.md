---
id: HARNESS-065
title: plan.sh edges are pinned - the AC-count threshold, first-match exceptions, and the write post-condition
slug: plan-sh-s-edges-are-pinned-the-ac-count
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-065-plan-sh-s-edges-are-pinned-the-ac-count
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/plan.sh, .claude/tests/plan.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(survivors P04, P05, P10 and P12). `scripts/plan.sh` had never been audited
before; 8 of its 12 mutants were killed. The four that survive `plan.test.sh`
(262 passed, 0 failed) are edges the suite never reaches. None is wrong today,
and each would let a later edit change behaviour without a test noticing:

- **P04** (line 299). `[ "$acs" -ge "$AC_MANY" ]` to `-gt` survives: no story
  fixture has exactly `AC_MANY` (6) acceptance criteria, so the boundary of the
  "many criteria, use advance-story" recommendation is unpinned.
- **P10** (line 216). Deleting the `break` after the first matching `except`
  row survives: first-match-wins among `models.conf` exceptions is unpinned.
  The shipped `models.conf` has no `except` rows today, so this is latent.
- **P12** (line 419). The write post-condition counts `## Model guidance`
  headings by whole line; widening it to `/^## Model guidance/` survives, so a
  story with a `## Model guidance notes` heading is unpinned.
- **P05** (line 421). Removing the post-condition's body comparison
  (`|| [ "$body" != "$plan_body" ]`) survives: the "refusing to report a write"
  branch has never been observed to fire for a body mismatch.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — A story with exactly 6 acceptance criteria (and nothing else
  that recommends advance-story) gets `advance-story` from `plan.sh ID`, citing
  the criteria count; one with 5 does not on that ground.
- **AC-2** — Given a fixture `models.conf` with two `except` rows that both
  match the same phase, `plan.sh write` renders the first row's model.
- **AC-3** — Given a story that already has a `## Model guidance notes`
  heading, `plan.sh write` writes exactly one `## Model guidance` section and
  leaves the other heading in place.
- **AC-4** — When the rendered body cannot be read back unchanged from the
  candidate file (fault injected through the test's own fixture, not by editing
  `plan.sh`), `plan.sh write` exits non-zero with "refusing to report a write"
  and the story file is unchanged.
- Each passes on arrival, so each is earned by its audit mutant (P04, P10, P12,
  P05) going red, recorded in `## Regressions`. If AC-4 cannot be reached
  without editing `plan.sh`, say so in `## Amendments` rather than weakening it.

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

**Writes:** `scripts/plan.sh`, `.claude/tests/plan.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Pinned by the Lead PO on 2026-10-19, on main at `4490906`.** RED may amend
any block below in place with a reason; GREEN builds what the amended block
says. Every path classifies as `harness`. No exported signature changes, so no
caller list is owed; `plan.sh write` keeps its interface and output.

**C-0. The lines, verified by `grep -n` today.**

    scripts/plan.sh:216   break                        (first matching except row wins)
    scripts/plan.sh:236   AC_MANY=6
    scripts/plan.sh:299   if [ "$acs" -ge "$AC_MANY" ]; then
    scripts/plan.sh:401   /^## Model guidance/ { ... skip = 1; matched = 1; next }   (the splice)
    scripts/plan.sh:419   found="$(awk '$0 == "## Model guidance" { n++ } ...)"     (post-condition count)
    scripts/plan.sh:421   if [ "$found" != 1 ] || [ "$body" != "$plan_body" ]; then

**C-1. The defect AC-3 exposes (measured by the orchestrator before RED).** The
splice at `:401` matches `## Model guidance` as a PREFIX, so a story holding
`## Model guidance notes` has that heading and its whole body replaced by the
plan. Fixture: a story with `## Model guidance notes` / `keep me` and no
`## Model guidance`. After `plan.sh write`: exit 0, success line printed,
`keep me` gone (0 occurrences), the notes heading gone. With BOTH headings
present, the notes section is likewise replaced. This is also why P12 survives:
the clobber removes the very heading P12's widened count would see.

**C-2. The fix (GREEN), one line.** `:401`'s pattern becomes whole-line,
`/^## Model guidance$/`, the same match `:419` and `:420` already use. Nothing
else in `plan.sh` changes. With it, a story that has only `## Model guidance
notes` gets the plan appended at the end (the existing `!matched` path) and the
notes section is left byte-for-byte; a story with both keeps the notes section
and has the real one replaced.

**C-3. Where the tests go.** `.claude/tests/plan.test.sh`, using its helpers:
`story_with <id> <type> <phase> <ac-count>` (writes N criteria as
`- **AC-n** - it works.`), `ordinary`, `plan`, and for write cases
`write_fixture`, `mg_count`, `mg_body`, `headings`, `identical`, `present`,
`success_lines` (WORLD-097 block, `:418-608`).
- *AC-1 (P04).* Beside the "many criteria" case (`T-14`, 9 criteria, `:353`):
  a story with exactly 6 criteria and a contract gets `advance-story` from
  `plan.sh next`, and the reason names the count (`has 6 acceptance criteria`).
  Control: 5 criteria gets `complete-story`.
- *AC-2 (P10).* In or after "the exception mechanism (against
  MECHANISM_POLICY)" (`:179`): a fixture `models.conf` (write it, run, put
  MECHANISM_POLICY back) with two `except | RED | no-contract | <model> | ...`
  rows naming DIFFERENT models; a story with no contract renders the FIRST
  row's model for RED in `plan.sh models` / `write`. Choose two model names
  that make the order visible (not the same as the base row's).
- *AC-3 (P12, and C-1's defect).* In the WORLD-097 block: (a) a story with
  `## Model guidance notes` plus body and NO `## Model guidance`; after write,
  exactly one `## Model guidance` (whole line), the notes heading and its body
  still there byte-for-byte, exit 0. (b) a story with both; after write, one
  `## Model guidance`, notes section intact. Red today on the notes body.
- *AC-4 (P05).* The `[ "$body" != "$plan_body" ]` branch fires only when the
  candidate file's section body differs from the rendered plan. RED looks for
  a fixture-only way to make that happen (a story or a fixture `models.conf`
  whose rendered body cannot be read back unchanged) and if there is none,
  records that under `## Amendments` with the reasoning, as the AC itself
  directs, rather than weakening the criterion. The orchestrator's note: the
  body is read back by an awk that stops at the next `^## ` line, and the plan
  table's rows start with `|`, so a rendered `why` field cannot open a heading;
  that is where to start looking, not a conclusion.

**C-4. What earns what.** AC-1, AC-2 and (if reachable) AC-4 pass on arrival
and are earned by their audit mutant through `scripts/mutate.sh`, output
pasted in `## Regressions`. AC-3 is a real RED today (C-1); it is earned by
watching it fail, and its P12 mutant is a GATES check (DV-2). The expressions,
dry-run today to change exactly their line (RED re-reads the line numbers):

    P04  bash scripts/mutate.sh scripts/plan.sh '299s#-ge "$AC_MANY"#-gt "$AC_MANY"#' -- bash scripts/selftest.sh plan
    P10  bash scripts/mutate.sh scripts/plan.sh '216s#break#:#' -- bash scripts/selftest.sh plan
    P05  bash scripts/mutate.sh scripts/plan.sh '421s# || \[ "$body" != "$plan_body" \]##' -- bash scripts/selftest.sh plan
    P12  bash scripts/mutate.sh scripts/plan.sh '419s|$0 == "## Model guidance"|/^## Model guidance/|' -- bash scripts/selftest.sh plan

**C-5. The floor.** `plan` is 42 at `.claude/tests/floors.conf:51` and in the
COUNTS table at `.claude/tests/selftest.test.sh:542`. The suite executes far
more (262 at the audit); the floor is a minimum. RED raises both to the
executed count of its RED run (passes plus fails), with a dated comment
appended at the end of `floors.conf`.

**C-6. Oracle partition.** All four are mechanical: an exact recommendation,
model name, heading count or byte-identical section for an exact fixture.

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

- **DV-1 — the defect put back.** With C-2's fix reverted (`:401` back to the
  prefix match `/^## Model guidance/`), AC-3's notes-section assertions MUST
  fail. RED cannot run this: the fix does not exist until GREEN. Run with
  `scripts/mutate.sh` against `bash scripts/selftest.sh plan`. **Owner: GATES.**
- **DV-2 — P12 against the fixed splice.** With `:419`'s count widened to
  `/^## Model guidance/` (C-4's P12 expression, line re-read), AC-3 (b) MUST
  fail: the post-condition counts the notes heading too and refuses the write.
  RED cannot run it meaningfully: before the fix the splice deletes that
  heading, so the mutant sees one heading and stays green. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-065` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `fable` | planning is the judgement phase - decomposition, the oracle partition, the contract - and planning is what fable is judged best at |
| RED | `test-developer` | `opus` | writing the failing tests, the negative controls and the handoff is development work, and opus is judged the stronger model for it |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

Any change to `plan.sh` beyond the one line C-2 names (the splice match). PO decision 1 in `## Notes` says why that one is in.

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

1. **PO decision, approved by the user (2026-10-19, at PLANNED).** Filed as a
   tests-only chore with any change to `plan.sh` out of scope. Probing AC-3
   before RED showed it cannot pass that way: `plan.sh write` destroys a
   `## Model guidance notes` section (C-1). The user chose to let this story
   make the one-line fix (C-2) and keep AC-3 as written. Type changed from
   `chore` to `fix`; `touches:` and Out of scope widened to match. Changed
   while PLANNED, so no `## Amendments` entry is owed.

