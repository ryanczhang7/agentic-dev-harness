---
id: HARNESS-018
title: Closing a story names what to run next, and what can run alongside it
slug: closing-a-story-names-what-to-run-next-a
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-018-closing-a-story-names-what-to-run-next-a
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/plan.sh, scripts/phase.sh, .claude/tests/plan.test.sh, .claude/tests/phase.test.sh, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/lead-po.md, CLAUDE.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Asked for by the user on 2026-10-01: every time a story is finished, the agent
should say which story or stories to run next, whether to run each with
`/advance-story` or `/complete-story`, whether more than one can start, and how
to run several at once.

None of that is mechanical today. `/advance-story` says only "report what the
next story is" (REVIEW → DONE), and `/complete-story` says "the next story you
recommend". The pieces exist, but nothing puts them together:

- `plan.sh next <id>` answers advance vs complete for **one** story, but only
  when you already know which story to ask about;
- `plan.sh waves` and `plan.sh conflicts --pairs` answer which stories may run
  together, but say nothing about which command each should run with, or how to
  set up the worktrees;
- the `/audit-mutations` recommendation when an epic closes lives only in
  prose in `advance-story.md`.

So each closing report is reconstructed by hand, from memory of five commands,
and it comes out different every time. This story adds one command that
produces the whole answer, and makes `phase.sh set <id> DONE` print it.

Required gate that would fail if this story's artifact broke: `unit`
(`bash scripts/selftest.sh`, which runs `plan.test.sh` and `phase.test.sh`).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given <state>, when <action>, then <observable outcome>.
- **AC-2** — Given <state>, when <action>, then <observable outcome>.

- **AC-1** — Given a backlog with at least one startable PLANNED story, when
  `bash scripts/plan.sh after <closed-id>` runs, then it prints a `Next:` line
  naming the first startable PLANNED story in backlog order, with the command
  `plan.sh next` recommends for it (`/complete-story <id>` or
  `/advance-story <id>`) and that command's reason. A blocked story is never
  the one named.
- **AC-2** — Given other startable PLANNED stories that declare no path shared
  with the `Next:` story, with each other, or with any story in flight, when
  `plan.sh after` runs, then it lists each under `Alongside:` with its own
  recommended command, and prints one `git worktree add` line per listed story
  using that story's frontmatter `branch:`, with the instruction to run each
  command from inside its worktree. *Control:* a story that shares a path with
  the `Next:` story, or with another listed story, is **not** listed, and the
  output names the path it shares. A story that declares no paths is not
  listed, and is named as one that cannot be judged.
- **AC-3** — Given no story that can start alongside the `Next:` story, when
  `plan.sh after` runs, then `Alongside:` says to run one story at a time, and
  the output still names why each other startable story was left out.
- **AC-4** — Given stories that are in flight (any phase other than PLANNED and
  DONE) or blocked by a `depends_on` that is not DONE, when `plan.sh after`
  runs, then each in-flight story is named under `In flight:` with its phase and
  `/advance-story <id>`, and each blocked story is named under `Blocked:` with
  every dependency that is not DONE.
- **AC-5** — Given no startable story, when `plan.sh after <id>` runs, then
  `Next:` says no new story is startable and names `/plan-story`. Given a
  closed story whose `epic:` is non-empty and every story in that epic is DONE,
  the output recommends `/audit-mutations <epic>`. *Control:* with an empty
  `epic:`, or with another story in that epic not DONE, it does not.
- **AC-6** — Given any story, when `bash scripts/phase.sh set <id> DONE`
  succeeds, then its output ends with the report `plan.sh after <id>` prints.
  *Control:* `phase.sh set <id>` to any other phase does not print it. And
  `/advance-story` (REVIEW → DONE), `/complete-story` (the final report) and the
  `lead-po` agent each tell the orchestrator to relay that report, by naming
  `bash scripts/plan.sh after`.

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

