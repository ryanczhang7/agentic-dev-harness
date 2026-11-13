---
id: HARNESS-103
title: The unreadable-section refusal says how to fix a hidden entry head
slug: the-unreadable-section-refusal-says-how
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-103-the-unreadable-section-refusal-says-how
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the boundaries suite under its selftest floor, which CI runs in full on the PR
---

## Context

A follow-up to HARNESS-102 (merged as #192), from its third diff review: a
Nice-to-have finding that was deferred rather than fixed there.

`scripts/check-boundaries.sh` block 3k, step 2a, refuses a `## Regressions` or
`## Amendments` section it cannot read to its end. Its one `problem` message
(line 1230 at `f53b2d0`) names three causes:

1. an HTML comment opener with no closer after it;
2. the section ends inside a fenced block;
3. a line shaped like an entry head sits inside a comment or a fence and names
   an id that is no head outside them (HARNESS-102's return 2: a stray pair of
   lines hides what lies between).

Its remedies - "Close the comment, close the fence, or quote the opener
together with its closer, or name it in words." - answer causes 1 and 2 only.
A writer refused for cause 3 has, in the commonest case, a perfectly closed
fence holding an example head, and nothing in the message says what to do
about it. This is the kind of refusal with no sanctioned next step that
`rules.md` warns invites an invented one.

The fix is text: one more remedy clause in that message. The scan itself
(`adj_scan`) is not changed, and neither is what is refused.

**Paraphrases elsewhere: none.** Searched 2026-11-12 at `f53b2d0` for
`unreadable`, `quote the opener`, `name it in words` and `step 2a` across
`docs/wiki/`, `.claude/skills/`, `.claude/commands/`, `.claude/agents/`,
`CLAUDE.md`, `.claude/harness/rules.md` and `scripts/`. The only file besides
the script and its suite that quotes step 2a's remedies is
`docs/backlog/stories/HARNESS-102.md`, which is a closed story's record and is
left as it is. `story-authoring/reference/sections.md` and the
`scripts/new-story.sh` template describe the entry head and the record, not
this refusal, and are not touched.

**The required gate.** Every gate is unconfigured in this repository, so
`required_gates` stays empty, as on HARNESS-102. The artifact is judged by the
`boundaries` suite under its self-test floor, which CI runs in full on the PR.

**The epic.** `epic:` is empty, as on every HARNESS story.

## Acceptance criteria

- **AC-1** — Given a story branch whose story file is new against the base and
  whose `## Regressions` holds, outside comments and fences, the entry head
  `### R-1` with its adjudication record, and after them a closed fenced block
  (a tilde marker line, one line, a tilde marker line) whose one line is
  `### R-3 (the next one)`, when `bash scripts/check-boundaries.sh` runs, then
  it exits non-zero and prints exactly one `FAIL` line in the whole run; that
  line names the story and `## Regressions`, says the section is `unreadable`,
  still carries the sentence "Close the comment, close the fence, or quote the
  opener together with its closer, or name it in words." word for word, and
  after that sentence says how to fix a hidden head: move the entry's head
  outside the comment or fence; or, if it is only an example, indent it four
  spaces or quote it inline; and write a fence's markers on lines of their
  own.
  *Control:* with that added clause deleted from the message in
  `scripts/check-boundaries.sh`, the assertion that pins it must fail (DV-1).
- **AC-2** — Given the same story with the example rewritten in either of the
  two ways the message offers for an example - (a) the same closed fence, its
  one line indented four spaces; (b) no fence, the head quoted in inline code
  inside a sentence of prose - when `bash scripts/check-boundaries.sh` runs,
  then it prints the `ok` line for `## Regressions`, no `FAIL` line at all,
  and exits 0. What the message tells the writer to do is accepted by the
  check that printed it.

## Contract

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**Who writes which.** Every path above classifies as `harness`, so the lock
divides nothing and this block does. RED (test-developer) writes
`.claude/tests/boundaries.test.sh` only. GREEN (feature-developer) writes
`scripts/check-boundaries.sh`, the two floor records and `VERSION`.

**C-1. The message.** One edit, in place, to the `problem` string of block 3k
step 2a (`scripts/check-boundaries.sh`, line 1230 at `f53b2d0`; find it by
`is unreadable: it holds`). Everything up to and including the sentence that
ends `or name it in words.` stays byte for byte. One sentence is appended
inside the same string, after a single space, so the message ends:

    Close the comment, close the fence, or quote the opener together with its closer, or name it in words. For a hidden head: move the entry's head outside the comment or fence, or, if it is only an example, indent it four spaces or quote it inline; and write a fence's markers on lines of their own.

The appended sentence has no backtick, no dollar sign and no double quote, so
it needs no escaping inside the double-quoted string. It stays on the same
source line: the edit adds no line to the script and removes none, so nothing
that names a line number of `check-boundaries.sh` moves (`sigpipe.test.sh`
pins several, all above this line). `problem` prints the message as one output
line beginning `FAIL  `.

Why these three remedies and what each one means to the scanner (`adj_scan`,
unchanged, read at `f53b2d0`):

- *move the entry's head outside* - a head outside comments and fences is read
  as a head, and its id is then judged in the ordinary way (it needs a record);
- *indent it four spaces or quote it inline* - the head pattern allows at most
  three leading spaces and must start the line, so a line indented four spaces,
  or a head that sits in backticks inside a sentence, is not head-shaped
  anywhere and hides nothing;
- *a fence's markers on lines of their own* - a line that opens and closes a
  fence on one line is counted as an opener only, which is how a pair of them
  comes to hide what lies between.

**C-2. What does not change.** `adj_scan`, its header comment, steps 1, 2, 3 to
6, every other message of block 3k, and which sections are refused. No story
that passes today is refused after this change and none that is refused
passes: only the text of one FAIL line differs.

**C-3. The fixtures and the assertions (RED).** In
`.claude/tests/boundaries.test.sh`, inside the HARNESS-102 block-3k describe,
after case (f) and before the lines that put `main` back
(`git -C "$FIX" checkout -q main`), using the helpers already there (`k_reg`,
`k_branch`, `K_REC_R1`, `K_RESULT`, `k_fails`, `k_unreadable`, `k_readable`,
`k_rc`). A new fixture story id, the next free `T-` number (T-118 at
`f53b2d0`).

- AC-1 fixture: `k_reg '### R-1 (the AC-2 count)' "$K_REC_R1"`, then a prose
  line, then the three-line tilde fence holding the head-shaped line for R-3.
  Measured on the extracted `adj_scan` at `f53b2d0`: it prints `head R-1`,
  `rec R-1 fable`, `unreadable`. This is refused today; what is red in RED is
  the message.
- AC-1 assertion: **one** `assert_eq`, so that nothing in it is green on
  arrival. Its value has three counts and expects `1 1 1`: `k_fails` (every
  FAIL in the run), `k_unreadable Regressions`, and the number of FAIL lines
  that END with the whole remedy text of C-1, from `Close the comment` to
  `lines of their own.`. Anchor that third needle to the end of the line - a
  fixed-string suffix compare in awk (`substr($0, length($0) - length(t) + 1)
  == t`), not a floating `grep` - so it pins the kept sentence, the new
  sentence, their order and that nothing follows. Today it reads `1 1 0`.
  Add the exit status as a second assertion only if RED wants it; it is green
  on arrival and adds nothing the first does not already imply through
  `k_fails`.
- AC-2 fixtures: (a) the AC-1 fixture with the fenced line indented four
  spaces; (b) `k_reg` as above, then one prose line that carries the same head
  text in inline code mid-sentence, and no fence. Each asserted with
  `k_readable ... Regressions <tag>`. Measured at `f53b2d0`: both scan as
  `head R-1`, `rec R-1 fable` and no `unreadable`. **Both are green on
  arrival**; DV-2 earns them, and RED runs it.

**C-4. What RED and every later phase must not paste where block 3k reads.**
Block 3k judges THIS story's own `## Regressions` and `## Amendments` on its
own PR. HARNESS-102 returned to RED twice over exactly this. So:

- Assertion NAMES carry no head-shaped text, no comment opener or closer and
  no fence marker. The existing block keeps stray lines in variables
  (`K_OPEN`, `K_STRAY_F`, ...) for this reason: a name is pasted, as part of a
  failure line, into a story's `## Regressions` or handoff. Describe the
  fixture in words in the name ("a closed fence holding an example head for
  the next id") and hold the line itself in a variable, e.g. `K_HID`.
- If this story ever writes `## Regressions` or `## Amendments`: every entry
  head (`### R-1 (...)`, `- **AM-1 (...)`) is outside comments and fences and
  has its `**Adjudicated ...:**` record line; no pasted output line begins,
  after at most three spaces, with `### R-<n>`, `- R-<n>`, `- **R-<n>` or
  `**R-<n>` (or the `AM-` forms) unless that id is a real entry of the
  section; pasted output goes in a fence whose two markers are each on a line
  of their own, or is indented four spaces.
- **Never paste the step 2a FAIL line itself**, in any section of this story.
  It quotes a comment opener in backticks, and every reader that strips
  comments from a section (block 3k, and the checks that look for a pasted
  result in `## Deferred verifications`, `## Regressions` and `## Gate
  probes`) then loses the rest of that section. Paste the assertion's own
  `FAIL <name>` line and the suite's summary line instead; if the message
  must be shown, cut the line off before the opener or describe the opener in
  words. This file is written that way throughout.

**C-5. The floors and the release (GREEN).** `boundaries` stands at 679 in
`.claude/tests/floors.conf` and in the hand-copied table in
`.claude/tests/selftest.test.sh` (line 531 at `f53b2d0`). GREEN raises both, in
the same commit, to the executed count it measures with
`bash scripts/selftest.sh boundaries` (expected 679 plus what RED adds: 1 for
AC-1, 2 per `k_readable` for AC-2, so 684 if RED adds nothing else), with a
dated comment in `floors.conf` in the form the HARNESS-102 entries use.
`.claude/harness/VERSION` goes from `121 (2026-11-11)` to `122` with the real
calendar date of the change: `check-boundaries.sh` refuses an upstream harness
change that does not bump it.

**C-6. Oracle partition.** Both criteria are **mechanical**: pin the text and
the counts exactly, invent nothing. The remedy wording in C-1 is **settled**
for RED - read it out; if RED finds a remedy in it that the scanner does not
in fact accept, that is an amendment to C-1 in place with the measurement, and
if it contradicts AC-1's wording it stops and goes to the user.

**C-7. Changed signatures: none.** No function, option or output format
changes; one message string gains a sentence. Callers of that string: the
`boundaries` suite, which today matches it only by the word `unreadable`
(`k_unreadable`), so no existing assertion changes.

**C-8. Commands.**

    bash scripts/selftest.sh boundaries
    bash scripts/attest.sh -- bash scripts/selftest.sh boundaries
    bash scripts/gates.sh --fast

## Deferred verifications

The budget is `rules.md`, "Mutation work per story". Each entry runs through
`scripts/mutate.sh` against the one suite that holds its assertion. C-4 applies
to what is pasted here: the assertion-name lines and the summary line, never
the step 2a message line.

- **DV-1, the defect put back (AC-1).** With the appended sentence deleted from
  the step 2a message, the message is again the one that leaves cause 3
  without a remedy, and AC-1's assertion **must** fail: `boundaries` reports
  exactly 1 failed, and it is that assertion. RED cannot run this: the
  sentence is not there to delete. **Owner: GATES.**

      bash scripts/mutate.sh scripts/check-boundaries.sh 's/ For a hidden head: .*lines of their own\.//' -- bash scripts/selftest.sh boundaries

  **Result (GATES, 2026-11-13, orchestrator):** as predicted - exactly 1
  failed, the AC-1 assertion; the file was restored and verified.

      === mutate: scripts/check-boundaries.sh (1 line(s) changed by s/ For a hidden head: .*lines of their own\.//) ===
      FAIL HARNESS-103 AC-1: a closed fence holding an example head for the next id: exactly one FAIL, it says ## Regressions is unreadable, and it ends with the kept remedy sentence followed by the remedy for a hidden head
      boundaries: 684 passed, 1 failed
      === mutate: command exited 1; restored (verified byte-for-byte against .claude/state/mutations/scripts_check-boundaries.sh.20261113T001452Z.746975.bak) ===

  `bash scripts/mutate.sh --check`: no stranded mutation.

- **DV-2, the two assertions that pass on arrival (AC-2).** The scanner
  already accepts both rewritten examples, so both `k_readable` cases are
  green the moment they are written. One mutation earns both: with the head
  pattern's start-of-line anchor and its three optional spaces removed, a
  head-shaped text is head-shaped anywhere in a line, and both AC-2 cases
  **must** fail (measured on the extracted `adj_scan` at `f53b2d0`: fixture
  (a) then scans `unreadable`; fixture (b) then scans a new `head R-3` with no
  record). Many other `boundaries` assertions will fail with them; what is
  owed is that both AC-2 names are among the failures. The code this mutates
  exists in RED, so RED runs it and pastes the result here. **Owner: RED.**

      bash scripts/mutate.sh scripts/check-boundaries.sh 's/hre = "^ ? ? ?((/hre = "((/' -- bash scripts/selftest.sh boundaries

  **DV-2 result (RED, 2026-11-12, test-developer on claude-opus-5-5).** Run
  exactly as above, after the AC-1 and AC-2 cases were written. It changed one
  line, line 1175. The suite reports 5 failed: the AC-1 assertion (red anyway in
  RED) and all four assertions from the two AC-2 `k_readable` calls. Fixture
  (a) scanned unreadable (`1 1 non-zero`) and fixture (b) gave one FAIL that is
  not the unreadable one (`0 1 non-zero`), which matches the scan the story
  predicted. One difference from the story's expectation: no other `boundaries`
  assertion failed under this mutation, where the story said many would. That
  makes the earning narrower, not weaker. `mutate.sh` restored the file and
  checked it byte for byte, and `mutate.sh --check` reports no stranded
  mutation. Both AC-2 names start `HARNESS-102 HARNESS-103 AC-2` because
  `k_readable` adds the `HARNESS-102` prefix to the tag it is given. Excerpt
  of the full log (the mutation header, the block-3k failures, the summary and
  the restore):

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/hre = "^ ? ? ?((/hre = "((/) ===
  1175 -       hre = "^ ? ? ?((####?#?#? |- )([*][*])?|[*][*])" p "-[0-9]+([^0-9]|$)"
  1175 +       hre = "((####?#?#? |- )([*][*])?|[*][*])" p "-[0-9]+([^0-9]|$)"

  HARNESS-102: a new ## Regressions or ## Amendments entry carries an adjudication record (block 3k)
    FAIL HARNESS-103 AC-1: a closed fence holding an example head for the next id: exactly one FAIL, it says ## Regressions is unreadable, and it ends with the kept remedy sentence followed by the remedy for a hidden head
         expected: 1 1 1
         actual:   1 1 0
    FAIL HARNESS-102 HARNESS-103 AC-2: twin: the example head in the closed fence indented four spaces, as the message advises: the ok line for ## Regressions
         expected: 1
         actual:   0
    FAIL HARNESS-102 HARNESS-103 AC-2: twin: the example head in the closed fence indented four spaces, as the message advises: no unreadable FAIL, no FAIL at all, exit 0
         expected: 0 0 0
         actual:   1 1 non-zero
    FAIL HARNESS-102 HARNESS-103 AC-2: twin: the example head quoted inline in a sentence of prose with no fence, as the message advises: the ok line for ## Regressions
         expected: 1
         actual:   0
    FAIL HARNESS-102 HARNESS-103 AC-2: twin: the example head quoted inline in a sentence of prose with no fence, as the message advises: no unreadable FAIL, no FAIL at all, exit 0
         expected: 0 0 0
         actual:   0 1 non-zero

boundaries: 680 passed, 5 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/wizardly-nash-14c13c/.claude/state/mutations/scripts_check-boundaries.sh.20261112T233041Z.625941.bak) ===
  1175:       hre = "^ ? ? ?((####?#?#? |- )([*][*])?|[*][*])" p "-[0-9]+([^0-9]|$)"
```

Not owed, and stated so that nobody adds one: a probe against a real line of
the tree. This story changes the text of a refusal, not the rule that decides
what is refused (C-2); HARNESS-102's own DV-2 probed that rule against a real
story file. The one orchestrator mutation `/advance-story` asks for after
GREEN can be DV-1 itself.

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

Planned by `bash scripts/plan.sh write HARNESS-103` from `.claude/harness/models.conf`.
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

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

- PLANNED (2026-11-12, `/plan-story`): `lead-po`, planned `fable`, resolved **claude-fable-5-2** (Fable 5.2). Dispatched as a subagent by the orchestrating session; no override was reported to it, and the agent declares `model: fable`.
- No departure from the plan. Both criteria are mechanical (Contract, C-6): pin the text and the counts exactly.

## Out of scope

- **`adj_scan` and what step 2a refuses.** No change to the scan, to the head
  or record patterns, or to which sections are unreadable. If the message's
  new advice turns out not to match the scanner, the message is what changes.
- **A separate message per cause.** The scan prints one `unreadable` line and
  does not say which of the three causes it met; splitting it is a different
  story. One message keeps naming all three causes and all the remedies.
- **Every other message of block 3k** (steps 3 and 4, the step 5 note, the
  step 6 ok line), and blocks 3d and 3g.
- **`docs/backlog/stories/HARNESS-102.md`.** It quotes the old message as a
  record of what was built then. Not edited.
- **`story-authoring`, `sections.md`, the `new-story.sh` template, `rules.md`,
  `CLAUDE.md`.** None paraphrases these remedies (Context has the search), and
  this story adds no advice about fenced examples to any of them.
- **The script's own header comment above `adj_scan`.** It describes the scan,
  which does not change.
- **Rewording the existing causes or the existing remedy sentence.** They stay
  byte for byte; AC-1 pins the remedy sentence.
- **An `## Amendments` twin of the AC-1 fixture.** Both sections print the
  same string from the same line; HARNESS-102's cases already show the refusal
  fires in both.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

All cases are at one level: integration. Each builds a fixture repository,
commits a spike story at REVIEW on its own branch, and runs the real
`scripts/check-boundaries.sh` over it, using the existing block-3k harness in
`.claude/tests/boundaries.test.sh`. They sit inside the HARNESS-102 block-3k
describe, after case (f) and before main is put back (C-3). The fixture story
id is T-118, which was unused before this story.

The head-shaped line and the tilde fence marker are held in the variables
`K_HID` and `K_TILDE`. The full expected remedy text (C-1, both sentences) is
held in `K_REMEDY`. No assertion name contains a head-shaped string, a comment
marker or a fence marker (C-4).

| Assertion | What it pins | AC |
|---|---|---|
| `HARNESS-103 AC-1: a closed fence holding an example head for the next id: exactly one FAIL, ...` | one `assert_eq` with three counts, expected `1 1 1`: `k_fails` (every FAIL in the run), `k_unreadable Regressions`, and `k_ends_remedy` (FAIL lines whose END is exactly `K_REMEDY`; an awk fixed-string suffix compare, never a floating grep) | AC-1 |
| `HARNESS-103 AC-1: and the run exits non-zero` | `k_rc` is `non-zero`. Green on arrival, because the section is already refused today. Kept because AC-1 names the exit status. | AC-1 |
| `HARNESS-102 HARNESS-103 AC-2: twin: the example head in the closed fence indented four spaces, ...` (two assertions from `k_readable`) | the ok line for `## Regressions`; and `0 0 0` for unreadable FAILs, all FAILs and the exit status | AC-2 (a) |
| `HARNESS-102 HARNESS-103 AC-2: twin: the example head quoted inline in a sentence of prose with no fence, ...` (two assertions from `k_readable`) | the same two checks | AC-2 (b) |

DV-1 is the control for AC-1 and belongs to GATES. DV-2 is the control for
AC-2; RED ran it, and its result is under `## Deferred verifications`.

## Handoff: RED -> GREEN

**Command.** `bash scripts/selftest.sh boundaries`. It takes about 27 minutes
on this host (1607 s, measured locally).

**Attested runs** (machine-local records, tree `7b7ef56f9a9dc1122ca908d61e50c511be5d026b`):

    bash scripts/attest.sh -- bash scripts/selftest.sh boundaries
      exit: 1   last: 1 of 1 harness suite(s) FAILED.
      log:  .claude/state/attest-logs/20261112T230253Z.564508.log
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
      exit: 0   last: All required gates passed (0 ran, 5 unconfigured, 0 known).
      log:  .claude/state/attest-logs/20261112T233031Z.625754.log

**The failure, verbatim from the log.** This is the assertion's own line plus
the summary. The step 2a FAIL line is deliberately not pasted (C-4).

```
  HARNESS-102: a new ## Regressions or ## Amendments entry carries an adjudication record (block 3k)
    FAIL HARNESS-103 AC-1: a closed fence holding an example head for the next id: exactly one FAIL, it says ## Regressions is unreadable, and it ends with the kept remedy sentence followed by the remedy for a hidden head
         expected: 1 1 1
         actual:   1 1 0

boundaries: 684 passed, 1 failed

assertion floors: all 1 suite(s) met their declared floor (684 assertions executed, 679 declared).
1 of 1 harness suite(s) FAILED.
```

**Why this is the right failure.** The fixture is refused today, exactly once
and as unreadable (the first two counts are already 1). The only count that is
wrong is the third: no FAIL line ends with the C-1 text, because the hidden-head
sentence is not there yet. The suite has exactly one failure, and it is this
assertion. Nothing else broke.

**The floor count.** The floors line above says 684 executed, but that matches
the passed count, not passed plus failed. In the DV-2 run it said 680, again
equal to the passed count. So the floor line appears to count passes only.
The suite holds 685 assertions: 684 + 1 here, 680 + 5 under DV-2. RED added 6 assertions: 2 for AC-1
(because the exit-status assertion was kept) and 4 for AC-2. That is one more
than C-5's "684 if RED adds nothing else". GREEN should take the number it
measures. Expect 685 executed, and the floor in `floors.conf` and in
`selftest.test.sh` should go from 679 to that number.

**Files touched.**
- `.claude/tests/boundaries.test.sh`: the new cases only, inserted after case (f).
- `docs/backlog/stories/HARNESS-103.md`: `## Test plan`, this handoff, and the
  DV-2 result.

**Shape the tests pin.** There is no module or export; the interface is the
output of `scripts/check-boundaries.sh`. For the AC-1 fixture, the tests pin:
- exactly one line beginning `FAIL  ` in the whole run;
- that line contains `T-118`, `## Regressions` and `unreadable`;
- that line ENDS with exactly the text below, with no trailing space or
  character after the final period:

      Close the comment, close the fence, or quote the opener together with its closer, or name it in words. For a hidden head: move the entry's head outside the comment or fence, or, if it is only an example, indent it four spaces or quote it inline; and write a fence's markers on lines of their own.

  That is C-1, read out unchanged. It is one space after `in words.` and the
  appended sentence, all inside the existing `problem` string;
- a non-zero exit.

For the two AC-2 fixtures, the tests pin the existing ok line
`ok    ## Regressions: every new entry carries an adjudication record`, no FAIL
line at all, and exit 0.

**What the tests do not constrain.** Everything in the message before
`Close the comment` (the cause text) is held only by the `unreadable` needle.
They also do not check that the edit stays on line 1230. C-1 requires that
for the sake of `sigpipe.test.sh`, and that suite, not these tests, catches a
moved line.

**Passed on arrival.** Five assertions:
- the AC-1 exit-status assertion. It is green because the fixture is already
  refused; the `k_fails` count in the main AC-1 assertion would catch the same
  break;
- the four AC-2 assertions. DV-2 earns them, and RED ran it: all four go red
  under the anchor-removal mutation, and the file was restored byte for byte.
  The output is under `## Deferred verifications`, DV-2.

**Negative controls, expected values.** This suite does not fail at import, so
the controls ran in RED. Only DV-1 could not run.

| Control | Threshold | Expected | Measured |
|---|---|---|---|
| AC-1 assertion, without the new sentence (today's tree) | `1 1 1` | `1 1 0` | `1 1 0` (RED run, local) |
| DV-1: the appended sentence deleted after GREEN | `1 1 1` | `1 1 0`, and `boundaries` reports exactly 1 failed | **not run by RED.** The sentence does not exist yet, so there is nothing to delete. Owner: GATES |
| DV-2: head-pattern anchor removed, fixture (a) | `0 0 0`, ok line 1 | unreadable | `1 1 non-zero`, ok line 0 (local) |
| DV-2: head-pattern anchor removed, fixture (b) | `0 0 0`, ok line 1 | a new unrecorded head, not unreadable | `0 1 non-zero`, ok line 0 (local) |

**Timings.** Every timing here is from a local run; none comes from CI. The
suite has no per-test timeout.

**Findings that may change the approach.** None for the implementation. Two
cosmetic points:
- `k_readable` puts `HARNESS-102` before the tag it is given, so the AC-2
  names read `HARNESS-102 HARNESS-103 AC-2: ...`. That is expected, not a bug.
- DV-2 broke fewer assertions than the story predicted (only the five above).
  This changes no assertion.

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

## Diff review

Round 1 (2026-11-13): a fresh `lead-po` on the DIFF-REVIEW row, planned
`fable`, resolved **Fable 5.2 (`claude-fable-5-2`)**. It changed no file.
Its report, as returned:

**What this change does.** It appends one sentence to the single refusal that
block 3k step 2a of `scripts/check-boundaries.sh` prints when a Regressions or
Amendments section is unreadable, saying how to fix the third cause (a
head-shaped line hidden in a comment or fence). The rule that decides what is
refused (`adj_scan`) is untouched. Six assertions are added to `boundaries`,
the two floor records go 679 -> 685, VERSION 121 -> 122.

**Checked:** the whole diff, `adj_scan` and step 2a, the block-3k helpers and
the story's own sections; `adj_scan` was extracted and each remedy run against
it on the reviewer's own inputs.

No findings.

**Each remedy the sentence gives is accepted by the scanner** (reviewer's own
inputs): the baseline (recorded R-1, closed tilde fence holding the example
head) scans unreadable; the line indented four spaces, in a fence or a
comment, scans readable; the head in inline code mid-sentence, at line start
or in a list item, scans readable; the head moved outside the fence is seen as
a head and judged (with a record: readable; without: the ordinary no-record
refusal, as C-1 says); two one-line backtick fences around the head scan
unreadable, and the same content as two proper three-line fences scans
readable with the head judged.

**The two untested remedies need no tests.** They are existing scanner
behaviour, not something this diff adds; the diff adds only message text,
which AC-1 pins whole with an end-of-line suffix compare. Moving the head
outside is already pinned by the HARNESS-102 head-spelling cases and the
"head also outside" twin; markers on their own lines is pinned only
indirectly, held by reproduction, and outside AC-2's scope.

**Tests and floors.** `k_ends_remedy` is a fixed-string suffix compare joined
with `k_fails` and `k_unreadable` in one `assert_eq`; it cannot pass with the
sentence missing, reordered or followed by anything, and DV-1's result (684
passed, 1 failed, that assertion) agrees. AC-2 is earned by DV-2. 685 in both
floor records matches; the one over the Contract's 684 is the exit-status
assertion C-3 allowed. No assertion name carries a head-shaped string, fence
or comment marker. The appended sentence has no backtick, dollar or double
quote and adds no line.

**The story's own sections (C-4).** Regressions and Amendments hold only the
template comment, so nothing is judged. Deferred verifications has no comment
marker and the step 2a line is pasted nowhere; DV-1's block is indented six
spaces (inside a list item), so the section's pasted-result check passes on
DV-2's fence. Notes are plain bullets. Not checked by the reviewer: the full
self-test and gates (as instructed), and the gate-stamp check, which did not
print with the story at GATES.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-13T00:53:17Z
    commit: d6ae595
    tree:   7cc11739526deea33b9b4a99b4392a6177a54733
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

- RED verified by the orchestrator (2026-11-12): `attest.sh check -- bash scripts/selftest.sh boundaries` was `fresh` (exit 1, tree 7b7ef56); its log holds exactly one FAIL, the HARNESS-103 AC-1 assertion (`1 1 0` against `1 1 1`). Not re-run. Test-developer resolved to claude-opus-5-5.
- GREEN verified by the orchestrator (2026-11-12): `attest.sh check` `fresh` for `bash scripts/selftest.sh boundaries` (exit 0, 685 passed, tree db845ff) and `bash scripts/gates.sh --fast` (exit 0). Not re-run. Feature-developer resolved to claude-opus-5-5.
- Self-test at GATES -> REVIEW (2026-11-13), run by the orchestrator directly (attested, not dispatched), as `bash scripts/attest.sh -- env SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`; `attest.sh check` with those words: `fresh`, tree db845ff.
  - header: `selftest: --changed — 15 of 34 suite(s) selected: boundaries ci-local dispatch doctor grep-count host-load lib plan procedure refresh run-lock selftest sigpipe story worktree`
  - `exit: 0`, `last: 15 harness suite(s) passed.`, `duration: 2145s`
- DV-1 run by the orchestrator in GATES; full gates attested `fresh`, exit 0 (all five gates unconfigured). Diff review round 1 resolved to claude-fable-5-2: Ship, no findings.
