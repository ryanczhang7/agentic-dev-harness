---
id: HARNESS-074
title: The self-test warns when other test runs share the host
slug: the-self-test-warns-when-other-test-runs
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-074-the-self-test-warns-when-other-test-runs
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/host-load.sh, scripts/selftest.sh, .claude/tests/_lib.sh, .claude/tests/host-load.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

The full self-test on this Windows/Git Bash host took 1,135 s serial and 336 s
at `SELFTEST_JOBS=4` on 2026-10-05 (HARNESS-036), and 2,894-17,015 s serial
for HARNESS-050..068 with nearly the same suites, while self-tests from three
other projects (manga-translator, fantasy-world-builder, clean_calendar) ran on
the same host - fork+exec measured 196 ms during those runs. Contention is the
likely cause and was never measured on an idle host; the orchestrator reading
a 3-hour run has no way to tell "slow host" from "orphaned run" from "three
other self-tests" except by looking, and `/advance-story` step 2 already tells
it to look for an orphan. This story makes the self-test look at its start and
say what it sees, so the duration recorded in `## Notes` arrives with its
circumstances.

**PO decision 3 - where it lives, what it detects, what it never does.**

- **In `scripts/selftest.sh`**, through a new sourced file
  `scripts/host-load.sh`, so every caller gets it: the command's step, CI,
  `ci-local.sh`, a person at a shell. Not a line in the command file, which
  would make the orchestrator the only reader.
