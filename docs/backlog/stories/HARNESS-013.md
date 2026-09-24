---
id: HARNESS-013
title: The LOCAL alarm counts only release refs as shipped
slug: the-local-alarm-counts-only-release-refs
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-013-the-local-alarm-counts-only-release-refs
depends_on: [HARNESS-012]  # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/refresh-harness.sh, .claude/tests/refresh.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

**HARNESS-012 fixed the alarm for objects no ref reaches. It left it switched
off for objects the WRONG ref reaches, and the incident that motivated
HARNESS-012 is one of those in any clone that fetched at the wrong time.**

`refresh-harness.sh` warns before it overwrites a downstream file that upstream
has never shipped (the LOCAL report, H26). Since release 51 it asks whether the
downstream blob is reachable from upstream:

    scripts/refresh-harness.sh:255   (release 51)
      up_reachable="$(git -C "$UP" rev-list --objects --all 2>/dev/null | awk '{print $1}')"

`--all` means every ref plus `HEAD`. So every ref is treated as a release, and
these still silence the alarm (HARNESS-012 PO-5 names them and defers them here):

* a **live stash** in the upstream checkout (`refs/stash`);
* a **fetched PR** kept as a ref (`refs/pull/*`, or a remote-tracking `pr/*`);
* a **remote-tracking experiment branch** (`refs/remotes/origin/<throwaway>`).

**The third is the sharp one.** HARNESS-010 pushed manga-translator's hooks to a
throwaway branch, `xcompare/HARNESS-010`, so that it could run a comparison on
CI. That branch was later deleted on origin. The push that deleted it also
removed the tracking ref in the clone that made the push, which is why this
repository's store holds the blobs as dangling objects and HARNESS-012 could see
them. **Any other clone** that fetched while the branch existed, and has not
run `git fetch --prune`, still has `refs/remotes/origin/xcompare/HARNESS-010`.
In that clone `--all` reaches the blobs, and the four reconciled files
HARNESS-012 brought back into the report drop out again. This was reproduced
against the real script and the real commit (Notes, M-3): 17 LOCAL becomes 13.

Pruning is not something the refresh can rely on. This clone has **40**
remote-tracking refs whose branches no longer exist on origin (M-1). Clones
that have never been pruned are the normal case.

The question this story answers: **which refs count as a release?** `--all` is
too wide. Narrowing it has a cost in the opposite direction, because each ref
dropped from the set can produce new false alarms. HARNESS-012's AC-2 (the
quiet half) exists because an alarm that fires for every file a project behind
by several releases carries is an alarm nobody reads. The measurements in
`## Notes` show which narrowings cost that silence and which do not. **One of
the narrowings needs a product decision (`## Open question`), which must be
answered before this story leaves PLANNED.**

**Required gate.** `BOOTSTRAPPED=no`, so all eight `gates.sh` gates are
UNCONFIGURED (as for HARNESS-008 through HARNESS-012). The thing that fails if
this artifact breaks is `bash scripts/selftest.sh refresh`, which runs in CI as
a required step. `required_gates: []` is the honest value.

## Acceptance criteria

Every "LOCAL" or "not LOCAL" below is judged by a `--dry-run` report line of the
exact form `    LOCAL     <path>` (four spaces, `LOCAL`, five spaces, the
path), matched as a whole line. It is never judged by the word `LOCAL`, which
also appears in the report's explanatory paragraph.

- **AC-1: a live stash is not a release.** Given a downstream file whose
  content is reachable in upstream only from `refs/stash`, the refresh lists it
  as LOCAL. *Control:* in the same fixture, a second file whose content is
  committed on upstream's default branch is NOT listed.
- **AC-2: a remote-tracking branch other than the default's upstream is not a
  release.** This is the sharp case. Given a downstream file whose content is
  reachable in upstream only from `refs/remotes/origin/<b>`, where `<b>` is not
  the default branch (the stale-experiment case), the refresh lists it as LOCAL.
  *Control (a quiet-half case):* upstream's local default branch is behind
  `refs/remotes/origin/<default>`, and the downstream file's content is
  reachable only from `origin/<default>`. That file is NOT listed. This is a
  project refreshed from a newer clone and now checked against an older one.
  Measured on real trees, dropping this ref costs 4 false alarms (Notes, M-5).
- **AC-3: a fetched PR ref is not a release.** Given a downstream file whose
  content is reachable in upstream only from `refs/pull/<n>/head`, the refresh
  lists it as LOCAL. *Control:* after the same commit is merged into the default
  branch, the file is NOT listed.
