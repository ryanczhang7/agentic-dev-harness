---
id: HARNESS-102
title: A contract-is-wrong claim is adjudicated on fable, and the PR is refused without the record
slug: a-contract-is-wrong-claim-is-adjudicated
epic: 
type: feature
status: in-progress
phase: GATES
branch: story/HARNESS-102-a-contract-is-wrong-claim-is-adjudicated
depends_on: [HARNESS-101]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/harness/models.conf, .claude/tests/plan.test.sh, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/lead-po.md, .claude/harness/rules.md, .claude/skills/diff-review/SKILL.md, scripts/new-story.sh, .claude/tests/new-story.test.sh, .claude/skills/story-authoring/SKILL.md, .claude/skills/story-authoring/reference/sections.md, .claude/tests/dispatch.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the suites named in Context under their selftest floors, which CI runs in full on the PR
---

## Context

The second half of the user's decision of 2026-11-11 (HARNESS-101 has the
first, and the reason for the whole re-split). HARNESS-101, merged as #191
(release 120), moved the session that orchestrates a story to `opus`. One
judgement that session makes today is
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

**Depends on HARNESS-101**, now DONE, for two things it built: the shape of a
row in `models.conf` that is a step and not a phase, and the `Route` label a
`lead-po` on `fable` puts on a diff-review finding or a PR-feedback item. An
entry that follows a `RED` or `AMEND` label has already been judged on `fable`
by a dispatch that did not make the claim, so that label is its adjudication.

**Re-read against the tree at `b10546e`, after HARNESS-101 merged**
(2026-11-11). What that changed here: HARNESS-101 added
`## When you are dispatched inside a story` to `lead-po.md`, which lists three
dispatches and now needs the fourth; `rules.md` sits exactly at
`rules-trim.test.sh`'s 370-line cap, so C-7's edits to it may not add a line;
`models.conf`'s header says "One step ships"; and the PR-feedback dispatch on
the REVIEW row exists and labels with the same `Route`. Block `3k` is still
the next free block of `check-boundaries.sh` and the three `sigpipe` pins
still hold. HARNESS-101's diff review also left two small follow-ups in files
this story already edits; both are taken, as AC-9 and AC-10.

**The required gate.** Every gate is unconfigured in this repository
(`bash scripts/gates.sh --list`, 2026-11-11: all eight `<unconfigured>`), so
`required_gates` stays empty. The artifact is judged by the `boundaries`,
`plan`, `dispatch` and `new-story` suites under their self-test floors, which
CI runs in full on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story: there is no
done-when to check these criteria against, and no gap to record.

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
  entry; and that an entry which comes from a diff-review finding or a
  REVIEW-row PR-feedback item routed `RED` or `AMEND` is adjudicated by that
  dispatch, and its record names it. None of the three still tells the
  orchestrator to reproduce the claim itself. `lead-po.md`'s
  `## When you are dispatched inside a story` lists the adjudication, on the
  `ADJUDICATE row`, among the work that arrives by dispatch, and the agent's
  `description:` names the `ADJUDICATE` row beside the other three.
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
- **AC-9** — Given a tree whose `advance-story.md` PLANNED → RED region does
  not say `read what it returned`, or whose `complete-story.md` has no
  PLANNED → RED bullet saying `lead-po`, `PLANNED row` and
  `before you commit at PLANNED` together, when the `dispatch` suite's guard
  reads it, then it prints one line per file naming the file and what is
  missing. Over the tree as it is, it prints neither. (Carried from
  HARNESS-101's diff review: its AC-3 read-before-commit sentence could be
  deleted with every suite green.)
