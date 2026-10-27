---
id: HARNESS-079
title: gates.sh --skip runs every gate but the named ones
slug: gates-sh-skip-runs-every-gate-but-the-na
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-079-gates-sh-skip-runs-every-gate-but-the-na
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, .claude/tests/gates.test.sh, .claude/tests/ci-local.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .github/workflows/gates.yml, .claude/skills/quality-gates/SKILL.md, .claude/harness/VERSION] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

A consuming project (`D:\fantasy-world-builder`) runs `bash scripts/gates.sh`
as ONE CI job on `windows-latest` with `timeout-minutes: 75`. Warm runs have
climbed to 48.5 min, of which `integration` (vitest in real Chromium, plus
Playwright) is 1351 s. A cold Rust cache after a runner-image update adds about
20 min, so the next cold run would land near 68-70 of 75. The user chose to
split `integration` into its own CI job.

Today `gates.sh` can run one gate (`--gate <id>`) or everything not marked
`slow` (`--fast`). Marking `integration` `slow` was rejected: local RED/GREEN
`--fast` runs rely on including it. So the split needs the complement of
`--gate`: every gate a full run would run, minus the named ones.

    job gates:        bash scripts/gates.sh --skip integration
    job integration:  bash scripts/gates.sh --gate integration

`gates.sh` is vendored, so this lands upstream first; the consuming project
then refreshes and splits its own `.github/workflows/gates.yml` in a chore
story of its own.

The required gate that fails if this story's artifact breaks: the harness
self-test (`gates`, `ci-local` and `sigpipe` suites), run by CI on every PR.

**Conflict with HARNESS-078, known and accepted.** HARNESS-078 (in flight in
the main checkout, GATES) also writes `scripts/gates.sh`,
`.claude/tests/gates.test.sh` and `.claude/tests/floors.conf`. Its change to
`gates.sh` is the `covers` check's `git diff` lines (today 990-991), which this
story does not touch; the overlap in the test suite and the floors file is
additive on both sides. Whichever merges second rebases and re-measures the
`gates` floor. The user asked for this story to run alongside it.

**PO decision 1 - repeatable, not a comma list.** `--skip <id>` takes exactly
one id and may be given more than once. A comma list needs a split rule and an
escaping story for an id containing a comma; repetition needs neither, and
`--skip a,b` is then simply an unknown id `a,b`, refused by AC-2 - so the
spelling a user might guess fails loudly rather than half-working.

**PO decision 2 - refuse, do not compose.** `--skip` with `--gate`, `--fast` or
`--required` exits 2 before anything runs. Each pair has a defensible meaning
(`--fast --skip x` = fast minus x), but none is needed for the CI split, and a
refusal is the one behaviour nobody has to look up. `--list` and `--audit` do
take it: `--list --skip x` marks `x` as left out, so a workflow author can see
what the job will run; `--audit --skip x` refuses an unknown `x` like any run
and otherwise audits the whole manifest, because the audit judges the
manifest, not a run.

**PO decision 3 - an `ondemand` or `slow` gate named by `--skip` is reported
once, as skipped.** The skip is decided ahead of every other disposition (after
`GATE_REQ` is recorded, so the `covers` check still knows whether the gate is
required). `--skip` on an `ondemand` gate is pointless but harmless.

## Acceptance criteria

- **AC-1** — Given a manifest with required gates `lint` and `unit`, an
  optional `integration` marked `slow`, and a required `build` marked `slow`,
  when `bash scripts/gates.sh --skip integration` runs, then `lint`, `unit` and
  `build` each report `PASS` (so it is a full run minus one, not `--fast`), the
  `integration` command is not executed, the output has exactly one line
  beginning `SKIPPED      integration`, and the run exits 0. With
  `--skip integration --skip build`, neither command executes and both are
  reported `SKIPPED`.
- **AC-2** — Given the same manifest, when `--skip intgration` runs, then it
  exits 2, stderr names `'intgration'`, and no gate command executes. The same
  holds for `--skip integration,build` (named `'integration,build'`), and for
  `--skip` with no id (exit 2, no gate executes).
