---
id: HARNESS-095
title: GATES to REVIEW runs the changed-suite self-test, and says when the full run is still warranted
slug: gates-to-review-runs-the-changed-suite-s
epic: 
type: feature
status: in-progress
phase: GREEN
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
  and records which suite the selection missed in `## Notes`; that failure
  is seen at REVIEW, so (c) says how to get back to this step:
  `` `bash scripts/phase.sh set $1 GATES` `` (AM-1). The control:
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

**Amended in RED (2026-11-05, test-developer).** Each item adds to or sharpens
a block above; none changes an acceptance criterion. GREEN builds this.

- *procedure: where the conditions are read.* The three `FULL_WHEN` needles
  are read from step 2's text **from the first `` `SELFTEST_JOBS=4 bash
  scripts/selftest.sh` `` span on**, with every run of whitespace (newlines
  included) squashed to one space. Reason: the `--changed` description that
  comes before the full-run sentence says `every suite` too ("every suite when
  a path cannot be placed"), and today's step already says "every suite"; read
  over the whole step, condition (a)'s needle could not fail. So GREEN puts the
  full-run sentence **after** the `--changed` description, and the three
  conditions after the full-run span. A condition may wrap across a
  continuation line; the other words may not.
- *procedure: the header line is a word.* `STEP_WORDS` gains
  `selftest: --changed —` (em dash, as `selftest.sh` prints it). Reason: AC-1
  requires the step to say the header line is pasted into `## Notes`, and no
  needle in the block above pinned it. Fault line:
  `` <file>: its `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` step does not say `selftest: --changed —` ``.
- *procedure: the full-run tool pattern stays, checked.* `TOOL_FULL='Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh:*)'`
  joins `TOOL_CHANGED`, with the same "allowed-tools lacks" fault line. Reason:
  AC-3 says the existing full-run pattern stays, and nothing pinned it.
- *procedure: no blank line inside step 2.* Not a change, a consequence GREEN
  must know: `gates_steps` ends a step at a blank line, so the full-run
  "paragraph" is continuation lines of step 2, not a separate paragraph.
- *dispatch: the needles.* `SELFTEST_NEEDLES` gains the run span
  `` bash scripts/attest.sh -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` (AC-1 names it) beside the
  `--changed` check. `BULLET_NEEDLES` gains `GATES row` and
  `` bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` (AC-3 says the bullet names
  the long run on the GATES row and its check). lead-po's long-run paragraph
  must hold, in ONE paragraph of `## Orchestrating`, all of
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` (both backticks),
  `feature-developer`, `GATES row` and the `--changed` check span (AC-3).
- *dispatch: the fault lines.* A self-test step that names
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` and no `--changed` span gets
  `` .claude/commands/advance-story.md: the self-test step does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``;
  a lead-po paragraph naming the full run, dispatched to a feature-developer,
  with no `--changed` in it gets
  `` .claude/agents/lead-po.md: its long-run paragraph does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``.
  Every other failure keeps HARNESS-085's lines.
- *dispatch: `S2_TODAY`'s spelling.* Moved to the `--changed` span, so it stays
  the "does not dispatch" control; the full-run spelling is the new `S2_FULL`
  control. `lead-no-check` now expects two lines (`L_LONG` then `L_CHECK`):
  removing every `attest.sh check` from the section necessarily removes the
  `--changed` check the long-run paragraph now needs.

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

**DV-1 result (2026-11-05, GATES, orchestrator).** Both guards go red on
the real files, and every file was restored and verified. `mutate.sh --check`
is clean.

1. `advance-story.md:277`, the step's dispatch-command span:

       bash scripts/mutate.sh .claude/commands/advance-story.md '277s/selftest.sh --changed`/selftest.sh`/' -- bash scripts/selftest.sh procedure
       actual:   .claude/commands/advance-story.md: its step 2 does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
       procedure: 148 passed, 1 failed
       === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261105T221741Z.2147.bak) ===

   This is the exact line DV-1 names.
