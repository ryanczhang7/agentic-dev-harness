---
id: HARNESS-065
title: plan.sh edges are pinned - the AC-count threshold, first-match exceptions, and the write post-condition
slug: plan-sh-s-edges-are-pinned-the-ac-count
epic: 
type: fix
status: in-progress
phase: GREEN
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
  **Amended by RED, 2026-10-19 (reason: the lead was followed to its end).**
  Story content and a fixture `models.conf` cannot reach the branch - the
  orchestrator's note holds, see `## Handoff` for the line-by-line reasoning.
  The ENVIRONMENT can: cmd_write reads the rendered body with
  `tail -n +2 "$tmp"` (`plan.sh:396`, its only use of `tail`), and a `tail`
  shim placed first on PATH by the test, corrupting only that one call, makes
  `plan_body` differ from the candidate's body while the heading count stays
  1. So AC-4 is tested, not amended; no `## Amendments` entry is owed. GREEN
  must keep the rendered body read through a PATH-resolved `tail -n +2
  <temp>` call with exactly those three arguments, or AC-4's fixture
  assertion ("the tail shim corrupted exactly one read") goes red - that
  assertion is a fixture check, and it says so when it fires.

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

- PLANNED, orchestrator (`lead-po` role, this session), 2026-10-19: **Opus 5.5** (`claude-opus-5-5`), the session model. Planned `fable`; the session model was the app's, not this story's choice.
- RED, `test-developer`, 2026-10-19: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override. Planned `opus`; no change.
- GREEN, `feature-developer`, 2026-10-19: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override. Planned `opus`; no change.

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

All in `.claude/tests/plan.test.sh`, at the level the suite already works at:
`scripts/plan.sh` run as a process inside the suite's project fixture (`FIX`, a
copy of `scripts/` taken when the suite starts), every assertion read off the
command's output or the story file on disk. 22 new assertions, none in a loop
or a conditional. All four criteria are mechanical (C-6): each pins an exact
recommendation, model row, heading count or byte-identical section.

| AC | Where | Assertions | On arrival | Earned by |
|---|---|---|---|---|
| AC-1 | "which command to drive the story with", after T-14 | 3 + 2 control | green | P04 (Regressions) |
| AC-2 | end of "the exception mechanism (against MECHANISM_POLICY)" | 1 + 1 order control | green | P10 (Regressions) |
| AC-3 | WORLD-097 write block, after its AC-4 | (a) 5, (b) 4 | **5 red** | watched to fail; DV-1, DV-2 are GATES' |
| AC-4 | WORLD-097 write block, after AC-3 | 1 fixture check + 5 | green | P05 (Regressions) |

The five-criteria control (AC-1), the swapped-order control (AC-2) and the
"every other heading / file minus the section" controls (AC-3) are what make
each primary assertion able to fail for the stated reason only; see the
handoff for what each would let through without it.

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

Written by the Test Developer (RED dispatch, agent definition `model: opus`;
no override was passed to this dispatch, and the dispatch reports itself as
Opus 5.5 - the orchestrator records what it resolved to).

### Command

    bash scripts/selftest.sh plan

Takes `.claude/state/run.lock`; one run at a time. **It takes about 20
minutes on this Windows machine** (measured 2026-10-19, local: `real 20m5s`
for the baseline). The suite's own fixture copies `scripts/` at start, so a
mutation of `scripts/plan.sh` is seen by the whole run.

### RED result (local run, 2026-10-19, plan.sh unchanged)

    write says it wrote only when the file on disk says so (WORLD-097)
      FAIL HARNESS-065 AC-3 (a): and its `## Model guidance notes` section survives the write byte for byte
           expected: ## Model guidance notes
           
           keep me: a hand-written note about the plan.
           - and a second line, with `code` in it.
           actual:   
      FAIL HARNESS-065 AC-3 (a) control: every other heading is where it was, once
           expected: ## Acceptance criteria
           ## Contract
           ## Model guidance notes
           ## Notes
           actual:   ## Acceptance criteria
           ## Contract
           ## Notes
      FAIL HARNESS-065 AC-3 (a) control: and the file minus the new section is the file it was
      FAIL HARNESS-065 AC-3 (b): and its `## Model guidance notes` section survives the write byte for byte
           expected: ## Model guidance notes
           
           keep me: a hand-written note about the plan.
           - and a second line, with `code` in it.
           actual:   
      FAIL HARNESS-065 AC-3 (b) control: and nothing outside `## Model guidance` moved

    plan: 279 passed, 5 failed

