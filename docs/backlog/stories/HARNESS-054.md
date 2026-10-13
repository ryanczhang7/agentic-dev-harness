---
id: HARNESS-054
title: A spike that escalates a gate cannot merge without having run it
slug: a-spike-that-escalates-a-gate-cannot-mer
epic: 
type: fix
status: in-progress
phase: RED
branch: story/HARNESS-054-a-spike-that-escalates-a-gate-cannot-mer
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**A port.** manhwa-cropper commit `3ac70e3` ("MC-039: a spike's
required_gates escalation actually binds", story
`D:/manhwa-cropper/docs/backlog/stories/MC-039.md`, 2026-09-20) fixed this in
the downstream copy of `scripts/check-boundaries.sh`. It has to land upstream
before manhwa-cropper is next refreshed, or the refresh overwrites the fix
(memory: a local fix downstream is ported upstream first, never overwritten).
Triaged against upstream release 93 on 2026-10-11; `check-boundaries.sh` is
unchanged in release 94, so the line numbers below are current on `main`.

**The defect.** `scripts/check-boundaries.sh` step 3e, `:387-457`:

```bash
# 3e. The gate record was written by gates.sh and matches the code being merged
case "$ph:$story_type" in
  REVIEW:spike|DONE:spike) note "spike story; gate record not required" ;;
  REVIEW:*|DONE:*)
    gr="$(section "$sfile" "Gate results")"
    if ! awk ... "$GATE_MARKER" <<< "$gr"; then
      problem "story $sid: ## Gate results was not written by scripts/gates.sh. ..."
    else
      ...
      # A gate the story escalated must appear in the record as having passed.
      # gates.sh enforces this while it runs; this catches the record written
      # before the escalation was added, where the gate is optional again by
      # the time anyone looks.
      for g in $(frontmatter_list "$sfile" required_gates); do      # :449
        if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
          ok "story-required gate '$g' passed in the recorded run"
        else
          problem "story $sid: frontmatter requires gate '$g', but the recorded run has no PASS for it. Run 'bash scripts/gates.sh' again."
        fi
      done
    fi ;;
esac
```

The `required_gates` re-check lives inside the non-spike arm, and inside the
`else` of the marker test. So a spike that declares
`required_gates: [integration]`, never runs the gate, and reaches REVIEW
merges with exit 0 and nothing said but
`note  spike story; gate record not required`. The frontmatter field that
`story-authoring` tells the PO to fill "before RED" for exactly the case where
only an optional gate exercises the artifact binds nothing for a spike. The
existing describe in `.claude/tests/boundaries.test.sh:1337`, "a gate the
story escalated for itself appears in the record", uses only `type: feature`,
so no fixture has ever put a spike through this path.

**The exemption is right; its width is wrong.** A spike normally delivers a
document, and demanding a full recorded gate run to merge markdown would be
ceremony. But a spike that names a gate in `required_gates` has made a
deliberate claim that something in the repository does need checking, and
that is the one case the exemption must not cover.

**Reproduced on unmodified upstream** (release 93 tree, 2026-10-11) with the
downstream suite's four fixtures run as a standalone triage suite, pasted
verbatim in `## Notes` below. `triage: 10 passed, 4 failed`:

    FAIL  AC-1a an escalating spike with no gate record is refused
          expected to contain: story T-1: frontmatter requires gate 'integration'
          actual:  ... spike story; gate record not required
    FAIL  AC-1a and the run fails rather than noting and moving on
          expected: 1   actual: 0
    FAIL  AC-1b a recorded run with no PASS for the escalated gate is refused
    FAIL  AC-1b and that run fails too
          expected: 1   actual: 0

The two controls (AC-2, AC-3 below) pass already on upstream, which is what
makes them controls. With the port applied: 14/14, and the existing
`boundaries.test.sh` 113 passed, 0 failed.

**Which required gate fails if this breaks.** None in `project.conf`: this
repository is the harness itself and `BOOTSTRAPPED=no`. The artifact is
covered by `bash scripts/selftest.sh`, a blocking CI step that runs *before*
`gates.sh` (see `.github/workflows/`), which is the right place for a check
on the machinery `gates.sh` depends on. `required_gates: []` is therefore
correct, not a gap; `ci-local.sh` runs the same sequence locally.

## Acceptance criteria

- **AC-1** — *The bug, reproduced.* Given a story file with `type: spike`,
  `phase: REVIEW` and `required_gates: [integration]`, when
  `bash scripts/check-boundaries.sh main` runs against it, then it **fails**
  (exit 1) and its output contains
  `story T-1: frontmatter requires gate 'integration'`, in **both** of these
  cases, pinned separately because they fail through different code today:
  - **AC-1a** — the story has no `## Gate results` section at all;
  - **AC-1b** — `## Gate results` carries a real record written by
    `gates.sh` (marker, `result: pass`, matching `tree:`) from a
    `project.conf` that configures only `unit`, so the record has no
    `PASS integration` line.
  *Control:* both fixtures pass on `main` today with exit 0 and the note
  `spike story; gate record not required` (pasted above); RED must show them
  red against the unfixed script.
- **AC-2** — *The exemption survives for the case it was written for.* Given
  a story file with `type: spike`, `phase: REVIEW`, `required_gates: []` and
  no `## Gate results` section, when `check-boundaries.sh` runs, then it
  **passes** (exit 0) and its output still contains
  `spike story; gate record not required`. *Control:* a fix that deleted the
  spike arm would turn this red (the story would be refused for having no
  gate record); this passes on `main` today and must keep passing.
