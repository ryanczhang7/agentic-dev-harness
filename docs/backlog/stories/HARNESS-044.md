---
id: HARNESS-044
title: task.sh passes its arguments to the task as words, not as shell
slug: task-sh-passes-its-arguments-to-the-task
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-044-task-sh-passes-its-arguments-to-the-task
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/task.sh, .claude/tests/doctor.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Lead 1 of the first `/security-audit` run, `docs/wiki/audits/security-2026-10-08.md`
(fingerprint `task.sh/eval-args/allowlisted-prefix`; the full record, with the
trace and reproduction plan, is outside the repository at
`C:\Users\ryanc\security-audit-skill\agentic-dev-harness\run-1\findings.json`
and `NEEDS-VALIDATION.md` beside it). `scripts/task.sh:50` runs
`cd "$ROOT/$cwd" && eval "$cmd" "$@"`. `eval` joins its operands with spaces
and parses the result as shell, so every argument the caller passes after the
task id is re-parsed: `'; touch PWNED'` runs `touch`, `'$(cmd)'` runs `cmd`,
and `'a b'` arrives as two words. The only test of argument passing,
`doctor.test.sh` AC-4 (`args:extra`, `arg=extra`), uses a benign word and
cannot tell the two behaviours apart.

**Why this is fixed now rather than validated first.** The audit left the
lead `needs_validation` because the half that would make it a consent
widening - whether Claude Code's `Bash(bash scripts/task.sh:*)` allow rule
auto-approves an argument carrying `;`, `$(` or `>` - is platform behaviour
this repository cannot observe. The user chose to fix rather than validate,
and that is sound on the script's own terms: `project.conf:8` documents a
task as "a convenience command, run by `scripts/task.sh <id>`" and
`doctor.test.sh` documents extra arguments as *appended*, so an argument that
is parsed as shell is a defect in the harness's stated behaviour whichever way
the platform question falls. **No criterion below depends on Claude Code's
permission behaviour**; every one runs under the harness's own bash suites.

**Decided, from the audit:** the fix shape `eval "$cmd \"\$@\""` (audit
`## Decided` 2, first bullet). The *evidence* is not settled - the audit ran
nothing - so AC-1 and AC-2 reproduce the defect first and are the permanent
regression test, as a `fix` requires.

**Type `fix`; not split.** One line of one script, three observable
behaviours of that line, tests in the suite where task.sh is already tested.
**The gate that fails if this breaks** is the harness's own `selftest` (CI
runs every suite on every PR): the `doctor` suite, where `task_golden` and the
HARNESS-024 task assertions live. No `required_gates` entry is needed.

One of three stories cut from the audit's three cheap leads; the others are
HARNESS-045 (the lock sees `git --output`) and HARNESS-046 (a story id is one
path component). They share no file with this one.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC. -->

All three are run from a project fixture (`make_project_fixture` +
`write_conf`) whose `project.conf` carries exactly one task,
`task | t | - | . | printf 'arg=%s\n'`, and are invoked as
`( cd "$FIX" && bash scripts/task.sh t <args> )`. `printf` with that format
prints one `arg=` line per argument it receives, so the line count is the
word count and the line text is the word - the oracle for every criterion.

- **AC-1 (a metacharacter in an argument is data)** — Given the fixture, when
  `task.sh t '; touch PWNED'`, `task.sh t '$(touch PWNED2)'` and
  `task.sh t '> PWNED3'` each run, then each exits 0 with stdout exactly
  `arg=; touch PWNED`, `arg=$(touch PWNED2)` and `arg=> PWNED3` respectively,
  and no file named `PWNED`, `PWNED2` or `PWNED3` exists anywhere under the
  fixture afterwards. *Reproduction today:* the first two create the file and
  the third creates `PWNED3` and prints nothing to stdout.
- **AC-2 (an argument is one word)** — Given the fixture, when
  `task.sh t 'a b' c` runs, then stdout is exactly two lines, `arg=a b` then
  `arg=c`, and the exit status is 0. *Reproduction today:* three lines,
  `arg=a`, `arg=b`, `arg=c`.
- **AC-3 (benign arguments are unchanged, byte for byte)** — Given the
  HARNESS-024 manifest fixtures, when `bash scripts/selftest.sh doctor` runs,
  then the two `task_golden` comparisons (`project.task.golden`,
  `crlf.task.golden`) and the `args:extra` / `arg=extra` assertions still pass
  unchanged - the fix must not alter what a plain word, a task with embedded
  pipes in its command, or a task run in its own `cwd` prints. This passes
  today and is the control that the fix changed only the parsing of
  arguments; it needs no new test, only the existing ones left green.

Every criterion is **mechanical** (oracle partition, Contract C-4).

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. -->

**Writes:** `scripts/task.sh`, `.claude/tests/doctor.test.sh`

