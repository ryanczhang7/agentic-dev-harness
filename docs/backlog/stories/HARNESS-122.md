---
id: HARNESS-122
title: Tidy reports stray sibling folders a removed worktree left behind
slug: tidy-reports-stray-sibling-folders-a-rem
epic: 
type: fix
status: in-progress
phase: GATES
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
- *Amended by RED, 2026-11-23, from measurement on this host (Git for
  Windows, MINGW64, Windows 11, no Developer Mode).* `cmd //c mklink /J ...`
  as written above fails with `Invalid switch`; the spelling that works is
  `MSYS_NO_PATHCONV=1 cmd /c mklink /J <cygpath -w link> <cygpath -w
  target>`, and the suite uses it. A junction made that way is listed by
  `find -type l`, `[ -L ]` is true, and once its target is removed `[ -e ]`
  is false. Also measured: `ln -s` to an existing *file* does not fail here
  but **copies** it (a regular file `find -type l` does not see), and a real
  file symlink (`MSYS=winsymlinks:nativestrict`, or `mklink` without `/J`)
  is refused for want of privilege. So AC-2 (e)'s "a link that resolves,
  its target a file outside the folder" can be built only where the host
  can make a file symlink (CI's Linux runner, and Windows with the
  privilege); under Git for Windows without it the fixture is a junction to
  a directory outside the folder, and its fact assertion names which kind
  it made. The rule judged is the same (C-2 rule 5: `[ -e ]` true for a link
  under the folder); only the link's target type differs by host.
- *Amended by RED, 2026-11-23: what "the name taken relative to MAIN" in
  C-2 rule 3 means, as the suite pins it.* For a candidate `P/<folder>` and
  each of its top-level directories `<d>` (not a link), the call is
  `git -C "$MAIN" check-ignore -q -- "<d>/"` - `<d>` alone, as though it sat
  at MAIN's root, not `../<folder>/<d>/` (which git refuses as outside the
  repository). A scratch candidate built that way passes the whole suite.

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

**Results (GATES, 2026-11-23, run by the orchestrator through `scripts/mutate.sh`, each against `bash scripts/selftest.sh tidy`).**

**DV-3, first run, against the GREEN tree (5564b85): the control did not discriminate, and that found a defect.** With rule 4 replaced by `:` the suite stayed green, `tidy: 181 passed, 0 failed`. Cause, reproduced in a scratch repository: rule 3 passed every top-level directory to one `git check-ignore -q` call, and git refuses `-q` with more than one path (`fatal: --quiet is only valid with a single pathname`, exit 128, hidden by `2>/dev/null`). So any candidate with two or more top-level directories was never STRAY, case (a)'s `c-file` (`node_modules`, `s-inner`) included, whatever rule 4 said. Fixed in GATES by a `feature-developer` dispatch to the C-8 amendment's form, one `check-ignore -q -- "<d>/"` per directory (see `## Notes`). No test pins a reported candidate with two top-level directories; left for diff review to route.

```
=== mutate: scripts/tidy.sh (1 line(s) changed by s/^  \[ -z "\$anyfile" \] || continue$/  :/) ===
  210 -   [ -z "$anyfile" ] || continue
  210 +   :
tidy: 181 passed, 0 failed
=== mutate: command exited 0; restored (verified byte-for-byte against /d/adh-HARNESS-122/.claude/state/mutations/scripts_tidy.sh.20261123T162055Z.6689.bak) ===

$ git check-ignore -q -- node_modules/ s-inner/      # scratch repo, .gitignore = node_modules/
fatal: --quiet is only valid with a single pathname
exit 128
```

**DV-1, against the fixed tree: red as predicted, in the HARNESS-122 block only.** `done <<< "$strays"` replaced by `done <<< ""`. Seven failures, all HARNESS-122; AC-1's whole-report assertion shows the census line alone as its actual output. (The same seven failed against the GREEN tree before the fix.)

```
=== mutate: scripts/tidy.sh (1 line(s) changed by s/^done <<< "\$strays"$/done <<< ""/) ===
    FAIL HARNESS-122 AC-1: the whole report is the STRAY pair for each stray-shaped folder, sorted by name, then the unchanged census
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
    FAIL HARNESS-122 AC-2: AC-1's s-dirs still gets its STRAY pair
    FAIL HARNESS-122 AC-2: AC-1's s-link still gets its STRAY pair
    FAIL HARNESS-122 AC-2: and those are the only two STRAY lines, in any spelling
    FAIL HARNESS-122 AC-3: the whole report is the worktree line, the ORPHAN pair, the two STRAY pairs in LC_ALL=C order, the DELETABLE line, then the census
    FAIL HARNESS-122 AC-4: report mode prints the two STRAY pairs, then the census
    FAIL HARNESS-122 AC-4/C-5: --apply prints the same STRAY pairs and acts on neither
tidy: 174 passed, 7 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-122/.claude/state/mutations/scripts_tidy.sh.20261123T163323Z.18967.bak) ===
```

**DV-3, against the fixed tree: red as predicted.** Rule 4 replaced by `:`; case (a) is named on a STRAY line and the STRAY count goes from 2 to 3; AC-1 stays green.

```
=== mutate: scripts/tidy.sh (1 line(s) changed by s/^  \[ -z "\$anyfile" \] || continue$/  :/) ===
    FAIL HARNESS-122 AC-2 (a) a folder holding one regular file is never named on a STRAY line
         expected: 0
         actual:   1
    FAIL HARNESS-122 AC-2: and those are the only two STRAY lines, in any spelling
         expected: 2
         actual:   3
tidy: 179 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-122/.claude/state/mutations/scripts_tidy.sh.20261123T163824Z.22395.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**DV-2, the real tree, against the fixed tree.** Main checkout `D:/agentic-dev-harness` (first record of `git worktree list`), parent `D:/`. Skeleton made with `mkdir -p /d/adh-h122-probe/node_modules/a/b`; the story's `tidy.sh` run from this worktree, report mode. The probe is the only STRAY line, spelled `D:/` as `git worktree list` spells the parent; every other sibling of `D:/` (other projects, other worktrees) is not reported. Wall time 3 s. Removal: the `rmdir` of the four empty directories was refused by the agent's own safety check (a removal directly under a drive root), so it is left for the user (`## Notes`). No `fwb-*` folder survives under `D:/`, so the optional run from `D:/fantasy-world-builder` has nothing to show.

