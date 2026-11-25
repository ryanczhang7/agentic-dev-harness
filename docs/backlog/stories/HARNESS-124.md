---
id: HARNESS-124
title: check-boundaries reads a suppression diff with colour forced
slug: check-boundaries-reads-a-suppression-dif
epic: 
type: fix
status: in-progress
phase: RED
branch: story/HARNESS-124-check-boundaries-reads-a-suppression-dif
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .github/workflows/gates.yml, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

The audit `docs/wiki/audits/runtime-cut-2026-11-25.md`, under "A defect,
not a speed-up": the weekly step `Harness self-test, with colour forced`
in `.github/workflows/gates.yml` has failed on every scheduled run since
2026-11-02. It asked for this story before anything touches the weekly run
(finding ST-9). The audit left the cause as "not known". This story
establishes it, as far as the evidence below goes, and fixes it.

**What fails.** Runs 41462331904 (2026-11-02), 42639068050 (11-09),
43886158056 (11-16) and 45223333374 (11-23); the last green scheduled run
is 40319598841 (10-26). In each, the first self-test step passes every
suite and the colour-forced step fails one, `boundaries`, by the same 160
assertions: `342 passed, 160 failed`, then `385 passed, 160 failed`, then
`527 passed, 160 failed` twice. Every one of the 160 is a case of block 3j
of `scripts/check-boundaries.sh`, "GREEN and GATES add no suppression"
(HARNESS-081, with HARNESS-082's stub rows and handler window). Each
reads the same way: a refusal that was expected is not printed
(`expected: 1`, `actual: 0`), the run exits 0 where 1 was expected, and
the `GREEN/GATES added no suppression` line is printed beside a commit
that added one.

**When it started.** Not with a change that broke something that worked.
Block 3j arrived in PR #169 (HARNESS-081, merged 2026-10-29; the line is
from commit `33f25eb`), with HARNESS-082 on 10-30. The first scheduled run
after that, 11-02, is the first red one. The rule has never passed under
forced colour. The pull request path never forces colour, so every PR
since has been green.

**The cause, and the evidence for each link.**

1. Block 3j reads each file's diff with
   `git show --format= --unified=0 "$c" -- "$f"` into a file
   (`check-boundaries.sh:1112`) and hands it to the awk in
   `suppression_hits`, which finds its lines by `^diff --git `, `^@@ ` and
   `^\+`.
2. The step sets `GIT_CONFIG_KEY_0=color.ui`, `GIT_CONFIG_VALUE_0=always`.
   Under that, the same `git show`, run here on a real commit of this
   repository, begins every one of those lines with an escape sequence
   (`ESC[1mdiff --git`, `ESC[36m@@`, `ESC[32m+`), written to a file as to
   a terminal. No line then starts with `diff`, `@@` or `+`, so the awk
   sees no hunk and no added line, prints nothing, and the rule passes
   with nothing judged.
3. Block 3j's own two functions, `suppression_needles` and
   `suppression_hits`, copied out of `check-boundaries.sh` unchanged and
   run in a scratch repository whose second commit adds
   `// eslint-disable-next-line @typescript-eslint/no-explicit-any` as
   line 2 of `src/main.ts`, print:
   - with no colour configured: `2|eslint-disable|// eslint-disable-next-line @typescript-eslint/no-explicit-any`;
   - under `color.ui=always`, the `git show` exactly as line 1112 has
     it: nothing;
   - under `color.ui=always`, the same `git show` with `--no-color`:
     the hit again, byte for byte.
   That is the defect and the fix in three commands.
4. Reproduced on this machine, one suite, no self-test:
   `bash .claude/tests/boundaries.test.sh` under the step's five
   variables printed 160 `FAIL` lines, in the same eight blocks and with
   the same counts as the CI log of run 45223333374: 15, 79 and 14 under
   HARNESS-081's AC-1, AC-2 and AC-5, then 3, 18, 12, 18 and 1 under
   HARNESS-082's. Not one more appeared in the first HARNESS-083 block,
   which followed. The run was stopped there, about an hour in on a
   loaded host, before its summary line; on CI the line is
   `boundaries: 527 passed, 160 failed`. DV-2 runs the suite to its end,
   after the fix.

