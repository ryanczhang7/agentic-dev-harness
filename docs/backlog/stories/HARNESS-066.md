---
id: HARNESS-066
title: Finished worktrees and merged branches are tidied when a story closes
slug: finished-worktrees-and-merged-branches-a
epic: 
type: feature
status: in-progress
phase: GREEN
branch: story/HARNESS-066-finished-worktrees-and-merged-branches-a
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/tidy.sh, .claude/tests/tidy.test.sh, scripts/phase.sh, .claude/tests/phase.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, CLAUDE.md, .claude/commands/advance-story.md] # files this story expects to write; `plan.sh conflicts` reads it
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
  fact. A registered worktree whose folder no longer exists is
  `KEEP <path>  missing`, checked before the four. The main checkout and the
  current worktree are never listed, whatever their state.
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
  prints the census line from AC-1 and, when any entry is removable or
  deletable, the line `tidy: run bash scripts/tidy.sh --apply to remove them`.
  Both come after its `writes allowed:` line and before the blank line that
  opens the `plan.sh after` report, so the report still ends with that
  report's `Next:`. It never applies anything itself. With nothing to tidy it
  adds only the census line.

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

**Writes:** `scripts/tidy.sh`, `.claude/tests/tidy.test.sh`, `scripts/phase.sh`, `.claude/tests/phase.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `CLAUDE.md`, `.claude/commands/advance-story.md`

**Pinned by the Lead PO on 2026-10-19, on main at `bcbfa44`.** RED may amend
any block below in place with a reason; GREEN builds what the amended block
says. Every path here classifies as `harness`, so the lock permits it in every
phase; the role table in `rules.md` is what keeps RED to the tests and GREEN to
the scripts and docs. Bash, awk, git and coreutils only (`rules.md`,
"Portability"): no python, no `ps`.

**C-1. The command.** `scripts/tidy.sh`, run from anywhere inside a working
tree of the repository it judges (its root is `git rev-parse --show-toplevel`
of the cwd, not the script's own location, so a copy in a linked worktree
judges the same repository).

    bash scripts/tidy.sh [--apply] [--base REF] [--idle-hours N]

- `--base REF` (default `origin/main`) is the ref "merged" is judged against.
  A REF that does not resolve is an error: exit 2, one line
  `tidy: base 'REF' does not resolve`, nothing printed or changed.
- `--idle-hours N` (default 24), a whole number; anything else is exit 2.
- Unknown option: exit 2. No network: the script never fetches, so "origin has
  no branch of that name" means no `refs/remotes/origin/<name>`. A stale
  remote-tracking ref therefore keeps a branch, which is the safe direction.

**C-2. The output, in this order, every line exact.** Paths are printed as
`git worktree list --porcelain` prints them (forward slashes on Windows). Two
spaces separate a path from its reason.

    REMOVABLE <path>
    KEEP <path>  <reason>              reason: unmerged | uncommitted | locked | recent
    ORPHAN <path>  empty               or  ORPHAN <path>  N file(s)
    DELETABLE <branch>
    tidy: N worktree(s), R removable, K kept; M merged branch(es) deletable

Worktree lines in `git worktree list` order, then ORPHAN lines (sorted), then
DELETABLE lines (sorted), then the census, always last. `N = R + K`; orphans
are not worktrees and are not counted. With `--apply` the REMOVABLE and
DELETABLE lines are printed first as the report, then each action prints one
of `removed <path>`, `deleted <branch>`, or
`LEFT <path>  <git's first error line>` followed on the next line by
`  finish it: <command>`. The census is printed once, last, describing the
state BEFORE the apply (it is the report the apply acted on).

*Amended by RED, 2026-10-19 - "the REMOVABLE and DELETABLE lines are printed
first" left open whether KEEP and ORPHAN lines are, and the tests have to pick
one.* Under `--apply` the WHOLE report is printed first, exactly as report mode
prints it minus the census (KEEP and ORPHAN lines, with their `remove it:`
lines, included); then the actions - every `removed`/`LEFT` pair in report
order, then every `deleted` (branch order free, C-12); then the census. So
`--apply` with nothing to act on prints byte-for-byte what report mode prints.

**C-3. The four facts (AC-2), checked in this order; the first that fails is
the reason.**
1. `unmerged`: `git merge-base --is-ancestor <HEAD of the worktree> <base>`
   fails. A detached HEAD is judged the same way.
2. `uncommitted`: `git -C <path> status --porcelain --untracked-files=all`
   prints anything.
3. `locked`: the worktree's `--porcelain` record has a `locked` line.
4. `recent`: any file `git -C <path> ls-files -co --exclude-standard` lists
   has an mtime newer than `--idle-hours` ago. Ignored files (build output,
   `node_modules`) are deliberately not consulted: they are what a removal
   frees, not evidence of work. Implementation free (`find ... -mmin -M` over
   that list is one way; GNU and BSD `find` both have `-mmin`).
A worktree whose directory no longer exists (git reports it `prunable`) is
`KEEP <path>  missing`; that fifth reason is in AC-2 (PO decision 3), because
`git worktree remove` cannot act on it and `git worktree prune` is a different
command. RED pins it with one fixture.

