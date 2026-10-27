---
id: HARNESS-078
title: The covers check sees every changed path by its real name, and selftest-needed answers in one line
slug: the-covers-check-sees-every-changed-path
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-078-the-covers-check-sees-every-changed-path
depends_on: [HARNESS-077]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, scripts/selftest-needed.sh, scripts/host-load.sh, .claude/tests/gates.test.sh, .claude/tests/selftest-needed.test.sh, .claude/tests/floors.conf]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Four known defects recorded, and deliberately not fixed, in the `## Notes` of
HARNESS-075 (diff review finding 4, and HARNESS-077's second review finding 4),
HARNESS-076 (diff review Nice to have 1) and HARNESS-077 (diff review Nice to
haves 1-2). Two are behaviour, two are comments that overclaim:

1. **`gates.sh`'s `covers` check drops a changed path whose name git quotes.**
   The changed-path enumeration (`scripts/gates.sh:991-992` on `c124456`) runs
   `git diff --name-only` and `git ls-files --others` under the default
   `core.quotePath=true`, so a non-ASCII name prints C-quoted:
   `"src/render/caf\303\251.ts"`. Reproduced by the PO on this host
   (2026-10-27): `classify_stdin` calls that quoted string `source`, and the
   loop's next line, `[ -e "$ROOT/$path" ]`, finds no such file and skips it as
   *deleted*. So a non-ASCII source file that only an optional gate reads
   produces no FAIL, one that no gate claims produces no WARN, and the run
   prints `All required gates passed` over it. `core.quotePath=false` would not
   be enough: git still C-quotes `"`, `\` and a tab in either mode. NUL-separated
   output (`-z`) is the fix, because it is the one mode in which git never
   quotes.
2. **`selftest-needed.sh:64`'s real `. "$LIB"` does not redirect stdout.** The
   probe on `:63` discards stdout; the real source does not, so a `lib.sh` that
   prints while loading adds a line to an answer whose contract is exactly one
   line, and the line a caller reads first is the library's, not the verdict.
   Today's `lib.sh` prints nothing on load, so the defect is latent.
3. **`host-load.sh`'s "Known limits" sentence** says a row whose UID holds a
   space is skipped by the all-digits test. Only when the account's second word
   is not a number: `Ryan 123` passes the test and the row is read with PID 123
   and the command from the STIME field. It is not reported either way, so the
   sentence's conclusion stands and its mechanism does not. Comment only.
4. **`selftest-needed.sh:59-61`** says an `exit` in the sourced file cannot end
   the script after the probe. False for a top-level `exit 0`: the probe's
   subshell exits 0, the real source then ends the script with rc 0, which is
   `run` with no line. Comment only.

The required gate that would fail if this story's artifact broke: `unit`
(`bash scripts/selftest.sh`), which runs `gates.test.sh` and
`selftest-needed.test.sh`. No optional gate is involved, so `required_gates`
stays empty.

## Acceptance criteria

- **AC-1** — Given an active story, `covers` lines under which `src/render/**`
  is read only by an `optional` gate, and an UNTRACKED `src/render/café.ts`,
  when `bash scripts/gates.sh` runs, then its output holds
  `FAIL         changes: src/render/café.ts is exercised only by optional gate(s): integration`
  with the name unquoted, and the run fails (`required gate(s) failed`).
  *Reproduces the bug:* today the quoted name is skipped as deleted and the run
  prints `All required gates passed`.
- **AC-2** — Given an active story and a COMMITTED (on the story branch, not on
  `main`) `src/shaders/café.glsl` that no `covers` line claims, when
  `bash scripts/gates.sh` runs, then its output holds
  `WARN         changes: src/shaders/café.glsl is exercised by no gate with a covers line`,
  unquoted. *Reproduces the bug* on the `git diff` half of the enumeration, as
  AC-1 does on the `git ls-files` half; today neither line appears.
- **AC-3** — Given the AC-1 set-up with the untracked file named
  `src/render/a"b.ts`, then `src/render/a\b.ts`, then `src/render/a<TAB>b.ts`,
  when `bash scripts/gates.sh` runs, then each run's FAIL line names the path
  byte-for-byte as the filesystem holds it. On a host where git cannot hold such
  a name (decision 3) the three cases are not run and the suite says so on
  stdout; on every other host, that the fixture holds the name is itself an
  assertion, so a host that should run them cannot quietly skip them.
  *This is the case that tells `-z` from `core.quotePath=false`:* AC-1 and AC-2
  pass under either.
- **AC-4** — Given a harness path changed on the story branch and a fixture
  `lib.sh` that prints a line to stdout while it is sourced, when
  `bash scripts/selftest-needed.sh` runs, then it exits 0 and its stdout is
  exactly ONE line, the pinned `selftest-needed: run — 1 harness path(s) changed
  against main (merge-base <short>): <path>` line, from the fixture root and
  from `src/`. *Reproduces the bug:* today stdout is two lines and the first is
  the library's.
- **AC-5** *(decision 1 - confirmed by the user, 2026-10-27)* — Given a
  harness path named `.claude/tests/a"b.test.sh`, then `a\b`, then `a<TAB>b`,
  changed on the story branch, when `bash scripts/selftest-needed.sh` runs, then
  it answers `run` (exit 0) naming that path byte-for-byte, under the same host
  rule as AC-3. *Reproduces the bug:* today the C-quoted name classifies
  `source` and the script answers `skip` (exit 1) - a wrong-way skip.

## Contract

RED may amend any block below, in place, with a reason; GREEN then builds what
the amended block says. The acceptance criteria above are frozen and change only
through `## Amendments`.

**Writes:** `scripts/gates.sh`, `scripts/selftest-needed.sh`, `scripts/host-load.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/selftest-needed.test.sh`, `.claude/tests/floors.conf`

### Oracle partition

All five criteria are **mechanical**: pin exactly, leave nothing open-ended.
The expected lines are **settled**, read out of today's message formats rather
than derived: the FAIL and WARN lines are the ones `gates.sh:1010` and `:1013`
already print and `gates.test.sh`'s `covers` block already asserts
(`gates.test.sh:428`, `:452`); the `run` line is the one HARNESS-075's Contract
pinned and `selftest-needed.test.sh`'s `expect` helper already compares whole.
There is no oracle-free criterion and no threshold, so no negative control on a
number. The controls are structural and already in the suites: the ASCII
`covers` cases (`mesh.ts`, `thing.ts`, `sky.glsl`) must stay green beside the
new ones, and AC-3/AC-5 are the control on the *choice of fix* (see AC-3).

### `scripts/gates.sh` - the changed-path enumeration

Today (`c124456`, lines 991-993):

    changed="$( { git -C "$ROOT" diff --name-only "$mb" 2>/dev/null
                  git -C "$ROOT" ls-files --others --exclude-standard 2>/dev/null; } \
                | sort -u | classify_stdin | awk -F'\t' '$1 == "source" { print $2 }')"

After: both git commands take `-z`, and the NUL-separated stream becomes one
path per line before `sort -u`, with `tr '\0' '\n'` (coreutils and BSD both
have it; no python, no `read -d ''` loop needed, because everything downstream
- `classify_stdin`, the `while read` over `$changed` - is line-based already).
The rest of the pipeline and the loop are unchanged. Keep it to the same three
lines plus, at most, a comment directly above them (next block); nothing above
line 965 moves.

**A name holding a newline is still broken after this, and the story does not
fix it.** `tr` turns its embedded newline into a record separator, the two
halves name no file, and the `-e` test drops both - unreported, exactly as the
C-quoted form is dropped today. Handling it would mean carrying NUL through
`classify_stdin`, which is line-based by contract across the harness. The
story records it as a known limit in a comment beside the enumeration:

    # -z: git C-quotes a non-ASCII name under the default core.quotePath, and
    # `"`, `\` and a tab under any setting; NUL-separated output is never
    # quoted (HARNESS-078). Known limit: a name holding a newline still splits
    # into two paths that name no file, and is dropped unreported.

### `sigpipe.test.sh` pins - checked against `c124456`, and not moved

The C-5 block's `DISCARDED` table (`.claude/tests/sigpipe.test.sh:574-585`)
pins two `gates.sh` lines, and its freshness assertion (`:604`) fails if either
moves:

    scripts/gates.sh:82:BOOTSTRAPPED="$(grep
    scripts/gates.sh:734:why="could not launch: $(

Today line 82 is `BOOTSTRAPPED="$(grep -E '^BOOTSTRAPPED=' "$CONF" | head -1)"`
and line 734 is `why="could not launch: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"`.
Both are above the enumeration (991), so an edit confined to the block above
shifts neither, and **this story does not change `sigpipe.test.sh`** - the
brief's assumption that it would was checked and is false. The same holds for
every other `gates.sh:<n>` reference in the suites (`sigpipe.test.sh:996`
`:432` and `:1016` `:428`, prose in comments; `gates.test.sh:2036` `:331`,
`:2737` `:233`; `selftest.test.sh:204` `:112`; `floors.conf:500` `:640`): all
below 991, none moved. If GREEN finds it must add a line above 734 after all,
that is a write RED owns - stop and return to RED to update the two pins; do
not edit the test in GREEN. `selftest-needed.sh` and `host-load.sh` have no
line pins anywhere (`grep -rnoE '(selftest-needed|host-load)\.sh:[0-9]+'` over
`.claude/tests` and `scripts` finds none).

### `scripts/selftest-needed.sh`

- **`:64`** becomes `. "$LIB" >/dev/null`. Stderr stays connected, as on the
  probe line, so a library that errors still shows its error.
- **`:59-61`** comment becomes:

      # Probe first: a `set -u` trip or a non-zero `exit` in a sourced file ends
      # the whole script, so it is sourced in a subshell (stderr kept, so the
      # error is seen) before the real source, which then cannot fail that way.
      # Both discard stdout: the answer is one line, and a library that prints
      # on load must not add one.

- **AC-5 (decision 1):** `:85` and `:87` take `-z`, each piped through
  `tr '\0' '\n'` inside its own command substitution, so the `|| fallback` on
  each still fires when git fails (`set -o pipefail` is on, `:33`).
  `-c core.quotePath=false` becomes redundant; GREEN may drop it. The comment
  on `:83-84` and the header's "Deliberate differences" sentence (`:22-26`,
  "a non-ASCII name is listed unquoted (`core.quotePath=false`)") are updated
  to say both scripts now read NUL-separated output, and the header's "Known
  limit" (`:29-31`) is replaced by the newline limit in the `gates.sh` wording.
  If the user declines decision 1 before RED: delete AC-5 and this bullet, and
  `:29-31` stays as it is.

### `scripts/host-load.sh` - header comment only (`:32-34`)

    # Known limits, not handled: a row whose UID holds a space moves PID out of
    # its field and is skipped, or read with the wrong PID and command; either
    # way it is not reported. Bash 3.2, awk and coreutils only.

No code change, no test. `host-load.test.sh` does not read the header.

### The tests

- **AC-1, AC-2, AC-3** go in `.claude/tests/gates.test.sh`, inside or directly
  after its `describe "covers: ..."` block (`:387`), reusing its fixture
  (`$FIX`, the `story`/`set_phase`/`write_conf`/`gates` helpers, the
  `unit`+`integration` conf at `:416-425`). Each case removes its file after
  itself, as the block's existing cases do, so the cases after it see the
  diff they expect. Names are written with `printf`, never with `sed -i`.
- **AC-4, AC-5** go in `.claude/tests/selftest-needed.test.sh`. AC-4's fixture
  `lib.sh` is the HARNESS-077 AC-1 pattern (`:356-358`): the fixture's COPY
  rewritten with `awk` to insert one `printf 'lib loaded\n'` (or `echo`) line
  as its line 2, with a precondition that sourcing it prints that line. It
  runs through `expect`, which already asserts exit, the whole first line and
  `stdout is exactly one line`, from root and `src/`.
- **The host rule (decision 3)** for AC-3 and AC-5: when `uname -s` matches
  `MINGW*|MSYS*|CYGWIN*`, the cases are not run and the suite prints one
  stdout line naming the cases and the reason (Git Bash maps `"` and a tab to
  private-use code points - `a"b.ts` reaches git as `a\357\200\242b.ts` - and
  cannot create `\` at all; measured by the PO on this host, 2026-10-27).
  On any other host the precondition - `git ls-files -z --others` lists the
  name byte-for-byte - is an `assert_eq`, so a Linux host cannot skip them.
  A skip is never counted as a pass.
- **Floors.** Adding assertions does not oblige a floor change
  (`floors.conf` header). If RED raises the `gates` (682) or
  `selftest-needed` (216) floor, it raises it to the count a Windows host
  executes - the count every host reaches - and says in the comment that a
  POSIX host executes the AC-3/AC-5 assertions on top.
- **No test-only dependencies.**
- **No signature changes.** No exported function changes shape; `classify_stdin`
  is called the same way.

## Deferred verifications

- **DV-1 - the defect put back (central claim, AC-1/AC-2).** With `-z` removed
  from both enumeration commands in `scripts/gates.sh`, the AC-1 and AC-2
  assertions that name the unquoted path, and AC-1's `required gate(s) failed`,
  **must** go red, and every pre-existing `covers` assertion must stay green.
  RED cannot run it: there is no `-z` to remove until GREEN. Run as
  `bash scripts/mutate.sh scripts/gates.sh 's/ diff -z --name-only/ diff --name-only/;s/ ls-files -z --others/ ls-files --others/' -- bash .claude/tests/gates.test.sh`
  (adjust the expression to what GREEN wrote, and say so), compare the failure
  count with RED's handoff, confirm green after the restore. **Owner: GATES.**
- **DV-2 - the POSIX-only cases (AC-3, AC-5) watched failing.** These cannot
  run on this host at all (decision 3), so their RED failure is never observed
  here. At GATES, if `wsl.exe -e uname -s` prints `Linux` (WSL is present on
  this host; whether a distribution is installed is unknown), run DV-1's
  mutation and its `selftest-needed.sh` equivalent (`-z` removed from `:85`
  and `:87`) in a Linux checkout of the branch and paste both reds; otherwise
  write WAIVED with that reason, and record the PR's CI run (ubuntu-latest) as
  the observed GREEN of those cases - which also catches a GREEN that used
  `core.quotePath=false` instead of `-z`, the one wrong fix AC-1/AC-2 cannot.
  **Owner: GATES.**

AC-4's test fails in RED on this host against the unfixed script, so it is
earned in RED; no mutation is owed for a test written against existing code.
That is the whole budget (`rules.md`, "Mutation work per story").

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

Planned by `bash scripts/plan.sh write HARNESS-078` from `.claude/harness/models.conf`.
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

- **PLANNED, `lead-po`, departed from `models.conf`'s `fable` row: dispatched
  on Opus by the user's instruction** ("Re-run the HARNESS-078 planning
  dispatch on Opus now, and record in the story that PLANNED departed from
  models.conf's fable row because of the usage limit"). The cause: the first
  planning dispatch stopped with `You've reached your Fable limit (rate_limit,
  HTTP 429)` before writing anything. **Resolved model, as the dispatch itself
  could see it:** the session opened identifying itself as Opus 5.5
  (`claude-opus-5-5`); midway, after the `plan-story` and `story-authoring`
  skills loaded, a system notice in the same dispatch identified the model as
  Fable 5.1 (`claude-fable-5-1`), and the commit attribution changed to match.
  The dispatch cannot tell which ran which part; both names are recorded
  rather than one guessed. `models.conf` is not edited.
  **Success condition, either way:** if RED amends more than half of the
  Contract's blocks (the `###` blocks: Oracle partition, the `gates.sh`
  enumeration, the `sigpipe` pins, `selftest-needed.sh`, `host-load.sh`, The
  tests - more than 3 of 6), the plan was weaker than a planning-phase plan
  should be; 3 or fewer, it was not. **Verdict: recorded at REVIEW.**
## Out of scope

- **A name holding a newline.** Still split into two paths and dropped
  unreported by `gates.sh` (and, with AC-5, misread by `selftest-needed.sh`);
  recorded as a known limit in a comment, not fixed. Fixing it means carrying
  NUL through `classify_stdin`, which is line-based across the harness.
- **Rename handling in `gates.sh`.** Its `git diff` still lists a rename under
  the new name only; `selftest-needed.sh`'s `--no-renames` difference stays.
- **Any other enumeration of paths in the harness** (`check-boundaries.sh`,
  `classify.sh --list`, `plan.sh`). Only the two named here.
- **`sigpipe.test.sh`.** Its `gates.sh` pins do not move (Contract); it is not
  edited.
- **`host-load.sh`'s parsing of a UID with a space**, and HARNESS-076's own
  `## Out of scope` sentence making the same claim - a DONE story is history,
  not edited. Only the script's header comment changes.
- **A `lib.sh` that prints on stderr while loading.** Stderr stays connected
  on purpose, so a load error is seen.
- **A top-level `exit 0` in `lib.sh`** still ends `selftest-needed.sh` with rc
  0 and no line after the probe. The comment stops overclaiming; the behaviour
  is unchanged.

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

- **PO decisions (2026-10-27, planning).**
  1. **`selftest-needed.sh` takes the same `-z` fix here (AC-5) - pending the
     user's confirmation.** The user named only `gates.sh`. Included because
     the story already edits `selftest-needed.sh` for AC-4 and the comment
     fix, HARNESS-077 recorded the identical limit there and named `-z` as the
     fix for both, and it is one case under the same host rule as AC-3. If the
     user declines before RED, delete AC-5 and its Contract bullet; after RED
     it is an `## Amendments` entry.
  2. **One story, one cycle.** Two behaviour changes (the enumeration, two
     lines in each script; the redirect, one line) and two comment rewrites,
     across three scripts and two suites. Each RED case reuses an existing
     fixture block. No split: no part is independently interesting to ship,
     and none of the four shares a file with another open story's area.
  3. **Names with `"`, `\` or a tab are tested on POSIX hosts only, by a
     guarded case whose guard is itself asserted elsewhere.** Measured on this
     host: Git Bash creates `a"b.ts` and `a<TAB>b.ts` but maps both characters
     to private-use code points, so git sees a non-ASCII name, not `"` or a
     tab; `a\b.ts` cannot be created at all. An index-only fixture does not
     help: git for Windows refuses such paths under `core.protectNTFS`, and
     with it disabled a worktree `git diff` still does not list them, and
     `gates.sh` drops a path with no file anyway. A fixture listing fed in
     instead would need a test seam in `gates.sh`, which is new surface for a
     comment-sized fix. So: skipped, visibly and uncounted, only when
     `uname -s` is MINGW/MSYS/CYGWIN; asserted everywhere else; observed
     failing via DV-2 (WSL if present) or WAIVED with CI as the observed
     green. The non-ASCII cases (AC-1, AC-2) run everywhere and carry the
     central claim on this host.
  4. **A name holding a newline is not fixed** (Contract; Out of scope).
  5. **Type `fix`, not `chore`.** Two of the four items are observable
     misbehaviour with a reproducing test; the comment items ride along.
  6. **`sigpipe.test.sh` is not changed.** The brief expected the fix to move
     its `gates.sh` pins; they are lines 82 and 734, both above the edit.
- **Decision 1 confirmed by the user (2026-10-27), before RED:** "Keep AC-5
  (selftest-needed.sh takes the same -z fix) and push the HARNESS-078 PLANNED
  commit straight to main." AC-5 stays in scope as written.
- **PO checks before RED (2026-10-27, orchestrator).** HARNESS-077 is DONE.
  Verified against today's tree: `gates.sh:991-993` is the enumeration the
  Contract quotes; the `sigpipe.test.sh` pins are `gates.sh:82` and `:734`,
  both above it; `gates.test.sh:387` opens the `covers` block, which asserts
  the "exercised only by optional gate" line once today;
  `selftest-needed.sh:64` is the unredirected `. "$LIB"`, `:85`/`:87` the two
  listings; `host-load.sh:32-34` the UID sentence; floors `gates 682`,
  `selftest-needed 216`. AC-5's label updated from "pending" to "confirmed"
  before this PLANNED commit (wording of the criterion unchanged). Criteria
  testable as written; the gate holding the artifact is the harness self-test
  (`gates`, `selftest-needed` suites); `required_gates` stays empty; no epic;
  no changed signatures. Resolved model for this check: Fable 5.1
  (`claude-fable-5-1`).