- **It detects other harness-shaped test processes on the host**: a
  `bash`/`sh` whose script argument ends in `selftest.sh`, `.test.sh` or
  `gates.sh`, and which does not belong to this run - this run being the
  process tree rooted at the outermost harness run (the run-lock holder's
  pid, `HARNESS_RUN_LOCK_PID`, else `$$`) plus this process's own ancestors
  (the wrapper that launched it, `ci-local.sh`, the agent's tool shell).
  Sibling suites under `SELFTEST_JOBS=4` are descendants of that root and are
  ours; a `bash scripts/selftest.sh` in another worktree or another project
  is not.
- **The listing is `ps -ef`**, which exists in Git Bash, Linux and macOS and
  prints the command with its arguments in all three (the MSYS header on this
  host is `UID PID PPID TTY STIME COMMAND`; Linux and macOS print `UID PID
  PPID C STIME TTY TIME CMD`), so the columns are found by header name, never
  by position. `ps -eo args` is refused on MSYS (`ps: unknown option -- o`),
  `tasklist` prints image names without arguments, `wmic` is gone from
  Windows 11 24H2+, and PowerShell is outside `rules.md`'s portability set
  (bash, awk, coreutils) - none of them is used.
- **It warns, on stderr, once, before the first suite.** It never refuses,
  never waits, never changes the exit status or a byte of stdout. The run lock
  (HARNESS-034) already refuses a second run *in the same tree*; this is about
  the other trees.
- **When it cannot tell, it says so.** `ps` failing, an injected listing that
  cannot be read, or a header without the three columns produces one line
  saying the host's processes could not be listed and other runs were not
  noticed. It never prints a reassurance; an empty listing prints nothing.
- **Injected, so a test never depends on what else the machine is running.**
  `HARNESS_PS_LISTING=<file>` replaces `ps -ef` with the file's contents, and
  `_lib.sh` exports it as `/dev/null` so every fixture run a suite starts is
  silent whatever the host is doing - which is what keeps `selftest.test.sh`'s
  "stderr is identical, which was empty" goldens and `run-lock.test.sh`'s
  fixtures deterministic. Only `host-load.test.sh` points it at listings it
  wrote.

A finding to carry: while this story was planned, `ps -ef` on this host showed
`bash C:\Users\...\Temp/run-selftest091.sh` from another project - the shape
of wrapper the detector sees *through*: the wrapper's name does not end in
`selftest.sh`, its child `bash scripts/selftest.sh` does and is reported.

The required gate that fails if this story's artifact breaks: the self-test
(`host-load` and `selftest` suites), run by CI on every pull request.

## Acceptance criteria

- **AC-1** — Given a listing in MSYS `ps -ef` shape (header
  `UID PID PPID TTY STIME COMMAND`) holding this run as pid S with parent P
  and grandparent G, and another tree's `bash scripts/selftest.sh` as pid X
  with its suite `/usr/bin/bash /d/other/.claude/tests/plan.test.sh` as pid Y
  (parent X), when `host_load_others S S <listing>` runs, then it prints
  exactly two lines, `X<TAB>bash scripts/selftest.sh` and
  `Y<TAB>/usr/bin/bash /d/other/.claude/tests/plan.test.sh`, in listing
  order. *Control:* the same processes in Linux shape (header
  `UID PID PPID C STIME TTY TIME CMD`, extra columns filled) give the
  identical two lines.
- **AC-2** — Given the same listing with, added, a suite
  `bash .claude/tests/x.test.sh` as pid D1 (parent S), a fixture's
  `bash scripts/selftest.sh` as pid D2 (parent D1), and the ancestors P
  (`bash scripts/ci-local.sh`) and G (`bash /tmp/run-selftest091.sh`) all of
  whose commands match the patterns, when `host_load_others S S <listing>`
  runs, then none of D1, D2, P, G is printed and X, Y still are. Given
  `host_load_others S R <listing>` where R is an ancestor of S that holds the
  run lock, then R's other descendants are not printed either.
  *Control:* D2 with its PPID rewired to an unrelated pid IS printed - the
  exclusion is by ancestry, not by command text.
- **AC-3** — Given a listing holding `grep -i selftest.sh`,
  `vim scripts/selftest.sh`, `bash scripts/plan.sh conflicts`,
  `bash C:\x\run-selftest091.sh` and `node vitest.test.sh`, when
  `host_load_others` runs, then none is printed; given
  `bash scripts/gates.sh --gate unit`, `sh scripts/selftest.sh`,
  `/usr/bin/bash /x/.claude/tests/a.test.sh` and
  `C:\Program Files\Git\usr\bin\bash.exe scripts/selftest.sh`, each is.
- **AC-4** — Given a project fixture (`make_project_fixture`) and
  `HARNESS_PS_LISTING` naming a listing with two foreign runs, when
  `bash scripts/selftest.sh` runs in the fixture, then its stderr is exactly
  three lines -
  `selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:`
  then `selftest:   pid <X>: <command>` for each - and its exit status and
  stdout are byte-identical to the same fixture run with `HARNESS_PS_LISTING`
  naming an empty file. Given seven foreign runs, the pid lines are the first
  five and a sixth line `selftest:   and 2 more` follows.
- **AC-5** — Given `HARNESS_PS_LISTING` naming a file that does not exist,
  when the fixture's `bash scripts/selftest.sh` runs, then its stderr is
  exactly one line,
  `selftest: cannot list this host's processes; other test runs, if any, were not noticed.`,
  and exit status and stdout are unchanged. Given a listing whose header has
  no `PID`, `PPID` or `COMMAND`/`CMD` column, the same line.
- **AC-6** — Given `HARNESS_PS_LISTING` naming an empty file, when the
  fixture's `bash scripts/selftest.sh` runs, then its stderr is empty; and
  after sourcing `.claude/tests/_lib.sh`, `HARNESS_PS_LISTING` is `/dev/null`
  and exported, so every fixture run a suite starts is silent.
- **AC-7** — Given the fixture with `scripts/host-load.sh` deleted, when
  `bash scripts/selftest.sh` runs, then stderr is exactly one line,
  `selftest: scripts/host-load.sh is missing; other test runs on this host were not checked.`,
  and the run proceeds with its exit status and stdout unchanged. The warning
  path contains no `sleep`, `read` or `wait`: the fixture run with a foreign
  listing (AC-4) finishes within the same bound the empty-listing run does.

## Contract

**Writes:** `scripts/host-load.sh`, `scripts/selftest.sh`, `.claude/tests/_lib.sh`, `.claude/tests/host-load.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Oracle partition.** AC-1..AC-7 are *mechanical*: pin outputs byte for
byte, whole lines (`grep -cxF`, as `run-lock.test.sh` does, because
`selftest:` is a prefix every suite header's neighbour could share). The two
`ps -ef` header shapes are *settled*, read out from `## Context`; do not
derive a third.

**`scripts/host-load.sh`** - sourced, never executed; bash 3.2, awk and
coreutils; no `$TMPDIR`, no `mktemp`, no `${var,,}`, no `sed -i`
(`lib.test.sh` rules on shipped scripts). Three functions:

- `host_load_listing` - writes the listing to stdout. If
  `HARNESS_PS_LISTING` is non-empty: `cat` that file, return 1 if it cannot be
  read. Else `ps -ef`, return 1 if `ps` is absent or exits non-zero.
- `host_load_others <self-pid> <root-pid> <listing-file>` - one awk pass.
  Row 1 is the header: find the field indices of `PID`, `PPID` and
  `COMMAND` or `CMD`; return 1 if any is missing. For every other row, the
  command is fields `cmd..NF` joined by single spaces. OURS = {root} ∪
  descendants of root (transitive, via PPID) ∪ ancestors of self (transitive)
  ∪ {self}. A row is a *test run* when the basename of its first word is
  `bash`, `sh` or `bash.exe` and its second word ends in `selftest.sh`,
  `.test.sh` or `gates.sh`. Prints `<pid><TAB><command>` for each test run
  not in OURS, in listing order; returns 0.
- `host_load_warn <self-pid> <root-pid>` - composes the message on
  **stdout** (the caller redirects to stderr) and always returns 0. Listing
  unavailable or header unparseable → the AC-5 line. Zero rows (empty
  listing) → nothing. N others → the AC-4 header line, up to five
  `selftest:   pid <pid>: <command>` lines, then `selftest:   and <N-5> more`
  when N > 5. No `sleep`, no prompt.

**`scripts/selftest.sh`** - after `run_lock_acquire ... || exit 2` and
before `# --- run ---`:

    if [ -f "$ROOT/scripts/host-load.sh" ]; then
      . "$ROOT/scripts/host-load.sh"
      host_load_warn "$$" "${HARNESS_RUN_LOCK_PID:-$$}" >&2
    else
      printf 'selftest: scripts/host-load.sh is missing; other test runs on this host were not checked.\n' >&2
    fi

The header gains a paragraph naming the warning, `HARNESS_PS_LISTING`, and
that CI and the goldens see `/dev/null`. The run lock's own refusal (same
tree) is unchanged and still comes first.

