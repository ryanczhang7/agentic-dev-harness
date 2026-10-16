# Harness mutation audit, 2026-10-15

## Scope

The harness's own enforcement and planning scripts, at commit `c78917d`
(origin/main, release after HARNESS-051/058). The previous audit,
`enforcement-mutants-2026-09-15.md`, ran at `7b6f6db` and left `plan.sh` out
entirely; `git log 7b6f6db..c78917d --stat` shows these files changed since:

| File | Commits since 7b6f6db | Oracle suite | In scope as |
|---|---|---|---|
| `scripts/plan.sh` | 11 | `plan` | whole file (never audited) |
| `scripts/mutate.sh` | 3 | `mutate` | whole file |
| `scripts/check-grep-count.sh` | 3 | `grep-count` | whole file, plus real-tree probes |
| `scripts/check-sigpipe.sh` | 3 | `sigpipe` | whole file, plus real-tree probes |
| `scripts/gates.sh` | 16 | `gates` | hunks changed since 7b6f6db |
| `scripts/check-boundaries.sh` | 8 | `boundaries` | hunks changed since 7b6f6db |
| `.claude/hooks/phase-guard.sh` | 6 | `phase-guard`, `worktree` | hunks changed since 7b6f6db |
| `.claude/hooks/lib.sh` | 15 | `lib`, plus `phase-guard` / `worktree` / `gates` where the hunk is theirs | hunks changed since 7b6f6db |

Left out on purpose: `refresh-harness.sh` (11 commits), `doctor.sh` (10),
`new-story.sh` (8), `selftest.sh`, `ci-local.sh`, `phase.sh`, `classify.sh`,
`task.sh`, `gate-reminder.sh`, `run-lock.sh`. They are a later round's scope.

No `mutation` gate is configured for the harness itself, so every mutant was
chosen by hand and run through `scripts/mutate.sh` against the one suite that
holds the targeted assertion (a dependent suite was added where the mutated
hunk is exercised only there). This round deliberately ran more than the
per-story budget in `rules.md`: it is the `/audit-mutations` round that budget
defers to.

## Decided

1. **`mutate.sh --check` must see sentinels whose names start with `.`**, and
   `mutate.sh` must refuse sed expressions that write or execute. Rests on F1
   and F5. Filed as HARNESS-059 (with survivor M11).
2. **Both tree guards' blindness after a quoted unbalanced `(` inside `"$(...)"`
   is a defect in the shared plumbing, not in one guard**, and is fixed once for
   both, with a real-tree probe as the acceptance test. Rests on F2. The
   backslash-continuation miss in `check-grep-count.sh` (F3) rides with it,
   because it is the same guard's scan loop. Filed as HARNESS-060.
3. **`check-sigpipe.sh`'s reader recognition is widened only to shapes a probe
   showed it missing** (assignment prefix, `-e PAT` before `-q`, `|&`), and its
   two unpinned existing shapes get fixtures. Rests on Q01-Q03, S03, S06. Filed
   as HARNESS-061, ordered after HARNESS-060 because both write
   `check-sigpipe.sh`.
4. **The other survivors are missing tests, not wrong code**, and are filed as
   test-only chores: `check-boundaries.sh` matching precision (HARNESS-062),
   phase-guard's state restore after a cross-worktree judgement (HARNESS-063),
   `gates.sh --story` validation (HARNESS-064), `plan.sh` edges (HARNESS-065).
   Each story's tests are earned by the audit mutant named in it going red.
5. **No story for the survivors judged equivalent or low impact** (C05, C06,
   C11, S04, L13, B09). Reasons below. A later round that shows one is not
   equivalent reopens it.

## Evidence

All mutants ran through `bash scripts/mutate.sh FILE 'EXPR' -- bash suites.sh
SUITE...` (a scratch wrapper that runs each named `.claude/tests/<suite>.test.sh`
and stops at the first failure). Every run logged `restored (verified)`, except
the one interrupted run described in F1. `mutate.sh` refuses to mutate itself,
so the `mutate.sh` mutants (M01-M11) ran under a byte-identical copy of it
placed under `.claude/state/selfmut/` (checked with `cmp` before each run and
removed afterwards), mutating the real `scripts/mutate.sh` that
`mutate.test.sh` exercises.

