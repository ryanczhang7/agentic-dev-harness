---
id: HARNESS-084
title: A subagent's verification run is recorded against the tree it ran on, and the orchestrator checks the record instead of re-running
slug: a-subagent-s-verification-run-is-recorde
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-084-a-subagent-s-verification-run-is-recorde
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/attest.sh, .claude/hooks/lib.sh, .claude/tests/attest.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/state/README.md, .claude/settings.json, .claude/agents/test-developer.md, .claude/agents/feature-developer.md, .claude/agents/lead-po.md, .claude/commands/advance-story.md, .claude/commands/complete-story.md, CLAUDE.md, .claude/harness/VERSION]
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

First of four stories cutting the cost of verification (HARNESS-084..087).
The user's finding: the orchestrator (`/advance-story`, `/complete-story`,
`lead-po`, all on `fable`) re-runs every verification a subagent has already
run against an unchanged tree. In RED the test-developer runs the tests and
`gates.sh --fast` (test-developer.md step 7), then the orchestrator runs both
again (advance-story.md, PLANNED → RED and RED → GREEN paragraphs). In GREEN
the feature-developer runs the tests, the full suite, `--fast` **and the full
`gates.sh`** (feature-developer.md steps 6-7), then the orchestrator runs the
tests and `--fast` again, and GATES runs the full `gates.sh` a second time,
overwriting GREEN's record so GREEN's full run leaves nothing behind. Every
return to RED repeats the loop. Measured on HARNESS-083, where every gate is
unconfigured and the cost is the story suite: `bash scripts/selftest.sh
boundaries` took 2407 s, 1931 s and 50m51s, and was run by the subagent and
then re-run by the orchestrator in each phase. The cost is not only wall
clock: each re-run is extra orchestrator turns, each turn re-sends the whole
standing context, and a 30-50 minute wait outlasts the prompt cache.

The law stays intact. Law 1's "watched to fail" and GREEN's confirmation of
negative controls are **shown** in the handoff, not claimed; what changes is
that the orchestrator's check of "did that command run against this tree, and
what did it say" becomes a script's answer rather than a second run. The
mechanism follows `gates.sh`: a run is stamped with the hash of the gated
tree it ran on (`gate_tree_hash`, HARNESS-014), and a stamp that does not
match the tree is not evidence. The one difference is that the record here is
machine-local and never read by CI - it stands in for the orchestrator's
re-run, not for `## Gate results`, which `gates.sh` alone still writes.

Two side effects the user asked for come with it: the subagent's full
`gates.sh` in GREEN goes (GATES runs it; GREEN keeps `--fast`), and the
command's output lands in a log file with only its tail printed, so an
untrimmed suite run no longer lands in the orchestrator's context.

The gate that fails if this breaks is `bash scripts/selftest.sh attest` (a
new suite); the prose criteria are structural guards over the real tree, in
the shape of `procedure.test.sh` and `policy.test.sh`.

## Acceptance criteria

