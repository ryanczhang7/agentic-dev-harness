---
id: HARNESS-072
title: The full self-test step runs with SELFTEST_JOBS=4
slug: the-full-self-test-step-runs-with-selfte
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-072-the-full-self-test-step-runs-with-selfte
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/tests/procedure.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

The GATES → REVIEW procedure runs the whole harness self-test once per story,
on the orchestrator's machine. `/advance-story` step 2 and `/complete-story`'s
matching bullet both spell it `bash scripts/selftest.sh`, so it runs one suite
at a time. Measured on the Windows/Git Bash host this harness is developed on:

- HARNESS-036 (2026-10-05): 1,135 s serial against 336 s with
  `SELFTEST_JOBS=4`, identical per-suite results (`scripts/selftest.sh` header,
  HARNESS-036 DV-2).
- HARNESS-050..068 (`## Notes` of each): 2,894 s to 17,015 s serial, with
  nearly the same suites, while self-tests from other projects on the same
  host (manga-translator, fantasy-world-builder, clean_calendar) were running.
  Fork+exec measured 196 ms and a subshell 53 ms during those runs. Contention
  is the likely cause; it was never measured on an idle host, so it is a
  likelihood and not a diagnosis.
- CI's whole `gates` job on ubuntu-latest: 140-210 s (HARNESS-054..061),
  205-223 s (HARNESS-067..071), with `SELFTEST_JOBS` unset.

`SELFTEST_JOBS` is opt-in by design (HARNESS-034 `## Out of scope`, HARNESS-036
`## Context`: default 1 locally, CI leaves it unset), and its correctness is
pinned: `selftest.test.sh` asserts byte-identical stdout and identical stderr
for a fixture run at `SELFTEST_JOBS=1` and `=3`, per-run buffers under
`.claude/state/selftest.<pid>/`, and the same exit status. Every full run is
also under the per-tree run lock (HARNESS-034), so a second run in the same
tree is refused rather than racing. Nothing in that design is changed here:
this story changes the *procedure* that asks for the run, in the two command
files, and the test that pins their wording.

