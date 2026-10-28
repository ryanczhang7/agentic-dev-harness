---
id: HARNESS-081
title: A suppression comment added to source in GREEN or GATES is refused unless the story declares it
slug: a-suppression-comment-added-to-source-in
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-081-a-suppression-comment-added-to-source-in
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/harness/rules.md, .claude/harness/VERSION, .claude/skills/story-authoring/reference/sections.md, scripts/new-story.sh, .claude/tests/new-story.test.sh]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

GitHub issue #132. The phase lock freezes test files in GREEN and GATES, and
`check-boundaries.sh` reads every RED commit's manifest diff so that the phase
forbidden from writing production code cannot pull production code in from a
registry. Nothing reads what GREEN and GATES *add* to source. GATES is the
phase whose stated job is making a lint, type or coverage failure go away, and
the cheapest way to do that is a one-line directive that silences the tool:
`// eslint-disable-next-line`, `# noqa`, `# type: ignore`,
`#[allow(dead_code)]`, `/* istanbul ignore next */`, `# pragma: no cover`,
`// Stryker disable next-line`. `rules.md` forbids every one of these in prose
("do not weaken an assertion, add a `skip`, widen a tolerance"), and prose does
not fail a build. A search of `scripts/`, `.claude/hooks/` and
`.claude/harness/` on release 99 finds no mechanical check for any of them.

This is the first of three stories cut from the issue. It builds the per-commit
walk over GREEN and GATES commits, the needle table, and the `## Suppressions`
escape hatch, and covers the two families that are **one-line comment
directives**: lint and type suppressions, and coverage and mutation ignores.
HARNESS-082 adds the stub family (statements, some of them multi-line) to the
same table; HARNESS-083 reads `project.conf` for a loosened gate, which is a
before/after comparison and not a needle at all. Each later story depends on
this one for the walk and the escape hatch.

The check lives in `scripts/check-boundaries.sh`, which CI runs on every PR
(`.github/workflows/boundaries.yml`). The gate that fails if this story's
artifact breaks is the harness's own self-test, `bash scripts/selftest.sh
boundaries`, which CI runs in full; `.claude/tests/floors.conf` carries the
suite's floor and this story raises it in RED.

Three constraints from our own law bind the design, and the Contract spells out
how each is met: it is a rule over the tree, so it owes a probe against a
**real line of the tree** through `scripts/mutate.sh` (DV-2); every needle is
anchored to the comment opener so prose that *mentions* a directive - this
story file, the issue text pasted into a doc, a comment saying "never add
eslint-disable here" - does not trip it; and the files judged are chosen by
`scripts/classify.sh`'s answer, never by a private regex, which is also what
keeps docs and harness paths out of it.

## Acceptance criteria

- **AC-1** — Given a story branch holding a commit whose committed story file
  says `phase: GREEN`, and that commit adds a line
  `// eslint-disable-next-line @typescript-eslint/no-explicit-any` to a file
  `classify.sh` calls `source`, when `bash scripts/check-boundaries.sh main`
  runs, then it exits non-zero and prints one `FAIL` line that names the rule
  id `eslint-disable`, the path, the line number in the committed file, the
  short commit, and the phase `GREEN`. The same commit with the story at
  `phase: GATES` is refused the same way, naming `GATES`.
- **AC-2** — Given one GREEN commit per row of the needle table in the
  Contract (C-2), each adding that row's example line to a `source` file (and,
  for the Dockerfile and Makefile rows, to a file `classify.sh` calls
  `config`), when `check-boundaries.sh` runs, then every row is refused and the
  `FAIL` line carries that row's rule id. *Control, same run shape:* the C-3
  non-matching corpus - a comment that mentions a directive in prose
  (`// never add an eslint-disable here`), a string literal containing one, a
  `Stryker restore` line, `# type: ignore` inside a docstring's prose with no
  `#` opener, `allow` as an identifier (`fn allow(x)`) - is **not** refused:
  no `FAIL` line from this rule, and the rule's `ok` line is printed.
