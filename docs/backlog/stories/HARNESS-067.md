---
id: HARNESS-067
title: The feature developer reuses before it writes
slug: the-feature-developer-reuses-before-it-w
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-067-the-feature-developer-reuses-before-it-w
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/agents/feature-developer.md, .claude/tests/briefs.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Today the GREEN brief, `.claude/agents/feature-developer.md`, says in Method
step 2 only: "Write the simplest thing that could make them pass. Resist
building for stories that have not been written yet." That names the goal and
gives no method for reaching it. Nothing in it says to look for what already
exists before writing new code: an existing helper, the standard library, an
installed dependency. Nothing says that a fix to a shared function belongs in
the shared function rather than in one caller, or that "simplest" stops short of
validation, data-loss handling, security and accessibility.

The source is a comparison with **ponytail** (github.com/DietrichGebert/ponytail,
MIT licence, commit 09c434a, 2026-10-18), whose `skills/ponytail/SKILL.md` is a
"smallest complete change" ladder for a coding agent. This story adapts the
ladder and four of its rules to GREEN. It does not take the test rules, see Out
of scope. Ponytail's benchmark (`benchmarks/results/2026-10-07-agentic.md`)
claims -53% code at level correctness for these rules. That is the source's own
claim, measured without a shell and outside a TDD loop, so nothing here depends
on the number. The story claims only that the brief carries the ladder and that
the test-writing brief does not.

**Where it lives, decided: `feature-developer.md` only, not `tdd-cycle`.** Both
developer agents load `tdd-cycle` (`test-developer.md` line 11:
"Load the `tdd-cycle` skill before starting"). A ladder in the skill reaches the
Test Developer's context. Its first rung, "does it need to exist?", is the right
question for production code and the wrong one for a test. Only
`feature-developer.md` is read by GREEN alone.

**Hard constraint: the lean mindset does not reach RED.** Ponytail's own test
rule is "new non-trivial logic leaves one small test … Trivial changes need
none". That contradicts law 1 (no production code without a failing test that
demanded it) and law 4 (every acceptance criterion has a test that fails when it
is broken). Ponytail's own benchmark reports the injected-bug catch rate falling
from 77% to 69% under its rules. So this story pins the ladder's **absence**
from `test-developer.md` and from `tdd-cycle/SKILL.md` (AC-4), and the absence of
ponytail's test-minimising phrasing from all three files.

**The required gate holding this story's artefact** is the harness self-test
(`bash scripts/selftest.sh`, which CI runs in full): a new suite, `briefs`,
fails if the ladder is removed from the GREEN brief or appears in the RED one.
The site is prose, so nothing executes it. This is the shape `tdd-cycle` calls
"code no machine you have can execute: grep for the shape", and it follows the
precedent of `procedure.test.sh` and `policy.test.sh`: one function returns one
line per violation; it runs over the real tree, where it must print nothing, and
over fixtures that are compliant by construction except for one regression,
where it must print exactly that one line.

## Acceptance criteria

- **AC-1** — The ladder is in the GREEN brief, in order. Given the repository,
  when `brief_problems` runs over it, then `.claude/agents/feature-developer.md`
  has a section whose heading line is exactly `## Reuse before you write`. That
  section holds five numbered items whose lines begin with the five rung labels
  of Contract C-2, rung *k* as item *k*. *Negative controls:* a fixture with
  rung 3 deleted prints exactly the C-4 "has no rung 3" line. A fixture with
  rungs 2 and 3 swapped prints exactly the two C-4 "is not item" lines. A
  fixture with the rung labels present but the heading changed to
  `## Reuse first` prints exactly the "has no section" line, and none of the
  rung lines.
- **AC-2** — The rules that bound "lazy" are in that section. Given the
  repository, when `brief_problems` runs, then the `## Reuse before you write`
  section holds a bullet beginning with each of the five rule labels of Contract
  C-2. The bullet beginning `- **Never cut:**`, with its continuation lines,
  names each of the four C-2 protected words. *Negative controls:* a fixture
  without the `Before a bug fix` bullet prints exactly its one "has no rule"
  line. A fixture whose `Never cut` bullet omits `accessibility` prints exactly
  the one "does not name" line. A fixture with the `Never cut` bullet moved out
  of the section, below the next `## ` heading, prints the "has no rule" line
  for it.