2. `lead-po.md:130`, the same expression:

       bash scripts/mutate.sh .claude/agents/lead-po.md '130s/selftest.sh --changed`/selftest.sh`/' -- bash scripts/selftest.sh dispatch
       actual:   .claude/agents/lead-po.md: does not dispatch long runs
       dispatch: 82 passed, 1 failed
       === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_agents_lead-po.md.20261105T221752Z.3382.bak) ===

   Red, but on the general `L_LONG` line rather than `L_LONG_CHANGED`.
   - Reason: `dispatch.test.sh:356-367` picks `L_LONG_CHANGED` only for a
     paragraph that holds the full run and no `--changed` anywhere. Line 137's
     check span still says `--changed`.
   - The `lead-regressed` fixture removes every `--changed`, so it is not the
     same mutation as the single-line one on the real file. The handoff's
     claim that it "is DV-1's lead-po mutation" holds only for the
     every-occurrence form, run here as a third probe.
3. `lead-po.md`, every `--changed` (2 lines):

       bash scripts/mutate.sh .claude/agents/lead-po.md 's/selftest.sh --changed/selftest.sh/g' -- bash scripts/selftest.sh dispatch
       actual:   .claude/agents/lead-po.md: its long-run paragraph does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
       dispatch: 82 passed, 1 failed
       === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_agents_lead-po.md.20261105T221822Z.4829.bak) ===
       mutate: no stranded mutation; nothing of a previous run is in the tree.

Finding, for diff review. A paragraph that dispatches the full run but still
mentions `--changed` in its check gets the less specific "does not dispatch
long runs" message. The guard is still red, so it discriminates; only the
message is imprecise. AC-4 is about the fixture with `--changed` absent
throughout, and it holds.

## Amendments

- **AM-1 (AC-2, case (c) says how to get back to the step).**
  - **What it said:** "(c) ... the fix round runs the full self-test before
    pushing again and records which suite the selection missed in
    `## Notes`. The control: ..."
  - **What it says now:** the same, plus "; that failure is seen at REVIEW,
    so (c) says how to get back to this step:
    `` `bash scripts/phase.sh set $1 GATES` ``".
  - **Why:** finding 2 of the first diff review (`## Diff review`). CI's
    failure is seen at REVIEW, and no step led back to step 2, so case (c)
    would have been skipped in exactly the situation it exists for. This was
    confirmed by reading advance-story's REVIEW → DONE paragraph.
  - **Approved by** the user, "Fix both", 2026-11-05.

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
- RED, `test-developer`: `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own `model:`; no override was reported. 2026-11-05.
- GREEN, `feature-developer`: `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own `model:`; no override was reported. 2026-11-05.
- GATES, `feature-developer` (full gates): `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own `model:`; no override. 2026-11-05.
- GATES, `feature-developer` (diff review): `opus` (Opus 5.5, `claude-opus-5-5`), no override. 2026-11-05.

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

Level: structural guards over prose (`tdd-cycle`, "code no machine you have
can execute: grep for the shape"). Two suites, each a guard function run over
the real tree (must be silent) and over fixtures compliant by construction
with one thing regressed (must print exactly the pinned lines). The guards
live in the test files; the "production" they judge is the three prose files.

| AC | Suite | Cases (fresh_case names) |
|---|---|---|
| AC-1 run named | procedure | real tree; `changed-regressed-step`, `changed-unclosed`, `changed-only-in-attest`, `changed-in-prose`, `changed-in-later-step`; HARNESS-072 `old-spelling-step`, `other-value-step`, `targeted-new-spelling` (now against the `--changed` span) |
| AC-1 run/check through attest | dispatch | real tree; `st-without-*` loop (now 6 needles incl. run + check spans), `st-full-094`, `st-bare-full`, `st-run-full`, `st-check-full`, `st-check-targeted`, `st-check-without-jobs` |
| AC-1 words + header + order | procedure | `word-*` loops, `words-in-next-step`, `word-skip`, `changed-no-header`, `changed-header-no-dash`; every HARNESS-032/068 order case (`selftest-after-phase`, `review-after-selftest`, ...) |
| AC-2 full run + three conditions | procedure | `full-missing`, `full-other-step`, `full-in-prose`, `full-targeted`, `full-no-condition` (control: three lines), `full-reworded` (control: three lines), `full-without-1..3`, `full-every-suite-before-only`, `full-condition-next-step`, `full-condition-wrapped`; R-1 `full-every-suite-only-in-closing` (control: the (a) line); AM-1 `full-no-route-back` (control: the route-back line), `full-route-back-before-only`, `full-route-back-expanded` |
| AC-3 bullet names `--changed` | procedure | `changed-regressed-bullet`, `changed-bullet-review-after`, `changed-bullet-needed-after`, `changed-bullet-full-before`; HARNESS-068/075 bullet cases |
| AC-3 bullet dispatch, GATES row, check | dispatch | `bullet-without-*` loop (4 needles), `bullet-094`, `bullet-check-full`, `bullet-today`, `bullet-next`, `bullet-none` |
| AC-3 lead-po long-run paragraph | dispatch | `lead-094`, `lead-regressed`, `lead-check-full`, `lead-no-gates-row`, `lead-full-undispatched`, `lead-no-selftest`, `lead-no-fd`, `lead-split-paragraphs`, `lead-no-check`, `lead-no-check-elsewhere` |
| AC-3 allowed-tools | procedure | `changed-tool-advance`, `changed-tool-complete`, `changed-tool-no-star`, `changed-tool-in-body`, `full-tool-advance`, `full-tool-complete`, `changed-tool-replaces-full` |
| AC-4 discrimination | both | `changed-regressed-step` and `changed-regressed-bullet` (procedure), `st-full-094` and `lead-regressed` (dispatch): exactly one line each; `changed-all-absent` (procedure) and `today-094` (dispatch): the HARNESS-094 text gives exactly the lines the real tree gives in RED; every HARNESS-032/068/072/075/085 case kept its verdict |

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

**Model.** RED ran on `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own
`model:`; the dispatch reported no override.