- **AC-3** — Given the AC-1 line added by a commit whose committed story is at
  `phase: RED`, `PLANNED`, `SCAFFOLD`, `REVIEW` or `DONE`, or added by a GREEN
  commit to a path `classify.sh` calls `docs`, `harness` or `test`
  (`docs/backlog/stories/T-1.md`, `scripts/x.sh`, `tests/a.test.ts`), when
  `check-boundaries.sh` runs, then this rule prints no `FAIL` line for it.
- **AC-4** — Given a GREEN commit that *removes* a `# noqa` line from a source
  file, and another GREEN commit that edits the line *next to* an existing
  `#[allow(dead_code)]` so that the directive appears only as diff context,
  when `check-boundaries.sh` runs, then neither is refused: removed lines and
  context lines are never judged, and the rule's `ok` line reports the number
  of commits it judged.
- **AC-5** — Given the AC-1 commit and a working-tree story whose
  `## Suppressions` section holds one line carrying the path, the rule id and
  the words `approved by`, when `check-boundaries.sh` runs, then this rule
  prints `ok` naming the path as declared and no `FAIL` line. *Controls:* an
  entry inside an HTML comment, an entry naming the path but not the rule id,
  one naming both but without `approved by`, and one for a *different* path
  each leave the refusal in place, and the refusal says what the entry must
  carry.
- **AC-6** — Given a branch where a GREEN commit's committed story file cannot
  be read (`git show <c>:docs/backlog/stories/<id>.md` fails because the file
  is absent at that commit), when `check-boundaries.sh` runs, then it prints a
  `note` naming that short commit as not judged, rather than skipping it in
  silence; and given a branch with no GREEN or GATES commit at all, the rule
  prints neither `ok` nor `FAIL` - it says nothing about commits it did not
  look at.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/harness/rules.md`, `.claude/harness/VERSION`, `.claude/skills/story-authoring/reference/sections.md`, `scripts/new-story.sh`, `.claude/tests/new-story.test.sh`

RED may amend any block below in place, with a reason; GREEN builds what the
amended block says.

**C-1. Where it lives, and how it walks.** A new numbered block in
`scripts/check-boundaries.sh`, `# --- 3j. GREEN and GATES add no suppression
---`, placed after 3i and modelled on it line for line: the same
`for c in $(git rev-list "$BASE"..HEAD)` walk, the same committed-phase read
(`git show "$c:$sfile" | sed -nE 's/^phase:[[:space:]]*//p' | head -1`), the
same `classify "$f"` from `lib.sh` for every path in `git diff-tree
--no-commit-id --name-only -r "$c"`. It judges a commit only when the
committed phase is exactly `GREEN` or `GATES`, and a path only when `classify`
answers `source` or `config`. Everything else - `docs`, `harness`, `test`,
`manifest`, `vendor`, `ignored`, `outside` - is out of scope by the
classifier's answer, so a project that reclassifies a path in `paths.conf`
moves it in or out of this rule with no change here. The lines judged are the
**added** lines of `git show --format= --unified=0 "$c" -- "$f"`: lines
beginning with a single `+` that are not the `+++` header, with the new-file
line number carried from the preceding `@@ -a,b +c,d @@` hunk header so the
refusal can name it. Removed lines (`-`) and context lines are never read
(AC-4). A binary file produces no `+` lines and is therefore clean.

Two differences from 3i, both deliberate. (a) 3i skips a commit whose story
file it cannot read by `continue`; this block prints `note "commit <7>: story
file not readable at this commit; GREEN/GATES additions not judged"` and moves
on (AC-6). The issue's floor-guard source distinguishes exit `2` (could not
run) from `0` and `1`; `check-boundaries.sh` has one exit convention,
`exit $fail`, and CI reads only zero or not, so what this block keeps of that
idea is the invariant behind it - a commit this rule could not judge is never
silently counted as clean - rather than the number. A commit whose **phase**
is readable and whose **diff** is not (`git show` of the file fails) is a
`problem`, not a note: the phase says the rule applies and nothing can say the
line is clean. (b) The summary line is `ok    GREEN/GATES added no suppression
(<n> commit(s) judged)` and is printed only when `n > 0`; with no GREEN or
GATES commit on the branch the block prints nothing (AC-6, second half),
because an `ok` over zero commits is the vacuous pass this repository's
documentation exists to warn about.

