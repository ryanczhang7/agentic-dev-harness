---
id: HARNESS-014
title: The gate stamp covers the commit to be, not untracked files
slug: the-gate-stamp-covers-the-commit-to-be-n
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-014-the-gate-stamp-covers-the-commit-to-be-n
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, scripts/gates.sh, .claude/tests/lib.test.sh, .claude/tests/gates.test.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/commands/advance-story.md, VERSION]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

**The gate stamp is computed over files that CI never sees, so a record can
pass `check-boundaries.sh` locally and fail it on CI for the same commit.
Nothing in the code changed between the two runs. The defect is in how the
local side measures.**

`gates.sh` stamps every full run with `tree: <hash>` from `gate_tree_hash()`
(`.claude/hooks/lib.sh:1036` at `ca8c414`). `check-boundaries.sh` recomputes
that hash and refuses a PR whose record does not match (`:366-374`). On CI it
recomputes from the commit (`gate_tree_hash_of "$PR_HEAD_SHA"`). Locally it
recomputes from the working tree (`gate_tree_hash`). `gate_tree_hash` seeds a
temporary index from HEAD and then runs `git add -A .` (`lib.sh:1048`), which
**adds every untracked, non-ignored file**. Any untracked file that classifies
as source, test, config or non-markdown harness is folded into the hash. A
commit contains none of them. The effect has a direction:

* **Record made with strays present:** local `check-boundaries.sh` passes, and
  CI fails with `gates were recorded against tree … but commit … is …`. The
  message says code changed after the run, which is wrong.
* **Record made clean, strays present later:** local `check-boundaries.sh`
  fails, and CI passes.

