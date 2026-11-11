---
id: HARNESS-102
title: A contract-is-wrong claim is adjudicated on fable, and the PR is refused without the record
slug: a-contract-is-wrong-claim-is-adjudicated
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-102-a-contract-is-wrong-claim-is-adjudicated
depends_on: [HARNESS-101]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/harness/models.conf, .claude/tests/plan.test.sh, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/lead-po.md, .claude/harness/rules.md, .claude/skills/diff-review/SKILL.md, scripts/new-story.sh, .claude/tests/new-story.test.sh, .claude/skills/story-authoring/SKILL.md, .claude/skills/story-authoring/reference/sections.md, .claude/tests/dispatch.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the suites named in Context under their selftest floors, which CI runs in full on the PR
---

## Context

The second half of the user's decision of 2026-11-11 (HARNESS-101 has the
first, and the reason for the whole re-split). HARNESS-101 moves the session
that orchestrates a story to `opus`. One judgement that session makes today is
too consequential to move with it: deciding whether a claim that the
**contract** is wrong - an acceptance criterion, a threshold, a frozen test -
is a correct escalation or an agent's excuse for not failing. Today the rule is
that the orchestrator reproduces the claim independently
(`advance-story.md`, "Rules for you as orchestrator"; `complete-story.md`;
`lead-po.md`; `story-authoring`). Two things were decided:

5. That claim is adjudicated by a fresh `fable` dispatch, not by the
   orchestrator.
6. The trigger is mechanical: `scripts/check-boundaries.sh` refuses a PR in
   which a new `## Regressions` or `## Amendments` entry has no adjudication
   record naming the model that ran it.

What exists to build on. `check-boundaries.sh` block 3d requires
`## Amendments` to have content when the criteria changed; block 3g requires
`## Regressions` to carry pasted output. Neither reads entries one by one, and
neither asks who judged the claim. Entries are written under an id by
convention, in three spellings found in this tree: `### R-1 (...)`
(HARNESS-089, HARNESS-094), `**R-1 (...)` (HARNESS-095) and `- **R-1 (...)`
(HARNESS-099, HARNESS-100); amendments as `- **AM-1 (...)`. HARNESS-082 wrote
`### Return 1`, which carries no id.

Two points the decision leaves open are settled here with a default, as AC-6
and AC-7, and put to the user before this story leaves PLANNED: what the check
does with a record that names a model other than the planned one, and how an
amendment the user asked for unprompted is recorded.

**Depends on HARNESS-101**, for two things it builds: the shape of a row in
`models.conf` that is a step and not a phase, and the diff reviewer's `Route`
label, which is one of the two dispatches entitled to write a record.

**The required gate.** Every gate is unconfigured in this repository. The
artifact is judged by the `boundaries`, `plan`, `dispatch` and `new-story`
suites under their self-test floors, which CI runs in full on the PR.

## Acceptance criteria

- **AC-1** — Given the tree, when the contract-is-wrong rule is read in
  `advance-story.md` ("Rules for you as orchestrator"), in `complete-story.md`
  and in `.claude/agents/lead-po.md`, then each says that a claim that an
  acceptance criterion, a threshold or a frozen test is wrong is adjudicated
  by a fresh `lead-po` dispatch on the `ADJUDICATE row` of `models.conf`,
  which reproduces it on different inputs without the claimant's code and
  answers upheld or rejected; that the orchestrator does not adjudicate it;
  that an upheld claim's `## Regressions` or `## Amendments` entry carries the
  adjudication record; that a rejected claim gets a line in `## Notes` and no
  entry; and that an entry which comes from a diff-review finding routed `RED`
  or `AMEND` is adjudicated by that review, and its record names it. None of
  the three still tells the orchestrator to reproduce the claim itself.
- **AC-2** — Given the shipped `models.conf` and an ordinary story, when
  `bash scripts/plan.sh models <id>` runs, then it prints HARNESS-101's seven
  rows unchanged and an eighth, last: `ADJUDICATE`, `lead-po`, `fable`.
- **AC-3** — Given a story branch whose story file has, outside HTML comments
  and fenced blocks, an entry head `R-<n>` in `## Regressions` or `AM-<n>` in
  `## Amendments` that the base branch's copy of that section does not have
  (every entry head, when the base has no copy of the file), and no
  adjudication record for that id in the same section, when
  `bash scripts/check-boundaries.sh` runs, then it exits non-zero and prints
  one `FAIL` line per such id, naming the story, the section and the id.