**C-2. The needle table.** A function `suppression_needles()` in
`check-boundaries.sh` that prints one `<rule id>|<ERE>` line per row, read
with `IFS='|'` so the ERE may itself contain `|` after the first field
(as `evidence` lines in `project.conf` do). Each ERE is anchored on both sides
of the **comment opener** of the language it belongs to: the opener is at the
start of the line or after whitespace (so a `#` or `//` inside a string
literal or a quoted phrase is not an opener), and the directive is the first
thing after it (so a comment that *mentions* a directive in prose is not one).
That is the only position in which the tool honours the directive, so the
anchor costs no true positive. `O` below stands for `(^|[[:space:]])` and is
spelled out in the code. Rows, with the example line AC-2 adds for each:

| rule id | ERE (awk/grep -E dialect, no `{n}` intervals) | example added line |
|---|---|---|
| `eslint-disable` | `O(//\|/\*)[[:space:]]*eslint-disable([[:space:]]\|-next-line\|-line\|$\|\*/)` | `// eslint-disable-next-line @typescript-eslint/no-explicit-any` |
| `ts-ignore` | `O//[[:space:]]*@ts-(ignore\|nocheck\|expect-error)([^A-Za-z-]\|$)` | `// @ts-ignore` |
| `biome-ignore` | `O(//\|/\*)[[:space:]]*biome-ignore[[:space:]]` | `// biome-ignore lint/suspicious/noExplicitAny: legacy` |
| `noqa` | `O#[[:space:]]*noqa([[:space:]:]\|$)` | `x = eval(s)  # noqa: S307` |
| `type-ignore` | `O#[[:space:]]*type:[[:space:]]*ignore([[:space:][]\|$)` | `y = f()  # type: ignore[attr-defined]` |
| `rust-allow` | `O#!?\[(allow\|expect)\(` | `#[allow(dead_code)]` and `#![allow(clippy::all)]` |
| `gd-warning-ignore` | `O@warning_ignore\(` | `@warning_ignore("unused_parameter")` |
| `coverage-ignore` | `O(//\|/\*)[[:space:]]*(istanbul\|c8\|v8)[[:space:]]+ignore([[:space:]]\|$\|\*/)` | `/* istanbul ignore next */` and `// c8 ignore start` |
| `no-cover` | `O#[[:space:]]*pragma:[[:space:]]*no[[:space:]]+(cover\|branch)([^A-Za-z]\|$)` | `def f():  # pragma: no cover` |
| `stryker-disable` | `O(//\|/\*\|#)[[:space:]]*Stryker[[:space:]]+disable([[:space:]]\|$\|\*/)` | `// Stryker disable next-line all` |
| `hadolint-ignore` | `^[[:space:]]*#[[:space:]]*hadolint[[:space:]]+ignore=` | `# hadolint ignore=DL3008` (added to `Dockerfile`, classified `config`) |
| `shellcheck-disable` | `^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+disable=` | `# shellcheck disable=SC2086` (added to `Makefile`, classified `config`) |

`@ts-expect-error` is in the `ts-ignore` row on purpose: it is the same move
with a nicer failure mode, and the escape hatch exists for the case where it
is the right one. `Stryker restore` is not a needle (it ends a disable). A
rule id is one token of `[a-z-]+`, because the `## Suppressions` entry has to
name it on one line (C-4). The table is data: HARNESS-082 appends rows and
changes nothing else in this block.

The matching is in **one awk per file**, reading the `--unified=0` diff on
stdin with the table passed as a file or here-string, never `grep -c` on a
pipe from `git show` (the SIGPIPE shape `check-sigpipe.sh` and
`check-grep-count.sh` refuse). Every refusal is one `problem` line:

    FAIL  story <sid>: commit <7> (<PHASE>) added a suppression to '<path>' line <n> [<rule id>]: <the added line, trimmed>. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.