- **AC-10** — Given the tree, when the paragraph of `advance-story.md`'s
  REVIEW → DONE region that dispatches a `lead-po` on the `REVIEW row` for PR
  feedback is read, then it says the model comes from
  `bash scripts/plan.sh models <id>` unless the story's `## Model guidance`
  `records a departure for that row`, as GATES → REVIEW step 1 says of the
  DIFF-REVIEW row. A region without those words makes the `dispatch` suite's
  guard print one line naming the file, the region and the phrase. (Carried
  from HARNESS-101's diff review.)

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

*Amended in RED (2026-11-12, test-developer, return 1 from GATES, `## Regressions`
R-2): the pattern above makes all three prefixes optional, so a prose line
that wraps to begin `R-2 of HARNESS-094 did the same` is read as a new entry
and refused (diff review 1, finding 4). A head now requires one prefix; every
spelling in the tree has one. The pattern GREEN builds is:*

    ^ {0,3}((#{3,6} |- )(\*\*)?|\*\*)(R|AM)-[0-9]+([^0-9]|$)

*It accepts `### R-1`, `### **R-1`, `- R-1`, `- **R-1` and `**R-1`, and refuses a
bare `R-1` at the start of a line. Everything else in C-1 stands.*

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
    - **Adjudicated R-2:** `fable` (resolved claude-fable-5-2), 2026-11-15, PR feedback at REVIEW, item 1.
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
`scripts/check-boundaries.sh:399`, `:438` and `:630`. (Checked at `b10546e`:
the file is 1132 lines, `3j` is its last block, `exit $fail` is its last
line, HARNESS-101 did not touch it, and the three pinned lines read as the
pins say. A helper function the block needs is defined inside the block, not
beside the helpers at the top of the file, for the same reason.) The block
judges the one story the script already resolved for the branch (`$sid`,
`$sfile`), inside the same guard blocks 3b to 3j sit behind. If GREEN finds a pin
has moved anyway, that is a return to RED for `sigpipe.test.sh` (HARNESS-089's
R-1 is the precedent), and the file joins `touches:` then. For each of the two
sections, in this order:

1. Nothing outside HTML comments: say nothing.
2. Content, and the comment-stripped section equals the base copy's
   comment-stripped section: say nothing (nothing is new).
2a. Content that is new, and the working tree's section cannot be read to its
   end: it holds a comment opener with no closer anywhere after it, or, read
   after comments are removed, it ends inside a fence (an odd number of fence
   lines, whatever opened the last one - an ordinary unclosed block, or a line
   that opens and closes a fence on the same line, which C-1's fence rule reads
   as an opener); or it has an entry head outside comments and fences, and a
   line matching C-1's head pattern was removed with a comment or skipped
   inside a fence whose id is not also a head outside them. One `problem`
   naming the story (`$sid`), `## <section>` and
   containing the word `unreadable`, saying that what was hidden cannot
   be judged and what to fix (close the comment, close the fence, or quote the
   opener together with its closer, or name it in words); then nothing else for this
   section - no step 3 to 6, so no FAIL for an id and no `ok`. Steps 1 and 2
   are unchanged and come first, so a section identical to the base copy is
   not judged by this step.
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

*Amended in RED (2026-11-12, test-developer, return 1 from GATES, `## Regressions`
R-1): step 2a is new (diff review 1, finding 1). Without it an unclosed
comment opener, quoted in inline code, or a one-line fence hides every entry
after it and the run says `ok`. The tests pin: exactly one `FAIL` in the run,
beginning `FAIL  `, containing the story id, `## Regressions` or
`## Amendments`, and `unreadable`; a non-zero exit; no `ok` line for that
section. A comment opener quoted with its closer, and a fence that is closed,
are readable. A section whose only text after an unclosed opener is the rest of
the section still counts as having no content under step 1 (AC-4: "nothing
outside comments ... no adjudication line at all"), and step 2a does not
override that.*

*Amended in RED (2026-11-12, test-developer, return 2 from GATES, `## Regressions`
R-3): step 2a's end-of-section tests miss a stray PAIR - two one-line fences,
a quoted opener and a later quoted closer, a quoted opener and a later
ordinary comment - which balances both counts and hides a new entry between
them while the run says `ok` (diff review 2, finding 1). The hidden-head test
is added to the end-of-section tests, not in place of them: an unclosed
opener or fence still hides everything after it, head-shaped or not, and the
R-1 cases keep passing. It applies only where the section has a head outside
comments and fences: with none, step 3's headless `problem` (AC-5) is the
refusal, as the AC-5 case "a head inside a fence or a comment" already pins,
and the section is refused either way. A fenced example whose head-shaped line
repeats a real head's id hides nothing and is read as usual; one whose id is
no head outside is refused like the pair. The remedy's third clause was wrong
(diff review 2, finding 2): comments are removed before fences are read, so a
fenced opener is still unclosed; it now says to quote the opener with its
closer, or name it in words. The tests pin the same needles as return 1.*

**C-5. A limit, stated.** Prose added under an id the base copy already has is
not judged, and neither is an entry on a story that never returns to a PR.
The check establishes that a record exists and names a model; it cannot
establish that the dispatch happened. That is the same standing every record
in a story has. This story's own branch carries the block from GREEN on, so
an entry this story writes about itself owes a record like any other.

**C-6. The row (AC-2).** One line at the end of the `model` rows in
`models.conf`, after `SCAFFOLD`, in HARNESS-101's step-row shape:

    model  | ADJUDICATE | lead-po | fable | <why>

Today's seven rows, in file order, are `PLANNED RED GREEN GATES DIFF-REVIEW
REVIEW SCAFFOLD` (`bash scripts/plan.sh models HARNESS-102` at `b10546e`);
the eighth goes last and the seven do not move. It can be needed in any
phase, which is why it is last and not between two phases. `lead-po` for the
reason HARNESS-101's C-2 gives for the diff review: it declares `fable`, so a
dispatch that loses its explicit model still lands there. `scripts/plan.sh`
is not changed: the file's header says it "prints and renders a step row
exactly like a phase row" and does not check the column against
`phases.conf`, so `plan.sh write` will put the row in every story table it
renders from then on. The dispatch reads its model from
`bash scripts/plan.sh models <id>`, not from the story's table, which predates
the row for a story planned earlier.

The header comment of `models.conf` is brought into line in the same edit:
"One step ships" becomes two steps and names `ADJUDICATE`, and the list of
`fable` work reached by dispatch gains it. The header keeps `DIFF-REVIEW` and
does not regain `The orchestrating commands and the planning agents`, which
`dispatch.test.sh` (`MC_NEEDLES`, `MC_NOT`) already pins.

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
At `b10546e` the three begin at `advance-story.md:474`, `complete-story.md:71`
and `lead-po.md:175`; find them by their opening words, not the numbers.

*Amended in RED (2026-11-11, test-developer), two things, both for the same
reason: the three needles above pin who adjudicates and that a record exists,
and leave four of AC-1's own clauses with no assertion that fails when they
are dropped.* (1) **Four more needles in each of the three bullets**:
`upheld` and `rejected` (AC-1: "answers upheld or rejected"), `## Notes` (AC-1:
"a rejected claim gets a line in `## Notes`") and `AMEND` (AC-1: an entry
"routed `RED` or `AMEND`" is adjudicated by that dispatch). Each is a word AC-1
already uses; none fixes a sentence. (2) **The locator.** Each bullet is the
first line beginning `- **A claim that the contract`, to just before the next
line beginning `- `, a blank line or a `#` heading. Those opening words are
common to all three today and are what `dispatch.test.sh` finds them by, so
GREEN keeps them; everything after them in the bold lead is GREEN's to rewrite.
Also pinned in the same guard, from the paragraph above: `lead-po.md`'s
`## When you are dispatched inside a story` says `ADJUDICATE row` and no longer
`Three pieces of work`; its `description:` says `PLANNED`, `DIFF-REVIEW` and
`ADJUDICATE`; `diff-review/SKILL.md`'s `## 5. What happens to a finding` says
`**Adjudicated`. The two headings are matched as whole lines and must not be
renamed.

What each of the three says about the mechanics, so that they agree:

- **Who is dispatched.** A fresh `lead-po`, on the model
  `bash scripts/plan.sh models <id>` gives for `ADJUDICATE`, unless the
  story's `## Model guidance` records a departure for that row. It is given
  the claim, the story's `Acceptance criteria` and `Contract`, and the paths
  involved - not the claimant's probe as something to re-run.
- **Who writes the record.** The adjudicating dispatch, itself: it owns
  `docs/backlog/**`, and it is the one that knows what it resolved to. For an
  upheld claim it writes the entry head under the next free id when the entry
  does not exist yet, the `**Adjudicated <id>:**` line, and its reproduction
  beneath; whoever owns the section (the Test Developer for a return to RED,
  the orchestrator with the user for an amendment) fills in the rest. For a
  rejected claim it writes one line in `## Notes` and no entry. It sets no
  phase and commits nothing.
- **An upheld `AC` claim still goes to the user.** Adjudication establishes
  that the criterion is wrong; law 6 still has the user approve what it
  becomes. The record and the approval are two different lines of the entry.
- **A `Route`d entry.** The diff reviewer and the REVIEW-row reader change no
  file, so for an entry that follows their `RED` or `AMEND` label the
  orchestrator writes the record, naming the review round and finding number
  or the PR-feedback item, the model that dispatch was planned on and the name
  it resolved to as `## Model guidance` already records them. No second
  dispatch.

`lead-po.md` changes in two more places, both written by HARNESS-101: in
`## When you are dispatched inside a story`, "Three pieces of work" becomes
four, with a bullet beginning `- **Adjudication, on the ADJUDICATE row.**`,
and the sentence after the list ("you report back and do not orchestrate ...
commit nothing") stays true of all four; and the frontmatter `description:`
names the `ADJUDICATE` row beside `PLANNED, DIFF-REVIEW or REVIEW`. Needle
for the section: `ADJUDICATE row` inside it, not only somewhere in the file.

`diff-review/SKILL.md`, in `## 5. What happens to a finding`, says an entry
that follows a `RED` or `AMEND` finding carries a record naming the review
round and finding number, written by the orchestrator. Needle: `**Adjudicated`
in that section.

`rules.md` is edited in words, not in sentences, because it is at the cap:
`wc -l` gives 370 at `b10546e` and `rules-trim.test.sh` has `CAP=370`, a
number the user set. Three places: the two lists of `fable` rows in
`# The model each agent runs on` ("on the PLANNED, DIFF-REVIEW and REVIEW
rows", lines 88-89 and 109) gain `ADJUDICATE`, and the Amendments
non-negotiable, whose last line is the 14 characters `  entry there.`, gains
a clause of at most one line saying a new entry carries an adjudication
record. The file ends at 370 lines or fewer; a paragraph that reflows a line
longer is reworded until it does not. `CAP` is not raised and
`rules-trim.test.sh` is not edited; its line prefixes (`- Acceptance criteria
are frozen once a story leaves PLANNED, for the same` and `**The per-phase
plan is ...`) still begin a line. `dispatch.test.sh` already pins that
section (`RU_NEEDLES`, and `RU_NOT` refuses `PLANNED and REVIEW on`): the new
wording keeps the five needles and avoids that phrase. New needle there:
`ADJUDICATE`.

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
| `plan.test.sh` | AC-2: `SHIP_EXPECTED` with eight rows, and `SHIP_ORDER` ending `REVIEW SCAFFOLD ADJUDICATE` |
| `dispatch.test.sh` | AC-1: the three regions, `lead-po.md`'s dispatch section and description, `diff-review`'s section 5 and the `rules.md` section, each with its needles, over the real tree, with a fixture that fails each. AC-9 and AC-10: C-10 |
| `new-story.test.sh` | AC-8: the template comments; and that a generated story plus one bare entry head is refused (or that case sits in `boundaries.test.sh`, RED's choice, stated in the handoff) |

`boundaries.test.sh` also holds three cases built from this tree's own
entries, copied verbatim into the fixture as the branch's story: the
`## Regressions` section of `docs/backlog/stories/HARNESS-089.md` (`### R-1`),
of `HARNESS-095.md` (`**R-1`) and of `HARNESS-099.md` (`- **R-1`, with its
`- **AM-1` from `## Amendments`). Each must be refused naming `R-1` (and
`AM-1`), because none of them carries a record. They are the fixtures that
were not written from this contract's reading of the format.

**C-10. The two items carried from HARNESS-101 (AC-9, AC-10).** Both live in
`dispatch.test.sh`'s HARNESS-101 guard, `row_problems`, and follow its line
shape (`r_say`: ``<path>: <label> does not say `<needle>` ``). Needles are
matched after `flat`, so a phrase reflowed across a line break still counts.

- **AC-9, advance-story.** The PLANNED → RED region (`pl_region`) must also
  say `read what it returned`. Today `PL_NEEDLES` is `lead-po` and
  `PLANNED row` and is shared with complete-story, so this is a needle of its
  own for the advance-story region, not a third member of the shared list.
  The sentence is at `advance-story.md:115-116` ("Once the dispatch is back,
  read what it returned."); RED confirms `pl_region` reaches that far and
  says so in the handoff.
- **AC-9, complete-story.** The bullet that satisfies the existing check (one
  PLANNED → RED bullet saying both `lead-po` and `PLANNED row`) must also say
  `before you commit at PLANNED` (`complete-story.md:93-97`). A tree with the
  dispatch bullet and without the phrase gives one line; RED chooses whether
  that is the existing `L_CB_PL` line reworded or a second line, and states
  it.
- **AC-10.** `RD_NEEDLES` gains `records a departure for that row`, read in
  the REVIEW → DONE region. GREEN adds the clause to the PR-feedback
  paragraph (`advance-story.md:408-411`, "Dispatch a `lead-po` on the REVIEW
  row of `models.conf` (the model from `bash scripts/plan.sh models $1`)"),
  in the words step 1 uses at line 272. The same words in GATES → REVIEW
  step 1 are outside the region and do not satisfy it.

AC-10's assertion over the real tree is red in RED, which is its watched
failure. AC-9's two are **green on arrival**, because the sentences exist:
RED earns each in RED, by mutation of the real file, and pastes the red into
the handoff. They are not deferred:

    bash scripts/mutate.sh .claude/commands/advance-story.md 's/read what it$/skim what it/' -- bash scripts/selftest.sh dispatch
    bash scripts/mutate.sh .claude/commands/complete-story.md 's/before you commit at PLANNED/before you move on/' -- bash scripts/selftest.sh dispatch

Each fixture control ("the region without the needle gives exactly the one
line") is written as HARNESS-101's are.

**Oracle partition.** AC-1, AC-2, AC-8, AC-9 and AC-10 are **mechanical**:
fixed strings in named regions, a row. AC-3 to AC-7 are **mechanical** too, and the grammar in
C-1 and C-2 is **settled**: read the two patterns out, do not redesign them;
amend them here with a reason if a real entry in the tree defeats one. Nothing
is oracle-free.

**Callers.** No existing function changes signature. `section`,
`strip_comments`, `has_content`, `problem`, `ok` and `note` are used as they
are. Existing fixtures in `boundaries.test.sh` that put content in
`## Regressions` or `## Amendments` of a branch story will now meet block 3k:
RED greps the suite for both headings, lists in its handoff every existing
case whose expected output gains a line, and updates those expectations. That
list is the caller list of this story. At `b10546e` the two headings occur on
36 lines of that suite.

**Existing assertions these edits meet.** Not signatures, but the same duty:
RED's handoff states each was checked against the tree.

- `plan.test.sh`: `SHIP_EXPECTED` (seven rows, sorted) and `SHIP_ORDER`
  (`PLANNED RED GREEN GATES DIFF-REVIEW REVIEW SCAFFOLD`). Both change with
  AC-2, in RED.
- `dispatch.test.sh`, the HARNESS-101 block: `RU_NEEDLES`/`RU_NOT` over
  `rules.md`, `MC_NEEDLES`/`MC_NOT` over the `models.conf` header,
  `LP_NEEDLES` over `lead-po.md`, `RD_NEEDLES`/`RD_KEEP` over REVIEW → DONE,
  `PL_NEEDLES` over both PLANNED → RED texts, and the compliant fixtures
  (`write_r_*`, `R_RU_GOOD` and the rest) that every new needle has to be
  added to, or "the fixture: compliant by construction" goes red.
- Suites that read a file this story edits and are **not** edited: they stay
  green, and a failure in one is a finding, not a pin to move. `rules-trim`
  (the cap and the line prefixes of `rules.md`), `sigpipe` (the three line
  pins of `check-boundaries.sh`), `procedure` (regions of `advance-story.md`
  and `complete-story.md`), and `new-story.test.sh`'s existing assertions over
  the `## Regressions` template comment (lines 139-148).
  `bash scripts/selftest-needed.sh --suites` on the branch is the full list.

**Floors and release, at `b10546e`.** `boundaries` 545, `plan` 286,
`dispatch` 145, `new-story` 58, recorded in `.claude/tests/floors.conf` and
mirrored in `selftest.test.sh`; GREEN raises each of the four to the executed
count it measures, in both files. `.claude/harness/VERSION` is `120
(2026-11-11)` and becomes 121 with the real date.

**Test-only dependencies.** None.

**Baseline, measured at PLANNED** (2026-11-11, tree at `5e52301`, re-run at
`b10546e` with the same result; the C-1 pattern run with `grep -E` over each
section as `story.sh section` returns it): HARNESS-089 `R-1`, `AM-1`;
HARNESS-094 `R-1 R-2`, `AM-1 AM-2`; HARNESS-095 `R-1`, `AM-1`; HARNESS-099
`R-1`, `AM-1`; HARNESS-100 `R-1`, no amendment; HARNESS-101 none in either
(both sections hold only the template comment); HARNESS-082 none in either
(its `### Return 1` carries no id). The
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
  print its `ok` unconditionally. **Owner: GATES.** AC-9's two assertions also
  arrive green, but the text they pin exists in RED, so RED earns them itself
  (C-10 has the two commands) and GATES does not repeat them.

Not a deferred verification, and stated so that nobody adds one: AC-1, AC-2,
AC-8 and AC-10 are red in RED over the real tree, which is their watched
failure. The one orchestrator mutation `/advance-story` asks for after GREEN
comes out of RED's table as usual and is not listed here.


**Results, GATES, 2026-11-12 (orchestrator, `scripts/mutate.sh` against `bash scripts/selftest.sh boundaries` unless noted; every run restored and verified byte for byte; `mutate.sh --check` clean after).**

- **DV-2 - discharged.** The command in the entry, over the real story file, printed a FAIL naming R-9; restored:

```
=== mutate: docs/backlog/stories/HARNESS-102.md (1 line(s) changed by /^## Regressions$/a - **R-9 (probe).**) ===
  1199 + - **R-9 (probe).**
FAIL  story HARNESS-102: ## Regressions entry R-9 is new and has no adjudication record. A claim that the contract is wrong is judged by a fresh lead-po dispatch on the ADJUDICATE row (the model from 
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/docs_backlog_stories_HARNESS-102.md.20261112T062704Z.1641.bak) ===
```

- **DV-1 - discharged.** `1226s/^      problem "story/      : "story/` (step 4's refusal disabled): 40 red, AC-3's assertion first among them, plus every AC-4 refused-record case, AC-7's R- refusal and the three C-9 real-entry cases. First lines:

```
### DV1 :: 1226s/^      problem "story/      : "story/
exit 1
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 1226s/^      problem "story/      : "story/) ===
boundaries: 581 passed, 40 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T062801Z.6716.bak) ===
    FAIL HARNESS-102 AC-3: a new `### R-1` with no record, on a story the base has no copy of, gives exactly one FAIL naming the story, ## Regressions and R-1
    FAIL HARNESS-102 AC-3: and the run exits non-zero
    FAIL HARNESS-102 AC-3: two new ids with no record give one FAIL each: R-1 once, R-2 once
    FAIL HARNESS-102 AC-3: a new `### R-12` with no record gives one FAIL for R-12 and none for R-1
    FAIL HARNESS-102 AC-3: a new `- **AM-1` in ## Amendments with no record gives exactly one FAIL naming ## Amendments and AM-1
    FAIL HARNESS-102 AC-3: and the run exits non-zero
    FAIL HARNESS-102 AC-3: the head spelled `### R-1 (the count)` is an entry head: one FAIL for R-1
    FAIL HARNESS-102 AC-3: the head spelled `**R-1 (the count).**` is an entry head: one FAIL for R-1
    FAIL HARNESS-102 AC-3: the head spelled `- **R-1 (the count).**` is an entry head: one FAIL for R-1
```

- **DV-3 - discharged, mutation by mutation (the handoff's table).** One survivor, explained below; the table's last row (the new-story.sh precondition) is not run: it pins the fixture, not block 3k.

```
### M1-ok-despite-fail :: 1233s/\[ "\$adj_bad" -eq 0 \]/true/
exit 1
boundaries: 620 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T064501Z.62121.bak) ===
    FAIL HARNESS-102 AC-3: and there is no ok line for ## Regressions beside the FAIL
### M2-record-never-matches :: 1167s/Adjudicated /Adjudicatd /
exit 1
boundaries: 603 passed, 18 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T070126Z.113540.bak) ===
    FAIL AC-1 twin: with the plain file gone, the same fixture exits 0
    FAIL HARNESS-102 AC-4: a new R-1 with its `- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2)` record prints the ## Regressions ok line
    FAIL HARNESS-102 AC-4: and no FAIL about adjudication
    FAIL HARNESS-102 AC-4: and the spike exits 0
    FAIL HARNESS-102 AC-4: two ids, each with its record (the second without its leading `- `), are accepted: no FAIL about adjudication, exit 0
    FAIL HARNESS-102 AC-4: a new AM-1 with its record prints the ## Amendments ok line
    FAIL HARNESS-102 AC-4: and no FAIL about adjudication, exit 0
    FAIL HARNESS-102 AC-4: twin: a fence before the record does not swallow the record after it: the ok line
    FAIL HARNESS-102 AC-4: and the new R-2, recorded, gives the ok line
    FAIL HARNESS-102 AC-4: and the spike exits 0
    FAIL HARNESS-102 AC-6: a record naming `sonnet` where the ADJUDICATE row plans `fable` is accepted: the ok line
    FAIL HARNESS-102 AC-6: and no FAIL about adjudication, exit 0
    FAIL HARNESS-102 AC-6: and one note line naming R-1, the model recorded (sonnet) and the model planned (fable)
    FAIL HARNESS-102 AC-6: a `fable` record where the row plans `opus` gives the note naming R-1, fable and opus
    FAIL HARNESS-102 AC-6: with no ADJUDICATE row in models.conf there is no note, and the record is still accepted
    FAIL HARNESS-102 AC-6: with no models.conf at all there is no note, and the record is still accepted
    FAIL HARNESS-102 AC-7: `**Adjudicated AM-1:** requested by the user` is accepted for an amendment: the ok line
    FAIL HARNESS-102 AC-7: and no FAIL about adjudication, exit 0
### M3-fence-not-skipped :: 1173s/if (fence) continue/if (0) continue/
exit 1
boundaries: 615 passed, 6 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T071820Z.164993.bak) ===
    FAIL HARNESS-102 AC-4: the record inside a backtick-fenced block: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record inside a backtick-fenced block: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record inside a tilde-fenced block: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record inside a tilde-fenced block: and the run exits non-zero
    FAIL HARNESS-102 AC-4: a head inside a fence or a comment is not an entry head: no FAIL for R-1 or R-2
    FAIL HARNESS-102 AC-5: and the section, which has new content and no head outside them, is refused as headless
### M4-comments-not-stripped :: 1204s/has_content < "\$adj_cur" ||/true ||/;1206s/strip_comments < /cat < /;1161s/> 0) {/> 999999999) {/
exit 1
boundaries: 616 passed, 5 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T073545Z.216424.bak) ===
    FAIL an untouched template block is not a claim
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         FAIL  story T-1: ## Regressions has new content and no entry head, so nothing can say which entry it is or whether it was adjudicated. An entry is headed R-<n> (`### R-<n> (...)`, `**R-<n> (.
    FAIL HARNESS-102 AC-4: the record on its own line inside a multi-line HTML comment: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record on its own line inside a multi-line HTML comment: and the run exits non-zero
    FAIL HARNESS-102 AC-4: a story fresh from new-story.sh, untouched, gets no adjudication line at all
    FAIL HARNESS-102 AC-4: two sections holding only comments get no adjudication line at all, neither ok nor FAIL, and exit 0
### M5-base-ids-empty :: 1210s/adj_scan "\$adj_old" "\$adj_p"/:/
exit 1
boundaries: 616 passed, 5 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T075416Z.270724.bak) ===
    FAIL HARNESS-102 AC-4: an R-1 the base copy already has is not judged: no FAIL for R-1
    FAIL HARNESS-102 AC-4: and the new R-2, recorded, gives the ok line
    FAIL HARNESS-102 AC-4: and the spike exits 0
    FAIL HARNESS-102 AC-4: twin: the new R-2 without its record is refused, and the old R-1 still is not judged
    FAIL HARNESS-102 AC-4: prose added under an id the base already has is not judged: no adjudication line at all, exit 0
### M6-no-step-2 :: 1208s/ && continue/ \&\& :/
exit 1
boundaries: 620 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T081235Z.322095.bak) ===
    FAIL HARNESS-102 AC-5: twin: the same headless ## Amendments content already on the base is not new: no adjudication line, exit 0
### M7-raw-nonwhitespace :: 1204s/has_content < "\$adj_cur" ||/grep -q "[^[:space:]]" "$adj_cur" ||/
exit 0
boundaries: 621 passed, 0 failed
=== mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T083123Z.373521.bak) ===
### M8-ok-unconditional :: 1203s/^/  ok "## $adj_sec: every new entry carries an adjudication record"; /
exit 1
boundaries: 606 passed, 15 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T155004Z.433722.bak) ===
    FAIL an absent section is not a failure
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
    FAIL an untouched template block is not a claim
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
    FAIL HARNESS-102 AC-3: and there is no ok line for ## Regressions beside the FAIL
    FAIL HARNESS-102 AC-4: a new R-1 with its `- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2)` record prints the ## Regressions ok line
    FAIL HARNESS-102 AC-4: a new AM-1 with its record prints the ## Amendments ok line
    FAIL HARNESS-102 AC-4: twin: a fence before the record does not swallow the record after it: the ok line
    FAIL HARNESS-102 AC-4: a story fresh from new-story.sh, untouched, gets no adjudication line at all
    FAIL HARNESS-102 AC-4: and the new R-2, recorded, gives the ok line
    FAIL HARNESS-102 AC-4: prose added under an id the base already has is not judged: no adjudication line at all, exit 0
    FAIL HARNESS-102 AC-4: a section identical to the base copy's says nothing: no adjudication line at all, exit 0
    FAIL HARNESS-102 AC-4: two sections holding only comments get no adjudication line at all, neither ok nor FAIL, and exit 0
    FAIL HARNESS-102 AC-4: a story with neither section gets no adjudication line at all, and exits 0
    FAIL HARNESS-102 AC-5: twin: the same headless ## Amendments content already on the base is not new: no adjudication line, exit 0
    FAIL HARNESS-102 AC-6: a record naming `sonnet` where the ADJUDICATE row plans `fable` is accepted: the ok line
    FAIL HARNESS-102 AC-7: `**Adjudicated AM-1:** requested by the user` is accepted for an amendment: the ok line
### M9-note-when-equal :: 1229s/\[ "\$adj_m" != "\$adj_planned" \]/[ "$adj_m" = "$adj_planned" ]/
exit 1
boundaries: 618 passed, 3 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T161620Z.485231.bak) ===
    FAIL HARNESS-102 AC-6: and one note line naming R-1, the model recorded (sonnet) and the model planned (fable)
    FAIL HARNESS-102 AC-6: a `fable` record where the row plans `opus` gives the note naming R-1, fable and opus
    FAIL HARNESS-102 AC-6: twin: a `fable` record where the row plans `fable` gives no note
### M10-default-fable :: 1201s/^/[ -n "$adj_planned" ] || adj_planned=fable; /
exit 1
boundaries: 619 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261112T164458Z.549364.bak) ===
    FAIL HARNESS-102 AC-6: with no ADJUDICATE row in models.conf there is no note, and the record is still accepted
    FAIL HARNESS-102 AC-6: with no models.conf at all there is no note, and the record is still accepted
