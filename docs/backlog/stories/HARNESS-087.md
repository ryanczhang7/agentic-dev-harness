---
id: HARNESS-087
title: rules.md keeps every rule and moves its worked cases into the tdd-cycle skill
slug: rules-md-keeps-every-rule-and-moves-its
epic: 
type: chore
status: todo
phase: PLANNED
branch: story/HARNESS-087-rules-md-keeps-every-rule-and-moves-its
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/harness/rules.md, .claude/skills/tdd-cycle/SKILL.md, .claude/skills/tdd-cycle/reference/cases.md, .claude/tests/rules-trim.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Fourth of four (HARNESS-084..087): the orchestrator's standing context.
CLAUDE.md imports `.claude/harness/rules.md` with `@`, so its 399 lines are
in context on every turn of every session - the orchestrator's, the
subagents', the planner's. CLAUDE.md says of itself that it "stays short";
rules.md has grown by accretion, and most of the growth is worked cases:
the four needle anecdotes, the three probe-against-the-tree cases and the
release-38/40 story under "Non-negotiables", the HARNESS-014 numbers under
"Mutation work per story", the "two stories once compared the default
model" history under "The model each agent runs on", the four-private-copies
case under "Path ownership". Each was written where it was because the rule
beside it was broken once, and each is worth keeping - loaded on demand, by
the agent whose phase it is about, rather than re-sent to everyone on every
turn.

This is a `chore` with no behaviour change, and it runs the ordinary
RED → GREEN cycle rather than SCAFFOLD: RED writes a suite that is red today
(the line cap) and GREEN makes it green by moving text, so there is a failing
test in front of the change and no `## Scaffold inventory` is needed. The
rules themselves are kept whole: every heading, every labelled bullet, every
sentence another suite pins. What moves is the evidence behind them, into
`.claude/skills/tdd-cycle/reference/cases.md`, each case under its own
heading and cited from the rule it supports by path.

Five suites already read rules.md and are the net under this change:
`policy` (the `# Mutation work per story` heading, no per-story count),
`reporting` (`# Reporting to the user`, its seven labelled bullets and their
needles), `mutate` (the `.claude/state/**` bullet with `.bak`, `.active` and
`mutate.sh --check`), `new-story` (the section name in the template),
`settings` (the same state bullet: `phase-guard-declined.log` and its
`denied to `Edit` in `settings.json`` sentence). The
gate that fails if the trim breaks is `bash scripts/selftest.sh rules-trim`
(a new suite), and those five must stay green unchanged.

## Acceptance criteria

- **AC-1** — Given `.claude/harness/rules.md`, when its lines are counted,
  then there are at most 280 (399 today). *Control:* the suite is red on
  today's file.
- **AC-2** — Given rules.md after the trim, when its structure is read, then
  every line of C-1's list is present exactly: the six `# ` headings, each
  `- **Label.**` bullet opener, and the first line of each unlabelled bullet
  C-1 names. *Control:* a fixture with one opener removed is reported with
  exactly one line naming it.
- **AC-3** — Given `.claude/skills/tdd-cycle/reference/cases.md`, when it is
  read, then each case needle of C-2 is present in it, under a `## ` heading,
  and **absent** from rules.md; and rules.md names
  `tdd-cycle`'s `reference/cases.md` at least once in each of the
  three sections a case moved out of (`# Path ownership`, `# The model each
  agent runs on`, `# Non-negotiables`) and once in `# Mutation work per
  story`. *Control:* a fixture whose rules.md still carries one needle is
  reported with exactly one line.
- **AC-4** — Given `.claude/skills/tdd-cycle/SKILL.md`, when it is read, then
  it names `reference/cases.md` under its `## Details` list (the existing
  list of `reference/*.md`), so the file is reachable from the skill that
  loads it. This and AC-3's pointers can only be checked structurally.
- **AC-5** — Given the real tree after GREEN, when `bash scripts/selftest.sh
  policy`, `reporting`, `mutate`, `new-story` and `settings` run, then each passes with
  its floor met - the suites that pin rules.md's text were the net, and the
  net held. This is a GATES check, not a new assertion; it is listed so the
  trim is not called done on `rules-trim` alone.

## Contract