- **AC-4: the quiet half holds.** In the same run as the positive cases in
  AC-1 to AC-3, a downstream file whose content matches an OLDER release on the
  default branch is NOT listed. That means a commit at least one release before
  the default branch's tip, not the tip itself. The existing quiet-half
  assertions in `refresh.test.sh` stay green: `while merely being behind is
  silent`, `a project holding upstream's own files is told nothing`, and
  `while a scripts/ file matching upstream is silent`.
- **AC-5: a local branch that is not the default. THIS CRITERION IS NOT FINAL.**
  Its outcome depends on `## Open question`, and it must be rewritten to one of
  the two forms below before the story leaves PLANNED. Given a downstream file
  whose content is reachable in upstream only from a local branch
  `refs/heads/<b>` that is not the default branch and is not merged into it:
  * *Option A:* it is NOT listed. Local branches count as shipped.
    *Control:* the same content reachable only from `refs/stash` IS listed.
  * *Option B:* it IS listed. Only the default line counts as shipped.
    *Control:* the same content after `<b>` is merged into the default branch is
    NOT listed.
- **AC-6: an upstream whose default branch cannot be identified does not cry
  wolf.** Given an upstream with no `refs/remotes/origin/HEAD`, no `main` and no
  `master`, a downstream file whose content is reachable from upstream's
  checked-out branch is NOT listed. An upstream the script cannot classify is
  not evidence that the content was never released. The refresh script's
  source-branch NOTE already follows this rule (lines 167-170 at release 51).
  *Control:* in the same fixture, content reachable only from `refs/stash` IS
  listed. Excluding the stash must not depend on finding a default branch.
- **AC-7: nothing HARNESS-012 fixed comes back, and the no-history guard is
  not weakened.** HARNESS-012's dangling-blob assertions (content in upstream's
  store that no ref reaches is LOCAL, at all three walks) still pass. A shallow
  or single-commit upstream still reports that it could not check. Neither
  outcome is presented as a clean result. The diff to the `up_has_history`
  branch is expected to be empty.
- **AC-8: the floor is raised in both places.** `.claude/tests/floors.conf` and
  the `COUNTS` table in `.claude/tests/selftest.test.sh` (currently line 452,
  `refresh 79`) record the same new count for `refresh`. *Control:* the value
  is the executed assertion count reported by `bash scripts/selftest.sh
  refresh`, not a count of `assert_` call sites. `bash scripts/selftest.sh
  selftest` passes, which is how the two records are checked to agree.

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

**Left for PLANNED**, following HARNESS-012's convention. It depends on the
answer to `## Open question`. The evidence it will draw on (the candidate ref
sets, their measured cost, and the HARNESS-012 assertions that Option B
rewrites) is in `## Notes`, so PLANNED can use those numbers rather than
measuring again. Two things PLANNED must pin, whichever option is chosen:

* **How the default branch is resolved.** Reuse the resolution the script
  already uses for its "not a release" NOTE (`src_default`, lines 171-178 at
  release 51): `origin/HEAD`'s target, then `main`, then `master`. The script
  should have one definition of "the release line", not two.
* **The callers of changed behaviour.** No exported signature changes. The one
  behaviour change with existing callers is the `up_reachable` set. List every
  assertion in `refresh.test.sh` that depends on a non-default ref counting as
  shipped (Notes, M-7), so that RED has the complete list.
* **Oracle partition, provisional.** AC-1 to AC-7 are *mechanical*. Each is a
  fixture upstream with refs arranged by hand, plus a whole-line count of
  `    LOCAL     <path>`. AC-8 is *settled*: read the number off the executed
  count. No criterion is oracle-free.

## Deferred verifications

### DV-1. Probe against a real tree: the stale-tracking-ref case, with the real commit

*Condition.* Use a `--no-hardlinks` clone of this repository at the story's
merge base. Give it `refs/remotes/origin/xcompare/HARNESS-010` pointing at the
real throwaway commit `83add19415d3d0ad7aaff9a3ca84dee3a868d612`, which is
still in this repository's store as an unreachable commit. With that clone as
upstream, a dry run of `../manga-translator` **must** list
`.claude/hooks/lib.sh`, `.claude/hooks/phase-guard.sh`,
`.claude/tests/phase-guard.test.sh` and `.claude/tests/_lib.sh` as LOCAL. At
release 51 it does not: 13 LOCAL against 17 without the ref (Notes, M-3).
Everything else in the LOCAL list must be unchanged from the same run without
the ref. That second check is the quiet half against a real tree. It is
**not** checked against a fixed number, because manga-translator moves (see M-2).