RED may amend any block here in place, with a reason. GREEN builds what the
amended block says.

**Writes:** `scripts/plan.sh`, `scripts/phase.sh`, `.claude/tests/plan.test.sh`,
`.claude/tests/phase.test.sh`, `.claude/commands/advance-story.md`,
`.claude/commands/complete-story.md`, `.claude/agents/lead-po.md`, `CLAUDE.md`

### `plan.sh after [<closed-id>]`

A new subcommand in `scripts/plan.sh`, dispatched from the `case` at the bottom
of the file. `<closed-id>` is optional. When it is given and names an existing
story, the report adds the header and the epic check; without it, the report
still prints, minus both. **Always exits 0**: an empty backlog is an answer,
not an error. It writes to stdout only, so `p="$(plan.sh after X)"` captures
all of it.

It **reuses**, and does not reimplement: `story_walk` (candidates and blocked
stories), `cmd_next` (the command and reason for each story), `unmet_deps` (the
blocked detail), and `story_paths` and `shared_paths` (the collision test). If
two of these disagree with `waves` or `conflicts` about what is clear, that is
a defect.

The help text at the top of the file gains a line for `after`, and the `-h`
branch's `sed -n '3,7p'` range grows with it, so `plan.sh --help` lists `after`.

**Labels.** Each block starts with a label padded to 11 columns
(`printf '%-11s'`), and continuation lines are indented 11 spaces. Tests anchor
on the label at the start of a line.

```
After HARNESS-003:                              <- only when <closed-id> exists

Next:      /complete-story HARNESS-018
           <cmd_next's reason, verbatim>

Alongside: can start now, in parallel with HARNESS-018 - no two of these, and no story in flight, declare a shared path:
             /advance-story HARNESS-019
           To run them together, give each its own worktree (one worktree, one story):
             git worktree add ../<repo>-HARNESS-019 -b story/HARNESS-019-<slug>
           then run its command from inside that worktree.
           HARNESS-020 shares scripts/plan.sh with HARNESS-018
           HARNESS-021 declares no paths, so it cannot be judged - UNKNOWN is not clear

In flight: HARNESS-017 (REVIEW)  /advance-story HARNESS-017

Blocked:   HARNESS-022  depends_on HARNESS-018 (PLANNED)

Epic:      E1 has no open story left - /audit-mutations E1 is recommended; nothing runs it automatically.
```

**What each block means:**

- **Candidates.** `story_walk` yields the non-DONE stories in the glob order of
  their files, which is backlog order. A candidate in phase PLANNED is
  *startable*; a candidate in any other phase is *in flight*. A story that
  `story_walk` calls `blocked` goes under `Blocked:`, whatever its phase.
- **`Next:`** names the first startable story, as `/<cmd> <id>` from
  `cmd_next`'s first field, with the second field verbatim on the next line.
  With no startable story it prints `Next:      no new story is startable.`,
  and then, when nothing is in flight either,
  `           Add work with /plan-story.`
- **`Alongside:`** appears only when `Next:` names a story. The members start as
  the `Next:` story plus every in-flight story. Each remaining startable story,
  in backlog order, is checked against **every** member:
  - if it declares no paths, it gets the UNKNOWN reason line;
  - if it shares a path with a member, it gets the reason line
    `<ID> shares <paths> with <MEMBER>`, naming the first member it collides
    with;
  - otherwise it joins the members and is listed.

  This is greedy first fit, the same as `waves`, and like `waves` it does not
  claim to find the largest set.
  - If the `Next:` story or any in-flight story declares no paths, nothing can
    be judged against it. `Alongside:` then reads
    `nothing - <ID> declares no paths, so nothing can be judged against it.`
    and no other startable story is listed.
  - When nothing joins: `Alongside: nothing - run one story at a time.`,
    followed by the reason lines.
  - When at least one joins: the block shown above. The worktree directory is
    `../<basename of the repo root>-<ID>`, and the branch is the story's
    frontmatter `branch:` verbatim.
