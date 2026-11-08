---
id: HARNESS-098
title: CLAUDE.md's --suites paragraph stops claiming a test-data mention never gives all
slug: claude-md-s-suites-paragraph-stops-claim
epic: 
type: fix
status: in-progress
phase: RED
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
- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1**
  (2026-11-07), as a `/plan-story` subagent; no override.
- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5**
  (2026-11-08), self-reported; `model: opus` passed. As planned.
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

Every criterion is mechanical; each is pinned by an exact whole-line or
exact-window assertion over `CLAUDE.md` / `scripts/selftest-needed.sh` with
`\r` stripped, all in `.claude/tests/selftest-needed.test.sh`, the
`HARNESS-096 AC-4` describe, plus the HARNESS-094 AC-8 describe. No
generator, no threshold, no negative control with a measured value: the
"controls" are the whole-line counts themselves, whose expected values are
stated below.

| AC | Assertion (title as it appears in the suite) | Expected after GREEN | On arrival (RED) |
|---|---|---|---|
| AC-1 | `CLAUDE.md's old declaration line 3 (ending `does not reach `all`.`) is gone` - `cm_count "$CM_O3"` | 0 | 1 - **red (new)** |
| AC-1 | `no line of CLAUDE.md still claims a test-data mention does not reach `all`` - awk `index` count | 0 | 1 - **red (new)** |
| AC-2 | `CLAUDE.md's declaration line 3 appears exactly once` - `CM_P3` re-pointed to C-2's line 3 | 1 | 0 - **red (re-pointed)** |
| AC-2 | `the declaration is its own paragraph directly before the one beginning `gates.sh` judges the **code**` - the five-line window `[] / P1 / P2 / P3 / []` | match | line 3 differs - **red (re-pointed)** |
| AC-2 | declaration lines 1 and 2 appear exactly once; the declaration sits in `## Running things` | 1, 1, heading | green (unchanged pins) |
| AC-3 | HARNESS-094 AC-8 (four assertions, 866-885 of the original file), the fence assertion and the lines-160-162 assertion | unchanged | green (unchanged pins) |
| AC-4 | `SNH_N1`..`SNH_N4` once each, in order between the R2 and R4 rows; `SNH_O1`/`SNH_O2` and `never under-selects` absent | unchanged | green (unchanged pins) |
| AC-4 | `git diff main -- scripts/selftest-needed.sh` empty | empty | not a suite assertion: a review check (GREEN writes nothing under `scripts/`; check-boundaries/diff review sees it) |

AC-3's "not edited" clause for the test file is a property of this RED's
diff, not a runtime assertion: `git diff` of the test file shows only the
comment, the `CM_P3` value, the `CM_O3` line and the two new assertions.

## Handoff: RED -> GREEN

**RED ran as `claude-opus-5-5`** (test-developer, dispatched by the
orchestrator; no model override stated in the dispatch).

### Command

    bash scripts/attest.sh -- bash scripts/selftest.sh selftest-needed

Record (fresh against tree `4c82d0be8e690bdd31c1e80cf168cd80b3b925d7`,
`attest.sh check` answered `fresh`): `exit: 1`,
`last: 1 of 1 harness suite(s) FAILED.`,
`log: .claude/state/attest-logs/20261108T033454Z.615879.log`, 303 s, Windows
host, local. (An earlier run, `20261108T032545Z.602465.log`, gave the same
616/4 before the floors.conf comment paragraph was appended; the record
above is the one on the final tree.)

Admissibility: `bash scripts/attest.sh -- bash scripts/gates.sh --fast` -
`exit: 0`, `last: All required gates passed (0 ran, 5 unconfigured, 0 known).`,
`log: .claude/state/attest-logs/20261108T033959Z.626925.log`. No gate is
configured here, as the story says; the suite above is the judge.

### Verbatim failure (from the log, lines 63-90)

```
  HARNESS-096 AC-4: the header and CLAUDE.md declare that a mention as test data maps a path
    FAIL CLAUDE.md's declaration line 3 appears exactly once
         expected: 1
         actual:   0
    FAIL CLAUDE.md's old declaration line 3 (ending `does not reach `all`.`) is gone
         expected: 0
         actual:   1
    FAIL no line of CLAUDE.md still claims a test-data mention does not reach `all`
         expected: 0
         actual:   1
    FAIL the declaration is its own paragraph directly before the one beginning `gates.sh` judges the **code**
         expected: []
         [`--suites` maps a changed path to every suite whose source names it, ending]
         [where the path ends, comments and test data included. A path a suite names]
         [only as test data counts as mentioned, never as unmapped (which gives `all`).]
         []
         actual:   []
         [`--suites` maps a changed path to every suite whose source names it, ending]
         [where the path ends, comments and test data included. A path a suite names]
         [only as test data is mapped by that mention and does not reach `all`.]
         []

selftest-needed: 616 passed, 4 failed
FAIL selftest-needed  did 616 units of work, below the floor of 620 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

Exactly the four predicted assertions are red, plus the floor line; no other
FAIL in the log. Each fails on its assertion (count or window), not on a
load or syntax error. Every AC-2 (lines 1, 2, heading), AC-3 and AC-4 pin is
green, as predicted.

### Tests, one line each

- `CLAUDE.md's declaration line 3 appears exactly once` - `CM_P3` (now C-2's
  new line 3) on exactly one line. AC-2. Re-pointed.
- `CLAUDE.md's old declaration line 3 (ending ...) is gone` - `CM_O3` (the old
  line) on 0 lines. AC-1. New.
