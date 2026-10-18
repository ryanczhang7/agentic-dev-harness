---
id: HARNESS-063
title: phase-guard restores the session's phase after judging a write into another worktree
slug: phase-guard-restores-the-session-s-phase
epic: 
type: chore
status: in-progress
phase: RED
branch: story/HARNESS-063-phase-guard-restores-the-session-s-phase
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/phase-guard.test.sh, .claude/tests/worktree.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(survivor G03). The required gate is the harness self-test (`phase-guard` and
`worktree` suites).

When a write targets another worktree of the same repository,
`.claude/hooks/phase-guard.sh` (lines 50-62) saves the session's lock state,
loads the owning worktree's, judges the path there, and restores the saved
state. Deleting the restore of `PHASE` (` PHASE=$sv_phase`, line 58) survives
both `phase-guard.test.sh` (378 passed, 0 failed) and `worktree.test.sh` (73
passed, 0 failed). So nothing pins that a command writing first into another
worktree and then into its own tree has its second target judged under its
own phase rather than the other tree's. Whether the mutant lets such a write
through or refuses it wrongly depends on which phases the two trees are in;
the audit did not build that fixture, so RED shows both directions.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — Given this worktree in GREEN (tests frozen) and another worktree
  of the same repository in RED, when one Bash command writes first to a test
  file in the other worktree and then to a test file in this one, then the
  second write is refused (this tree's GREEN), naming this tree's phase.
- **AC-2** — Given this worktree in RED and the other in GREEN, when one Bash
  command writes first to a source file in the other worktree and then to a
  test file in this one, then the command is allowed: the first write under
  the other tree's GREEN, the second under this tree's RED. *Control:* with
  the other tree in RED instead, the same command is refused on the other
  tree's source file, naming that tree's story, its phase and the
  `worktree:` it was judged in.
- Both pass on arrival if the current code is right, so each is earned by
  mutant G03 (line 58's ` PHASE=$sv_phase` removed) going red, recorded in
  `## Regressions`.

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

**Writes:** `.claude/tests/phase-guard.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Pinned by the Lead PO on 2026-10-18, on main at `6e85c28`.** RED may amend
any block below in place with a reason; what the amended block says is what
the story claims. `.claude/hooks/phase-guard.sh` is NOT written by this story:
the audit judged line 58 correct and the test absent. If RED finds the guard
wrong, that is an escalation, not a fix. Every path here classifies as
`harness`; no `## Scaffold inventory` is owed (no source file changes).
`worktree.test.sh` stays in `touches:` only as a permitted alternative home
(C-1); it is not expected to change.

**C-0. The line under test, verified today.** `phase-guard.sh:50-62` is
`check_path`'s cross-worktree branch: it saves `STORY_ID`, `STORY_SLUG`,
`PHASE`, `STORY_TYPE` and `BRANCH`, loads the owning worktree's state, judges
the path, and puts them back. Line 58 is
`STORY_ID=$sv_id; STORY_SLUG=$sv_slug; PHASE=$sv_phase`. The guard's Bash path
loops over every write target of one command and calls `check_path` for each;
`deny` exits at the FIRST refusal, so a command is refused on its first
refused target and nothing after it is judged.

*Amended by RED, 2026-10-17:* "first" means first in **`sort -u` order**, not
command order. The Bash branch builds `CANDIDATES` through
`grep -vE ... | sort -u` (phase-guard.sh, the line after the `$`-filter
comment, :162) and the loop at :187-235 reads that sorted list. Nothing
the test writes in the command can change which target is judged first; the
collation does. See C-2.

**C-1. Where the tests go.** New assertions in `.claude/tests/phase-guard.test.sh`,
in a new `describe "HARNESS-063 ..."` block placed after the HARNESS-035 AC-4
block (`:1485`), reusing the HARNESS-035 fixture as it stands: `H035_A` (the
session's tree, what `CLAUDE_PROJECT_DIR` names), `H035_B` (a linked worktree
of A under a different folder name), `h035_state <tree> <id> <phase>` and
`h035_reason Bash command '<cmd>'` (the denial text, or empty when allowed).
No new helper is needed. RED may put them in `worktree.test.sh` instead, with
a reason.

**C-2. The commands, verbatim shape** (`$H035_B` expanded by the test):

    printf x > $H035_B/tests/main.test.ts; printf y > tests/main.test.ts   # AC-1
    printf x > $H035_B/src/main.ts; printf y > tests/main.test.ts          # AC-2 and its control

The first target is absolute (so `check_path` takes the cross-worktree branch)
and comes first in the command; the second is relative to A. RED re-reads the
target loop and confirms the order targets are judged in is the order they
appear; if it is not, the command is reordered, not the claim.

*Amended by RED, 2026-10-17, with the reason:* the order is NOT the order they
appear. Targets are judged in `sort -u` order (C-0), so reordering the command
cannot help and was not done; the commands stay as above. What puts B's target
first is that `$H035_B` is an absolute path beginning with `/` (or a drive
letter), which collates before `t` byte-wise - true under `C`/`C.UTF-8` (the
default on ubuntu-latest and in Git Bash here, where `LANG` is unset; also
measured with `LC_ALL=en_US.UTF-8` on this host: absolute first). A
punctuation-ignoring glibc locale could compare `tmp...` with `tests...` and put
A's target first, and then AC-1 and AC-2 would pass unmutated AND under G03 -
toothless, silently. So the block opens with a **premise assertion** that runs
the same `sort -u` over the two targets and requires B's first; on such a
machine it goes red instead of letting the two criteria pass without pinning
anything.

**C-3. The needles.**
- *AC-1* (A=GREEN, B=RED): refused, and the reason contains `story:    T-A`,
  `phase:    GREEN` and `path:     tests/main.test.ts`, and does NOT contain
  `worktree:` (the session's own tree is judged without one; HARNESS-035's
  control at `:1469` pins the same).
- *AC-2* (A=RED, B=GREEN): `h035_reason` returns empty.
- *AC-2 control* (A=RED, B=RED): refused, with `story:    T-B`,
  `phase:    RED`, `path:     src/main.ts` and `worktree: $H035_B`.

**C-4. Baseline the orchestrator measured, on a scratch fixture of the same
shape** (two real worktrees, the shipped `paths.conf`/`phases.conf`, through
`scripts/mutate.sh`, restored and `--check` clean):

| Command | Unmutated | With G03 (line 58's `PHASE` restore removed) |
|---|---|---|
| AC-1 | refused: T-A, GREEN, `tests/main.test.ts`, no `worktree:` | **allowed** (B's RED leaked into A) |
| AC-2 | allowed | **refused**: T-A, GREEN, `tests/main.test.ts` (B's GREEN leaked into A) |

So G03 fails AC-1 by letting a frozen test through and AC-2 by refusing a
legal write: both directions the Context asks for. The AC-2 control is
unaffected by G03 (the first target is refused before anything leaks), which
is what makes it a control: it shows the first target IS judged, by B.

**C-5. What earns the tests.** Each passes on arrival. One mutation, through
`scripts/mutate.sh`, dry-run today to change exactly line 58:

    bash scripts/mutate.sh .claude/hooks/phase-guard.sh '58s#; PHASE=$sv_phase##' -- bash scripts/selftest.sh phase-guard

Expected: the AC-1 and AC-2 assertions go red (the AC-2 control and every
pre-existing assertion stay green), restored byte for byte, `--check` clean.
RED pastes it into `## Regressions`. The `phase-guard` suite is long on this
host; nothing else may run in the tree while it does (run lock).

**C-6. The floor.** `phase-guard` is floored at **378** at
`.claude/tests/floors.conf:50` and mirrored at `.claude/tests/selftest.test.sh:541`.
RED raises both to the executed count of its clean run, with a dated comment
appended to the end of `floors.conf` (where every floor-raise comment lives).

**C-7. Oracle partition.** Both criteria are mechanical: an exact verdict for
an exact command. No signature changes, so no caller list is owed.

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

- **DV-1 — RED's G03 run, repeated by someone else.** RED's `## Regressions`
  will show G03 turning exactly the AC-1 and AC-2 assertions red. The
  orchestrator re-runs C-5's command at GATES on the committed tests and
  compares: the same assertion names fail, no others, the file is restored and
  `bash scripts/mutate.sh --check` is clean. RED cannot discharge this - it is
  a check on RED's own claim. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-063` from `.claude/harness/models.conf`.
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

None.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One level: the hook driven end to end through `guard` (stdin JSON in, the
`permissionDecision` out), the same level as HARNESS-035's cases, because the
claim is about what one Bash command's verdict is - check_path's restore is
not reachable any cheaper. All in one new describe in
`.claude/tests/phase-guard.test.sh`, directly after HARNESS-035 AC-4, on the
HARNESS-035 fixture (A = session tree, B = real linked worktree). Each case
sets both trees' state first.

| # | Assertion (name as printed) | Covers |
|---|---|---|
| 1 | `premise: the guard's sort judges B's absolute target before A's relative one` | precondition for AC-1/AC-2 to pin G03 at all (C-0/C-2 amendment) |
| 2 | `AC-1: after a legal test write into B (RED), A's own test write is refused by A's story` | AC-1 |
| 3 | `AC-1: under A's phase GREEN, not B's RED` | AC-1 |
| 4 | `AC-1: on A's own path tests/main.test.ts` | AC-1 |
| 5 | `AC-1: judged in the session's own tree, so with no worktree line` | AC-1 |
| 6 | `AC-2: a source write into B (GREEN) then a test write in A (RED) is allowed` | AC-2 |
| 7 | `AC-2 control: with B in RED the command is refused by B's story` | AC-2 control |
| 8 | `AC-2 control: under B's phase RED` | AC-2 control |
| 9 | `AC-2 control: on B's relative path src/main.ts` | AC-2 control |
| 10 | `AC-2 control: naming B as the worktree it was judged in` | AC-2 control |

Out of scope, not pinned: the other four restored variables (`STORY_ID`,
`STORY_SLUG`, `STORY_TYPE`, `BRANCH`). `STORY_ID` happens to be observed by #2
(`story:    T-A`), but no mutant of those was asked for or run.

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

Written by the Test Developer (agent definition `model: opus`; dispatched with
no model override), 2026-10-17.

**Command.**

    bash scripts/selftest.sh phase-guard

It takes `.claude/state/run.lock`; exit 2 means another run holds it - wait.
Measured on this host (Windows, Git Bash): **1339 s** clean, 1032 s under G03.
Local timings only; no CI run was taken. (ubuntu-latest runs the whole
selftest in about 31 s per gates.yml.)

**Clean result, this tree, `phase-guard.sh` unchanged:**

    phase-guard: 388 passed, 0 failed

    assertion floors: all 1 suite(s) met their declared floor (388 assertions executed, 378 declared).
    1 harness suite(s) passed.

388 executed = 378 before + 10 new. The floor is now 388 in both
`.claude/tests/floors.conf:50` and `.claude/tests/selftest.test.sh:541`, with a
dated HARNESS-063 comment appended to the end of `floors.conf`.

**Every new assertion passed on arrival** (the guard is already correct), so
there is no RED failure to show from the plain run. What earns them is G03,
pasted in full under `## Regressions`:

| Mutant | Expression | Red under it | Count |
|---|---|---|---|
| G03 | `bash scripts/mutate.sh .claude/hooks/phase-guard.sh '58s#; PHASE=$sv_phase##' -- bash scripts/selftest.sh phase-guard` | `AC-1: after a legal test write into B (RED), A's own test write is refused by A's story`; `AC-1: under A's phase GREEN, not B's RED`; `AC-1: on A's own path tests/main.test.ts`; `AC-2: a source write into B (GREEN) then a test write in A (RED) is allowed` | `phase-guard: 384 passed, 4 failed` |

Exactly the predicted direction both ways (C-4 reproduced on the real suite):
AC-1 was ALLOWED under G03 (empty reason, so all three positive needles
failed), AC-2 was REFUSED naming `story:    T-A`, `phase:    GREEN`,
`path:     tests/main.test.ts`. Green under G03, as expected: the premise, the
AC-1 `worktree:` absence (vacuously - the reason is empty), all four AC-2
control assertions, and all 378 pre-existing assertions. Restored byte for
byte; `mutate.sh --check` clean.

**Negative control, expected values** (measured, not claims - the suite loads,
so every assertion here has executed):

| Control | Expected | Unmutated (measured) | Under G03 (measured) |
|---|---|---|---|
| AC-2 control (A RED, B RED, same command as AC-2) | refused: `story:    T-B`, `phase:    RED`, `path:     src/main.ts`, `worktree: $H035_B` | refused, all four needles present (4/4 green) | unchanged, 4/4 green - the refusal comes before any restore |
| premise (`sort -u` order) | B's absolute target first | B first (green) | B first (green) |

**Export shape.** None: no module is imported; the tests drive
`.claude/hooks/phase-guard.sh` through `_lib.sh`'s `guard`. They constrain the
denial text's `story:`, `phase:`, `path:` and `worktree:` lines (already pinned
by HARNESS-035) and that a Bash command's targets after a cross-worktree one are
judged under the session tree's PHASE. They do not constrain how check_path
saves or restores state.

**GREEN is expected to be a no-op.** No source changes; `phase-guard.sh` is not
in this story's Writes. GREEN should run the command above and confirm 388/0.

**Discovered - Contract amended in place (C-0, C-2).** The guard judges a Bash
command's targets in `sort -u` order (phase-guard.sh:162), not command order.
The criteria still hold here because the absolute B path collates before
`tests/...` under C / C.UTF-8 (and under en_US.UTF-8 on this host), but on a
punctuation-ignoring collation A's target could be judged first and AC-1/AC-2
would pass under G03 without pinning it. The premise assertion (#1) makes that
case red rather than silently toothless. It reproduces the guard's `sort -u`
rather than asking the guard - a deliberate, narrow duplication; if the
guard's pipeline ever stops sorting, the premise stays green while the order
it claims to mirror changes, so a change to line 162 should revisit this block.

**Files touched:** `.claude/tests/phase-guard.test.sh` (new describe),
`.claude/tests/floors.conf` (line 50, plus appended comment),
`.claude/tests/selftest.test.sh` (line 541), this story (C-0, C-2 amendments,
`## Test plan`, this handoff, `## Regressions`).

**Deferred verifications.** DV-1 is owned by GATES and is a re-run of RED's own
claim; RED cannot discharge it and did not.

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

Not a return from GREEN or GATES: this story's tests were written against a
guard that already satisfies them, so every one passed on arrival and is earned
here instead (rules.md, Non-negotiables). One mutation, audit mutant G03:
line 58's `PHASE=$sv_phase` restore removed. Re-read first:
`grep -n sv_phase .claude/hooks/phase-guard.sh` gave `58:      STORY_ID=$sv_id; STORY_SLUG=$sv_slug; PHASE=$sv_phase`.
Run 2026-10-17 on this tree, 1032 s. Exactly the AC-1 (three positive needles)
and AC-2 assertions went red; the AC-2 control, the premise and all 378
pre-existing assertions stayed green. (The floor was raised 378 -> 388 in
`floors.conf` while this run was in flight; its floor line below still reads
378 declared, and reports 384 executed against the 388 the summary line
counts - not investigated, and not something this story changes.)

    bash scripts/mutate.sh .claude/hooks/phase-guard.sh '58s#; PHASE=$sv_phase##' -- bash scripts/selftest.sh phase-guard

```
=== mutate: .claude/hooks/phase-guard.sh (1 line(s) changed by 58s#; PHASE=$sv_phase##) ===
  58 -       STORY_ID=$sv_id; STORY_SLUG=$sv_slug; PHASE=$sv_phase
  58 +       STORY_ID=$sv_id; STORY_SLUG=$sv_slug

=== mutate: running bash scripts/selftest.sh phase-guard ===

=== phase-guard ===

  RED: quoted arguments are not shell syntax

  RED: real writes to source are still blocked

  RED: a here-string does not open a heredoc

  RED may declare what its tests need, and nothing else

  a redirect belongs to the redirect rule and to no other

  an option's argument is not the file being written

  RED: a path in a variable is still a path

  scripts/mutate.sh is the sanctioned way to mutate a frozen file

  RED: the seven false positives reported from the field

  RED: four more false positives, all of them read-only commands

  A read-only command with no write in it, in any phase

  RED: the harness's own vocabulary in a commit message

  RED: a double-quoted Windows path keeps its backslashes

  RED: three holes found by probing, closed

  RED: a parse the guard cannot believe declines rather than denies

  RED: relative paths resolve against the command's own cwd

  GREEN: tests are frozen, source is not

  Generated output is not source

  No active story means no lock

  a phase the table does not list is refused, not waved through

  WORLD-080: a filename containing -i is not the sed -i option

  HARNESS-010 AC-1: C-1's twenty-two commands under the union rule

  HARNESS-010 AC-3: mv removes its source, so the source operand is judged

  HARNESS-010 AC-3: -t and --target-directory invert the destination

  HARNESS-010 AC-2: every operand of an in-place edit, not the last word

  HARNESS-010 AC-4: a write that parsed to no target leaves a trace

  HARNESS-010 AC-5: the denial names the operand's role

  HARNESS-010 AC-6 and C-4: the hook asks lib.sh rather than re-deriving

  HARNESS-010 C-6: what the reconciled parser must NOT start refusing

  HARNESS-011 AC-2: GREEN freezes the tests DIRECTORY, not only the files

  HARNESS-011 AC-3: RED may write the bare directories RED owns

  HARNESS-031: a project rule X/** covers bare X, through the guard

  HARNESS-035 premise: B and W are linked worktrees of A, C is not

  HARNESS-035 AC-1: the session's tree follows the hook input's cwd

  HARNESS-035 AC-2: an absolute path into a sibling worktree is judged by its lock

  HARNESS-035 AC-3: a worktree nested under the root is its own tree

  HARNESS-035 AC-4: another repository, or a same-named folder, is still outside

  HARNESS-063: the session's phase is restored after a cross-worktree target
    FAIL AC-1: after a legal test write into B (RED), A's own test write is refused by A's story
         expected to contain: story:    T-A
         actual:               
    FAIL AC-1: under A's phase GREEN, not B's RED
         expected to contain: phase:    GREEN
         actual:               
    FAIL AC-1: on A's own path tests/main.test.ts
         expected to contain: path:     tests/main.test.ts
         actual:               
    FAIL AC-2: a source write into B (GREEN) then a test write in A (RED) is allowed
         expected: 
         actual:   BLOCKED by the harness phase lock.    story:    T-A   phase:    GREEN   path:     tests/main.test.ts   category: test  Story is in GREEN. Tests are frozen: make the existing failing tests pass without changing them. If the tests are genuinely wrong, go back to RED rather than editing them here.  If this write is genuinely correct, change the phase deliberately rather than working around the lock:  bash scripts/phase.sh set T-A <PHASE>

  HARNESS-045 AC-1: a git --output target is judged as a write

  HARNESS-045 AC-2: the --output target is judged by its category, not refused outright

  HARNESS-045 AC-3: read-only git stays read-only

  HARNESS-045 AC-4: git mv and git rm keep the rules they already had

  HARNESS-053: a paren inside a quoted argument is data (0937c76)

phase-guard: 384 passed, 4 failed

assertion floors: all 1 suite(s) met their declared floor (384 assertions executed, 378 declared).
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_phase-guard.sh.20261018T031732Z.277.bak) ===
  58:       STORY_ID=$sv_id; STORY_SLUG=$sv_slug; PHASE=$sv_phase
```

Then:

```
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

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

1. **PO decision, AC-2 reworded at PLANNED (2026-10-18), approved by the
   user.** As filed, AC-2 asked one command to be refused on its first target
   AND to report its second target as allowed. The guard denies at its first
   refusal and judges nothing after it (C-0), so the second verdict is never
   produced, and a test of it could not see G03 either. Measured on a scratch
   fixture before the change (C-4). Reworded so the first write is legal in
   the other tree (source, under GREEN) and the second is this tree's test
   write under RED: allowed unmutated, refused under G03. The "names each
   worktree" half moved to the control, where a refusal exists to carry it.
   Changed while PLANNED, so no `## Amendments` entry is owed.