- **AC-3** — Method step 2 points at the section. Given the repository, when
  `brief_problems` runs, then step 2 of the `## Method` section of
  `feature-developer.md` (the line beginning `2. ` and its continuation lines)
  contains the fixed string `Reuse before you write`. *Negative control:* a
  fixture whose step 2 is the current text, "Write the simplest thing that could
  make them pass.", prints exactly the C-4 step-2 line.
- **AC-4** — The ladder does not reach the test-writing brief. Given the
  repository, when `brief_problems` runs, then neither
  `.claude/agents/test-developer.md` nor `.claude/skills/tdd-cycle/SKILL.md`
  contains any C-3 ladder needle. None of the three files contains either C-3
  ponytail needle. *Negative controls:* a fixture whose `test-developer.md` gains
  the line `1. **Does it need to exist?** Skip it.` prints exactly one "carries
  the GREEN reuse ladder" line naming that file and that needle. A fixture whose
  `tdd-cycle/SKILL.md` gains "Trivial changes need none." prints exactly one
  "carries ponytail's" line.
- **AC-5** — The guard runs in CI and cannot be emptied. Given the repository,
  when the full self-test runs, then the `briefs` suite runs and passes.
  `.claude/tests/floors.conf` carries a `briefs` floor equal to the executed
  assertion count measured at GATES. The hand-copied table in
  `.claude/tests/selftest.test.sh` carries the same value, so the `selftest`
  suite passes.

## Contract

**Writes:** `.claude/agents/feature-developer.md`, `.claude/tests/briefs.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

RED may amend any block below, in place, with a reason; GREEN then builds what
the amended block says. The acceptance criteria above are frozen and change only
through `## Amendments`.

**C-1. The suite.** `.claude/tests/briefs.test.sh`, sourcing `_lib.sh` the way
`procedure.test.sh` does (`describe`, `assert_eq`, `summary`). It defines
`brief_problems <root>`, which prints one line `<relative-path>: <reason>` per
violation in the order the checks are listed in C-4, prints nothing when
compliant, and always returns 0. The suite asserts:
- `brief_problems "$REPO_ROOT"` prints nothing (red in RED: the section does not
  exist yet);
- a compliant fixture, built by construction and never copied from the real
  tree, prints nothing;
- one fixture per negative control in AC-1 to AC-4 prints exactly its line.

Matching is pure bash (mapfile, `case`, `[ = ]`): no grep or awk fork per needle,
as in `procedure.test.sh` (HARNESS-023 measured 109 s against 10.6 s for the
same output on Windows). Strip a trailing CR from each line, so a CRLF checkout
reads the same as an LF one. The fixture lives under a `mktemp -d` work
directory removed on EXIT, never in the tree.

**C-2. Presence needles, settled: read them out, do not reword them.**
The file is `.claude/agents/feature-developer.md`.
- *Section:* from the line exactly `## Reuse before you write` up to, not
  including, the next line beginning `## `, or EOF. It is placed after
  `## Method` and before `## When the brief tells you *how*`; the guard does not
  check where it sits.
- *Item:* inside the section, a line matching `^[0-9]+\. ` starts item *n*,
  where *n* is that integer.
- *Rungs:* rung *k* is present when some item's line, after its `N. ` prefix,
  **begins with** label *k*. It is in order when that item's number is *k*.
  1. `**Does it need to exist?**`
  2. `**Already in this codebase?**`
  3. `**The standard library or the platform?**`
  4. `**A dependency already installed?**`
  5. `**Only then, the minimum new code.**`
