---
id: HARNESS-089
title: check-boundaries never deadlocks on a story copy near 64 KiB
slug: check-boundaries-never-deadlocks-on-a-st
epic: 
type: bug
status: todo
phase: PLANNED
branch: story/HARNESS-089-check-boundaries-never-deadlocks-on-a-st
depends_on: [HARNESS-094, HARNESS-095]      # the fast pre-PR self-test goes first (user decision, 2026-11-04); both must be DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/state/README.md, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

**A field report from fantasy-world-builder (FWB), measured on harness
release 99 and re-checked in the source of release 107 (`b65e2f4`), where
the code is unchanged.** Draft acceptance criteria from the report; the PO
refines them, writes the Contract and confirms `touches:` before RED.

On the Windows host FWB is developed on (Git for Windows, `GNU bash 5.3.15
x86_64-pc-cygwin`), `bash scripts/check-boundaries.sh` hung for **about five
hours** on WORLD-148's branch (2026-11-03), with no child process, printing
nothing after the `branch matches the story's frontmatter` line. It had to be
killed with `kill -9`, and FWB used CI's boundaries job (Linux) as the run of
record.

What was measured, and nothing beyond it:

- The hang is in `criteria_baseline` (check-boundaries.sh, around line 321).
  It reads every committed copy of the story, oldest first, up to the first
  copy that is not PLANNED, and feeds each one through
  `frontmatter_value - phase <<< "$txt"` (line 330 in release 107; the same
  shape on the base copy a few lines above).
- On WORLD-148 the first non-PLANNED copy (its RED commit) was **65,566
  bytes**.
- Reproduced alone, outside the script: a here-string of **65,565 bytes**
  blocked forever. `timeout 10 bash -c '... <<< "$1"'` did not return either.
  A here-string of about **30 KB** was fine.
- A 133 KB story passed check-boundaries on FWB's WORLD-046. That does not show
  a 133 KB here-string is fine, because only the copies up to the first
  non-PLANNED one are fed through, and those may have been small.

**Cause, as a hypothesis only.** Since bash 5.1, a here-string small enough to
fit in a pipe is written to a pipe rather than a temp file. A size near 64 KiB
hanging, with smaller ones fine, fits the pipe-size test going wrong on Cygwin.
That is not proven. The fix should not depend on it: reading a story copy any
way other than a here-string removes the question.

The here-string was a deliberate choice. The comment above `criteria_baseline`
says `git show | section -` was a pipeline into an early-exiting awk (the
SIGPIPE class `has_content` documents). Whatever replaces it has to avoid both
traps: no pipe into an awk that exits early, and no here-string of unbounded
size. A temp file under `.claude/state/` (never `$TMPDIR`, which is unset in
some of these shells), or awk reading the `git show` output to its end, both
qualify.

**Size of the class.** Release 107 has 75 `<<< "` here-strings across 13
files: check-boundaries.sh 15, gates.sh 18, plan.sh 13, refresh-harness.sh 6,
tidy.sh 5, lib.sh 5, and 1 to 3 in each of seven others. Most are fed short
values, such as a frontmatter field or a list of paths. This story covers only
the ones that can carry a whole story copy or a `git show` result. The rest
are listed under `## Out of scope`.

**The gate that fails if this story breaks:** every gate in this repository's
`project.conf` is unconfigured. The artifact is judged by `bash
scripts/selftest.sh boundaries`, which CI runs. CI is Linux, where the
deadlock does not happen. So no CI run can show the original failure, and AC-3
is a deferred verification on a Windows host.

## Acceptance criteria

All three are **mechanical**: an exact `ok`/`note` line, an exact refusal
line, an exit status under `timeout`.