```

  M7 survives (621/0), and is equivalent: with step 1 replaced by a raw non-whitespace test, a comment-only section still reaches step 2, where both sides are compared after `strip_comments` - the base side is empty or the same comments - so it returns before any judging. The "two sections holding only comments" case is earned instead by M4 (which disables both steps) and M8. M4 and M8 also turned two pre-existing assertions red ("an untouched template block is not a claim", "an absent section is not a failure"), which pin the same property from 3j's side.

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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

- PLANNED (2026-11-11, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the session that ran `/plan-story`; no override was reported to it, and the agent declares `model: fable`.
- PLANNED review (2026-11-11, /advance-story): lead-po, planned fable, resolved claude-fable-5-2
- RED (2026-11-11, /advance-story): `test-developer`, planned `opus`, resolved **claude-opus-5-5**; no override reported.
- GREEN (2026-11-11, /advance-story): `feature-developer`, planned `opus`, resolved **claude-opus-5-5**; no override reported.
- GATES (2026-11-12, /advance-story): `feature-developer` for the full gate run, planned `opus`, resolved **claude-opus-5-5**; no override. DV-1..DV-3 run by the orchestrator (claude-opus-5-5).
- No departure from the plan. The table was re-rendered at the PLANNED review, after HARNESS-101 merged, so it carries the DIFF-REVIEW row. It has no ADJUDICATE row: that row is this story's own. If this story needs an adjudication before its GREEN adds the row, dispatch a fresh `lead-po` with `fable` named explicitly and record what it resolved to; after GREEN, `bash scripts/plan.sh models HARNESS-102` on the branch gives the row.

## Out of scope

- **Everything HARNESS-101 delivered**: the commands' `model:`, the
  `DIFF-REVIEW` row, the `Route` label, planning and PR feedback by dispatch.
  The two exceptions are the follow-ups its diff review left, taken here as
  AC-9 and AC-10; nothing else of HARNESS-101's text is reopened.
- **A departure clause or a PR-feedback paragraph in `complete-story.md`.**
  It defers to `/advance-story` for the REVIEW-row dispatch and has no
  sentence of its own to amend; AC-10 is about `advance-story.md` only.
- **Raising `rules-trim.test.sh`'s cap.** `rules.md` stays within 370 lines.
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

All four suites are bash, under `.claude/tests/`, run by `scripts/selftest.sh`.
The level is the one the contract lives at: the `boundaries` cases build a
two-branch fixture repository and run the real `scripts/check-boundaries.sh`
in it (integration); `dispatch`, `plan` and `new-story` read the real tree
or run the real script against fixtures.

| AC | Suite | Assertions (describe block) | Over |
|---|---|---|---|
| AC-1 | `dispatch` | `adj_problems` (new guard): the three contract-is-wrong bullets, `lead-po.md`'s description and `## When you are dispatched inside a story`, `diff-review`'s `## 5. What happens to a finding` - "HARNESS-102 AC-1 the real tree" (red), the compliant/CRLF/wrapped fixtures, today's words verbatim (28 lines), one case per needle per bullet (21), per forbidden phrase (3), region ends (next bullet, blank line), no region (3), the dispatch section, the description (3), section 5, missing files (4) | real tree + fixtures |
| AC-1 | `dispatch` | `row_problems`: `RU_NEEDLES` gains `ADJUDICATE` (rules.md); its own real-tree line count (red) | real tree + fixtures |
| AC-2 | `plan` | `SHIP_EXPECTED` with eight rows, for four story shapes; `SHIP_ORDER` ending `REVIEW SCAFFOLD ADJUDICATE`; `plan.sh write` renders exactly one `| ADJUDICATE | \`lead-po\` | \`fable\` | <why> |` row (C-6) | shipped `models.conf` in a fixture |
| AC-3 | `boundaries` | "block 3k": a new id without a record gives one FAIL per id naming the story, section and id, non-zero exit; two ids; `R-12` is not `R-1`; `AM-1`; the four head spellings | fixture repo |
| AC-4 | `boundaries` | the record accepted (ok line, exit 0) for R-1, two ids, AM-1; refused in a comment (inline, multi-line), in a ``` fence, in a ~~~ fence, for another id (R-2, R-12), in the other section, an unknown model, no `(resolved ...)`, no backticks, an empty name, mid-line; a fence does not swallow a record after it; heads in a fence/comment are not heads; a story from `new-story.sh` plus one head is refused, and untouched says nothing; an id the base has is not judged (and its twin); prose under an old id; a section equal to the base; comment-only sections and absent sections say nothing | fixture repo |
| AC-5 | `boundaries` | headless new content refused in both sections, naming `R-<n>` / `AM-<n>`; `### Return 1`; an `AM-` head in `## Regressions`; twin: the same content on the base | fixture repo |
| AC-6 | `boundaries` | `sonnet` record vs `fable` row accepted with one note naming R-1, sonnet, fable; `fable` vs `opus`; twin `fable`/`fable` no note; no row and no file: no note, accepted | fixture repo, `models.conf` written per case |
| AC-7 | `boundaries` | `requested by the user` accepted for AM-1; refused for R-1 | fixture repo |
| C-9 | `boundaries` | HARNESS-089, -095 and -099's own `## Regressions` and `## Amendments`, read verbatim from the real files: one FAIL for R-1, one for AM-1, no headless FAIL, non-zero | real entries in a fixture repo |
| AC-8 | `new-story` | the template's `## Amendments` and `## Regressions` comments name `AM-<n>` / `R-<n>`, show `**Adjudicated AM-<n>:**` / `**Adjudicated R-<n>:**` and `(resolved <name>)`, say `fable` and `fresh`; Amendments no longer says "orchestrator's own reproduction" (any case); `sections.md`'s two sections name the head, the record and `fable`; `story-authoring/SKILL.md`'s paragraph loses the old sentence and says `fable` and `ADJUDICATE` | generated story + real skill files |
| AC-9 | `dispatch` | `row_problems`: advance-story's PLANNED → RED region must say `read what it returned` (`PL_ADV_NEEDLES`); complete-story's dispatch bullet must say `before you commit at PLANNED` (a second line, `CB_PL_READ`); real-tree counts (green on arrival, earned in RED, see Handoff); fixture cases: without, wrapped, after the marker, in the other bullet | real tree + fixtures |
| AC-10 | `dispatch` | `RD_NEEDLES` gains `records a departure for that row`; real-tree count (red); the words only in GATES → REVIEW step 1 do not count; wrapped | real tree + fixtures |

The AC-4 case "a story fresh from `new-story.sh` plus one bare entry head is
refused" sits in `boundaries.test.sh` (C-9 left the choice to RED): it needs
`check-boundaries.sh` run over a fixture repository, which that suite already
builds and `new-story.test.sh` does not.

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

Written 2026-11-11 by the test-developer, dispatched planned `opus`, resolved
**claude-opus-5-5** (no override was reported to it).

### The command

    bash scripts/selftest.sh boundaries plan dispatch new-story

Run through attest exactly as `bash scripts/attest.sh -- bash scripts/selftest.sh boundaries plan dispatch new-story`.
The record and the fast gates are at the end of this section.

### What fails, and why it is the right failure

Every fixture control in all four suites is green; no suite fails to load. What
is red is exactly the new assertions over the real tree, and the `boundaries`
refusals that block 3k does not exist yet to make:

- `boundaries`: 565 passed, 56 failed. The 56 are the block 3k describe: every refusal (no 3k line is printed, and the spike fixtures exit 0) and every ok line. The other 20 assertions of that block pass on arrival (listed below, DV-3). The rest of the suite is green, the T-43 caller included.
- `plan`: 281 passed, 6 failed - the four `SHIP_EXPECTED` sets (seven rows printed, eight expected), `SHIP_ORDER`, and the `plan.sh write` ADJUDICATE row: `models.conf` has no ADJUDICATE row.
- `dispatch`: 201 passed, 4 failed - the four real-tree assertions: `row_problems` (2 lines: the AC-10 clause, `rules.md` ADJUDICATE), its AC-10 and `rules.md` line counts, and `adj_problems` (28 lines). The AC-9 counts are green (the sentences exist).
- `new-story`: 59 passed, 20 failed - every AC-8 needle over the generated template, `sections.md` and `story-authoring/SKILL.md`; the one precondition passes.

The FAIL lines, verbatim from the log (each assertion name, cut at 200 characters by `cut -c1-200`; the full text, with expected and actual, is in the log):