- **AC-4** — Given the same story with, in the same section, a line of the
  form ``**Adjudicated R-1:** `fable` (resolved claude-fable-5-2), ...`` for
  each new id, then the run prints an `ok` line for that section and no `FAIL`
  about adjudication. It is still refused, for that id, when the record: sits
  inside an HTML comment or a fenced block; names a different id; sits in the
  other section; names a model that is not one of `opus`, `fable`, `sonnet`,
  `haiku`; or has no `(resolved <name>)`. A story fresh from
  `scripts/new-story.sh`, with one entry head added and nothing else, is
  refused: the template's own comments do not discharge the check. An entry
  head the base copy already has is not judged. A story whose two sections
  hold nothing outside comments gets no adjudication line at all, neither `ok`
  nor `FAIL`.
- **AC-5** — Given a story whose `## Regressions` or `## Amendments` has
  content outside HTML comments that the base copy's section does not have,
  and no entry head at all, when `check-boundaries.sh` runs, then it prints a
  `FAIL` naming the section and saying an entry is headed `R-<n>` or `AM-<n>`.
  An entry written without an id cannot pass unjudged.
- **AC-6** — Given a record that is well formed and names a model other than
  the one the `ADJUDICATE` row of `models.conf` plans, when
  `check-boundaries.sh` runs, then the record is accepted and the run prints a
  `note` line (not a `FAIL`) naming the id, the model recorded and the model
  planned. With no `models.conf`, or no `ADJUDICATE` row in it, there is no
  such note.
- **AC-7** — Given an `## Amendments` entry `AM-<n>` whose record reads
  ``**Adjudicated AM-<n>:** requested by the user, <date>``, when
  `check-boundaries.sh` runs, then it is accepted: a change the user asked for
  unprompted is not a claim and has no dispatch to name. The same words for an
  `R-<n>` in `## Regressions` are refused.
- **AC-8** — Given a story created by `scripts/new-story.sh`, when its
  `## Amendments` and `## Regressions` template comments are read, then each
  gives the entry head and the record line in the form AC-3 and AC-4 accept
  and says a fresh `fable` dispatch writes the judgement, and the Amendments
  comment no longer asks for "the ORCHESTRATOR'S OWN reproduction".
  `.claude/skills/story-authoring/reference/sections.md` and the sentence in
  `story-authoring/SKILL.md` that ends "after the orchestrator has reproduced
  the finding independently, on its own inputs" say the same.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/harness/models.conf`, `.claude/tests/plan.test.sh`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/agents/lead-po.md`, `.claude/harness/rules.md`, `.claude/skills/diff-review/SKILL.md`, `scripts/new-story.sh`, `.claude/tests/new-story.test.sh`, `.claude/skills/story-authoring/SKILL.md`, `.claude/skills/story-authoring/reference/sections.md`, `.claude/tests/dispatch.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`boundaries.test.sh`, `plan.test.sh`, `new-story.test.sh` and
`dispatch.test.sh`. GREEN (feature-developer) writes everything else,
including the two floor records, raised to the executed counts it measures.

