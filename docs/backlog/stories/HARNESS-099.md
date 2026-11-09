---
id: HARNESS-099
title: The gates suite executes the same count in a bootstrapped project as in the template
slug: the-gates-suite-executes-the-same-count
epic: 
type: fix
status: in-review
phase: REVIEW
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
  the line names, in manifest order within each gate (`--list` groups the
  lines by gate, in `gate`-line order) - the ids agree; (b) the patterns agree,
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
  either path, titled `AC-7 (<label>): ...` for a non-empty `<label>` and
  `AC-7: ...` for an empty one (the prefix is `AC-7${1:+ ($1)}:`). The real
  manifest is called with an EMPTY label, so the template tree's three titles
  stay exactly `AC-7: the shipped project.conf holds the keep-when format line
  once, after skipped-when's and before BOOTSTRAPPED=` and so on; the fixture
  calls carry their labels. Their bodies and expected values are not touched
  (the one change is `$SHIP69` → `$2`, the `<conf>` argument). The `note:`
  printf is deleted. The template path is the three existing assertions over
  `<conf>`. The bootstrapped path is C-3. `ship69 "" "$SHIP69" "$REPO_ROOT"`
  is called once where the `if` was.
  *Amended in RED (test-developer, 2026-11-08).* As planned this block said
  `<label>` is `shipped` for the real manifest, giving titles that begin
  `AC-7 (shipped): the shipped project.conf ...`. That contradicts AC-5, which
  is frozen and requires the three template titles to begin
  `AC-7: the shipped project.conf holds the keep-when format line once`,
  `AC-7: and an example keep-when line in a comment` and
  `AC-7: the shipped project.conf carries no live keep-when line`, "with their
  text ... unchanged". The AC wins and the Contract is amended to fit it; no
  criterion moved.
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
  - *R-1 note (2026-11-09, AM-1):* (a) and (b) compare both sides after a
    stable sort by gate id (`LC_ALL=C sort -s -t"$_t" -k1,1`, `_t` a TAB),
    because `gates.sh --list` groups lines by gate. (a)'s title now ends
    `... to the gate it names, in manifest order within each gate`. Read
    together, (a) and (b) still require identical (id, pattern) sequences
    within each gate.
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
  the `ws.conf` path pin fails (`template`, and two of its three template
  assertions fail on a manifest with no format line - the third, "carries no
  live keep-when line", holds, because C-4's `ws.conf` has no live line;
  *amended in RED, 2026-11-08, from "its three template assertions fail",
  to match the step-1 run in `## Handoff`*) - that is AC-2 and AC-4 reproduced;
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

*Result (orchestrator, 2026-11-08, tree `2723914`):* ran with RED's recorded
expression, in this worktree, alone. Exactly the one predicted assertion went
red, the bootstrapped count pin (3 against 0), and the floor FAIL reads 991
against 998, which matches RED's corrected arithmetic: two fixture manifests
take the bootstrapped path in the template tree, so 6 assertions stop. The
restore was verified and `mutate.sh --check` was clean afterwards.

```
=== mutate: .claude/tests/gates.test.sh (1 line(s) changed by s/then boot69 "\$_p" "\$2" "\$3"; return 0/then return 0/) ===
=== mutate: running bash scripts/selftest.sh gates ===
    FAIL HARNESS-099 AC-2: the bootstrapped path of the shipped-manifest block executes exactly three assertions
         expected: 3
         actual:   0
gates: 991 passed, 1 failed
FAIL gates  did 991 units of work, below the floor of 998 in .claude/tests/floors.conf
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests_gates.test.sh.20261108T215303Z.1250066.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

*R-1 prediction for a re-run (test-developer, 2026-11-08; predicted, not
observed).* The result above stands for tree `2723914`. R-1 added `alt.conf`,
a third fixture on the bootstrapped path with its own count pin, so on the R-1
tree the same expression (checked with `sed` + `diff` on a copy: it still
matches exactly one line, now 3908) stops 9 assertions in the template tree and
fails TWO pins, the existing `HARNESS-099 AC-2: the bootstrapped path of the
shipped-manifest block executes exactly three assertions` and the new
`HARNESS-099 AC-2: the bootstrapped path executes exactly three assertions on a
manifest whose keep-when lines alternate between gates`, each `3` against `0`.
1002 - 9 = 993 executed, 2 failed: `gates: 991 passed, 2 failed` and
`FAIL gates  did 991 units of work, below the floor of 1002`. In a consumer
tree the real manifest takes the path too: 990 executed, 988 passed.

*Result on the R-1 tree (orchestrator, 2026-11-09, tree `fab1689`):* the
expression was re-run in this worktree, alone, and exactly matched the
prediction: both bootstrapped count pins went red, each 3 against 0, giving
`gates: 991 passed, 2 failed` and the floor FAIL at 991 against 1002. The
restore was verified, and `mutate.sh --check` was clean afterwards.

```
=== mutate: .claude/tests/gates.test.sh (1 line(s) changed by s/then boot69 "\$_p" "\$2" "\$3"; return 0/then return 0/) ===
=== mutate: running bash scripts/selftest.sh gates ===
    FAIL HARNESS-099 AC-2: the bootstrapped path of the shipped-manifest block executes exactly three assertions
         expected: 3
         actual:   0
    FAIL HARNESS-099 AC-2: the bootstrapped path executes exactly three assertions on a manifest whose keep-when lines alternate between gates
         expected: 3
         actual:   0
gates: 991 passed, 2 failed
FAIL gates  did 991 units of work, below the floor of 1002 in .claude/tests/floors.conf
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests_gates.test.sh.20261109T060131Z.1532306.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

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