```
    FAIL HARNESS-102 AC-3: a new `### R-1` with no record, on a story the base has no copy of, gives exactly one FAIL naming the story, ## Regressions and R-1
    FAIL HARNESS-102 AC-3: and the run exits non-zero
    FAIL HARNESS-102 AC-3: two new ids with no record give one FAIL each: R-1 once, R-2 once
    FAIL HARNESS-102 AC-3: a new `### R-12` with no record gives one FAIL for R-12 and none for R-1
    FAIL HARNESS-102 AC-3: a new `- **AM-1` in ## Amendments with no record gives exactly one FAIL naming ## Amendments and AM-1
    FAIL HARNESS-102 AC-3: and the run exits non-zero
    FAIL HARNESS-102 AC-3: the head spelled `### R-1 (the count)` is an entry head: one FAIL for R-1
    FAIL HARNESS-102 AC-3: the head spelled `**R-1 (the count).**` is an entry head: one FAIL for R-1
    FAIL HARNESS-102 AC-3: the head spelled `- **R-1 (the count).**` is an entry head: one FAIL for R-1
    FAIL HARNESS-102 AC-3: the head spelled `   ### R-1 (indented three)` is an entry head: one FAIL for R-1
    FAIL HARNESS-102 AC-4: a new R-1 with its `- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2)` record prints the ## Regressions ok line
    FAIL HARNESS-102 AC-4: a new AM-1 with its record prints the ## Amendments ok line
    FAIL HARNESS-102 AC-4: the record inside an HTML comment: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record inside an HTML comment: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record on its own line inside a multi-line HTML comment: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record on its own line inside a multi-line HTML comment: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record inside a backtick-fenced block: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record inside a backtick-fenced block: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record inside a tilde-fenced block: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record inside a tilde-fenced block: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record names a different id (R-2): refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record names a different id (R-2): and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record names R-12, which is not R-1: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record names R-12, which is not R-1: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record sits in the other section (## Amendments): refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record sits in the other section (## Amendments): and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record names a model that is not opus, fable, sonnet or haiku: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record names a model that is not opus, fable, sonnet or haiku: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record has no (resolved <name>): refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record has no (resolved <name>): and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record's model is not backticked and it has no resolved name (PLANNED's own refused example): refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record's model is not backticked and it has no resolved name (PLANNED's own refused example): and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record's resolved name is empty: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record's resolved name is empty: and the run exits non-zero
    FAIL HARNESS-102 AC-4: the record words in the middle of a prose line, not at its start: refused, one FAIL for R-1
    FAIL HARNESS-102 AC-4: the record words in the middle of a prose line, not at its start: and the run exits non-zero
    FAIL HARNESS-102 AC-4: twin: a fence before the record does not swallow the record after it: the ok line
    FAIL HARNESS-102 AC-5: and the section, which has new content and no head outside them, is refused as headless
    FAIL HARNESS-102 AC-4: the same story with one entry head added and nothing else is refused: one FAIL for R-1 - the template's own comments do not discharge it
    FAIL HARNESS-102 AC-4: and the new R-2, recorded, gives the ok line
    FAIL HARNESS-102 AC-4: twin: the new R-2 without its record is refused, and the old R-1 still is not judged
    FAIL HARNESS-102 AC-5: new ## Regressions content with no entry head gives one FAIL naming ## Regressions and the head `R-<n>`
    FAIL HARNESS-102 AC-5: and the run exits non-zero
    FAIL HARNESS-102 AC-5: new ## Amendments content with no entry head gives one FAIL naming ## Amendments and the head `AM-<n>`
    FAIL HARNESS-102 AC-5: and the run exits non-zero
    FAIL HARNESS-102 AC-5: `### Return 1` is not an entry head: the headless FAIL
    FAIL HARNESS-102 AC-5: an `AM-1` head in ## Regressions is not a Regressions head: the headless FAIL, and no FAIL for AM-1
    FAIL HARNESS-102 AC-6: a record naming `sonnet` where the ADJUDICATE row plans `fable` is accepted: the ok line
    FAIL HARNESS-102 AC-6: and one note line naming R-1, the model recorded (sonnet) and the model planned (fable)
    FAIL HARNESS-102 AC-6: a `fable` record where the row plans `opus` gives the note naming R-1, fable and opus
    FAIL HARNESS-102 AC-7: `**Adjudicated AM-1:** requested by the user` is accepted for an amendment: the ok line
    FAIL HARNESS-102 AC-7: the same words for an R- entry in ## Regressions are refused: one FAIL for R-1
    FAIL HARNESS-102 AC-7: and the run exits non-zero
    FAIL HARNESS-102 C-9: HARNESS-089's own ## Regressions and ## Amendments, verbatim, are refused: one FAIL for R-1, one for AM-1, no headless FAIL, non-zero
    FAIL HARNESS-102 C-9: HARNESS-095's own ## Regressions and ## Amendments, verbatim, are refused: one FAIL for R-1, one for AM-1, no headless FAIL, non-zero
    FAIL HARNESS-102 C-9: HARNESS-099's own ## Regressions and ## Amendments, verbatim, are refused: one FAIL for R-1, one for AM-1, no headless FAIL, non-zero
    FAIL HARNESS-101: row_problems over the real tree prints nothing: advance-story's PLANNED → RED dispatches a lead-po on the PLANNED row; GATES → REVIEW step 1 dispatches a lead-po on the DIFF-
    FAIL HARNESS-102 AC-10: advance-story's REVIEW → DONE region, over the real tree, says the PR-feedback dispatch's model comes from plan.sh unless `## Model guidance` `records a departure for tha
    FAIL HARNESS-102 AC-1: rules.md's # The model each agent runs on, over the real tree, names ADJUDICATE among the fable rows
    FAIL HARNESS-102 AC-1: adj_problems over the real tree prints nothing: advance-story, complete-story and lead-po.md each say a fresh lead-po on the ADJUDICATE row adjudicates the claim, upheld or 
    FAIL HARNESS-102 AC-8: the template's ## Amendments comment names the entry head `AM-<n>`
    FAIL HARNESS-102 AC-8: the template's ## Amendments comment shows the record line `**Adjudicated AM-<n>:**`
    FAIL HARNESS-102 AC-8: the template's ## Amendments record line carries `(resolved <name>)`
    FAIL HARNESS-102 AC-8: the template's ## Amendments comment says a `fable` dispatch writes the judgement
    FAIL HARNESS-102 AC-8: the template's ## Amendments comment says the dispatch is a fresh one
    FAIL HARNESS-102 AC-8: the template's ## Regressions comment names the entry head `R-<n>`
    FAIL HARNESS-102 AC-8: the template's ## Regressions comment shows the record line `**Adjudicated R-<n>:**`
    FAIL HARNESS-102 AC-8: the template's ## Regressions record line carries `(resolved <name>)`
    FAIL HARNESS-102 AC-8: the template's ## Regressions comment says a `fable` dispatch writes the judgement
    FAIL HARNESS-102 AC-8: the template's ## Regressions comment says the dispatch is a fresh one
    FAIL HARNESS-102 AC-8: the template's ## Amendments comment no longer asks for the orchestrator's own reproduction
    FAIL HARNESS-102 AC-8: story-authoring's sections.md ## Amendments names the entry head `AM-<n>`
    FAIL HARNESS-102 AC-8: story-authoring's sections.md ## Amendments shows the record line `**Adjudicated AM-<n>:**`
    FAIL HARNESS-102 AC-8: story-authoring's sections.md ## Amendments says a `fable` dispatch writes the judgement
    FAIL HARNESS-102 AC-8: story-authoring's sections.md ## Regressions names the entry head `R-<n>`
    FAIL HARNESS-102 AC-8: story-authoring's sections.md ## Regressions shows the record line `**Adjudicated R-<n>:**`
    FAIL HARNESS-102 AC-8: story-authoring's sections.md ## Regressions says a `fable` dispatch writes the judgement
    FAIL HARNESS-102 AC-8: story-authoring's SKILL.md no longer says the orchestrator reproduces the finding itself
    FAIL HARNESS-102 AC-8: story-authoring's SKILL.md says the finding is adjudicated by a `fable` dispatch
    FAIL HARNESS-102 AC-8: story-authoring's SKILL.md names the ADJUDICATE row
    FAIL an ordinary story: fable plans and reviews, opus writes and tests the code
    FAIL with no contract, the plan is the same
    FAIL with a contract the lock cannot police, the plan is the same
    FAIL for a bootstrap story, the plan is the same
    FAIL HARNESS-101 AC-2, HARNESS-102 AC-2: the plan lists DIFF-REVIEW after GATES and before REVIEW, and ADJUDICATE last, after SCAFFOLD, the other six in today's order, for all four story shapes
    FAIL HARNESS-102 C-6: plan.sh write puts exactly one `| ADJUDICATE | `lead-po` | `fable` | <why> |` row in ## Model guidance, with a reason
```

The two real-tree aggregates, in full (dispatch):

```
    FAIL HARNESS-101: row_problems over the real tree prints nothing: advance-story's PLANNED → RED dispatches a lead- ...
         expected: 
         actual:   .claude/commands/advance-story.md: REVIEW → DONE does not say `records a departure for that row`
         .claude/harness/rules.md: # The model each agent runs on does not say `ADJUDICATE`
    FAIL HARNESS-102 AC-1: adj_problems over the real tree prints nothing: advance-story, complete-story and lead-po.md  ...
         expected: 
         actual:   .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `lead-po`
         .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `ADJUDICATE row`
         .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `upheld`
         .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `rejected`
         .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `**Adjudicated`
         .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `## Notes`
         .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `AMEND`
         .claude/commands/advance-story.md: its contract-is-wrong bullet still says `you reproduce independently`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `lead-po`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `ADJUDICATE row`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `upheld`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `rejected`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `**Adjudicated`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `## Notes`
         .claude/commands/complete-story.md: its contract-is-wrong bullet does not say `AMEND`
         .claude/commands/complete-story.md: its contract-is-wrong bullet still says `verify it yourself`
         .claude/agents/lead-po.md: its description does not say `ADJUDICATE`
         .claude/agents/lead-po.md: ## When you are dispatched inside a story does not say `ADJUDICATE row`
         .claude/agents/lead-po.md: ## When you are dispatched inside a story still says `Three pieces of work`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `lead-po`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `ADJUDICATE row`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `upheld`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `rejected`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `**Adjudicated`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `## Notes`
         .claude/agents/lead-po.md: its contract-is-wrong bullet does not say `AMEND`
         .claude/agents/lead-po.md: its contract-is-wrong bullet still says `reproduce it on different inputs`
         .claude/skills/diff-review/SKILL.md: ## 5. What happens to a finding does not say `**Adjudicated`
```

One `boundaries` refusal in full, for the shape (block 3k does not exist, so the run prints no 3k line and the spike exits 0):

```
    FAIL HARNESS-102 AC-3: a new `### R-1` with no record, on a story the base has no copy of, gives exactly one FAIL naming the story, ## Regressions and R-1 ...
         expected: 1
         actual:   0
    FAIL HARNESS-102 AC-3: and the run exits non-zero
         expected: non-zero
```

### Files touched

- `.claude/tests/boundaries.test.sh` - the block 3k describe (AC-3 to AC-7,
  C-9), appended before `summary`; the HARNESS-097 T-43 fixture (the one caller,
  below).
- `.claude/tests/plan.test.sh` - `SHIP_EXPECTED` gains the ADJUDICATE row,
  `SHIP_ORDER` ends `ADJUDICATE`, one `plan.sh write` row assertion (AC-2, C-6).
- `.claude/tests/dispatch.test.sh` - `row_problems` gains AC-9 and AC-10 and
  the `rules.md` ADJUDICATE needle; a new guard `adj_problems` for the rest of
  AC-1.
- `.claude/tests/new-story.test.sh` - the AC-8 block.
- `docs/backlog/stories/HARNESS-102.md` - `## Contract` C-7 amended in place
  (four needles and the locator, with the reason), `## Test plan`, this section.

Nothing else. Floors are not raised (GREEN's, C-9 / "Floors and release").

### What GREEN builds, as the tests already pin it

**Block 3k in `scripts/check-boundaries.sh`.** The tests run the real script in
a fixture and read its output; there is no function to import. What they read:

| Needle | Exact form | Where pinned |
|---|---|---|
| a missing record | one line beginning `FAIL  ` that contains the story id, `## <Section>` and `**Adjudicated <id>:**` (C-4: the problem spells the record line out, so the id appears inside its own record). One such line per id; the exit is non-zero | `k_fail` |
| headless new content | one line beginning `FAIL  ` with the story id, `## <Section>` and the literal `R-<n>` (Regressions) or `AM-<n>` (Amendments); non-zero exit | `k_headless` |
| accepted | the whole line `ok    ## Regressions: every new entry carries an adjudication record` (or `## Amendments`), exactly once (C-4 step 6) | `k_ok` |
| AC-6 note | one line beginning with two spaces (`note`'s prefix) that contains the id, the recorded model and the planned model | `k_note` |
| "no adjudication line at all" | no line matching `/adjudicat/` in any case, nor containing `R-<n>` or `AM-<n>` | `k_adj` |
| "no FAIL about adjudication" | the same, among lines beginning `FAIL  ` | `k_adj_fail` |

So: every 3k `problem` and `ok` should carry the word "adjudication" or the
head form, and **no other line of the script may** - an unrelated message that
says "adjudicated" would break the "says nothing" cases. Every 3k fixture is a
`spike` at REVIEW that changes no source, so its exit status is 3k's alone: an
accepted case asserts exit 0.

The planned model for AC-6 is read from `.claude/harness/models.conf` in the
directory the script runs in (the fixture writes it per case: the shipped file
with any ADJUDICATE row replaced by `model  | ADJUDICATE | lead-po | <m> | ...`,
or without one, or deleted).

Not constrained: the rest of each message's wording, the order of 3k's lines
relative to each other, what a FAIL says beyond the needles, how the block is
factored, and whether the base copy is read once or per section (C-3 still says
through `$cp`).

**`dispatch.test.sh` needles.** `row_problems` lines GREEN must clear, verbatim:

    .claude/commands/advance-story.md: REVIEW → DONE does not say `records a departure for that row`
    .claude/harness/rules.md: # The model each agent runs on does not say `ADJUDICATE`

and `adj_problems` (new) prints today the 28 lines in the failure output
above. To clear them: each of the three bullets that begin
`- **A claim that the contract` (keep those words; the bullet runs to the next
`- ` line, blank line or heading) says `lead-po`, `ADJUDICATE row`, `upheld`,
`rejected`, `**Adjudicated`, `## Notes` and `AMEND`, and loses
`you reproduce independently` (advance-story), `verify it yourself`
(complete-story), `reproduce it on different inputs` (lead-po). `lead-po.md`'s
`description:` says `PLANNED`, `DIFF-REVIEW` and `ADJUDICATE`; its
`## When you are dispatched inside a story` says `ADJUDICATE row` and not
`Three pieces of work`. `diff-review/SKILL.md`'s `## 5. What happens to a
finding` says `**Adjudicated`. Needles are matched after flattening, so a
phrase may wrap. The two headings are matched as whole lines: do not rename
them. C-7 (amended in RED) has the reason for the four extra needles.

The `REVIEW → DONE` region is the HARNESS-101 one (from `**REVIEW → DONE.**` to
the next paragraph that begins `**`); the clause goes in the PR-feedback
paragraph. GATES → REVIEW step 1 saying it does not count (fixture case).

**AC-9's choice (C-10).** The complete-story check prints a **second** line,
`.claude/commands/complete-story.md: its PLANNED → RED dispatch bullet does not say \`before you commit at PLANNED\``,
only when a dispatch bullet (one saying both `lead-po` and `PLANNED row`)
exists and none of them has the phrase; with no dispatch bullet the existing
`L_CB_PL` line stands alone. `pl_region` reaches `advance-story.md:115-116`:
the region runs from line 43 (`**PLANNED → RED.**`) to the next marker at line
168 (`**RED → GREEN.**`), and the C-10 mutation below shows the sentence is
read.

**`plan.test.sh`.** `plan.sh models <id>` prints eight rows, the eighth
`ADJUDICATE lead-po fable`, last; `plan.sh write` renders
`| ADJUDICATE | \`lead-po\` | \`fable\` | <why> |` once with a non-blank reason.
Not constrained: the `<why>` text, and the header comment (C-6 says to change
it; no assertion reads it - `MC_NEEDLES` is unchanged).

**`new-story.test.sh`.** Each of the two template comments contains, after
whitespace is collapsed: `AM-<n>` / `R-<n>`, `**Adjudicated AM-<n>:**` /
`**Adjudicated R-<n>:**`, `(resolved <name>)`, `fable`, `fresh`; the Amendments
one no longer contains "orchestrator's own reproduction" in any case.
`sections.md`'s `## Amendments ...` and `## Regressions ...` sections contain
the head, `**Adjudicated <p>-<n>:**` and `fable`. `story-authoring/SKILL.md`'s
paragraph beginning `If the Test Developer reports that a criterion` (to the
next blank line) keeps those opening words, loses "after the orchestrator has
reproduced the finding independently, on its own inputs", and says `fable`
and `ADJUDICATE`. Not constrained: the rest of the wording.

### The caller list (Contract, "Callers")

`grep -n '## Regressions\|## Amendments' .claude/tests/boundaries.test.sh`
gave the 36 lines the contract counted, before this story's block. Read case
by case, and then measured: a candidate 3k (written in a scratch copy of the
tree, never in `scripts/`, from C-1 to C-4) appended to a copy of
`check-boundaries.sh` and the unchanged suite run against it gave
`boundaries: 544 passed, 1 failed`. The one:

- **HARNESS-097, "AC-1 twin: with the plain file gone, the same fixture exits
  0"** (story T-43). Its `## Amendments` entry has no head, so 3k adds an AC-5
  FAIL and the twin exits 1 for 3k's reason. **Updated**: the entry is headed
  `- **AM-1.**` and carries `- **Adjudicated AM-1:** requested by the user,
  2026-11-11.`; 3d reads only that the section has content, so every other
  assertion of that case is unchanged. Green today and green against the
  candidate.

Every other case on those 36 lines gains a line under 3k and still passes:
they match a substring (`refused`, `assert_contains`, `assert_not_contains` of
a 3d or 3g phrase, `whole_line` of a 3d/3g line) and their fixtures are
`feature` stories at REVIEW with no `## Gate results`, which already exit 1.
The two "says nothing about `## Regressions`" cases (an absent section, an
untouched template block) have no content outside comments, so 3k is silent
there by C-4 step 1.

### "Existing assertions these edits meet", checked against the tree

- `plan.test.sh` `SHIP_EXPECTED` / `SHIP_ORDER`: changed here, with AC-2.
- `dispatch.test.sh` HARNESS-101 block: `RU_NEEDLES` gains `ADJUDICATE`, and
  the compliant `R_RU_GOOD` and both sections around it in `write_r_rules`
  carry it; `RD_NEEDLES` gains the departure clause and `R_RD_GOOD` and
  `R_AFTER` carry it; `PL_ADV_NEEDLES` and `CB_PL_READ` are new and `R_PL_GOOD`,
  `R_RG`, `R_CB_PL_GOOD` and `write_r_complete`'s trailing line carry them.
  "the fixture: compliant by construction" is green with all of them. The
  controls that print today's lines were extended by the new lines (pl-today
  3, pl-after-marker 3, rd-today 4, rd-bold-paragraph 5, the HARNESS-101
  whole-tree case 34). `RU_NOT` still refuses `PLANNED and REVIEW on`;
  `MC_NEEDLES`/`MC_NOT` and `LP_NEEDLES` are unchanged.
- `rules-trim`, `sigpipe`, `procedure`, and `new-story.test.sh` lines 139-148:
  not edited, and nothing here reads them differently. `rules.md` is **370
  lines at the cap** (`wc -l`, `CAP=370` in `rules-trim.test.sh`): GREEN's three
  edits there are word-level and must leave it at 370 or fewer (C-7).
  `sigpipe.test.sh` pins `check-boundaries.sh:399`, `:438` and `:630` - block
  3k goes after 3j, before the last line, so none moves (C-4).
- `bash scripts/selftest-needed.sh --suites` on the branch is the full list for
  the final self-test.

### Green on arrival, and what earns each (DV-3)

**AC-9, earned in RED** by the two C-10 mutations, each against the one
suite. Before them the suite stood at `dispatch: 201 passed, 4 failed`; under
each, exactly one more assertion went red - the one the mutation targets - and
`mutate.sh` restored the file byte for byte. Output, the 28 lines of the
already-red AC-1 real-tree assertion elided where marked:

C-10 mutation 1, `bash scripts/mutate.sh .claude/commands/advance-story.md 's/read what it$/skim what it/' -- bash scripts/selftest.sh dispatch` (blank lines removed):

```
=== mutate: .claude/commands/advance-story.md (1 line(s) changed by s/read what it$/skim what it/) ===
  115 - That is the end of the brief. Once the dispatch is back, read what it
  115 + That is the end of the brief. Once the dispatch is back, skim what it
=== mutate: running bash scripts/selftest.sh dispatch ===
=== dispatch ===
  the real tree (AC-1 to AC-5)
  the fixture: compliant by construction
  AC-1: the GREEN → GATES region dispatches the full gate run
  AC-2: the self-test step dispatches the run and checks its verdict
  AC-3: check-boundaries stays the orchestrator's own run, after the commit
  AC-4: complete-story's bullet and lead-po's ## Orchestrating
  AC-5: feature-developer.md has ## Run and report
  missing files, and the order of the lines
  HARNESS-095 AC-4: the self-test step names the `--changed` run, and the full-run spelling does not
  HARNESS-095 AC-3: complete-story's bullet and lead-po's long-run paragraph name the `--changed` run and its check
  HARNESS-095 AC-4: the lines the tree at HARNESS-094 prints, in order
  HARNESS-101 the real tree: who is dispatched on which row (AC-3, AC-4, AC-6, AC-7)
    FAIL HARNESS-101: row_problems over the real tree prints nothing: advance-story's PLANNED → RED dispatches a lead-po on the PLANNED row; GATES → REVIEW step 1 dispatches a lead-po on the DIFF-REVIEW row, read from `bash scripts/plan.sh models`, with a Route checked by `bash scripts/classify.sh`, and not on the GATES row; REVIEW → DONE has PR feedback read by a lead-po on the REVIEW row with a Route; complete-story's bullets say the same; diff-review's description and ## Who runs it name the lead-po on the DIFF-REVIEW row and no feature-developer; rules.md's model section states the 2026-11-11 split; models.conf's header names DIFF-REVIEW; lead-po.md names the DIFF-REVIEW row; and (HARNESS-102) advance-story's PLANNED → RED says `read what it returned`, complete-story's dispatch bullet says `before you commit at PLANNED`, the PR-feedback paragraph `records a departure for that row`, and rules.md's model section names ADJUDICATE
         expected: 
         actual:   .claude/commands/advance-story.md: PLANNED → RED does not say `read what it returned`
         .claude/commands/advance-story.md: REVIEW → DONE does not say `records a departure for that row`
         .claude/harness/rules.md: # The model each agent runs on does not say `ADJUDICATE`
    FAIL HARNESS-102 AC-9: advance-story's PLANNED → RED region, over the real tree, says `read what it returned` (HARNESS-101 AC-3's read-before-commit sentence)
         expected: 0
         actual:   1
    FAIL HARNESS-102 AC-10: advance-story's REVIEW → DONE region, over the real tree, says the PR-feedback dispatch's model comes from plan.sh unless `## Model guidance` `records a departure for that row`
         expected: 0
         actual:   1
    FAIL HARNESS-102 AC-1: rules.md's # The model each agent runs on, over the real tree, names ADJUDICATE among the fable rows
         expected: 0
         actual:   1
  HARNESS-101 the fixture: compliant by construction
  HARNESS-101 AC-3: advance-story's PLANNED → RED is a lead-po dispatch on the PLANNED row
  HARNESS-101 AC-4: GATES → REVIEW step 1 is a lead-po dispatch on the DIFF-REVIEW row
  HARNESS-101 AC-6: PR feedback at REVIEW is read by a lead-po on the REVIEW row
  HARNESS-101 AC-3, AC-4: complete-story's PLANNED → RED and GATES → REVIEW bullets
  HARNESS-101 AC-4: diff-review's description and ## Who runs it
  HARNESS-101 AC-7: rules.md, models.conf's header and lead-po.md state the split
  HARNESS-101: missing files, and every line a tree at 9a10054 prints, in order
  HARNESS-102 AC-1 the real tree: a contract-is-wrong claim goes to a fresh lead-po on the ADJUDICATE row
    FAIL HARNESS-102 AC-1: adj_problems over the real tree prints nothing: advance-story, complete-story and lead-po.md each say a fresh lead-po on the ADJUDICATE row adjudicates the claim, upheld or rejected, with the record (`**Adjudicated`) in the entry, a rejected claim in ## Notes, and a Route'd RED or AMEND entry adjudicated by that dispatch, and none tells the orchestrator to reproduce it itself; lead-po.md's dispatch section and description name the ADJUDICATE row; diff-review's section 5 says a Route'd entry carries a `**Adjudicated` record
         expected: 
         actual:   .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `lead-po`
         [... the rest of the 28 AC-1 real-tree lines elided ...]
         .claude/skills/diff-review/SKILL.md: ## 5. What happens to a finding does not say `**Adjudicated`
  HARNESS-102 AC-1 the fixture: compliant by construction, and today's words
  HARNESS-102 AC-1: each of the three statements, one clause at a time
  HARNESS-102 AC-1: lead-po.md's dispatch section and description, diff-review's section 5
dispatch: 200 passed, 5 failed
assertion floors: all 1 suite(s) met their declared floor (200 assertions executed, 145 declared).
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261111T220732Z.119391.bak) ===
  115: That is the end of the brief. Once the dispatch is back, read what it
```

C-10 mutation 2, `bash scripts/mutate.sh .claude/commands/complete-story.md 's/before you commit at PLANNED/before you move on/' -- bash scripts/selftest.sh dispatch` (blank lines removed):

```
=== mutate: .claude/commands/complete-story.md (1 line(s) changed by s/before you commit at PLANNED/before you move on/) ===
  97 -   and record the model it resolved to, before you commit at PLANNED.
  97 +   and record the model it resolved to, before you move on.
=== mutate: running bash scripts/selftest.sh dispatch ===
=== dispatch ===
  the real tree (AC-1 to AC-5)
  the fixture: compliant by construction
  AC-1: the GREEN → GATES region dispatches the full gate run
  AC-2: the self-test step dispatches the run and checks its verdict
  AC-3: check-boundaries stays the orchestrator's own run, after the commit
  AC-4: complete-story's bullet and lead-po's ## Orchestrating
  AC-5: feature-developer.md has ## Run and report
  missing files, and the order of the lines
  HARNESS-095 AC-4: the self-test step names the `--changed` run, and the full-run spelling does not
  HARNESS-095 AC-3: complete-story's bullet and lead-po's long-run paragraph name the `--changed` run and its check
  HARNESS-095 AC-4: the lines the tree at HARNESS-094 prints, in order
  HARNESS-101 the real tree: who is dispatched on which row (AC-3, AC-4, AC-6, AC-7)
    FAIL HARNESS-101: row_problems over the real tree prints nothing: advance-story's PLANNED → RED dispatches a lead-po on the PLANNED row; GATES → REVIEW step 1 dispatches a lead-po on the DIFF-REVIEW row, read from `bash scripts/plan.sh models`, with a Route checked by `bash scripts/classify.sh`, and not on the GATES row; REVIEW → DONE has PR feedback read by a lead-po on the REVIEW row with a Route; complete-story's bullets say the same; diff-review's description and ## Who runs it name the lead-po on the DIFF-REVIEW row and no feature-developer; rules.md's model section states the 2026-11-11 split; models.conf's header names DIFF-REVIEW; lead-po.md names the DIFF-REVIEW row; and (HARNESS-102) advance-story's PLANNED → RED says `read what it returned`, complete-story's dispatch bullet says `before you commit at PLANNED`, the PR-feedback paragraph `records a departure for that row`, and rules.md's model section names ADJUDICATE
         expected: 
         actual:   .claude/commands/advance-story.md: REVIEW → DONE does not say `records a departure for that row`
         .claude/commands/complete-story.md: its PLANNED → RED dispatch bullet does not say `before you commit at PLANNED`
         .claude/harness/rules.md: # The model each agent runs on does not say `ADJUDICATE`
    FAIL HARNESS-102 AC-9: complete-story's PLANNED → RED dispatch bullet, over the real tree, names `lead-po` and `PLANNED row` and says `before you commit at PLANNED`
         expected: 0 0
         actual:   0 1
    FAIL HARNESS-102 AC-10: advance-story's REVIEW → DONE region, over the real tree, says the PR-feedback dispatch's model comes from plan.sh unless `## Model guidance` `records a departure for that row`
         expected: 0
         actual:   1
    FAIL HARNESS-102 AC-1: rules.md's # The model each agent runs on, over the real tree, names ADJUDICATE among the fable rows
         expected: 0
         actual:   1
  HARNESS-101 the fixture: compliant by construction
  HARNESS-101 AC-3: advance-story's PLANNED → RED is a lead-po dispatch on the PLANNED row
  HARNESS-101 AC-4: GATES → REVIEW step 1 is a lead-po dispatch on the DIFF-REVIEW row
  HARNESS-101 AC-6: PR feedback at REVIEW is read by a lead-po on the REVIEW row
  HARNESS-101 AC-3, AC-4: complete-story's PLANNED → RED and GATES → REVIEW bullets
  HARNESS-101 AC-4: diff-review's description and ## Who runs it
  HARNESS-101 AC-7: rules.md, models.conf's header and lead-po.md state the split
  HARNESS-101: missing files, and every line a tree at 9a10054 prints, in order
  HARNESS-102 AC-1 the real tree: a contract-is-wrong claim goes to a fresh lead-po on the ADJUDICATE row
    FAIL HARNESS-102 AC-1: adj_problems over the real tree prints nothing: advance-story, complete-story and lead-po.md each say a fresh lead-po on the ADJUDICATE row adjudicates the claim, upheld or rejected, with the record (`**Adjudicated`) in the entry, a rejected claim in ## Notes, and a Route'd RED or AMEND entry adjudicated by that dispatch, and none tells the orchestrator to reproduce it itself; lead-po.md's dispatch section and description name the ADJUDICATE row; diff-review's section 5 says a Route'd entry carries a `**Adjudicated` record
         expected: 
         actual:   .claude/commands/advance-story.md: its contract-is-wrong bullet does not say `lead-po`
         [... the rest of the 28 AC-1 real-tree lines elided ...]
         .claude/skills/diff-review/SKILL.md: ## 5. What happens to a finding does not say `**Adjudicated`
  HARNESS-102 AC-1 the fixture: compliant by construction, and today's words
  HARNESS-102 AC-1: each of the three statements, one clause at a time
  HARNESS-102 AC-1: lead-po.md's dispatch section and description, diff-review's section 5
dispatch: 200 passed, 5 failed
assertion floors: all 1 suite(s) met their declared floor (200 assertions executed, 145 declared).
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_complete-story.md.20261111T220903Z.122218.bak) ===
  97:   and record the model it resolved to, before you commit at PLANNED.
