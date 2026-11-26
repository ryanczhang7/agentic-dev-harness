---
id: HARNESS-131
title: A floor edit or a CLAUDE.md edit selects only the suites that read them
slug: a-floor-edit-or-a-claude-md-edit-selects
epic: 
type: chore
status: in-progress
phase: GATES
branch: story/HARNESS-131-a-floor-edit-or-a-claude-md-edit-selects
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/floors.test.sh, .claude/tests/selftest.test.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/floors.conf, .claude/tests/attest.test.sh, .claude/tests/lib.test.sh, .claude/tests/phase-guard.test.sh, .claude/tests/plan.test.sh, .claude/tests/refresh.test.sh, .claude/tests/rules-trim.test.sh, .claude/tests/shipped-docs.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/worktree.test.sh, .claude/harness/VERSION]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Before a PR, a story runs only the suites its diff can break
(`SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`, chosen by
`bash scripts/selftest-needed.sh --suites`). A suite is chosen when its
source mentions a changed path, unless it declares on a line of its own,
`# fixture-only: <path>`, that it only writes its own copy (HARNESS-115).
The audit `docs/wiki/audits/runtime-cut-2026-11-25.md` found two places
where that selection picks suites that cannot be broken by the change
(findings **ST-3** and **ST-4**, decision 8).

**ST-3, the floor table.** A story that adds assertions raises its suite's
floor in `.claude/tests/floors.conf` and in the hand-copied table that
guards it, which lives in `.claude/tests/selftest.test.sh` (the `COUNTS`
heredoc, `:518-570` at main `d495ae7`). So nearly every story edits
`selftest.test.sh` and selects the whole `selftest` suite, 51 s on CI and
far longer on a loaded host, for a one-number change. The audit counted 28
of the last 30 merged PRs.

**ST-4, `CLAUDE.md`.** Fourteen suites mention `CLAUDE.md`. Five read the
real file. Nine name it only in a comment, write a fixture's own copy, or
use the name as a classification input.

**The decision is settled; the numbers are not.** Re-measured at PLANNED in
a scratch clone of main `d495ae7` (`## Notes` has the output):

| Diff | Selected today | After this story |
|---|---|---|
| `CLAUDE.md` only | 14 of 35 | 5 of 36 |
| `.claude/tests/floors.conf` only | `selftest` (366 assertions) | `floors` (9 assertions) |

Each of the nine suites was read at PLANNED, mention by mention (Contract
C-2), not taken from the audit's list. The audit's "28 of 30" and "93 s of
CI time" were not re-measured and are not criteria; the criteria pin the
selection itself.

**What a wrong declaration costs.** A suite that declares a path
`fixture-only` and does read the real file is silently left out of the
pre-PR run when that file changes. CI's full run is the backstop, but the
point of the local run is not to need it. So the declarations are checked
against the real tree, not only against fixtures (Deferred verifications
DV-2).

No assertion is deleted, skipped or loosened: nine assertions move from one
suite to a new one, word for word, and the two floors sum to today's.

**The gate that judges it.** Every gate is unconfigured in this repository.
The artifact is judged by the `selftest-needed` suite (the selection pins),
the new `floors` suite and the `selftest` suite, each under its floor, and
by the full self-test's own audit that every suite has a floor. CI runs the
full self-test on the PR.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


"Over the real suites" means the fixture `h115_real` builds in
`.claude/tests/selftest-needed.test.sh`: a repository whose `main` holds a
copy of every shipped suite, on a story branch, with the named paths then
changed. Each case is run from the root and from a subdirectory, and
`<m>` is the number of shipped suites, counted by the suite, not written
down. stdout and stderr are compared as that suite's `h115_expect` compares
them: stdout whole, the header exactly, each reason line exactly once, the
not-selected line exactly and last.

- **AC-1 (a `CLAUDE.md` edit selects the five suites that read it)** —
  Given only `CLAUDE.md` changed over the real suites, when
  `bash scripts/selftest-needed.sh --suites` runs, then it exits 0; stdout
  is exactly the five lines `mutate`, `reporting`, `run-queue`,
  `selftest-needed`, `story`; stderr's first line is the header for 5 of
  `<m>` from 1 harness path; each of the five has the reason line
  `CLAUDE.md (mentioned)`; and stderr's last line is exactly
  `  not selected (fixture-only): attest lib phase-guard plan refresh rules-trim shipped-docs sigpipe worktree`.
  *Control:* today the same case prints 14 names and no not-selected line.

- **AC-2 (a floor edit selects the floors suite, not the selftest suite)**
  — Given only `.claude/tests/floors.conf` changed over the real suites,
  then stdout is exactly `floors`; the header says 1 of `<m>` from 1
  harness path; the reason line is `floors` with
  `.claude/tests/floors.conf (mentioned)`; and the last line is exactly
  `  not selected (fixture-only): host-load refresh run-lock run-queue selftest`.
  *Control:* today the same case prints `selftest`.

- **AC-3 (a suite that reads the real file is selected whatever it
  declares)** — Given a copy of the real `mutate.test.sh` with the line
  `# fixture-only: CLAUDE.md` appended on `main`, and `CLAUDE.md` then
  changed, then `mutate` is still printed, with the reason
  `CLAUDE.md (mentioned under $REPO_ROOT, despite fixture-only)`. Given a
  copy of the real `floors.test.sh` with `# fixture-only:
  .claude/tests/floors.conf` appended, and `floors.conf` then changed, then
  `floors` is still printed with the same kind of reason.
  *Control:* these are the two files AC-1 and AC-2 leave selected, so a
  script that honoured every declaration fails here.

- **AC-4 (the nine assertions move whole, and the floors add up)** — Given
  the tree after this story, then `.claude/tests/floors.test.sh` exists and
  `bash scripts/selftest.sh floors` reports the nine assertions that
  `selftest.test.sh` held at `:416-576` on main (the real tree has a floor
  for every suite; the five HARNESS-021 cases of `suites_without_floor`;
  each floor equals the hand-copied count; `profiles` and `lib` by name),
  with their descriptions unchanged; `bash scripts/selftest.sh selftest`
  reports nine fewer than it did on main; `floors.conf` floors `floors` at
  9 and `selftest` at 357, which sum to today's 366; and the hand-copied
  table, now in `floors.test.sh`, holds a row for every suite, `floors`
  included.
  *Control:* the full self-test fails a suite with no floor line, and the
  table's own assertion fails on a row that disagrees with `floors.conf`,
  so a moved assertion that was dropped shows as a count below its floor.

- **AC-5 (the selection pins that already exist still hold)** — Given the
  existing cases of `selftest-needed.test.sh` that run over the real
  suites, then each still passes, with its expected list changed only as
  this story's two effects require: `floors` is listed where
  `floors.conf` is among the changed paths; `selftest` is listed only where
  its own file is among them, with the reason `(itself)`; and the case that
  shows a declaration being overridden uses the suite that now reads the
  real `floors.conf`. No case is removed, and the suite's executed count
  does not fall.