*Result (orchestrator, 2026-11-08):* passed. Two `--no-hardlinks` scratch
clones were made of the branch at `2723914`. In the bootstrapped clone,
`BOOTSTRAPPED=yes` was set, the five required gates were given `printf ok`,
and five `evidence | <id> | -` lines were appended. The template clone was
left unmodified. Both ran `bash scripts/selftest.sh gates`. `--audit` passed
in the bootstrapped clone first. The two runs printed the same count, 998,
equal to the floor; there was no `FAIL gates` line and the `note:` line count
was 0 in both. The before side (981 against 984) is the PLANNED reproduction
in `## Notes`.

```
clones at: 2723914 2723914
== boot clone --audit:
Manifest audit passed.
audit rc=0
== boot clone: bash scripts/selftest.sh gates
boot rc=0
gates: 998 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (998 assertions executed, 998 declared).
== template clone: bash scripts/selftest.sh gates
tmpl rc=0
gates: 998 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (998 assertions executed, 998 declared).
```

**DV-3 (a real consumer's manifest, end to end - AC-1 and AC-3 after
AM-1). Owner: GATES.** In a `--no-hardlinks` scratch clone of the GATES tree,
copy `D:\mt-harness-refresh\.claude\harness\project.conf` (read-only, never
written) over the clone's `project.conf`, then run
`bash scripts/selftest.sh gates`. The run **must** print `gates: <N> passed,
0 failed`, where `<N>` is the template count, with no `FAIL gates` line and
exit 0. If the suite fails for a reason unrelated to this block, for example
an `--audit` cwd that does not exist in the upstream tree, paste which
assertion failed and why, and confirm that none of `AC-7 (...)` or
`HARNESS-099` are among the failures. The before side is the run at
`e1500a6` against the same manifest, recorded in `## Regressions` R-1. Added
2026-11-08 with AM-1, because DV-2's bootstrapped clone had no live
keep-when line.

*DV-2 and DV-3 on the R-1 tree (orchestrator, 2026-11-09, tree `fab1689`):*
both pass. Three `--no-hardlinks` scratch clones of the branch were run in
parallel:
- `g2t`: unmodified.
- `g2b`: bootstrapped exactly as DV-2 above.
- `g3m`: `D:\mt-harness-refresh\.claude\harness\project.conf` copied in, read
  and never written. It has 16 live keep-when lines that alternate between
  gates, the R-1 shape.

All three ran `bash scripts/selftest.sh gates` and print the same count,
1002, equal to the floor. None has a FAIL line, none prints the `note:`
line, and all exit 0. `g3m` is DV-3. Its before side, at `e1500a6`, was
`gates: 996 passed, 2 failed` (R-1), so the consumer this story unblocks now
passes.

```
clones at: fab1689 fab1689 fab1689
g3m live keep-when lines: 16
== g2t
g2t rc=0
gates: 1002 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (1002 assertions executed, 1002 declared).
== g2b
g2b rc=0
gates: 1002 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (1002 assertions executed, 1002 declared).
== g3m
g3m rc=0
gates: 1002 passed, 0 failed
assertion floors: all 1 suite(s) met their declared floor (1002 assertions executed, 1002 declared).
```

## Amendments