**Command.**

    bash scripts/attest.sh -- bash scripts/selftest.sh procedure dispatch
    bash scripts/attest.sh -- bash scripts/selftest.sh selftest

Each suite alone: `bash .claude/tests/procedure.test.sh`,
`bash .claude/tests/dispatch.test.sh` (about 25 s and 20 s on this host).
`gates.sh --fast` was not run: gates are unconfigured in this repository
(`BOOTSTRAPPED=no`), so it has nothing to judge.

**The red, from the attest record** (`exit: 1`,
`last: 2 of 2 harness suite(s) FAILED.`, log
`.claude/state/attest-logs/20261105T172228Z.24979.log`, duration 150 s):

```
    FAIL dispatch_problems over the real tree prints nothing: ...
         expected:
         actual:   .claude/commands/advance-story.md: the self-test step does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
         .claude/commands/complete-story.md: its GATES → REVIEW bullet does not name the dispatch
         .claude/agents/lead-po.md: its long-run paragraph does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
dispatch: 82 passed, 1 failed
FAIL dispatch  did 82 units of work, below the floor of 83 in .claude/tests/floors.conf
    FAIL procedure_problems over the real tree prints nothing: ...
         expected:
         actual:   .claude/commands/advance-story.md: allowed-tools lacks `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)`
         .claude/commands/advance-story.md: its step 2 does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
         .claude/commands/complete-story.md: allowed-tools lacks `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)`
         .claude/commands/complete-story.md: its GATES → REVIEW bullet does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`
procedure: 148 passed, 1 failed
FAIL procedure  did 148 units of work, below the floor of 149 in .claude/tests/floors.conf
assertion floors: 0 of 2 suite(s) met their declared floor.
2 of 2 harness suite(s) FAILED.
```

**Why it is the right red.** In each suite the ONLY failing assertion is the
real-tree one, and every line it prints is a Contract fault line naming a real
file and the `--changed` text it lacks. Every fixture case passes, including
`changed-all-absent` (procedure) and `today-094` (dispatch), which build the
HARNESS-094 text by hand and expect exactly these four and three lines - so
the real tree fails for the reason the fixtures say it should, not for an
unrelated one. The floor lines are the expected consequence of floors
counting passes: each suite sits one below its new floor until GREEN.

**Floors** (`floors.conf` with a comment, and `selftest.test.sh`'s table):
procedure 118 -> 149 (148 passed + 1 failed = 149 executed), dispatch
67 -> 83 (82 + 1 = 83). Measured locally, this run. Every assertion is
unconditional and every loop a fixed list. The selftest suite's own run:
`exit: 0`, `last: 1 harness suite(s) passed.`, duration 649 s (host
shared with another worktree's gates run), log
`.claude/state/attest-logs/20261105T172524Z.28055.log`;
`selftest: 309 passed, 0 failed`, floor met. Both records report `fresh`
under `attest.sh check` (tree `63c528081154ccfb8c57b00418df48e3b26b4299`).

**What GREEN writes.** Prose only, in three files (plus VERSION). Every needle
below is matched as a fixed string; the ones in code spans include BOTH
backticks unless marked.

`.claude/commands/advance-story.md`
- `allowed-tools:` keeps every entry it has (`Bash(bash scripts/selftest.sh:*)`,
  `Bash(bash scripts/ci-local.sh:*)`, `Bash(bash scripts/selftest-needed.sh:*)`,
  `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh:*)`, `Bash(bash scripts/attest.sh check:*)`)
  and adds the entry `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)`
  (comma-separated, compared after trimming, must be EQUAL).
- `**GATES → REVIEW.**` steps: review is step 1, the self-test step 2, phase
  set 3, `Commit` 4, check-boundaries 5 (unchanged). Step 2 is ONE numbered
  step: every line after `2. ` is an indented continuation line, and **no
  blank line** inside it (a blank line ends the step for both guards).
- Step 2 must contain, read from the step's own lines:
  `` `bash scripts/selftest-needed.sh` `` before the first
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``;
  the words `detached`, `Windows`, `## Notes`, `other test runs`, `skip`,
  `selftest: --changed —` (each on one line; the em dash is U+2014);
  `feature-developer`, `alone`, `verdict` (reflow allowed);
  `` bash scripts/attest.sh -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` and
  `` bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
  (each ending in its closing backtick; reflow across lines allowed for dispatch);
  then, AFTER the `--changed` description, the full run
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` and, after that span, the
  three conditions `every suite`, `cannot name the suite`, `had not selected`
  (these may wrap).