```
$ git worktree list | head -1
D:/agentic-dev-harness 40cb34f [main]
$ mkdir -p /d/adh-h122-probe/node_modules/a/b && bash scripts/tidy.sh
KEEP D:/adh-HARNESS-121  recent
STRAY D:/adh-h122-probe  empty
  remove it: Remove-Item -LiteralPath '\?\D:\adh-h122-probe' -Recurse -Force
tidy: 1 worktree(s), 0 removable, 1 kept; 0 merged branch(es) deletable
exit 0
wall: 3s
$ find /d/adh-h122-probe | wc -l
4
$ ls -d /d/fwb-*
no fwb-* folders survive
```

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
- RED, `test-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-23; no override. Orchestrator checked: `attest.sh check -- bash scripts/selftest.sh tidy` fresh, exit 1, `tidy: 168 passed, 13 failed`, all 13 HARNESS-122 pins, every HARNESS-066 assertion green; `gates.sh --fast` fresh, exit 0. The dispatch measured its controls against a throwaway STRAY candidate built in its scratchpad, never in the tree (handoff table). The AC-2 (e) fixture is a junction to a directory under Git for Windows and a file symlink elsewhere; put to the user with the RED report. Every junction target and every `rm` in the new block is under the suite's own `$WORK` (read by the orchestrator).
- GREEN, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-23; no override. Orchestrator checked: `attest.sh check -- bash scripts/selftest.sh tidy` fresh, exit 0, `tidy: 181 passed, 0 failed`, 181 executed of 181 declared; `gates.sh --fast` fresh, exit 0 (vacuous: 0 ran). No test file changed (`git status`: only `scripts/tidy.sh` and this story). The one control GREEN owns ("all six rules", expected 181/0) measured 181/0; the mutation rows are GATES' DV entries.
- GATES fix, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-23; no override. Rule 3 rewritten to one `check-ignore -q` per top-level directory after DV-3 found the batched call refused by git (`## Deferred verifications`, `## Notes`). Orchestrator checked: `attest.sh check -- bash scripts/selftest.sh tidy` fresh, exit 0, 181/0; `gates.sh --fast` fresh, exit 0.
- GATES full run, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-23; no override. Orchestrator checked: `attest.sh check -- bash scripts/gates.sh` fresh, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).` (vacuous here, BOOTSTRAPPED=no; the tidy suite under its floor is the judge). Did not queue.
- RED R-1, `test-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-23; no override. Added the C-2 rule 3 block (own parent `h122/r3`, 7 assertions), earned by three `mutate.sh` runs pasted in R-1. Orchestrator checked: `attest.sh check -- bash scripts/selftest.sh tidy` fresh, exit 0, `tidy: 188 passed, 0 failed`; `gates.sh --fast` fresh, exit 0; `git diff -- scripts/` empty.
- GREEN after R-1: a no-op, verified by the orchestrator. `git diff cfabd05 -- scripts/` is empty, and `attest.sh check -- bash scripts/selftest.sh tidy` is fresh on this tree, exit 0, `tidy: 188 passed, 0 failed`.
- GATES findings 2 and 3, `feature-developer`: planned `opus`, resolved Opus 5.5 (`claude-opus-5-5`), 2026-11-23; no override. Rule 3 back to one `check-ignore` call, without `-q`; rule 5 reads links NUL-delimited, a failed `find` appending an empty record that keeps the folder (rule 6). `tidy.sh` on `D:/`: 2.5-2.9 s before, 1.1-1.2 s after. Orchestrator checked: `attest.sh check -- bash scripts/selftest.sh tidy` fresh, exit 0, 188/0; `attest.sh check -- bash scripts/gates.sh` fresh, exit 0, `All required gates passed (0 ran, 7 unconfigured, 0 known).` (queued 9m07s behind `/d/manga-translator`). The newline-named link cannot be made on Windows, so finding 3 is unverified on this host.

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

One level: the `tidy` suite, `.claude/tests/tidy.test.sh`, which runs a copy of
`scripts/tidy.sh` inside real fixture repositories (`new_repo`), exactly as the
HARNESS-066 assertions above it do. Every criterion is mechanical (C-9), so
every pin is a whole report (`whole`), a whole line (`has_line`), a pair of
consecutive whole lines (`h_pairs_of`), an exit status, or a before/after
`find` listing. Each fixture's distinguishing fact is asserted first, through
`h_shape` (`git|listed|files=N|links=N|resolving=N|top=..|ignored=..|nested=N`),
so a broken fixture fails as a fixture.

Layout (C-8): every parent is `$WORK/h122/<case>/` with the main checkout at
`<case>/main`; origins in `$WORK/h122/origins/`, link targets in
`$WORK/h122/targets/`. Nothing new lands directly in `$WORK`.

| Block (describe) | Assertions | AC |
|---|---|---|
| HARNESS-122 AC-1 | 4 fixture facts (parent holds `main,s-dirs,s-link`; git lists 1; `s-dirs` and `s-link` shapes), whole report = two STRAY pairs + `census 0 0 0 0`, exit 0 | AC-1 |
| HARNESS-122 AC-2 | 10 fixture facts, (a)-(i); 11 "never named on a STRAY line" (a, b-file, b-dir, c, d, e, f, g, h, i, main checkout); AC-1's two pairs still present (2); exactly two `STRAY ` lines; (c) gets `KEEP <path>  recent` | AC-2 |
| (same, rule-6 hosts only) | c-unreadable: fact + never named | C-2 rule 6 |
| HARNESS-122 AC-3 | 3 fixture facts, census with folders absent = `1 / 1 / 0 / 1`, 3 more facts, whole report in order, census unchanged, exit 0 | AC-3, C-4 |
| HARNESS-122 AC-4 | 2 fixture facts, whole report-mode output, whole `--apply` output, `find` listings identical, exits `0|0` | AC-4, C-5 |
| HARNESS-122 AC-5 | the five C-6 lines as whole lines of `--help`, the four rule lines consecutive | AC-5, C-6 |

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

