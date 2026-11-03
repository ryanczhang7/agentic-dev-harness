---
id: HARNESS-086
title: The orchestrator reads a story by section through scripts/story.sh
slug: the-orchestrator-reads-a-story-by-sectio
epic: 
type: feature
status: in-progress
phase: GATES
branch: story/HARNESS-086-the-orchestrator-reads-a-story-by-sectio
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/story.sh, .claude/hooks/lib.sh, .claude/tests/story.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/commands/advance-story.md, .claude/commands/complete-story.md, .claude/agents/lead-po.md, CLAUDE.md, .claude/harness/VERSION]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Third of four (HARNESS-084..087): the orchestrator's standing context. Both
orchestrating commands open with `Read docs/backlog/stories/$1.md first`,
and a story file grows as it runs: HARNESS-083 reached 1,760 lines, most of
it handoffs, regressions, pasted probe output and gate records that the
phase at hand does not need. Every turn re-sends it. The user's decision:
the orchestrator reads the frontmatter and the sections the current phase
needs, through a script that prints one named section, and dispatch prompts
are built from those sections.

The reading of "a section" must be the one CI already makes.
`check-boundaries.sh` has `section()`: from the line beginning `## <name>`
to the line before the next column-0 `## `, heading excluded, fences not
special. A second reading would eventually disagree with it about where a
section ends, and the orchestrator would then be judging different text from
the text CI judges. So the extractor goes into `lib.sh`, `story.sh` calls it,
and `check-boundaries.sh` is left alone in this story - HARNESS-083 is in
flight on that file - with converging its `section()` onto the library
function recorded in `## Notes` as the follow-up.

The gate that fails if this breaks is `bash scripts/selftest.sh story` (a
new suite); the prose criteria are structural guards over the real tree.

## Acceptance criteria

- **AC-1** — Given a story file with sections `Context`, `Acceptance
  criteria`, `Handoff: RED -> GREEN` and `Notes`, when `bash scripts/story.sh
  section <id> "Handoff: RED -> GREEN"` runs, then it prints that section's
  body - every line after the heading up to the line before the next
  column-0 `## `, the heading itself excluded - byte for byte what
  `check-boundaries.sh`'s `section()` reading gives, including a `## `-shaped
  line inside a fenced block ending the section. *Controls:* a name the story
  has no section for exits 1 and prints, on stderr, `no section "<name>" in
  <path>` followed by the names it does have; a name that is a prefix of a
  real one (`Handoff`) is not a match; an id that is not one path component
  (`../X`) exits 2 with `valid_story_id`'s message.
- **AC-2** — Given the same story, when `bash scripts/story.sh sections <id>`
  runs, then it prints one line per `## ` heading in file order, `<name>\t<N>`
  with N the section's line count, and `bash scripts/story.sh frontmatter
  <id>` prints the frontmatter block between the two `---` lines, exclusive.
  *Control:* a story with no frontmatter exits 1.
- **AC-3** — Given the real tree, when the suite's structural guard
  (`story_problems <root>`, C-4) runs over `REPO_ROOT`, then it prints
  nothing; over fixtures compliant by construction with one site regressed, it
  prints exactly the one line C-4 pins. The sites: advance-story.md no longer
  contains the sentence `Read `docs/backlog/stories/$1.md` first.` and carries
  a line beginning `| PLANNED → RED |` in a table that names, per phase, the
  sections to read with `bash scripts/story.sh section $1`; complete-story.md
  and lead-po.md name `bash scripts/story.sh section`; both commands'
  `allowed-tools` carry an entry equal to `Bash(bash scripts/story.sh:*)`;
  CLAUDE.md's `## Running things` block carries one line beginning
  `bash scripts/story.sh section ID NAME`. This can only be checked
  structurally; the suite pins that the instruction is present, not that a
  model follows it.

## Contract

**Writes:** `scripts/story.sh`, `.claude/hooks/lib.sh`, `.claude/tests/story.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `.claude/agents/lead-po.md`, `CLAUDE.md`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says.

**C-1. `scripts/story.sh`.**

    bash scripts/story.sh section <id> "<name>"   the body of `## <name>`, heading excluded
    bash scripts/story.sh sections <id>           `<name>\t<lines>` per `## ` heading, file order
    bash scripts/story.sh frontmatter <id>        the lines between the first two `---` lines

`<id>` is validated with `valid_story_id` (exit 2 on refusal). The function
prints nothing itself; "its message" in AC-1 is the one every caller prints
on refusal (gates.sh, new-story.sh), on stderr:
`error: story id '<id>' is not one path component: an id is letters, digits,
'.', '_' or '-', and starts with a letter or digit`. It is then resolved to `docs/backlog/stories/<id>.md` under the repository root; a
missing file exits 1 with `no story file at docs/backlog/stories/<id>.md`.
`<name>` is matched as the **whole** text after `## ` (trailing spaces
trimmed), so `Handoff` does not match `Handoff: RED -> GREEN`. Unknown
subcommand or missing argument: exit 2 and a usage line. Output is the
section's lines unchanged, including blank ones and HTML comments: the
orchestrator reads what is there, and `strip_comments` is the caller's
choice.

*Amended in RED (test-developer, 2026-11-02), each pinned by story.test.sh.
No criterion changed; these fill in what the block left open, so GREEN has one
answer rather than a guess:*

