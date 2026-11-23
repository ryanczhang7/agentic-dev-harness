---
id: HARNESS-123
title: Tidy suite pins dot-named folders and rule 3's path prefix
slug: tidy-suite-pins-dot-named-folders-and-ru
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-123-tidy-suite-pins-dot-globs-and-rule3-prefix
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/tidy.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the tidy suite under its selftest floor, which CI runs in full on the PR
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

`scripts/tidy.sh` reads three directories with the same three globs,
`* .[!.]* ..?*`, so that a folder whose name starts with one dot or with two
is seen like any other: the ORPHAN loop over `<main>/.claude/worktrees/`
(`:171`, HARNESS-066), the STRAY loop over the main checkout's parent
(`:193`) and rule 3's loop over a candidate's top-level directories
(`:207`, both HARNESS-122). Rule 3 then hands each top-level name to
`git check-ignore` as `./<name>/` (`:208`), so that a name starting `:(` is
a path and not pathspec magic.

HARNESS-122's diff review found three places where the script is right and
nothing fails if it stops being right (`docs/backlog/stories/HARNESS-122.md`,
`## Diff review` rounds 2 and 3, and `## Regressions` R-2, "Not pinned
separately"). The story left them out of scope:

1. **ORPHAN, dot names.** No fixture under `.claude/worktrees/` has a name
   starting with a dot. With both dot globs dropped from `:171` the `tidy`
   suite stays green.
2. **STRAY, the `..?*` glob alone.** R-2's fixtures are `.hidden` and
   `.venv`, which only `.[!.]*` matches. With `..?*` dropped from `:193` or
   from `:207` the suite stays green.
3. **Rule 3's `./` prefix.** No fixture has a top-level directory whose name
   git would read as pathspec magic. With the prefix dropped from `:208` the
   suite stays green, and a folder holding only `:(top)node_modules/` is
   reported STRAY (measured at PLANNED, see `## Notes`).

This story adds the missing fixtures and assertions to
`.claude/tests/tidy.test.sh`. It is a test-only story: `scripts/tidy.sh`
already does all three things, and is not edited.

**The gate that judges it.** Every gate is unconfigured in this repository.
The artifact is the `tidy` suite, held by its floor in
`.claude/tests/floors.conf`, which the full self-test checks and CI runs on
the PR.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

Each criterion describes what `tidy.sh` already does. Each passes today and
fails only when the line it pins is broken, so none can be watched to fail
in an ordinary RED. `## Deferred verifications` names the one mutation that
earns each.

- **AC-1 (ORPHAN sees dot names)** — Given a main checkout whose parent
  holds nothing else, and whose `.claude/worktrees/` holds exactly three
  folders git does not list - `.o-hid` (empty), `..o-two` (holding one
  file, one directory down) and `o-plain` (empty) - when `tidy.sh` runs in
  report mode from that checkout, then its whole output is the ORPHAN line
  and remove-it line for `..o-two` (`1 file(s)`), then for `.o-hid`
  (`empty`), then for `o-plain` (`empty`), then the census
  `tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable`,
  and it exits 0.
  *Control:* `o-plain` is in the same report, so a script that prints no
  ORPHAN line, or sorts dot names last, fails the whole-report assertion.

- **AC-2 (STRAY sees names starting with two dots)** — Given the parent
  HARNESS-122's dot-names case uses (`.hidden/node_modules/a/b` and
  `v-hidden/.venv/a/b` beside a main checkout that ignores `node_modules/`
  and `.venv/`), with two folders added - `..two/node_modules/a/b`, and
  `w-two/..cache/a/b` where the main checkout also ignores `..cache/` -
  when `tidy.sh` runs in report mode from that checkout, then its whole
  output is the STRAY line and remove-it line for `..two`, then `.hidden`,
  then `v-hidden`, then `w-two`, then the census with every count 0, and it
  exits 0.
  *Control:* `..two` has a plain top-level directory and `w-two` has a
  plain name, so each is lost by exactly one of the two loops (`..two` when
  the parent loop stops seeing two-dot names, `w-two` when rule 3's loop
  does).

