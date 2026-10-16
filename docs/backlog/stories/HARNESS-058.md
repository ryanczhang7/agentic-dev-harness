---
id: HARNESS-058
title: The Rust profile runs every test binary on its test gates and warns off --ignore-run-fail
slug: the-rust-profile-runs-every-test-binary
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-058-the-rust-profile-runs-every-test-binary
depends_on: [HARNESS-055] # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/skills/stack-profiles/reference/rust-cargo.md, .claude/tests/profiles.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

A port from the consuming project manhwa-cropper (`D:/manhwa-cropper`, commits
`b8ded77` MC-057 and `b23198c` MC-058, 2026-09-29), found by a triage on
2026-10-11 of every harness file that project changed locally. It is one of the
ports that must land upstream before manhwa-cropper's harness is refreshed;
the refresh replaces `.claude/skills/**`, so without it the guidance is lost.

**The defect.** By default `cargo test` stops at the first test *binary* with a
failing test and never runs the rest, so a change that breaks five suites
reports one, and the other four surface one re-run at a time. `cargo llvm-cov`
behaves the same. `--no-fail-fast` runs them all and still exits non-zero, so
the gate still fails; on a passing run the output is unchanged, so evidence
lines and floors read the same numbers. `cargo llvm-cov` also offers
`--ignore-run-fail`, which runs every test too but **exits 0** when tests fail
and the report succeeds: on a required gate that is a failing test graded as a
pass.

The upstream profile (release 94) has neither flag and no warning:

    $ grep -rn 'no-fail-fast\|ignore-run-fail' .claude/ docs/ scripts/
    (no output)
    $ sed -n 11,12p .claude/skills/stack-profiles/reference/rust-cargo.md
        gate | unit      | required | . | cargo test --workspace
        gate | coverage  | required | . | cargo llvm-cov --workspace --fail-under-lines 100

Nothing in `.claude/tests/profiles.test.sh` pins the cargo test-gate commands
today, so no test would notice the flag being dropped again. The required gate
holding this story's artefact is the harness self-test (`profiles` suite).

Split out of HARNESS-055 (the `no-count` declaration), which also edits
`rust-cargo.md` and `profiles.test.sh`: no mechanism is shared, so it is its own
story, and `depends_on` orders it after 055 to avoid the textual collision.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given `rust-cargo.md`'s `## Gate commands for project.conf` block,
  when `profiles.test.sh` reads its `gate | unit` and `gate | coverage` lines,
  then each command carries `--no-fail-fast` as a whole word, and the `unit`
  command still carries `--workspace`. Fails today (neither carries it).
  *Negative control:* the same check run over a fixture block whose `unit` line
  is `cargo test --workspace` must report it missing.
- **AC-2** — Given the same profile, when `profiles.test.sh` reads every
  `gate |` line in it, then none carries `--ignore-run-fail`; and the profile's
  prose names `--ignore-run-fail` together with the fact that it exits 0 on
  failing tests. The first half passes today (a guard, earned by DV-1); the
  second fails today. *Negative control:* a fixture `gate | coverage | required
  | . | cargo llvm-cov --workspace --ignore-run-fail` must be refused.
- **AC-3** — The profile explains why: a paragraph after the `--workspace`
  paragraph saying cargo stops at the first failing test binary, that
  `--no-fail-fast` runs them all and still exits non-zero, and that a passing
  run's evidence and floors are unchanged. Pinned by the presence of the phrase
  `first test *binary*` in that section. Fails today.

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

**Writes:** `.claude/skills/stack-profiles/reference/rust-cargo.md`, `.claude/tests/profiles.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Re-anchored 2026-10-16 (Lead PO, before RED), after HARNESS-055 landed.**
Verified by grep today: the gate block is `rust-cargo.md:9-13` (`unit` at `:11`,
`coverage` at `:12`), the `--workspace` paragraph starts at `:25` and
`## Evidence of work` is `:32`, with 055's three `no-count` lines at `:42-44`
below the evidence lines - C-1's paragraph goes between `:25-31` and `:32`.
`profiles.test.sh` defines `line_of` at `:445`, `section` at `:448` and `RUST`
at `:453` - AFTER the describes at `:130-321` - so the new describe must sit
after `:453` (after the HARNESS-041 AC-5 block at `:517` is the natural place).
Both files classify as `harness` (`bash scripts/classify.sh`), so the lock
permits GREEN's profile edit and no `## Scaffold inventory` is owed for this
`chore`. No file in the tree mentions `--no-fail-fast` or `--ignore-run-fail`.

