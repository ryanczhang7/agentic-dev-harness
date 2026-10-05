---
id: HARNESS-034
title: A run lock stops the self-test and gates overlapping
slug: a-run-lock-stops-the-self-test-and-gates
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-034-a-run-lock-stops-the-self-test-and-gates
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/run-lock.sh, scripts/gates.sh, scripts/selftest.sh, .claude/tests/run-lock.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/tests/sigpipe.test.sh, .claude/state/README.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

This story is the first half of finding C + MT-042, group 6 ("Process"), in
`docs/wiki/audits/manga-translator-port-2026-10-02.md` (GitHub issue #97). The
audit's `## Decided` item 6 C is settled and is not reopened here: **a run lock
so `selftest.sh` and `gates.sh` cannot run on top of each other (stale-lock
reclaim by pid), then opt-in concurrent suites (`SELFTEST_JOBS`, default 1
locally) with per-run buffers.** Those are two behaviours and two RED->GREEN
cycles. This story is the lock. The concurrency is the follow-up (see
`## Out of scope`), and it is ordered second for the reason the audit gives
under "What would have to be true": concurrent suites are safe only while no
suite writes shared state, and "the lock in item 6 is what makes two *runs*
safe".

**The field evidence (issue #97, finding C, and the audit's own).** In
manga-translator, `selftest.sh` run beside `gates.sh` in one worktree hung in
`phase-guard.test.sh` for over 30 minutes; another such run had `coverage-core`
fail 93 times with `E_OUTOFMEMORY`. Each passed alone. Upstream, on 2026-10-02,
a full selftest stalled past 60 minutes beside an orphaned selftest and passed
alone in 6,135 s. `advance-story.md:196-212` already tells the orchestrator to
"run nothing else in this worktree until it exits: not `gates.sh`, not a second
self-test". That is prose; nothing enforces it. This story makes the second run
refuse.

**Downstream is not a source for this half.** `053c58e` (MT-042) in
manga-translator adds concurrency only - `SELFTEST_JOBS`, per-suite buffers
under `.claude/state/selftest/` - and no lock of any kind (read at PLANNED:
`git -C /d/manga-translator show 053c58e -- scripts/selftest.sh`). The lock is
designed here.

**Verified at PLANNED against this tree (release 76, `4d4ea68`):**

- `scripts/gates.sh:226-233` is HARNESS-030's `mutate.sh --check` refusal: it
  runs only when neither `--list` nor `--audit` is given, before any gate, and
  exits 2 ("nothing ran"). Its comment says "Detection, not a lock: nothing
  here waits". `:235` starts `table_lookup`. No gate command runs before
  `:543` (`( cd "$ROOT/$cwd" && eval "$cmd" ) 2>&1 | tee "$log"`). Nothing
  above `:233` writes anything but `mkdir -p "$LOGDIR"` (`:72`).
- `.claude/tests/sigpipe.test.sh:567-568` pin two `gates.sh` lines in C-5:
  `scripts/gates.sh:74:BOOTSTRAPPED="$(grep` and
  `scripts/gates.sh:563:why="could not launch: $(`. Inserting below `:233`
  leaves `:74` where it is and moves `:563`. `gates.sh -h` prints
  `sed -n '2,42p' "$0"`, so the header must not grow either.
- `scripts/selftest.sh:254-259` reports floors faults and exits 1 before any
  suite runs; `:261` is `# --- run ---`; `:272` runs each suite as
  `out="$(bash "$suite" 2>&1)"`. It has no trap and sources nothing.
- `scripts/ci-local.sh:178-188` runs each CI step with `eval "$cmd"`, in
  sequence: `bash scripts/selftest.sh` exits before `bash scripts/gates.sh`
  starts. So a lock taken and released by each script needs no change to
  `ci-local.sh`.
- **Nested runs.** No suite in `.claude/tests/` runs the real tree's
  `gates.sh` or `selftest.sh`: every run is a fixture copy, made by
  `make_project_fixture` (`_lib.sh:123-131`, `cp -r "$REPO_ROOT/scripts"`), and
  both scripts derive `ROOT` from their own path (`gates.sh:48`,
  `selftest.sh:62`). So a lock keyed to `$ROOT/.claude/state` already cannot
  deadlock a fixture on the outer run's lock. What keying alone does NOT cover
  is a run nested in the SAME tree - a gate command that calls
  `bash scripts/selftest.sh` - which would be refused by its own parent. No
  upstream gate does that today (`project.conf` is unbootstrapped; no
  stack profile's command calls either script), but a consuming project's
  could, and the failure would read as a gate failure. The env marker in C-4
  covers it, compared against the tree's own lock path exactly as
  `HARNESS_MUTATION` is compared against the tree's own `mutations/`
  (`gates.sh:897-898`), because every fixture inherits the outer run's
  environment.
- **`mutate.sh`** runs its command as `( cd "$ROOT" && HARNESS_MUTATION=...
  "${CMD[@]}" )` (`mutate.sh:462`) and takes no lock itself. So
  `mutate.sh F 'E' -- bash scripts/gates.sh --gate X` (or `-- bash
  scripts/selftest.sh X`) takes the lock in the inner script when no run holds
  it, and is refused with exit 2 when one does.
- **Every uncontended run must print nothing new.** `gates.test.sh:1064-1066`
  holds byte-identical goldens of whole `gates.sh` runs, and
  `selftest.test.sh` compares whole output lines. The lock speaks only when it
  refuses or reclaims.
- **The primitives, measured on both platforms at PLANNED** (scratch scripts,
  not committed):
  - MSYS (Git Bash 5.3.15, `MINGW64_NT-10.0-26200`): `kill -0 $$` is 0; `kill
    -0` on an exited child's pid is 1; on a bogus pid is 1; on a background
    `sleep`'s pid **from a separate shell** is 0, then 1 once it is killed. A
    native Windows pid (from `powershell.exe`'s `$PID`, exited) is 1. `ln a b`
    (hard link, no `-f`) onto an existing `b` fails with `File exists`, rc 1.
  - Linux (WSL Ubuntu 24.04, bash 5.2.21): the same `kill -0` results for self,
    an exited child and a live child. `kill -0 1` (root-owned) is **1** -
    EPERM reads as "not running". Same `ln` behaviour.
  - Both: a script with an `EXIT` trap and `trap 'exit 143' TERM`, sent TERM
    while its foreground child runs, waits for the child, runs the EXIT trap and
    exits 143. Without the TERM trap both platforms ran the EXIT trap too, but
    exited at once and left the child running - an orphan, which is finding
    C's other half. Hence C-3's explicit traps.

**The required gate that fails if this breaks:** `selftest`, through the new
`run-lock.test.sh`. No optional gate is involved; `required_gates` stays empty.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

Every criterion is observed in a throwaway fixture tree built by
`make_project_fixture` (real `scripts/` and hooks copied in), never in this
checkout, except AC-7's real-tree facts. "The holder" is a first run whose
gate command or suite is **blocked** on a release file the test creates, so
"in progress" is a state the test controls rather than a race it hopes to win.
"The lock" is `<tree>/.claude/state/run.lock`. The output lines are pinned
byte for byte in C-2 and compared as whole lines.

- **AC-1 (the field case, both directions)** — Given the holder is
  `bash scripts/gates.sh --gate unit` in progress, when
  `bash scripts/selftest.sh <suite>` is started in the same tree, then it
  exits **2**, runs no suite (the suite's own marker file is absent), and its
  output carries C-2's three refusal lines naming the holder's pid and the
  command `scripts/gates.sh --gate unit`. Given the holder is
  `bash scripts/selftest.sh slow` in progress, when `bash scripts/gates.sh
  --gate unit` is started, then it exits **2**, the gate command never runs
  (its marker file is absent), `.claude/state/last-gate-run` is not created or
  changed, and the refusal names `scripts/selftest.sh slow`. In both
  directions the lock file is byte-identical before and after the refused
  attempt, the holder then finishes with its own normal status (0), and the
  same second command, run again after the holder exits, runs and exits 0.
  *Control:* today the second command runs to completion while the holder is
  still blocked - RED observes exactly that.
- **AC-2 (every way out releases)** — After `gates.sh --gate unit` exits 0
  (gate passes), exits 1 (gate fails), and exits **143** after being sent
  TERM while its gate command runs (the gate command is let finish first), and
  after `selftest.sh <suite>` exits 0 and exits 1 (a failing suite), neither
  `.claude/state/run.lock` nor any `.claude/state/run.lock.*` exists. An
  uncontended run prints no line beginning `run-lock:`, and
  `gates.test.sh`'s byte-identical goldens stay green.
- **AC-3 (stale-lock reclaim by pid)** — Given a lock whose recorded pid is
  a process that has already exited, when `gates.sh --gate unit` runs, then it
  prints C-2's reclaim line exactly once, runs the gate, exits 0, and leaves no
  lock. Given a lock with no numeric `pid` line, the run prints C-2's
  unreadable-lock line and proceeds the same way. The same holds for
  `selftest.sh <suite>`. *Control:* the same lock file with the pid of a live
  process (a background `sleep` the test owns) is refused as in AC-1 - which
  is what tells reclaim-by-pid apart from ignoring the lock.
- **AC-4 (manifest-only modes are not gated)** — While a live lock is held,
  `gates.sh --list`, `gates.sh --audit` and `gates.sh --help` each produce
  output and an exit status identical to the same command with no lock
  present, and the lock file is byte-identical afterwards.
- **AC-5 (keyed to the tree)** — Given a live lock held in tree A, a
  `gates.sh --gate unit` in a separate tree B runs, exits 0 and prints no
  `run-lock:` line. And with `HARNESS_RUN_LOCK` and `HARNESS_RUN_LOCK_PID`
  naming tree A's lock and its live holder exported into that run, B still
  takes its own lock (B's gate command observes `B/.claude/state/run.lock`
  existing while it runs) and leaves none behind - so a fixture run by a suite
  never takes the outer run's lock for its own, nor is refused by it.
- **AC-6 (a run nested in the same tree)** — Given a gate whose command is
  `bash scripts/selftest.sh tiny`, `gates.sh --gate unit` in the same tree
  reports that gate PASS, exits 0, and leaves no lock. *Control:* the same gate
  with the command `env -u HARNESS_RUN_LOCK -u HARNESS_RUN_LOCK_PID bash
  scripts/selftest.sh tiny` FAILs, and its gate log carries C-2's first
  refusal line naming `scripts/gates.sh --gate unit` - which shows both that
  the lock really is held during the gate and that the marker is what lets the
  child through. And a marker naming the right lock path but a pid other than
  the one recorded in the lock is refused, so the path alone is not a bypass.
- **AC-7 (state and suite hygiene)** — `.claude/state/README.md` has a row
  for `run.lock` and one for `run.lock.<pid>`, each `yes` in the
  `Hand-editable` column, and `bash scripts/selftest.sh settings` passes.
  `git check-ignore -q --no-index .claude/state/run.lock` exits 0 in this
  repository. The new suite has a floor in `floors.conf` and a row in
  `selftest.test.sh`'s `COUNTS`, both equal to its total assertion count at the
  end of RED. `sigpipe.test.sh`'s C-5 pin on `scripts/gates.sh` names the line
  where `why="could not launch: $(` now is, its pin on `scripts/gates.sh:74`
  is unchanged, and its freshness assertion stays green.
  `bash scripts/check-sigpipe.sh` and `bash scripts/check-grep-count.sh` stay
  clean over the tree, and a full `bash scripts/selftest.sh` passes.

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

**Writes:** `scripts/run-lock.sh`, `scripts/gates.sh`, `scripts/selftest.sh`, `.claude/tests/run-lock.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/state/README.md`

**RED may amend any block below in place, with a reason. GREEN builds what the
amended block says.**

**The phase lock enforces nothing here.** At PLANNED, `bash scripts/classify.sh`
returned `harness` for `.claude/state/run.lock`; `scripts/*`, `.claude/tests/*`
and `.claude/hooks/*` all classify as `harness` (`plan.sh:87`). So the split is
held by discipline, as in HARNESS-030, -032 and -033:

- **RED** writes only `.claude/tests/run-lock.test.sh` and the two `run-lock`
  floor lines (`floors.conf`, `selftest.test.sh` `COUNTS`).
- **GREEN** writes `scripts/run-lock.sh`, `scripts/gates.sh`,
  `scripts/selftest.sh`, `.claude/state/README.md`, and the one line pin in
  `sigpipe.test.sh` C-5 (`scripts/gates.sh:563:...`). The pin is a fixture
  that tracks where a source line sits, not an assertion; HARNESS-030 and -033
  gave the same pin update to GREEN.

### C-1 Where the lock lives, and who takes it

- **The file:** `$ROOT/.claude/state/run.lock`, where `$ROOT` is the running
  script's own root - `gates.sh:48` and `selftest.sh:62` as they are today -
  never `$PWD` and never `$CLAUDE_PROJECT_DIR`. One lock per tree, so one per
  worktree, as `current-story.env` already is.
- **The format:** three TAB-separated `key<TAB>value` lines, the convention of
  `mutate.sh`'s `.active` sentinel (`mutate.sh:124-133`):

  ```
  pid<TAB><the taking script's $$>
  started<TAB><date -u +%Y-%m-%dT%H:%M:%SZ>
  command<TAB><command>
  ```

  `<command>` is `scripts/gates.sh` or `scripts/selftest.sh`, followed by a
  space and `"$*"` when arguments were given (so `scripts/selftest.sh` alone,
  `scripts/selftest.sh slow`, `scripts/gates.sh --gate unit`). Literal script
  paths, not `$0`, which may be absolute.
- **Atomic creation, never visible half-written.** Write the three lines to
  `$ROOT/.claude/state/run.lock.$$`, then `ln` (a hard link, no `-f`) it to
  `run.lock`, then remove `run.lock.$$` whatever `ln` returned. `ln` fails when
  `run.lock` exists, on MSYS and Linux alike (measured, `## Context`), so
  exactly one contender wins and the winner's record is complete before anyone
  can read it. `mkdir -p "$ROOT/.claude/state"` first.
- **Who takes it.**
  - `gates.sh`: every invocation that reaches the gates - a full run,
    `--story`, `--gate`, `--fast`, `--required`. Not `--list`, `--audit` or
    `--help` (AC-4), which read the manifest and must keep working while a run
    is in flight (CI and `ci-local.sh` run both). Placed immediately after the
    `mutate.sh --check` block, i.e. **inserted after the current line 233**,
    before `table_lookup` (`:235`) and therefore before any gate command.
    Nothing may be added above line 74, header comments included: `gates.sh:74`
    is pinned by `sigpipe.test.sh:567`, and `-h` prints lines 2-42. The
    explanation of the lock goes beside the inserted block.
  - `selftest.sh`: every invocation, full or single-suite, **inserted between
    the floors-fault block (ends `:259`) and `# --- run ---` (`:261`)**, so a
    malformed floors file is still reported at once without contending for
    anything.
- **Refuse, never wait.** A held lock is a refusal with exit 2, the code both
  scripts' neighbours use for "nothing ran" (`gates.sh:231`). Waiting is what
  turned finding C into an hour-long stall; `mutate.sh:102-104` records the
  same judgement ("a lock the harness can deadlock against its own subagent is
  worse than the race") and a refusal cannot deadlock.

### C-2 What it prints (stderr), byte for byte

Nothing at all on an uncontended take or release (AC-2; the `gates.test.sh`
goldens depend on it). Otherwise, with `<self>` this run's own `<command>`
string and `<pid>`, `<started>`, `<command>` read from the lock:

Refusal, three lines, then exit 2:

```
run-lock: refusing to start <self>: another harness run holds this worktree's lock.
run-lock:   pid <pid>, started <started>: <command>
run-lock: wait for it to finish. If pid <pid> is not that run, delete .claude/state/run.lock and run again.
```

Stale lock, one line, then the run proceeds:

```
run-lock: reclaimed a stale lock from pid <pid> (<command>); that process is no longer running.
```

Unreadable lock (no `pid` line, or one that is not all digits), one line, then
the run proceeds:

```
run-lock: reclaimed an unreadable lock (no pid recorded in .claude/state/run.lock).
```

The lock cannot be created for any reason other than another holder (the state
directory unwritable, `ln` unsupported), one line, exit 2:

```
run-lock: cannot create .claude/state/run.lock; nothing was run.
```

That last message is not an AC - it needs a broken filesystem to reach - but
it is the fail-closed direction, and a GREEN that silently runs unlocked when
`ln` fails would be the defect this story removes.

### C-3 `scripts/run-lock.sh`, a sourced library

New file, sourced by both scripts with
`. "$ROOT/scripts/run-lock.sh" || { printf 'run-lock: scripts/run-lock.sh is missing; nothing was run.\n' >&2; exit 2; }`.
Under `scripts/` and named `*.sh` because `refresh-harness.sh` replaces
`scripts/*.sh` and no subdirectory of it (`refresh-harness.sh:407-413`): a
library anywhere else would not ship with the scripts that need it.
`selftest.sh` deliberately does not take on `.claude/hooks/lib.sh`, whose
contract is "fail open" - the wrong one for a lock - and whose
`HARNESS_ROOT` defaults from `CLAUDE_PROJECT_DIR`. Bash 3.2: no `wait -n`, no
associative arrays, no `${var,,}`, no `mapfile`, no GNU-only `sed -i`; `lib.test.sh:266-270` greps
every `scripts/*.sh` for the last two. Bash, awk and coreutils
only (`rules.md`, Portability).

```
run_lock_alive <pid>              # 0 if <pid> is running; one line, exactly:
run_lock_alive() { kill -0 "$1" 2>/dev/null; }
run_lock_acquire <root> <command> # 0: this process may run (it took the lock,
                                  #    or it is nested under the holder, C-4);
                                  # 2: refused or cannot create, message printed
run_lock_release                  # removes the lock iff THIS process took it
                                  # and its pid line is still $$; never fails
```

`run_lock_alive` is one line, exactly as above, because DV-1's single `sed`
expression targets it. It errs the cautious way, as `mutate.sh --check` notes
(`mutate.sh:106-107`): a recycled pid reads RUNNING (a refusal the message
tells you how to clear), a live process never reads GONE - except one owned by
another user, where EPERM reads as gone (measured, `## Context`; see
`## Out of scope`).

Acquire, in order: (1) the C-4 nested check; (2) `ln` the temp record into
place - success: export the C-4 markers, set the held flag, return 0; (3) on
failure, if `run.lock` exists and its pid is alive, print the refusal and
return 2; (4) if it exists and its pid is dead or unreadable, print the reclaim
line, remove it, and try `ln` exactly once more - a second failure means a
contender won the race, and is a refusal naming the new holder; (5) if
`run.lock` does not exist after a failed `ln`, print the cannot-create line and
return 2.

**Traps, in both scripts, installed immediately BEFORE acquire:**

```
trap run_lock_release EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
```

Before, so a signal between taking and trapping cannot strand a lock; release
is a no-op when nothing was taken. The INT and TERM traps are explicit
because, measured on both platforms, an untrapped TERM exits at once and
leaves the foreground child running; trapped, bash waits for the child, so the
lock is held for exactly as long as the work is. Neither script has a trap
today (`grep -n trap` at PLANNED found none), so none is displaced.

### C-4 A run nested in the same tree

On taking the lock, export `HARNESS_RUN_LOCK=<absolute path of run.lock>` and
`HARNESS_RUN_LOCK_PID=$$`. At the start of acquire, a process may proceed
**without** taking, releasing or printing anything when all four hold:
`$HARNESS_RUN_LOCK` equals its own lock path, `run.lock` exists, its `pid` line
equals `$HARNESS_RUN_LOCK_PID`, and that pid is alive. Otherwise the markers
are ignored and acquire proceeds normally. The path comparison is what keeps a
fixture run under an outer real run from adopting the outer lock (AC-5); the
pid comparison is what keeps a stale or hand-set variable from being a bypass
(AC-6). The refusal message never mentions the variables.

**`run-lock.test.sh` runs under the real `selftest.sh`, which exports both
markers into it.** Every fixture run the suite makes therefore inherits them,
which is exactly AC-5's situation; cases that are about the markers set them
explicitly, and no case may depend on their being absent.

### C-5 The suite

`.claude/tests/run-lock.test.sh`, sourcing `_lib.sh`, ending
`summary "run-lock"`. One `make_project_fixture` tree (two for AC-5), with
`write_conf` gates whose commands are `printf`s and file tests. The holder:

- a gate command, or a suite in the fixture's `.claude/tests/`, that touches a
  `started` marker and then waits for a `release` file the test creates,
  bounded (e.g. 120 s) so a defect cannot hang the suite;
- started by **backgrounding the script itself** - `cd "$FIX"` in the test,
  then `bash scripts/gates.sh --gate unit &` - not `( cd ... && bash ... ) &`,
  so that `$!` is the script's pid, which is what the lock records and what
  AC-2's TERM must reach;
- the test polls for `started` (bounded) before starting the second run, and
  `wait`s the holder for its exit status after creating `release`.

The fixture needs `.claude/tests/_lib.sh` copied in (as `selftest.test.sh:48`
does) and a `floors.conf` naming its suites, so the fixture's `selftest.sh`
passes its own floors audit. A dead pid for AC-3 is a background
`bash -c 'exit 0'` that has been `wait`ed. Every background process the suite
starts is killed and waited on an `EXIT` trap.

**The floor.** `floors.conf` and `selftest.test.sh` `COUNTS` (alphabetical,
between `reporting` and `selftest`) record the suite's TOTAL assertion count
at the end of RED - passed plus failed, which is what it will pass when green
(HARNESS-033 recorded 101 = 90 + 11 the same way).

### C-6 Oracle partition

- **Settled - read out, do not re-decide:** that there is a lock, that it is
  per tree, that a stale one is reclaimed by pid (audit `## Decided` 6 C);
  refuse-not-wait, exit 2, the file and its format, the messages (this
  contract).
- **Mechanical - pin exactly:** every AC. The messages are compared as whole
  lines (`grep -cxF` or equivalent), because `run-lock: reclaimed ...` and
  `run-lock: refusing ...` share a prefix, and a needle of `run-lock:` alone
  would be satisfied by the wrong one (`rules.md`, "An assertion's needle").
  Exit statuses are compared exactly: 2, not "non-zero" - a crash is non-zero
  too.
- **Oracle-free:** none.

### C-7 Callers

No existing function signature changes. The CLIs of `gates.sh` and
`selftest.sh` gain one outcome, exit 2 with the C-2 refusal; `selftest.sh` has
never exited 2 before. Its callers treat any non-zero as failure:
`ci-local.sh:181` (`if ! eval "$cmd"`), the CI steps in
`.github/workflows/gates.yml` (`bash scripts/selftest.sh`), and
`mutate.sh:462`, which reports its command's status. None needs a change.

### C-8 `.claude/state/README.md`

Two rows, `Hand-editable` **yes**, because deleting the lock is the printed
remedy and a deny rule would also block that `rm` (the reasoning of the
`mutations/*.active` row):

```
| `run.lock` | `scripts/gates.sh`, `scripts/selftest.sh` | `scripts/run-lock.sh`, in the next run | yes |
| `run.lock.<pid>` | `scripts/run-lock.sh` | `ln`, while it takes the lock | yes |
```

and a short paragraph under "The exhaust": what a leftover `run.lock` means
(a run was SIGKILLed or its machine went away; the next run reclaims it if the
pid is gone, and refuses if a recycled pid is alive) and that a leftover
`run.lock.<pid>` is safe to delete. No `settings.json` change: `yes` rows
carry no deny rules, and `settings.test.sh` checks that both ways.
`.gitignore`'s `.claude/state/*` already ignores both (AC-7 asserts it).

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

This story adds no rule over the tree (it is a runtime lock, not a guard that
reads the tree's contents) and adds or changes no gate, so it owes no
real-tree probe and no `## Gate probes`. The budget is `rules.md`'s default:
one "defect put back" entry, DV-1. DV-2 is one more, for a stated reason.

**DV-1 (defect put back).** Owner: GATES. Make every holder look dead, which
is the defect itself - a second run proceeds on top of a live first one, the
lock reclaimed out from under it. C-3 pins `run_lock_alive` to one line so
that this one expression matches it (checked at PLANNED against that exact
line with Git Bash's sed and GNU sed on Linux: both print
`run_lock_alive() { false; }`). Run detached (`nohup`), so a tool limit cannot
kill it mid-mutation:

```
bash scripts/mutate.sh scripts/run-lock.sh 's|kill -0 "\$1" 2>/dev/null|false|' -- bash scripts/selftest.sh run-lock
```

**Must** fail: AC-1's refusal assertions in both directions (exit 2, the three
lines, the absent marker), AC-3's live-pid control, and AC-6's
wrong-pid-marker refusal. **Must stay green:** AC-3's two reclaim cases - a
dead pid is still reclaimed - which is what shows the mutation hit liveness
and not the lock as a whole. Other assertions may move either way; record the
counts. RED cannot run this: there is no `run-lock.sh` to mutate. Paste the
`mutate.sh` output, including its verified restore, and a green re-run of
`bash scripts/selftest.sh run-lock`.

**DV-2 (the field scenario, in the real tree).** Owner: GATES, during
GATES -> REVIEW step 1 while the full `bash scripts/selftest.sh` runs detached
in this worktree. Run once:

```
bash scripts/gates.sh --gate unit; echo "rc=$?"
```

It **must** print C-2's three refusal lines naming `scripts/selftest.sh` and
the self-test's pid, and `rc=2`. After the self-test exits,
`ls .claude/state/run.lock*` **must** find nothing. Why beyond the default
budget: every suite assertion runs against a fixture copy, so this is the only
check that the real tree's `gates.sh` sources the real tree's `run-lock.sh`
and refuses beside the real self-test - which is finding C's exact situation -
and it costs one command that exits in seconds, beside a run step 1 makes
anyway. RED cannot run it: nothing exists to refuse.

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

Planned by `bash scripts/plan.sh write HARNESS-034` from `.claude/harness/models.conf`.
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

**Oracle partition for the RED brief:** `## Contract` C-6. In short: the lock's
existence, per-tree keying and pid reclaim are settled (audit `## Decided`
6 C); refuse-not-wait, exit 2, the file, its format and the four messages are
settled by this contract; every AC is mechanical and pinned as whole lines and
exact statuses; nothing is oracle-free.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **MT-042, `SELFTEST_JOBS` - the follow-up story (HARNESS-035, to be planned
  when this one closes).** Concurrent suites within ONE self-test run, opt-in,
  `SELFTEST_JOBS` defaulting to **1** locally (the audit's decision; downstream
  `053c58e` defaults to 4, which is not to be copied), with per-run output
  buffers. Downstream put its buffers at `.claude/state/selftest/<name>.out`,
  one shared directory per tree; two runs would collide there, so the
  follow-up keys them per run, and the lock this story adds is what makes a
  second run in the same tree impossible in the first place. That story will
  need its own `.claude/state` rows, `selftest.test.sh` assertions (and a
  raised `selftest` floor), and the lock to hold across all of a run's
  concurrent suites - which this story's design already gives it, since the
  lock is taken once per `selftest.sh` process. Do not start any of it here.
- **`mutate.sh` taking or checking the lock.** It runs its command under the
  lock the inner script takes (C-7), but it mutates the file BEFORE running
  that command, so a mutation started while a full `gates.sh` holds the lock
  still changes the tree under that run. `gates.sh`'s `--check` (HARNESS-030)
  catches only a mutation present when the run STARTS. A candidate follow-up;
  record it if the GATES orchestrator meets it.
- **`ci-local.sh` holding the lock across its steps.** Each step's script takes
  and releases its own; nothing stops another run slipping in between steps.
  C-4's marker would make that change small, but it is not this story.
- **Waiting, queueing, `--wait`, a timeout.** Refusal only (C-1).
- **Orphans after SIGKILL.** The lock records one pid. SIGKILL of `gates.sh`
  or `selftest.sh` leaves its child (a gate command, a suite) running, the
  pid dead, and the next run reclaims the lock beside the orphan. Killing a
  process group is platform-specific on MSYS and not attempted. TERM and INT
  are handled (C-3).
- **A holder owned by another user, or started under another MSYS runtime.**
  `kill -0` returns EPERM-as-failure for another user's process on Linux
  (measured: `kill -0 1` is 1), and an MSYS pid is visible only to processes
  of the same MSYS installation. Either makes a live holder look stale. One
  worktree, one user, one Git Bash is the case this harness supports.
- **The reclaim race.** Two runs that both find the same stale lock in the
  same instant can each remove it; C-3's single retry narrows the window but
  does not close it. Not worth a second mechanism for a lock whose job is to
  stop a person or an agent starting a second run by hand.
- **Prose elsewhere.** `advance-story.md:196-212` and `complete-story.md:27`
  already say "run nothing else in this worktree"; they stay true and are not
  edited (`procedure.test.sh` pins their text). `CLAUDE.md`, `rules.md`'s list
  of state files and `doctor.sh` are not touched; `.claude/state/README.md` is
  the table `settings.test.sh` reads, and the only doc this story must change.
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


**PLANNED, 2026-10-05 (lead-po).** Split: finding C + MT-042 is two
behaviours - "a second run refuses" and "one run's suites run concurrently" -
each its own RED->GREEN cycle with its own suite changes, so it is two stories.
This is the first; `SELFTEST_JOBS` is recorded in `## Out of scope` as the
follow-up. Left uncommitted at PLANNED: the orchestrator creates
`story/HARNESS-034-a-run-lock-stops-the-self-test-and-gates` and commits the
story there at PLANNED, which is the criteria baseline (HARNESS-033).

Decisions this plan took that the audit did not, each open to RED amending the
contract and to the user overruling:

- **Refuse, not wait** (C-1). The audit says only "cannot run on top of each
  other". Waiting is what made finding C an hour-long stall, and
  `mutate.sh:102-104` already argues against a harness lock that can block.
- **Single-suite self-test runs take the lock too.** Finding C's first case was
  a suite hanging beside `gates.sh`; a named suite is no safer than the full
  run. The cost is that an agent cannot run two named suites at once in one
  worktree.
- **The same-tree nested marker (C-4, AC-6).** Root keying alone is enough for
  every fixture in this tree (verified: no suite runs the real tree's scripts).
  The marker exists for a consuming project's gate that calls `selftest.sh`;
  without it that gate would fail on its own parent's lock. It costs one AC.
- **A new sourced `scripts/run-lock.sh`** rather than `lib.sh` or two copies.
  `refresh-harness.sh` ships `scripts/*.sh`, and `selftest.sh` stays free of
  the hook library's fail-open contract.
