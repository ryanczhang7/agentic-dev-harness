---
id: HARNESS-099
title: The gates suite executes the same count in a bootstrapped project as in the template
slug: the-gates-suite-executes-the-same-count
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-099-the-gates-suite-executes-the-same-count
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/gates.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]
required_gates: []  # every gate is unconfigured here; the artifact is judged by the gates suite under the selftest floor, which CI runs in full on the PR
---

## Context

In a consuming project - one whose own `.claude/harness/project.conf` reads
`BOOTSTRAPPED=yes` - the full self-test fails the `gates` suite on its
assertion floor with no assertion failing. Found 2026-11-08 refreshing
manga-translator from release 97 to 117 (evidence log, read only:
`D:\mt-harness-refresh\.claude\state\attest-logs\20261108T181943Z.868912.log`,
lines 385, 407-408):

    note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
    gates: 981 passed, 0 failed
    FAIL gates  did 981 units of work, below the floor of 984 in .claude/tests/floors.conf

Cause, read from the tree (`main` at `3c79f70`, release 117). The
`# --- AC-7: the shipped manifest ---` block of `.claude/tests/gates.test.sh`
(lines 3805-3829) reads the REAL tree's `project.conf` through
`SHIP69="$REPO_ROOT/.claude/harness/project.conf"` and branches on it: when
`grep -qE '^BOOTSTRAPPED=yes'` matches (line 3817) it prints the `note:` above
and runs nothing; otherwise (the template, `BOOTSTRAPPED=no` at
`project.conf:307`) it runs three `assert_eq` about the template's text - the
keep-when format line once and in position (3823), the commented example
(3826), no live keep-when line (3828). HARNESS-070 added the branch because a
consumer's `project.conf` is the project's own: `refresh-harness.sh` leaves it,
and it may carry live keep-when lines, which is what the feature is for. At
that time `gates` was floored at 682 and the branch cost nothing ("a
bootstrapped tree runs 847 of 850, so `floors.conf` does not move", HARNESS-070
`## Contract`). Every raise since was measured on the template -
`floor | gates | 984` (floors.conf line 47, hand-copied at selftest.test.sh
line 538) landed in HARNESS-093 RED (`221b275`) - so the floor is the
template's count, every bootstrapped consumer executes at most 981, and the
floor can never hold there. The consumer cannot repair it: `scripts/selftest.sh`
(lines 102-113, HARNESS-020) makes a suite floored in both `floors.conf` and
`project-floors.conf` a fault, by design, so a project cannot lower an upstream
floor. The consumer's CI runs the full self-test, so its refresh PR is red.

Reproduced upstream at PLANNED, without touching manga-translator: a scratch
clone of this tree with `BOOTSTRAPPED=no` → `BOOTSTRAPPED=yes` substituted in
its own `project.conf`, then `bash scripts/selftest.sh gates`, against a second
scratch clone left as the template. The results are in `## Notes`.

**The class.** `grep -n BOOTSTRAPPED .claude/tests/*.test.sh` finds 60 hits in
six suites; every one but this block WRITES the word into a fixture
(`write_conf`, `printf ... > "$FIX/.claude/harness/project.conf"`, `h88_conf`,
`gl_swap`) or pins how `gates.sh`/`doctor.sh` read it (`sigpipe.test.sh`
579-580). Only `gates.test.sh` 3817 READS the real tree's `project.conf` and
changes what it executes on the answer. The other real-tree reads in the suites
(`configuring.md` at 3869-3872, the manifest goldens at 3868-3875,
`scripts/*.sh` everywhere) are of files a refresh REPLACES, so they are the
same bytes in every tree; `project.conf` is the one file a refresh LEAVES, so it
is the one file a real-tree read can diverge on. The same refresh's other 34
suites met their floors in the consumer. So the class has one instance, and the
fix is to that block; the rule it teaches - an assertion over a file the refresh
leaves must execute the same count in every tree - is written into the block's
comment, and a guard for it is out of scope (`## Out of scope`).

