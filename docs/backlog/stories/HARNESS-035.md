---
id: HARNESS-035
title: Opt-in concurrent self-test suites
slug: opt-in-concurrent-self-test-suites
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-035-opt-in-concurrent-self-test-suites
depends_on: [HARNESS-034]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/selftest.sh, .claude/tests/selftest.test.sh, .claude/tests/floors.conf, .claude/state/README.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

This story is the second half of finding C + MT-042, group 6 ("Process"), in
`docs/wiki/audits/manga-translator-port-2026-10-02.md` (GitHub issue #97).
HARNESS-034 (release 77, #111) built the first half, the run lock. The audit's
`## Decided` item 6 C is settled and is not reopened here: **"then opt-in
concurrent suites (`SELFTEST_JOBS`, default 1 locally) with per-run
buffers."** HARNESS-034's `## Out of scope` recorded what this follow-up must
honour: default **1** locally (downstream `053c58e` defaults to 4, not to be
copied), output buffers keyed **per run** (downstream used one shared
`.claude/state/selftest/` per tree), and a raised `selftest` floor.

**Why opt-in, and why it is worth having at all.** A full self-test takes
25-70 minutes on this Windows host (6,135 s on 2026-10-02, alone) and about 31 s
to 2 minutes on `ubuntu-latest`. It is spawn-bound, and finding C is what
happens when two spawn-heavy runs share a Windows machine: a hang past 30
minutes, `E_OUTOFMEMORY` in another case. So concurrency is for the person who
chooses it on a machine they know; the default stays one suite at a time, which
is what every run does today, and CI is not changed (decision in `## Notes`).

**Downstream is a reference, not a source.** `053c58e` in manga-translator
(read at PLANNED: `git -C /d/manga-translator show 053c58e`, and its MT-042
story) is a 241-line rewrite of the runner: one concurrent path for every run,
default 4, a shared buffer directory, largest-file-first start order and a
`SERIAL_SUITES` hatch. This story takes its verified mechanism - `kill -0`
polling plus `wait <pid>` per job, because bash 3.2 has no `wait -n` - and its
two classic failure modes as tests (a lost exit status, completion-order
output). It does not take the default, the buffer path, the single path for
all runs, or the hatch (`## Out of scope`).

**Verified at PLANNED against this tree (release 77, `c9260a7`):**

- **How `scripts/selftest.sh` runs today.** `:63` `ONLY="${1:-}"`. `:181-184`
  load the floors files; `:214-221` build the suite list in glob order;
  `:226-259` audit floors and exit 1 with `Nothing was run.` before anything
  runs. `:261-275` is HARNESS-034's lock block: source `run-lock.sh` (`:271`),
  `trap run_lock_release EXIT` (`:272`), INT -> 130 (`:273`), TERM -> 143
  (`:274`), `run_lock_acquire ... || exit 2` (`:275`). `:277` `# --- run ---`.
  `:279-322` is one sequential loop: header `printf '\n=== %s ===\n'` (`:283`),
  `out="$(bash "$suite" 2>&1)"; rc=$?` (`:288`), `printf '%s\n' "$out"`
  (`:289`), then the per-suite verdict (`:291-321`): rc, the floor read from
  `$out` by `executed_count` (`:304`), the `FAIL ... printed no summary line`
  and `FAIL ... below the floor` lines to stdout, the single-suite `WARNING`
  lines to stderr. `:324-327` `No suites matched` exit 1; `:329-345` the floors
  line and `N harness suite(s) passed.` / `F of N harness suite(s) FAILED.`
  (exit 1). Everything a suite prints, stderr included, reaches selftest's
  stdout through `$out`; `$(...)` strips its trailing newlines.
- **Nothing pins `selftest.sh` line numbers** (`grep 'selftest\.sh:[0-9]'
  .claude/tests/*.sh` is empty), and this story does not touch `gates.sh`, so
  `sigpipe.test.sh`'s pin on `scripts/gates.sh:74` cannot move.
- **The primitives, measured on both platforms at PLANNED** (scratch scripts,
  not committed):
  - MSYS Git Bash 5.3.15 and WSL Ubuntu bash 5.2.21: a background job polled
    with `kill -0` until gone, then `wait <pid>`, returns that job's own status
    (`exit 7` -> `rc=7` on both). `wait -n` exists in both, but bash 3.2 (macOS
    `/bin/bash`) lacks it, so it is not used.
  - Both: a script with two background jobs, a `sleep` poll loop,
    `trap 'exit 143' TERM` and an `EXIT` trap that `wait`s each job, sent TERM:
    exits 143, and both jobs ran to completion before the EXIT trap finished.
    That is the drain C-4 relies on.
- **Write isolation of the real suites, surveyed.** Every suite builds its own
  `mktemp -d` fixture (`make_fixture`, `_lib.sh:81-116`, or its own `mktemp`).
  Every `$REPO_ROOT` reference is a read: sourcing `lib.sh`, reading scripts,
  the README and `settings.json`, `git check-ignore`, `ci-local.sh --dry-run`
  (`ci-local.test.sh:25`), `classify.sh --list` (`sigpipe.test.sh:113`).
  Real scripts that write are run only from fixture copies: `new-story.sh`
  (`new-story.test.sh:20-24`), `refresh-harness.sh` run with `cd "$PROJ"`
  (`refresh.test.sh:90`), and the hooks with `CLAUDE_PROJECT_DIR` pointed at
  the fixture (`_lib.sh:181`, `gate-reminder.test.sh:51`) - `phase-guard.sh`
  writes its declined log to `$HARNESS_ROOT` (`phase-guard.sh:62,81`), which is
  `CLAUDE_PROJECT_DIR` (`lib.sh:10`). `mutate.test.sh:126,680`'s relative
  `.claude/state/mutations/*.bak` runs inside `mutate.sh`'s `( cd "$ROOT" ...)`
  where `ROOT` is the fixture's. `run-lock.test.sh:80-101`'s `$REPO_ROOT`
  writes are inside heredoc suite bodies written into the fixture, where
  `REPO_ROOT` resolves to the fixture. `worktree.test.sh` and `plan.test.sh`
  add worktrees to fixture repositories only.
  **Measured as well as read** - see `## Notes`, "Isolation probe", for the
  result of running every suite concurrently in this worktree and diffing the
  tree before and after.
- **Nested runs under HARNESS-034's lock.** `run_lock_acquire` exports
  `HARNESS_RUN_LOCK` and `HARNESS_RUN_LOCK_PID` (selftest.sh's `$$`). A suite
  started in the background inherits them exactly as a foreground one does,
  and `$$` does not change in a background job. Fixture runs compare the
  marker path with their own lock path and take their own lock (HARNESS-034
  AC-5), so nothing about the lock changes. `run_lock_release` returns at once
  in a subshell (`run-lock.sh:146`, `${BASHPID:-$$}` guard), so a job's subshell
  cannot release the parent's lock. What concurrency DOES change is the exit
  path: today `trap run_lock_release EXIT` releases at exit, which is correct
  only because no suite can still be running then. With background suites the
  release has to come after they are drained (C-4).
- **CI and `ci-local.sh`.** `.github/workflows/gates.yml:72` runs
  `bash scripts/selftest.sh`; `:104` the colour-forced re-run.
  `scripts/ci-local.sh` derives its steps from the workflows' `run:` lines and
  `eval`s them, and `ci-local.test.sh` derives the expected step list from the
  same files. Neither is changed by this story, so neither derivation moves. A
  person who exports `SELFTEST_JOBS` gets it in `ci-local.sh`'s self-test steps
  too, through `eval`'s inherited environment, which is what opt-in means.
- **Shipped-script rules already enforced** that bear on GREEN:
  `lib.test.sh:318-319` - no shipped script uses `$TMPDIR` or `mktemp`, so the
  buffers go under `.claude/state`; `lib.test.sh:266-270` - no `${var,,}`, no
  GNU `sed -i` in `scripts/*.sh`; `check-sigpipe.sh` and `check-grep-count.sh`
  scan `selftest.sh`.

**The required gate that fails if this breaks:** `selftest` (the CI step
`bash scripts/selftest.sh`), through `selftest.test.sh`. `project.conf` is
unbootstrapped upstream; no optional gate is involved and `required_gates`
stays empty.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

Every criterion except AC-6's real-tree facts is observed in a throwaway
fixture built by `make_project_fixture`, with the real `_lib.sh` copied in and
synthetic suites written by the test, exactly as `selftest.test.sh` does today.
"Holds" means a suite blocks on a file the test creates (bounded, so a defect
cannot hang the suite), so ordering is a state the test controls rather than a
race it hopes to win. Every case states `SELFTEST_JOBS` explicitly - set, empty,
or removed with `env -u` - and none depends on the caller's environment.

- **AC-1 (the default is unchanged)** — Given a fixture of at least four
  suites, when `bash scripts/selftest.sh` runs with `SELFTEST_JOBS` unset, set
  empty, and set to `1`, then the three runs' stdout, stderr and exit status are
  identical to each other and byte-identical to the output the release-77
  `selftest.sh` produced on the same fixture (captured in RED and held in the
  suite as a literal); no two suites are ever alive at once (each suite records
  which others are alive when it starts); and no `.claude/state/selftest.*`
  entry exists during the run (a suite lists `.claude/state` while it runs) or
  after it. *Control:* the same fixture with `SELFTEST_JOBS=3` has suites alive
  together (AC-3) and a buffer directory during the run (AC-5).
- **AC-2 (concurrent output is the serial output)** — Given a fixture whose
  first suite in glob order finishes **last**, in which one suite exits
  non-zero while meeting its floor (neither first nor last in glob order, nor
  first or last to finish), one exits 0 below its floor, one prints no summary
  line, and one writes to stderr and ends its output with blank lines, when it
  runs with `SELFTEST_JOBS=1` and with `SELFTEST_JOBS=3`, then the two runs'
  stdout is byte-identical, their stderr is identical, and both exit **1** with
  `3 of <N> harness suite(s) FAILED.` as the last line. The same holds for an
  all-passing fixture (both exit 0, identical `assertion floors: all ...` and
  `<N> harness suite(s) passed.` lines), for `SELFTEST_JOBS=3 bash
  scripts/selftest.sh <one suite>` against `SELFTEST_JOBS=1` (exactly one suite
  runs), and for `SELFTEST_JOBS=3 bash scripts/selftest.sh nosuchsuite` (the
  shipped `No suites matched 'nosuchsuite'. ...` line, exit 1). And during a
  `SELFTEST_JOBS=3` run, the first suite's `=== <name> ===` block is already on
  stdout while a later suite is still held. *Control:* the run's markers show
  the suites finished in an order other than glob order, so the identity is not
  bought by running them one at a time.
- **AC-3 (bounded, and a free slot is refilled at once)** — With
  `SELFTEST_JOBS=2` over four held suites, the largest number of suites alive at
  once is exactly **2**; with `SELFTEST_JOBS=3` over five, exactly **3**; with
  `SELFTEST_JOBS=10` over four, exactly **4**. And given `SELFTEST_JOBS=2` and
  four suites where the first in glob order holds until the **last** suite in
  glob order has started, the run completes and exits 0 - which a runner that
  waits on its oldest job instead of any job cannot do (it would wait until the
  hold's bound expires, and the suite fails). *Control:* the same fixture at
  `SELFTEST_JOBS=1` exits 1, the first suite reporting that its hold timed out -
  showing the hold really does need a second slot to clear.
- **AC-4 (a bad value is refused before anything runs)** — For each of
  `SELFTEST_JOBS` = `0`, `00`, `-1`, `abc`, `1.5`, ` 2` and `2x`, both
  `bash scripts/selftest.sh` and `bash scripts/selftest.sh <suite>` exit **2**,
  print on stderr exactly the one C-3 line naming that value, print nothing on
  stdout, run no suite (its marker is absent), and leave no
  `.claude/state/run.lock` and no `.claude/state/selftest.*` behind. The refusal
  happens even when `floors.conf` is also malformed (the value is checked
  first). *Control:* `SELFTEST_JOBS=10` (more than the suites) is accepted and
  passes.
- **AC-5 (per-run buffers, the lock held to the end, every exit cleans)** —
  During a `SELFTEST_JOBS=3` run, a suite observes the buffer directory
  `.claude/state/selftest.<pid>/`, where `<pid>` is the pid of the
  `selftest.sh` process (the test backgrounds the script itself, so `$!` is
  it), and the suite that finishes last still observes `.claude/state/run.lock`
  recording that pid. After the run exits 0, after it exits 1 (a failing
  suite), and after it is sent TERM while two suites are held and a third is
  queued, no `.claude/state/selftest.*` entry and no `run.lock` or `run.lock.*`
  remains. On TERM the run exits **143**, is still alive one second after the
  signal while its suites are held, both held suites write their `finished`
  marker before the run exits (they are let finish, not orphaned), and the
  queued suite never starts.
- **AC-6 (state, suite and portability hygiene)** — `.claude/state/README.md`
  has a row for `selftest.<pid>/*.out`, `yes` in the `Hand-editable` column,
  and `bash scripts/selftest.sh settings` passes. `git check-ignore -q
  --no-index .claude/state/selftest.12345/gates.out` exits 0 in this
  repository. `scripts/selftest.sh` defines C-2's `suite_status` on exactly one
  line, as written there; its code lines (not comments) contain none of
  `wait -n`, `wait -p`, `mapfile`, `readarray`, `coproc`, `declare -A`,
  `local -A` or `typeset -A`. The `selftest` floor in `floors.conf` and its
  row in `selftest.test.sh`'s `COUNTS` both equal the suite's total assertion
  count at the end of RED. `bash scripts/check-sigpipe.sh` and
  `bash scripts/check-grep-count.sh` stay clean over the tree, and a full
  `bash scripts/selftest.sh` passes.

## Contract

<!-- Written by the Lead PO BEFORE RED, and AMENDABLE BY RED IN PLACE with a
     reason - GREEN then builds what the amended block says. This is where "RED
     tested one shape and GREEN built another" is prevented, and it is not the
     acceptance criteria: the criteria are frozen and change only through
     ## Amendments; this is a working agreement RED is expected to sharpen.
     One block per thing the story touches:
       * the files it WRITES, on one line at column 0 that starts
         `**Writes:**`, each path backticked and repository-relative:
           **Writes:** `src/core/world.ts`, `tests/world.test.ts`
         `bash scripts/plan.sh conflicts` compares it with `touches:` and prints
         DRIFT for a written file `touches:` does not cover. Without the line
         there is no DRIFT at all, and files the prose merely cites never count
       * module paths and exported names, exactly
       * exact signatures, and the types the assertions will destructure
       * THE SEMANTICS BEHIND EACH NUMBER - not clamp(latitude) but "latitude
         clamps at +/-85, and dragging DOWN brings the north into view". One
         sentence per number settles a sign error in one line
       * the accessible markup for anything user-facing: roles, labels, what is
         a sibling of what
       * the oracle partition of the criteria (settled / oracle-free /
         mechanical - see story-authoring)
       * baseline measurements the story may read out rather than re-derive,
         each with what it was measured on
       * TEST-ONLY DEPENDENCIES this story is likely to need, by name. RED
         may add them itself, but only inside the dev block - so a library
         production will ALSO use is a GREEN change and is better decided
         here than discovered mid-phase. Where the ecosystem has no dev
         block at all (go.mod, requirements.txt, *.csproj), RED cannot
         declare one and the phase round trip is yours to plan for
       * FOR EVERY EXISTING EXPORT WHOSE SIGNATURE THIS STORY CHANGES: every
         caller, source and test, grep-listed here before dispatch. RED cannot
         find these itself - the old signature still exists during RED, so a
         caller of it still compiles and is absent from RED's typecheck. One
         such file went missing and took 25 tests with it, silently, at GREEN. -->

**Writes:** `scripts/selftest.sh`, `.claude/tests/selftest.test.sh`, `.claude/tests/floors.conf`, `.claude/state/README.md`

**RED may amend any block below in place, with a reason. GREEN builds what the
amended block says.**

**The phase lock enforces nothing here.** `scripts/*`, `.claude/tests/*` and
`.claude/state/README.md` all classify as `harness`, which every phase permits
(as in HARNESS-030 to -034). The split is held by discipline:

- **RED** writes only `.claude/tests/selftest.test.sh` (new cases, and the
  `selftest` row of `COUNTS`) and the `selftest` line of
  `.claude/tests/floors.conf`.
- **GREEN** writes `scripts/selftest.sh` and `.claude/state/README.md`.

Not written by anyone in this story: `scripts/gates.sh`, `scripts/run-lock.sh`,
`scripts/ci-local.sh`, `.github/workflows/*`, `.gitignore` (its
`.claude/state/*` already covers the buffers; AC-6 asserts it), `CLAUDE.md`,
the command files.

### C-1 Two paths, and the default takes the one that exists today

- **`SELFTEST_JOBS` unset, empty or `1`, or a run of at most one suite** (a
  named suite, or a tree with one): the existing sequential loop, unchanged in
  behaviour - capture with `out="$(bash "$suite" 2>&1)"; rc=$?`, print, judge.
  It creates nothing new, starts nothing in the background, and prints what
  release 77 prints byte for byte (AC-1).
- **`SELFTEST_JOBS` of 2 or more over two or more suites:** the concurrent path
  (C-2).
- **One verdict, shared.** The per-suite block of today's loop - header, the
  printed `$out`, rc, the floor read and its `FAIL` lines, the counters -
  becomes one function both paths call in glob order, so the two cannot drift.
  Name it `report_suite <name> <rc>` with the suite's output in the global
  `$out` (GREEN may choose the parameter passing; the name is not pinned by a
  test). The `WARNING: no floor line` path is reachable only on a single-suite
  run, which is always the sequential path.

### C-2 The concurrent path

- **Bounded.** At most `SELFTEST_JOBS` suites alive at once (AC-3). No upper
  cap: a value above the number of suites runs them all at once.
- **Work-conserving.** A slot is refilled when **any** running suite exits, not
  the oldest. No `wait -n` (bash 3.2): poll the running pids with `kill -0`,
  and collect a finished one's status with `wait <pid>`, which both platforms
  return correctly after the job has exited (measured, `## Context`). Each
  `sleep` in the poll is a fork, so back off while nothing changes (downstream
  went 0.1 s -> 2 s and reset on any exit); the interval is GREEN's choice.
- **Each suite's status is collected by its own pid, on exactly this line,
  once in the file:**

  ```
  suite_status() { wait "$1"; }
  ```

  called as `suite_status "$pid"; rc=$?`. One line, exactly, because DV-1's
  single `sed` expression targets it and AC-6 pins it. A `wait` that reports a
  pid it no longer knows returns 127, which counts as a failure - fail closed.
- **Start order is free; print order is not.** Suites may start in glob order
  or largest file first (downstream measured glob order leaving its longest
  suite ~108 s late); no test pins it, and DV-2 records what GREEN chose.
  Printing is in **glob order**, each suite's block contiguous, and a suite's
  block is printed as soon as it and every suite before it in glob order have
  finished (AC-2), so a 25-70 minute run is not silent until its end.
- **The buffer, per suite:** `bash "$suite" > "$BUF/<name>.out" 2>&1 &`, the
  redirect made before the suite's first line runs. Read back into `$out` with
  trailing newlines stripped exactly as `$(...)` strips them (a suite whose
  output ends in blank lines is in AC-2 for this reason; `$(cat "$buf")` is the
  simple way and costs one fork per suite on a full run only).
- **`VERBOSE`** reaches each suite through the environment, as today.
- No pipeline whose left side can be cut off by the right under `pipefail`
  (`check-sigpipe.sh`), no `grep -c ... || echo 0` (`check-grep-count.sh`).

### C-3 `SELFTEST_JOBS` and its refusal

Read once, **before anything else the script does** - immediately after
`ONLY="${1:-}"` (`:63`), before the floors files are loaded - so a bad value is
refused before the floors audit, before the lock, before any suite (AC-4).
Valid: unset, empty (both mean 1), or digits matching `[1-9][0-9]*`. Anything
else - `0`, `00`, leading zeros such as `04`, a sign, a decimal point,
whitespace, letters - is refused, on stderr, with exit **2** (the script's
"nothing ran" status since HARNESS-034, and `gates.sh:89`'s for a bad option),
with exactly this one line, `<value>` being the variable's value verbatim:

```
selftest: SELFTEST_JOBS must be a whole number of suites to run at once, 1 or more; got '<value>'. Nothing was run.
```

### C-4 Buffers, keyed per run, and one exit path

- **Where:** `$ROOT/.claude/state/selftest.$$/`, `$$` being this
  `selftest.sh` process - the pid the lock records. Created only on the
  concurrent path, **after** the lock is taken (a refused run creates nothing),
  with `mkdir -p`. Never `$TMPDIR` or `mktemp` (`lib.test.sh:318-319`).
  Keyed per run rather than downstream's shared `.claude/state/selftest/`,
  because two `selftest.sh` processes can legitimately be alive in one tree:
  HARNESS-034's C-4 lets a run nested under the lock holder through.
  If the directory cannot be created: one line on stderr,
  `selftest: cannot create .claude/state/selftest.<pid> for the suites' output; nothing was run.`,
  exit 2. Not an AC (it needs an unwritable directory, which `chmod` cannot
  make on Windows), but it is the fail-closed direction.
- **One `EXIT` handler, replacing `trap run_lock_release EXIT` at `:272`:**
  define a function before `:271` - name it `selftest_exit` - that, in order,
  (1) `wait`s every suite still running (on a normal exit there are none),
  (2) removes `$ROOT/.claude/state/selftest.$$` if this process created it,
  (3) calls `run_lock_release`. Then `trap selftest_exit EXIT` in place of
  `:272`. The INT and TERM traps at `:273-274` stay as they are. The lock is
  therefore released only after the last suite has exited, and a second run is
  refused for as long as any suite of this one is alive (AC-5).
- **TERM and INT drain; they do not kill.** On the signal no further suite is
  started; the suites already running are waited for; the buffers are removed;
  the lock is released; exit 143 or 130. This is HARNESS-034's serial
  behaviour (a trapped TERM waits for the foreground suite) carried over to N
  suites, measured on both platforms (`## Context`). A suite that never ends
  makes TERM wait, as it does in the serial runner today; SIGKILL leaves
  orphans either way (`## Out of scope`).
- **A buffer directory left behind** means a run was killed outright. It is not
  reclaimed by the next run; the README says it is safe to delete.

### C-5 `.claude/state/README.md`

One row, after `run.lock.<pid>`, `Hand-editable` **yes** (written and removed
by a tool, safe to delete; a deny rule would block that `rm`):

```
| `selftest.<pid>/*.out` | `scripts/selftest.sh`, with `SELFTEST_JOBS` above 1 | `scripts/selftest.sh`, to print each suite in order | yes |
```

and a short paragraph under "The exhaust": a full self-test run with
`SELFTEST_JOBS` of 2 or more writes each suite's output there and prints it in
order; the directory is removed on every exit the script can still run code
on; one left behind means a run was killed outright and is safe to delete. No
`settings.json` change: `yes` rows carry no deny rules, and `settings.test.sh`
checks that both ways.

### C-6 The suite: `selftest.test.sh`

New cases appended to the existing suite (not a new suite), reusing its
fixture (`make_project_fixture` + real `_lib.sh`) and its `reset_suites` /
`floors` helpers. Synthetic suites hold on files the test creates, bounded
(60 s for "started", 120 s for a hold), and record what they see into a marker
directory: alive peers on start (`alive/<name>` created on start, removed on
finish), `finished/<name>`, a listing of `.claude/state`, the content of
`run.lock`. AC-3's "hold until the last suite has started" uses a SHORT bound
(about 10 s), because its control at `SELFTEST_JOBS=1` is meant to hit it; a
120 s bound there would cost the suite two minutes on every run. The holder for AC-5 is the script itself backgrounded after `cd`
(`bash scripts/selftest.sh &`), as `run-lock.test.sh` does, so that `$!` is the
pid in the directory name and the lock. An `EXIT` trap releases every hold and
waits every background pid.

**Every new case sets `SELFTEST_JOBS` explicitly**, including the default case
(`env -u SELFTEST_JOBS`). The existing cases are left alone and inherit the
caller's value; under DV-2's `SELFTEST_JOBS=4` run they therefore exercise the
concurrent path over every floors case, which is free coverage, not a
dependency.

AC-1's golden is captured in RED by running the release-77 `selftest.sh` (the
one in the tree at RED) on the AC-1 fixture, and pasted into the suite as a
literal; it contains only text the synthetic suites print and selftest.sh's
own lines, no paths or pids.

Comparisons are whole-output (`assert_eq` on the full stdout) or whole lines
(`grep -cxF`), never a floating substring: `harness suite(s) passed.` is a
suffix of nothing wrong, but `FAILED.` lines differ only by their counts.

**The floor.** `floors.conf`'s `selftest` line and `COUNTS`' `selftest` row
record the suite's TOTAL assertion count at the end of RED - passed plus
failed, which is what it will pass when green (HARNESS-033 and -034 did the
same), with a HARNESS-035 note at the foot of `floors.conf`.

### C-7 Oracle partition

- **Settled - read out, do not re-decide:** opt-in concurrency, the variable's
  name, default 1 locally, buffers per run (audit `## Decided` 6 C and
  HARNESS-034 `## Out of scope`); the refusal line, exit 2, the buffer path,
  `suite_status`, drain-on-TERM (this contract). The output strings
  `=== <name> ===`, `No suites matched ...`, `... harness suite(s) passed.`,
  `... FAILED.` are read out of `scripts/selftest.sh` as shipped, not reworded.
- **Mechanical - pin exactly:** every AC. Exit statuses exactly (2, not
  "non-zero"; 143). Peaks exactly (2, 3, 4), not "at most".
- **Oracle-free:** none among the ACs. DV-2's timing is a measurement with a
  recorded verdict, not a threshold.

### C-8 Callers

No existing function signature changes. The CLI gains one outcome, exit 2 with
the C-3 line, for an environment value no caller sets today. Callers of
`selftest.sh` - `ci-local.sh:181` (`if ! eval "$cmd"`), the CI steps
(`gates.yml:72,104`), `mutate.sh`'s command, and the fixture runs in
`selftest.test.sh` and `run-lock.test.sh` - treat any non-zero as failure and
need no change.

## Deferred verifications

<!-- REQUIRED when a verification this story depends on provably cannot run in
     the phase that wants it; omit the section otherwise. Written by the Lead PO
     at PLANNED, and the phase that owns it pastes the result in.
     The case this exists for: a negative control for a round trip, a threshold
     or a codec has to break the real implementation to mean anything, and in
     RED there is no implementation to break. RED naming the control and saying
     it could not run it is the honest answer; RED claiming a verification it
     did not do is the failure. One block per entry:
       * what it verifies, as a falsifiable condition - "with one field dropped
         from the encoder, AC-1's property test MUST fail"
       * why the phase that wants it cannot run it
       * THE PHASE THAT OWNS IT, declared as `Owner: GATES` (or RED, GREEN,
         REVIEW). check-boundaries.sh refuses a PR
         whose block names no phase
       * the RESULT, pasted, once that phase runs it: what was mutated, what
         failed, and that the file was restored - or the word WAIVED with the
         reason. check-boundaries.sh refuses a PR that has neither
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

This story adds no rule over the tree and adds or changes no gate, so it owes
no real-tree probe and no `## Gate probes`. AC-1's cases pass on arrival in RED
by design (the default path is today's code); they are earned by the RED-time
golden capture and by DV-1's "must stay green" half, not by a separate
mutation. The budget is `rules.md`'s default: one "defect put back" entry,
DV-1. DV-2 is the measurement the story was asked for.

**DV-1 (defect put back: a concurrent run loses a suite's exit status).**
Owner: GATES. This is the classic concurrent-runner defect and the one that
makes a concurrent runner strictly worse than a slow one: it reports success
over a failing harness. C-2 pins `suite_status` to one line so that this one
expression matches it (checked at PLANNED against that exact line with Git
Bash's sed and GNU sed on Linux: both print
`suite_status() { wait "$1"; return 0; }`, and a function so mutated returns 0
for a job that exited 5). Run detached (`nohup`), so a tool limit cannot kill it
mid-mutation:

```
bash scripts/mutate.sh scripts/selftest.sh 's|suite_status() { wait "\$1"; }|suite_status() { wait "$1"; return 0; }|' -- bash scripts/selftest.sh selftest
```

The outer run is single-suite and so takes the sequential path, which never
calls `suite_status`; the fixtures copy the mutated script. **Must** fail:
AC-2's failing-fixture comparison (the `SELFTEST_JOBS=3` run exits 0 and its
last line is `<N> harness suite(s) passed.` where the serial run's is
`3 of <N> harness suite(s) FAILED.` - only the rc-only failure is lost, so the
expected wrong count is visible), and AC-5's exit-1 case if it asserts the
status. **Must stay green:** every AC-1 case and the `SELFTEST_JOBS=1` halves of
AC-2 - which is what shows the mutation hit the concurrent path's status
collection and not the runner as a whole. Record the counts. RED cannot run
this: there is no `suite_status` to mutate. Paste the `mutate.sh` output,
including its verified restore, and a green re-run of
`bash scripts/selftest.sh selftest`.

**DV-2 (the real full self-test, `SELFTEST_JOBS=1` then `SELFTEST_JOBS=4`, on
this host).** Owner: GATES, as part of GATES -> REVIEW step 1. The two runs go
**one after the other, never together** - the run lock would refuse the second
anyway, and running them together would measure contention, not the runner.
Both detached (`nohup`), in this worktree, nothing else running in it:

```
# run 1 - this IS step 1's full self-test; the variable is removed, not trusted
git status --porcelain --ignored > /tmp/h035-before-1; ls -A .claude/state > /tmp/h035-state-1
s=$(date +%s); env -u SELFTEST_JOBS bash scripts/selftest.sh > /tmp/h035-jobs1.out 2>&1; echo "rc=$? wall=$(( $(date +%s) - s ))s"
# run 2 - only after run 1 has exited
s=$(date +%s); SELFTEST_JOBS=4 bash scripts/selftest.sh > /tmp/h035-jobs4.out 2>&1; echo "rc=$? wall=$(( $(date +%s) - s ))s"
git status --porcelain --ignored > /tmp/h035-after; ls -A .claude/state > /tmp/h035-state-2
```

(Use a scratch directory with an explicit path if `/tmp` is not writable.)
Falsifiable conditions, each of which can come out either way:

1. Both runs exit 0.
2. The two runs' suite summary lines (`^[a-z-]+: [0-9]+ passed, [0-9]+ failed$`)
   are identical **in order**, as are their `assertion floors:` and
   `harness suite(s) passed.` lines. A difference is a suite that behaves
   differently beside others - a write-isolation or timing defect in the real
   suites - and is a GATES failure, not a flake to re-run away.
3. `git status --porcelain --ignored` and `ls -A .claude/state` are the same
   before run 1 and after run 2: no buffer directory, no lock, nothing written
   into the real tree.
4. **Speed, recorded with a verdict.** Paste both wall times and the ratio.
   The `selftest.sh` header's sentence about when `SELFTEST_JOBS` helps is
   written from this result: if run 2 is not faster than run 1 on this host, the
   header says so, plainly, rather than recommending it. Also record what start
   order GREEN chose (C-2).

Why beyond the default budget: every suite assertion runs over synthetic
fixture suites, so this is the only check that the 24 real suites are
write-isolated when they actually run side by side - the premise the audit's
"What would have to be true" names - and it is the measurement that decides
whether the feature is worth recommending here. Its cost is one extra full run
(the `SELFTEST_JOBS=1` run is step 1's, which GATES -> REVIEW makes anyway).
RED cannot run it: there is nothing concurrent to run.

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

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-035` from `.claude/harness/models.conf`.
A PLAN, not a record: a session setting or an explicit override can beat both
this and the agent's own `model:` field, and nothing here can see which won.
The orchestrator still writes down the model each dispatch **resolved** to, by
name, below the table.

| Phase | Agent | Planned | Why |
|---|---|---|---|
| PLANNED | `lead-po` | `opus` | planning is the judgement phase: decomposition, the oracle partition, and what goes in the contract |
| RED | `test-developer` | `opus` | the lock freezes none of the paths this story names, so the contract is not an aid to the model here - it is the only enforcement there is. A weaker model against a safety net and a weaker model against nothing are different propositions |
| GREEN | `feature-developer` | `opus` | the failure mode of a weaker model here is reaching green by weakening a test, which is the one thing this harness exists to prevent |
| GATES | `feature-developer` | `opus` | same risk as GREEN, and a gate failure is where "make it stop complaining" is most tempting |
| REVIEW | `lead-po` | `opus` | reading review feedback against the contract is judgement, and a wrong call here ships |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation, with no failing test in front of any of it |

**Resolved:**

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

- PLANNED, `lead-po`, resolved to Opus 5.5 (`claude-opus-5-5`), dispatched without a model override.

**Oracle partition for the RED brief:** `## Contract` C-7. In short: opt-in,
the name, default 1 and per-run buffers are settled (audit `## Decided` 6 C,
HARNESS-034 `## Out of scope`); the refusal line, exit 2, the buffer path,
`suite_status` and drain-on-TERM are settled by this contract; the shipped
output strings are read out of `selftest.sh`; every AC is mechanical, pinned as
whole outputs or whole lines and exact statuses and peaks; nothing is
oracle-free.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **Changing the default, or setting `SELFTEST_JOBS` in CI.** CI runs the
  self-test in about 31 s to 2 minutes on `ubuntu-latest`, so concurrency pays
  least there, and `gates.yml` is a template every consuming project copies.
  Setting it in a workflow `run:` line would also put it into `ci-local.sh`'s
  local run (it `eval`s those lines), which is exactly the local default the
  audit decided against. No assertion pins "no `SELFTEST_JOBS` in the
  workflows" either: a consuming project may legitimately set it in its own
  CI, and an upstream suite that pins a project-owned value is issue #97's
  finding A.
- **`SERIAL_SUITES` or any per-suite opt-out.** Downstream shipped an empty
  hatch. If DV-2 shows a real suite misbehaving beside others, that is a GATES
  failure to stop on and re-plan, not a hatch to improvise.
- **A `selftest.sh` option instead of an environment variable**, and any upper
  cap on the value.
- **Reclaiming a buffer directory left by a killed run.** Documented as safe to
  delete (C-5); no sweep.
- **Orphans after SIGKILL, and killing a suite's own children on TERM.** The
  drain waits for each suite's `bash` process; a suite's fixture processes are
  its own business, as in the serial runner (HARNESS-034 `## Out of scope`).
- **Command prose.** `advance-story.md` and `complete-story.md` keep
  `bash scripts/selftest.sh` as GATES -> REVIEW step 1 (`procedure.test.sh`
  pins that text, and the `allowed-tools` prefix `Bash(bash
  scripts/selftest.sh:*)` would not match a `SELFTEST_JOBS=4 bash ...`
  invocation). `CLAUDE.md`'s command list is not edited; the variable is
  documented in `selftest.sh`'s own header, which is where `VERBOSE=1` is.
- **`gates.sh`.** Not touched; its `sigpipe.test.sh` pins (`gates.sh:74`,
  `:580`) stay where they are.
- **Group 6 D** of the audit (the 3g/3h messages). A separate story.

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
         or Gate probes section describes a failure without showing one
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
     it guards, run the gate, paste the failure, revert. One block per gate:
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

**PLANNED, 2026-10-05 (lead-po).** One story: the behaviour is "one run's
suites run concurrently, opt-in", one RED->GREEN cycle over `selftest.sh` and
its own suite. Left uncommitted at PLANNED: the orchestrator creates
`story/HARNESS-035-opt-in-concurrent-self-test-suites` and commits the story
there at PLANNED, which is the criteria baseline (HARNESS-033).

Decisions this plan took that the audit did not, each open to RED amending the
contract and to the user overruling:

- **Two paths, not one** (C-1). With the default at 1, keeping today's loop for
  it means the default changes nothing - no buffers, no background jobs, no new
  state - by construction rather than by test. Downstream's single path made
  every run concurrent-shaped. The cost is a shared verdict function, so the
  paths cannot drift, and AC-2 compares them byte for byte.
- **Invalid values refuse with exit 2** (C-3), before anything else; downstream
  exits 1. 2 is this script's "nothing ran" since HARNESS-034. Leading zeros
  (`04`) are refused rather than normalised - simpler, and no one types them.
- **TERM drains rather than kills** (C-4), matching HARNESS-034's serial
  behaviour; downstream kills the running suites.
- **Incremental printing** (C-2, AC-2): a suite is printed as soon as it and
  its glob predecessors are done, so a long run is not silent until the end.
- **CI unchanged** (`## Out of scope`).

**Isolation probe (PLANNED, 2026-10-05).** Every real suite was run directly
(`bash .claude/tests/<name>.test.sh`, not through `selftest.sh`, so no lock
was involved), at most four at a time, started in glob order, in this worktree
at `c9260a7` with no story active. Before and after: `git status --porcelain
--ignored`, a `find` of every file outside `.git`, and a `find -newer` against
a marker touched at the start. Scratch script, not committed.

- **All 24 suites exited 0, every summary line `..., 0 failed`.**
- **The tree was unchanged except for this story file**, which was being
  written during the run: the status diff, the file-list diff and the
  `-newer` list each name only `docs/backlog/stories/HARNESS-035.md`. Nothing
  appeared in `.claude/state`. So the static survey in `## Context` holds when
  measured: no suite writes the real tree, and no suite failed beside others.
  One run, which cannot rule out a rare race; DV-2 repeats the check through
  the real runner.
- **Timing, as a preliminary only** (not DV-2; glob-order start, no runner,
  the machine also running this session): wall **3,793 s** for all 24 at four
  jobs. The longest, `phase-guard`, took 3,325 s under that contention and was
  started 11th; `plan` 2,932 s, `gates` 1,484 s, `boundaries` 1,483 s,
  `sigpipe` 1,356 s. The sum of the per-suite times was 14,736 s, which is
  contention-inflated and is not a serial time. The last measured serial run
  on this host was 6,135 s (2026-10-02, audit `## Evidence`), so four jobs may
  save something like a third here; DV-2 measures it properly, back to back.
  With `phase-guard` as the critical path, a start order that puts it first
  is likely to matter more than the job count (C-2 leaves that to GREEN).

**Decision from the probe:** suites are write-isolated as far as can be
measured, so `SELFTEST_JOBS` above 1 is not refused and no suite is
serialised.