```

**Listed for GATES (DV-3), not run in RED** - the block they need to break does
not exist. Each is green today because there is no block 3k at all:

| Assertion (boundaries, block 3k) | The mutation of the built 3k that turns it red |
|---|---|
| AC-3 "no ok line for ## Regressions beside the FAIL" | print the `ok` whatever step 4 found |
| AC-4 "and no FAIL about adjudication" / "the spike exits 0" (R-1), "two ids ... exit 0", AM-1 "no FAIL ..., exit 0", AC-6 "no FAIL ..., exit 0", AC-7 "no FAIL ..., exit 0" | make the record never match (e.g. `Adjudicated` -> `Adjudicatd` in the C-2 pattern) |
| AC-4 "a head inside a fence or a comment is not an entry head" | read heads from the section without skipping fenced lines (R-1 is then a head) |
| AC-4 "a story fresh from new-story.sh, untouched, gets no adjudication line" | judge the section without stripping comments (the template's `R-<n>` text is then content) |
| AC-4 "an R-1 the base copy already has is not judged", "the spike exits 0", "prose added under an id the base already has", "a section identical to the base copy's says nothing" | take the base id set as empty |
| AC-5 twin "the same headless content already on the base is not new" | drop C-4 step 2 (the comparison with the base copy) |
| AC-4 "two sections holding only comments get no adjudication line" | test the raw section for non-whitespace instead of `has_content` |
| AC-4 "a story with neither section gets no adjudication line" | print each section's `ok` unconditionally (DV-3's own example) |
| AC-6 twin "a fable record where the row plans fable gives no note" | note when the models are equal (`!=` -> `=`) |
| AC-6 "no ADJUDICATE row: no note", "no models.conf: no note" | default the planned model to `fable` when there is no row |
| AC-4 "precondition: new-story.sh wrote a story with a branch and a ## Regressions heading" | a fixture precondition, not a behaviour; remove the heading from `new-story.sh` and it goes red |

In `new-story`, "story-authoring's SKILL.md still has the paragraph that opens
..." is green on arrival: it is the region's precondition, and renaming the
paragraph's opening words turns it red. In `dispatch`, every fixture case is
green on arrival by design (they test the guard, not the tree); the "today's
words" controls, which print every line, are what show the guard reading the
real wording.

### Deferred verifications

- **DV-1 (the defect put back): declined in RED - I cannot run it.** It
  disables block 3k's refusal for a new id without a record, and there is no
  block 3k to disable. GATES owns it, with the expression written against
  GREEN's line; the assertion it must turn red is AC-3's
  "a new `### R-1` with no record ... gives exactly one FAIL ...".
- **DV-2 (a real line of the tree): declined in RED - I cannot run it.** It
  needs the block to print a FAIL naming `R-9` over this story's own file, and
  the block does not exist. GATES owns it; the command is in the entry.
- **DV-3**: listed above, mutation by mutation, for GATES. AC-9's two are not
  in it: earned here.

### Floors, for GREEN to raise (C-9, "Floors and release")

Executed in RED (passed + failed): `boundaries` 621 (545 + 76), `plan` 287
(286 + 1), `dispatch` 205 (145 at b10546e + 60), `new-story` 79 (58 + 21). The
floor counts passes, so once green each should pass that many; GREEN records
the counts it measures, in `floors.conf` and `selftest.test.sh` both.

### Expected values of the controls

Every control below ran in RED, because no suite failed to load. The 3k
column is a claim about GREEN's block: it was measured against a **candidate**
3k in a scratch copy, so GREEN confirms each against the shipped block.

| Control | Expected | Measured in RED (no 3k) | Measured, candidate 3k |
|---|---|---|---|
| block 3k describe in `boundaries` | 76 assertions, 0 failed | 20 passed, 56 failed | 76 passed, 0 failed |
| the rest of `boundaries` (unchanged cases) | all green | all green | 544 of 545 before the T-43 update; the T-43 twin is the only one |
| `dispatch` "the fixture: compliant by construction" (HARNESS-101 and HARNESS-102) | silent | silent | - |
| `dispatch` today's words, `adj_problems` | 28 lines | 28 lines (= the real tree's output) | - |
| `dispatch` today's words, `row_problems` | 34 lines | 34 | - |
| `dispatch` real tree, `row_problems` | 2 lines in RED, 0 after GREEN | 2 | - |
| `dispatch` real tree, `adj_problems` | 28 lines in RED, 0 after GREEN | 28 | - |
| C-10 mutation 1 / 2 | one more red, the AC-9 assertion it targets | 200 passed, 5 failed (from 201/4), each | - |
| C-1 heads over the real stories, fence skipping on or off | HARNESS-089 R-1 AM-1; -094 R-1 R-2 AM-1 AM-2; -095 R-1 AM-1; -099 R-1 AM-1; -100 R-1; -101, -082 none | identical with fences skipped (any indent or column 0) and not skipped, over every story in `docs/backlog/stories` | - |

The last row answers the contract's question: no real entry is lost to fence
skipping. Over every story file, the C-1 ids with fenced lines skipped and
without are the same set (HARNESS-008, -014, -015, -060, -087, -089, -090,
-091, -094, -095, -099, -100 carry ids).

### Discovered, for GREEN

- **The C-1 pattern needs an awk with interval expressions** (`{0,3}`,
  `{3,6}`). Git Bash's gawk has them; so does any POSIX awk, but mawk before
  1.3.4 does not. The candidate wrote `([*][*])?` for `(\*\*)?` because gawk
  warns on `\*` inside a string regex; either works as a dynamic regex only if
  written that way.
- **A fixture's `docs/backlog/stories` disappears** on `git checkout main` in
  the boundaries fixture once main holds no story files - the suite's block
  makes the directory before writing. Not a GREEN concern; noted for whoever
  extends the block.
- The real `pl_region` and `para_region` already reach the sentences AC-9 and
  AC-10 name; no region code changed.

### The record

The test command, through attest (the record's own lines):

    command:  bash scripts/selftest.sh boundaries plan dispatch new-story
    tree:     5a3895695a53c66f4eb9eff66620aab70567b148
    status:   ok
    exit:     1
    duration: 1938s
    last:     4 of 4 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261111T221223Z.127173.log

`plan`'s floor line in that log, `FAIL plan  did 281 units of work, below the
floor of 286`, is the six red assertions (the floor counts passes); 287 run.
No suite fails to load: the log has no `unbound variable`, `No such file`,
`syntax error` or `command not found`.

The fast gates, through attest:

    command:  bash scripts/gates.sh --fast
    tree:     5a3895695a53c66f4eb9eff66620aab70567b148
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261111T224458Z.209967.log

That is the shape this repository gives: every gate is unconfigured here
(`required_gates: []`), so the suites above are what judge the story, under
their floors. Also run, clean: `bash scripts/check-sigpipe.sh` (0 findings over
62 files), `bash scripts/check-grep-count.sh` (0 findings), and the two suites
`selftest-needed.sh --suites` adds for a scanned `*.sh`, `grep-count` 38/0 and
`host-load` 72/0; `sigpipe` 91/0.

Timings: every duration above is a local run on a loaded host (two other test
runs and another project's `gates.sh` were running). None of the new cases
carries a timeout; the suites have none.

### Return 1 (from GATES)

Diff review 1 sent the story back for findings 1 and 4 (`## Diff review`;
`## Regressions` R-1 and R-2 hold the reason and the watched red). RED added
tests only, to `.claude/tests/boundaries.test.sh`, after the C-9 cases and
before the block's "Put main back" lines. Model: planned `opus`, resolved
claude-opus-5-5, no override.

**Command.** `bash scripts/selftest.sh boundaries`. Through attest:

    command:  bash scripts/selftest.sh boundaries
    tree:     0e98042125533e15515117b41d07fc6aa18190a2
    exit:     1
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261112T180754Z.11317.log

    command:  bash scripts/gates.sh --fast
    tree:     0e98042125533e15515117b41d07fc6aa18190a2
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261112T185523Z.127672.log

**Counts.** Now: `boundaries: 632 passed, 20 failed` (652 executed; floor 621
met). The 20 are exactly the new assertions listed in `## Regressions`; no
other assertion fails. 31 assertions are new: 20 red, 11 green on arrival
(below). After GREEN: **652 passed, 0 failed**, and GREEN raises the
`boundaries` floor to the passed count it measures (652 if nothing else moves)
in `floors.conf` and `selftest.test.sh`. RED did not touch either.

**The new assertions, and what each pins.**

