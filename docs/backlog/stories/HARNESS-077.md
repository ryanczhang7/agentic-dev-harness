---
id: HARNESS-077
title: selftest-needed answers run when its library or classifier fails
slug: selftest-needed-answers-run-when-its-lib
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-077-selftest-needed-answers-run-when-its-lib
depends_on: [HARNESS-075]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest-needed.sh, .claude/tests/selftest-needed.test.sh, .claude/commands/advance-story.md, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, docs/backlog/stories/HARNESS-075.md] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

HARNESS-075 added `scripts/selftest-needed.sh`, which step 2 of GATES → REVIEW
asks before spending the full harness self-test: `run` (exit 0) when the
story's diff touches a `harness` path, `skip` (exit 1) when it does not, and
`run` whenever the diff cannot be computed (HARNESS-075, PO decision 3: the
cost of a wrong `run` is minutes, the cost of a wrong `skip` is a red CI the
story could have seen locally). Its second diff review (HARNESS-075,
`## Diff review`, "Second review") shipped with five findings left for a
follow-up, and the PO disposition there says that story carries RED cases for
1, 2 and 3 and records 4 and 5. This is that story. Read before starting:
HARNESS-075's `## Contract`, both reviews with their dispositions,
`## Regressions` (Return 1, the shape of a wrong-way skip and its RED case),
and the last `## Notes` entries.

The three defects, each a wrong-way `skip` or a silent exit that reads as one,
against today's `scripts/selftest-needed.sh`:

1. **A `lib.sh` that trips `set -u` at load time exits the script silently,
   rc=1** (line 54). `{ [ -f "$LIB" ] && . "$LIB"; } 2>/dev/null || fallback`
   never reaches `fallback`: under `set -u` an unbound variable in a sourced
   file is a fatal shell error, which exits the *whole* script rather than the
   compound command, and the `2>/dev/null` hides the only message. The caller
   sees empty stdout, empty stderr and exit 1, which is the `skip` exit.
   Reproduced here: `printf 'x=1\necho "$NOPE_UNSET"\n' > f; set -uo pipefail;
   { [ -f f ] && . f; } 2>/dev/null || echo fallback; echo reached` prints
   nothing; the same with `( . f ) >/dev/null || echo fallback; echo reached`
   prints `NOPE_UNSET: unbound variable`, `fallback`, `reached`.
2. **The committed side of `core.quotePath=false` has no test** (line 71).
   The non-ASCII case of Return 1 is untracked only, so it exercises the
   `ls-files` line; the flag on the `git diff` line is reached by no
   assertion, and removing it leaves the suite green while a committed
   `project-café.test.sh` answers `skip`. No code defect; a test gap, which a
   mutation earns (DV-2).
3. **A failure inside the classify step still answers `skip`** (line 78).
   `harness="$(... | classify_stdin | awk ...)"` checks no exit status, so a
   pipeline that exits non-zero leaves `harness` empty and the script says
   `skip`. And a missing `.claude/harness/paths.conf` is not even a failure:
   `classify_stdin` reads the rules with `getline`, which returns -1 on a
   missing file, the loop ends with zero rules, awk exits 0, and every path
   classifies `source`. Checked on this host:
   `awk 'BEGIN{while((getline l < "/nonexistent")>0) n++; print n+0}'`
   prints `0`, rc 0.

**PO decision 1 - a missing `paths.conf` gets its own check; `|| fallback`
on the pipeline is a separate, second fix, and each has its own RED case.**
The reviewer suggested `|| fallback` and reached it with a fake `awk` on
PATH exiting 2 and with `paths.conf` missing. Those are two different
failures: the second one does not fail (above), so `|| fallback` cannot see
it, and it is the one reachable without a contrived PATH - a consumer whose
tree lost the file, or a fixture built without it. So AC-3 has two halves.
The `paths.conf` half is the primary case: RED removes the fixture's
`.claude/harness/paths.conf` and expects `run`. The pipeline half keeps the
`|| fallback` the reviewer asked for, and its RED case is the fake `awk`,
because a non-zero exit from that pipeline has no other reachable cause; the
contrivance is named in the case and confined to the one invocation
(`PATH="$fake:$PATH" bash "$SN"`). Both are red against today's script
(`skip`, exit 1) for the right reason, so neither needs a mutation to earn it.