Written by the Test Developer, RED, 2026-11-23. Dispatched on `opus`; resolved
to Opus 5.5 (`claude-opus-5-5`), no override.

**Command.** `bash scripts/selftest.sh tidy` (the suite alone:
`bash .claude/tests/tidy.test.sh`). Wall time on this Windows host: 72-103 s.

**Attested runs (this tree, Windows host, local).**

```
bash scripts/attest.sh -- bash scripts/selftest.sh tidy
exit:     1
last:     1 of 1 harness suite(s) FAILED.
log:      .claude/state/attest-logs/20261123T075701Z.3810162.log

bash scripts/attest.sh -- bash scripts/gates.sh --fast
exit:     0
last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
log:      .claude/state/attest-logs/20261123T075904Z.3817513.log
```

`gates.sh --fast` has nothing to run here (every gate unconfigured), so the
admissibility check is the suite itself plus `check-sigpipe.sh` (0 findings)
and `check-grep-count.sh` (0 findings), both run over this tree, and the other
suites `selftest-needed.sh --suites` selects for this diff: `bash scripts/selftest.sh
selftest shipped-docs sigpipe grep-count` - `4 harness suite(s) passed`, 519
executed, 519 declared (so the `tidy 181` row matches `floors.conf`).

**The failure, verbatim from the log** (the five AC-5 `has_line` failures each
print the whole `--help` text after the needle; that text is today's header and
is cut here to the needle line):

```
  HARNESS-122 AC-1: two stray-shaped folders beside the main checkout are each reported STRAY, with the command to remove them
    FAIL HARNESS-122 AC-1: the whole report is the STRAY pair for each stray-shaped folder, sorted by name, then the unchanged census
         expected:
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac1/s-dirs  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac1\s-dirs' -Recurse -Force
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac1/s-link  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac1\s-link' -Recurse -Force
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         actual:
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         stderr: 

  HARNESS-122 AC-2: a folder that differs from stray-shaped in one fact is never STRAY
    FAIL HARNESS-122 AC-2: AC-1's s-dirs still gets its STRAY pair
         expected: 1
         actual:   0
    FAIL HARNESS-122 AC-2: AC-1's s-link still gets its STRAY pair
         expected: 1
         actual:   0
    FAIL HARNESS-122 AC-2: and those are the only two STRAY lines, in any spelling
         expected: 2
         actual:   0

  HARNESS-122 AC-3: STRAY pairs follow every ORPHAN line and precede every DELETABLE line, and the census does not count them
    FAIL HARNESS-122 AC-3: the whole report is the worktree line, the ORPHAN pair, the two STRAY pairs in LC_ALL=C order, the DELETABLE line, then the census
         expected:
         REMOVABLE C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac3/h3-rm
         ORPHAN C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac3/main/.claude/worktrees/o-h3  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac3\main\.claude\worktrees\o-h3' -Recurse -Force
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac3/Z-dirs  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac3\Z-dirs' -Recurse -Force
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac3/a-link  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac3\a-link' -Recurse -Force
         DELETABLE story/h3-done
         tidy: 1 worktree(s), 1 removable, 0 kept; 1 merged branch(es) deletable
         actual:
         REMOVABLE C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac3/h3-rm
         ORPHAN C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac3/main/.claude/worktrees/o-h3  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac3\main\.claude\worktrees\o-h3' -Recurse -Force
         DELETABLE story/h3-done
         tidy: 1 worktree(s), 1 removable, 0 kept; 1 merged branch(es) deletable
         stderr: 

  HARNESS-122 AC-4: nothing is deleted, in report mode or with --apply
    FAIL HARNESS-122 AC-4: report mode prints the two STRAY pairs, then the census
         expected:
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac4/s-dirs  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac4\s-dirs' -Recurse -Force
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac4/s-link  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac4\s-link' -Recurse -Force
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         actual:
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         stderr: 
    FAIL HARNESS-122 AC-4/C-5: --apply prints the same STRAY pairs and acts on neither
         expected:
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac4/s-dirs  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac4\s-dirs' -Recurse -Force
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.AGu79JmDdf/h122/ac4/s-link  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.AGu79JmDdf\h122\ac4\s-link' -Recurse -Force
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         actual:
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         stderr: 


  HARNESS-122 AC-5: --help states the STRAY rule (Contract C-6)
    FAIL HARNESS-122 AC-5: --help has the whole line: then one STRAY line per folder beside the main checkout that holds no
         expected exactly one line: then one STRAY line per folder beside the main checkout that holds no
         found it 0 time(s) in:
    FAIL HARNESS-122 AC-5: --help has the whole line: regular file and no link that resolves, has no .git, is not a listed
    FAIL HARNESS-122 AC-5: --help has the whole line: worktree, and has a top-level directory this repository ignores, each
    FAIL HARNESS-122 AC-5: --help has the whole line: followed by the command to remove it (printed, never run),
    FAIL HARNESS-122 AC-5: --help has the whole line: A STRAY folder is reported and never removed, with or without --apply.
    FAIL HARNESS-122 AC-5: the four lines of the STRAY rule are consecutive, in C-6's order
         expected: 1
         actual:   0

tidy: 168 passed, 13 failed
FAIL tidy  did 168 units of work, below the floor of 181 in .claude/tests/floors.conf
```