- Do not write the bare full-run span `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` ``
  anywhere in step 2 before the full-run sentence (for instance in the
  expectation numbers): the guard reads the conditions from its FIRST
  occurrence on, and an early one would let the `--changed` description's
  `every suite` satisfy condition (a). Say "the full run" in words there.

`.claude/commands/complete-story.md`
- `allowed-tools:` gains `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)`, keeps the rest.
- The `- **GATES → REVIEW` bullet (ends at the next `- ` line or a blank line)
  names `` `diff-review` `` and `` `bash scripts/selftest-needed.sh` ``, each
  before the first `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``;
  and, anywhere in it, `feature-developer`, `verdict` (lower case), `GATES row`,
  and `` bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``.
  The full-run clause pointing at advance-story is not pinned.

`.claude/agents/lead-po.md`, `## Orchestrating`
- ONE paragraph (a run of non-blank lines) holds all of
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``, `feature-developer`,
  `GATES row`, and `` bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``.
  The parenthesis naming the full run is not pinned. The section must still
  say `bash scripts/attest.sh check` (it will, via that span) and must not say
  `every rung is something you run, not`.

**Not constrained:** wording around the needles, the expectation numbers
(3,845-11,419 s, 6,444 s against 12,502 s), the orphan/host-load sentences,
the `gates` check not being required on `main`, and the bullet's full-run
clause. Those are the Contract's, not the guards'; DV-1 and the diff review
judge them.

**Every needle, and the region it is read from.**

| Suite | Needle | Region |
|---|---|---|
| procedure | `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` | advance-story GATES → REVIEW numbered steps (first step holding it = "the self-test step"); complete-story bullet |
| procedure | `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` | the self-test step |
| procedure | `every suite`, `cannot name the suite`, `had not selected` | the self-test step from its first full-run span on, whitespace squashed |
| procedure | `detached`, `Windows`, `## Notes`, `other test runs`, `skip`, `selftest: --changed —` | the self-test step, unsquashed |
| procedure | `` `bash scripts/selftest-needed.sh` `` | the self-test step (before the run); the bullet (before the run) |
| procedure | `` `bash scripts/phase.sh set $1 REVIEW` ``, `` `bash scripts/check-boundaries.sh` ``, `` the `diff-review` skill `` | steps, by number (unchanged) |
| procedure | `` `diff-review` `` | the bullet, before the run (unchanged) |
| procedure | `Bash(bash scripts/selftest.sh:*)`, `Bash(bash scripts/ci-local.sh:*)`, `Bash(bash scripts/selftest-needed.sh:*)`, `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh:*)`, `Bash(SELFTEST_JOBS=4 bash scripts/selftest.sh --changed:*)` | each command's frontmatter `allowed-tools:` entries, equal after trim |
| dispatch | `` `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` / `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` | advance-story steps (locates the self-test step / the HARNESS-094 step) |
| dispatch | `feature-developer`, `detached`, `alone`, `verdict`, `` bash scripts/attest.sh -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``, `` bash scripts/attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` `` | the self-test step, flattened |
| dispatch | `feature-developer`, `verdict`, `GATES row`, the `--changed` check span | complete-story bullet, flattened |
| dispatch | the `--changed` span, `feature-developer`, `GATES row`, the `--changed` check span | one paragraph of lead-po `## Orchestrating`, flattened |
| dispatch | `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` + `feature-developer` + no `--changed` | one paragraph of lead-po `## Orchestrating` (the HARNESS-094 line) |
| dispatch | GG_NEEDLES, RUN_NEEDLES, `every rung is something you run, not`, `bash scripts/attest.sh check` | unchanged (HARNESS-085) |