- **AC-3** — *A spike that escalates a gate and runs it merges.* Given a
  spike at `REVIEW` with `required_gates: [integration]` and a
  `## Gate results` section written by a real `gates.sh` run from a
  `project.conf` where `integration` is configured and passes, so the record
  carries `PASS         integration` and a `tree:` equal to `gate_tree_hash`
  of the committed fixture, when `check-boundaries.sh` runs, then it passes
  (exit 0) and no line of its output begins with `FAIL`. *Control:* AC-1b
  and AC-3 differ only in whether `integration` is in the record, so a fix
  that refused every escalating spike would pass AC-1 and fail this. Passes
  on `main` today and must keep passing.
- **AC-4** — *Nothing else moves.* Given `bash scripts/selftest.sh` (every
  suite, as CI runs it), when it runs after the fix, then every suite passes
  with its floors met, and `sigpipe`'s C-5 freshness assertion still finds
  all twelve status-discarded lines where it says they are. *Control:* the
  fix adds lines to `check-boundaries.sh` above `:608`, so the pin at
  `.claude/tests/sigpipe.test.sh:563`
  (`scripts/check-boundaries.sh:608:ph_at="$(git show`) goes stale unless
  this story moves it; a stale pin is reported as `no longer holds`, not as
  a pass.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/sigpipe.test.sh`

**Pinned by the Lead PO before RED (2026-10-12).** RED may amend any block
below in place, with a reason beside it; GREEN builds what the amended block
says.

- **Where the fix lives, exactly.** `scripts/check-boundaries.sh`, step 3e.
  Delete the comment and `for g in ...` loop inside the non-spike arm's
  `else` (`:444-455`, the blank line at `:443` with them), and after the
  `esac` that closes 3e (`:457`) add a new block, for every story type, gated
  on phase alone. This is the downstream text, verbatim from
  `3ac70e3` (`git -C D:/manhwa-cropper show 3ac70e3 -- scripts/check-boundaries.sh`),
  with the matcher already in upstream's pipe-free shape; GREEN may reword
  the comment but not the `problem` text:

  ```bash
  # 3e-i. A gate the story escalated must appear in the record as having passed.
  #
  # gates.sh enforces this while it runs; this catches the record written before
  # the escalation was added, where the gate is optional again by the time
  # anyone looks - and the record that was never written at all.
  #
  # Outside the case above on both axes: every story type, spike included (the
  # spike exemption is about the RECORD; a spike that names a gate in
  # required_gates has claimed something needs checking), and outside the marker
  # test's else, so a story with no ## Gate results is told WHICH gate it did not
  # run.
  case "$ph" in
    REVIEW|DONE)
      gr="$(section "$sfile" "Gate results")"
      for g in $(frontmatter_list "$sfile" required_gates); do
        if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
          ok "story-required gate '$g' passed in the recorded run"
        else
          problem "story $sid: frontmatter requires gate '$g', but the recorded run has no PASS for it. Run 'bash scripts/gates.sh' again."
        fi
      done ;;
  esac
  ```

  Net change: +11 lines to `check-boundaries.sh` (hunk `@@ -441,21 +441,32 @@`
  against release 93).
- **The matcher stays pipe-free.** Downstream's original used
  `printf '%s\n' "$gr" | grep -qE ...`; that is the `pipefail` + early-exit
  reader shape `scripts/check-sigpipe.sh` refuses tree-wide, and the
  `sigpipe` suite would fail. Use the `awk ... <<< "$gr"` form above, which
  is what upstream already has at `:450`. Same for any new assertion in the
  test: count on a here-string (`grep -c ... <<<`), never a pipe into
  `grep -q`.
- **Messages, exactly.** The `ok` and `problem` strings are the existing
  ones at `:451` and `:453`, unchanged, so the existing feature-type
  assertions at `boundaries.test.sh:1350-1363` keep matching. The spike arm's
  `note "spike story; gate record not required"` is untouched (AC-2).
- **A side effect to accept, not to fix.** A non-spike at REVIEW with
  `required_gates: [x]` and no `## Gate results` at all now gets two
  problems - `## Gate results was not written by scripts/gates.sh` and
  `frontmatter requires gate 'x'` - where before it got only the first. Still
  exit 1. No existing assertion counts problems for that case (`whole_line`
  is used for 3g/3h only); RED does not add one.
- **Exit status.** `problem` sets the script's failure; the final exit is 1
  on any problem, 0 otherwise, exactly as today. AC-1 asserts `1`, AC-2 and
  AC-3 assert `0`.
- **The sigpipe pin.** `.claude/tests/sigpipe.test.sh:563` holds
  `scripts/check-boundaries.sh:608:ph_at="$(git show`. After +11 lines that
  line is `:619`. The same story updates the pin (`608` -> `619`) - in GREEN,
  because the pin is in a test file and RED cannot know GREEN's exact line
  count. RED writes nothing to `sigpipe.test.sh`; if GREEN's hunk is not
  +11, GREEN pins whatever `grep -n 'ph_at="$(git show' scripts/check-boundaries.sh`
  prints. The other two check-boundaries pins (`:394`, `:433`) are above the
  change and do not move. `sigpipe` C-5 freshness is the assertion that
  notices if this is skipped.
- **Test placement and helpers.** New cases go in
  `.claude/tests/boundaries.test.sh`, in one new `describe`:
  *a spike that escalates a gate has to have run it*, placed directly after
  the existing describe "a gate the story escalated for itself appears in
  the record" (`:1337-1363`). Helpers already present: `make_project_fixture`,
  `run_boundaries` / `boundaries()` capture into `$out` and `$rc`, `refused`,
  `assert_contains`, `assert_eq`, `commit_all` (`:64`), `write_conf`,
  `story_on_branch` (`:69`), `story_blocked` (`:526`). Suite command:
  `bash scripts/selftest.sh boundaries` (one suite); the full run is
  `bash scripts/selftest.sh`.
