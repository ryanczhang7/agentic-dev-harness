---
id: HARNESS-093
title: gates.sh --list still lists a duplicated gate id and an empty evidence regex
slug: gates-sh-list-still-lists-a-duplicated-g
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-093-gates-sh-list-still-lists-a-duplicated-g
depends_on: [HARNESS-094, HARNESS-095]      # the fast pre-PR self-test goes first (user decision, 2026-11-04); both must be DONE
touches: [.claude/tests/gates.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

HARNESS-088 (PR #177, merged 2026-11-04) made `scripts/gates.sh` refuse a
gate id declared twice (line 511-520, `is_dup`) and an `evidence` line whose
regex is empty (line 601-607), under `--audit` and on a run. Both refusals are
guarded by `[ "$LIST" = 0 ]`, because `--list` is not a judge: its Contract
C-1 says `--list` "prints the duplicate's two lines and an empty `evidence:`
as it does today". No test pins that. HARNESS-088's diff review round 1
(Should fix 1) found the gap and PO decision 9 deferred it to a follow-up
(`HARNESS-088.md`, `## Notes`): with either `LIST` guard deleted, `--list` on
such a file would silently lose a row - the `continue` runs before the row is
printed - and every `--list` assertion in `gates.test.sh` would stay green,
since none runs on a faulty manifest. Verified before this story was cut:
`grep -n 'describe "HARNESS-088' .claude/tests/gates.test.sh` finds the two
HARNESS-088 describes, and neither calls `gates --list`.

Measured on the shipped `gates.sh` (release 107) over a manifest holding
`BOOTSTRAPPED=yes`, two identical `gate | unit | required | . | printf 'Tests
47 passed (47)\n'` lines and `evidence | unit |`, `bash scripts/gates.sh
--list` exits 0 and prints exactly four lines, the row and its `evidence:`
line twice (the `evidence:` line ends in one space, `%s` of an empty regex):

```
unit         required  .      printf 'Tests  47 passed (47)\n'
                              evidence: 
unit         required  .      printf 'Tests  47 passed (47)\n'
                              evidence: 
```

This is a test written against code that already exists, so it passes the
moment it is written; it is earned by the two `LIST`-guard mutations in
`## Deferred verifications`. A `chore`: it changes no behaviour and adds the
missing test. The phase path is RED (the test), a verified no-op GREEN, GATES
and REVIEW, as HARNESS-021 ran a test-only story; SCAFFOLD is not used.

Required gate that would fail if this story's artifact broke: none is
configured in this repository; the artifact is judged by the self-test,
`bash scripts/selftest.sh gates`, which CI runs in full on the PR.

## Acceptance criteria

- **AC-1** — Given a project.conf whose `gate | unit` line is declared twice
  and whose `evidence | unit |` regex is empty, when `bash scripts/gates.sh
  --list` runs, then it exits 0 and its output is exactly the four lines in
  Context: the `unit` row twice (`count_line` of the row = 2) and the
  `evidence: ` line twice, with no `FAIL` line and no `manifest problem`
  line. *Control:* `--audit` on the same file prints HARNESS-088's two FAIL
  lines (`H88_EMPTY_AUDIT`, then `H88_DUP_AUDIT`) and exits 1, so the file
  under test is the faulty one and `--list` alone lets it through.
- **AC-2** — Given the same manifest with the second `gate | unit` line
  deleted, when `--list` runs, then the row and the `evidence: ` line each
  appear once, exit 0 - so AC-1's count of two is the duplicate being
  listed, not the row being printed twice for one line.

## Contract

**Writes:** `.claude/tests/gates.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria do not inherit that: a change to
one of them goes through `## Amendments`.

**C-1. Where and how.** One `describe "HARNESS-093 AC-1/AC-2: --list lists a
duplicated id and an empty evidence regex, both lines, exit 0"` in
`gates.test.sh`, after HARNESS-088's second describe (its C-1 "where the two
faults meet" block, line 4220-4226) and before the closing `set_phase`/
`summary` lines, built with HARNESS-088's own helpers so the manifest is the
one its tests judge: `h88_conf "$H88_GATE" "$H88_GATE" 'evidence | unit |'`,
`gates --list`, `count_line` (line 843, `grep -cxF`, a whole line). The
expected row is `"$(printf '%-12s %-9s %-6s %s' unit required . "printf 'Tests  47 passed (47)\\n'")"`
and the expected evidence line `"$(printf '%-12s %-9s %-6s evidence: %s' '' '' '' '')"`,
formed by the same `printf` formats `gates.sh` uses (line 618-619) so the
trailing space is in the needle by construction, never typed. AC-1 pins the
whole output with one `assert_eq` of the four lines against `$out`, and the
counts and the absence of `FAIL`/`manifest problem` with `count_line`; the
`--audit` control reuses `h88_fails`. AC-2 is the same with `h88_conf
"$H88_GATE" 'evidence | unit |'`. The fixture ends with `set_phase "$FIX" ""`
and `git -C "$FIX" checkout -q -- .` as the neighbouring blocks do.

**C-2. What `--list` is pinned to.** Row and `evidence:` line for every `gate`
line in file order; nothing else for this manifest (no floor, covers, waiver,
skip, slow or on-request line is declared). Exit 0 from line 915
(`[ "$LIST" = 1 ] && exit 0`), which no fault count changes - which is why
the listed-row count, not the exit status, is what the mutations move
(`## Deferred verifications`).

**C-3. Floors.** `floor | gates | 972` in `floors.conf` and the hand copy
`gates 972` in `selftest.test.sh` (line 538) rise in RED to the executed
count (expected about 972 + 10). `VERSION` bumps in GREEN to the number after
whatever the file holds when GREEN is reached (107 today; HARNESS-091 and
HARNESS-092 are planned alongside and take the next free number each).

**C-4. Phases.** Test-only, as HARNESS-021: RED writes everything in
`**Writes:**` except `VERSION`; GREEN is a verified no-op the orchestrator
checks itself (`git diff --stat main...HEAD` names only the four written
paths and this story; `bash scripts/selftest.sh gates` green) plus the
`VERSION` bump.

**C-5. Oracle partition.** All **mechanical**: exact lines and counts,
measured on the shipped script and recorded in Context; RED reads them out.

## Deferred verifications

- **DV-1, earning AC-1 against the duplicate guard.** With the `LIST` guard
  dropped from the duplicate fault -
  `bash scripts/mutate.sh scripts/gates.sh 's/\[ "\$is_dup" = 0 \] \&\& \[ "\$LIST" = 0 \]/[ "$is_dup" = 0 ]/' -- bash .claude/tests/gates.test.sh`
  - AC-1 MUST go red: the row and `evidence:` line are listed once (the
  second line `continue`s into the fault before line 617 prints it), while
  the exit status stays 0; AC-2 and every HARNESS-088 assertion stay green.
  A test written against existing code cannot be watched to fail in RED;
  this is its earning. **Owner: GATES.**
- **DV-2, earning AC-1 against the empty-regex guard.** With the `LIST` guard
  dropped from the empty-regex fault -
  `bash scripts/mutate.sh scripts/gates.sh 's/\[ -z "\$exp" \] \&\& \[ "\$LIST" = 0 \]/[ -z "$exp" ]/' -- bash .claude/tests/gates.test.sh`
  - AC-1 AND AC-2 MUST go red: no `unit` row is listed at all (every line
  `continue`s at line 601-607), exit still 0. The two mutations are different
  guards and are both owed, one each, because either alone leaves the other
  guard untested. **Owner: GATES.**

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

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-093` from `.claude/harness/models.conf`.
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
- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1**
  (2026-11-04), dispatched as a `/plan-story` subagent planning HARNESS-091..093
  together; no model override was passed. Context, AC, Contract, Deferred
  verifications and Out of scope were written in this dispatch.

**Oracle partition:** every criterion is mechanical - exact `--list` lines and counts measured on the shipped script and recorded in Context; RED reads them out and forms the needles with the same `printf` formats `gates.sh` uses.

## Out of scope

- Changing `scripts/gates.sh`: `--list` behaves as HARNESS-088 C-1 says and
  this story only pins it.
- `--audit`, run and `--gate` behaviour on the faulty manifest (HARNESS-088
  AC-1..AC-4, already pinned).
- Any other `--list` case (floors, covers, skips) on a faulty manifest.

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

