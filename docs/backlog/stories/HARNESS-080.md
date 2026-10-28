---
id: HARNESS-080
title: The shipped-manifest audit passes in a project whose gates run in a subdirectory
slug: the-shipped-manifest-audit-passes-in-a-p
epic: 
type: fix
status: in-progress
phase: RED
branch: story/HARNESS-080-the-shipped-manifest-audit-passes-in-a-p
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/gates.test.sh, .claude/harness/VERSION] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Found by the fantasy-world-builder refresh from release 95 to 98
(2026-10-27), the refresh that brings in `gates.sh --skip` so that project can
split its slow `integration` gate into a CI job of its own. Its full selftest
failed one suite of 35:

    gates: 920 passed, 3 failed
        FAIL AC-7: the shipped manifest's --audit still passes   expected 1, actual 0
        FAIL AC-7: and exits 0                                   expected 0, actual 1
        FAIL AC-7: with no FAIL line                             expected 0, actual 5

HARNESS-069's `# --- AC-7: the shipped manifest ---` block in
`.claude/tests/gates.test.sh` copies the running tree's
`.claude/harness/project.conf` into F69, a `make_project_fixture` tree that
holds only `scripts/` and `.claude/hooks/`, and asserts `gates.sh --audit`
passes there. The audit FAILs any configured gate whose cwd does not exist
(`scripts/gates.sh`, `cwd does not exist:`). The template's gates all run in
`.` and have no command, so in this repository the check is never reached.
fantasy-world-builder runs five Rust gates in `src-tauri`; reproduced in a
fixture the audit says `FAIL rust-format  cwd does not exist: src-tauri`, and
the same for rust-lint, rust-unit, rust-coverage and rust-coverage-worldfile.
On that project's real tree `gates.sh --audit` exits 0.

HARNESS-070 guarded the same block's template-TEXT assertions behind
`BOOTSTRAPPED=yes`, and its AC-3 deliberately kept this trio running in both
trees. That is still right: the trio is about the manifest auditing clean, and
it should keep asserting that in a consumer. What is wrong is the fixture: it
is not faithful to the tree the manifest belongs to. The consumer's CI
`boundaries` job runs `scripts/selftest.sh`, so the defect blocks it from
adopting release 98. The refresh is held unpushed on its branch
`chore/harness-release-98` (`b2e9ab0`) and will refresh to the release this
story makes instead.

## Acceptance criteria

- **AC-1** — Given a manifest that sets `BOOTSTRAPPED=yes` and configures a
  gate (with a command) whose cwd is a subdirectory that exists in the tree the
  manifest comes from, when HARNESS-069's shipped-manifest block audits it in
  its fixture, then the audit passes and exits 0 with no `FAIL` line. Without
  the fix the same manifest FAILs with `cwd does not exist: <that directory>`.
- **AC-2** — A configured cwd that does NOT exist in the tree the manifest
  comes from still FAILs the audit in the fixture, with
  `cwd does not exist: <that directory>`: the fix copies the real tree's shape,
  it does not wave every cwd through.
- **AC-3** — In this repository the three shipped-manifest assertions
  (`--audit` passes, exits 0, no `FAIL` line) still run against the real
  `project.conf`, unguarded, and still pass.

## Contract

**Writes:** `.claude/tests/gates.test.sh`, `.claude/harness/VERSION`

One change in `.claude/tests/gates.test.sh`, HARNESS-069's
`# --- AC-7: the shipped manifest ---` block. A helper

    cwds69 <conf> <source root> <fixture>

reads every `gate` line of `<conf>` (fields split on `|`, trimmed, CRs
stripped), and for each cwd other than `.` that is a directory under
`<source root>`, creates it under `<fixture>`. A cwd that is absolute or
contains `..` is skipped, so nothing is created outside the fixture; such a
cwd then FAILs the audit, which is the right signal. A second helper,
`audit69 <conf> <source root>`, copies `<conf>` into F69, calls `cwds69`, and
runs `g69 --audit`. The shipped trio becomes `audit69 "$SHIP69" "$REPO_ROOT"`,
assertions unchanged. Two new fixture manifests under `$M69`, each
`BOOTSTRAPPED=yes` with one gate (a command, `evidence | <id> | -`), audited
against a source root `$M69/src` that holds `sub/` and not `gone/`:

- AC-1: cwd `sub` - `Manifest audit passed.` once, rc 0, no `FAIL` line;
- AC-2: cwd `gone` - one line matching `^FAIL gone +cwd does not exist: gone$`.

The fixture manifests run BEFORE the shipped trio, so F69 ends holding the
shipped manifest as before. No production file changes: a defect in a test,
so GREEN is a verified no-op, as in HARNESS-070. `.claude/harness/VERSION`
goes to 99 (a released harness change; `check-boundaries.sh` requires the
bump). Floors: new assertions only raise `gates`' count, so `floors.conf`
does not move.

Oracle partition: all mechanical (exact assertion names, exact lines, exit
codes). No metric.

## Deferred verifications

**DV-1 (defect put back, against a real line).** With the real
`.claude/harness/project.conf` mutated through `scripts/mutate.sh` so the
`unit` gate runs `printf ok` in cwd `.github` (a directory this repository
has and F69 does not; RED first chose `docs`, which F69 does have - see the
result) with `evidence | unit | -`, `bash scripts/selftest.sh gates`
must pass the shipped trio against the fixed suite, and the same mutation
against the unfixed suite (origin/main at 9e4fdb7) must fail exactly the
trio with `cwd does not exist: .github`. With cwd `src-tauri` instead (absent
here), the FIXED suite must fail the trio: AC-2 against a real line.
**Owner: RED.**

Result, RED, 2026-10-27 (orchestrator). The first attempt used cwd `docs` and
did not bite on the UNFIXED suite - `make_fixture` creates `docs/backlog/stories`,
so F69 already has it. That was the probe's mistake, not the test's:

    === mutate: .claude/harness/project.conf (2 line(s) changed by s/^gate | unit      | required | \. |$/gate | unit      | required | docs | printf ok\nevidence | unit | -/) ===
      required_gates: a story can escalate an optional gate for itself
    gates: 926 passed, 0 failed
    === mutate: command exited 0; restored (verified byte-for-byte against <scratch>/base/.claude/state/mutations/.claude_harness_project.conf.20261028T034545Z.1923.bak) ===

With `.github`, which this repository has and F69 does not. Unfixed suite
(scratch detached worktree at 9e4fdb7) - the defect, on a real line:

    === mutate: .claude/harness/project.conf (2 line(s) changed by s/^gate | unit      | required | \. |$/gate | unit      | required | .github | printf ok\nevidence | unit | -/) ===
      required_gates: a story can escalate an optional gate for itself
        FAIL AC-7: the shipped manifest's --audit still passes
        FAIL AC-7: and exits 0
        FAIL AC-7: with no FAIL line
    gates: 923 passed, 3 failed
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against <scratch>/base/.claude/state/mutations/.claude_harness_project.conf.20261028T035236Z.92.bak) ===

Fixed suite, this worktree - the trio passes:

    === mutate: .claude/harness/project.conf (2 line(s) changed by s/^gate | unit      | required | \. |$/gate | unit      | required | .github | printf ok\nevidence | unit | -/) ===
      required_gates: a story can escalate an optional gate for itself
    gates: 931 passed, 0 failed
    === mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/jolly-brattain-aa87af/.claude/state/mutations/.claude_harness_project.conf.20261028T035236Z.93.bak) ===

Fixed suite, cwd `src-tauri`, which this repository does not have - the trio
still fails (AC-2 against a real line). The AC-5 pair is HARNESS-069's earlier
audit of the real manifest in the real tree, which rightly fails too:

    === mutate: .claude/harness/project.conf (2 line(s) changed by s/^gate | unit      | required | \. |$/gate | unit      | required | src-tauri | printf ok\nevidence | unit | -/) ===
      required_gates: a story can escalate an optional gate for itself
        FAIL AC-5: and its audit says it passed
        FAIL AC-5: and exits 0
        FAIL AC-7: the shipped manifest's --audit still passes
        FAIL AC-7: and exits 0
        FAIL AC-7: with no FAIL line
    gates: 926 passed, 5 failed
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/jolly-brattain-aa87af/.claude/state/mutations/.claude_harness_project.conf.20261028T040105Z.38893.bak) ===

