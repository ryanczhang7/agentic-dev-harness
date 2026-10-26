---
id: HARNESS-074
title: The self-test warns when other test runs share the host
slug: the-self-test-warns-when-other-test-runs
epic: 
type: feature
status: in-progress
phase: RED
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
  `bash scripts/selftest.sh` as pid D2 (parent D1), the ancestors P
  (`bash scripts/ci-local.sh`) and G (`bash /tmp/run-selftest091.sh`),
  neither of whose commands matches the patterns, and G's parent GG
  (`bash /d/me/scripts/gates.sh`), whose command does, when
  `host_load_others S S <listing>` runs, then none of D1, D2, P, G, GG is
  printed and X, Y still are. Given
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
  ∪ {self}. A row is a *test run* when its command begins with an
  *interpreter path* whose basename (the text after the last `/` **or `\`**)
  is `bash`, `sh` or `bash.exe`, and the word right after that path ends in
  `selftest.sh`, `.test.sh` or `gates.sh`. The interpreter path is the first
  word; or, when the first word itself contains a `/` or `\`, the first k
  words for the smallest k whose k-th word has one of those basenames (a
  Windows path with a space in it). Prints `<pid><TAB><command>` for each test
  run not in OURS, in listing order; returns 0.
  *Amended in RED (test-developer, 2026-10-26):* the original rule ("the
  basename of its first word ... and its second word ends in ...") cannot
  satisfy AC-3's last positive case, `C:\Program Files\Git\usr\bin\bash.exe
  scripts/selftest.sh`: split on whitespace its first word is `C:\Program`, and
  a `/`-only basename of a backslash path is the whole path. The amendment is
  the narrowest rule that prints that case and still prints none of AC-3's five
  negatives (`vim scripts/selftest.sh` is not reached because `vim` holds no
  separator). Checked against a scratch candidate: the suite is 48/48 with it.
  **Two sets, not one.** Root's descendants and self's ancestors must be
  computed separately and unioned at the end. Seeding the ancestors into the
  descendant closure makes every child of pid 1 "ours" - X's tree included -
  and AC-1 goes red; that mutation was measured (see the handoff).
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

## Amendments

**AC-2, 2026-10-26, approved by the user in chat** ("Record an Amendment
correcting AC-2's clause that P and G match the patterns").

- **What it said:** "...and the ancestors P (`bash scripts/ci-local.sh`) and G
  (`bash /tmp/run-selftest091.sh`) all of whose commands match the patterns,
  when `host_load_others S S <listing>` runs, then none of D1, D2, P, G is
  printed and X, Y still are."
- **What it says now:** "...the ancestors P (`bash scripts/ci-local.sh`) and G
  (`bash /tmp/run-selftest091.sh`), neither of whose commands matches the
  patterns, and G's parent GG (`bash /d/me/scripts/gates.sh`), whose command
  does, when `host_load_others S S <listing>` runs, then none of D1, D2, P, G,
  GG is printed and X, Y still are."
- **Why:** the old clause was false under the Contract's own test-run rule and
  contradicted AC-3: `ci-local.sh` and `run-selftest091.sh` end in none of
  `selftest.sh`, `.test.sh`, `gates.sh`, and AC-3 requires
  `bash C:\x\run-selftest091.sh` not to match. With no matching ancestor, the
  criterion would not exercise the ancestor exclusion at all. GG is the
  matching ancestor RED added to the suite for exactly that reason; the
  amendment makes the criterion say what the suite already asserts. Nothing
  about the behaviour GREEN must build changes.
- **Reproduction (orchestrator, independent of RED's code):** read the
  Contract's rule against the two commands by hand - `ci-local.sh` and
  `run-selftest091.sh` (`091.sh` suffix) match no listed suffix, and AC-3's
  own negative list names `bash C:\x\run-selftest091.sh`. Recorded in
  `## Notes` before this amendment.

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

One new suite, `.claude/tests/host-load.test.sh`, 48 executed assertions, at
two levels:

- **Unit** (AC-1, AC-2, AC-3, AC-5's header rule, `host_load_listing`): the
  suite sources `scripts/host-load.sh` and calls `host_load_others` directly on
  listings it writes under its own `mktemp -d`. Output compared WHOLE
  (`assert_eq` on the full stdout), never by substring.
- **Integration** (AC-4, AC-5, AC-6, AC-7): a `make_project_fixture` tree with
  two passing suites (`tiny`, `tiny2`) and a `floors.conf` naming both; the
  fixture's real `scripts/selftest.sh` is run with `HARNESS_PS_LISTING` set per
  case. Its stderr is compared whole (with a sentinel `x` so a trailing newline
  is not lost); stdout and exit status are compared byte for byte against the
  same fixture run with an EMPTY listing. Two suites, so "exactly three lines"
  also says the warning is printed once, not per suite.
- **Static** (AC-7's "no sleep, read or wait"): an awk scan of
  `scripts/host-load.sh` for those words at a command position, comments
  stripped. An absent file is reported as absent, never as a pass. This is the
  correct instrument rather than a substitute: a `read` against `</dev/null`
  returns at once, so no run can observe it.
- **Environment** (AC-6's `_lib.sh` half): read before the suite touches
  anything - the variable's value, a child's view of it, and a child that
  sources `_lib.sh` with another value already in its environment.

The two `ps -ef` header shapes are read out of `## Context`, not derived: MSYS
`     UID     PID    PPID  TTY        STIME COMMAND` (rows carry the trailing
space the real `ps -ef` prints on this host) and Linux
`UID          PID    PPID  C STIME TTY          TIME CMD`.

| AC | Assertions |
|---|---|
| (module) | `scripts/host-load.sh exists` |
| AC-1 | MSYS: exactly X, Y in order; rc 0. Linux control: identical lines; rc 0 |
| AC-2 | S-rooted: D1, D2, P, G, GG absent, X, Y present; controls: D2 rewired IS printed; S's parent link broken -> GG IS printed; R-rooted: E1, E2 absent; control: same listing S-rooted prints E1, E2 |
| AC-3 | five negatives print nothing, rc 0; four positives each printed, exact lines |
| AC-5 | unit: no-PID / no-PPID / no-COMMAND header -> rc 1 and no output (x3); `host_load_listing` rc 1 on a missing file, and emits the injected file unchanged. Fixture: missing file -> exactly the "cannot list" line, rc and stdout unchanged; each bad header -> the same line, stdout unchanged (x3) |
| AC-6 | `_lib.sh` sets `/dev/null`, exported, and overrides an inherited value; empty listing -> stderr empty; that baseline run exits 0; inherited `/dev/null` -> stderr empty |
| AC-4 | 2 foreign: stderr exactly 3 lines, rc and stdout identical; 7 foreign: header + 5 pid lines + `and 2 more`, rc and stdout identical; the warning precedes `=== tiny ===` in a merged stream |
| AC-7 | foreign run within empty run + 5 s; no sleep/read/wait in host-load.sh; host-load.sh deleted -> exactly the "is missing" line, rc and stdout unchanged |

Note on AC-2's wording: it calls P (`bash scripts/ci-local.sh`) and G
(`bash /tmp/run-selftest091.sh`) commands that "match the patterns". Under the
Contract's rule neither does - and AC-3 requires `run-selftest091.sh` NOT to
match. So P and G alone could not show the ancestor exclusion working. The
suite keeps P and G exactly as written and adds GG (`bash
/d/me/scripts/gates.sh`, G's parent), which DOES match, plus a control that
breaks S's parent link so GG stops being an ancestor and is printed. The
AC's observable claim - none of D1, D2, P, G printed - is asserted unchanged.

## Handoff: RED -> GREEN

RED dispatch: `test-developer`, resolved model **Opus 5.5** (`claude-opus-5-5`),
no override seen by this dispatch.

**Command.** `bash scripts/selftest.sh host-load` (last suite line
`host-load: N passed, M failed`). Directly, without the floors audit:
`bash .claude/tests/host-load.test.sh`.

**Files touched in RED.**

- `.claude/tests/host-load.test.sh` - new suite, 48 executed assertions.
- `.claude/tests/_lib.sh` - `export HARNESS_PS_LISTING=/dev/null` after
  `set -uo pipefail`, with its comment (AC-6). Written AFTER the suite's first
  run, which showed the three `_lib.sh` assertions red (`<unset>`, `<unset>`,
  `/somewhere/else`); they are green now because of that line.
- `.claude/tests/floors.conf` - `floor | host-load | 48` (after `grep-count`),
  plus a dated note.
- `.claude/tests/selftest.test.sh` - `host-load 48` in the COUNTS table.
- this story: `## Contract` (one amendment, below), `## Test plan`, this section.

**Not touched:** `scripts/host-load.sh` (does not exist) and
`scripts/selftest.sh` (`git diff --stat -- scripts/` is empty).

**Contract amendment (in place, with its reason in the block).** The *test
run* rule: the interpreter's basename is taken after the last `/` OR `\`, and
when the first word holds a separator the interpreter path may run over
several words (a Windows path with a space). The original rule could not print
AC-3's `C:\Program Files\Git\usr\bin\bash.exe scripts/selftest.sh`. The same
block now also says the descendant set and the ancestor set are computed
SEPARATELY - see the controls table, row "ancestors seeded".

### The RED run, verbatim

`bash scripts/selftest.sh host-load`, 2026-10-26, this host, after the
`_lib.sh` export was written, exit 1:

```

=== host-load ===

  HARNESS-074  scripts/host-load.sh is a sourced file with three functions
    FAIL scripts/host-load.sh exists
         not found at /d/agentic-dev-harness/scripts/host-load.sh - every direct call below fails as 'command not found'

  HARNESS-074 AC-1  another tree's run and its suite are printed, pid TAB command, in listing order
    FAIL MSYS shape: exactly X and Y are printed, in listing order
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         actual:   
    FAIL MSYS shape: host_load_others returns 0
         expected: 0
         actual:   127
    FAIL control - Linux shape (C, TTY, TIME columns filled): the identical two lines
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         actual:   
    FAIL Linux shape: host_load_others returns 0
         expected: 0
         actual:   127

  HARNESS-074 AC-2  this run's own tree is not printed: descendants of root, ancestors of self
    FAIL D1 (suite of this run), D2 (fixture under D1), P, G and GG (ancestors) are not printed; X and Y still are
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         actual:   
    FAIL control - D2 with its PPID rewired to an unrelated pid IS printed: exclusion is by ancestry, not command text
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         4102	bash scripts/selftest.sh
         actual:   
    FAIL control - with S's parent link broken, GG (bash /d/me/scripts/gates.sh) is no longer an ancestor and IS printed
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         4000	bash /d/me/scripts/gates.sh
         actual:   
    FAIL root R (an ancestor of S holding the run lock): R's other descendants E1, E2 are not printed either
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         actual:   
    FAIL control - the same listing rooted at S prints E1 and E2: it is the root that makes them ours
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
         4201	bash .claude/tests/y.test.sh
         4202	bash /tmp/fixture/scripts/gates.sh
         actual:   

  HARNESS-074 AC-3  a test run is bash/sh running *selftest.sh, *.test.sh or *gates.sh
    FAIL and host_load_others still returns 0 on a listing with no test runs
         expected: 0
         actual:   127
    FAIL gates.sh --gate unit, sh selftest.sh, /usr/bin/bash a.test.sh, bash.exe under C:\Program Files: each is printed
         expected: 6101	bash scripts/gates.sh --gate unit
         6102	sh scripts/selftest.sh
         6103	/usr/bin/bash /x/.claude/tests/a.test.sh
         6104	C:\Program Files\Git\usr\bin\bash.exe scripts/selftest.sh
         actual:   

  HARNESS-074 AC-5 (unit)  a header without PID, PPID or COMMAND/CMD is refused, not guessed
    FAIL header no-pid: host_load_others returns 1
         expected: 1
         actual:   127
    FAIL header no-ppid: host_load_others returns 1
         expected: 1
         actual:   127
    FAIL header no-cmd: host_load_others returns 1
         expected: 1
         actual:   127
    FAIL host_load_listing returns 1 when HARNESS_PS_LISTING names a file that does not exist
         expected: 1
         actual:   127
    FAIL host_load_listing writes the injected file's contents to stdout, unchanged
         expected:      UID     PID    PPID  TTY        STIME COMMAND
            ryanc    3999       1 ?        12:07:33 /usr/bin/bash -c source /c/Users/ryanc/.claude/shell-snapshots/snapshot.sh 
            ryanc    5001    3999 ?        12:07:33 bash scripts/selftest.sh 
            ryanc     770     703 ?        12:07:33 tee /d/manga-translator/.claude/state/gate-logs/unit.log 
            ryanc    5002    5001 ?        12:07:33 /usr/bin/bash /d/other/.claude/tests/plan.test.sh 
            ryanc    4003    4002 ?        12:07:33 bash scripts/selftest.sh 
            ryanc    4002    4001 ?        12:07:33 bash scripts/ci-local.sh 
            ryanc    4001       1 ?        12:07:33 bash /tmp/run-selftest091.sh 
            ryanc    3402    4003 ?        12:07:33 ps -ef 
         actual:   

  HARNESS-074 AC-6  an empty listing prints nothing; _lib.sh exports /dev/null

  HARNESS-074 AC-4  N other runs: one header line, up to five pid lines, then 'and N more'
    FAIL two foreign runs: stderr is exactly the header line and two pid lines
         expected: selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:
         selftest:   pid 9100001: bash /d/other1/scripts/selftest.sh
         selftest:   pid 9100002: bash /d/other2/scripts/selftest.sh
         x
         actual:   x
    FAIL seven foreign runs: the header, the first five pid lines, and 'and 2 more'
         expected: selftest: 7 other test run(s) are on this host; expect this run to be slower, not wrong:
         selftest:   pid 9100001: bash /d/other1/scripts/selftest.sh
         selftest:   pid 9100002: bash /d/other2/scripts/selftest.sh
         selftest:   pid 9100003: bash /d/other3/scripts/selftest.sh
         selftest:   pid 9100004: bash /d/other4/scripts/selftest.sh
         selftest:   pid 9100005: bash /d/other5/scripts/selftest.sh
         selftest:   and 2 more
         x
         actual:   x
    FAIL the warning is printed before the first suite's header
         expected: selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:
         actual:   === tiny ===

  HARNESS-074 AC-5  a listing that cannot be read or parsed says so, in one line
    FAIL HARNESS_PS_LISTING names a missing file: stderr is exactly the 'cannot list' line
         expected: selftest: cannot list this host's processes; other test runs, if any, were not noticed.
         x
         actual:   x
    FAIL header no-pid: stderr is exactly the 'cannot list' line
         expected: selftest: cannot list this host's processes; other test runs, if any, were not noticed.
         x
         actual:   x
    FAIL header no-ppid: stderr is exactly the 'cannot list' line
         expected: selftest: cannot list this host's processes; other test runs, if any, were not noticed.
         x
         actual:   x
    FAIL header no-cmd: stderr is exactly the 'cannot list' line
         expected: selftest: cannot list this host's processes; other test runs, if any, were not noticed.
         x
         actual:   x

  HARNESS-074 AC-7  the warning path never waits; a missing host-load.sh is said, not fatal
    FAIL scripts/host-load.sh contains no sleep, read or wait
         expected: 
         actual:   scripts/host-load.sh is absent
    FAIL host-load.sh deleted: stderr is exactly the 'is missing' line, even with foreign runs listed
         expected: selftest: scripts/host-load.sh is missing; other test runs on this host were not checked.
         x
         actual:   x

host-load: 22 passed, 26 failed
FAIL host-load  did 22 units of work, below the floor of 48 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
1 of 1 harness suite(s) FAILED.
```

**Why this is the right failure.** The suite RUNS to its summary: it checks
for `scripts/host-load.sh` (one named FAIL), sources it only if present, and
every direct call then fails as `command not found` - rc `127`, empty stdout -
so every AC-1/2/3/5-unit assertion is red on its own expected value, not on an
import abort. The fixture assertions are red because today's `selftest.sh`
prints no warning: stderr is exactly the sentinel `x` (empty) where the AC-4,
AC-5 and AC-7 lines are expected, and the merged stream's first line is
`=== tiny ===` rather than the warning. The floor FAIL (`22 < 48`) is expected
in RED: `selftest.sh` reads PASSES against the floor, and the floor is the
executed count. No failure is a syntax error or fixture-setup error: the
fixture's empty-listing baseline exits 0 (asserted).

Other suites with the `_lib.sh` export in place (each run alone, this host):

    selftest: 268 passed, 0 failed
    run-lock: 140 passed, 0 failed
    lib: 324 passed, 0 failed

`bash scripts/gates.sh --fast`: `All required gates passed (0 ran, 5
unconfigured, 0 known)` - this repository's project.conf has no gate commands
(`BOOTSTRAPPED=no`); the self-test is the gate that judges this story, on CI.
`check-sigpipe.sh` and `check-grep-count.sh`: 53 shell files, 0 findings, the
new suite included.

### The export shape the tests pin

`scripts/host-load.sh`, SOURCED by the suite with `. "$REPO_ROOT/scripts/host-load.sh"`
under `set -uo pipefail` (from `_lib.sh`), and by `selftest.sh` per the
Contract. It must source cleanly under `set -u` and print nothing when sourced.

| Function | Called as | Pinned |
|---|---|---|
| `host_load_others` | `host_load_others <self> <root> <listing-file>` | stdout exactly `<pid>\t<command>\n` per foreign test run, listing order; rc 0 on a parseable header (with or without matches); rc 1 and NO stdout when the header lacks `PID`, `PPID` or `COMMAND`/`CMD` (whole-field match: `PPID` is not `PID`). Command = fields from the COMMAND/CMD index to NF joined by one space (the MSYS trailing space must not appear) |
| `host_load_listing` | `host_load_listing` (in a child `bash -c` that sourced the file) | with `HARNESS_PS_LISTING` naming a readable file: its bytes on stdout, unchanged; naming a missing file: rc 1 |
| `host_load_warn` | only through the fixture's `selftest.sh` per the Contract's insertion: `host_load_warn "$$" "${HARNESS_RUN_LOCK_PID:-$$}" >&2` | the stderr lines of AC-4, AC-5; nothing for an empty listing or `/dev/null` |

`scripts/selftest.sh`: the Contract's six-line `if/else`, between
`run_lock_acquire ... || exit 2` and `# --- run ---`; the merged-stream
assertion pins that the warning precedes the first `=== <suite> ===`.

Messages pinned byte for byte (whole stderr):

    selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:
    selftest:   pid 9100001: bash /d/other1/scripts/selftest.sh
    selftest:   and 2 more
    selftest: cannot list this host's processes; other test runs, if any, were not noticed.
    selftest: scripts/host-load.sh is missing; other test runs on this host were not checked.

(three spaces after `selftest:` on the pid and `and N more` lines.)

**Not constrained** - the implementer's choice: how `host_load_warn` hands the
listing to `host_load_others` (temp file, `/dev/stdin`, a pipe - but no
`mktemp`/`$TMPDIR`, which `lib.test.sh` refuses in shipped scripts); the awk
variable names; what `host_load_listing` prints on stderr when it fails; the
real-`ps` branch (DV-2's, not this suite's); `host_load_warn`'s behaviour on a
listing with a header and zero test runs (the suite's foreign listings always
hold a non-test row too; AC-6 pins only the EMPTY file and `/dev/null`).

### Assertions that pass on arrival (22), and what earns each

Earned in RED against a SCRATCH candidate implementation (not in the tree:
`host-load.sh` and a `selftest.sh` with the Contract's insertion, copied into
the fixture by a scratch copy of the suite). The candidate passes 48/48, which
also shows the suite is satisfiable. GREEN must re-confirm against the shipped
files; until then these are claims.

| Assertion(s) | Why green today | Mutation of the candidate that turns it red |
|---|---|---|
| AC-6 `_lib.sh` x3 | the export line | earned by real red: run before the line was written, all three red |
| AC-3 "none is printed" | 127 prints nothing | interpreter check removed (`if (1) k = cc`) -> red |
| AC-5 unit "and prints nothing" x3 | 127 prints nothing | `PID` matched by substring -> `no-pid` variant red (+ its rc and fixture line) |
| AC-6 empty listing / inherited `/dev/null` stderr empty x2 | no warning yet | a "0 other test run(s)" reassurance on empty -> both red |
| AC-6 baseline exits 0 | fixture is sound | n/a - it is the baseline's precondition, not a claim about the story |
| AC-4/AC-5 rc and stdout identical (2+2+2+3) | no warning yet | `>&2` dropped from the insertion -> every stdout-identical assertion red (6 of them, with the stderr ones: 12 red) |
| AC-7 deleted: rc, stdout | no warning yet | `exit 4` after the "is missing" printf -> both red |
| AC-7 time bound | no warning yet | `sleep 7` in `host_load_warn` -> red (`empty 1s, two foreign 8s`), and the static scan red with it |

### Negative controls - expected values

Measured against the scratch candidate, outside the shipped tree. In RED the
functions do not exist, so in-suite every one of these was red on rc 127;
confirming them against the SHIPPED module is GREEN's job.

| Control | Threshold | Candidate range | Measured (candidate) |
|---|---|---|---|
| AC-1 Linux shape | stdout identical to MSYS | exactly 2 lines | `5001\tbash scripts/selftest.sh` / `5002\t/usr/bin/bash /d/other/.claude/tests/plan.test.sh` |
| AC-2 D2 rewired to ppid 7777 | D2 printed | 3 lines, D2 last | X, Y, `4102\tbash scripts/selftest.sh` |
| AC-2 S's ppid broken (7777) | GG printed | 3 lines, GG last | X, Y, `4000\tbash /d/me/scripts/gates.sh` |
| AC-2 ac2r rooted at S | E1, E2 printed | 4 lines | X, Y, `4201\t...y.test.sh`, `4202\t.../gates.sh` |
| AC-5 `no-pid` header (PPID present) | rc 1, no output | rc 1 | rc 1, empty; substring-`PID` mutant: 3 red |
| AC-7 time bound | foreign <= empty + 5 s | empty 0-1 s locally | empty 1 s, foreign 1 s; `sleep 7`: foreign 8 s, red |
| ancestors seeded into the descendant closure (mutant) | AC-1 must go red | - | 6 red: AC-1 x2 and AC-2 x4 (every child of pid 1 became "ours") |
| DV-1 shape (descendant marking removed, candidate) | AC-2 red, AC-1/AC-3 green | - | `43 passed, 5 failed`: exactly the five AC-2 assertions; AC-1, AC-3, all fixture cases green |

Timings: all LOCAL (this host, 2026-10-26, other projects' gate runs live).
Whole suite 13 s wall; each fixture `selftest.sh` 0-1 s. No CI timing exists
yet. The suite carries no framework timeout; the one budget is AC-7's
`empty + 5 s`, relative to a run measured in the same suite seconds earlier,
so a slower host moves both sides.

### Deferred verifications - declined in RED, in writing

- **DV-1: I cannot run it.** `host_load_others` does not exist in RED, so
  there is no descendant rule to remove. It is GATES's. What GREEN should
  write so GATES can name the line: compute root's descendants as a
  transitive closure over the parsed rows, in its OWN set, on ONE line that
  ends with the comment `# descendants of root are ours` - e.g. in the awk
  `END` block, after `desc[root] = 1`:

      do { ch = 0; for (i = 1; i <= n; i++) if (!(pid[i] in desc) && (ppid[i] in desc)) { desc[pid[i]] = 1; ch = 1 } } while (ch)  # descendants of root are ours

  and the ancestors of self in a SEPARATE set (`anc`), walked up `par[]`
  afterwards; a row is excluded when it is in `desc` or `anc`. GATES's mutation
  then neutralises that one line, e.g.
  `bash scripts/mutate.sh scripts/host-load.sh '/# descendants of root are ours/s/desc\[pid\[i\]\] = 1; ch = 1/ch = 0/' -- bash scripts/selftest.sh host-load`
  (adjusted to the final text). Expected, measured on the candidate: exactly
  the five AC-2 assertions red (D1, D2 printed; E1, E2 printed), AC-1 and AC-3
  green, `43 passed, 5 failed`. A `/.../d` deletion also works if the line is a
  complete statement on its own.
- **DV-2: I cannot run it either** - it is the real-host `ps -ef` check and
  it needs the shipped `host_load_listing`; GATES's.

### Discovered - may change the approach (not pinned; for GREEN and the orchestrator)

1. **Two-token STIME on MSYS (unverified on this host).** Cygwin's `ps`
   prints STIME as `%H:%M:%S` for a process under a day old and, from memory
   of its source, as `%b %d` - `Oct 25`, TWO fields - once older. Field-index
   parsing (the Contract's `cmd..NF`) would then start the command one field
   early (`25 bash scripts/selftest.sh`) and silently miss a run more than a
   day old - which is the orphaned run the story's Context mentions. No process
   on this host was old enough to check. Linux prints `Oct25`, one field.
   Not in any AC, so not pinned; a fix would be the COMMAND column's character
   offset from the header, or skipping a two-token STIME. Worth a decision.
2. **A Windows user name with a space** (`UID` column) shifts every field the
   same way. Same remedy, same status.
3. The descendant/ancestor conflation trap (above) is easy to write: pid 1 is
   every top-level process's parent.
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
- **RED verified by the orchestrator (2026-10-26).** Reran
  `bash scripts/selftest.sh host-load`: 22 passed, 26 failed, below its new
  floor of 48 - the failures are the missing `scripts/host-load.sh` and the
  absent warning lines, as the handoff explains. `scripts/` untouched
  (`git diff --stat -- scripts/` empty). RED reported `selftest` 268/0,
  `run-lock` 140/0 and `lib` 324/0 after the `_lib.sh` export.
- **AC-2's wording, checked independently (2026-10-26).** AC-2 says the
  ancestors P (`bash scripts/ci-local.sh`) and G (`bash /tmp/run-selftest091.sh`)
  have commands that "match the patterns". Under the Contract neither does:
  `ci-local.sh` and `run-selftest091.sh` end in none of `selftest.sh`,
  `.test.sh`, `gates.sh` (and AC-3 itself requires `run-selftest091.sh` not to
  match). The criterion's observable claim - none of D1, D2, P, G printed; X, Y
  printed - is unaffected and asserted as written; RED added GG
  (`bash /d/me/scripts/gates.sh`, which does match) so the ancestor exclusion is
  exercised by a matching command. The descriptive clause is inaccurate, not
  the criterion; left as written and raised with the user rather than amended
  silently.
- **Known limit, raised by RED, not verified.** RED recalled that Cygwin/MSYS
  `ps -ef` may print STIME as two fields (`Oct 25`) for a process older than a
  day, and a UID with a space would shift fields likewise; either would break
  the `cmd..NF` command parse for exactly an old orphaned run. Checked on this
  host on 2026-10-26: every row's STIME was one `HH:MM:SS` field, so there was
  nothing old enough to test. Out of scope for this story; GATES's DV-2 is the
  real-host check.
- Resolved models: RED `test-developer` on Opus 5.5 (`claude-opus-5-5`), its
  declared `opus`, no override.
