---
id: HARNESS-095
title: GATES to REVIEW runs the changed-suite self-test, and says when the full run is still warranted
slug: gates-to-review-runs-the-changed-suite-s
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-095-gates-to-review-runs-the-changed-suite-s
depends_on: [HARNESS-094]      # the command this step names exists only once 094 merges; DV-2 there measures whether it is cheaper
touches: [.claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/lead-po.md, .claude/tests/procedure.test.sh, .claude/tests/dispatch.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

HARNESS-094 gives the harness `bash scripts/selftest-needed.sh --suites`
(which suites a diff can break, mechanically, `all` when it cannot tell) and
`SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` (run exactly those,
with the full run's floors audit). This story is the **procedure**: step 2
of GATES → REVIEW in `.claude/commands/advance-story.md`, the matching
bullet in `complete-story.md`, and the "long runs" paragraph of
`.claude/agents/lead-po.md` name the `--changed` run as the local self-test
before a PR, keep the full run as an explicit option, and say when it is
still warranted. Read HARNESS-094's Context for the cost this answers
(11,419 s locally for HARNESS-088 against 4m35s on CI) and for the
branch-protection finding: the `gates` check is **not** required on `main`,
so "CI's full run on the PR is the full check" is a claim about the user
reading the check before merging, not about a gate that cannot be skipped.

The guards that pin this text, `procedure.test.sh` (HARNESS-068/072/075) and
`dispatch.test.sh` (HARNESS-085), carry the full-run command as their
needle and must follow: the new needle is the `--changed` command, and the
full-run spelling becomes a control the way the pre-072 spelling did.

**Depends on HARNESS-094** (frontmatter): the command the step names does
not exist until it merges, and DV-2 there measures whether it is cheaper on
a real diff; if it is not, this story is re-planned before RED.

**The gate that fails if this story breaks:** every gate in `project.conf`
is unconfigured; the artifact is judged by `bash scripts/selftest.sh
procedure` and `bash scripts/selftest.sh dispatch`, both of which CI runs.
`required_gates` stays empty.

## Acceptance criteria

All **mechanical**: whole-line and fixed-string needles over extracted
regions, in the style the two guards already use (see the Contract).

- **AC-1 (the step)** — Given `.claude/commands/advance-story.md`, when its
  `**GATES → REVIEW.**` numbered steps are read, then the self-test step is
  still step 2, still begins with `` `bash scripts/selftest-needed.sh` ``,
  and on `run` names `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
  as the command the `feature-developer` dispatch runs (through
  `bash scripts/attest.sh -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`)
  and `` `bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
  as the check, with every word the step carries today (`detached`,
  `Windows`, `## Notes`, `other test runs`, `skip`) and the step's order
  unchanged (review before it, phase set after it). The step says the
  header line `selftest: --changed — ...` is pasted into `## Notes` beside
  `exit:`, `last:` and `duration:`.
- **AC-2 (the full run stays, and when)** — Given that step, when read, then
  it names `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` (no `--changed`)
  as the explicit full run and lists exactly three conditions under which it
  is run instead: (a) the `--changed` header says `every suite` (then it
  already is one; nothing to decide); (b) the story changed a script that
  other scripts invoke and the orchestrator cannot name the suite that
  exercises the caller - HARNESS-094's declared limit; (c) CI's self-test
  failed on the PR in a suite the local `--changed` run had not selected,
  in which case the fix round runs the full self-test before pushing again
  and records which suite the selection missed in `## Notes`. The control:
  a step that names the full run with no condition, or with the three
  reworded away, is reported.
- **AC-3 (the bullet and the agent)** — Given `complete-story.md`'s
  `- **GATES → REVIEW` bullet and `lead-po.md`'s `## Orchestrating` section,
  when read, then each names `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
  as the long run that goes to a `feature-developer` on the GATES row and is
  checked with `` `bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``,
  and `complete-story.md`'s bullet keeps `diff-review` before it and
  `` `bash scripts/selftest-needed.sh` `` before it. Both `allowed-tools`
  lines carry `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)`
  beside the existing full-run pattern, which stays.
- **AC-4 (the guards follow, and discriminate)** — Given `procedure.test.sh`
  and `dispatch.test.sh`, when run over the real tree, then both are silent;
  when run over their compliant fixtures with the step's command regressed to
  the full-run spelling (`` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` as
  the dispatch command, `--changed` absent), then each prints exactly one
  line naming the file and that it does not name the `--changed` command.
  The needle is the whole code span including its closing backtick, so the
  full-run spelling - a prefix of the new one - is not matched by it.

## Contract

**Writes:** `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/agents/lead-po.md`, `.claude/tests/procedure.test.sh`, `.claude/tests/dispatch.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Oracle partition.** AC-1..AC-4 *mechanical*: extracted regions, fixed
needles, one fault line per violation, silent on the real tree. Settled and
read out: the names of the three conditions in AC-2 are this story's and
are pinned by needle (`every suite`, `cannot name the suite`, `had not
selected`); do not invent others.

**`procedure.test.sh`.** `STEP_SELFTEST` becomes
`` '`SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`' ``; a new
`STEP_FULL='`SELFTEST_JOBS=4 bash scripts/selftest.sh`'` is the explicit
option and AC-2's needle, required in the same step together with the three
condition needles `FULL_WHEN=('every suite' 'cannot name the suite' 'had not
selected')`. `TOOL_CHANGED='Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh
--changed:*)'` joins the tool patterns both commands must carry;
`TOOL_SELFTEST` stays. Fault lines, in the existing style:
`` <file>: its step 2 does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``,
`` <file>: its `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` step does not say `<word>` ``
(the existing word loop, retargeted), `` <file>: its step 2 does not name the full run `SELFTEST_JOBS=4 bash scripts/selftest.sh` as an option ``,
`` <file>: its full-run option does not say when: `<condition>` ``,
`` <file>: allowed-tools lacks `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)` ``.
Matching the step's command: the step text holds both spellings, so the
"does not name" check for `STEP_SELFTEST` must match the whole span with its
closing backtick (the full-run span ends in `selftest.sh\``, the new one in
`--changed\``), as `dispatch.test.sh`'s `ATTEST_CHECK` needles already do.
`compliant_fixture`, `GOOD_STEPS`, `GOOD_BULLET` and `GOOD_TOOLS` carry the
new text; every HARNESS-068/072/075 case keeps its verdict, with the
pre-094 full-run-only step as AC-4's regressed fixture. Floor rises; RED
records it in `floors.conf` and in `selftest.test.sh`'s table.

**`dispatch.test.sh`.** `STEP_SELFTEST`, `LONG_RUN` and the `ATTEST_CHECK`
needle move to the `--changed` spelling (`STEP_NEEDLES` entry
`` 'bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`' ``);
`S2_GOOD`, `BULLET_GOOD` and `LONG_GOOD` carry it; `S2_TODAY` (the
HARNESS-085 regressed shape) stays a control, and a new control is today's
HARNESS-085-compliant text with the full-run spelling, which must now be
reported as not naming the `--changed` command. The `lead-po.md` paragraph
needle is the `## Orchestrating` section's "long runs" sentence; its words
`feature-developer`, `GATES row`, `attest.sh check` stay. Floor rises; RED
records it.

**The step text (advance-story, step 2).** Still one numbered step
beginning `` `bash scripts/selftest-needed.sh` — `` with the HARNESS-075
`run`/`skip` sentences. On `run`: `SELFTEST_JOBS=4 bash scripts/selftest.sh
--changed` - the suites this story's diff can break, chosen by
`selftest-needed.sh --suites` (a suite that mentions a changed path, a
changed suite itself, the five tree-scanning suites for the paths they scan,
and every suite when a path cannot be placed or the library changed), with
the full run's floors audit first. Dispatch, detached-and-alone, attest,
check, the expectation (CI's whole job 2-4 minutes; the local full run
3,845-11,419 s on this host, HARNESS-086..088; the `--changed` number from
HARNESS-094's DV-2, read out), the orphan check, the host-load sentence,
`exit:`/`last:`/`duration:` and the header line into `## Notes`, the
failure routes - every sentence HARNESS-072/075 put there, retargeted. Then
one paragraph: the full `SELFTEST_JOBS=4 bash scripts/selftest.sh` is still
run, in place of the `--changed` run, in the three AC-2 cases, each in one
sentence, and the orphan/host-load advice applies to it unchanged. CI runs
every suite on the PR either way, and the sentence saying so now adds that
the `gates` check is not required on `main`, so the merge is where the user
reads it.

**`complete-story.md`'s bullet** gains `--changed` on its self-test
clause and one clause for the full run's three conditions, pointing at
advance-story for the words. **`lead-po.md`** `## Orchestrating`: the "two
long runs" sentence names `SELFTEST_JOBS=4 bash scripts/selftest.sh
--changed` and, in a parenthesis, the full run as the option advance-story
says when to take.

**Callers.** No script changes. `attest.sh`'s header comment (line 22)
cites the full-run command as an example of one attestable command; it is a
comment and stays. `CLAUDE.md`'s command list already carries the
`--changed` line from HARNESS-094; the `ci-local.sh` step list is derived
from the workflows and does not change.

**The measured numbers to read out (HARNESS-094, merged as #179).** Its DV-2 ran
`SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` against a synthetic base
on this host. It selected 21 of 34 suites, all of which passed, and took
6,444 s. The full run took 12,502 s just before it, on the same loaded host,
with `run-lock` failing (see HARNESS-091 AC-4). That is one observation, and
the step says so rather than quoting a ratio. The `--changed` header that
`selftest.sh` prints begins `selftest: --changed — ` and continues with either
`every suite: <reason>` or `<k> of <n> suite(s) selected: <names>`
(`scripts/selftest.sh:303` and `:364`). AC-2(a)'s needle `every suite` is
therefore what the header really says.

**RED may amend any block above in place, with a reason; GREEN builds what the amended block says.**

## Deferred verifications

**DV-1 (the probe against the real tree; the story's central claim).
Owner: GATES.** With the GATES edits in the working tree, mutate a real line
of `advance-story.md` - delete ` --changed` from the step's dispatch command
span - with
`bash scripts/mutate.sh .claude/commands/advance-story.md 's/selftest.sh --changed`/selftest.sh`/' -- bash scripts/selftest.sh procedure`
(adjust to the line GREEN wrote; name it) and paste the red line
`` .claude/commands/advance-story.md: its step 2 does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
and `mutate.sh`'s restore lines; then the same expression against
`.claude/agents/lead-po.md` under `bash scripts/selftest.sh dispatch`. Two
mutations, one per guard, each against the one suite that holds the
assertion. These are the only probes that show the guards see the real
files and not only their fixtures.

## Amendments

<!-- none yet -->

## Suppressions

<!-- none -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-095` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`: `fable` (Fable 5.1, `claude-fable-5-1`), the agent's own `model:`; no override was reported to the dispatch. 2026-11-04.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **The mechanism** - `selftest-needed.sh --suites`, `selftest.sh --changed`
  and their suites - is HARNESS-094's and is not reopened here. A gap found
  in the selection while writing the procedure is a note for a follow-up,
  not an edit to a script this story does not touch.
- **CI's workflows** and **branch protection**: unchanged. The step text
  states the finding (the `gates` check is not required) and nothing more.
- **`ci-local.sh`** keeps running the full self-test, as the workflow does.
- **Rewriting the sigpipe line pins**, and HARNESS-091's flake: as in
  HARNESS-094.
- **A fourth condition.** If GATES finds a case where the full run was
  warranted and none of the three names it, that is an `## Amendments`
  question, not a silent fourth sentence.

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

