---
id: HARNESS-008
title: One phase lock per worktree, so two stories can be in flight at once
slug: one-phase-lock-per-worktree-so-two-stori
epic: 
type: chore
status: in-progress
phase: RED
branch: story/HARNESS-008-one-phase-lock-per-worktree-so-two-stori
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/doctor.sh, .claude/tests/worktree.test.sh, .claude/tests/doctor.test.sh, CLAUDE.md]  # files this story expects to write
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

No epic. The harness maintaining itself, and the story that removes the hard
constraint on parallel work.

**One checkout works one story, and the reason is one file.**
`.claude/state/current-story.env` holds a single `STORY_ID` and a single
`PHASE`. Every hook reads it - `phase-guard.sh` to decide what may be written,
`gate-reminder.sh` to decide what to nag about, `inject-state.sh` to tell the
session where it is. Two stories in one checkout means one file and two truths.

**Most of the work is already done, and this was measured rather than assumed.**
A throwaway worktree at release 45:

    git worktree add -d <tmp> HEAD
    ls <tmp>/.claude/state/     -> README.md
    ls  ./.claude/state/        -> README.md  gate-logs  last-gate-run
    git check-ignore -v .claude/state/current-story.env
      -> .gitignore:2:.claude/state/*

`.claude/state/*` is gitignored, and a git worktree has its own working
directory, so **each worktree already gets its own phase lock**. Nothing is
shared. `phase.sh set` already refuses to advance a story while the checkout is
on the wrong branch, which is exactly the one-story-per-worktree invariant this
needs. The mechanism is not missing; it has never been tried, named, or tested.

**So this story is smaller than it looks and mostly adversarial.** It is not
"build a per-worktree lock" - it is "prove the lock is per-worktree, find what
breaks when two of them are live, and fix or document that". The things most
likely to break are the ones that assume a single tree:
`refresh-harness.sh` (run per worktree, or once?), `gates.sh`'s stamp in
`.claude/state/last-gate-run`, and `doctor.sh`, which says nothing today about
which worktree it is in.

**Why it is the story that matters.** HARNESS-006 makes it possible to ask which
stories could run together. It does not make running them possible. Until this
lands, the answer to "can we work two at once" is no, regardless of how good the
planning gets.
## Acceptance criteria

- **AC-1** - Given two git worktrees of this repository, when a story is set to
  a phase in one, then `phase.sh show` in the other reports no active story and
  the first still reports its own. *Control:* setting a second story in the
  second worktree leaves the first unchanged - neither overwrites the other.
- **AC-2** - Given two worktrees each with a different story active in a
  source-freezing phase, when a write to a source path is attempted in each,
  then each is judged against ITS OWN phase. A RED worktree refuses the write; a
  GREEN worktree beside it allows it, at the same moment.
- **AC-3** - Given a worktree, when `bash scripts/gates.sh` runs in it, then the
  record it writes and the record in the other worktree are independent, and
  `check-boundaries.sh` in each judges its own tree. *Control:* a gate run in
  one worktree does not satisfy `check-boundaries.sh` in the other.
- **AC-4** - Given a worktree that is not the main checkout, when
  `bash scripts/doctor.sh` runs, then it names which worktree it is in and
  whether that worktree's harness is the same release as the main checkout's.
  Two worktrees on different releases is a state the refresh procedure can
  produce and nothing currently reports.
- **AC-5** - `bash scripts/refresh-harness.sh` run inside a worktree either
  works correctly on that worktree alone, or refuses and says why. What it must
  not do is partially update a tree it shares files with. *Control for
  whichever it turns out to be:* the other worktree's `VERSION` is unchanged
  after the run.
- **AC-6** - `CLAUDE.md` documents the worktree workflow: how to create one per
  story, that `plan.sh conflicts` should be consulted before choosing the
  second story, and that the answer is only as good as the `touches:`
  declarations it reads. *Verified by review* - see `## Deferred verifications`.
## Contract

**No new state file, and no change to `current-story.env`'s format.** The lock
is already per-worktree because `.claude/state/*` is gitignored and a worktree
has its own working directory. This story proves that and repairs what assumes
otherwise; a design that adds a registry of active stories is the wrong answer
and is out of scope.

**`scripts/doctor.sh`** gains a worktree line, printed always, in the existing
`ok`/`MISSING` style:

    ok       worktree     main checkout, harness 46
    ok       worktree     linked worktree of <path>, harness 46
    MISSING  worktree     linked worktree, harness 44 - main checkout is 46

Detected with `git rev-parse --git-common-dir` compared to `--git-dir`: they
differ in a linked worktree and match in the main one. No new dependency.

**`scripts/refresh-harness.sh`** — AMENDED IN PLACE BY RED, 2026-09-21. The
block said it "gains one refusal or one note, whichever the RED investigation
shows is correct". The investigation was done and the answer is NEITHER: refresh
already works correctly inside a linked worktree.

Measured by RED against a fixture, and reproduced independently by the
orchestrator against this real repository rather than by re-running RED's own
probe:

    git worktree add -d <tmp> HEAD
    cd <tmp> && bash scripts/refresh-harness.sh --dry-run <main checkout>
      into: <tmp>   (45)        <- the worktree, correctly, not the main checkout
      rc=0                      <- no refusal

It targets the worktree it is run in, leaves the other trees alone, and the
release-39 "not a release" note fires on source branch as normal. So this story
adds NOTHING to refresh-harness.sh, and AC-5's "works" branch is the one that
holds. AC-5 is unchanged and still falsifiable: its control - the other
worktree's `VERSION` unchanged after the run - is what the suite asserts.

Recorded rather than deleted, because "the contract asked for a change that
turned out to be unnecessary" is a finding, and a silently dropped clause reads
later like an oversight.

**`.claude/tests/worktree.test.sh`**, new, carries AC-1 through AC-5. It creates
real worktrees with `git worktree add -d` in a throwaway fixture and removes
them in a trap. It does NOT simulate a worktree by copying a directory: the
whole claim is about what git does with `.git`, and a copy would pass while
proving nothing - the release 41 rule, applied to this story's own fixtures.

**Test-only dependencies:** none. git worktree is git.

**Callers of anything whose signature changes:** none. `doctor.sh` gains
output; nothing parses it except `doctor.test.sh`, which this story updates.

## Deferred verifications

**AC-6, the documentation criterion. Owner: REVIEW.**

A `CLAUDE.md` section is not assertable without pinning its phrasing, which
goes stale the first time somebody rewrites it better. REVIEW reads it and
records here that it answers the question a person will actually have: what to
do when `plan.sh conflicts` says UNKNOWN, which - until every story carries
`touches:` - is most of the time.

**Result:** <!-- filled at REVIEW -->

**AC-2 against a REAL pair of stories. Owner: GATES.**

Release 41 requires a probe against the tree the rule judges. GATES creates two
worktrees, sets a real story from this backlog to RED in one and another to
GREEN in the other, attempts a source write in each, and pastes both outcomes.
Fixture stories would demonstrate the mechanism; this demonstrates it on the
backlog that exists.

**Result:** <!-- filled at GATES -->

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

Planned by `bash scripts/plan.sh write HARNESS-008` from `.claude/harness/models.conf`.
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

- **HARNESS-009**, the orchestrator dispatching into these worktrees. This story
  makes two locks possible; something still has to decide to use them.
- **HARNESS-007**, the planner aiming for disjoint footprints. Not a dependency:
  this works without it, you just have fewer safe pairs to choose from.
- **Checking a `touches:` declaration against the diff a story produced.** Named
  in HARNESS-006 and still not scheduled. Parallel work makes it matter more,
  because a story that strays outside its declaration now strays into somebody
  else's worktree.
- **Any shared lock, registry or lease.** If two worktrees need to coordinate
  beyond "different branches, different files", that is a design this story has
  not earned and should not invent.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

One suite, `.claude/tests/worktree.test.sh`, at the level the contract lives:
the real scripts and the real hook, driven from inside real worktrees. Run by
`bash scripts/selftest.sh worktree`; picked up by the selftest glob, which CI
runs at `gates.yml:72`. No unit level exists below this - every claim is about
what a script does with `.git`, so a test that did not shell out would be
testing a re-implementation.

**The fixture** is one main checkout (`make_project_fixture`, with the real
`.claude/state/*` ignore rule appended, two chore stories `T-A`/`T-B` and a
one-gate `project.conf` committed) plus two linked worktrees made with
`git worktree add -b story/T-A-fixture` / `-b story/T-B-fixture`, and a
second project fixture stamped `99 (2099-01-01)` as the upstream for AC-5. The
trap removes the worktrees through `git worktree remove --force` before the
directories go. Not a copied directory, per the Contract: the premise block
asserts both linked trees resolve `--git-common-dir` to the main checkout's
`.git` and `--git-dir` to somewhere else, so a `cp -r` would fail before AC-1.

**The measurement in `## Context` reproduced** on this checkout at 6764f8a
before the suite was written: a fresh `git worktree add -d` had
`.claude/state/{.gitkeep,README.md}` only (the story's bare `ls` hid the
`.gitkeep`); this checkout had `current-story.env gate-logs last-gate-run
mutations` beside them; `git check-ignore -v` gave `.gitignore:2:.claude/state/*`;
`--git-dir`/`--git-common-dir` read `.git`/`.git` in main and
`<main>/.git/worktrees/<name>`/`<main>/.git` in the linked one.

| Block | AC | What it pins | Level |
|---|---|---|---|
| premise | Context | this repo ignores `current-story.env` and `last-gate-run` and does NOT ignore `state/README.md`; the fixture worktrees share main's `.git`; a fresh linked worktree has no state file | real repo (read-only), fixture |
| AC-1 | AC-1 | `phase.sh set T-A RED` in `a`; `phase.sh show` in `b` and in main is exactly `No active story. The phase lock is off.`; `a` shows `STORY_ID=T-A`/`PHASE=RED`. Control: `set T-B GREEN` in `b` leaves `a`'s state and `a`'s story frontmatter untouched, and `b`'s copy of `T-A.md` still says PLANNED | script + files |
| AC-2 | AC-2 | the same `printf x > src/main.ts` judged by the real hook in both worktrees concurrently (`&`, `wait`): refused in `a` naming `story: T-A`, `phase: RED`, `path: src/main.ts`; allowed in `b`. Controls: a test write refused in `b` (GREEN) and allowed in `a`; the `Write` tool path both ways | hook |
| AC-3 | AC-3 | `gates.sh` in `a` (REVIEW) writes `a/.claude/state/last-gate-run` with `RESULT=pass` and a `tree:` line into `a`'s `T-A.md`; `b` and main have neither. `check-boundaries.sh <base>` in `a`: rc 0, `ok    gate record matches the working tree`. Control: `b` set to REVIEW without a gate run: rc 1, `FAIL  story T-B: ## Gate results was not written by scripts/gates.sh`, no `gate record matches` line, no mention of T-A | scripts + files |
| AC-4 | AC-4 | doctor in `a`: exactly one `  ok       worktree     linked worktree of <path>, harness 45`, no `main checkout` row, no `MISSING  worktree` row, rc 0. In main: one `  ok       worktree     main checkout, harness 45`, no `linked worktree`. `a`'s VERSION rewritten to `44 (...)`: one `  MISSING  worktree     linked worktree ... harness 44 ... main checkout is 45`, no `ok worktree` row, rc 1; main still reads its own stamp | script |
| AC-5 | AC-5 | `refresh-harness.sh <up>` from inside `a` (cleared, clean): rc 0; `a`'s VERSION is `99 (2099-01-01)`; the hook upstream ships arrives in `a`; `b`'s and main's VERSION byte-identical to before; neither got the hook. Then doctor in `a` reports `harness 99 ... main checkout is 45`, rc 1, and doctor in main is still ok | script + files |

AC-6 is not asserted (deferred verification, owner REVIEW). Every needle is
anchored at line start and counted with awk over a here-string; the two
`check-boundaries.sh` needles read the `ok    `/`FAIL  ` status column.

## Handoff: RED -> GREEN

**Run:** `bash scripts/selftest.sh worktree` (the whole selftest: `bash
scripts/selftest.sh`). About 90 s on this Windows checkout, in line with the
other script-driving suites (`refresh` 61 s, `doctor` 59 s, `gates` 273 s
here); Linux CI is much faster at process spawn. No `gates.sh` gate covers it -
see PO decision 1 in `## Notes` - so `gates.sh --fast` is run only for shape:
`All required gates passed (0 ran, 5 unconfigured, 0 known)`, rc 0, not
recorded. `scripts/check-sigpipe.sh` and `scripts/check-grep-count.sh` both
scan 39 shell files including the new suite and report 0 findings. The full
`bash scripts/selftest.sh` after the last probe: 17 suites green, `worktree:
65 passed, 8 failed`, `1 of 18 harness suite(s) FAILED` - the eight below and
nothing else.

**Files touched:** `.claude/tests/worktree.test.sh` (new), this story's
`## Test plan` and this section. Nothing else. No test dependency: worktrees
are git.

### The failure, verbatim, and why it is the right one

```
=== worktree ===

  premise: the measurement the story rests on, reproduced

  AC-1: a story set in one worktree is invisible to the other

  AC-2: each worktree's write is judged against ITS OWN phase

  AC-3: the gate record belongs to the worktree that ran the gates

  AC-4: doctor names the worktree it is in, and whether its release matches
    FAIL a linked worktree is named as one, with its release
         expected: 1
         actual:   0
    FAIL the main checkout is named as one, with its release
         expected: 1
         actual:   0
    FAIL a linked worktree behind the main checkout is MISSING, naming both releases
         expected: 1
         actual:   0
    FAIL and doctor exits 1 on the mismatch
         expected: 1
         actual:   0
    FAIL the main checkout reads its own stamp, not the linked worktree's
         expected: 1
         actual:   0

  AC-5: refresh-harness.sh inside a linked worktree works on that worktree alone
    FAIL doctor in the refreshed worktree reports the mismatch the refresh produced
         expected: 1
         actual:   0
    FAIL and exits 1
         expected: 1
         actual:   0
    FAIL doctor in the main checkout still reports its own release as ok
         expected: 1
         actual:   0

worktree: 65 passed, 8 failed

1 of 1 harness suite(s) FAILED.
```

All eight reds are one absence: `doctor.sh` prints no `worktree` row. Five are
the AC-4 block; three are AC-5's tail, which asks doctor to report the
release mismatch the refresh just produced. Nothing else is red, and that is
the story's thesis - the lock already IS per-worktree - so the 65 that pass on
arrival are each earned below by a mutation, or named as a control/fixture
guard that no production mutation can reach.

### What GREEN builds - the output shape the tests already pin

Only `scripts/doctor.sh` is under a red test. The Contract's three lines are
pinned as follows; the regexes are the assertions' own:

| Situation | Line doctor must print (once) | Exit |
|---|---|---|
| main checkout | `  ok       worktree     main checkout, harness 45` — regex `^  ok       worktree +main checkout, harness 45([^0-9]\|$)` | 0 |
| linked worktree, same release | `  ok       worktree     linked worktree of <path>, harness 45` — regex `^  ok       worktree +linked worktree of [^,]+, harness 45([^0-9]\|$)` | 0 |
| linked worktree, release differs | `  MISSING  worktree     linked worktree, harness 44 - main checkout is 45` — regex `^  MISSING  worktree +linked worktree.*harness 44([^0-9]\|$).*main checkout is 45([^0-9]\|$)`, and NO `^  ok       worktree` row | 1 (counted into `missing`) |

`45` is read from the fixture's own stamp at run time (`first_version`), so a
bump does not break it. The two releases are: the tree doctor runs in reads
**its own** `.claude/harness/VERSION`; "main checkout is N" reads the main
working tree's, which is `$(git rev-parse --git-common-dir)/..` (the Contract's
detection; `--git-dir` and `--git-common-dir` both read `.git` in main and
differ in a linked worktree - measured on this checkout). The main checkout
must not print `linked worktree` anywhere, and a matching linked worktree must
not print a `MISSING  worktree` row.

**Not constrained, GREEN's choice:** what follows the release number (`45` and
`45 (2026-09-20)` both match; `450` does not); which path `<path>` is (the
assertion only requires something non-empty with no comma before `, harness` -
Windows path spelling made pinning it brittle; the main checkout's path is what
the Contract means); whether the main checkout's row mentions that linked
worktrees exist; the exact wording after `MISSING  worktree` beyond the two
release numbers in that order. Where the row sits in doctor's output is not
constrained either, but it must be printed on every run, including the early
`project.conf has no commands` exit, or the unbootstrapped case has no row.

**`doctor.test.sh`** is named in `touches:` but this RED did not change it:
nothing in it asserts the absence of a `worktree` row, so it stays green once
the row exists. If GREEN wants the row covered there too, that is a RED
change, not a GREEN one.

**`refresh-harness.sh`**: no red test. See "AC-5: what it turned out to be".

### Every assertion, and what earns it

Probe ids refer to the table in the next section. "cascade" means the
assertion also went red under other probes because the mutation broke an
earlier step it depends on; the probe named is the one aimed at it.

| Block | Assertion | On arrival | Earned by |
|---|---|---|---|
| premise | this repository ignores `.claude/state/current-story.env` | pass | P6 |
| premise | and `.claude/state/last-gate-run` | pass | P6 |
| premise | but not the README that documents the directory | pass | P9 (after the `--no-index` correction, below) |
| premise | a/b: shares the main checkout's `.git` | pass | fixture guard - refuses a copied directory; shown outside the framework, below |
| premise | a/b: has its own git dir, so it is linked, not main | pass | fixture guard - the other half; a copy passes this one, which is why both are asserted |
| premise | git lists three worktrees | pass | fixture guard - a copy lists 1 |
| premise | a fresh linked worktree has no state file | pass | the measurement itself; goes red only if state became tracked, which check-boundaries.sh refuses |
| AC-1 | T-A goes to RED in worktree a, on its own branch, without --force | pass | P7 |
| AC-1 | and phase.sh says so | pass | P7 |
| AC-1 | phase.sh show in worktree b reports no active story | pass | P1 |
| AC-1 | and so does the main checkout | pass | P1 |
| AC-1 | worktree a still reports T-A / in RED | pass | P7 |
| AC-1 | T-B goes to GREEN in worktree b | pass | P7 |
| AC-1 | worktree a is unchanged: still T-A / still RED | pass | P1 |
| AC-1 | and never mentions T-B | pass | P1 (actual 4) |
| AC-1 | worktree b reports T-B / in GREEN | pass | P7 |
| AC-1 | the main checkout still has no state file | pass | P1 |
| AC-1 | a's story file says RED; b's story file says GREEN | pass | P7 |
| AC-1 | b's copy of the same story file does not; a's copy of that one does not | pass | control - no single production line can make phase.sh write into a SIBLING worktree; these pin that the fixture's worktrees are separate directories (a copy-free fixture would fail the premise block first) |
| AC-2 | T-M goes to RED in the main checkout | pass | P7 cascade (branch read from the wrong tree) |
| AC-2 | the RED worktree refuses the source write | pass | P1, P7 (not blocked at all) |
| AC-2 | and the refusal names T-A | pass | **P2** (named T-M instead) |
| AC-2 | and RED | pass | P1, P7 |
| AC-2 | the GREEN worktree beside it allows the same write | pass | **P2** (refused, naming T-M / RED) |
| AC-2 | the main checkout refuses it too, naming T-M | pass | P7 cascade |
| AC-2 | blocks: the GREEN worktree refuses a test write | pass | P2 (main's RED allows tests) |
| AC-2 | allows: the RED worktree allows the same test write | pass | control against a hook that denies everything; the generic lock is pinned by phase-guard.test.sh. Not reddened by any worktree probe |
| AC-2 | Write to source in RED is refused | pass | P1, P7 |
| AC-2 | Write to source in GREEN is allowed | pass | **P2** |
| AC-3 | gates.sh runs in worktree a | pass | precondition (rc of the run whose record is asserted next) |
| AC-3 | and records into a's story file | pass | P2 (no story found in the shared location) |
| AC-3 | the stamp is written in worktree a / and says pass | pass | **P3** |
| AC-3 | worktree b has no stamp | pass | control - no production line puts a's stamp into a sibling |
| AC-3 | the main checkout has no stamp | pass | **P3** |
| AC-3 | a's story file carries the tree hash | pass | **P8** |
| AC-3 | b's copy of the same story file does not | pass | control, as for AC-1's sibling copies |
| AC-3 | nor does the main checkout's | pass | **P8** |
| AC-3 | check-boundaries in a accepts the record it finds (rc 0) | pass | P2, P8 cascade (rc 1) |
| AC-3 | and says the record matches a's tree | pass | **P4** |
| AC-3 | for story T-A | pass | **P4** |
| AC-3 | check-boundaries in b refuses (rc 1) | pass | **P4** (judged main's tree: no story, rc 0) |
| AC-3 | because b has no tool-written record | pass | **P4** |
| AC-3 | and never claims a's record matches; it judged T-B, not T-A | pass | controls - pass under every probe including P4, where b judged main's tree and mentioned neither story |
| AC-4 | 5 positive assertions | **red** | GREEN |
| AC-4 | and not as the main checkout / no mismatch while releases match / and not as a linked worktree / and is not also reported ok | pass, **vacuously** - there is no worktree row yet | GREEN's job: see the controls table |
| AC-4 | and doctor exits 0 (twice) | pass | vacuous until the row exists; the mismatch case's `exits 1` is red now |
| AC-5 | the refresh completes | pass | control on rc; P5 cascade would refuse if main were dirty |
| AC-5 | worktree a is stamped with upstream's release | pass | **P5** (stayed 45) |
| AC-5 | a hook upstream ships arrives in worktree a | pass | **P5** |
| AC-5 | worktree b's VERSION is unchanged; worktree b did not receive the hook | pass | controls - sibling; no production line reaches it |
| AC-5 | the main checkout's VERSION is unchanged | pass | **P5** (became 99) |
| AC-5 | nor did the main checkout | pass | **P5** |
| AC-5 | 3 doctor assertions | **red** | GREEN |

### The probes: what was mutated, what went red

Every one through `bash scripts/mutate.sh FILE 'EXPR' -- bash scripts/selftest.sh
worktree`, sequentially, against this checkout; every restore verified
byte-for-byte by the script. The eight AC-4 lines are red in every run and are
elided from the pastes as `[... 8 AC-4 lines, red in every run ...]`. The
mutation in each case is the same idea: point one path at the shared `.git`'s
parent - the main checkout - which is what "the lock is not per-worktree"
would look like in code.

**P1 - `scripts/phase.sh`, the lock's path.** Reddens AC-1.

```
=== mutate: scripts/phase.sh (1 line(s) changed by s|^STATE="\$ROOT/\.claude/state/current-story\.env"$|STATE="$(cd "$ROOT" \&\& cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)/.claude/state/current-story.env"|) ===
  18 - STATE="$ROOT/.claude/state/current-story.env"
  18 + STATE="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)/.." && pwd)/.claude/state/current-story.env"
    FAIL phase.sh show in worktree b reports no active story
         expected: No active story. The phase lock is off.
         actual:   Active story
         ------------
           # Written by scripts/phase.sh — do not edit by hand.
           STORY_ID=T-A
           [...]
    FAIL and so does the main checkout
    FAIL worktree a is unchanged: still T-A
    FAIL still RED
    FAIL and never mentions T-B
         expected: 0
         actual:   4
    FAIL the main checkout still has no state file
         expected: no
         actual:   yes
    FAIL the RED worktree refuses the source write
         not blocked at all
    [... AC-2/AC-3 cascade, 8 AC-4 lines ...]
worktree: 50 passed, 23 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/scripts_phase.sh.20260921T202122Z.2861564.bak) ===
  18: STATE="$ROOT/.claude/state/current-story.env"
```

**P2 - `.claude/hooks/lib.sh`, the hook's state path.** Reddens AC-2 in both
directions, because the main checkout has T-M in RED: the GREEN worktree is
refused and the refusal names the wrong story.

```
=== mutate: .claude/hooks/lib.sh (1 line(s) changed by s|^STATE_FILE="\$HARNESS_ROOT/\.claude/state/current-story\.env"$|STATE_FILE="$(cd "$HARNESS_ROOT" \&\& cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)/.claude/state/current-story.env"|) ===
  12 - STATE_FILE="$HARNESS_ROOT/.claude/state/current-story.env"
  12 + STATE_FILE="$(cd "$HARNESS_ROOT" && cd "$(git rev-parse --git-common-dir)/.." && pwd)/.claude/state/current-story.env"
    FAIL and the refusal names T-A
    FAIL the GREEN worktree beside it allows the same write
         expected:
         actual:   BLOCKED by the harness phase lock.    story:    T-M   phase:    RED   path:     src/main.ts   category: source  [...]
    FAIL blocks: the GREEN worktree refuses a test write
         not blocked at all
    FAIL Write to source in GREEN is allowed
         expected:
         actual:   BLOCKED by the harness phase lock.    story:    T-M   phase:    RED   path:     src/main.ts   [...]
    FAIL and records into a's story file
    FAIL a's story file carries the tree hash
    FAIL check-boundaries in a accepts the record it finds
    FAIL and says the record matches a's tree
    [... 8 AC-4 lines, red in every run ...]
worktree: 57 passed, 16 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20260921T202352Z.2869156.bak) ===
  12: STATE_FILE="$HARNESS_ROOT/.claude/state/current-story.env"
```

**P3 - `scripts/gates.sh`, the stamp path.** Reddens AC-3's stamp half.

```
=== mutate: scripts/gates.sh (1 line(s) changed by s|^STAMP="\$ROOT/\.claude/state/last-gate-run"$|STAMP="$(cd "$ROOT" \&\& cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)/.claude/state/last-gate-run"|) ===
  45 - STAMP="$ROOT/.claude/state/last-gate-run"
  45 + STAMP="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)/.." && pwd)/.claude/state/last-gate-run"
    FAIL the stamp is written in worktree a
         expected: yes
         actual:   no
    FAIL and says pass
    FAIL the main checkout has no stamp
         expected: no
         actual:   yes
    [... 8 AC-4 lines, red in every run ...]
worktree: 62 passed, 11 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20260921T202626Z.2876425.bak) ===
  45: STAMP="$ROOT/.claude/state/last-gate-run"
```

**P4 - `scripts/check-boundaries.sh`, the tree it judges.** Reddens AC-3's
check-boundaries half, both worktrees: each judged the main checkout's tree,
where no story claims `master`, and exited 0 with nothing to say.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s|^cd "\$ROOT"$|cd "$(cd "$ROOT" \&\& cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)"|) ===
  21 - cd "$ROOT"
  21 + cd "$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)/.." && pwd)"
    FAIL and says the record matches a's tree
    FAIL for story T-A
    FAIL check-boundaries in b refuses
         expected: 1
         actual:   0
    FAIL because b has no tool-written record
    [... 8 AC-4 lines, red in every run ...]
worktree: 61 passed, 12 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20260921T202812Z.2882167.bak) ===
  21: cd "$ROOT"
```

**P5 - `scripts/refresh-harness.sh`, the tree it refreshes.** Reddens AC-5:
the refresh landed in the main checkout instead.

```
=== mutate: scripts/refresh-harness.sh (1 line(s) changed by s|^PROJ="\$(pwd)"$|PROJ="$(cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)"|) ===
  67 - PROJ="$(pwd)"
  67 + PROJ="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"
    FAIL worktree a is stamped with upstream's release
         expected: 99 (2099-01-01)
         actual:   45 (2026-09-20)
    FAIL a hook upstream ships arrives in worktree a
         expected: yes
         actual:   no
    FAIL the main checkout's VERSION is unchanged
         expected: 45 (2026-09-20)
         actual:   99 (2099-01-01)
    FAIL nor did the main checkout
         expected: no
         actual:   yes
    [... 8 AC-4 lines, red in every run ...]
worktree: 61 passed, 12 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/scripts_refresh-harness.sh.20260921T203050Z.2891448.bak) ===
  67: PROJ="$(pwd)"
```

**P6 - `.gitignore`, the ignore rule.** Reddens the premise.

```
=== mutate: .gitignore (1 line(s) changed by s|^\.claude/state/\*$|.claude/state-probe/*|) ===
  2 - .claude/state/*
  2 + .claude/state-probe/*
    FAIL this repository ignores .claude/state/current-story.env
         expected: 0
         actual:   1
    FAIL and .claude/state/last-gate-run
         expected: 0
         actual:   1
    [... 8 AC-4 lines, red in every run ...]
worktree: 63 passed, 10 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/.gitignore.20260921T203357Z.2902464.bak) ===
  2: .claude/state/*
```

**P7 - `scripts/phase.sh`, which tree's branch the transition guard reads.**
Reddens "set works in a worktree without --force" and everything downstream.

```
=== mutate: scripts/phase.sh (1 line(s) changed by s#^  cur="\$(git -C "\$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"$#  cur="$(git -C "$(cd "$ROOT" \&\& cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"#) ===
  95 -   cur="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  95 +   cur="$(git -C "$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)/.." && pwd)" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
    FAIL T-A goes to RED in worktree a, on its own branch, without --force
         expected: 0
         actual:   1
    FAIL and phase.sh says so
    FAIL worktree a still reports T-A
    FAIL in RED
    FAIL T-B goes to GREEN in worktree b
    FAIL a's story file says RED
         expected: RED
         actual:   PLANNED
    FAIL b's story file says GREEN
         expected: GREEN
         actual:   PLANNED
    [... AC-2/AC-3 cascade, 8 AC-4 lines ...]
worktree: 43 passed, 30 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/scripts_phase.sh.20260921T203713Z.2912400.bak) ===
  95:   cur="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
```

**P8 - `scripts/gates.sh`, which tree's story file receives the record.**
Reddens the story-file half of AC-3.

```
=== mutate: scripts/gates.sh (1 line(s) changed by s|^STORY_FILE="\$ROOT/docs/backlog/stories/\$STORY\.md"$|STORY_FILE="$(cd "$ROOT" \&\& cd "$(git rev-parse --git-common-dir)/.." \&\& pwd)/docs/backlog/stories/$STORY.md"|) ===
  221 - STORY_FILE="$ROOT/docs/backlog/stories/$STORY.md"
  221 + STORY_FILE="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)/.." && pwd)/docs/backlog/stories/$STORY.md"
    FAIL a's story file carries the tree hash
         expected: 1
         actual:   0
    FAIL nor does the main checkout's
         expected: 0
         actual:   1
    FAIL check-boundaries in a accepts the record it finds
    FAIL and says the record matches a's tree
    [... 8 AC-4 lines, red in every run ...]
worktree: 61 passed, 12 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20260921T203833Z.2915558.bak) ===
  221: STORY_FILE="$ROOT/docs/backlog/stories/$STORY.md"
```

**P9 - `.gitignore`, the README negation.** The control for P6. Its first run
did NOT go red: `git check-ignore` never reports a tracked file as ignored, so
the control was satisfied by the README being tracked, not by the rule. The
three premise calls were corrected to `--no-index` (the rules, not the index;
identical answers for the two untracked state files) and P6 and P9 re-run
against the corrected file:

```
=== mutate: .gitignore (1 line(s) changed by s|^\.claude/state/\*$|.claude/state-probe/*|) ===
  2 - .claude/state/*
  2 + .claude/state-probe/*
    FAIL this repository ignores .claude/state/current-story.env
         expected: 0
         actual:   1
    FAIL and .claude/state/last-gate-run
         expected: 0
         actual:   1
    [... 8 AC-4 lines, red in every run ...]
worktree: 63 passed, 10 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/.gitignore.20260921T204559Z.2937094.bak) ===
  2: .claude/state/*

=== mutate: .gitignore (1 line(s) changed by s|^!\.claude/state/README\.md$|# probe: negation removed|) ===
  4 - !.claude/state/README.md
  4 + # probe: negation removed
    FAIL but not the README that documents the directory
         expected: 1
         actual:   0
    [... 8 AC-4 lines, red in every run ...]
worktree: 64 passed, 9 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /c/Users/ryanc/Projects/agentic-dev-harness/.claude/state/mutations/.gitignore.20260921T204835Z.2944925.bak) ===
  4: !.claude/state/README.md
```

The final baseline of the corrected file is the block pasted at the top of
this section (65 passed, 8 failed), re-run after the edit.

**Probes P1-P5, P7 and P8 were run against the suite before that `--no-index`
edit.** The edit touched only the three `check-ignore` lines in the premise
block; no assertion those probes redden reads them.

### A copied directory fails the premise block

Run outside the framework (the same two `rev-parse` questions, against
`cp -r` of a fixture), so that the fixture guards are not merely asserted:

```
main .git:          /tmp/tmp.OPtk8sbQ03/.git
copy --git-common:  /tmp/tmp.S5WR1nVOTt/a/.git
copy --git-dir:     /tmp/tmp.S5WR1nVOTt/a/.git
shares the main checkout's .git: WOULD FAIL (expected: /tmp/tmp.OPtk8sbQ03/.git, actual: /tmp/tmp.S5WR1nVOTt/a/.git)
has its own git dir (copy): would pass - which is why BOTH halves are asserted
worktree list lines: 1
```

### Negative controls: expected values

No threshold in this suite - every criterion is mechanical - so the controls
are counts that must read 0, and they are the ones that cannot be earned in
RED because the row they guard does not exist yet. Their value is 0 today
**vacuously**. GREEN confirms each against the shipped doctor by mutating it
and watching the control alone go red:

| Control (AC-4) | Expected | Measured in RED | Meaning once the row exists | GREEN's probe |
|---|---|---|---|---|
| linked worktree: `^  ok       worktree +main checkout` count | 0 | 0 (no row at all) | detection is not inverted | swap the `--git-dir`/`--git-common-dir` comparison; both "not as" controls must go red |
| main checkout: lines containing `linked worktree` | 0 | 0 (vacuous) | same, other direction | same probe |
| linked worktree, same release: `^  MISSING  worktree` count | 0 | 0 (vacuous) | the mismatch row is conditional | make the MISSING row unconditional; this control and both `exits 0` must go red |
| mismatch: `^  ok       worktree` count | 0 | 0 (vacuous) | ok and MISSING are exclusive | print both rows on mismatch; must go red |
| `and doctor exits 0` (linked, same release; main) | 0 | 0 (vacuous: nothing is counted into `missing`) | the row does not count into `missing` when it is ok | count the ok row into `missing`; must go red |

### AC-5: what it turned out to be, and the one thing GREEN should not do

`refresh-harness.sh` run inside a linked worktree **works on that worktree
alone** - measured, not assumed: its tree is `$(pwd)`, every path it writes is
under it, and its git calls (`status`, `hash-object`, `cat-file -e` on
upstream) share nothing between worktrees. So the outcome pinned is "works":
rc 0, that worktree stamped, the hook delivered, the other worktree's and the
main checkout's `VERSION` byte-identical. P5 shows the assertions discriminate.

**Consequence for the Contract.** It says refresh "gains one refusal or one
note, whichever the RED investigation shows is correct". The investigation
shows it works, and AC-5's "works" branch requires nothing be printed. **There
is therefore no failing test behind a note**, and a refusal would turn this
suite red (`the refresh completes` expects 0). If the orchestrator wants a
note ("this is a linked worktree; the main checkout at X stays on release N"),
that is a sentence the AC does not require and a test does not demand - say
so, and it comes back to RED for one assertion. Left as GREEN's choice
otherwise: the suite does not constrain refresh's output at all. The mismatch
the refresh leaves behind IS reported, by AC-4's row, which is the mechanism
the story asked for.

One thing seen and not pinned: on this machine the refresh always prints
`upstream ships a different refresh-harness.sh; running that one`, because
`autocrlf` checks the worktree out CRLF while the upstream fixture's copy is
LF, so `cmp` differs. Harmless, Windows-only, and not a worktree property.

### Discoveries

- **The Context measurement reproduced** (see `## Test plan`), with one
  detail: a fresh linked worktree's `.claude/state/` holds `.gitkeep` as well
  as `README.md`; the story's `ls` without `-A` hid it. Nothing turns on it.
- **`git check-ignore` and tracked files** - above. A control that names a
  rule must ask the rule (`--no-index`); the default asks the index, and a
  tracked file is never "ignored" whatever the rules say. Worth knowing for any
  future guard over `.gitignore`.
- **Three trees, not two, in AC-2.** The main checkout carries a third story
  (T-M, RED) during that block because a hook reading a shared location finds
  no state at all when main is idle - and "allows everything" satisfies the
  allow-half of AC-2. With main in RED the shared-read mutation refuses in
  GREEN and names T-M, which is the failure the criterion is about.
- **`.claude/state/mutations/` held four `scripts_plan.sh.*.bak/.new` files
  from 00:16 today before this RED started.** Not mine; my nine probes cleaned
  up after themselves (`ls` after the chain shows only those four and `log`).
  rules.md says a leftover `.bak` means a restore failed and exited 90 - that
  session's story should say what happened.
- **No timeout to budget**: `selftest.sh` has none, and CI runs it directly.
  The suite is process-spawn bound (six `doctor` runs, two `check-boundaries`,
  three `phase.sh show` on an active story at ~8 s each here).

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

Filed 2026-09-21, with HARNESS-009, after the user asked what HARNESS-006
actually enables. The honest answer was: nothing yet. 006 is the declaration,
007 is the planning, and THIS is the one that removes the constraint.

**`depends_on: []` deliberately.** 006 and 007 make parallel work sensible;
neither makes it possible, and neither is mechanically required to start this.
Pulling this forward is the fastest route to running two stories at once, and
the cost of doing it first is only that you pick the second story by hand
instead of being told which are safe.

**The measurement this story rests on** is in `## Context` and was taken before
the story was written rather than assumed from how worktrees are supposed to
behave. If RED finds it wrong, that is the story failing early and cheaply,
which is the point of taking it.

**PO decision 1, taken at PLANNED→RED: no `project.conf` gate covers this
story's artifact, and that is structural rather than a gap.**

`bash scripts/gates.sh --list` at release 45 reports every gate
`<unconfigured>`, because this repository is the harness template and
`BOOTSTRAPPED=no`. `gates.sh` judges a PROJECT; this repository has none.

The artifact is still verified, and by a required path: `.claude/tests/` is run
by `scripts/selftest.sh`, which CI invokes as its own workflow step
(`gates.yml:72`), and `selftest.sh` globs `.claude/tests/*.test.sh` - so
`worktree.test.sh` is picked up with no wiring. A broken suite fails CI.

So `required_gates` stays empty, and the admissibility question the advance
procedure asks of `gates.sh --fast` is answered by `bash scripts/selftest.sh`
here instead. Recorded because it applies to every story in this repository,
not just this one, and because "no gate covers it" would otherwise read as a
reason the story is not ready.