**Writes:** `.claude/harness/rules.md`, `.claude/skills/tdd-cycle/SKILL.md`, `.claude/skills/tdd-cycle/reference/cases.md`, `.claude/tests/rules-trim.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says.

**C-1. What stays, line for line (settled: read out of today's rules.md, do
not paraphrase).** The suite pins each as an exact whole line, or an exact
line prefix where the bullet wraps:

Headings, whole lines:

    # Path ownership
    # The model each agent runs on
    # Phase permissions
    # Non-negotiables
    # Mutation work per story
    # Reporting to the user

Bold paragraph openers at column 0, line prefixes:

    **The bootstrap exception.**
    **`.gitignore` has no single owner.**
    **Portability.**
    **A test that needs this answer asks for it; it does not reimplement it.**
    **The per-phase plan is `.claude/harness/models.conf`, not a judgement made
    **RED may declare a test dependency, and only a test dependency.**
    **When RED needs something the manifest cannot carry, it stops and says so.**
    **A gate failure whose only legal fix is a write the current phase forbids is a

Labelled bullet openers, line prefixes (`- **` through the closing `**`, or
the first line where the bold wraps):

    - **Lockfiles are permitted unchecked.**
    - **Some ecosystems have no in-file split at all**
    - **That is a property of the assertion, not of the phase or the run.**
    - **An assertion's needle is part of the assertion, and a needle that cannot
    - **A rule is probed against the tree it judges, not only against fixtures you
    - **Narrowing an input domain can be correct; loosening a comparison is always a
    - **Required per story.**
    - **How a mutation runs.**
    - **Not per story.**
    - **Lead with the outcome.**
    - **One next action, last.**
    - **Plain words.**
    - **Working notes stay in the story.**
    - **Evidence, not a diagnosis.**
    - **Five items, then offer the rest.**
    - **Agent-to-agent artefacts are exempt.**

Unlabelled bullets, line prefixes:

    - A test that has never been observed to fail is not a test.
    - A gate that has never been observed to fail is not a gate.
    - Do not weaken an assertion, add a `skip`, widen a tolerance, or delete a
    - Acceptance criteria are frozen once a story leaves PLANNED, for the same
    - `## Gate results` is written by `scripts/gates.sh`, never by hand.
    - `depends_on` and `branch` in a story's frontmatter are enforced by
    - Do not commit `.claude/state/**`.
    - Agentic scaffolding (`.claude/`, `docs/`, `scripts/`, `.github/`) never ships

Where a bold opener wraps today, the prefix above is its first line as it
stands, and GREEN keeps that break so the prefix holds. RED reads every
prefix out of the file with `grep -nF` before pinning it and amends this
block for any that is not there verbatim.
The ownership table (`| Agent | Writes | Never writes |` and its five rows)
and the phase table (`| Phase | May write | Meaning |` and its eight rows)
are pinned by their header lines. Reflowing prose that is not a pinned line is
allowed; deleting a rule sentence is not, and the reviewer judges that half.

**C-2. What moves, by needle.** Each needle is a fixed string present in
rules.md today; after GREEN each is in `cases.md` under a `## ` heading and
absent from rules.md:

| Needle | From | Case heading in cases.md |
|---|---|---|
| `four private copies in one project drifted apart` | Path ownership | `## Four private copies of "a source module"` |
| `compared "the default model" against a stronger one` | The model each agent runs on | `## "The default model" against itself` |
| `"a lockfile is permitted unchecked"` | Non-negotiables, needle rule | `## Four needles that could not fail` |
| `IMPLAUSIBLE: sed -i option` | same | same |
| `ci-local: 15 passed, 0 failed` | same | same |
| `check-grep-count.sh` was probed with | Non-negotiables, probe rule | `## Three guards green over a tree they could not see` |
| `read a here-string as a heredoc opener` | same | same |
| `written into `lib.sh` in release 38` | same | same |
| `keeping `-0` out of the coordinate generator` | Non-negotiables, narrowing rule | `## Negative zero: narrow the generator, not the comparison` |
| `on HARNESS-014 the` | Mutation work per story | `## HARNESS-014: eighteen mutations, no defect` |
| `The backup path is explicit rather than `$TMPDIR`` | Non-negotiables, state bullet | `## A backup that went to an unset $TMPDIR` |

Every needle above was checked present in rules.md at release 101 with
`grep -nF` (lines 67, 102-103, 212, 218, 220, 240, 247, 269, 290, 336, 326).
The `-0` row moves the worked example only; the rule's own sentence about
narrowing a generator stays, as the `Narrowing an input domain` opener pins.

The rule each supported keeps its statement and gains, where the case left,
a parenthetical pointer of the form `(the case: `tdd-cycle`,
`reference/cases.md`, "<heading>")`. The `.claude/state/**` bullet keeps
`.bak`, `.active` and `mutate.sh --check` (the `mutate` suite reads that
bullet); only the `$TMPDIR` sentence moves. The `(three|two) mutations`
word-pair stays out of both files (`policy`).