- **AC-3** — Given the same manifest, when `--skip` is combined with `--gate`,
  `--fast` or `--required` (in either order), then the run exits 2, stderr
  says `--skip cannot be combined with` and names the other option, and no gate
  command executes.
- **AC-4** — Given an active story in GATES, on its own branch, with a clean
  tree, when `--skip unit` runs (leaving out a REQUIRED gate), then the run is
  not recorded: the output carries
  `(not recorded in the story: a partial run is not evidence of anything)`,
  the story file is byte-for-byte unchanged, the stamp says `FULL=no`, and the
  "CI runs one more script" note a full run prints is absent. *Control:* the
  same tree's plain full run records into the story.
- **AC-5** — Given `--skip integration --skip build`, when the run finishes,
  then its summary carries exactly one line `--skip skipped: integration build`
  (gates in manifest order), followed by a line beginning
  `This is a subset, not a verdict`.
- **AC-6** — Given the same manifest, when `--list --skip integration` runs,
  then the `integration` entry carries a line containing
  `skip:     left out by --skip`, no other gate does, and it exits 0; when
  `--audit --skip intgration` runs, it exits 2 naming `'intgration'`; when
  `--audit --skip integration` runs, it exits 0 with `Manifest audit passed.`
- **AC-7** — Given `bash scripts/gates.sh --help`, then its output documents
  `--skip`: it contains `--skip integration` and the split pattern
  `--gate integration`. `.github/workflows/gates.yml` and the `quality-gates`
  skill name the split pattern (`--skip <id>` in one job, `--gate <id>` in
  another) beside their `gates.sh` invocation. The second half is checked by
  reading.
- **AC-8** — Given a project whose `gates.yml` has two jobs, one running
  `bash scripts/gates.sh --skip integration` and one running
  `bash scripts/gates.sh --gate integration`, when
  `bash scripts/ci-local.sh --dry-run` runs, then both commands are printed,
  each exactly once, the `--skip` one first. No change to `ci-local.sh` is
  expected: the test confirms the claim rather than assuming it.

## Contract

**Writes:** `scripts/gates.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/ci-local.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.github/workflows/gates.yml`, `.claude/skills/quality-gates/SKILL.md`, `.claude/harness/VERSION`

**Oracle partition.** All mechanical: exit statuses, whole lines, whether a
marker file a gate command touches exists. Nothing is a measurement.

**RED may amend any block below in place, with a reason, and GREEN builds
what the amended block says.**

**`scripts/gates.sh` (changed).**