- **AC-3 (a top-level name starting `:(` is a path)** — Given the parent
  HARNESS-122's rule-3 case uses (`r3-two` and `r3-none` beside a main
  checkout that ignores `node_modules/`), with one folder added, `c-magic`,
  whose only entry is a directory named `:(top)node_modules` holding only
  empty directories, when `tidy.sh` runs in report mode from that checkout,
  then no line beginning `STRAY ` names `c-magic`, and the whole output is
  still `r3-two`'s STRAY line and remove-it line, then the census with
  every count 0.
  *Control:* the fixture is only a test if git reads the bare name as
  pathspec magic. So its fact assertion records both answers from the same
  checkout: `git check-ignore -q -- ':(top)node_modules/'` exits 0 (magic,
  it matches `node_modules/`) and `git check-ignore -q --
  './:(top)node_modules/'` exits 1 (a path nothing ignores). `r3-two` is
  still reported, so a script that reports nothing fails too.

The suite's host conditions do not change: all three criteria run on every
host, Git for Windows included (`## Notes`, "The Git Bash probe").

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

**Writes:** `.claude/tests/tidy.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason. No export changes
signature, so there is no caller list.

**C-1. The subject, and its lines at PLANNED.** `scripts/tidy.sh` at
`b3a7f9e`, 265 lines, read and not written. The four lines this story pins,
checked against the file at PLANNED (HARNESS-122's review cited `:206` for
the third; it is `:207` since `2441a5b`):

- `:171` the ORPHAN loop: `for d in * .[!.]* ..?*; do` inside `names="$(cd "$MAIN/.claude/worktrees" && ...`
- `:193` the STRAY parent loop: `for d in * .[!.]* ..?*; do` inside `strays="$(cd "$P/" && ...`
- `:207` rule 3's loop: `for d in "$s"/* "$s"/.[!.]* "$s"/..?*; do`
- `:208` rule 3's spelling: `tops+=("./${d##*/}/")`

Re-check the numbers before running a mutation; the expressions in
`## Deferred verifications` are line-addressed.

**C-2. Where the fixtures go.** All in `.claude/tests/tidy.test.sh`, using
the helpers the HARNESS-122 block already has (`h_parent`, `h_ls`,
`h_shape`, `h_pair`, `h_pairs_of`, `h_stray_names`, `whole`, `census`,
`remove_cmd`, `T`). No helper changes behaviour for an existing caller.

- **AC-1: a parent of its own**, `h_parent orph` (so `$WORK/h122/orph/main`,
  origin under `h122/origins/`), in a new `describe` named for HARNESS-123
  AC-1. Not fixture `d`: its whole report, its `--apply` run and its
  snapshot are HARNESS-066's and stay as they are. Under
  `main/.claude/worktrees/`: `mkdir -p` for `.o-hid`, `..o-two/x` and
  `o-plain`, and one file `..o-two/x/f`. The parent `h122/orph` holds
  `main` only, so no STRAY line can appear.
- **AC-2: HARNESS-122's `h122/dot` parent**, in its existing `describe`.
  Add `..cache/` to the same `.gitignore` commit that adds `.venv/` (one
  commit, so the tree stays clean), and `mkdir -p`
  `"$HD/..two/node_modules/a/b"` and `"$HD/w-two/..cache/a/b"`.
- **AC-3: HARNESS-122's `h122/r3` parent**, in its existing `describe`.
  `mkdir -p "$HR/c-magic/:(top)node_modules/a/b"`. No `.gitignore` change.

**C-3. The assertions, and the count.** Eleven new, four changed in place.
Every one is outside any conditional.

AC-1, five new:
1. fixture fact: `.claude/worktrees/` holds `..o-two,.o-hid,o-plain`
   (`h_ls`), none listed by `git worktree list`, with file counts 1, 0, 0;
   and the parent holds `main` only.
2. the ORPHAN pair for `.o-hid`: the line `ORPHAN <path>  empty` followed
   by `  remove it: <remove_cmd path>`, once, as two consecutive whole lines.
3. the ORPHAN pair for `..o-two`: `ORPHAN <path>  1 file(s)` and its
   remove-it line, the same way.
4. `whole`: the three pairs in the order AC-1 gives, then `census 0 0 0 0`.
5. exit status 0.

`h_pairs_of` builds a STRAY pair; the ORPHAN pair needs its own spelling
(a small helper, or the awk inline). Paths are git's spelling, taken from
`porc_paths` as every other block does.

AC-2, four new and two changed:
6. fixture fact for `..two`: `h_shape` gives
   `nogit|unlisted|files=0|links=0|resolving=0|top=node_modules|ignored=node_modules|nested=2`.
