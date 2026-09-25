---
id: HARNESS-015
title: Mutation work per story is one targeted probe; exhaustive earning moves to audit-mutations
slug: mutation-work-per-story-is-one-targeted
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-015-mutation-work-per-story-is-one-targeted
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/harness/rules.md, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/commands/audit-mutations.md, .claude/skills/story-authoring/SKILL.md, .claude/skills/story-authoring/reference/sections.md, .claude/skills/tdd-cycle/SKILL.md, scripts/new-story.sh, scripts/gates.sh, .claude/skills/stack-profiles/reference/*.md, .claude/harness/project.conf, .claude/tests/gates.test.sh, .claude/tests/profiles.test.sh, .claude/tests/new-story.test.sh, .claude/tests/policy.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

**Filed 2026-09-25 at the user's request.** The user asked that mutation
checking run **only when they request it, or possibly once per epic**, and not
as part of every story and PR. Today it runs on every story through two
channels, and neither involves the optional `mutation-tester` agent:

1. **The `mutation` gate.** Every stack profile configures it
   (`node-typescript.md:15` `stryker run`, `python-uv.md:13` `mutmut run`,
   `rust-cargo.md:14` `cargo mutants`) as `optional`, with a `slow` line.
   `slow` only keeps a gate out of `--fast`. So in a downstream project the
   mutation tool runs on **every full `gates.sh` run**: every story's GATES,
   and every PR's CI `gates` job. `project.conf:187-195` already carries a
   waiver for one such tool that could not even run. In this repository the
   gate is unconfigured, so nothing runs here.
2. **Per-story mutation duties written as prose.** Three instructions stack:
   * **"Do three mutations"**, in `/advance-story` GREEN → GATES (`:132`),
     `story-authoring/SKILL.md:271`, `reference/sections.md:61`, the story
     template (`scripts/new-story.sh:109`) and `tdd-cycle/SKILL.md:279`.
   * **"Two mutations, one run each"** to verify a handoff's mutation table
     (`/advance-story:301`, `/complete-story:48`).
   * **Each PO's own `## Deferred verifications`**, which nothing bounds.
     HARNESS-014's DV-3 asked for every assertion that passed on arrival to be
     earned. `rules.md` does not require that: it asks for a mutation only for
     a test written or corrected **against code that already exists**, and has
     GREEN confirm the measured values of controls instead.

**What it cost, measured on HARNESS-014** (commit timestamps, Git Bash on
Windows 11; Notes M-1): about 7.5h from PLANNED to REVIEW, of which **about
2h20 was GATES mutation work**: 18 mutations and about 27 full-suite runs.
**None of the 18 found a defect in the code.** Each one confirmed a test that
was already right. The one real defect in that story, two unpassable frozen
assertions, was found by GREEN simply running the suite. The same suites take
76s on CI's Linux runner and 20-30 min locally, so every local mutation run
costs roughly 15-40x what it would cost there.

**Required gate.** `BOOTSTRAPPED=no`, so every `gates.sh` gate is
UNCONFIGURED here. The check that fails if this story's artifact breaks is
`bash scripts/selftest.sh`, specifically the `gates`, `profiles`, `new-story`
suites and a new policy guard. CI runs them as a required step, so
`required_gates: []` is the honest value.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1: a gate can be marked on-request, and a full run then leaves it
  out.** Given a `project.conf` that configures a `mutation` gate and marks it
  on-request (the line's exact form is the Contract's), a full `gates.sh` run
  and a `--fast` run both leave the gate's command unexecuted: a marker that
  the command writes is absent afterwards. Each run's summary carries one line
  naming the gate as not run on request, and saying how to run it. The
  recorded `## Gate results` carries that line, and the overall result is
  unaffected. *Control:* `gates.sh --gate mutation` executes the command, and
  the marker appears. So does a full run for a story whose `required_gates`
  names the gate: the story asked for it.
- **AC-2: an on-request gate cannot be required.** `gates.sh --audit` exits
  non-zero, naming the gate, when an on-request line names a gate whose
  requirement is `required`. *Control:* the same line on an `optional` gate
  passes the audit.
- **AC-3: every stack profile marks its mutation gate on-request.** For every
  profile under `.claude/skills/stack-profiles/reference/` that configures a
  `mutation` gate, the profile also carries the on-request line for it, and the
  `profiles` suite asserts this for each profile it finds. *Control:* with one
  profile's on-request line removed through `scripts/mutate.sh`, that
  assertion fails for that profile by name.
- **AC-4: the per-story mutation budget is stated once, in `rules.md`, and
  every other site defers to it.**
  * **Where it lives:** `rules.md` gains one section, headed `# Mutation work
    per story`, stating the budget:
    - **Required per story:** a mutation that earns each test written or
      corrected against code that already exists (unchanged law); for a story
      that changes a rule over the tree, one probe against a real line of that
      tree (unchanged law); and for the story's central claim, one
      "defect put back" mutation. A format or codec story may add one
      wrong-value mutation.
    - **How a mutation runs:** against the one suite, or the narrowest test
      command, that holds the assertion it targets.
    - **Not per story:** exhaustively earning every assertion that passed on
      arrival, full mutation tables, and the `mutation` gate. Those belong to
      `/audit-mutations`.
  * **The other sites:** `/advance-story`, `/complete-story`,
    `story-authoring/SKILL.md`, `story-authoring/reference/sections.md`,
    `tdd-cycle/SKILL.md` and the story template in `scripts/new-story.sh` each
    name that section. None of them still instructs "three mutations" or "two
    mutations" per story.
  * **How it is checked:** a policy guard suite, with whole-line or anchored
    needles only (`rules.md`, "an assertion's needle is part of the
    assertion"). *Control:* restoring the old `Do three mutations` sentence in
    any one site, through `mutate.sh`, fails the guard for that file by name.
- **AC-5: a new story is born with the budget, not the old rule.** A story
  created by `scripts/new-story.sh` has a `## Deferred verifications` comment
  that names the `rules.md` section. It says that by default a story carries
  one "defect put back" entry for its central claim, and that exhaustive
  earning goes to `/audit-mutations`. The word `THREE` is absent from it.
  *Control:* the `new-story` suite fails when the template still says
  `Do THREE mutations`.
- **AC-6: `/audit-mutations` is where the exhaustive work lives.**
  * Its command file says it runs **on request**. Under Option S (the
    user's decision, 2026-09-25) `/advance-story` REVIEW → DONE also
    *recommends* `/audit-mutations <epic>` in its report when the story it
    closes was the last open story of its epic. It never runs it. A story with
    an empty `epic:` gets no recommendation.
  * Where a `mutation` gate is configured, it runs `bash scripts/gates.sh
    --gate mutation`. It also takes over earning assertions that passed on
    arrival, and verifying handoff mutation tables, for the stories in its
    scope.
  * Neither `/advance-story` nor `/complete-story` dispatches
    `mutation-tester` or runs the `mutation` gate itself.
  * The policy guard of AC-4 checks all three.
- **AC-7: what already holds still holds.** `check-boundaries.sh`'s
  Deferred-verifications checks (an owner named; a pasted result or `WAIVED`)
  and its pasted-output checks for `## Regressions` and `## Gate probes` are
  unchanged, and their existing assertions pass unchanged. `mutate.sh` is
  unchanged.
- **AC-8: floors raised in both places.** Every suite that gains assertions
  (expected: `gates`, `profiles`, `new-story` and the new policy suite) has the
  same new executed count in `.claude/tests/floors.conf` and in
  `selftest.test.sh`'s `COUNTS`, read from `bash scripts/selftest.sh <suite>`.
  `bash scripts/selftest.sh selftest` passes.

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

**Left for PLANNED**, as in HARNESS-012 to HARNESS-014. It depends on the answer to
`## Open question`, and on two shapes the PO pins before RED: the on-request
line's exact form (for example `ondemand | <id> | <why>`, parsed like `slow`) and
the exact summary line of AC-1. The sites it must name are listed in `## Notes`,
M-2.

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

### DV-1. The policy guard, probed against the real tree

*Condition.* With the GREEN tree checked out, restoring the old sentence at a
**real** site (for example `/advance-story`'s `Do three mutations rather than
one`) through `scripts/mutate.sh` **must** fail the policy guard, naming that
file. The control of AC-4 does the same against fixtures; this does it against
the tree the guard judges (`rules.md`, "a rule is probed against the tree it
judges"). **This is the story's only deferred verification, by its own
budget.**

*Why not RED.* The guard fails in RED anyway, because the sites still say
"three mutations". A probe run there proves nothing.

**Owner: GATES**

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

- **Weakening "watched to fail".** Law 1 and the non-negotiables stand as
  written: a test written or corrected against existing code is still earned
  by a mutation, and a rule over the tree is still probed against a real line.
  This story bounds everything *beyond* those.
- **`check-boundaries.sh`.** It keeps checking that each deferred verification
  names an owner and carries a result or `WAIVED`. A story that deliberately
  writes more entries than the budget may still do so. The budget is a default
  for the PO, not a cap that the script enforces.
- **Local suite speed on Windows.** Suites run 15-40x slower here than on CI
  because Git Bash is slow at starting processes. That is real, but it is a
  separate problem: fewer runs is this story, faster runs is not.
- **Re-running or retro-waiving past stories' deferred verifications.**
  HARNESS-014's DV-2 and DV-3 stay as recorded.
- **`mutate.sh` and the `mutation-tester` agent definition.** They are
  unchanged, apart from the command file for `/audit-mutations` (AC-6).
- **Downstream `project.conf` files.** Profiles gain the on-request line, and
  a consuming project picks it up through `refresh-harness.sh` or by adding the
  line by hand. This story does not edit any other repository.

## Open question - DECIDED: Option S (the user, 2026-09-25)

**Is `/audit-mutations` tied to epics, and if so, how?** The user said "only
when I request, or potentially for each epic". The answer changes AC-6's
wording and whether `/advance-story` REVIEW → DONE changes at all.

* **Option Q: on request only.** `/audit-mutations` runs when the user types
  it, and nothing in the story loop mentions it. *For:* the smallest change,
  and nothing runs by surprise. *Against:* nothing reminds anyone, so the
  exhaustive audit may never happen.
* **Option S: suggested at epic close.** When REVIEW → DONE closes the last
  open story of an epic, the orchestrator's report recommends
  `/audit-mutations <epic>`, with the epic's touched paths as scope. It never
  runs it. *For:* the audit arrives at a natural checkpoint and the user
  decides. *Against:* one more line in `/advance-story`, and harness stories
  have no epic, so this repository would behave as under Q.
* **Option A: run automatically at epic close.** *For:* it always happens.
  *Against:* it is the cost the user asked to stop paying on a timer the user
  did not choose, at epic scale instead of story scale.

**PO recommendation: S.** It matches "potentially for each epic" without
spending anything the user has not approved.

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


Filed 2026-09-25 by the orchestrator, at the user's request, straight after
HARNESS-014 closed (release 53, `fda194a`). **The `## Contract` is left for
PLANNED.** Line numbers are at `fda194a`.

### Measurements

**M-1. Where HARNESS-014's time went.** Commit timestamps, local time, on
2026-09-24, Git Bash on Windows 11:

| Commit | Time | Phase closed | Duration |
|---|---|---|---|
| `7543732` | 13:03 | PLANNED | - |
| `dcf6f35` | 14:02 | RED | 1h |
| `4a1dd44` | 16:18 | GREEN | 2h15 |
| `9c95a78` | 17:51 | RED re-entry (R-1) | 1h30 |
| `613c56e` | 20:26 | GATES → REVIEW | 2h35, of which about 2h20 was DV-2 and DV-3 mutations |

The mutation work was 18 mutations and about 27 full-suite runs. They ran
four at a time in detached worktrees, and only the logs from 18:12 to 20:25
survive. **None of the 18 found a defect.** CI for the same PR (#83) took
1m29s for `gates`, whose self-test step was 1m16s, and 4s for `boundaries`.
Locally, `boundaries` alone takes about 15 min and `gates` 7-20 min.

**M-2. Every site that currently prescribes per-story mutation work**
(`grep -rn -i "three mutations\|two mutations"` over `.claude`, `scripts` and
`CLAUDE.md`, story files excluded, plus a read of each command):

| Site | What it says today |
|---|---|
| `.claude/commands/advance-story.md:132` | GREEN → GATES: "Do three mutations rather than one where the entry is about a format or a codec" |
| `.claude/commands/advance-story.md:301` | verifying a mutation table: "Two mutations, one run each, is enough" |
| `.claude/commands/complete-story.md:48` | "A mutation table in the handoff is a claim until you run one" |
| `.claude/skills/story-authoring/SKILL.md:271` | "Do three mutations, and make one a wrong value" |
| `.claude/skills/story-authoring/reference/sections.md:61` | "Three mutations beat one" |
| `.claude/skills/tdd-cycle/SKILL.md:279` | the codec anecdote behind the three-mutation rule |
| `scripts/new-story.sh:109` | template: "Do THREE mutations rather than one" |
| `.claude/harness/rules.md` | the non-negotiables. These are the law that stays; they set no per-story count |

**M-3. The `mutation` gate in every profile.** `stack-profiles/reference/`:
`node-typescript.md:15` (`pnpm exec stryker run`), `python-uv.md:13`
(`uv run mutmut run`) and `rust-cargo.md:14` (`cargo mutants`), each
`optional`. This repository's `project.conf:234` declares the gate with no
command, and `:242` marks it `slow`. `slow` is read only by `--fast`
(`gates.sh:281`), so a full run in a consuming project executes the mutation
tool, and so does CI's `gates` job, which runs a full `gates.sh`.

### PO notes

**PO-A. One story, not two.** Moving the gate onto request (AC-1 to AC-3) and
rewriting the prose budget (AC-4 to AC-6) are the two channels of one
behaviour. The user asked for mutation checking to stop being per-story, and
shipping either half alone leaves the other channel still running it on every
story.

**PO-B. The budget is a default, not a cap.** `check-boundaries.sh` is not
changed to count deferred verifications. A story with a real reason for more,
such as a codec, still writes them. What changes is what the PO writes by
default and what the orchestrator runs by default.

**PO-C. The rule this story keeps.** "A test that has never been observed to
fail is not a test" is untouched. The HARNESS-014 evidence argues for fewer
probes, not for none: X-A, the defect put back, is the one mutation whose
result would have mattered had it gone the other way. It is also the one the
budget keeps.

**PO-D. The Open question is decided: Option S.** The user answered "S" on
2026-09-25. `/audit-mutations` runs on request, and REVIEW → DONE only
*suggests* it when an epic's last open story closes. AC-6 was rewritten to
that form on `main` before the story left PLANNED, so the base branch carries
the final criterion and no `## Amendments` entry is needed (the HARNESS-014
precedent, PO-E).