*Amended by RED, 2026-10-19 - the parenthesis is not a test that works.*
Measured on this host (git 2.55.0.windows.5): a missing worktree that is also
LOCKED has no `prunable` line in `--porcelain` (only `locked`), because git
never offers to prune a locked worktree. Judge `missing` by the directory not
existing (`[ ! -d <path> ]`), not by the `prunable` line. RED pins this with a
second fixture, missing AND locked, which must report `missing`.

**C-4. Branches (AC-3).** Candidates are local branches whose name starts
`story/` or `harness/`. DELETABLE needs all three: tip is an ancestor of
`<base>`; no worktree's `--porcelain` record names `branch refs/heads/<name>`;
no `refs/remotes/origin/<name>`. Nothing else is ever printed about branches:
no KEEP line for a branch that fails.

**C-5. `--apply` (AC-4).** For each REMOVABLE path:
`git -c core.longpaths=true worktree remove <path>` (no `--force`). For each
DELETABLE branch: `git branch -d <name>` (never `-D`). Branches are deleted
AFTER worktrees are removed. A failed removal prints the LEFT pair and the
script carries on with the rest, then exits 1. The finish-it command is, on
Git Bash on Windows (`uname -s` matching `MINGW*|MSYS*|CYGWIN*`),
`Remove-Item -LiteralPath '\\?\<path with backslashes>' -Recurse -Force`
followed by `; git worktree prune`, and elsewhere
`rm -rf -- '<path>' && git worktree prune`. These are printed for the user and
never executed. Exit 0 when nothing was LEFT. ORPHAN lines never change the
exit status and are never acted on.

