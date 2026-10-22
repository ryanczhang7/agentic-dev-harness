---
id: HARNESS-070
title: The gates suite passes in a project whose manifest keeps signatures
slug: the-gates-suite-passes-in-a-project-whos
epic: 
type: fix
status: in-progress
phase: GREEN
branch: story/HARNESS-070-the-gates-suite-passes-in-a-project-whos
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/gates.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Found by the manga-translator refresh to release 96 (2026-10-21), the first
refresh to carry HARNESS-069. Its full selftest failed one suite:

    HARNESS-069 AC-1..AC-11  a failing log with an unexplained signature outlives later failures
      FAIL AC-7: and an example keep-when line in a comment, between the format line and BOOTSTRAPPED=
           expected: yes
           actual:   no (example at none)
      FAIL AC-7: the shipped project.conf carries no live keep-when line
           expected: 0
           actual:   8
    gates: 848 passed, 2 failed

HARNESS-069's "shipped manifest" block in `.claude/tests/gates.test.sh` reads
`$REPO_ROOT/.claude/harness/project.conf` and asserts the TEMPLATE's text: the
keep-when format line once, a commented example, and no live `keep-when` line.
In a project built on the harness that file is the project's own -
`refresh-harness.sh` LEAVES it - and manga-translator's carries eight live
`keep-when` lines (they are why HARNESS-069 exists) and MT-053's own comment
block without the example. So every consumer that uses the feature fails the
gates suite, which CI runs on every refresh PR.

The template/project test already exists: `scripts/check-boundaries.sh`
section 3a-bis scopes its upstream-only check to a repo that is not
bootstrapped - "every real project sets BOOTSTRAPPED=yes; the template never
does". This story uses the same test. No required gate covers the harness's own
scripts (PO-3 of HARNESS-069); the selftest suites are the judge, and CI runs
them.
## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given a repository whose `.claude/harness/project.conf` sets
  `BOOTSTRAPPED=yes` and carries live `keep-when` lines and no commented
  example, when `.claude/tests/gates.test.sh` runs, then none of HARNESS-069's
  template-text assertions about that file (the format line once, the commented
  example, no live line) is asserted, and the suite prints one line saying they
  were not and why. Without the fix the same tree fails two of them (the
  Context's output).
- **AC-2** — Given the template (`project.conf` without `BOOTSTRAPPED=yes`),
  the three template-text assertions still run unchanged, and a live
  `keep-when` line added to it still turns
  `AC-7: the shipped project.conf carries no live keep-when line` red.
- **AC-3** — In both trees, the assertions that do not depend on the template's
  text still run: the live-line reader's control, and `--audit` passing (and
  exiting 0) on a copy of the real manifest.

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

**Writes:** `.claude/tests/gates.test.sh`

One block, in `.claude/tests/gates.test.sh`, HARNESS-069's
`# --- AC-7: the shipped manifest ---` section (after `SHIP69=` and `live69()`).
The three template-text assertions - format line once, example between format
line and `BOOTSTRAPPED=`, `0` live lines - go inside

    if tr -d '\r' < "$SHIP69" | grep -qE '^BOOTSTRAPPED=yes'; then
      printf '    note: %s\n' "project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)"
    else
      ...the three assert_eq calls, unchanged...
    fi

The live-line reader's control (`live.conf`, counts 2) and the `--audit` pair
stay outside the `if`, unchanged. The test for "is this the template" is the
one `check-boundaries.sh` 3a-bis uses (`^BOOTSTRAPPED=yes`); nothing new
decides it. `grep -q` on a `tr` pipe of a small file under pipefail: the file is
read whole by `tr` before grep can exit only if it is under the pipe buffer;
RED checks `check-sigpipe.sh` and, if it objects, captures with `$(...)` first.

No production file changes: this is a defect in a test, so GREEN is a verified
no-op. Floors: `gates` is floored at 682 and a bootstrapped tree runs 847 of
850, so `floors.conf` does not move.

Oracle partition: all three criteria are mechanical (exact assertion names,
exact counts). There is no metric.

## Deferred verifications

