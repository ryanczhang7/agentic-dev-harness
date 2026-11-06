---
id: HARNESS-090
title: a self-test that cannot start a process keeps every result it has and names every suite it did not run
slug: a-self-test-that-cannot-start-a-process
epic: 
type: bug
status: in-progress
phase: PLANNED
branch: story/HARNESS-090-a-self-test-that-cannot-start-a-process
depends_on: [HARNESS-094, HARNESS-095]      # the fast pre-PR self-test goes first (user decision, 2026-11-04); both must be DONE
touches: [scripts/selftest.sh, .claude/tests/selftest.test.sh, .claude/tests/floors.conf, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

**A field report from fantasy-world-builder (FWB), measured on harness
release 107 (`b65e2f4`), vendored unchanged.** Draft acceptance criteria
from the report; the PO refines them, writes the Contract and confirms
`touches:` before RED.

On 2026-11-04, FWB ran `SELFTEST_JOBS=4 bash scripts/selftest.sh` to check its
refresh to release 107, on its Windows host (Git for Windows, Cygwin bash 5.3).
The host was loaded: another project's `gates.sh` and an orphaned `gates.sh`
were running, and selftest's own host-load line named two of them. The run
used 2 h 14 min of host time and gave nothing usable. What was observed, from
the log, `ps` and the buffer directory:

- **Started at 08:19:20, 39 suites.** Suites were started in glob order. The
  17th, `plan`, started at 09:07:08. No suite after it was ever started, so
  22 never ran.
- **At 09:35 the selftest.sh process itself** (not a suite) logged
  `dofork: child -1 - CreateProcessW failed for '...\bash.exe', errno 27`,
  then `scripts/selftest.sh: fork: File too large`.
- At 09:57, three suites were running (boundaries, phase-guard, plan). At
  10:21 only boundaries was. With four slots, a free slot was not refilled
  from at least 09:57 on.
- At 10:21, `.claude/state/selftest.<pid>/` held 17 `.out` files. Sixteen
  ended in a summary line. `attest` had been printed; boundaries, the second
  in order, was still running, so by design nothing after it could print yet.
  One buffered result was `plan: 283 passed, 1 failed`, a failure the PR's CI
  run did not reproduce (`plan: 284 passed, 0 failed`, 39 suites passed).
- **It exited 254 after 8,033 s.** The log ends with attest's block and the two
  fork lines. There is no summary line and no line saying which suites never
  ran. The EXIT handler (`selftest_exit`) had **deleted the buffer
  directory**, taking 15 passing results and the one failure with it. The
  failure was seen only because the buffers were read by hand at 10:21.

**Cause, as far as it is known:** the fork failure is the host's, not the
harness's. Why the scheduler stopped refilling slots afterwards, and where
exit status 254 came from, have not been established. selftest.sh never exits
254 itself. So the defect this story fixes is not the fork failure. It is what
the run did with the work it had already done: it kept none of it and said
nothing about what was missing. The exit status was non-zero, so nothing
reported the run as passing, which is the part that worked.

**The gate that fails if this story breaks:** every gate here is unconfigured.
The artifact is judged by `bash scripts/selftest.sh selftest`, which CI runs.

## Acceptance criteria

All four are **mechanical**: exact lines, exit statuses, and the presence or
absence of files. Each applies to the parallel path only (`SELFTEST_JOBS` of
2 or more, two or more suites); the one-at-a-time path is out of scope, and
stays byte-identical to release 77 as HARNESS-036 AC-1 pins it.

- **AC-1 (a finished suite is never lost)** — Given a parallel run in which
  some suites have finished but not yet been printed, when the run ends
  before its summary for any reason (a signal, a fork bash does not return
  from, an error in the scheduler), then every started suite's block is
  printed before exit, in glob order, exactly as a run that reached its
  summary prints it: the `=== <name> ===` header, the suite's output, and the
  same verdict lines. A suite still running when the end comes is waited for,
  as today, and printed too. The negative control is release 110's
  `selftest_exit` put back, which prints none of them (DV-1).
- **AC-2 (what is missing is named, and nothing says "passed")** — Given the
  same early end, then after the last block the run prints, on stdout, an
  empty line and then `selftest: ended before its summary: <p> of <n>
  suite(s) reported (status <s>).`, where `<p>` counts the blocks printed,
  `<n>` the suites selected and `<s>` the status the run was ending with.
  Then `selftest: never started: <names>` naming, in glob order, every
  selected suite that was never started, and `selftest: unreported:
  <names>` naming every started suite whose block could not be printed (its
  status was not collected, or its buffer is not a readable file). Each
  naming line is printed only when it names at least one suite. The exit
  status is `<s>` when `<s>` is not zero (a TERM still exits 143), and 1
  otherwise. The output never contains `harness suite(s) passed.` and never
  an `assertion floors:` line.
- **AC-3 (a start the scheduler sees fail is reported, and the run goes on)**
  — Given a suite whose start fails in a way the scheduler can see — the
  `&` reports failure, `$!` did not change, or the test hook
  `SELFTEST_FAIL_START` names the suite — then that suite's block, at its
  place in glob order, is its header and one line, `FAIL <name>  not
  started: <error>`; it counts as one failure and one suite in `<f> of <r>
  harness suite(s) FAILED.`, contributes nothing to the `assertion floors:`
  line, and the exit status is 1. Every suite after it in glob order still
  starts and is reported as usual. The injection is the hook: with
  `SELFTEST_FAIL_START` holding the suite's name, its start is not attempted
  and its error is `fork: simulated by SELFTEST_FAIL_START`. The test never
  depends on exhausting the host's process table. A fork failure bash does
  not return from ends the shell (measured below), and is covered by AC-1,
  AC-2 and AC-4, not by this criterion.
- **AC-4 (the buffers outlive a result that could not be printed)** — Given
  an early end, when every started suite's block was printed, then the
  buffer directory is removed as today; when any started suite is
  unreported, then the directory is kept and `selftest: buffers kept:
  .claude/state/selftest.<pid>/` is printed after the naming lines. A run
  that reaches its summary removes it as today.

## Contract

**Writes:** `scripts/selftest.sh`, `.claude/tests/selftest.test.sh`, `.claude/tests/floors.conf`, `.claude/harness/VERSION`

**Oracle partition.** All four criteria are mechanical. The only measurement
the story rests on, taken on this host on 2026-11-06 (Git for Windows,
`GNU bash 5.3.15 x86_64-pc-cygwin`): a fatal error inside a top-level
compound command of a non-interactive bash ends the shell rather than the
command. `bash -c 'v="a-b"; while :; do echo in; echo "${!v}"; echo never;
done; echo after'` printed `in`, the error, and nothing else, status 1. That
is bash's `throw_to_top_level`, the same path a failed `fork` takes, so the
field report's run (no summary, the EXIT handler ran, status 254) is an early
end of the shell, not a scheduler that kept going. Everything the run can
still do at that point happens in the EXIT handler. `ulimit -u` is not
settable here (`cannot modify limit`), which is why the real fork failure is
never produced in a test.

**The defect, by line, at `dd97d6b`.** `scripts/selftest.sh` lines 427-435,
`selftest_exit`: it waits for any suite still running, then `rm -rf "$BUF"`,
then releases the lock. Nothing prints a block for a finished suite the main
loop (lines 548-586) had not yet printed, nothing names the suites never
started, and the buffer directory goes regardless. The script runs under
`set -uo pipefail` (line 98), so every array element the handler reads must
be initialised or read with a default.

**The fix (GREEN), parallel path only.** The one-at-a-time path (lines
506-519) does not change by a byte: HARNESS-036 AC-1 compares its output to
release 77's. Every new behaviour is conditioned on `BUF_MADE=1`.

- **`LOOP_DONE`.** A new variable, `LOOP_DONE=0`, set beside `BUF_MADE=0`,
  and set to `1` immediately after the parallel loop's closing `done`,
  before the summary. The handler treats `BUF_MADE=1` and `LOOP_DONE=0` as
  the early end.
- **`start_suite <index>`.** The inline start (lines 551-553) moves into one
  function, called as `start_suite "$started"`, next to `suite_status`
  (which stays one line, exactly: HARNESS-036 DV-1 targets it). It reads
  `name="${NAMES[$i]}"`, and:
  1. If `$name` is one of the words in `SELFTEST_FAIL_START` (read once at
     start-up as `FAIL_START="${SELFTEST_FAIL_START-}"`; documented in the
     script's header as a test hook, nothing more), it sets
     `STARTERR[$i]="fork: simulated by SELFTEST_FAIL_START"` and returns 1
     without starting anything.
  2. Else it runs `{ bash "$TESTS_DIR/$name.test.sh" > "$BUF/$name.out" 2>&1 & } 2> "$BUF/$name.start"; rc=$?`
     and reads `pid="${!-}"`. The group's stderr is where bash itself
     prints a fork error; the child's own `2>&1` still sends the suite's
     stderr into its `.out`.
  3. The start failed when `rc` is not 0, or when `pid` is empty or equal to
     `LASTPID` (the pid of the previous successful start; `$!` is not
     updated by a failed fork). Then `STARTERR[$i]` is the first line of
     `$BUF/$name.start`, or `start failed (status <rc>)` when that file is
     empty, and the function returns 1.
  4. Otherwise `PIDS[$i]=$pid`, `LASTPID=$pid`, `RCS[$i]=""`,
     `STARTERR[$i]=""`, the `.start` file is removed, and it returns 0.

  The scheduler increments `started` either way and `running` only on 0. A
  failed start therefore refills the slot with the next name on the next
  pass of the same inner loop, which is AC-3's "goes on".
- **`report_unstarted <name> <error>`.** Beside `report_suite`, for both the
  main loop and the handler: `suite_header "$name"`, then
  `printf 'FAIL %s  not started: %s\n' "$name" "$err"`, then `ran=$((ran+1))`
  and `fails=$((fails+1))`. It touches none of `floored`, `met`, `executed`,
  `declared`.
- **The print loop** (lines 568-574) prints index `printed` when either
  `RCS[$printed]` is set (as today: `suite_header`, `out="$(cat ...)"`,
  `report_suite`) or `STARTERR[$printed]` is set (`report_unstarted`).
- **`selftest_exit`**, in this order, with `st=$?` captured as its first
  statement:
  1. **Drain, collecting.** For each started index with a pid still
     recorded: `suite_status "$pid"; RCS[$i]=$?; PIDS[$i]=""`. Today's
     drain only waits; collecting here is what lets step 3 print, and a
     second `wait` on the same pid would return 127.
  2. If not the early end (`BUF_MADE` not 1, or `LOOP_DONE=1`): remove the
     buffer directory if made and release the lock, exactly as today. Done.
  3. **Print what it has.** For `i` from `printed` to `started-1`, in order:
     a `STARTERR` entry gets `report_unstarted`; otherwise, if `RCS[$i]` is
     set and `$BUF/$name.out` is a regular file that `cat` can read, the
     block is printed as the main loop prints it (`suite_header`,
     `out="$(cat ...)"`, `report_suite`) and `printed` advances; otherwise
     the name is appended to `unreported` and `kept=1`.
  4. **Name the rest.** `printf '\n'`, then
     `selftest: ended before its summary: <printed> of <NSUITES> suite(s) reported (status <st>).`;
     then `selftest: never started: <NAMES[started..NSUITES-1], space-separated>`
     if any; then `selftest: unreported: <names>` if any; then, if
     `kept=1`, `selftest: buffers kept: .claude/state/selftest.<pid>/`. All
     on stdout.
  5. `[ "$kept" = 1 ] || rm -rf "$BUF"`; `run_lock_release`; then
     `exit "$st"` if `st` is not 0, else `exit 1`.

  Printing goes through `report_suite`, so `ran` and `fails` move, but the
  summary lines (`assertion floors:`, `N of M harness suite(s) FAILED.`,
  `N harness suite(s) passed.`) are never printed from the handler.
- **No change** to `suite_header`, `report_suite`, `suite_status`,
  `executed_count`, `floor_of`, the lock, the host-load warning, or the
  signal traps (`exit 130`/`exit 143` stay, which is how a TERM still exits
  143 through step 5).
- **VERSION** 110 → 111.

**AC-3's hook, and why it is in production code.** The real event is a
`fork` bash does not return from, and AC-1/2/4 cover it through the handler.
A start the scheduler *can* see fail (a non-zero `&`, a stale `$!`) is a
code path with no portable trigger: `ulimit -u` is refused on this host and
is per-user on Linux. The hook is the only way to execute `start_suite`'s
failure branch and the `report_unstarted` block in a test, and it enters at
the top of `start_suite`, so the detection logic below it is shared.

**Fixtures (RED), in `selftest.test.sh`, reusing HARNESS-036's helpers**
(`held`, `floors`, `mk_reset`, `release`, `jstart`, `jrun`, `h_wait`,
`h_left`, `present`): a new block after the HARNESS-036 AC-5 TERM case.

- **AC-1 + AC-2 + AC-4 (removed):** five held suites at `SELFTEST_JOBS=2`:
  `e1-held` and `e2-held` hold on release; `e3-done` must *finish* before
  the TERM is sent — it needs a slot, so make `e1-held` hold and `e2-...`
  finish quickly, or use three jobs; RED picks the arrangement and asserts
  the precondition (`mk/finished/<name>` present, its block absent from
  `$HW/out` before the TERM). Send TERM, release, wait. Expect: status 143;
  `$HW/out` holds the blocks of every started suite in glob order, each
  with its `<name>: N passed, 0 failed` line; then the empty line, the
  `ended before its summary` line with the right counts and `(status 143)`;
  `never started: <the queued names>`; no `unreported:` line; no `buffers
  kept:` line; no `harness suite(s) passed.`; no `assertion floors:`;
  `h_left` empty. Twin: the same run at `SELFTEST_JOBS=1`-equivalent is out
  of scope; instead compare a block printed by the handler, byte for byte,
  with the same suite's block from a run that reached its summary.
- **AC-4 (kept) + AC-2 (unreported):** a started suite whose buffer is not
  a readable file. Portable recipe: a held suite that, on start, does
  `mkdir "$REPO_ROOT/.claude/state/selftest."*/<later>.out` for a suite
  `<later>` that has not started yet; when `<later>` starts, its
  redirection fails inside the child (`Is a directory`), the child exits
  non-zero, and its buffer is a directory. Combined with a TERM while the
  first suite still holds: expect `unreported: <later>`, the `buffers kept:`
  line, the directory present after exit (`present`), and the handler's
  other blocks still printed. The test removes the directory afterwards so
  `h_left` of later cases is clean. If RED finds a simpler portable way to
  make a buffer unreadable, it may amend this block.
- **AC-3:** four suites at `SELFTEST_JOBS=2` with `SELFTEST_FAIL_START`
  naming the second in glob order (`jrun` gains an environment pass-through,
  or a sibling `jrun_env`). Expect: exit 1; the second's block is its header
  and `FAIL <name>  not started: fork: simulated by SELFTEST_FAIL_START`;
  the third and fourth started and finished (`mk/finished/`); the summary
  is `assertion floors: all 3 suite(s) met their declared floor (...)` and
  `1 of 4 harness suite(s) FAILED.`. Control: the same fixture with the hook
  empty exits 0 with `4 harness suite(s) passed.`.
- **Serial unchanged:** HARNESS-036 AC-1's byte-identity case already pins
  it; RED adds nothing for it.
- **Negative controls RED cannot run** are the two DVs below. The
  fixtures above fail in RED because the handler prints nothing and names
  nothing, and the hook does not exist; RED pastes that red.

**Floors.** `selftest` rises from 309; RED records the measured count in
`floors.conf` with a comment and in `selftest.test.sh`'s table (line 555).

**Callers.** No existing function changes signature. `selftest_exit` is
called only by the trap. The inline start moves into `start_suite`, which is
new. `suite_status` keeps its one line. `procedure.test.sh` matches
`Bash(... scripts/selftest.sh:*)` tool strings only, not the script's body.

**RED may amend any block above in place, with a reason; GREEN builds what the amended block says.**

## Deferred verifications

Two entries, one above the default budget in `rules.md`: AC-3 is a claim
about a different mechanism (the scheduler's start) from the story's central
claim (the EXIT handler), and the hook makes it one cheap run.

**DV-1 (AC-1 and AC-4, defect put back; the story's central claim). Owner:
GATES.** With GREEN's handler in the tree, put release 110's `selftest_exit`
back through `scripts/mutate.sh`: one `sed` expression that deletes the
handler's print-and-name lines and makes its `rm -rf "$BUF"` unconditional
(name the lines GREEN wrote), run against `bash scripts/selftest.sh selftest`.
AC-1's "every started suite's block is printed" assertions, AC-2's
`ended before its summary` line and AC-4's `buffers kept` case must go red;
HARNESS-036 AC-5's TERM case (status 143, `h_left` empty) must stay green,
because the old handler satisfied it. Paste the red lines and `mutate.sh`'s
restore line. RED cannot run this: there is no handler to put back.

**DV-2 (AC-3, the failed start counts). Owner: GATES.** Through
`scripts/mutate.sh`, delete the `fails=$((fails+1))` line of
`report_unstarted`, against `bash scripts/selftest.sh selftest`. AC-3's exit
status assertion (1) and its `1 of 4 harness suite(s) FAILED.` assertion
must go red, and the control (hook empty, exit 0) must stay green. Paste the
red lines and the restore line.

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

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-090` from `.claude/harness/models.conf`.
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

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Preventing the host's fork failure (Cygwin errno 27 under load). That is the
  environment's problem.
- Retrying a suite that failed to start. AC-3 reports it and moves on. A retry
  policy is a separate decision.
- The one-at-a-time path (`SELFTEST_JOBS` unset). It has no buffers to lose,
  though AC-2's "never started" line would apply to it as well if the PO wants
  that.

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

- Filed 2026-11-04 from FWB, where the harness is vendored at release 107
  (PR 113 there). FWB's response was to let the PR's CI self-test be the run
  of record for the refresh. CI ran it in about 6 minutes, with 39 suites
  passed.
- Related, and not this story: HARNESS-089, which FWB filed the same day.
- PO decisions at PLANNED (orchestrator, 2026-11-06):
  1. **Parallel path only.** The one-at-a-time path has no buffers to lose,
     and HARNESS-036 AC-1 pins its output byte for byte against release 77.
     AC-2's "never started" line is not extended to it.
  2. **The real fork failure is an early end of the shell, not a scheduler
     event.** Measured on this host (Contract): a fatal error inside a
     top-level loop of a non-interactive bash ends the shell. That matches
     the field report (no summary, the handler ran, status 254). So the EXIT
     handler is the whole defence, and no "the loop ended early" guard after
     the loop is written: nothing could reach it, and no test could demand
     it.
  3. **AC-3 keeps a test hook in production code**, `SELFTEST_FAIL_START`,
     because the scheduler's failure branch has no portable trigger
     (`ulimit -u` is refused here). It enters at the top of `start_suite`,
     so the detection below it is shared with a real returned failure.
  4. **Exit status 254's origin is not established** and is not pursued.
     The handler keeps whatever non-zero status the run was ending with and
     forces 1 only when it would otherwise be 0.
  5. **Two deferred verifications**, one above the default budget: the
     handler and the scheduler are different mechanisms.
  6. `touches:` confirmed as the field report provisionally listed it:
     `scripts/selftest.sh`, `.claude/tests/selftest.test.sh`,
     `.claude/tests/floors.conf`, `.claude/harness/VERSION`. No
     `.claude/state/README.md` change: the `selftest.<pid>/*.out` row's
     columns (writer, reader, hand-editable) do not change.
  7. **Not already delivered:** at `dd97d6b`, `selftest_exit` (lines
     427-435) still removes the buffer directory unconditionally and prints
     nothing, and `SELFTEST_FAIL_START` appears nowhere in the tree.
  8. `plan.sh conflicts`: CONFLICT with HARNESS-091, 092, 093 and 096 on
     `VERSION`, `floors.conf` and `selftest.test.sh`. Run alone.