*Why not RED.* This probes the fix itself, and during RED the fix does not
exist. RED's fixtures reproduce the same shape on a small scale. This entry is
the real-tree check that `rules.md` requires for a change to a rule that judges
a tree. The clone and the ref live in a scratch directory. Nothing is written to
this repository or to manga-translator except the refresh's own self-copy under
manga-translator's gitignored `.claude/state/`, which the script removes.

*Caveat for whoever runs it.* A plain `git clone` of a local path does not copy
unreachable objects. Use `--no-hardlinks` and check `git cat-file -t 83add19`
before creating the ref. If `gc` has pruned the commit by then, say so and
rebuild the equivalent by committing manga-translator's four files on a branch
in the clone, then moving that branch to `refs/remotes/origin/`.

**Owner: GATES**

### DV-2. The wrong-VALUE mutation: put `--all` back

*Condition.* With the fixed ref set mutated back to `--all` through
`scripts/mutate.sh`, the positive assertions for AC-1, AC-2 and AC-3 **must**
fail (at least three). No quiet-half assertion may fail. RED predicts the exact
count in its mutation table, and GATES compares against that prediction. A
second mutation that drops only `origin/<default>` from the set **must** turn
AC-2's control red.

*Why not RED.* There is no fixed ref set to mutate until GREEN.

**Owner: GATES**


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

Planned by `bash scripts/plan.sh write HARNESS-013` from `.claude/harness/models.conf`.
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

| Phase | Agent | Planned | Resolved | How dispatched | Verdict |
|---|---|---|---|---|---|
| PLANNED (filing only) | `lead-po` | `opus` | `claude-opus-5-5` (self-reported) | dispatched by the orchestrator to file the story. No model override was reported to this agent | pending. Filing is not all of PLANNED: the Open question, the rewrite of AC-5 and the `## Contract` are still to do |

The RED row's `fable` assumes a partitioned `## Contract`. At filing, the
Contract holds only a placeholder, although `plan.sh write` rendered the
`fable` row anyway. If RED is dispatched before the Contract is written, the
premise of that row does not hold. Re-run `plan.sh write` after the Contract
exists.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **Running `git fetch --prune`, `git stash drop`, `git gc`, or anything else
  that mutates the upstream checkout.** The refresh only reads upstream. It is
  somebody else's clone, and the 40 stale refs in this clone (M-1) are
  housekeeping for the user, not work for this story. The fix has to hold in an
  unpruned clone, because that is where the defect lives.
- **Changing WHICH files are replaced.** This story changes what the report
  SAYS. The KEPT/REPLACED copy loop does not change.
- **Changing what the "source is not a release" NOTE does.** The NOTE stays a
  warning and does not become a refusal. The story reuses the NOTE's
  default-branch resolution. It does not change it, and it does not change when
  the NOTE prints.
- **Introducing release tags or changing `VERSION`.** This repository has no
  tags (M-4). `VERSION` is the release marker, `51 (2026-09-23)`, and nothing
  parses it. "Tags only" is therefore not an available definition of a release,
  and tagging past releases is a separate decision for a separate story. Adding
  `--tags` to the ref set is PLANNED's choice (Notes, M-6). It makes no
  difference today.
- **The reflog question.** HARNESS-012 PO-5 settled it: reflogs are not roots,
  and `--reflog` stays out.
- **Remotes not named `origin`.** Both options use `refs/remotes/origin/<default>`
  as "the default branch's upstream", because the NOTE's resolution already
  assumes `origin`. An upstream checkout whose remote has another name (for
  example `upstream`) loses only AC-2's control case there. Its local default
  branch still counts. That is a known limit, to be recorded in the script's
  comment, not handled here.
- **The HEADs of other linked worktrees of the upstream checkout.** `--all`
  includes them. A narrower set includes them only through the branch each one
  has checked out. That is correct for this story's purposes and gets no
  special handling.
- **Porting manga-translator's MT-043 changes upstream.** M-2 found four new
  LOCAL files there, and they are real local edits. That is port-before-refresh
  work and belongs to its own round.
- **The cost of the ref set.** Every candidate set is smaller than `--all`
  (M-5, the `objects=` column), and the membership test is unchanged. If PLANNED
  finds a shape that costs more, it measures the cost as HARNESS-012 did. It
  must not choose a cheaper set that answers a different question.

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

Filed 2026-09-24 as the follow-up that HARNESS-012 PO-5 recommended. **The
`## Contract` is left for PLANNED.** This section holds the evidence, so that
PLANNED can use these numbers rather than measuring again.

### Measurements, 2026-09-24, this repository at `6c2d6a7` (release 51), Git Bash on Windows 11

