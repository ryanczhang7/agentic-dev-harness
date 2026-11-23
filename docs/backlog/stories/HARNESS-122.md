---
id: HARNESS-122
title: Tidy reports stray sibling folders a removed worktree left behind
slug: tidy-reports-stray-sibling-folders-a-rem
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-122-tidy-reports-stray-sibling-folders-a-rem
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/tidy.sh, .claude/tests/tidy.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the tidy suite under its selftest floor, which CI runs in full on the PR
---

## Context

`scripts/tidy.sh` (HARNESS-066) reports what a finished story leaves behind:
worktrees git lists, merged branches, and ORPHAN folders under
`<main>/.claude/worktrees/`. It looks nowhere else. But `CLAUDE.md` tells
people to put a worktree beside the main checkout
(`git worktree add ../adh-WORLD-015 ...`), and `plan.sh after` prints the
same shape (`scripts/plan.sh:803`, `../<repo>-<id>`). So the sibling layout
is the harness's own convention, and a folder a removed sibling worktree
leaves behind is in the one place tidy never reads. That is a defect in
tidy, not a new feature.

**The finding, measured 2026-11-21 in the consumer `D:/fantasy-world-builder`
(read-only: `find`, `ls`, `readlink`, `test -e`).**

- `git worktree list` there shows only the main checkout.
- Beside it, in `D:/`, sit `fwb-WORLD-052`, `fwb-ab-main`, `fwb-main-ab` and
  `fwb-refresh-136`. A fifth, `fwb-WORLD-169`, was there at the first
  measurement and gone minutes later (the user was removing them by hand).
  None has a `.git` entry and git lists none of them.
- Each holds one top-level entry, `node_modules`, and under it **635
  directories, 1100 links and 0 regular files** (`fwb-refresh-136`: 1101
  links). PowerShell counts a link as a directory, which is where the first
  report of "about 1735 directories, 0 files" came from.
- In `fwb-WORLD-052` all 1100 links are dangling: each points at a path
  inside the same folder that no longer exists. The other three were counted
  but not checked link by link.
- `git -C D:/fantasy-world-builder check-ignore node_modules/` matches
  (`.gitignore:2`).
- `bash scripts/tidy.sh`, run there from this repository's `main` (`fcf3835`,
  release 138) with the four folders present, prints exactly one line:
  `tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable`.

**How the removals left the folders like this is not known**, and this story
does not depend on it. No cause is to be written into the script, the tests
or the PR. The folder names are not evidence either: `fwb-*` does not share
a prefix with `fantasy-world-builder`.

This story makes tidy report such a folder, as `STRAY`, with the command to
remove it printed and never run. It is recognised by what it holds, not by
its name (Contract C-2, and Notes D-1 for the alternatives turned down).

**The gate that would fail if this broke.** Every gate is unconfigured in
this repository. The artifact is judged by the `tidy` suite under its floor
in `.claude/tests/floors.conf`, which CI runs in full on the PR.

## Acceptance criteria

Every fixture is a real repository made as `.claude/tests/tidy.test.sh`
makes them, with `node_modules/` in its `.gitignore`, whose main checkout
sits in a parent directory that holds nothing but what the criterion names.
"The parent" is that directory. "A stray-shaped folder" is a folder directly
in the parent, with no `.git` entry, not listed by `git worktree list`,
holding the one top-level entry `node_modules` with nested directories under
it and no regular file anywhere. "The STRAY pair for `<path>`" is these two
consecutive lines, where `<path>` is the main checkout's path as git prints
it with its last component replaced by the folder's name, and the command is
the one tidy already prints for an ORPHAN:

    STRAY <path>  empty
      remove it: <the remove command for <path>>

- **AC-1 (the gap, reproduced)** — Given a parent holding the main checkout
  and two stray-shaped folders, one holding directories only and one that
  also holds a dangling link (a link whose target does not exist), when
  `bash scripts/tidy.sh` runs in report mode, then the whole output is the
  STRAY pair for each folder, sorted by folder name, followed by the census
  `tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable`,
  and the exit status is 0. *(Today the whole output is the census line.
  The folder with the dangling link is the shape measured in the consumer.)*