**Negative controls** (each a fixture run through the guard in the test file;
these did execute in RED - the guards are in the test files, so nothing failed
at import - and each passed, i.e. printed exactly the expected lines):

| Control | Expected output | Measured in RED |
|---|---|---|
| procedure `changed-regressed-step` | 1 line, `its step 2 does not name ...--changed` | that 1 line |
| procedure `changed-regressed-bullet` | 1 line, bullet does not name `--changed` | that 1 line |
| procedure `changed-unclosed` (`--changed origin/main`) | 1 line | that 1 line |
| procedure `full-no-condition` | 3 lines, one per condition | 3 lines |
| procedure `full-reworded` | 3 lines | 3 lines |
| procedure `full-every-suite-before-only` | 1 line, `every suite` | that 1 line |
| procedure `full-missing` | 1 line, no full-run option | that 1 line |
| procedure `changed-all-absent` (HARNESS-094 text) | 4 lines = the real tree's RED output | 4 lines, identical to the real tree's |
| dispatch `st-full-094` | 1 line, step does not name `--changed` | that 1 line |
| dispatch `lead-regressed` (every `--changed` deleted) | 1 line, long-run paragraph does not name `--changed` | that 1 line |
| dispatch `st-check-full` / `st-run-full` | 1 line, does not dispatch | that 1 line each |
| dispatch `today-094` (HARNESS-094 text) | 3 lines = the real tree's RED output | 3 lines, identical to the real tree's |

There is no threshold in this story; the controls are exact-output.

**Passed on arrival.** Every fixture case passes in RED by construction (the
guard and the fixtures are both in the test file); what earns them is that
the controls above produce exactly the fault lines and the compliant fixture
produces none. The one assertion that judges the real files is red. No
assertion against the real files passed on arrival.

**DV-1 is declined in RED.** It mutates the real `advance-story.md` and
`lead-po.md` after GREEN has written the `--changed` text; that text does not
exist yet, so there is nothing to delete. Owner GATES. Expected red lines:
procedure prints exactly
`` .claude/commands/advance-story.md: its step 2 does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
and nothing else, provided the expression removes ` --changed` from
the bare span (procedure locates the step by it; the attest spans do not
contain it, lacking the opening backtick). Add `g` if GREEN puts two spans on
one line. Dispatch, for the same expression on advance-story, prints exactly
`` .claude/commands/advance-story.md: the self-test step does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``;
for the lead-po mutation it prints exactly
`` .claude/agents/lead-po.md: its long-run paragraph does not name `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` ``
(fixture `lead-regressed` is that mutation, and it gave that line in RED).
The expression `s/selftest.sh --changed`/selftest.sh`/` does not touch the
`allowed-tools` entry (`--changed:*)`), so no "lacks" line joins it.

**Callers checked.** `rg 'SELFTEST_JOBS=4 bash scripts/selftest.sh'` over
`.claude`, `scripts`, `.github` and `CLAUDE.md` (state logs aside): the three
files above and the two guards; `scripts/attest.sh:22` (comment, stays, as the
Contract says); `scripts/selftest-needed.sh:13` and `scripts/selftest.sh:11`
(comments describing the full run, both still true, stay - the Contract's
Callers list did not name these two; no change needed); `CLAUDE.md:162`
already carries the `--changed` line - **do not edit it**:
`.claude/tests/selftest-needed.test.sh:868` (`CM_L2`) pins that whole line,
"(HARNESS-095 switches the procedure to it)" included.