- *Bullet:* inside the section, a line beginning `- ` plus the following
  non-blank lines that begin with whitespace. A rule is present when some
  bullet's first line **begins with** its label:
  - `- **The tests decide what must exist.**` (the ladder chooses *how* to
    satisfy a frozen test, never *whether*: a behaviour a test demands needs to
    exist, by definition)
  - `- **Before a bug fix, grep every caller.**` (of the function touched, then
    fix the shared code once, not one caller)
  - `- **Lazy about the solution, never about completeness.**` (finish every
    caller, fixture and config the change breaks)
  - `- **Moved or merged code keeps its checks.**` (its validation and its error
    handling)
  - `- **Never cut:**`
- *Protected words:* the `- **Never cut:**` bullet, first line plus
  continuation lines, contains each of these fixed strings: `validation at trust
  boundaries`, `error handling that prevents data loss`, `security`,
  `accessibility`.
- *Method step 2:* the section from the line exactly `## Method` to the next
  `## `; its step 2 is the line beginning `2. ` plus its continuation lines. It
  contains the fixed string `Reuse before you write`.

Rung 4's text must say never to add a dependency for a few lines. The guard does
not pin that wording, but GREEN writes it.

**C-3. Absence needles, settled.** These are fixed strings, case-sensitive,
matched anywhere in the file.
- *Ladder needles,* judged in `.claude/agents/test-developer.md` and
  `.claude/skills/tdd-cycle/SKILL.md`: `Reuse before you write`, the five rung
  labels of C-2, and the five rule labels of C-2 without their leading `- `.
- *Ponytail needles,* judged in those two files and in
  `.claude/agents/feature-developer.md`: `one small test` and `need none`.
An absence needle has a known limit: it is satisfied by any other spelling of
the same idea. The presence checks in C-2 are the strong half. The absence half
catches the copy-paste route, which is how the ladder would most likely arrive.
Both needles were checked against the current tree: none of the three files
contains any of them today (verified at PLANNED, see Notes).

**C-4. Output lines, byte for byte.** `F` = `.claude/agents/feature-developer.md`.
`<label>` is the label exactly as in C-2, inside backticks.
- `<file>: file is missing` (for any of the three files; no other line for that file)
- `F: has no \`## Reuse before you write\` section` (then no rung, rule or word lines)
- `F: its reuse ladder has no rung <k>: \`<label>\``
- `F: rung <k> \`<label>\` is item <n> of its reuse ladder, not item <k>`
- `F: its reuse section has no \`<rule label>\` rule`
- `F: its \`- **Never cut:**\` rule does not name \`<word>\``
- `F: its Method step 2 does not name \`Reuse before you write\``
- `<file>: carries the GREEN reuse ladder's \`<needle>\``
- `<file>: carries ponytail's test-minimising \`<needle>\``

Order: the files in the order F, `test-developer.md`, `tdd-cycle/SKILL.md`. Within
F: section, rungs 1 to 5, rules in C-2 order, words in C-2 order, step 2, then
ponytail needles. Within the other two files: ladder needles in C-3 order, then
ponytail needles.

**C-5. The brief text.** GREEN writes the section in the voice of the rest of
`feature-developer.md`. It covers the ladder ("take the first that works");
rung 2's "use it the way the surrounding code does"; and the five rules. Step 2
keeps its warning against building for stories not yet written, and adds the
pointer. The text names no `docs/` path that `.claude/harness/docs-shipped.conf`
neither ships nor declares written: `shipped-docs.test.sh` scans every agent
file. Credit ponytail in one line inside the section (repo and licence).

**C-6. Floors.** The `briefs` floor is the `N` of `briefs: N passed, 0 failed`
from `bash scripts/selftest.sh briefs` at GATES. It goes in `floors.conf` and in
the COUNTS heredoc of `selftest.test.sh`, in the same commit, alphabetically
(after `boundaries`).

**Oracle partition.** Every criterion is **mechanical**: pin the needles and the
output lines exactly, and leave nothing open-ended. Nothing is oracle-free, and
the only settled values are the C-2 and C-3 needles. Read them out; do not
improve their wording.

**Test-only dependencies:** none (bash and coreutils only, per rules.md
"Portability").

**Changed signatures:** none. No existing export changes.

## Deferred verifications