- **AC-2 (what is never STRAY)** — Given AC-1's parent also holding the
  following, each differing from a stray-shaped folder in the one fact
  named: (a) a folder with one regular file, nested three levels down;
  (b) a folder with a `.git` file, and one with a `.git` directory; (c) a
  live linked worktree of the repository; (d) a worktree git still lists
  whose folder has been reduced by hand to the stray shape (its `.git` file
  deleted); (e) a folder holding a link that resolves, its target a file
  outside the folder; (f) a folder whose only top-level entry is `src`,
  which the repository does not ignore; (g) a completely empty folder;
  (h) a regular file in the parent; (i) a stray-shaped folder one level
  further down, inside (a) rather than directly in the parent — when tidy
  runs in report mode, then no line beginning `STRAY ` names any of them or
  the main checkout, the two folders of AC-1 still get their STRAY pairs,
  and (c) gets the worktree line it gets today.
- **AC-3 (where the lines go, and what they do not count)** — Given a
  repository with one REMOVABLE worktree, one ORPHAN folder under
  `.claude/worktrees/`, two stray-shaped folders in the parent and one
  DELETABLE branch, when tidy runs in report mode, then the whole output is,
  in this order: the worktree line, the ORPHAN line and its command, the two
  STRAY pairs sorted by folder name (`LC_ALL=C`), the DELETABLE line, and
  the census `tidy: 1 worktree(s), 1 removable, 0 kept; 1 merged branch(es)
  deletable`. The census has the same four numbers with the two folders
  absent.
- **AC-4 (nothing is deleted, in either mode)** — Given AC-1's parent, when
  tidy runs in report mode and then with `--apply`, then `--apply` prints
  the same STRAY pairs, the listing of every entry under each stray folder
  (`find`, sorted) is identical before the first run and after the second,
  and both exit statuses are 0.
- **AC-5 (the rule is written where it is read)** — `bash scripts/tidy.sh
  --help` prints the STRAY rule in the text Contract C-6 pins.

## Contract