| Assertion (prefix `HARNESS-102 R-1:` / `R-2:`) | Pins | Red now |
|---|---|---|
| comment opener quoted in inline code, then new R-2 unrecorded: exactly one FAIL, unreadable / exits non-zero / no ok line | C-4 step 2a, comment case | 3 of 3 |
| opener between R-1 and its record: same three | step 2a stops the section: no missing-record FAIL for R-1 | 1 of 3 (the exit and no-ok already hold) |
| one-line fence, then new R-2 unrecorded: same three | step 2a, fence case | 3 of 3 |
| multi-line fence never closed, R-2 head after it: same three | step 2a, "ends inside a fence" | 3 of 3 |
| `## Amendments`, comment opener, then AM-2 unrecorded: same three | step 2a in the other section | 3 of 3 |
| `## Amendments`, one-line fence, then AM-2 unrecorded: same three | same | 3 of 3 |
| twin: no stray line, R-2 recorded: ok line / no unreadable, no FAIL, exit 0 | the control: removing the stray line is the whole difference | green |
| twin: opener quoted with its closer on the same line: same two | "unclosed" means unclosed | green |
| twin: a closed fence last in the section: same two | a balanced fence is readable | green |
| twin: `## Amendments` without the stray line, AM-2 recorded: same two | control for the AM cases | green |
| twin: unreadable section identical to the base copy: no unreadable, no adjudication line, exit 0 | step 2a comes after step 2 | green |
| R-2: wrapped line beginning `R-2 of HARNESS-094`: no FAIL for R-2 / the ok line / exit 0 | amended C-1: a head needs a prefix | 3 of 3 |
| R-2: in `## Amendments`, wrapped line beginning `AM-2 of`: no FAIL for AM-2, exit 0 | same | 1 of 1 |

**Needles GREEN's message must meet** (helpers `k_unreadable`, `k_fails`):
the line begins `FAIL  ` and contains the story id, `## Regressions` or
`## Amendments`, and the lowercase word `unreadable`; it is the only `FAIL`
line in the whole run for those fixtures. The rest of the wording is GREEN's,
under C-4's convention (say what is wrong and what to write). Not
constrained: how the scan reports it internally, where in the message the
word sits, whether the message names the line.

**Built against a candidate.** RED checked that the tests can be met without
touching any other case: a candidate fix applied with `scripts/mutate.sh`
(four sed lines: set a flag where `adj_scan` meets an opener with no closer;
print `unreadable` when that flag or `fence` is set at the end; after
`adj_scan "$adj_cur"`, `problem ...unreadable...` and `continue` when the scan
said so; the amended head regex, spelled without interval expressions as
`"^ ? ? ?((####?#?#? |- )([*][*])?|[*][*])" p`). Result: `boundaries: 652
passed, 0 failed`, the file restored and verified byte for byte. So the
caller list does not grow: no existing case in the suite gains or loses a line
under the fix. That candidate is a measurement, not the implementation; GREEN
writes its own and confirms the 652.

**Negative controls, expected values.** All ran in RED (the suite loads):

| Control | Expected after GREEN | Measured now, today's 3k | Measured, candidate 3k |
|---|---|---|---|
| the 9 twin assertions above | green | green | green |
| AC-3 head-spelling loop (`### R-1`, `**R-1`, `- **R-1`, indented `### R-1`): one FAIL for R-1 each | green | green | green |
| the 20 new red assertions | green | red | green |
| everything else in `boundaries` | green | 621 green | green |

**Also GREEN's, from the same review, not tested here:** findings 2 (the
`scripts/new-story.sh` Amendments and Regressions comments: the orchestrator
writes the record for an entry that follows a review finding routed `RED` or
`AMEND`) and 3 (one sentence in `advance-story.md`'s "Returning to RED from
GREEN or GATES" first bullet). See `## Diff review`, items 2 and 3, for the
fix text. `new-story.test.sh`'s needles are said to still hold after
finding 2; RED did not re-run that suite.

**Discovered.** A section whose unclosed opener comes before any other text
reads as having no content (step 1), so step 2a never sees it. AC-4 says a
section holding nothing outside comments gets no adjudication line, so RED
did not pin a FAIL there; C-4's amendment states it as a limit.
Comment stripping ignores fences, so a comment opener inside a fenced block
also counts as unclosed. The story's own `## Regressions` holds none (checked).

### Return 2 (from GATES)

Diff review 2 sent the story back for finding 1 (`## Diff review`, Review 2;
`## Regressions` R-3 holds the reason and the watched red). RED added tests
only, to `.claude/tests/boundaries.test.sh`, after the R-2 cases and before
the block's "Put main back" lines; the two R-1 helpers `k_unread_refused` and
`k_readable` gained an optional third argument, the name tag (default `R-1`,
so every R-1 name is byte-identical). Contract C-4 step 2a is amended in
place. Model: planned `opus`, resolved claude-opus-5-5, no override.

**Command.** `bash scripts/selftest.sh boundaries`. The attest records of it
and of `bash scripts/gates.sh --fast` were made on the final tree, after this
section was written, and are in the RED report to the orchestrator; the plain
run the red in R-3 was read from took 42 minutes on this host.

**Counts.** Now: `boundaries: 664 passed, 15 failed` (679 executed; floor 652
met). 27 assertions are new: 15 red, all listed in R-3, and 12 green on
arrival (the controls, below); no other assertion fails. After GREEN: **679
passed, 0 failed**, and GREEN raises the `boundaries` floor to the passed
count it measures (679 if nothing else moves) in `floors.conf` and
`selftest.test.sh`. RED did not touch either.

**The new assertions** (prefix `HARNESS-102 R-3:`).

| Fixture | Assertions | Red now |
|---|---|---|
| (a) one-line fence, new unrecorded R-2, one-line fence | exactly one FAIL, unreadable / exits non-zero / no ok line | 3 of 3 |
| (b) prose quoting the opener, R-2, prose quoting the closer | same three | 3 of 3 |
| (c) prose quoting the opener, R-2, an ordinary complete comment | same three | 3 of 3 |
| (d) `## Amendments`: AM-1 recorded, (a)'s pair around a new AM-2 | same three | 3 of 3 |
| (e) a closed fence holding a head-shaped line whose id is no head outside it | same three | 3 of 3 |
| twin (a), (b), (c), (d): the pair with only prose between, R-2/AM-2 recorded after it | ok line / no FAIL at all, exit 0 | green |
| twin (e): a closed fence holding a head-shaped line whose id IS a head outside | same two | green |
| twin: heads only inside a fence and a comment, none outside | the headless FAIL and no unreadable one | green |
| twin (f): this story's own `## Regressions`, verbatim at run time | no unreadable FAIL, the ok line | green |

**What GREEN builds** (C-4 step 2a as amended): in addition to the two
end-of-section tests, `unreadable` when the section has at least one head
outside comments and fences and a line matching C-1's head pattern was removed
with a comment or skipped inside a fence whose id is not one of those heads.
With no visible head at all, step 3's headless problem stays the refusal: the
AC-5 case "a head inside a fence or a comment" (`k_headless` = 1) and the new
twin pin that, and a hidden-head test placed before step 3 without the
condition would break both. The needles are return 1's: a line beginning
`FAIL  ` with the story id, `## <section>` and `unreadable`, the only FAIL in
the run. Not constrained: how `adj_scan` finds the hidden lines, the wording
beyond those needles.

**Built against a candidate, outside the suite.** Unlike return 1, the
candidate was not run through the whole suite (one run is 42 minutes here). A
scratch copy of `adj_scan` with two edits (before stripping, collect the ids of
every raw line matching the head pattern; at the end, print `unreadable` also
when one of those ids is not in `H` and `H` is non-empty) was run directly on
each new fixture body and on the R-1 bodies: `unreadable` for (a)-(e) and for
R-1's comment and one-line-fence cases; not for any twin; nothing at all for
the AC-5 body (headless, step 3); this section scans
`head R-1, rec R-1, head R-2, rec R-2, head R-3, rec R-3` under both today's
and the candidate scan. Over all 179 non-empty `## Regressions` and
`## Amendments` sections in `docs/backlog/stories/`, the candidate prints
`unreadable` for none. The rest of the run for these fixtures is today's,
which gives no FAIL for any of them (the red's `actual: 0 0`), so the one
problem step 2a adds is the only FAIL. GREEN's suite run is what confirms 679.

**Negative controls, expected values.**

| Control | Expected after GREEN | Measured now (suite) | Candidate (scan only) |
|---|---|---|---|
| the 12 R-3 twin assertions | green | green | no `unreadable` |
| return 1's 31 assertions (R-1 and R-2) | green | green | R-1's red bodies `unreadable`, its twins not |
| AC-5 "a head inside a fence or a comment" | headless FAIL = 1 | green | no `unreadable` |
| the 15 new red assertions | green | red | `unreadable` |

**Also GREEN's: review 2, finding 2.** Step 2a's message ends "... or put the
quoted opener in a fenced block of its own"; it must say instead "or quote the
opener together with its closer, or name it in words" (C-4 step 2a, amended).
Comments are removed before fences are read, so a fenced opener is still
unclosed and the old remedy leads back to the refusal. No test pins the
clause; the review routed it to GATES and the orchestrator to the GREEN that
follows.

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


### R-1 (diff review 1, finding 1: an unclosed comment opener or a one-line fence hides later entries)

- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2), 2026-11-12, diff review round 1, finding 1.

No test was wrong; tests were missing. Block 3k's `adj_scan` drops everything after an HTML comment opener that never closes, and treats a line that opens and closes a code fence on the same line as opening a fence that never closes, so a new entry after either is never judged (the review reproduced it with a recorded R-1, a prose line quoting the opener, and an unrecorded R-2: the run said `ok`). Found by the GATES → REVIEW diff review. What the tests should assert: a section with content that holds an unclosed comment opener, or ends inside a fence, gets exactly one `FAIL` saying it cannot be read past that point, and the run exits non-zero; each with an accepted twin (the same entries without the stray opener or fence). The new assertions fail against today's block, which is their watched red; RED pastes it below.

**RED, return 1 (2026-11-12, test-developer, resolved claude-opus-5-5).** The
tests, in `.claude/tests/boundaries.test.sh` after the C-9 cases, under
"Return 1 (R-1, ...)": an unclosed comment opener quoted in inline code before
a new unrecorded R-2; the same opener between R-1 and its record; a one-line
fence before a new unrecorded R-2; an ordinary multi-line fence never closed,
with the R-2 head inside it; the comment and one-line-fence cases again in
`## Amendments` with AM-1 and AM-2. Each asserts exactly one FAIL in the whole
run, naming the story, the section and `unreadable`; a non-zero exit; and no
`ok` line for that section. Twins (green on arrival, they are the controls):
the same sections without the stray line and with R-2 or AM-2 recorded; an
opener quoted with its closer on the same line; a fence closed as the last
thing in the section; and an unreadable section identical to the base copy,
which says nothing (the new step comes after step 2). Contract C-4 gains step
2a, amended in place. Decided here: a section that ends inside an ordinary
unclosed multi-line fence is unreadable too, since "ends inside a fence" is the
rule whatever opened the fence.

The watched red, against today's block 3k (attest record `last: 1 of 1
harness suite(s) FAILED.`, log `.claude/state/attest-logs/20261112T180754Z.11317.log`,
`boundaries: 632 passed, 20 failed`; these 16 are the R-1 ones, and no
assertion outside this return fails):

```
    FAIL HARNESS-102 R-1: a prose line quoting an unclosed comment opener in inline code, then a new R-2 with no record: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-1: a prose line quoting an unclosed comment opener in inline code, then a new R-2 with no record: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-1: a prose line quoting an unclosed comment opener in inline code, then a new R-2 with no record: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-1: an unclosed comment opener between R-1 and its record: the refusal is the unreadable one, not a missing record: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   1 0
    FAIL HARNESS-102 R-1: a line that opens and closes a backtick fence on the same line, then a new R-2 with no record: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-1: a line that opens and closes a backtick fence on the same line, then a new R-2 with no record: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-1: a line that opens and closes a backtick fence on the same line, then a new R-2 with no record: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-1: a multi-line fence that is never closed, so the section ends inside it, with a new R-2 head after the opener: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-1: a multi-line fence that is never closed, so the section ends inside it, with a new R-2 head after the opener: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-1: a multi-line fence that is never closed, so the section ends inside it, with a new R-2 head after the opener: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-1: ## Amendments: AM-1 recorded, a prose line quoting an unclosed comment opener, then a new AM-2 with no record: exactly one FAIL in the run, and it names the story, ## Amendments and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-1: ## Amendments: AM-1 recorded, a prose line quoting an unclosed comment opener, then a new AM-2 with no record: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-1: ## Amendments: AM-1 recorded, a prose line quoting an unclosed comment opener, then a new AM-2 with no record: and there is no ok line for ## Amendments
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-1: ## Amendments: AM-1 recorded, a one-line fence, then a new AM-2 with no record: exactly one FAIL in the run, and it names the story, ## Amendments and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-1: ## Amendments: AM-1 recorded, a one-line fence, then a new AM-2 with no record: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-1: ## Amendments: AM-1 recorded, a one-line fence, then a new AM-2 with no record: and there is no ok line for ## Amendments
         expected: 0
         actual:   1
```

`actual: 0 0` with `exit 0` and the ok line present is the defect itself: the
hidden R-2 (or AM-2) is never judged. The `1 0` row is the reverse case: one
FAIL, but it is the missing-record one for R-1, not the unreadable one.

### R-2 (diff review 1, finding 4: a wrapped prose line that starts with an id is not an entry head)

- **Adjudicated R-2:** `fable` (resolved claude-fable-5-2), 2026-11-12, diff review round 1, finding 4.

No test was wrong; a test was missing. C-1's head pattern makes all three prefixes optional, so a wrapped prose line beginning `R-2 of HARNESS-094 ...` is read as a new entry and refused. Found by the same review. What the test should assert: such a line is not an entry head (no FAIL for that id), while `### R-2`, `**R-2 ...**` and `- **R-2 ...**` still are. C-1 is amended in place by RED to require one prefix. The new assertion fails against today's block; RED pastes it below.

**RED, return 1 (2026-11-12, test-developer, resolved claude-opus-5-5).** Two
tests in `.claude/tests/boundaries.test.sh`, under "Return 1 (R-2, ...)": a
`## Regressions` with a recorded `### R-1` and a prose line wrapping to begin
`R-2 of HARNESS-094 did the same ...` must give no FAIL for R-2, the ok line
and exit 0; the same in `## Amendments` with a wrapped line beginning
`AM-2 of`. The twin, that `### R-1`, `**R-1 (...).**`, `- **R-1 (...).**` and
a three-space-indented `### R-1` are still heads and still refused unrecorded,
is the existing AC-3 head-spelling loop, which stays green and is not
duplicated. Contract C-1 is amended in place with the pattern GREEN builds.

The watched red, from the same run (`.claude/state/attest-logs/20261112T180754Z.11317.log`):

```
    FAIL HARNESS-102 R-2: a prose line that wraps to begin `R-2 of HARNESS-094` is not an entry head: no FAIL for R-2
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-2: and the section, whose only entry R-1 is recorded, gets the ok line
         expected: 1
         actual:   0
    FAIL HARNESS-102 R-2: and the run exits 0
         expected: 0
         actual:   non-zero
    FAIL HARNESS-102 R-2: in ## Amendments, a wrapped line beginning `AM-2 of` is not an entry head: no FAIL for AM-2, exit 0
         expected: 0 0
         actual:   1 non-zero
```


### R-3 (diff review 2, finding 1: a pair of stray lines hides the entry between them)

- **Adjudicated R-3:** `fable` (resolved claude-fable-5-2), 2026-11-12, diff review round 2, finding 1.

No test was wrong; tests were missing. Step 2a judges the end of the section, so an even number of one-line fences, or a quoted opener with a later quoted closer or a later ordinary comment, hides a new unrecorded entry between them and the run says ok. Found by the review of the fix. What the tests should assert: in each of the three reproductions, the section is refused as unreadable (exactly one FAIL, non-zero, no ok line); each with a twin where nothing head-shaped is hidden (accepted). The new assertions fail against today's block; RED pastes the red below.

**RED, return 2 (2026-11-12, test-developer, resolved claude-opus-5-5).** The
tests, in `.claude/tests/boundaries.test.sh` after the R-2 cases, under
"Return 2 (R-3, ...)": each has a recorded `### R-1` and a new unrecorded
`### R-2` with the stray pair around it - two one-line fences; a prose line
quoting the opener and a later one quoting the closer; the quoted opener and a
later ordinary comment; the first again in `## Amendments` with AM-1 and AM-2;
and, decided here, a closed fence whose head-shaped line names an id that is
no head outside it. Each asserts what the R-1 cases assert (exactly one FAIL in
the run, naming the story, the section and `unreadable`; non-zero; no ok
line). Twins, green on arrival and the controls: each pair with only prose
between it and R-2 recorded after it; a closed fence whose head-shaped line
repeats a real head's id; heads only inside a fence and a comment, which keeps
step 3's headless FAIL and is not unreadable; and this section itself, read
verbatim from the file at run time, which gets the ok line. Contract C-4 step
2a is amended in place: the hidden-head test is added, the end-of-section
tests stay, and the remedy's third clause is corrected.

The watched red, against today's block 3k (plain run of
`bash scripts/selftest.sh boundaries`, `boundaries: 664 passed, 15 failed`;
these 15 are all the failures, and every one is R-3's; the attest record of
the same command on the final tree is in the handoff, Return 2):

