---
id: HARNESS-020
title: A project declares its own suites' floors in a file the refresh keeps
slug: a-project-declares-its-own-suites-floors
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-020-a-project-declares-its-own-suites-floors
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest.sh, .claude/tests/selftest.test.sh, .claude/tests/refresh.test.sh, .claude/tests/floors.conf]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Found on 2026-10-01 while refreshing `fantasy-world-builder` (FWB) from release
45 to 62. After the refresh, FWB's full `bash scripts/selftest.sh` fails before
running a single suite:

```
FAIL project-ci  no floor line in .claude/tests/floors.conf; every suite must declare one
FAIL project-handoff  no floor line in .claude/tests/floors.conf; every suite must declare one
FAIL project-harness-deps  no floor line in .claude/tests/floors.conf; every suite must declare one
FAIL project-sections  no floor line in .claude/tests/floors.conf; every suite must declare one
FAIL project-sigpipe  no floor line in .claude/tests/floors.conf; every suite must declare one
```

The assertion-floor audit (ported from manga-translator's MT-039) requires a
floor for **every** suite in `.claude/tests`. A consuming project's own suites
are named `project-*.test.sh` precisely so the refresh keeps them. But the only
place a floor can be declared, `.claude/tests/floors.conf`, ships upstream and is
**replaced on every refresh**. So a project can satisfy the audit only by editing
an upstream file, which the next refresh then wipes and flags as `LOCAL`. Every
consuming project with its own suites fails its selftest after refreshing, and
with it the CI job that runs the selftest first: FWB's `boundaries.yml` does.

The fix is a project-owned floors file that the refresh keeps:
`.claude/tests/project-floors.conf`. Upstream never ships it, so
`refresh-harness.sh` already treats it as `KEPT`, the same as `project-*.test.sh`.

Required gate that would fail if this story's artifact broke: `unit`
(`bash scripts/selftest.sh`, which runs `selftest.test.sh` and `refresh.test.sh`).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — Given a suite whose floor is declared only in
  `.claude/tests/project-floors.conf`, when the full `bash scripts/selftest.sh`
  runs, then the floors audit accepts it, and that floor is enforced: the run
  fails when the suite executes fewer assertions than declared, and passes when
  it executes at least that many.
- **AC-2** — Given a suite with a floor in neither file, when the full selftest
  runs, then it fails, and the message names both
  `.claude/tests/floors.conf` and `.claude/tests/project-floors.conf`, so a
  project knows where its own suite's floor belongs.
- **AC-3** — Given `project-floors.conf`, when a line in it is malformed, names
  a suite with no `.claude/tests/<name>.test.sh`, or names a suite that also
  has a floor in `floors.conf`, then the full run fails, naming
  `.claude/tests/project-floors.conf`, the line number, and the fault.
  *Control:* with no `project-floors.conf` at all, behaviour is exactly as
  before. An upstream tree passes, and the absence is not a fault.
- **AC-4** — Given a single-suite run (`selftest.sh <name>`) of a suite floored
  in `project-floors.conf`, then that floor is enforced, as a single-suite run
  already enforces a `floors.conf` floor.
- **AC-5** — Given a project with a `.claude/tests/project-floors.conf`, when
  `refresh-harness.sh` runs (dry run and real), then the file is reported
  `KEPT`, not `LOCAL`, and survives byte-identical. *Control:* upstream's
  `floors.conf` in the same refresh is still replaced.

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

RED may amend any block here in place, with a reason. GREEN builds what the
amended block says.

**Writes:** `scripts/selftest.sh`, `.claude/tests/selftest.test.sh`,
`.claude/tests/refresh.test.sh`, `.claude/tests/floors.conf`

### `scripts/selftest.sh`

- A second floors file, `PROJECT_FLOORS_REL=".claude/tests/project-floors.conf"`,
  is resolved from `$ROOT`, the same way `FLOORS_REL` is.
- The loading loop becomes one function applied to each file:
  `load_floors <abs-path> <rel-path>`, called for `floors.conf` and then,
  **only if it exists**, for `project-floors.conf`. It keeps the same grammar,
  the same three faults (not a floor line, unknown kind, names a missing suite,
  not a number), and the same messages, with `<rel-path>:<lineno>` in place of
  the hard-coded `$FLOORS_REL:$lineno`. So existing fault strings for
  `floors.conf` are unchanged, byte for byte.
- **A suite floored in both files is a fault**, recorded against
  `project-floors.conf`'s line:
  `.claude/tests/project-floors.conf:<n>  floor for '<name>' is already declared in .claude/tests/floors.conf; a suite has one floor`.
  The duplicate is not loaded.
- The missing-floor message on a full run becomes:
  `<name>  no floor line in .claude/tests/floors.conf or .claude/tests/project-floors.conf; every suite must declare one (a project's own suites go in project-floors.conf)`.
  This is the one existing message that changes, so any existing test that pins
  the old text is a caller (see below).
- `.claude/tests/floors.conf` absent remains a fault, as today.
  `project-floors.conf` absent is never a fault.
- The process budget stands: no new forks per suite (DV-5 in the file).
  Loading a second file is one more `while read` loop, not a subprocess.

### `.claude/tests/floors.conf`

Its header gains one paragraph saying that a consuming project's own suites
declare their floors in `project-floors.conf`, which upstream never ships and
the refresh keeps. **No floor value changes**, so the hand-copied table in
`selftest.test.sh` is untouched.

### Callers of the changed message

The missing-floor text changes, so every test that matches
`no floor line in .claude/tests/floors.conf` is a caller. RED must grep for it
and update every one in the same phase; this story may change those
assertions' needles, because the criterion they serve is unchanged.
Orchestrator's grep, 2026-10-01:
`grep -rn 'no floor line' .claude/tests/ scripts/` returns only
`selftest.test.sh:242-243`, whose needle is the bare `no floor line`, which the
new text still contains. So no existing assertion needs changing. RED re-runs it and lists
the results in the handoff.

### `refresh-harness.sh`

**No change expected.** It keeps any file inside a replaced directory that
upstream does not ship, and upstream does not ship `project-floors.conf`. AC-5
pins that. If RED finds the refresh does not keep it, that is a finding, and the
Contract gains a block.

**Upstream must never ship `.claude/tests/project-floors.conf`.** If it ever
did, the refresh would replace every project's file. That is out of scope for a
guard here; it is noted in `## Out of scope`.

### Oracle partition

Everything is mechanical: exact fault strings, exact exit statuses, KEPT and
LOCAL lines.

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

- **Defect put back: the project file is not read.** With the call that loads
  `project-floors.conf` removed from `selftest.sh`, AC-1's fixture MUST fail
  with the missing-floor fault. RED cannot run this, because the call does not
  exist yet. **Owner: GATES.** Run it with `scripts/mutate.sh` against
  `bash .claude/tests/selftest.test.sh`.

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

Planned by `bash scripts/plan.sh write HARNESS-020` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `opus` | planning is the judgement phase: decomposition, the oracle partition, and what goes in the contract |
| RED | `test-developer` | `opus` | the lock freezes none of the paths this story names, so the contract is not an aid to the model here - it is the only enforcement there is. A weaker model against a safety net and a weaker model against nothing are different propositions |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `opus` | reading review feedback against the contract is judgement, and a wrong call here ships |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation, with no failing test in front of any of it |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- A guard that upstream never ships `project-floors.conf`.
- Raising any floor in `floors.conf`.
- Changing which files `refresh-harness.sh` replaces.
- Writing FWB's floors. That happens in FWB's refresh, after this merges.

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