**C-1. The entry head.** A line of a section, read after HTML comments are
removed and with lines inside a fenced block (opened and closed by a line
beginning with three backticks or three tildes) skipped, that matches:

    ^ {0,3}(#{3,6} |- )?(\*\*)?(R|AM)-[0-9]+([^0-9]|$)

`## Regressions` reads only `R-` heads and `## Amendments` only `AM-` heads.
The id is the letters, the hyphen and the digits: `R-1`, `AM-12`. The trailing
`([^0-9]|$)` is what keeps `R-1` from matching inside `R-12`. Several lines
may carry the same id (HARNESS-099 writes `- **R-1 before side, ...` further
down the same entry); the section's ids are a set. This accepts the three
spellings in the tree - `### R-1 (`, `**R-1 (` and `- **R-1 (` - and does not
accept `### Return 1`.

**C-2. The adjudication record.** One line, in the same section as the entry
it belongs to, read under the same two exclusions (no HTML comment, no fenced
block), matching:

    ^ {0,3}(- )?\*\*Adjudicated (R|AM)-[0-9]+:\*\* <who>

where `<who>` is one of

    `<model>` \(resolved <name>\)        <model> is opus, fable, sonnet or haiku
                                         <name> is one or more of A-Z a-z 0-9 . _ -
    requested by the user                 accepted for an AM- id only (AC-7)

and the rest of the line is free. As it is written in a story:

    - **Adjudicated R-1:** `fable` (resolved claude-fable-5-2), 2026-11-14, fresh dispatch: reproduced on a two-workflow fixture of its own; the test expected one fault where the script reports two.
    - **Adjudicated AM-1:** `fable` (resolved claude-fable-5-2), 2026-11-14, diff review round 1, finding 2.
    - **Adjudicated AM-2:** requested by the user, 2026-11-14.

`<model>` is the model the dispatch was planned on, backticked, and
`<name>` is what it resolved to, by name - the same two facts
`## Model guidance` records for every dispatch. A record line is not an entry
head: it begins `**Adjudicated`, which C-1 does not match.

**C-3. What is new.** The ids of the working tree's section, minus the ids of
the same section in `$BASE:<story file>` (the script's first argument, default
`origin/main`, as block 3d uses it). When the base has no copy of the file,
the base set is empty and every id is new. The base copy is written to the
script's scratch file (`$cp`) and read from there, as 3d does: a here-string
of a story copy blocked on Cygwin bash near 64 KiB (HARNESS-089), and a
pipeline into an awk that exits early is the SIGPIPE shape
`check-sigpipe.sh` refuses. Any `grep -c` follows `check-grep-count.sh`.

**C-4. The block.** A new block, `3k`, appended after block 3j and before the
final `exit $fail`, so that no line above it moves: `sigpipe.test.sh` pins
`scripts/check-boundaries.sh:399`, `:438` and `:630`. If GREEN finds a pin
has moved anyway, that is a return to RED for `sigpipe.test.sh` (HARNESS-089's
R-1 is the precedent), and the file joins `touches:` then. For each of the two
sections, in this order:

1. Nothing outside HTML comments: say nothing.
2. Content, and the comment-stripped section equals the base copy's
   comment-stripped section: say nothing (nothing is new).
3. Content that is new, and no entry head at all: one `problem` (AC-5).
4. For each new id with no record for that id in this section: one `problem`
   naming story, section and id (AC-3). A `requested by the user` record
   counts for `AM-` only (AC-7).
5. For each new id whose record names a model other than the `ADJUDICATE`
   row's: one `note` (AC-6). The row is read from
   `.claude/harness/models.conf` with the field grammar `plan.sh` uses; no
   file or no row, no note.
6. At least one new id and no `problem` from 3 or 4 for this section: one
   `ok`, "## <section>: every new entry carries an adjudication record".

The messages follow the file's convention: a `problem` says what is missing
and exactly what to write, with the record line spelled out.

**C-5. A limit, stated.** Prose added under an id the base copy already has is
not judged, and neither is an entry on a story that never returns to a PR.
The check establishes that a record exists and names a model; it cannot
establish that the dispatch happened. That is the same standing every record
in a story has.

**C-6. The row (AC-2).** One line at the end of the `model` rows in
`models.conf`, in HARNESS-101's step-row shape:

    model  | ADJUDICATE | lead-po | fable | <why>

It can be needed in any phase, which is why it is last and not between two
phases. `lead-po` for the reason HARNESS-101's C-2 gives for the diff review:
it declares `fable`, so a dispatch that loses its explicit model still lands
there. `scripts/plan.sh` is not changed. The dispatch reads its model from
`bash scripts/plan.sh models <id>`, not from the story's table, which predates
the row for a story planned earlier.

**C-7. The procedure (AC-1).** The three statements of the rule are rewritten
in place: the bullet beginning "**A claim that the contract itself is wrong**"
in `advance-story.md`, the bullet beginning "**A claim that the contract is
wrong is reproduced before it is accepted.**" in `complete-story.md`, and the
rung beginning "**A claim that the contract is wrong is reproduced
independently.**" in `lead-po.md`. Each keeps what the reproduction is -
different inputs, not the claimant's code, and why the claim has this shape -
and changes who performs it. Needles, each on one line: `ADJUDICATE row`,
`lead-po`, `**Adjudicated` in all three. None keeps `you reproduce
independently` (advance-story), `verify it yourself` (complete-story) or
`reproduce it on different inputs` addressed to the orchestrator (lead-po).
`diff-review/SKILL.md`, in its section on what happens to a finding, says an
entry that follows a `RED` or `AMEND` finding carries a record naming the
review round and finding number. `rules.md` gains one sentence in the
Amendments non-negotiable and one in "The model each agent runs on" naming
the `ADJUDICATE` row; `rules-trim.test.sh` stays green without being edited.

**C-8. The template (AC-8).** `scripts/new-story.sh`: the `## Amendments` and
`## Regressions` comments name the head (`AM-<n>`, `R-<n>`) and show the
record line. Both stay inside the HTML comment, and AC-4 pins that a comment
does not discharge the check. `new-story.sh` writes its body from a quoted
heredoc, so backticks in the record line are safe; `new-story.test.sh` holds
the regression for an unquoted one.

**C-9. Where the assertions live.**

| Suite | Holds |
|---|---|
| `boundaries.test.sh` | AC-3 to AC-7, in fixture repositories built the way the suite's 3d and 3g cases are; one case per refusal listed in AC-4, each with the accepted twin that differs in that one thing |
| `plan.test.sh` | AC-2: `SHIP_EXPECTED` with eight rows |
| `dispatch.test.sh` | AC-1: the three regions and their needles, over the real tree, with a fixture that fails each |
| `new-story.test.sh` | AC-8: the template comments; and that a generated story plus one bare entry head is refused (or that case sits in `boundaries.test.sh`, RED's choice, stated in the handoff) |

`boundaries.test.sh` also holds three cases built from this tree's own
entries, copied verbatim into the fixture as the branch's story: the
`## Regressions` section of `docs/backlog/stories/HARNESS-089.md` (`### R-1`),
of `HARNESS-095.md` (`**R-1`) and of `HARNESS-099.md` (`- **R-1`, with its
`- **AM-1` from `## Amendments`). Each must be refused naming `R-1` (and
`AM-1`), because none of them carries a record. They are the fixtures that
were not written from this contract's reading of the format.

**Oracle partition.** AC-1, AC-2 and AC-8 are **mechanical**: fixed strings in
named regions, a row. AC-3 to AC-7 are **mechanical** too, and the grammar in
C-1 and C-2 is **settled**: read the two patterns out, do not redesign them;
amend them here with a reason if a real entry in the tree defeats one. Nothing
is oracle-free.

**Callers.** No existing function changes signature. `section`,
`strip_comments`, `has_content`, `problem`, `ok` and `note` are used as they
are. Existing fixtures in `boundaries.test.sh` that put content in
`## Regressions` or `## Amendments` of a branch story will now meet block 3k:
RED greps the suite for both headings, lists in its handoff every existing
case whose expected output gains a line, and updates those expectations. That
list is the caller list of this story.

**Test-only dependencies.** None.

**Baseline, measured at PLANNED** (2026-11-11, tree at `5e52301`, the C-1
pattern run with `grep -E` over each section as `story.sh section` returns
it): HARNESS-089 `R-1`, `AM-1`; HARNESS-094 `R-1 R-2`, `AM-1 AM-2`;
HARNESS-095 `R-1`, `AM-1`; HARNESS-099 `R-1`, `AM-1`; HARNESS-100 `R-1`, no
amendment; HARNESS-082 none in either (its `### Return 1` carries no id). The
C-2 pattern accepted the first and third example lines above and refused
`` - **Adjudicated R-1:** fable `` (no backticks, no `resolved`). That run
did not skip fenced blocks; the built block does, and RED checks that no real
entry above is lost to it.

## Deferred verifications

The budget is `rules.md`, "Mutation work per story": one defect put back, one
probe against a real line of the tree, and one mutation per assertion that
passes on arrival. Each runs through `scripts/mutate.sh` against the one suite
that holds the assertion.

- **DV-1, the defect put back (AC-3).** With block 3k's refusal for a new id
  that has no record disabled in `scripts/check-boundaries.sh`, the AC-3
  assertion in the `boundaries` suite must fail. RED cannot run this: there is
  no block to disable. The expression is written against GREEN's line.
  **Owner: GATES.**

- **DV-2, a real line of the tree (AC-3).** The block is a rule over the
  tree's story files, and its fixtures are written from the contract's reading
  of how an entry is spelled. On this story's own branch, with one line
  `- **R-9 (probe).**` inserted under the `## Regressions` heading of the real
  `docs/backlog/stories/HARNESS-102.md`, `bash scripts/check-boundaries.sh`
  must print a `FAIL` naming `R-9`; `mutate.sh` restores the file. RED cannot
  run this: the block does not exist. **Owner: GATES.**

      bash scripts/mutate.sh docs/backlog/stories/HARNESS-102.md '/^## Regressions$/a - **R-9 (probe).**' -- bash scripts/check-boundaries.sh

- **DV-3, assertions that pass on arrival.** RED lists in its handoff every
  assertion it wrote that was green on its first run, with the mutation that
  would turn it red. The likely ones are the "say nothing" cases of AC-4
  (empty sections give no adjudication line) and the "no note" case of AC-6,
  which today's script satisfies by having no block at all. Each is earned
  once against the built block: for the first, a mutation that makes the block
  print its `ok` unconditionally. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-102` from `.claude/harness/models.conf`.
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

- PLANNED (2026-11-11, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the session that ran `/plan-story`; no override was reported to it, and the agent declares `model: fable`.
- No departure from the plan. This table was rendered before HARNESS-101 merged, so it has no DIFF-REVIEW row; at GATES → REVIEW take that row from `bash scripts/plan.sh models HARNESS-102`. This story's own ADJUDICATE row does not exist until it merges.
## Out of scope

- **Everything HARNESS-101 delivers**: the commands' `model:`, the
  `DIFF-REVIEW` row, the `Route` label, planning and PR feedback by dispatch.
- **Proving the dispatch happened.** The check reads a record. It does not
  read a transcript, and it does not refuse a record that names a model other
  than the planned one (AC-6 makes that a `note`).
- **Judging the adjudication's quality.** Whether the reproduction really used
  different inputs is read by the user in the PR, not by a script.
- **Entries the base branch already has**, and every story that is DONE. No
  past story is edited to add a record.
- **A story in flight when this lands.** Its entries are new against the base,
  so it owes a record for each; one adjudication dispatch, dated when it ran,
  is the honest way to get one. No grandfather clause.
- **`## Gate probes`, `## Deferred verifications`, `## Suppressions`.** Not
  read by the new block.
- **Blocks 3d and 3g.** Unchanged: 3d still asks for an `## Amendments` entry
  when the criteria changed, 3g still asks `## Regressions` for pasted output.
  The new block adds to them and replaces neither.
- **The RED → GREEN admissibility check and the mutation-table check.** They
  stay with the orchestrator; neither is a claim that the contract is wrong.
- **`scripts/plan.sh`.** Not changed.
- **Requiring an id on entries in other sections**, or renumbering the entries
  of past stories (HARNESS-082's `### Return 1`).

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


- Planned 2026-11-11 with HARNESS-101, from the user's decisions 5 and 6 of that day, on `main` at `5e52301`. `depends_on: [HARNESS-101]` is a real ordering: the record format accepts a diff-review `Route` finding as an adjudication, and the `ADJUDICATE` row takes the step-row shape, both of which HARNESS-101 builds. The two stories also share nine files.
- Two defaults are not among the user's decisions and are reported for a yes or no before this story leaves PLANNED: AC-6 (a record naming a model other than the planned one is accepted with a `note`, not refused) and AC-7 (an amendment the user asked for unprompted is recorded as `requested by the user`, with no dispatch).
- Decision 6 says every new entry needs a record. That includes a mechanical return to RED (a moved line pin, a reflowed test): it costs one small `fable` dispatch, and an exemption for "mechanical" entries would hand the routing judgement back to the orchestrator.
- **User answers, 2026-11-11:** AC-6 confirmed (a record naming a non-planned model passes with a `note`, not refused); AC-7 confirmed (`requested by the user` accepted for `AM-` entries only); and every new `## Regressions` entry needs a record, with no exemption for mechanical ones, confirmed. Asked in chat before the story left PLANNED; no criterion changed.
- **Carried from HARNESS-101 (2026-11-11), not yet in this story's criteria** — two items its diff review left, both in files this story edits; take them into the contract at PLANNED or say why not:
  1. `.claude/tests/dispatch.test.sh:988`: the PLANNED → RED needle list `row_problems` checks only `lead-po` and `PLANNED row`, so deleting HARNESS-101 AC-3's read-before-commit sentence ("Once the dispatch is back, read what it returned." in `advance-story.md`; "before you commit at PLANNED" in `complete-story.md`) leaves every suite green. Add a needle per file with a control, earned by mutation since the text exists (Route: RED).
  2. `.claude/commands/advance-story.md` ~line 410: the REVIEW-row PR-feedback dispatch should carry the same "unless the story's `## Model guidance` records a departure for that row" clause as GATES → REVIEW step 1 (Route: GATES).