What this does not show: that no other script misreads coloured output in
a path no suite exercises. The weekly step is the instrument for that, and
in each of the four red runs the other 34 suites passed under it.

**Why it matters beyond a red weekly run.** The failure is silent in use.
A checkout whose git configuration forces colour gets a `check-boundaries`
that prints `GREEN/GATES added no suppression` over a commit that added
one. A guard that passes because it could not read its input is the case
`rules.md` calls a needle that cannot fail, on the instrument's side.

The required gate that fails if this breaks is `selftest`: AC-1 to AC-3
are cases in `.claude/tests/boundaries.test.sh` that force colour for
themselves, so the pull request path runs them, and the next defect of
this kind in 3j is red on the PR that introduces it and not a week later.

## Acceptance criteria

- **AC-1 (the bug, reproduced where every pull request runs it)** — Given
  the HARNESS-081 fixture, a spike whose GREEN commit adds
  `// eslint-disable-next-line @typescript-eslint/no-explicit-any` as line
  2 of `src/main.ts`, when `check-boundaries.sh` runs with
  `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always`
  in its environment, then it prints the refusal naming `eslint-disable`,
  `src/main.ts`, line 2, the commit and `GREEN`, as one whole line, the
  same line HARNESS-081 AC-1 pins without the variables; it prints no
  `GREEN/GATES added no suppression` line; and it exits 1.
  Today it prints no refusal, prints the `added no suppression` line and
  exits 0.