**Writes:** `scripts/tidy.sh`, `.claude/tests/tidy.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block below, in place, with a reason; GREEN builds what
the amended block says. The acceptance criteria are not amendable this way.

**C-1. Where tidy looks.** One directory: the parent of the main checkout.
`MAIN` is the first record of `git worktree list --porcelain`, as the script
already holds it (`WT_PATH[0]`), and the parent is `P="${MAIN%/*}"`. It is
listed as `"$P/"` and a candidate's printed path is `"$P/<name>"`, so a main
checkout at a drive root (`D:/fantasy-world-builder`, `P` = `D:`) prints
`D:/<name>` with one slash. No fixture can sit at a drive root; DV-2 covers
that spelling. Candidates are the directories directly in `P`, dot names
included, that are not themselves links: the same enumeration the ORPHAN
loop uses. Nothing deeper, and no other worktree's parent.

**C-2. What makes a candidate STRAY.** All of these, and the first that
fails ends the judgement of that folder with no output:

1. it is not `MAIN` and not any listed worktree (`-ef` against every
   `WT_PATH`, as the ORPHAN loop does);
2. it has no `.git` entry, file or directory;
3. at least one of its top-level directories is a path the repository
   ignores: `git -C "$MAIN" check-ignore -q -- "<name>/"`, the name taken
   relative to `MAIN`. This is the evidence that the folder was a checkout
   of this repository; a completely empty folder has none and is not STRAY.
   Measured: `check-ignore -- node_modules/` matches in this repository
   (`.gitignore:37`), where no `node_modules` directory exists, and in the
   consumer;
4. it holds no regular file at any depth (`find <folder> -type f`);
5. no link under it resolves: for every `find <folder> -type l`, `[ -e ]`
   is false. A link that resolves to anything, inside or outside the
   folder, means the folder is left alone;
6. every `find` over it exited 0. A folder that could not be read is
   unknown, and unknown is never STRAY.

Rules 4 to 6 are the safety; rule 3 is the recognition. The order above is
also the cost order and is to be kept: 1 to 3 do not walk the tree, so an
unrelated sibling full of files costs a directory listing and one git call,
and `find -type f` should stop at the first file (`-print -quit`). Rule 5
must not spawn a process per link (a `[ -e ]` loop in the shell, not
`-exec test`): one folder in the consumer holds 1100 links, and a per-link
`-exec test -e` over it ran for over two minutes on this machine at PLANNED.

Rule 6 has no criterion: `chmod 000` does nothing under Git for Windows,
where this suite runs locally. RED pins it where it can make a directory
unreadable and says in the handoff which hosts that is; it is not to be
pinned by a skipped test.

**C-3. Output.** For each STRAY folder, two lines appended to the report:
`STRAY <path>  empty` (two spaces before `empty`, as ORPHAN has) and
`  remove it: <cmd>`, `<cmd>` being the script's existing `remove_cmd` for
that path, unchanged. STRAY folders are sorted by name under `LC_ALL=C`.
They come after every ORPHAN line and before every DELETABLE line. The
token is `STRAY`: `LEFT` already means a removal git refused.

**C-4. The census does not change.** Same text, same four numbers; STRAY
folders are counted in none of them, as ORPHAN folders are not.
`scripts/phase.sh:201` matches the census with a regex anchored at both
ends and prints nothing when it does not match, so any change to that line
silences the close-of-story report.

**C-5. `--apply`.** Prints the same STRAY pairs and acts on none. The exit
status is not affected by STRAY folders in either mode. The decision and
its reason: Notes D-2.

**C-6. The header text (AC-5).** The header of `scripts/tidy.sh`, which
`--help` prints, gains these lines, whole and in this order (the lines
between and around them are GREEN's to write):

    then one STRAY line per folder beside the main checkout that holds no
    regular file and no link that resolves, has no .git, is not a listed
    worktree, and has a top-level directory this repository ignores, each
    followed by the command to remove it (printed, never run),

and, in the paragraph on `--apply`:

    A STRAY folder is reported and never removed, with or without --apply.

RED pins each as whole lines of `--help`'s output.

**C-7. No existing export changes.** `tidy.sh` has no caller of a changed
signature: the options, the exit codes and the census are as they were.
`scripts/phase.sh:200` runs it with no arguments and reads only the census.
Every assertion `tidy.test.sh` holds at PLANNED stays as it is and stays
green.

**C-8. Fixtures (for RED).**

- Every existing fixture's main checkout sits directly in `$WORK`, so
  `$WORK` is the parent tidy will now read for all of them. New stray
  folders go under a parent of their own (for example
  `$WORK/h122/<case>/main`), never directly in `$WORK`, or the existing
  whole-report assertions will see them. Check too that nothing the
  existing fixtures already leave in `$WORK` is stray-shaped (`d-outside`
  is an empty folder: rule 3 keeps it out).
- A dangling link: on Git for Windows `ln -s` to a missing target does not
  make one by default. `cmd //c mklink /J <link> <target>` with the target
  then removed does, and is the kind the consumer's folders hold; elsewhere
  `ln -s`. Assert the fixture's fact first, as the suite does everywhere:
  `find -type l` counts it and `[ -e ]` is false for it.
- The suite's `cleanup` trap removes worktrees for the mains named `a` to
  `e` and `z` only. A new main that owns a worktree is added to that list,
  or its worktree is removed through git before the trap's `rm -rf`.
- `new_repo` already writes `node_modules/` into each fixture's
  `.gitignore`.

**C-9. Oracle partition.** All five criteria are mechanical: whole lines,
whole reports, exit statuses, a before-and-after listing. Pin them exactly,
with the suite's whole-line needles. Nothing is to be calibrated; the
counts in the Context are a record of the finding, not thresholds.

**C-10. Floors and release.** RED raises `tidy`'s floor in
`.claude/tests/floors.conf` (128 at PLANNED) to the count the suite
executes, with the usual note, and the `tidy 128` line in
`.claude/tests/selftest.test.sh` (`:563` at PLANNED) with it.
`.claude/harness/VERSION` takes the next free release number at GATES (138
is on `main` at PLANNED; HARNESS-120 is in flight and will take one too).

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