```
    FAIL HARNESS-102 R-3: a one-line fence before a new unrecorded R-2 and another after it: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-3: a one-line fence before a new unrecorded R-2 and another after it: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-3: a one-line fence before a new unrecorded R-2 and another after it: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-3: a prose line quoting the comment opener before a new unrecorded R-2, and a later prose line quoting the closer: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-3: a prose line quoting the comment opener before a new unrecorded R-2, and a later prose line quoting the closer: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-3: a prose line quoting the comment opener before a new unrecorded R-2, and a later prose line quoting the closer: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-3: a prose line quoting the comment opener before a new unrecorded R-2, and a later ordinary complete comment: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-3: a prose line quoting the comment opener before a new unrecorded R-2, and a later ordinary complete comment: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-3: a prose line quoting the comment opener before a new unrecorded R-2, and a later ordinary complete comment: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-3: ## Amendments: AM-1 recorded, a one-line fence before a new unrecorded AM-2 and another after it: exactly one FAIL in the run, and it names the story, ## Amendments and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-3: ## Amendments: AM-1 recorded, a one-line fence before a new unrecorded AM-2 and another after it: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-3: ## Amendments: AM-1 recorded, a one-line fence before a new unrecorded AM-2 and another after it: and there is no ok line for ## Amendments
         expected: 0
         actual:   1
    FAIL HARNESS-102 R-3: a closed fence holding a head-shaped line whose id is no head outside it: exactly one FAIL in the run, and it names the story, ## Regressions and says the section is unreadable
         expected: 1 1
         actual:   0 0
    FAIL HARNESS-102 R-3: a closed fence holding a head-shaped line whose id is no head outside it: and the run exits non-zero
         expected: non-zero
         actual:   0
    FAIL HARNESS-102 R-3: a closed fence holding a head-shaped line whose id is no head outside it: and there is no ok line for ## Regressions
         expected: 0
         actual:   1
```

`actual: 0 0` with exit 0 and the ok line present is the defect: R-2 (or
AM-2) between the pair is never judged.

## Diff review

### Review 1 — the whole diff against main at d5edacc (resolved claude-fable-5-2)

A fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved claude-fable-5-2, no override. It changed no file and ran neither the self-test nor `gates.sh`.

What this change does: moves the judging of a "the contract is wrong" claim from the orchestrator to a fresh `lead-po` dispatch on a new `ADJUDICATE` row of `models.conf`; adds block 3k to `scripts/check-boundaries.sh`, refusing a new `## Regressions` or `## Amendments` entry with no `**Adjudicated <id>:**` record; rewrites the procedure text to match; adds AC-9 and AC-10 carried from HARNESS-101.

Checked: the full diff of every non-test file; block 3k line by line against C-1 to C-6; the `dispatch.test.sh` region helpers; the `new-story.test.sh` needles; `adj_scan` extracted and run over every story's two sections and 13 edge inputs.

Answers to the orchestrator's four questions:

1. **AC-10's needle is not the gap GREEN feared.** `para_region "$RD_START"` runs from `**REVIEW → DONE.**` (`advance-story.md:381`) to `**Returning to RED from GREEN or GATES.**` (line 424); "Rules for you as orchestrator" (line 471) is outside it. The phrase occurs once in the region, at line 411, in the PR-feedback paragraph. Region-scoped, as AC-10 asks. No finding.
2. **Block 3k:** grammar matches C-1/C-2; the interval-free regexes are equivalent; the base copy goes through `$cp`, nothing after 3k reads it; a base without the story makes every id new; scratch files match the EXIT trap's glob; no early exit skips 3k; it changes neither 3d nor 3g. Findings 1 and 4 are its two defects.
3. **Wording:** the record format is the same in all seven places and matches 3k; no stale "orchestrator reproduces" text outside stories and tests. Findings 2 and 3 are two disagreements.
4. **Existing stories: safe.** Heads in 12 stories (008, 014, 015, 060, 087, 089, 090, 091, 094, 095, 099, 100), none lost to fence skipping; all DONE and identical to the base, so step 2 says nothing. No existing section has an unclosed comment or an odd fence count.

**Must fix:**

1. **A stray comment opener or a one-line code fence hides every entry after it** (`scripts/check-boundaries.sh:1158-1173`, step 2 at `:1206-1208`)
   - **What this is:** `adj_scan`, which lists a section's heads and records after dropping HTML comments and fenced blocks.
   - **Problem:** an unclosed comment opener (for example quoted in inline code) drops the rest of the section; a line that opens and closes a fence on one line opens a fence that never closes. Reproduced: `### R-1` with its record, a prose line quoting the opener in backticks, then a new `### R-2` with no record: the scan prints only `head R-1` and `rec R-1 fable`, the run says `ok`, R-2 is never judged. Reversed, a valid record after such a line is not seen.
   - **Fix:** in block 3k, fail closed: a section with content holding an unclosed comment opener, or ending inside a fence, gets one `problem` saying so and that nothing after it can be read. Add both cases, each with its accepted twin, to `.claude/tests/boundaries.test.sh`.
   - **If we skip it:** the gate passes an unadjudicated entry by accident of wording, in a repository whose entries routinely quote the opener.
   - **Route:** RED

**Should fix:**

2. **The story template says the orchestrator never writes the record; the procedure says it does** (`scripts/new-story.sh:147-158`, `:241-248`)
   - **What this is:** the `## Amendments` and `## Regressions` comments in every new story.
   - **Problem:** both say the record is written by the ADJUDICATE dispatch, "never the orchestrator"; `advance-story.md`, `diff-review/SKILL.md` §5 and C-7 say the orchestrator writes it for an entry following a `RED` or `AMEND` finding. The Regressions comment omits that case.
   - **Fix:** in both comments, say an entry following a diff-review or PR-feedback finding routed `RED` or `AMEND` carries a record the orchestrator writes, naming the round and finding; keep "never the orchestrator" for the judgement only. The `new-story.test.sh` needles still hold.
   - **If we skip it:** after a review routes `RED`, the orchestrator stalls or pays for a second dispatch the design does not need.
   - **Route:** GATES

3. **The return-to-RED procedure never mentions the head or the adjudication** (`.claude/commands/advance-story.md:424-460`)
   - **What this is:** "Returning to RED from GREEN or GATES", including the everyday format-gate return.
   - **Problem:** its first bullet says only "say in `## Regressions` what is wrong with the test"; the adjudication rule is in another bullet, phrased for a subagent's claim. An orchestrator following these steps writes an entry with no `R-<n>` head and no record, and learns it from `check-boundaries.sh` after the test changed.
   - **Fix:** one sentence in that first bullet: the entry is headed `R-<n>` and carries its `**Adjudicated R-<n>:**` record; a return no review finding routed gets an ADJUDICATE dispatch before the test changes, mechanical returns included.
   - **If we skip it:** the dispatch happens after the fact, to satisfy the gate - the rubber stamp this story removes.
   - **Route:** GATES

**Nice to have:**

4. **A wrapped prose line that starts with an id counts as an entry head** (`scripts/check-boundaries.sh:1166`)
   - **What this is:** C-1's entry-head pattern, whose `###`, `- ` and `**` prefixes are all optional.
   - **Problem:** a prose line in `## Regressions` that wraps to start with `R-2 of HARNESS-094 did the same` is read as a new entry `R-2`, and the run FAILs for an entry that does not exist.
   - **Fix:** require one of the three prefixes in the head pattern (every spelling in the tree has one), with a case in `.claude/tests/boundaries.test.sh`; C-1 amended in place to match.
   - **If we skip it:** an occasional confusing refusal, cured by re-wrapping. It fails closed.
   - **Route:** RED

Not checked: behaviour under mawk (only GNU Awk 5.4.1 here; the regexes were read, not run there); a full `check-boundaries.sh` run on this branch; consuming projects, where an in-flight story with headless entries is refused after a refresh, as `## Out of scope` states.

Verdict: Fix first.