- **`story_on_branch` grows two optional arguments, backward compatible.**
  Today it hardcodes `type: feature` and no extra frontmatter. RED gives it
  `story_on_branch [type] [extra-frontmatter-line]` with defaults
  `feature` and empty, so every existing call site produces a byte-identical
  story file. Downstream's spelling (from the triage suite in `## Notes`):

      story_on_branch() {
        local type="${1:-feature}" extra="${2:-}"
        ...
        printf -- '---\nid: T-1\ntitle: Fixture story\nslug: fixture\ntype: %s\nstatus: todo\nphase: REVIEW\nbranch: story/T-1-fixture\n' "$type"
        [ -n "$extra" ] && printf -- '%s\n' "$extra"
        printf -- '---\n\n'
        ...

  RED may instead extend `story_blocked`, which already takes
  `[required_gates]` and runs `gates.sh`, if that reads better; the fixture
  story must still be `type: spike`. Callers of `story_on_branch` on this
  tree (grep-listed, all positional-argument-free so none change):
  `grep -n 'story_on_branch' .claude/tests/boundaries.test.sh` - RED
  re-runs this and states the count in the handoff.
- **Records are written by a real `gates.sh` run inside the fixture, never
  pasted.** A hand-written block cannot carry a `tree:` hash
  `check-boundaries.sh` agrees with. For AC-1b and AC-3: `write_conf` with
  `printf` gate commands, then **`commit_all "T-1 conf"` before running
  `gates.sh`** - upstream's `gates.sh` refuses to record while a gated file
  is untracked (`scripts/gates.sh:893-899`), which downstream's did not; the
  triage suite marks both spots `ADAPTED`. Then
  `( cd "$FIX" && bash scripts/gates.sh --story T-1 )`, assert it printed
  `recorded in docs/backlog/stories/T-1.md`, then `commit_all` again.
  AC-1b's conf: `unit` only. AC-3's conf: `unit` required plus
  `integration | optional` with a passing `printf` and an `evidence` line, so
  the record carries `PASS         integration`.
- **Three fixture self-checks** belong beside AC-3's assertions, because the
  code under test does not look at them today and a fixture that quietly
  stopped being what it claims would look like a pass: `gates.sh` said it
  recorded; the record contains `PASS         integration`; the recorded
  `tree:` equals
  `( cd "$FIX" && CLAUDE_PROJECT_DIR="$FIX" bash -c '. .claude/hooks/lib.sh; gate_tree_hash' )`.
- **Deliberately not asserted.** Whether an escalating spike must also
  satisfy the marker / `result:` / `tree:` checks (AC-1b's record is
  otherwise valid, so it fails only for the missing PASS). Whether the
  `spike story; gate record not required` note is still printed for an
  *escalating* spike (only AC-2 asserts the note). The wording of any
  message beyond the substrings in the criteria.
- **Oracle partition.** Every criterion is *mechanical*: an exact substring,
  an exact exit code, an absent `FAIL` line, a line-number pin. Pin exactly;
  nothing to calibrate. The one *settled* item is that the spike exemption
  survives for `required_gates: []` (AC-2), decided downstream at MC-039
  PLANNED on 2026-09-19 and not re-opened here.
- **No signature changes** to any production export. `section`,
  `frontmatter_list`, `ok`, `problem`, `note` keep their names and
  arguments; no caller list is owed. The one test-helper signature change
  (`story_on_branch`) is additive and listed above.
- **Test-only dependencies:** none. bash, awk, git, coreutils only
  (rules.md, Portability).

## Deferred verifications

- **DV-1 (defect put back)** — With the new 3e-i block disabled so the
  re-check is once again unreachable for a spike (through
  `scripts/mutate.sh`, a `sed` that turns `case "$ph" in` of the 3e-i block
  into a case over `"$ph:$story_type"` whose arm is `REVIEW:feature|DONE:feature)`,
  or simply deletes the `REVIEW|DONE)` arm's body - GATES picks the
  expression against GREEN's exact text), AC-1a's and AC-1b's four
  assertions in the `boundaries` suite MUST go red, and AC-2's and AC-3's
  MUST stay green, and the pre-existing feature-type assertions at
  `:1350-1363` MUST go red too (they now run through the same block).
  Downstream recorded exactly this partition for the equivalent mutation
  ("loop back inside the else -> only AC-1a/1b red"). RED cannot run this:
  the block it would disable does not exist yet. Owner: GATES. Command
  shape, for the orchestrator to adapt:

      bash scripts/mutate.sh scripts/check-boundaries.sh \
        '<line>s/^  REVIEW|DONE)$/  NEVER)/' \
        -- bash scripts/selftest.sh boundaries

  Paste the failing assertion names, the pass/fail counts, and the restore
  line here.

- **DV-2 (the control's control)** — With the spike arm deleted
  (`scripts/mutate.sh` with `'/REVIEW:spike|DONE:spike) note/d'` against
  `scripts/check-boundaries.sh`), AC-2's two assertions MUST go red (the
  spike is refused for having no gate record) and every other assertion in
  the suite MUST stay green. This shows AC-2 is pinned to the exemption and
  not satisfied by any passing run. Downstream recorded this partition
  ("delete the spike arm -> only AC-2's two assertions red"). Runs in GATES
  alongside DV-1 because it is one `mutate.sh` invocation against the same
  suite; it is the budget's "earn a test that is green on arrival", since
  AC-2 and AC-3 pass before the fix exists. Owner: GATES.

      bash scripts/mutate.sh scripts/check-boundaries.sh \
        '/REVIEW:spike|DONE:spike) note/d' \
        -- bash scripts/selftest.sh boundaries

That is the rules.md budget: one defect-put-back for the central claim, plus
one mutation earning the two control tests that pass on arrival. AC-3 is
earned by DV-1 (it stays green while AC-1b, its twin, goes red, which is the
discrimination it exists to provide). No wrong-value mutation is owed; this
is not a codec.

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

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-054` from `.claude/harness/models.conf`.
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

- RED: `test-developer` on `opus` (its declared `model:`; the dispatch gave no override). Planned `opus`; no change.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- **Removing the spike exemption.** AC-2 exists to stop it. A spike with no
  escalation still merges without a gate record.
- **Any other arm of the 3e `case`, or any other step.** `feature`, `fix`
  and `chore` already enforce the gate record; the marker, `result:`,
  `blocked` and `tree:` checks are not touched. AC-4 is what notices.
- **`gates.sh` silently skipping a `required_gates` entry with no
  `project.conf` line.** A story can escalate a gate id the project never
  configured; `gates.sh` runs nothing for it and still records
  `result: pass`. After this story `check-boundaries.sh` refuses that story
  at REVIEW (no `PASS` for it), which is the right backstop, but the
  escalation should fail at `gates.sh` time, with the gate named. **Follow-up
  story, not this one**: it is a `gates.sh` + `gates.test.sh` change and a
  different file footprint.
- **The large-section fix** (downstream `1de97ec`, `has_content` /
  `has_pasted_output` on a megabyte section). Already covered upstream; the
  triage suite's first describe passed on release 93 and is not ported.
- **Wiring `selftest.sh` into `gates.sh`** as a gate, or adding a
  `required_gates` entry here. See Context: it is a CI step that runs before
  `gates.sh`, deliberately.
- **Any file other than the three in `touches:`.** In particular no change
  to `scripts/gates.sh`, `.claude/hooks/lib.sh`, `docs/wiki/**` or any other
  suite.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

Level: integration, the only level that can falsify these criteria. Each
case builds a real two-branch git fixture (`make_project_fixture`), writes a
`type: spike` story at `phase: REVIEW`, and runs the real
`scripts/check-boundaries.sh main` over it via `run_boundaries` (sets `$out`
and `$rc`). Records for AC-1b and AC-3 are written by a real `gates.sh --story
T-1` run inside the fixture, never pasted, because only that record carries a
`tree:` the script agrees with.

All in `.claude/tests/boundaries.test.sh`, one new describe
*a spike that escalates a gate has to have run it*, placed directly after
*a gate the story escalated for itself appears in the record* and before
*machine-local state is never committed*.

| Assertion (exact name) | Pins | AC | On arrival |
|---|---|---|---|
| `AC-1a an escalating spike with no gate record is refused` | `$out` contains `story T-1: frontmatter requires gate 'integration'` | AC-1a | RED |
| `AC-1a and the run fails rather than noting and moving on` | `$rc` = `1` | AC-1a | RED |
| `fixture: a run that never touched integration was recorded by gates.sh` | gates.sh printed `recorded in docs/backlog/stories/T-1.md` (unit-only conf) | AC-1b fixture | green |
| `AC-1b a recorded run with no PASS for the escalated gate is refused` | `$out` contains `story T-1: frontmatter requires gate 'integration'` | AC-1b | RED |
| `AC-1b and that run fails too` | `$rc` = `1` | AC-1b | RED |
| `AC-2 a spike escalating nothing still needs no gate record` | `$out` contains `spike story; gate record not required` (`required_gates: []`, no `## Gate results`) | AC-2 | green (control) |
| `AC-2 and merges` | `$rc` = `0` | AC-2 | green (control) |
| `fixture: a run that did cover integration was recorded by gates.sh` | gates.sh printed `recorded in docs/backlog/stories/T-1.md` (unit + optional integration conf) | AC-3 fixture | green |
| `fixture: the record carries a PASS for integration` | story file contains `PASS         integration` | AC-3 fixture | green |
| `fixture: the record's tree is the tree being merged` | first recorded `tree:` hex = `gate_tree_hash` of the committed fixture | AC-3 fixture | green |
| `AC-3 a spike that ran the gate it escalated merges` | `$rc` = `0` | AC-3 | green (control) |
| `AC-3 and nothing in the run objects` | `grep '^FAIL' <<< "$out"` is empty (no line BEGINS with `FAIL`) | AC-3 | green (control) |

AC-4 (every suite passes, sigpipe C-5 still finds its twelve lines) is not a
new assertion: it is the existing `selftest.sh` run plus the pin GREEN moves
(see the handoff). Nothing in RED can make it red, because the line it pins
has not moved yet.

Edges and non-goals: the non-escalating spike (AC-2) is the "empty" case of
`required_gates`; the one-gate cases are AC-1/AC-3. The out-of-scope
behaviour "a non-spike with an escalation and no record now gets two problems"
is deliberately NOT asserted (Contract, "A side effect to accept").

## Handoff: RED -> GREEN

RED by `test-developer`, dispatched on its declared `model: opus`; no override
was given in the dispatch.

**Command.** `bash scripts/selftest.sh boundaries` (one suite). The same file
runs directly as `bash .claude/tests/boundaries.test.sh` (`VERBOSE=1` lists
the passes too). It is slow on this Windows machine: about 20 minutes wall
time per run (`real 20m5.632s`, `user 1m37s`, `sys 8m21s`, a local run with
other processes going at the time; no CI timing was taken). The suite has no
per-test timeouts, so nothing here needs a budget.

**Failure output, verbatim** (`bash scripts/selftest.sh boundaries`, against
the unmodified `scripts/check-boundaries.sh`, 2026-10-13; describes with no
failure print as headers only):

```
  a gate the story escalated for itself appears in the record

  a spike that escalates a gate has to have run it
    FAIL AC-1a an escalating spike with no gate record is refused
         expected to contain: story T-1: frontmatter requires gate 'integration'
         actual:               ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in REVIEW
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
           spike story; gate record not required
    FAIL AC-1a and the run fails rather than noting and moving on
         expected: 1
         actual:   0
    FAIL AC-1b a recorded run with no PASS for the escalated gate is refused
         expected to contain: story T-1: frontmatter requires gate 'integration'
         actual:               ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in REVIEW
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
           spike story; gate record not required
    FAIL AC-1b and that run fails too
         expected: 1
         actual:   0

  machine-local state is never committed
...
boundaries: 121 passed, 4 failed

assertion floors: all 1 suite(s) met their declared floor (121 assertions executed, 113 declared).
1 of 1 harness suite(s) FAILED.
exit=1
```

**Why it is the right failure.** Exactly the four AC-1 assertions are red,
and the actual output shows the defect itself: a spike with
`required_gates: [integration]` gets only `spike story; gate record not
required` and exit 0. Both AC-1b fixture self-checks passed, so AC-1b fails
on the missing re-check and not on a missing record. The 113 pre-existing
assertions all pass, so `story_on_branch`'s new arguments changed nothing for
existing callers. 121 passed = 113 existing + 8 new green (2 gates.sh
recorded, PASS integration, tree hash, 2 AC-2, 2 AC-3); 4 red = AC-1a x2,
AC-1b x2. That is the split the Contract predicted.

**Files touched.** `.claude/tests/boundaries.test.sh` only (plus this story
file). Not touched: `scripts/check-boundaries.sh`, `.claude/tests/sigpipe.test.sh`,
`.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`.

**Assertion -> AC map.** See `## Test plan`; one line each:

- `AC-1a an escalating spike with no gate record is refused` - output contains `story T-1: frontmatter requires gate 'integration'` (AC-1a)
- `AC-1a and the run fails rather than noting and moving on` - exit 1 (AC-1a)
- `fixture: a run that never touched integration was recorded by gates.sh` - fixture self-check (AC-1b)
- `AC-1b a recorded run with no PASS for the escalated gate is refused` - same substring (AC-1b)
- `AC-1b and that run fails too` - exit 1 (AC-1b)
- `AC-2 a spike escalating nothing still needs no gate record` - output contains `spike story; gate record not required` (AC-2)
- `AC-2 and merges` - exit 0 (AC-2)
- `fixture: a run that did cover integration was recorded by gates.sh` - fixture self-check (AC-3)
- `fixture: the record carries a PASS for integration` - `PASS         integration` in the story file (AC-3)
- `fixture: the record's tree is the tree being merged` - recorded `tree:` = `gate_tree_hash` (AC-3)
- `AC-3 a spike that ran the gate it escalated merges` - exit 0 (AC-3)
- `AC-3 and nothing in the run objects` - no output line begins `FAIL`; the actual value is the offending lines, so a failure names them (AC-3)

**`story_on_branch` callers.** `grep -n 'story_on_branch' .claude/tests/boundaries.test.sh`
on the RED tree before the edit returned 27 lines: the comment at `:67`, the
definition at `:69`, a comment at `:1683`, and **24 call sites** (`:109 118
135 150 161 179 197 215 222 244 277 614 630 645 661 673 693 704 718 731 818
1596 1610 1693`). The brief said 25; the tree says 24. All are argument-free,
so all take the defaults (`feature`, no extra line), and the new body writes
the same bytes as the old: the old single `printf` ended
`branch: story/T-1-fixture\n---\n\n`, and the new one writes
`branch: story/T-1-fixture\n`, then nothing (the extra line is empty), then
`---\n\n`. The 113 pre-existing passes are the evidence. The new describe adds
four argument-bearing calls (`spike 'required_gates: [integration]'` x3,
`spike 'required_gates: []'` x1).

**What the tests pin (exact).**

- `problem` text substring: `story T-1: frontmatter requires gate 'integration'`
  (from the Contract's `problem "story $sid: frontmatter requires gate '$g', but ..."`).
  check-boundaries prints problems as lines beginning `FAIL  `.
- `note` text substring: `spike story; gate record not required` for a spike
  with `required_gates: []` (AC-2).
- Exit codes: `1` for AC-1a and AC-1b, `0` for AC-2 and AC-3.
- AC-3: no output line matches `^FAIL`.
- The existing `ok` text `ok    story-required gate 'unit' passed in the
  recorded run` and the existing `problem` text in the feature-type describe
  (`:1350-1363` before this edit) keep pinning the unchanged messages.

**What they do NOT constrain.** Comment wording in the 3e-i block; whether
the `spike story; gate record not required` note still prints for an
*escalating* spike (it does today and may keep doing so); whether an
escalating spike must also pass the marker / `result:` / `tree:` checks
(AC-1b's record is otherwise valid); how many problems a non-spike with an
escalation and no record gets; the wording of anything after the pinned
substrings; where in 3e the re-check lives, provided the behaviour holds.

**No production exports.** This is a shell script; the tests only run
`scripts/check-boundaries.sh main` in a fixture and read stdout/stderr and the
exit status. No function in it is sourced by the new tests.

**Passed on arrival, and what earns each.** All are controls that pass on
the unfixed script by design (the Contract's oracle partition):

| Assertion | Green on arrival because | Earned by |
|---|---|---|
| `AC-2 a spike escalating nothing still needs no gate record` | the spike arm already prints the note | DV-2 (delete the spike arm: must go red) |
| `AC-2 and merges` | the spike arm already skips the record | DV-2 (must go red: refused for no gate record) |
| `AC-3 a spike that ran the gate it escalated merges` | the spike arm skips everything | DV-1 (defect put back: stays green while its twin AC-1b goes red) |
| `AC-3 and nothing in the run objects` | as above | DV-1 (same) |
| 4 `fixture:` self-checks | they check gates.sh and the fixture, not check-boundaries.sh | not mutation-earned; they guard the fixture, and the AC-1b one is what makes AC-1b's red mean "re-check missing" rather than "no record" |

**Expected values of the controls** (all measured on this tree, local run,
against the unfixed script; these are the real suite assertions, which did
execute - nothing here fails at import):

| Control | Threshold | Measured now (unfixed) | Expected after GREEN | Expected under DV-1 | Expected under DV-2 |
|---|---|---|---|---|---|
| AC-2 exit | `= 0` | 0 | 0 | 0 | non-zero (red) |
| AC-2 note | contains | present | present | present | absent or with refusal (red) |
| AC-3 exit | `= 0` | 0 | 0 | 0 | 0 |
| AC-3 `^FAIL` lines | none | none | none | none | none |
| AC-1a/1b exit | `= 1` | 0 (red) | 1 | 0 (red) | 1 (green) |

The DV columns assume the mutation is applied to GREEN's fixed script, which
is when GATES runs them. Under DV-2 the escalating spikes fall into the
ordinary arm and the new 3e-i block still fires, so AC-1 stays green there;
only AC-2 goes red. These after-GREEN and DV values are expectations derived
from the Contract's text. No run has measured them.

DV-1 and DV-2 are GATES' to run. RED cannot run DV-1 (the 3e-i block it
disables does not exist yet) and did not run DV-2: I decline both in writing
here, as the story assigns them to GATES.

**For GREEN, the things to do besides the hunk.**

1. **Move the sigpipe pin.** `.claude/tests/sigpipe.test.sh:563` holds
   `scripts/check-boundaries.sh:608:ph_at="$(git show`. Today
   `grep -n 'ph_at="$(git show' scripts/check-boundaries.sh` prints `608:`.
   After the hunk, re-run that grep and pin whatever line it prints (`619` if
   the hunk is exactly +11). RED did not touch `sigpipe.test.sh`, per the
   Contract. The `:394` and `:433` pins are above the change.
2. Then run `bash scripts/selftest.sh boundaries` (expect 125 passed, 0
   failed) and `bash scripts/selftest.sh sigpipe`, and the full
   `bash scripts/selftest.sh` for AC-4.

**Discovered, for the orchestrator.**

- **Floor not raised.** `boundaries` now executes 125 assertions against a
  floor of 113 (`.claude/tests/floors.conf:39`, mirrored in
  `.claude/tests/selftest.test.sh:530`). Recent stories (HARNESS-037, -039,
  -053) raised the floor in the RED commit. This story's Contract puts every
  file outside `touches:` out of scope ("no change to ... any other suite"),
  and `floors.conf` says a story that adds assertions "need not touch this
  file", so I left it at 113. If the orchestrator wants the floor at 125, it
  is a two-file change (`floors.conf` plus `selftest.test.sh`'s table) and
  needs a `touches:` decision first.
- The diagnostic `[ "$rc" = 0 ] || printf ... | grep FAIL | sed` from the
  triage suite was dropped. AC-3's second assertion now uses
  `assert_eq ... "" "$(grep '^FAIL' <<< "$out")"`, a here-string, which also
  carries the diagnostic: a failure prints the offending lines.
- The tree-hash self-check reads the first `tree:` line with one
  `sed -nE '/.../{s/.../\1/p;q;}'`, not `sed | head -1`, to keep a pipe out of
  the suite.
- `bash scripts/check-sigpipe.sh`: `scanned 49 shell file(s), 45 with
  pipefail, 0 finding(s)`. `bash scripts/check-grep-count.sh`: `scanned 49
  shell file(s), 0 finding(s)`. `bash scripts/gates.sh --fast`: every gate
  UNCONFIGURED on this harness (`BOOTSTRAPPED=no`), so it ran nothing; the
  selftest is the real judge here, as Context says.

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

### Provenance

- Downstream fix: `git -C D:/manhwa-cropper show 3ac70e3` (MC-039, 2026-09-20).
  Story: `D:/manhwa-cropper/docs/backlog/stories/MC-039.md`. Its `## Test
  plan` and "Deliberately not asserted" are reproduced in the Contract above
  in substance.
- Triage 2026-10-11 against upstream release 93 (`check-boundaries.sh`
  unchanged in 94): defect MISSING upstream; port applied cleanly; triage
  suite 14/14 with it, `boundaries.test.sh` 113/0 with it.
- The triage scratch directory was session-local and is gone; everything
  the next agent needs from it is pasted here.
- Planned 2026-10-12 by the Lead PO (one of six sibling planners in the same
  tree on `harness/HARNESS-052-057-plan`; this story touches only its own
  file until RED).

### The triage suite that reproduced the defect on upstream (verbatim)

Run as `bash .claude/tests/triage.test.sh` from a release-93 checkout with
the file placed under `.claude/tests/` (it sources `_lib.sh`). The two
`ADAPTED` lines are the only differences from downstream's fixtures. RED may
lift these fixtures into `boundaries.test.sh` directly; the names in the
`assert_*` calls are the ones AC-1 to AC-3 cite.

```bash
#!/usr/bin/env bash
# Downstream (manhwa-cropper) cases from 1de97ec and 3ac70e3, run against
# upstream release 93's check-boundaries.sh. Helpers copied from downstream.
. "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
FIX="$(make_project_fixture)"
trap 'rm -rf "$FIX"' EXIT
git -C "$FIX" -c user.email=t@t -c user.name=t branch -M main >/dev/null 2>&1
boundaries() {
  ( cd "$FIX" && GITHUB_HEAD_REF= PR_HEAD_SHA= bash scripts/check-boundaries.sh main 2>&1 )
}
commit_all() { git -C "$FIX" add -A >/dev/null 2>&1
               git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm "${1:-wip}" >/dev/null 2>&1; }
story_on_branch() {
  local type="${1:-feature}" extra="${2:-}"
  git -C "$FIX" checkout -q main 2>/dev/null
  git -C "$FIX" branch -D story/T-1-fixture >/dev/null 2>&1
  git -C "$FIX" checkout -q -b story/T-1-fixture 2>/dev/null
  mkdir -p "$FIX/docs/backlog/stories"
  {
    printf -- '---\nid: T-1\ntitle: Fixture story\nslug: fixture\ntype: %s\nstatus: todo\nphase: REVIEW\nbranch: story/T-1-fixture\n' "$type"
    [ -n "$extra" ] && printf -- '%s\n' "$extra"
    printf -- '---\n\n'
    printf -- '## Acceptance criteria\n\n- **AC-1** - it works.\n\n## Handoff: RED -> GREEN\n\nthe command, the failure, the export shape.\n\n'
    cat
  } > "$FIX/docs/backlog/stories/T-1.md"
  commit_all "story T-1"
}

# ---------------------------------------------------------------- 1de97ec
describe "1de97ec: a large section is read, not silently treated as empty"
big_text() { # <lines> <prefix>
  awk -v n="$1" -v p="$2" 'BEGIN { for (i = 0; i < n; i++)
    print p " line " i " with enough text on it to make the section large" }'
}
{
  big_text 16000 "handoff"
  printf -- '\n## Gate probes\n\n'
  big_text 16000 "    probe"
  printf -- '\n'
} > "$FIX/.big-sections"
story_on_branch < "$FIX/.big-sections"
out="$(boundaries)"
assert_contains "a megabyte handoff is filled in" "## Handoff is filled in" "$out"
assert_contains "a megabyte gate probe shows its output" "## Gate probes carries pasted output" "$out"
rm -f "$FIX/.big-sections"

# ---------------------------------------------------------------- 3ac70e3
describe "3ac70e3: a spike that escalates a gate has to have run it"
gates_record() {
  local out
  out="$( cd "$FIX" && bash scripts/gates.sh --story T-1 2>&1 )"
  assert_contains "fixture: $1 was recorded by gates.sh" \
    "recorded in docs/backlog/stories/T-1.md" "$out"
}
story_on_branch spike 'required_gates: [integration]' <<'EOF'
## Notes

A spike that named a gate in its frontmatter and never ran it.
EOF
out="$(boundaries)"; rc=$?
assert_contains "AC-1a an escalating spike with no gate record is refused" \
  "story T-1: frontmatter requires gate 'integration'" "$out"
assert_eq "AC-1a and the run fails rather than noting and moving on" "1" "$rc"

story_on_branch spike 'required_gates: [integration]' </dev/null
write_conf "$FIX" <<'EOF'
gate     | unit | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit | Tests +[1-9][0-9]* passed
EOF
commit_all "T-1 conf"  # ADAPTED: upstream gates.sh will not record with an untracked gated file
gates_record "a run that never touched integration"
commit_all "T-1 recorded, integration unrun"
out="$(boundaries)"; rc=$?
assert_contains "AC-1b a recorded run with no PASS for the escalated gate is refused" \
  "story T-1: frontmatter requires gate 'integration'" "$out"
assert_eq "AC-1b and that run fails too" "1" "$rc"

story_on_branch spike 'required_gates: []' <<'EOF'
## Notes

A spike that escalated nothing, which is what a spike usually is.
EOF
out="$(boundaries)"; rc=$?
assert_contains "AC-2 a spike escalating nothing still needs no gate record" \
  "spike story; gate record not required" "$out"
assert_eq "AC-2 and merges" "0" "$rc"
[ "$rc" = 0 ] || printf '%s\n' "$out" | grep FAIL | sed 's/^/      AC-2 output: /'

story_on_branch spike 'required_gates: [integration]' </dev/null
write_conf "$FIX" <<'EOF'
gate     | unit        | required | . | printf 'Tests  47 passed (47)\n'
evidence | unit        | Tests +[1-9][0-9]* passed
gate     | integration | optional | . | printf 'Tests  3 passed (3)\n'
evidence | integration | Tests +[1-9][0-9]* passed
EOF
commit_all "T-1 conf"  # ADAPTED: upstream gates.sh will not record with an untracked gated file
gates_record "a run that did cover integration"
assert_contains "fixture: the record carries a PASS for integration" "PASS         integration" \
  "$(cat "$FIX/docs/backlog/stories/T-1.md")"
commit_all "T-1 recorded, integration run"
assert_eq "fixture: the record's tree is the tree being merged" \
  "$( cd "$FIX" && CLAUDE_PROJECT_DIR="$FIX" bash -c '. .claude/hooks/lib.sh; gate_tree_hash' )" \
  "$(sed -nE 's/^[[:space:]]*tree:[[:space:]]*([0-9a-f]+).*/\1/p' "$FIX/docs/backlog/stories/T-1.md" | head -1)"
out="$(boundaries)"; rc=$?
assert_eq "AC-3 a spike that ran the gate it escalated merges" "0" "$rc"
case "$out" in
  *FAIL*) _bad "AC-3 and nothing in the run objects" "objected: $out" ;;
  *) _ok "AC-3 and nothing in the run objects" ;;