7. fixture fact for `w-two`: `h_shape` gives
   `nogit|unlisted|files=0|links=0|resolving=0|top=..cache|ignored=..cache|nested=2`.
8. `..two` gets its STRAY pair (`h_pairs_of` is 1).
9. `w-two` gets its STRAY pair.
- changed: the parent listing fact, from `.hidden,main,v-hidden` to
  `..two,.hidden,main,v-hidden,w-two`.
- changed: the `whole` report, from two pairs to four, in `LC_ALL=C` order:
  `..two`, `.hidden`, `v-hidden`, `w-two`, then `census 0 0 0 0`.

AC-3, two new and one changed:
10. fixture fact for `c-magic`, spelled by hand and not through `h_shape`'s
    `ignored` field (that field asks git about the bare name, which is the
    magic reading): no `.git`, unlisted, no file, no link, top-level entries
    exactly `:(top)node_modules`, and the two exit statuses of AC-3's
    control, bare 0 and prefixed 1, both from `git -C "$MR"`.
11. `c-magic` is never named on a STRAY line (`h_stray_names` is 0).
- changed: the parent listing fact, from `main,r3-none,r3-two` to
  `c-magic,main,r3-none,r3-two`.
- unchanged, and now carrying AC-3: the `whole` report of that block
  (`r3-two`'s pair, then the census).

The descriptions of the changed assertions and the block comments above
them are updated to say what they now hold. A changed assertion keeps
everything it asserted before and adds to it; none is loosened.

**C-4. The semantics behind each name.** `.o-hid` and `.hidden` start with
one dot and a non-dot: only `.[!.]*` matches them. `..o-two`, `..two` and
`..cache` start with two dots and one more character: only `..?*` matches
them. `:(top)node_modules` is git's long-form pathspec magic for "from the
top of the tree, `node_modules`": bare, it asks about `node_modules/`,
which every fixture ignores; behind `./` it is one odd directory name that
nothing ignores. Sort order is `LC_ALL=C`: `.` is 0x2E, below every letter,
so `..x` sorts before `.x` and both before plain names.

**C-5. Oracle partition.** All three criteria are mechanical: whole lines,
whole reports, exit statuses. Pin them exactly, with the suite's whole-line
needles. Nothing is calibrated.

**C-6. How RED earns them.** The implementation exists, so every new
assertion passes on its first run. RED's evidence is therefore two things:
the suite green at the new count, and the three `mutate.sh` runs in
`## Deferred verifications`, pasted there. An assertion that fails on
arrival, with `scripts/tidy.sh` unmutated, is not a test to adjust and not
a defect for GREEN to fix: RED stops and reports it, and the story goes
back to planning (`## Out of scope`).

**C-7. GREEN writes nothing.** There is no production change to make. The
orchestrator confirms the suite is green at the new floor and moves on.

**C-8. Floors and release.** Baseline at PLANNED: `tidy 195`
(`.claude/tests/floors.conf:71` and `.claude/tests/selftest.test.sh:563`),
which is what the suite executes on a Windows host; CI executes 197,
because rule 6's two assertions run only where `chmod 000` makes a
directory unreadable. With C-3's eleven, RED raises both places to **206**
(208 on CI) and adds the usual dated note at the end of `floors.conf`:
what was added, that four existing assertions changed in place and how,
the measured `tidy: N passed, 0 failed` line, and that the new assertions
are earned by mutation in this story. If RED's count differs from eleven,
the floor is the count the suite executes on the Windows host, and RED
says why here. `selftest.test.sh` compares its `tidy` line with
`floors.conf`, so the two move together. No other floor moves.
`.claude/harness/VERSION` goes from `141 (2026-11-23)` to release **142**
with the real date, at GATES. If another story has taken 142 on `main` by
then, take the next free number and say so in `## Notes`.

**C-9. Test-only dependencies.** None. bash, awk, coreutils and git.

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

The budget is `rules.md`, "Mutation work per story": one mutation for each
test written against code that already exists. This story is nothing but
such tests, in three groups, so it has three entries and no separate
"defect put back": each entry puts back the defect its criterion pins.
Nothing here is deferred because a phase cannot run it. The section is
used because it is the one `check-boundaries.sh` holds to a pasted result.

Each runs through `scripts/mutate.sh` against the one suite, as
`bash scripts/mutate.sh scripts/tidy.sh '<expression>' -- bash scripts/selftest.sh tidy`,
never the full self-test. Each expression names a real line of
`scripts/tidy.sh` (Contract C-1) and was tried at PLANNED on a scratch copy
of the script (`## Notes`). For each, paste: the expression, the suite's
failing assertions with expected and actual, its `tidy: N passed, M failed`
line, and `mutate.sh`'s line saying the file was restored.

- **DV-1 (AC-1): the ORPHAN loop stops seeing dot names.** Expression
  `171s/ \.\[!\.\]\* \.\.?\*//`. The suite **must** fail in exactly three
  assertions, all in the HARNESS-123 AC-1 block: the ORPHAN pair for
  `.o-hid` (expected 1, actual 0), the ORPHAN pair for `..o-two` (expected
  1, actual 0), and the whole report (actual: `o-plain`'s pair and the
  census). Every other assertion passes, HARNESS-122's dot-names block
  included. **Owner: RED.**

- **DV-2 (AC-2): both STRAY loops stop seeing two-dot names.** Expression
  `193s/ \.\.?\*//;207s# "\$s"/\.\.?\*##`, one run changing two lines. The
  suite **must** fail in exactly three assertions, all in HARNESS-122's
  dot-names block: the STRAY pair for `..two` (lost at `:193`), the STRAY
  pair for `w-two` (lost at `:207`), and the whole report (actual:
  `.hidden`'s pair, `v-hidden`'s pair, the census). `.hidden` and
  `v-hidden` must still get their pairs: that is the evidence the mutation
  removed `..?*` alone. **Owner: RED.**

- **DV-3 (AC-3): rule 3 passes the bare name.** Expression
  `208s#"\./\${d#"${d#`. The suite **must** fail in exactly two assertions,
  both in HARNESS-122's rule-3 block: `c-magic` never named on a STRAY line
  (expected 0, actual 1) and the whole report (actual: `c-magic`'s pair,
  `r3-two`'s pair, the census). **Owner: RED.**

If a run fails more assertions than listed, or fewer, that is a finding:
paste it as it came out and say so. Do not adjust a fixture until the
count matches.

**The orchestrator's own run (the ladder).** At GATES, against the
committed tree, the orchestrator re-runs DV-3 and compares the count with
the one RED pasted. DV-3 is the one whose catch is narrowest. It is
recorded in `## Notes`. **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-123` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`: planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-23; no override reported. The oracle partition is Contract C-5: all three criteria mechanical.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **`scripts/tidy.sh`.** Not edited, by any phase. It changes only inside a
  `mutate.sh` run, which restores it. If a new assertion fails against the
  unmutated script, the script mishandles a case nobody knew about: RED
  stops, records the failing assertion and its output in `## Notes`, and
  the story returns to planning for a criterion that reproduces the defect.
  It is not fixed in GREEN under this story's criteria.
- **Fixture `d` and HARNESS-066's AC-5 block.** Its folders, its whole
  report, its `--apply` run and its snapshot stay as they are.
- **Rule 5's second NUL** (`scripts/tidy.sh:216`, `|| printf '\0\0'`).
  HARNESS-122's round 3 found no way to arrange a `find` that dies part-way
  through a name. Still unpinned, and not attempted here.
- **Rule 6 and its host guard.** The `chmod 000` pair stays CI-only, and
  nothing is added beside it.
- **Other odd names.** A leading `-`, `!`, `#`, a space, a newline, `:!`
  and `:(x`. Round 3 measured that the `./` prefix changes nothing for the
  first five; `:(top)node_modules` is the one name this story pins, because
  it is the one whose bare reading is "ignored".
- **The ORPHAN remove-it command for a dot-named folder.** Asserted as
  `remove_cmd` prints it today; whether it suits such a folder is not
  judged.
- **Helpers.** `h_shape`'s `ignored` field keeps asking about the bare
  name. C-3 item 10 works around it for one fixture; it is not rewritten.
- **A suite the self-test at GATES shows red.** A finding to record and
  route, not a licence to edit it here.
- **Any file not in `touches:`.** No documentation describes these gaps;
  `CLAUDE.md`, the skills and `rules.md` are not edited.

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

- **PLANNED (2026-11-23, `lead-po`, declared `fable`, resolved Fable 5.2,
  `claude-fable-5-2`; no override reported to me).** Planned from
  HARNESS-122's `## Diff review` rounds 2 and 3 and `## Regressions` R-2.
  No epic: HARNESS-122 has none. `branch:` was set by hand to the branch
  the worktree was already on,
  `story/HARNESS-123-tidy-suite-pins-dot-globs-and-rule3-prefix`;
  `new-story.sh` derives a different one from the title, and
  `check-boundaries.sh` reads `branch:`, not the slug.

- **The Git Bash probe (2026-11-23, this machine: MINGW64_NT-10.0-26200,
  bash 5.3.15, git 2.55.0.windows.5).** The question was whether AC-3's
  fixture has to be CI-only, like rule 6's. It does not. In a scratch
  parent holding a fixture-shaped `main` (ignores `node_modules/`) and
  `c-magic`:

  ```
  $ mkdir -p 'c-magic/:(top)node_modules/a/b'; echo "mkdir rc=$?"
  mkdir rc=0
  $ ls -A c-magic
  :(top)node_modules
  $ ( cd c-magic && for d in *; do printf 'glob sees: [%s]\n' "$d"; done )
  glob sees: [:(top)node_modules]
  $ powershell: the name's code points, as Windows stores it
  F03A 0028 0074 006F 0070 0029 006E 006F 0064 0065 005F 006D 006F 0064 0075 006C 0065 0073
  $ git check-ignore -q -- ':(top)node_modules/'; echo $?      # from main
  0
  $ git check-ignore -q -- './:(top)node_modules/'; echo $?
  1
  ```

  So Windows stores the colon as U+F03A, and bash's glob hands the script
  `:` again, which is the name the rule cares about. With `tidy.sh` as it
  is, `c-magic` is not reported. With `:208` changed to pass the bare name
  (DV-3's expression), it is: `STRAY <parent>/c-magic  empty`. The fixture
  discriminates on this host, so AC-3 runs everywhere and the floor counts
  it on Windows. Linux and macOS take the name as it is written.

- **The five single mutations, on the same scratch parent (2026-11-23).**
  The parent also held `..two/node_modules/a`, `w-two/..cache/a` (with
  `..cache/` ignored) and, under `main/.claude/worktrees/`, `.o-hid`,
  `..o-two/x/f` and `o-plain`. `mkdir` made every name. Unmutated, the
  report was the three ORPHAN pairs (`..o-two  1 file(s)`, `.o-hid  empty`,
  `o-plain  empty`), then STRAY `..two` and `w-two`, then the census. Each
  mutation of a copy of `scripts/tidy.sh` lost exactly one thing:

  | Line | Dropped | Lost from the report |
  |---|---|---|
  | `:171` | `.[!.]*` | ORPHAN `.o-hid` |
  | `:171` | `..?*` | ORPHAN `..o-two` |
  | `:193` | `..?*` | STRAY `..two` |
  | `:207` | `"$s"/..?*` | STRAY `w-two` |
  | `:208` | `./` | nothing lost; STRAY `c-magic` appears |

  DV-1 and DV-2 each combine two of these into one run, to keep the story
  at three suite runs; the fixtures are built so each lost folder still
  shows as its own failing assertion. These were runs of the script on a
  scratch parent, not of the suite: they are why the criteria are believed
  satisfiable, and they earn nothing. RED's three runs do.

- **Baseline measured at PLANNED (2026-11-23, this machine, unedited tree
  at `b3a7f9e`).** `bash .claude/tests/tidy.test.sh` ended
  `tidy: 195 passed, 0 failed`, which is the floor in `floors.conf:71`.

- **Before RED: the branch is one commit behind `origin/main`.** It was cut
  from `b3a7f9e`; `origin/main` is `300a9e3`, the commit that marks
  HARNESS-122 DONE. In this tree HARNESS-122 still reads REVIEW, so
  `plan.sh conflicts` prints `CONFLICT HARNESS-122 + HARNESS-123` on all
  four files. That is the stale story file, not a second story in flight.
  Merging `origin/main` into the branch clears it; the planning dispatch
  did not, because it was asked to commit the story file only.

- **`check-boundaries.sh` at PLANNED (08e4989).** Frontmatter and branch
  checks pass. Its three failures are the ones every story has before
  REVIEW: the phase is PLANNED, `## Handoff` is empty, and
  `## Deferred verifications` has no pasted result yet.