**M-1. What refs this clone holds.** `git for-each-ref` returns 16 local
branches under `refs/heads/harness/*` plus `main`, and 41 remote-tracking refs
plus `origin/HEAD`. There is no `refs/stash`, no `refs/pull/*`, and there are
no tags. `git ls-remote --heads origin` returns **one** head, `main`. So **40
of the 41 remote-tracking refs are stale**: their branches were deleted on
origin and never pruned here. Every ref, local or remote, is merged into
`main` (`git branch -a --no-merged main` is empty). So in THIS clone no
narrowing changes anything today. The defect is latent here and live in other
clones.

**M-2. The manga-translator baseline moved while this story was being
measured.** The brief said 13 LOCAL. That was true at manga-translator
`51f2558`, and the first dry run here reproduced it. By the next run another
session had run `git pull --ff-only` there (reflog, 2026-09-23 23:53) to
`76ed934`, "MT-043: close as DONE". MT-043 changed `scripts/mutate.sh`,
`.claude/tests/mutate.test.sh`, `.claude/harness/rules.md` and
`.claude/state/README.md`. None of those blobs exists in this repository, so
the real script now reports **17 LOCAL**, correctly. They are the other 4.
**Quote this story's numbers as "17 at `76ed934`", and never as a bare
count.** DV-1 compares two runs against each other for this reason and does not
use a fixed number.