- **AC-1** — Given a project fixture and a command that prints two lines and
  exits 3, when `bash scripts/attest.sh -- <command>` runs, then it exits 3,
  prints the record it wrote followed by the command's last lines, and
  `.claude/state/attest.log` ends with a block carrying `command:` (the words
  joined by one space), `tree:` (the work hash, C-2), `status: ok`,
  `exit: 3`, `last:` (the command's last non-blank line), `duration:` and
  `log:` naming a file under `.claude/state/attest-logs/` that holds the
  command's full output. *Control:* a leading `NAME=value` word is exported to
  the command (the command prints `$NAME` and the log shows `value`) and is
  part of `command:`.
- **AC-2** — Given AC-1's record, when `bash scripts/attest.sh check --
  <the same words>` runs on the unchanged tree, then it prints that record
  and a last line `fresh`, exit 0. *Controls:* a different command, or the
  same words in another order, answers `none`, exit 1; after a tracked
  `source` file is edited, `stale`, exit 1, naming the recorded and the current
  hash; after an untracked, non-ignored `test` file is created, and again
  after its content changes, `stale`, exit 1; after only a `docs` file is
  edited, still `fresh`, exit 0.
- **AC-3** — Given a command that edits a tracked `source` file while it
  runs, when `attest.sh -- <command>` runs, then the command's exit status is
  passed through, the block carries `status: void` with the words `tree
  changed during the run`, and `attest.sh check` for it answers `void`, exit 1.
  *Control:* a command that writes only an ignored path (under
  `.claude/state/`) records `status: ok`.
- **AC-4** — Given a `mutations/*.active` marker in `.claude/state/`, when
  `attest.sh -- <command>` runs, then it refuses before running the command
  (the command's side effect does not appear), prints `mutate.sh --check`'s
  report and exits 2.
- **AC-5** — Given the real tree, when the suite's structural guard
  (`attest_problems <root>`, C-5) runs over `REPO_ROOT`, then it prints
  nothing; and over fixtures compliant by construction with one site
  regressed, it prints exactly the one line C-5 pins for that regression. The
  sites: feature-developer.md's `## Method` no longer runs the full
  `` `bash scripts/gates.sh` `` and runs `--fast` through `attest.sh`;
  test-developer.md's test and `--fast` steps run through `attest.sh`;
  advance-story.md's `**PLANNED → RED.**` and `**RED → GREEN.**` regions each
  name `bash scripts/attest.sh check` and neither says `run the tests
  yourself`; complete-story.md and lead-po.md's `## Orchestrating` name
  `bash scripts/attest.sh check`; both commands' `allowed-tools` carry
  `Bash(bash scripts/attest.sh:*)`. This criterion can only be checked
  structurally: nothing executes the prose, and the suite pins that the
  instruction is present where the orchestrator reads it, not that a model
  follows it.
- **AC-6** — Given `.claude/state/README.md` and `.claude/settings.json`,
  when `bash scripts/selftest.sh settings` runs, then it passes with the two
  new rows: `attest.log` hand-editable `no` (it is read as evidence, so
  `Edit(./.claude/state/attest.log)` is denied) and `attest-logs/*.log`
  hand-editable `yes`.

## Contract

**Writes:** `scripts/attest.sh`, `.claude/hooks/lib.sh`, `.claude/tests/attest.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/state/README.md`, `.claude/settings.json`, `.claude/agents/test-developer.md`, `.claude/agents/feature-developer.md`, `.claude/agents/lead-po.md`, `.claude/commands/advance-story.md`, `.claude/commands/complete-story.md`, `CLAUDE.md`, `.claude/harness/VERSION`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says.

**C-1. `scripts/attest.sh` - the command surface.**

    bash scripts/attest.sh -- <word>...          run the words, record the run, exit with the command's status
    bash scripts/attest.sh check -- <word>...    is there a fresh record for exactly these words on this tree?
    bash scripts/attest.sh show                  every record whose tree: is the current work hash

The words after `--` are executed directly (`"$@"`), never through a shell:
no globbing, no quoting rules beyond the caller's. Leading words matching
`^[A-Za-z_][A-Za-z0-9_]*=` are exported into the command's environment and
stripped from what is executed, so `SELFTEST_JOBS=4 bash scripts/selftest.sh`
is one attestable command. The recorded `command:` is **all** the words,
assignments included, joined by one space; `check` compares that string for
equality, so `a b` and `b a` are different commands (AC-2's control).
Usage errors (no `--`, nothing after it, an unknown first word) exit 2.

**C-2. The work hash.** `gate_tree_hash` (lib.sh) covers tracked and staged
gated files - the tree `git commit -a` would make - and leaves untracked
files out. A RED subagent's new test file is usually untracked, so a record
keyed only to that hash could not tell its edits apart. New lib.sh function,
appended at the end of the file:

    work_tree_hash   # stdout: one hash; the gate_tree_hash listing plus one
                     # `<blob>\t<path>` line per untracked_gated file, blob
                     # from `git hash-object`, through _hash_blob_listing.
                     # Prints `unavailable` and returns 1 when either part fails.

Semantics: the hash moves when any tracked, staged **or untracked** `source`,
`test` or `config` file changes content, and stays when only `docs`,
`harness`, `vendor` or `ignored` paths change (AC-2's docs control, AC-3's
ignored-path control). `gated_stdin` is the existing filter and defines
"gated" here; nothing new decides it. `unavailable` is never `fresh`.

**C-3. The record.** Appended to `.claude/state/attest.log`, one block per
run, blank-line separated, fields in this order:

    run:      <RUN_STARTED_AT, UTC, the gates.sh stamp format>
    command:  <words joined by one space>
    tree:     <work hash before the command started>
    after:    <work hash when it exited>
    status:   ok | void: tree changed during the run | void: hash unavailable
    exit:     <the command's exit status>
    duration: <whole seconds>s
    last:     <last non-blank line of the command's combined output, or `(no output)`>
    log:      .claude/state/attest-logs/<run>.<pid>.log

The command's stdout and stderr go to the log file, not the terminal. After
it exits, attest.sh prints the block it wrote, then a line `--- last N lines
of <log> ---` and the last `ATTEST_TAIL` lines (default 20) of the log. It
never prints the whole output: that is the point. `status:` is `void` when
`tree:` and `after:` differ (AC-3) or either is `unavailable`; the command's
exit status is passed through regardless of status.

**C-4. `check`.** Reads the log, takes the newest block whose `command:`
equals the joined words. Answers, as the last line of stdout:

| Case | Last line | Exit |
|---|---|---|
| no block for these words | `none: no record for this command` | 1 |
| newest block is `void` | `void: <its status text>` | 1 |
| its `tree:` differs from the current work hash | `stale: recorded on <tree> at <run>, the tree is now <hash>` | 1 |
| equal | the block, then `fresh` | 0 |

`fresh` says the command ran on this tree; it says nothing about whether it
passed. The orchestrator reads `exit:` and `last:`, and the log when it needs
more. That split is deliberate: a RED run is supposed to exit non-zero, and a
`check` that folded the exit status into its own would call a correct RED
`stale`.

Before running (AC-4), `attest.sh` runs `bash scripts/mutate.sh --check` and
refuses with its report, exit 2, when it is not clean - the same refusal
`gates.sh` makes (HARNESS-030): a run inside a mutation is a run on a tree
nobody will ever see again.

**C-5. The structural guard and its sites.** `attest_problems <root>` in
`.claude/tests/attest.test.sh`, one line `<path>: <reason>` per violation,
silent on a compliant tree, modelled on `procedure_problems`. Regions are
the ones `reporting.test.sh` and `procedure.test.sh` already define: a phase
paragraph of advance-story.md runs from a line beginning `**X → Y.**` to the
next such line; `## Orchestrating` in lead-po.md runs to the next `## `;
`## Method` in feature-developer.md and test-developer.md is the numbered
list under that heading.

| Site | Must hold | Reported as |
|---|---|---|
| `.claude/agents/feature-developer.md` `## Method` | no line contains `` `bash scripts/gates.sh` `` (closing backtick directly after `.sh`) | `still runs the full gate run in GREEN` |
| same | a line contains `bash scripts/attest.sh -- bash scripts/gates.sh --fast` | `does not run --fast through attest.sh` |
| `.claude/agents/test-developer.md` `## Method` | a line contains `bash scripts/attest.sh --` and a line contains `bash scripts/attest.sh -- bash scripts/gates.sh --fast` | `does not run its tests through attest.sh` / `does not run --fast through attest.sh` |
| `.claude/commands/advance-story.md`, `**PLANNED → RED.**` region and `**RED → GREEN.**` region, each | contains `bash scripts/attest.sh check`; does not contain `run the tests yourself` | `<region> does not check the record` / `<region> still re-runs the tests` |
| `.claude/commands/complete-story.md` | contains `bash scripts/attest.sh check` | `does not check the record` |
| `.claude/agents/lead-po.md` `## Orchestrating` | contains `bash scripts/attest.sh check` | `does not check the record` |
| both commands' frontmatter `allowed-tools` | an entry equal to `Bash(bash scripts/attest.sh:*)` (procedure's `has_entry` semantics: equal, trimmed, not contained) | `does not permit attest.sh` |

The needle `` `bash scripts/gates.sh` `` is anchored by its closing backtick:
it matches today's step 7 (`Run `bash scripts/gates.sh`. Fix what it
reports.`) and not `` `bash scripts/gates.sh --fast` ``. Step 7's guidance
about `## Gate results`, evidence lines and waivers is not deleted; it moves
out of the numbered list into a paragraph for a GATES dispatch and refers to
the full run as `` `scripts/gates.sh` without `--fast` ``, which the needle
does not match. Steps 8-9 renumber to 7-8; `briefs.test.sh` pins step 2's
pointer and the `## Reuse before you write` section, neither of which moves.

**C-6. What the prose says, in substance.** GREEN writes the words; these are
the obligations. test-developer.md steps 4 and 7: run the test command and
`--fast` as `bash scripts/attest.sh -- <command>`, and paste the `last:`
line and the log path into the handoff beside the verbatim failure the law
already requires. feature-developer.md step 6: `bash scripts/attest.sh --
bash scripts/gates.sh --fast`; the full run is GATES' (the orchestrator
dispatches it there - HARNESS-085 moves that dispatch off the orchestrator).
advance-story.md: after each dispatch returns, read the files it wrote, then
`bash scripts/attest.sh check -- <command>` for the test command and for
`bash scripts/gates.sh --fast`; **run the command yourself only when the
answer is not `fresh`**, and say in the story which it was. The RED
verification "fail for the right reason" is read from the log the record
names, not from a re-run. lead-po.md `## Orchestrating`: the ladder's first
rung becomes "a report of success is a claim; `attest.sh check` is how you
check it without paying for the run twice; `stale` means you run it". CLAUDE.md
`## Running things` gains one line in the block's existing shape:
`bash scripts/attest.sh -- CMD        # run CMD, record it against the tree; `check -- CMD` instead of a re-run`.

**C-7. State and settings.** `.claude/state/README.md` rows, in the table's
existing shape: `attest.log` | `scripts/attest.sh` | `scripts/attest.sh check`,
and the orchestrator | **no**; `attest-logs/*.log` | `scripts/attest.sh` |
you, and the story that quotes it | yes. `settings.json` deny gains
`"Edit(./.claude/state/attest.log)"`, per file, like the two it joins.
`settings.test.sh` checks the table and the rules against each other in both
directions and needs no change. Both are `ignored` to the phase lock already
(`.claude/state/*` is gitignored and no `paths.conf` rule classifies it).

**C-8. The suite.** `.claude/tests/attest.test.sh`, sourcing `_lib.sh`,
fixture from `make_project_fixture` (a git repository with the harness
scripts, `paths.conf` and a `src/`, `tests/` layout - RED confirms which
categories its fixture paths classify to with `bash scripts/classify.sh`
before asserting on them). Commands under test are tiny scripts the suite
writes (`printf` two lines and `exit 3`; one that appends to `src/x.sh`; one
that writes under `.claude/state/`). Floors: a `floor | attest | N` row in
`floors.conf` and the same N in `selftest.test.sh`'s table, N the executed
count read off a run. No suite other than `attest` and `settings` reads a
file this story writes, except `briefs` (feature-developer.md's step 2 and
reuse ladder, unchanged), `procedure` (allowed-tools membership and the
GATES → REVIEW steps, unchanged by this story), `reporting` (`## Orchestrating`
heading, unchanged), `phase` (`bash scripts/plan.sh after` in lead-po.md,
kept) and `mutate` (one exact CLAUDE.md line, kept).

**C-9. Oracle partition.** Every criterion is **mechanical**: pin exactly.
Settled values to read out, not re-derive: the stamp format and the
`gate_tree_hash` listing shape (`lib.sh`), `has_entry` semantics
(`procedure.test.sh`), the README table shape. Nothing is oracle-free.

**C-10. No existing export changes signature.** `gate_tree_hash`,
`untracked_gated` and `_hash_blob_listing` are called, not changed; their
callers (`gates.sh`, `check-boundaries.sh`, `selftest-needed.sh`) are
untouched.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** With the `after:` comparison in
`attest.sh` disabled - a `mutate.sh` expression that makes the script treat
`tree:` and `after:` as equal - AC-3's `status: void` assertion **must** go
red and nothing else in the suite should. RED cannot run this: there is no
`attest.sh` to mutate. Run against `bash scripts/selftest.sh attest`; paste
the red, the count and the restore.

**DV-2 (a rule probed against the tree it judges). Owner: GATES.** With a
real line of `.claude/agents/feature-developer.md` mutated to put
`` Run `bash scripts/gates.sh`. `` back into `## Method`, `attest_problems
"$REPO_ROOT"` **must** print exactly one line, `still runs the full gate
run in GREEN`, and nothing with the file restored. RED's fixtures say the
guard is right about what it imagined; this says it is right about the file
that is there.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-084` from `.claude/harness/models.conf`.
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

- Dispatching the full `gates.sh`, the self-test and `check-boundaries.sh`
  to an opus subagent: HARNESS-085, which builds on this record.
- Reading the story by section, and trimming `rules.md`: HARNESS-086 and
  HARNESS-087.
- `## Gate results`, `last-gate-run` and the Stop hook: unchanged. The
  attest record is never evidence to CI; `check-boundaries.sh` does not read
  it and must not start to.
- `ci-local.sh`: it mirrors the workflow files by construction
  (`ci-local.test.sh` derives its steps from them) and is not made to skip
  anything.
- A consuming project's `test` task in `project.conf`: the subagents attest
  whatever command the story names; no new `project.conf` grammar.
- Pruning the attest log. It is machine-local exhaust; the README says it is
  safe to delete.

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched, and which AC each test covers
       * the EXPORT SHAPE the tests already pin
       * any test that passed on arrival, and the probe or negative control
         that earns it
       * the EXPECTED VALUE of every negative control
       * anything discovered that changes the approach -->

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. One block per return, with the PASTED probe output. -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run. Do not paste or
     edit it. -->

## Gate probes

<!-- Not expected: this story adds no gate to project.conf. If GREEN finds it
     changed one, record the probe here and say so in ## Notes. -->

## Notes