**C-3. The non-matching corpus RED must carry beside the table** (AC-2's
control), each added by a GREEN commit to a `source` file and each required to
be clean, with the part of the anchor that excludes it: `// never add an
eslint-disable here` (prose after the opener); `const s = "# noqa";` (the `#`
follows `"`, so it is not an opener); `// see rules.md: "# pragma: no cover"
is refused` (same - and the honest hard case, because the directive text is
present verbatim); `// Stryker restore all` (not a needle); `fn allow(x: u32)
-> u32 { x }` and `let expect = 3;` (no `#[`); `// @ts-ignored-thing` (the
`[^A-Za-z-]` guard); a Python docstring line `    Lines ending in type: ignore
are not honoured here.` (no `#`); `url = "http://x/#noqa"` (the `#` follows
`/`). If one of these trips a row, the ERE is wrong, not the corpus: RED
amends C-2 in place and says which case forced it. RED writes both corpora as
one table-driven loop so that a row added by HARNESS-082 inherits both halves.

**C-4. The escape hatch.** A new story section `## Suppressions`, owned by the
Lead PO with the user, validated by 3j the way 3e validates a BLOCKED gate's
`pending CI` line: evidence on **one line** carrying the path, the rule id and
`approved by`, matched case-insensitively after `strip_comments` (an entry
inside an HTML comment is the template, not a declaration), as

    - `src/legacy/parse.ts` [noqa] approved by <who>: <why this line, not a fix>

The declaring line is matched by substring on the path and on `[<rule id>]`
or the bare rule id as a word, and must contain `approved by`; the order of
the three on the line is free. A line that discharges one refusal discharges
every refused line of that path and rule id in the PR - the unit of approval
is "this suppression in this file", not a line number that moves. The section
is read from the **working-tree** story (`$sfile`), as `## Amendments` is, so
a suppression can be declared at REVIEW, where docs are writable. The
refusal for a partial entry says which of the three is missing. `## Suppressions` is added to the story template in `scripts/new-story.sh` (one
heading, one HTML comment, between `## Amendments` and `## Model guidance`),
to `reference/sections.md` under "Lead PO, with the user", and to `rules.md`'s
non-negotiables as the sentence after the "do not weaken an assertion" bullet,
naming the check. `.claude/tests/new-story.test.sh` pins the new heading the
way it pins the others.

**C-5. The self-test.** New `describe` blocks in `.claude/tests/boundaries.test.sh`,
using `story_on_branch` and a `source_story <phase> <path> <line>` helper in
the shape of `manifest_story`: cut a branch, commit the story at `<phase>`,
commit `<line>` appended to `<path>`, run `run_boundaries`, assert through
`refused`/`assert_not_contains` on **both** `$out` and `$rc`. The AC-2
positive and C-3 negative corpora are one loop each over a here-document
table. The fixture tree's `src/main.ts` is `source` and `Dockerfile` is
`config` by the real `paths.conf` the fixture copies, so no classification is
faked. `floors.conf`'s `boundaries` floor is raised in the RED commit that
adds the assertions, to the count RED measures, with the measurement in the
comment above it as HARNESS-062 and -079 did.

**C-6. Oracle partition.** Every criterion is **mechanical**: an exact
message, an exit status, a table row. Nothing is to be invented or calibrated.
The table in C-2 is **settled** as to which rows exist and what their ids are;
RED may tighten an ERE (C-3) and must not drop a row. The one thing RED is
asked to *decide* is the `#`-anchor question in C-3, and it records the
decision as an amendment to C-2.

**C-7. Version and docs.** `.claude/harness/VERSION` bumps to the next
release number (100) in GREEN, as every harness change must (3a-bis).
`rules.md` gains one sentence; no other doc changes in this story.

**C-8. No signature changes.** Nothing exported changes; `section`,
`strip_comments`, `has_content`, `classify` and `problem/ok/note` are used as
they are. No caller list is owed.

**Test-only dependencies:** none. bash, awk, git, coreutils.

## Deferred verifications