**M-3. The sharp case, reproduced against the real script with the real
commit.** The throwaway commit from HARNESS-010's CI run is still in this
store as an unreachable commit:

    $ git fsck --unreachable --no-reflogs --no-progress | awk '$2=="commit"{print $3}'   # 13 commits
    ... one of them contains blob 632dc4e6 (manga-translator's lib.sh):
    83add19415d3d0ad7aaff9a3ca84dee3a868d612  2026-09-23 12:02:27  THROWAWAY: HARNESS-010 union-corpus cross-comparison on CI

The test used a scratch `git clone --no-hardlinks` of this repository, made in
the scratchpad, with `git update-ref refs/remotes/origin/xcompare/HARNESS-010
83add19`. That simulates a clone that fetched while the branch existed and
never pruned. Then, from `../manga-translator` at `76ed934`:

    $ bash <clone>/scripts/refresh-harness.sh --dry-run <clone> | grep -cx '    LOCAL     .*'
    13          # the real release-51 script; 17 without the stale ref

The 4 that disappear are exactly the ones HARNESS-012 brought back:
`.claude/hooks/lib.sh`, `.claude/hooks/phase-guard.sh`,
`.claude/tests/phase-guard.test.sh` and `.claude/tests/_lib.sh`.

**M-4. Tags.** `git tag` prints nothing. `VERSION` is `51 (2026-09-23)`, a
number with a date, and nothing parses it (its own header says so). **Releases
are not tagged, so "tags only" is not an option.** A release, as this
repository practises it, is a commit on `main`. The refresh script's own NOTE
already uses that definition: "not merged into '<default>'" means "not a
release".

**M-5. Each candidate ref set against real trees.** A replica of the three
walks (`scratchpad/measure.sh`: the same candidate files, the same
`hash-object`, a membership test against each set) was checked against the real
script first. Both give 17 on the real tree and 13 with the stale ref, and they
list the same files. Upstream = the scratch clone, downstream =
manga-translator `76ed934` (69 candidate files), unless stated otherwise:

| ref set | real tree | + stale `origin/xcompare` | + `refs/pull/999/head` | + `refs/stash` | + local `refs/heads/experiment` | upstream `main` behind `origin/main`* |
|---|---|---|---|---|---|---|
| `--all` (release 51) | 17 | **13** | **13** | **13** | **13** | 0 |
| `--branches` | 17 | 17 | 17 | 17 | **13** | **4** |
| `--branches --tags` | 17 | 17 | 17 | 17 | **13** | **4** |
| `--branches --remotes` | 17 | **13** | 17 | 17 | **13** | 0 |
| `HEAD` | 17 | 17 | 17 | 17 | 17 | **4** |
| `main origin/main` | 17 | 17 | 17 | 17 | 17 | 0 |
| `HEAD main origin/main` | 17 | 17 | 17 | 17 | 17 | 0 |

Each injected ref points at `83add19`. Bold marks a result that differs from
the correct answer: 17 in the injected columns, 0 in the last.

\* Last column: downstream = this checkout at release 51, and upstream = the
scratch clone with local `main` moved back to `ce2ff90` (release 50) while
`origin/main` stays at release 51. This simulates a project refreshed from a
newer clone and then checked against an older one. `--branches` alone
reports `floors.conf`, `refresh.test.sh`, `selftest.test.sh` and
`refresh-harness.sh` as LOCAL. That is **four false alarms, all in the quiet
half**, for files that are release 51 exactly. **This rules out `--branches`
alone and `--branches --tags`.** Any acceptable set must include
`origin/<default>`, and that requirement is AC-2's control.

`--branches --remotes` fixes the stash and the PR ref but not the sharp case,
so it is ruled out too.

The fixtures were cleaned up afterwards (`update-ref -d`, `main` restored to
`6c2d6a7`). None of this touched this repository or manga-translator. The
dry runs wrote only their self-copy under manga-translator's gitignored
`.claude/state/`, which the script removes.

**M-6. What remains, and the only column where the two survivors differ.**
Two sets survive: *A* = `--branches HEAD origin/<default>`, and *B* = `HEAD
<default> origin/<default>`. Both give the correct answer in every column
except the local `refs/heads/experiment` one: A reports 13 (the file stays
silent) and B reports 17 (the file is listed). No real tree measured today can
tell them apart, because every local branch here is merged into `main` (M-1).
Adding `--tags` to either set changes nothing today (M-4).

**M-7. The existing assertions whose meaning depends on the answer.**
`refresh.test.sh` lines 424-440 (HARNESS-012's AC-1 control) commit three
contents on a local branch `survives`, which is never merged. They then assert
`once a surviving ref reaches the blob, walk 1 is silent`, `and walk 2` and `and
walk 3`, and the comment at line 420 says "whether or not it is the default
one". **These three assertions pin Option A.** Under Option B they go red and
must be rewritten in RED to use a branch that is merged, or a push to
`origin/<default>`. The rewritten assertions must then be earned by a mutation,
because a corrected test written against an existing implementation passes on
its first run (`rules.md`, non-negotiables). The fixture statements `fixture: <f>
is now reachable from the surviving branch` (lines 431-434) read `rev-list
--all` directly and stay true under either option, but under B they no longer
describe the script's question. The other 76 assertions do not depend on the
answer. The upstream fixture is created with a plain `git init -q` (line 48),
so its default branch is `master` unless `init.defaultBranch` is set. Neither
this machine nor ubuntu CI sets it. The fixture therefore resolves through the
`master` candidate, and a machine configured with some other name would send
it down AC-6's no-default path. RED may pin `git init -q -b master` for that
reason.

## Open question

**Is a LOCAL branch of the upstream checkout that is not merged into its default
branch a release?** The evidence does not settle it (M-6), and the two answers
lead to different code and to different results for three existing assertions
(M-7).

* **Option A: yes, every local branch counts.** Set: `--branches HEAD
  origin/<default>`.
  *For:* the smallest change from release 51. HARNESS-012's `survives`
  assertions stay as they are. A maintainer's own local work-in-progress never
  triggers the alarm against itself.
  *Against:* the HARNESS-010 incident began as a **local** branch in this very
  clone before it was pushed. While it existed, a dry run from this checkout
  would have been silent about those four files, which is the defect HARNESS-012
  was fixing. It also conflicts with the script's own NOTE, which already says
  an unmerged branch "is not a release".
  *Measured cost:* none on any real tree today. It fails only the one column
  where a local unmerged branch holds downstream content (13 instead of 17).

* **Option B: no, only the default branch counts, plus its `origin` counterpart
  and whatever is checked out.** Set: `HEAD <default> origin/<default>`.
  *For:* one definition of "a release" across the whole script, the same one
  the NOTE uses. It closes the local-branch case as well. It is correct in every
  column of M-5.
  *Against:* a project that vendored unreleased work from an upstream feature
  branch, which the NOTE warned about, is told those files are LOCAL on the
  next refresh from `main`. That can be read as correct (it WAS unreleased) or
  as noise. It also means three of HARNESS-012's assertions must be rewritten
  and earned again (M-7).
  *Measured cost:* none on any real tree today. There is no unmerged local
  branch here, so no new false alarm on manga-translator.

Under both options `HEAD` stays in the set. The content being installed comes
from HEAD's working tree, and dropping it would make a second refresh from the
same checkout report the first refresh's files as LOCAL.

**PO recommendation: Option B**, because the script already defines a release
as "merged into the default branch", and the incident this line of work exists
for started on a local branch. It is still a product decision about what the
alarm should say to a maintainer about their own unmerged work, so it goes to
the user. **AC-5 must be rewritten to the chosen option before the story leaves
PLANNED.** Record the decision in `## Notes` as PO-1, with who made it.