- **AC-2 (the shapes that depend on the diff's structure)** — Given the
  same environment, when `check-boundaries.sh` runs over each of these
  fixtures, then its 3j lines and exit status are the ones the existing
  uncoloured case pins: (a) the third of three lines added in one hunk is
  refused by its own line number, 4; (b) a two-line empty handler,
  `} catch (e) {` then `}`, is refused once, at the opener's line; (c) a
  `raise NotImplementedError` whose two previous added lines are
  `@abstractmethod` and a `def` is not refused.
- **AC-3 (colour does not turn the rule into one that refuses
  everything)** — Given the same environment and the AC-1 fixture with a
  `## Suppressions` line that carries the path, `[eslint-disable]` and
  `approved by`, when `check-boundaries.sh` runs, then it prints no
  refusal and exits 0; and given a commit that adds no directive, it
  prints the `GREEN/GATES added no suppression` line and exits
  0.
- **AC-4 (the weekly step's own environment)** — Given
  `FORCE_COLOR=1 CLICOLOR_FORCE=1 GIT_CONFIG_COUNT=1
  GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always`, the environment
  the step `Harness self-test, with colour forced` sets, when
  `bash .claude/tests/boundaries.test.sh` runs, then its last line is
  `boundaries: <n> passed, 0 failed` with `<n>` no less than the suite's
  floor. Today it is `<n> passed, 160 failed`.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.github/workflows/gates.yml`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

**C-1. The one line.** `scripts/check-boundaries.sh`, block 3j, the read of
one file's diff (line 1112 at main `d495ae7`):

    git show --format= --unified=0 "$c" -- "$f" > "$dp"

gains `--no-color`. Nothing else in the block changes: not the needle
table, not `suppression_hits`, not `suppression_declared`. The comment
above `suppression_hits` that describes its input ("one file's
`git show --unified=0` diff") gains one sentence: the diff is asked for
without colour, because every anchor in the awk (`^diff --git `, `^@@ `,
`^\+`) is a start-of-line match and a colour escape sits before the first
character of each of those lines.

**C-2. Why this line and no other.** What the evidence shows, and where it
stops:

- `git show --format= --unified=0 <commit> -- <file>` under
  `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always`
  begins every header, hunk and added line with an escape sequence, to a
  file as to a terminal; with `--no-color` added, under the same
  variables, it does not. Run here on a real commit of this repository.
- It is the only call in `scripts/` and `.claude/hooks/` that asks git
  for a patch and parses it (`grep -rnE 'git .*(show|diff|log).*(--unified|-U[0-9]| -p\b)'`
  finds this line alone). The other `git show` calls in
  `check-boundaries.sh` read a blob (`<rev>:<path>`), and the `git diff`
  and `git diff-tree` calls ask for `--name-only`; the suite's other
  cases, which exercise them, pass under the weekly environment.
- Each of the four failing scheduled runs fails 160 assertions, while the
  suite's passing count grew from 342 to 527 as later stories added
  cases. In the latest run, read case by case, all 160 sit under the
  HARNESS-081 and HARNESS-082 headings of block 3j, and the
  `project.conf` branch of 3j (HARNESS-083), which reads blobs and no
  diff, has none.
- See `## Context` for the three-command reproduction with the block's
  own functions, and for the suite run under the step's environment.

RED confirms rather than assumes: its handoff states that each new case
fails today with zero refusals (the awk saw no added line), not with a
differently worded refusal. If any new case fails for another reason,
RED stops and reports it, because the cause above would then be
incomplete.

**C-3. The new cases, and how they force colour.** They go in
`.claude/tests/boundaries.test.sh`, beside the HARNESS-081 and
HARNESS-082 cases they mirror, and reuse those fixtures' helpers
(`_src_story`, `_src_branch`, the spike-at-REVIEW premise that makes the
exit status mean something). Each sets the three `GIT_CONFIG_*` variables
for the one `check-boundaries.sh` invocation it judges, and for nothing
else: not exported for the fixture's own `git commit` calls, and not left
set for the next case. Expected text is literal, never "the same as an
uncoloured run of this case": under the weekly step the whole suite
already runs coloured, so a second run in the same process is no
baseline. The cases must therefore pass identically on the pull request
path (variables set only by the case) and under the weekly step
(variables set by the step, and again by the case).

**C-4. The floor.** `boundaries` is floored at 687 in
`.claude/tests/floors.conf`, with the hand copy in
`.claude/tests/selftest.test.sh`. The new assertions raise the executed
count; raise both copies to the measured count in the same commit. No
floor is lowered.

**C-5. The comment in `gates.yml`.** The block above the colour-forced
step says of this repository "where nothing has ever regressed and the
tool surface is one program" and "It re-runs all 17 suites". Both are now
false. Correct them to what is true: the suite count is not stated as a
number (it goes stale; say "every suite"), and the step caught a guard
that read coloured `git show` output and refused nothing, from its first
scheduled run after that guard merged, red for four weeks before anyone
read it. No trigger, `if:`, `run:` line or step changes.

**Oracle partition.**

| AC | Kind | Instruction to RED |
|---|---|---|
| AC-1, AC-2, AC-3 | mechanical | Whole lines, anchored, copied from the existing HARNESS-081 and HARNESS-082 cases they mirror. Do not invent a new fixture where one exists. AC-3 is the control that colour does not flip the rule to refusing everything. |
| AC-4 | mechanical, run at GATES | Not a case inside the suite: it is the suite, run once under the step's environment (DV-2), and the step itself on a runner (DV-3). |
| The 160 and the run ids | settled | Read out of `## Context`. |

No existing export changes its signature. No test-only dependency.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". DV-1 is the defect put
back for the central claim. DV-2 and DV-3 are not mutations: they are the
reproduction this fix exists for, once on this machine and once on the
runner where it has failed four times. None runs the full self-test
locally.

**DV-1. The defect put back.** With `--no-color` removed from the
`git show` of C-1 in `scripts/check-boundaries.sh` (one
`scripts/mutate.sh` expression), AC-1's refusal assertion **must** fail,
reading 0 refusals where it expects 1, and the uncoloured HARNESS-081
AC-1 case beside it must still pass. Run against
`bash .claude/tests/boundaries.test.sh` only. RED cannot run it as a
mutation: in RED the flag is not there, and the new cases fail for that
reason, which RED records as the watched failure. **Owner: GATES.**

**DV-2. The whole suite under the step's environment.** AC-4 as one
command, on the story branch after GREEN:
`FORCE_COLOR=1 CLICOLOR_FORCE=1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always bash .claude/tests/boundaries.test.sh`.
Its last line **must** read `0 failed`, with a passed count no less than
the suite's floor after this story. Paste the last line and the count of
`FAIL` lines. One suite, not the self-test. RED cannot run it to a pass:
the fix does not exist. **Owner: GATES.**

**DV-3. The step itself, on a runner.** Push the story branch and start
the workflow on it by hand (`gh workflow run gates.yml --ref <branch>`;
only a manual or scheduled run executes the colour-forced step). The step
`Harness self-test, with colour forced` **must** end
`<n> harness suite(s) passed.`, with the `boundaries` line showing
`0 failed`. Paste those two lines and the run id. This is the run that
has been red since 2026-11-02, and it is the only place the other 34
suites are re-checked under colour after the change. RED and GREEN cannot
run it: it needs the fix on a pushed branch. **Owner: GATES.**

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Head each entry AM-<n> (`- **AM-1 (AC-2).** ...`), and give it its
     adjudication record, a line of its own in this section, outside any
     comment or fence - check-boundaries.sh refuses a new entry without one:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A claim that a criterion is wrong is also what an agent says when it
     wants to stop failing, so it is judged by a fresh `fable` dispatch - a
     `lead-po` on the ADJUDICATE row of models.conf, on different inputs, not
     the claimant's code - and that dispatch writes the judgement and the
     record line; the judgement is never the orchestrator's. An entry that
     follows a diff-review or PR-feedback finding routed RED or AMEND was
     judged by that review, so the orchestrator writes its record, naming the
     round and finding (or the PR-feedback item) and the model the review was
     planned on and resolved to:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Its being upheld does not replace the user's approval; both go in the
     entry. A change
     the user asked for unprompted is not a claim: `- **Adjudicated AM-<n>:**
     requested by the user, <date>`. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-124` from `.claude/harness/models.conf`.
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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |
| ADJUDICATE | `lead-po` | `fable` | a claim that an acceptance criterion, a threshold or a frozen test is wrong is judged against the contract by a fresh dispatch on different inputs, never by the orchestrator that wants the answer; needed in any phase, so it is last |

**Resolved:**

- PLANNED, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-25; no override reported. Planned by `/plan-story` in a batch of four (HARNESS-124 to 127). The oracle partition is in `## Contract`: AC-1 to AC-3 mechanical, AC-4 run at GATES (DV-2, DV-3).
- RED, `test-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-25; no override. Orchestrator checked both attest records `fresh` itself (`boundaries: 694 passed, 9 failed`, exit 1, all 9 FAILs HARNESS-124 cases; `--fast` exit 0, vacuous) and ran neither command again.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- Any speed-up of the weekly run, the pull request run or the suite
  (audit ST-1, ST-9; HARNESS-125 and later stories).
- Moving the colour-forced step onto the pull request path, or changing
  its `if:`, its `run:` line, or the `on:` triggers.
- A tree-wide guard that every `git` call whose output a script parses
  disables colour. Today exactly one call in `scripts/` and
  `.claude/hooks/` asks for a patch and parses it, and this story fixes
  it; a rule over the tree is its own story, with its own probe.
- Other configuration that can reshape a diff (`diff.external`, textconv,
  `diff.noprefix`). None is forced by the weekly step and none has a
  failing case; `suppression_hits` already ignores the prefix.
- The suppression rule itself: the needle table, the handler window, the
  `## Suppressions` grammar, the `project.conf` branch.
- Why four red scheduled runs went unseen for four weeks. Nothing in the
  harness reads the result of a scheduled run; whether `doctor.sh` or
  `/status` should is a question for a separate story.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

Level: integration, one level only - each case builds a real two-branch fixture
repository with HARNESS-081's helpers (`source_story`, `_src_branch`,
`_src_story`, `want_3j`, `want_3j_ok`, `sup_nfail`, `sup_fails`, `sup_count`,
`whole_line`) and runs the real `scripts/check-boundaries.sh` over it. The
defect lives in how that script reads git's output, so nothing cheaper can
falsify it. No new fixture: AC-1 and AC-3 reuse HARNESS-081's spike-at-REVIEW
premise and its AC-1 line, AC-2 (a) is HARNESS-081 A-1 (b), (b) is HARNESS-082
AC-3's first row, (c) is HARNESS-082's abstract-method control row.

Colour is forced by one helper, `run_boundaries_coloured`
(`.claude/tests/boundaries.test.sh:3181`): `run_boundaries` with
`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always` as a
prefix assignment on the one `check-boundaries.sh` invocation, so the fixture's
own `git commit` calls never see them and no later case inherits them (C-3).
Every expected value is literal (HARNESS-081's `want_3j` strings).

All 16 new assertions sit in four describes at
`.claude/tests/boundaries.test.sh:3161-3293`, after HARNESS-082's baseline
removal and before HARNESS-083's fixture. None is in a loop or conditional.

| Line | Asserts | AC |
|---|---|---|
| 3199 | premise: under the three variables, the AC-1 commit's `git show --format= --unified=0` of `src/main.ts` has 0 lines matching `^+` | C-2 (the cases exercise the coloured path) |
| 3202 | premise: same, with `--no-color`, has exactly 1 whole line `+// eslint-disable-next-line @typescript-eslint/no-explicit-any` | C-2 (the fix's own mechanism) |
| 3212 | coloured: the whole refusal line, `want_3j <c> GREEN src/main.ts 2 eslint-disable <AC-1 line>` | AC-1 |
| 3214 | coloured: exactly 1 `added a suppression to` line | AC-1 (DV-1's assertion) |
| 3215 | coloured: exit status 1 | AC-1 |
| 3216 | coloured: 0 `GREEN/GATES added no suppression` lines | AC-1 |
| 3227 | coloured: the whole refusal of `// @ts-ignore` at line 4, the third of three added lines | AC-2 (a) |
| 3229 | coloured: rc\|refusals\|summary = `1\|1\|0` | AC-2 (a) |
| 3243 | coloured: the whole `empty-handler` refusal at the opener's line 2, quoting `} catch (e) {` | AC-2 (b) |
| 3245 | coloured: rc\|refusals\|summary = `1\|1\|0` (refused once) | AC-2 (b) |
| 3263 | coloured: no line naming `'src/shapes.py' line` for an abstract method, all three lines added | AC-2 (c) |
| 3265 | coloured: rc\|FAIL lines\|summary(1) = `0\|\|1` | AC-2 (c) |
| 3279 | coloured, declared in `## Suppressions`: rc\|refusals = `0\|` | AC-3 |
| 3280 | coloured, declared: the whole line `ok    suppression [eslint-disable] in 'src/main.ts' is declared in ## Suppressions` | AC-3 (makes "no refusal" mean the hit was found and discharged) |
| 3288 | coloured, a clean GREEN commit: rc\|FAIL lines = `0\|` | AC-3 |
| 3289 | coloured, clean: the whole summary line `ok    GREEN/GATES added no suppression (1 commit(s) judged)` | AC-3 |

AC-4 is deliberately not a case (oracle partition): it is DV-2 and DV-3 at GATES.

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

Written by the test-developer, RED, 2026-11-25.

**Command.** From the worktree:

    bash scripts/attest.sh -- bash .claude/tests/boundaries.test.sh

Recorded run (Windows host, local, 2126 s), tree `53b9f9825e0083a13fe916dbd3debe240e4b524c`:

    last:     boundaries: 694 passed, 9 failed
    log:      .claude/state/attest-logs/20261125T140405Z.707204.log

Fast gates (`bash scripts/attest.sh -- bash scripts/gates.sh --fast`): every
gate UNCONFIGURED in this repository (BOOTSTRAPPED=no), so nothing judges the
tests but the suite itself; no gate failed on a timeout, config or lint rule.

    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261125T140424Z.708001.log

**The failure, verbatim from the log** (all 9 `FAIL` lines in the run; none
outside the HARNESS-124 describes):

```
    FAIL HARNESS-124 AC-1: under forced colour the refusal names eslint-disable, src/main.ts, line 2, the commit and GREEN, by its whole line
         expected: 1
         actual:   0
    FAIL HARNESS-124 AC-1: under forced colour it is the only refusal this rule prints (refusals)
         expected: 1
         actual:   0
    FAIL HARNESS-124 AC-1: under forced colour the run exits 1, where the same branch without the line exits 0
         expected: 1
         actual:   0
    FAIL HARNESS-124 AC-1: under forced colour no summary line claims the commit was clean beside the refusal
         expected: 0
         actual:   1
    FAIL HARNESS-124 AC-2 (a): under forced colour the third of three lines added in one hunk is refused by ITS line number, 4
         expected: 1
         actual:   0
    FAIL HARNESS-124 AC-2 (a): under forced colour - rc|refusals|summary (refused once, exit 1, nothing calls it clean)
         expected: 1|1|0
         actual:   0|0|1
    FAIL HARNESS-124 AC-2 (b): under forced colour '} catch (e) {' then '}' is refused as empty-handler at the opener's line, 2, by its whole line
         expected: 1
         actual:   0
    FAIL HARNESS-124 AC-2 (b): under forced colour - rc|refusals|summary (refused once, exit 1, nothing calls it clean)
         expected: 1|1|0
         actual:   0|0|1
    FAIL HARNESS-124 AC-3: under forced colour the rule says the path is declared
         expected: 1
         actual:   0

boundaries: 694 passed, 9 failed
```

**C-2 confirmed: every new case that fails, fails with ZERO refusals.** AC-1,
AC-2 (a) and (b) each read `0` refusal lines (`sup_nfail`), exit 0, and print
the `GREEN/GATES added no suppression` summary - the rule judged the commit and
saw no added line. No case fails with a differently worded refusal, and no FAIL
from any other block appears on these branches (exit 0 with a spike premise
means no `problem` was raised anywhere). AC-3's declared case reads 0 `is
declared` lines for the same reason: no hit was found to discharge. The cause
in `## Context` is therefore not shown incomplete by anything RED saw.

**Fix preview, run through `mutate.sh` on a scratch subset** (the suite's
prelude, HARNESS-081's fixture describe, and the four HARNESS-124 describes;
17 assertions; restore verified). With `--no-color` added to line 1112 all 17
pass, uncoloured and again under the weekly step's five variables (C-3's
"identically on both paths"):

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/git show --format= --unified=0 "\$c"/git show --no-color --format= --unified=0 "$c"/) ===
boundaries-h124-subset: 17 passed, 0 failed
=== mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-124/.claude/state/mutations/scripts_check-boundaries.sh.20261125T135643Z.697165.bak) ===
# and with FORCE_COLOR=1 CLICOLOR_FORCE=1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always exported:
boundaries-h124-subset: 17 passed, 0 failed
=== mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-124/.claude/state/mutations/scripts_check-boundaries.sh.20261125T140302Z.705571.bak) ===
```

**Passed on arrival, and what earns each.** Seven of the 16:

- 3199, 3202 (premise) - claims about git, not 3j; each half is the other's
  control (the same diff reads 0 `^+` lines without `--no-color` and 1 with it,
  under the same variables). The first goes red if git ever stops colouring a
  patch written to a file, which would make every case below vacuous.
- 3279 (AC-3 declared, rc|refusals) - vacuous today by construction; its
  partner 3280 is red today and is what makes it mean something.
- 3263, 3265 (AC-2 (c)) and 3288, 3289 (AC-3 clean) - controls against the
  FIX, vacuous today because 3j under colour judges nothing. Earned by two
  compound mutations through `mutate.sh` on the scratch subset, each adding
  `--no-color` (the fix) and breaking the one behaviour the control pins:

```
=== mutate: scripts/check-boundaries.sh (2 line(s) changed by s/git show --format= --unified=0 "\$c"/git show --no-color --format= --unified=0 "$c"/;s/id\[k\] == "stub-raise" \&\& p1/id[k] == "stub-raiseX" \&\& p1/) ===
    FAIL HARNESS-124 AC-2 (c): under forced colour an abstract method, all three lines added (src/shapes.py), is not refused
         expected: 
         actual:   FAIL  story T-1: commit f0a01aa (GREEN) added a suppression to 'src/shapes.py' line 4 [stub-raise]: raise NotImplementedError. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.
    FAIL HARNESS-124 AC-2 (c): under forced colour - rc|FAIL lines|summary(1)
         expected: 0||1
         actual:   1|FAIL  story T-1: commit f0a01aa (GREEN) added a suppression to 'src/shapes.py' line 4 [stub-raise]: raise NotImplementedError. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.|0
