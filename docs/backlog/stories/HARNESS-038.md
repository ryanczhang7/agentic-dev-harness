---
id: HARNESS-038
title: The worktree premises compare the directory, not its spelling
slug: the-worktree-premises-compare-the-direct
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-038-the-worktree-premises-compare-the-direct
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/phase-guard.test.sh, .claude/tests/worktree.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Found by manga-translator's harness refresh to release 81
(ryanczhang7/manga-translator#71). Its CI runs the self-test on
`windows-latest`, and two suites failed there that pass on upstream's Ubuntu CI
and on this Windows machine. Run 37505575305 (the `gates` job, "Harness
self-test" step):

```
  HARNESS-035 premise: B and W are linked worktrees of A, C is not
    FAIL B shares A's .git
         expected: /tmp/tmp.yYgZrMyJNq/.git
         actual:   /c/Users/runneradmin/AppData/Local/Temp/tmp.yYgZrMyJNq/.git
    FAIL W shares A's .git
         expected: /tmp/tmp.yYgZrMyJNq/.git
         actual:   /c/Users/runneradmin/AppData/Local/Temp/tmp.yYgZrMyJNq/.git
phase-guard: 348 passed, 2 failed
    FAIL a: shares the main checkout's .git
    FAIL b: shares the main checkout's .git
worktree: 71 passed, 2 failed
```

Both are premise checks: "this fixture really is a linked worktree of that
one". Each compares two `pwd` outputs as strings
(`.claude/tests/phase-guard.test.sh:1356-1358`,
`.claude/tests/worktree.test.sh:188-192`). The main checkout's side is reached
through the path `mktemp` returned (`/tmp/…`); the linked worktree's side is
reached through the path git wrote into its `.git` file, which Git for Windows
writes in Windows form (`C:/Users/…/Temp/…`). On that runner the two spellings
of ONE directory do not come back from `pwd` the same. Production code is not
affected: `same_repo` and `is_root` in `.claude/hooks/lib.sh:794-808` compare
with `[ a = b ] || [ a -ef b ]` for exactly this reason, and every
HARNESS-035 assertion beyond the premise passed on that run.

Reproduced off Windows (orchestrator, WSL Ubuntu, git 2.43): a repository
created through a symlinked directory and a linked worktree added under the
real path. The suites' comparison says DIFFERENT; string-or-`-ef` says same:

```
old A=/tmp/h38/link/a/.git
old B=/tmp/h38/real/a/.git
string: DIFFERENT
string-or-ef: same
```

The cause of the differing spellings on that runner is not established
(a short-name `RUNNER~1` temp path is a guess). The fix does not depend on it.

The required gate that runs these suites is the self-test (CI's `gates` job,
"Harness self-test" step); this repository has no configured project gates.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — The "shares A's .git" premise checks in `phase-guard.test.sh`
  (HARNESS-035) and the "shares the main checkout's .git" checks in
  `worktree.test.sh` pass when the two sides are different spellings of the
  same directory: they compare as `[ a = b ] || [ a -ef b ]`, as `same_repo`
  does, not as strings alone.
- **AC-2** — Negative control, same checks: when the "worktree" is in fact a
  separate repository (its own `.git`), each check still fails. `-ef` must not
  make them pass for two different directories.
- **AC-3** — `phase-guard.test.sh`'s "C is a separate repository" check uses
  the same comparison, so a C that IS the same directory under another
  spelling is still caught.
- **AC-4** — The full self-test passes, with assertion counts and floors
  unchanged (the fix replaces comparisons; it adds or removes no assertion).

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

**Writes:** `.claude/tests/phase-guard.test.sh`, `.claude/tests/worktree.test.sh`

A test-only story: every file it writes is a test, so the change is made in
RED and GREEN has nothing to build. There is no production change; `lib.sh`'s
`same_repo` (`:802-808`) is the model, not a target.

- **C-1 `phase-guard.test.sh:1355-1362`.** The premise block compares the
  common git directory of A with B's, W's and C's. Each comparison becomes
  `[ "$a" = "$b" ] || [ "$a" -ef "$b" ]` (or a helper doing exactly that,
  defined beside `_common`). The assertion labels stay byte-for-byte
  (`B shares A's .git`, `W shares A's .git`, `C is a separate repository`),
  as does the number of assertions. For C, "same directory" under the new
  comparison is the failure, as it is today under the string one.
- **C-2 `worktree.test.sh:188-192`.** `main_git` against each linked tree's
  `common`: the same comparison. The label
  `<tree>: shares the main checkout's .git` and the assertion count stay. The
  `own` vs `main_git` case beside it (a linked tree's own git dir is NOT the
  common dir) gets the same comparison for the same reason, so a second
  spelling cannot make it pass by being "different".
- **C-3** `-ef` is a bash test builtin on both MSYS and Linux and needs both
  paths to exist; all of them are directories the fixtures just created.
- **C-4** Counts: unchanged. `floors.conf` and `selftest.test.sh` COUNTS are
  not touched.

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

- **DV-1 (the defect, reproduced in the real suite, before and after).**
  Owner: RED. On Linux (WSL), with the temp directory reached through a
  symlink, `TMPDIR=/tmp/h38/link bash .claude/tests/worktree.test.sh` fails
  `a: shares the main checkout's .git` and `b: …` BEFORE the change (measured
  at PLANNED, below) and passes them AFTER. The same run with `TMPDIR=/tmp` is
  the control: those two pass either way. (Three other assertions fail in both
  WSL runs - `.claude/state` check-ignore cases, from running the Windows
  checkout under WSL - and are not this story's.)

  Measured at PLANNED, before the change:

  ```
  TMPDIR=/tmp/h38/link:
      FAIL a: shares the main checkout's .git
      FAIL b: shares the main checkout's .git
  worktree: 68 passed, 5 failed
  TMPDIR=/tmp (control):
  worktree: 70 passed, 3 failed
  ```

- **DV-2 (AC-2, the new comparison still discriminates).** Owner: GATES. Make
  B a separate repository rather than a worktree of A, with one expression
  through `scripts/mutate.sh` on `phase-guard.test.sh` (replace B's
  `git worktree add` with a `git init` of that path), against
  `bash .claude/tests/phase-guard.test.sh`. `B shares A's .git` MUST fail.

- **DV-3 (the downstream proof).** Owner: REVIEW. After release 82, the
  manga-translator refresh PR (#71) re-run on `windows-latest`: phase-guard and
  worktree pass. Recorded in `## Notes` with the run URL.

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

Planned by `bash scripts/plan.sh write HARNESS-038` from `.claude/harness/models.conf`.
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

- PLANNED: written by the orchestrator itself (`claude-opus-5-5`, Opus 5.5) rather than a `lead-po` dispatch, because the diagnosis, the CI evidence and the reproduction were already in hand in that session. No override.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

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