**Discovered.** Other suites read these three files and must stay green after
GREEN: `attest.test.sh` (advance-story and lead-po must keep
`bash scripts/attest.sh check` and `Bash(bash scripts/attest.sh check:*)`),
`reporting.test.sh` (lead-po `## Orchestrating`, the commands' last
paragraphs) and `story.test.sh`. Run
`bash scripts/selftest.sh procedure dispatch attest reporting story` in GREEN.

**Files touched in RED.** `.claude/tests/procedure.test.sh`,
`.claude/tests/dispatch.test.sh`, `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh`, this story (`## Contract` amendment block,
`## Test plan`, this handoff).

### R-1 addendum (return to RED from GATES, 2026-11-05)

**GREEN must:** add the route-back clause to condition (c) in
`.claude/commands/advance-story.md` step 2, containing the literal span
`` `bash scripts/phase.sh set $1 GATES` `` (`$1` as text, not expanded) after
the first `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` span, inside
step 2 (no blank line before it, not in step 3 or later). Keep condition
(a)'s backticked `` `every suite` `` after that span too. Nothing else.

**What changed in the guard** (`procedure.test.sh`):
- `FULL_WHEN[0]` is now `` '`every suite`' `` (backticks in the needle). The
  fault line is unchanged: `<file>: its full-run option does not say when:
  `every suite`` (the printf strips the needle's own backticks).
- New `STEP_BACK='`bash scripts/phase.sh set $1 GATES`'`, read by
  `full_option` from the same region (squashed text after the first full-run
  span), with its own line:
  `.claude/commands/advance-story.md: its full-run option does not say how to get back: `bash scripts/phase.sh set $1 GATES``.
  It is not a `FULL_WHEN` entry, so "three conditions" stays true in every
  description and in the count wording.
- Fixtures: `REST` gains, after condition (c), the route back on its own
  lines and the real step's closing sentence "CI runs every suite on the PR
  either way."; `CLAUSE` backticks `every suite` and appends the route back.
- New cases (+5 assertions): `full-every-suite-only-in-closing` (precondition
  + control, exactly the (a) line), `full-no-route-back` (control, in prose
  elsewhere, exactly the AM-1 line), `full-route-back-before-only`,
  `full-route-back-expanded` (`HARNESS-095` in place of `$1`). Floor
  procedure 149 -> 154 in `floors.conf` and `selftest.test.sh`.

**Command:** `bash scripts/selftest.sh procedure selftest`

**Observed failure** (attested; local run, two `gates.sh --fast` runs from
other sessions on the host):

    exit:     1
    duration: 105s
    last:     1 of 2 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261105T223240Z.18813.log

        FAIL procedure_problems over the real tree prints nothing: ...
             expected: 
             actual:   .claude/commands/advance-story.md: its full-run option does not say how to get back: `bash scripts/phase.sh set $1 GATES`
    procedure: 153 passed, 1 failed
    FAIL procedure  did 153 units of work, below the floor of 154 in .claude/tests/floors.conf
    selftest: 309 passed, 0 failed

Every fixture case passes; the one red is the real-tree assertion, on the
AM-1 line alone. `gates.sh --fast` skipped: gates are unconfigured
(BOOTSTRAPPED=no).

**Files touched in this return:** `.claude/tests/procedure.test.sh`,
`.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, this story
(`## Regressions` R-1, this addendum).

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

**R-1 (from GATES, 2026-11-05): condition (a)'s needle cannot fail on the real tree.**

- **Which test:** `procedure.test.sh`, `full_option`, with
  `FULL_WHEN=('every suite' ...)`. It asserted that the text from the first
  full-run span onward says `every suite`.
- **What was wrong:** the step's closing sentence, "CI runs every suite on
  the PR either way", comes after that span. So the bare `every suite` is
  satisfied whether or not condition (a) exists. A needle that cannot fail is
  a test that cannot fail (`rules.md`).
- **How it was found:** finding 1 of the first diff review. The orchestrator
  reproduced it with a different edit, which rewrote line 318's
  `` `every suite`: the run already is the full one `` as
  `the selection was everything`:

      bash scripts/mutate.sh .claude/commands/advance-story.md '318s/`every suite`: the run already is the full one/the selection was everything/' -- bash scripts/selftest.sh procedure
      procedure: 149 passed, 0 failed
      === mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261105T222525Z.11085.bak) ===

