---
id: HARNESS-081
title: A suppression comment added to source in GREEN or GATES is refused unless the story declares it
slug: a-suppression-comment-added-to-source-in
epic: 
type: feature
status: in-progress
phase: GATES
branch: story/HARNESS-081-a-suppression-comment-added-to-source-in
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/harness/rules.md, .claude/harness/VERSION, .claude/skills/story-authoring/reference/sections.md, scripts/new-story.sh, .claude/tests/new-story.test.sh, .claude/tests/selftest.test.sh]
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
  `phase: GATES` is refused the same way, naming `GATES`. The same line added
  by a commit at `phase: REVIEW` whose first parent's committed story is at
  `GATES` is refused the same way, naming `REVIEW, after GATES`. A GREEN
  commit appending three lines whose third is the needle is refused naming
  the third line's number. *(Both sentences added by A-1.)*
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
  `foo();// eslint-disable-line` and `x = eval(s)# noqa` are refused too.
  *(Added by A-1.)*
- **AC-3** — Given the AC-1 line added by a commit whose committed story is at
  `phase: RED`, `PLANNED`, `SCAFFOLD`, `REVIEW` or `DONE` and whose first
  parent's committed story is not at `GREEN` or `GATES` *(qualifier added by
  A-1)*, or added by a GREEN
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
  carry. So do an entry naming the path only after another path
  (`- src/other.ts [noqa] approved by ryan: same as src/main.ts`), an entry
  for `src/main.ts.bak`, and an entry that brackets another rule id and names
  the right one only bare (`- src/main.ts [noqa] approved by ryan: not
  eslint-disable`). *(Added by A-1.)*
- **AC-6** — Given a branch where a GREEN commit's committed story file cannot
  be read (`git show <c>:docs/backlog/stories/<id>.md` fails because the file
  is absent at that commit), when `check-boundaries.sh` runs, then it prints a
  `note` naming that short commit as not judged, rather than skipping it in
  silence; and given a branch with no GREEN or GATES commit at all, the rule
  prints neither `ok` nor `FAIL` - it says nothing about commits it did not
  look at.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/harness/rules.md`, `.claude/harness/VERSION`, `.claude/skills/story-authoring/reference/sections.md`, `scripts/new-story.sh`, `.claude/tests/new-story.test.sh`, `.claude/tests/selftest.test.sh`

*Amended in RED: `.claude/tests/selftest.test.sh` added - it carries the
hand-copied floor table that must move with `floors.conf` in the same commit
(see the comment above the floors). `touches:` does not list it yet; that is
frontmatter, the Lead PO's.*

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

*Amended in RED (test-developer, 2026-10-28), two tightenings the tests pin.*
**A judged commit** is one whose committed phase is `GREEN` or `GATES` **and**
whose `diff-tree` names at least one path `classify` calls `source` or
`config`; `<n>` counts those. A GREEN commit touching only docs, harness or
test paths is not judged and is not counted - DV-2 already depends on this
("this branch's GREEN commit touched no `source` or `config` path, [so] no 3j
`ok` line either"), and AC-3's path case pins it (`(1 commit(s) judged)` on a
branch with three such commits and one clean source commit). **The summary is
printed only when `n > 0` and this block refused nothing**: an `ok ... added
no suppression` beside a `FAIL ... added a suppression` is the "ok and FAIL in
the same run" defect that block 2's `harness state not tracked` comment records. AC-1 and AC-2 pin
its absence beside a refusal. A declared suppression (C-4) is not a refusal,
so the summary may print beside it; the tests do not constrain that either way.
The note in (a) is exactly `note "commit <7>: story file not readable at this
commit; GREEN/GATES additions not judged"`, so the printed line is that text
behind `note`'s two-space indent, pinned as a whole line; a not-judged commit
is neither refused nor counted.

**C-2. The needle table.** A function `suppression_needles()` in
`check-boundaries.sh` that prints one `<rule id>|<ERE>` line per row, read
with `IFS='|'` so the ERE may itself contain `|` after the first field
(as `evidence` lines in `project.conf` do). Each ERE is anchored on both sides
of the **comment opener** of the language it belongs to: the opener is at the
start of the line or after whitespace (so a `#` or `//` inside a string
literal or a quoted phrase is not an opener), and the directive is the first
thing after it (so a comment that *mentions* a directive in prose is not one).
*Corrected in GREEN, return 1, per C-9:* the anchor is a trade, not free. The
opener may also follow `;`, `,`, `)` or `}`, so `foo();// eslint-disable-line`
and `x = eval(s)# noqa` are caught; a directive glued to a closing quote, a
word or digit, `]`, `(` or `{` is still missed although its tool honours it
(`s = "a"# noqa`, `x=1# noqa`, `foo// eslint-disable-line`,
`a[0]// eslint-disable-line`, `fn f(#[allow(unused)] x: u32)`,
`{// eslint-disable-line` - measured, all six missed), because the same
characters are what keep the C-3 string and URL cases clean. `O` below stands
for `(^|[[:space:];,)}])` and is spelled out in the code (it was
`(^|[[:space:]])` before A-1). Rows, with the example line AC-2 adds for each:

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

*Amended in RED (test-developer, 2026-10-28): the C-6 decision, and three
facts the implementation must respect. No ERE changed and no row was dropped.*

- **The `#`-anchor decision: keep `O` = `(^|[[:space:]])` exactly as written.**
  Measured with gawk 5.4.1 (default, `--posix` and `--traditional` all
  agree), reading the twelve rows from a file: every C-2 example line matches
  its own row and no other, and every C-3 line matches no row. But the two
  cases C-6 asked about are **not excluded by `O`**: in `const s = "# noqa";`
  and `url = "http://x/#noqa"` the character after `noqa` is `"`, which the
  `noqa` row's tail `([[:space:]:]|$)` already refuses, so with `O` deleted
  from every row both lines are still clean. The only C-3 line `O` decides is
  `// see rules.md: "# pragma: no cover" is refused` (with `O` deleted it trips
  `no-cover`). So C-3 as written did not test the anchor it was asked about;
  RED added three lines on which only `O` holds (C-3, amended). Measured with
  `O` deleted from the `noqa` and `rust-allow` rows: `const s = "# noqa:
  S307";` and `url = "http://x/#noqa:frag"` trip `noqa`, `msg =
  "#[allow(dead_code)]"` trips `rust-allow`; with `O` present all three are
  clean.
- **Match the added line with its leading `+` removed.** Run against the raw
  diff line (`+// eslint-disable-next-line ...`) the `^` alternative of `O`
  never holds, and 11 of the 14 example lines are missed - every one whose
  directive opens the line (measured). Only the three with code before the
  comment (`noqa`, `type-ignore`, `no-cover`) still match.
- **Pass the table to awk as a file or on stdin, never through `awk -v`.**
  `-v` processes escape sequences: `gawk -v re='#!?\[(allow|expect)\('` warns
  "escape sequence `\[' treated as plain `['" and dies with "invalid regexp:
  unbalanced [" (measured). A table read by `getline`, from a file or a
  here-string, keeps the backslashes.
- **One `FAIL` per added line, not one per matching row.** No example line
  matches two rows, and AC-2's composite assertion counts exactly one refusal
  per added line (28 for 14 rows in GREEN and GATES), so an implementation
  that printed one line per matching row would only differ on lines no test
  holds; first matching row wins is the simplest reading and is what the
  tests are consistent with.

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

*Amended in RED (test-developer, 2026-10-28): three lines added, none removed,
because the parenthetical reasons above are wrong for two of them (see C-2's
amendment).* `const s = "# noqa";` and `url = "http://x/#noqa"` are excluded
by the `noqa` row's **tail** guard (`"` follows `noqa`), not by `O`. The
corpus therefore also carries `const s = "# noqa: S307";`, `url =
"http://x/#noqa:frag"` and `msg = "#[allow(dead_code)]"` - each clean only
because `O` refuses a `#` that follows `"` or `/`. The corpus is 12 lines.

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

*Amended in RED (test-developer, 2026-10-28): the two output lines this block
left unworded, which AC-5 needs exact, and the template comment's one ask.*

- **A declared suppression** prints, once per path and rule id discharged,
  exactly `ok    suppression [<rule id>] in '<path>' is declared in ##
  Suppressions` (one line; it wraps here only).
- **A partial entry** - a line of the comment-stripped `## Suppressions`
  section that contains the refused path but not both of the other two -
  appends one sentence to the end of the C-2 refusal, after its final `.`:
  ` The ## Suppressions line naming '<path>' is missing <X>.` where `<X>` is
  `the rule id [<rule id>]`, `'approved by'`, or `the rule id [<rule id>]
  and 'approved by'` (the path cannot be missing: the line was chosen by it).
  Where no line of the section names the path - an entry for another path, an
  entry inside an HTML comment, an entry outside the section - the refusal is
  the C-2 line exactly, with nothing appended. The first two `<X>` forms are
  pinned; the third is stated so the implementation has one answer.
- **The template's comment** asks for `approved by` in so many words; the
  new-story suite pins that, and that the section body is one HTML comment
  with nothing outside it.

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

*Amended in RED (test-developer, 2026-10-28): how the shape above was met, and
two departures from it, both for a measured reason.* (1) **The fixture story
is `type: spike`, not `story_on_branch`'s feature.** A feature story at REVIEW
needs a `## Gate results` record that only a real `gates.sh` run can write, so
every feature fixture in the suite exits 1 whatever 3j does, and `$rc` could
not distinguish this rule's refusal from 3e's. A spike at REVIEW needs no
record, and its `## Scaffold inventory` names every changed path, so a branch
3j does not refuse exits 0 - asserted as a premise before anything relies on
it. AC-1 is also pinned on a `feature` story by its whole line, so the rule
cannot key on the type. (2) **The two corpora are one branch and one run
each, not one branch per row.** A `check-boundaries.sh` run costs ~3 s on this
host (measured: 3,070 ms on a two-commit branch, 5,895 ms on 21 commits), the
suite already takes 11 min here, and a run per row was 48 runs, 5 min.
Each row is still its own assertion - by its whole `FAIL` line in AC-2, by the
absence of its text from the output in C-3 - and the exit status is pinned
per case in AC-1 and in each AC-5 control. Every AC-2 row is added in GREEN
**and then again in GATES**, because DV-1 needs "every GATES row of AC-2" to
exist. `refused` is not used: its substring needle is weaker than the whole
lines pinned here, and every rc is asserted directly.

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

**C-9. A-1's changes (PO, 2026-10-28; these supersede C-1, C-2 and C-4
where they differ).** RED may amend this block in place with a reason, as it
may every other block; GREEN builds what the amended block says.

- **Which commits are judged (C-1).** A commit is judged when its own
  committed phase is `GREEN` or `GATES`, **or** its first parent's committed
  phase is. The parent's phase is read the same way:
  `git show "$c^:$sfile"`, or nothing when the parent has no story file.
  - The FAIL line's phase field is the commit's own phase when that is
    GREEN or GATES. Otherwise it is `<own>, after <parent's>`, so the
    documented case prints `(REVIEW, after GATES)`.
  - The not-judged `note` still keys on the commit's own story file.
  - A root commit (no `$c^`) has no parent phase.