- **`In flight:`** prints one line per in-flight story:
  `<ID> (<PHASE>)  /advance-story <ID>`.
- **`Blocked:`** prints one line per blocked story, listing each unmet
  dependency the way `waves` does: `<dep> (<PHASE>)`, comma-separated, with
  `missing` for a dependency that has no story file.
- **`Epic:`** prints only when `<closed-id>` is given, its `epic:` is non-empty,
  and every story file whose `epic:` equals it is DONE.
- A block with nothing to say is left out entirely, except `Next:`, which always
  prints. Blocks are separated by one blank line.

### `phase.sh set <id> DONE`

After its existing output (`<id> -> DONE`, then `writes allowed: …`),
`cmd_set` prints one blank line and then the output of
`bash "$ROOT/scripts/plan.sh" after "$id"`, but **only** when the target phase
is DONE. By then the phase is already written, so a failure in `plan.sh` must
not fail the phase change: its exit status is ignored, and its stderr goes to
stderr.

### The prose sites

The first three must each contain the literal string
`bash scripts/plan.sh after`, because that is what AC-6's test reads.

- `.claude/commands/advance-story.md`, REVIEW → DONE: `phase.sh set … DONE`
  prints the report, and the orchestrator relays it to the user **as printed**,
  including any `Alongside:` set and its worktree commands. This replaces
  "report what the next story is". The existing `/audit-mutations` prose stays,
  now pointing at the `Epic:` line, and keeps "Recommend it; never run it".
- `.claude/commands/complete-story.md`: in the final report, "the next story you
  recommend" becomes the output of `bash scripts/plan.sh after $1`, relayed as
  printed. The story is at REVIEW by then, so it appears under `In flight:`.
- `.claude/agents/lead-po.md`: one sentence wherever it describes closing a
  story or reporting at the end of a run.
- `CLAUDE.md`: one line in "Running things" and one in the loop block. This one
  is untested; it is the index.

### Callers of changed signatures

None: no existing function's signature changes. `cmd_set`'s output grows only
for DONE, and no test pins `phase.sh set` output with `assert_eq` or a count.
`grep -rn 'phase.sh set\|phase set' .claude/tests/*.sh | grep 'assert_eq\|count'`
returns nothing (checked 2026-10-01).

### Oracle partition

Everything is mechanical, pinned by the labels and strings above. There is no
threshold and no metric.

### Test-only dependencies

None. The suites are bash. They use the existing `story_with` helper in
`plan.test.sh` and the `phase`/`story` helpers in `phase.test.sh`, and run in
`make_project_fixture`.

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
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

- **Defect put back: the collision check.** With the shared-path test inside
  the Alongside loop of `plan.sh after` made never to fire, AC-2's control (a
  conflicting story is not listed) MUST fail, and only assertions about
  collisions should fail. RED cannot run this, because `after` does not exist
  yet. **Owner: GATES.** Run it with `scripts/mutate.sh` against
  `bash .claude/tests/plan.test.sh`.

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

Planned by `bash scripts/plan.sh write HARNESS-018` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `opus` | planning is the judgement phase: decomposition, the oracle partition, and what goes in the contract |
| RED | `test-developer` | `opus` | the lock freezes none of the paths this story names, so the contract is not an aid to the model here - it is the only enforcement there is. A weaker model against a safety net and a weaker model against nothing are different propositions |
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

- Creating worktrees, or dispatching into them. The report prints the commands,
  and the user or the lead-po runs them. "Never create a worktree to make work
  parallel on your own initiative" still stands.
- Choosing the largest parallel set. This is greedy first fit, like `waves`.
- Changing the thresholds in `plan.sh next`, or what `waves` and `conflicts`
  print.
- A machine-readable mode. `conflicts --pairs` is already what the orchestrator
  parses; this is a report for a person.

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