- **AM-1 (2026-11-08, AC-3(a), approved by the user in chat: "Yes, amend
  it").**
  - **Was:** "... prints one `keep-when: <pattern>` line per live line, under
    the gate the line names, in manifest order - the ids agree".
  - **Is:** "... under the gate the line names, in manifest order within each
    gate (`--list` groups the lines by gate, in `gate`-line order) - the ids
    agree".
  - **Why:** found by the GATES diff review and reproduced by the
    orchestrator (below). `scripts/gates.sh` 634-636 prints keep-when lines
    under each gate, looping over gates in `gate`-line order. So a manifest
    whose keep-when lines alternate between gates is printed grouped, not in
    file order. That is manga-translator's shape, and changing `gates.sh` is
    out of scope. Within one gate `--list` does keep file order, which is the
    order the first-match rule (346-357) depends on. As written, AC-3(a) was
    false of `gates.sh` for the consumer this story exists to unblock.
  - **Orchestrator's reproduction, independent of the reviewer's code:** a
    `--no-hardlinks` clone at `e1500a6`, with `D:\mt-harness-refresh`'s
    `project.conf` copied in. The live keep-when ids are listed in file order
    by an awk over the conf, and in `--list` order by an awk over `gate`
    rows and `keep-when:` lines:

        == MT file order (ids):
        unit unit coverage coverage coverage-core coverage-core integration integration unit unit coverage coverage coverage-core coverage-core integration integration
        == --list order (ids):
        unit unit unit unit coverage coverage coverage coverage coverage-core coverage-core coverage-core coverage-core integration integration integration integration

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
- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5**
  (2026-11-08), self-reported; `model: opus` passed. As planned.
- GREEN - `feature-developer`, planned `opus`, resolved **claude-opus-5-5**
  (2026-11-08), self-reported; `model: opus` passed. As planned.
- GATES - `feature-developer` (full gates run), planned `opus`, resolved
  **claude-opus-5-5** (2026-11-08), self-reported; `model: opus` passed. As
  planned.
- GATES - `feature-developer` (diff review, fresh), planned `opus`, resolved
  **claude-opus-5-5** (2026-11-08), self-reported. Verdict: fix 1 first (R-1).
- RED (return, R-1) - `test-developer`, planned `opus`, resolved
  **claude-opus-5-5** (2026-11-08), self-reported. As planned.
- GATES (after R-1) - `feature-developer` (full gates run), planned `opus`,
  resolved **claude-opus-5-5** (2026-11-09), self-reported. As planned.
- GATES (after R-1) - `feature-developer` (second diff review, fresh), planned
  `opus`, resolved **claude-opus-5-5** (2026-11-09), self-reported. Ship.
- GATES (after R-1) - `feature-developer` (`--changed` self-test), planned `opus`,
  resolved **claude-opus-5-5** (2026-11-09), self-reported. As planned.

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

All in `.claude/tests/gates.test.sh`, in the HARNESS-069 section, at the level
the defect lives: the suite's own shipped-manifest block, run by
`bash scripts/selftest.sh gates`. Every assertion is unconditional and runs in
every tree, except the real manifest's three, which run on whichever path the
real `project.conf` takes, and are three either way.

| Assertion (title) | Covers |
|---|---|
| `AC-7: the shipped project.conf holds the keep-when format line once, ...` / `AC-7: and an example keep-when line in a comment, ...` / `AC-7: the shipped project.conf carries no live keep-when line` - `ship69 "" "$SHIP69"` in the template tree (titles and bodies unchanged) | AC-5 |
| `AC-7: gates.sh --list attributes every live keep-when line ...` / `AC-7: and prints every live keep-when pattern verbatim` / `AC-7: every live keep-when pattern is a valid ERE ...` - the same call in a bootstrapped tree | AC-1, AC-3 |
| `AC-7 (template-fixture): ...` x3, on `tmpl.conf` | AC-2 (template path holds on a template-shaped manifest) |
| `HARNESS-099 AC-2: the template path of the shipped-manifest block executes exactly three assertions` (3) | AC-2 |
| `AC-7 (bootstrapped-fixture): ...` x3, on `boot.conf` (live line before `BOOTSTRAPPED=`, a `|`-less spacing variant, a `\+` pattern, a commented line) | AC-3 (a), (b), (c) |
| `HARNESS-099 AC-2: the bootstrapped path of the shipped-manifest block executes exactly three assertions` (3) | AC-2, AC-1 by construction |
| `AC-7 (whitespace-yes): ...` x3, on `ws.conf` (empty live set) | AC-4, AC-3 on the empty case |
| `HARNESS-099 AC-4: BOOTSTRAPPED=  yes  , read as gates.sh reads it, takes the bootstrapped path` (`bootstrapped`) | AC-4 |
| `HARNESS-099 AC-3 control: badere69 counts the invalid ERE ( once` (1, on `bad.conf`) | AC-3 control |
| `HARNESS-099 AC-3 control: kw69 reads live.conf's two live lines trimmed and not the comment` (`unit\tx\nunit\ty`) | AC-3 control |
| floors: `floor \| gates \| 998` (floors.conf 47) = `gates 998` (selftest.test.sh 538), the `selftest` suite's existing equality check | AC-5 |

AC-1 is about two whole runs, not one assertion; it is measured (Handoff,
"Bootstrapped-tree count") and owned end to end by DV-2.

*R-1 note (2026-11-09):* the suite now also writes `alt.conf`, a
bootstrapped fixture whose live keep-when lines alternate unit, cov, unit,
and runs `ship69 alternating-fixture` on it with its own count pin: 3 + 1
assertions. Before the sort, its (a) and (b) failed (1000 passed, 2
failed); with the sort the suite gives 1002 passed, 0 failed. The floor is
`floor | gates | 1002` (floors.conf 47) and `gates 1002` (selftest.test.sh
538), replacing the 998 above.

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

Written by `test-developer`, resolved **claude-opus-5-5** (Opus 5.5), 2026-11-08,
dispatched by the orchestrator with no model override stated. Windows host,
local, every number below.

**Command.** `bash scripts/selftest.sh gates` (about 10 minutes here).

**Files touched.**
- `.claude/tests/gates.test.sh` - the shipped-manifest block (now 3805-3946)
  rewritten as `ship69` plus readers, fixtures, pins and controls. Nothing
  after it changed: lines from `mkdir -p "$M69/src/sub"` (now 3947) to the end
  are byte-identical to `main` (checked with `diff`). The HARNESS-080 blocks,
  the `--audit` trio (now 3959-3962) and the goldens keep their text.
- `.claude/tests/floors.conf` - line 47 `984` -> `998`, and a HARNESS-099
  paragraph appended to the comment block (the end of the file).
- `.claude/tests/selftest.test.sh` - line 538 `gates 984` -> `gates 998`.
- `docs/backlog/stories/HARNESS-099.md` - `## Test plan`, this handoff, and two
  in-place Contract amendments (C-2, C-7; below).
- Not touched: `scripts/gates.sh`, `.claude/harness/project.conf`,
  `.claude/harness/VERSION` (GREEN's).

**C-5 ordering: the functions moved up.** `cwds69` (with its HARNESS-080
comment) and `audit69` moved, bodies byte-identical, to directly after
`live69()` (now 3837 and 3848); the new `list69` is beside them (3850), then
`kw69` 3854, `kwlist69` 3865, `badere69` 3873, `boot69` 3884 (the
bootstrapped path's three assertions), `ship69` 3900, the real-manifest call
`ship69 "" "$SHIP69" "$REPO_ROOT"` 3916, then `live.conf` and its existing
control, then C-4's fixtures, pins and controls (3918-3946). Callers checked:
`audit69`'s three callers (now 3950, 3955, 3959) keep their signature
`audit69 <conf> <source root>`; `kwlist69` uses stdout only (`g69` discards
stderr).

**Contract amendments made in RED (in place, with reasons there).**
- **C-2:** the real manifest is called with an EMPTY label, and the prefix is
  `AC-7${1:+ ($1)}:`, so the template tree's three titles stay `AC-7: the
  shipped project.conf ...` exactly. As planned, `shipped` would have made them
  `AC-7 (shipped): ...`, which contradicts frozen AC-5 ("titles beginning
  `AC-7: the shipped project.conf holds ...`", "text ... unchanged"). No AC
  moved. The fixture calls carry labels (`template-fixture`,
  `bootstrapped-fixture`, `whitespace-yes`). Template bodies' one change:
  `$SHIP69` -> `$2`.
- **C-7:** step 1 fails TWO of `ws.conf`'s three template assertions, not
  three: C-4's `ws.conf` has no live line, so "carries no live keep-when line"
  holds. That is measured (below), not a defect.

**Step 1 - the defect reproduced (AC-2, AC-4).** `ship69` with today's
behaviour inside it: the literal `grep -qE '^BOOTSTRAPPED=yes'` decision and
a bootstrapped path that printed the HARNESS-070 `note:` and asserted
nothing, plus every C-4 fixture, pin and control. Attest record:

    command:  bash scripts/selftest.sh gates
    tree:     3a614a03154501cfb53f6c477f3fb56e0946bfe5
    status:   ok
    exit:     1
    duration: 652s
    last:     1 of 1 harness suite(s) FAILED.
    log:      .claude/state/attest-logs/20261108T201721Z.1152954.log

The FAIL lines, verbatim from that log (117-129):

    note: project.conf is this project's own (BOOTSTRAPPED=yes), not the template; its keep-when text is not asserted (HARNESS-070)
    FAIL HARNESS-099 AC-2: the bootstrapped path of the shipped-manifest block executes exactly three assertions
         expected: 3
         actual:   0
    FAIL AC-7 (whitespace-yes): the shipped project.conf holds the keep-when format line once, after skipped-when's and before BOOTSTRAPPED=
         expected: yes
         actual:   no (keep-when format at none, skipped-when format at none, BOOTSTRAPPED at none)
    FAIL AC-7 (whitespace-yes): and an example keep-when line in a comment, between the format line and BOOTSTRAPPED=
         expected: yes
         actual:   no (example at none)
    FAIL HARNESS-099 AC-4: BOOTSTRAPPED=  yes  , read as gates.sh reads it, takes the bootstrapped path
         expected: bootstrapped
         actual:   template

    gates: 991 passed, 4 failed

Those are the right failures: the count pin is 3 against 0 because the
bootstrapped path ran nothing (the `note:` printed once, for `boot.conf`);
`BOOTSTRAPPED=  yes  ` went down the template path. The template-path count
pin and both AC-3 controls passed there (995 executed = 984 + 3 + 1 + 0 + 1 +
3 + 1 + 2).

**Step 2 - C-3 written: green.** Floors already set to 998 (the prediction);
attest record on the final tree:

    run:      2026-11-08T20:29:52Z
    command:  bash scripts/selftest.sh gates
    tree:     8819b3d31de55b894e7c145740808774962936eb
    status:   ok
    exit:     0
    duration: 572s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261108T202952Z.1175278.log

    gates: 998 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (998 assertions executed, 998 declared).

No `FAIL` and no `note: project.conf` line in that log.
`attest.sh check -- bash scripts/selftest.sh gates` reports `fresh` after the
story edits (the story is not in the hashed tree).

**Measured floor: 998 EXECUTED** (template tree), written to floors.conf 47
and selftest.test.sh 538.

**Bootstrapped-tree count, measured (not the worktree).** A
`git clone --no-hardlinks` of this tree under the session scratchpad
(`C:\Users\ryanc\AppData\Local\Temp\claude\4cfd7d19cf4ea1ee\13cff595-70f1-48a0-9b4b-07e8e971562b\scratchpad\h099\boot-yes`),
the three changed test files copied in, its own `project.conf` given DV-2's
clean procedure (line 307 -> `BOOTSTRAPPED=yes`, `printf ok` on lint,
typecheck, unit, coverage, build, `evidence | <id> | -` for each appended);
`bash scripts/gates.sh --audit` there: `Manifest audit passed.`, exit 0. Then
`bash scripts/selftest.sh gates` there (log `...\scratchpad\h099\boot-yes.log`):

    gates: 998 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (998 assertions executed, 998 declared).
    exit 0

No `note:` line. This is evidence toward AC-1; DV-2 is still GATES's and must
be run on the GATES tree.

**Admissibility.**

    command:  bash scripts/gates.sh --fast
    tree:     8819b3d31de55b894e7c145740808774962936eb
    exit:     0
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261108T203946Z.1215803.log

`bash scripts/mutate.sh --check`: `mutate: no stranded mutation; nothing of a
previous run is in the tree.`

**Shape GREEN inherits (stated as fact).** No production module is imported;
the suite calls only `scripts/gates.sh --list` and `--audit` in `F69`, which
this story does not change. Helpers in the suite, all of them test code:
`ship69 <label> <conf> <source root>` (sets global `SHIP69_PATH`),
`boot69 <prefix> <conf> <source root>`, `kw69 <conf>`,
`kwlist69 <conf> <source root>`, `list69 <conf> <source root>`,
`badere69 <conf>`. Not constrained: nothing in production.

**What GREEN must do.** Bump `.claude/harness/VERSION` `117 (2026-11-08)` ->
`118 (<date>)` and nothing else; verify the no-op by running
`bash scripts/selftest.sh gates` (expect `gates: 998 passed, 0 failed`, floor
met) and paste the summary. No test, floor or Contract-listed file other
than VERSION is GREEN's to touch.

**Tests that passed on arrival.** The template-path count pin, the three
`template-fixture` assertions and both AC-3 controls passed in step 1. They are
new assertions over new test helpers written in the same step (no existing
implementation is being pinned); the count pin is earned by DV-1's mutation
(its bootstrapped twin goes red on the same counter), and the controls were
measured outside the framework (table). Not separately mutation-probed in RED.

**Negative controls - expected values.** Measured outside the framework:
`kw69`/`badere69`/`live69` sourced from the block into a plain bash, run on
copies of the fixtures under the scratchpad (`...\scratchpad\h099\ctl`).
Then confirmed inside the suite in both runs (they passed in step 1 and
step 2).

| Control | Threshold / expected | Candidate range | Measured outside framework | In suite |
|---|---|---|---|---|
| `badere69 bad.conf` (`keep-when \| unit \| (`) | exactly 1 | 0 = reader blind to exit 2; 1 = correct | 1 | pass (step 1, step 2) |
| `badere69 live.conf` (valid `x`, `y`) | 0 (not asserted; sanity) | - | 0 | n/a |
| `kw69 live.conf` | `unit\tx\nunit\ty` | comment `z` included, untrimmed fields, or `y` missed = wrong | `unit\tx\nunit\ty` (od -c) | pass |
| `kw69 boot.conf` (C-4's stated value; not a separate assertion) | `unit\tWindows fatal exception` then `cov\tUnknown C\+\+ exception` | - | as expected | via (a)/(b) |
| `kw69` on `keep-when \| unit \| a\|b ` (a `\|` in a pattern) | `unit\ta\|b` | - | `unit\ta\|b` | n/a (probe of `rest 3` parity) |
| `live69 live.conf` (existing) | 2 | - | 2 | pass |

**Deferred verifications - declined, GATES owns both.** I cannot run DV-1 or
DV-2 in RED: DV-1 has to be made against the committed shape, and DV-2 against
the GATES tree. For DV-1, the expression against the shape as built (line 3905
is the only line it matches; checked with `sed` + `diff` on a copy):

    bash scripts/mutate.sh .claude/tests/gates.test.sh 's/then boot69 "\$_p" "\$2" "\$3"; return 0/then return 0/' -- bash scripts/selftest.sh gates

Predicted red, template tree: two fixture manifests run the bootstrapped path
here (`boot.conf`, `ws.conf`; the real manifest is the template), so 6
assertions stop executing. The `ws.conf` path pin still passes (the path is set
before `boot69` is called), and exactly one assertion fails:

    FAIL HARNESS-099 AC-2: the bootstrapped path of the shipped-manifest block executes exactly three assertions
         expected: 3
         actual:   0
    gates: 991 passed, 1 failed
    FAIL gates  did 991 units of work, below the floor of 998 in .claude/tests/floors.conf

(998 - 6 = 992 executed, 1 failed, so 991 passed; selftest.sh's "units of
work" is the PASSED count, which is why it is 991, not 992 - DV-1's
"<N-9>" would be wrong here. In a consumer tree the real manifest also takes
the path: 998 - 9 = 989 executed, 988 passed.) These are predictions, not
observations.

**Discovered.** The planned C-2 title (`shipped`) contradicted AC-5; amended,
not routed around. Nothing else changes the approach.

### GREEN

Written by `feature-developer`, resolved **claude-opus-5-5** (Opus 5.5),
2026-11-08, no model override stated in the dispatch.

GREEN changed one line: `.claude/harness/VERSION` line 34 `117 (2026-11-08)`
-> `118 (2026-11-08)`. Nothing else - no test, floor, script or other
Contract-listed file. Tests ran frozen.

    command:  bash scripts/selftest.sh gates
    tree:     706f4a51c29d1d50a241b21fed01fc154107fcf5
    exit:     0
    duration: 720s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261108T213638Z.1219037.log

    gates: 998 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (998 assertions executed, 998 declared).

In that log, 0 lines begin with `FAIL` and 0 lines contain `note: project.conf`.
That matches RED's step-2 summary (998/0, floor 998). The handoff's control
table rows asserted in the suite all passed. GREEN did not re-measure them
outside the framework, because no production module changed and nothing
measured differently.

    command:  bash scripts/gates.sh --fast
    tree:     706f4a51c29d1d50a241b21fed01fc154107fcf5
    exit:     0
    duration: 1s
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261108T214854Z.1247206.log

### R-1 (return to RED)

Written by `test-developer`, resolved **claude-opus-5-5** (Opus 5.5),
2026-11-08, no model override stated in the dispatch. Remit: R-1 only.

**Command:** `bash scripts/selftest.sh gates`.

**What changed, in `.claude/tests/gates.test.sh` only (plus the floors):**
- New fixture `$M69/alt.conf`, after the `boot.conf` count pin:
  `BOOTSTRAPPED=yes`, `gate`/`evidence` lines for `unit` and `cov`, then live
  keep-when lines `unit | Windows fatal exception`, `cov | Unknown C\+\+
  exception`, `unit | Segmentation fault`. `ship69 alternating-fixture` on it
  between `n0`/`n1`, then one count pin, `HARNESS-099 AC-2: the bootstrapped
  path executes exactly three assertions on a manifest whose keep-when lines
  alternate between gates` (3). That is 4 new unconditional assertions.
- `boot69`: `_kw` and `_kl` are each piped through `LC_ALL=C sort -s
  -t"$_t" -k1,1` (`_t` a local TAB) before (a) and (b) compare them - stable,
  so manifest order within each gate is kept (AM-1). `LC_ALL=C` so both sides
  sort identically on any host.
- Title of (a) changed: `... to the gate it names, in manifest order` ->
  `... in manifest order within each gate`, to say what it now asserts. (b)
  and (c) titles unchanged. The template-path titles (AC-5) are untouched.
  Nothing else references the old (a) title (grepped).

**Red, then green** - verbatim in `## Regressions` R-1 "Earned": unsorted
comparison `gates: 1000 passed, 2 failed` (the new fixture's (a) and (b)
only); sorted `gates: 1002 passed, 0 failed`, floor 1002.

**Mutation:** `bash scripts/mutate.sh .claude/tests/gates.test.sh 's/ |
LC_ALL=C sort -s -t"\$_t" -k1,1//g' -- bash scripts/selftest.sh gates` - one
line changed, the alternating fixture's (a) and (b) red and nothing else,
`gates: 1000 passed, 2 failed`, restore verified, `--check` clean. Output in
`## Regressions`.

**DV-1:** its expression still matches exactly one line (now 3908). Its
predicted numbers change with the new fixture (991 passed, 2 failed, floor
1002) - written as a prediction under DV-1; the recorded result for `2723914`
is left as observed. DV-3 not run (GATES owns it); `D:\mt-harness-refresh` not
touched.

**Floors:** `.claude/tests/floors.conf` 47 and `.claude/tests/selftest.test.sh`
538: gates 998 -> 1002, with an R-1 paragraph appended to floors.conf's
comment block. Measured, local, Windows host: template tree `gates: 1002
passed, 0 failed` (1002 executed). Bootstrapped `--no-hardlinks` scratch clone
of `e1500a6` with these three files copied in, DV-2's procedure
(`BOOTSTRAPPED=yes`, five required gates `printf ok`, five `evidence | <id> |
-`; `--audit` printed `Manifest audit passed.`, rc 0): `gates: 1002 passed, 0
failed`, rc 0, 0 `note: project.conf` lines - **equal**. (That clone has no
live keep-when line in its own manifest, so its (a)/(b) on the real manifest
compare empty with empty; the alternating shape is covered by `alt.conf`, and
end to end by DV-3.)

**Files touched:** `.claude/tests/gates.test.sh`, `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh`, `docs/backlog/stories/HARNESS-099.md`
(`## Deferred verifications` DV-1 note, this handoff part, `## Regressions` R-1
Earned).

**What GREEN does:** nothing beyond verifying. VERSION is already 118; no
production file moved. Run the command above and confirm `gates: 1002 passed,
0 failed`.

**Final records (attested, local, Windows host):**

    command:  bash scripts/selftest.sh gates
    tree:     1129f14dbbdc438c4e7c381af665897465aa619d
    exit:     0
    duration: 422s
    last:     1 harness suite(s) passed.
    log:      .claude/state/attest-logs/20261108T235714Z.1446620.log

    gates: 1002 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (1002 assertions executed, 1002 declared).

    command:  bash scripts/gates.sh --fast
    tree:     1129f14dbbdc438c4e7c381af665897465aa619d
    exit:     0
    duration: 1s
    last:     All required gates passed (0 ran, 5 unconfigured, 0 known).
    log:      .claude/state/attest-logs/20261109T000418Z.1469010.log

## Regressions

- **R-1 (2026-11-08, found at GATES → REVIEW by the fresh diff review).**
  - **What is wrong:** `boot69`'s assertions (a) and (b) compare `kw69`
    (live keep-when lines in file order) with `kwlist69` (lines in
    `gates.sh --list` order). `--list` groups lines by gate, so on any
    manifest whose keep-when lines alternate between gates, (a) and (b) fail
    on a correct manifest. manga-translator's real manifest is that shape: 16
    lines alternating unit / coverage / coverage-core / integration. The
    reviewer predicted `gates: 996 passed, 2 failed` there, which still blocks
    the refresh this story exists to unblock.
  - **How it was missed:** no fixture alternates between gates (`boot.conf`
    has one `unit` line, then one `cov` line). DV-2's bootstrapped clone had
    no live keep-when line, so (a) and (b) compared empty with empty.
  - **What it should assert instead (AM-1):** both sides are stably sorted
    by gate id before comparing, so ids and patterns agree in file order
    within each gate. A new fixture with lines alternating between gates
    (for example unit, cov, unit) pins it, and must fail against the current
    comparison. DV-2 is strengthened to run with manga-translator's real
    manifest copied in (DV-3).
  - **Earning it:** the corrected comparison passes on arrival against an
    alternating fixture only if it is right. RED shows the new fixture's (a)
    and (b) red against the current unsorted comparison, then green after the
    sort. RED also runs one `mutate.sh` mutation removing the sort and
    watches the alternating fixture's assertion go red. The output is pasted
    here.
  - **Earned (test-developer, return to RED, 2026-11-08, Windows host,
    local).** Fixture `alt.conf` (live keep-when lines unit, cov, unit) and
    its count pin added first, against the UNSORTED comparison - the defect
    reproduced, (a) and (b) for the new fixture red, nothing else:

        FAIL AC-7 (alternating-fixture): gates.sh --list attributes every live keep-when line to the gate it names, in manifest order
             expected: unit
             cov
             unit
             actual:   unit
             unit
             cov
        FAIL AC-7 (alternating-fixture): and prints every live keep-when pattern verbatim
             expected: Windows fatal exception
             Unknown C\+\+ exception
             Segmentation fault
             actual:   Windows fatal exception
             Segmentation fault
             Unknown C\+\+ exception
        gates: 1000 passed, 2 failed

    Then both sides stably sorted by gate id (`LC_ALL=C sort -s -t"$_t"
    -k1,1`): `gates: 1002 passed, 0 failed`, floor 1002 met. Then the sort
    removed by mutation, the corrected file restored and verified:

        === mutate: .claude/tests/gates.test.sh (1 line(s) changed by s/ | LC_ALL=C sort -s -t"\$_t" -k1,1//g) ===
        === mutate: running bash scripts/selftest.sh gates ===
            FAIL AC-7 (alternating-fixture): gates.sh --list attributes every live keep-when line to the gate it names, in manifest order within each gate
                 expected: unit
                 cov
                 unit
                 actual:   unit
                 unit
                 cov
            FAIL AC-7 (alternating-fixture): and prints every live keep-when pattern verbatim
                 expected: Windows fatal exception
                 Unknown C\+\+ exception
                 Segmentation fault
                 actual:   Windows fatal exception
                 Segmentation fault
                 Unknown C\+\+ exception
        gates: 1000 passed, 2 failed
        FAIL gates  did 1000 units of work, below the floor of 1002 in .claude/tests/floors.conf
        assertion floors: 0 of 1 suite(s) met their declared floor.
        === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests_gates.test.sh.20261108T234612Z.1422539.bak) ===
        mutate: no stranded mutation; nothing of a previous run is in the tree.

- **R-1 before side, whole suite (orchestrator, 2026-11-08):** a
  `--no-hardlinks` clone at `e1500a6` with `D:\mt-harness-refresh`'s
  `project.conf` copied in (read-only), `bash scripts/selftest.sh gates`. It
  confirms the reviewer's prediction exactly, and it is DV-3's before side:

        FAIL AC-7: gates.sh --list attributes every live keep-when line to the gate it names, in manifest order
        FAIL AC-7: and prints every live keep-when pattern verbatim
    gates: 996 passed, 2 failed
    FAIL gates  did 996 units of work, below the floor of 998 in .claude/tests/floors.conf

- **R-1 RED verified by the orchestrator (2026-11-09):** `attest.sh check`
  said `fresh` for `bash scripts/selftest.sh gates` (exit 0,
  `gates: 1002 passed, 0 failed`, no FAIL line, log
  `20261108T235714Z.1446620.log`) and for `bash scripts/gates.sh --fast`
  (exit 0). Diff read: `boot69` sorts both sides stably by gate id (title (a)
  now ends "within each gate"), plus the new `alt.conf` fixture and its count
  pin. Floors 998 → 1002 in both files. `mutate.sh --check` is clean, and the
  Earned block is pasted above.

## Diff review

### First review (2026-11-08, at `e1500a6`)

Fresh `feature-developer` with the `diff-review` skill, resolved
**claude-opus-5-5**, no override. It changed no file in the worktree.
Condensed; the finding is kept whole.

- **Checked and held:**
  - Lines 1-3804, and everything from `mkdir -p "$M69/src/sub"` to the end,
    are byte-identical to `3c79f70` (`cmp`), so the `--audit` trio and the
    HARNESS-080 blocks are unchanged.
  - The readers hold under CRLF, surrounding whitespace, `|` in a pattern, a
    leading `-` (`-e`), an empty live set, and a missing `BOOTSTRAPPED=`.
  - `list69` copies the conf as `audit69` does. `gates.sh` finds ROOT from
    its own location (`gates.sh:62`), so `--list` in F69 cannot read the real
    conf.
  - The count pins use `_lib.sh`'s own counters, and `assert_eq` adds exactly
    one to `_pass` or `_fail`.
  - The floors.conf paragraph matches DV-1/DV-2.
- **Must fix 1:** a real consumer's manifest fails (a) and (b).
  - **Problem:** `--list` groups keep-when lines by gate (`gates.sh`
    634-636), and manga-translator's 16 lines alternate between gates. Run
    against a scratch copy, the diff's own readers disagree on both ids and
    patterns; (c) holds. The predicted result is `gates: 996 passed, 2
    failed`.
  - **Fix:** stable-sort both sides by gate id, and add an alternating
    fixture. This is a test change, so it returns to RED, and AC-3(a)'s "in
    manifest order" is an `## Amendments` question.
  - **Not checked:** the reviewer did not run the whole suite on that
    manifest.

Verdict: fix 1 first.

*Orchestrator (2026-11-08):* reproduced independently (AM-1). The user
approved the amendment, and the story returns to RED (R-1).

### Second review (2026-11-09, at `31a1a52`, after R-1)

Fresh `feature-developer` with the `diff-review` skill over the whole diff
`3c79f70..31a1a52`, resolved **claude-opus-5-5**, no override. It changed no
file in the worktree and ran nothing there. Condensed; its reproductions and
numbers are kept.

- **Independent run on manga-translator's real manifest:** a scratch clone
  at `31a1a52` with `D:\mt-harness-refresh`'s `project.conf` copied in (16
  live keep-when lines alternating between gates; read-only). It gave
  `gates: 1002 passed, 0 failed`, the floor was met (1002 of 1002), rc 0,
  and there was no FAIL or `note:` line.
- **The sort is stable and locale-proof.** Git Bash and ubuntu CI both have
  GNU coreutils `sort` (8.32 here), so `-s` is supported. It was checked on
  lines that reorder without `-s`. `-k1,1` keys on field 1 only, so a TAB in
  a pattern does not affect it. `LC_ALL=C` rules out locale collation of ids.
- **The sort hides no misattribution.** (a) and (b) compare columns 1 and 2
  of the same sorted sequences. Passing both requires identical (id,
  pattern) pairs in the same within-gate order, which is the order the
  first-match rule depends on. Only the meaningless cross-gate order is
  dropped. A swap A:Y/B:X now shows under (b) rather than (a); only how the
  failure reads changes.
- **`kwlist69` parses correctly.** On the real `--list` output every
  indented line starts with 30 spaces and its own label, and only
  `^ +keep-when: ` emits a pair. A 13-character id (`coverage-core`) still
  reads correctly as `$1`. The rows that `--list` prints before the gate loop
  set no false id.
- **Duplicate gate ids, and a keep-when naming no configured gate:** (a)
  fails, and `--audit` fails too, so there is no disagreement on any
  manifest the audit accepts.
- **One case the audit accepts:** `keep-when |  | x` with an empty id. It
  passes `--audit`, `--list` omits it, and (b) fails. The suite is reporting
  a genuinely dead line, so this is a gap in `--audit`, and `gates.sh` is out
  of scope here.
- **The readers match `gates.sh`'s parser:** the same live-line test, the
  same trimming, and the same handling of a line with no `|` or with an
  empty pattern.
- **Count pins cannot be fooled:** they read `_lib.sh`'s counters in the
  calling shell, `ship69` does not run in a subshell, and DV-1 shows both
  bootstrapped pins go red.
- **floors.conf numbers add up:** 984 + 14 = 998, and + 4 = 1002. Counting
  the `assert_eq` calls in the diff gives the same. There is no other
  984/998 pin in tests, scripts, `.github` or `docs/wiki`. `floors.conf:47`
  equals `selftest.test.sh:538` (1002), and VERSION is 118.
- **Nice to have 1:** C-3 and the Test plan described the suite as it was
  before R-1.

Verdict: Ship.

*Orchestrator (2026-11-09):* Nice to have 1 was taken, story only: dated R-1
notes were added to C-3 and to the Test plan. The empty-id `--audit` gap is
out of scope here; it is offered to the user as a follow-up.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-09T06:35:22Z
    commit: fab1689
    tree:   5dc4e7361d7741cd4c5008678b393bc48508d2a7
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

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
- RED verified by the orchestrator (2026-11-08): the step-1 log
  `20261108T201721Z.1152954.log` shows exactly the four predicted FAILs
  (the bootstrapped count pin 3 vs 0, two `AC-7 (whitespace-yes)` template
  assertions, the AC-4 path pin), `gates: 991 passed, 4 failed`. `attest.sh
  check` said `fresh` for the final `bash scripts/selftest.sh gates` (exit 0,
  `gates: 998 passed, 0 failed`, no FAIL or `note:` line, log
  `20261108T202952Z.1175278.log`) and for `bash scripts/gates.sh --fast`
  (exit 0, 0 ran), so neither was re-run. Diff read: `gates.test.sh` lines
  1-3804 and everything from `mkdir -p "$M69/src/sub"` to the end are
  byte-identical to `main`, so only the shipped-manifest block changed. The
  real call is `ship69 "" "$SHIP69" "$REPO_ROOT"`, so the template titles keep
  their `AC-7: ` text. The DV-1 needle matches one line (3905).
  - **C-2 amendment reproduced:** AC-5 (frozen) requires the three template
    titles to begin `AC-7: the shipped project.conf ...`, so C-2's planned
    `AC-7 (shipped):` prefix could not satisfy it. An empty label giving
    `AC-7:` is the only form that keeps both. Accepted. The C-7 amendment
    (two of `ws.conf`'s template assertions fail, not three, because it has no
    live keep-when line) matches the step-1 log above.
- GREEN verified by the orchestrator (2026-11-08): `attest.sh check` said
  `fresh` for `bash scripts/selftest.sh gates` (exit 0,
  `gates: 998 passed, 0 failed`, no FAIL line, log
  `20261108T213638Z.1219037.log`) and for `bash scripts/gates.sh --fast`
  (exit 0, 0 ran, log `20261108T214854Z.1247206.log`), so neither was re-run.
  Diff read: GREEN changed only `VERSION` (117 → 118) and the story.
- GATES verified by the orchestrator (2026-11-08): DV-1 and DV-2 were run
  by me before and beside `gates.sh`, with results pasted in their blocks.
  The full run was dispatched; `attest.sh check -- bash scripts/gates.sh`
  said `fresh` (exit 0, 2 s, log `20261108T222155Z.1297391.log`, verdict `All
  required gates passed (0 ran, 7 unconfigured, 0 known).`), so it was not
  re-run. The developer changed no file.
- GREEN after R-1 (orchestrator, 2026-11-09): a verified no-op, so it was
  run by the orchestrator, not dispatched. `git diff main` outside the tests
  touches only `VERSION` (already `118`). `bash scripts/attest.sh -- bash
  scripts/selftest.sh gates`: exit 0, `gates: 1002 passed, 0 failed`, no FAIL
  line, 1065 s, log `20261109T001702Z.1476575.log`. `bash scripts/attest.sh --
  bash scripts/gates.sh --fast`: exit 0, 0 ran, log
  `20261109T003449Z.1506741.log`. Both checks are `fresh`.
- GATES after R-1 verified by the orchestrator (2026-11-09): DV-1, DV-2 and
  DV-3 were re-run on `fab1689` and are pasted in `## Deferred
  verifications`. DV-1 is 991/2 as predicted; DV-2 and DV-3 are 1002/0 in all
  three clones, manga-translator's real manifest included. The full run was
  dispatched; `attest.sh check -- bash scripts/gates.sh` said `fresh` (exit 0,
  4 s, log `20261109T063519Z.1629456.log`, verdict `All required gates
  passed (0 ran, 7 unconfigured, 0 known).`), so it was not re-run.
- Diff review at GATES → REVIEW: the first review (`e1500a6`) said fix 1
  first, which became R-1. The second review (`31a1a52`) said `Verdict:
  Ship.` and independently ran manga-translator's manifest at 1002/0. Both
  are in `## Diff review`.
- Self-test at GATES → REVIEW (2026-11-09): `selftest-needed: run`.
  `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` was dispatched,
  detached, and ran alone. `attest.sh check` said `fresh`, `exit: 0`,
  `last: 11 harness suite(s) passed.`, `duration: 1568s`, log
  `20261109T070616Z.1660566.log`. Header:
  `selftest: --changed — 11 of 34 suite(s) selected: boundaries doctor gates grep-count host-load mutate refresh run-lock selftest sigpipe worktree`.
  The floors were met for all 11 (2927 executed, 2927 declared), and the log
  has no FAIL line. `--changed` is enough: no script changed, so case (b)
  does not apply.
- Follow-up offered to the user: `--audit` accepts `keep-when |  | x` (an
  empty gate id), a line `gates.sh` never applies. Found by the second
  review; `gates.sh` is out of scope here.