- **The anchor (C-2).**
  - `O` becomes `(^|[[:space:];,)}])` in every row except `hadolint-ignore`
    and `shellcheck-disable`, which stay anchored to the start of the line.
  - The sentence "the anchor costs no true positive", and the code comment
    that says the same, are replaced with what is true. The anchor trades
    away a directive glued to an identifier or a string (`x=1;"# noqa"` is
    not caught) to keep the C-3 string and URL cases clean, and every known
    miss is named.
  - The two A-1 example lines must be refused, and the C-3 corpus must stay
    clean.
- **What declares a path and a rule (C-4).**
  - *Amended by the PO, return 2 (2026-10-29), from diff review round 2
    finding 1; this supersedes the delimiter list in the next sentence.* A
    token is split on whitespace and backticks only. `,;:()` and the quote
    marks `'` and `"` are then **trimmed from each end** of the token, never
    split inside it. So `app/(auth)/page.tsx` and `lib/(shared)/util.py`
    survive whole, and `(src/main.ts)`, `src/main.ts,` and `'src/main.ts'` (as
    the FAIL line prints it) still declare `src/main.ts`. *Reason:* splitting
    on `()` made a Next.js route-group path impossible to declare, a
    regression from round 1's code, which the orchestrator reproduced. The
    quote marks are round 2's finding 2, on the same line.
  - The path counts only as a **whole token**: delimited by the line's start
    or end, whitespace, a backtick, or one of `,;:()`. It must also be the
    first token on the line that contains a `/`, or appear when no earlier
    token contains one. So `src/main.ts.bak` and a path named after another
    path do not declare it, while `Dockerfile [hadolint-ignore] approved by
    X: see docs/a.md` does.
  - The rule id counts as `[<id>]` anywhere. It counts as a bare word only on
    a line that brackets **no** id. So `[noqa] ... not eslint-disable` does
    not declare `eslint-disable`, and the frozen order-free form
    `Approved By ryan: eslint-disable in src/main.ts, because ...` still
    does.
  - `approved by` and case-insensitivity are unchanged.
  - *Amended in RED, return 1 (test-developer, 2026-10-28).* **The
    partial-entry suffix keys on the same token rule.** C-4 picks the line a
    suffix is about as one that "contains the refused path", which is the
    substring reading this block replaces. A line that does not name the path
    by the whole-token rule above does not name it for the suffix either, and
    gets none - the refusal is the C-2 line exactly. *Reason:* otherwise
    `- src/other.ts [noqa] approved by ryan: same as src/main.ts` would print
    "the ## Suppressions line naming 'src/main.ts' is missing the rule id",
    telling the author to add a rule id to a line this block says can never
    declare `src/main.ts`, and `src/main.ts.bak`'s entry would have no gap to
    name at all. So the four A-1 controls pin: path-after-another-path (with
    `[noqa]` and with `[eslint-disable]`) and `src/main.ts.bak` - no suffix;
    `- src/main.ts [noqa] approved by ryan: not eslint-disable` - ` The ##
    Suppressions line naming 'src/main.ts' is missing the rule id
    [eslint-disable].`
- **The line number (C-1).** Unchanged in behaviour. The A-1 AC-1 case pins
  it for a line that is not first in its hunk, and the new assertion is
  earned by a `mutate.sh` run that deletes `ln++` (the law for a test written
  against existing code).

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

**DV-1 result (GATES, 2026-10-28, orchestrator, tree at 33f25eb).** The
phase test in the real 3j narrowed from GREEN-or-GATES to GREEN only, against
the boundaries suite alone (612 s). Exactly the predicted 18 went red - AC-1's
three GATES assertions, every AC-2 row's GATES whole line, and the AC-2 table
composite - and the other 198 stayed green; RED's prototype m1 predicted the
same 18. Restored and verified; `mutate.sh --check` clean after.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/case "\$ph_at" in GREEN|GATES) ;;/case "$ph_at" in GREEN) ;;/) ===
=== mutate: running bash .claude/tests/boundaries.test.sh ===
    FAIL AC-1 (GATES): the refusal names eslint-disable, src/main.ts, line 2, the commit and GATES
    FAIL AC-1 (GATES): it is the only refusal this rule prints
    FAIL AC-1 (GATES): and the run exits 1, where the same branch without the line exits 0
    FAIL AC-2 [eslint-disable] (GATES): the added line is refused by its whole line, naming eslint-disable
    FAIL AC-2 [ts-ignore] (GATES): the added line is refused by its whole line, naming ts-ignore
    FAIL AC-2 [biome-ignore] (GATES): the added line is refused by its whole line, naming biome-ignore
    FAIL AC-2 [noqa] (GATES): the added line is refused by its whole line, naming noqa
    FAIL AC-2 [type-ignore] (GATES): the added line is refused by its whole line, naming type-ignore
    FAIL AC-2 [rust-allow] (GATES): the added line is refused by its whole line, naming rust-allow
    FAIL AC-2 [rust-allow] (GATES): the added line is refused by its whole line, naming rust-allow
    FAIL AC-2 [gd-warning-ignore] (GATES): the added line is refused by its whole line, naming gd-warning-ignore
    FAIL AC-2 [coverage-ignore] (GATES): the added line is refused by its whole line, naming coverage-ignore
    FAIL AC-2 [coverage-ignore] (GATES): the added line is refused by its whole line, naming coverage-ignore
    FAIL AC-2 [no-cover] (GATES): the added line is refused by its whole line, naming no-cover
    FAIL AC-2 [stryker-disable] (GATES): the added line is refused by its whole line, naming stryker-disable
    FAIL AC-2 [hadolint-ignore] (GATES): the added line is refused by its whole line, naming hadolint-ignore
    FAIL AC-2 [shellcheck-disable] (GATES): the added line is refused by its whole line, naming shellcheck-disable
    FAIL AC-2: the table branch - rc|refusals (one per added line)|summary
boundaries: 198 passed, 18 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261028T23554[...].bak) ===
```

**After Return 2 (GATES, 2026-10-29, orchestrator, tree at 5a66660).**
Return 2 changed only `suppression_declared`, the tokenizer of a
`## Suppressions` line. `git diff b9a664b 5a66660 -- scripts` is 11 lines in
that function and its comment. Neither DV-1 nor DV-1b mutates or depends on
it, so their b9a664b results below stand for this tree and were not re-run.
DV-2's first half was re-run, because it reads the whole of 3j over the real
branch:

    == DV-2 first half on 5a66660
    (3j printed nothing)

**Re-run after Return 1 (GATES, 2026-10-29, orchestrator, tree at b9a664b).**
The walk changed in GREEN (return 1), so DV-1 and DV-2's first half were run
again on the shipped code. The earlier results stay below for history.

- **DV-1**, with the own-phase arm narrowed to GREEN: **19 red**, all of them
  GATES cases. That is AC-1's three, plus the GATES whole line of all 16 AC-2
  rows, including the two A-1 rows.
  - The AC-2 table composite stays green this time. Its GATES commits are
    still judged, through the new parent arm, as `GATES, after GATES`. So the
    count holds while every whole line goes red, which is the claim this
    mutation pins.
- **DV-1b, A-1's defect put back**: the parent-phase arm never matches.
  Exactly the four AC-1 (a) assertions went red, and the other 226 stayed
  green.
- **DV-2's first half**: 3j printed nothing on this branch.
- Every restore was verified, and `mutate.sh --check` came back clean.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/^    GREEN|GATES) ;;$/    GREEN) ;;/) ===
  795 -     GREEN|GATES) ;;
  795 +     GREEN) ;;
    FAIL AC-1 (GATES): the refusal names eslint-disable, src/main.ts, line 2, the commit and GATES
    FAIL AC-1 (GATES): it is the only refusal this rule prints
    FAIL AC-1 (GATES): and the run exits 1, where the same branch without the line exits 0
    FAIL AC-2 [<each of the 16 rows>] (GATES): the added line is refused by its whole line, naming <row>
boundaries: 211 passed, 19 failed
=== mutate: command exited 1; restored (verified byte-for-byte against .../scripts_check-boundaries.sh.20261029T020428Z.1088.bak) ===

=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/case "\$sup_pph" in GREEN|GATES) ph_at=/case "$sup_pph" in NONE) ph_at=/) ===
  800 -        case "$sup_pph" in GREEN|GATES) ph_at="$ph_at, after $sup_pph" ;; *) continue ;; esac ;;
  800 +        case "$sup_pph" in NONE) ph_at="$ph_at, after $sup_pph" ;; *) continue ;; esac ;;
    FAIL AC-1 (REVIEW after GATES): a line committed by the step that sets REVIEW is refused, naming 'REVIEW, after GATES'
    FAIL AC-1 (REVIEW after GATES): rc|refusals|summary - refused once, and nothing calls it clean
    FAIL AC-1 (REVIEW after GREEN): a line committed by the step that sets REVIEW is refused, naming 'REVIEW, after GREEN'
    FAIL AC-1 (REVIEW after GREEN): rc|refusals|summary - refused once, and nothing calls it clean
boundaries: 226 passed, 4 failed
=== mutate: command exited 1; restored (verified byte-for-byte against .../scripts_check-boundaries.sh.20261029T022109Z.24817.bak) ===

##### DV-2 first half (re-run on b9a664b)
(3j printed nothing)
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**DV-2 result (GATES, 2026-10-28, orchestrator, tree at 33f25eb).** First
half, unmutated: `GITHUB_HEAD_REF= PR_HEAD_SHA= bash scripts/check-boundaries.sh
origin/main` printed no 3j line at all - no `FAIL ... added a suppression`, no
`GREEN/GATES added no suppression` summary - and its rc=1 came only from 3b
(phase GATES, not REVIEW) and 3h (this very block, then without a result):

```
ok    story files validated
ok    harness state not tracked
ok    source changes accompanied by test changes (0 source, 0 test)
FAIL  story HARNESS-081 is in phase 'GATES'; a PR should be opened from REVIEW or DONE
ok    branch matches the story's frontmatter
ok    acceptance criteria unchanged since origin/main
ok    ## Handoff is filled in
ok    ## Deferred verifications names the phase that owns each entry
FAIL  story HARNESS-081: ## Deferred verifications has no result and no waiver. [...]
rc=1
```

Second half, the category test widened to judge `docs` through `mutate.sh`:
the same command refused this story file by path and line, under the real
rule, on lines GREEN's `## Notes` added (the controls measurement table) -
three refusals, naming `noqa`, `type-ignore` and `no-cover`. The only change
was the classifier's answer being ignored. Restored and verified:

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/in source|config) sup_paths=/in source|config|docs) sup_paths=/) ===
  758 -     case "$(classify "$f")" in source|config) sup_paths="$sup_paths $f" ;; esac
  758 +     case "$(classify "$f")" in source|config|docs) sup_paths="$sup_paths $f" ;; esac