**DV-1 (defect put back; the story's central claim; AC-1). Owner: GATES.**
With GREEN's `check-boundaries.sh` in the tree, run
`bash scripts/mutate.sh scripts/check-boundaries.sh '<expr>' -- bash scripts/selftest.sh boundaries`
where `<expr>` narrows the phase test from GREEN-or-GATES to GREEN only (the
exact `sed` depends on how GREEN spells the condition; it is one line). AC-1's
GATES assertion and every GATES row of AC-2 **must** go red; every assertion
outside them stays green. Paste the red lines, the restore line, and a green
run after. RED cannot run this: there is no 3j block to mutate.

**DV-2 (the rule against a real line of the tree; AC-3 and the needle rule).
Owner: GATES.** This repository holds exactly one file `classify.sh` calls
`source` (`.mcp.json.example`) and no `config`, so no fixture can stand in
for the tree this rule judges on a harness PR. The real line is this story's
own: the GREEN commit of this branch adds `docs/backlog/stories/HARNESS-081.md`
lines that quote `# noqa`, `eslint-disable` and `# pragma: no cover` in prose,
and `scripts/check-boundaries.sh` lines that hold every needle. First, run
`GITHUB_HEAD_REF= PR_HEAD_SHA= bash scripts/check-boundaries.sh origin/main`
on this branch at GATES and paste the output: 3j **must** print no `FAIL` and
(because this branch's GREEN commit touched no `source` or `config` path) no
3j `ok` line either. Then, with `mutate.sh` widening the category test in the
real `check-boundaries.sh` so that `docs` is judged alongside `source` and
`config`, the same command **must** refuse this story file by path and line,
naming `noqa` or `eslint-disable` - the real line, under the real rule, with
the only thing changed being the classifier's answer being ignored. Paste
both runs and the restore. That is the probe the law owes a rule over the
tree: it shows the exclusion of docs and harness is the classifier's doing and
not the needles' silence, on lines nobody wrote for the fixture.

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

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-081` from `.claude/harness/models.conf`.
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

- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1** (2026-10-28). The story was cut and the Contract, Deferred verifications and Out of scope written in this dispatch; no override reported.

**Oracle partition:** every criterion is mechanical (an exact message, an exit status, a table row); the needle/finding tables are settled and RED may tighten but not drop a row. See the Contract.

## Out of scope

- **Stubs** (`throw new Error("not implemented")`, `todo!()`,
  `unimplemented!()`, `raise NotImplementedError`, an empty `catch {}`) -
  HARNESS-082. They are statements, two of them multi-line, and need a
  different matcher; the table in C-2 is built so that story appends rows.
- **A gate loosened in `project.conf`** - an `evidence`, `floor`, `covers` or
  `gate` line removed, a floor or a `--fail-under` lowered, `required` turned
  `optional` - HARNESS-083. That is a before/after comparison of one known
  file, which `classify.sh` calls `harness`, and not a needle over added lines.
- **Thresholds in stack configuration** (`vitest.config.*` thresholds, which
  `paths.conf` classifies as `test`; `fail_under` in `pyproject.toml`, which
  is `manifest`; `.coveragerc`). Where they live is per stack and which of
  them are judgeable is an open question put to the user in the planning
  report; nothing here reads them.
- **Lint configuration loosened** (`ignore = [...]` added under
  `[tool.ruff]`, a rule turned `off` in an ESLint config, `#![allow]` moved
  into `Cargo.toml` `[lints]`). Same family as the previous item.
- **The phase lock.** This is CI's after-the-fact check on the commit, as 3i
  is; `phase-guard.sh` sees a path and never a diff, and stays that way.
- **SCAFFOLD, RED, REVIEW and DONE commits**, and `test`-classified files in
  any phase. A test file changed in a GREEN commit is a separate gap in
  `check-boundaries.sh` (nothing refuses it today) and is not this story.
- **Removing or editing existing suppressions**, and suppressions already on
  `main`. Tightening is silent; only an added line is loud.
- **Other ecosystems' directives** - Go's `//nolint`, C#'s `#pragma warning
  disable`, Java's `@SuppressWarnings`. The table covers the stacks
  `stack-profiles` knows (TypeScript, Python, Rust, Godot, static web) plus
  the two `config`-file linters that turn up in every stack's Dockerfile and
  Makefile. A project adds a row for its own stack in the bootstrap story.
- **An exit code `2` for "could not run"** - see C-1(a) for what is kept of
  that idea and why the number is not.

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