- **AC-6 (the selftest suite no longer names the real floors file as its
  own input)** — Given `selftest.test.sh` after this story, then it holds
  the line `# fixture-only: .claude/tests/floors.conf` at column 0, and its
  source holds that path nowhere directly after `$REPO_ROOT/` or
  `${REPO_ROOT}/`, and it does not call `suites_without_floor` on the real
  tree.
  *Control:* AC-2's not-selected line names `selftest`; with the path left
  after `$REPO_ROOT/` the script prints `selftest` with a `despite` reason
  instead, and AC-2 fails.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
       * the files it WRITES, on one line at column 0 that starts
         `**Writes:**`, each path backticked and repository-relative:
           **Writes:** `src/core/world.ts`, `tests/world.test.ts`
         `bash scripts/plan.sh conflicts` compares it with `touches:` and prints
         DRIFT for a written file `touches:` does not cover. Without the line
         there is no DRIFT at all, and files the prose merely cites never count
       * module paths and exported names, exactly
       * exact signatures, and the types the assertions will destructure
       * THE SEMANTICS BEHIND EACH NUMBER - not clamp(latitude) but "latitude
         clamps at +/-85, and dragging DOWN brings the north into view". One
         sentence per number settles a sign error in one line
       * the accessible markup for anything user-facing: roles, labels, what is
         a sibling of what
       * the oracle partition of the criteria (settled / oracle-free /
         mechanical - see story-authoring)
       * baseline measurements the story may read out rather than re-derive,
         each with what it was measured on
       * TEST-ONLY DEPENDENCIES this story is likely to need, by name. RED
         may add them itself, but only inside the dev block - so a library
         production will ALSO use is a GREEN change and is better decided
         here than discovered mid-phase. Where the ecosystem has no dev
         block at all (go.mod, requirements.txt, *.csproj), RED cannot
         declare one and the phase round trip is yours to plan for
       * FOR EVERY EXISTING EXPORT WHOSE SIGNATURE THIS STORY CHANGES: every
         caller, source and test, grep-listed here before dispatch. RED cannot
         find these itself - the old signature still exists during RED, so a
         caller of it still compiles and is absent from RED's typecheck. One
         such file went missing and took 25 tests with it, silently, at GREEN. -->

**Writes:** `.claude/tests/floors.test.sh`, `.claude/tests/selftest.test.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/attest.test.sh`, `.claude/tests/lib.test.sh`, `.claude/tests/phase-guard.test.sh`, `.claude/tests/plan.test.sh`, `.claude/tests/refresh.test.sh`, `.claude/tests/rules-trim.test.sh`, `.claude/tests/shipped-docs.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/worktree.test.sh`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason. The acceptance
criteria are not amendable this way. No function changes signature.

**C-1. Who writes which, and in what order.** Every path above classifies
as `harness`, and all but `VERSION` are suites or the floors file, so the
test-developer writes them, in RED, in this order:

1. the new and changed pins in `selftest-needed.test.sh` (AC-1, AC-2, AC-3,
   AC-5), run against the unchanged suites and **watched to fail** (AC-1
   prints 14 names, AC-2 prints `selftest`); the failure output goes in the
   handoff;
2. the nine declaration lines (C-2), `floors.test.sh` and the cut from
   `selftest.test.sh` (C-3), the floors (C-4);
3. the same suites run again, now passing.

GREEN is a verified no-op (the handoff says so, with the passing run);
GATES writes `VERSION`. **Not written: `scripts/selftest-needed.sh`,
`scripts/selftest.sh`, `.claude/tests/_lib.sh`, `CLAUDE.md`.** The selection
rules do not change; only what the suites declare does. `_lib.sh` untouched
keeps this story's own pre-PR run from resolving to every suite.

**C-2. The nine declarations.** Each suite gets, in its header comment, at
column 0, the line `# fixture-only: CLAUDE.md`, followed by an indented
comment line saying why, as the five existing declarations do.
`refresh.test.sh` already has a declaration line (`:19`); `CLAUDE.md` is
added to it or given a line of its own. Each mention, read at PLANNED on
main `d495ae7`:

| Suite | Every mention of `CLAUDE.md` | Kind |
|---|---|---|
| `attest` | `:28`, `:324`, `:336`, `:513` comments; `:206`, `:338`, `:350`, `:521` write `$FIX/` or `$WFIX/CLAUDE.md`; `:351`, `:352`, `:524`, `:527` labels and `git -C` on those fixtures | fixture copy |
| `lib` | `:30`, the string `CLAUDE.md=harness` in a table of paths to classify | a name, never a file |
| `phase-guard` | `:8`, `:152` | comments |
| `plan` | `:2180` | comment |
| `refresh` | `:45`, `:91` write `$UP/` and `$PROJ/CLAUDE.md`; `:200-217` read those two | fixture copy |
| `rules-trim` | `:4` | comment |
| `shipped-docs` | `:46`, `:324` comments; `:328` writes `$d/CLAUDE.md`; `:329` label | fixture copy |
| `sigpipe` | `:294`, `:639` | comments |
| `worktree` | `:57` | comment |

The five that are not declared, because they read the real file: `mutate`
(`:953`, `$REPO_ROOT/CLAUDE.md`), `reporting` (`:31`), `run-queue`
(`:1609`), `selftest-needed` (`:872`), `story` (`:290`).

RED re-reads every mention before writing a declaration, on the tree as it
is then: a suite added or changed by a story merged since PLANNED is
classified by the same rule, a suite that turns out to read the real file
is left undeclared, and either changes AC-1's list only through
`## Amendments`. A line shifted by a merged story is not a finding; a new
kind of mention is.

**C-3. `floors.test.sh`.** A new suite, `summary "floors"`. Its body is
`selftest.test.sh:416-576` at main `d495ae7`, moved, not rewritten: from the
`describe "AC-6/AC-7  the shipped floors file covers every suite, at its
count"` line to the assertion that `lib` is floored at its executed count,
with the helpers `floor_of`, `suites_without_floor` and `floor_root` and
their comments. That is nine executed assertions. Changes allowed inside
the moved text, and no others:

- `floor_root` builds under the new suite's own scratch directory
  (`mktemp -d`, removed on exit) instead of `$FIX/floor-roots`; the new
  suite needs no `make_project_fixture`;
- the `COUNTS` rows this story changes (C-4);
- nothing else: descriptions, needles, helper bodies and comments are
  byte-identical, and DV-3 shows it.

*Amended in RED (test-developer, 2026-11-25).* Two refinements, neither
widening what may change. (1) The new suite's `mktemp -d` scratch directory
is **named `FIX`** (`FIX="$(mktemp -d ...)"`, `trap 'rm -rf "$FIX"' EXIT`),
so `floor_root`'s body (`_fr="$FIX/floor-roots/$1"`) and the comment above
it ("a throwaway directory under $FIX") are byte-identical rather than
edited: the first bullet's effect - own scratch directory, no
`make_project_fixture` - with a zero-line diff instead of a one-line one.
DV-3's diff therefore shows only `COUNTS` rows. (2) The moved range is
**`:415-576` on this branch's base `5f0de59`**, one line wider than the
`:416-576` above: line 415 is the `# ----` separator that heads the
describe, and leaving it behind would have left a dangling separator in
`selftest.test.sh` above HARNESS-020's `# ====` banner. `selftest.test.sh`
loses `:415-577` (the separator, the block, and the one blank line after
it). The line numbers are the same on `d495ae7` and `5f0de59`; the only
difference in the block between the two is the `boundaries` row (687 to
703, HARNESS-124). Also, the rewritten `selftest.test.sh` header names the
new suite **bare** (`floors.test.sh`), not by its whole path: the whole
path there would be a mention, and every edit to the table (which now lives
in that suite) would select `selftest` again - ST-3 reintroduced by a
comment.