- *Header* (also the `--help` text): one usage line after `--fast`'s,
  `#   bash scripts/gates.sh --skip integration   every gate a full run would run, but that one  (not recorded)`,
  and one paragraph after the `ondemand` paragraph saying what the PO
  decisions above say, including the split pattern. `--help`'s `sed -n` range
  is widened to the new last header line (today `2,45p`, which already stops
  three lines short of the header; it becomes the header's real end).
- *Parsing.* `SKIPS=""` (newline-joined, each entry preceded by a newline) and
  `NL=$'\n'` on the existing defaults line; a `--skip)` case that refuses a
  missing or empty id (exit 2) and appends one. After the loop, a block that
  exits 2 when `SKIPS` is set together with `--gate`, `--fast` or
  `--required`, message `error: --skip cannot be combined with --<other>...`.
- *Unknown ids.* Beside the existing `--gate` typo check: each `--skip` id must
  be in `GATE_IDS`, else
  `error: --skip names no gate '<id>' in project.conf; see --list`, exit 2. An
  id containing whitespace is refused the same way (it could otherwise match
  two adjacent ids in the space-joined list). Before the mutation check and
  the run lock, so nothing runs and no stamp is written.
- *The gate loop.* Right after the `--gate`/`--required` filters: `is_skip`
  0/1 from a `case` on `"$SKIPS$NL"`; when 0 and not `--list`/`--audit`, append
  the id to `skipped_by_flag`, add
  `SKIPPED      <id> (left out by --skip; bash scripts/gates.sh --gate <id>)`
  to `results`, and `continue`. In the `--list` print block, one line
  `skip:     left out by --skip (run it with --gate <id>)` when `is_skip` is 0.
  No new process per gate (HARNESS-024 and HARNESS-057 count them): builtins
  only.
- *FULL and the record.* `[ -n "$SKIPS" ]` joins the three conditions that set
  `FULLRUN=no`, that print `(not recorded in the story: ...)`, and (negated)
  that gate the closing "CI runs one more script" note.
- *Summary.* After the `--fast` block:
  `--skip skipped:<space-joined ids>` and
  `This is a subset, not a verdict: the gates it left out ran nowhere in this run.`
- *Line budget, because `sigpipe.test.sh`'s C-5 freshness list pins two
  `gates.sh` lines by number.* The `BOOTSTRAPPED="$(grep` line moves 82 → **93**
  (the header grows by 11 lines) and the `why="could not launch: $(` line
  734 → **773** (39 lines added before it in all). RED updates both pins to
  these numbers, so `sigpipe` is red until GREEN lands; GREEN either lands on
  exactly these lines or, if it cannot, says so and the pins return through
  RED with a `## Regressions` entry. (The numbers come from applying the blocks
  above to a scratch copy at PLANNED.)

**`.claude/tests/gates.test.sh` (additions only).** One `describe` per AC-1..AC-7
(AC-7's `--help` half), in a block before `summary`. Each gate command touches
a marker under `$FIX/.claude/state/` so "not executed" is a file that does not
exist, not the absence of a word in the output. AC-4 runs on the
`story/T-1-fixture` branch pattern the `--fast` block already uses.

**`.claude/tests/ci-local.test.sh` (additions only).** AC-8 in a fixture project,
the `PFIX` pattern. It passes on arrival - `ci-local.sh` already reads every
`run:` line regardless of job - so RED earns it with one `mutate.sh` mutation
of `ci-local.sh` that drops a `--gate` step, watched red, restored.

**`.claude/tests/sigpipe.test.sh`.** The two pins above, nothing else.

**Floors.** `gates` and `ci-local` raised to their new executed counts in
`floors.conf` and in `selftest.test.sh`'s mirrored table, with a dated comment.

**Docs (GREEN, config/harness).** `.github/workflows/gates.yml`: a comment above
`Run gates` showing the two-job split. `quality-gates` SKILL.md: `--skip` in the
command list and a short paragraph on the split. `.claude/harness/VERSION`:
98 at REVIEW.

## Deferred verifications

**DV-1 (defect put back; the story's central claim; AC-4). Owner: GATES.**
With GREEN's `gates.sh` in the tree, remove `|| [ -n "$SKIPS" ]` from the
record block's condition only (the `(not recorded in the story: ...)` `if`),
with one `mutate.sh` expression, against `bash scripts/selftest.sh gates`.
AC-4's assertions on the not-recorded line and on the story file being
unchanged **must** go red; every assertion outside AC-4 must stay green. Paste
the red lines, the restore lines, and a green run after.

**DV-2 (the rule against a real line of the tree; AC-2). Owner: GATES.**
The unknown-id rule is probed against this repository's own
`.claude/harness/project.conf`, not a fixture: `bash scripts/gates.sh --list
--skip integration` must exit 0 with the `skip:` line under the real
`integration` entry; then, with `mutate.sh` renaming the real
`gate | integration` line's id to `integ`, the same command must exit 2 naming
`'integration'`. Paste both, and the restore.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-079` from `.claude/harness/models.conf`.
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

- PLANNED — no subagent dispatch: written inline by the session the
  orchestrating session started for this story, resolved: **opus** (Opus 5.5,
  `claude-opus-5-5`, the session model). Departs from the `fable` row for
  PLANNED; no success condition was set for it, so no verdict is claimed.
## Out of scope

- A comma-list spelling (PO decision 1).
- Composing `--skip` with `--gate`, `--fast` or `--required` (PO decision 2).
- Refusing a `--skip` that leaves no gate to run. It prints
  `All required gates passed (0 ran, ...)`, as `--fast` over a manifest of slow
  gates does today; it is never recorded, and no CI split produces it.
- Splitting this repository's own `gates.yml` into two jobs: here the gates are
  unconfigured and the job is 3 billed minutes. Only a comment showing the
  pattern is added.
- The consuming project's own workflow split - its chore story, after refresh.

## Test plan

## Handoff: RED -> GREEN

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Notes