**Why this is the right failure.** Every one of the 13 is a HARNESS-122 pin,
and each fails because tidy has no STRAY scan and no STRAY text: the actual
output in AC-1 and AC-4 is the census line alone (the gap the Context
measured), and in AC-3 it is exactly the expected report with the two STRAY
pairs missing. All 128 HARNESS-066 assertions pass, all 22 HARNESS-122
fixture facts pass (so every fixture is the shape it claims), and the 18
absence controls pass on arrival. No failure is an error, a timeout or a
fixture.

**Counts.** 181 executed on this host = 128 existing + 53 new
(AC-1 6, AC-2 25, AC-3 10, AC-4 6, AC-5 6). On a host where a directory can
be made unreadable (CI's non-root Linux runner) the suite executes 183: the
two rule-6 assertions are inside `if [ "$RO" = 1 ]`. The floor is raised
128 -> 181 (the smaller), in `.claude/tests/floors.conf` with a note and in
`.claude/tests/selftest.test.sh:563`. GREEN must reach `tidy: 181 passed, 0
failed` here, 183 on CI.

**What passes on arrival, and why that is expected.** Today nothing is ever
STRAY, so every absence pin is green before GREEN exists:

- AC-2's 11 "is never named on a STRAY line" assertions (and rule 6's on
  hosts that run it);
- AC-2 (c): `KEEP <c-live>  recent`, today's line, unchanged by design;
- AC-3: the census with the folders absent (`1 / 1 / 0 / 1`), and that the
  census after equals it (C-4);
- AC-3 and AC-1 exit 0; AC-4's identical `find` listings and `0|0` exits.

They are earned by DV-3 at GATES (rule 4 out, (a) must go red) and by the
measurements below; not by anything in RED against the real script.

**Negative controls: expected values.** No assertion has run against a STRAY
implementation, because there is none: these are claims until GREEN confirms
them against the shipped `tidy.sh`. To check that each control discriminates
before handing over, RED built a **scratch candidate outside the repository**
(a copy of `scripts/` and `.claude/` in the session scratchpad, with a 23-line
STRAY loop following C-2's rules in order and the C-6 lines added to the
header; never in the tree, deleted after), ran the suite against it, then
removed one C-2 rule at a time from that scratch copy. Measured, Windows host:

| Candidate | tidy result | Failing assertions |
|---|---|---|
| all six rules | `181 passed, 0 failed` | none - including every HARNESS-066 whole report, so nothing in `$WORK` is stray-shaped |
| rule 1 off (listed worktrees) | `176 passed, 5 failed` | (d) named; only-two-STRAY; and 3 HARNESS-066 AC-5 pins, because the expression also hit the ORPHAN loop's identical `known` line |
| rule 2 off (`.git`) | `179 passed, 2 failed` | (b) the `.git` directory named; only-two-STRAY. (The `.git` *file* case is also a regular file, so rule 4 still holds it; only the `.git` directory isolates rule 2) |
| rule 3 off (ignored top-level dir) | `175 passed, 6 failed` | (f) and (g) named; only-two-STRAY; and HARNESS-066 `C-6: ... a folder outside it are never considered` plus both AC-5 whole reports, because `$WORK/d-outside` (empty) becomes STRAY - the C-8 concern, measured |
| rule 4 off (no regular file) - DV-3's mutation | `179 passed, 2 failed` | (a) named; only-two-STRAY. AC-1 stays green |
| rule 5 off (no resolving link) | `179 passed, 2 failed` | (e) named; only-two-STRAY |
| rule 6 off (`find` exit status) | `181 passed, 0 failed` | none, on this host: the rule-6 fixture is never made here (RO=0). This mutation removed only the `-type f` find's exit check; the candidate's `-type l` find still had `|| continue`, so it was not a full removal of rule 6 even where the fixture exists. Expected on CI with rule 6 fully removed: the rule-6 "never named" assertion and only-two-STRAY go red. Unmeasured - a claim |
| scan disabled (`done <<< ""`) - DV-1's shape | `174 passed, 7 failed` | AC-1 whole report (actual: the census line alone), AC-2 both pairs and only-two-STRAY, AC-3 whole report, AC-4 both whole outputs - all in the HARNESS-122 block, none elsewhere |

GREEN confirms the first row against the shipped script; GATES runs DV-1 and
DV-3 against it, whose expected results are the "scan disabled" and "rule 4 off" rows above.