**Required gate.** None is configured here; the artifact is judged by
`bash scripts/selftest.sh gates`, whose floor is what this story makes hold in
both trees, and CI runs the full self-test on the PR.

## Acceptance criteria

- **AC-1** - Given a clone of this tree whose `.claude/harness/project.conf`
  reads `BOOTSTRAPPED=yes` by `gates.sh`'s reading (the first `^BOOTSTRAPPED=`
  line, the text after `=` with whitespace removed), when
  `bash scripts/selftest.sh gates` runs there, then the `gates` suite executes
  the same number of assertions as the same command executes in the template
  tree (`BOOTSTRAPPED=no`), `0 failed` in both, it meets `floors.conf`'s `gates`
  floor in both, and the line beginning `note: project.conf is this project's
  own` is printed in neither. *On `main` today:* 981 against 984, and
  `FAIL gates  did 981 units of work, below the floor of 984`.
- **AC-2** - Given the shipped-manifest block, when it runs on a manifest that
  reads bootstrapped and when it runs on a manifest that reads as the template,
  then each run executes exactly three assertions, and the suite pins both
  counts on fixture manifests it writes itself - so the pin executes in every
  tree, whichever path the real `project.conf` takes.
- **AC-3** - Given a bootstrapped manifest with live keep-when lines, when the
  block runs on it, then its three assertions are about those lines and hold
  for a well-formed manifest: (a) `bash scripts/gates.sh --list` on that
  manifest prints one `keep-when: <pattern>` line per live line, under the gate
  the line names, in manifest order - the ids agree; (b) the patterns agree,
  verbatim; (c) every live pattern is a valid extended regex for the matcher
  `gates.sh` applies it with (`grep -E`). *Controls:* a manifest whose live
  pattern is `(` is counted as 1 invalid by (c)'s reader; the live-line reader
  on the existing `live.conf` fixture (`keep-when | unit | x`,
  `  keep-when|unit|y`, a commented `z`) yields exactly the two live pairs
  `unit`/`x` and `unit`/`y`, trimmed, and not the comment.
- **AC-4** - Given a manifest whose line is `BOOTSTRAPPED=  yes  `, when the
  block runs on it, then it takes the bootstrapped path - the block decides
  with `gates.sh`'s reading (`scripts/gates.sh` 93-95), not a literal
  `^BOOTSTRAPPED=yes`. *On `main` today* that manifest takes the template path
  and fails all three template assertions.
- **AC-5** - Given the template tree, when the suite runs, then the three
  template assertions (titles beginning `AC-7: the shipped project.conf holds
  the keep-when format line once`, `AC-7: and an example keep-when line in a
  comment`, `AC-7: the shipped project.conf carries no live keep-when line`)
  still run against the real `project.conf` with their text and expected values
  unchanged; `floor | gates | <N>` in `floors.conf` and `gates <N>` in
  `selftest.test.sh` carry the new measured count, equal; the unconditional
  `--audit` trio on the shipped manifest (today 3864-3867) and the HARNESS-080
  blocks are unchanged; and `.claude/harness/VERSION` reads `118 (<date>)`.

## Contract