The budget is `rules.md`, "Mutation work per story": DV-1 is the defect put
back for the central claim; DV-2 is the probe against the real tree that a
story changing a rule over the tree owes; DV-3 is the one mutation that
earns the controls of AC-2, which pass on arrival (today nothing is ever
STRAY). RED cannot run any of them: the rule does not exist until GREEN.
Each runs against the one suite or the one command named, never the full
self-test.

- **DV-1, the defect put back (AC-1, AC-3).** With the scan of the parent
  directory disabled in `scripts/tidy.sh` (the expression is written at
  GATES against the script as built; it must change code, not a comment,
  and is recorded with the result), the `tidy` suite **must** fail, in the
  HARNESS-122 block and nowhere else, and AC-1's whole-report assertion must
  show the census line alone as its actual output. Run through
  `scripts/mutate.sh` against `bash scripts/selftest.sh tidy`.
  **Owner: GATES.**

- **DV-2, the rule on the real tree.** The tree this rule judges is a real
  main checkout and the real directory beside it, so the probe runs there
  and not in a fixture. It does not depend on the consumer's `fwb-*`
  folders, which were being removed at PLANNED. From this repository's real
  main checkout (the first record of `git worktree list`; its parent is the
  drive root `D:/` on the machine this was planned on, which is the
  spelling C-1 says no fixture reaches):

  1. make a throwaway skeleton beside it with `mkdir -p` only, under a name
     nothing else uses, for example `<parent>/adh-h122-probe/node_modules/a/b`;
  2. run the story's `bash scripts/tidy.sh` and paste its whole output with
     its wall time;
  3. remove the skeleton with plain `rmdir`, deepest first, one directory
     per argument, never a recursive delete, and show it is gone.

  The output **must** hold the STRAY pair for the probe folder, with the
  path spelled as `git worktree list` spells the main checkout's parent. And
  for every other STRAY line it prints, `find <path> -type f` must print
  nothing: a real sibling that holds a file and is reported is a failure of
  this story, to be routed, not explained. Every sibling of the real parent
  that holds files (other projects, other worktrees) is the control, and at
  PLANNED there were more than twenty. The wall time is recorded, not
  judged: no threshold is claimed here. Nothing in the repository is
  mutated, so this is not a `mutate.sh` run. **Owner: GATES.**

  Optional, and only if any still exist at GATES: the same script run from
  `D:/fantasy-world-builder` prints one STRAY pair per surviving `fwb-*`
  folder. If none survives, say so in one line; that is not a waiver of
  DV-2.

- **DV-3, the controls of AC-2 earned.** With rule 4 of C-2 (no regular
  file) taken out of `scripts/tidy.sh` (expression written at GATES against
  the script as built, and recorded), AC-2's case (a) **must** fail, its
  folder named on a STRAY line, and AC-1 must stay green. Run through
  `scripts/mutate.sh` against `bash scripts/selftest.sh tidy`.
  **Owner: GATES.**

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