The pin is `.claude/tests/procedure.test.sh` (HARNESS-032, HARNESS-068). It
matches the step by the whole token `` `bash scripts/selftest.sh` `` -
`STEP_SELFTEST`, line 43 - and its real-tree assertion ("procedure_problems
over the real tree prints nothing", line 473) is what fails when the two
commands drift from each other or from the procedure. A step reading
`` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` does not contain that token,
so the needle has to move with the text, and the control that today refuses a
targeted run (`` `bash scripts/selftest.sh reporting` ``, the
`selftest-targeted` case) has to keep refusing it under the new spelling.

**PO decision 1 - why 4, and why under contention too.** 4 is the value
measured on this host; the self-test is spawn-bound and the slowest suite
(`phase-guard`) sets the floor whatever the value. Under contention the
alternative on record is the serial run, at 2,894-17,015 s, so a value that
was 3.4x faster idle is not what makes a contended host slow. The step says
what to expect: slower, not wrong; keep the value; look for an orphaned run
before blaming the host (the existing sentence). It does not pick a different
number per host, because a number re-chosen every story is the habit the
harness's model policy exists to stop, and a lower value has no measurement
behind it.

The required gate that fails if this story's artifact breaks: the harness has
no `project.conf` gates; the self-test (`procedure` suite) is what judges it,
and CI runs the full self-test on every pull request.

## Acceptance criteria

- **AC-1** — Given this repository, when `procedure_problems` (the
  `procedure` suite's checker) runs over the real tree, then it prints
  nothing, and `/advance-story`'s GATES → REVIEW paragraph has a numbered step
  whose text contains the whole token
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``, numbered after the
  `diff-review` step and before `` `bash scripts/phase.sh set $1 REVIEW` ``,
  which is before `` `bash scripts/check-boundaries.sh` ``.
  *Control:* a fixture whose step reads the old spelling,
  `` `bash scripts/selftest.sh` ``, with everything else compliant, gets
  exactly one line, naming the file and the missing token:
  ``.claude/commands/advance-story.md: its GATES → REVIEW steps do not name `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``.
- **AC-2** — Given `/complete-story`, when the checker runs, then its
  `- **GATES → REVIEW` bullet contains the same whole token, and names
  `` `diff-review` `` before it.
  *Control:* a bullet reading ``the full `bash scripts/selftest.sh` `` (old
  spelling) gets exactly one line:
  ``.claude/commands/complete-story.md: its GATES → REVIEW bullet does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``.
- **AC-3** — Given the advance-story step, when the checker reads it, then it
  says `detached`, `Windows`, `## Notes` (the existing words) and
  `other test runs` - the sentence that tells the orchestrator what a slow run
  on a shared host means: slower, not wrong; the value is kept and no suite is
  swapped out.
  *Control:* the compliant fixture with `other test runs` removed from that
  step gets exactly one line:
  ``.claude/commands/advance-story.md: its `SELFTEST_JOBS=4 bash scripts/selftest.sh` step does not say `other test runs` ``.
- **AC-4** — Given a step that names a single suite,
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh reporting` ``, when the
  checker runs, then it is reported as not naming the full run (one "do not
  name" line), exactly as the old spelling's `selftest-targeted` case is
  today. *Control:* the compliant fixture, with the full token, is silent.
- **AC-5** — Given the real tree, when `bash scripts/selftest.sh procedure`
  runs, then the suite passes and its executed count meets its floor in
  `floors.conf`, with that floor recorded twice (`floors.conf` and
  `selftest.test.sh`'s copy) as the floors file's header requires.

## Contract

**Writes:** `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/tests/procedure.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Oracle partition.** All five criteria are *mechanical*: pin the tokens and
the fault lines exactly, byte for byte. Nothing here is a measurement; the
timings in `## Context` are settled numbers to be read out into the step's
prose, not re-measured.

**The needle (settled, read out).** In `procedure.test.sh`:

    STEP_SELFTEST='`SELFTEST_JOBS=4 bash scripts/selftest.sh`'
    STEP_WORDS=('detached' 'Windows' '## Notes' 'other test runs')

`TOOL_SELFTEST='Bash(bash scripts/selftest.sh:*)'` is unchanged: the
allowed-tools entry is a tool pattern, and `SELFTEST_JOBS=4 bash ...` is
still `bash scripts/selftest.sh` invoked by the Bash tool with an environment
assignment in front. Every fault line that quotes the needle (`no_step`,
`no_word`, `NO_BULLET_NEEDLE`, `BULLET_REVIEW_AFTER`, the out-of-order lines)
quotes the new one. `compliant_fixture`, `GOOD_STEPS` and `GOOD_BULLET` carry
the new spelling; the `selftest-targeted` case carries
`` `SELFTEST_JOBS=4 bash scripts/selftest.sh reporting` ``; a new case carries
the OLD spelling as AC-1's and AC-2's control. HARNESS-068's review-ordering
cases (`review-after-selftest`, `review-same-step-as-selftest`, the
`bullet-*` cases) move to the new token and keep their verdicts.

**The step text (advance-story, step 2 of GATES → REVIEW).** One numbered
step, beginning `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` — ``. It keeps
every sentence the current step has (detached run, nothing else in this
worktree, judge by exit status and last line, paste into `## Notes`, the
orphan check, failure routes) and replaces the duration sentence with the
measured ones: CI about 2-4 minutes; this host 336 s at `SELFTEST_JOBS=4`
against 1,135 s serial (HARNESS-036), and 2,894-17,015 s serial while other
test runs shared the host (HARNESS-050..068). It adds, in these words or
near them: "When other test runs share the host the run is slower, not wrong:
keep the value, do not swap in named suites." The phrase `other test runs`
is the pinned word. `complete-story`'s bullet names
``the full `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` after `` `diff-review` ``.

**Callers of the changed token.** `grep -rn 'bash scripts/selftest.sh'` over
`.claude/commands/`, `.claude/tests/procedure.test.sh`, `CLAUDE.md`,
`.claude/skills/`: only the two command files and `procedure.test.sh` carry
the GATES → REVIEW spelling. `CLAUDE.md`'s "Running things" line and
`refresh-harness.sh:518` describe the plain command and stay as they are;
`gates.yml` stays `bash scripts/selftest.sh` (CI leaves `SELFTEST_JOBS`
unset, HARNESS-036; `ci-local.test.sh` derives its list from the workflow and
does not move).

**Floors.** `procedure` is 37 today. RED records the executed count it
measures (`bash scripts/selftest.sh procedure` on this tree) in both files in
the RED commit, as `floors.conf`'s header says.

## Deferred verifications

**DV-1 (defect put back; the story's central claim). Owner: GATES.** With the
value removed from the real step -
`bash scripts/mutate.sh .claude/commands/advance-story.md 's/`SELFTEST_JOBS=4 bash scripts\/selftest.sh`/`bash scripts\/selftest.sh`/' -- bash scripts/selftest.sh procedure`
- the real-tree assertion ("procedure_problems over the real tree prints
nothing") **must** go red with the AC-1 fault line, and the file is restored.
RED cannot run it: the needle does not match the tree until GREEN edits the
command, so the suite is red for the right reason throughout RED. Paste the
failing line and `mutate.sh`'s restore line.

**DV-2 (the other command). Owner: GATES.** The same mutation on
`.claude/commands/complete-story.md`'s bullet **must** go red with the AC-2
fault line. One line of `sed`, one suite run, paste both.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-072` from `.claude/harness/models.conf`.
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

- PLANNED — `lead-po` — resolved: **fable** (Fable 5.1, the agent's own `model:`; the dispatching session attributes its commits to Opus 5.5 and passed no model override that this dispatch could see). Verdict on the plan: n/a - no row departed from `models.conf`.
## Out of scope

- Setting `SELFTEST_JOBS` in CI (`gates.yml`), where it has been left unset
  since HARNESS-036 and a 2-vCPU runner has not been measured. Worth a
  separate measurement; not this story.
- Changing `scripts/selftest.sh`: its default stays 1, its header stays true.
- Detecting other test runs on the host - HARNESS-074.
- Dropping or moving any CI step - HARNESS-073.
- `CLAUDE.md`'s "Running things" listing of `bash scripts/selftest.sh`: it
  documents the command, not the procedure.

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


- Planned 2026-10-23 as one of three from a single request ("SELFTEST_JOBS=4
  in the self-test step, drop the duplicate guard CI steps, warn when other
  test runs share the host"). Split because each is its own behaviour with
  its own test, and together they would touch ten files across three
  mechanisms. Their footprints are disjoint except `floors.conf` and
  `selftest.test.sh` (each adds or raises a floor, recorded twice), so
  `plan.sh conflicts` reports every pair as CONFLICT on those two files and
  `plan.sh waves` places them in three waves: 072, then 073, then 074. Run
  them one after another; 072 first, because it makes every later full
  self-test on this host cheaper.