=== mutate: running env GITHUB_HEAD_REF= PR_HEAD_SHA= bash scripts/check-boundaries.sh origin/main ===
[the same eight lines as above, then:]
FAIL  story HARNESS-081: commit 33f25eb (GREEN) added a suppression to 'docs/backlog/stories/HARNESS-081.md' line 852 [noqa]: 4|noqa|x = eval(s)  # noqa: S307. GREEN and GATES may not silence a tool to reach green; [...]
FAIL  story HARNESS-081: commit 33f25eb (GREEN) added a suppression to 'docs/backlog/stories/HARNESS-081.md' line 853 [type-ignore]: 5|type-ignore|y = f()  # type: ignore[attr-defined]. [...]
FAIL  story HARNESS-081: commit 33f25eb (GREEN) added a suppression to 'docs/backlog/stories/HARNESS-081.md' line 859 [no-cover]: 11|no-cover|def f():  # pragma: no cover. [...]
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261028T235451Z.3990.bak) ===
  758:     case "$(classify "$f")" in source|config) sup_paths="$sup_paths $f" ;; esac
rc=1
```

So docs are excluded by `classify`'s answer and not by the needles' silence.
The three refused lines sit in a `|`-delimited table, which shows the ERE
anchors on the comment opener as C-2 says and not on the start of the line.

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

**A-1 (2026-10-28, approved by the user, "Amend, fix 1/4/5/6"; from diff
review round 1, findings 1, 4, 5 and 6; finding 1 reproduced by the
orchestrator on different inputs, pasted under `## Diff review`).** The other
five findings (2, 3, 7, 8, 9) and 3i's matching hole go to a follow-up story;
nothing here covers them.

- **AC-1** said the line is refused in a GREEN commit and in a GATES commit.
  It now also says: (a) the same line added by a commit whose committed story
  is at `phase: REVIEW`, and whose **first parent's** committed story is at
  `GATES` (or `GREEN`), is refused the same way. Its FAIL line names the phase
  as `REVIEW, after GATES`. That commit is the documented GATES → REVIEW step,
  which sets the phase and only then commits. (b) A GREEN commit appending
  three lines whose third is the needle is refused naming the third line's
  number, not the hunk's first. *Why:* (a) work done in GATES and committed by
  the documented step was never judged; (b) only the first added line of a
  hunk had a pinned number.
- **AC-2** listed the C-2 example lines. It now also requires
  `foo();// eslint-disable-line` (`eslint-disable`) and
  `x = eval(s)# noqa` (`noqa`) to be refused. These are directives the tools
  honour with no space before the comment opener. The C-3 corpus must stay
  clean. *Why:* finding 5; C-2's claim that the anchor "costs no true
  positive" was false.
- **AC-3** said a commit at `RED`, `PLANNED`, `SCAFFOLD`, `REVIEW` or `DONE`
  is not refused. It now says so only when the commit's first parent is also
  not at `GREEN` or `GATES`. *Why:* AC-1 (a).
- **AC-5** said an entry naming the path, the rule id and `approved by`
  discharges the refusal. It adds three controls that must leave the refusal
  in place:
  - an entry `- src/other.ts [noqa] approved by ryan: same as src/main.ts`,
    where the path appears only after another path;
  - an entry for `src/main.ts.bak`;
  - an entry `- src/main.ts [noqa] approved by ryan: not eslint-disable`,
    where the right rule id appears only bare while another id is bracketed.

  The existing AC-5 cases keep their outcome, including the order-free bare
  form `Approved By ryan: eslint-disable in src/main.ts`. *Why:* finding 4:
  one approval could cover a file or a rule it does not name.

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
- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-28), self-reported, no override. Orchestrator's own run of the two suites on 8dc17c8's tree: `boundaries: 168 passed, 48 failed`, `new-story: 53 passed, 5 failed` (575 s); every red assertion is 3j output or the `## Suppressions` heading. `touches:` gained `.claude/tests/selftest.test.sh` (its hand-copied floor table), which RED had to change.
- GREEN - `feature-developer`, planned `opus`, resolved **claude-opus-5-5** (2026-10-28), self-reported; no override was reported to it.
- RED (return 1) - test-developer, planned opus, resolved claude-opus-5-5 (2026-10-28), self-reported; no override was reported to it.
- GREEN (return 1) - feature-developer, planned opus, resolved claude-opus-5-5 (2026-10-28), self-reported; no override was reported to it.
- RED (return 2) - test-developer, planned opus, resolved claude-opus-5-5 (2026-10-29), self-reported; no override was reported to it.
- GREEN (return 2) - feature-developer, planned opus, resolved claude-opus-5-5 (2026-10-29), self-reported; no override was reported to it.

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

One level: **integration**, through the real `scripts/check-boundaries.sh`
copied into `make_project_fixture`'s throwaway repository (real `paths.conf`,
real `lib.sh`, real git history), driven by `run_boundaries`. That is where the
contract lives - a commit walk, a classifier answer and a printed line - and
there is no smaller unit the tests could call without pinning an internal
function name. The template heading is pinned in `new-story.test.sh` against
the real `scripts/new-story.sh` run into a temp root.

`.claude/tests/boundaries.test.sh`, eight new describes at the end of the file
(75 assertions):

| Describe | Assertions | AC |
|---|---|---|
| `...(HARNESS-081): the fixture` | premise: a spike branch whose GREEN commit adds a clean line exits 0 and prints no `FAIL` | (makes every rc below mean 3j) |
| `AC-1: ...` | GREEN and GATES each: the whole `FAIL` line (rule, path, line 2, commit, phase); exactly one refusal from this rule; rc 1; no summary `ok` beside it. Plus the same whole line on a `feature` story | AC-1 |
| `AC-2: every row ...` | one branch, 14 rows x {GREEN, GATES} = 28 commits, one run: each commit's whole `FAIL` line (28); rc 1, 28 refusals, no summary (1) | AC-2 |
| `AC-2 control ...` | one branch, 12 C-3 lines, one GREEN commit each, one run: each line absent from the output (12); rc 0, no `FAIL` at all, summary `(12 commit(s) judged)` (1) | AC-2 control |
| `AC-3: ...` | phases: RED, PLANNED, SCAFFOLD, REVIEW, DONE commits each add the AC-1 line, then a clean GREEN commit: no refusal naming each phase (5); rc 0, no refusal, summary `(1 commit(s) judged)` (1). Paths: GREEN commits add the line to `docs/backlog/stories/T-1.md`, `scripts/x.sh`, `tests/a.test.ts`, then a clean GREEN source commit: no line naming each path (3); rc 0, no refusal, summary `(1 ...)` (1) | AC-3 |
| `AC-4: ...` | a GREEN commit removing a `# noqa` line and one editing the line beside an `#[allow(dead_code)]` (both on main): rc 0, no refusal; summary `(2 commit(s) judged)` as a whole line | AC-4 |
| `AC-5: ...` | the AC-1 branch, story rewritten in the working tree only: a whole entry -> rc 0, no refusal, the declared `ok` line; same with order/case changed and the bare rule id -> rc 0, no refusal, declared `ok`; five controls (HTML comment, no rule id, no `approved by`, other path, entry under `## Notes`) -> rc 1, one refusal, the exact whole refusal line (with the partial-entry sentence where C-4 says), no declared `ok` | AC-5 |
| `AC-6: ...` | a commit with no story file adds the AC-1 line: the whole `note` line naming it; rc 0, no refusal, no summary. A branch with only RED and REVIEW commits: rc 0 and no line containing `GREEN/GATES` or `added a suppression` | AC-6 |

`.claude/tests/new-story.test.sh` (5 assertions): `## Suppressions` added to
the "every section the harness reads by name" list; and a new describe -
exactly one `## Suppressions` heading line; the heading order contains
`## Amendments|## Suppressions|## Model guidance|`; the section body is one
HTML comment with nothing outside it; the comment says `approved by`. Covers
C-4's template clause.

Edges covered beyond the ACs, cheaply: the story type (feature as well as
spike); the declaration read from the working tree, not HEAD (the AC-5 cases
are uncommitted edits); a whole entry outside the section; the three C-3
lines added because the original two string-literal cases did not exercise
the opener anchor (C-2/C-3 amendments); line numbers on files that grow across
commits (AC-2 appends to the same file repeatedly; each expected line number
is read from the committed file).

**Return 1 (A-1), +14 assertions in the same describes** (boundaries 216 -> 230):

| Describe | Assertions | AC |
|---|---|---|
| `AC-1: ...` | parent at GATES, then at GREEN: a story-only commit at that phase, then one commit setting REVIEW and appending the AC-1 line -> its whole `FAIL` line with phase `REVIEW, after <parent>`; rc 1, one refusal, no summary (4). A GREEN commit appending three lines, `// @ts-ignore` third -> the whole line naming line 4; one refusal (2) | AC-1 (a), (b) |
| `AC-2: every row ...` | two rows appended to the table, so +4 whole lines (GREEN, GATES): `foo();// eslint-disable-line` [eslint-disable], `x = eval(s)# noqa` [noqa]. The branch count assertion now expects 32 | AC-2 |
| `AC-3: ...` | unchanged; its REVIEW commit's parent is SCAFFOLD, so it still means what amended AC-3 says (comment in the file) | AC-3 |
| `AC-5: ...` | four controls appended: path after another path with `[noqa]` and with `[eslint-disable]`, `src/main.ts.bak`, `[noqa]` bracketed with the right id bare (4) | AC-5 |

Out of scope and **not** pinned: stubs (HARNESS-082), `project.conf` (HARNESS-083),
other ecosystems' directives, suppressions on main (AC-4 relies on main
holding two and on their not being judged, which is the cheap half of that
non-goal).

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

Written by `test-developer`, declared `opus`; this session ran as
**claude-opus-5-5**, dispatched with no model override that I was told of.

**Commands.**

    bash .claude/tests/boundaries.test.sh      # the 3j describes are the last eight
    bash .claude/tests/new-story.test.sh
    bash scripts/selftest.sh boundaries        # the same, with the floor arithmetic
    bash scripts/selftest.sh new-story

`boundaries.test.sh` takes ~11 min on this host under load (it took 11m05s
before this story, with 141 assertions); the new block adds 18
`check-boundaries.sh` runs at ~3 s each. Both timings are local.

**The red, verbatim (abridged only where marked).**