esac
summary "triage"
```

Two things about lifting it: the `1de97ec` describe is out of scope and
stays out of `boundaries.test.sh`; and the `[ "$rc" = 0 ] || printf ... | grep FAIL | sed`
diagnostic line is a pipeline whose status is discarded under `||`, which
`check-sigpipe.sh` tolerates, but a here-string form is cleaner in a
committed suite.

### The port diff against release 93 (verbatim; `cb.orig` was the unmodified script)

```diff
diff --git a/../cb.orig b/scripts/check-boundaries.sh
index 64bdea6..103b54e 100644
--- a/../cb.orig
+++ b/scripts/check-boundaries.sh
@@ -441,21 +441,32 @@ case "$ph:$story_type" in
       else
         problem "story $sid: gates were recorded against tree '${rec:-none}' but $where is '$now'. Source, test or config changed after the last full gate run; run 'bash scripts/gates.sh' again and commit the result."
       fi
-
-      # A gate the story escalated must appear in the record as having passed.
-      # gates.sh enforces this while it runs; this catches the record written
-      # before the escalation was added, where the gate is optional again by
-      # the time anyone looks.
-      for g in $(frontmatter_list "$sfile" required_gates); do
-        if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
-          ok "story-required gate '$g' passed in the recorded run"
-        else
-          problem "story $sid: frontmatter requires gate '$g', but the recorded run has no PASS for it. Run 'bash scripts/gates.sh' again."
-        fi
-      done
     fi ;;
 esac
 