**PO decision 2 - the probe-load.** The reviewer's
`( . "$LIB" ) >/dev/null 2>&1 || fallback` is taken in shape, not in its
redirections: the probe's stdout is discarded, its stderr is **kept**, so the
load error is no longer hidden (the request's second half of item 1). The
real source follows, unredirected. Checkable, not binding: GREEN may do it
another way as long as AC-1 holds.

**PO decision 3 - item 4 is recorded, not fixed.** Names containing `"`, `\`
or a tab are still C-quoted by git despite `core.quotePath=false` (only `-z`
removes that), classify `source`, and can be created on POSIX hosts only.
Known, in the script's header and beside HARNESS-075's `gates.sh:991-992`
note; `-z` is the eventual fix (Out of scope).

**PO decision 4 - item 5 is docs only, no new needle.** Step 2's
parenthetical lists three fallback causes and the script now has eight
(`cannot locate the harness`, `not a git checkout` x3, `no origin/main or
main`, `no merge base`, `git diff ... failed`, `git ls-files failed`, and
this story adds three). A prose list of examples is not a rule to pin;
`procedure.test.sh` keeps pinning what it pins (checked against the real
file, see `## Contract`), and the real-tree assertion staying green is the
check.

**In this repository nothing changes in practice**: `lib.sh` loads clean,
`paths.conf` exists, `awk` is real. The fixes are for the consuming tree
where one of them is not true, and where today the answer is a silent `skip`.

The required gate that fails if this story's artifact breaks: the harness
self-test (`selftest-needed` and `procedure` suites), run by CI on every PR.

## Acceptance criteria

- **AC-1** — Given a checkout whose `.claude/hooks/lib.sh` trips `set -u`
  when sourced (a line reading an unset variable inserted as its line 2),
  when `bash scripts/selftest-needed.sh` runs with a harness change on the
  branch, then it exits 0, its single stdout line begins
  `selftest-needed: run — cannot compute the diff: ` and ends
  `; defaulting to run`, and stderr is non-empty and names the unbound
  variable. *Today:* empty stdout, empty stderr, exit 1.
- **AC-2** — Given a branch whose only change is a **committed**
  `.claude/tests/project-café.test.sh` (UTF-8 name), when it runs, then it
  exits 0 and its line is exactly
  `selftest-needed: run — 1 harness path(s) changed against main (merge-base <short>): .claude/tests/project-café.test.sh`,
  unquoted, with nothing on stderr - the committed twin of HARNESS-075's
  untracked case. *Control (DV-2):* with `-c core.quotePath=false` removed
  from the `git diff` line only, this case goes red and the untracked case
  stays green, which is the gap it closes.
- **AC-3** — Given a checkout where the changed paths cannot be classified -
  (a) `.claude/harness/paths.conf` is missing from the harness the script
  belongs to, or (b) the classify pipeline exits non-zero (a fake `awk` first
  on PATH for that one invocation, exiting 2) - when it runs with a harness
  change on the branch, then in each case it exits 0 and its single stdout
  line begins `selftest-needed: run — cannot compute the diff: ` and ends
  `; defaulting to run`. *Today:* both answer `skip`, exit 1, (a) with the
  path counted and misfiled as `source`, (b) with `0 changed path(s)`.
- **AC-4** — Given `scripts/selftest-needed.sh` after this story, when its
  header comment is read, then it states that names containing `"`, `\` or a
  tab are still C-quoted despite `core.quotePath=false` and classify
  `source` (POSIX hosts only; `-z` would fix it); and HARNESS-075's
  `## Notes` carries one line saying the same beside its `gates.sh:991-992`
  note. Checked by reading, not by a suite (prose in a comment and a closed
  story).
- **AC-5** — Given `.claude/commands/advance-story.md` after this story, when
  step 2 of GATES → REVIEW is read, then its parenthetical no longer lists
  the fallback causes as a closed set of three but as examples (of the form
  "for example no base to compare against, or git failing"), the step still
  says the script says why and answers `run`, and `bash scripts/selftest.sh
  procedure` passes with its real-tree assertion green - every needle it pins
  (`` `bash scripts/selftest-needed.sh` `` before
  `` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` in the same step; the words
  `detached`, `Windows`, `## Notes`, `other test runs`, `skip`; the
  diff-review step before it, the phase change after it; both
  `allowed-tools` entries) still holds.

## Contract

**Writes:** `scripts/selftest-needed.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/commands/advance-story.md`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `docs/backlog/stories/HARNESS-075.md`

**Oracle partition.** Everything here is *mechanical*: pin the exit status,
the token after `selftest-needed: `, and the pieces of the line each AC
names, exactly; where the fixture makes the whole line deterministic (AC-2),
`assert_eq` on the whole line. AC-4 and AC-5 are read, with AC-5's half that
a suite can see (the needles) already pinned by `procedure.test.sh`. Nothing
is a measurement; there is nothing to calibrate.

**RED may amend any block below in place, with a reason, and GREEN builds
what the amended block says.** The acceptance criteria are frozen; this
section is not.

**`scripts/selftest-needed.sh` (changed).** Same interface as HARNESS-075's
Contract: `[base-ref]`, exit 0 `run` / 1 `skip` / 2 usage, one stdout line,
stderr empty on the run/skip paths, and the pinned fail-toward-run shape

    selftest-needed: run — cannot compute the diff: <reason>; defaulting to run

is kept byte for byte for every new reason. Changes, in file order:

- *Header comment.* The "Deliberate differences" paragraph gains two
  sentences: the `lib.sh` probe (a library that will not load answers `run`
  and its error reaches stderr), and the known limit - names containing `"`,
  `\` or a tab are still C-quoted by git despite `core.quotePath=false` and
  classify `source`; POSIX hosts only (Windows cannot create them); `-z` is
  the fix if it is ever needed.
- *Loading `lib.sh` (today line 54).* Replace the guarded direct source with
  a probe in a subshell and then the real source:

      [ -f "$LIB" ] || fallback "cannot load $LIB"
      ( . "$LIB" ) >/dev/null || fallback "cannot load $LIB"
      . "$LIB"

  Semantics: the probe's stdout is discarded, its **stderr is not** - that is
  what makes the load error visible (AC-1's stderr assertion); a `set -u`
  trip, a syntax error, an `exit`/`return` non-zero in the file all end the
  subshell non-zero and reach `fallback`. The real source runs only after
  the probe passed, so it cannot end the script. The `declare -F
  classify_stdin` check after it stays. Reason text `cannot load <LIB>` is
  today's and stays; the suite pins prefix and suffix, not the path.
- *`paths.conf` (new, after the `lib.sh` load, before any git work).* The
  script knows where the rules live the way `lib.sh` does
  (`$HARNESS_DIR/paths.conf`, `HARNESS_DIR=$HARNESS_ROOT/.claude/harness`,
  which the exported `CLAUDE_PROJECT_DIR=$SELF_ROOT` fixes to the harness the
  script belongs to):

      [ -r "${HARNESS_DIR:-$SELF_ROOT/.claude/harness}/paths.conf" ] \
        || fallback "cannot classify the changed paths: no $SELF_ROOT/.claude/harness/paths.conf"

  (GREEN picks the exact variable after reading `lib.sh:22`; the point is
  that it is the file `classify_stdin` would read.) Semantics: without the
  rules every path is `source`, so a `skip` from that state is a wrong-way
  `skip` by construction; the script must not reach the decision line.
- *The classify pipeline (today line 78).*

      harness="$(printf '%s\n' "$changed" | classify_stdin | awk -F'\t' '$1 == "harness" { print $2 }')" \
        || fallback "cannot classify the changed paths: classify_stdin failed"

  Under `set -o pipefail` the assignment's status is the pipeline's, so a
  non-zero `awk` (either one) reaches `fallback`. The earlier
  `awk 'length' | sort -u` and `awk 'END { print NR }'` lines are not
  guarded in this story: with a broken `awk` the script falls through to the
  guarded line with `changed` empty and still answers `run` there, which is
  what AC-3(b) observes; a guard on them is a GREEN choice, not a
  requirement.
- *Nothing else moves.* `SELF_ROOT` before the `cd`, `--no-renames`,
  `core.quotePath=false` on both listings, the exit checks on `git diff` and
  `git ls-files`, the list shape, the `+N more`: as HARNESS-075 left them.
  The `"harness"` literal still occurs exactly once (DV-1 of HARNESS-075 and
  `/audit-mutations` rely on that).

**`.claude/tests/selftest-needed.test.sh` (changed, additions only).** A new
block before `summary`, in the Return 1 style (`new_fixture`, `story_branch`,
`put`, `commit_all`, `expect` or the `run_sn` loop with `GF_PRE`/`GF_SUF`):

- *AC-1.* `new_fixture; story_branch; put scripts/x.sh; commit_all`, then
  insert a line reading an unset variable as line 2 of
  `$d/.claude/hooks/lib.sh` (`sed -i '2i echo "$NOPE_UNSET"'` on the
  **fixture's** copy, which is test data, not source; or rewrite the file
  with `awk`/`printf` - the fixture is `touches:`-free scratch). Precondition
  asserted: sourcing the fixture's `lib.sh` under `set -u` in a subshell
  fails. Then, root and `src/`: exit 0; first line begins `GF_PRE` and ends
  `GF_SUF`; one stdout line; stderr non-empty and containing `NOPE_UNSET`
  (bash prints `<file>: line 2: NOPE_UNSET: unbound variable`; pin the
  variable name, not the whole message). Today: exit 1, no stdout, no stderr
  - the silent exit this story exists to remove.
- *AC-2.* `new_fixture; story_branch; put "$CAFE" 'true'; commit_all "café"`,
  precondition `[ -f "$d/$CAFE" ]`, then `expect ... 0 "selftest-needed: run
  $D 1 harness path(s) changed against main (merge-base $(short main)):
  $CAFE" yes`. Same `CAFE` constant as the untracked case. Passes on arrival
  (the flag is already on the `git diff` line); earned by DV-2's mutation
  rather than watched red in RED - say so in the handoff, with the expected
  red count.
- *AC-3(a).* `new_fixture; story_branch; put scripts/x.sh; commit_all; rm
  "$d/.claude/harness/paths.conf"`. Precondition asserted: the file is gone
  and `bash "$d/scripts/classify.sh" scripts/x.sh` now says `source` (the
  misfile that makes today's `skip` wrong). Root and `src/`: exit 0, `GF_PRE`
  prefix, `GF_SUF` suffix, one line. Stderr not asserted.
- *AC-3(b).* `new_fixture; story_branch; put scripts/x.sh; commit_all`; a
  directory `$WORK/fakebin` holding an executable `awk` that is `#!/usr/bin/env
  bash` + `exit 2`; the script run as `PATH="$WORK/fakebin:$PATH" bash "$SN"`
  from root and `src/` (extend `run_sn` with an optional PATH prefix, or
  inline the loop). Precondition asserted: `PATH=... awk 'BEGIN{}'` exits 2.
  Exit 0, `GF_PRE`, `GF_SUF`, one line. Stderr not asserted, and the reason
  text is not either: if the fake `awk` already fails `lib.sh`'s probe-load,
  the answer is `cannot load`, and if it reaches the classify line it is
  `classify_stdin failed` - both are `run` in the pinned shape, and today's
  script answers `skip` from the same fixture, so the case is red for the
  right reason either way. RED says in the handoff which reason it saw.
- *Floor.* RED records the executed count it measures in `floors.conf`
  (`selftest-needed | 174 -> N`, with a history line in the file's footer as
  the HARNESS-075 entries are written) and in `selftest.test.sh`'s C-3
  COUNTS row, in the RED commit. Every new assertion is unconditional so the
  count is the same red and green.

**`.claude/commands/advance-story.md`, step 2 of GATES → REVIEW (changed,
one parenthetical).** Today:

    When it cannot compute the diff (no `origin/main` or `main`, no
    merge base, not a git checkout) it says why and answers `run`.

After:

    When it cannot compute the diff (for example no base to compare
    against, no merge base, git failing, or its own library or `paths.conf`
    not loading) it says why and answers `run`.

Still one numbered step with three-space continuation lines; nothing else in
the step changes. Needles `procedure.test.sh` pins, checked against the real
file on 2026-10-27 (`procedure.test.sh:52-77, 391, 1139-1145`): `STEP_NEEDED`
`` `bash scripts/selftest-needed.sh` `` before `STEP_SELFTEST`
`` `SELFTEST_JOBS=4 bash scripts/selftest.sh` `` in the first step holding
the latter; `STEP_WORDS` `detached`, `Windows`, `## Notes`, `other test runs`,
`skip` in that step; `STEP_REVIEW` `the `diff-review` skill` in an earlier
step; `STEP_PHASE` `` `bash scripts/phase.sh set $1 REVIEW` `` and
`STEP_BOUNDARIES` after; `TOOL_SELFTEST`, `TOOL_CILOCAL`, `TOOL_NEEDED` in
`allowed-tools`; `PARA_START` `**GATES → REVIEW.**`. None of them is inside
the parenthetical. `complete-story.md`'s bullet does not enumerate causes
and is not touched. No new needle (PO decision 4); the `procedure` suite's
real-tree assertion is AC-5's check, and GREEN pastes `procedure: 118
passed, 0 failed` into `## Notes`.

**`docs/backlog/stories/HARNESS-075.md`, `## Notes` (one line added).**
Directly after the entry beginning "**Known, not fixed here (2026-10-26,
from `## Diff review` finding 4).**": a sibling entry, "**Known, not fixed
(HARNESS-077, from the second review's finding 4).** Names containing `"`,
`\` or a tab are still C-quoted by `git diff --name-only` and `git ls-files`
despite `core.quotePath=false`, so `selftest-needed.sh` and
`gates.sh:991-992` both classify them `source`; POSIX hosts only (Windows
cannot create them). `-z` output is the fix when either is taken up." Written
by GREEN (docs are writable in every phase); HARNESS-075 is DONE and its
criteria are not touched.

**Callers.** No export changes signature. `lib.sh` is read, not edited
(`classify_stdin` and `HARNESS_DIR` as they are). `gates.sh` untouched.
`complete-story.md` and `CLAUDE.md` untouched. `ci-local.sh` untouched.

**Test-only dependencies.** None; bash, awk, coreutils, git.

## Deferred verifications

**DV-1 (defect put back; the story's central claim; AC-1). Owner: GATES.**
On the story branch, with GREEN's script in the tree, put back the direct
guarded source that HARNESS-075 shipped - the probe removed, the `2>/dev/null`
restored - with one `mutate.sh` expression named against GREEN's lines (for
the Contract's shape, something like
`bash scripts/mutate.sh scripts/selftest-needed.sh 's/^( \. "\$LIB" ) >\/dev\/null || fallback/{ . "$LIB"; } 2>\/dev\/null \&\& true || fallback/' -- bash scripts/selftest.sh selftest-needed`;
GATES writes the expression it actually ran and shows the changed line). The
AC-1 case **must** go red on its `exits 0`, first-line and stderr assertions
in both runs (predicted: up to 8 red, 2 runs x 4; the one-line assertion may
stay green, since empty stdout is 0 lines and will not), and every other case
- AC-2, AC-3(a), AC-3(b), all 174 of HARNESS-075 - **must** stay green. Paste
the red lines, `mutate.sh`'s restore lines, and a green run after the restore.
RED cannot run this: in RED the fix does not exist, and the case is red
against the shipped file for the defect itself, which is the ordinary RED
evidence and is recorded in the handoff instead.

**DV-2 (earning AC-2's test, which passes on arrival). Owner: GATES.**
`bash scripts/mutate.sh scripts/selftest-needed.sh '/diff --no-renames/s/ -c core.quotePath=false//' -- bash scripts/selftest.sh selftest-needed`
removes the flag from the `git diff` line only (the `ls-files` line keeps
it). The committed-café case **must** go red (its `exits 0` and whole-line
assertions, both runs: 4 red, with `actual:` a `skip` line counting 1 changed
path) and the untracked-café case **must** stay green - that pair is the
finding: before this story the mutation left the suite green. Everything else
stays green. Paste the red lines, the mutant line `mutate.sh` prints, its
restore lines, and the suite green after the restore. On this Windows host the
UTF-8 name survives the commit (HARNESS-075 Return 1 checked the untracked
side with `od -c`); if the committed side does not, say so with the `od`
output and the case is wrong, not the mutation. Not owned by RED: the test
passes on arrival there and the mutation is the only thing that earns it.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-077` from `.claude/harness/models.conf`.
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

- PLANNED — `lead-po` — resolved: **fable** (Fable 5.1, `claude-fable-5-1`,
  the agent's own `model:`; dispatched by a lead-po session running
  `/plan-story`, no model override visible to this dispatch). Verdict on the
  plan: n/a - no row departs from `models.conf`.

## Out of scope

- Fixing the quoting of `"`, `\` and tab in names (`-z` output on both
  listings, NUL-split, and the same in `gates.sh:991-992`'s `covers` check).
  Recorded as known here (AC-4); the eventual fix is `-z`, in its own story,
  and it will move `gates.sh` line numbers `sigpipe.test.sh` pins.
- A `project.conf` key to widen or narrow the trigger (HARNESS-075's Out of
  scope, unchanged).
- Guarding every `awk` call in the script (`awk 'length'`, `awk 'END'`, the
  list formatter) individually; AC-3(b) is satisfied by the classify line's
  guard and GREEN may add more, but no test asks for them.
- A new `procedure.test.sh` needle for step 2's wording (PO decision 4).
- `complete-story.md`, `CLAUDE.md`, `ci-local.sh`, `lib.sh`, `classify.sh`.
- A control for a `lib.sh` that is *absent* (already `cannot load`, green
  today) or that defines no `classify_stdin` (already `defines no`): both
  pass on arrival and would owe a mutation each; left to `/audit-mutations`.

## Design notes

<!-- Omit for non-UI stories. -->

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
     evidence line. Omit the section entirely otherwise. -->

## Scaffold inventory

<!-- REQUIRED for a bootstrap or chore story that writes production code under
     SCAFFOLD. Omit otherwise. -->

## Notes

- Planned 2026-10-27 from the request "close `scripts/selftest-needed.sh`'s
  remaining wrong-way skips", the five findings HARNESS-075's second diff
  review left open. Type `fix`, not `chore`: items 1 and 3 are bugs and AC-1
  and AC-3 reproduce them against today's script. `depends_on: [HARNESS-075]`
  (DONE, merged as #162): this story edits the script, the suite and the step
  text 075 wrote.
- **Checked before cutting (2026-10-27).** `lib.sh:22`
  `HARNESS_DIR="$HARNESS_ROOT/.claude/harness"`; `classify_stdin` at
  `lib.sh:1257` reads `$HARNESS_DIR/paths.conf` with `getline`, which on a
  missing file returns -1 and exits 0 with zero rules (reproduced, Context).
  `make_fixture` (`_lib.sh:95`) copies `paths.conf` into every fixture, so
  AC-3(a) is one `rm`. The `set -u` silent exit reproduced in a bare shell
  (Context). `procedure.test.sh`'s needle constants are lines 52-77 and the
  AC-4 fault lines 1139-1145; none reads the parenthetical. HARNESS-077 was
  free (no story file, no local or remote branch) when the file was created.
- **Conflicts.** `touches:` shares `.claude/tests/floors.conf` and
  `.claude/tests/selftest.test.sh` with HARNESS-076 (PLANNED, one floor row
  each). Not a dependency - a collision: whichever starts second merges a
  one-line floor. `bash scripts/plan.sh conflicts` output is in the planning
  report; with HARNESS-075 DONE the two are the startable pair.
- **One cycle.** Three one-line guards in one script, four fixture cases in
  one suite, one parenthetical, two notes. The ACs do not join two
  behaviours: every one is "a failure to classify answers `run`", seen from
  a different failure. Not split.
