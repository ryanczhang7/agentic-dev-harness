---
id: HARNESS-074
title: The self-test warns when other test runs share the host
slug: the-self-test-warns-when-other-test-runs
epic: 
type: feature
status: in-review
phase: REVIEW
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
- **AC-8** — Given an MSYS-shaped listing holding X (a foreign
  `bash scripts/selftest.sh`) and, after it, the continuation rows Git Bash
  prints for a multi-line command - rows whose PID or PPID field is not all
  digits, e.g. `# a b c d bash scripts/selftest.sh` and
  `cd /d/a && git -C /d/b/c status && bash scripts/selftest.sh` - when
  `host_load_others S S <listing>` runs, then it prints exactly the one line
  for X, and no line for any continuation row. *Control:* the same rows with
  numeric PID and PPID fields ARE printed - the guard is on the PID/PPID
  shape, not on the command text.
- **AC-9** — Given `HARNESS_PS_LISTING` empty and a stub `ps` first on `PATH`
  that prints a listing holding one foreign run, when
  `host_load_warn S S` runs, then it prints the AC-4 header line and that
  run's pid line. Given `HARNESS_PS_LISTING` empty and no `ps` on `PATH`,
  then it prints exactly the AC-5 "cannot list" line. (The branch that reads
  the real host is the one CI's top-level run uses.)

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


Result (GATES, 2026-10-26, run by the orchestrator; ok lines elided). The
descendant closure at `host-load.sh:85` with its `desc[pid[i]] = 1; ch = 1` body
replaced by `ch = 0`, so root's descendants are never marked ours:

```
=== mutate: scripts/host-load.sh (1 line(s) changed by /# descendants of root are ours/s/desc\[pid\[i\]\] = 1; ch = 1/ch = 0/) ===
=== mutate: running bash scripts/selftest.sh host-load ===
    FAIL D1 (suite of this run), D2 (fixture under D1), P, G and GG (ancestors) are not printed; X and Y still are
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
    FAIL control - D2 with its PPID rewired to an unrelated pid IS printed: exclusion is by ancestry, not command text
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
    FAIL control - with S's parent link broken, GG (bash /d/me/scripts/gates.sh) is no longer an ancestor and IS printed
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
    FAIL root R (an ancestor of S holding the run lock): R's other descendants E1, E2 are not printed either
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
    FAIL control - the same listing rooted at S prints E1 and E2: it is the root that makes them ours
         expected: 5001	bash scripts/selftest.sh
         5002	/usr/bin/bash /d/other/.claude/tests/plan.test.sh
FAIL host-load  did 43 units of work, below the floor of 48 in .claude/tests/floors.conf

assertion floors: 0 of 1 suite(s) met their declared floor.
host-load: 43 passed, 5 failed
FAIL host-load  did 43 units of work, below the floor of 48 in .claude/tests/floors.conf
1 of 1 harness suite(s) FAILED.
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_host-load.sh.20261026T183938Z.24.bak) ===
```

Exactly the five AC-2 assertions went red (D1 and D2 printed; the rewired,
broken-link and rooted-at-R controls with them), while AC-1, AC-3 and every
fixture case stayed green: 43 passed, 5 failed, as RED predicted. File restored,
`mutate.sh --check` clean. This is also the orchestrator's one "does the suite
discriminate" mutation; `host-load` was 48/0 again afterwards.

**DV-2 (the real host). Owner: GATES.** Run `bash scripts/selftest.sh
host-load` at the top level (no `HARNESS_PS_LISTING` in the environment) while
another project's self-test is live on this host, and paste the warning lines
it prints; if no other run is live at the time, paste the silent result and
the `ps -ef | grep -c '[.]test[.]sh'` count beside it, and write `WAIVED` with
that reason. This is the one check of the real `ps -ef` shape on the host the
story is for.

Result (GATES, 2026-10-26, orchestrator). **WAIVED - no other run was live.**
At the top level with `HARNESS_PS_LISTING` unset, `ps -ef | grep -c
'[.]test[.]sh' was `0` and no `selftest.sh` or `gates.sh` from another tree was in
`ps -ef`; `env -u HARNESS_PS_LISTING bash scripts/selftest.sh host-load` then
printed nothing on stderr (the silent result) and passed:

```
test.sh procs: 0
(stderr empty)
assertion floors: all 1 suite(s) met their declared floor (48 assertions executed, 48 declared).
1 harness suite(s) passed.
```

The real `ps -ef` shape on this host was nevertheless exercised: GREEN's
dispatch, running the same command earlier the same day while another
project's `gates.sh --fast` was live, saw
`selftest: 2 other test run(s) are on this host; expect this run to be slower, not wrong:`
followed by `selftest:   pid 1710: bash scripts/gates.sh --fast` and
`selftest:   pid 1863: bash scripts/gates.sh --fast` (its report, recorded under
`## Notes`). That run was GREEN's, not this phase's, so the waiver stands and
the preview is cited as corroboration only.

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

**AC-8 and AC-9 added, 2026-10-26, approved by the user in chat** ("Take
findings 1 and 3 in this story: return to RED for the junk-row and
real-ps-branch tests, fix the junk-row guard in GREEN, and file finding 2
(two-field STIME) as a follow-up story").

- **What it said:** AC-1 to AC-7; nothing on continuation rows or on the
  `ps -ef` branch.
- **What it says now:** AC-8 (rows whose PID or PPID is not all digits are
  never reported) and AC-9 (the un-injected branch of `host_load_listing`
  runs `ps`, and says "cannot list" when there is none).
- **Why:** the GATES diff review's Should-fix 1 and 3. Finding 1 was
  reproduced on this host by the reviewer: a Bash-tool command whose second
  line was `# a b c d bash scripts/selftest.sh` made `host_load_warn $$ $$`
  report `4 other test run(s)`, all with pid `a`, from the shell running the
  check. Finding 3: every case injected a listing, so the real-host branch -
  the one CI's top-level run uses - had no test; `ps -eo args`, a dropped
  `command -v ps` or an inverted `|| return 1` left 48/48 green. Finding 2
  (two-field STIME for a day-old process) is unverified and goes to a
  follow-up story, not here.
- **Reproduction (orchestrator, independent of the reviewer's command):**
  see `## Notes`, "Finding 1 reproduced by the orchestrator".

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
| AC-8 | (return to RED) MSYS listing: X, S, then four raw continuation rows (`# a b c d ...`, `cd /d/a && git -C /d/b/c ...`, PID-only-numeric `# 7005 b ...`, PPID-only-numeric `# a 7006 ...`) -> exactly X's line; rc 0. Control: the same raw rows with only fields 2-3 numeric ARE printed |
| AC-9 | (return to RED) `HARNESS_PS_LISTING=` + stub `ps` (answers only `-ef`) first on PATH -> exactly the AC-4 header + one pid line, rc 0; precondition: under the no-ps PATH `ps` is not found and `awk` runs; no `ps` on PATH -> exactly the AC-5 "cannot list" line, rc 0 |

The return to RED raises the suite to **54** executed assertions.

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

### Addendum: the return to RED for AC-8 and AC-9 (2026-10-26)

RED dispatch: `test-developer`, resolved model **Opus 5.5** (`claude-opus-5-5`),
its declared `opus`, no override seen by this dispatch.

**Command.** `bash scripts/selftest.sh host-load`. Now **54** executed
(floor and COUNTS raised 48 -> 54).

**Files touched.** `.claude/tests/host-load.test.sh` (two new `describe`
groups at the end, before `summary`), `.claude/tests/floors.conf` (54, plus a
dated note), `.claude/tests/selftest.test.sh` (COUNTS `host-load 54`), this
story (`## Test plan`, this addendum, `## Regressions`). **Not touched:**
`scripts/host-load.sh`, `scripts/selftest.sh`.

**Current result, verbatim** (exit 1; the PASS lines elided):

```
  HARNESS-074 AC-8  continuation rows of a multi-line command (PID or PPID not all digits) are never reported
    FAIL MSYS listing with X and four continuation rows: exactly X's one line is printed
         expected: 5001	bash scripts/selftest.sh
         actual:   5001	bash scripts/selftest.sh
         a	bash scripts/selftest.sh
         /d/a	/d/b/c status && bash scripts/selftest.sh
         7005	bash scripts/selftest.sh
         a	bash scripts/selftest.sh

  HARNESS-074 AC-9  with HARNESS_PS_LISTING empty, the listing comes from 'ps -ef' on PATH, and no ps says 'cannot list'

host-load: 53 passed, 1 failed
FAIL host-load  did 53 units of work, below the floor of 54 in .claude/tests/floors.conf
```

**What GREEN writes: one line.** In `host_load_others`'s awk, at the top of the
per-row block, before `n++` (line 72 today), skip any data row whose PID or
PPID field is not all digits:

    if ($pc !~ /^[0-9]+$/ || $ppc !~ /^[0-9]+$/) next

It must test **both** fields: the suite has a row with numeric PID and junk
PPID (`# 7005 b ...`) and one the other way round. Before `n++`, so a junk row
enters neither `pid[]`/`ppid[]` nor `par[]`. Then update the "Known limits"
paragraph of `host-load.sh`'s header, which currently names the
continuation-line case as unhandled.

**Expected GREEN result, measured** by applying exactly that line through
`mutate.sh` (restored, verified): `host-load: 54 passed, 0 failed`, floor met
(54 / 54). And a PID-only guard (`if ($pc !~ /^[0-9]+$/) next`) measured
`53 passed, 1 failed` - the AC-8 assertion red on `7005	bash scripts/selftest.sh` -
so a half-guard does not pass.

**Pinned shape (unchanged):** `host_load_others <self> <root> <file>` prints
`<pid>TAB<command>` lines; `host_load_warn <self> <root>` prints on stdout and
returns 0; `HOST_LOAD_CANNOT`'s text; `host_load_listing` runs `ps -ef`
(exactly those arguments - AC-9's stub refuses any other) after
`command -v ps`. **Not constrained:** where the guard sits textually beyond
"before the row is recorded", or whether it is also applied to the header row
(it is never reached for NR == 1).

**Passed on arrival** (code already exists): the AC-8 control (numeric PID/PPID
rows printed) - it is a control, green today and green after the guard; what
earns it is that it shares every word but fields 2-3 with the red row, so the
guard cannot be on command text. And all three AC-9 assertions, earned by
mutation - output in `## Regressions`.

**Timings.** No new timeout; AC-8/AC-9 are pure function calls, no fixture
runs. Local only.
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

### Return 1: GATES -> RED, 2026-10-26 (AC-8, AC-9 - the user's decision)

**What was missing.** Not a wrong test: two behaviours no test covered, found
by the GATES diff review (`## Diff review`, Should-fix 1 and 3) and added as
AC-8 and AC-9 under `## Amendments`.

- **Finding 1 (AC-8).** Git Bash's `ps -ef` prints each later line of a
  multi-line command as a raw row, whose PID/PPID fields are arbitrary words.
  `host_load_others` parsed them as rows, so a comment line
  `# a b c d bash scripts/selftest.sh` in the shell running the check was
  reported as `pid a`. Reproduced by the reviewer and independently by the
  orchestrator (`## Notes`). Every listing in the suite was well-formed, so
  48/48 stayed green.
- **Finding 3 (AC-9).** Every case injected `HARNESS_PS_LISTING`, so the
  un-injected branch of `host_load_listing` - `command -v ps`, then `ps -ef` -
  never ran under test; the reviewer showed `ps -eo args` or a dropped
  `|| return 1` left it green.

**What the new tests assert.** AC-8: an MSYS listing of X, S and four raw
continuation rows (the two shapes AC-8 names, plus PID-only and PPID-only
numeric variants) gives exactly X's line, rc 0; control: the same raw rows
with only fields 2-3 made numeric ARE printed. AC-9: with
`HARNESS_PS_LISTING=` and a stub `ps` first on PATH that answers `-ef` (and
refuses any other arguments) with one foreign run, `host_load_warn` prints
exactly the AC-4 header and that pid line, rc 0; with a PATH of one directory
holding only an `awk` wrapper (`#!/bin/sh` + `exec /usr/bin/awk "$@"` by
absolute path - on Git Bash `awk` and `ps` share `/usr/bin`, so no system
directory can stay on PATH), a precondition asserts `ps` is not found and
`awk` runs, and `host_load_warn` prints exactly the AC-5 "cannot list" line,
rc 0. The awk wrapper matters: without awk, `host_load_others` would fail on
its own and print "cannot list" for the wrong reason - the second mutation
below would then survive.

**AC-8's evidence: its natural red**, against the shipped, unchanged
`host-load.sh` - `bash scripts/selftest.sh host-load`, exit 1:

```
  HARNESS-074 AC-8  continuation rows of a multi-line command (PID or PPID not all digits) are never reported
    FAIL MSYS listing with X and four continuation rows: exactly X's one line is printed
         expected: 5001	bash scripts/selftest.sh
         actual:   5001	bash scripts/selftest.sh
         a	bash scripts/selftest.sh
         /d/a	/d/b/c status && bash scripts/selftest.sh
         7005	bash scripts/selftest.sh
         a	bash scripts/selftest.sh

host-load: 53 passed, 1 failed
FAIL host-load  did 53 units of work, below the floor of 54 in .claude/tests/floors.conf
```

**AC-9 (a) earned: `ps -ef` -> `ps -eo args`.**
`bash scripts/mutate.sh scripts/host-load.sh 's/ps -ef 2>/ps -eo args 2>/' -- bash scripts/selftest.sh host-load`
(PASS lines elided; the AC-8 red is the natural one above):

```
  HARNESS-074 AC-9  with HARNESS_PS_LISTING empty, the listing comes from 'ps -ef' on PATH, and no ps says 'cannot list'
    FAIL stub ps first on PATH, one foreign run: the AC-4 header line and that run's pid line, rc 0
         expected: selftest: 1 other test run(s) are on this host; expect this run to be slower, not wrong:
         selftest:   pid 9100001: bash /d/other1/scripts/selftest.sh
         rc=0
         actual:   selftest: cannot list this host's processes; other test runs, if any, were not noticed.
         rc=0

host-load: 52 passed, 2 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_host-load.sh.20261026T195317Z.4949.bak) ===
  38:     ps -ef 2>/dev/null || return 1
```

**AC-9 (b) earned: no `ps` -> `return 0` instead of `return 1`.**
`bash scripts/mutate.sh scripts/host-load.sh '/command -v ps/s/return 1/return 0/' -- bash scripts/selftest.sh host-load`.
(Dropping the `command -v ps` line alone would NOT be caught, and is not a
defect: `ps -ef 2>/dev/null || return 1` then fails with 127 and still says
"cannot list". The behaviour pinned is "no ps -> cannot list", and the
mutation that breaks it is a silent success.)

```
  HARNESS-074 AC-9  with HARNESS_PS_LISTING empty, the listing comes from 'ps -ef' on PATH, and no ps says 'cannot list'
    FAIL no ps on PATH: exactly the AC-5 'cannot list' line, rc 0
         expected: selftest: cannot list this host's processes; other test runs, if any, were not noticed.
         rc=0
         actual:   rc=0

host-load: 52 passed, 2 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_host-load.sh.20261026T195338Z.5869.bak) ===
  37:     command -v ps >/dev/null 2>&1 || return 1
```

**Not earned by mutation:** the AC-9 no-ps *precondition* assertion. It checks
the test's own PATH, not production behaviour, so there is no production
mutation that pins it; it is green because the environment is as built.

**GREEN is not a no-op:** AC-8 needs the one-line guard in the handoff
addendum. `bash scripts/mutate.sh --check` was clean after every mutation.

## Diff review

Run at GATES → REVIEW step 1, 2026-10-26, over `git diff main...HEAD` at
`1bf2c5b`. Reviewer: a fresh `feature-developer` dispatch, resolved to **Opus
5.5 (`claude-opus-5-5`)**, its declared `opus`, no override. It changed no
file. Report as returned, lightly condensed in the checked list:

What this change does: Before its first suite, `scripts/selftest.sh` now
sources a new `scripts/host-load.sh` and reads `ps -ef`. If it finds other
harness test runs outside this run's own process tree, it reports them on
stderr. `.claude/tests/_lib.sh` exports `HARNESS_PS_LISTING=/dev/null`, so
every fixture run a suite starts sees an empty listing and prints nothing. A
new 48-assertion suite pins the behaviour against injected listings.

Checked and sound: descendant and ancestor sets separate, loop-bounded; the
amended `C:\Program Files\...\bash.exe` rule; `-` as stdin in gawk, mawk,
BusyBox and BWK awk; a bad header under pipefail gives "cannot list" even with
SIGPIPE; `local found` then `found=$(...) || {` keeps the status; every
golden-running suite sources `_lib.sh` and no `env -u`/`env -i` strips the
export; `refresh-harness.sh` ships `.claude/tests` with `scripts/*.sh`; CI's
step shell is an ancestor and matches nothing; Linux/macOS `ps -ef` print full
commands when piped; `lib` 324/0; `host-load` 48/48 = floor, whole-output
needles; cost ~60 ms per fixture run, a few seconds per full run, immaterial.

**Should fix:**

1. **Junk rows from a multi-line command produce a false warning, including one about this run's own command** (`scripts/host-load.sh:73-82`)
   - **What this is:** The per-row parse that takes PID, PPID and the command by field number.
   - **Problem:** On Git Bash, `ps -ef` prints each line of a multi-line command as a row of its own. Reproduced on this host: a Bash-tool command whose second line was `# a b c d bash scripts/selftest.sh` made `host_load_warn $$ $$` print `selftest: 4 other test run(s) are on this host` and four `pid a: bash scripts/selftest.sh` lines, from the shell running the check. `cd /d/a && git -C /d/b/c status && bash scripts/selftest.sh` also matches, since the sixth word holds a `/` and the rule scans on.
   - **Fix:** Skip any data row whose PID or PPID is not all digits. Needs a RED test first.
   - **If we skip it:** Now and then a run reports foreign runs that do not exist; the warning's job is to explain slowness accurately.

2. **A Git Bash run more than a day old is probably never reported** (`scripts/host-load.sh:73-82`)
   - **What this is:** The same field-number parse, when STIME is two words.
   - **Problem:** If Cygwin `ps` prints `Oct 25` for a day-old process, the command starts a field later and `ryanc 123 1 ? Oct 25 bash scripts/selftest.sh` is missed - the orphaned-run case the Context names.
   - **Fix:** Confirm the format on a host with an old process; if two words, shift the command start by one when `$cc` is all digits after a month. Plus a RED fixture row.
   - **If we skip it:** The warning is silent in the case it most needs to speak.

3. **The real `ps -ef` branch has no test** (`scripts/host-load.sh:33-40`)
   - **What this is:** `host_load_listing`'s branch when `HARNESS_PS_LISTING` is empty.
   - **Problem:** Every case injects a listing, so the branch never runs under test; `ps -eo args`, a dropped `command -v ps`, or an inverted `|| return 1` all leave 48/48 green.
   - **Fix:** Two cases with `HARNESS_PS_LISTING=` and a stub `ps` first on `PATH`: one printing a fixture listing, one absent. A return to RED.
   - **If we skip it:** A regression in the one path that reads the real host goes unnoticed; DV-2 was waived.

Not checked: whether MSYS/Cygwin `ps -ef` really prints a two-word STIME for a day-old process; nothing on this host was that old.

Verdict: Ship.

**Orchestrator's disposition (lead-po):** the user chose (2026-10-26) to take findings 1 and 3 in this story - AC-8 and AC-9 added under `## Amendments`, a return to RED for their tests, the junk-row guard in GREEN - and to file finding 2 as a follow-up story. See
`## Notes`.

### Round 2 (2026-10-26, the fix only: `git diff 1bf2c5b HEAD -- scripts .claude/tests`)

Reviewer: a fresh `feature-developer` dispatch, resolved to **Opus 5.5
(`claude-opus-5-5`)**, its declared `opus`, no override. It changed no file.

What this change does: `scripts/host-load.sh` now skips any listing row whose
PID or PPID is not all digits, so a multi-line command's later lines are never
reported as test runs; the header says so, and admits a continuation line with
numeric words 2 and 3 still parses as a process. `host-load.test.sh` gains AC-8
(four continuation shapes plus a numeric control) and AC-9 (a stub `ps` on
PATH; a PATH with no `ps`); floor 48 -> 54.

Checked: the guard runs before anything is recorded, so a skipped row leaves no
trace in the parent map, descendants or ancestor walk; Linux, macOS and
Cygwin/MSYS `ps -ef` print PID/PPID as plain integers - on this host every row
the guard would skip was a continuation line, none of this user's real rows; a
UID with a space skips all that user's rows together, no worse than before
(they were undetected already); AC-9's stub refuses any argument but `-ef`,
PATH changes only inside the `bash -c` child, later cases unaffected;
`command -v awk` gives an absolute path on ubuntu-latest and every other tool
on that branch is a builtin; AC-9 cannot pass for the wrong reason (precondition
shows awk runs; both mutations in `## Regressions` turned their case red);
`## Regressions` "Return 1" shows fenced output with restore lines; both floor
copies say 54. `host-load: 54 passed, 0 failed`, floor met.

**Nice to have:**

1. **One sentence in the header comment is now out of date** (`scripts/host-load.sh:28-30`)
   - **What this is:** The "Known limits" sentence about a UID holding a space.
   - **Problem:** It says such a row "shifts the command one field"; with the new guard the row is skipped, not shifted.
   - **Fix:** Reword it to say that user's rows are skipped by the guard (unless the name's second word is a number). Comment only.
   - **If we skip it:** Whoever picks up HARNESS-076 starts from a wrong description of today's behaviour.

Not checked: the suite on Linux or macOS; AC-9's PATH handling there is from reading, not a run.

Verdict: Ship.

**Orchestrator's disposition (lead-po):** finding 1 is Nice to have and listed
only; rather than another code round here, it is carried into HARNESS-076's
`## Notes`, the story that owns the UID-with-a-space limit.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-26T20:04:19Z
    commit: f1e84ff
    tree:   2f0b0e6a868bb46c74486dd835c4be09592cc1a5
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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
- **GREEN verified by the orchestrator (2026-10-26).** Reran
  `bash scripts/selftest.sh host-load`: 48 executed, 48 declared, passed (RED:
  22 passed, 26 failed); `gates.sh --fast` exit 0; `mutate.sh --check` clean.
  The feature-developer reported `selftest` 268/0, `run-lock` 140/0, `lib`
  324/0, `sigpipe` 91/0, `grep-count` 38/0, both tree guards 0 findings over
  54 files, and confirmed five of the 22 pass-on-arrival assertions against
  the shipped files by `mutate.sh` (output in its report; e.g. dropping `>&2`
  turned exactly the predicted 12 red). Real-host preview, not DV-2: with
  another project's `gates.sh --fast` live it printed
  `selftest: 2 other test run(s) are on this host; ...` naming both pids.
  Resolved model: GREEN `feature-developer` on Opus 5.5 (`claude-opus-5-5`),
  its declared `opus`, no override.
- **GREEN's findings, for the PO (2026-10-26).**
  1. The Contract's "CI sees `/dev/null`" is half true: only processes that
     source `_lib.sh` (every fixture run and golden) do. CI's top-level
     `bash scripts/selftest.sh` reads the runner's real `ps -ef`, harmless
     where no other harness run exists. `selftest.sh`'s header says so.
  2. Real `ps -ef` on this host prints a command's embedded newlines as extra
     rows (seen for a `bash -c '...<<EOF...'` tool shell). Those rows carry
     junk PID/PPID; none falsely matched today, but a crafted one could. The
     fix (skip rows whose PID/PPID are not numeric) has no failing test, so it
     was not written (law 1). Named as a known limit in `host-load.sh`'s
     header; a follow-up story candidate.
  3. RED's two-field STIME and UID-with-a-space limits are unhandled, as the
     Contract's `cmd..NF` rule implies; GREEN checked that the header's
     character offset is not a fix either (Linux fixture: CMD header at 52,
     row commands at 56). Named in the file header.
  4. Wrappers (`timeout`, `nohup`) are not matched themselves; their child is,
     so the run is still reported.
  5. `host_load_others` on an empty file returns 0, not 1: an empty file has
     no header to refuse, and AC-6 needs an empty listing to print nothing.
- **Finding 1 reproduced by the orchestrator (2026-10-26), with a different
  command from the reviewer's.** A Bash-tool call of three lines -
  `unset HARNESS_PS_LISTING; . scripts/host-load.sh`, then the comment
  `# a b c d bash scripts/selftest.sh`, then `host_load_warn $$ $$` - printed:

      selftest: 6 other test run(s) are on this host; expect this run to be slower, not wrong:
      selftest:   pid 951: bash scripts/gates.sh
      selftest:   pid 824: bash scripts/gates.sh
      selftest:   pid a: bash scripts/selftest.sh
      selftest:   pid a: bash scripts/selftest.sh
      selftest:   pid a: bash scripts/selftest.sh
      selftest:   and 1 more

  The `pid a` rows are the call's own continuation lines; the two `gates.sh`
  rows were real runs elsewhere on the host. Finding 1 stands.
- **Return to RED (2026-10-26), the user's decision.** From GATES, for AC-8
  and AC-9's tests (see `## Amendments`). Finding 2 (two-field STIME) is filed
  as a separate follow-up story on main.
- **RED return verified by the orchestrator (2026-10-26).** Reran
  `bash scripts/selftest.sh host-load`: 53 passed, 1 failed - the one red is
  AC-8's main assertion, printing the four continuation rows beside X - plus
  the below-floor line (53 against the new floor 54). `host-load` 54 in both
  `floors.conf:47` and `selftest.test.sh:538`. `scripts/` untouched;
  `mutate.sh --check` clean. AC-9's two cases were earned by mutation
  (`ps -ef` -> `ps -eo args`; `command -v ps ... || return 1` -> `return 0`),
  output in `## Regressions`. Resolved model: RED `test-developer` on Opus 5.5
  (`claude-opus-5-5`), its declared `opus`, no override.
- **Second GREEN verified by the orchestrator (2026-10-26).** Reran
  `bash scripts/selftest.sh host-load`: 54 executed, 54 declared, passed
  (RED return: 53/1); `gates.sh --fast` exit 0. The guard
  `if ($pc !~ /^[0-9]+$/ || $ppc !~ /^[0-9]+$/) next` sits at the top of the
  per-row block; the header's Known limits now attribute the STIME and
  UID-with-a-space limits to HARNESS-076 (planned on main as `5962311`, in
  worktree `D:/adh-HARNESS-076`). The feature-developer reported `lib` 324/0,
  `sigpipe` 91/0, `grep-count` 38/0, and the real-host repro now printing
  nothing (`rc=0`) while `ps -ef` still showed the continuation row. Resolved
  model: GREEN `feature-developer` on Opus 5.5 (`claude-opus-5-5`), its
  declared `opus`, no override.
- **Full self-test before REVIEW (2026-10-26, GATES, orchestrator).** After the
  round-2 diff review returned `Verdict: Ship.`, with no other test run live on
  the host, `SELFTEST_JOBS=4 bash scripts/selftest.sh` ran detached from
  15:06:50, stdout and stderr captured apart. Exit status 0. Last lines:

      assertion floors: all 29 suite(s) met their declared floor (4125 assertions executed, 3948 declared).
      29 harness suite(s) passed.

  Duration: 702 s. Stderr was empty: the run's own `host_load_warn`, reading
  the real `ps -ef`, found no foreign run - consistent with the host, and the
  first top-level run of the shipped warning. (29 suites: `host-load` is new.)