**`.claude/tests/_lib.sh`** - one line after `set -uo pipefail`:
`export HARNESS_PS_LISTING=/dev/null`, with a comment saying why (AC-6).
`host-load.test.sh` overrides it per case.

**`.claude/tests/host-load.test.sh`** - new suite, sources `_lib.sh` and
`scripts/host-load.sh`; AC-1..AC-3 call `host_load_others` directly on
listings written under its own `mktemp -d`; AC-4..AC-7 run a
`make_project_fixture` tree's `scripts/selftest.sh` with a tiny `.claude/tests`
(one passing suite and a `floors.conf` naming it, as `run-lock.test.sh`'s
`fixture_setup` does), comparing stdout byte for byte between the foreign and
the empty listing. Floor line `floor | host-load | <N>` in `floors.conf`,
recorded twice. `selftest` stays 268 unless RED adds a case there.

**Callers of changed signatures.** None: `scripts/host-load.sh` is new, and
`selftest.sh` gains a call without changing any function. `make_project_fixture`
copies `scripts/` wholesale (`_lib.sh:126`), so every existing fixture gets
`host-load.sh` for free; `refresh-harness.sh` ships `scripts/*.sh` the same
way. `sigpipe` C-3's file count is computed from `classify.sh`, so the new
shell file raises it without a pin moving.

## Deferred verifications

**DV-1 (defect put back; the story's central claim). Owner: GATES.** With the
descendant exclusion removed from `host_load_others` (one `sed` on the awk
rule that marks root's descendants as ours, named by RED in the handoff
against the final text) and `bash scripts/selftest.sh host-load`, AC-2
**must** go red - D1 and D2 printed - while AC-1 and AC-3 stay green. RED
cannot run it: the function does not exist in RED. Paste the red lines and
`mutate.sh`'s restore line.

**DV-2 (the real host). Owner: GATES.** Run `bash scripts/selftest.sh
host-load` at the top level (no `HARNESS_PS_LISTING` in the environment) while
another project's self-test is live on this host, and paste the warning lines
it prints; if no other run is live at the time, paste the silent result and
the `ps -ef | grep -c '[.]test[.]sh'` count beside it, and write `WAIVED` with
that reason. This is the one check of the real `ps -ef` shape on the host the
story is for.

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-074` from `.claude/harness/models.conf`.
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

- PLANNED — `lead-po` — resolved: **fable** (Fable 5.1, the agent's own `model:`; the dispatching session attributes its commits to Opus 5.5 and passed no model override that this dispatch could see). Verdict on the plan: n/a - no row departed from `models.conf`.
## Out of scope

- `scripts/gates.sh` warning too: it shares `run-lock.sh` and could call
  `host_load_warn` for one line of code, but its stdout and stderr are read by
  `gates.test.sh`'s goldens and by consuming projects' CI logs, and the user
  asked for the self-test step. A follow-up if the warning earns its place.
- Refusing or delaying a run because of host load. The run lock refuses the
  same-tree case; everything else is a warning.
- Seeing non-harness test runs (`vitest`, `pytest`, `cargo test`) started
  outside a `gates.sh`. Their process names vary per stack; the harness
  cannot name them portably.
- Processes `ps -ef` cannot show: on Git Bash, a process started from
  PowerShell or cmd outside the MSYS runtime is not listed. The AC-5 line is
  for a listing that failed, not for one that is incomplete; the
  `selftest.sh` header says so.
- Changing what `SELFTEST_JOBS` does, or its default - HARNESS-072 changes the
  procedure's value; HARNESS-073 the CI steps.

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


- Planned 2026-10-23 as one of three from a single request ("SELFTEST_JOBS=4
  in the self-test step, drop the duplicate guard CI steps, warn when other
  test runs share the host"). Split because each is its own behaviour with
  its own test, and together they would touch ten files across three
  mechanisms. Their footprints are disjoint except `floors.conf` and
  `selftest.test.sh` (each adds or raises a floor, recorded twice), so
  `plan.sh conflicts` reports every pair as CONFLICT on those two files and
  `plan.sh waves` places them in three waves: 072, then 073, then 074. Run
  them one after another; 072 first, because it makes every later full
  self-test on this host cheaper.
