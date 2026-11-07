---
id: HARNESS-096
title: --suites counts a mention only where the path ends, and declares fixture mentions
slug: suites-counts-a-mention-only-where-the-p
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-096-suites-counts-a-mention-only-where-the-p
depends_on: [HARNESS-094]      # the mechanism it refines; user decision 2026-11-04 to ship 094 and file this
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION, CLAUDE.md]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

HARNESS-094 added `bash scripts/selftest-needed.sh --suites`, which maps a
branch's changed harness paths to the suites that can break. Rule R3 maps a
path to every suite whose source contains it as a fixed-string substring (the
awk `index($0, p[j])`). R5 gives `all` for any path that no rule maps. The
second GATES diff review of HARNESS-094 found two ways R3 keeps a path away
from R5 when it should not. The orchestrator reproduced both in a clone at
`9bf37f0` (see `HARNESS-094.md`, `## Diff review`, "Second review"). The user
chose to ship 094 and file them here (094 `## Notes`, PO decision).

1. **Prefix match.** A path counts as mentioned when a suite names a longer
   path that starts with it. An untracked `scripts/plan` selected 8 of 34
   suites `(mentioned)`, from suites that name `scripts/plan.sh`. A comment
   `# leftover: scripts/newtool.sh.bak` in one suite made a new
   `scripts/newtool.sh` select that suite. Today no tracked harness path
   (158, against 34 suites) is mentioned only as a prefix, so this is latent.
2. **Fixture mentions.** `selftest-needed.test.sh` names
   `.claude/tests/_helpers.sh` and `scripts/newtool.sh` as fixture data. A
   real file of either name is therefore mapped to `selftest-needed` and never
   reaches R5: an untracked `.claude/tests/_helpers.sh` gave 3 of 34, where an
   unmentioned `.claude/tests/_zz_probe_helper.sh` gave `all`. This is a limit
   of mapping by mention and cannot be removed without dropping R3. It can be
   declared, and the suite's own fixture names can be made ones no real file
   will take.

CI runs every suite on every PR whatever `--changed` selects, so an
under-selection costs a CI round trip, not a broken `main`. That is why this
was deferred rather than fixed in 094.

Required gate that would fail if this story's artifact broke: none is
configured in this repository. The artifact is judged by
`bash scripts/selftest.sh selftest-needed`, which CI runs in full on the PR.

## Acceptance criteria

- **AC-1 (a mention ends where the path ends)** — Given a fixture suite whose
  source names `scripts/x.sh.bak` and `scripts/xy.sh` but never `scripts/x.sh`
  on its own, when a changed `scripts/x.sh` is enumerated by `--suites`, then
  stdout is exactly `all` and stderr names `scripts/x.sh` as mapped by no
  rule. Given the same suite naming `scripts/x.sh` followed by a space, a
  quote, a backtick, a closing parenthesis, a colon, a comma, or a `.` that
  ends a sentence, then `scripts/x.sh` maps to that suite (the control).
- **AC-2 (prefix of a directory)** — Given a suite that names
  `scripts/new-story.sh` only, a changed untracked `scripts/new` gives
  exactly `all`.
- **AC-3 (fixture names cannot collide)** — Every path that
  `selftest-needed.test.sh` creates as fixture data for an R5 case uses a name
  no real harness file will plausibly take, and that `classify.sh` still calls
  `harness` (check it with `bash scripts/classify.sh PATH`; do **not** reach
  for the `__probe_` convention without checking, because it classifies as
  `test`). A real-tree probe of each such R5
  case is pasted into `## Gate probes`: on the real tree, an untracked file of
  a plausible real name that no suite mentions gives `all`.
- **AC-4 (the limit is declared)** — The header of `selftest-needed.sh` no
  longer claims R3 "never under-selects" (today its line 54); it says instead
  that a path any suite names, including as test data, is mapped by that
  mention and does not reach R5. `CLAUDE.md` carries the same declaration as
  the exact new lines pinned in Contract C-5, in its "Running things"
  section, while its `--suites` and `--changed` command lines stay byte for
  byte as they are: HARNESS-094 AC-8 pins both, and `CLAUDE.md` never made
  the "never under-selects" claim (refined at PLANNED → RED, PO decision 1
  in `## Notes`).

## Contract

- **Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`,
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` (its floor
  table), `.claude/harness/VERSION`, `CLAUDE.md`.
