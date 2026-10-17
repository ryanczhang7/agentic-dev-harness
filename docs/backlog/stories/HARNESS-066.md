---
id: HARNESS-066
title: Finished worktrees and merged branches are tidied when a story closes
slug: finished-worktrees-and-merged-branches-a
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-066-finished-worktrees-and-merged-branches-a
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/tidy.sh, .claude/tests/tidy.test.sh, scripts/phase.sh, .claude/tests/phase.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, CLAUDE.md, .claude/commands/advance-story.md]touches: [scripts/tidy.sh, .claude/tests/tidy.test.sh, scripts/phase.sh, .claude/tests/phase.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, CLAUDE.md, .claude/commands/advance-story.md]touches: []         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed on 2026-10-17 from a manual clean-up, at the user's request, so that next
time it happens without anyone doing it by hand. The required gate holding this
story's artefact is the harness self-test: a new suite for the new script, plus
the `phase` suite for the DONE report.

**What was left behind, and found only by looking.** One working session
closed four harness stories (the 2026-10-15 mutation audit, HARNESS-059, 060
and 061). Afterwards the user asked why `D:\` held so many copies of the repo.
A manual sweep found these, across this repository and the three projects that
vendor its harness:

| Kind | Instances found | What made it |
|---|---|---|
| Per-story worktrees outside the repo, finished (HEAD in `origin/main`, no uncommitted changes, idle for days) | `D:\adh-HARNESS-051`, `D:\adh-release-93` (this repo); `D:\adh-WORLD-121`, `D:\adh-WORLD-129` (fantasy-world-builder); `D:\manga-translator-ci-selftest`, `D:\manga-translator-MT-071`, `D:\manhwa-cropper-ci-selftest`, `D:\manhwa-cropper-refresh` | the `git worktree add ../<repo>-<id> -b <branch>` lines that `plan.sh after` prints (`plan.sh:803`), which nothing ever reverses |
| Claude app session worktrees, finished | 2 in fantasy-world-builder and 2 in manga-translator under `.claude/worktrees/`, detached or on a merged branch | the desktop app. Its own clean-up removes only worktrees idle for 30+ days; these were 4 to 12 days old |
| Merged local branches | `harness/mutation-audit-2026-10-15`, `story/HARNESS-059-…`, `story/HARNESS-060-…`, `story/HARNESS-061-…`. Their remote copies were already gone, deleted on merge | `/advance-story`'s REVIEW → DONE step, which closes the story but leaves its local branch |
| Folders a failed removal left behind | `adh-WORLD-121` after `git worktree remove` exited with `error: failed to delete 'D:/adh-WORLD-121': Filename too long`; the worktree was unregistered, but 9 GB stayed on disk. Two app worktrees left empty `node_modules/` trees: 635 directories, no files | Windows' 260-character path limit. `git` removes deep `node_modules` paths only with `core.longpaths=true` |
| Empty folders no repository lists | `D:\adh-main-probe`, `D:\fwb-WORLD-113`, `.claude/worktrees/funny-poincare-928ccb` | unknown. Each was empty and unregistered |

Together they held about 36 GB, almost all of it `node_modules`, `.venv` and
build output in the finished worktrees. None held uncommitted work, and every
HEAD was already in its repository's `origin/main`. The sweep decided each one
from four facts: is it registered, is its HEAD in `origin/main`, is its status
clean, and is anything running in it (`ps -ef`). That decision is mechanical,
which is why it belongs in a script rather than in a person's memory.

**Two things the sweep could not do, and why they shape this story.**

- A built-in safety check refused `rm -rf` and `rmdir` on top-level `D:\`
  folders, even empty ones. So a tidy that ends in a plain recursive delete
  outside the repository will be refused when an agent runs it, and must not
  try to route around that. Removal goes through `git worktree remove` with
  long paths enabled. A folder git will not remove is reported to the user with
  the command to run, not deleted by other means.
- `git worktree remove` keeps a worktree's branch, which is the behaviour the
  user chose for every removal in the sweep. Deleting a branch is a separate,
  narrower rule (AC-3).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — A report, and only a report, by default. Given a repository with
  several worktrees in different states, when `bash scripts/tidy.sh` runs
  without arguments, it prints one line per worktree other than the main
  checkout and the worktree it runs in. Each line is `REMOVABLE <path>` or
  `KEEP <path>  <reason>`. It ends with a census line
  `tidy: N worktree(s), R removable, K kept; M merged branch(es) deletable`.
  It changes nothing on disk or in git: the worktree list, the branch list and
  `git status` are byte-identical before and after. *Negative control:* a
  fixture with no worktrees except the main checkout prints `0 worktree(s)` and
  exits 0.
- **AC-2** — What counts as finished. A worktree is `REMOVABLE` only when all
  four hold:
  1. its HEAD is an ancestor of `origin/main` (or the base branch
     `check-boundaries.sh` uses);
  2. `git -C <path> status --porcelain --untracked-files=all` is empty;
  3. it is not locked (`git worktree lock`);
  4. no file in it, outside `.git` and ignored directories, was modified in the
     last 24 hours (`--idle-hours N` overrides this).

  Otherwise it is `KEEP`, with the first failing reason as one of
  `unmerged`, `uncommitted`, `locked` or `recent`. Each reason has its own
  fixture, and each fixture differs from a `REMOVABLE` one in exactly that
  fact. The main checkout and the current worktree are never listed, whatever
  their state.
- **AC-3** — Merged local branches. A local branch matching `story/*` or
  `harness/*` is reported `DELETABLE <branch>` when:
  - its tip is an ancestor of `origin/main`;
  - no worktree has it checked out;
  - `origin` has no branch of that name.

  Any other local branch is never listed. That covers `main`, `claude/*`, an
  unmerged `story/*`, a `story/*` checked out in some worktree, and one whose
  remote still exists. Each has a fixture.
- **AC-4** — `--apply` does exactly what the report said. `bash
  scripts/tidy.sh --apply` removes each `REMOVABLE` worktree with
  `git -c core.longpaths=true worktree remove <path>` and keeps its branch. It
  deletes each `DELETABLE` branch with `git branch -d`, never `-D`. It touches
  nothing reported `KEEP`. After it, `git worktree list` and `git branch` lack
  exactly the reported entries. A `--apply` immediately after it reports
  `0 removable`. A worktree that `git worktree remove` fails on is reported
  `LEFT <path>  <git's message>` together with the one-line PowerShell or
  shell command for the user to finish it. The script exits non-zero, and it
  does not delete the folder by any other means.
- **AC-5** — Orphan folders are reported, never deleted. A directory under
  `.claude/worktrees/` that `git worktree list` does not name is reported as
  `ORPHAN <path>  empty` when it holds no files, or `ORPHAN <path>  N file(s)`
  when it does. `--apply` does not remove either kind: both go to the user,
  with the command to run. *Negative control:* a registered worktree under
  `.claude/worktrees/` is never an `ORPHAN`.
- **AC-6** — The DONE step tells the user. `bash scripts/phase.sh set ID DONE`
  ends its report with the census line from AC-1 and, when any entry is
  removable or deletable, the line `tidy: run bash scripts/tidy.sh --apply to
  remove them`. It never applies anything itself. With nothing to tidy it adds
  only the census line.

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

<!-- FILLED BY A TOOL, not by hand: `bash scripts/plan.sh write <id>`, as the
     last step of PLANNED once the ## Contract exists. It renders the per-phase
     plan from .claude/harness/models.conf with the reason for each row. Run it
     again after amending the contract; it replaces the section rather than
     appending to it.

     Not at story creation: the plan depends on the contract, and the "no
     contract, so RED stays on the stronger model" exception would be baked in
     before anybody had a chance to write one.

     What you add BY HAND is the other half - a departure from the plan, and
     the model each dispatch RESOLVED to. Make a departure falsifiable rather
     than folklore:
       * which phase, which model, and why that phase specifically
       * THE RESOLVED MODEL ACTUALLY DISPATCHED, by name - never the word
         "default". An agent definition's `model:` field, or the session's
         setting, or an override: the orchestrator cannot see which won unless
         it records it. Two stories once compared "the default model" against a
         stronger one, and neither could say what the default had resolved to,
         so the comparison may have been the stronger model against itself
       * what the orchestrator should stay on
       * HOW to brief it differently - a model chosen for judgement wants the
         criteria and the constraints, not a pre-decided test design
       * the ORACLE PARTITION of the criteria: which are settled (read the
         numbers out, do not calibrate), which are oracle-free (invent the
         metric and demand a negative control that fires hard), which are
         mechanical (pin exactly). Measured to matter more than the model
       * a success condition that could come out either way
     Then record the VERDICT against that condition when the phase ends, with
     evidence. The verdict is the part that gets skipped, and without it a model
     choice becomes a habit nobody can argue with. -->

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **Folders outside the repository that no repository lists**, such as
  `D:\adh-main-probe` and `D:\fwb-WORLD-113`. Nothing ties them to this
  repository, so a script cannot know they belong to it. Guessing from the
  `../<repo>-<id>` naming is how it would delete a stranger's folder. Report
  at most, and only under `.claude/worktrees/` (AC-5).
- **Other repositories.** `tidy.sh` judges the repository it runs in. The
  three consuming projects get it through `refresh-harness.sh` and run it
  there. No cross-repository sweep.
- **The Claude app's session records.** Removing an app session's worktree
  leaves the session and its branch. The app checks the branch out again if the
  session is resumed, so deleting sessions stays with the app.
- **Running it unasked.** AC-6 reports. Nothing removes on its own, because a
  worktree can belong to a session that is idle but still open, and the 24-hour
  idle rule narrows that risk without closing it.
- **Detecting a process running inside a worktree.** `ps` output is not
  portable across Git Bash, Linux and macOS in a form the harness can rely on.
  The idle rule (AC-2.4) stands in for it, and `## Notes` records that it is a
  proxy.
- **`.claude/state/` scratch**, such as old logs from earlier stories. A
  separate question, with its own owners in `.claude/state/README.md`.

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


**Provenance (Lead PO, 2026-10-17).** This story was written in the session
that did the manual sweep in `## Context` (worktree `nervous-snyder-2b307a`),
and the user asked for it. Every instance in the table was measured that day
with `git worktree list`, `git merge-base --is-ancestor HEAD origin/main`,
`git status --porcelain` and `du`. The 36 GB figure adds the `du` sizes of the
removed worktrees. The 24-hour idle rule (AC-2.4) is a proxy for "no session is
using this". The sweep used `ps -ef` instead, which is not portable enough for
the harness.

**Before RED.** The Contract still has to be pinned. Two questions are yours as
Lead PO. Does the `../<repo>-<id>` line `plan.sh after` prints get a matching
`bash scripts/tidy.sh --apply` reminder? And where does the census sit in
`phase.sh`'s DONE output, which `plan.sh after` already prints?