boundaries-h124-subset: 15 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-124/.claude/state/mutations/scripts_check-boundaries.sh.20261125T135731Z.699105.bak) ===

=== mutate: scripts/check-boundaries.sh (2 line(s) changed by s/git show --format= --unified=0 "\$c"/git show --no-color --format= --unified=0 "$c"/;s/(id\[k\] in seen) || s !~ re\[k\]/(id[k] in seen)/) ===
    FAIL fixture: a spike branch whose GREEN commit adds a clean line exits 0, and nothing objects
    FAIL HARNESS-124 AC-1: under forced colour it is the only refusal this rule prints (refusals)
    FAIL HARNESS-124 AC-2 (a): under forced colour - rc|refusals|summary (refused once, exit 1, nothing calls it clean)
    FAIL HARNESS-124 AC-2 (b): under forced colour - rc|refusals|summary (refused once, exit 1, nothing calls it clean)
    FAIL HARNESS-124 AC-2 (c): under forced colour an abstract method, all three lines added (src/shapes.py), is not refused
    FAIL HARNESS-124 AC-2 (c): under forced colour - rc|FAIL lines|summary(1)
    FAIL HARNESS-124 AC-3: under forced colour a declared suppression - rc|refusals
    FAIL HARNESS-124 AC-3: under forced colour a commit adding no directive - rc|FAIL lines
    FAIL HARNESS-124 AC-3: under forced colour the summary says the one GREEN commit added no suppression