- `no line of CLAUDE.md still claims a test-data mention does not reach `all``
  - awk `index($0, "does not reach `all`")` over `CM_TEXT`, 0. AC-1. New.
  This is the needle with no negation problem: the new line contains
  "gives `all`", not "does not reach".
- `the declaration is its own paragraph directly before ...` - the five lines
  before `` `gates.sh` judges `` are `[] / P1 / P2 / P3 / []`. AC-2. Re-pointed
  through the variable; text unchanged.
- Unchanged and green: declaration lines 1-2 once each, `## Running things`
  (AC-2); the fence and lines-160-162 assertions and HARNESS-094 AC-8 (AC-3);
  `SNH_*` header pins (AC-4).

### Files touched in RED

- `.claude/tests/selftest-needed.test.sh` - in the HARNESS-096 AC-4 describe
  only: a three-line comment above `CM_P1` naming HARNESS-098 as superseding
  HARNESS-096 C-5; `CM_P3` re-assigned; `CM_O3` added; the two new assertions
  directly after the line-3 assertion. Describe title, `SNH_*`, `CM_P1`,
  `CM_P2`, the line-1/line-2 assertions, the placement/heading/fence/lineno
  assertions and the HARNESS-094 AC-8 describe untouched.
- `.claude/tests/floors.conf` - `floor | selftest-needed | 618` -> `620`
  (line 64), plus a HARNESS-098 paragraph appended to the comment block.
- `.claude/tests/selftest.test.sh` - `selftest-needed 618` -> `620` (line 556).
  Not run in RED (that suite's own run is long); it compares this table with
  floors.conf, and both say 620.
- this story's `## Test plan` and this handoff.

### Floor measured

620 EXECUTED (616 passed + 4 failed), equal to the C-4 prediction. The floor
counts passed units, so it is red in RED (616 < 620) and green once GREEN
lands (620).

### What GREEN writes - exactly this, nothing else

1. `CLAUDE.md` line 192, replace
   `` only as test data is mapped by that mention and does not reach `all`. ``
   with exactly
   `` only as test data counts as mentioned, never as unmapped (which gives `all`). ``
   (77 characters, no trailing space, LF as the rest of the file). Lines 190-191
   and everything else in `CLAUDE.md` unchanged; the paragraph stays three lines.
2. `.claude/harness/VERSION`: `116 (2026-11-07)` -> `117 (<date of GREEN>)`.
3. Nothing under `scripts/` (AC-4: `git diff main -- scripts/selftest-needed.sh`
   empty), and no test file (frozen).

Export shape / callers: this is a docs-pin story; no module, function or
output shape is involved. Callers list: **none** - checked: a repo-wide grep
for `does not reach `all`` (excluding `.git`, `.claude/state` and the 096/098
story files) finds only `CLAUDE.md:192` and the new test/floors text that
names it; `CM_P3`/`CM_O3` occur only in the describe. Unconstrained: nothing;
the line is pinned byte for byte.

### Predicted post-GREEN counts

`bash scripts/selftest.sh selftest-needed`: `selftest-needed: 620 passed, 0
failed`, floor 620 met.

### Negative controls

None measured: the criteria are whole-line counts with fixed expected values
(table in `## Test plan`). Unlike an import-failing suite, every assertion in
this file executed in RED, so the red lines above are observed, not claimed.

### Deferred verifications

**DV-1 (owner GATES) - declined in RED, not run.** It restores the old line
into a `CLAUDE.md` that holds the new one; in RED the new line is not there,
so the `mutate.sh` expression would match nothing (and `mutate.sh` refuses a
no-op). Predicted when GATES runs it: exactly the four assertions above red,
`selftest-needed: 616 passed, 4 failed`, every HARNESS-094 AC-8, placement
(other than the window), heading, fence, lineno and `SNH_*` assertion green.
Note the DV-1 sed expression contains literal backticks inside single quotes
and `\.`/`$` anchors; it is well-formed as written in `## Deferred
verifications`.

### Contract

No block amended. C-1's anchors held (line numbers in the test file have
shifted by +3 from the comment and +1 from `CM_O3` below line 1031, and by
+6 more below the line-3 assertion).

### Implementation notes

None; one-line edit. The `selftest` suite pins the floor table and should be
in the PR's CI selftest; nothing GREEN writes affects it.

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
- PLANNED → RED checks (orchestrator, 2026-11-07): every C-1 anchor
  re-read on `b7b1809` and matches; the defect is reproduced (`grep -cxF`
  of the old line 1, substring count 1); `gates.sh --list` shows every gate
  unconfigured, so `required_gates: []` stands; empty epic. The story was
  committed at PLANNED as `de1594c` on its branch before the phase was set.
- RED verified by the orchestrator (2026-11-08): `attest.sh check` said
  `fresh` for `bash scripts/selftest.sh selftest-needed` (exit 1,
  `selftest-needed: 616 passed, 4 failed`, log
  `20261108T033454Z.615879.log`) and `bash scripts/gates.sh --fast` (exit 0,
  0 ran, log `20261108T033959Z.626925.log`), so neither was re-run. The four
  FAIL lines are exactly C-3's: line 3 once, the old line gone, the
  substring gone, and the placement window. The only other FAIL is the
  floor line (616 against 620). Diff read: only the AC-4 describe changed
  (comment, `CM_P3`, `CM_O3`, two assertions); both floors went 618 → 620;
  no source, CLAUDE.md or script was touched.