- **What it must assert now:** condition (a)'s needle is the backticked code
  span `` `every suite` ``. The closing sentence writes it without backticks,
  and a later reword of it will too. AM-1 also adds a needle for (c)'s route
  back, `` `bash scripts/phase.sh set $1 GATES` ``, read from the same region.
  That one fails on the real tree today, because GREEN has not written it.
- **What earns it:** the same mutation, run against the corrected test, must
  turn `procedure` red with the "does not say when" line for
  `` `every suite` ``. RED pastes it here.

RED (R-1) earned: line 318 was checked first (`sed -n 318p` gives
`` `every suite`: the run already is the full one, and there is nothing to ``),
so the line number stands. The corrected test, same mutation, `procedure`
red with the (a) line for advance-story.md. The AM-1 line beside it is
expected: GREEN has not written the route back yet. The floor line is the
same red seen as a count (153 passed against a floor of 154). Then
`mutate.sh --check` was clean:

    $ bash scripts/mutate.sh .claude/commands/advance-story.md '318s/`every suite`: the run already is the full one/the selection was everything/' -- bash scripts/selftest.sh procedure
    === mutate: .claude/commands/advance-story.md (1 line(s) changed by 318s/`every suite`: the run already is the full one/the selection was everything/) ===
    === mutate: running bash scripts/selftest.sh procedure ===
        FAIL procedure_problems over the real tree prints nothing: ...
             expected: 
             actual:   .claude/commands/advance-story.md: its full-run option does not say when: `every suite`
             .claude/commands/advance-story.md: its full-run option does not say how to get back: `bash scripts/phase.sh set $1 GATES`
    procedure: 153 passed, 1 failed
    FAIL procedure  did 153 units of work, below the floor of 154 in .claude/tests/floors.conf
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261105T223227Z.18262.bak) ===
    $ bash scripts/mutate.sh --check
    mutate: no stranded mutation; nothing of a previous run is in the tree.

Unmutated, the same suite reports only the AM-1 line (attested run in the
handoff's R-1 addendum), so the (a) line above comes from the mutation alone.
The fixture case `full-every-suite-only-in-closing` reproduces the defect
without the real tree: (a) reworded away, the closing sentence kept, exactly
the (a) line.

## Diff review

First review, 2026-11-05: a fresh `feature-developer`, Opus 5.5
(`claude-opus-5-5`), no override, using the `diff-review` skill. It changed
no file. The report, as returned:

**What this change does.** The local self-test before a PR changes from the
full `SELFTEST_JOBS=4 bash scripts/selftest.sh` to
`SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`, which runs only the
suites the diff can break. The full run is kept for three named cases. The
change touches advance-story step 2, the complete-story bullet, lead-po's
long-run paragraph and both allowed-tools lines. procedure.test.sh and
dispatch.test.sh are retargeted to the `--changed` spelling, and their floors
are raised to 149 and 83.

**What it checked:**
- The whole diff against main.
- `scripts/selftest.sh` lines 290-370: the header text, that the floors audit
  runs first under `--changed`, and the `every suite` wording.
- HARNESS-094's DV-2 numbers (21 of 34 suites, 6,444 s against 12,502 s),
  against HARNESS-094.md lines 533-551.
- The 3,845 s and 11,419 s durations, against HARNESS-086 and HARNESS-088.
- Which suites read the three files:
  - GREEN's attested run covered attest, reporting, story and shipped-docs,
    all green.
  - `selftest-needed.test.sh`'s CM_L2 pins CLAUDE.md, which the diff does not
    touch.
  - plan.test.sh reads only the commands' `model:` line, which did not
    change.
- The HARNESS-068/072/075 fixtures keep their expected lines. Only the
  targeted/prose/other-paragraph message moved, from "GATES → REVIEW steps do
  not name" to "step 2 does not name", as the Contract asks.
- HARNESS-085's `today` case keeps its six lines, and `lead-no-check` expects
  two, as RED's amendment records.
- `bash scripts/selftest.sh procedure dispatch`: 149 and 83 passed, both
  floors met.

**Should fix**

1. **Condition (a)'s needle cannot fail on the real tree**
   (`procedure.test.sh` `FULL_WHEN`, `full_option`; `advance-story.md:318`
   and `:326`).
   - The check reads the text from the first full-run span onward. The
     step's last sentence, "CI runs every suite on the PR either way"
     (line 326), comes after that span, so it satisfies the `every suite`
     needle whether or not condition (a) exists.
   - Probe:
     `bash scripts/mutate.sh .claude/commands/advance-story.md '318s/`every suite`/`all suites`/' -- bash scripts/selftest.sh procedure`
     gave `procedure: 149 passed, 0 failed`, and the file was restored.
   - Fix: a backticked needle, `` '`every suite`' ``. That is a test change,
     so it means a return to RED, earned by this mutation. Rewording line 326
     alone leaves the trap for the next edit.
2. **Case (c) is in a step the orchestrator is no longer running when it
   applies** (`advance-story.md:322-325`).
   - CI's failure is seen at REVIEW, and nothing says to go back to GATES and
     through this step again.
   - Fix: one clause in (c), "set the phase back with
     `bash scripts/phase.sh set $1 GATES`, fix, and at this step dispatch the
     full run". Prose only, so it can be fixed in GATES.

**Nice to have**

3. The dispatch guard's "does not name `--changed`" message appears only
   when every `--changed` in the paragraph is gone (`dispatch.test.sh:356-367`).
   This is the same as DV-1's finding. The guard is still red; only the
   message is imprecise.
4. "its `gates` check is not required on `main`" (`advance-story.md:326-328`)
   is a fact about this repository, but it ships to consumer projects.
   Qualify it as "in this repository".

Not checked: the full self-test, which was out of its brief.

Verdict: Ship.

**Orchestrator's reproduction of finding 1, with a different edit.**
Condition (a)'s own words on line 318 were replaced, and the guard stayed
silent:

    bash scripts/mutate.sh .claude/commands/advance-story.md '318s/`every suite`: the run already is the full one/the selection was everything/' -- bash scripts/selftest.sh procedure
    procedure: 149 passed, 0 failed
    === mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261105T222525Z.11085.bak) ===
    mutate: no stranded mutation; nothing of a previous run is in the tree.