**Writes:** `.claude/tests/gates.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

- **C-1. Anchors (tree `3c79f70`, `main`, 2026-11-08).**
  `.claude/tests/gates.test.sh` (4282 lines): `count_line` 843, `count_re`
  844; the HARNESS-069 fixture `F69` 3332, `M69` 3343, `g69()` 3347 (stdout
  only, `2>/dev/null`); the shipped-manifest block 3805-3829: comment 3805-3814,
  `SHIP69=` 3815, `live69()` 3816, the `if` 3817-3829 with the `note:` printf
  3818 and the three template `assert_eq` at 3823, 3826 and 3828; `live.conf`
  and its control 3830-3831; `cwds69()` 3840-3850, `audit69()` 3851; the
  HARNESS-080 blocks 3852-3863; the unconditional `--audit` trio on `$SHIP69`
  3864-3867; the goldens 3868-3875; `CFG69=` 3878; `summary "gates"` 4282.
  (Verified with `grep -n` at PLANNED; the field report's 3815-3828 is the
  same block.)
  `scripts/gates.sh`: the `BOOTSTRAPPED` reader 93-95; the keep-when matcher
  is `grep -E`, case-sensitive, manifest order, first wins (346-357); `--list`
  prints `keep-when: <pattern>` under each gate (634-636, format
  `'%-12s %-9s %-6s keep-when: %s\n' "" "" "" "$wpat"`, so the line is
  `                              keep-when: <pattern>` - 12+1+9+1+6+1 = 30
  columns of space, then `keep-when: `). Floors: `floor | gates         | 984`
  (floors.conf 47), `gates 984` (selftest.test.sh 538). `.claude/harness/VERSION`
  holds `117 (2026-11-08)`. `_lib.sh`: `_pass`/`_fail` counters 28, `assert_eq`
  59, `make_project_fixture` 146, `write_conf` 158 (prepends
  `BOOTSTRAPPED=yes`).
- **C-2. The block becomes a function, run on the real manifest and on
  fixtures.** `ship69 <label> <conf> <source root>` replaces the `if` of
  3818-3829. It decides the path as `gates.sh` 93-95 does - first
  `^BOOTSTRAPPED=` line of the CR-stripped conf, text after `=`, all whitespace
  removed, empty meaning `no`; `yes` is bootstrapped - and sets `SHIP69_PATH`
  to `bootstrapped` or `template`. It executes EXACTLY THREE assertions on
  either path, titled `AC-7 (<label>): ...`; `<label>` is `shipped` for the
  real manifest so the template tree's three titles become
  `AC-7 (shipped): the shipped project.conf holds the keep-when format line
  once, after skipped-when's and before BOOTSTRAPPED=` and so on - the title
  prefix is the one change to the template assertions, their bodies and
  expected values are not touched. The `note:` printf is deleted. The template
  path is the three existing assertions over `<conf>`. The bootstrapped path
  is C-3. `ship69 shipped "$SHIP69" "$REPO_ROOT"` is called once where the
  `if` was.
- **C-3. The bootstrapped path - three assertions about the manifest's own
  live keep-when lines**, none a duplicate of the `--audit` trio at
  3864-3867, which stays unconditional. Readers, as functions beside `live69`:
  - `kw69 <conf>`: the live keep-when lines of the CR-stripped conf as
    `<id><TAB><pattern>`, both fields trimmed of leading and trailing blanks,
    manifest order - the same lines `live69` counts (a line matching
    `^[[:space:]]*keep-when[[:space:]]*\|`; a `#`-prefixed line is a comment).
  - `kwlist69 <conf> <source root>`: the same pairs as `gates.sh --list` sees
    them, by running `g69 --list` in `F69` with `<conf>` copied in and
    `cwds69` applied (a `list69` sibling of `audit69`, same body with
    `--list`), then walking stdout: a gate row (a line whose first field is a
    gate id, i.e. not beginning with a space) sets the current id; a line
    matching `^ +keep-when: ` emits `<current id><TAB><text after "keep-when: ">`.
  - `badere69 <conf>`: the number of `kw69` patterns on which
    `grep -E -e "$pat" </dev/null` exits 2 (`-e`, so a pattern starting with
    `-` is a pattern; exit 1 is "valid, no match").
  The three assertions, each one `assert_eq`:
  - (a) `AC-7 (<label>): gates.sh --list attributes every live keep-when line
    to the gate it names, in manifest order` - expected `kw69 | cut -f1`,
    actual `kwlist69 | cut -f1`, newline-joined.
  - (b) `AC-7 (<label>): and prints every live keep-when pattern verbatim` -
    the same with `cut -f2-`.
  - (c) `AC-7 (<label>): every live keep-when pattern is a valid ERE for
    grep -E, the matcher gates.sh applies it with` - expected `0`, actual
    `badere69 <conf>`.
  Why these three: the `--audit` trio already says the live lines name
  configured gates and have patterns; what nobody checks in a consumer is that
  `gates.sh`'s reader and the suite's agree on WHICH lines and WHAT text
  (spacing, CRLF, a `|` in a pattern), and that the pattern will not make
  `grep -E` exit 2 at the moment a failing log is being judged for keeping,
  which `--audit` does not test. A property on pattern CONTENT (for instance
  "matches no empty line") was considered and rejected: `keep-when | unit | .`
  - keep every failing unit log - is a legitimate wish, and the self-test
  must not impose policy on a consumer's manifest.
