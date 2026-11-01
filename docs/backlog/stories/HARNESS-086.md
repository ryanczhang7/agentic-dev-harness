---
id: HARNESS-086
title: The orchestrator reads a story by section through scripts/story.sh
slug: the-orchestrator-reads-a-story-by-sectio
epic: 
type: feature
status: todo
phase: PLANNED
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

`<id>` is validated with `valid_story_id` (exit 2 on refusal, its message)
and resolved to `docs/backlog/stories/<id>.md` under the repository root; a
missing file exits 1 with `no story file at docs/backlog/stories/<id>.md`.
`<name>` is matched as the **whole** text after `## ` (trailing spaces
trimmed), so `Handoff` does not match `Handoff: RED -> GREEN`. Unknown
subcommand or missing argument: exit 2 and a usage line. Output is the
section's lines unchanged, including blank ones and HTML comments: the
orchestrator reads what is there, and `strip_comments` is the caller's
choice.

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

**DV-1 (defect put back). Owner: GATES.** With `story_section` mutated to
stop at the first `## ` line **inside a fence as well as outside** - which is
the reading this story rejects - nothing must go red (the fence case is a
boundary in both readings); so the mutation that earns AC-1 is the other one:
make `story_section` match the name as a prefix, and AC-1's `Handoff`
control **must** go red while every other assertion stays green. RED cannot
run this: `story.sh` does not exist. Run against `bash scripts/selftest.sh
story`; paste the red, the count and the restore.

**DV-2 (a rule probed against the tree it judges). Owner: GATES.** With a
real line of `.claude/commands/advance-story.md` mutated to put `Read
`docs/backlog/stories/$1.md` first.` back, `story_problems "$REPO_ROOT"`
**must** print exactly `still reads the whole story file first`, and nothing
once restored.

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

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. -->

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return, with the PASTED probe output. -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run. Do not paste or
     edit it. -->

## Notes

- Follow-up, not this story: once HARNESS-083 has merged, make
  `check-boundaries.sh`'s `section()` call `story_section` and list its
  prefix-matching callers (the `Handoff` lookup) before changing it.