**DV-1, defect put back (the story's central claim).** With rung 3's line
deleted from the REAL `.claude/agents/feature-developer.md`, the guard **must**
fail with exactly the C-4 `has no rung 3` line. Run:
`bash scripts/mutate.sh .claude/agents/feature-developer.md '/^3\. \*\*The standard library or the platform?\*\*/d' -- bash scripts/selftest.sh briefs`.
The briefs run must fail, and mutate.sh must report the file restored. RED
cannot run this, because the section does not exist until GREEN writes it.
**Owner: GATES.**

**DV-2, the absence rule against a real line.** This probes the rule against
the tree it judges (rules.md, "A rule is probed against the tree it judges").
Append the line `2. **Already in this codebase?** Use it.` after a REAL heading
of `.claude/agents/test-developer.md`:
`bash scripts/mutate.sh .claude/agents/test-developer.md 's/^## A test-only dependency is yours to declare$/&\n2. **Already in this codebase?** Use it./' -- bash scripts/selftest.sh briefs`.
The guard **must** fail with exactly one `carries the GREEN reuse ladder's`
line for that needle, and the file must be restored. RED could run this, but
GATES owns it, so that it runs against the finished guard. **Owner: GATES.**

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-067` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`: resolved to **Opus 5.5 (`claude-opus-5-5`) by explicit override**, not the planned `fable`. The user's Fable usage limit was reached, and the user chose in chat to re-run the lead-po planning for HARNESS-067 and 068 on Opus and to record the override in both stories. What it changes: this PLANNED ran on `opus`, so if RED has to send this contract back, that counts against this planning run, not against `fable`. It is not evidence for or against the PLANNED row of `models.conf`.

## Out of scope

- **Anything in `test-developer.md` or `tdd-cycle`.** The lean mindset must not
  reach RED. Ponytail's "one small test, not coverage" and "trivial changes need
  none" contradict laws 1 and 4. Its own benchmark shows the injected-bug catch
  rate falling from 77% to 69%. AC-4 pins the absence; do not "harmonise" the
  two briefs.
- **Ponytail's rung 5, "one line a reader gets at a glance"**, and its
  `shortcut:` comment convention. These are style rules, not reuse rules, and
  each would need its own reason to exist here.
- **Ponytail's levels (lite/full/ultra)**, its persona ("lazy senior dev"), and
  its reply-format rule. The harness has its own reporting rule (rules.md,
  "Reporting to the user").
- **The review half** (`ponytail-review`). That is HARNESS-068, a separate
  behaviour with a disjoint footprint.
- **Enforcing the ladder.** Nothing checks that GREEN *followed* it, and this
  story does not try. The guard pins that the brief says it. A reviewer reading
  a diff for duplicated helpers is HARNESS-068's job.
- **Measuring the -53% claim** in this harness. Not attempted, and nothing here
  depends on it.

## Test plan

## Handoff: RED -> GREEN

## Gate results

## Notes

- **Source and credit.** The ladder and rules are adapted from ponytail,
  github.com/DietrichGebert/ponytail, MIT licence, commit 09c434a (2026-10-18),
  file `skills/ponytail/SKILL.md`. Its benchmark figures are the source's own
  claims, measured without a shell and outside a TDD loop.
- **Planned on Opus 5.5 by explicit override.** PLANNED was dispatched on Opus
  (`claude-opus-5-5`), not lead-po's declared `fable`, because the user's Fable
  usage limit was reached. The user chose in chat to re-run the lead-po planning
  for HARNESS-067 and 068 on Opus and to record the override in both stories.
  The same record is in `## Model guidance`.
- **Absence needles checked at PLANNED.** None of the C-3 needles occurs today
  in `test-developer.md`, `tdd-cycle/SKILL.md` or `feature-developer.md`.
  The real-tree assertion is therefore red in RED for exactly one reason: the
  section is missing.
- **Floors and HARNESS-068.** This story owns `floors.conf` and
  `selftest.test.sh`. HARNESS-068 adds assertions to an existing suite and
  deliberately leaves both files alone, so the pair is `clear`.
