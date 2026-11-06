---
id: HARNESS-092
title: Every cases.md pointer in rules.md names a heading that exists
slug: every-cases-md-pointer-in-rules-md-names
epic: 
type: feature
status: in-progress
phase: GREEN
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

*Amended in RED (test-developer, 2026-11-06), an addition, not a change:* an
opener with no `")` anywhere after it ends the scan and yields no text. The
block was silent on it, and `${rest%%'")'*}` with no terminator would return
the whole rest of the file as one "text". Nothing on the real tree is so
shaped; if one were written, AC-6's list equality is what would see it. The
eight texts above were confirmed by running the C-2 string ops over this
tree's rules.md (release 113) - they come out exactly as tabled.

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

*Amended in RED (test-developer, 2026-11-06).* Rewriting the fixture's
`"The default model"` pointer whole already makes it quote
`"The default model" against itself`, so "adds one quoting it" was read as a
SECOND pointer to that heading, placed in `# Phase permissions` (not one of
the four `POINTED` sections, so it cannot mask the `pointer-moved` case). It
gives the compliant fixture the real tree's "one heading pointed at twice"
shape (rules.md 4 and 5). The `$TMPDIR` pointer sits on the continuation of
the `.claude/state/**` bullet, wrapped twice and indented, its opener ending
one line - the shape of rules.md 299-300. So the fixture has six pointers,
pinned as `FIX_POINTERS`. One consequence for an existing case: with no
cases.md every fixture pointer is unresolvable, so `cases-absent`'s expected
report now begins with those six `points at` lines (C-2's order) before the
eleven `missing` ones. Its one assertion stays one assertion.

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

- PLANNED, `lead-po` (orchestrator): Fable 5.1 (`claude-fable-5-1`). RED, `test-developer`: `opus` (Opus 5.5, `claude-opus-5-5`), the agent's own `model:`; no override. 2026-11-06.
- GREEN: no dispatch. A verified no-op plus the VERSION bump, by the orchestrator (Fable 5.1, `claude-fable-5-1`), as decision 3 plans. 2026-11-06.
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

All in `.claude/tests/rules-trim.test.sh`, one level (the suite IS the guard:
a rule over two prose files, pure bash). Run: `bash scripts/selftest.sh rules-trim`.

- pinned lists `"8 32 11 4 8"` - `POINTERS` holds C-1's eight texts (C-2).
- real tree, AC-6 - `pointer_list "$REPO_ROOT"` equals `POINTERS`, whole list, in order.
- real tree, AC-1 - no `rules.md: points at ` line in the real-tree report (and the existing whole-report-empty assertion now covers it too).
- fixture, C-3 - the compliant fixture's six pointers extract exactly as `FIX_POINTERS` (wrapped ones joined), and the fixture stays silent.
- AC-2 typo - `"Four needles that could not fial"` is one line quoting it verbatim.
- AC-2 prefix control - `"Four needles"` is reported.
- AC-2 suffix - `"needles that could not fail"` is reported.
- AC-2 case control - `"four needles that could not fail"` is reported.
- AC-2 twice - a failing text at two sites is two identical lines.
- AC-2 heading renamed - `## Four needles that could not fall` in cases.md leaves the pointer reported and nothing else (fixture twin of DV-1).
- AC-3 control - the wrapped pointer joined onto one line resolves.
- AC-3 indented wrap - the second line indented four spaces still resolves (trimmed join).
- AC-3 wrapped failing - reported as one line, joined by one space.
- AC-3 control - the same failing text on one line, reported identically.
- AC-4 control - dropping the inner opening quote is reported as `The default model" against itself`.
- AC-4 - dropping the inner closing quote ends the text at the first `")`: `Four private copies of "a source module`.
- AC-4 - `unset TMPDIR` (no `$`) is reported: the `$` is part of the heading.
- AC-4 - `unset $HOME` is reported as written: no expansion.
- AC-5 - a pointer naming the fenced `## a fenced comment, not a heading` is reported.
- AC-5 control - the same line with the fence removed resolves.
- C-2 order - a still-carries, a pointer and a cases.md fault come out in that order.
- `cases-absent` (existing, expected value extended) - six pointer lines, then the eleven needles.

## Handoff: RED -> GREEN

Test developer, 2026-11-06, model Opus 5.5 (`claude-opus-5-5`, from the
agent definition's `model: opus`; no override applied). Tree: branch head
`9ec3543` plus this RED's uncommitted diff.

**This story is test-only (Notes, decision 3).** The guard is written in the
suite, every real pointer already resolves, so every new assertion PASSED ON
ARRIVAL. That is the planned shape, not a missing RED. "Watched to fail" is
earned by mutation: one single-assertion mutation below, then DV-1 and DV-2
at GATES. **GREEN is a verified no-op plus the `VERSION` bump** (`113
(2026-11-06)` today -> the next free number when GREEN is reached): no
production file is involved, and nothing in `rules.md` or `cases.md`
changes (C-4).

**Command:** `bash scripts/selftest.sh rules-trim` (or directly
`bash .claude/tests/rules-trim.test.sh`).

**Files touched**
- `.claude/tests/rules-trim.test.sh` - header note 43-62; `OPEN`, `CLOSE`,
  `POINTERS` 147-159; helpers `pointer_texts`, `h2_headings`, `resolves`,
  `pointer_list` 265-302; the guard block in `rules_trim_problems` 341-348
  (after the `$POINTED` loop, before the cases.md half); fixture pointers
  rewritten and added inside `compliant_fixture` (406-553); `FIX_POINTERS`
  556-566; pinned-lists assertion 598-601; real-tree AC-6 and AC-1 619-622;
  fixture extraction 632-633; `cases-absent` expected report 714-723; the
  five HARNESS-092 describes 756-866.
- `.claude/tests/floors.conf` - `floor | rules-trim | 30` -> `50`, dated
  note at the foot.
- `.claude/tests/selftest.test.sh` - table line 552 `rules-trim 30` -> `50`.
- this story: `## Contract` C-1 and C-3 amended in place (below), `## Test
  plan`, this section.

**Export shape.** None: no module is imported; the suite sources only
`_lib.sh`. The message line is pinned byte for byte:
`rules.md: points at "<text>", not a ## heading of cases.md`.

**`POINTERS`, as pinned** (C-1, confirmed by running the C-2 string ops over
rules.md at release 113):

    Four private copies of "a source module"
    "The default model" against itself
    Four needles that could not fail
    Three guards green over a tree they could not see
    Three guards green over a tree they could not see
    Negative zero: narrow the generator, not the comparison
    A backup that went to an unset $TMPDIR
    HARNESS-014: eighteen mutations, no defect

**New assertions, by AC** (20 new; one existing expected value extended)
- C-2 / AC-6: pinned lists `"8 32 11 4 8"` (existing assertion, fifth number).
- AC-6: real-tree `pointer_list` equals `POINTERS` (1).
- AC-1: real tree prints no `points at` line (1); the existing "prints
  nothing" assertion now covers it too.
- C-3 (AC-3 and AC-4 resolving cases): the compliant fixture's six pointers
  extract exactly as `FIX_POINTERS` (1), and the fixture stays silent
  (existing assertion).
- AC-2 (6): typo; strict prefix `Four needles`; strict suffix; case only;
  one failing text at two sites gives two lines; heading renamed in cases.md
  (fixture twin of DV-1).
- AC-3 (4): one-line control resolves; indented wrap resolves; wrapped
  failing text is one line joined by one space; the same failing text on one
  line is reported identically.
- AC-4 (4): inner opening quote dropped -> `The default model" against
  itself`; inner closing quote dropped -> the text ends at the first `")`;
  `unset TMPDIR` reported; `unset $HOME` reported as written (no expansion).
- AC-5 (2): a pointer at the fenced `## a fenced comment, not a heading` is
  reported; control with the fence removed resolves.
- C-2 order (1): still-carries line, then pointer line, then cases.md line.
- `cases-absent` (existing, count unchanged): its report now opens with the
  six fixture pointer lines (C-3 amendment).

**Measured count:** `rules-trim: 50 passed, 0 failed` - 50 EXECUTED (30
before + 20), Windows host (Git for Windows bash 5.3.15), local. About 11 s
plain. No timeouts are involved (bash suite).

**Attest records**
- `bash scripts/attest.sh -- bash scripts/selftest.sh rules-trim` - tree
  `c2af911087524f17756c8a6d05d5660af107a148`, exit 0, `last:     1 harness
  suite(s) passed.`, log
  `.claude/state/attest-logs/20261106T165835Z.441813.log` (its tail:
  `rules-trim: 50 passed, 0 failed` and `assertion floors: all 1 suite(s)
  met their declared floor (50 assertions executed, 50 declared).`).
- `bash scripts/attest.sh -- bash scripts/gates.sh --fast` - same tree, exit
  0, `last:     All required gates passed (0 ran, 5 unconfigured, 0
  known).`, log `.claude/state/attest-logs/20261106T165851Z.442303.log`.
  Shape as expected: every gate unconfigured, nothing ran.
- `bash scripts/check-sigpipe.sh`: `scanned 62 shell file(s), 57 with
  pipefail, 0 finding(s)`. `bash scripts/check-grep-count.sh`: `scanned 62
  shell file(s), 0 finding(s)`.

**The one mutation (RED's own).** Remove the fence toggle from
`h2_headings` only (the identical line in `placed` is untouched, by the sed
address range). Predicted catch: exactly one assertion, "AC-5: a pointer
naming a ## line inside a fence of cases.md is reported" - a fenced `## `
line becomes a heading, and no other case points at one. Observed: 49
passed, 1 failed, that one. It was run twice: the first run's output was
filtered through `grep` for display, so it was run again unfiltered and that
run is pasted. Same result both times.

```
=== mutate: .claude/tests/rules-trim.test.sh (1 line(s) changed by /^h2_headings() {/,/^}/s/    if is_fence "\$l"; then fence=\$((1 - fence)); fi/    : no fence toggle/) ===
  284 -     if is_fence "$l"; then fence=$((1 - fence)); fi
  284 +     : no fence toggle

=== mutate: running bash .claude/tests/rules-trim.test.sh ===

  the pinned lists are the Contract's, whole

  the real tree (red until GREEN moves the cases)

  the fixture: compliant by construction

  AC-1  the cap

  AC-2  every rule opener stays, exactly

  AC-3  every case moves to cases.md, under a heading, and is pointed at

  AC-4  SKILL.md lists cases.md under ## Details

  HARNESS-092 AC-2  a pointer's text is exactly a ## heading

  HARNESS-092 AC-3  a wrapped pointer is read joined

  HARNESS-092 AC-4  inner quotes and $ are part of the text

  HARNESS-092 AC-5  a ## line inside a fence is not a heading
    FAIL AC-5: a pointer naming a ## line inside a fence of cases.md is reported
         expected: rules.md: points at "a fenced comment, not a heading", not a ## heading of cases.md
         actual:   

  HARNESS-092 C-2  where the pointer lines stand in a report

rules-trim: 49 passed, 1 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests_rules-trim.test.sh.20261106T165814Z.441271.bak) ===
  284:     if is_fence "$l"; then fence=$((1 - fence)); fi
```

`bash scripts/mutate.sh --check` afterwards: `mutate: no stranded mutation;
nothing of a previous run is in the tree.`

**Negative controls.** Unlike an import-failing RED, every control here
EXECUTED against the guard as written, so these values are measured, not
claimed. Every expected value is an exact line; there is no threshold.

| Control | Expected | Measured (local, this tree) |
|---|---|---|
| compliant fixture | empty report | empty |
| fixture extraction | `FIX_POINTERS`, 6 texts | equal |
| real-tree extraction (AC-6) | `POINTERS`, 8 texts | equal |
| strict prefix `Four needles` | one `points at "Four needles"` line | that line |
| case only | one line, the lower-case text | that line |
| one-line twin of the wrapped pointer | empty, and the same line as wrapped when failing | empty / same line |
| inner opening quote dropped | `points at "The default model" against itself"` line | that line |
| fence removed (AC-5) | empty | empty |
| fence toggle removed from `h2_headings` (mutation) | exactly AC-5's assertion red | 49 passed, 1 failed, AC-5 |

**Deferred verifications.** DV-1 (a real heading of cases.md renamed) and
DV-2 (a real wrapped pointer of rules.md broken on its second line) are
**owned by GATES and were not run in RED**, as directed. I cannot claim
them. Their expected outcomes are as the story writes them: DV-1 one
`points at "Four needles that could not fail"` line and nothing else; DV-2
the real-tree pointer assertion naming `Three guards green over a tree they
could not see.` with AC-6's list equality red too, one pointer line only.
The fixture twin of DV-1 (`heading-renamed`) passes; that is evidence about
the mechanism, not a substitute for the real-line probe.

**Contract amendments (in place, with reasons):**
- C-1: an opener with no `")` after it ends the scan (the block was silent;
  without that guard `%%` would return the rest of the file as one text).
  The C-2 string ops were confirmed to behave as claimed on this host's bash
  5.3; C-2 itself needed no change.
- C-3: "adds one quoting `"The default model" against itself`" became a
  second pointer to that heading in `# Phase permissions`, because the
  rewrite already quotes it whole; the `$TMPDIR` pointer is placed in the
  shape of rules.md 299-300; `cases-absent`'s expected report is extended
  accordingly.

**Not constrained.** There is nothing for GREEN to implement. The
unterminated-opener behaviour is stated but not asserted by any fixture, and
pointers outside the `` `reference/cases.md`, " `` shape are deliberately
invisible (C-4).

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


- PO decisions at PLANNED → RED (orchestrator, 2026-11-06, tree `6b5f3ed`):
  1. **The Contract's settled values re-checked and unchanged:** the eight
     pointers are at rules.md lines 67-68, 101, 208, 226-227, 246-247,
     269-270, 299-300 and 308; the seven headings at cases.md lines 10, 23,
     34, 56, 82, 97 and 106; DV-1's line (`## Four needles that could not
     fail`, 34) and DV-2's (`  they could not see").`, 227) are as written.
  2. **Not already delivered:** `rules-trim.test.sh` has no `points at`
     guard; `POINTER='reference/cases.md'` (line 60) is still the whole
     check.
  3. **Test-only, as HARNESS-091 was:** the guard lives in the suite, so RED
     writes everything in `**Writes:**` except `VERSION`, every new assertion
     passes on arrival (the real tree resolves every pointer), and the law's
     earning is by mutation: RED's own single-assertion mutation, then DV-1
     and DV-2 at GATES. GREEN is a verified no-op plus the `VERSION` bump,
     checked by the orchestrator, not dispatched. `VERSION` holds
     `113 (2026-11-06)`; GREEN takes the next free number.
  4. **Required gate:** none is configured; the `rules-trim` suite judges
     the artifact, and CI runs it in full on the PR. `required_gates: []`
     stays.
  5. `plan.sh conflicts`: CONFLICT with HARNESS-093 and HARNESS-096 on
     `VERSION`, `floors.conf` and `selftest.test.sh`. Run alone.
- RED verified by the orchestrator, 2026-11-06.
  - `attest.sh check` said `fresh` for both runs at tree `c2af911`, so
    neither was re-run. `selftest.sh rules-trim`: exit 0,
    `rules-trim: 50 passed, 0 failed` (floor 30 → 50). `gates.sh --fast`:
    exit 0.
  - Green in RED is this story's planned shape (decision 3): the guard is
    written in this phase and every real pointer resolves. It is earned by
    RED's mutation (the fence toggle removed from `h2_headings` only: exactly
    the AC-5 assertion red, `49 passed, 1 failed`, restored) and by DV-1/DV-2
    at GATES.
  - Read the guard (`rules-trim.test.sh` 266-305, 340-348) and the real-tree
    assertions (618-621). They match C-1/C-2 as amended. AC-2..AC-5 each have
    fault cases with controls, and the real tree has both AC-6's list
    equality and AC-1's empty report.
  - RED's C-1 amendment (an opener with no `")` after it ends the scan)
    has no fixture. RED says so, and nothing on the real tree has that shape.
    Accepted as stated.
- GREEN verified by the orchestrator as a no-op, 2026-11-06. Not dispatched
  (decision 3). Run directly, not through `attest.sh`, because the
  orchestrator runs a no-op's checks itself.
  - `git diff --stat origin/main...HEAD` before the bump named exactly
    `rules-trim.test.sh`, `floors.conf`, `selftest.test.sh` and this story.
    `rules.md`, `cases.md` and `scripts/` are untouched.
  - `VERSION`: `113` → `114 (2026-11-06)`; `origin/main` still held 113.

```
rules-trim: 50 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (50 assertions executed, 50 declared).
1 harness suite(s) passed.
All required gates passed (0 ran, 5 unconfigured, 0 known).
```