`selftest.test.sh` loses exactly those lines; its header (`:36-38`, "The
one real-tree assertion block reads ...") is rewritten to say the block
lives in `floors.test.sh`; it gains the declaration of AC-6. The comment in
`floors.conf` that says where the hand-copied table lives (`:33`) is
updated to name `floors.test.sh`. Both tree guards scan the new file
(`check-sigpipe.sh`, `check-grep-count.sh`); the moved text already passes
them where it is.

**C-4. The floors.** `floors.conf`: a new line `floor | floors | 9`;
`selftest` 366 to 357; `selftest-needed` raised to whatever RED measures
after C-5 (1099 today); a dated note for each, in the file's own style. The
`COUNTS` table carries the same three changes. 9 + 357 = 366: the sum is a
criterion (AC-4), so if RED measures a different executed count for either
suite on its host, it reports that before changing a number. No other floor
moves: the nine edited suites gain a comment line and no assertion.

**C-5. The existing pins in `selftest-needed.test.sh`, and what each
becomes.** Read from `scripts/selftest-needed.sh` (`:291-296` for the
reason words, `:337-341` for the not-selected line, which leaves out any
suite that was selected by another rule):

- *HARNESS-115 AC-1* (VERSION, `floors.conf`, `selftest.test.sh` and
  `shipped-docs.test.sh` changed): 7 suites become 8. `floors` is added
  with reason `.claude/tests/floors.conf (mentioned)`; `selftest` stays,
  its reason now `.claude/tests/selftest.test.sh (itself)`; the
  not-selected line is unchanged.
- *HARNESS-115 AC-2* (VERSION and `floors.conf`): `doctor`, `floors`,
  `lib`, `worktree`; the not-selected line gains `selftest` at its end.
- *HARNESS-115 AC-5, second case* (a copy of the real `selftest.test.sh`
  declaring `floors.conf` is still printed, `despite`): its subject no
  longer reads the real file, so the case is pointed at the copy of
  `floors.test.sh`, which does. This is AC-3's second half. The claim is
  the same; the first case (`doctor` and VERSION) is untouched.
- Descriptions and the describe headings of those cases are updated to say
  what they now hold. Every other case in the suite is untouched.
- New: AC-1's case, AC-2's case, AC-3's first half.

That suite spells no changed path whole on purpose (its "names none of
AC-1's four paths whole" block); the new cases keep to that, building
`floors.test.sh`'s path the way `H115_ST` is built.

**C-6. Oracle partition.** Mechanical, pinned exactly: every list, reason
line and not-selected line in AC-1, AC-2, AC-3 and C-5. Settled, read out:
9, 357 and 366. Nothing is oracle-free.

**C-7. Baselines** (scratch clone of main `d495ae7`, 2026-11-25): a
`CLAUDE.md`-only diff selects 14 of 35 (`attest lib mutate phase-guard plan
refresh reporting rules-trim run-queue selftest-needed shipped-docs sigpipe
story worktree`), no not-selected line; a `floors.conf`-only diff selects
`selftest`, with `not selected (fixture-only): host-load refresh run-lock
run-queue`.

## Deferred verifications

<!-- REQUIRED when a verification this story depends on provably cannot run in
     the phase that wants it; omit the section otherwise. Written by the Lead PO
     at PLANNED, and the phase that owns it pastes the result in.
     The case this exists for: a negative control for a round trip, a threshold
     or a codec has to break the real implementation to mean anything, and in
     RED there is no implementation to break. RED naming the control and saying
     it could not run it is the honest answer; RED claiming a verification it
     did not do is the failure. One block per entry:
       * what it verifies, as a falsifiable condition - "with one field dropped
         from the encoder, AC-1's property test MUST fail"
       * why the phase that wants it cannot run it
       * THE PHASE THAT OWNS IT, declared as `Owner: GATES` (or RED, GREEN,
         REVIEW). check-boundaries.sh refuses a PR
         whose block names no phase
       * the RESULT, pasted, once that phase runs it: what was mutated, what
         failed, and that the file was restored - or the word WAIVED with the
         reason. check-boundaries.sh refuses a PR that has neither. A result
         counts only as a block: a line beginning with three backticks or
         three tildes (a fence), or a line indented by exactly four spaces.
         Prose does not count, nor inline code in backticks, nor a tab, nor
         anything inside an HTML comment
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

The budget is `rules.md`, "Mutation work per story". Three entries: the
"defect put back"; the probe against the real tree, which this story owes
because a declaration is a claim about a real suite that no fixture can
check; and the proof that the move was a move.

- **DV-1 (defect put back: a declaration removed).** Through `bash
  scripts/mutate.sh .claude/tests/attest.test.sh '<expression deleting its
  fixture-only line for CLAUDE.md>' -- bash scripts/selftest.sh
  selftest-needed`, AC-1's case **must** fail: stdout gains `attest` (six
  lines), the header says 6, and the not-selected line loses `attest`.
  AC-2's case still passes. Paste the failing assertions with expected and
  actual, the summary line and the restore line. The case copies the real
  suites when it runs, so the mutation of the real file reaches it.
  **Owner: GATES.**

- **DV-2 (the declarations are true of the real suites).** In a throwaway
  clone of the story branch (under `.claude/state/` or the OS temp
  directory, never the checkout itself), delete `CLAUDE.md` and run each of
  the nine declared suites from the clone (`bash
  <clone>/.claude/tests/<name>.test.sh`): every one **must** end `0 failed`
  at a count not below its floor. As the control, `mutate` run the same way
  **must** fail. Then, in the same clone with `CLAUDE.md` restored, replace
  `.claude/tests/floors.conf` with a file holding the single line `floor |
  nothing | 1` and run `selftest` and `floors`: `selftest` **must** end `0
  failed` at 357 or more, and `floors` **must** fail. Paste the eleven
  summary lines and the two failing ones. A declared suite that fails here
  reads the real file after all: its declaration comes out, and AC-1's list
  changes through `## Amendments`. **Owner: GATES.**

- **DV-3 (the move changed nothing it was not allowed to).** Compare
  `git show main:.claude/tests/selftest.test.sh` lines 416-576 with the
  moved text in `.claude/tests/floors.test.sh`, and paste the whole diff:
  it **must** consist only of the `floor_root` directory and the `COUNTS`
  rows of Contract C-3 and C-4. And `git diff main --
  .claude/tests/selftest.test.sh` **must** show only those lines removed,
  the header rewritten and the declaration added. **Owner: RED.**

  **Result (RED, test-developer, 2026-11-25). PASS.** Compared against
  this branch's base `5f0de59` (origin/main when the worktree was cut),
  not `d495ae7`: HARNESS-124 merged between them, and the block's only
  difference between the two is its `boundaries` row (687 -> 703). The
  moved range is `:415-576` (the separator line added, C-3 as amended).
  (a) the moved text against main: only the three `COUNTS` changes of
  C-4 - `floor_root` needed no edit, because the new suite names its
  scratch directory `FIX` (C-3, amended):

```
--- git show 5f0de59:.claude/tests/selftest.test.sh, lines 415-576
+++ .claude/tests/floors.test.sh, lines 28-190
@@ -120,6 +120,7 @@
 classify 55
 dispatch 205
 doctor 71
+floors 9
 gate-reminder 32
 gates 1002
 grep-count 38
@@ -139,8 +140,8 @@
 run-lock 141
 run-queue 901
 security-audit 52
-selftest 366
-selftest-needed 1099
+selftest 357
+selftest-needed 1165
 settings 70
 shipped-docs 24
 sigpipe 91
```

  (b) `git diff 5f0de59 -- .claude/tests/selftest.test.sh`, whole: the
  header rewritten (`:36-38` -> ten lines, the declaration among them) and
  `:415-577` removed. The removed lines were checked against main's
  `:415-577` with `cmp`: identical, 163 lines.

```
diff --git a/.claude/tests/selftest.test.sh b/.claude/tests/selftest.test.sh
index 0e47053..c7a764b 100644
--- a/.claude/tests/selftest.test.sh
+++ b/.claude/tests/selftest.test.sh
@@ -33,9 +33,16 @@
 #    floors.conf, so nothing here depends on - or disturbs - the real suites
 #    whose counts the shipped floors.conf records.
 #
-# The one real-tree assertion block reads .claude/tests/floors.conf itself and
-# checks it against the counts measured from a full run of this repository.
-# Those are read out, not re-derived.
+# The real-tree assertion block - the shipped floors file has a floor for every
+# suite, each at the count measured from a full run of this repository - lives
+# in floors.test.sh, beside this file (HARNESS-131). It moved so that a story
+# raising a floor selects that suite before a PR, not this one; this suite
+# never reads the real floors file. (The name is left bare on purpose: the
+# whole path here would make every edit to that suite's table select this
+# one again.)
+#
+# fixture-only: .claude/tests/floors.conf
+#   writes its fixture's own floors files; never reads the real one.
 
 . "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
 
@@ -412,169 +419,6 @@ line="$(shortfall)"
 assert_contains "space is trimmed and the commented-out floor ignored" \
   "did 3 units of work, below the floor of 9" "$line"
 
-# ---------------------------------------------------------------------------
-describe "AC-6/AC-7  the shipped floors file covers every suite, at its count"
-
-# The real tree, not a fixture. AC-6 makes C-3's table exhaustive; AC-7's own
-# control is that `profiles` is recorded at 44 and not at its 1 call site.
-REAL="$REPO_ROOT/.claude/tests/floors.conf"
-
-# One awk over the file, for the same reason as shortfall() above: `sed | head -1`
-# is a pipeline into an early-exit reader, and check-sigpipe.sh flagged it.
-floor_of() { # <suite> <file>   the value recorded for a suite in <file>, or empty
-  awk -v want="$1" '
-    { line = $0; sub(/#.*/, "", line) }
-    { n = split(line, f, "|") }
-    n < 3 { next }
-    { for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t]+$/, "", f[i]) } }
-    f[1] == "floor" && f[2] == want && f[3] ~ /^[0-9]+$/ { print f[3]; exit }
-  ' "$2" 2>/dev/null
-}
-
-# suites_without_floor <root>   The space-joined names of the suites in
-# <root>/.claude/tests/*.test.sh that have a floor line in neither
-# <root>/.claude/tests/floors.conf nor, when it exists,
-# <root>/.claude/tests/project-floors.conf. Empty when every suite is floored.
-# HARNESS-021: this loop used to read floors.conf only, so every consuming
-# project that floors its project-*.test.sh suites in project-floors.conf (as
-# HARNESS-020 designed) failed the assertion below. Taking a root is what lets
-# the fixture cases further down point it at a tree that is not this one.
-suites_without_floor() {
-  _swf_dir="$1/.claude/tests"
-  _swf_missing=""
-  for _swf_s in "$_swf_dir"/*.test.sh; do
-    [ -e "$_swf_s" ] || continue
-    _swf_n="$(basename "$_swf_s" .test.sh)"
-    [ -n "$(floor_of "$_swf_n" "$_swf_dir/floors.conf")" ] && continue
-    if [ -f "$_swf_dir/project-floors.conf" ]; then
-      [ -n "$(floor_of "$_swf_n" "$_swf_dir/project-floors.conf")" ] && continue
-    fi
-    _swf_missing="$_swf_missing $_swf_n"
-  done
-  printf '%s' "${_swf_missing# }"
-}
-
-assert_eq "every suite in .claude/tests has a floor" "" "$(suites_without_floor "$REPO_ROOT")"
-
-# HARNESS-021 fixture cases for suites_without_floor. Each root is a throwaway
-# directory under $FIX holding only the .claude/tests files the helper reads:
-# empty suite files (it reads names, not contents) and the floors files. Every
-# needle is the helper's WHOLE output compared with assert_eq, so a helper that
-# reports nothing, or reports the right name among wrong ones, cannot pass.
-
-# floor_root <case> <suite>...   A fresh root with an empty <suite>.test.sh for
-# each name. Prints the root. floors.conf / project-floors.conf are written by
-# the caller, so "absent" is a case and not an accident.
-floor_root() {
-  _fr="$FIX/floor-roots/$1"; shift
-  rm -rf "$_fr"; mkdir -p "$_fr/.claude/tests"
-  for _fr_s in "$@"; do : > "$_fr/.claude/tests/$_fr_s.test.sh"; done
-  printf '%s' "$_fr"
-}
-
-describe "HARNESS-021 AC-1  a suite floored only in project-floors.conf is not reported missing"
-
-R="$(floor_root ac1 alpha project-mine)"
-printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
-printf '# a project'"'"'s own suites\nfloor | project-mine | 4\n' > "$R/.claude/tests/project-floors.conf"
-assert_eq "a suite floored in project-floors.conf alone is not reported as missing a floor" \
-  "" "$(suites_without_floor "$R")"
-# The same, beside an unfloored suite: the project floor excuses project-mine
-# and nothing else, so the output is exactly the orphan.
-R="$(floor_root ac1b alpha project-mine project-orphan)"
-printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
-printf 'floor | project-mine | 4\n' > "$R/.claude/tests/project-floors.conf"
-assert_eq "beside an unfloored suite, only the unfloored one is reported" \
-  "project-orphan" "$(suites_without_floor "$R")"
-
-describe "HARNESS-021 AC-2  control: a suite floored in neither file is reported, by name"
-
-# Without this, a helper that reports nothing satisfies AC-1. A project-floors.conf
-# EXISTS here (comment only), so this also refuses a helper that treats the
-# file's mere presence as excusing every suite. Green under the old and the new
-# helper alike - it is the control, not the change.
-R="$(floor_root ac2 alpha project-orphan)"
-printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
-printf '# a project file that floors nothing\n' > "$R/.claude/tests/project-floors.conf"
-assert_eq "a suite floored in neither file is reported, and only that suite" \
-  "project-orphan" "$(suites_without_floor "$R")"
-
-describe "HARNESS-021 AC-3  with no project-floors.conf the check behaves as before"
-
-R="$(floor_root ac3 alpha beta gamma)"
-printf 'floor | alpha | 3\nfloor | gamma | 1\n' > "$R/.claude/tests/floors.conf"
-assert_eq "with no project-floors.conf, a suite missing from floors.conf is reported" \
-  "beta" "$(suites_without_floor "$R")"
-# Two missing, to pin the space-joined shape the real-tree message prints.
-R="$(floor_root ac3b alpha beta gamma)"
-printf 'floor | alpha | 3\n' > "$R/.claude/tests/floors.conf"
-assert_eq "and several missing suites are reported space-joined, in name order" \
-  "beta gamma" "$(suites_without_floor "$R")"
-# AC-3's second half - this repository's real tree still passes - is the
-# real-tree assertion above. Deliberately NOT asserted: that the real tree has
-# no project-floors.conf. This file is copied into consuming projects, which
-# do ship one, and there that assertion would be the defect this story removes.
-
-# The counts measured from a full run of THIS repository, read out rather than
-# re-derived. MT's numbers were deliberately NOT inherited: its suite set is a
-# different one, and a floor copied from another tree is a floor nobody
-# measured - which is the exact defect this mechanism exists to catch, pointed
-# at itself. Confirmed against the CI run of the same tree, and three of them
-# (profiles, mutate, lib) re-run locally at the port.
-wrong=""
-while read -r n v; do
-  [ -z "$n" ] && continue
-  got="$(floor_of "$n" "$REAL")"
-  [ "$got" = "$v" ] || wrong="$wrong $n=${got:-<none>}(want $v)"
-done <<'COUNTS'
-attest 179
-boundaries 703
-briefs 31
-ci-local 52
-classify 55
-dispatch 205
-doctor 71
-gate-reminder 32
-gates 1002
-grep-count 38
-host-load 72
-lib 332
-mutate 328
-new-story 79
-phase 73
-phase-guard 388
-plan 287
-policy 17
-procedure 183
-profiles 132
-refresh 215
-reporting 27
-rules-trim 50
-run-lock 141
-run-queue 901
-security-audit 52
-selftest 366
-selftest-needed 1099
-settings 70
-shipped-docs 24
-sigpipe 91
-spawns 69
-story 97
-tidy 206
-worktree 73
-COUNTS
-assert_eq "and each records the executed count measured on this tree" "" "$wrong"
-
-# Named individually, because these two are the reason AC-7 is a criterion
-# rather than a note: a call-site implementation records 1 and 104. HARNESS-010
-# moved lib from 139 to 197 and phase-guard from 188 to 288 - both floors are
-# recorded in RED, so both suites sit BELOW them until the reconciled parser
-# lands. See the note at the foot of floors.conf.
-assert_eq "profiles is floored at its 132 executed assertions, not its call-site count" \
-  132 "$(floor_of profiles "$REAL")"
-assert_eq "lib is floored at its 332 executed assertions, not its call-site count" \
-  332 "$(floor_of lib "$REAL")"
-
 # ===========================================================================
 # HARNESS-020: a project declares its own suites' floors in
 # .claude/tests/project-floors.conf, which upstream never ships and the refresh
```


**Results, GATES, 2026-11-25, run by the orchestrator on commit `0b9dc12`.**

DV-1, the defect put back: `attest.test.sh`'s `# fixture-only: CLAUDE.md`
line deleted through `mutate.sh`, against `bash scripts/selftest.sh
selftest-needed`. AC-1's case fails both from the root and from a
subdirectory: `attest` is added to stdout (six lines), the header reads 6,
and the not-selected line loses `attest`. AC-2's case passes (it has no FAIL
line). AC-3's first half fails too. That is expected: it also changes
`CLAUDE.md` over the real suites, so its pinned list gains `attest` in the
same way. Restored and verified; `mutate.sh --check` is clean.