**Orchestrator (2026-11-12):** all four followed as labelled. `classify.sh` calls every path the fixes name `harness` (`scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `scripts/new-story.sh`, `.claude/commands/advance-story.md`), so the lock permits both phases and the labels decide. Findings 1 and 4 return the story to RED (`## Regressions` R-1, R-2), adding tests that fail against today's block, so their red is watched in the ordinary way. Findings 2 and 3 are made by the GREEN that follows, with the source fixes for 1 and 4. The fixed tree gets a review of the fix before the self-test.

### Review 2 — the fix only, git diff d5edacc ad4c303 (resolved claude-fable-5-2)

A fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved claude-fable-5-2, no override. It changed no file; scratch copies of `section`, `strip_comments`, `has_content` and `adj_scan` were run in its scratchpad.

Round 1's findings: **1 fixed for the cases round 1 named, not for the class** (finding 1 below); **2 fixed** (the template's record line matches 3k's pattern); **3 fixed** (word for word in both commands, consistent with `advance-story.md:479-503`); **4 fixed** (bare `R-2 of ...` / `AM-2 of ...` not heads; prefixed spellings still are; four-space indent, `* R-9`, seven hashes are not). Real stories: none newly refused - 45 sections with content, 44 identical to `main`; HARNESS-102's own `## Regressions` scans `head R-1, rec R-1 fable, head R-2, rec R-2 fable` and gets the ok line. Portability: no interval expressions; same output under `gawk --posix` and `--traditional`; `check-sigpipe.sh` exit 0, pins unmoved.

**Must fix:**

1. **A pair of stray lines still hides the entry between them, and the run says ok** (`scripts/check-boundaries.sh:1165-1170`, `:1175-1176`, flag at `:1192`)
   - **What this is:** `adj_scan`'s two "unreadable" tests: an opener with no closer anywhere after it, and an odd count of fence lines.
   - **Problem:** both test the end of the section, not what was skipped. Reproduced, each with a recorded `### R-1` then a new unrecorded `### R-2`: (a) a one-line fence before R-2 and another after it; (b) a prose line quoting the opener in backticks before R-2 and a later line quoting the closer; (c) the same opener and a later ordinary comment. All three print only `head R-1`, `rec R-1 fable`, no `unreadable`; 3k prints ok and R-2 is never judged.
   - **Fix:** in `adj_scan`, also print `unreadable` when a line matching the head pattern was removed with a comment or skipped inside a fence and its id is not printed as a head. Cases (a)-(c), each with a twin, in `.claude/tests/boundaries.test.sh`; C-4 step 2a amended in place. No real section trips it (45 checked).
   - **If we skip it:** the ok line still depends on wording, as round 1's finding 1 said it must not.
   - **Route:** RED

**Should fix:**

2. **The refusal recommends a remedy that does not clear it** (`scripts/check-boundaries.sh:1217`)
   - **What this is:** step 2a's message, ending "... or put the quoted opener in a fenced block of its own."
   - **Problem:** comments are removed before fences are read, so an opener inside a closed fence is still unclosed. Reproduced: a three-line fence holding only the opener, then `### R-2`: still `unreadable`.
   - **Fix:** replace the third remedy with "or quote the opener together with its closer, or name it in words". No test pins the clause; C-4's sentence corrected with finding 1's amendment.
   - **If we skip it:** a refusal whose own instructions lead back to it.
   - **Route:** GATES

**The known limit, judged: no finding.** An unclosed opener as the section's first content makes `has_content` false, so step 1 stops; every block that reads the section through `has_content`, and the rendered story, treat it as empty at once. Not worth amending AC-4; if ever closed, it is a `has_content` change for the whole file, in a story of its own.

Not checked: a real mawk; a full `check-boundaries.sh` run on this branch (steps 1-2a emulated); the boundaries suite not re-run.

Verdict: Fix first.

**Orchestrator (2026-11-12):** both followed as labelled; `classify.sh` calls `scripts/check-boundaries.sh` and `.claude/tests/boundaries.test.sh` `harness`, so the labels decide. Finding 1 returns the story to RED (`## Regressions` R-3); finding 2 is made by the GREEN that follows.

### Review 3 — the fix of the fix, git diff ad4c303 HEAD (503acc3, 4c8a597, f6e94d9) (resolved claude-fable-5-2)

A fresh `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved claude-fable-5-2, no override. It changed no file in the repository and ran neither the self-test nor `gates.sh`. Scratch copies of `section`, `strip_comments`, `has_content` and `adj_scan`, extracted with `sed` from `scripts/check-boundaries.sh` at HEAD, were run in its scratchpad.

What this change does: `adj_scan` now also prints `unreadable` when the section has at least one entry head outside comments and fences and some raw line shaped like a head names an id that is none of those heads; step 2a's message describes the new cause and replaces the remedy that did not work; 27 assertions (R-3) are added to `boundaries.test.sh`, and the `boundaries` floor goes 652 → 679 in both records.

Checked: the whole diff of the three commits; block 3k line by line against C-1 and C-4 as amended; the R-3 fixtures and twins; 14 hiding candidates, 10 remedy inputs and every story's two sections through the extracted scan.

Review 2's findings: **1 fixed as a class**, **2 fixed**, with one gap in the new wording (finding 1 below).

1. **The class is closed.** The new test reads every raw line, so it does not depend on how the line was hidden; a head escapes it only if its raw line does not match the head pattern, and such a line is no head under C-1 hidden or not. Each candidate had a recorded `### R-1` first; what the scan printed after `head R-1` / `rec R-1 fable`:

   | Candidate | Scan output after R-1's two lines |
   |---|---|
   | two one-line tilde fences around a new `### R-2` | `unreadable` |
   | backtick opener, tilde closer around `### R-2` | `unreadable` |
   | fences indented five spaces around `### R-2` | `unreadable` |
   | two one-line fences around `- **R-2 (new)**` | `unreadable` |
   | hidden `### R-01` and `- **AM-2` in `## Regressions` | `unreadable` |
   | CRLF line endings, fenced `### R-2` | `unreadable` |
   | a blockquoted fence, then a real fence around `### R-3` | `unreadable` |
   | multi-line complete comment holding `### R-5` | `unreadable` |
   | record hidden in a fence, head `### R-2` visible | `head R-2`, no `rec` (step 4 refuses it) |
   | quoted opener, then a line `--> ### R-2 (new)` | nothing more (not a head in C-1 or in rendered Markdown) |
   | fenced `### R-1 (a different, new claim)`, repeating the visible id | nothing more (C-5's stated limit; the same text unfenced is not judged either) |

2. **The condition is sound.** Step 2a is reached only when the section has content and differs from the base; with no visible head the scan prints no `head` line, so step 3 refuses. Reproduced: prose plus a fenced `### R-1 (new)` prints nothing, step 3's headless FAIL; the R-3 twin pins it.
3. **No existing section is refused.** 102 story files, 204 sections, 45 with content, 17 with heads: `unreadable` for none. HARNESS-102's own `## Regressions` scans `head R-1, rec R-1 fable, head R-2, rec R-2 fable, head R-3, rec R-3 fable`. The `new-story.sh` template comments indent their example lines five spaces, so a new story cannot trip the test.
4. **The four listed remedies each clear the cause they are for** (quote the opener with its closer, name it in words, close the comment, close the fence). The new third cause has no listed remedy: finding 1.
5. **Neither accepted limit is a finding.** A one-line complete comment holding a head is not rendered and AC-4 says text inside a comment is nothing; a fenced example naming an id that exists nowhere outside has fixture (a)'s shape and fails closed, and no real section does it today.

**Nice to have:**

1. **The refusal names the hidden-head cause but gives no remedy for it** (`scripts/check-boundaries.sh:1230`)
   - **What this is:** step 2a's message, which now lists three causes and ends "Close the comment, close the fence, or quote the opener together with its closer, or name it in words."
   - **Problem:** all four remedies are for the first two causes. Reproduced: recorded `### R-1`, then a closed three-line tilde fence holding `### R-3 (the next one)` (fixture (e)) prints `unreadable`; there is no comment to close, the fence is closed, no opener to quote.
   - **Fix:** one clause: for a head-shaped line, move the entry's head outside the comment or fence, or, if it is only an example, indent it four spaces or quote it inline; write a fence's markers on lines of their own. Verified: fixture (e)'s line indented four spaces, or as inline code, scans with no `unreadable`. No test pins the clause.
   - **If we skip it:** an author with a legitimate fenced example works the remedy out from the description of the cause, which is accurate.
   - **Route:** GATES

**Limits seen, judged: no finding.** A quoted opener-and-closer pair already in the base copy, with a head added between them, leaves the comment-stripped text identical, so step 2 says nothing; it needs a story whose section has content on `main` while still in flight, which this loop does not produce. A head misspelled outside C-1's grammar (`###  R-2`, two spaces) is not a head; C-1 as planned, a story of its own if ever worth closing.

Not checked: a real mawk (the new lines use only `split`, `match`, `in`, `substr`); a full `check-boundaries.sh` run on this branch; the boundaries suite not re-run (679 from the GREEN and GATES records).

Verdict: Ship.

**Orchestrator (2026-11-12):** verdict Ship, so GATES → REVIEW goes on. The one finding is Nice to have, routed GATES, and is deferred rather than made here: making it changes the tree and restarts these steps with a fourth review, for a message clause whose cause description is already accurate. It is offered to the user as a follow-up. Neither limit is acted on.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-12T21:47:20Z
    commit: 4c8a597
    tree:   fcc43cd5c610709fd98bfdfde38e1f43a1c09cda
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


- Planned 2026-11-11 with HARNESS-101, from the user's decisions 5 and 6 of that day, on `main` at `5e52301`. `depends_on: [HARNESS-101]` is a real ordering: the record format accepts a diff-review `Route` finding as an adjudication, and the `ADJUDICATE` row takes the step-row shape, both of which HARNESS-101 builds. The two stories also share nine files.
- Two defaults are not among the user's decisions and are reported for a yes or no before this story leaves PLANNED: AC-6 (a record naming a model other than the planned one is accepted with a `note`, not refused) and AC-7 (an amendment the user asked for unprompted is recorded as `requested by the user`, with no dispatch).
- Decision 6 says every new entry needs a record. That includes a mechanical return to RED (a moved line pin, a reflowed test): it costs one small `fable` dispatch, and an exemption for "mechanical" entries would hand the routing judgement back to the orchestrator.
- **User answers, 2026-11-11:** AC-6 confirmed (a record naming a non-planned model passes with a `note`, not refused); AC-7 confirmed (`requested by the user` accepted for `AM-` entries only); and every new `## Regressions` entry needs a record, with no exemption for mechanical ones, confirmed. Asked in chat before the story left PLANNED; no criterion changed.
- **PLANNED review, 2026-11-11, after HARNESS-101 merged (tree at `b10546e`).** Both carried items below are taken: item 1 is AC-9, item 2 is AC-10, both specified in Contract C-10. Reason: each is a few lines in `dispatch.test.sh` and `advance-story.md`, files already in `touches:`, in the guard this story extends anyway; a story of its own would cost a full cycle for one clause and two needles. They add no file and no suite, so the story stays one RED→GREEN cycle; if RED finds otherwise it says so in the handoff and they are split off as a `chore`. Also changed at this review, while the criteria may still change: AC-1 now covers `lead-po.md`'s `## When you are dispatched inside a story` and `description:` (HARNESS-101 wrote both, listing three rows) and counts a REVIEW-row PR-feedback item routed `RED` or `AMEND` as adjudicated by that dispatch, as a diff-review finding is (PO decision 1, returned to the user for a yes or no). Contract C-7 now says who writes the record: the adjudicating dispatch itself, and the orchestrator only for a `Route`d entry, whose reviewer changes no file (PO decision 2). `rules.md` is at the 370-line cap, so C-7's edits to it are word-level and the cap is not raised. The user's three answers above stand unchanged.
- **Carried from HARNESS-101 (2026-11-11)** — two items its diff review left, both in files this story edits; taken, as the line above says:
  1. `.claude/tests/dispatch.test.sh:988`: the PLANNED → RED needle list `row_problems` checks only `lead-po` and `PLANNED row`, so deleting HARNESS-101 AC-3's read-before-commit sentence ("Once the dispatch is back, read what it returned." in `advance-story.md`; "before you commit at PLANNED" in `complete-story.md`) leaves every suite green. Add a needle per file with a control, earned by mutation since the text exists (Route: RED).
  2. `.claude/commands/advance-story.md` ~line 410: the REVIEW-row PR-feedback dispatch should carry the same "unless the story's `## Model guidance` records a departure for that row" clause as GATES → REVIEW step 1 (Route: GATES).
- **User answers, 2026-11-11 (PLANNED review):** Q1 confirmed — a REVIEW-row PR-feedback item routed `RED` or `AMEND` counts as adjudicated by that dispatch, as a diff-review finding does (AC-1 as extended). PO decision 2 confirmed — the adjudicating dispatch writes its own record line; the orchestrator writes it only for a Route'd entry. Asked in chat before the story left PLANNED; no criterion changed beyond the PLANNED review's.
- **RED verified by the orchestrator, 2026-11-11.** Changed files: the four suites and this story only. `attest.sh check -- bash scripts/selftest.sh boundaries plan dispatch new-story` `fresh` on tree `5a38956`, exit 1, `4 of 4 harness suite(s) FAILED.`, log `.claude/state/attest-logs/20261111T221223Z.127173.log`: boundaries 565/56, dispatch 201/4, new-story 59/20, plan 281/6. Every FAIL line is a HARNESS-102 criterion (AC-1..AC-8, AC-10, C-6, C-9) or a HARNESS-101 pin extended by it; no load error. The plan suite's floor miss (281 < 286) counts passes; GREEN raises the floors to the handoff's 621/287/205/79. `attest.sh check -- bash scripts/gates.sh --fast` `fresh`, exit 0 (no gate configured in this repository). AC-9's two C-10 mutations are in the handoff, each 201/4 → 200/5 and restored. `mutate.sh --check` clean. The C-7 in-place amendment (four needles taken from AC-1's own words, and the locator) is accepted; no acceptance criterion changed.
- **GREEN, 2026-11-11** (`feature-developer`, planned `opus`, resolved claude-opus-5-5, no override). Changed: `scripts/check-boundaries.sh` (block 3k appended after 3j, before `exit $fail`; the three sigpipe pins 399/438/630 unmoved; regexes spelled without interval expressions for an older mawk), `.claude/harness/models.conf` (the `ADJUDICATE | lead-po | fable` row, last, and the header), `.claude/commands/advance-story.md` (the contract-is-wrong bullet; the PR-feedback paragraph's `records a departure for that row`), `.claude/commands/complete-story.md`, `.claude/agents/lead-po.md` (description, `## When you are dispatched inside a story` now four pieces of work, the bullet), `.claude/harness/rules.md` (three word-level edits, still 370 lines), `.claude/skills/diff-review/SKILL.md` (section 5, the record), `scripts/new-story.sh` (both template comments), `.claude/skills/story-authoring/SKILL.md` and `reference/sections.md`, `.claude/harness/VERSION` 120 -> 121. Floors raised in `floors.conf` and the `selftest.test.sh` mirror: boundaries 545 -> 621, plan 286 -> 287, dispatch 145 -> 205, new-story 58 -> 79, each the passing count measured. Controls confirmed against the shipped block: block 3k describe 76/0, the rest of boundaries green (621/0 total, as the candidate measured), `adj_problems` and `row_problems` silent over the real tree.
- **GREEN verified by the orchestrator, 2026-11-12.** Changed files are the Contract's harness files, `VERSION` (121), and of `.claude/tests/` only the floor rows in `floors.conf` and the `selftest.test.sh` mirror (545→621, 286→287, 145→205, 58→79, the handoff's counts). `attest.sh check -- bash scripts/selftest.sh boundaries plan dispatch new-story` `fresh` on tree `739c5a6`, exit 0, `4 harness suite(s) passed.`, 1582 s, log `.claude/state/attest-logs/20261111T234901Z.118097.log`; `attest.sh check -- bash scripts/gates.sh --fast` `fresh`, exit 0 (no gate configured), log `20261112T001543Z.214788`. `rules.md` 370 lines; `mutate.sh --check` clean. Feature-developer's doubts for GATES and diff review: (1) the AC-10 needle's `REVIEW → DONE` region may reach the orchestrator-rules bullets, so the phrase could be satisfied from outside the PR-feedback paragraph; GREEN keeps it in that paragraph only; (2) it aborted one attested run and deleted a `run.lock` whose holder pid was dead; (3) `selftest-needed.sh --suites` lists 27 of 34 suites for this diff, for the self-test at GATES → REVIEW.
- **GATES, 2026-11-12.** `attest.sh check -- bash scripts/gates.sh` `fresh`, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).`, log `20261112T171547Z.613246` - as in every harness story, `project.conf` configures no gate here, so the evidence for this code is the self-test at GATES → REVIEW and `check-boundaries.sh` after the commit. Mutation 7 of the DV-3 table ran for about 7 hours (02:31 to 09:50 local) against the usual ~17 minutes, and finished and restored cleanly; the log shows no cause.
- **Return 1 to RED verified by the orchestrator, 2026-11-12.** `test-developer`, planned `opus`, resolved claude-opus-5-5. Changed: `boundaries.test.sh` and this story only (C-1, C-4 amended in place; R-1/R-2 red pasted; handoff "Return 1"). `attest.sh check -- bash scripts/selftest.sh boundaries` `fresh`, exit 1, `boundaries: 632 passed, 20 failed`, log `20261112T180754Z.11317`: the 20 are exactly the new `HARNESS-102 R-1:`/`R-2:` assertions; `--fast` `fresh`, exit 0. Known limit, not pinned: an unclosed comment opener that is the section's first content leaves nothing outside comments, so step 1 says nothing (AC-4's "only comments" case); markdown renders that section empty too.
- **GREEN after return 1, 2026-11-12** (`feature-developer`, planned `opus`, resolved claude-opus-5-5, no override). Changed: `scripts/check-boundaries.sh` block 3k only (C-4 step 2a: `adj_scan` sets a flag where a comment opener has no closer and prints a last line `unreadable` when that flag or `fence` is set at the end; after the working tree's scan, one `problem` naming `$sid`, `## <section>` and `unreadable`, then `continue`; the amended C-1 head regex, interval-free, `^ ? ? ?((####?#?#? |- )([*][*])?|[*][*])`; the header comment's head pattern updated to match; all lines appended inside 3k, nothing above it moved), `scripts/new-story.sh` (diff review finding 2: both template comments say the judgement is never the orchestrator's, and that an entry following a diff-review or PR-feedback finding routed RED or AMEND carries a record the orchestrator writes, naming the round and finding, with the record line shown), `.claude/commands/advance-story.md` (finding 3: one sentence in the first bullet of "Returning to RED from GREEN or GATES") and the same sentence in `complete-story.md`'s "A return to RED ends with pasted red" bullet. Floor `boundaries` 621 -> 652 in `floors.conf` (dated comment) and the `selftest.test.sh` mirror. Real-tree check of the new scan against HEAD's, over both sections of every story under `docs/backlog/stories/`: identical output for all 17 sections that carry a head, none `unreadable`, no head lost to the prefix requirement.
- **Return 1, GREEN verified by the orchestrator, 2026-11-12.** `feature-developer`, planned `opus`, resolved claude-opus-5-5. Diff review findings 1-4 made (block 3k step 2a and the C-1 head prefix; `new-story.sh` comments; the return-to-RED bullet in `advance-story.md`, and the same sentence in `complete-story.md`'s return bullet). Of `.claude/tests/`, only the boundaries floor (621→652) and its mirror. `attest.sh check -- bash scripts/selftest.sh boundaries new-story dispatch procedure` `fresh` on tree `93d529f`, exit 0, `4 harness suite(s) passed.` (652/79/205/183), log `20261112T190444Z.137793`; `--fast` `fresh`, exit 0. Step 2a's watched red is RED return 1's 20 failures against the old block; no further defect-put-back run was made.
- **Return 1, GATES, 2026-11-12.** The full run was made by the orchestrator directly, not dispatched: it takes 2 s here because no gate is configured. `attest.sh check -- bash scripts/gates.sh` `fresh`, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).`, log `20261112T193428Z.219900`. No GATES-owned deferred verification is new in this return.
- **Return 2 to RED verified by the orchestrator, 2026-11-12.** `test-developer`, planned `opus`, resolved claude-opus-5-5, no override. Changed: `boundaries.test.sh` and this story only (C-4 step 2a amended in place with the hidden-head test and review 2 finding 2's remedy wording; R-3 red pasted; handoff "Return 2 (from GATES)"). `attest.sh check -- bash scripts/selftest.sh boundaries` `fresh` on tree `53e0c03`, exit 1, `boundaries: 664 passed, 15 failed`, log `20261112T202918Z.287245`: the 15 are exactly the new `HARNESS-102 R-3:` assertions (five fixtures, three each); 12 new twins green on arrival; `--fast` `fresh`, exit 0. Decisions accepted: the hidden-head test applies only when the section has a head outside comments and fences, so AC-5's headless FAIL (boundaries.test.sh:4066-4070) is unchanged; the fifth fixture (a closed fence quoting a head with no real twin) follows from review 2's fix as written. Review 2 finding 2 has no test; GREEN makes it from the amended C-4.
- **GREEN after return 2, 2026-11-12** (`feature-developer`, planned `opus`, resolved claude-opus-5-5, no override). Changed: `scripts/check-boundaries.sh` block 3k only - `adj_scan` keeps a copy of the raw section and counts the visible heads it prints (`nh`); at the end, when `nh > 0`, every raw line matching C-1's head pattern whose id is not one of the visible heads sets `hid`, and `unreadable` is printed when `open`, `fence` or `hid` is set (C-4 step 2a as amended; with no visible head nothing new, so step 3's headless problem stays the refusal); the header comment says so; step 2a's message gains a sentence for the hidden-head case and its remedy now ends "or quote the opener together with its closer, or name it in words" (diff review 2, finding 2). All lines inside 3k; nothing above it moved. Floor `boundaries` 652 -> 679 in `floors.conf` (dated comment) and the `selftest.test.sh` mirror. Real-tree check of the new scan against HEAD's, over both sections of every story under `docs/backlog/stories/`: 176 non-empty sections, identical output for all, none `unreadable`. The attest records of the suite and `--fast` are in the GREEN report to the orchestrator.
- **Return 2, GREEN verified by the orchestrator, 2026-11-12.** `feature-developer`, planned `opus`, resolved claude-opus-5-5. Changed: block 3k of `scripts/check-boundaries.sh` only (the hidden-head test in `adj_scan`, conditional on a visible head; step 2a's message with review 2 finding 2's remedy), and of `.claude/tests/` only the boundaries floor (652→679) and its mirror. `attest.sh check -- bash scripts/selftest.sh boundaries new-story dispatch procedure` `fresh` on tree `dd90ad5`, exit 0, `4 harness suite(s) passed.` (679/79/205/183), log `20261112T211655Z.348227`; `--fast` `fresh`, exit 0. Accepted limit: a head-shaped line wholly inside a one-line comment (`<!-- ### R-5 -->`) does not trip the hidden-head test; it is invisible when rendered too, so it hides no visible entry.
- **Return 2, GATES, 2026-11-12.** Full run by the orchestrator directly (2 s, no gate configured). `attest.sh check -- bash scripts/gates.sh` `fresh`, exit 0, log `20261112T214719Z.406244`. No GATES-owned deferred verification is new in this return; R-3's red was watched against the old block in RED.
