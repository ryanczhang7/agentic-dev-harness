---
id: HARNESS-087
title: rules.md keeps every rule and moves its worked cases into the tdd-cycle skill
slug: rules-md-keeps-every-rule-and-moves-its
epic: 
type: chore
status: in-progress
phase: GREEN
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
  then there are at most 370 (399 today). *Control:* the suite is red on
  today's file. (Amended from 280: see `## Amendments`, A-1.)
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
*RED amendment (2026-11-03, test-developer):* re-read at release 105 with
`grep -cF` / `grep -nF`, every needle occurs exactly once, verbatim as the
table gives it (backticks included in rows 6, 8, 9 and 11), at lines 67,
104, 212, 218, 220, 240, 247, 269, 290, 336, 326 - the "default model"
needle is one line, 104, not 102-103. No needle changed.
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
one-line change. *Amended in GREEN (A-1): the cap is `370`, and the message
shape reads `the cap is 370`.*

*RED amendment (2026-11-03, test-developer): where C-4 left a matching rule
open, the suite settles it as follows; GREEN builds to these.* Reason: each
was a choice the shapes above did not fix, and a wrong guess is a red suite.
- `<section>` in the pointer line is the heading text **without** `# `:
  `rules.md: Path ownership does not point at reference/cases.md`. A section
  whose heading is itself missing is reported once, as the missing heading,
  not again as a missing pointer. A section runs from its `# ` line to the
  next column-0 `# ` line outside a ``` fence, and its pointer is the fixed
  string `reference/cases.md` anywhere in it (a bare `cases.md` does not count).
- A C-1 heading or table header is a **whole line**; every other C-1 entry is
  a **prefix at column 0** (an indented copy does not count). Presence is "at
  least one line"; C-4 has no shape for a duplicate, so none is reported.
- "still carries" is judged over rules.md **joined** (each line trimmed, joined
  with one space), so a needle reflowed across two lines is still seen.
- "present in cases.md" is judged **per line**: GREEN keeps each needle on one
  line of cases.md. "Under a `## ` heading" means some line holding the needle
  follows a line starting `## ` (outside a ``` fence; `### ` does not count).
  It is not checked against the specific heading C-2 names: C-4 has no shape
  for that, and the reviewer holds the heading names.
- AC-4's entry is a line **beginning** ``- `reference/cases.md` `` inside
  SKILL.md's `## Details` section (to the next `## ` line), the shape of the
  three entries already there; a prose mention does not count.
- With cases.md absent, each needle is reported `cases.md: missing "<needle>"`;
  with SKILL.md absent, the one SKILL.md line. Every file is read with a
  trailing CR dropped from each line, and the line count is the number of
  lines `mapfile` reads.

**C-5. Oracle partition.** AC-1's cap is the one **number** in the story, and
it is **settled by decision, not measured**: the user asked for a shorter
file, and 280 is the planner's estimate of what the rules occupy without
their cases (headings and tables ~70, Non-negotiables ~70, the rest ~130). Its
control is that the suite is red today. *Amended in GREEN (A-1): the
estimate was wrong. Non-negotiables holds about 115 lines of rule text, not
70, and moving every C-2 case reaches 369, so the user set the cap at 370.*
AC-2..AC-4 are **mechanical** with
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

## Amendments

- **A-1 (AC-1, 2026-11-03, approved by the user, ryanc, in chat: "Cap at
  370").**
  - Before: "then there are at most 280 (399 today)".
  - After: "then there are at most 370 (399 today)".
  - Why: GREEN moved all 11 C-2 cases and reached 369 lines without
    deleting or rewording a rule. The orchestrator reproduced the ceiling
    independently (`## Notes`, "GREEN stopped on AC-1"): the cases total
    53 non-blank lines, so even with no pointers rules.md would be about
    346. 280 was an estimate in C-5, not a measurement.
  - The choice the user did not take: widen C-2 to move more passages.
  - 370 keeps the 30 lines saved and fails the suite if rules.md grows
    again.
  - C-4 and C-5 are amended to match. The test's `CAP` constant changes
    through a return to RED (`## Regressions`).

## Test plan

One suite, `.claude/tests/rules-trim.test.sh` (pure bash, sources `_lib.sh`),
30 assertions, every one executed unconditionally. The sites are prose, so
the level is "grep for the shape" over files: `rules_trim_problems <root>`
over the real tree (the assertions that are red now) and over fixtures built
compliant by construction, regressed one site at a time (the controls, which
run and pass in RED - nothing here fails at import).

| # | Test (behaviour) | Level | AC |
|---|---|---|---|
| 1 | the pinned lists are the Contract's, whole: 8 whole lines, 32 prefixes, 11 needles, 4 pointed sections | list sanity | AC-2, AC-3 |
| 2 | real tree: rules.md is at most 280 lines | real tree | AC-1 |
| 3 | real tree: rules.md keeps every C-1 heading, table header and rule opener (passes on arrival - see handoff) | real tree | AC-2 |
| 4 | real tree: rules.md no longer carries any C-2 needle | real tree | AC-3 |
| 5 | real tree: cases.md carries every needle, under a `## ` heading | real tree | AC-3 |
| 6 | real tree: each of the four sections points at `reference/cases.md` | real tree | AC-3 |
| 7 | real tree: SKILL.md lists `reference/cases.md` under `## Details` | real tree | AC-4 |
| 8 | real tree: `rules_trim_problems` prints nothing | real tree | AC-1..4 |
| 9 | the compliant fixture is silent | fixture | all (controls' baseline) |
| 10-11 | exactly 280 lines is silent; 281 is one cap line with its count | fixture | AC-1 |
| 12-18 | heading demoted to `##`; heading with a suffix (whole line, pointer not double-reported); bold opener reworded; wrapped opener re-broken; labelled bullet indented; unlabelled bullet deleted; table header changed - each exactly one `missing line` | fixture | AC-2 |
| 19-27 | one needle left in rules.md; a needle reflowed across two lines of rules.md; a needle missing from cases.md; a needle only in the preamble; under only a `###`; under only a fenced `## `; cases.md absent (11 lines, Contract order); pointer moved to the next section; pointer as bare `cases.md` | fixture | AC-3 |
| 28-30 | SKILL.md entry outside `## Details`; a prose mention inside it; SKILL.md absent - each exactly one line | fixture | AC-4 |

AC-5 has no assertion here, by design (it is a GATES check of five existing
suites); the handoff lists what those suites read.

## Handoff: RED -> GREEN

**Model.** RED ran on `claude-opus-5-5` (Opus 5.5), the model the agent
definition declares; no override.

**Command.** `bash scripts/selftest.sh rules-trim` (the suite alone:
`bash .claude/tests/rules-trim.test.sh`, about 8 s locally).

**Attested runs** (machine-local records, tree `ed58e8f23dde97e4eb806ad4a4f0968e675bb2fe`):

    bash scripts/attest.sh -- bash scripts/selftest.sh rules-trim
      exit: 1
      last: 1 of 1 harness suite(s) FAILED.
      log:  .claude/state/attest-logs/20261103T145949Z.850.log
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
      exit: 0
      last: All required gates passed (0 ran, 5 unconfigured, 0 known).
      log:  .claude/state/attest-logs/20261103T150008Z.693.log

`gates.sh --fast` has no configured gate in this repository (format, lint,
typecheck, unit, coverage all UNCONFIGURED, BOOTSTRAPPED=no), so it judges
nothing here; it was run as the phase requires. The suite is not slow and no
timeout applies to it.

**Verbatim failure** (the whole log of the first run above). This is the
right failure: the suite loads and runs, all 23 fixture and list assertions
and the AC-2 real-tree assertion pass, and the six red ones are the real tree
still carrying the cases - the cap line, the 11 needles still in rules.md, the
11 missing from cases.md, the four missing pointers and the SKILL.md entry.

```

=== rules-trim ===

  the pinned lists are the Contract's, whole

  the real tree (red until GREEN moves the cases)
    FAIL AC-1: rules.md is at most 280 lines
         expected: 
         actual:   rules.md: 399 lines, the cap is 280
    FAIL AC-3: rules.md no longer carries any C-2 case needle
         expected: 
         actual:   rules.md: still carries "four private copies in one project drifted apart"
         rules.md: still carries "compared "the default model" against a stronger one"
         rules.md: still carries ""a lockfile is permitted unchecked""
         rules.md: still carries "IMPLAUSIBLE: sed -i option"
         rules.md: still carries "ci-local: 15 passed, 0 failed"
         rules.md: still carries "`check-grep-count.sh` was probed with"
         rules.md: still carries "read a here-string as a heredoc opener"
         rules.md: still carries "written into `lib.sh` in release 38"
         rules.md: still carries "keeping `-0` out of the coordinate generator"
         rules.md: still carries "on HARNESS-014 the"
         rules.md: still carries "The backup path is explicit rather than `$TMPDIR`"
    FAIL AC-3: cases.md carries every C-2 case needle, each under a ## heading
         expected: 
         actual:   cases.md: missing "four private copies in one project drifted apart"
         cases.md: missing "compared "the default model" against a stronger one"
         cases.md: missing ""a lockfile is permitted unchecked""
         cases.md: missing "IMPLAUSIBLE: sed -i option"
         cases.md: missing "ci-local: 15 passed, 0 failed"
         cases.md: missing "`check-grep-count.sh` was probed with"
         cases.md: missing "read a here-string as a heredoc opener"
         cases.md: missing "written into `lib.sh` in release 38"
         cases.md: missing "keeping `-0` out of the coordinate generator"
         cases.md: missing "on HARNESS-014 the"
         cases.md: missing "The backup path is explicit rather than `$TMPDIR`"
    FAIL AC-3: each of the four sections a case left points at reference/cases.md
         expected: 
         actual:   rules.md: Path ownership does not point at reference/cases.md
         rules.md: The model each agent runs on does not point at reference/cases.md
         rules.md: Non-negotiables does not point at reference/cases.md
         rules.md: Mutation work per story does not point at reference/cases.md
    FAIL AC-4: tdd-cycle's SKILL.md lists reference/cases.md under ## Details
         expected: 
         actual:   SKILL.md: does not list reference/cases.md
    FAIL rules_trim_problems over the real tree prints nothing: every rule kept, every case moved and pointed at
         expected: 
         actual:   rules.md: 399 lines, the cap is 280
         rules.md: still carries "four private copies in one project drifted apart"
         rules.md: still carries "compared "the default model" against a stronger one"
         rules.md: still carries ""a lockfile is permitted unchecked""
         rules.md: still carries "IMPLAUSIBLE: sed -i option"
         rules.md: still carries "ci-local: 15 passed, 0 failed"
         rules.md: still carries "`check-grep-count.sh` was probed with"
         rules.md: still carries "read a here-string as a heredoc opener"
         rules.md: still carries "written into `lib.sh` in release 38"
         rules.md: still carries "keeping `-0` out of the coordinate generator"
         rules.md: still carries "on HARNESS-014 the"
         rules.md: still carries "The backup path is explicit rather than `$TMPDIR`"
         rules.md: Path ownership does not point at reference/cases.md
         rules.md: The model each agent runs on does not point at reference/cases.md
         rules.md: Non-negotiables does not point at reference/cases.md
         rules.md: Mutation work per story does not point at reference/cases.md
         cases.md: missing "four private copies in one project drifted apart"
         cases.md: missing "compared "the default model" against a stronger one"
         cases.md: missing ""a lockfile is permitted unchecked""
         cases.md: missing "IMPLAUSIBLE: sed -i option"
         cases.md: missing "ci-local: 15 passed, 0 failed"
         cases.md: missing "`check-grep-count.sh` was probed with"
         cases.md: missing "read a here-string as a heredoc opener"
         cases.md: missing "written into `lib.sh` in release 38"
         cases.md: missing "keeping `-0` out of the coordinate generator"
         cases.md: missing "on HARNESS-014 the"
         cases.md: missing "The backup path is explicit rather than `$TMPDIR`"
         SKILL.md: does not list reference/cases.md

  the fixture: compliant by construction

  AC-1  the cap

  AC-2  every rule opener stays, exactly

  AC-3  every case moves to cases.md, under a heading, and is pointed at

  AC-4  SKILL.md lists cases.md under ## Details

rules-trim: 24 passed, 6 failed
FAIL rules-trim  did 24 units of work, below the floor of 30 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

`rules-trim: 24 passed, 6 failed` - 30 EXECUTED. **Floor: 30**, in
`.claude/tests/floors.conf` and in `selftest.test.sh`'s COUNTS table. The
`selftest` suite was run with both in place: `selftest: 268 passed, 0 failed`.

### What GREEN writes, file by file

1. `.claude/harness/rules.md` - at most **280** lines (399 today). Move the
   eleven C-2 passages out; keep every C-1 line exactly (headings and table
   headers as whole lines; every other C-1 entry as a column-0 prefix, so a
   wrapped opener keeps today's line break). Each of `# Path ownership`,
   `# The model each agent runs on`, `# Non-negotiables` and
   `# Mutation work per story` must contain the string `reference/cases.md`
   (the C-2 pointer form does). No needle may survive anywhere in the file,
   **even reflowed across two lines** - the check joins lines. None of the
   case headings contains a needle (`HARNESS-014: eighteen mutations, no
   defect` does not contain `on HARNESS-014 the`); keep pointer text that way.
2. `.claude/skills/tdd-cycle/reference/cases.md` - new. Preamble, then one
   `## ` section per C-2 row. Each needle **on one line** (presence is per
   line) and after a `## ` line (not `###`, not a `## ` inside a ``` fence).
   The suite does not check the heading names; C-2 names them and the
   reviewer holds them.
3. `.claude/skills/tdd-cycle/SKILL.md` - one line in `## Details` beginning
   ``- `reference/cases.md` `` (the shape of the three entries there). The
   `policy` suite reads this file too: it must still name
   `Mutation work per story` and must not match `(three|two) mutations`.

Nothing else. The suite, floors.conf, selftest.test.sh and VERSION
(`106 (2026-11-03)`) are already written.

### Shape the suite pins

Not a module; the interface is three paths and their text:
`.claude/harness/rules.md`, `.claude/skills/tdd-cycle/reference/cases.md`,
`.claude/skills/tdd-cycle/SKILL.md`. The constants (`CAP=280`, the four
lists) and the matching rules are in the suite's header and in C-4's RED
amendment. Not constrained: the wording of cases.md and its preamble, the case
headings, the pointer wording beyond containing `reference/cases.md`, where
in a section the pointer sits, and any prose that is not a C-1 line.

### What the five net suites read (AC-5: do not disturb)

| Suite | Reads | Pins |
|---|---|---|
| `policy` | rules.md whole; `.claude/skills/tdd-cycle/SKILL.md` as one of its six sites | rules.md has a line exactly `# Mutation work per story` and nothing matching `grep -Eiw '(three\|two) mutations'`; SKILL.md names `Mutation work per story` and carries no such count |
| `reporting` | `# Reporting to the user` (lines 362-399 today) to the next column-0 `# ` outside a fence | the heading exactly once; each of the seven `- **Label.**` bullets exactly once in that section; the `- **One next action, last.**` bullet holds `bash scripts/plan.sh after <id>` and `bash scripts/plan.sh <id>`; the `- **Agent-to-agent artefacts are exempt.**` bullet holds `## Handoff`, `## Regressions`, `docs/wiki/audits/`. A bullet there ends at the next `- ` line or blank line |
| `mutate` | the bullet beginning ``- Do not commit `.claude/state/**` `` (line 313) up to the next line starting `- ` | contains `` `.bak` left behind ``, `.active` and `mutate.sh --check` |
| `settings` | the same bullet, joined with white space collapsed, ending at a line starting `- ` or `#`, or a **blank** line | contains `phase-guard-declined.log` and the C-3 sentence ``denied to `Edit` in `settings.json` - the one file deny rule the runtime matches, and it covers `Write` and `MultiEdit` too`` (a re-wrap is fine, a blank line inside the bullet is not); must NOT contain `TOOLS`, `Write(`, `MultiEdit(`, `Write, Edit`, or `` `Write`, `Edit` `` |
| `new-story` | not rules.md itself: the story template's `## Deferred verifications` comment | names `Mutation work per story`, so that heading must not change |

So: the `$TMPDIR` sentence (lines 326-329) is the last sentence of the state
bullet. Moving it leaves the `.bak`, `.active` and `mutate.sh --check`
sentences in place, and its pointer must not introduce a blank line or a line
beginning `- ` inside the bullet.

### shipped-docs constraint on cases.md

`shipped-docs.test.sh` scans every `.md` under `.claude/skills`, taking each
token matching `docs/[A-Za-z0-9_./-]*` (one trailing `.` stripped). A token
ending in `/` is a pattern and is skipped; any other must be a `ship` or
`written` path in `.claude/harness/docs-shipped.conf`, or lie under a
`written` directory (`docs/backlog/epics/`, `docs/backlog/stories/`). None of
the eleven passages contains a `docs/` token today (rules.md's tokens are on
lines 12, 15, 16, 330 and 397, none of which moves). So cases.md must not
introduce one: no `docs/wiki/audits/<file>.md`, no `docs/wiki/<name>.md`
that the conf does not list. `docs/wiki/audits/` with its trailing slash, or
a path under `docs/backlog/stories/`, is safe.

### Passed on arrival

- **"AC-2: rules.md keeps every C-1 heading, table header and rule opener"**
  (real tree). Green today because rules.md has every rule; it is the
  regression guard GREEN must keep green. Earned by the seven AC-2 fixture
  controls and by one probe against a real line (lines elided at `[...]` are
  the unchanged AC-3/AC-4 failures shown above):

```
$ bash scripts/mutate.sh .claude/harness/rules.md 's/^\*\*Portability\.\*\*/**Portable.**/' -- bash .claude/tests/rules-trim.test.sh
=== mutate: .claude/harness/rules.md (1 line(s) changed by s/^\*\*Portability\.\*\*/**Portable.**/) ===
  40 - **Portability.** Harness scripts, hooks and skill examples stay in bash, awk and
  40 + **Portable.** Harness scripts, hooks and skill examples stay in bash, awk and

=== mutate: running bash .claude/tests/rules-trim.test.sh ===

  the pinned lists are the Contract's, whole

  the real tree (red until GREEN moves the cases)
    FAIL AC-1: rules.md is at most 280 lines
         expected: 
         actual:   rules.md: 399 lines, the cap is 280
    FAIL AC-2: rules.md keeps every C-1 heading, table header and rule opener
         expected: 
         actual:   rules.md: missing line "**Portability.**"
    FAIL AC-3: rules.md no longer carries any C-2 case needle
[...]
rules-trim: 23 passed, 7 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_harness_rules.md.20261103T145918Z.1107.bak) ===
  40: **Portability.** Harness scripts, hooks and skill examples stay in bash, awk and
```

  `bash scripts/mutate.sh --check` afterwards: no stranded mutation.
- **"the pinned lists are the Contract's, whole"**: a size check on the
  constants, green by construction. It makes a list shortened by a later edit
  visible.

### Negative controls: expected and measured

Unlike a module suite, nothing here fails at import. Every control below
**ran in RED** and was observed against the guard as written in the test
file, so these are measured values, not claims. They do not depend on
GREEN's files; GREEN confirms only that they are still the 23 passing.

| Control | Expected output | Measured |
|---|---|---|
| compliant fixture | nothing | nothing |
| rules.md at 280 lines | nothing | nothing |
| rules.md at 281 lines | `rules.md: 281 lines, the cap is 280` | same |
| `# Phase permissions` demoted to `##` | `rules.md: missing line "# Phase permissions"` | same, 1 line |
| `# Non-negotiables, and more` | `rules.md: missing line "# Non-negotiables"`, no pointer line | same, 1 line |
| `**Portable.**` | `rules.md: missing line "**Portability.**"` | same |
| the per-phase opener broken after `not a` | `rules.md: missing line` naming the per-phase opener | same |
| `- **Plain words.**` indented two spaces | `rules.md: missing line "- **Plain words.**"` | same |
| state bullet deleted | ``rules.md: missing line "- Do not commit `.claude/state/**`."`` | same |
| ownership header with a 4th column | `rules.md: missing line "\| Agent \| Writes \| Never writes \|"` | same |
| one needle left in rules.md | `rules.md: still carries "IMPLAUSIBLE: sed -i option"` | same, 1 line |
| a needle wrapped across two lines of rules.md | `rules.md: still carries "on HARNESS-014 the"` | same |
| a needle dropped from cases.md | ``cases.md: missing "keeping `-0` out of the coordinate generator"`` | same |
| a needle only in the preamble | ``cases.md: "The backup path is explicit rather than `$TMPDIR`" is not under a ## heading`` | same |
| a needle under a `###` only | `cases.md: "four private copies in one project drifted apart" is not under a ## heading` | same |
| a needle under a fenced `## ` only | the same line | same |
| cases.md absent | 11 `cases.md: missing` lines, C-2 order | same |
| a pointer moved to the next section | `rules.md: The model each agent runs on does not point at reference/cases.md` | same |
| a pointer as bare `cases.md` | `rules.md: Mutation work per story does not point at reference/cases.md` | same |
| SKILL.md entry outside Details; a prose mention in Details; SKILL.md absent | `SKILL.md: does not list reference/cases.md`, once each | same |
| real tree with `**Portability.**` mutated (probe above) | the AC-2 real-tree assertion red with one line | same |

### Deferred verifications

**DV-1 is declined by RED.** It belongs to GATES and cannot be run here: the
needle `IMPLAUSIBLE: sed -i option` is in rules.md today, so putting it back
proves nothing while the whole real-tree check is red. Not claimed.

### Contract amendments

Two, both in place in `## Contract` with reasons. A note under C-2: every
needle re-read at release 105, all verbatim, and the "default model" needle
is on line 104, not 102-103; no needle changed. A paragraph under C-4
settling the matching rules C-4 left open: the pointer line's `<section>` is
the heading text without `# `; whole lines versus column-0 prefixes; "still
carries" over joined text; needles per line in cases.md, under any `## `
outside a fence; the SKILL.md entry as a ``- `reference/cases.md` `` line in
`## Details`. All 32 C-1 prefixes, the 6 headings and both table headers were
re-read with `awk 'index($0,p)==1'` and each begins exactly one line; none
needed amending.

### Files touched

- `.claude/tests/rules-trim.test.sh` (new, staged)
- `.claude/tests/floors.conf` (`floor | rules-trim | 30` and its note)
- `.claude/tests/selftest.test.sh` (`rules-trim 30` in the COUNTS table)
- `.claude/harness/VERSION` (`106 (2026-11-03)`)
- `docs/backlog/stories/HARNESS-087.md` (Contract amendments, Test plan, this handoff)

### Discovered

- The `settings` bullet reader stops at a **blank** line and `mutate`'s does
  not: the state bullet must stay one paragraph with no blank line in it.
- The suite cannot see whether a reflowed rule kept every sentence; that is
  the reviewer's half of C-1, as the Contract says.

## Regressions

### R-1 (2026-11-03, GREEN -> RED): the AC-1 cap was an estimate

- **What was wrong.** `.claude/tests/rules-trim.test.sh` pinned `CAP=280`.
  That number was the planner's estimate in C-5, not a measurement, and the
  user corrected AC-1 to 370 (`## Amendments`, A-1).
- **How it was found.** GREEN moved every C-2 case into
  `.claude/skills/tdd-cycle/reference/cases.md` without deleting or rewording
  a rule, and rules.md came to 369 lines. AC-1 could not be met at 280.
- **The fix.** One line, `CAP=280` -> `CAP=370`, plus its comment. Nothing
  else in the file changed. The fixtures derive from `$CAP`, so the suite
  still executes 30 assertions and its floor is unchanged.
- **What it asserts now.** `AC-1: rules.md is at most 370 lines`: the real
  rules.md has at most 370 lines, and the whole-tree `rules_trim_problems`
  check reports `rules.md: N lines, the cap is 370` when it has more.
- **How it was earned.** The corrected assertion passes on its first run
  against GREEN's 369-line rules.md, so I mutated rules.md by adding two
  lines (to 371, one over the cap) and ran the suite once. Exactly the AC-1
  cap assertion and the whole-tree check went red, both naming 371 against
  370. mutate.sh restored the file byte-for-byte, `mutate.sh --check` is
  clean, and rules.md is back to 369.

```
$ bash scripts/mutate.sh .claude/harness/rules.md '1s/^/x\nx\n/' -- bash .claude/tests/rules-trim.test.sh
=== mutate: .claude/harness/rules.md (2 line(s) changed by 1s/^/x\nx\n/) ===
  1 + x
  2 + x

=== mutate: running bash .claude/tests/rules-trim.test.sh ===

  the pinned lists are the Contract's, whole

  the real tree (red until GREEN moves the cases)
    FAIL AC-1: rules.md is at most 370 lines
         expected: 
         actual:   rules.md: 371 lines, the cap is 370
    FAIL rules_trim_problems over the real tree prints nothing: every rule kept, every case moved and pointed at
         expected: 
         actual:   rules.md: 371 lines, the cap is 370

  the fixture: compliant by construction

  AC-1  the cap

  AC-2  every rule opener stays, exactly

  AC-3  every case moves to cases.md, under a heading, and is pointed at

  AC-4  SKILL.md lists cases.md under ## Details

rules-trim: 28 passed, 2 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_harness_rules.md.20261103T155950Z.1240.bak) ===

$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

After the fix, against the unmutated tree:

```
$ bash scripts/attest.sh -- bash scripts/selftest.sh rules-trim
exit:     0
last:     1 harness suite(s) passed.
log:      .claude/state/attest-logs/20261103T160022Z.739.log
(rules-trim: 30 passed, 0 failed; floor met, 30 executed, 30 declared)
```

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
- RED verification (orchestrator, 2026-11-03): test-developer resolved to
  claude-opus-5-5. `attest.sh check -- bash scripts/selftest.sh rules-trim`
  answered `fresh` (tree ed58e8f2): `exit: 1`, `rules-trim: 24 passed,
  6 failed`. The 6 are the real-tree assertions for AC-1, AC-3 (three) and
  AC-4, plus the whole-tree "prints nothing" check, which is the right
  reason. `gates.sh --fast` was `fresh`, exit 0 (0 gates ran). Read
  `rules_trim_problems` and its helpers. `mutate.sh --check` is clean.
  Neither command was re-run by the orchestrator.
- GREEN stopped on AC-1 (2026-11-03). The feature-developer (resolved
  claude-opus-5-5; it read the handoff, the contract and the criteria with
  `story.sh section` rather than getting them pasted) moved all 11 C-2 cases
  and reached 369 lines, not 280. In `rules-trim` the result is 28/30; the
  two failures are both `rules.md: 369 lines, the cap is 280`. The other net
  suites passed through attest: policy, reporting, mutate, new-story,
  settings and shipped-docs.
  Independent reproduction (orchestrator, not reusing its numbers):
  `git diff -U0 HEAD -- rules.md` removes 53 non-blank lines and adds 23 for
  pointers, a net 30. Per section, before → after: Non-negotiables 153 → 128,
  Path ownership 82 → 79, model 38 → 37, Mutation work 29 → 28, Phase
  permissions 59 → 59, Reporting 38 → 38. Even with every C-2 case removed
  and no pointer at all, rules.md would be about 346 lines (399 - 53). So
  280 is out of reach by C-2 alone. C-5's estimate of ~70 lines for
  Non-negotiables was low: about 115 lines of it are rule text. This is the
  AC-1 question put to the user, pending.
- GREEN verification (orchestrator, 2026-11-03): after the RED return
  (R-1, test-developer resolved claude-opus-5-5), GREEN was a no-op. The
  source was unchanged, and its rules.md (369 lines) already met the
  amended cap. `attest.sh check -- bash scripts/selftest.sh rules-trim`
  answered `fresh`: `exit: 0`, `1 harness suite(s) passed.` (30/30).
  `gates.sh --fast` was `fresh`, exit 0. Neither was re-run by the
  orchestrator. Read the diff stat, the test diff (CAP only), the eight
  pointers and cases.md's seven headings. `mutate.sh --check` is clean. No
  feature-developer was dispatched for the no-op. The GREEN agent's net-suite
  runs (policy, reporting, mutate, new-story, settings, shipped-docs, all
  exit 0) predate the CAP edit, so AC-5 stands to the GATES self-test.
