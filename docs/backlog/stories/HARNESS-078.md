---
id: HARNESS-078
title: The covers check sees every changed path by its real name, and selftest-needed answers in one line
slug: the-covers-check-sees-every-changed-path
epic: 
type: fix
status: in-progress
phase: RED
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
~~The rest of the pipeline and the loop are unchanged.~~ Keep the enumeration
to the same three lines plus, at most, a comment directly above them (next
block); nothing above line 965 moves.

**Amended by RED (2026-10-27): `-z` alone does not satisfy AC-3, and two more
edits below line 991 are required.** Measured on Linux (WSL, git 2.43, gawk
5.2), with the "After" pipeline above typed out verbatim in a scratch script
(no source edited) over a repo holding the three AC-3 names, then the loop's
`-e` test and the summary's `printf '%b'`, piped to `od -An -c`: `a"b.ts`
comes out right; the tab name is dropped, cut at its tab; the backslash name
prints with a BACKSPACE byte (od's `\b`; a literal backslash would be `\\`).

     D R O P P E D a s d e l e t
     e d : s r c / r e n d e r / a
     \n
     \n F A I L c h
     a n g e s : s r c / r e n d e
     r / a " b . t s i s e x e r
     ...
     i n t e g r a t i o n \n F A I L
     c h a n g e s
     : s r c / r e n d e r / a \b .
     t s i s e x e r c i s e d

1. **A tab in the name is cut by the awk filter.** `classify_stdin` prints
   `<category>\t<path>` and the filter `awk -F'\t' '$1 == "source" { print $2 }'`
   prints only the text up to the path's own tab, so `src/render/a<TAB>b.ts`
   becomes `src/render/a`, which `-e` then drops as deleted. The filter must
   print everything after the FIRST tab, e.g.
   `awk -F'\t' '$1 == "source" { print substr($0, length($1) + 2) }'`.
2. **A backslash in the name is interpreted by `printf '%b'`.** The FAIL and
   WARN lines (`:1010`, `:1013`) put `$path` into `$results`, which is printed
   with `printf '\n--- gate summary ---%b\n' "$results"` (`:1055`) and recorded
   with `printf '%b' "$results"` (`:1191`). `%b` turns the `\b` of
   `src/render/a\b.ts` into a backspace (and a `\c` would end the summary
   outright). `$path` must have each `\` doubled before it is appended to
   `$results`, in both lines - the mechanism is GREEN's (a `sed 's/\\/\\\\/g'`
   is portable to bash 3.2; check any `${path//...}` form there before using
   it). The `glob_matches` call and the `-e` test keep the raw `$path`.

Both edits are below line 991, so the `sigpipe.test.sh` pins (`:82`, `:734`)
still do not move.

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
- **`:92` (amended by RED, 2026-10-27): the harness filter must print
  everything after the first tab**, as in the `gates.sh` block's amendment 1:
  `awk -F'\t' '$1 == "harness" { print substr($0, length($1) + 2) }'`.
  Measured on Linux with the `-z | tr` listing typed out in a scratch script:
  the three AC-5 names come out of `classify_stdin | awk -F'\t' ... print $2`
  as `.claude/tests/a` (the tab name, cut), `.claude/tests/a"b.test.sh` and
  `.claude/tests/a\b.test.sh` - so without this the AC-5 tab cases answer
  `run` naming the wrong path. The `%b` defect does not arise here: the
  answer is printed with `%s`.

      . c l a u d e / t e s t s / a \n
      . c l a u d e / t e s t s / a "
      b . t e s t . s h \n . c l a u d
      e / t e s t s / a \ b . t e s t
      . s h \n

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

All five criteria are mechanical (Contract, "Oracle partition"): every expected
line is read out of today's formats and pinned whole or as an exact substring.
Every case is at the level the criterion lives: the real `scripts/gates.sh` and
`scripts/selftest-needed.sh`, run in a fixture repository, through the suites'
own helpers. No new helper, no test-only dependency, no floor change.

**`.claude/tests/gates.test.sh`** - a new `describe "covers (HARNESS-078): ..."`
block inside the `covers` section, after its `--audit` cases and before its
cleanup lines, on the same fixture (`story/T-1-fixture`, phase GATES, story
T-1 with no `required_gates`). It writes the block's `unit`+`integration` conf
(`src/core/**` required, `src/render/**` optional) and removes `mesh.ts` first,
so the only optional-gate path in each run is the case's own.

| Case | Asserts | AC |
|---|---|---|
| precondition | `git ls-files -z --others -- src/render` lists exactly `src/render/café.ts` | AC-1 |
| AC-1 FAIL line | output holds `FAIL         changes: src/render/café.ts is exercised only by optional gate(s): integration` | AC-1 |
| AC-1 run fails | output holds `required gate(s) failed` | AC-1 |
| AC-1 no false pass | output does NOT hold `All required gates passed` | AC-1 |
| precondition | `git diff -z --name-only main HEAD -- src/shaders/` (less the block's `sky.glsl`) is exactly `src/shaders/café.glsl`, and it is not untracked | AC-2 |
| AC-2 WARN line | output holds `WARN         changes: src/shaders/café.glsl is exercised by no gate with a covers line` | AC-2 |
| AC-3 x3 names, POSIX only | precondition `ls-files -z --others -- src/render` is the name byte for byte (assert_eq); FAIL line names it byte for byte; `required gate(s) failed` | AC-3 |

Each case removes its file after itself (AC-2 by `git rm` + a commit, so the
story branch no longer differs from main by it); the block's original cleanup
then runs unchanged. The whole suite was run, Windows and Linux, and the only
failures are this block's (see Handoff).

**`.claude/tests/selftest-needed.test.sh`** - two blocks before `summary`.

| Case | Asserts | AC |
|---|---|---|
| AC-4 preconditions | sourcing the fixture's lib.sh copy prints exactly `lib-loaded-on-stdout`; the only path changed against main is `scripts/x.sh`, tree clean | AC-4 |
| AC-4 `expect`, root and `src/` | exit 0; first line is the whole pinned `run ... 1 harness path(s) ...: scripts/x.sh` line; stdout is exactly one line; stderr empty | AC-4 |
| AC-5 x3 names x {untracked, committed}, POSIX only | precondition: the `-z` listing (`ls-files --others` / `diff main HEAD`) is the name byte for byte; then `expect` as above with the name in the pinned line | AC-5 |

AC-4's lib.sh rewrite is committed on `main` before the story branch, so
lib.sh is not itself a changed path and the pinned count stays `1`.
AC-5 runs each name both untracked and committed because each of the two
listings (`:85`, `:87`) needs its own `-z`.

**The host rule (decision 3).** Both POSIX-only groups sit in
`case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*)`, which prints one `    SKIP ...`
line on stdout and runs nothing; on any other host the precondition is an
`assert_eq`, so a Linux host cannot skip them quietly. Skipped cases are not
counted. The PO's measurement was re-taken on this host (Handoff) and holds.

## Handoff: RED -> GREEN

**Model.** This RED dispatch ran on Opus 5.5 (`claude-opus-5-5`), as its
system context identified it; dispatched as `test-developer`, whose `model:`
is `opus`. No override was stated in the brief.

**Read the two Contract amendments first** (`gates.sh` enumeration block,
"Amended by RED", and the `selftest-needed.sh` `:92` bullet). The Contract's
`-z` fix alone does NOT turn AC-3's backslash and tab cases or AC-5's tab
cases green: a tab in a path is cut by the `awk -F'\t' ... print $2` filters
in both scripts, and `gates.sh` prints `$results` with `printf '%b'`, which
turns `a\b` into `a<BACKSPACE>`. Both measured on Linux; both fixes are
below `gates.sh:991`, so the `sigpipe.test.sh` pins still do not move. The
acceptance criteria are untouched. 2 of the Contract's 6 `###` blocks are
amended (for the Model guidance success condition).

### Commands

    bash scripts/selftest.sh gates              # ~7.5 min on this host
    bash scripts/selftest.sh selftest-needed    # ~1.2 min on this host
    bash .claude/tests/gates.test.sh            # the suite alone, same result

The POSIX-only cases (AC-3, AC-5) never run on this host. They were run in
RED under WSL (Ubuntu, git 2.43, bash 5.2, gawk 5.2), from a throwaway clone
of this branch with the two edited suites copied in:

    MSYS_NO_PATHCONV=1 wsl.exe -e bash -c 'W=$(mktemp -d /tmp/h78.XXXXXX);
      git clone -q /mnt/d/agentic-dev-harness "$W/r" && cd "$W/r" &&
      git checkout -q story/HARNESS-078-the-covers-check-sees-every-changed-path &&
      cp /mnt/d/agentic-dev-harness/.claude/tests/{gates,selftest-needed}.test.sh .claude/tests/ &&
      bash .claude/tests/gates.test.sh; bash .claude/tests/selftest-needed.test.sh; rm -rf "$W"'

(`MSYS_NO_PATHCONV=1` stops Git Bash rewriting `/mnt/...` arguments; the WSL
VM's `/tmp` is wiped when it idles out, so keep logs on `/mnt/c`.) GREEN can
use the same to watch AC-3/AC-5 go green before GATES' DV-2.

### RED output - this host (MINGW64_NT-10.0-26200)

`gates`: 856 executed, `852 passed, 4 failed`; every failure is this
story's. Verbatim, abridged only where a line reads `...` (the gate-run
preamble and the untracked-file advice; the other three failures print the
same output):

    covers (HARNESS-078): a changed path is seen by its real name, not git's quoted one
      FAIL AC-1: an UNTRACKED src/render/café.ts that only an optional gate reads FAILs, named unquoted
           expected to contain: FAIL         changes: src/render/café.ts is exercised only by optional gate(s): integration
           actual:
           --- gate summary ---
           PASS         unit (1s, observed 47)
           PASS         integration (0s, observed 25)

           changes: 1 changed source path(s), all exercised by a required gate

           untracked: 2 gated file(s) are not part of the recorded tree:
               UNTRACKED  "src/render/caf\303\251.ts"
               UNTRACKED  tests/other.test.ts
           ...
           All required gates passed (2 ran, 0 unconfigured, 0 known).
      FAIL AC-1: and the run fails
           expected to contain: required gate(s) failed
      FAIL AC-1: and the run does not claim all required gates passed
           expected NOT to contain: All required gates passed
      FAIL AC-2: a COMMITTED src/shaders/café.glsl no covers line claims WARNs, named unquoted
           expected to contain: WARN         changes: src/shaders/café.glsl is exercised by no gate with a covers line
           ...
           changes: 1 changed source path(s), all exercised by a required gate
           ...
           All required gates passed (2 ran, 0 unconfigured, 0 known).
      SKIP covers AC-3 (HARNESS-078 decision 3): the untracked src/render/a"b.ts, src/render/a\b.ts and src/render/a<TAB>b.ts cases are not run on MINGW64_NT-10.0-26200: Git Bash maps " and a tab to private-use code points and cannot create \ at all; not counted as a pass

    gates: 852 passed, 4 failed

    assertion floors: all 1 suite(s) met their declared floor (852 assertions executed, 682 declared).
    1 of 1 harness suite(s) FAILED.

**Why it is the right failure.** `changes: 1 changed source path(s)` is
`src/core/thing.ts` alone: `café.ts` (and, for AC-2, `café.glsl`) reached
the loop C-quoted, failed `[ -e ]`, and was dropped as deleted - the defect
exactly, while the gates themselves pass. The quoted form is visible in the
same output (the `untracked:` report, a different enumeration and out of
scope). Both preconditions passed, so the fixture holds the names as the
criteria describe.

`selftest-needed`: 226 executed, `222 passed, 4 failed`:

    HARNESS-078 AC-4: a lib.sh that prints while it is sourced does not add a line to the answer
      FAIL a lib.sh that prints a line on load: the answer is still the one pinned run line [from root]: the first line is exactly the pinned line
           expected: selftest-needed: run — 1 harness path(s) changed against main (merge-base 8ff2c59): scripts/x.sh
           actual:   lib-loaded-on-stdout
      FAIL a lib.sh that prints a line on load: the answer is still the one pinned run line [from root]: stdout is exactly one line
           expected: 1
           actual:   2
      FAIL a lib.sh that prints a line on load: the answer is still the one pinned run line [from subdir]: the first line is exactly the pinned line
           expected: selftest-needed: run — 1 harness path(s) changed against main (merge-base 8ff2c59): scripts/x.sh
           actual:   lib-loaded-on-stdout
      FAIL a lib.sh that prints a line on load: the answer is still the one pinned run line [from subdir]: stdout is exactly one line
           expected: 1
           actual:   2

    HARNESS-078 AC-5: a harness path named with `"`, `\` or a tab is seen, and named byte for byte
      SKIP HARNESS-078 AC-5 (decision 3): the .claude/tests/a"b.test.sh, .claude/tests/a\b.test.sh and .claude/tests/a<TAB>b.test.sh cases, untracked and committed, are not run on MINGW64_NT-10.0-26200: Git Bash maps " and a tab to private-use code points and cannot create \ at all; not counted as a pass

    selftest-needed: 222 passed, 4 failed

**Right failure:** the library's line comes first and the verdict second -
`:64`'s unredirected `. "$LIB"`, exactly; exit 0 and empty stderr already hold.

### RED output - Linux (WSL), the POSIX-only cases

`gates`: 865 executed, `855 passed, 10 failed` - the 4 above plus 6 AC-3
(`"`, `\`, tab x {FAIL line, run fails}); all 3 AC-3 preconditions passed.
`selftest-needed`: 280 executed, `252 passed, 28 failed` - the 4 AC-4 plus
24 AC-5 (3 names x {untracked, committed} x {root, src/} x {exit, first
line}); all 6 preconditions passed. Gates, one name each, the `expected`
and `UNTRACKED` lines of each failure (the rest is the same summary as above):

    FAIL AC-3: an UNTRACKED src/render/a"b.ts that only an optional gate reads FAILs, named byte for byte
         expected to contain: FAIL         changes: src/render/a"b.ts is exercised only by optional gate(s): integration
             UNTRACKED  "src/render/a\"b.ts"
    FAIL AC-3: an UNTRACKED src/render/a\b.ts that only an optional gate reads FAILs, named byte for byte
         expected to contain: FAIL         changes: src/render/a\b.ts is exercised only by optional gate(s): integration
             UNTRACKED  "src/render/a\\b.ts"
    FAIL AC-3: an UNTRACKED src/render/a<TAB>b.ts that only an optional gate reads FAILs, named byte for byte
             UNTRACKED  "src/render/a\tb.ts"
    gates: 855 passed, 10 failed

and selftest-needed, one of the 24:

    FAIL a COMMITTED .claude/tests/a\b.test.sh answers run and names it byte for byte [from root]: exits 0
         expected: 0
         actual:   1
    FAIL a COMMITTED .claude/tests/a\b.test.sh answers run and names it byte for byte [from root]: the first line is exactly the pinned line
         expected: selftest-needed: run — 1 harness path(s) changed against main (merge-base c261258): .claude/tests/a\b.test.sh
         actual:   selftest-needed: skip — no harness path among 1 changed path(s) against main (merge-base c261258); CI runs the self-test on the PR
    selftest-needed: 252 passed, 28 failed

Right failure: every one is the C-quoted name dropped (gates.sh) or
classified `source` (selftest-needed: `skip`, exit 1) - the wrong-way skip
AC-5 names.

### Host measurement (decision 3), re-taken in RED

On this host, in a scratch repo, `printf` creating each name, then
`git ls-files --others` and `-z`:

    MINGW64_NT-10.0-26200
    created:  a " b . t s
    host.sh: line 8: /tmp/tmp.kEPN4n5oHZ/a\b.ts: No such file or directory
    cannot create:  a \ b . t s
    created:  a \t b . t s
    created:  c a f 303 251 . t s
    --- ls-files --others (default quotePath):
    "a\357\200\211b.ts"
    "a\357\200\242b.ts"
    "caf\303\251.ts"

The PO's measurement holds: `"` reaches git as U+F022, a tab as U+F009, and
`\` cannot be created. `printf '\t'` does produce a real tab here (the
`created: a \t b` line); it is the filesystem layer that remaps it.

### Files touched

- `.claude/tests/gates.test.sh` - additions only (AC-1, AC-2, AC-3).
- `.claude/tests/selftest-needed.test.sh` - additions only (AC-4, AC-5).
- `docs/backlog/stories/HARNESS-078.md` - the two Contract amendments,
  `## Test plan`, this handoff.
- Not touched: `floors.conf`, `selftest.test.sh`, `sigpipe.test.sh`, anything
  under `scripts/`.

### Floors - unchanged

`gates` 682 and `selftest-needed` 216 stay. This host now executes 856 and
226 (Linux: 865 and 280); the `gates` floor was already 168 below the count
before this story, and raising either is optional (`floors.conf` header).

### What the tests pin, and what they leave to GREEN

No module, function or signature is imported or called by the new tests; they
drive the two scripts as commands. Pinned:

- `gates.sh` output holds, byte for byte, `FAIL         changes: <path> is
  exercised only by optional gate(s): integration` and `WARN         changes:
  <path> is exercised by no gate with a covers line`, with `<path>` as the
  filesystem holds it, and a run with such a FAIL ends `required gate(s)
  failed`, never `All required gates passed`.
- `selftest-needed.sh`'s stdout is exactly one line, the pinned `run` line,
  whatever `lib.sh` prints on stdout while loading; and names a harness path
  holding `"`, `\` or a tab byte for byte, `run`, exit 0, from root and `src/`.
- **`-z`, not `core.quotePath=false`.** AC-1, AC-2 and every pre-existing
  `café` case pass under either. Only AC-3/AC-5 tell them apart, and only on
  a POSIX host - so on this host nothing distinguishes the two fixes; Linux CI
  (or WSL) is the only place a `quotePath=false` GREEN goes red.

Left to GREEN: the escaping mechanism for `%b` (amendment 2), the exact awk
form of the after-first-tab filter (amendments), whether to drop
`-c core.quotePath=false` in `selftest-needed.sh`, and all comment wording
(`host-load.sh`, `selftest-needed.sh` header, the `gates.sh` known-limit
comment) - no test reads any comment.

### Passed on arrival among the new assertions

- **Preconditions** (2 on this host: AC-1, AC-2; plus AC-4's 2; Linux adds 3
  AC-3 and 6 AC-5). They assert the fixture, not the scripts; each would go
  red if the fixture failed to hold the name (that is how a Linux host is
  stopped from skipping quietly). Not separately mutated.
- **AC-4's `exits 0` and `nothing on stderr` (4)** and **AC-5's `stdout is
  exactly one line` and `nothing on stderr` (24, Linux)**: these come from
  the shared `expect` helper, whose assertions were earned in HARNESS-075's
  RED (script absent, exit 127). They are not what AC-4/AC-5 claim; the
  claimed assertions (first line, line count for AC-4; exit and first line
  for AC-5) are red above. No new mutation is owed for them (rules.md,
  "Mutation work per story").

### Negative controls - expected values

There is no threshold in this story (Contract, "Oracle partition"), so no
numeric control. The structural controls are the pre-existing ASCII
`covers` cases (`mesh.ts`, `thing.ts`, `sky.glsl`) and the HARNESS-075/077
`café` cases: all green now, all must stay green after GREEN.

| Control | Expected after GREEN | Measured in RED (this host) |
|---|---|---|
| pre-existing `covers` assertions | all pass | all pass (the 4 failures are all HARNESS-078's) |
| `gates` suite, this host | 856 passed, 0 failed | 852 passed, 4 failed |
| `selftest-needed` suite, this host | 226 passed, 0 failed | 222 passed, 4 failed |
| `gates` suite, Linux | 865 passed, 0 failed | 855 passed, 10 failed |
| `selftest-needed` suite, Linux | 280 passed, 0 failed | 252 passed, 28 failed |

### Deferred verifications - declined

- **DV-1 - declined; owned by GATES.** RED cannot run it: there is no `-z` to
  remove until GREEN. **Predicted red count** with `-z` removed from both
  enumeration commands and GREEN's other two edits in place: on this host
  **4** (`gates: 852 passed, 4 failed` - the same 4 as RED: AC-1 x3, AC-2
  x1), every pre-existing `covers` assertion green; on Linux **10** (those 4
  plus AC-3's 6). Note the mutation expression in DV-1 assumes `diff -z
  --name-only` / `ls-files -z --others` word order; adjust to what GREEN
  wrote.
- **DV-2 - declined; owned by GATES.** Not run as a mutation here. Fact for
  GATES: `wsl.exe -e uname -s` prints `Linux` on this host and the
  distribution has git 2.43, bash 5.2 and gawk 5.2, so DV-2 can be run
  rather than WAIVED, with the command above. Predicted reds with `-z`
  removed: gates **10** on Linux; selftest-needed **24** on Linux (all AC-5
  cases) if `-c core.quotePath=false` is kept, and on this host **0** - no
  case on Windows distinguishes `-z` in `selftest-needed.sh` while
  `quotePath=false` stays. If GREEN drops `quotePath=false`, the mutation also
  turns the HARNESS-075/077 `café` cases red on this host.

### Discovered, changing the approach

- The two Contract defects above (tab cut by awk; `%b` on `$results`).
- `gates.sh`'s `untracked:` report (HARNESS-014) prints the same names
  C-quoted (`UNTRACKED  "src/render/caf\303\251.ts"`) - another enumeration,
  out of scope by `## Out of scope`; recorded only.

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
- **RED verified by the orchestrator (2026-10-27).** Test-developer
  (resolved: Opus 5.5, `claude-opus-5-5`, declared `opus`, no override).
  Reran on this host: `gates: 852 passed, 4 failed` (AC-1 x3, AC-2 x1 - the
  non-ASCII names dropped as deleted) and `selftest-needed: 222 passed, 4
  failed` (AC-4: two stdout lines, the library's first), each with the
  visible AC-3 / AC-5 SKIP line; `scripts/` untouched; floors unchanged. RED
  also ran the POSIX-only cases in WSL (Ubuntu) and watched them fail (10 and
  28 red); DV-2 can therefore be run at GATES, not waived.
  **RED's two Contract amendments, reproduced independently** on inputs of my
  own, not RED's script: `printf 'harness\tdocs/x\ty.md\n' | awk -F'\t'
  '$1 == "harness" { print $2 }'` prints `docs/x` (a tab in a name truncates
  it after `classify_stdin`), and `printf '%b' "lib\new.sh"` turns `\n` into
  a newline (`gates.sh:1055` and `:1191` print `$results` with `%b`). So `-z`
  alone does not pass AC-3/AC-5; the amended blocks are accepted. Criteria
  unchanged (the AC section's diff against the PLANNED commit is empty).
  Amended blocks so far: 2 of the Contract's 6 - under the 3 the PLANNED
  model condition sets.