**DV-1 (the fix, against the consumer's shape of manifest).** With the real
`.claude/harness/project.conf` mutated through `scripts/mutate.sh` so that
`BOOTSTRAPPED=no` reads `BOOTSTRAPPED=yes` and one live
`keep-when | unit | x` line follows it, `bash scripts/selftest.sh gates` must
report `0 failed` and print the note once. The same mutation against the
unfixed suite is the reproduction (measured downstream, Context). RED owns it:
the corrected test exists only from RED on, and there is no production code.
**Owner: RED.**

Result, RED, 2026-10-21 (orchestrator). Against the corrected test, in this
tree:

    === mutate: .claude/harness/project.conf (2 line(s) changed by s/^BOOTSTRAPPED=no$/BOOTSTRAPPED=yes
keep-when | unit | x/) ===
        FAIL AC-5: and its audit says it passed
        FAIL AC-5: and exits 0
        note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
        FAIL AC-7: the shipped manifest's --audit still passes
        FAIL AC-7: and exits 0
        FAIL AC-7: with no FAIL line
    gates: 842 passed, 5 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-070/.claude/state/mutations/.claude_harness_project.conf.20261022T003306Z.1404500.bak) ===

What this shows, and what it does not. The guard engaged: the note printed
once, and none of the three template-text assertions ran (842 = 850 - 3 - 5).
The "0 failed" this entry demanded was mis-specified at PLANNED: setting
`BOOTSTRAPPED=yes` on the TEMPLATE, whose required gates have no commands,
makes `--audit` fail, and five audit assertions (HARNESS-069's AC-7 pair plus
an earlier AC-5 pair that audits the real manifest) report exactly that. A real
bootstrapped project configures its gates, so that is an artefact of the
mutation, not of the fix. The faithful version of the condition is the
consumer's own tree, run below.

The faithful run: the corrected `gates.test.sh` copied into the
manga-translator refresh worktree (`D:/mt-harness-refresh-95`, release 96 plus
this one file; its `project.conf` is `BOOTSTRAPPED=yes` with eight live
`keep-when` lines and MT-053's comment block), `bash scripts/selftest.sh gates`:

    note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
    gates: 847 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (847 assertions executed, 682 declared).
    1 harness suite(s) passed.

The same tree with release 96's unfixed suite (the Context) was
`gates: 848 passed, 2 failed`. That is AC-1, measured where it happens.

**DV-2 (the template still bites).** With only a live `keep-when | unit | x`
line appended to the real `project.conf` (`$a`), `BOOTSTRAPPED` untouched,
`bash scripts/selftest.sh gates` must fail exactly
`AC-7: the shipped project.conf carries no live keep-when line` and nothing
else, with the note not printed. **Owner: RED.**

Result, RED, 2026-10-21 (orchestrator), in a detached worktree at db2c9b0:

    === mutate: .claude/harness/project.conf (1 line(s) changed by $a keep-when | unit | x) ===
        FAIL AC-7: the shipped project.conf carries no live keep-when line
    gates: 849 passed, 1 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-070-dv2/.claude/state/mutations/.claude_harness_project.conf.20261022T003319Z.1404839.bak) ===

Exactly the one assertion, and no note: in the template the rule still bites.

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

Planned by `bash scripts/plan.sh write HARNESS-070` from `.claude/harness/models.conf`.
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

- Any other suite that reads the real `project.conf`. This story fixes the one
  the manga-translator refresh measured failing; a sweep for the same defect
  elsewhere is a separate question.
- `scripts/gates.sh` and the keep-when feature itself: unchanged.
- Raising floors (`floors.conf` and `selftest.test.sh`'s `COUNTS`).

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


**Who ran what (orchestrator, 2026-10-21).** Planned, RED and the rest of this
story were run directly by the orchestrating session, which resolved to
**Opus 5.5 (`claude-opus-5-5`)**, not dispatched to `lead-po` (fable) and
`test-developer`. A departure from the plan above, for a one-block test fix
found in the middle of a consumer refresh, whose diagnosis and reproduction
were already in hand. Success condition: DV-1 and DV-2 come out as stated; if
either does not, the story goes back to planning with `lead-po`.