Baselines, unmutated, on this machine (Windows 11, Git Bash):
`boundaries 125/0 (352s)`, `phase-guard 378/0 (536s)`, `lib 283/0 (60s)`,
`worktree 73/0 (58s)`, `gates 671/0 (338s)`, `plan 262/0`, `mutate 189/0`,
`grep-count 20/0`, `sigpipe 82/0`.

### Per-file results

| File | Mutants | Killed | Survived | Survivors |
|---|---|---|---|---|
| `check-grep-count.sh` | 11 | 7 | 4 | C05, C06, C07, C11 |
| `check-sigpipe.sh` | 10 | 7 | 3 | S03, S04, S06 |
| `mutate.sh` | 11 | 10 | 1 | M11 |
| `plan.sh` | 12 | 8 | 4 | P04, P05, P10, P12 |
| `check-boundaries.sh` | 10 | 5 | 5 | B04, B05, B07, B08, B09 |
| `lib.sh` (changed hunks) | 13 | 12 | 1 | L13 |
| `phase-guard.sh` (changed hunks) | 6 | 5 | 1 | G03 |
| `gates.sh` (changed hunks) | 14 | 13 | 1 | A13 |
| **total** | **87** | **67** | **20** | |

Plus 9 real-tree probes (R00-R02, R04 for `check-grep-count.sh`; Q00-Q04 for
`check-sigpipe.sh`), listed under F2 and Q.

**P08 is not a valid kill.** Its expression,
`768s#while \[ "$k" -lt "${#fly_ids\[@\]}" \]#while false#`, contains a `#`
inside `${#fly_ids`, so sed ended the pattern there and read the rest as flags,
including `w`. The line became `    fly_ids[@]}" ]#fly_ids[@]}" ]; do`, a syntax
break (210 of 262 assertions failed), and the `w` flag wrote a file called
`hile false#` into the repository root. It counts as killed in the table above,
but it says nothing about the `while` it meant to target. It is also the
evidence for F5.

### Survivors, with the evidence for each verdict

Ranked by production impact. "Real" means a behavioural difference was shown
on a concrete input. "Equivalent" means no input was found that tells the mutant
from the original.

**F1, `mutate.sh --check` is blind to `.claude/**` targets (real, highest).**
Not a mutant: an observed failure. An audit run mutating
`.claude/tests/gates.test.sh:1894` hit
`dofork: child -1 - forked process 29224 died unexpectedly` and its session
ended. The tree was left with the mutated file and these sentinels:

```
.claude/state/mutations/.claude_tests_gates.test.sh.20261016T053548Z.1527829.active
.claude/state/mutations/.claude_tests_gates.test.sh.20261016T053548Z.1527829.bak
.claude/state/mutations/.claude_tests_gates.test.sh.20261016T053548Z.1527829.diff
.claude/state/mutations/.claude_tests_gates.test.sh.20261016T053548Z.1527829.new
```

`bash scripts/mutate.sh --check` printed:

```
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

and exited 0, while `git diff` showed line 1894 mutated. `--check` enumerates
with `for a in "$MUTDIR"/*.active` (`mutate.sh:122`), and a bash glob does not
match a leading `.`. Restored by hand after `cmp` confirmed the `.bak` matched
`HEAD`. Copies of the sentinels were kept with the audit's scratch output.

**F2, both tree guards go blind after a quoted `(` inside `"$( ... )"` (real,
high).** Real-tree probe R00:

```
=== mutate: .claude/tests/gates.test.sh (1 line(s) changed by 1894s#"$T1"; }#"$T1" || printf 0; }#) ===
  1894 - h56_runs()    { grep -c '^ *run: ' "$T1"; }
  1894 + h56_runs()    { grep -c '^ *run: ' "$T1" || printf 0; }

=== mutate: running bash scripts/check-grep-count.sh ===
check-grep-count: scanned 49 shell file(s), 0 finding(s)
```

The same line, alone in a file in an isolated copy of the tree (`git archive
HEAD` into a scratch repository), is reported. Bisecting `masked_lines` output
put the quote-state flip at `gates.test.sh:1812`
(`"$(count_re '^\(not recorded: ...' "$out")"`). Minimal inputs, isolated copy,
line 2 `y=$(grep -c x f || printf 0)`:

```
x="$(f '(a')"     0 findings      x="$(f 'a)')"     1 finding
x="$(f "(a")"     0 findings      x="$(f '(a)')"    1 finding
x="$(f \()"       0 findings      x="$(f 'a' "$o")" 1 finding
```

`check-sigpipe.sh`, with `set -o pipefail` and line 3
`if cmd | grep -q x; then :; fi`, gave 0 findings after `x="$(f '(a')"` and
`x="$(f "(a")"`, and 1 after the balanced shapes. R01 and R02 (other spellings
of the same mutation on the same line) also reported 0. **R04**, a correct
`n=$(grep -c ...) || n=0` spelling meant as a negative control, reported 0 too,
but it sits inside the blind region and so proves nothing either way.

**F3, `check-grep-count.sh` misses a fallback on a continuation line (real).**
In the isolated copy, unmutated, `y=$(grep -c x f \` / `  || printf 0)` gave
0 findings. Mutant C07 (`215s#i < NR#0#`, which disables continuation folding)
survives for the same reason: `scan_line` judges raw lines one at a time.

**Q01-Q03, `check-sigpipe.sh` reader shapes (real, latent).** All were
`mutate.sh` probes of `scripts/check-boundaries.sh:527`, a pipefail file, run
with `check-sigpipe.sh` over the whole tree:

```
Q00  | grep -qi owner;                        1 finding  (check-boundaries.sh:527)
Q01  | LC_ALL=C grep -qi owner;               0 findings
Q02  | grep -e owner -qi;                     0 findings
Q03  |& grep -qi owner;                       0 findings
Q04  | sed -n '/owner/{p;q}' | grep -q .;     1 finding
```

`git grep` over `*.sh` finds none of the three missed shapes in the tree today.

**S03 and S06 (real, fixture gaps).** Both survive `sigpipe` (82/0). In the
isolated copy, with the mutant applied: `if cmd | grep --max-count=1 x; then :;
fi` went from 1 finding to 0 (S03), and `cmd | grep -q x || echo no` went from
1 to 0 (S06). The latter's sibling, `if cmd | grep -q x || other; then`, is
still reported under S06, because the `if` makes the status read anyway.

**B08, B04, B05, B07 (`check-boundaries.sh`, real by construction).** Each
survives `boundaries` (125/0). Their behavioural difference follows from the
regex alone and was not run on a fixture: B08 (`$g( |\(|$)` to `$g`) makes
`PASS unit-slow` satisfy a required `unit`; B04 lets `owner: <any word>` pass;
B05 lets `unwaived` count as a waiver; B07 drops the required-gates check at
DONE. B07's impact is the lowest of the four, because DONE commits land on main
directly and `check-boundaries.sh` runs on PRs.

**G03 (`phase-guard.sh:58`, real by construction).** Dropping the restore of
`PHASE` after a cross-worktree judgement survives both `phase-guard` (378/0)
and `worktree` (73/0). The audit did not build the two-worktree fixture that
would show a wrong verdict; HARNESS-063 builds it.

**A13 (`gates.sh:90`, real by construction).** `valid_story_id "$STORY" ||` to
`true ||` survives `gates` (671/0). The input that matters is `--story ../x`;
not run.

**P04, P05, P10, P12 (`plan.sh`, real but low).** Each survives `plan`
(262/0). P04 is the `-ge` / `-gt` boundary at `AC_MANY=6`. P10 matters only
with two matching `except` rows, and the shipped `models.conf` has none. P12
matters only with a `## Model guidance…` prefix heading. P05 removes a
post-condition that no test has made fire.

**M11 (`mutate.sh:191`, real, low).** Without the `--` check,
`mutate.sh F E cmd args` shifts `cmd` away and runs `args`. It survives
`mutate` (189/0).

**Equivalent or unresolved (no story):**

- **C05** (`180s` drop `sub(/^.*\$\(/, "", head)`): line 179's class
  `[({;&|]` already strips through the `(` of `$(`. Probed on
  `y=$(grep -c x f || printf 0)`: still 1 finding. Equivalent.
- **C06** (`207s` heredoc skip disabled): `masked_lines` already masks heredoc
  bodies. Probed with `cat <<EOF` / `y=$(grep -c x f || printf 0)` / `EOF`:
  0 findings, original and mutant alike. Equivalent while `masked_lines` does
  that.
- **C11** (`163s` backslash skip disabled): three inputs (`"a\"b"`, `a\)`,
  `\$x`) gave the same finding count with and without it. Unresolved, leaning
  equivalent: `masked_lines` handles escapes first.
- **S04** (`171s` drop `D == 0 &&`): three substitution-pipe inputs gave 0
  findings both ways. Unresolved.
- **L13** (`lib.sh:605`, quote tracking in `tokenize` disabled): survives
  `lib` and `phase-guard` (378/0). Not probed. Unresolved: quoted spans are
  likely masked before `tokenize` sees them.
- **B09** (`check-boundaries.sh:144`, frontmatter-start check forced true): a
  file without frontmatter still fails the per-key checks below it. Low.

**F5, `mutate.sh` lets a sed expression write into the tree (real).** See P08
above: the target was restored and verified, and the untracked file
`hile false#` stayed at the repository root. It happened twice during the round,
once from the first session's expression and once from P08. Both files were
removed by hand.

## What would have to be true for this to be wrong

- The suites ran here as CI runs them. They ran on Windows Git Bash; CI runs
  Linux. A survivor here could be killed by a platform-specific assertion
  there, and the reverse.
- The `suites.sh` wrapper read each suite's verdict from its exit status and its
  `^<suite>: N passed, M failed$` summary line (anchored). If a suite exits 0
  having failed, a survivor is overstated.
- The isolated copies used for the equivalence probes and for F2's
  minimisation (`git archive HEAD`) behave like the tree. They carry the same
  scripts, but not untracked files or `.claude/state`.
- F2's diagnosis that the flip begins at line 1812 rests on bisecting
  `masked_lines` output. The two guards could also be blinded by something
  else further down the file.

## What was not checked

- **The handoff mutation tables of the stories that changed these files** were
  not re-verified one by one. This round chose its own mutants instead.
- **Equivalence of C11, S04 and L13** rests on two or three inputs each, and L13
  on none.
- **B04, B05, B07, B08, G03 and A13** were judged real from the code, without a
  fixture showing the wrong verdict. Each story's RED is where that gets shown.
- **The extent of F2 across the tree**: how many lines of how many harness files
  sit in a blind region. Only `gates.test.sh` from line 1812 was measured.
  `check-sigpipe.sh`'s census line still prints the honest file count while that
  coverage is partial.
- **Hunks of `gates.sh`, `check-boundaries.sh`, `lib.sh` and `phase-guard.sh`
  that did not change since `7b6f6db`**, and every file in the "left out" list
  under Scope.
- **Concurrency.** The first session's batch ran alongside interactive probes,
  which is a likely contributor to the fork failure behind F1; that is not
  established. The resumed batches ran alone.
- **Linux.** No mutant was run on CI hardware.

## Spike code

None. The scratch wrappers (`suites.sh`, `run.sh`, `batch.sh`, `rt.sh`,
`runm.sh`) and the isolated tree copy lived in the session's scratchpad and were
not committed.

## Stories filed

- **HARNESS-059**: mutate.sh leaves the tree as it found it - --check sees
  dot-named sentinels and writing sed commands are refused. From F1, F5, M11.
- **HARNESS-060**: The tree guards stay sighted past a quoted paren inside a
  quoted substitution. From F2, F3 (C07).
- **HARNESS-061**: check-sigpipe recognises the early-exit reader shapes it
  misses and pins the ones it only implies. From Q01-Q03, S03, S06. Depends on
  HARNESS-060.
- **HARNESS-062**: check-boundaries matches gate names, owners and waivers as
  whole words, at DONE as well as REVIEW. From B08, B04, B05, B07.
- **HARNESS-063**: phase-guard restores the session's phase after judging a
  write into another worktree. From G03.
- **HARNESS-064**: gates.sh --story refuses an id that is not one path
  component, and a test says so. From A13.
- **HARNESS-065**: plan.sh edges are pinned - the AC-count threshold,
  first-match exceptions, and the write post-condition. From P04, P10, P12, P05.