Finding 2 was confirmed by reading: advance-story's REVIEW → DONE paragraph
has no route back from a red CI self-test to step 2.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-05T22:21:27Z
    commit: 0d3f352
    tree:   6e0e011ccc46fd7fe0cf8e53d639f0df4e1c04d7
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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

- RED verified by the orchestrator, 2026-11-05. `attest.sh check` said
  `fresh` for both runs at tree `63c5280`, so the orchestrator ran neither
  again.
  - `selftest.sh procedure dispatch`: exit 1. Each suite has exactly one red
    assertion, the real-tree one. Its actual output is the Contract's fault
    lines naming the three real files (log
    `.claude/state/attest-logs/20261105T172228Z.24979.log`).
  - `selftest.sh selftest`: exit 0, 309 passed.
  - Gates were not run, because none is configured (BOOTSTRAPPED=no).
- GREEN verified by the orchestrator, 2026-11-05.
  - The feature-developer ran the 20 suites that `--suites` selected,
    through attest: exit 0, `20 harness suite(s) passed.`, 9,299 s, log
    `.claude/state/attest-logs/20261105T175944Z.62799.log`. procedure scored
    149/149 and dispatch 83/83, and every suite met its floor. `attest.sh
    check` said `fresh`, so the orchestrator did not run it again.
  - While that run was going, the developer also ran `procedure.test.sh`
    once in the same worktree. That run only reads files, and the tree hash
    is the same before and after.
  - The orchestrator read the diff, and checked the 3,845-11,419 s figures
    against HARNESS-086..088.
  - `gates.sh --fast` was run after that test run finished. No gate is
    configured.
- GATES, 2026-11-05.
  - The orchestrator ran DV-1. Its result is in `## Deferred verifications`.
  - A feature-developer ran the full gates through attest:
    `All required gates passed (0 ran, 7 unconfigured, 0 known)`, exit 0,
    log `.claude/state/attest-logs/20261105T222126Z.7848.log`.
  - `attest.sh check` said `fresh`.
- GREEN after R-1, 2026-11-05.
  - A feature-developer, Opus 5.5 (`claude-opus-5-5`), made two edits to
    `advance-story.md` step 2: case (c)'s way back, via
    `bash scripts/phase.sh set $1 GATES`, and the qualifier "in this
    repository" on the branch-protection sentence.
  - It ran six suites through attest:
    `selftest.sh procedure dispatch attest reporting story shipped-docs` gave
    exit 0, `6 harness suite(s) passed.`, procedure 154/154. `attest.sh check`
    said `fresh`.
  - `gates.sh --fast` passed, with no gate configured.