```
  AC-1: a suppression added in GREEN or GATES is refused, by path, line, commit and phase
    FAIL AC-1 (GREEN): the refusal names eslint-disable, src/main.ts, line 2, the commit and GREEN
         expected: 1
         actual:   0
    FAIL AC-1 (GREEN): it is the only refusal this rule prints
         expected: 1
         actual:   0
    FAIL AC-1 (GREEN): and the run exits 1, where the same branch without the line exits 0
         expected: 1
         actual:   0
    [the same three for GATES]
    FAIL AC-1: a feature story's GREEN commit is refused by the same whole line
         expected: 1
         actual:   0

  AC-2: every row of the needle table is refused by its rule id, in GREEN and in GATES
    FAIL AC-2 [eslint-disable] (GREEN): the added line is refused by its whole line, naming eslint-disable
         expected: 1
         actual:   0
    [27 more, one per row and phase, same shape]
    FAIL AC-2: the table branch - rc|refusals (one per added line)|summary
         expected: 1|28|0
         actual:   0|0|0

  AC-2 control: a line that only mentions a directive is clean (C-3)
    FAIL AC-2 control: the corpus branch - rc|refusals|summary(12)
         expected: 0||1
         actual:   0||0

  AC-3: other phases, and docs, harness and test paths, are not judged
    FAIL AC-3: across those phases - rc|refusals|summary(1)
         expected: 0||1
         actual:   0||0
    FAIL AC-3: across those paths - rc|refusals|summary(1)
         expected: 0||1
         actual:   0||0

  AC-4: removed lines and context lines are never judged
    FAIL AC-4: and the summary counts the two GREEN commits it judged
         expected: 1
         actual:   0

  AC-5: a suppression declared in ## Suppressions is accepted, and only a whole declaration
    FAIL AC-5: and the rule says the path is declared
         expected: 1
         actual:   0
    FAIL AC-5: the three in another order, other case, rule id bare - rc|refusals|declared
         expected: 0||1
         actual:   0||0
    FAIL AC-5 control, an entry inside an HTML comment: still refused, by the whole line - rc|refusals|line|declared
         expected: 1|1|1|0
         actual:   0|0|0|0
    [the same for: no rule id; no approved by; a different path; an entry outside ## Suppressions]

  AC-6: a commit the rule could not judge is said out loud; no judged commit, nothing said
    FAIL AC-6: the commit with no readable story file is named as not judged
         expected: 1
         actual:   0

boundaries: 168 passed, 48 failed

=== boundaries ===   (bash scripts/selftest.sh boundaries)
boundaries: 168 passed, 48 failed
FAIL boundaries  did 168 units of work, below the floor of 216 in .claude/tests/floors.conf

  a new story carries ## Suppressions, between ## Amendments and ## Model guidance (HARNESS-081, C-4)
    FAIL the generated story has exactly one ## Suppressions heading line
         expected: 1
         actual:   0
    FAIL it sits between ## Amendments and ## Model guidance, with nothing between
         expected to contain: ## Amendments|## Suppressions|## Model guidance|
         actual:               ## Context|## Acceptance criteria|## Contract|## Deferred verifications|## Amendments|## Model guidance|## Out of scope|...
    FAIL its body is one HTML comment and nothing outside it
         expected: comment|
         actual:   none|
    FAIL and the comment asks for 'approved by', which 3j requires on the line
    [and "has ## Suppressions" in the heading list]
new-story: 53 passed, 5 failed
FAIL new-story  did 53 units of work, below the floor of 58 in .claude/tests/floors.conf
```

**Why this is the right failure.** Every one of the 48 is a 3j output that
does not exist yet: a missing whole `FAIL` line, a missing `ok` summary, a
missing `note`, or rc 0 where 3j's refusal is the only thing that can make it 1.
Nothing failed on a fixture error: the premise assertion (a spike branch with a
clean GREEN line exits 0 and prints no `FAIL`) passes, all 141 pre-existing
assertions pass, and the identical suite passed **75 of 75** against a scratch
3j written outside the tree to check the tests are satisfiable (see below). The
five new-story reds are the missing template heading and nothing else.

**Files touched.**

- `.claude/tests/boundaries.test.sh` - eight describes before `summary`, AC-1..AC-6 (table in `## Test plan`).
- `.claude/tests/new-story.test.sh` - `## Suppressions` in the heading list, and one describe; C-4's template clause.
- `.claude/tests/floors.conf` - boundaries 136 -> 216, new-story 53 -> 58, measurement comment at the end.
- `.claude/tests/selftest.test.sh` - the hand-copied floor table, the same two numbers (the selftest suite fails otherwise). Not in `touches:`; added to the Contract's `**Writes:**`.
- this story: `## Contract` amendments (C-1 b, C-2, C-3, C-4, C-5, the Writes line), `## Test plan`, this handoff.

**What the tests pin about 3j's output - exact, not suggested.** There is no
function to import; the interface is the lines `check-boundaries.sh` prints and
its exit status. `<7>` is the first seven characters of the full commit hash
(the tests compute `${c:0:7}`, as 3i prints `${c%${c#???????}}`); the fixture
story id is `T-1`.

1. Refusal, one per added line that matches a row (first row wins), printed through `problem` (so `FAIL  ` and `fail=1`):
   `FAIL  story T-1: commit <7> (<GREEN|GATES>) added a suppression to '<path>' line <n> [<rule id>]: <added line, leading and trailing whitespace trimmed, internal whitespace kept>. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.`
   `<n>` is the new-file line number from the hunk header (line 2 for a line appended to a one-line file; the AC-2 rows append repeatedly to the same files and every expected number is read from the committed file).
2. Partial entry suffix, appended directly after that final `.`: ` The ## Suppressions line naming '<path>' is missing the rule id [<rule id>].` or ` The ## Suppressions line naming '<path>' is missing 'approved by'.` Nothing appended when no comment-stripped line of the section names the path.
3. Declared: `ok    suppression [<rule id>] in '<path>' is declared in ## Suppressions`, exactly once for one declared line; rc unaffected.
4. Summary: `ok    GREEN/GATES added no suppression (<n> commit(s) judged)`, only when n > 0 **and** 3j refused nothing; `<n>` counts GREEN/GATES commits touching at least one `source`/`config` path (AC-3 paths: three docs/harness/test-only GREEN commits plus one source commit -> `1`; AC-4 -> `2`; C-3 corpus -> `12`).
5. Not judged: the line `  commit <7>: story file not readable at this commit; GREEN/GATES additions not judged` (that is `note "commit <7>: ..."`), not a refusal, not counted.
6. Silence: on a branch with no GREEN/GATES commit, no output line contains `GREEN/GATES` or `added a suppression`.
7. The `## Suppressions` section is read from the working-tree story file (`$sfile`), comment-stripped, matched case-insensitively; the path by substring; the rule id as `[<id>]` or as a bare word (the order-free case writes `eslint-disable in src/main.ts`); `approved by` anywhere on the line.
8. Template: exactly one `## Suppressions` line in a generated story, directly between `## Amendments` and `## Model guidance`, body = one HTML comment containing the words `approved by`, nothing outside it.

**What the tests do NOT constrain.** The function names (`suppression_needles`
is the Contract's, but no test calls it); how the table reaches awk, beyond
"not `-v`" (below); whether the summary line prints beside a declared
suppression; the third partial-entry form (`... the rule id [<id>] and
'approved by'.`); behaviour when one line matches two rows (no test line does);
the order of 3j's lines among themselves; anything about merge commits; how a
binary file is handled (C-1 says it has no `+` lines); the `problem` C-1 asks
for when a readable-phase commit's diff cannot be shown (no fixture can make
`git show` fail on an existing commit cheaply - unpinned, say so in GATES if it
matters).

**Passed on arrival (27 of the 75), and what earns each.** All are the
*absence* halves of a case whose *presence* half is red today, plus the
fixture premise:

| Assertion(s) | Count | Earned by |
|---|---|---|
| fixture premise (spike branch exits 0, no FAIL) | 1 | a claim about the fixture, not 3j; it is what makes every rc half discriminate. Its converse is shown by AC-1's rc going red today |
| AC-1 "no summary beside the refusal" (GREEN, GATES) | 2 | m7 below: summary printed whenever n > 0 turns both red |
| C-3 per-line "not refused" | 12 | m3 below turns the three RED-added lines red; the other nine are earned only by the ERE measurements in the controls table (no scratch mutation run per row) |
| AC-3 per-phase "not refused" | 5 | m5 below: judge every phase turns all five red |
| AC-3 per-path "not refused" | 3 | m6 below: judge every category turns all three red (DV-2 is the same probe on the real tree, GATES') |
| AC-4 rc/refusals | 1 | not mutated here: a 3j reading `-` lines or context would be needed; owed only if the orchestrator wants it |
| AC-5 declared rc/refusals | 1 | m4 below |
| AC-6 note case rc/refusals/summary | 1 | m2 below |
| AC-6 silence on a branch with no GREEN/GATES commit | 1 | m2 (`-gt 0` -> `-ge 0`) and m5 below |

**Negative controls, measured outside the framework.** The ERE table was run
through gawk 5.4.1 from a file (`NR == FNR` table read, `$0 ~ re[k]`), not
through the suite, so these are claims about the C-2 EREs until GREEN's
`suppression_needles` is measured:

| Control | Threshold | Measured with C-2's EREs | Measured with the defect |
|---|---|---|---|
| 14 example lines, each matches exactly its own row | 14/14 | 14/14 (default, `--posix`, `--traditional`) | raw `+` line: 3/14 match |
| 12 C-3 lines match no row | 0 matches | 0 | `O` deleted from every row: 1 (`// see rules.md: "# pragma: no cover"` -> `no-cover`); `O` deleted from `noqa` and `rust-allow`: 3 (the three RED-added lines); `[[:space:]]*` before the directive loosened to `.*`: 1 (`// never add an eslint-disable here`) |
| `awk -v` carrying an ERE | must not be used | - | `fatal: invalid regexp: unbalanced [` |

**The suite against a scratch 3j.** To check the tests are satisfiable and that
the absence assertions discriminate, a prototype 3j was appended to a *copy* of
`check-boundaries.sh` in the session scratch directory and swapped into a
driver's fixture (never into this tree). 75 of 75 passed against it. Four
mutations of that copy, one run each:

    m1 phase test GREEN|GATES -> GREEN       boundaries-3j: 57 passed, 18 failed
       (AC-1 GATES x3, every AC-2 (GATES) whole line x14, the AC-2 branch composite)
    m2 summary guard -gt 0 -> -ge 0          boundaries-3j: 73 passed, 2 failed
       FAIL AC-6: and it is neither refused nor counted - rc|refusals|summary
       FAIL AC-6: a branch with only RED and REVIEW commits - rc|anything from this rule
    m3 O dropped from the noqa and rust-allow rows   boundaries-3j: 71 passed, 4 failed
       FAIL AC-2 control: 'const s = "# noqa: S307";' in src/app.py is not refused
       FAIL AC-2 control: 'url = "http://x/#noqa:frag"' in src/app.py is not refused
       FAIL AC-2 control: 'msg = "#[allow(dead_code)]"' in src/lib.rs is not refused
       FAIL AC-2 control: the corpus branch - rc|refusals|summary(12)
    m4 ## Suppressions read from HEAD, not the working tree   boundaries-3j: 70 passed, 5 failed
       FAIL AC-5: a declared suppression - rc|refusals
       FAIL AC-5: and the rule says the path is declared
       FAIL AC-5: the three in another order, other case, rule id bare - rc|refusals|declared
       FAIL AC-5 control, an entry naming the path but not the rule id: ...
       FAIL AC-5 control, an entry naming path and rule id without approved by: ...
    m5 phase test GREEN|GATES -> any phase   boundaries-3j: 68 passed, 7 failed
       FAIL AC-3: the AC-1 line added in a RED commit is not refused
       [the same for PLANNED, SCAFFOLD, REVIEW, DONE]
       FAIL AC-3: across those phases - rc|refusals|summary(1)
       FAIL AC-6: a branch with only RED and REVIEW commits - rc|anything from this rule
    m6 category test source|config -> any category   boundaries-3j: 71 passed, 4 failed
       FAIL AC-3: the AC-1 line added to docs/backlog/stories/T-1.md (docs) in GREEN is not refused
       FAIL AC-3: the AC-1 line added to scripts/x.sh (harness) in GREEN is not refused
       FAIL AC-3: the AC-1 line added to tests/a.test.ts (test) in GREEN is not refused
       FAIL AC-3: across those paths - rc|refusals|summary(1)
    m7 summary guard drops "and refused nothing"   boundaries-3j: 72 passed, 3 failed
       FAIL AC-1 (GREEN): and no summary line claims the commit was clean beside the refusal
       FAIL AC-1 (GATES): and no summary line claims the commit was clean beside the refusal
       FAIL AC-2: the table branch - rc|refusals (one per added line)|summary

These are measurements of a prototype, not of the shipped block: GREEN's 3j is
what the gates judge, and confirming that the same assertions go red against
*it* is DV-1's and DV-2's job.

**Deferred verifications: declined.** DV-1 (narrow the phase test in the real
3j, watch AC-1 GATES and every AC-2 GATES whole line go red) and DV-2 (run the
real `check-boundaries.sh` on this branch, then widen its category test to
judge `docs`) are both `Owner: GATES`, and both mutate a block that does not
exist in RED. I cannot run either and have not. m1 above is the shape DV-1
should reproduce: 18 reds, all GATES.

**Discovered, and changes the approach.**

- **Strip the leading `+` before matching** (C-2 amendment). On the raw diff
  line 11 of 14 example rows never match, because `O`'s `^` sees the `+`.
- **No `awk -v` for the table** (C-2 amendment). `getline` from a file or
  here-string keeps the backslashes; `-v` does not.
- **Skip the diff's file header, not every line beginning `+++`.** Only lines
  after the first `@@` are added lines; a test file never adds `++...`, so this
  is unpinned, but `/^\+\+\+/ { next }` would drop an added `++x` line.
- **"Judged" means touched a source or config path** (C-1 b amendment), or
  AC-3's path case and DV-2 both fail.
- **The summary must not print beside a refusal** (C-1 b amendment); AC-1 and
  AC-2 pin its absence.
- **The fixture stories are spikes on purpose** (C-5 amendment); do not read
  `type` in 3j - AC-1 pins a feature story too.
- `classify` is per path and costs a subprocess; the AC-2 branch has 28 judged
  commits and one run, so a 3j that spawned per *line* rather than per *file*
  would show up as wall time in this suite before anywhere else.
- **Earning still open, at the orchestrator's choice:** AC-4's rc/refusals
  half (no scratch mutation reads removed or context lines), and nine of the
  twelve C-3 per-line assertions, which rest on the ERE measurements rather
  than on a mutation of a running 3j. Every other on-arrival pass is earned by
  m2-m7 against the prototype - claims about the shipped block until GREEN.
- `bash scripts/selftest.sh selftest` is green with the new floor table
  (`selftest: 268 passed, 0 failed`); `check-sigpipe.sh` (56 files, 0
  findings) and `check-grep-count.sh` (56 files, 0 findings) are clean;
  `gates.sh --fast` reports every gate UNCONFIGURED, as on every harness
  story (BOOTSTRAPPED=no), so the test gates do not judge these suites -
  `selftest.sh` does.

### Return 1 addendum (RED from GATES, A-1; test-developer, 2026-10-28)

**Command:** `bash .claude/tests/boundaries.test.sh` (~11 min on this host,
local). Only that file changed among the suites; `floors.conf` and
`selftest.test.sh`'s copied table now say `boundaries 230`.

**Red run, on 5f76df2's source (GREEN's 3j) with the new tests:**

    AC-1: a suppression added in GREEN or GATES is refused, by path, line, commit and phase
      FAIL AC-1 (REVIEW after GATES): a line committed by the step that sets REVIEW is refused, naming 'REVIEW, after GATES'
           expected: 1
           actual:   0
      FAIL AC-1 (REVIEW after GATES): rc|refusals|summary - refused once, and nothing calls it clean
           expected: 1|1|0
           actual:   0|0|0
      FAIL AC-1 (REVIEW after GREEN): a line committed by the step that sets REVIEW is refused, naming 'REVIEW, after GREEN'
           expected: 1
           actual:   0
      FAIL AC-1 (REVIEW after GREEN): rc|refusals|summary - refused once, and nothing calls it clean
           expected: 1|1|0
           actual:   0|0|0
    AC-2: every row of the needle table is refused by its rule id, in GREEN and in GATES
      FAIL AC-2 [eslint-disable] (GREEN): the added line is refused by its whole line, naming eslint-disable
      FAIL AC-2 [eslint-disable] (GATES): the added line is refused by its whole line, naming eslint-disable
      FAIL AC-2 [noqa] (GREEN): the added line is refused by its whole line, naming noqa
      FAIL AC-2 [noqa] (GATES): the added line is refused by its whole line, naming noqa
           (each: expected: 1  actual: 0)
      FAIL AC-2: the table branch - rc|refusals (one per added line)|summary
           expected: 1|32|0
           actual:   1|28|0
    AC-5: a suppression declared in ## Suppressions is accepted, and only a whole declaration
      FAIL AC-5 control, the path only after another path (A-1): still refused, by the whole line - rc|refusals|line|declared
           expected: 1|1|1|0
           actual:   1|1|0|0
      FAIL AC-5 control, the path only after another path, right rule id (A-1): still refused, by the whole line - rc|refusals|line|declared
           expected: 1|1|1|0
           actual:   0|0|0|1
      FAIL AC-5 control, an entry for src/main.ts.bak (A-1): still refused, by the whole line - rc|refusals|line|declared
           expected: 1|1|1|0
           actual:   0|0|0|1
      FAIL AC-5 control, another id bracketed, the right one only bare (A-1): still refused, by the whole line - rc|refusals|line|declared
           expected: 1|1|1|0
           actual:   0|0|0|1
    boundaries: 217 passed, 13 failed

**Why each is the right failure.**

- REVIEW after GATES/GREEN: `0|0|0` - 3j skipped the commit on its own phase
  (finding 1, reproduced). Not a fixture fault: rc 0 means nothing else
  objected either.
- AC-2's two rows: no refusal at all - the anchor is `[[:space:]]` only
  (finding 5). The count assertion is pre-existing; it reads `${#ac2_want[@]}`,
  so it moved to 32 with the rows, and 28 is today's 3j.