- **AC-1 (the baseline does not depend on the copy's size)** — Given a fixture
  history built with the HARNESS-033 helpers (`crit_base`, `crit_branch`,
  `crit_commit`) where the first non-PLANNED copy of the story is exactly
  **65,566 bytes** on disk, and separately one of at least **135,000 bytes**,
  when `check-boundaries.sh` runs on this host under `timeout 120`, then it
  exits with the same status and prints the same criteria line
  (`ok    acceptance criteria unchanged since the last committed PLANNED
  state (<c7>)`, or the `first`/`base` form, with the same `<c7>`) as the
  same history built with small copies. Every HARNESS-033 case keeps its
  verdict, and so does every other case in `boundaries.test.sh`.
- **AC-2 (no here-string carries a story copy or a `git show` result)** —
  Given `scripts/check-boundaries.sh`, when a guard in `boundaries.test.sh`
  enumerates its `<<<` lines, then it is silent. The rule, mechanical: for
  each line holding `<<<`, every `$name` or `${name` token in the text after
  `<<<` names a variable; the guard is red for the line if any assignment to
  that variable anywhere in the script (`name=$(` or `name="$(`) opens with
  `git show`, `git cat-file`, `cat `, or `<` (the `$(< file)` form). One
  fault line per offending line: `scripts/check-boundaries.sh:<n>: here-string
  carries <name>, assigned from <command>`. The control: the script as it
  stands today is refused on exactly six lines (330, 336, 372, 1077, 1086,
  1113), and a fixture copy with the defect put back on one line is refused
  on that one line. A fixture copy whose here-string variable is assigned
  from `git rev-parse` is accepted.
- **AC-3 (no deadlock on this host)** — Given this Windows host (Git for
  Windows, `GNU bash 5.3.15 x86_64-pc-cygwin`, the same shell as the
  report's), when `check-boundaries.sh` runs over the 65,566-byte history of
  AC-1 under `timeout 120`, then its status is not 124 and the criteria line
  is printed. The defect-put-back control: with the here-string read of a
  story copy restored through `scripts/mutate.sh`, the same run exits 124.
  Measured here before RED: a here-string whose payload is 65,536 to 65,566
  bytes blocks forever; 65,535 and 66,000 do not. This is owned by DV-1 at
  GATES, on this host.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/state/README.md`, `.claude/harness/VERSION`

**Oracle partition.** All mechanical. Settled values to read out, measured on
this host on 2026-11-05 (`timeout 15 bash -c 'cat <<< "$1" | wc -c'`):
payloads of 30,000, 65,000 and 65,535 bytes return; 65,536, 65,565 and
65,566 block until killed (124); 66,000 to 140,000 return. Bash appends one
newline to a here-string, so a `$(git show)` of a 65,566-byte file (its
trailing newline stripped) writes 65,566 bytes, inside the window. A fixture
has to hit that window exactly, so its size is set on the file on disk and
checked with `wc -c` as a precondition assertion.

**The defect, by line, in `scripts/check-boundaries.sh` at `3b9f531`.**
`criteria_baseline` (lines 321-352) reads each committed story copy with
`txt="$(git show ...)"` and feeds it to `frontmatter_value - phase <<< "$txt"`
(330, 336). Line 371-373 reads the baseline copy the same way into
`crit_txt` and feeds `section - ... <<< "$crit_txt"`, then `sed <<<
"$before"`. The suppression block does it again for `sup_story` (1077) and
`sup_pstory` (1086), and feeds a whole `git show --unified=0` diff through
`suppression_hits <<< ...` (1113). Those six are AC-2's control.

**The fix (GREEN).** Every such read goes to a scratch file, never through a
here-string and never through a pipe into an early-exiting awk (`has_content`
above explains why not a pipe):

- One scratch directory, `.claude/state/check-boundaries/`, created on
  entry (`mkdir -p`), two files in it, `copy-$$.md` and `diff-$$.txt`, and a
  `trap 'rm -rf "$ROOT/.claude/state/check-boundaries/"*-$$.*' EXIT` set
  right after `fail=0`. `.claude/state/*` is gitignored, so neither
  `gates.sh`'s UNTRACKED check nor 3f sees them. `.claude/state/README.md`
  gets a row for `check-boundaries/*`, written by `scripts/check-boundaries.sh`,
  read by nothing (scratch for a `git show` result), hand-editable `yes`;
  `settings.test.sh` reads that table.
- `criteria_baseline`: `git show "$BASE:$f" > "$cp" 2>/dev/null` then
  `frontmatter_value "$cp" phase`; in the loop, `git show "$rev:$f" > "$cp"
  2>/dev/null || continue`, keeping the `|| continue` on `git show`'s own
  status, then `frontmatter_value "$cp" phase`.
- The baseline comparison: `git show "$crit_rev:$sfile" > "$cp"`, then
  `before="$(section "$cp" "Acceptance criteria" | sed 's/[[:space:]]*$//')"`,
  the same shape as the `after=` line beneath it (a pipe into `sed` is fine:
  `sed` reads to the end).
- The suppression block: `if ! git show "$c:$sfile" > "$cp" 2>/dev/null; then
  note ...; continue; fi`, then `frontmatter_value "$cp" phase`; the parent
  copy the same way; and the diff: `git show --format= --unified=0 "$c" --
  "$f" > "$dp" 2>/dev/null` with the existing `sup_refused` branch on
  failure, then `suppression_hits` reading the table, the separator line and
  the diff from a file: `{ printf '%s\n--8<-- diff\n' "$sup_table"; cat "$dp"; } > "$cp"`
  and `suppression_hits < "$cp"`. No change to `suppression_hits` itself.
- No other line of the script changes. The here-strings fed short values
  (234-235, 373's replacement, 392, 467, 469, 1038, 1105, 1118) stay.

**AC-2's guard (RED), in `boundaries.test.sh`.** A function
`here_string_sources <script>` that prints the fault lines above, over any
script path, so it runs over fixtures and over the real file. Fixture
copies are written under `$FIX`; the real-tree assertion runs it over
`$REPO_ROOT/scripts/check-boundaries.sh` and expects nothing. The
enumeration is awk, one pass; the assignment search is a second awk over the
same file keyed by variable name. Case-insensitive nothing: names are exact.

**AC-1 and AC-3 fixtures (RED).** A new describe after the HARNESS-033 block
reuses `crit_base`, `crit_branch`, `crit_commit` and
`run_boundaries_against`, wrapped so the run is `timeout 120 bash
scripts/check-boundaries.sh`: add a `timeout` variant of the runner rather
than editing the existing one. The oversized copy is the RED commit: build
the PLANNED copy small, then the RED copy with `## Notes` padded by a loop of
fixed-width lines until `wc -c` of the file is exactly 65,566 (precondition
asserted), then the working tree at GREEN. Expected: status not 124, and the
exact `ok    acceptance criteria unchanged since the last committed PLANNED
state (<c7>)` line, `<c7>` from the PLANNED commit, the same line the
small-copy twin of the history prints. The 135,000-byte twin likewise. On
today's code, on this host, both oversized cases exit 124 and print no
criteria line: that is RED's red, and RED pastes it. On Linux CI today's
code passes them; the Handoff says so, so GREEN does not read a green CI as
proof of anything.

**Planned return to RED (R-1), and why.** `sigpipe.test.sh` pins three
`scripts/check-boundaries.sh` lines by NUMBER (`DISCARDED`, lines 574-576:
`:395:res=$(printf`, `:434:rec=$(printf`, `:626:ph_at="$(git show`) with a
freshness check that fails as a stale fixture when a line moves. GREEN's
edits above line 395 move all three. GREEN cannot edit a test, so the story
returns to RED once after GREEN, with one remit: re-pin those three numbers.
The red that earns the re-pin is GREEN's own `sigpipe` run (the stale-fixture
lines, pasted into `## Regressions`), and the green after it is the same
suite. RED's first pass does **not** touch `sigpipe.test.sh`: the numbers are
not known until GREEN has written the lines.

**Floors.** `boundaries` rises from 518; RED records the measured count in
`floors.conf` with a comment and in `selftest.test.sh`'s table.

**Callers.** No signature changes. `section`, `frontmatter_value`,
`suppression_hits`, `has_content` keep their interfaces; only their call
sites in `check-boundaries.sh` change from `-`/stdin to a file path.
`plan.sh` has its own `section`; untouched.

**RED may amend any block above in place, with a reason; GREEN builds what the amended block says.**

## Deferred verifications

**DV-1 (AC-3, defect put back; the story's central claim). Owner: GATES, on
this host.** This host runs the same shell as the report
(`GNU bash 5.3.15 x86_64-pc-cygwin`) and reproduces the hang (Contract), so
the control runs here rather than being deferred to FWB. With GREEN's fix in
the tree, put the here-string read back on the loop's copy with
`bash scripts/mutate.sh scripts/check-boundaries.sh '<expr restoring txt="$(git show "$rev:$f" 2>/dev/null)" || continue and frontmatter_value - phase <<< "$txt" on the loop lines>' -- bash scripts/selftest.sh boundaries`
(name the lines GREEN wrote). AC-1/AC-3's 65,566-byte case must go red with
status 124 and no criteria line; the 135,000-byte case stays green (the
window is narrow). Paste the red lines and `mutate.sh`'s restore line. The
suite itself must not hang: the case runs under `timeout 120`, so the
mutated run costs two minutes and ends.

**DV-2 (AC-2, the guard sees the real file). Owner: GATES.** With the same
mutation as DV-1, the AC-2 real-tree assertion must print exactly one fault
line naming the restored line. Same `mutate.sh` run as DV-1 if both red
lines appear in one `boundaries` run; say so.

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

Planned by `bash scripts/plan.sh write HARNESS-089` from `.claude/harness/models.conf`.
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

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- The other 60 or so here-strings across the tree, which are fed short values
  such as a frontmatter field, a path list or a gate line. Any of them that can
  carry a whole file belongs in a follow-up story with the same AC-2 shape.
  Candidates to read first are gates.sh (18), plan.sh (13) and lib.sh (5).
- Proving the Cygwin mechanism. The fix removes the dependency on it.

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

- Filed 2026-11-04 from FWB, where the harness is vendored at release 107
  (PR 113 there). The FWB-side workaround, until this lands: if
  check-boundaries prints nothing for more than about two minutes after
  `branch matches`, run `git show <rev>:<story> | wc -c` on the branch's
  commits and suspect a copy near 65,536 bytes. Kill the hung run and let CI's
  boundaries job judge the commit.
- PO decisions at PLANNED, 2026-11-05 (orchestrator, Fable 5.1):
  1. **This host reproduces the hang** (same Cygwin bash 5.3.15), measured
     with here-strings of 30,000 to 140,000 bytes: 65,536-65,566 block,
     the rest return. So AC-3 and its control run here at GATES (DV-1), not
     on FWB's host.
  2. **A scratch file under `.claude/state/check-boundaries/`**, not
     process substitution: `frontmatter_value` and `section` are early-exit
     awks, and a `<(git show)` would be the pipe class `has_content`
     documents, only with its status hidden.
  3. **One planned return to RED for `sigpipe.test.sh`'s line-number pins**
     (Contract). The alternative, keeping the script's line count above 395
     unchanged, couples the fix to line arithmetic and is not taken.
  4. `touches:` confirmed and widened: `sigpipe.test.sh`,
     `selftest.test.sh` (its floor table), `.claude/state/README.md`.
