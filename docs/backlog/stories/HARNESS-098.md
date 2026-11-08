---
id: HARNESS-098
title: CLAUDE.md's --suites paragraph stops claiming a test-data mention never gives all
slug: claude-md-s-suites-paragraph-stops-claim
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-098-claude-md-s-suites-paragraph-stops-claim
depends_on: [HARNESS-096]      # it rewrites one line HARNESS-096 wrote and supersedes one of its assertions; 096 is DONE on main (b7b1809)
touches: [CLAUDE.md, .claude/tests/selftest-needed.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by the selftest-needed suite, which CI runs in full on the PR
---

## Context

HARNESS-096 added a three-line paragraph to `CLAUDE.md` (`## Running things`,
directly before the paragraph beginning `` `gates.sh` judges the **code** ``)
declaring how `bash scripts/selftest-needed.sh --suites` maps a changed path.
Its third line says a path a suite names only as test data "is mapped by that
mention and does not reach `all`". The last clause is false for the four R2
paths, `.claude/tests/_lib.sh`, `.claude/tests/_spawns.sh`,
`scripts/selftest.sh` and `.claude/hooks/lib.sh`: suites do name them (on this
tree 11 suites name `scripts/selftest.sh` and 13 name `.claude/hooks/lib.sh`),
and `--suites` still answers `all` for them, because R2 ("read by every
suite") wins before R3 is consulted (`scripts/selftest-needed.sh:234-236`,
the `case` that `continue`s with `why_all="$p is read by every suite"`;
pinned by HARNESS-094 AC-2, `selftest-needed.test.sh:622`). What the clause
meant is that such a path never falls through to R5, the unmapped default.
The header of `scripts/selftest-needed.sh` (lines 53-56) says exactly that -
"mapped by that mention and never reaches R5" - and is correct; it does not
change here.

The finding is HARNESS-096 `## Diff review`, Nice to have 1 (verdict Ship),
which the orchestrator deferred to a follow-up because AC-4 of that story
pinned the text. Script behaviour is correct and does not change: a reader
who believed the clause would expect a change to `scripts/selftest.sh` to
select a short list, and the script would still print `all`, so the defect
is in the wording only. The fix is one line of `CLAUDE.md`.

**This story changes a DONE story's assertion, and says so.** The current
third line is pinned byte for byte by HARNESS-096 AC-4 / Contract C-5, in
`.claude/tests/selftest-needed.test.sh`, the `HARNESS-096 AC-4` describe
(line 995): `CM_P3` at line 1034 and the two assertions that use it (1038,
1039-1048). Changing that text means changing that pin. That is not a test
edited to make it pass: it is a new story's acceptance criterion, decided at
PLANNED with the defect reproduced in Context, superseding the old one. The
RED of this story rewrites the pin to the new line and adds the assertions
that reproduce the defect (the old clause absent), so the corrected assertion
is watched to fail against today's `CLAUDE.md` in the ordinary way. HARNESS-096
is DONE and its file is not edited; the supersession is recorded here (PO
decision 1) and the 096 describe keeps its name, with a comment naming this
story.

No gate is configured in this repository (`project.conf` has none); the
artifact is judged by the `selftest-needed` suite, run in full by CI on the
PR and locally through `bash scripts/selftest.sh selftest-needed`.

## Acceptance criteria

- **AC-1** - Given `CLAUDE.md` on this branch, when its lines are compared
  whole (after stripping `\r`), then no line is exactly
  `` only as test data is mapped by that mention and does not reach `all`. ``
  and no line contains the substring `` does not reach `all` `` anywhere.
  *(The defect, reproduced: on `main` at `b7b1809` both counts are 1.)*
- **AC-2** - Given `CLAUDE.md` on this branch, when its lines are compared
  whole, then the `--suites` declaration is exactly the three lines of
  Contract C-2, each appearing exactly once, as its own paragraph (a blank
  line either side) directly before the paragraph beginning `` `gates.sh`
  judges the **code** ``, inside `## Running things`; the first two lines are
  HARNESS-096's unchanged.
- **AC-3** - Given `CLAUDE.md` on this branch, when lines 160-162 and the
  code block that holds them are read, then the `selftest-needed.sh`,
  `--suites` and `--changed` command lines are unchanged byte for byte, the
  block still closes directly into the `` `mutate.sh` exists because ``
  paragraph, and the HARNESS-094 AC-8 assertions (`selftest-needed.test.sh`
  866-885) and the HARNESS-096 placement assertions (1039-1068) are not
  edited.
- **AC-4** - Given `scripts/selftest-needed.sh` on this branch, when the
  header's R3 row is read, then it is the four HARNESS-096 lines unchanged
  (`SNH_N1`..`SNH_N4`, `selftest-needed.test.sh` 1005-1008), and the script
  is not changed at all: `git diff main -- scripts/selftest-needed.sh` is
  empty.

## Contract

**Writes:** `CLAUDE.md`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

- **C-1. Anchors (tree `b7b1809`, `main`, 2026-11-07).** `CLAUDE.md`: the
  `## Running things` code block is 157-182, with the `selftest-needed.sh`,
  `--suites` and `--changed` lines at 160-162; the `` `mutate.sh` exists
  because `` paragraph 184-188; the `--suites` declaration paragraph 190-192;
  the `` `gates.sh` judges `` paragraph begins at 194.
  `.claude/tests/selftest-needed.test.sh` (1070 lines): HARNESS-094 AC-8
  describe 866, `cm_count` 873, `CM_L1` 870; HARNESS-096 AC-4 describe 995,
  `SNH_N1`..`SNH_N4` 1005-1008, `CM_P1` 1032, `CM_P2` 1033, `CM_P3` 1034,
  `CM_GATES_HEAD` 1035, the three `cm_count` assertions 1036-1038, the
  placement assertion 1039-1048, the `## Running things` assertion
  1049-1053, the fence assertion 1054-1062, the lines-160-162 assertion
  1063-1068, `summary "selftest-needed"` 1070. Floors: `floor |
  selftest-needed | 618` (floors.conf 64) and `selftest-needed 618`
  (selftest.test.sh 556). `.claude/harness/VERSION` holds `116 (2026-11-07)`.
  `scripts/selftest-needed.sh` header: R2 row 50-52, R3 row 53-56, R5 row
  59-61; the R2 short-circuit at 234-236.
- **C-2. The new text.** Lines 190-192 of `CLAUDE.md` become exactly these
  three lines, the first two unchanged from HARNESS-096 C-5:
  `` `--suites` maps a changed path to every suite whose source names it, ending ``
  / `where the path ends, comments and test data included. A path a suite names`
  / `` only as test data counts as mentioned, never as unmapped (which gives `all`). ``
  Why this wording: "counts as mentioned" is R3's claim and is true whether
  or not R2 then wins; "never as unmapped" is the header's "never reaches
  R5" in CLAUDE.md's words; the parenthesis keeps the one fact a reader
  needs from the old line (unmapped means `all`) without claiming the
  path's answer is not `all`, which for an R2 path it is. 77 characters,
  within the file's prose width (several existing lines are 80). Nothing
  else in `CLAUDE.md` changes; the paragraph stays three lines so the
  placement assertion's five-line window (`NR - 5` to `NR - 1`) still fits
  without edit.
- **C-3. Assertions in the `HARNESS-096 AC-4` describe that change, and
  only these.** (a) `CM_P3` (line 1034) is assigned the new third line of
  C-2. The assertion "CLAUDE.md's declaration line 3 appears exactly once"
  (1038) and the placement assertion (1039-1048) keep their text and now
  pin the new line through the variable. (b) Two assertions are added
  directly after 1038, in the style of `SNH_O1`/`SNH_O2` (1009-1010,
  1024-1030): `CM_O3` holding the old third line, asserted to appear on 0
  lines by `cm_count`; and a substring count of `` does not reach `all` ``
  over `CM_TEXT` (awk `index`, as the `never under-selects` assertion at
  1026-1030 does), asserted 0. These two are AC-1 and are the assertions
  watched to fail. (c) A comment above `CM_P1` says the third line is
  HARNESS-098's, superseding HARNESS-096 C-5, and the describe title is
  unchanged. Everything else in the describe - `SNH_*`, `CM_P1`, `CM_P2`,
  1036-1037, 1049-1068 - is unchanged, and so is the HARNESS-094 AC-8
  describe. The describe stays where it is, before `summary`.
- **C-4. Floors.** +2 assertions, each unconditional: 618 → 620 in both
  `floors.conf` line 64 and `selftest.test.sh` line 556, with a paragraph
  appended to the `floors.conf` comment block in the HARNESS-096 style
  (what was added, the measured `passed`/`failed`, EXECUTED total). RED
  measures and records the real number; 620 is the prediction.
- **C-5. Phases.** RED writes the test file and the two floors, nothing
  else; its two new assertions fail on arrival (both counts are 1 on
  `main`), and the two re-pointed assertions (1038, 1039-1048) fail too
  (the new line is absent) - 4 red, 616 green predicted, the AC-2/AC-3/AC-4
  pins all green on arrival because they pin what is already there. GREEN
  writes the one line of `CLAUDE.md` and bumps `.claude/harness/VERSION`
  116 → 117 (`check-boundaries.sh` refuses an upstream harness change
  without a bump; `CLAUDE.md` and the test classify `harness`). GREEN
  writes nothing under `scripts/`. Callers: none - no script, signature or
  output shape moves.
- **Oracle.** Every criterion is mechanical: exact lines, whole-line counts
  (`cm_count`), exact awk windows, in the style of HARNESS-094 AC-8 and
  HARNESS-096 AC-4. Nothing is settled-by-measurement and nothing is
  oracle-free. Pin exactly; leave nothing open-ended.
- RED may amend a block in place with a reason, and GREEN builds what the
  amended block says.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** Restore the old third line with
`bash scripts/mutate.sh CLAUDE.md 's/^only as test data counts as mentioned, never as unmapped (which gives `all`)\.$/only as test data is mapped by that mention and does not reach `all`./' -- bash scripts/selftest.sh selftest-needed`
(the narrowest command holding the assertions). Exactly the four assertions
of C-3 (a) and (b) **must** go red - the new line 3 absent, the placement
window, the old line present once, the substring present - and every
HARNESS-094 AC-8, HARNESS-096 placement and `SNH_*` assertion must stay
green: 616 passed, 4 failed predicted. RED cannot run this: the new line is
not in `CLAUDE.md` until GREEN. Paste the red lines and the restore line,
and confirm `bash scripts/mutate.sh --check` is clean.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-098` from `.claude/harness/models.conf`.
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
## Out of scope

- Any change to `scripts/selftest-needed.sh` - its awk, its R2 `case`, or
  its header, which already says "never reaches R5" and is correct (AC-4
  pins that it is untouched).
- Any change to the `selftest-needed.sh`, `--suites` or `--changed` command
  lines of `CLAUDE.md` (HARNESS-094 AC-8), to the paragraph's placement, or
  to the first two lines of the paragraph.
- Editing `docs/backlog/stories/HARNESS-096.md`: it is DONE; the
  supersession is recorded here, not as a 096 `## Amendments` entry (the
  diff review's suggestion assumed the change would land inside 096).
- Reconsidering R2 itself, transitive selection, or the known limit the
  header records.
- Any other wording of `CLAUDE.md`; the `--suites` paragraph is the whole
  change.

## Test plan

<!-- Filled by the Test Developer during RED. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run. -->

## Notes

- Planned 2026-11-07 (lead-po, resolved **claude-fable-5-1**, dispatched
  by the plan-story command; no model override was stated) from HARNESS-096
  `## Diff review`, Nice to have 1, at the user's request. `main` at
  `b7b1809`, no active story.
- PO decisions at PLANNED:
  1. **This story supersedes HARNESS-096 AC-4 / C-5's pin of CLAUDE.md's
     third line.** HARNESS-096 is DONE and its criteria are frozen; its
     file is not edited. The new text is this story's AC-2, decided here
     at PLANNED with the defect reproduced (AC-1, Context), and RED
     rewrites the `CM_P3` pin and adds the two defect assertions, so the
     corrected pin is watched to fail against today's `CLAUDE.md`. This
     is the sanctioned route for a DONE story's assertion that pins a
     wrong text: a new story whose criterion says what the line must be,
     not a test edited in GREEN to fit. The 096 describe keeps its title
     and gains a comment naming this story (C-3 c).
  2. **Defect reproduced on `main` at `b7b1809`:** `grep -cxF` of the old
     third line in `CLAUDE.md` is 1, and the substring `` does not reach
     `all` `` occurs once; 11 suites name `scripts/selftest.sh` and 13 name
     `.claude/hooks/lib.sh`, and the R2 `case` at
     `scripts/selftest-needed.sh:234` answers `all` for them before R3
     runs - which is what HARNESS-094 AC-2 (`selftest-needed.test.sh:622`)
     pins. So the clause is false of the four R2 paths, as the review said.
  3. **The header of `scripts/selftest-needed.sh` needs no change.** Lines
     53-56 say a test-data-only mention is "mapped by that mention and
     never reaches R5", and line 48 says "`all` wins over everything",
     which together are exactly right for R2. AC-4 pins the script as
     untouched.
  4. **Wording chosen (C-2):** "counts as mentioned, never as unmapped
     (which gives `all`)". The review's "is not defaulted to `all` as
     unmapped" made the third line 80-83 characters in every spelling that
     kept the paragraph at three lines; the chosen line is 77 and says the
     same thing. Three lines are kept so the 096 placement assertion's
     window needs no edit.
  5. **Floors and VERSION follow HARNESS-096's pattern:** +2 assertions
     → floor 618 → 620 (RED measures; the number is a prediction), VERSION
     116 → 117 in GREEN.
  6. **Not already delivered:** `CLAUDE.md:192` still reads the old line
     on `main`.
  7. **Required gate:** none configured; judged by the `selftest-needed`
     suite. `required_gates: []` stays. Epic empty: no done-when to check.
  8. `plan.sh conflicts`: "fewer than two startable stories".
  9. **Budget:** DV-1 is the one "defect put back" the default owes. No
     test is written against code that already exists except the
     re-pointed pins, which DV-1 earns in the same run; no rule over the
     tree changes, so no real-tree probe is owed.