Either way the local check stops predicting CI, which is its only job.
HARNESS-008 found this as PO-M
(`docs/backlog/stories/HARNESS-008.md:1870-1928`, "`gate_tree_hash()` hashes
UNTRACKED files") and left it for its own story. No story has owned it until
now.

**What it cost this week:**

* **HARNESS-012, PO-6** (`HARNESS-012.md:1119-1128`, commit `4d9e642`). The
  first gate record was stamped over `handoff-world-080/*.patch`: three files
  classify as `source` and one as `test`. In REVIEW the phase lock correctly
  refused to move the source-classified files. So the story went back to
  GATES, the files were parked outside the repository, `gates.sh` was re-run,
  and the files were restored. `check-boundaries.sh` was then run in a clean
  `git worktree`, because the main checkout could not be trusted.
* **HARNESS-013.** According to the orchestrator's account of the session
  (the story file does not record it), the same files were parked before every
  gate run. `check-boundaries.sh` was again run in a throwaway worktree on a
  renamed branch. That produced a spurious branch-mismatch FAIL of its own,
  and the first time it skipped the story checks entirely, because the branch
  name did not contain the story id. The workaround for this defect cost a
  second defect's worth of confusion.
* **The user's standing memory** records it as a trap to step around: "Park
  them, run `gates.sh`, commit, restore."

The live specimen is still in this checkout: `handoff-world-080/` and two
root `.md` files, all untracked and all the user's. Measured here at
`ca8c414` (Notes, M-3), `gate_tree_hash` is `d2af6c3…` and CI's
`gate_tree_hash_of HEAD` is `62c0c30…`.

**The fix has a trap in the other direction.** "Hash tracked files only" leaves
out any file the story itself creates and has not committed. The documented
flow runs `gates.sh` in GATES and commits in REVIEW (`/advance-story`,
GATES → REVIEW, steps 1-2). A new test or module that was never staged would
drop out of the stamp and then enter the commit. `## Notes` measures both
flows against every candidate (M-4, M-5). One product decision remains open
(`## Open question`) and must be answered before this story leaves PLANNED.

**Required gate.** `BOOTSTRAPPED=no`, so all eight `gates.sh` gates are
UNCONFIGURED (as for HARNESS-008 to HARNESS-013). The thing that fails if this
artifact breaks is `bash scripts/selftest.sh`, specifically the `lib`, `gates`
and `boundaries` suites, which CI runs as a required step. `required_gates: []`
is the honest value.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

"Gated" below means what `gated_stdin` keeps: classified `source`, `test`,
`config`, or `harness` that is not markdown and not under `.claude/state/`.
"Untracked" means listed by `git ls-files --others --exclude-standard`, so it
is never ignored. A hash "equals CI's" when it equals `gate_tree_hash_of` for
the commit named.

- **AC-1: an untracked gated file does not move the stamp (the bug,
  reproduced).** Given a fixture repository with everything committed, when an
  untracked `handoff/x.patch` (which classifies as `source`, as the specimen's
  files do) and an untracked file that classifies as `test` are added, then
  `gate_tree_hash` equals `gate_tree_hash_of HEAD`. At `ca8c414` it does not
  (Notes, M-3). *Control:* in the same fixture, an unstaged edit to a
  **tracked** source file makes `gate_tree_hash` differ from
  `gate_tree_hash_of HEAD`. The working tree still counts for files git
  tracks. A fix that simply hashed HEAD would pass the positive case and fail
  this control.
- **AC-2: the local verdict and CI's verdict agree.** Given a story in REVIEW
  whose `## Gate results` was written by `gates.sh` against a committed tree,
  when an untracked gated file is then added, then `check-boundaries.sh` run
  without `PR_HEAD_SHA` prints `ok    gate record matches the working tree`
  and exits 0. With `PR_HEAD_SHA=$(git rev-parse HEAD)` it prints `ok    gate
  record matches commit …` and exits 0 as well. At `ca8c414` the first run
  refuses. That refusal is why HARNESS-012 and HARNESS-013 ran this check in a
  throwaway worktree. *Control:* after a committed change to a tracked source
  file, both runs refuse with `gates were recorded against tree` and a
  non-zero exit.
- **AC-3: a file the story creates is covered once it is staged (the opposite
  trap).** Given a new gated file that has been written and staged with `git
  add` but not committed, `gate_tree_hash` equals `gate_tree_hash_of` the
  commit that a following `git commit` makes. *Control:* the same file written
  but **not** staged: `gate_tree_hash` does not equal that later commit's
  hash. The unstaged file is exactly what AC-4 exists to name, so AC-3's
  positive case cannot pass for the wrong reason.
- **AC-4: gates.sh names every untracked gated file.** Given untracked gated
  files, both a full `gates.sh` run and a `--fast` run print one line per file
  of the exact form `    UNTRACKED  <path>` (four spaces, `UNTRACKED`, two
  spaces, the path). The line is matched whole (`grep -cx`) and never by the
  bare word. The same output says, in words, that those files are not part of
  the recorded tree. *Control:* in the same run, an untracked docs file
  (`notes.md` at the root) and a harness markdown file are not named. With no
  untracked gated files, no `UNTRACKED` line appears at all.
- **AC-5: what a full run does with its record when AC-4 named anything. THIS
  CRITERION IS NOT FINAL.** It depends on `## Open question` and must be
  rewritten to the chosen option before the story leaves PLANNED. Under
  either option, with **no** active story (CI, and `ci-local.sh`'s gates
  step), `gates.sh` exits with the gates' own status and never refuses because
  of an untracked file.
  * *Option W, warn and record:* with an active story, `gates.sh` records as
    usual, and the `tree:` it writes equals `gate_tree_hash_of` the commit made
    next **without** the named files. *Control:* the named files are still in
    the working tree after the run, unmoved.
  * *Option R, refuse to record:* with an active story, `gates.sh` leaves
    `## Gate results` byte-for-byte unchanged, prints a `(not recorded: …)`
    line giving the reason, and exits non-zero even when every gate passed.
    *Control:* once the named files are staged, or excluded through
    `.git/info/exclude`, the same run records and exits 0.
- **AC-6: ignored files stay irrelevant, including the local exclude file.**
  Given an untracked file that would classify as `source` but is ignored,
  either by `.gitignore` or by `.git/info/exclude`, it neither moves
  `gate_tree_hash` nor gets an `UNTRACKED` line. *Control:* with the ignore
  rule removed, the same file is named by AC-4.
  `.git/info/exclude` is here on purpose. It is the remedy the refusal (under
  R) or the warning (under W) will point a user to for a stray they mean to
  keep, so it must actually work.
- **AC-7: what already holds still holds.** These existing assertions pass
  unchanged: in `lib.test.sh`, `working tree hash equals HEAD hash under
  autocrlf=true`; in `boundaries.test.sh`, `a stamp describing a different
  tree is refused`, `a test changing alone breaks the stamp too` and `and the
  stamp gates.sh wrote IS that hash`; and `worktree.test.sh`'s AC-3 block.
  Three `lib.test.sh` assertions in "covers what the gates judge" hash files
  the fixture never commits (Notes, M-6): `a hook moves the hash`, which fails
  under the fix, and `a command prompt does not move the hash` and `a docs
  file does not move the hash`, which would become vacuous. RED rewrites all
  three so that their files are tracked, keeping the names and what they
  claim. Each rewritten assertion is earned by a mutation, because it passes
  the moment it is written (`rules.md`, non-negotiables).
- **AC-8: the floor is raised in both places.** For every suite that gains
  assertions (expected: `lib`, `gates` and `boundaries`),
  `.claude/tests/floors.conf` and the `COUNTS` table in
  `.claude/tests/selftest.test.sh` (lines 437-456 at `ca8c414`: `lib 197`,
  `gates 92`, `boundaries 73`) record the same new count. *Control:* the value
  is the executed count reported by `bash scripts/selftest.sh <suite>`, not a
  count of `assert_` call sites. `bash scripts/selftest.sh selftest` passes,
  which is how the two records are checked to agree.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
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

**Left for PLANNED**, following HARNESS-012 and HARNESS-013. The contract
depends on the answer to `## Open question`. The evidence it will draw on is in
`## Notes`: the callers of `gate_tree_hash` (M-1), the candidate computation
already measured equal to CI's on the real tree (M-3, row C), and the existing
assertions that pin today's behaviour (M-6).

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
         reason. check-boundaries.sh refuses a PR that has neither
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. Do THREE mutations rather
     than one, and make one of them a wrong VALUE rather than a missing field: a
     suite that catches an omission can be blind to a corruption, and a codec
     that is uniformly wrong round-trips through itself perfectly. -->

### DV-1. Probe against the real tree: the live specimen

*Condition.* In this checkout, with the user's untracked files present and
**untouched** (`handoff-world-080/` and the two root `.md` files), and the
story's GREEN commit checked out:

* `gate_tree_hash` **must** equal `gate_tree_hash_of HEAD`. At `ca8c414` they
  differ: `d2af6c3…` against `62c0c30…` (M-3).
* `gates.sh --fast` **must** print exactly four `    UNTRACKED  <path>`
  lines: the three `.patch` files that classify as `source` and the one that
  classifies as `test` (M-2). It must not name `handoff-world-080/README.md`,
  `agentic-dev-harness-brief.md` or `harness-feedback-world-080.md`, which
  classify as `docs`.
* *Control on a real line:* with `lib.sh`'s hash computation mutated back to
  `git add -A .` through `scripts/mutate.sh`, the first check **must** fail on
  this same tree.

This is the real-tree probe that `rules.md` requires for a change to a rule
that judges the tree. The fixtures encode the reading of the problem written
here, and only this probe shows the rule is right about the files that are
actually in the tree.

*Why not RED.* It probes the fix, and in RED the fix does not exist. Nothing is
moved, staged or excluded. If the user has cleaned up the specimen by GATES,
say so, and rebuild the same shape in a scratch `git worktree` with an
untracked `.patch` file, rather than touching the user's files.

**Owner: GATES**

### DV-2. Wrong-value mutations of the hash

*Condition.* Each of the following, run one at a time through
`scripts/mutate.sh` against the GREEN implementation, **must** turn red the
assertions RED predicts, and nothing else. RED writes the predicted counts in
its handoff, and GATES compares against them.

* **X-A, the defect put back** (`add -A` in place of the fix): AC-1's
  positive case and AC-2's local run go red.
* **X-B, staged files dropped** (seed the temporary index from HEAD instead of
  from the real index, or whatever GREEN's spelling of "staged" is): AC-3's
  positive case goes red, and AC-3's control does not.
* **X-C, the wrong value: the working tree ignored for tracked files** (hash
  the index alone, with no update from the working tree): AC-1's control goes
  red, and AC-1's positive case does not. This is the one where a mutation
  that leaves out a step is not enough, because a fix of "hash HEAD" passes
  every positive case.
* **X-D, the ignore filter dropped** from the listing that AC-4 prints
  (`--exclude-standard` removed, or its equivalent): AC-6 goes red.

*Why not RED.* There is nothing to mutate until GREEN.

**Owner: GATES**

### DV-3. Every assertion that passes on arrival is earned by a mutation

*Condition.* RED's handoff lists every new or rewritten assertion that is
green against `ca8c414`. Expected: AC-1's control, AC-3's control, AC-6's
positive cases, AC-7's rewritten assertions, and AC-5's no-active-story
clause. Beside each, the handoff names the mutation that turns it red. GATES
runs each one and pastes the output here.

*Why not RED.* Most of the mutations target code that GREEN writes.

**Owner: GATES**

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from the base branch without an entry here. Omit the section if unused.
     Where the change came from a subagent's claim that the criterion was
     wrong, record the ORCHESTRATOR'S OWN reproduction of it - different
     inputs, not the subagent's code. That claim is also what an agent says
     when it wants to stop failing. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-014` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `opus` | planning is the judgement phase: decomposition, the oracle partition, and what goes in the contract |
| RED | `test-developer` | `fable` | the measured case. With a partitioned contract to work from, the brief carries the judgement and the weaker model writes sharper negative controls than the stronger one did without it |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `opus` | reading review feedback against the contract is judgement, and a wrong call here ships |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation, with no failing test in front of any of it |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **Deleting, moving, staging, ignoring or excluding the user's untracked
  files** (`agentic-dev-harness-brief.md`, `handoff-world-080/`,
  `harness-feedback-world-080.md`). They are the specimen DV-1 runs against.
  Adding them to `.gitignore` or `.git/info/exclude` is the user's decision,
  and the story does not make it for them.
- **HARNESS-001's mutation tests** for the same stamp. That story keeps its
  own criteria, and this one does not edit them (see Notes, PO-B).
- **CI configuration.** `.github/workflows/*.yml` is read here, not changed.
  CI already computes the correct answer (M-5). The fix makes the local
  side agree with it.
- **`gate_tree_hash_of`.** It reads a commit, and it is already correct.
- **Changing what is gated.** `gated_stdin` and `paths.conf` do not change. A
  `.patch` file falling through to `source` is correct for an authored file.
  The defect is that the file is untracked, not how it is classified.
- **`code_changed_since`, the Stop hook's staleness check.** It walks files
  newer than the stamp, whether tracked or not. After this story, an untracked
  gated file edited after a gate run will make the Stop hook ask for a re-run
  that the stamp does not need. That false alarm errs on the safe side and has
  not been seen in practice: the specimen files do not change. But it makes
  the comment at `lib.sh:936-939` ("the two answers cannot drift apart") false
  for untracked files. **GREEN corrects that comment** so that it states the
  asymmetry. Making the two predicates agree again is a separate story if
  anyone ever hits it.
- **Committing new files earlier in the cycle.** Whether RED and GREEN must
  commit is a procedural question for `/advance-story`. This story changes
  that file only to say that a new file must be staged before the full
  `gates.sh` run (see Contract, once written), and it does not otherwise
  change the procedure.
- **Retro-stamping past stories.** Gate records already merged are left alone.
  Their hashes were checked by CI against their own commits and matched.
- **The user's memory note** ("Park them, run gates.sh, commit, restore")
  becomes stale once this ships. Updating it is the user's or the
  orchestrator's job, not something for a story diff.

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
         or Gate probes section describes a failure without showing one
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
     it guards, run the gate, paste the failure, revert. One block per gate:
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


Filed 2026-09-24 as the story HARNESS-008's PO-M asked for. **The
`## Contract` is left for PLANNED**, as in HARNESS-012 and HARNESS-013. This
section holds the evidence, so that PLANNED can read the numbers out rather
than measure them again. Line numbers are at `ca8c414` (release 52).

### Measurements, 2026-09-24, this repository at `ca8c414`, Git Bash on Windows 11

**M-1. Every caller of `gate_tree_hash`, and of what it claims to agree
with.** From `grep -rn gate_tree_hash` over `.claude/`, `scripts/` and
`.github/`. A change to what the function hashes changes the meaning of all of
them:

| Where | What it does | Affected? |
|---|---|---|
| `scripts/gates.sh:206` (`record_in_story`) | writes `tree:` into `## Gate results` | **yes**: this is the recorder |
| `scripts/check-boundaries.sh:369` | the local verifier, when `PR_HEAD_SHA` is unset | **yes**: this is the side that disagrees with CI today |
| `scripts/check-boundaries.sh:367` | `gate_tree_hash_of "$PR_HEAD_SHA"`, used by CI and by `ci-local.sh` | no: it reads a commit |
| `.claude/hooks/lib.sh:945` `code_changed_since` → `.claude/hooks/gate-reminder.sh:135` | Stop hook staleness check. It does not call the function, but its comment (`lib.sh:936-939`) claims to answer "would the recorded gate hash still match" | its **comment** becomes false for untracked files (see Out of scope) |
| `.claude/tests/lib.test.sh:239-254` | autocrlf: `gate_tree_hash` equals `gate_tree_hash_of HEAD` after a commit | must still pass (AC-7). The fix must keep the HEAD or index seeding that the CRLF fix depends on |
| `.claude/tests/lib.test.sh:348-368` | "covers what the gates judge": writes `.claude/commands/advance-story.md` and `.claude/hooks/lib.sh` into the fixture and hashes them **without committing** | see M-6 |
| `.claude/tests/boundaries.test.sh:1188-1222` | a record matches its tree, the stamp IS the hash, and a later source or test change is refused | must still pass (AC-7) |
| `.claude/tests/worktree.test.sh:290-318` | HARNESS-008 AC-3: a record belongs to the worktree that made it | must still pass (AC-7) |
| `.claude/tests/gate-reminder.test.sh:277` | comment only | no |

No signature changes are planned. Both options keep `gate_tree_hash` with no
arguments, printing one hash. What changes is its meaning, which is why the
list matters.

**M-2. The live specimen.** `git ls-files --others --exclude-standard`, each
path run through `scripts/classify.sh`:

    agentic-dev-harness-brief.md                               docs
    harness-feedback-world-080.md                              docs
    handoff-world-080/README.md                                docs
    handoff-world-080/part-_lib.sh.patch                       source
    handoff-world-080/part-phase-guard.sh.patch                source
    handoff-world-080/world-080-phase-guard-sed-inplace.patch  source
    handoff-world-080/part-phase-guard.test.sh.patch           test

Four gated files and three not gated: the same set HARNESS-008's PO-M listed
three days earlier. The files have been in the tree through three stories.

**M-3. The live comparison, read-only.** `scratchpad/measure.sh` sources
`lib.sh` from the repository root, the same way `boundaries.test.sh:1203`
does, and prints four hashes. Nothing in the tree was moved.
`git status --porcelain` was identical before and after:

    A gate_tree_hash (today, working tree incl. untracked): d2af6c301eb3e0190c595a0979507d6c0f7a284b
    B gate_tree_hash_of HEAD (what CI computes):           62c0c30969085155993ac26dedab4fcf0d859a1a
    C candidate (a), index + add -u:                        62c0c30969085155993ac26dedab4fcf0d859a1a
    D today's listing with untracked paths removed:        62c0c30969085155993ac26dedab4fcf0d859a1a

**They differ.** Today's local stamp is not the hash CI will compute for this
same commit. Two tracked-only computations agree with CI exactly:

* **C** copies the real index (tracked plus staged) and runs `git add -u`,
  which updates tracked files and records deletions. That is "the tree `git
  commit -a` would make".
* **D** is today's listing with the untracked paths removed.

All four took 6.9s together (a single hash is about 1.7s), so cost does not
separate the candidates.

"Files absent" measurement: in a scratch `git worktree add --detach` of
`ca8c414`, under the scratchpad and since removed, all four print
`62c0c30…`. So the whole difference is the untracked files.

**M-4. The new-file flow, the opposite trap, measured.** In the same scratch
worktree, a new `.claude/tests/new-thing.test.sh` (classifies as `harness`,
which is gated):

| state of the new file | A (today) | C (candidate a) | CI after `git commit` |
|---|---|---|---|
| absent | `62c0c30` | `62c0c30` | n/a |
| written, **untracked** | `40b6e7e` | `62c0c30` | n/a |
| **staged** (`git add`) | `40b6e7e` | `40b6e7e` | n/a |
| committed | - | - | `gate_tree_hash_of HEAD` = `40b6e7e` |

So **today's behaviour is right for a new file and wrong for a stray one**.
Candidate (a) is the reverse, **unless the new file is staged**. When staged,
(a) is right for both. An unstaged new file under (a) gives a stamp of
`62c0c30`, and after the commit CI computes `40b6e7e`. That is a **loud**
mismatch, never a silent match: nothing in (a) can make CI agree with a stamp
that left out a file the commit contains. The worse outcome the brief named,
"a match that judged less code than it claims", cannot come from the new-file
flow under any candidate. It can come from the stray flow (see M-7).

**M-5. What CI and `ci-local.sh` hash.**
* `.github/workflows/boundaries.yml` checks out with `fetch-depth: 0` and runs
  `check-boundaries.sh origin/<base>` with `PR_HEAD_SHA` set to the PR head.
  So CI always takes `gate_tree_hash_of <commit>`: **tracked files at that
  commit, nothing else**. `gates.yml` runs `selftest.sh`, the two tree guards,
  `gates.sh --list`, `--audit` and a full `gates.sh`. On CI there is no
  active story (`.claude/state/` is gitignored), so that `gates.sh` records
  nothing.
* `scripts/ci-local.sh:69` sets `PR_HEAD_SHA=$(git rev-parse HEAD)` before
  running the same steps (`--dry-run` lists them: 8 steps, `check-boundaries`
  last). So **`ci-local.sh` is not fooled.** Its boundaries step compares the
  story's record with the commit, exactly as CI does, and with strays present
  it reports CI's FAIL. This was established by reading, not by a run, because
  a full `ci-local.sh` here is a 15-minute-plus selftest.
  One interaction to know about: with an active story, `ci-local.sh`'s own
  `gates.sh` step rewrites `## Gate results` in the working tree before
  `check-boundaries` reads it. Today that re-records a stray-inclusive stamp,
  and the step then FAILs, which is the right verdict for the wrong reason.
  After this story it records a stamp that agrees. Under Option R it declines
  to record, and AC-5 says what the exit status is.
* So the defect affects exactly **two** readers: `gates.sh` when it records,
  and `check-boundaries.sh` run by hand. It is also the one CLAUDE.md tells
  you to run "after committing and before opening the PR".

**M-6. Existing assertions that pin today's behaviour.** Measured by running
candidate (a) as a mutation (`git add -A .` → `git add -u .` in
`gate_tree_hash`, through `scripts/mutate.sh`) over the `lib`, `gates`,
`worktree`, `gate-reminder` and `boundaries` suites.

    === mutate: .claude/hooks/lib.sh (1 line(s) changed by s/GIT_INDEX_FILE="\$idx" git add -A \. >/GIT_INDEX_FILE="$idx" git add -u . >/) ===
        FAIL a hook moves the hash
    lib: 196 passed, 1 failed
    gates: 92 passed, 0 failed
    worktree: 73 passed, 0 failed
    gate-reminder: 32 passed, 0 failed
    boundaries: 73 passed, 0 failed
    === mutate: command exited 0; restored (verified byte-for-byte against …/.claude_hooks_lib.sh.20260924T170114Z.362334.bak) ===

This matches the prediction made from reading M-1's rows. **Exactly one
existing assertion pins the defect:** `lib.test.sh:363-365`, `a hook moves
the hash`. It writes `.claude/hooks/lib.sh` into the fixture and never commits
it, so it passes only because untracked files are hashed. RED rewrites it so
that the file is tracked (or staged) before `h0` is taken, and earns it with
DV-3. **Two more become vacuous without failing:** `a command prompt does not
move the hash` and `a docs file does not move the hash` (`:360-362`) write
untracked files. Under the fix, an untracked file moves nothing whatever its
class, so these two would pass against a hash that counted markdown. RED
makes those files tracked as well, so that the negatives still discriminate
by class and not by tracking status. This is why AC-7 lists them. **Every
other assertion in the five suites is indifferent to the change.** It follows
that nothing in the suite today would notice the fix being reverted: that is
AC-1's job, and DV-2 X-A checks it.

**M-7. Which past stories created files, and whether those files were tracked
when `gates.sh` ran.** `git log --diff-filter=A` over `.claude/tests`,
`scripts` and `.claude/hooks`: the only story-cycle addition is HARNESS-008's
`worktree.test.sh`. It was committed in the RED commit `7215b22`, before the
gate record in `5d19583`. HARNESS-012 and HARNESS-013 added no files. Both
committed RED and GREEN before GATES (`a8134b6`, `4a0e72d`), and their
records say `commit: … (working tree had uncommitted changes)` only because
of docs and `VERSION`. **In this repository's practice, a new file is already
tracked when `gates.sh` runs.** `/advance-story` does not require that,
though, and a downstream project that writes a module in GATES to satisfy a
lint rule would hit the unstaged case. **The stray case happened in two
consecutive stories, and the new-file case has not happened at all.**

The stray flow also contains the one path to a silent wrong answer. The gates
**run** over the working tree, strays included. In a project whose test
runner collects by glob (vitest, pytest), an untracked `*.test.*` file is
executed and counted, and an untracked module can be imported by committed
code. With a tracked-only stamp, such a run records a hash that matches CI
while the gates judged a tree that CI will not have. CI's own `gates` job
re-runs the suite and would catch an import that breaks, but the recorded
stamp itself would claim more than it knows. This is the argument for Option
R below.

### Candidates

| | stray `.patch` present (the specimen) | new gated file, staged | new gated file, unstaged | cost |
|---|---|---|---|---|
| **today** | local passes, CI FAILs: silent until the PR | correct | correct | none, until it bites |
| **(a) hash tracked + staged** (M-3, row C) | stamp = CI's, and local `check-boundaries` agrees (AC-1, AC-2) | correct (M-4) | stamp omits it, and after the commit **both** local `check-boundaries` (REVIEW step 3) and CI refuse: loud, but found one step late | a stray that a runner collects is judged but not stamped (M-7) |
| **(b) refuse or warn, hash unchanged** | the specimen blocks or warns on every run, and **local `check-boundaries` stays wrong** (it still hashes the strays) | correct | named at `gates.sh` time | does not fix the verifier, so HARNESS-012's worktree dance remains. **Rejected on its own** |
| **(c) tracked + untracked inside `touches:` / `## Contract` paths** | stray excluded | correct | correct if declared | CI cannot reproduce it. `check-boundaries.sh` has no active-story context on CI and would need to parse frontmatter to rebuild a hash. `touches:` is not enforced, and CLAUDE.md says nothing checks a declaration against the diff. `gates.sh` with no active story (CI, `ci-local`) has no paths at all. **Rejected**: it makes the stamp's meaning depend on an unchecked declaration |
| **(a) + name them, W: warn and record** | named each run. Stamp = CI's | correct | named at `gates.sh` time, and refused locally at REVIEW step 3 if ignored | the specimen prints four lines on every run |
| **(a) + name them, R: refuse to record** | with an active story, no record until the strays are staged, moved or excluded (`.git/info/exclude`, the user's choice). With no story, no refusal | correct | refused at `gates.sh` time, the earliest point | this checkout cannot record a gate run until the user excludes or moves the four `.patch` files, once |

**PO-A. Recommendation: (a) plus naming, with Option R.** (a) is the part
that fixes the defect. It is the only candidate that makes the local
verifier and CI compute the same thing, and it measured equal to CI on the
real tree (M-3). Naming is the part that covers the opposite trap: an
unstaged new file is named at `gates.sh` time under either option. W and R
differ only in whether a record is written while the gates ran over files the
stamp does not describe. R is the honest one: the stamp means "the gates ran
against exactly this", and a user with a stray they mean to keep adds one line
to `.git/info/exclude` once (AC-6 makes that remedy real). W is the
convenient one. It is still correct for CI, but the recorded stamp can claim
less than the gates saw (M-7). That is a product decision about how loud the
harness is about the user's own files, so it goes to the user.

**PO-B. Relation to HARNESS-001.** HARNESS-001 ("Gate record tree stamp is
verified end to end", `type: chore`, `depends_on: []`, still PLANNED) targets
the same stamp at the same three sites. Its line numbers are stale
(`gates.sh:191` is now `:206`, `check-boundaries.sh:294` is now `:370`, and
`lib.sh:637` is now inside `_hash_blob_listing` at `:1023`). **Its criteria
appear to be satisfied already.** Commit `9fbd39d` ("Construct the violating
input for law 1 and law 3", 2026-09-15, the day the audit was filed) added
`boundaries.test.sh:1195-1222`:
* `and the stamp gates.sh wrote IS that hash` covers HARNESS-001's AC-2;
* `a stamp describing a different tree is refused` covers AC-1;
* `a test changing alone breaks the stamp too` covers AC-3;
* `run_boundaries` now captures `$rc`, and `refused` asserts that it is
  non-zero (`:32-49`), which covers AC-4.

The filing PO checked one of these rather than taking it from the
reading. HARNESS-001's own AC-2 mutation, through `scripts/mutate.sh`:

    === mutate: scripts/gates.sh (s#tree="\$(gate_tree_hash)"#tree=0000000#) ===
        FAIL and the stamp gates.sh wrote IS that hash
             expected: b37e2e9e04a492c81def59bae10190ad47147ce8
             actual:   0000000
    boundaries: 69 passed, 4 failed
    === mutate: command exited 1; restored (verified byte-for-byte against …/scripts_gates.sh.20260924T164550Z.330169.bak) ===

(The run took 14m48s, and 4 assertions fail rather than 1 because the other 3
depend on a matching stamp.) So **the orchestrator's premise, that
HARNESS-014 goes first "so HARNESS-001 pins the corrected behaviour", does not
hold as stated**. HARNESS-001's criteria say nothing about untracked files, and
the corrected behaviour is pinned by HARNESS-014's own AC-1 to AC-3. **The
order does not matter to HARNESS-001's criteria.** It matters only for
conflicts: the two touch `lib.sh`'s hash, `gates.sh:206`,
`check-boundaries.sh:367-370` and `boundaries.test.sh`, so they must not run
in parallel worktrees. **Recommendation to the user, not acted on:** check
AC-1, AC-3 and AC-4 of HARNESS-001 by their own mutations and, if they are
killed, close HARNESS-001 as already delivered by `9fbd39d`, rather than add
`depends_on: [HARNESS-014]` to it. If it is kept, adding `depends_on:
[HARNESS-014]` is harmless, and whether to do so is the user's call.
HARNESS-001's criteria were not edited.

`bash scripts/plan.sh conflicts` for the pair: `UNKNOWN   HARNESS-001 +
HARNESS-014 no Contract paths declared yet - cannot judge`. Neither story has
a Contract. **By hand: CONFLICT**, on the four files above. (The command
exited 1 because of an unrelated real conflict, `HARNESS-006 + HARNESS-009` on
`scripts/plan.sh` and `.claude/tests/plan.test.sh`.)

**PO-C. Sizing: one story, not split.** The candidate is one computation in
`gate_tree_hash` (C, measured), a listing plus a branch in `gates.sh`, and one
sentence in `/advance-story`. Every criterion falls in one of three suites the
harness already has, and each can be tested in isolation. Splitting "fix the
hash" from "name the files" would ship (a) alone for one story. By M-4, that
turns the unstaged-new-file case from correct into a mismatch found one step
late, with nothing naming the cause. The two halves are one behaviour: the
stamp means the commit to be, and the harness says when the working tree
holds more than that.

**PO-D. Oracle partition, for the Contract.** Every criterion is
**mechanical**: fixture repositories, hash equality against
`gate_tree_hash_of`, whole-line counts of `    UNTRACKED  <path>`, exit
statuses. There is no metric to invent. The one settled number is AC-8's
floors, which are read from `selftest.sh`.

## Open question

**When a full `gates.sh` run with an active story finds untracked gated
files, does it record anyway (W) or refuse to record (R)?** The hash fix is
the same under both. What differs is `gates.sh`'s record-and-exit branch and
AC-5's wording.

* **Option W: warn and record.** The `UNTRACKED` lines are printed. The record
  is written with the tracked-plus-staged stamp, which equals CI's. Exit
  status is the gates' own.
  *For:* nothing blocks. The specimen in this checkout costs four lines of
  output per run and nothing else. *Against:* the recorded stamp can describe
  less than the gates ran over, when a runner collects an untracked test or
  committed code imports an untracked module (M-7). An unstaged new file is
  named, but if the name is ignored, the mismatch surfaces one step later, at
  REVIEW step 3.
  *Measured cost here:* none. Gate runs in this checkout record correctly with
  the specimen in place.
* **Option R: refuse to record.** The `UNTRACKED` lines are printed. With an
  active story, `## Gate results` is left unchanged, a `(not recorded: …)`
  line gives the reason and the two remedies (stage the file, or exclude or
  move it), and the exit is non-zero. With no active story (CI, `ci-local`'s
  gates step), there is no refusal.
  *For:* a record exists only when the gates judged exactly the stamped tree.
  An unstaged new file is caught at the earliest point. *Against:* in this
  checkout no story can record a gate run until the user moves the four
  `.patch` files or adds them to `.git/info/exclude`, once.
  *Measured cost here:* four files, one exclude line (for example
  `handoff-world-080/*.patch`), done by the user and never by the story.

**PO recommendation: R** (PO-A). AC-5 must be rewritten to the chosen option
before the story leaves PLANNED, and the decision recorded here as PO-1, with
who made it.