```
=== mutate: .claude/tests/attest.test.sh (1 line(s) changed by /^# fixture-only: CLAUDE.md$/d) ===
=== mutate: running bash scripts/selftest.sh selftest-needed ===
selftest-needed: 1149 passed, 16 failed
=== mutate: command exited 1; restored (verified byte-for-byte against .claude/state/mutations/.claude_tests_attest.test.sh.20261125T235600Z.1299127.bak) ===
      8     FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it [root x4, subdir x4]
      8     FAIL AC-3: a copy of the real mutate.test.sh declaring CLAUDE.md is still printed when CLAUDE.md changes, saying why [root x4, subdir x4]
    FAIL AC-1: ... [from root]: stdout is exactly the pinned list
         expected: mutate / reporting / run-queue / selftest-needed / story
         actual:   attest / mutate / reporting / run-queue / selftest-needed / story
    FAIL AC-1: ... [from root]: stderr's first line is exactly the pinned header
         expected: selftest-needed: suites — 5 of 36 selected from 1 harness path(s) changed against main (merge-base 80621cd)
         actual:   selftest-needed: suites — 6 of 36 selected from 1 harness path(s) changed against main (merge-base 80621cd)
    FAIL AC-1: ... [from root]: stderr's last line is exactly the not-selected line
         expected:   not selected (fixture-only): attest lib phase-guard plan refresh rules-trim shipped-docs sigpipe worktree
         actual:     not selected (fixture-only): lib phase-guard plan refresh rules-trim shipped-docs sigpipe worktree
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

DV-2, run in a throwaway clone of `0b9dc12` under `.claude/state/dv2-clone`.
With `CLAUDE.md` deleted, each of the nine declared suites ends `0 failed`,
each exactly at its floor. The control, `mutate`, fails on the assertion
that reads the real `CLAUDE.md`. With `CLAUDE.md` restored and
`floors.conf` replaced by `floor | nothing | 1`, `selftest` ends `0 failed`
at 357 and `floors` fails:

```
--- CLAUDE.md deleted
attest rc=0: attest: 179 passed, 0 failed
lib rc=0: lib: 332 passed, 0 failed
phase-guard rc=0: phase-guard: 388 passed, 0 failed
plan rc=0: plan: 287 passed, 0 failed
refresh rc=0: refresh: 215 passed, 0 failed
rules-trim rc=0: rules-trim: 50 passed, 0 failed
shipped-docs rc=0: shipped-docs: 24 passed, 0 failed
sigpipe rc=0: sigpipe: 91 passed, 0 failed
worktree rc=0: worktree: 73 passed, 0 failed
mutate rc=1: mutate: 327 passed, 1 failed
    FAIL AC-7: CLAUDE.md's Running things block lists bash scripts/mutate.sh --check