Both classify as `harness` (`bash scripts/classify.sh` at PLANNED), so the
phase lock freezes neither; the role boundary is honoured by the agents: RED
writes `doctor.test.sh` only, GREEN writes `task.sh` only. No existing export
changes signature; there is no caller list.

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 The sink and its fix (settled - read out, never re-derived).**
  `scripts/task.sh:50` is today

      cd "$ROOT/$cwd" && eval "$cmd" "$@"

  and becomes

      cd "$ROOT/$cwd" && eval "$cmd \"\$@\""

  Semantics: the string `eval` parses is the task command followed by the
  four literal characters `"$@"`; `eval` then expands that `"$@"` from
  task.sh's **own** positional parameters, which after the `shift` at `:49`
  are exactly the caller's arguments, each as one word, never re-parsed. The
  task command text itself (`$cmd`, from the user-owned `project.conf`) is
  still parsed as shell - that is the documented design of a task and is out
  of scope. The file's line count does not change. No new process is spawned:
  `doctor.test.sh` HARNESS-024 AC-2 counts task.sh's spawns over a padded
  manifest and must stay equal.
- **C-2 Where the tests go.** A new `describe "HARNESS-044 ..."` block in
  `.claude/tests/doctor.test.sh`, after the HARNESS-024 blocks (task.sh has no
  suite of its own and `floors.conf` floors every suite, so a new file would
  need a floor line; adding assertions to an existing suite needs nothing).
  The fixture is `make_project_fixture` with `write_conf` fed the one task
  line above; each case is run as `( cd "$FIX" && bash scripts/task.sh t ... )`
  with stdout captured and compared with `assert_eq` (whole-output equality,
  not containment - a containment on `arg=` would pass on the broken code's
  first line). Absence of a file is asserted as `[ ! -e "$FIX/PWNED" ]` after
  the run; on today's code the file *is* created, which is what makes RED red
  for the right reason. Each case removes any `PWNED*` it finds before the
  next, so a failure in one does not mask the next.
- **C-3 What `'> PWNED3'` means today versus after.** Today the eval string is
  `printf 'arg=%s\n' > PWNED3`, a redirect: stdout is empty and `PWNED3`
  holds `arg=`. After, `printf 'arg=%s\n' "> PWNED3"` prints `arg=> PWNED3`.
  Both halves of AC-1's third case (the output *and* the absent file) are
  asserted, so a fix that quoted the argument but still let the redirect
  through could not pass.
- **C-4 Oracle partition.** Every criterion is **mechanical**: pin exact
  stdout, exact exit status, exact file absence. Nothing is to be invented
  or calibrated.
- **C-5 Tree-wide guards.** `scripts/check-sigpipe.sh` and
  `scripts/check-grep-count.sh` run over `scripts/task.sh` in CI
  (`ci-local.sh`). The one-line change introduces no pipeline and no
  `grep -c`, so neither should fire; GATES runs `bash scripts/ci-local.sh`
  to confirm rather than reasoning about it.
- **C-6 Test-only dependencies.** None. Bash and coreutils only, as
  `rules.md` "Portability" requires.

## Deferred verifications

<!-- One block per entry; the owning phase pastes the result in. -->

- **DV-1 (defect put back - the story's central claim). Owner: GATES.**
  With the fix reverted - `scripts/task.sh:50` mutated back to
  `eval "$cmd" "$@"` through `bash scripts/mutate.sh scripts/task.sh
  '<sed expression GATES writes for that exact substitution>' -- bash
  scripts/selftest.sh doctor` - AC-1's three cases and AC-2's one case
  **must** go red (RED predicts the exact assertion count in its handoff;
  at least four: three file-absence or output assertions for AC-1, one for
  AC-2), and every other `doctor` assertion, AC-3's goldens included, must
  stay green. Then `mutate.sh` restores the file and verifies the restore,
  and the suite is green again. RED cannot run this: there is no fix to
  revert. Paste the mutate.sh output and the red assertion names here, as a
  fenced block.

## Out of scope

- The `eval` of the task **command text** read from `project.conf` (`$cmd`).
  That is user-owned configuration and the documented design of a task;
  `doctor.sh:268` and `gates.sh:560` share it and take no caller arguments.
- `.claude/settings.json`'s `Bash(bash scripts/task.sh:*)` allow rule. The
  audit's consent question is the platform's; this story fixes the script.
- Validating the task **id** (`$1`) or refusing unknown tasks differently.
- Any observation of Claude Code's permission matcher (the audit's
  owner-observed check). If the user runs it, the result goes in
  `docs/wiki/audits/security-2026-10-08.md`, not here.
- The other two leads: HARNESS-045, HARNESS-046.

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


## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-044` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po` ran on **Fable 5.1** (`claude-fable-5-1`), the model its definition declares; the dispatching prompt stated no override and none was observed. 2026-10-08.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