284 executed. **Why these are the right failures:** every one is C-1's clobber
and nothing else. The extracted notes section is EMPTY after the write - the
heading and both body lines are gone - while the same runs' `exit / success
lines / headings` assertions read `0/1/1` and pass, i.e. the command exits 0,
prints its success line and leaves exactly one `## Model guidance`, exactly as
C-1 measured. In (a) the plan sits where the notes heading was (so the
plan-body assertion passes today; after C-2 the plan is appended at the end
instead, and it must still pass). In (b) the real heading takes the plan and
the notes heading, matching the prefix second, prints nothing and skips its
body. No failure is in AC-1, AC-2 or AC-4, which pass on arrival as the story
expects, and nothing outside the HARNESS-065 assertions moved (262 before, 262
of the 279 passes are the old ones).

### The assertions, one line each

AC-1 (in "which command to drive the story with", fixtures T-15, T-16):
- `HARNESS-065 AC-1: a story with exactly 6 criteria (AC_MANY) is driven one phase at a time` - first field of `plan next T-15` is exactly `advance-story`.
- `HARNESS-065 AC-1: and the reason cites the criteria count` - output contains `T-15 has 6 acceptance criteria (6 or more).` (the many-criteria branch's own clause).
- `HARNESS-065 AC-1: the bare form recommends advance-story for it too` - `plan T-15` contains `Recommended:  /advance-story T-15` (AC-1 names `plan.sh ID`).
- `HARNESS-065 AC-1 control: one with 5 criteria is not 'many' - it runs end to end` - `plan next T-16` first field exactly `complete-story`.
- `HARNESS-065 AC-1 control: as an ordinary cycle, with its count` - contains `T-16 is an ordinary cycle: a contract to work from, 5 criteria,`.

AC-2 (end of the mechanism block, fixtures T-7, T-8, no contract):
- `HARNESS-065 AC-2: of two exceptions matching the same phase, the FIRST one's model is written` - the whole `^| RED ` line of T-7.md after `plan write` equals ``| RED | `test-developer` | `haiku` | the first matching exception |``. Asserted on the **written story**, not on `plan.sh models`.
- `HARNESS-065 AC-2 control: the same two rows swapped write the other model - order decides, not the row` - same rows in the other order, T-8.md's RED line is ``| RED | `test-developer` | `sonnet` | the first matching exception |``.
- The fixture `models.conf` is written by `two_exceptions`; MECHANISM_POLICY is copied to `$FIX/models.conf.mechanism` first and copied back before either assertion.

AC-3 (WORLD-097 block; fixtures T-54 notes-only, T-55 both; helpers `notes_section`, `notes_fixture`):
- `(a): a story with only ## Model guidance notes - exit / success lines / headings` - `0/1/1`. Green today.
- `(a): and its ## Model guidance notes section survives the write byte for byte` - extracted section (heading through the line before the next `## `) before == after. **Red today.**
- `(a): and the new ## Model guidance section's body is the rendered plan` - `mg_body` == `rendered_plan T-54`. Green today, must stay green after C-2 (appended path).
- `(a) control: every other heading is where it was, once` - **Red today.**
- `(a) control: and the file minus the new section is the file it was` - **Red today.**
- `(b): a story with both headings - exit / success lines / headings` - `0/1/1`. Green today.
- `(b): and its ## Model guidance notes section survives the write byte for byte` - **Red today.**
- `(b): and the real section is replaced by the rendered plan, stale body gone` - `mg_body` == `rendered_plan T-55`. Green today.
- `(b) control: and nothing outside ## Model guidance moved` - `without_mg` before == after. **Red today.**

AC-4 (WORLD-097 block, fixture T-56 `middle`, run with a `tail` shim first on PATH):
- `HARNESS-065 AC-4 fixture: the tail shim corrupted exactly one read, of the plan-write temp file` - the shim's log holds exactly one `.../plan-write.<pid>.md` line. A fixture check: red means the shim was never reached, not that plan.sh is wrong.
- `HARNESS-065 AC-4: a body that does not read back from the candidate exits non-zero`.
- `HARNESS-065 AC-4: and says it refuses to report the write, in one error line` - exactly one whole line `plan: refusing to report a write: docs/backlog/stories/T-56.md would not hold the rendered plan` (`grep -cx`).
- `HARNESS-065 AC-4: and prints no success line`.
- `HARNESS-065 AC-4: and leaves the story file byte-identical to what it was` (`cmp`).
- `HARNESS-065 AC-4: and leaves neither the .new candidate nor the temp file behind`.

### What GREEN must change - C-2, one line

`scripts/plan.sh:401`, the splice's pattern, prefix to whole line:

    -    /^## Model guidance/ { while ((getline line < planfile) > 0) print line; skip = 1; matched = 1; next }
    +    /^## Model guidance$/ { while ((getline line < planfile) > 0) print line; skip = 1; matched = 1; next }

Nothing else in `plan.sh`. In particular do not touch `:396` (the `tail -n +2
"$tmp"` read - AC-4's fault is injected through it, see below), `:419`/`:420`
(already whole-line, and DV-2 mutates `:419`), `:421`, `:216` or `:299`. No
test file, `floors.conf` or `selftest.test.sh` change: they are frozen, and
the floor is already the executed count (284). Expected after C-2: `plan: 284
passed, 0 failed`.

### Export shape the tests pin

No module is imported. The tests pin the CLI of `scripts/plan.sh` as a
process: `plan.sh next ID` prints `advance-story<TAB>ID has N acceptance
criteria (6 or more). ...` for N >= 6 and `complete-story<TAB>ID is an ordinary
cycle: a contract to work from, N criteria, ...` below; `plan.sh ID` prints
`  Recommended:  /advance-story ID`; `plan.sh write ID` renders RED rows as
``| RED | `agent` | `model` | why |``, exits 0 and prints `wrote the model plan
into docs/backlog/stories/ID.md` on success, and on a failed post-condition
exits non-zero with `plan: refusing to report a write:
docs/backlog/stories/ID.md would not hold the rendered plan` on stderr. All of
those exist today and are unchanged by C-2. **Not constrained:** where in the
file the appended section goes beyond "after everything else" (the (a)
"file minus the section" control accepts any trailing blank lines `$(...)`
strips), and the wording of the plan prose (compared against the tool's own
render via `rendered_plan`, not against literal text, in AC-3).

### AC-4: reachable, and how

From **story content or a fixture `models.conf`, unreachable** - the
orchestrator's lead holds, and here is why in full. `plan_body` is `tail -n +2`
of the temp render (`:396`); `body` is the candidate's lines after the first
whole-line `## Model guidance` up to the next `^## ` (`:420`). For them to
differ with `found` = 1:
- the render would need a line beginning `## ` after its heading. Its lines are
  fixed `printf` prose (`:373-379`, `:383-386`), and table rows printed as
  `| %s | ...` (`:381`) - always starting `|`. A models.conf field comes from
  one line of one row through `field()` (`:81`) and `printf %s`, so it cannot
  carry a newline; an empty field collapses `read`'s tab-split but the row
  still starts `|`. The story id reaches the render only as an existing file
  name.
- or the candidate would need the plan somewhere other than right after the
  first whole-line heading. The splice (`:401`) prints the whole temp file at
  the first prefix match and resumes printing only at a `^## ` line (`:402`);
  no line it copies from the story can equal `## Model guidance` (every such
  line matches `:401` first); a second prefix match prints nothing because
  `getline` is already at EOF. In the no-heading case the plan is appended
  last (`:404`) and the read-back runs to EOF.
- the unrenderable case (a file at `.claude/state`, the WORLD-097 AC-2 (b)
  fixture) gives `found` = 0, so the first half of `:421` refuses it, not the
  body comparison.

From **the environment, reachable**: `tail` is resolved through PATH and
`:396` is cmd_write's only use of it. The test puts a shim first on PATH that
passes every call straight to the real `tail` except exactly
`tail -n +2 */plan-write.*.md`, for which it prints the real output plus `a
line the candidate file does not hold`. The candidate is the correct splice,
so `found` = 1 and only `[ "$body" != "$plan_body" ]` can refuse. Nothing in
`plan.sh` is edited. This is my judgement that a PATH shim is "the test's own
fixture" in AC-4's sense; I flag it for the orchestrator rather than treat it
as settled. Consequence for GREEN: keep `:396` as a PATH-resolved
`tail -n +2 "$tmp"` (C-3 amended to say so).

### Passed on arrival, and what earns it

| Mutant | Expression (C-4, line re-read 2026-10-19) | Goes red | Count |
|---|---|---|---|
| P04 | `299s#-ge "$AC_MANY"#-gt "$AC_MANY"#` | AC-1's three (6 criteria -> advance-story; the count clause; the bare form). The two 5-criteria controls stay green, as they must | 276 passed, 8 failed (3 + AC-3's 5) |
| P10 | `216s#break#:#` | both AC-2 assertions (first-wins, and the swapped-order control), each rendering the LAST matching row | 277 passed, 7 failed (2 + AC-3's 5), plus the floor line |
| P05 | `421s# \|\| \[ "$body" != "$plan_body" \]##` | four AC-4 assertions (exit non-zero, refusal line, no success line, story unchanged). The shim check and "nothing left behind" stay green, correctly | 275 passed, 9 failed (4 + AC-3's 5), plus the floor line |

AC-3's five assertions are red under every mutant because they are red in RED;
that is not a mutant effect. Full outputs in `## Regressions`. P12 and the
defect put back are GATES' (DV-2, DV-1): **RED declines both** - DV-1 needs
C-2's fix to exist so it can be reverted, and DV-2 is meaningless before C-2
because the clobber deletes the notes heading the widened count would see.

### Negative controls - expected values

These ran in the suite (no import step here; everything executed), so the
numbers are measured, not claimed. Local run, 2026-10-19.

| Control | Pins against | Expected | Measured (plan.sh unchanged) | Under its mutant |
|---|---|---|---|---|
| AC-1 5 criteria -> `complete-story` | threshold moved down to `-ge 5` | `complete-story` | `complete-story` (pass) | P04: still pass (5 > 6 false either way) |
| AC-2 swapped order -> `sonnet` | second row unable to match, making the first assertion vacuous | `sonnet` row | `sonnet` row (pass) | P10: red, measured `haiku` with the second row's reason |
| AC-3 (a) headings minus MG | notes heading dropped or duplicated | `AC / Contract / MG notes / Notes` | `AC / Contract / Notes` (red - the defect) | - |
| AC-4 shim log | PATH shim never reached | 1 | 1 (pass) | P05: 1 (the shim still runs) |

### Timings

All local (Windows 11, Git Bash), none from CI: baseline `plan` run 20m05s;
the new assertions add about 15 `plan.sh` invocations to a suite of several
hundred. No timeout budget exists in this suite to adjust.

### Other checks run at the end of RED (local, 2026-10-19)

- `bash scripts/gates.sh --fast`: every gate UNCONFIGURED in this repository
  (`BOOTSTRAPPED=no`), so it says nothing about these tests; `selftest.sh` is
  the real judge here.
- `bash scripts/selftest.sh selftest`: `selftest: 268 passed, 0 failed` - the
  COUNTS table (`plan 284`) agrees with `floors.conf`.
- `bash scripts/check-grep-count.sh`: 49 files, 0 findings.
  `bash scripts/check-sigpipe.sh`: 49 files, 0 findings.
- `bash scripts/mutate.sh --check`: no stranded mutation. `git diff
  scripts/` is empty.
- Not run: the other selftest suites. GATES' full run covers them.

### Files touched

- `.claude/tests/plan.test.sh` - the 22 assertions and helpers `two_exceptions`, `notes_section`, `notes_fixture`, the `tail` shim.
- `.claude/tests/floors.conf` - `plan` 42 -> 284 (`:51`), dated HARNESS-065 comment appended. 284 = passes + fails of the RED run, as the brief asked. **But `selftest.sh`'s floor counts PASSES** (`executed_count`, `scripts/selftest.sh:220-231`), so every `plan` run before GREEN also prints `FAIL plan  did 279 units of work, below the floor of 284` and fails the suite on that ground too. Expected; GREEN's 284 passes meet it exactly. If GREEN sees fewer than 284 passes, something is still red - do not read the floor line as the cause.
- `.claude/tests/selftest.test.sh` - COUNTS table `plan 42` -> `plan 284` (`:542`).
- `docs/backlog/stories/HARNESS-065.md` - Contract C-3 (AC-4 paragraph amended in place, with reason), `## Test plan`, this handoff, `## Regressions`.

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

### RED, 2026-10-19 - earning the assertions that passed on arrival

Not a return to RED. AC-1, AC-2 and AC-4 test behaviour `plan.sh` already has,
so their assertions passed on their first run; each is earned by its audit
mutant, run through `scripts/mutate.sh` against `bash scripts/selftest.sh plan`
(local runs, this tree, plan.sh otherwise unchanged). AC-3's five assertions
are red in every run below because they are red in RED (C-1's defect), not
because of the mutant. The P04 run read `floors.conf` before the `plan` floor
was raised (hence `42 declared`); the P10 and P05 runs read 284 and so also
print the floor line - selftest's floor counts passes, see `floors.conf`.

**P04** - `-ge` to `-gt` at `:299`. AC-1's three primary assertions go red;
the two 5-criteria controls stay green, as they must (5 is below 6 either way).

```
=== mutate: scripts/plan.sh (1 line(s) changed by 299s#-ge "$AC_MANY"#-gt "$AC_MANY"#) ===
  299 -   if [ "$acs" -ge "$AC_MANY" ]; then
  299 +   if [ "$acs" -gt "$AC_MANY" ]; then

=== mutate: running bash scripts/selftest.sh plan ===

=== plan ===

  the shipped policy: fable plans, opus builds and tests

  the exception mechanism (against MECHANISM_POLICY)

  which command to drive the story with
    FAIL HARNESS-065 AC-1: a story with exactly 6 criteria (AC_MANY) is driven one phase at a time
         expected: advance-story
         actual:   complete-story
    FAIL HARNESS-065 AC-1: and the reason cites the criteria count
         expected to contain: T-15 has 6 acceptance criteria (6 or more).
         actual:               complete-story	T-15 is an ordinary cycle: a contract to work from, 6 criteria, nothing deferred, no dependency waiting. Run it end to end.
    FAIL HARNESS-065 AC-1: the bare form recommends advance-story for it too
         expected to contain: Recommended:  /advance-story T-15
         actual:               Story T-15
         
           Recommended:  /complete-story T-15
           Because:      T-15 is an ordinary cycle: a contract to work from, 6 criteria, nothing deferred, no dependency waiting. Run it end to end.
         
           Model plan (from .claude/harness/models.conf — a plan, not a record;
           write down what each dispatch RESOLVED to, in ## Model guidance):
         
             PLANNED   lead-po            opus   planning is the judgement phase
             RED       test-developer     fable  the measured case: with a partitioned contract the brief carries the judgement and the model writes sharper negative controls
             GREEN     feature-developer  opus   a weaker model here reaches green by weakening a test
             GATES     feature-developer  opus   same risk as GREEN
             REVIEW    lead-po            opus   a wrong call here ships
             SCAFFOLD  lead-po            opus   source, tests and config in one derivation

  the plan is written into the story, not left to be looked up

  write says it wrote only when the file on disk says so (WORLD-097)
    FAIL HARNESS-065 AC-3 (a): and its `## Model guidance notes` section survives the write byte for byte
         expected: ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         actual:   
    FAIL HARNESS-065 AC-3 (a) control: every other heading is where it was, once
         expected: ## Acceptance criteria
         ## Contract
         ## Model guidance notes
         ## Notes
         actual:   ## Acceptance criteria
         ## Contract
         ## Notes
    FAIL HARNESS-065 AC-3 (a) control: and the file minus the new section is the file it was
         expected: ---
         id: T-54
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-54-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         
         ## Notes
         
         hand-written notes.
         actual:   ---
         id: T-54
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-54-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Notes
         
         hand-written notes.
    FAIL HARNESS-065 AC-3 (b): and its `## Model guidance notes` section survives the write byte for byte
         expected: ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         actual:   
    FAIL HARNESS-065 AC-3 (b) control: and nothing outside `## Model guidance` moved
         expected: ---
         id: T-55
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-55-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         
         ## Notes
         
         hand-written notes.
         actual:   ---
         id: T-55
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-55-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Notes
         
         hand-written notes.

  HARNESS-051: next, models and the bare id refuse a story that has no file

  conflicts: which startable stories would fight over the same file

  conflicts: a story declares the files it touches in frontmatter (HARNESS-006)

  drift reads what a Contract writes (HARNESS-016)

  waves: the planner cuts stories into waves (HARNESS-007)

  conflicts --pairs: the clear pairs, for an orchestrator to read (HARNESS-009)

  after: closing a story names what to run next, and what can run alongside it (HARNESS-018)

plan: 276 passed, 8 failed

assertion floors: all 1 suite(s) met their declared floor (276 assertions executed, 42 declared).
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_plan.sh.20261019T163202Z.93686.bak) ===
  299:   if [ "$acs" -ge "$AC_MANY" ]; then
```

**P10** - the `break` after the first matching exception removed at `:216`.
Both AC-2 assertions go red, each showing the LAST matching row's model and
reason rendered instead of the first's.

```
=== mutate: scripts/plan.sh (1 line(s) changed by 216s#break#:#) ===
  216 -       break
  216 +       :

=== mutate: running bash scripts/selftest.sh plan ===

=== plan ===

  the shipped policy: fable plans, opus builds and tests

  the exception mechanism (against MECHANISM_POLICY)
    FAIL HARNESS-065 AC-2: of two exceptions matching the same phase, the FIRST one's model is written
         expected: | RED | `test-developer` | `haiku` | the first matching exception |
         actual:   | RED | `test-developer` | `sonnet` | the second matching exception |
    FAIL HARNESS-065 AC-2 control: the same two rows swapped write the other model - order decides, not the row
         expected: | RED | `test-developer` | `sonnet` | the first matching exception |
         actual:   | RED | `test-developer` | `haiku` | the second matching exception |

  which command to drive the story with

  the plan is written into the story, not left to be looked up

  write says it wrote only when the file on disk says so (WORLD-097)
    FAIL HARNESS-065 AC-3 (a): and its `## Model guidance notes` section survives the write byte for byte
         expected: ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         actual:   
    FAIL HARNESS-065 AC-3 (a) control: every other heading is where it was, once
         expected: ## Acceptance criteria
         ## Contract
         ## Model guidance notes
         ## Notes
         actual:   ## Acceptance criteria
         ## Contract
         ## Notes
    FAIL HARNESS-065 AC-3 (a) control: and the file minus the new section is the file it was
         expected: ---
         id: T-54
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-54-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         
         ## Notes
         
         hand-written notes.
         actual:   ---
         id: T-54
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-54-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Notes
         
         hand-written notes.
    FAIL HARNESS-065 AC-3 (b): and its `## Model guidance notes` section survives the write byte for byte
         expected: ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         actual:   
    FAIL HARNESS-065 AC-3 (b) control: and nothing outside `## Model guidance` moved
         expected: ---
         id: T-55
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-55-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         
         ## Notes
         
         hand-written notes.
         actual:   ---
         id: T-55
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-55-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Notes
         
         hand-written notes.

  HARNESS-051: next, models and the bare id refuse a story that has no file

  conflicts: which startable stories would fight over the same file

  conflicts: a story declares the files it touches in frontmatter (HARNESS-006)

  drift reads what a Contract writes (HARNESS-016)

  waves: the planner cuts stories into waves (HARNESS-007)

  conflicts --pairs: the clear pairs, for an orchestrator to read (HARNESS-009)

  after: closing a story names what to run next, and what can run alongside it (HARNESS-018)

plan: 277 passed, 7 failed
FAIL plan  did 277 units of work, below the floor of 284 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_plan.sh.20261019T164531Z.117627.bak) ===
  216:       break
```

**P05** - the body comparison removed from the post-condition at `:421`. Four
AC-4 assertions go red: the write is reported (exit 0, success line, no
refusal line) and the story file changes. The fixture check (shim reached
once) and "neither .new nor temp left behind" stay green, correctly: under the
mutant the write completes and cleans up after itself.

```
=== mutate: scripts/plan.sh (1 line(s) changed by 421s# || \[ "$body" != "$plan_body" \]##) ===
  421 -   if [ "$found" != 1 ] || [ "$body" != "$plan_body" ]; then
  421 +   if [ "$found" != 1 ]; then

=== mutate: running bash scripts/selftest.sh plan ===

=== plan ===

  the shipped policy: fable plans, opus builds and tests

  the exception mechanism (against MECHANISM_POLICY)

  which command to drive the story with

  the plan is written into the story, not left to be looked up

  write says it wrote only when the file on disk says so (WORLD-097)
    FAIL HARNESS-065 AC-3 (a): and its `## Model guidance notes` section survives the write byte for byte
         expected: ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         actual:   
    FAIL HARNESS-065 AC-3 (a) control: every other heading is where it was, once
         expected: ## Acceptance criteria
         ## Contract
         ## Model guidance notes
         ## Notes
         actual:   ## Acceptance criteria
         ## Contract
         ## Notes
    FAIL HARNESS-065 AC-3 (a) control: and the file minus the new section is the file it was
         expected: ---
         id: T-54
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-54-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         
         ## Notes
         
         hand-written notes.
         actual:   ---
         id: T-54
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-54-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Notes
         
         hand-written notes.
    FAIL HARNESS-065 AC-3 (b): and its `## Model guidance notes` section survives the write byte for byte
         expected: ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         actual:   
    FAIL HARNESS-065 AC-3 (b) control: and nothing outside `## Model guidance` moved
         expected: ---
         id: T-55
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-55-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Model guidance notes
         
         keep me: a hand-written note about the plan.
         - and a second line, with `code` in it.
         
         ## Notes
         
         hand-written notes.
         actual:   ---
         id: T-55
         title: Fixture story
         slug: fixture
         type: feature
         status: todo
         phase: PLANNED
         branch: story/T-55-fixture
         ---
         
         ## Acceptance criteria
         
         - **AC-1** - it works.
         
         ## Contract
         
         `src/core/world.ts` exports `buildWorld(seed: number): World`.
         
         ## Notes
         
         hand-written notes.
    FAIL HARNESS-065 AC-4: a body that does not read back from the candidate exits non-zero
         expected: non-zero
         actual:   zero
    FAIL HARNESS-065 AC-4: and says it refuses to report the write, in one error line
         expected: 1
         actual:   0
    FAIL HARNESS-065 AC-4: and prints no success line
         expected: 0
         actual:   1
    FAIL HARNESS-065 AC-4: and leaves the story file byte-identical to what it was
         expected: identical
         actual:   differs

  HARNESS-051: next, models and the bare id refuse a story that has no file

  conflicts: which startable stories would fight over the same file

  conflicts: a story declares the files it touches in frontmatter (HARNESS-006)

  drift reads what a Contract writes (HARNESS-016)

  waves: the planner cuts stories into waves (HARNESS-007)

  conflicts --pairs: the clear pairs, for an orchestrator to read (HARNESS-009)

  after: closing a story names what to run next, and what can run alongside it (HARNESS-018)

plan: 275 passed, 9 failed
FAIL plan  did 275 units of work, below the floor of 284 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_plan.sh.20261019T165930Z.140603.bak) ===
  421:   if [ "$found" != 1 ] || [ "$body" != "$plan_body" ]; then
```

After all three:

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

1. **PO decision, approved by the user (2026-10-19, at PLANNED).** Filed as a
   tests-only chore with any change to `plan.sh` out of scope. Probing AC-3
   before RED showed it cannot pass that way: `plan.sh write` destroys a
   `## Model guidance notes` section (C-1). The user chose to let this story
   make the one-line fix (C-2) and keep AC-3 as written. Type changed from
   `chore` to `fix`; `touches:` and Out of scope widened to match. Changed
   while PLANNED, so no `## Amendments` entry is owed.

2. **RED confirmed by the orchestrator (2026-10-19).** `bash scripts/selftest.sh
   plan` on the uncommitted RED tree, 17:18Z to 17:31Z, `scripts/` untouched:

    plan: 279 passed, 5 failed

   The five are exactly RED's AC-3 (a)/(b) assertions, each failing on the
   notes section being gone - C-1's clobber, the right reason.
3. **AC-4's PATH shim accepted as "the test's own fixture".** RED showed that
   no story or `models.conf` content can make the read-back body differ (its
   reasons are in the handoff; they match the orchestrator's reading of
   `plan.sh:373-421`). It injects the fault through the environment instead:
   a `tail` first on PATH that corrupts only `cmd_write`'s one
   `tail -n +2 <plan-write temp>` read, with the shim's own log asserted so a
   PATH the child ignored is a fixture failure. `plan.sh` is not edited, which
   is the line the criterion draws. The cost is a coupling: the test now
   depends on `cmd_write` reading the plan with a PATH-resolved `tail`. RED
   recorded that in C-3, so a later rewrite of that line knows to move the
   shim with it.
4. **GREEN verified by the orchestrator (2026-10-19).** `scripts/plan.sh`
   differs from the RED commit by the one line C-2 names (`:401`,
   `/^## Model guidance/` to `/^## Model guidance$/`), and `bash
   scripts/selftest.sh plan`, 17:44:47Z to 17:57Z:

    plan: 284 passed, 0 failed

    assertion floors: all 1 suite(s) met their declared floor (284 assertions executed, 284 declared).
    1 harness suite(s) passed.

   `gates.sh --fast`: `All required gates passed (0 ran, 5 unconfigured, 0
   known)`; this repository configures no gates.