- AC-5: three of the four are **discharged** today (`0|0|0|1`: rc 0, the
  declared `ok`) - the substring path match and the bare id beside a bracketed
  one (finding 4). The first (`[noqa]` after `src/other.ts`) is refused today,
  but with the wrong suffix: today's 3j reads the line as naming `src/main.ts`
  and appends "is missing the rule id"; C-9 (amended) says no suffix. That one
  row alone could not catch finding 4, because `[noqa]` does not match the
  refused rule anyway - which is why the `[eslint-disable]` variant is there:
  it is the same AC-5 control ("an entry naming the path only after another
  path") with the one id that would discharge it, and today it does.
- Every pre-existing assertion is green (217 = 216 old minus AC-2's count +
  the 2 on-arrival new ones).

**Exact lines pinned (whole lines, via `want_3j`/`SUP_TAIL`):**

- `FAIL  story T-1: commit <c7> (REVIEW, after GATES) added a suppression to 'src/main.ts' line 2 [eslint-disable]: // eslint-disable-next-line @typescript-eslint/no-explicit-any. GREEN and GATES may not silence ...` - and the same with `(REVIEW, after GREEN)`. `<c7>` is the REVIEW commit.
- `FAIL  story T-1: commit <c7> (GREEN) added a suppression to 'src/main.ts' line 4 [ts-ignore]: // @ts-ignore. GREEN and GATES ...`
- `... [eslint-disable]: foo();// eslint-disable-line. GREEN and GATES ...` and `... 'src/app.py' line <n> [noqa]: x = eval(s)# noqa. GREEN and GATES ...`, in GREEN and in GATES.
- AC-5: the C-2 line with no suffix for the two path-after-path rows and the
  `.bak` row; with ` The ## Suppressions line naming 'src/main.ts' is missing the rule id [eslint-disable].` for `- src/main.ts [noqa] approved by ryan: not eslint-disable`.

**Not constrained:** how the parent's phase is read (C-9 says `git show
"$c^:$sfile"`, but only the output is pinned); a root commit's behaviour; a
merge commit's parent choice; the anchor for `/*`-only rows beyond the two
example lines; how the token rule is coded; what a REVIEW commit whose parent
is RED prints (AC-3's existing case pins that it is clean only alongside
other phases). The `note` for an unreadable story is unchanged and still pinned
by AC-6.

**Passed on arrival:** the two third-line-number assertions. Earned by
`mutate.sh` deleting `ln++` for an added line - output in `## Regressions`,
Return 1.

**Negative controls:** none new with a threshold; every case is mechanical.
The C-3 corpus is untouched (12 lines) and stayed clean in the red run
(`AC-2 control` describe: no FAIL). GREEN's widened anchor must keep it so.

### Return 2 addendum (RED from GATES, diff review round 2; test-developer, 2026-10-29)

**Command:** `bash .claude/tests/boundaries.test.sh` (14m03s locally on this
host). Floor: `boundaries 236` in `floors.conf` and in `selftest.test.sh`'s
copied table. `bash scripts/selftest.sh selftest` reports 268 passed, 0 failed.
The verbatim red is under `## Regressions`, `### Return 2`. In summary:
`boundaries: 230 passed, 6 failed`, and the 6 are the new assertions.

**Added cases (AC-5 describe, each 2 assertions, rc|refusals = `0|` and one whole line):**

- `- 'src/main.ts' [eslint-disable] approved by ryan: copied from the refusal`.
  This runs on the existing src/main.ts branch, after the order-free case. It
  pins `ok    suppression [eslint-disable] in 'src/main.ts' is declared in ## Suppressions`.
- ``- `app/(auth)/page.tsx` [eslint-disable] approved by ryan: route group``
  and the same line bare. These run on a new branch built by
  `source_story GREEN 'app/(auth)/page.tsx' "$AC1_LINE"`, placed after the
  control table. They pin `ok    suppression [eslint-disable] in 'app/(auth)/page.tsx' is declared in ## Suppressions`.

`ac5` now takes the inventory path from `$ac5_path`. It defaults to
`src/main.ts`, is set to the route-group path for the two new cases, and is
reset afterwards. Every pre-existing case therefore runs exactly as before.

**Checked outside the suite, scratch only, not source.** I fed the entries to
today's `suppression_declared` and to a candidate built to amended C-9: split
on `[[:space:]`]+`, then trim `,;:()'"` from both ends of each token.

    entry                                                       today   candidate
    - `app/(auth)/page.tsx` [eslint-disable] approved by ...    []      declared
    - app/(auth)/page.tsx [eslint-disable] approved by ...      []      declared
    - 'src/main.ts' [eslint-disable] approved by ...            []      declared
    - src/other.ts [eslint-disable] ... same as src/main.ts     []      []
    - `src/main.ts.bak` [eslint-disable] ...                    []      []
    - (src/main.ts) [eslint-disable] ...                        declared declared

The candidate keeps the A-1 controls in place. It is evidence that the needles
can be reached, not a design. GREEN must confirm both under the shipped code.

**Not constrained:** how the trim is coded, and whether a double-quoted path
(`"src/main.ts"`) declares. C-9 says it does, but no case pins it. Also not
pinned: paths with `[` `]`, or with glob characters. Round 2 notes that
`for f in $(...)` globs, and that is deferred.

**Passed on arrival:** none. All six new assertions are red.
**Negative controls:** none new. The four A-1 controls keep their outcomes in
the red run.

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

### Return 1: GATES → RED (2026-10-28), from diff review round 1

- **Which tests, and what was wrong.**
  - The AC-3 phase cases asserted that a REVIEW commit is never judged. That
    is the hole in finding 1: the documented GATES → REVIEW commit can carry
    GATES work.
  - No test pinned the number of a hunk's non-first added line (finding 6).
  - No test covered a directive with no space before its opener (finding 5).
  - No test covered a `## Suppressions` entry that names the path or the
    rule id in the wrong place (finding 4).
- **How it was found.** A fresh `feature-developer` diff review at
  GATES → REVIEW. Finding 1 was reproduced by the orchestrator in a clone,
  with output under `## Diff review`. The user approved A-1.
- **What they assert now.** The A-1 criteria and C-9. The source changes for
  findings 1, 4 and 5 follow in GREEN. Finding 6's assertion passes against
  today's code and is earned by a mutation of `ln++` (output to follow
  below).
- **The red, on 5f76df2's source with the new tests** (test-developer, local
  run, 2026-10-28; `bash .claude/tests/boundaries.test.sh`). 13 reds: the 12
  new A-1 assertions for findings 1, 4 and 5, plus AC-2's table-branch count,
  which reads the row count and now expects 32. Full output is in the handoff's
  Return 1 addendum; the totals and the finding-1 lines:

```
FAIL AC-1 (REVIEW after GATES): a line committed by the step that sets REVIEW is refused, naming 'REVIEW, after GATES'
     expected: 1
     actual:   0
FAIL AC-1 (REVIEW after GATES): rc|refusals|summary - refused once, and nothing calls it clean
     expected: 1|1|0
     actual:   0|0|0
FAIL AC-1 (REVIEW after GREEN): a line committed by the step that sets REVIEW is refused, naming 'REVIEW, after GREEN'
FAIL AC-1 (REVIEW after GREEN): rc|refusals|summary - refused once, and nothing calls it clean
FAIL AC-2 [eslint-disable] (GREEN) / (GATES), FAIL AC-2 [noqa] (GREEN) / (GATES)
FAIL AC-2: the table branch - rc|refusals (one per added line)|summary
     expected: 1|32|0
     actual:   1|28|0
FAIL AC-5 control x4 (the A-1 rows)
boundaries: 217 passed, 13 failed
```

- **The probe that earns finding 6's assertion** (passes on arrival). One
  mutation, deleting the `ln++` that advances the counter past an added line
  in `suppression_hits`, one run of the suite holding it, restore verified by
  `mutate.sh`. The run differs from the red run above by exactly one assertion,
  the line-number whole line (217/13 -> 216/14). The sibling "one refusal"
  assertion stays green, as it should: the count does not depend on the number.

```
$ bash scripts/mutate.sh scripts/check-boundaries.sh 's/^      ln++; next$/      next/' -- bash .claude/tests/boundaries.test.sh
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/^      ln++; next$/      next/) ===
  718 -       ln++; next
  718 +       next
=== mutate: running bash .claude/tests/boundaries.test.sh ===
...
    FAIL AC-1: the third of three lines added in one hunk is refused by ITS line number, 4, not the hunk's first
         expected: 1
         actual:   0
...
boundaries: 216 passed, 14 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261029T010421Z.1404.bak) ===
  718:       ln++; next
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

- **What else changed.** Nothing outside the test file, the floors (boundaries
  216 -> 230 in `floors.conf` and `selftest.test.sh`), and this story's Test
  plan, Handoff, C-9 (one sub-bullet: the partial-entry suffix uses the same
  token rule, with the reason) and Model guidance. `scripts/check-boundaries.sh`
  is untouched (`git status` shows it unmodified).

### Return 2: GATES → RED (2026-10-29), from diff review round 2

- **Which test, and what was wrong.** The AC-5 cases had no path containing
  `(`, `)` or quote marks. So return 1's tokenizer, which splits on `()`,
  passed every test while it made a route-group path, such as
  `app/(auth)/page.tsx`, impossible to declare. A quoted path, the form the
  FAIL line prints, could not be declared either.
- **How it was found.** Diff review round 2. The orchestrator reproduced it
  with `lib/(shared)/util.py`, `noqa` and `'lib/x.py'`, and the output is
  pasted under `## Diff review`.
- **What it asserts now.** AC-5 declared cases with a route-group path, both
  backticked and bare, and with a single-quoted path. C-9, as amended in
  return 2, says how those are tokenized.
- **Earned by:** watching each new case fail against today's
  `suppression_declared`. It is a real red, because the behaviour is absent.
  The run was `bash .claude/tests/boundaries.test.sh` on cb352c0's
  `check-boundaries.sh` plus the new cases (test-developer, local, 14m03s).
  The 6 reds are exactly the new assertions, and all 230 pre-existing ones
  pass:

```
  AC-5: a suppression declared in ## Suppressions is accepted, and only a whole declaration
    FAIL AC-5: a path in single quotes, as the refusal prints it - rc|refusals
         expected: 0|
         actual:   1|FAIL  story T-1: commit d882602 (GREEN) added a suppression to 'src/main.ts' line 2 [eslint-disable]: // eslint-disable-next-line @typescript-eslint/no-explicit-any. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.
    FAIL AC-5: and the quoted path is declared
         expected: 1
         actual:   0
    FAIL AC-5: a route-group path, backticked - rc|refusals
         expected: 0|
         actual:   1|FAIL  story T-1: commit 12369a7 (GREEN) added a suppression to 'app/(auth)/page.tsx' line 1 [eslint-disable]: // eslint-disable-next-line @typescript-eslint/no-explicit-any. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.
    FAIL AC-5: and the backticked route-group path is declared
         expected: 1
         actual:   0
    FAIL AC-5: a route-group path, bare - rc|refusals
         expected: 0|
         actual:   1|FAIL  story T-1: commit 12369a7 (GREEN) added a suppression to 'app/(auth)/page.tsx' line 1 [eslint-disable]: // eslint-disable-next-line @typescript-eslint/no-explicit-any. GREEN and GATES may not silence a tool to reach green; if this one is needed, declare it in ## Suppressions - one line carrying the path, the rule id and 'approved by <who>', with the reason - and say why in that line.
    FAIL AC-5: and the bare route-group path is declared
         expected: 1
         actual:   0

boundaries: 230 passed, 6 failed
```

  Each red is the right red. The path is judged, because the refusal names
  `'app/(auth)/page.tsx'`. Without a suffix, no line was read as naming the
  path, which is the tokenizer's fault, not the fixture's. `classify.sh` says
  `source` for `app/(auth)/page.tsx`.

## Diff review

Round 1 (2026-10-28), a fresh `feature-developer` on the GATES row (planned
`opus`, resolved **claude-opus-5-5**, self-reported, no override), against
`git diff origin/main...HEAD` at 037b732. Report, condensed only in wording:

**Checked beyond the diff:**
- Hunk parsing: a `+c` header with no `,d`, a `+c,0` hunk, an added `++x` line, `\ No newline`, and several hunks all gave correct line numbers.
- mawk 1.3.4 (CI's awk): the three new functions gave 14/14 rows, 0/12 C-3 lines and the same `suppression_declared` results.
- No SIGPIPE shape; no 3j output on a branch no story claims; the merge-head skip.
- The negative assertions are paired with rc, no-FAIL and summary composites.

**Must fix**
1. **Work done in GATES is never judged when committed by the documented GATES → REVIEW step** (`check-boundaries.sh:767-768`). advance-story steps 3-4 set REVIEW and then commit, so a GATES fix still uncommitted then lands in a `phase: REVIEW` commit and 3j skips it. Fix: judge a commit when the committed phase at `c` **or at its first parent** is GREEN or GATES. This contradicts AC-3's literal REVIEW clause, so it needs an `## Amendments` entry. 3i has the same hole for RED work committed after GREEN is set.

**Should fix**

2. A source path with a space or a non-ASCII name is word-split or C-quoted, read as an empty diff, and counted as judged and clean. Fix: `diff-tree -z`; 3i shares the defect.
3. A file moved in GREEN or GATES is refused as an added suppression, because a single-path `git show` cannot pair the rename. Fix: one `git show -M` per commit over the paths on both sides.
4. `suppression_declared` matches the path and the bare rule id as substrings anywhere on the line. So `src/b.ts [noqa] approved by X: same as src/a.ts` declares `src/a.ts`, and `lib/src/a.ts.bak` declares `src/a.ts`. Fix: the path only as a whole token; the bare rule id only before the first `:`.
5. The anchor `(^|[[:space:]])` misses `foo();// eslint-disable-line` and `x = eval(s)# noqa`, both of which the tools honour. The comment and C-2 claim the anchor "costs no true positive". Fix: correct the claim, and optionally widen the anchor for the `//` and `/*` rows to `(^|[[:space:];,)}])`.
6. No test pins the line number of anything but a hunk's first added line; deleting `ln++` would go unnoticed (read, not mutated). Fix: one assertion, earned by `mutate.sh` against `ln++`.

**Nice to have**

7. A suppression added while resolving a merge conflict is invisible: a merge commit lists no paths under plain `diff-tree`. Fix: note a merge that `--cc` shows touching source or config.
8. `classify` runs on every path of every commit before the phase is read. Fix: read the phase first, as 3i does.
9. Only the first matching row is reported per line, so declaring one discharges a second directive on the same line.

Verdict: fix 1 first.

**Orchestrator's reproduction of finding 1** (different file and rule from the reviewer's case; a throwaway clone of this branch at 037b732). `.mcp.json.example`, which classifies `source`, got `// eslint-disable-next-line no-console` appended. The story was set to `phase: REVIEW` and both were committed together:

    == documented order (REVIEW commit):
    (3j printed nothing)
    == control (GATES commit):
    FAIL  story HARNESS-081: commit 562830f (GATES) added a suppression to '.mcp.json.example' line 9 [eslint-disable]: // eslint-disable-next-l[...]

Confirmed. The fix contradicts AC-3's REVIEW clause, so it waits on the user.

Round 2 (2026-10-29), a fresh `feature-developer` on the GATES row (planned
`opus`, resolved **claude-opus-5-5**, self-reported, no override), against
`git diff 46114ea..HEAD` and the whole of 3j at db13956. Report, condensed
only in wording:

**Checked and sound:**
- The parent arm, case by case:
  - no commit is judged twice;
  - an unreadable own story still gets the note;
  - a root commit or a parentless story is not judged, and `"$c^"` is no
    `set -u` hazard;
  - REVIEW → DONE is not judged;
  - a story-only REVIEW-after-GATES commit is neither judged nor counted;
  - `RED, after GATES` is judged correctly.
- The widened anchor: 16/16 and 0/12 under gawk 5.4.1 and mawk 1.3.4. The
  realistic `a, # noqa`, `],# type: ignore` and `}#[allow(...)]` are true
  positives. The only new false positives are contrived string literals, and
  JSON cannot carry `#`.
- CRLF: `[[:space:]]` includes `\r`, and `.gitattributes` pins `*.md eol=lf`.
- The tests: whole lines with `rc` paired, and the fourth AC-5 control
  discriminates.

**Must fix**
1. **A path containing `(` or `)` can never be declared.** The return-1
   split on `[[:space:]`,;:()]+` breaks `app/(auth)/page.tsx` into pieces, so
   no token equals the path. That is a Next.js route group, and its escape
   hatch is shut. Measured in a clone: the declaration was ignored and no
   suffix was printed. Round-1 code declared it, so return 1 regressed it.
   Fix: split on whitespace and backticks, then trim `,;:()` from token ends.
   This goes back to RED for one AC-5 case.

**Should fix**

2. **A path in quotes does not declare.** `'src/main.ts'` is how the FAIL
   line itself prints the path, so an author who copies it gets nothing. Fix:
   trim `'` and `"` from token ends too, in the same change.

Not made worse: deferred findings 2, 3, 7, 8 and 9, and 3i's hole. One
addition for the follow-up story: the unquoted `for f in $(...)` also globs,
so `app/[id]/page.tsx` can expand to `app/i/page.tsx`.

Verdict: fix 1 first.

**Orchestrator's reproduction of round 2 findings 1 and 2.** These are
different paths and a different rule from the reviewer's: the shipped
`suppression_declared`, extracted from `check-boundaries.sh` at db13956 and
fed one entry line, with rule `noqa`:

    - `lib/(shared)/util.py` [noqa] approved by sam: vendored      path=lib/(shared)/util.py   -> []
    - lib/(shared)/util.py [noqa] approved by sam: vendored        path=lib/(shared)/util.py   -> []
    - 'lib/x.py' [noqa] approved by sam: copied from the FAIL line path=lib/x.py               -> []
    - `lib/x.py` [noqa] approved by sam: control                   path=lib/x.py               -> [declared]

Confirmed. This is a regression against AC-5's existing promise, that an
entry carrying the path, the rule id and `approved by` discharges the
refusal, so no criterion changes. C-9's tokenizing is amended (return 2), and
both fixes are taken in this story.

Round 3 (2026-10-29): a fresh `feature-developer` on the GATES row (planned
`opus`, resolved **claude-opus-5-5**, self-reported, no override), against
`git diff db13956..HEAD` at e157fa6. The report is condensed in wording only.

**Checked and sound:**
- The A-1 controls hold after the trim. The extracted shipped function ran
  under gawk 5.4.1 and mawk 1.3.4 20240123 (the mawk run used a symlink and
  printed its version line); the 23 rows were identical across the two.
  - Refused: `(src/other.ts) ... same as src/main.ts`, `src/other.ts,
    src/main.ts:`, `src/main.ts).` and `'src/main.ts.bak',`.
  - Declared: `"src/main.ts",`, `('src/main.ts'),` and `'src/main.ts:'`.
- The trim can never remove a `/`, so the first-path-token rule sees the
  same tokens it saw before the change.
- The bracketed and bare rule-id tests read the whole line, not the tokens.
  This corrects GREEN return 2's note, which said they used the tokens.
- `'\''` delivers `/^[,;:()'"]+|[,;:()'"]+$/` to both awks.
- The new tests pin whole lines with `rc`, and the `$ac5_path` reset is
  correct.

**Should fix**
1. A path that itself starts or ends with `,;:()'"`, such as `bin/run(old)`
   or `lib/(x)`, can never be declared, because the trim eats its last
   character. Return 1 had the same gap, and no path of this shape appears
   in the stacks this harness targets; Next.js `(.)photo` paths declare.
   Fix: compare the untrimmed token too.
2. Trimming `"`, `(`, `)`, `;` and `:` has no test. Only `'` and `,` are
   pinned, so narrowing the class to `[,']` would leave all 236 assertions
   green (a reading of the code, not a mutation run). Fix: one declared case,
   `("src/main.ts");`.

**Nice to have**

3. `src/main.ts:2` no longer declares the file. This follows C-9 as amended,
   and it refuses rather than accepts.
4. `lib/noqa.py` names the rule as a bare word inside its own path. This is
   older than the delta. `app/[id]/x.tsx` turns bare-id matching off.

Verdict: Ship.

**PO decision.** None of the four lets through anything that should be
refused; each one either refuses wrongly or leaves a gap in the tests. They
join round 1's deferred findings 2, 3, 7, 8 and 9, 3i's matching hole, and
round 2's globbing note in the follow-up story, which is to be planned after
this story merges.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-29T04:16:17Z
    commit: 5a66660
    tree:   ce392bcd71f8b0e81ced3c9945fd3fe503b72c77
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

**GREEN (feature-developer, claude-opus-5-5, 2026-10-28): the negative controls,
measured against the shipped `suppression_needles` and `suppression_hits`.**
Both functions were extracted from the real `scripts/check-boundaries.sh` and
fed a synthetic `--unified=0` diff (header, `@@ -0,0 +1,n @@`, every line `+`).
The handoff's table holds exactly:

    gawk 5.4.1
    == C-2 example lines through suppression_hits (line|first row|trimmed text)
    1|eslint-disable|// eslint-disable-next-line @typescript-eslint/no-explicit-any
    2|ts-ignore|// @ts-ignore
    3|biome-ignore|// biome-ignore lint/suspicious/noExplicitAny: legacy
    4|noqa|x = eval(s)  # noqa: S307
    5|type-ignore|y = f()  # type: ignore[attr-defined]
    6|rust-allow|#[allow(dead_code)]
    7|rust-allow|#![allow(clippy::all)]
    8|gd-warning-ignore|@warning_ignore("unused_parameter")
    9|coverage-ignore|/* istanbul ignore next */
    10|coverage-ignore|// c8 ignore start
    11|no-cover|def f():  # pragma: no cover
    12|stryker-disable|// Stryker disable next-line all
    13|hadolint-ignore|# hadolint ignore=DL3008
    14|shellcheck-disable|# shellcheck disable=SC2086
    == every row tested against each example line: each matches exactly its own row (14/14, no line matches two)
    == the 12 C-3 lines through suppression_hits: no output; every row against each: 0 matches
    == the defect: raw '+' lines, leading + kept: 3/14 match some row

Same numbers as RED's (14/14, 0/12, 3/14). No divergence.

**Decisions GREEN made that the Contract left open.**

- The `note` for an unreadable story file is printed only for a commit that
  changed at least one `source` or `config` path. A commit with no such path has
  nothing this rule could judge in any phase, so "additions not judged" would be
  noise; the AC-6 commit touches `src/main.ts` and gets the note.
- The third partial-entry form is ` ... is missing the rule id [<id>] and
  'approved by'.` as C-4 states. With several partial lines naming the path, the
  first one's gap is reported; any whole line anywhere in the section wins.
- A bare rule id counts as a word when the characters either side are not
  `[a-z0-9_-]`.
- The table and the diff reach awk as one here-string, separated by a
  `--8<-- diff` line (the table is read until it, the diff after it), so there
  is no temp file and no `-v`.
- A merge commit in `BASE..HEAD` (CI's detached merge head) lists no paths under
  plain `diff-tree -r`, so it is neither judged nor noted.
- **Not handled, reported:** a file renamed in a GREEN/GATES commit. The diff is
  read per path (`git show ... -- "$f"`), and with only the new path in the
  pathspec git cannot pair the rename, so every line of the moved file reads as
  added: an existing suppression carried by a `git mv` is refused. That fails
  closed (the escape hatch discharges it) and no test pins it.

**GREEN runs, on the uncommitted GREEN tree.**

    bash .claude/tests/boundaries.test.sh   -> boundaries: 216 passed, 0 failed
    bash .claude/tests/new-story.test.sh    -> new-story: 58 passed, 0 failed
    bash scripts/selftest.sh selftest       -> selftest: 268 passed, 0 failed
    policy: 17/0, reporting: 27/0, lib: 324/0 (the suites that read rules.md / sections.md)
    check-sigpipe: scanned 56 shell file(s), 51 with pipefail, 0 finding(s)
    check-grep-count: scanned 56 shell file(s), 0 finding(s)
    gates.sh --fast: All required gates passed (0 ran, 5 unconfigured, 0 known)
    GITHUB_HEAD_REF= PR_HEAD_SHA= bash scripts/check-boundaries.sh origin/main
      -> no 3j line at all (no FAIL, no ok, no note); the two FAILs it prints are
         3b (phase GREEN, not REVIEW) and 3h (DVs not yet run), both expected now.

**GREEN, return 1 (feature-developer, claude-opus-5-5, 2026-10-28): A-1's
findings 1, 4 and 5 in 3j, and the controls re-measured against the shipped
functions.** `suppression_needles`, `suppression_hits` and
`suppression_declared` were extracted from the real `scripts/check-boundaries.sh`
by `awk '/^name\(\) \{/,/^}$/'` and `eval`ed; the hits ran over a synthetic
`--unified=0` diff (`@@ -0,0 +1,28 @@`, every line `+`). The same script ran
twice: under Git Bash's gawk, and under WSL with `awk` exported as a function
calling `mawk` (its `awk -W version` line printed `mawk 1.3.4 20240123`, so the
override held inside the functions). The two outputs are identical line for
line; the gawk run:

    awk: GNU Awk 5.4.1
    == example lines: line -> rows it matches (want its own row only)
    eslint-disable       eslint-disable         // eslint-disable-next-line @typescript-eslint/no-explicit-any
    ts-ignore            ts-ignore              // @ts-ignore
    biome-ignore         biome-ignore           // biome-ignore lint/suspicious/noExplicitAny: legacy
    noqa                 noqa                   x = eval(s)  # noqa: S307
    type-ignore          type-ignore            y = f()  # type: ignore[attr-defined]
    rust-allow           rust-allow             #[allow(dead_code)]
    rust-allow           rust-allow             #![allow(clippy::all)]
    gd-warning-ignore    gd-warning-ignore      @warning_ignore("unused_parameter")
    coverage-ignore      coverage-ignore        /* istanbul ignore next */
    coverage-ignore      coverage-ignore        // c8 ignore start
    no-cover             no-cover               def f():  # pragma: no cover
    stryker-disable      stryker-disable        // Stryker disable next-line all
    hadolint-ignore      hadolint-ignore        # hadolint ignore=DL3008
    shellcheck-disable   shellcheck-disable     # shellcheck disable=SC2086
    eslint-disable       eslint-disable         foo();// eslint-disable-line
    noqa                 noqa                   x = eval(s)# noqa
       own-row-only: 16/16
    == C-3 lines: rows matched (want -)
    -                      // never add an eslint-disable here
    -                      const s = "# noqa";
    -                      // see rules.md: "# pragma: no cover" is refused
    -                      // Stryker restore all
    -                      fn allow(x: u32) -> u32 { x }
    -                      let expect = 3;
    -                      // @ts-ignored-thing
    -                          Lines ending in type: ignore are not honoured here.
    -                      url = "http://x/#noqa"
    -                      const s = "# noqa: S307";
    -                      url = "http://x/#noqa:frag"
    -                      msg = "#[allow(dead_code)]"
       C-3 lines matching any row: 0/12
    == through suppression_hits (synthetic diff, all lines added)
    [abridged here: 16 lines, `1|eslint-disable|...` to `16|noqa|x = eval(s)# noqa`, each naming its own row; nothing for lines 17-28, the C-3 corpus]
    == suppression_declared src/main.ts eslint-disable (AC-5 lines)
    declared     <- - `src/main.ts` [eslint-disable] approved by ryan: the generated client types this as any; replacing the generator is its own story.
    declared     <- - Approved By ryan: eslint-disable in src/main.ts, because the generated client types this as any.
    the rule id [eslint-disable] <- - `src/main.ts` [noqa] approved by ryan: legacy
    'approved by' <- - `src/main.ts` [eslint-disable]: legacy
                 <- - `src/other.ts` [eslint-disable] approved by ryan: legacy
                 <- - src/other.ts [noqa] approved by ryan: same as src/main.ts
                 <- - src/other.ts [eslint-disable] approved by ryan: same as src/main.ts
                 <- - `src/main.ts.bak` [eslint-disable] approved by ryan: legacy
    the rule id [eslint-disable] <- - src/main.ts [noqa] approved by ryan: not eslint-disable
    the rule id [eslint-disable] <- - `src/main.ts` approved by nobody, no id here
    the rule id [eslint-disable] and 'approved by' <- - `src/main.ts` legacy
       (C-9 example) Dockerfile hadolint-ignore:
    declared     <- - Dockerfile [hadolint-ignore] approved by X: see docs/a.md
    == the named misses (comment and C-2), every row against each
    - (missed)       s = "a"# noqa
    - (missed)       x=1# noqa
    - (missed)       foo// eslint-disable-line
    - (missed)       a[0]// eslint-disable-line
    - (missed)       fn f(#[allow(unused)] x: u32)
    - (missed)       {// eslint-disable-line

Against the handoff: 14/14 became 16/16 with A-1's two lines, each matching
only its own row; 0/12 C-3 lines match, as RED measured; the eight AC-5 lines
the suite holds give the outcome it pins (two declared, two with the pinned
suffix, four with none) and the A-1 fourth row gives the pinned
`the rule id [eslint-disable]` suffix. No divergence from RED's numbers. The
last three `suppression_declared` lines are not in the suite; they show the
third partial-entry form and C-9's Dockerfile example.

**Decisions GREEN (return 1) made that C-9 left open.**

- **Path tokens.** The line is lower-cased and split on
  ``[[:space:]`,;:()]+``; the path is named when a token equals it before any
  token containing `/` has been seen. Brackets are not delimiters, so
  `[noqa]` is a token without a `/` and does not stop the scan. A path that
  itself contains a delimiter (a space, `:`, `,`, `(`...) can never be named;
  no such path can reach this block today either, because the walk word-splits
  `diff-tree` output (finding 2, out of scope).
- **"Brackets an id"** is `\[[a-z-]+\]` anywhere on the lower-cased line, the
  rule-id alphabet C-2 fixes. A Markdown link text like `[see](x)` on an entry
  line therefore counts as a bracketed id and turns bare-word matching off for
  that line; that fails closed.
- **Parent phase.** Read only when the commit's own phase is not GREEN or
  GATES, with `git show "$c^:$sfile"` into a variable and `frontmatter_value`,
  as the own phase is. A failing `git show` (root commit, no story file at the
  parent) leaves it empty, so the commit is not judged. An own story file with
  no `phase:` line and a GATES parent would print `(, after GATES)`; no case
  makes that reachable through `phase.sh`, and it is left as is.
- **The unreadable-diff `problem`** inherits the composed phase label, so a
  REVIEW commit after GATES reads `(REVIEW, after GATES)` there too.

**GREEN (return 1) runs, on the uncommitted tree.**

    bash .claude/tests/boundaries.test.sh   -> boundaries: 230 passed, 0 failed
    check-sigpipe: scanned 56 shell file(s), 51 with pipefail, 0 finding(s)
    check-grep-count: scanned 56 shell file(s), 0 finding(s)
    gates.sh --fast: All required gates passed (0 ran, 5 unconfigured, 0 known).
    mutate.sh --check: no stranded mutation

The suite ran against the finished code; one comment in 3j (the known-miss
list) was re-wrapped onto three lines while it ran, with no code change, and
`bash -n`, sigpipe and grep-count were re-run after it.

**GREEN, return 2 (feature-developer, claude-opus-5-5, 2026-10-29): the
tokenizer in `suppression_declared`, and the AC-5 lines re-measured against the
shipped function.** One change in `scripts/check-boundaries.sh`: the line is
split on ``[[:space:]`]+`` only, and each token then has `,;:()'"` trimmed from
both ends (`gsub(/^[,;:()'"]+|[,;:()'"]+$/, "", tok[j])`, the `'` written as
`'\''` inside the single-quoted program), never from inside it. The
first-path-token rule, the bracketed-id rule, `approved by` and the suffix are
unchanged and key on the same trimmed tokens. The comment above the function
says so.

Method: the function was extracted from the real file with
`sed -n '/^suppression_declared() {$/,/^}$/p'` and `eval`ed, then fed each
AC-5 entry line as the comment-stripped section. It ran under Git Bash's gawk,
and under WSL with a `PATH` directory whose `awk` is a symlink to `/usr/bin/mawk`
(WSL's own `awk` is gawk; the first attempt without the symlink printed
`GNU Awk 5.2.1` and is discarded). A byte copy of the shipped file
(`cmp` identical) was used on the WSL side, log on /mnt/c. The two outputs are
identical below their version line (`diff` empty). Rows 4 and 5 (double quotes,
parenthesised) are not in the suite; the HTML-comment and outside-section
controls are decided by `section`/`strip_comments` before this function and are
not rows here.

    awk: GNU Awk 5.4.1, API 4.1, PMA Avon 8-g1, (GNU MPFR 4.2.2, GNU MP 6.3.0)
    src/main.ts            [eslint-disable] declared                           <- - `src/main.ts` [eslint-disable] approved by ryan: the generated client types this as any; replacing the generator is its own story.
    src/main.ts            [eslint-disable] declared                           <- - Approved By ryan: eslint-disable in src/main.ts, because the generated client types this as any.
    src/main.ts            [eslint-disable] declared                           <- - 'src/main.ts' [eslint-disable] approved by ryan: copied from the refusal
    src/main.ts            [eslint-disable] declared                           <- - "src/main.ts" [eslint-disable] approved by ryan: double quotes (C-9, unpinned)
    src/main.ts            [eslint-disable] declared                           <- - (src/main.ts) [eslint-disable] approved by ryan: parenthesised
    src/main.ts            [eslint-disable] the rule id [eslint-disable]       <- - `src/main.ts` [noqa] approved by ryan: legacy
    src/main.ts            [eslint-disable] 'approved by'                      <- - `src/main.ts` [eslint-disable]: legacy
    src/main.ts            [eslint-disable] <nothing>                          <- - `src/other.ts` [eslint-disable] approved by ryan: legacy
    src/main.ts            [eslint-disable] <nothing>                          <- - src/other.ts [noqa] approved by ryan: same as src/main.ts
    src/main.ts            [eslint-disable] <nothing>                          <- - src/other.ts [eslint-disable] approved by ryan: same as src/main.ts
    src/main.ts            [eslint-disable] <nothing>                          <- - `src/main.ts.bak` [eslint-disable] approved by ryan: legacy
    src/main.ts            [eslint-disable] the rule id [eslint-disable]       <- - src/main.ts [noqa] approved by ryan: not eslint-disable
    app/(auth)/page.tsx    [eslint-disable] declared                           <- - `app/(auth)/page.tsx` [eslint-disable] approved by ryan: route group
    app/(auth)/page.tsx    [eslint-disable] declared                           <- - app/(auth)/page.tsx [eslint-disable] approved by ryan: route group
    awk: mawk 1.3.4 20240123      <- the mawk run's version line; its 14 rows are identical

Against the handoff's candidate table: every row agrees (the three new entries
declared, `src/other.ts ... same as src/main.ts` and `src/main.ts.bak` give
nothing, `(src/main.ts)` declared). The A-1 controls keep their pinned
outcomes, including both suffixes. `"src/main.ts"` in double quotes is
declared, as C-9 says, under both awks. No divergence.

**Decision.** Trimming is per token and repeated (`+`), so `('src/main.ts'),`
also names the path; a `.` is not trimmed, so `src/main.ts.` does not. Neither
is pinned.

**GREEN (return 2) runs, on the uncommitted tree.** No file was edited while
the suite ran; this paragraph was added after it finished.

    bash .claude/tests/boundaries.test.sh   -> boundaries: 236 passed, 0 failed   (17m23s, rc 0)
    check-sigpipe: scanned 56 shell file(s), 51 with pipefail, 0 finding(s)
    check-grep-count: scanned 56 shell file(s), 0 finding(s)
    gates.sh --fast: All required gates passed (0 ran, 5 unconfigured, 0 known).
    mutate.sh --check: no stranded mutation