Planned by `bash scripts/plan.sh write HARNESS-122` from `.claude/harness/models.conf`.
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

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
- PLANNED: `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override reported.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **Deleting anything.** No STRAY folder is removed by tidy, by `--apply`,
  by a test's subject under test, or by any agent running this story. Not
  with `rm -r`, not with a directory-by-directory `rmdir` pass (Notes D-2).
  The one removal in this story is DV-2's own probe folder, made by the
  person running the probe, with plain `rmdir`.
- **The close-of-story output.** `phase.sh set <id> DONE` relays only
  tidy's census, and the census does not change (C-4), so a STRAY folder
  still shows only when `tidy.sh` is run directly. Making the close-of-story
  output mention STRAY and ORPHAN folders is a possible follow-up: it is a
  change to `scripts/phase.sh` and its suite, a second behaviour, and the
  regex at `scripts/phase.sh:201` is anchored at both ends, so it cannot be
  had by adding to the census here. `scripts/phase.sh` and
  `.claude/tests/phase.test.sh` are not edited.
- **The census, the options and the exit codes.** Unchanged, to the byte.
- **`remove_cmd`, ORPHAN, REMOVABLE, KEEP, LEFT, DELETABLE.** No existing
  rule, line or command changes. In particular the command printed for a
  folder full of links is the one ORPHAN already prints; whether a different
  command would suit such a folder better is not decided here.
- **A listed worktree whose folder has become a skeleton** (AC-2 (d)). It is
  never STRAY. The worktree line it gets today is not pinned and not
  changed; if that line looks wrong, it is a finding for Notes, not work for
  this story.
- **Any directory but the main checkout's parent.** Not the parents of other
  listed worktrees, not folders two levels away, not a configured list of
  places.
- **Recognition by name, or by a record.** No name prefix, no list of
  worktrees tidy has seen kept under `.claude/state/`, no reading of
  `.git/worktrees/` (Notes D-1).
- **Why the folders were left.** Unknown, and not investigated here. No
  cause goes into a comment, a test name or the PR body. pnpm, junctions on
  Windows and `git worktree remove` are not to be named as the reason.
- **The consumer.** `D:/fantasy-world-builder` and its `fwb-*` folders are
  read at most, by DV-2's optional run. Nothing there is written, removed
  or refreshed by this story.
- **`CLAUDE.md` and `.claude/commands/advance-story.md`.** Neither describes
  tidy's report beyond the census; neither is edited.
- **A suite the self-test at GATES shows red.** A finding to record and
  route, not a licence to edit it here.

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

- **D-1, how a sibling is recognised: by content (PLANNED, 2026-11-21).**
  Turned down, each for a stated reason:
  - *A name prefix taken from the main checkout.* Misses the real case:
    `fwb-*` sits beside `fantasy-world-builder`.
  - *A prefix or path taken from git's records* (`.git/worktrees/*/gitdir`,
    `git worktree list`). Git no longer lists the folders in question, and
    its records for them are gone; that is what makes them invisible.
  - *A list of worktrees tidy has seen, kept under `.claude/state/`.* It
    would never have seen the folders that already exist, and it is
    per-worktree state.
  - *Every folder with no regular file.* No evidence it was ever a checkout
    of this repository; an empty `New folder` beside the repository would
    be reported with a delete command.
  Chosen: no regular file, no link that resolves, no `.git`, not listed,
  and a top-level directory the repository ignores (C-2). What a removal
  leaves behind is ignored content, which is what tidy's header already says
  a removal frees. Known limit, accepted: an unrelated folder beside the
  repository that holds nothing but an empty `node_modules/` is reported.
  It holds no file, and tidy only prints.
- **D-2, should `--apply` finish a half-done removal? No: report only
  (PLANNED, 2026-11-21).** tidy's header says nothing is deleted by any
  means but git, because a recursive delete outside the repository is what
  an agent's own safety checks refuse. Two further reasons here: that the
  folder was a worktree is inferred from its content, not recorded by git;
  and the measured folders are trees of links. Considered and turned down:
  a deepest-first `rmdir` pass, which cannot delete a file but is still an
  agent removing about 1700 entries outside the repository on an inference.
- **HARNESS-120 is in flight** (`D:/adh-HARNESS-120`, PLANNED at the time
  of writing) and declares `.claude/tests/floors.conf`,
  `.claude/tests/selftest.test.sh` and `.claude/harness/VERSION`, all three
  of which this story writes. The two are not to run side by side; whichever
  reaches REVIEW second merges `main` first and re-runs its gates.
- **The id.** Planned as HARNESS-121 until another session created
  `HARNESS-121.md` (a different story) during planning; this is HARNESS-122
  on the coordinator's word, re-checked free immediately before
  `new-story.sh`.
- **Confirmed on `main` at 40cb34f (2026-11-23), before RED, by the orchestrator.** HARNESS-120 (PR #210, release 139) and HARNESS-121 (PR #211, release 140) have both merged, so the in-flight note above no longer applies and nothing else declares this story's files. `git diff --stat 5dd9d69 40cb34f -- scripts/tidy.sh .claude/tests/tidy.test.sh scripts/phase.sh scripts/plan.sh` is empty: the Contract's line references (`scripts/phase.sh:200-201`, `scripts/plan.sh:803`) and the `tidy` floor of 128 (`floors.conf:71`, `selftest.test.sh:563`) hold as written. `.claude/harness/VERSION` is `140 (2026-11-22)`, so C-10's next free release is 141 unless another story takes it first. No re-plan was dispatched: no criterion, contract block or caller changed.