- **Absent name (AC-1's "followed by the names it does have").** Exit 1,
  stdout empty, stderr EXACTLY: line 1 `no section "<name>" in
  docs/backlog/stories/<id>.md` (`<path>` is the repo-relative path, the same
  spelling as the missing-file message), then one line per `## ` heading in
  file order, each the trimmed name prefixed by two spaces. Reason: AC-1 fixes
  the first line but not the list's shape, and a whole-output compare needs
  one.
- **Present but empty.** A heading with no body (`## Empty` directly followed
  by `## Notes`) exits 0 and prints nothing. Reason: "absent" and "empty" must
  not share an exit code, or the orchestrator cannot tell a missing section
  from an unfilled one.
- **`sections`.** `<N>` is the number of lines `section` prints for that
  heading (heading excluded; the last section runs to end of file). The name
  printed is trimmed of trailing whitespace, so it round-trips into `section`.
  A `## ` line inside a fence is a heading here too: fences are not special in
  any subcommand.
- **`frontmatter`.** Line 1 must be exactly `---` and a later line exactly
  `---`; it prints the lines between them. Otherwise - no `---` on line 1, or
  never closed - exit 1, stdout empty, stderr `no frontmatter in
  docs/backlog/stories/<id>.md`. Reason: "the first two `---` lines" read
  literally would print the text between two horizontal rules of a story with
  no frontmatter, which is AC-2's control; the fixture has exactly that case.
- **Success writes nothing to stderr.** Matching is case-sensitive. The story
  is found from a subdirectory too (`cd src && bash ../scripts/story.sh ...`):
  "under the repository root" means the script's root, not the working
  directory.
- **Usage.** Exit 2, stdout empty, stderr contains `usage:`. The rest of the
  line is GREEN's choice. Pinned for: no arguments, `bogus T-1`, `section T-1`
  (no name), and `section`, `sections`, `frontmatter` with no id.
- **Byte for byte** means trailing blank lines and trailing spaces kept: the
  suite captures stdout with a sentinel, so a reading that drops a section's
  final blank line fails.

**C-2. `story_section <file> <name>` in `lib.sh`**, appended at the end of
the file: prints the body, returns 1 when the heading is absent. Its reading
is `check-boundaries.sh`'s `section()` verbatim - `index($0, "## " name) ==
1` to start, the next line matching `/^## /` to stop, no fence tracking -
with one tightening the test pins: the match is whole-heading, where
`section()` is prefix. (Prefix is what lets `section "$f" "Handoff"` find
`## Handoff: RED -> GREEN` in check-boundaries.sh today; story.sh takes the
full name and the orchestrator is told the names by `sections`.) `## Notes`
in this story records the follow-up: make `check-boundaries.sh`'s `section()`
call `story_section` once HARNESS-083 has merged, with its prefix callers
listed.

**C-3. The prose.** advance-story.md: the line `Read
`docs/backlog/stories/$1.md` first. Then, based on its current phase:`
becomes an instruction to read the frontmatter (`bash scripts/story.sh
frontmatter $1`) and the sections the phase needs, followed by this table,
which GREEN writes in exactly this shape so the guard can find its rows:

    | Phase | Read with `bash scripts/story.sh section $1 <name>` |
    |---|---|
    | PLANNED → RED | Context, Acceptance criteria, Contract, Deferred verifications, Model guidance, Out of scope |
    | RED → GREEN | Acceptance criteria, Contract, Handoff: RED -> GREEN, Deferred verifications, Regressions, Model guidance |
    | GREEN → GATES | Deferred verifications, Gate results, Gate probes, Notes |
    | GATES → REVIEW | Diff review, Gate results, Deferred verifications, Notes |
    | REVIEW → DONE | Notes |

and one sentence: a dispatch prompt is built from those sections, pasted,
not from the file; `## Handoff` is pasted whole, because it is the channel.
The rest of the file is unchanged, including the `Create and switch to the
story's branch` anchor `boundaries.test.sh` reads. complete-story.md: its
summary says the same per-phase reading, by naming `bash scripts/story.sh
section`. lead-po.md `## Orchestrating`: the dispatch list ("the story id
and file path, the acceptance criteria restated, the story's `## Contract`")
says each is taken with `bash scripts/story.sh section`. CLAUDE.md `##
Running things`: one line in the block's shape, `bash scripts/story.sh
section ID NAME   # one section of a story, as check-boundaries reads it`.
Both commands' `allowed-tools` gain `Bash(bash scripts/story.sh:*)`.

**C-4. The suite.** `.claude/tests/story.test.sh`, `_lib.sh`, a
`make_project_fixture` tree with a story written by the test (not by
`new-story.sh`, whose template is mostly comments; the fixture's sections are
short and one holds a fenced block containing a `## ` line). `story_problems
<root>` in `procedure_problems`' shape:

| Site | Must hold | Reported as |
|---|---|---|
| advance-story.md | does not contain `Read `docs/backlog/stories/$1.md` first.` | `still reads the whole story file first` |
| advance-story.md | contains a line beginning `| PLANNED → RED |` and one beginning `| GATES → REVIEW |` | `has no per-phase section table` |
| advance-story.md, complete-story.md, lead-po.md | contain `bash scripts/story.sh section` | `does not read the story by section` |
| both commands' frontmatter `allowed-tools` | an entry equal to `Bash(bash scripts/story.sh:*)` | `does not permit story.sh` |
| CLAUDE.md | a line beginning `bash scripts/story.sh section ID NAME` inside the `## Running things` fenced block | `Running things does not list story.sh` |

*Amended in RED (test-developer, 2026-11-02): the shape the suite pins.*
Each printed line is `<relative-path>: <reason>` (procedure_problems' shape),
e.g. `.claude/commands/advance-story.md: does not permit story.sh` and
`CLAUDE.md: Running things does not list story.sh`. Order: advance-story's
four rows in table order, complete-story's two, lead-po's, CLAUDE.md's. A site
file that does not exist prints `<path>: file is missing` instead of its rows.
"Inside the `## Running things` fenced block" is read as: the FIRST fenced
block (first line beginning ```` ``` ```` to the next) after a column-0
heading whose trimmed text is exactly `## Running things`, before any later
column-0 `## `; the line must begin with the needle at column 0. A second
fence in the section, a fence under another heading, an indented line and
`bash scripts/story.sh sections ID` do not count. The `contain` needle
`bash scripts/story.sh section` is a substring match as written, so
`bash scripts/story.sh sections` also satisfies it; the suite records that as
a documented limit rather than tightening it, because a trailing-space needle
would refuse C-3's own lead-po wording (`` `bash scripts/story.sh section` ``,
backtick after). CRLF files read the same as LF.

Floors: `floor | story | N` in `floors.conf` and the same N in
`selftest.test.sh`'s table. Suites that read files this story writes, and
what they pin, all kept: `boundaries` (the branch anchor in advance-story.md),
`procedure` (allowed-tools membership, GATES → REVIEW steps), `policy`
(`REVIEW → DONE` paragraph, mutation count absence), `reporting` (`##
Orchestrating`, the reporting reference), `phase` (`bash scripts/plan.sh
after`), `mutate` (one exact CLAUDE.md line), `lib` (classification table;
a new function at the end of lib.sh changes no pinned line).

**C-5. Oracle partition.** AC-1 and AC-2 are **mechanical** with one
**settled** value: the section reading is `check-boundaries.sh`'s, read out
of its `section()` and pinned by a fixture that includes the fence case.
AC-3 is mechanical. Nothing is oracle-free.

**C-6. No existing export changes signature.** `section()` in
`check-boundaries.sh` is not touched in this story (HARNESS-083 holds that
file). `valid_story_id` is called, not changed.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** Make `story_section` match the
name as a prefix - `section()`'s reading, which this story tightens - and
AC-1's `Handoff` control **must** go red while every other assertion stays
green. (Corrected at RED → GREEN by the PO: the first draft also described a
fence mutation backwards. Stopping at a fenced `## ` line IS the adopted
reading; the mutation that breaks it is making `story_section` fence-aware,
which RED measured turning exactly the 3 fenced-body assertions red. That one
is not owed: the prefix mutation is the story's central claim.) RED cannot
run this: `story.sh` does not exist. Run against `bash scripts/selftest.sh
story`; paste the red, the count and the restore.

Result (GATES, 2026-11-02, orchestrator): `h == name` → `index(h, name) == 1`
in lib.sh's `story_section`, via `mutate.sh`. Exactly the five `Handoff`-prefix
assertions red, every other assertion green; restored and verified.

```
$ bash scripts/mutate.sh .claude/hooks/lib.sh 's/\/\^## \/ \&\& h == name {/\/^## \/ \&\& index(h, name) == 1 {/' -- bash scripts/selftest.sh story
    FAIL the prefix `Handoff` does not match `Handoff: RED -> GREEN`: exit 1
    FAIL the prefix `Handoff` prints nothing on stdout
    FAIL the prefix `Handoff` is reported as an absent name
    FAIL story_section with the prefix `Handoff` returns 1
    FAIL story_section with the prefix `Handoff` prints nothing
story: 92 passed, 5 failed
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_hooks_lib.sh.20261102T225920Z.99880.bak) ===
```

**DV-2 (a rule probed against the tree it judges). Owner: GATES.** With a
real line of `.claude/commands/advance-story.md` mutated to put `Read
`docs/backlog/stories/$1.md` first.` back, `story_problems "$REPO_ROOT"`
**must** print exactly `still reads the whole story file first`, and nothing
once restored.

Result (GATES, 2026-11-02, orchestrator): real line 17 of advance-story.md
replaced with the old sentence, via `mutate.sh`. Only the real-tree guard went
red, printing exactly the one line; restored and verified. Unmutated, the same
assertion is green (GREEN's fresh `story` record, 97/0).

```
$ bash scripts/mutate.sh .claude/commands/advance-story.md 's/^Do not read the whole story file: it grows as the story runs, and every turn$/Read `docs\/backlog\/stories\/$1.md` first./' -- bash scripts/selftest.sh story
    FAIL story_problems over the real tree prints nothing: advance-story reads by section through a per-phase table and no longer reads the whole file first, complete-story and lead-po name `bash scripts/story.sh section`, both commands permit story.sh, and CLAUDE.md's Running things block lists it
         expected: 
         actual:   .claude/commands/advance-story.md: still reads the whole story file first
story: 96 passed, 1 failed
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_commands_advance-story.md.20261102T225937Z.100231.bak) ===
  17: Do not read the whole story file: it grows as the story runs, and every turn
```

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-086` from `.claude/harness/models.conf`.
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
## Out of scope

- Converging `check-boundaries.sh`'s `section()` onto `story_section`:
  recorded in `## Notes` as the follow-up, after HARNESS-083 merges.
- Trimming `rules.md` or CLAUDE.md: HARNESS-087 (rules.md only).
- Changing which sections a story has, or the story template.
- `plan.sh`'s own reading of stories (`contract_writes`, `cmd_write`):
  untouched.
- Any change to what a subagent reads: it is dispatched with pasted
  sections today and tomorrow; this story changes how the orchestrator gets
  them.

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One new suite, `.claude/tests/story.test.sh` (`bash scripts/selftest.sh
story`), 97 executed assertions, every one unconditional. Two levels:

- **Integration, AC-1 and AC-2:** `scripts/story.sh` run as a process inside a
  `make_project_fixture` tree (real scripts and hooks copied in) against a
  story the test writes itself: frontmatter, then `Context` (with `##not` and
  an indented `  ## ` line, neither a heading), `Acceptance criteria` (with a
  third `---` line), `Handoff: RED -> GREEN` (holding a ```` ```bash ````
  fence whose `## a heading-shaped line inside a fence` ENDS the section),
  that fenced heading's own section, `Empty` (no body), and `Notes   ` (three
  trailing spaces in the heading; last line has a trailing space). Two more
  story files are written for the frontmatter controls (T-2 no frontmatter but
  two `---` rules in the body, T-3 opened and never closed) and one with no
  heading (T-4). All stdout compares are byte for byte (sentinel capture).
- **The oracle block** reads `section()` OUT of `scripts/check-boundaries.sh`
  (awk from `section() {` to the closing `}`, eval'd as `cb_section`) and
  checks the literal bodies against it, so the settled reading is the CI
  function itself, not a paraphrase. Two controls show the fixture
  discriminates: a fence-aware reading gives 9 lines for Handoff, not 5; and
  `section()` DOES match the prefix `Handoff`, so the whole-heading control is
  a real difference between the two readings.
- **Unit, C-2:** `story_section` called directly from `.claude/hooks/lib.sh`.
- **Structural guard, AC-3:** `story_problems <root>` (pure bash), run over
  `REPO_ROOT` (must print nothing) and over 34 fixtures written compliant by
  construction with one site regressed, each compared whole-output.

Edges covered: empty section (exit 0, nothing printed) against absent (exit
1); one heading inside a fence; many sections in order; case sensitivity; a
longer-than-heading name; trailing spaces in a heading and in a body; a valid
id with no file; `../X` on all three subcommands; six usage shapes; running
from a subdirectory; CRLF command files.

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. -->

Resolved model: this dispatch ran as `test-developer`, which declares
`model: opus`; the session reports Opus 5.5 (`claude-opus-5-5`). No override
was given in the dispatch.

**Command:** `bash scripts/selftest.sh story` (and `bash scripts/selftest.sh
selftest` for the floor table).

**Attest records** (all on tree `df90749c60e6804d02731d791f3b9d7695503188`;
the story file is not a gated path, so editing this section does not stale
them):

| Command | exit | last | log |
|---|---|---|---|
| `bash scripts/selftest.sh story` | 1 | `1 of 1 harness suite(s) FAILED.` | `.claude/state/attest-logs/20261102T190027Z.9370.log` |
| `bash scripts/selftest.sh selftest` | 0 | `1 harness suite(s) passed.` (`selftest: 268 passed, 0 failed`) | `.claude/state/attest-logs/20261102T190053Z.9967.log` |
| `bash scripts/gates.sh --fast` | 0 | `All required gates passed (0 ran, 5 unconfigured, 0 known).` | `.claude/state/attest-logs/20261102T190505Z.798.log` |

`gates.sh --fast` runs nothing here: this repository's `project.conf` is not
bootstrapped (`BOOTSTRAPPED=no`), so every gate is UNCONFIGURED and the
harness's real gate is the self-test. Its shape is therefore uninformative
rather than red; the run did flag `UNTRACKED .claude/tests/story.test.sh`
(stage it with the commit). `check-sigpipe.sh` (60 files, 0 findings) and
`check-grep-count.sh` (0 findings) are clean over the tree with the new suite.

**Failure, verbatim** (from the story log; 43 FAIL lines, excerpted - the full
list is in the log):

```
=== story ===

  the oracle: the fixture's literal bodies are check-boundaries.sh's section() reading

  AC-1: story.sh section prints the body of one named section
    FAIL section Handoff: RED -> GREEN exits 0
         expected: 0
         actual:   127
    FAIL section Handoff: RED -> GREEN prints its body byte for byte, ending at the fenced `## ` line, heading excluded
         expected: 
         Run it:
         
         ```bash
         bash scripts/run.sh
         
         actual:   
...
    FAIL the id `../X` prints the refusal its callers print, on stderr
         expected: error: story id '../X' is not one path component: an id is letters, digits, '.', '_' or '-', and starts with a letter or digit
         actual:   bash: scripts/story.sh: No such file or directory
...
  AC-1: lib.sh's story_section is the extractor story.sh calls (C-2)
    FAIL story_section <file> "Handoff: RED -> GREEN" returns 0
         expected: 0
         actual:   127
...
  AC-3: the real tree
    FAIL story_problems over the real tree prints nothing: advance-story reads by section through a per-phase table and no longer reads the whole file first, complete-story and lead-po name `bash scripts/story.sh section`, both commands permit story.sh, and CLAUDE.md's Running things block lists it
         expected: 
         actual:   .claude/commands/advance-story.md: still reads the whole story file first
         .claude/commands/advance-story.md: has no per-phase section table
         .claude/commands/advance-story.md: does not read the story by section
         .claude/commands/advance-story.md: does not permit story.sh
         .claude/commands/complete-story.md: does not read the story by section
         .claude/commands/complete-story.md: does not permit story.sh
         .claude/agents/lead-po.md: does not read the story by section
         CLAUDE.md: Running things does not list story.sh

  AC-3: the fixture, compliant by construction

  AC-3: advance-story.md, one site regressed at a time

  AC-3: complete-story.md and lead-po.md

  AC-3: CLAUDE.md's Running things block

  AC-3: every site regressed at once, in the C-4 order

story: 54 passed, 43 failed
FAIL story  did 54 units of work, below the floor of 97 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

**Why this is the right failure.** The suite loads and every assertion runs:
no syntax error, no fixture error. 42 failures are exit 127 and the shell's `bash:
scripts/story.sh: No such file or directory` (39 asserts on story.sh) or exit 127 from an undefined `story_section`
(3, the C-2 block) - exactly the two things C-1/C-2 contract GREEN
to write, and nothing else. The 43rd is the real-tree guard printing the eight
lines for the eight unwritten sites (C-3). The 54 passes: the oracle block (8),
the guard's 34 fixture assertions (3 compliant, 30 single-site, 1 all-sites), and 12 story.sh
assertions that pass vacuously while the script is missing (every "prints
nothing on stdout" and the "exits 0/prints nothing" for empty outputs); each
of those is paired with an rc or stderr assertion that is red now.

**Candidate check, outside the suite.** To confirm the expected values are
self-consistent (not that GREEN must look like this), I ran a throwaway
candidate `story.sh` from the session scratchpad against a copy of the suite
whose `_in_fix`/`_in_src` pointed at it: `story: 93 passed, 4 failed` - the 4
being the three `story_section` assertions (candidate had no lib function) and
the real-tree guard. Two mutations of that candidate: prefix matching ->
exactly the three `Handoff` prefix assertions went red (`90 passed, 7
failed`); fence-AWARE stopping -> exactly the three fenced-body assertions
went red (`90 passed, 7 failed`). Nothing of the candidate is in the tree.

**Per test, what it asserts and which AC** (grouped; each line is one
`describe` block):

- oracle (C-5, AC-1): `section()` exists in check-boundaries.sh; the fixture's
  `Notes` heading really has three trailing spaces; the four literal bodies
  equal `section()`'s output; fence-aware control reads 9 lines; `section()`
  matches the prefix `Handoff`. 8 assertions, green on arrival by design (they
  check the oracle and the fixture, not production; the two controls are their
  negative controls).
- AC-1 section: Handoff body byte for byte, exit 0, empty stderr, equal to
  `cb_section`; Context keeps non-headings; AC keeps `---`; the fenced heading
  is its own section; Notes trimmed match to EOF, comment and trailing space
  kept, exit 0; Empty exits 0 and prints nothing; from a subdirectory.
- AC-1 controls: absent name exit 1 / stdout empty / exact stderr; `Handoff`
  prefix exit 1 / stdout empty / exact stderr; longer name exit 1; `notes`
  exit 1; `../X` exit 2 / exact refusal / stdout empty; `T-9` exit 1 / exact
  message.
- C-2: `story_section` returns 0 with the Handoff body; returns 1 and prints
  nothing for `Handoff`.
- AC-2: `sections` exit 0 and exact table; `frontmatter` exit 0 and exact
  lines; T-2 exit 1 / stdout empty / exact stderr; T-3 exit 1; T-4 sections
  exit 0 and empty; `sections ../X` and `frontmatter ../X` exit 2 and refusal.
- C-1 usage: six arg shapes, each `exit 2` + `usage:` in stderr, and stdout
  empty.
- AC-3 real tree: `story_problems "$REPO_ROOT"` prints nothing.
- AC-3 fixtures: compliant silent; trimmed allowed-tools entries silent; CRLF
  silent; then one regression per row of C-4 (see the suite for the 30
  single-site cases, including controls: a different sentence about the same
  path is silent; `sections` accepted as a documented limit) and the
  all-sites-regressed case giving the eight lines in order.

**Export shape the tests pin (fact, not suggestion):**

- `scripts/story.sh`, invoked as `bash scripts/story.sh <sub> ...` from the
  repository root and as `bash ../scripts/story.sh ...` from `src/`.
  Subcommands `section <id> <name>`, `sections <id>`, `frontmatter <id>`.
- `.claude/hooks/lib.sh` defines `story_section <file> <name>`, usable after a
  plain `. lib.sh` in `bash -c` with no `CLAUDE_PROJECT_DIR` set: stdout is
  the body, return 0 when present (even if empty), 1 when absent. Its stderr is
  NOT constrained.
- Exact strings GREEN must print (stderr unless said):
  - refusal, exit 2: `error: story id '<id>' is not one path component: an id is letters, digits, '.', '_' or '-', and starts with a letter or digit`
  - missing file, exit 1: `no story file at docs/backlog/stories/<id>.md`
  - absent name, exit 1: `no section "<name>" in docs/backlog/stories/<id>.md`
    then `  <name>` (two spaces) per heading, file order, trimmed names
  - no frontmatter, exit 1: `no frontmatter in docs/backlog/stories/<id>.md`
  - usage, exit 2: any line containing `usage:`
  - `sections` stdout: `<trimmed name>\t<N>` per heading, N = lines
    `section` prints for it
- NOT constrained: the usage wording beyond `usage:`; how story.sh finds the
  root (dirname or git); whether it shells out to awk; `story_section`'s
  implementation and stderr; behaviour for duplicate headings; CRLF story
  files (story files are LF by `.gitattributes`); the order of argument
  checks when both the id and the arity are wrong.

**Negative controls, expected values** (measured outside the framework where
the suite could not run them):

| Control | Threshold / expectation | Measured |
|---|---|---|
| fence-aware reading of Handoff (proves the fence case discriminates) | must differ from 5 lines | 9 lines (ran in the suite: passes in RED, it needs no production code) |
| `section()` with prefix `Handoff` (proves the whole-heading control discriminates) | non-empty, = Handoff body | = Handoff body (ran in the suite) |
| `story.sh section T-1 Handoff` | exit 1, stdout empty | candidate: exit 1; prefix-mutated candidate: exit 0 with body, 3 asserts red |
| `story.sh frontmatter T-2` (two `---` rules, no frontmatter) | exit 1 | candidate: exit 1 |
| `story.sh frontmatter T-3` (never closed) | exit 1 | candidate: exit 1 |
| `story.sh section ../X` | exit 2 | candidate: exit 2 |
| `story_problems` over each one-site fixture | exactly the one C-4 line | all 34 fixture assertions pass in RED (they test the guard, which is in the test file) |
| `story_problems "$REPO_ROOT"` | empty | 8 lines today (above); GREEN makes it empty |

The story.sh rows were measured against a scratchpad candidate, not the shipped
module: confirming them against the real `scripts/story.sh` is GREEN's job.

**Contract amendments made in RED:** C-1 (absent-name stderr shape, empty
vs absent, `sections` N and trimmed names, frontmatter requires line 1 `---`
plus its message, success writes nothing to stderr, case-sensitive,
subdirectory, usage pin, byte-for-byte meaning) and C-4 (line format
`<path>: <reason>`, order, `file is missing`, what "inside the fenced block"
means, the `sections` substring limit). Both are written in place under the
blocks, with reasons. No acceptance criterion changed.

**Files touched:** `.claude/tests/story.test.sh` (new),
`.claude/tests/floors.conf` (`floor | story | 97` and a note at the foot),
`.claude/tests/selftest.test.sh` (`story 97` in the COUNTS table), this story
(Contract C-1/C-4 amendments, Test plan, Handoff).

**Floor:** 97 executed (`story: 54 passed, 43 failed` before GREEN, local).
selftest.sh reads the PASSED count, so the suite sits below its floor until
GREEN lands - expected.

**Deferred verifications:** DV-1 and DV-2 are GATES' and I decline them: RED
has no `story_section` or prose to mutate. One note for whoever runs DV-1: its
first sentence says a mutation that stops at `## ` "inside a fence as well as
outside" is "the reading this story rejects" - that is in fact the reading this
story ADOPTS (`section()`'s, fences not special), so that mutation changes
nothing, as the DV says. The mutation that DOES go red on the fence assertions
is the opposite one, making `story_section` fence-aware (three asserts red on
the candidate). The DV's binding instruction - prefix matching must turn the
`Handoff` control red and nothing else story.sh-related - matches what the
candidate showed (the `section ... Handoff` exit/stdout/stderr asserts, plus
`story_section ... Handoff returns 1` once the lib function exists).

**For the implementation:** the other suites C-4 lists read these files and
are not touched by this suite's fixtures (they are all under `$WORK`); no
other suite pins the sentence `Read \`docs/backlog/stories/$1.md\` first.`
(grepped), so removing it breaks nothing else. Keep `Create and switch to the
story's branch` in advance-story.md (boundaries.test.sh). New function at the
END of lib.sh, per C-2, so lib.test.sh's pinned lines do not move.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return, with the PASTED probe output. -->

## Diff review

### Round 1 (fresh feature-developer, resolved claude-opus-5-5, 2026-11-02)

Verdict: fix 1 first.

**Must fix 1. The GATES → REVIEW row leaves out sections its own procedure
reads** (`.claude/commands/advance-story.md:28`). The procedure checks
`## Gate probes` ("must record it having been observed to fail") and writes a
PR body listing the acceptance criteria with their tests, but the row names
neither `Gate probes` nor `Acceptance criteria` / `Test plan`. GREEN → GATES
and GATES → REVIEW both record the resolved model under `## Model guidance`,
which neither row names. Fix: add them. The guard pins only the row
prefixes, so the suite stays green.

**Should fix 2. A repeated `## <name>` cuts `section` off silently.** Real
case: `bash scripts/story.sh sections HARNESS-054` lists `Notes` three times
(80, 22, 237 lines): heredoc lines inside a fenced excerpt in that story's
Notes are column-0 `## ` lines, so `section ... Notes` returns 80 of ~340
lines. Inherited from `section()`'s reading, which AC-1 pins. Proposed: a
stderr note when the name occurs more than once.

**Nice to have 3. CR not trimmed** from headings or the `---` line: on a
Linux awk with CRLF story files every lookup misses. Not reproducible here
(gawk on this host drops the CR; this repo pins `*.md eol=lf`).

Orchestrator reproduction: `bash scripts/story.sh sections HARNESS-054 |
grep -n '^Notes'` printed `Notes 80`, `Notes 22`, `Notes 237`; the table rows
read as quoted.

PO decisions:
- 3. Must fix 1 is a prose fix in GATES. The rows now differ from C-3's
  block: GREEN → GATES adds `Model guidance`; GATES → REVIEW adds
  `Gate probes`, `Acceptance criteria`, `Test plan`, `Model guidance`. C-3's
  block was wrong against the procedure it serves; the guard's pins (the two
  row prefixes) are unchanged.
- 4. Should fix 2 is a behaviour change to `story.sh` with no failing test
  in front of it, so it is not made in GATES. This story mitigates it in
  prose: advance-story.md tells the orchestrator how a fenced `## ` line
  splits a section (premise corrected by round 2 and PO decision 5: copies
  are joined, not cut). The stderr note is a follow-up story (RED first),
  together with finding 3.
### Round 2 (fresh feature-developer, resolved claude-opus-5-5, 2026-11-02)

Verdict: fix 1 first. Every table row now names every section its procedure
reads; story 97/0, procedure 118/0, dispatch 67/0, policy 17/0, reporting
27/0, phase 73/0, boundaries 502/0 on HEAD (37e6b08).

**Must fix 1. The new duplicate-heading sentence describes the wrong
behaviour.** `story_section` turns printing back on at every `## <name>` with
the same name, so `section` JOINS the copies; it does not stop at the second.
`bash scripts/story.sh section HARNESS-054 Notes | wc -l` gives 339
(80+22+237), the whole of Notes. Round 1's "80 of ~340" was read from
`sections`, never from `section`. What does lose or mix content: the section
holding a fenced `## ` line ends there (truncated, and listed only once), and
if the fenced name is also a real section's name, that real section's read
starts with the stray lines. Fix: say that, and correct PO decision 4.

Orchestrator reproduction, on a different input (a 4-line story of my own):
`## A / a1 / ``` / ## B / fenced / ``` / a2 / ## B / real b / ## C`.
`story_section A` printed `a1` and the opening fence only (`a2` lost);
`story_section B` printed `fenced`, the closing fence, `a2`, `real b`.
And `section HARNESS-054 Notes | wc -l` = 339.

PO decision 5: PO decision 4's premise ("cut at the second") was wrong; the
deferral stands (a behaviour change needs a failing test first), and the
follow-up is now specified against the measured behaviour above.
### Round 3 (fresh feature-developer, resolved claude-opus-5-5, 2026-11-02)

Verdict: fix 1 first.

**Must fix 1. "`section` prints every copy joined" holds only for adjacent
copies.** `story_section` exits at the first heading of a different name, so
when a fenced `## X` sits in an earlier section and a real `## X` comes later
past another heading, `section X` prints the stray lines INSTEAD of the real
body, exit 0. Joining happens only when no other heading lies between the
copies (HARNESS-054's three adjacent `Notes`, and round 2's probe).

**Nice to have 2.** `grep -n '^## '` lists the fenced heading too, unmarked;
add `-e '^```' -e '^~~~'` so fence lines show between the headings.

**Nice to have 3.** The header comments of `story_section` and `story.sh` say
a section ends "before the next column-0 `## `", but a later heading of the
same name continues it. Comment only.

Orchestrator reproduction, on a different input:
`## P / p1 / ``` / ## Q / stray / ``` / p2 / ## R / r / ## Q / real-q / ## S`;
`story_section Q` printed `stray`, the closing fence and `p2`, rc=0, and
never `real-q`.

PO decision 6: three rounds have each found the previous description of the
mechanics incomplete. The sentence stops enumerating cases: it says that a
fenced `## ` line makes `section` unreliable for that story (truncated,
stray or missing lines, exit 0 regardless), and gives the workaround with
fence lines listed (nice to have 2, taken). Nice to have 3 is taken (comment
only, no behaviour). The follow-up carries round 3's case alongside round
2's.
### Round 4 (fresh feature-developer, resolved claude-opus-5-5, 2026-11-02)

Every claim in the sentence and both comments probed true on scratch stories
(cut short, stray lines before a real copy, stray lines in place of a
non-adjacent real copy, same-name continuation, no match rc=1); the
workaround grep lists fence lines in pairs on this story; the double-backtick
span is valid markdown; no suite pins the removed wording.

Nice to have (recorded as follow-up, not made: a change restarts the loop):
1. The workaround is a shell `grep`, which `/advance-story`'s allowed-tools
   do not permit; the Grep tool with `^(## |```|~~~)` does the same.
2. "in a story that has one `section` can" wants a comma after "one".
3. The comments' "a later heading of the same name" means the NEXT heading;
   say "if that heading has the same name, the section continues".

Verdict: Ship.
## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-03T01:07:31Z
    commit: fc029ba (working tree had uncommitted changes)
    tree:   47958fd6ca92de3be7b0715efb5d9b5961913bd3
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

## Notes

- PO decision 1 (2026-11-02, PLANNED → RED): HARNESS-083 has since merged
  (DONE), so the reason for leaving `check-boundaries.sh` alone no longer
  holds. The convergence stays out of scope anyway: the criteria were cut
  without it, and it changes what CI reads (prefix callers), which wants its
  own story and its own probe. It is now unblocked, not deferred.
- PO decision 2 (2026-11-02, PLANNED → RED): AC-1's "`valid_story_id`'s
  message" is pinned in C-1 as the refusal line its callers already print;
  the function itself prints nothing. No criterion changed.
- Epic check: `epic:` is empty, so there is no done-when to compare.
- Callers (C-6): no existing signature changes. `valid_story_id` is called,
  not changed; its callers today are gates.sh (107, 475), new-story.sh (12)
  and phase.sh (157), none touched.
- Follow-up, not this story: once HARNESS-083 has merged, make
  `check-boundaries.sh`'s `section()` call `story_section` and list its
  prefix-matching callers (the `Handoff` lookup) before changing it.

- 2026-11-02, RED verified by the orchestrator (claude-opus-5-5) without
  re-running: `attest.sh check` answered `fresh` for `bash scripts/selftest.sh
  story` (exit 1, 54 passed / 43 failed: 42 on the missing story.sh /
  story_section, 1 the real-tree guard naming the unwritten sites; the floor
  of 97 unmet as expected), `selftest` (exit 0) and `bash scripts/gates.sh
  --fast` (exit 0, nothing configured). Read the oracle wiring: `section()` is
  copied out of check-boundaries.sh and eval'd. DV-1's text corrected (see
  the block). Resolved: RED, test-developer, claude-opus-5-5.

- 2026-11-02, GREEN (feature-developer, `model: opus`, resolved
  claude-opus-5-5; no override in the dispatch). Built `scripts/story.sh`,
  `story_section` at the end of `.claude/hooks/lib.sh`, the C-3 prose
  (advance-story.md opening + table + dispatch sentence, complete-story.md,
  lead-po.md `## Orchestrating`, CLAUDE.md `## Running things`), both
  commands' `allowed-tools` gain `Bash(bash scripts/story.sh:*)`, VERSION
  104 -> 105 (2026-11-02). `check-boundaries.sh` untouched.
  `story_section` passes the name through `ENVIRON`, not `awk -v`, so a
  backslash in a heading name is not escape-expanded.

  **GREEN confirmations of the handoff's controls**, measured against the
  shipped `scripts/story.sh` + `lib.sh` copied into a scratch tree (story with
  Context, Handoff: RED -> GREEN holding a fenced `## fenced`, Empty,
  `Notes   `), outside the suite:

  | Control | RED (candidate) | GREEN (shipped) |
  |---|---|---|
  | `section T-1 "Gate results"` (absent) | exit 1, exact stderr | exit 1, stdout empty, stderr `no section "Gate results" in docs/backlog/stories/T-1.md` then `  Context`, `  Handoff: RED -> GREEN`, `  fenced`, `  Empty`, `  Notes` - matches |
  | `section T-1 Handoff` (prefix) | exit 1, stdout empty | exit 1, stdout empty, the same absent-name stderr - matches |
  | `section ../X Context` | exit 2 | exit 2, stdout empty, stderr exactly the refusal line - matches |
  | `frontmatter T-2` (two `---` rules, no frontmatter) | exit 1 | exit 1, stdout empty, `no frontmatter in docs/backlog/stories/T-2.md` - matches |
  | `frontmatter T-3` (never closed) | exit 1 | exit 1, same message - matches |
  | `section T-1 Empty` | exit 0, nothing | exit 0, stdout empty, stderr empty - matches |
  | `story_problems "$REPO_ROOT"` | 8 lines | empty (suite assertion green) |

  No divergence from RED's numbers. Inside the suite: `story: 97 passed, 0
  failed`, floor 97 met.
- 2026-11-02, GREEN verified by the orchestrator (claude-opus-5-5) without
  re-running: `attest.sh check` answered `fresh` with `exit: 0` for
  `bash scripts/selftest.sh` story (97/0, floor met), selftest, boundaries,
  procedure, policy, reporting, phase, mutate and lib, and for
  `bash scripts/gates.sh --fast`. No test file in the diff. Read story.sh and
  `story_section` against C-1/C-2 and the prose against C-3. Resolved: GREEN,
  feature-developer, claude-opus-5-5.
- 2026-11-02, GATES: DV-1 and DV-2 run by the orchestrator via `mutate.sh`,
  results pasted in their blocks. Full gate run dispatched
  (feature-developer, resolved claude-opus-5-5); `attest.sh check -- bash
  scripts/gates.sh` answered `fresh`, `exit: 0`, verdict at log line 17 of
  `.claude/state/attest-logs/20261102T230014Z.100672.log`:
  `All required gates passed (0 ran, 7 unconfigured, 0 known).` As always in
  this repo, the self-test at GATES → REVIEW is the real check.
- Follow-up, not this story (diff review round 1, findings 2 and 3):
  `story.sh section` warns on stderr when a heading name occurs more than
  once (HARNESS-054 lists `Notes` three times; `section` joins all three,
  339 lines; a fenced `## X` before a non-adjacent real `## X` makes `section X` print the stray lines instead of the real body, exit 0 - diff review rounds 2 and 3; a section holding a fenced `## ` line is truncated with no
  flag - see diff review round 2), and `story_section`, `headings`
  and `frontmatter` trim a trailing CR. Both need a failing test first.
- Follow-up, not this story (diff review round 4, nice to have 1-3): name the
  Grep tool for the workaround in advance-story.md, add the comma, and
  reword the same-name parenthetical in lib.sh and story.sh. Prose and
  comments only; take them with the stderr-note follow-up.