- **C-1. Anchors (tree `d3e8822`, 2026-11-07).** `scripts/selftest-needed.sh`:
  the header rule table at lines 50-60, with R3 at 53-54 (`#   R3 mentioned a
  suite whose source holds the path as a fixed substring,` / `#
  comments included (over-selects, never under-selects)`); the R3 awk at
  190-204, whose hit test is line 203,
  `if (!(j in hit) && index($0, p[j])) { hit[j] = 1; print j "\t" s }`.
  `.claude/tests/selftest-needed.test.sh` (884 lines): `suites_stubs` 513,
  `suites_fixture` 525, `expect_suites` 547, `hdr` 591, `SUITES_ALL` 596,
  the HARNESS-094 describes at 601, 622, 665, 749, 816, 850, 863; the AM-2
  fixtures `put .claude/tests/_helpers.sh` at 785 and `put scripts/newtool.sh`
  at 790; `summary "selftest-needed"` 884. Floors: `floor | selftest-needed |
  482` (floors.conf 64) and `selftest-needed 482` (selftest.test.sh 556).
  `CLAUDE.md`: the `--suites` line is 161, inside the `## Running things`
  code block (153-171); `## Context discipline` follows. `VERSION` holds
  `115 (2026-11-06)`.
- **C-2. Shape of the amended R3.** The awk keeps exactly one hit decision,
  at the same place as today's `index($0, p[j])`, spelled
  `clean_hit($0, p[j])`, where `clean_hit(line, p)` is an awk function
  defined in the same program: it walks every occurrence of `p` in `line`
  (`index` on a shrinking suffix), and returns 1 at the first whose next
  character `c = substr(line, k + length(p), 1)` is `""`, or is not in
  `[A-Za-z0-9_/-]` and is not (`.` with `substr(line, k + length(p) + 1, 1)`
  in `[A-Za-z0-9]`); else 0. Character classes are spelled as string
  `index()` against a literal alphabet, not as regex classes over `c`, so
  the function is POSIX awk. This spelling is what makes DV-1 a one-line
  mutation: `s/clean_hit(\$0, p\[j\])/index($0, p[j])/`.
- **C-3. AC-1 and AC-2 fixtures.** Built on `suites_fixture` (nine stub
  suites, `SUITE_STUBS`), with one extra line appended to one stub by
  `printf ... >> "$d/.claude/tests/<stub>.test.sh"` before `commit_all`, as
  `suites_stubs` does. AC-1: a stub line `# keeps scripts/x.sh.bak and runs
  scripts/xy.sh` and an untracked `scripts/x.sh` → stdout exactly `all`,
  stderr exactly `${SUITES_ALL}scripts/x.sh is mapped by no rule; defaulting
  to every suite`, via `expect_suites ... whole`. AC-1 controls: eight stub
  lines, one per terminator — `scripts/x.sh ` (space), `scripts/x.sh"`,
  `scripts/x.sh'`, `` scripts/x.sh` ``, `scripts/x.sh)`, `scripts/x.sh:`,
  `scripts/x.sh,`, and `scripts/x.sh.` at end of line — each in a fresh
  fixture (or one stub holding all eight), with `scripts/x.sh` then listed
  for that stub: `expect_suites ... first "$(hdr 1 9 1)"` and `out_has
  <stub>` = 1. Plus one control where the clean mention sits AFTER a dirty
  one on the same line (`scripts/x.sh.bak then scripts/x.sh`), which must
  still map. AC-2: a stub line `# runs scripts/new-story.sh` and an untracked
  `scripts/new` → `all`, stderr naming `scripts/new`. Note `alpha` already
  names `scripts/probes/x.sh`, which does not contain `scripts/x.sh`.
- **C-4. AC-3 fixture names.** The AM-2 fixtures at 785 and 790 become
  `.claude/tests/_h096_fixture_helper.sh` and `scripts/h096-fixture-tool.sh`
  (both verified `harness` by `bash scripts/classify.sh` on this tree), and
  their labels and pinned stderr follow. No other test in the tree names
  `_helpers.sh` or `scripts/newtool.sh`. The real-tree probe AC-3 asks for
  is DV-3, owned by GATES, because its result belongs in `## Gate probes`.
- **C-5. AC-4 texts.** Header lines 53-54 become exactly these four lines:
  `#   R3 mentioned a suite whose source holds the path as a fixed substring`
  / `#                that ends where the path ends; comments and test data`
  / `#                count, so a path a suite names only as test data is`
  / `#                mapped by that mention and never reaches R5 (HARNESS-096)`.
  `CLAUDE.md` gains, as its own paragraph directly after the code block that
  closes at line 171 and before the paragraph beginning `` `gates.sh` judges
  the **code** ``, exactly these three lines:
  `` `--suites` maps a changed path to every suite whose source names it, ending ``
  / `where the path ends, comments and test data included. A path a suite names`
  / `` only as test data is mapped by that mention and does not reach `all`. ``
  Lines 160-162 of `CLAUDE.md` (the `selftest-needed.sh`, `--suites` and
  `--changed` lines) are unchanged byte for byte. RED pins all of this with
  whole-line counts (`grep -cxF` or the `cm_count` style of HARNESS-094
  AC-8), and asserts the two old lines are gone.