--- CLAUDE.md restored, floors.conf replaced
selftest rc=0: selftest: 357 passed, 0 failed
floors rc=1: floors: 5 passed, 4 failed
    FAIL every suite in .claude/tests has a floor
    FAIL and each records the executed count measured on this tree
    FAIL profiles is floored at its 132 executed assertions, not its call-site count
```

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

Planned by `bash scripts/plan.sh write HARNESS-131` from `.claude/harness/models.conf`.
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
- PLANNED, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-25; no override reported. Planned by `/plan-story` in a batch of five (HARNESS-128 to 132).
- RED, `test-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-25; no override. Orchestrator checked all four attest records `fresh` itself on tree `655c422` (`selftest-needed: 1165 passed, 0 failed`, `floors: 9 passed, 0 failed`, `selftest: 357 passed, 0 failed`, `--fast` exit 0, vacuous), read the step-1 watched failure (`selftest-needed: 1110 passed, 50 failed`, every FAIL in a HARNESS-131 or changed HARNESS-115 case) and ran none of them again.
- GREEN: no dispatch; a verified no-op by the orchestrator (C-1), recorded under `## Notes`.
- GATES, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-25; no override. Ran `bash scripts/gates.sh` only: exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).`, not queued; orchestrator checked the record `fresh`. DV-1 and DV-2 were run by the orchestrator, results under `## Deferred verifications`; VERSION 144.
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **The selection rules.** `scripts/selftest-needed.sh` is not edited: no
  new rule, no change to what a declaration means, no checking that a
  declaration is true (that stays "the declaring suite's to know", and DV-2
  is this story's one check of it).
- **The five suites that read the real `CLAUDE.md`.** `run-queue` among
  them, the longest suite; it reads the file's Running things section and
  stays selected. Narrowing what those five read is not this story.
- **Other over-selection.** `.claude/harness/VERSION`, the three confs
  `make_fixture` copies, `_lib.sh` and `lib.sh` (which select every suite
  by rule), and any other path.
- **Removing the hand-copied table.** It moves; it is not merged into
  `floors.conf` or dropped. A floor is still recorded in two places.
- **Consuming projects.** `floors.test.sh` reaches them by the next refresh
  like any other suite. No refresh is run here.
- **CI.** CI runs every suite whatever is selected. This story changes the
  local pre-PR run only.
- Any change to an assertion's needle, description or expected value other
  than the ones Contract C-5 lists.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

Every criterion is mechanical (C-6) and is pinned at the level where the
selection actually happens: `scripts/selftest-needed.sh --suites` run over
`h115_real`, a fixture repository holding a copy of every shipped suite, so
the declarations and the moved block are judged by the real script over
the real suite text, not by a stub. `h115_expect` compares stdout whole and
its line count, the header exactly, the not-selected line exactly and last
(and that there is exactly one), and each reason line exactly once, from the
fixture root and from `src/`. `<m>` is counted from the real directory.

| Test (`.claude/tests/selftest-needed.test.sh` unless named) | What it asserts | AC |
|---|---|---|
| `HARNESS-131 AC-1` (new) | CLAUDE.md (tracked on `main`, edited on the branch) changed: stdout exactly `mutate reporting run-queue selftest-needed story`, header `5 of <m> from 1`, five `CLAUDE.md (mentioned)` reasons, last line the nine-name not-selected line | AC-1 |
| `HARNESS-131 AC-2` (new) | floors.conf changed: stdout exactly `floors`, header `1 of <m> from 1`, reason `.claude/tests/floors.conf (mentioned)`, last line `... host-load refresh run-lock run-queue selftest` | AC-2, AC-6's control |
| `HARNESS-131 AC-3` (new) | the copy of the real `mutate.test.sh` with `# fixture-only: CLAUDE.md` appended on `main`: `mutate` still printed with the `despite` reason, the rest as AC-1 | AC-3 (first half) |
| `HARNESS-115 AC-5`, second case (re-pointed, C-5) | the copy of the real `floors.test.sh` with `# fixture-only: .claude/tests/floors.conf` appended: `floors` printed with the `despite` reason; not-selected line gains `selftest` | AC-3 (second half), AC-5 |
| `HARNESS-115 AC-1` (changed, C-5) | the four-path case prints 8: `floors` added `(mentioned)`, `selftest` now `(itself)`; not-selected line unchanged | AC-5 |
| `HARNESS-115 AC-2` (changed, C-5) | VERSION + floors.conf: `doctor floors lib worktree`; not-selected line gains `selftest` | AC-5, AC-6 |
| `HARNESS-115` "names none of AC-1's four paths whole" (one assertion added) | this suite's source holds the whole `floors.test.sh` path on no line, so its copy in the fixtures is not a mention | AC-5 (keeps the pinned lists reachable) |
| `.claude/tests/floors.test.sh` (moved, 9 assertions) | the real tree has a floor for every suite; the five HARNESS-021 `suites_without_floor` cases; every floor equals the `COUNTS` row (now with `floors 9`, `selftest 357`, `selftest-needed 1160`); `profiles` and `lib` by name | AC-4 |
| `bash scripts/selftest.sh floors` / `selftest` | `floors` executes 9, `selftest` executes 357 (366 on main), each at its floor | AC-4 |
| `.claude/tests/selftest.test.sh` (cut) | holds `# fixture-only: .claude/tests/floors.conf` at column 0; no `$REPO_ROOT/` + floors.conf, no `suites_without_floor` | AC-6 (checked by grep in the handoff; its behavioural consequence is AC-2's not-selected line) |

AC-6's three textual conditions are not given an assertion of their own:
AC-6's stated control is AC-2's not-selected line, which fails if the
declaration is missing (selftest printed `(mentioned)`) or contradicted
(selftest printed `despite`); the greps are in the handoff.

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

Written by the test-developer dispatch (declared `model: opus`, resolved
`claude-opus-5-5`, no override), 2026-11-25, in worktree
`D:/adh-HARNESS-131`, branch base `5f0de59`. All timings are local, a
loaded Windows host; none from CI.

**GREEN has nothing to write.** C-1: every path this story writes is a
suite or the floors file, classified `harness`, and RED wrote them all. The
tests were watched to fail against the unchanged suites (step 1 below),
then the declarations and the move landed and the same suites pass (step
3). `scripts/selftest-needed.sh`, `scripts/selftest.sh`, `_lib.sh` and
`CLAUDE.md` are untouched (`git diff --stat 5f0de59` lists none of them).
GREEN's job is to confirm the step-3 records are still fresh
(`bash scripts/attest.sh check -- <command>`) and move on; GATES writes
`VERSION`.

**Commands.**

    bash scripts/attest.sh -- bash .claude/tests/selftest-needed.test.sh
    bash scripts/attest.sh -- bash .claude/tests/floors.test.sh
    bash scripts/attest.sh -- bash .claude/tests/selftest.test.sh
    bash scripts/attest.sh -- bash scripts/selftest.sh floors
    bash scripts/attest.sh -- bash scripts/gates.sh --fast

**Step 1, watched to fail** (new and changed pins written, every other
file unchanged). Record: `exit: 1`, `last: selftest-needed: 1110 passed,
50 failed`, log `.claude/state/attest-logs/20261125T222404Z.1177605.log`
(tree `4fe2427`, 662 s). The 50, by case (each from root and from `src/`):

    10  FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it
    10  FAIL AC-1: VERSION, floors.conf, selftest.test.sh and shipped-docs.test.sh changed over the real suites print the eight suites that read, scan or are them
     6  FAIL AC-2: VERSION and floors.conf changed over the real suites print doctor, floors, lib and worktree, and leave selftest out
     6  FAIL AC-2: floors.conf changed over the real suites prints floors alone, and names selftest among the suites that declare it
    10  FAIL AC-3: a copy of the real mutate.test.sh declaring CLAUDE.md is still printed when CLAUDE.md changes, saying why
     8  FAIL AC-5 / HARNESS-131 AC-3: a copy of the real floors.test.sh declaring floors.conf is still printed when floors.conf changes

The two controls the story names, verbatim from the log (root run; the
`src/` run is identical): AC-1 prints 14 names and no not-selected line,
AC-2 prints `selftest`.

```
  HARNESS-131 AC-1: a CLAUDE.md edit over the real suites selects the five suites that read it
    FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it [from root]: stdout is exactly the pinned list
         expected: mutate
         reporting
         run-queue
         selftest-needed
         story
         actual:   attest
         lib
         mutate
         phase-guard
         plan
         refresh
         reporting
         rules-trim
         run-queue
         selftest-needed
         shipped-docs
         sigpipe
         story
         worktree
    FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it [from root]: stdout has exactly 5 line(s)
         expected: 5
         actual:   14
    FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it [from root]: stderr's first line is exactly the pinned header
         expected: selftest-needed: suites — 5 of 35 selected from 1 harness path(s) changed against main (merge-base badcd5e)
         actual:   selftest-needed: suites — 14 of 35 selected from 1 harness path(s) changed against main (merge-base badcd5e)
    FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it [from root]: stderr's last line is exactly the not-selected line
         expected:   not selected (fixture-only): attest lib phase-guard plan refresh rules-trim shipped-docs sigpipe worktree
         actual:     worktree         CLAUDE.md (mentioned)
    FAIL AC-1: CLAUDE.md changed over the real suites prints mutate, reporting, run-queue, selftest-needed and story, and names the nine that declare it [from root]: stderr holds 1 not-selected line(s)
         expected: 1
         actual:   0
  HARNESS-131 AC-2: a floors.conf edit over the real suites selects floors, not selftest
    FAIL AC-2: floors.conf changed over the real suites prints floors alone, and names selftest among the suites that declare it [from root]: stdout is exactly the pinned list
         expected: floors
         actual:   selftest
    FAIL AC-2: floors.conf changed over the real suites prints floors alone, and names selftest among the suites that declare it [from root]: stderr's last line is exactly the not-selected line
         expected:   not selected (fixture-only): host-load refresh run-lock run-queue selftest
         actual:     not selected (fixture-only): host-load refresh run-lock run-queue
    FAIL AC-2: floors.conf changed over the real suites prints floors alone, and names selftest among the suites that declare it [from root]: stderr's reason line for floors is exactly `.claude/tests/floors.conf (mentioned)`, once
         expected: 1
         actual:   0
```

Why it is the right failure: every red is a selection list, a header count,
a reason line or the not-selected line - the script ran, exited 0 and
answered; it answered with today's selection. The AC-5 second case
additionally showed `1 of 36` against an expected `1 of 35`, because its
hook appended a declaration to a `floors.test.sh` copy that did not exist
yet and so created a one-line suite in the fixture; that disappears once the
real file exists (it did). The step-1 run predates the five AC-6
assertions (below), which were written after it.

**Step 3, passing** (final tree `655c422`, every record `status: ok`):

| Command | exit | last | log |
|---|---|---|---|
| `bash .claude/tests/selftest-needed.test.sh` | 0 | `selftest-needed: 1165 passed, 0 failed` (993 s) | `.claude/state/attest-logs/20261125T225418Z.1234841.log` |
| `bash .claude/tests/floors.test.sh` | 0 | `floors: 9 passed, 0 failed` (12 s) | `.claude/state/attest-logs/20261125T225306Z.1231898.log` |
| `bash .claude/tests/selftest.test.sh` | 0 | `selftest: 357 passed, 0 failed` (436 s) | `.claude/state/attest-logs/20261125T225327Z.1232771.log` |
| `bash scripts/selftest.sh floors` | 0 | `1 harness suite(s) passed.` - "all 1 suite(s) met their declared floor (9 assertions executed, 9 declared)" | `.claude/state/attest-logs/20261125T225335Z.1233048.log` |
| `bash scripts/gates.sh --fast` | 0 | `All required gates passed (0 ran, 5 unconfigured, 0 known).` | `.claude/state/attest-logs/20261125T225517Z.1237362.log` |

`gates.sh --fast` has the expected shape for this repository: every gate
UNCONFIGURED (BOOTSTRAPPED=no), and it lists `floors.test.sh` as UNTRACKED -
it is new and uncommitted, and the orchestrator's commit stages it. Tree
guards over the final tree: `check-sigpipe: scanned 66 shell file(s), 59
with pipefail, 0 finding(s)`, `check-grep-count: scanned 66 shell file(s),
0 finding(s)`, both exit 0; `classify.sh --list harness` returns
`.claude/tests/floors.test.sh`, so both scanned it.

**Measured counts (C-4).** `floors` 9 and `selftest` 357, exactly the
settled numbers: 9 + 357 = 366, `selftest`'s floor on main.
`selftest-needed` 1099 -> 1165, +66, all unconditional: HARNESS-131 AC-1 22,
AC-2 14, AC-3 22 (11/7/11 per run, two runs each), AC-6 5, HARNESS-115
AC-1's added `floors` reason line 2, and one "names no path whole"
assertion for `floors.test.sh`. Step 1 measured 1160 executed before AC-6's
five existed. No other floor moved; the nine declaring suites gained only
comment lines.

**Files touched, and what each covers.**

| File | Change | AC |
|---|---|---|
| `.claude/tests/selftest-needed.test.sh` | `H131_FT` built from halves; HARNESS-115 AC-1 and AC-2 cases changed (C-5); AC-5's second case re-pointed at `floors.test.sh`; new HARNESS-131 AC-1, AC-2, AC-3, AC-6 blocks; one names-no-path assertion | AC-1, AC-2, AC-3, AC-5, AC-6 |
| `.claude/tests/floors.test.sh` (new) | header, `FIX` scratch dir, `selftest.test.sh` `:415-576` moved, `COUNTS` rows `floors 9`, `selftest 357`, `selftest-needed 1165`, `summary "floors"` | AC-4 |
| `.claude/tests/selftest.test.sh` | `:415-577` removed; header rewritten; `# fixture-only: .claude/tests/floors.conf` | AC-4, AC-6 |
| `.claude/tests/floors.conf` | `floor \| floors \| 9`; `selftest` 357; `selftest-needed` 1165; table-location comment names `floors.test.sh`; dated HARNESS-131 note | AC-4 |
| `attest`, `lib`, `phase-guard`, `plan`, `rules-trim`, `shipped-docs`, `sigpipe`, `worktree` `.test.sh` | `# fixture-only: CLAUDE.md` at column 0 plus an indented reason, before the `_lib.sh` line | AC-1 |
| `.claude/tests/refresh.test.sh` | `CLAUDE.md` appended to its existing declaration line (`:19`) | AC-1 |
| `docs/backlog/stories/HARNESS-131.md` | C-3 amended; `## Test plan`; this handoff; DV-3's result | - |

**C-2 re-read on this tree.** Every `CLAUDE.md` mention in all fourteen
suites was re-read at `5f0de59`: the set of suites is the same fourteen,
and every mention in the nine is at the line and of the kind the C-2 table
gives (no line shifted - HARNESS-124 touched none of them). No suite has
been added since PLANNED. So AC-1's list stands; no amendment needed.

**Export shape.** None: no module, no function signature, nothing imported.
What the tests pin is text: the nine declaration lines (column 0, exact),
the absence of `$REPO_ROOT/` + floors.conf and of `suites_without_floor` in
`selftest.test.sh`, the `$REPO_ROOT/.claude/tests/floors.conf` read in
`floors.test.sh` (the AC-3 second half needs it), and the floors.

**Passed on arrival, and what earns it.**

- HARNESS-131 AC-6's five assertions were written after the move, against a
  `selftest.test.sh` that already satisfied them. Earned by one mutation
  through `scripts/mutate.sh` (the declaration line deleted), below; the
  three absence needles are earned outside the framework by running the
  same awk counts over main's `selftest.test.sh`, where each must be
  non-zero for the needle to be able to fail:

      5f0de59: summary=1 decl=0 repo=1 brace=0 swf=9
      final:   summary=1 decl=1 repo=0 brace=0 swf=0

  `${REPO_ROOT}/` is 0 on both trees: no tree has ever spelled it there, so
  that needle is a guard against a spelling, unexercised - said so rather
  than claimed.
- In step 1, AC-3's `mutate ... despite` reason line passed already (the
  script's despite rule exists since HARNESS-115); the case still failed on
  its list, header and not-selected line.

**The AC-6 probe** (declaration deleted from `selftest.test.sh`, run
against the one suite that holds the assertion, on the final tree; local):

    bash scripts/mutate.sh .claude/tests/selftest.test.sh \
      '/^# fixture-only: \.claude\/tests\/floors\.conf$/d' \
      -- bash .claude/tests/selftest-needed.test.sh

```
=== mutate: .claude/tests/selftest.test.sh (1 line(s) changed by /^# fixture-only: \.claude\/tests\/floors\.conf$/d) ===
  44 - # fixture-only: .claude/tests/floors.conf
...
    FAIL AC-6: the real selftest suite holds `# fixture-only: <floors.conf>` at column 0, exactly once
         expected: 1
         actual:   0
...
    FAIL AC-2: floors.conf changed over the real suites prints floors alone, and names selftest among the suites that declare it [from root]: stdout is exactly the pinned list
         expected: floors
         actual:   floors
         selftest
    FAIL AC-2: floors.conf changed over the real suites prints floors alone, and names selftest among the suites that declare it [from root]: stderr's last line is exactly the not-selected line
         expected:   not selected (fixture-only): host-load refresh run-lock run-queue selftest
         actual:     not selected (fixture-only): host-load refresh run-lock run-queue

selftest-needed: 1138 passed, 27 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-131/.claude/state/mutations/.claude_tests_selftest.test.sh.20261125T231116Z.1271618.bak) ===
  44: # fixture-only: .claude/tests/floors.conf
```

The 27, by case: AC-6's declaration assertion 1; HARNESS-131 AC-2 8;
HARNESS-115 AC-2 8; HARNESS-115 AC-5 / HARNESS-131 AC-3 8; HARNESS-115
AC-1 2 (its `selftest (itself)` reason line - with the declaration gone,
the floors.conf mention sorts first and becomes the reason). No other
assertion moved. `bash scripts/mutate.sh --check` afterwards: `no stranded
mutation`. This doubles as AC-6's stated control ("with the path left ...
AC-2 fails"), in its declaration-missing form.

**Negative controls, expected values.**

| Control | Where | Expected | Measured |
|---|---|---|---|
| AC-1 before the declarations | step 1 | 14 names, no not-selected line | 14 names, 0 not-selected lines (above) |
| AC-2 before the move | step 1 | `selftest` | `selftest`, not-selected line without `selftest` (above) |
| AC-3 / C-5: a declaring copy that reads `$REPO_ROOT/` | step 3 | `mutate` and `floors` printed `despite` | passed, both, from root and `src/` |
| AC-4: a dropped moved assertion | `selftest.sh floors` | count below floor 9 fails | 9 executed, 9 declared |
| AC-6: declaration deleted | mutate.sh probe | AC-6 decl assertion and AC-2-shaped cases red | 27 red: AC-6 1, AC-2 cases 16, AC-5 8, HARNESS-115 AC-1 2; restored |
| DV-1 (GATES), DV-2 (GATES) | not run here | as the story says | **Not run in RED.** Both are GATES-owned and left to that phase |

**Discovered.**

- A whole path in a comment is a mention. The rewritten header of
  `selftest.test.sh` first named `.claude/tests/floors.test.sh` in full,
  which would have made every `COUNTS` edit select `selftest` again. It now
  names the suite bare; C-3 is amended to say so. Worth a line in the
  floors.conf convention if this recurs.
- The AC-6 assertions read `selftest.test.sh` through a composed path, so a
  `selftest.test.sh`-only diff does not select `selftest-needed` and the
  pre-PR run would not run them; AC-2's not-selected line (which does run on
  every floors.conf diff) and CI's full run cover that gap.
- bash reads a script lazily: a run started before the AC-6 block was
  appended still executed it (a void run, superseded, reported 1165). Not a
  defect, but a reason never to edit a suite while it runs.

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

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-26T01:16:12Z
    commit: 0b9dc12
    tree:   da28aa0922d39c76a83fcbf20820c9db3318e5a0
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


**Measured at PLANNED** (2026-11-25, a scratch clone of main `d495ae7`,
one line appended to the named file, `bash scripts/selftest-needed.sh
--suites main`):

    --- CLAUDE.md only
    selftest-needed: suites — 14 of 35 selected from 1 harness path(s) changed against main (merge-base d495ae7)
      attest           CLAUDE.md (mentioned)
      lib              CLAUDE.md (mentioned)
      mutate           CLAUDE.md (mentioned)
      phase-guard      CLAUDE.md (mentioned)
      plan             CLAUDE.md (mentioned)
      refresh          CLAUDE.md (mentioned)
      reporting        CLAUDE.md (mentioned)
      rules-trim       CLAUDE.md (mentioned)
      run-queue        CLAUDE.md (mentioned)
      selftest-needed  CLAUDE.md (mentioned)
      shipped-docs     CLAUDE.md (mentioned)
      sigpipe          CLAUDE.md (mentioned)
      story            CLAUDE.md (mentioned)
      worktree         CLAUDE.md (mentioned)
    --- floors.conf only
    selftest-needed: suites — 1 of 35 selected from 1 harness path(s) changed against main (merge-base d495ae7)
      selftest  .claude/tests/floors.conf (mentioned)
      not selected (fixture-only): host-load refresh run-lock run-queue

- The audit names nine suites for the declaration. All nine held up when
  each mention was read (Contract C-2). None of them reads the real file
  through a glob, a file list or a copy of the tree: `sigpipe` lists
  harness `*.sh` files only, `shipped-docs` scans commands, agents and
  skills and pins that `CLAUDE.md` is not scanned, `attest`'s real-tree
  check loads three named procedure files.
- The block that moves is `selftest.test.sh:416-576`, nine executed
  assertions: one at `:457`, five between `:475` and `:512`, the `COUNTS`
  loop's one, and two at `:573-576`. `floor_of`, `suites_without_floor` and
  `floor_root` are used nowhere else in that suite.
- The real-tree assertion at `:457` reads the real `floors.conf` through a
  helper (`suites_without_floor "$REPO_ROOT"`), which the selection rule
  cannot see. If it stayed behind, the declaration of AC-6 would be false
  and nothing would say so. It moves with the rest.
- Other planners were writing HARNESS-124 to 127 and 133 to 136 in the
  same checkout at PLANNED. A suite one of them adds or edits is classified
  in RED by C-2's rule.

**Planning.** Planned by a `lead-po` dispatch on `fable`, resolved
`claude-fable-5-2`, 2026-11-25; no override.


**GREEN, 2026-11-25: a verified no-op, done by the orchestrator, no dispatch.**
Contract C-1 makes GREEN a no-op: RED wrote every path and the selection
rules do not change. Nothing was written in GREEN. `git diff origin/main...HEAD`
touches no path under `scripts/`, `.claude/hooks/`, `CLAUDE.md` or
`.claude/tests/_lib.sh`. Every changed path classifies `harness` or `docs`.
RED's four passing records still answer `fresh` against this tree, so none
was re-run:

    bash .claude/tests/selftest-needed.test.sh: fresh  (exit 0, selftest-needed: 1165 passed, 0 failed)
    bash .claude/tests/floors.test.sh: fresh           (exit 0, floors: 9 passed, 0 failed)
    bash .claude/tests/selftest.test.sh: fresh         (exit 0, selftest: 357 passed, 0 failed)
    bash scripts/gates.sh --fast: fresh                (exit 0, 0 ran, 5 unconfigured)

The negative controls in this story are mechanical pins checked by RED's
step-1 run (red, 1110/50) and its passing run. There is no threshold value
for GREEN to confirm.