**PO decision 1 (2026-10-16).** The Contract's "no floor change" is reversed
for the same reason as HARNESS-057's: the `profiles` floor is **116** today
(`floors.conf:54`, mirrored at `selftest.test.sh:545` and in the sentence at
`:564`), and HARNESS-055, the story the Contract waited on, is DONE. RED raises
it to the executed count it reads off its own run, in all three places;
`touches:` and `**Writes:**` widened accordingly.

**C-1. The profile text (GREEN), verbatim from downstream `b23198c`'s final
state**, adapted only in the attribution sentence:

    gate | unit      | required | . | cargo test --workspace --no-fail-fast
    gate | coverage  | required | . | cargo llvm-cov --workspace --no-fail-fast --fail-under-lines 100

and, after the `--workspace` paragraph, before `## Evidence of work`:

    **`--no-fail-fast` on the test gates.** By default cargo stops at the first
    test *binary* with a failing test and never runs the rest, so a change that
    breaks five suites reports one, and the other four surface one re-run at a
    time. `--no-fail-fast` runs them all and still exits non-zero, so the gate
    still fails. On a passing run it changes nothing in the output, so evidence
    lines and floors read the same numbers. Found on a consuming project's
    unit gate, then its coverage gate. `cargo llvm-cov` also offers
    `--ignore-run-fail`, which runs every test too but **exits 0** when tests
    fail and the report succeeds. On a required gate that is a failing test
    graded as a pass: never use it there.

The `task | test` line is left as it is: it is a developer convenience, not a gate.
If HARNESS-055 has changed the gate block's surrounding lines (it adds
`no-count` lines), GREEN anchors on the two `gate |` lines by text, not by line
number.

**C-2. The tests (RED)**, a new `describe` block in `profiles.test.sh` using its
existing `$RUST` variable and `section`/`line_of` helpers. Read the gate block
with the existing section reader; match `gate` lines by id with an anchored ERE
(`^[[:space:]]*gate[[:space:]]*[|][[:space:]]*unit[[:space:]]*[|]`), and the
flag as a whole word (`(^|[[:space:]])--no-fail-fast([[:space:]]|$)`), so
`--no-fail-fast-x` or a commented mention does not satisfy it. The negative
controls (AC-1, AC-2) run the same matcher over a heredoc fixture, not over a
copy of the file, so a matcher that cannot fail is caught in RED.

**Oracle partition:** all three ACs are mechanical (text presence/absence in a
shipped file). Nothing here is settled by judgement.

**No floor change is required**: floors are minima. If RED raises the
`profiles` floor, `.claude/tests/floors.conf` and `selftest.test.sh` join
`touches:` and the story waits for HARNESS-055, which raises the same floor.

## Deferred verifications

- **DV-1 — the defect put back.** With `--no-fail-fast` removed from the `unit`
  line of the shipped profile, AC-1's shipped-file assertion MUST fail, and only
  it. Run via `bash scripts/mutate.sh .claude/skills/stack-profiles/reference/rust-cargo.md
  '/gate | unit/s/ --no-fail-fast//' -- bash scripts/selftest.sh profiles`.
  Owner: GATES. Cannot run in RED: the flag is not in the file yet.
- **DV-2 — the guard earned.** AC-2's "no gate line carries
  `--ignore-run-fail`" passes on arrival. With `--ignore-run-fail` appended to
  the shipped `coverage` line (`mutate.sh ... '/gate | coverage/s/$/ --ignore-run-fail/'
  -- bash scripts/selftest.sh profiles`), it MUST fail. Owner: GATES.

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

Planned by `bash scripts/plan.sh write HARNESS-058` from `.claude/harness/models.conf`.
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

- `no-count` lines in the rust profile: HARNESS-055.
- The `task | test` line: a convenience, not a gate; it keeps fail-fast.
- Other profiles' test runners (vitest, pytest): they already run every file by
  default; nothing found says otherwise, and nothing here measures it.
- Changing any consuming project's `project.conf`: project-owned; manhwa-cropper
  already carries both flags (MC-057/058).

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


**Provenance.** Planned 2026-10-12 by the orchestrator (Opus 5.5), split out of
HARNESS-055 at that planner's recommendation. Source commits:
`git -C D:/manhwa-cropper show b8ded77 b23198c -- .claude/skills/stack-profiles/reference/rust-cargo.md`.
Both commit messages say the change was "probed both ways"; the probe output
is in downstream's `docs/backlog/stories/MC-057.md` and `MC-058.md`, which this
planner did not re-read or re-run.