- **C-6. Phases.** RED writes the test file, the floors (482 → the measured
  count) and nothing else; its AC-1/AC-2/AC-4 cases fail on arrival (the awk
  is bare `index`, the texts are absent), its AC-3 renames pass on arrival
  and are earned by one mutation RED runs itself (rename one fixture back
  and watch only its own assertions move). GREEN writes the awk, the header,
  `CLAUDE.md` and `VERSION` (115 → 116). Callers: none — the change is
  inside one awk program; `--suites`' stdout and stderr shapes are
  unchanged, and HARNESS-094's existing cases must all stay green.
- **R3, amended.** A match of `p` at offset `k` in a line counts only when the
  character after it (offset `k + length(p)`) is end of line, or is not in
  `[A-Za-z0-9_/-]` and is not a `.` followed by `[A-Za-z0-9]`. When a line
  holds `p` more than once, any one match that ends cleanly counts. This
  holds in POSIX awk, so it needs no gawk extension (`rules.md`,
  Portability).
- **Oracle.** All criteria are mechanical: exact stdout, exact stderr shape,
  exact exit status, in the fixture style of the HARNESS-094 cases.
- RED may amend a block in place with a reason, and GREEN builds what the
  amended block says.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** Revert the boundary check with
`bash scripts/mutate.sh scripts/selftest-needed.sh 's/clean_hit(\$0, p\[j\])/index($0, p[j])/' -- bash scripts/selftest.sh selftest-needed`
(the expression C-2 fixes).
AC-1's `x.sh.bak` case and AC-2 must go red, and AC-1's controls must stay
green. Paste the red lines and the restore line.

**DV-3 (AC-3, real tree). Owner: GATES.** On the real tree at GATES, with
the AM-2 fixtures renamed, an untracked `.claude/tests/_helpers.sh` and an
untracked `scripts/newtool.sh` — the two plausible real names the old
fixtures took — each give exactly `all` from `bash scripts/selftest-needed.sh
--suites`, stderr naming the path as mapped by no rule. Negative control: the
same two files against the merge base's script and suite (a clone or
`git stash`-free worktree at `d3e8822`) give a list, not `all` (094's review
measured `_helpers.sh` at 3 of 34). Paste both into `## Gate probes`.

**DV-2 (real tree). Owner: GATES.** On the real tree, `--suites` against the
branch's merge base must still give, for the merged PRs #165 to #177 replayed
as in HARNESS-094's second review, the same answers as the 094 script, or
`all` where a prefix-only mention was the only thing mapping a path. Paste
the table. A list that shrinks is a finding.

## Amendments

<!-- none yet -->

## Suppressions

<!-- none -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-096` from `.claude/harness/models.conf`.
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
  (2026-11-04), as a `/plan-story` subagent; refined at PLANNED → RED by the
  orchestrator on **claude-fable-5-1** (2026-11-07): C-1..C-6, DV-3, AC-4's
  wording, `touches:` + `CLAUDE.md`.

## Out of scope

- Replacing mention-based mapping with a static call graph of which scripts
  each suite runs. That was the rejected alternative in HARNESS-094.
- Changing what CI runs. CI keeps running every suite.

## Test plan

## Handoff: RED -> GREEN

## Regressions

## Gate results

## Gate probes

## Scaffold inventory

<!-- not a SCAFFOLD story -->

## Notes

- Planned 2026-11-04 from HARNESS-094's second GATES diff review, at the
  user's decision "Ship, file follow-up".
- PO decisions at PLANNED → RED (orchestrator, 2026-11-07, tree `d3e8822`):
  1. **AC-4 refined, not amended** (still PLANNED, so no `## Amendments`).
     `CLAUDE.md` holds no "never under-selects" claim — `grep -rn
     under-select scripts CLAUDE.md .claude/harness docs/wiki` finds only
     `scripts/selftest-needed.sh:54` — and its `--suites` line (161) is
     pinned byte for byte by HARNESS-094 AC-8 (selftest-needed.test.sh
     863-882), together with the `--changed` line after it. Rewriting that
     line would mean editing a DONE story's assertion to fit. So the
     declaration lands in `CLAUDE.md` as a new paragraph (C-5) and the
     command lines stay. Reported to the user first, so it can be overruled
     before GREEN.
  2. **Not already delivered:** line 203 is still the bare
     `index($0, p[j])`; line 54 still says `never under-selects`; the AM-2
     fixtures are still `_helpers.sh` / `newtool.sh`; `CLAUDE.md` has no
     declaration paragraph.
  3. **Required gate:** none configured; the artifact is judged by the
     `selftest-needed` suite, which CI runs in full on the PR.
     `required_gates: []` stays. Epic empty: no done-when to check.
  4. **Callers:** none. The change is inside one awk program and the
     output shapes do not move (C-6).
  5. `plan.sh conflicts`: "fewer than two startable stories"; this is the
     last story on the board.
  6. **Budget:** DV-1 is the defect put back; DV-3 is the real-tree probe a
     rule-over-the-tree story owes; RED earns its AC-3 renames with one
     mutation of its own. DV-2 (the 094 replay) is above the default and
     kept, because a shrinking list is the one regression this story could
     introduce without any fixture seeing it.