+# 3e-i. A gate the story escalated must appear in the record as having passed.
+#
+# gates.sh enforces this while it runs; this catches the record written before
+# the escalation was added, where the gate is optional again by the time
+# anyone looks - and the record that was never written at all.
+#
+# Outside the case above on both axes: every story type, spike included (the
+# spike exemption is about the RECORD; a spike that names a gate in
+# required_gates has claimed something needs checking), and outside the marker
+# test's else, so a story with no ## Gate results is told WHICH gate it did not
+# run.
+case "$ph" in
+  REVIEW|DONE)
+    gr="$(section "$sfile" "Gate results")"
+    for g in $(frontmatter_list "$sfile" required_gates); do
+      if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
+        ok "story-required gate '$g' passed in the recorded run"
+      else
+        problem "story $sid: frontmatter requires gate '$g', but the recorded run has no PASS for it. Run 'bash scripts/gates.sh' again."
+      fi
+    done ;;
+esac
+
 # 3f. The handoff was actually written
 case "$story_type" in
   feature|fix)
```

### Downstream's recorded probes (MC-039 GATES), to be re-run here as DV-1 / DV-2

- Defect put back (loop moved back inside the `else`): only AC-1a and AC-1b
  went red.
- Control mutation (the `REVIEW:spike|DONE:spike` arm deleted): only AC-2's
  two assertions went red.

### Follow-up, not this story

`gates.sh` silently skips a `required_gates` entry with no `project.conf`
`gate` line and still writes `result: pass`. After this story the escalation
is caught at REVIEW by `check-boundaries.sh`; it should be caught when
`gates.sh` runs, naming the gate. Needs its own story over `scripts/gates.sh`
and `.claude/tests/gates.test.sh`.

### PO decisions

1. **The `boundaries` floor is raised 113 -> 125 in the RED commit**, in
   `.claude/tests/floors.conf:39` and the mirrored table at
   `.claude/tests/selftest.test.sh:530`, with the measurement comment appended
   to `floors.conf`. The test-developer left it at 113 and escalated, reading
   the Contract's "no file outside `touches:`" literally - the right call for
   it. The Contract's scope line was about production and other suites, not
   about the floor table; HARNESS-037, -039 and -053 all raised the floor in
   the RED commit that added the assertions, and a floor 12 below the executed
   count is 12 assertions that could vanish unnoticed. `touches:` is widened
   to name both files. The orchestrator ran `selftest.sh boundaries` and
   `selftest.sh selftest` itself after the change; output in `### RED
   verification` below.

### RED verification (orchestrator, 2026-10-13)

RED dispatched to `test-developer`; it reported running on `opus` (its
declared model, no override in the dispatch). Its diff was read in full: the
`story_on_branch` extension and one new describe, nothing else in the suite.

Orchestrator's own runs, after raising the floor (decision 1), against the
unmodified `scripts/check-boundaries.sh`:

    $ time bash scripts/selftest.sh boundaries
      a spike that escalates a gate has to have run it
        FAIL AC-1a an escalating spike with no gate record is refused
        FAIL AC-1a and the run fails rather than noting and moving on
        FAIL AC-1b a recorded run with no PASS for the escalated gate is refused
        FAIL AC-1b and that run fails too
    boundaries: 121 passed, 4 failed
    FAIL boundaries  did 121 units of work, below the floor of 125 in .claude/tests/floors.conf
    1 of 1 harness suite(s) FAILED.
    real    30m7.852s
    exit=1

    $ time bash scripts/selftest.sh selftest
    selftest: 268 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (268 assertions executed, 268 declared).
    real    7m30.890s
    exit=0

    $ bash scripts/check-sigpipe.sh
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    $ bash scripts/check-grep-count.sh
    check-grep-count: scanned 49 shell file(s), 0 finding(s)

Right failure: the four red assertions are AC-1a and AC-1b and nothing else,
and their actual output is the defect itself (`spike story; gate record not
required`, exit 0). The floor shortfall is the same four assertions counted a
second way (floors count passes): GREEN's expected `boundaries: 125 passed, 0
failed` clears both. `gates.sh --fast` runs nothing on this repository
(`BOOTSTRAPPED=no`, every gate unconfigured), so admissibility is the two
tree-wide checks above plus the selftest suite.