**C-3. `cases.md`.** `.claude/skills/tdd-cycle/reference/cases.md`, with a
one-paragraph preamble saying what it is (the evidence behind rules in
`rules.md`, moved here so it is loaded by the phase it is about), then one
`## ` section per row of C-2, carrying the moved text with the wording it
had, lightly edited only to stand alone. `SKILL.md` lists it under
`## Details` (the existing list of `reference/*.md`), one line. `shipped-docs.test.sh`
scans every `.md` under `.claude/skills` for `docs/` references; the moved
text mentions `docs/wiki/audits/` only with a trailing slash, which that
suite skips as a pattern, and RED checks the file against that suite's
reading before GREEN writes it.

**C-4. The suite.** `.claude/tests/rules-trim.test.sh`, `_lib.sh`, pure
bash over the real tree for the presence checks (`mapfile`, whole-line and
prefix compares, as `reporting.test.sh` does) and over fixtures for the
controls. `rules_trim_problems <root>` prints one line per violation:
`rules.md: <N> lines, the cap is 280`, `rules.md: missing line "<prefix>"`,
`rules.md: still carries "<needle>"`, `cases.md: missing "<needle>"`,
`cases.md: "<needle>" is not under a ## heading`, `rules.md: <section> does
not point at reference/cases.md`, `SKILL.md: does not list reference/cases.md`.
Floors: `floor | rules-trim | N` and the same N in `selftest.test.sh`'s table.
The cap `280` is one constant at the top of the file with the measurement
beside it (399 on 2026-10-31, release 101); raising it later is a visible
one-line change.

**C-5. Oracle partition.** AC-1's cap is the one **number** in the story, and
it is **settled by decision, not measured**: the user asked for a shorter
file, and 280 is the planner's estimate of what the rules occupy without
their cases (headings and tables ~70, Non-negotiables ~70, the rest ~130). Its
control is that the suite is red today. AC-2..AC-4 are **mechanical** with
settled needles read out of the file. Nothing is oracle-free.

**C-6. No signature changes; no script changes.**

## Deferred verifications

**DV-1 (defect put back, and the rule probed against the tree it judges -
one experiment). Owner: GATES.** With a real line of rules.md mutated to
carry `IMPLAUSIBLE: sed -i option` again, `rules_trim_problems "$REPO_ROOT"`
**must** print exactly `rules.md: still carries "IMPLAUSIBLE: sed -i
option"` and nothing else, and print nothing once restored. RED cannot run
this: on today's file the needle is present and the whole suite is red, so
one more red line proves nothing. Paste the line and the restore.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-087` from `.claude/harness/models.conf`.
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

- CLAUDE.md. It is 224 lines and also in every turn; its "Two stories at
  once" and "Running things" sections are candidates for the same treatment,
  but `mutate`, `reporting`, `phase-guard` and `lib` pin lines in it and the
  two trims are two cycles. A follow-up story, if the user wants it.
- The command files and agent definitions: HARNESS-084..086 edit them for
  their own reasons; their length is not this story's.
- Rewording any rule. Moving evidence is the whole change; a rule that
  reads wrong after its case leaves is reported in `## Notes`, not fixed
  here.
- A `rules.md` section the trim would have to invent (an index of cases):
  the pointers are per rule.

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

- PO decision 1 (PLANNED → RED, 2026-11-03): AC-5 and Context name a fifth
  net suite, `settings`. It reads the same `.claude/state/**` bullet as
  `mutate` (`state_bullet` in `settings.test.sh`, pinning
  `phase-guard-declined.log` and the C-3 `denied to `Edit`` sentence), so a
  trim of that bullet can break it. I found it by grepping every
  `.claude/tests/*.sh` for `rules.md`. The other eight hits only mention
  rules.md in comments or fixtures, or pin the `Reporting to the user`
  heading name (`security-audit`). Refined before the PLANNED commit, so no
  Amendment is needed.
- Pre-dispatch checks (2026-11-03, release 105): rules.md is 399 lines; each
  of the 11 C-2 needles occurs exactly once (`grep -cF`); each of the 38 C-1
  prefixes begins exactly one line (`awk index()==1`). No signature changes
  (C-6), so there is no callers list. `epic:` is empty, so there is no
  done-when to check. This repo has no configured gates; the check is
  `bash scripts/selftest.sh rules-trim`, and CI runs every suite.