- **C-4. Fixture manifests and pins, all unconditional, written under
  `$M69`**, after the real-manifest call:
  - `tmpl.conf`, template-shaped, exactly these four lines in order:
    `# Format:  skipped-when | <gate id> | <extended regex>` /
    `# Format:  keep-when | <gate id> | <extended regex>` /
    `#   keep-when | integration | SEGFAULT in worker [0-9]+` /
    `BOOTSTRAPPED=no`. `ship69 template-fixture` on it: three green, path
    `template`.
  - `boot.conf`, consumer-shaped: `keep-when | unit | Windows fatal exception`
    (a live line BEFORE `BOOTSTRAPPED=`, as manga-translator's are) /
    `BOOTSTRAPPED=yes` / `gate | unit | required | . | printf ok` /
    `evidence | unit | -` / `gate | cov | required | . | printf ok` /
    `evidence | cov | -` / `  keep-when|cov|Unknown C\+\+ exception` (the
    spacing variant `live.conf` already uses) / `# keep-when | unit | z`.
    `ship69 bootstrapped-fixture` on it: three green, path `bootstrapped`;
    `kw69` on it is `unit<TAB>Windows fatal exception` then
    `cov<TAB>Unknown C\+\+ exception`.
  - `ws.conf`: `BOOTSTRAPPED=  yes  ` / `gate | unit | required | . | printf ok`
    / `evidence | unit | -`. `ship69 whitespace-yes` on it: three green (no live
    line, so `kw69` and `kwlist69` are both empty and `badere69` is 0).
  - Count pins, through `_lib.sh`'s counters: `n0=$((_pass+_fail))` before a
    `ship69` call and `n1` after; `assert_eq "HARNESS-099 AC-2: the template
    path of the shipped-manifest block executes exactly three assertions" 3
    $((n1-n0))` after `tmpl.conf`, and the same sentence with `bootstrapped`
    after `boot.conf`. (RED may amend to an existing idiom if the suites have
    one for counting a helper's assertions; the Contract found none.)
  - Path pin: `assert_eq "HARNESS-099 AC-4: BOOTSTRAPPED=  yes  , read as
    gates.sh reads it, takes the bootstrapped path" bootstrapped "$SHIP69_PATH"`
    after `ws.conf`.
  - Controls (AC-3): `assert_eq "HARNESS-099 AC-3 control: badere69 counts
    the invalid ERE ( once" 1 "$(badere69 "$M69/bad.conf")"` where `bad.conf` is
    `BOOTSTRAPPED=yes` / `keep-when | unit | (`; and `assert_eq "HARNESS-099
    AC-3 control: kw69 reads live.conf's two live lines trimmed and not the
    comment" "$(printf 'unit\tx\nunit\ty')" "$(kw69 "$M69/live.conf")"`.
    (`live.conf` is written at 3830 today; the control goes after it.)
- **C-5. Ordering inside the file.** `cwds69` and `audit69` (3840-3850) are
  defined AFTER the block that must now use `list69`; RED moves `cwds69`,
  `audit69` and the new `list69` up to directly after `live69()`, bodies
  unchanged, or places the whole shipped block after them - either, said in the
  handoff. Nothing else in the HARNESS-069/080 section moves, and the
  `--audit` trio at 3864-3867 and the goldens keep their text. `g69` discards
  stderr, which `kwlist69` relies on (stdout only).
- **C-6. Counts.** Template today 984, of which the block is 3. New
  unconditional work: `tmpl.conf` 3 + pin 1, `boot.conf` 3 + pin 1, `ws.conf`
  3 + pin 1, controls 2 = 14. Predicted 998 in the template and 981 + 3 + 14 =
  998 in a bootstrapped tree - equal by construction (AC-1), pinned (AC-2).
  RED measures the real number on this tree and writes it to `floors.conf` 47
  and `selftest.test.sh` 538, with a paragraph appended to `floors.conf`'s
  comment block in the HARNESS-098 style (what was added, measured
  `passed`/`failed`, EXECUTED total, and that the count is the same in a
  bootstrapped tree, with the number measured there).
- **C-7. Phases.** `.claude/tests/gates.test.sh`, `floors.conf` and
  `selftest.test.sh` all classify `harness` (writable in every phase); the
  suite is a test file by role, so RED writes the whole suite change and the
  floors, as HARNESS-070 did for this same block. RED watches the defect fail
  in two steps, both pasted in the handoff: (1) the function with the
  bootstrapped path still printing the `note:` and asserting nothing, plus
  C-4's fixtures and pins - the bootstrapped count pin fails `3` against `0`,
  the `ws.conf` path pin fails (`template`, and its three template assertions
  fail on a manifest with no format line) - that is AC-2 and AC-4 reproduced;
  (2) C-3 written - green. AC-1 itself is not a suite assertion (it is a
  statement about two whole runs) and is verified by DV-2. GREEN bumps
  `.claude/harness/VERSION` 117 → 118 (`check-boundaries.sh` refuses an
  upstream harness change without a bump) and is otherwise a verified no-op:
  it runs `bash scripts/selftest.sh gates` and pastes the green summary.
  Callers: `audit69`'s three callers (3855, 3859, 3864) keep their signature;
  no exported shape of any script changes.
- **Oracle.** Every criterion is mechanical: exact titles, exact counts,
  exact line lists. Nothing is settled-by-measurement except the floor's
  number, which RED reads off the run; nothing is oracle-free. Pin exactly,
  leave nothing open-ended.
- RED may amend a block in place with a reason, and GREEN builds what the
  amended block says.

## Deferred verifications

**DV-1 (defect put back). Owner: GATES.** Empty the bootstrapped path again:
`bash scripts/mutate.sh .claude/tests/gates.test.sh '<sed expression RED
records in the handoff that replaces the bootstrapped path's three assertion
calls with a no-op, e.g. the line calling them with `:`>' -- bash
scripts/selftest.sh gates`. Exactly one assertion **must** go red -
`HARNESS-099 AC-2: the bootstrapped path of the shipped-manifest block executes
exactly three assertions`, `3` against `0` - and the run must also print
`FAIL gates  did <N-9> units of work, below the floor of <N>` (three paths run
the bootstrapped branch on fixtures in the template tree: `boot.conf`,
`ws.conf` and, in a consumer, the real manifest; here `boot.conf` and `ws.conf`,
so 6 fewer plus the pin's 0; RED corrects the arithmetic to the shape it built).
RED cannot own this: in RED the suite is being written, and the committed shape
is what the mutation must be against. Paste the red lines, the floor FAIL, the
restore line, and confirm `bash scripts/mutate.sh --check` is clean.

**DV-2 (the consumer's shape, end to end - AC-1). Owner: GATES.** In a scratch
clone of the GATES tree (`git clone --no-hardlinks . <scratch>`, never
manga-translator's worktree), make the clone's own
`.claude/harness/project.conf` a bootstrapped manifest that audits clean, as
a real consumer's does: substitute `BOOTSTRAPPED=no` → `BOOTSTRAPPED=yes`
(line 307), give the five required gate lines (`lint`, `typecheck`, `unit`,
`coverage`, `build`, lines 311-316) the command `printf ok`, and append
`evidence | <id> | -` for each; confirm `bash scripts/gates.sh --audit` there
prints `Manifest audit passed.` and exits 0 FIRST (with `BOOTSTRAPPED=yes` and
no commands the audit fails `no command` five times, and three real-manifest
assertions of the suite - the `--audit` trio at 3864-3867 - plus two of
`AC-5` fail for that reason alone; the PLANNED reproduction in `## Notes` shows
both shapes). Then run `bash scripts/selftest.sh gates` there, and the same
command in an unmodified clone. Both **must** print `gates: <N> passed, 0
failed` with the same `N`, `N` ≥ the floor, no `FAIL gates` line, no `note:
project.conf is this project's own` line, and exit 0. The PLANNED
reproduction of the same procedure against `main` (`## Notes`) is the before
side. Paste both summary lines and both exit codes.

## Amendments

<!-- none -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-099` from `.claude/harness/models.conf`.
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
- PLANNED - `lead-po`, planned `fable`, resolved **claude-fable-5-1**
  (2026-11-08), as a `/plan-story` subagent; no override was stated in the
  dispatch. Oracle partition for RED's brief: every criterion is mechanical
  (Contract, "Oracle"); the only measured number is the floor, read off the
  run.
## Out of scope

- Any change to `scripts/selftest.sh`'s floor mechanism - a declared or
  counted skip, a per-tree floor, or letting `project-floors.conf` lower an
  upstream floor. Rejected as the fix: rules.md names adding a `skip` as a
  weakening, a counted skip is a unit of work printed rather than done, and the
  floor exists to be a count that cannot be padded. HARNESS-020's "a suite
  floored in both files is a fault" stands.
- Any change to `scripts/gates.sh` (its `BOOTSTRAPPED` reader, `--list`
  format, keep-when matcher or `--audit`), to the template `project.conf`'s
  text, or to the `--audit` trio and HARNESS-080 blocks of the suite.
- Any policy on the CONTENT of a consumer's keep-when patterns beyond being a
  valid ERE (C-3 says why).
- A guard over all suites for the class ("no assertion count may depend on a
  file the refresh leaves"): the class has one instance (Context), and such a
  guard would need a rule over suite source that this story does not define.
  The rule is recorded in the block's comment and in `## Notes`.
- Touching `D:\mt-harness-refresh` or any manga-translator file. Its
  `project.conf` and the evidence log were read, not written, at PLANNED.
- Editing `docs/backlog/stories/HARNESS-070.md`; it is DONE, and the
  supersession of its `note:` is recorded here.

## Design notes

<!-- not a UI story -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

## Handoff: RED -> GREEN

<!-- Filled by the Test Developer at the end of RED. This is the ONLY channel
     to the Feature Developer, whose context is fresh. Must contain:
       * the exact command that runs the new tests
       * the failure output, and why it is the RIGHT failure
       * every file touched, and which AC each test covers
       * any test that passed on arrival, and the probe or negative control
         that earns it
       * the EXPECTED VALUE of every negative control, as a table
       * the sed expression DV-1 will use, against the shape as built
       * which of C-5's two orderings was taken
       * anything discovered that changes the approach -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Notes

- Planned 2026-11-08 (lead-po, resolved **claude-fable-5-1**, dispatched by
  the plan-story command; no model override was stated) from the
  manga-translator 97 → 117 refresh field report. `main` at `3c79f70`, no
  active story. **This story blocks the manga-translator 97 → 118 refresh**
  (worktree `D:\mt-harness-refresh`, branch `harness/refresh-97-to-117`),
  whose CI runs the full self-test and fails the `gates` floor until a release
  carrying this fix is refreshed in. That worktree was not touched: its
  `project.conf` (797 lines, 16 live keep-when lines, all before
  `BOOTSTRAPPED=yes`, naming `unit`, `coverage`, `coverage-core`,
  `integration`) and its attest log were read to shape C-3 and C-4.
- PO decisions at PLANNED:
  1. **Fix the suite, not the floor mechanism** (`## Out of scope`, first
     bullet, says why the counted-skip candidate lost).
  2. **Equal count by construction, and pinned.** The block runs exactly three
     assertions on either path; the pin runs on fixture manifests so it
     executes in every tree. A pin that ran only on the real manifest would
     itself execute in one tree and not the other.
  3. **The bootstrapped path asserts something a consumer needs** - that
     `gates.sh` and the suite agree on its live keep-when lines, and that each
     pattern compiles for `grep -E` - rather than re-running the `--audit`
     trio (already unconditional at 3864-3867) or asserting the template's
     text against a fixture only (a test of the readers, meaningless to the
     consumer). Checked at PLANNED: the consumer's manifest, copied into a
     bare clone of this harness, passes `bash scripts/gates.sh --audit` (exit
     0, `Manifest audit passed.`), and its 16 patterns are valid EREs - so C-3
     holds for the one real consumer there is.
  4. **The branch reads `BOOTSTRAPPED` as `gates.sh` does** (AC-4): the
     HARNESS-083 tests in `boundaries.test.sh` 3753-3755 pin that
     `BOOTSTRAPPED=  yes  ` reads `yes`, and the literal grep at 3818 would
     send such a project down the template path and fail all three template
     assertions there. One line, same block, so it is in scope.
- The grep for other BOOTSTRAPPED-dependent branches: 60 hits across
  `boundaries`, `gates`, `refresh`, `security-audit`, `sigpipe` and the
  `floors.conf` comments; every one writes the word into a fixture or pins a
  script's reader; only `gates.test.sh` 3818 reads the real tree's
  `project.conf` and conditions assertions on it. Rule for suite authors,
  recorded here and in the block's comment: a suite may read the real tree,
  but an assertion over a file `refresh-harness.sh` LEAVES (`project.conf`,
  `project-floors.conf`, `project-*.test.sh`) must execute the same number of
  assertions whatever that file says, because the floor is measured on the
  template and a consumer cannot lower it.
- History of the floor against the branch: HARNESS-070 (release ~80) measured
  "847 of 850" in a bootstrapped tree against a floor of 682; the floor reached
  984 in HARNESS-093 RED (`221b275`), measured on the template; HARNESS-098
  (release 117) did not move it. The defect was armed the first time the floor
  was raised to within 3 of the template's count.
- PLANNED reproduction (this host, Windows, local, three scratch clones of
  `main` at `3c79f70` under the session scratchpad; manga-translator
  untouched; `bash scripts/selftest.sh gates` in each):
  - the template, unmodified:

        gates: 984 passed, 0 failed
        assertion floors: all 1 suite(s) met their declared floor (984 assertions executed, 984 declared).
        exit 0

  - `BOOTSTRAPPED=no` → `BOOTSTRAPPED=yes` substituted and nothing else -
    981 executed, the consumer's number exactly, and the floor fails; the
    five failures are not the defect: the template's required gates have no
    command, so `--audit` of the real manifest fails `no command` five times
    and the suite's five real-manifest audit assertions (`AC-5: and its audit
    says it passed`, `AC-5: and exits 0`, and the `AC-7: the shipped
    manifest's --audit still passes` trio) fail with it. A real consumer has
    commands, which is why manga-translator saw 981 passed, 0 failed:

        note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
        gates: 976 passed, 5 failed
        FAIL gates  did 976 units of work, below the floor of 984 in .claude/tests/floors.conf
        exit 1

  - the same clone with its manifest made audit-clean as DV-2 prescribes
    (`printf ok` on the five required gates, `evidence | <id> | -` for each;
    `Manifest audit passed.`, exit 0): the consumer's log reproduced exactly,
    with no manga-translator file involved - 981 executed, none failing, the
    note once, the floor unmet by 3:

        note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
        gates: 981 passed, 0 failed
        FAIL gates  did 981 units of work, below the floor of 984 in .claude/tests/floors.conf
        exit 1

  The scratch clones live under the session scratchpad
  (`C:\Users\ryanc\AppData\Local\Temp\claude\4cfd7d19cf4ea1ee\13cff595-70f1-48a0-9b4b-07e8e971562b\scratchpad\boot-{no,yes,mt}`,
  logs `gates-bootno.log`, `gates-bootyes.log`, `gates-bootyes-clean.log`
  beside them) and are disposable; `boot-mt` holds only the consumer's
  `project.conf` copied into a bare clone, for the `--audit` check in PO
  decision 3.