boundaries-h124-subset: 8 passed, 9 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-124/.claude/state/mutations/scripts_check-boundaries.sh.20261125T135826Z.701171.bak) ===
```

  The first breaks the abstract-method window: exactly (c)'s two go red. The
  second makes every added line hit every rule ("colour turns the rule into one
  that refuses everything"): both AC-3 controls go red. `mutate.sh --check`
  is clean after all four runs.

**Negative controls - expected values.** These are mechanical, no thresholds:

| Control | Expected after GREEN | Today (measured, full suite) | Under the fix (measured, subset) |
|---|---|---|---|
| 3199 `^+` lines, coloured, no `--no-color` | 0 | 0 | 0 |
| 3202 `+<AC-1 line>` whole lines, coloured, `--no-color` | 1 | 1 | 1 |
| 3263 lines naming `'src/shapes.py' line` | empty | empty | empty (2 refusal lines with the window broken) |
| 3265 rc\|FAIL\|summary(1) | `0\|\|1` | `0\|\|1` | `0\|\|1` |
| 3288 rc\|FAIL lines, clean commit | `0\|` | `0\|` | `0\|` (`1\|FAIL ...` with every line a hit) |
| 3289 summary `(1 commit(s) judged)` | 1 | 1 | 1 |

GREEN confirms these against the shipped change in the full suite.

**DV-1 expectation (GATES owns it).** With `--no-color` removed again from the
`git show` of C-1, through one `mutate.sh` expression against
`bash .claude/tests/boundaries.test.sh`: 3214 reads `actual: 0` where
`expected: 1` (with 3212, 3215, 3216 and the other five above red beside it,
exactly the 9 of this RED run), while HARNESS-081's uncoloured
`AC-1 (GREEN): it is the only refusal this rule prints` and its whole-line
refusal still pass. This RED run already shows both halves on the unfixed
script: those 9 red, and every HARNESS-081 AC-1 assertion green (694 passed).
RED cannot run DV-1 as a mutation: the flag does not exist yet.

**What GREEN must change (C-1, C-5; RED touched neither).**

1. `scripts/check-boundaries.sh` line 1112:
   `git show --format= --unified=0 "$c" -- "$f" > "$dp"` becomes
   `git show --no-color --format= --unified=0 "$c" -- "$f" > "$dp"`. The
   subset preview above used exactly that spelling, `--no-color` first.
   Nothing else in block 3j changes.
2. The comment above `suppression_hits` (around line 767, "file's
   `git show --unified=0` diff") gains C-1's one sentence: the diff is asked
   for without colour, because every anchor in the awk (`^diff --git `, `^@@ `,
   `^\+`) is a start-of-line match and a colour escape sits before the first
   character of each.
3. `.github/workflows/gates.yml`, the comment above the colour-forced step, per
   C-5. No trigger, `if:`, `run:` or step changes.
4. `.claude/harness/VERSION` bump (in `touches:`), as every harness change.

**Export shape.** No module is imported; the tests drive
`bash scripts/check-boundaries.sh main` as a process and read its stdout and
exit status. No existing export or function changes signature, so no callers
list is needed. Not constrained: where the flag sits among `git show`'s options,
and the exact wording of C-1's comment sentence.

**Floors (C-4).** `boundaries` 687 -> 703 in `.claude/tests/floors.conf:40`
and the hand copy `.claude/tests/selftest.test.sh:531`, with a history entry
at the end of `floors.conf`. 703 is the EXECUTED count of the recorded run
(694 passed + 9 failed = 687 before + 16 new), following earlier REDs
(HARNESS-089, HARNESS-097): until GREEN lands, boundaries sits 9 below its
floor, expected in RED.

**Files touched.**

- `.claude/tests/boundaries.test.sh` - +133 lines at 3161-3293 (four describes,
  one helper, 16 assertions); nothing else in the file changed.
- `.claude/tests/floors.conf` - line 40 (687 -> 703); +14 lines appended at the
  end (1433-1446).
- `.claude/tests/selftest.test.sh` - line 531 (687 -> 703).
- `docs/backlog/stories/HARNESS-124.md` - `## Test plan`, this section.

**Timings.** All local, Windows host under load: full suite 2126 s; the subset
36 s. No test timeout exists in this bash suite; nothing is budgeted. Each
coloured case is one `check-boundaries.sh` run, the same cost as its
uncoloured twin.

**Discovered.** Nothing that changes the approach. What RED did not measure:
the other 160 HARNESS-081/082 assertions under the weekly variables with the
fix in place. The subset preview covers only HARNESS-081's fixture premise and
the new cases; whether DV-2's whole suite reads `0 failed` is DV-2's to show.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return, headed
     R-<n> (`### R-1 (the count test)`), and carrying its adjudication
     record - a line of its own, outside any comment or fence, written by
     the fresh `fable` dispatch (a `lead-po` on the ADJUDICATE row of
     models.conf) that judged the claim the test is wrong; the judgement is
     never the orchestrator's. check-boundaries.sh refuses a new entry
     without one:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A return that follows a diff-review or PR-feedback finding routed RED
     or AMEND was judged by that review, so the orchestrator writes the
     record, naming the round and finding (or the PR-feedback item) and the
     model the review was planned on and resolved to:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Then:
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