A lead for the LEFT fixture, not a requirement: `git worktree remove` refuses
a worktree that contains a submodule ("working trees containing submodules
cannot be moved or removed"), and a committed submodule leaves the status
clean, so such a worktree reports REMOVABLE and then fails under `--apply`.
RED checks that this holds on this host before relying on it, and says if it
does not (a submodule from a local path may need `-c protocol.file.allow=always`).

**C-6. Orphans (AC-5).** Every immediate subdirectory of
`<main checkout>/.claude/worktrees/` that no `git worktree list` record names
(compared as directories, `-ef`, not as strings). `empty` when `find <dir>
-type f` finds nothing; otherwise `N file(s)` with that count. Nothing outside
`.claude/worktrees/` is ever considered (Out of scope).

*Amended by RED, 2026-10-19 - AC-5 says both kinds "go to the user, with the
command to run", and no block said what that command is or where it is
printed.* Every ORPHAN line, in report mode and under `--apply` alike, is
followed on the next line by `  remove it: <command>`, where the command is
C-5's finish-it command without the prune (an orphan is not a worktree):
on Git Bash on Windows
`Remove-Item -LiteralPath '\\?\<path with backslashes>' -Recurse -Force`,
elsewhere `rm -rf -- '<path>'`. Printed, never executed. The ORPHAN path is
`<main checkout path as --porcelain prints it>/.claude/worktrees/<name>`, the
same spelling as every other path in the report. Only immediate
subdirectories: a plain file under `.claude/worktrees/` gets no line.

**C-7. The DONE report (AC-6, as reworded at PLANNED).** In `cmd_set` of
`scripts/phase.sh`, inside the existing `if [ "$phase" = DONE ]` block
(`phase.sh:191-195` today), before the `printf '\n'` that opens the
`plan.sh after` report: run `bash "$ROOT/scripts/tidy.sh"` (report mode, no
options), print only its census line, and when R + M > 0 print
`tidy: run bash scripts/tidy.sh --apply to remove them`. A tidy that fails or
prints no census prints nothing here and must not fail the phase change (the
same rule the block already applies to `plan.sh`). Order of the DONE output:
`<id> -> DONE`, `writes allowed: ...`, the census, the apply line if any, a
blank line, then `plan.sh after` exactly as today.

**C-8. Callers of the changed output.** `phase.sh set <id> DONE`'s stdout gains
one or two lines. Every reader, by `git grep` today:
`.claude/tests/phase.test.sh:140` (discards output), `:168-182` (HARNESS-018
AC-6: asserts the first line is `K-1 -> DONE` and that the output ENDS with a
blank line and then `plan.sh after K-1` - both still hold under C-7, so these
assertions are expected to stay green); prose in `plan.test.sh:2130` and
`refresh.test.sh:135` (comments, not readers). RED's handoff states it checked
this list against the tree.

**C-9. Docs (GREEN).** `CLAUDE.md`, "Running things": one line,
`bash scripts/tidy.sh [--apply]   # finished worktrees and merged branches`.
`.claude/commands/advance-story.md`, the `**REVIEW → DONE.**` paragraph
(`:234` today): one sentence saying the DONE report carries the tidy census
and that `--apply` is recommended to the user, never run by the orchestrator
unasked. `policy.test.sh` reads that paragraph for `/audit-mutations`; RED
checks the sentence does not disturb it.

**C-10. Tests and floors.** A new suite `.claude/tests/tidy.test.sh`, built on
`_lib.sh`, with a real bare repository as `origin` and real `git worktree add`
worktrees (never copied directories; `worktree.test.sh` explains why). File
mtimes are set with `touch -t` (portable). The new suite gets a `floor` line in
`.claude/tests/floors.conf` and a row in the COUNTS table in
`.claude/tests/selftest.test.sh`; `phase`'s floor and row move by whatever
`phase.test.sh` adds. Each set to the count RED measures, with a dated comment
at the end of `floors.conf`.

**C-11. Oracle partition.** Every criterion is mechanical: exact lines for
exact fixtures, and exact before/after state of `git worktree list`,
`git branch` and `git status`. The one judgement in the story, the 24-hour
idle proxy, is a default with an override, pinned as a number.

**C-12. Not decided here, so free.** Internal structure of `tidy.sh`; the
order DELETABLE branches are deleted in; wording of error messages other than
the ones above.

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

- **DV-1 — the defect put back.** The story's central claim is that nothing
  with work in it is ever reported REMOVABLE. With the `unmerged` check
  removed from `scripts/tidy.sh` (the ancestor test made always true), AC-2's
  `unmerged` fixture MUST report `REMOVABLE`, and its assertion and AC-4's
  "touches nothing reported KEEP" for that fixture MUST go red. RED cannot run
  this: `tidy.sh` does not exist yet. Run through `scripts/mutate.sh` against
  `bash scripts/selftest.sh tidy`. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-066` from `.claude/harness/models.conf`.
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

- RED, `test-developer`: `opus` (Opus 5.5), as planned; no override.
- GREEN, `feature-developer`: `opus` (Opus 5.5, `claude-opus-5-5`), as planned; no override.

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

Two suites, both integration level (a real script over real git state is the
cheapest thing that can falsify any of these criteria; there is no unit below
it worth isolating). Every criterion is mechanical (C-11), so every verdict is
a whole-line or whole-output comparison.

- `.claude/tests/tidy.test.sh` (new, 128 executed): AC-1..AC-5 and C-1's
  options. Six fixture repositories under one `mktemp -d`, each a main
  checkout on `main` with a bare `origin` and `main` pushed:
  `z` (main only: AC-1 control, C-1 cwd), `a` (14 worktrees: AC-1, AC-2, the
  24-hour default, the order of reasons, `--idle-hours`, `--base`, C-1 errors),
  `b` (branches: AC-3), `c` (`--apply` happy path: AC-4), `e` (a removal git
  refuses: AC-4 LEFT), `d` (orphans: AC-5).
- `.claude/tests/phase.test.sh` (+15, 73 executed): AC-6. Three assertions
  beside the HARNESS-018 AC-6 block on its existing no-origin fixture (C-7's
  failure path), and a new describe at the end with its own fixture `P66`
  that has a real origin (C-7's success paths).

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

**Written by the Test Developer (RED), 2026-10-19, on `opus` as declared in
`test-developer.md` (no override was given in the dispatch).**

### Commands

    bash scripts/selftest.sh tidy
    bash scripts/selftest.sh phase

Each takes `.claude/state/run.lock`; run them one at a time. Measured wall
time on this Windows host (local, not CI): tidy 3m20s with no `tidy.sh`,
about 5m15s against a working implementation; phase about 2m50s. The cost is
process spawns (git, awk, find) under Git Bash, not anything waiting; CI is
ubuntu-latest, where spawns are cheap. No suite in this harness has a timeout,
so this is a cost note, not an admissibility risk.

### The RED result, and why it is the right failure

    === tidy ===
    tidy: 68 passed, 60 failed
    FAIL tidy  did 68 units of work, below the floor of 128 in .claude/tests/floors.conf

    === phase ===
    phase: 66 passed, 7 failed
    FAIL phase  did 66 units of work, below the floor of 73 in .claude/tests/floors.conf

The tidy suite does NOT abort: it runs to the end. Every tidy invocation exits
127 with exactly one cause on stderr, which every verdict failure prints:

    FAIL AC-1 control: tidy in a repository with no other worktree prints only the census, 0 worktree(s), and nothing else
         expected:
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         actual:

         stderr: bash: /tmp/tmp.BtN1PCzJWI/z/scripts/tidy.sh: No such file or directory
    FAIL AC-1 control: and exits 0
         expected: 0
         actual:   127
    FAIL AC-4: the refused worktree is reported LEFT <path>  <git's first error line>
         expected exactly one line: LEFT C:/Users/ryanc/AppData/Local/Temp/tmp.BtN1PCzJWI/e-sub  fatal: working trees containing submodules cannot be moved or removed
    FAIL AC-5: an empty unregistered folder is ORPHAN <path>  empty
         expected exactly one line: ORPHAN C:/Users/ryanc/AppData/Local/Temp/tmp.BtN1PCzJWI/d/.claude/worktrees/o-empty  empty

The 60 red are every assertion that needs tidy to print or do something. The
68 green are (a) every fixture precondition - each fixture's facts, asserted
before its verdict, all green, so no fixture is broken - and (b) the absence
controls, which cannot be red while tidy is absent (listed below). No syntax
error, no fixture error, no awk warning (one `awk -v` carrying a Windows
backslash path was found and moved to ARGV during RED).

In phase, the 7 red are exactly the census lines and the one precondition that
`scripts/tidy.sh` is present in the fixture:

    FAIL HARNESS-066 AC-6 precondition: this fixture carries scripts/tidy.sh and has no origin/main, so tidy fails here
         expected: present|unresolved
         actual:   absent|unresolved
    FAIL HARNESS-066 AC-6: the census is the third line, straight after writes allowed:
         expected: tidy: 1 worktree(s), 1 removable, 0 kept; 1 merged branch(es) deletable
         actual:

HARNESS-018's five AC-6 assertions (and its five per-phase controls) stay green.

**The expectations were checked to be satisfiable.** A throwaway prototype
`tidy.sh` and a prototype C-7 edit of `phase.sh` were written OUTSIDE this
tree (session scratchpad, never copied in, not handed on), and both suites
were run from a scratch copy of the harness against them:
`tidy: 128 passed, 0 failed`, `phase: 73 passed, 0 failed`. So a red
assertion in GREEN means the implementation, not an impossible expectation.
GREEN writes its own implementation from the Contract.

### Assertions, by AC (tidy.test.sh)

AC-1 control (`z`): `precondition - exactly one worktree`; `prints only the
census, 0 worktree(s)` (whole output); `and exits 0`.

Fixtures (`a`): 14 `fixture <name>: its facts are <m|c|l|i>` (one per
worktree, from the suite's own `facts` oracle), plus `a-missing-locked is still
locked`, `a-ignored-fresh holds a fresh file in node_modules/`, `a-idle25 is
24-26 h old`, `a-idle23 is 22-24 h old`, `the main checkout is dirty`.

AC-1/AC-2 (`a`, report mode, cwd = main checkout):
- `a merged, clean, unlocked, idle detached worktree is REMOVABLE`; `and so is
  one on a branch` (AC-2)
- `AC-2 unmerged | uncommitted | locked | recent | missing: ... is KEEP,
  reason <r>` (one fixture each, AC-2)
- `a fresh file in an ignored directory does not make a worktree recent`
  (AC-2.4)
- `default 24h: 25 hours old leaves it REMOVABLE`; `23 hours old makes it KEEP
  recent` (AC-2.4)
- `order: unmerged+uncommitted+locked+recent -> unmerged`;
  `uncommitted+locked+recent -> uncommitted`; `locked+recent -> locked`;
  `missing and locked -> missing` (AC-2's first-failing-reason rule)
- `the main checkout is never listed, though it is dirty` (AC-2)
- `the census counts 14 worktrees, 4 removable, 10 kept, 0 branches` (AC-1)
- `the whole report is the worktree lines in git worktree list order, then
  the census` (AC-1, C-2)
- `report mode exits 0`; `worktree list, every ref, git status and every
  worktree's files are byte-identical before and after` (AC-1)

AC-2 current worktree / C-1 (cwd = `a-recent`, running the main checkout's
copy): `a-recent is not listed`; `the main checkout is not listed either`;
`the report is every other non-main worktree, then 13 / 4 / 9` (whole). Then
`a's copy run from z judges z` (whole output = zero census).

Options (`a`): `--idle-hours 26` -> idle25 KEEP recent; `--idle-hours 22` ->
idle23 REMOVABLE; `--base <a-unmerged's commit>` -> a-unmerged REMOVABLE, and
a-all-four still unmerged; `--base no/such/ref` exits 2, prints exactly
`tidy: base 'no/such/ref' does not resolve` (stdout+stderr together), changes
nothing; `--idle-hours abc | -3 | 1.5 | <missing>` exit 2; `--frobnicate`
exit 2. (C-1)

AC-3 (`b`): 9 branch-fact preconditions and b-wt's facts; `story/b-done` and
`harness/b-done` DELETABLE; `main`, `claude/b-done`, `feature/b-done`,
`storyboard/b-done`, `story/b-open` (unmerged), `story/b-checked-out`,
`story/b-still-remote` never the subject of any line (7); five of them never
NAMED anywhere in the output (5, a floating absence - the stronger claim);
whole report (KEEP b-wt recent, DELETABLE sorted, census `1 / 0 / 1 / 2`);
exit 0; `--base story/b-open` makes story/b-open DELETABLE and still not
story/b-still-remote.

AC-4 (`c`): 4 fixture facts; whole `--apply` output; exit 0; worktree list
lacks exactly the two REMOVABLE paths; branch list lacks exactly
`story/c-done`; removed folders gone; `story/c-kept-wt` (the removed
worktree's branch) kept; KEEP unmerged untouched (registered, same HEAD, same
file list); KEEP locked untouched (there, still locked); `story/c-open`
kept; second `--apply`: census `2 / 0 / 2 / 0`, no `removed`/`deleted`/
`LEFT` line, exit 0.

AC-4 LEFT (`e`): submodule present (mode 160000); e-sub and e-rm facts; git
itself refuses e-sub and leaves it (the mechanism re-measured in-suite);
`LEFT <path>  <git's first line>`; `  finish it: <cmd>`; the finish line is
immediately after the LEFT line; whole output; exit 1; LEFT folder still on
disk and registered; carried on: e-rm removed; carried on: `story/e-done`
deleted after the failure.

AC-5 (`d`): 3 fixture preconditions; `ORPHAN ... empty` for an empty folder
and for one holding only empty directories (the `node_modules` case from
## Context); `1 file(s)`; `3 file(s)` (nested); the `remove it:` line;
control: reg is never ORPHAN in any spelling; reg is listed as `KEEP ...
recent`; a plain file under `.claude/worktrees/` and a folder outside it are
never named; whole report; `--apply` prints the same; every orphan file still
on disk; exit 0 in both modes.

### Assertions, by AC (phase.test.sh)

Beside HARNESS-018 (FIX, no `origin`): `precondition: carries scripts/tidy.sh
and has no origin/main`; `a tidy that fails adds no line - no line begins
tidy:`; `does not fail the phase change - exits 0` (C-7 failure path).

New describe `HARNESS-066 AC-6` (P66, real origin): precondition (q-rm merged,
clean, unlocked, idle; story/q-done merged, nowhere checked out, no origin
copy); `first two lines are still -> DONE and writes allowed:`; `census is the
third line`; `the fourth line says how to remove them`; `each appears exactly
once`; `then one blank line, and the output still ENDS with exactly what
plan.sh after Q-1 prints`; `DONE never applies` (worktree on disk, registered,
branch exists); `phase change happened, exit 0`. Then nothing to tidy:
precondition; `third line is the census alone`
(`tidy: 1 worktree(s), 0 removable, 1 kept; 0 merged branch(es) deletable`);
`no apply line`; `census, one blank line, then exactly plan.sh after Q-2`.

### The interface the tests pin (fact, not suggestion)

- **Invocation**: `bash <main checkout>/scripts/tidy.sh [--apply] [--base REF]
  [--idle-hours N]`, run from a directory inside the fixture. The suite copies
  the whole `scripts/` and `.claude/hooks/` into each fixture's main checkout,
  untracked, so tidy.sh may source `../.claude/hooks/lib.sh` if it wants.
  The repository judged is the cwd's (`git rev-parse --show-toplevel`): pinned
  by running fixture a's copy from inside `a-recent` and from fixture `z`.
- **Exit codes**: 0 report mode; 0 `--apply` with nothing LEFT; 1 `--apply`
  with any LEFT; 2 for unresolvable `--base`, `--idle-hours` not matching
  `^[0-9]+$` (abc, -3, 1.5, missing value) and any unknown option. ORPHANs
  never change it.
- **Lines** (stdout, whole-line, two spaces before every reason):
  `REMOVABLE <path>` / `KEEP <path>  <unmerged|uncommitted|locked|recent|missing>` /
  `ORPHAN <path>  empty` or `ORPHAN <path>  <N> file(s)`, each followed by
  `  remove it: <cmd>` / `DELETABLE <branch>` / `removed <path>` /
  `LEFT <path>  <git's first stderr line>` followed by `  finish it: <cmd>` /
  `deleted <branch>` / `tidy: N worktree(s), R removable, K kept; M merged branch(es) deletable`.
  The error line is exactly `tidy: base '<REF>' does not resolve` and is the
  only output of that run (either stream).
- **Paths**: exactly as `git worktree list --porcelain` prints them
  (`C:/Users/...` here). ORPHAN paths are `<main checkout's porcelain
  path>/.claude/worktrees/<name>`.
- **Commands** (`uname -s` matching `MINGW*|MSYS*|CYGWIN*`):
  `Remove-Item -LiteralPath '\\?\C:\...\x' -Recurse -Force` for an orphan, and
  the same followed by `; git worktree prune` for a LEFT; elsewhere
  `rm -rf -- '<path>'` and `rm -rf -- '<path>' && git worktree prune`.
- **Order**: worktree lines in porcelain order (git does NOT sort it; the
  suite builds its expectation from porcelain order, so do not sort); ORPHAN
  pairs sorted by name; DELETABLE sorted (C locale); census last. Under
  `--apply` (C-2 as amended): the whole report minus census, then
  `removed`/`LEFT` pairs in report order, then `deleted` lines, then the
  census of the BEFORE state. Main checkout and the cwd's worktree never
  listed and not counted.
- **Facts**: C-3, in order unmerged, uncommitted, locked, recent, with
  `missing` before all four, judged by the directory not existing (C-3 as
  amended: a locked missing worktree has no `prunable` line). `recent` looks
  only at `ls-files -co --exclude-standard` (a fresh file in `node_modules/`
  must not count). The threshold is "modified less than N hours ago"; a file
  25 h old is idle and 23 h old is recent at the default 24.
- **AC-6 / C-7**: in the DONE output, line 1 `<id> -> DONE`, line 2
  `writes allowed: ...`, line 3 the census, line 4 the apply line only when
  R + M > 0, then one blank line, then `plan.sh after` to the end.
  **Trap, found by the prototype:** when tidy fails on a repo with no
  `origin/main` it prints `tidy: base 'origin/main' does not resolve` - which
  ALSO begins `tidy:`. phase.sh must recognise only the census shape (or tidy's
  exit status), not "a line starting `tidy:`". A prototype that took the last
  `tidy:` line printed that error line plus the apply line, and
  `a tidy that fails adds no line to the DONE report` went red (actual 2).

**Not constrained** (implementer's choice): tidy.sh's internals; stderr in the
ordinary runs (never asserted, except the base error which may use either
stream); how R + M > 0 is detected in phase.sh; the wording of every other
error message; the order of `deleted` lines; whether tidy sources lib.sh.

### Fixtures and the one fact each differs in

Idle means every file and directory touched to `202001010000` (`touch -t`).
Detached at `main` unless noted.
- `a-rm-detached` the REMOVABLE baseline; `a-rm-branch` on `story/a-rm-branch`,
  pushed so it is never DELETABLE.
- `a-unmerged` + one commit; `a-uncommitted` + one untracked file (also
  backdated); `a-locked` + `git worktree lock`; `a-recent` + `src/a.txt`
  touched now; `a-missing` folder deleted by the suite.
- `a-ignored-fresh` + a fresh `node_modules/pkg/index.js` (still REMOVABLE).
- `a-idle25` / `a-idle23`: `src/a.txt` set to 25 / 23 hours ago (`date -d @t`,
  else BSD `date -r t`).
- Order: `a-all-four` (commit + fresh untracked + lock), `a-three` (fresh
  untracked + lock), `a-two` (tracked file now + lock), `a-missing-locked`
  (lock, then folder deleted).
- `b`: `story/b-done`, `harness/b-done`, `claude/b-done`, `feature/b-done`,
  `storyboard/b-done`, `story/b-still-remote`, `story/b-checked-out` each a
  commit fast-forwarded into main; `story/b-still-remote` also pushed;
  `story/b-open` a commit main lacks; `b-wt` (fresh) holds
  `story/b-checked-out`.
- `c`: `c-rm-branch` on `story/c-kept-wt` (pushed), `c-rm-detached`,
  `c-keep-unmerged` (+ commit), `c-keep-locked`; branches `story/c-done`
  (merged) and `story/c-open` (not).
- `e`: `e-sub` on `story/e-sub` with a committed submodule (fast-forwarded
  into main, pushed); `e-rm` made before the submodule reached main;
  `story/e-done` merged.
- `d`: under `d/.claude/worktrees/`: `o-empty`, `o-dirs` (4 nested empty
  dirs), `o-one` (1 file), `o-three` (3 files, nested), `stray.txt` (a file),
  and `reg`, a registered fresh worktree; `$WORK/d-outside` an unregistered
  empty folder outside it.
- `P66` (phase.test.sh): `make_project_fixture` + bare origin + `HEAD:main`
  pushed; `q-rm` idle detached worktree; `story/q-done` at HEAD. Then q-rm
  removed, the branch deleted, `q-keep` (fresh) added.

### The LEFT mechanism (verified, not assumed)

C-5's lead holds on this host, measured in the scratchpad before relying on it
(git 2.55.0.windows.5): a worktree holding a committed submodule (added with
`-c protocol.file.allow=always`, which a local-path submodule needs) has an
empty `status --porcelain --untracked-files=all`, its HEAD is in origin/main,
and `git -c core.longpaths=true worktree remove` prints
`fatal: working trees containing submodules cannot be moved or removed` and
exits 128, leaving folder and registration in place. The suite re-measures it
every run (`git itself refuses to remove it...`) and takes git's own first
line as the expected message, so a git version with other wording still
passes. Git refuses only POPULATED submodules, so `e-rm` is created before the
submodule reaches main. No shim.

### Floors (how counted)

`floor | tidy | 128` (new, between spawns and worktree) and `phase` 58 -> 73,
mirrored in selftest.test.sh's COUNTS table (`selftest: 268 passed, 0 failed`
after the edit). tidy: passes+fails of the RED run (68 + 60), equal to the
green count by construction - no assertion is conditional and every loop is
over a fixed list - and confirmed 128/0 against the scratch prototype. phase:
66 + 7 = 73, confirmed 73/0 against the prototype phase.sh. Until GREEN
lands, selftest.sh also prints the below-the-floor lines above; GREEN
confirms both numbers.

### Passed on arrival, and what earns them

Absence controls cannot be red while tidy.sh is absent. Each is paired with a
positive assertion on the same run that is red now, so a run that printed
nothing cannot satisfy the pair:
- tidy: `main checkout is never listed` (x2), `a-recent is not listed`,
  `report mode changes nothing`, `--base no/such/ref changes nothing`, the 12
  AC-3 never-mentioned / never-named checks, `--base story/b-open ... still
  not story/b-still-remote`, `removed worktree's branch is kept`, the two
  `KEEP ... untouched`, `the unmerged branch is kept`, `second --apply acts on
  nothing`, `LEFT folder still on disk`, `reg is never ORPHAN`, `a plain file
  ... never named`, `--apply leaves every orphan on disk`.
- phase: `a tidy that fails adds no line`, `exits 0` (both meaningful only
  once the red precondition `carries scripts/tidy.sh` turns green), P66's two
  preconditions, `first two lines`, `DONE never applies`, `phase change
  happened, exit 0`, `no apply line`.
Earned outside the tree, against the scratch prototype (so these are claims
until GREEN measures them against the shipped module):

| Control | Mutation of the prototype | Expected | Measured (scratch) |
|---|---|---|---|
| DV-1 analog: unmerged check removed | `elif false; then why=unmerged` | AC-2 unmerged and `KEEP unmerged untouched` red | `tidy: 118 passed, 10 failed`, incl. both, plus `order: ... reports unmerged`, the whole-output and census checks, `worktree list lacks exactly ...` |
| C-7 failure path | phase.sh takes the last line matching `^tidy: ` | `a tidy that fails adds no line` red | `phase: 72 passed, 1 failed`, `expected: 0 actual: 2` |
| AC-5 `-ef` control | not run (no time on Windows) | an implementation comparing paths as strings lists `reg` as ORPHAN here | - |

### C-8, checked against the tree

`git grep -nE "phase(\.sh)? set [^ ]+ DONE"` on 2026-10-19 finds, outside
story files and audits: `phase.test.sh:140` (`phase set T-11 DONE
>/dev/null`, discards output), `phase.test.sh:168` (the HARNESS-018 block,
which stays green under C-7: measured against the prototype), and prose only
in `plan.test.sh:2130`, `refresh.test.sh:135`, `scripts/plan.sh:707` and
`.claude/commands/advance-story.md:236`. No other suite and no workflow reads
DONE's stdout. C-8's list is complete; `advance-story.md:236` and
`plan.sh:707` are two more prose sites, neither a reader.

### C-9, policy.test.sh

`policy.test.sh` reads advance-story.md's `**REVIEW → DONE.**` paragraph from
that line to the next line that BEGINS `**`. GREEN's new sentence must
therefore not start a line with `**`, must keep `/audit-mutations` in the
paragraph, and must not contain `mutation-tester`, `--gate mutation`, or
`two mutations`/`three mutations` anywhere in the file.

### Deferred verifications

DV-1 is GATES' and I did not run it: `scripts/tidy.sh` does not exist in RED,
so there is nothing to mutate. The scratch-prototype row above is calibration,
not DV-1's result.

### Files touched

- `.claude/tests/tidy.test.sh` (new; untracked until committed - `gates.sh
  --fast` reports it as UNTRACKED)
- `.claude/tests/phase.test.sh` (+15 assertions; `done_rc=$?` added after the
  existing `done_out=` line, no existing assertion changed)
- `.claude/tests/floors.conf` (tidy 128, phase 73, dated comment)
- `.claude/tests/selftest.test.sh` (COUNTS: phase 73, tidy 128)
- this story: Contract C-2, C-3, C-6 amended in place, `## Test plan`, this
  handoff

`bash scripts/gates.sh --fast`: every gate unconfigured in this repository
(BOOTSTRAPPED=no), so the self-test above is the only judge; nothing tripped.

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

**PO decisions at PLANNED (2026-10-19), before RED.**

1. **AC-6 reworded, approved by the user.** As filed, AC-6 put the census at
   the END of the DONE report. HARNESS-018's test (`phase.test.sh:168-182`)
   requires that report to end with `plan.sh after`'s output, so that `Next:`
   is the last thing the user reads (`rules.md`, "Reporting to the user"). The
   user chose to put the census before the `plan.sh after` report instead.
   Changed while PLANNED, so no `## Amendments` entry is owed.
2. **No tidy reminder beside `plan.sh after`'s `git worktree add` lines.**
   The question the provenance note left open. Answered no: AC-6 already
   reports at the moment a story closes, which is when a worktree becomes
   finished, and changing `plan.sh`'s output would put `plan.sh` and its suite
   in this story's scope for a second reminder of the same thing.
3. **A fifth KEEP reason, `missing`** (C-3), for a registered worktree whose
   folder is gone. The criteria list four; without this, such an entry has no
   correct line. It narrows nothing the criteria allow.
4. **The `touches:` line was malformed** (three copies on one line, as
   committed in `a4af13e`); repaired to one list before RED.


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

**RED checked by the orchestrator (2026-10-19).** `scripts/tidy.sh` absent,
`scripts/phase.sh` untouched; the two suites run one after the other,
23:09Z to 23:16Z:

    tidy: 68 passed, 60 failed
    FAIL tidy  did 68 units of work, below the floor of 128 in .claude/tests/floors.conf
    phase: 66 passed, 7 failed
    FAIL phase  did 66 units of work, below the floor of 73 in .claude/tests/floors.conf

Every failure traces to the missing script: 42 `No such file or directory`
lines in the tidy log, and the rest are exit-status assertions expecting 0 or
2 where a missing script gives 127. The 7 phase failures are the HARNESS-066
AC-6 block (census and apply lines absent, plus its precondition that the
fixture carries `scripts/tidy.sh`); HARNESS-018's AC-6 assertions stay green.
RED amended C-2 (the `--apply` print order), C-3 (`missing` judged by the
folder, not by git's `prunable` line, measured) and C-6 (orphans get a
`remove it:` command, which AC-5 requires and no block had defined); each
amendment carries its reason in place. RED also prototyped `tidy.sh` and the
C-7 change in its own scratch directory, never in the tree, to check that
every expectation can be met (128/0 and 73/0 there); GREEN writes its own.

**GREEN (feature-developer), 2026-10-20.** Ran on `opus` (Opus 5.5, `claude-opus-5-5`), as `feature-developer.md` declares; no override in the dispatch. Wrote `scripts/tidy.sh` (new), the C-7 block in `scripts/phase.sh` `cmd_set`, one line in `CLAUDE.md` "Running things", and one sentence at the end of `advance-story.md`'s `**REVIEW → DONE.**` paragraph. No test file touched. The suites, one at a time, against the shipped code:

    tidy: 128 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (128 assertions executed, 128 declared).
    phase: 73 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (73 assertions executed, 73 declared).
    policy: 17 passed, 0 failed
    selftest: 268 passed, 0 failed
    check-sigpipe: scanned 2 shell file(s), 2 with pipefail, 0 finding(s)   (scripts/tidy.sh scripts/phase.sh)
    check-grep-count: scanned 2 shell file(s), 0 finding(s)

Wall time here: tidy 3m29s, phase 1m27s. Both match RED's recorded counts.

How phase.sh avoids the handoff's trap: it prints a census only from a tidy that exited 0 AND only a line matching the full census shape; R + M are read from that line's fields 4 and 8. Either guard alone keeps the failure path silent, so the C-7 control below removes both.

Negative controls measured against the shipped code, each through `scripts/mutate.sh`, restored and verified:

    C-7 failure path: phase.sh's tidy capture made `2>&1 ... || true` and its census regex `/^tidy: /`
    phase: 72 passed, 1 failed     (HARNESS-018 AC-6 block: expected: 0  actual: 1)
    === mutate: command exited 1; restored (verified byte-for-byte ...) ===

    AC-5 `-ef` control: tidy.sh's orphan check `[ "$o" -ef "${WT_PATH[i]}" ]` made a string compare `=`
    tidy: 128 passed, 0 failed
    === mutate: command exited 0; restored (verified byte-for-byte ...) ===

Two divergences from the handoff. (1) C-7: RED's prototype measured `actual: 2`, and this one measures `actual: 1`. The shipped apply line is computed from the census fields, and tidy's error line `tidy: base 'origin/main' does not resolve` gives no R + M, so only the error line leaks. That is benign and the control still goes red. My output filter dropped the FAIL name line, so which assertion went red is inferred from the values: the block's other HARNESS-066 assertion is the exit status, which `|| true` keeps 0. (2) The AC-5 `-ef` control, which RED did not run, does NOT discriminate on this host. The ORPHAN path is built from the main checkout's porcelain path, and git records `reg` in that same spelling, so comparing strings gives the same answer as `-ef`. `reg is never ORPHAN` passes against a string-compare implementation. `-ef` stays in the code, as C-6 requires. Making the control bite needs a fixture whose spelling differs from git's, such as a symlinked or `/tmp`-vs-`C:/` registered path. That is a test-side question for RED or `/audit-mutations`, not a GREEN change.

One behaviour the contract leaves open (C-12): `git branch -d` judges "merged" against the branch's upstream or the current HEAD, not against `--base`. So a branch that is DELETABLE against `origin/main` can still be refused when tidy runs from a checkout whose HEAD lacks it. tidy then prints `not deleted <branch>  <git's first line>` and exits 1. It never falls back to `-D`. No fixture reaches this (every fixture runs from `main`).

**GREEN checked by the orchestrator (2026-10-20).** No file under
`.claude/tests/` changed (`git status`: `scripts/tidy.sh` new, `scripts/phase.sh`,
`CLAUDE.md`, `advance-story.md`, this story). The two suites, run one after the
other:

    tidy: 128 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (128 assertions executed, 128 declared).
    phase: 73 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (73 assertions executed, 73 declared).

`gates.sh --fast`: `All required gates passed (0 ran, 5 unconfigured, 0 known)`
after `scripts/tidy.sh` was staged. One discrimination mutation of my own,
different from the developer's (the apply-line condition, not the failure path),
against the phase suite only:

    === mutate: scripts/phase.sh (1 line(s) changed by s/if (r + m > 0) print/if (r + m > 999) print/) ===
        FAIL HARNESS-066 AC-6: with one removable worktree and one deletable branch, the fourth line says how to remove them
        FAIL HARNESS-066 AC-6: each appears exactly once
        FAIL HARNESS-066 AC-6: then one blank line, and the output still ENDS with exactly what plan.sh after Q-1 prints (non-empty)
    phase: 70 passed, 3 failed
    === mutate: command exited 1; restored (verified byte-for-byte against .../scripts_phase.sh.20261020T152031Z.42483.bak) ===

Open for the PO, not GREEN's to fix: the AC-5 `-ef` control does not discriminate
on this host (above), and `git branch -d` can refuse a branch DELETABLE against
`--base` when run from a checkout whose HEAD lacks it (C-12 gap). Neither
blocks GATES; both are candidates for `/audit-mutations` or a follow-up story.