**DV-2 (the consumer's own manifest).** A detached scratch worktree of this
branch with fantasy-world-builder's `project.conf` (release 98) and an empty
`src-tauri/` must run `bash scripts/selftest.sh gates` with `0 failed`; the
same tree on the unfixed suite reproduces the Context's three failures.
**Owner: RED.**

Result, RED, 2026-10-27 (orchestrator). fantasy-world-builder's
`.claude/harness/project.conf` from its `chore/harness-release-98` branch
(last changed in 6d17c05) copied in, with an empty `src-tauri/`. Unfixed
(scratch detached worktree at 9e4fdb7) - the Context's failure, reproduced:

      required_gates: a story can escalate an optional gate for itself
        FAIL AC-7: the shipped manifest's --audit still passes
        FAIL AC-7: and exits 0
        FAIL AC-7: with no FAIL line
    gates: 920 passed, 3 failed
    1 of 1 harness suite(s) FAILED.

Fixed (scratch detached worktree at this branch, the corrected
`gates.test.sh` copied in):

      required_gates: a story can escalate an optional gate for itself
        note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
    gates: 928 passed, 0 failed

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-080` from `.claude/harness/models.conf`.
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

- `scripts/gates.sh` and its audit: unchanged. The audit is right to FAIL a
  missing cwd; the fixture was wrong to lack one.
- `--skip` missing from `gate-reminder.sh`'s list of partial-run modes, and no
  test of `--skip` on an ondemand gate: HARNESS-079 follow-ups, not this.
- A sweep of other suites that audit the real `project.conf` in a fixture.
  This one is the one the consumer measured failing.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

All in `.claude/tests/gates.test.sh`, HARNESS-069's shipped-manifest block,
run by `bash scripts/selftest.sh gates`:

- AC-1: `HARNESS-080 AC-1: a bootstrapped manifest whose gate runs in a
  subdirectory of its tree audits clean in the fixture`, `... and exits 0`,
  `... with no FAIL line` - fixture manifest `$M69/sub.conf`, source root
  `$M69/src` holding `sub/`.
- AC-2: `HARNESS-080 AC-2: a cwd its tree lacks still FAILs the audit in the
  fixture` (anchored: `^FAIL gone +cwd does not exist: gone$`) and
  `... and exits 1` - `$M69/gone.conf`, same source root, no `gone/`.
- AC-3: HARNESS-069's trio, unchanged in name and needle, now through
  `audit69 "$SHIP69" "$REPO_ROOT"`; DV-1 is it against a real line.

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

The fix and its test are both test code: `cwds69` and `audit69` in
`.claude/tests/gates.test.sh`, as the Contract says. Command:
`bash scripts/selftest.sh gates`.

Watched to fail. The new assertions were written first with `audit69` copying
the manifest and auditing WITHOUT calling `cwds69` - the unfixed fixture:

      required_gates: a story can escalate an optional gate for itself
        FAIL HARNESS-080 AC-1: a bootstrapped manifest whose gate runs in a subdirectory of its tree audits clean in the fixture
             expected: 1
             actual:   0
        FAIL HARNESS-080 AC-1: and exits 0
             expected: 0
             actual:   1
        FAIL HARNESS-080 AC-1: with no FAIL line
             expected: 0
             actual:   1
    gates: 928 passed, 3 failed
    1 of 1 harness suite(s) FAILED.

The right failure: the same manifest in a bare fixture, audited by hand -

    FAIL sub          cwd does not exist: sub
    rc=1

and with `sub/` created, `ok   sub          (liveness declared unassertable)`,
`Manifest audit passed.`, rc=0. AC-2 passed on arrival, as it must: it pins
behaviour the fix must NOT remove, and DV-1's `src-tauri` run earns it against
a real line. With `cwds69` called: `gates: 931 passed, 0 failed`.

No production file changes, so GREEN is a verified no-op.
`check-sigpipe.sh` and `check-grep-count.sh`: 0 findings.

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


**Who ran what (orchestrator, 2026-10-27).** Planned and every later phase
were run directly by the orchestrating session, which resolved to
**Opus 5.5 (`claude-opus-5-5`)**, not dispatched to `lead-po` (fable) and
`test-developer`. A departure from the plan, for a one-block test fix found in
the middle of a consumer refresh, as HARNESS-070 was, with the diagnosis and a
reproduction already in hand. Success condition: DV-1 and DV-2 come out as
stated; if either does not, the story goes back to planning with `lead-po`.