**Git for Windows link facts** (measured here, recorded in C-8's amendment):
`ln -s` to a missing target fails; `ln -s` to an existing file copies it;
file symlinks are refused without privilege; `MSYS_NO_PATHCONV=1 cmd /c mklink
/J` makes a junction that `find -type l` lists and `[ -L ]` sees, and `[ -e ]`
is false once its target is removed (the dangling fixtures). The resolving
fixture (e) is a file symlink on Linux/macOS and a junction to a directory
here; its fact assertion says which (`to a directory outside the folder`
on this host).

**Rule 6 hosts.** Pinned only where a chmod 000 probe makes `find` fail:
non-root Linux and macOS, so CI. Not under Git for Windows (chmod 000 has no
effect; measured by the probe, RO=0 here), and not as root. Not a skipped test:
where the probe says no, the fixture is never made. The rule-6 fixture
(`c-unreadable/node_modules/a` at 000) has never been run by RED, since this
host cannot make it; its expected value is
`nogit|unlisted|files=0|links=0|resolving=0|top=node_modules|ignored=node_modules|nested=1|unreadable`
and "never named", claims until CI runs them. The cleanup trap
`chmod -R u+rwx`s `$WORK/h122` before it removes anything.

**Export shape the tests pin** (shell, not a module):

- `scripts/tidy.sh`, run as `bash <main>/scripts/tidy.sh [--apply]` from the
  main checkout; options, exit codes and census unchanged (C-7).
- Per STRAY folder, two consecutive lines: `STRAY <P>/<name>  empty` and
  `  remove it: <remove_cmd "<P>/<name>">`, `<P>` being `git worktree list`'s
  first path with its last component dropped. Under Git for Windows the
  command is `Remove-Item -LiteralPath '\\?\C:\...\<name>' -Recurse -Force`.
- Order: worktree lines, ORPHAN pairs, STRAY pairs (`LC_ALL=C` by name:
  `Z-dirs` before `a-link`), DELETABLE lines, census. Same in `--apply`, where
  the census is printed after the (empty) action lines, as today.
- `--help` prints, as whole lines, the four C-6 rule lines consecutively and
  `A STRAY folder is reported and never removed, with or without --apply.`

**Not constrained:** how the parent is enumerated, the shell code of each
rule, the order of rules beyond the output, the wording of header lines around
C-6's, and the line tidy prints for a listed worktree reduced to the stray
shape (AC-2 (d) is only "never STRAY"). Rule 5's no-spawn-per-link and
`find -print -quit` (C-2's cost order) are not timed by any assertion.

**Deferred verifications.** DV-1, DV-2 and DV-3 are declined in RED: each
needs the real STRAY implementation (DV-1 and DV-3 mutate it; DV-2 runs it on
the real parent of the main checkout), which does not exist in this phase.
They belong to GATES. The scratch-candidate table above is a measurement of
the suite, not a substitute for them.

**Files touched.**

- `.claude/tests/tidy.test.sh` - the HARNESS-122 block before `summary`;
  `new_repo` takes an optional origin path; the cleanup trap covers the three
  new mains and restores permissions under `$WORK/h122`.
- `.claude/tests/floors.conf` - `tidy` 128 -> 181, with the note.
- `.claude/tests/selftest.test.sh` - `tidy 128` -> `tidy 181`.
- `docs/backlog/stories/HARNESS-122.md` - C-8 amended (two dated bullets),
  `## Test plan`, this handoff.

**For the implementation.** Use the measured spellings: the parent listing as
the ORPHAN loop does it; `[ -e ]` in the shell over `find -type l`'s output
(one dangling junction is enough to need it); a sed that disables rule 1 must
not also hit the ORPHAN loop's `[ "$known" = 1 ] && continue`, so at GATES
write DV mutations against a line unique to the STRAY loop.

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

### R-1 (no reported fixture has two top-level directories)

- **Adjudicated R-1:** `fable` (resolved claude-fable-5-2), 2026-11-23, diff review round 1, finding 1

**Which test was missing, and what was wrong.** No assertion changed; one
was absent. Every fixture that has to be reported STRAY (`s-dirs`, `s-link`
in h122/ac1 and h122/ac4, `Z-dirs`, `a-link` in h122/ac3) has `node_modules`
as its only top-level directory, because the criteria define a stray-shaped
folder that way. So nothing in `.claude/tests/tidy.test.sh` failed when a
candidate with two or more top-level directories stopped being reported.
That is exactly how the GREEN rule 3 (`5564b85`) went wrong: it passed every
top-level directory to one `git check-ignore -q`, which git refuses with more
than one path (`fatal: --quiet is only valid with a single pathname`, exit
128, hidden by `2>/dev/null`). It also left the suite green if only the first
top-level directory was judged.

**How it was found.** DV-3's first run at GATES found the defect in the
implementation, and GATES fixed it (`cfabd05`, one `check-ignore -q` per
directory). Diff review round 1, finding 1, then showed that the suite stayed
at 183 passed on Linux with the `5564b85` rule 3 put back, and with a
judge-only-the-first loop.

**What it asserts now.** It adds a new describe, "HARNESS-122 C-2 rule 3: a
folder with several top-level directories is STRAY when ANY of them is
ignored, not only the first", after AC-2, with 7 assertions in a parent of
its own, `h122/r3`. It has its own parent because AC-1 and AC-2 name parents
that "hold nothing but what the criterion names", and the criteria's
stray-shaped folder holds the *one* top-level entry `node_modules`. Adding
the fixture there would change what AC-1's whole report and AC-2's "only two
STRAY lines" assert. No existing assertion was touched.
- fixture `h122/r3` holds exactly `main,r3-none,r3-two`;
- fixture `r3-two` is `nogit|unlisted|files=0|links=0|resolving=0|top=aaa,node_modules|ignored=node_modules|nested=3`
  (`h_shape`): `aaa/x` comes before `node_modules/a/b` in glob order, and only
  `node_modules` is ignored;
- fixture `r3-none` is `nogit|unlisted|files=0|links=0|resolving=0|top=aaa,src|ignored=-|nested=2`:
  two directories, neither ignored. This is the control against a
  "two or more directories counts as ignored" shortcut;
- `r3-two` gets its STRAY pair exactly once (`h_pairs_of`, two whole lines);
- no `STRAY ` line names `r3-none` (`h_stray_names`);
- the whole report is `r3-two`'s STRAY pair, then `census 0 0 0 0` (`whole`);
- report mode exits 0.

Count: tidy 181 -> 188 executed on this host (190 on CI, with C-2 rule 6's
two). `floors.conf` and `selftest.test.sh:563` have moved with it.

**What earns it.** The tests pass on arrival against `cfabd05`'s
`scripts/tidy.sh`, so each new assertion that can be red is earned by
mutation, run with `bash scripts/mutate.sh scripts/tidy.sh '<expr>' -- bash
scripts/selftest.sh tidy`, on a Windows host, locally.

(1) The single-call rule 3 put back. The four sed expressions rebuild the
`5564b85` loop line for line: collect `tops`, then make one `check-ignore -q`
over all of them. The one line not rebuilt is `[ ${#tops[@]} -gt 0 ] ||
continue`. Leaving it out changes nothing: `check-ignore -q --` with no path
fails, so the folder is skipped either way. Only the two r3-two assertions go
red. Every other fixture has one top-level directory, so the batched call
still works for them, and that is the gap the finding names.

```
=== mutate: scripts/tidy.sh (4 line(s) changed by s/^  ignored=0$/  tops=()/; s/^    \[ -d "\$d" \] && \[ ! -L "\$d" \] || continue$/    [ -d "$d" ] \&\& [ ! -L "$d" ] \&\& tops+=("${d##*\/}\/")/; /check-ignore -q -- "\${d##\*\/}\/"/d; s/^  \[ "\$ignored" = 1 \] || continue$/  git -C "$MAIN" check-ignore -q -- "${tops[@]}" 2>\/dev\/null || continue/) ===
  204 -   ignored=0
  204 +   tops=()
  206 -     [ -d "$d" ] && [ ! -L "$d" ] || continue
  207 -     if git -C "$MAIN" check-ignore -q -- "${d##*/}/" 2>/dev/null; then ignored=1; break; fi
  206 +     [ -d "$d" ] && [ ! -L "$d" ] && tops+=("${d##*/}/")
  209 -   [ "$ignored" = 1 ] || continue
  208 +   git -C "$MAIN" check-ignore -q -- "${tops[@]}" 2>/dev/null || continue

=== mutate: running bash scripts/selftest.sh tidy ===
  HARNESS-122 C-2 rule 3: a folder with several top-level directories is STRAY when ANY of them is ignored, not only the first
    FAIL HARNESS-122 C-2 rule 3: a folder whose ignored top-level directory is its second, not its first, gets its STRAY pair
         expected: 1
         actual:   0
    FAIL HARNESS-122 C-2 rule 3: the whole report is r3-two's STRAY pair, then the unchanged census
         expected:
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.5d70FnKjSB/h122/r3/r3-two  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.5d70FnKjSB\h122\r3\r3-two' -Recurse -Force
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         actual:
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         stderr: 
tidy: 186 passed, 2 failed
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-122/.claude/state/mutations/scripts_tidy.sh.20261123T172139Z.11692.bak) ===
  204:   ignored=0
  206:     [ -d "$d" ] && [ ! -L "$d" ] || continue
  207:     if git -C "$MAIN" check-ignore -q -- "${d##*/}/" 2>/dev/null; then ignored=1; break; fi
  209:   [ "$ignored" = 1 ] || continue
```

(2) Only the first top-level directory is judged: the loop breaks after the
first directory, whether or not that directory is ignored. The same two
assertions go red, and nothing else does.

```
=== mutate: scripts/tidy.sh (1 line(s) changed by s/then ignored=1; break; fi$/then ignored=1; fi; break/) ===
  207 -     if git -C "$MAIN" check-ignore -q -- "${d##*/}/" 2>/dev/null; then ignored=1; break; fi
  207 +     if git -C "$MAIN" check-ignore -q -- "${d##*/}/" 2>/dev/null; then ignored=1; fi; break

=== mutate: running bash scripts/selftest.sh tidy ===
  HARNESS-122 C-2 rule 3: a folder with several top-level directories is STRAY when ANY of them is ignored, not only the first
    FAIL HARNESS-122 C-2 rule 3: a folder whose ignored top-level directory is its second, not its first, gets its STRAY pair
         expected: 1
         actual:   0
    FAIL HARNESS-122 C-2 rule 3: the whole report is r3-two's STRAY pair, then the unchanged census
         expected:
         STRAY C:/Users/ryanc/AppData/Local/Temp/tmp.4iifnnl91g/h122/r3/r3-two  empty
           remove it: Remove-Item -LiteralPath '\\?\C:\Users\ryanc\AppData\Local\Temp\tmp.4iifnnl91g\h122\r3\r3-two' -Recurse -Force
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         actual:
         tidy: 0 worktree(s), 0 removable, 0 kept; 0 merged branch(es) deletable
         stderr: 
tidy: 186 passed, 2 failed
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-122/.claude/state/mutations/scripts_tidy.sh.20261123T172541Z.17514.bak) ===
  207:     if git -C "$MAIN" check-ignore -q -- "${d##*/}/" 2>/dev/null; then ignored=1; break; fi
```

(3) The `r3-none` control, which is also new against existing code. Every
top-level directory is judged as though it were `node_modules`, so any folder
with a directory counts as ignored. The control goes red. So does AC-2 (f)
(`c-src`), which already pinned the single-directory version, along with AC-2's
STRAY-line count and the r3 whole report. Without the control, the
"two or more directories" shortcut would go unseen. `c-empty` stays green
because it has no directory to judge.

```
=== mutate: scripts/tidy.sh (1 line(s) changed by s/check-ignore -q -- "\${d##\*\/}\/"/check-ignore -q -- "node_modules\/"/) ===
  207 -     if git -C "$MAIN" check-ignore -q -- "${d##*/}/" 2>/dev/null; then ignored=1; break; fi
  207 +     if git -C "$MAIN" check-ignore -q -- "node_modules/" 2>/dev/null; then ignored=1; break; fi
=== mutate: running bash scripts/selftest.sh tidy ===
    FAIL HARNESS-122 AC-2 (f) a folder whose only top-level entry is src, not ignored is never named on a STRAY line
    FAIL HARNESS-122 AC-2: and those are the only two STRAY lines, in any spelling
    FAIL HARNESS-122 C-2 rule 3: a folder with two top-level directories, neither ignored, is never named on a STRAY line
    FAIL HARNESS-122 C-2 rule 3: the whole report is r3-two's STRAY pair, then the unchanged census
tidy: 184 passed, 4 failed
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-122/.claude/state/mutations/scripts_tidy.sh.20261123T173027Z.21982.bak) ===
```

The fixture-fact assertions and the exit-status assertion are preconditions,
and they are green under every mutation, as they should be. Afterwards:

```
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**GREEN is a no-op.** R-1 changes only test paths
(`.claude/tests/tidy.test.sh`, `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh`) and this story file. `scripts/tidy.sh` is
`cfabd05`'s, untouched, and the suite passes against it. The attested run is
below.

## Diff review

### Round 1 (cfabd05, against merge-base 40cb34f)

Reviewer: `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-23; no override. Changed no file in either worktree (checked by the orchestrator, below). Report as returned, its account of its own excursion moved to `## Notes`.

What this change does: `scripts/tidy.sh` now looks at the folders beside the main checkout. It prints a `STRAY` line and a remove command for each one that holds no file, no working link and no `.git`, is not a listed worktree, and has a top-level directory the repository ignores. It never deletes one. The census line, options and exit codes are unchanged.

What I checked: the whole STRAY loop against Contract C-1 to C-8, the worktree and ORPHAN loops, `remove_cmd`, how `MAIN`, `WT_PATH` and `idx` are set, and the one caller (`scripts/phase.sh:200`, which reads only the census). `tidy 181` agrees in `floors.conf` and `selftest.test.sh`, and the latter compares only against `floors.conf`, so CI's 183 passes. **Rule 6 has now run:** on Linux (WSL, non-root), from an exported copy of `cfabd05`, the suite gives `tidy: 183 passed, 0 failed`; with the `|| continue` dropped after both `find` calls it gives 181 passed, 2 failed (the rule-6 assertion, expected 0, actual 1; the STRAY count, expected 2, actual 3). Dropping either `|| continue` alone leaves 183 green, which is not a gap: an unreadable directory fails both `find` calls, so each guard covers the other. Load assumed: one developer machine and the parent `D:/`, with 20 sibling folders holding 164 top-level directories.

**Should fix:**

1. **Nothing fails when a folder with two or more top-level directories stops being reported** (`.claude/tests/tidy.test.sh`, HARNESS-122 block; rule 3 at `scripts/tidy.sh:203-209`)
   - **What this is:** Rule 3, the check that a candidate has a top-level directory the repository ignores. Every fixture that must be reported (`s-dirs`, `s-link`, `Z-dirs`, `a-link`) has `node_modules` as its only top-level directory.
   - **Problem:** With the GREEN tree's rule 3 put back (`tidy.sh` of `5564b85`, one `check-ignore -q` over all directories) the suite stayed at 183 passed on Linux. It also stayed green when only the first top-level directory was judged (`then ignored=1; fi; break`). Directly: a sibling `two/` holding `aaa/x` and `node_modules/a` is reported by the tip script and silently missing with the `5564b85` script.
   - **Fix:** In `.claude/tests/tidy.test.sh`, add a fixture that must be reported and has two top-level directories, with the ignored one not first in glob order (for example `aaa/x` and `node_modules/a/b`). Assert its STRAY pair. Earn it with one mutation that puts the single-call rule 3 back. If the count rises, move the `tidy` floor in `.claude/tests/floors.conf` and the `tidy 181` line in `.claude/tests/selftest.test.sh`.
   - **If we skip it:** The defect GATES just fixed can come back with every test green.
   - **Route:** RED

**Nice to have:**

2. **One git process per top-level directory of every sibling** (`scripts/tidy.sh:205-208`)
   - **What this is:** The GATES fix for rule 3. Contract C-2 says an unrelated sibling costs "a directory listing and one git call".
   - **Problem:** `tidy.sh` took 0.73 s at `40cb34f` and 2.64 s at the tip, with no stray folder present. The cost grows with every folder beside the main checkout, and `phase.sh` runs tidy at every story close.
   - **Fix:** In `scripts/tidy.sh`, collect the names and make one call without `-q`: `git -C "$MAIN" check-ignore -- "${tops[@]}" >/dev/null 2>&1` (measured: exit 0 when any path is ignored, 1 when none). Do it after finding 1's test exists, so the test pins it.
   - **If we skip it:** About two extra seconds per tidy run on this machine.
   - **Route:** GATES

3. **A working link whose name contains a newline is read as dangling** (`scripts/tidy.sh:212-216`)
   - **What this is:** Rule 5, which reads `find -type l` output line by line.
   - **Problem:** On Linux, a folder holding only `node_modules/` and a link named `a<newline>b` pointing at an existing file is reported STRAY.
   - **Fix:** In `scripts/tidy.sh`, read the links NUL-delimited (`find ... -print0` with `read -r -d ''`), keeping the check of `find`'s exit status. Not possible on Windows.
   - **If we skip it:** A contrived folder gets a printed remove command; tidy deletes nothing.
   - **Route:** GATES

Not checked: rule 6 on macOS or as root; the Windows junction fixtures on any host but this one; no mutation in the story worktree itself, only in the Linux copy.

Verdict: fix 1 first.

**Orchestrator's disposition (2026-11-23).** `classify.sh` on every path the fixes name: `harness .claude/tests/tidy.test.sh`, `harness .claude/tests/floors.conf`, `harness .claude/tests/selftest.test.sh`, `harness scripts/tidy.sh`; both phases may write them, so the labels decide. Finding 1 is followed: the story returns to RED as R-1. Findings 2 and 3 are followed in GATES after R-1, by a `feature-developer` dispatch, in that order (2 after 1's test exists, as the reviewer asks), then the gates and a second review round.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-23T17:57:37Z
    commit: d617721 (working tree had uncommitted changes)
    tree:   77a67beea41672943cee8b625ee45ffe8ea1983a
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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
- **PO decision 1 (2026-11-23), AC-2 (e) on Git for Windows.** The user accepted the RED fixture's variant: without the symlink privilege the "link that resolves, its target a file outside the folder" is a junction to a directory outside the folder on Git for Windows, and a file symlink as written on CI's Linux. The rule both exercise is the same (a folder holding any link that resolves is never STRAY), so the criterion's text is unchanged and no `## Amendments` entry is needed. The user's words: "Yes, advance it", answering "Accept the Windows junction variant and advance HARNESS-122 to GREEN?".
- **GREEN -> GATES (2026-11-23, feature-developer, resolved to Opus 5.5, `claude-opus-5-5`, no override).** The STRAY loop is `scripts/tidy.sh` lines 187-219, after the ORPHAN loop. Lines unique to it, for the deferred mutations (the ORPHAN loop's `[ "$known" = 1 ] && continue` is not among them, so a rule-1 sed must use `listed`): rule 1 `[ "$listed" = 1 ] && continue` (:201); rule 4 `[ -z "$anyfile" ] || continue` (:210, DV-3: replace it with `:`); the scan's input `done <<< "$strays"` (:219, DV-1: replace with `done <<< ""`). Rule 3 is one `check-ignore -q` call over every top-level directory of the candidate (`<d>/` each, per the C-8 amendment); rule 5 is a shell `[ -e ]` loop over one `find -type l`; rule 6 is the `|| continue` on each of the two `find`s. `.claude/harness/VERSION` is untouched: C-10 gives the release number to GATES (141 is next on `main` at 40cb34f).
- **GATES fix (2026-11-23, feature-developer, resolved to Opus 5.5, `claude-opus-5-5`, no override): rule 3 never held for a candidate with two or more top-level directories.** Found by the orchestrator during DV-3. The STRAY loop ran one `git -C "$MAIN" check-ignore -q -- "${tops[@]}" 2>/dev/null || continue` over all of a candidate's top-level directories; git refuses `-q` with more than one path (`fatal: --quiet is only valid with a single pathname`, exit 128), and `2>/dev/null` hid it, so e.g. a folder holding only `node_modules/a` and `dist/x` was never reported, contrary to C-2 rule 3. Repro (scratch repo, `.gitignore` = `node_modules/`, `dist/`; siblings `two/{node_modules/a,dist/x}`, `mixed/{src/a,node_modules/b}`, `clean/{src/a,lib/b}`): `git check-ignore -q -- node_modules/ dist/` prints the fatal line, exit 128; the tidy at HEAD reports no STRAY at all; the fixed tidy reports `two` and `mixed` and not `clean`. Fix, as the C-8 amendment spells it: one `git -C "$MAIN" check-ignore -q -- "<d>/"` per top-level directory (not a link), stopping at the first ignored one; rule 3 holds when any one is ignored. The mutation-target lines are unchanged and still unique: `[ "$listed" = 1 ] && continue` (:201), `[ -z "$anyfile" ] || continue` (:211, was :210), `done <<< "$strays"` (:220, was :219). **No test pins a multi-directory candidate**: in `.claude/tests/tidy.test.sh` every fixture that must be reported STRAY (s-dirs, s-link) has the single top-level directory `node_modules`; the fixtures with two (c-file `node_modules,s-inner`, c-gitfile and c-gitdir `.git,node_modules`) are all expected not-STRAY and are kept out by another rule (a file, a `.git`) whatever rule 3 does, which is why the suite stayed green over the defect. For diff review to judge whether that is a test gap to route back to RED.
- **DV-2's probe folder is left for the user (2026-11-23).** `D:/adh-h122-probe` holds four empty directories (`node_modules/a/b`) and nothing else; the orchestrator's `rmdir`, deepest first, was refused by its own safety check for a removal directly under a drive root. Until it is removed, `tidy.sh` reports it STRAY, which is this story working.
- **The round 1 diff reviewer ran commands outside its brief (2026-11-23), by its own report.** To run rule 6 on Linux it used WSL (Ubuntu-24.04, uid 1000), and two commands lost their scratch-directory variable: one extracted an archive of `cfabd05` into the WSL home and made a `git init` and one commit there (it removed the 348 entries and that `.git`); the other ran from the main checkout `/mnt/d/agentic-dev-harness`, applied `sed -i` to `scripts/tidy.sh` (no pattern matched; main has no STRAY code), copied the original back, and ran main's tidy suite four times (128 passed each). Orchestrator's check afterwards: main checkout `git status --short` empty at 40cb34f, no stash; this worktree clean at cfabd05, `mutate.sh --check` clean; the WSL home lists only entries dated before 2026-11-23 plus `.motd_shown`, and no `~/.git`. A reviewer is briefed to change no file; this is recorded so the next brief can say "and run nothing outside this worktree and your scratchpad".
- **GATES, diff review round 1 findings 2 and 3 (2026-11-23, feature-developer, resolved to Opus 5.5, `claude-opus-5-5`, no override).** Finding 2: rule 3 collects the candidate's top-level directories that are not links (`<name>/` each) and makes ONE `git -C "$MAIN" check-ignore -- "${tops[@]}" >/dev/null 2>&1 || continue` without `-q` (exit 0 when any is ignored, 1 when none); a folder with no top-level directory is skipped before git is called (`[ "${#tops[@]}" -gt 0 ] || continue`), so C-2's "a directory listing and one git call" holds again. Finding 3: rule 5 reads links NUL-delimited, `while IFS= read -r -d '' l ... done < <(find "$s" -type l -print0 2>/dev/null || printf '\0')`; rule 6 is kept by the `|| printf '\0'`: a failing `find` appends an empty record, which no path can be, and an empty record sets `live=1`, so the folder is kept (checked directly: `find` over a missing path gives `live=1`). The rule-4 `find -type f ... || continue` is unchanged. Mutation-target lines unchanged and each unique (`grep -c` = 1): `[ "$listed" = 1 ] && continue` (:201), `[ -z "$anyfile" ] || continue` (:212), `done <<< "$strays"` (:222). Scratch repo (`.gitignore` = `node_modules/`), new and HEAD script alike: `two/{aaa/x,node_modules/a}` reported, `clean/{aaa/x,src/y}` not, `empty/` not, `dead/` (node_modules + dangling junction) reported, `live/` (node_modules + resolving junction) not. Timing of `bash scripts/tidy.sh` (report mode) from this worktree, parent `D:/` with 22 entries: HEAD script 2.52-2.94 s (4.32 s cold first run), new 1.11-1.24 s. A link whose name holds a newline cannot be made on Windows, so finding 3 was not reproduced here; it is unverified on this host and rests on the reviewer's Linux reproduction and the `-print0` reading. `tidy: 188 passed, 0 failed`.
