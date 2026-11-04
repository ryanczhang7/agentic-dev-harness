---
id: HARNESS-092
title: Every cases.md pointer in rules.md names a heading that exists
slug: every-cases-md-pointer-in-rules-md-names
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-092-every-cases-md-pointer-in-rules-md-names
depends_on: [HARNESS-094, HARNESS-095]      # the fast pre-PR self-test goes first (user decision, 2026-11-04); both must be DONE
touches: [.claude/tests/rules-trim.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

HARNESS-087 (PR #176) moved the worked cases out of `.claude/harness/rules.md`
into `.claude/skills/tdd-cycle/reference/cases.md` and left eight pointers
behind, each of the shape `(the case: \`tdd-cycle\`, \`reference/cases.md\`,
"<heading>")`, where `<heading>` is meant to be the text of a `## ` heading in
cases.md. `.claude/tests/rules-trim.test.sh` checks that the moved needles sit
under `## ` headings of cases.md and that each of the four sections a case
left carries the fixed string `reference/cases.md`. **It does not read the
quoted heading text at all** (`POINTER='reference/cases.md'` is the whole
check, `rules_trim_problems`, the `$POINTED` loop). Renaming a heading in
cases.md, or mistyping one in rules.md, leaves a pointer that resolves to
nothing, and nothing says so. Verified on the shipped tree before this story
was cut: the only reference to `reference/cases.md` in `.claude/tests` is that
fixed-string check.

The eight pointers today (rules.md at release 107, lines 67, 101, 208, 226,
246, 269, 299, 308) point at seven distinct headings of cases.md (line 10, 23,
34, 56, 82, 97, 106), and three of them are awkward for a parser: two
heading texts contain double quotes (`"The default model" against itself`,
`Four private copies of "a source module"`), one contains `$`
(`A backup that went to an unset $TMPDIR`), and six of the eight wrap across
two lines of rules.md, the quote opening on one line and closing on the next.

The check lives in `rules-trim.test.sh`, the suite that already owns this
relationship between the two files, and is a rule over the tree: so, as
`rules.md` "A rule is probed against the tree it judges" requires, the story
carries a probe against a real line of both files (`## Deferred
verifications`), beside the fixtures.

Required gate that would fail if this story's artifact broke: none is
configured in this repository; the artifact is judged by the self-test,
`bash scripts/selftest.sh rules-trim`, which CI runs in full on the PR.

## Acceptance criteria

- **AC-1** — Given this repository's `rules.md` and `cases.md`, when
  `rules_trim_problems` runs over the real tree, then it prints no pointer
  line: every pointer's quoted text is a `## ` heading of cases.md. *Control:*
  DV-1 and DV-2 rename a real heading and a real pointer with `mutate.sh` and
  this assertion goes red naming the text; a parser that extracts no pointers
  is caught by AC-6.
- **AC-2** — Given a rules.md pointer whose quoted text is not exactly a `## `
  heading of cases.md, when `rules_trim_problems` runs, then it prints exactly
  one line `rules.md: points at "<text>", not a ## heading of cases.md`, with
  the quoted text verbatim. *Controls:* the compliant fixture prints nothing;
  a quoted text that is a strict **prefix** of a heading (`Four needles` for
  `Four needles that could not fail`) is reported, and so is one that differs
  in case only.
- **AC-3** — Given a pointer that wraps across two lines of rules.md (the
  opening `"` on one line, the closing `")` on the next, as six of the eight
  real ones do), when it resolves, nothing is printed; and when the wrapped
  text does not resolve, it is reported as one line with the text joined by a
  single space, as C-2's "still carries" needles are joined. *Control:* the
  same text on one line behaves identically in both cases.
- **AC-4** — Given a heading whose text contains double quotes or a `$`
  (`"The default model" against itself`, `Four private copies of "a source
  module"`, `A backup that went to an unset $TMPDIR`), when a pointer quotes
  it whole, it resolves. *Control:* a pointer that drops the inner opening
  quote (`The default model" against itself`) is reported with that exact
  text, so the inner quotes are read as part of the text and not as its end.
- **AC-5** — Given a `## ` line inside a ``` fence of cases.md, when a pointer
  names its text, then it is reported: a fenced `## ` line is not a heading,
  as `placed` already holds for the needles. *Control:* the same line outside
  the fence resolves.
- **AC-6** — Given this repository's rules.md, when the pointer texts are
  extracted in file order, then they are exactly the eight listed in C-1 of
  the Contract, in that order - the real-tree assertion of AC-1 cannot pass by
  finding nothing. *Control:* dropping one pointer from the list makes this
  assertion red (it is an equality over the whole list).

## Contract

**Writes:** `.claude/tests/rules-trim.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria do not inherit that: a change to
one of them goes through `## Amendments`.

**C-1. The pointer grammar, and the settled list.** A pointer is read from the
JOINED text of rules.md (`joined`, every line trimmed and joined with one
space, the same `J` the "still carries" check reads). Each occurrence of the
fixed string `` `reference/cases.md`, " `` (backtick, path, backtick, comma,
space, double quote) opens a pointer; its text runs to the first `")`
(double quote, close paren) after it, exclusive. Inner `"` and `$` are
ordinary characters of the text: no heading contains `")`, and that is the
whole reason the terminator is two characters. The eight texts on the real
tree, in file order, which RED pins as a `POINTERS` list beside `NEEDLES`:

| # | rules.md line(s) | text |
|---|---|---|
| 1 | 67-68 | `Four private copies of "a source module"` |
| 2 | 101 | `"The default model" against itself` |
| 3 | 208 | `Four needles that could not fail` |
| 4 | 226-227 | `Three guards green over a tree they could not see` |
| 5 | 246-247 | `Three guards green over a tree they could not see` |
| 6 | 269-270 | `Negative zero: narrow the generator, not the comparison` |
| 7 | 299-300 | `A backup that went to an unset $TMPDIR` |
| 8 | 308 | `HARNESS-014: eighteen mutations, no defect` |

A text **resolves** when some line of cases.md, outside a ``` fence (the
`is_fence` toggle `placed` uses), is exactly `## ` followed by the text - a
whole-line compare, so a prefix, a suffix and a case difference all fail.
A heading pointed at twice (4 and 5) is one heading; a pointer that fails is
reported once per occurrence.

**C-2. The guard.** `rules_trim_problems` gains one block, after the
`$POINTED` loop and before the cases.md half, so that its lines come out in
that position in a multi-fault report: load cases.md's `## ` headings outside
fences into a list (one pass, pure bash, as the rest of the file), then walk
the pointers of `J` and print `rules.md: points at "%s", not a ## heading of
cases.md` for each that does not resolve. Pure bash string ops over `J`
(`${J#*"$OPEN"}`, `${rest%%'")'*}`), no `grep`, no `sed`: the texts contain
`"` and `$`, and the file's own rule is no fork per check. The whole-tree
assertion "rules_trim_problems over the real tree prints nothing" stays and
now covers this too. The pinned-lists assertion (`"8 32 11 4"`) grows a fifth
number, `8`, the length of `POINTERS`.

**C-3. The fixtures.** `compliant_fixture` is compliant **by construction**,
and today its pointers are prefixes of its headings (`"Four private copies"`
against `## Four private copies of "a source module"`, `"The default model"`,
`"Four needles"`, `"HARNESS-014"`). Under AC-2's prefix control those are
faults, so RED rewrites the fixture's four pointers to quote the fixture's
headings whole - keeping the wrapped one (`"Four private\ncopies ..."`)
wrapped, because AC-3's resolving case needs a real wrapped pointer in the
compliant fixture - and adds one fixture pointer quoting the `$TMPDIR`
heading and one quoting `"The default model" against itself`, so AC-4's
resolving case runs on the compliant fixture before any mutation. AC-2..AC-5's
failing cases are `fresh_case` fixtures with one site changed by `subst`, one
fault each, as the existing cases are. A `## ` line inside the fixture
cases.md's existing fence (`## a fenced comment, not a heading`) is AC-5's
subject.

**C-4. Not written.** `rules.md` and `cases.md` are not changed by this
story: every real pointer already resolves (checked by hand when the story
was cut, table above). The pointer syntax in `rules.md` is not changed
either; a pointer written in some other shape is not a pointer to this check,
and that is accepted and said in the test file's header.

**C-5. Floors.** `floor | rules-trim | 30` in `floors.conf` and the hand copy
`rules-trim 30` in `selftest.test.sh` (line 552) rise in RED to the executed
count (expected about 30 + 14). `VERSION` bumps in GREEN to the number after
whatever the file holds when GREEN is reached (107 today; HARNESS-091 and
HARNESS-093 are planned alongside and take the next free number each).

**C-6. Oracle partition.** All **mechanical**: exact message lines, an exact
list equality (AC-6), and whole-line heading compares. The list in C-1 is
**settled**: RED reads it out of rules.md and confirms it against the file
rather than deriving a different grammar.

## Deferred verifications

- **DV-1, defect put back (AC-1), a real line of cases.md.** With one real
  heading renamed - `bash scripts/mutate.sh
  .claude/skills/tdd-cycle/reference/cases.md 's/^## Four needles that could
  not fail$/## Four needles that could not fall/' -- bash
  .claude/tests/rules-trim.test.sh` - the real-tree assertion MUST go red
  with exactly one pointer line, `rules.md: points at "Four needles that could
  not fail", not a ## heading of cases.md`, and nothing else in the suite
  moves (the needle `IMPLAUSIBLE: sed -i option` is still under a `## `
  heading, since the renamed line is still one). This is the rename the story
  exists to catch. RED cannot own it: the guard it would exercise is what RED
  is writing, and in RED the real-tree assertion is red for the right reason
  only once the guard exists. **Owner: GATES.**
- **DV-2, the rule over the tree it judges, a real line of rules.md.** With a
  real wrapped pointer broken on its second line - `bash scripts/mutate.sh
  .claude/harness/rules.md 's/^  they could not see")\.$/  they could not
  see.")./' -- bash .claude/tests/rules-trim.test.sh` (line 227; the text
  becomes `Three guards green over a tree they could not see.`) - the
  real-tree assertion MUST go red naming that joined text, and AC-6's list
  equality MUST go red too (the extracted text differs); the second real
  pointer to the same heading (246-247) still resolves, so exactly one
  pointer line is printed. This probes the wrap and the real file's spelling
  at once, which no fixture can. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-092` from `.claude/harness/models.conf`.
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

**Oracle partition:** every criterion is mechanical - exact message lines, whole-line heading compares, and AC-6's list equality. The eight-pointer list in Contract C-1 is settled: RED reads it out of rules.md and confirms it, rather than deriving another grammar.

## Out of scope

- Changing `rules.md` or `cases.md`, their pointer wording, or the pointer
  syntax; adding pointers for sections that have none.
- Checking that the pointed-at section's *content* matches the rule, or that
  every `## ` heading of cases.md is pointed at from somewhere.
- Pointers in any file other than `rules.md` (SKILL.md's `## Details` entry
  is AC-4 of HARNESS-087, unchanged).
- The HARNESS-087 cap (370 lines) and its other checks.

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

