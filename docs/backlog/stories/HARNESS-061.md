---
id: HARNESS-061
title: check-sigpipe recognises the early-exit reader shapes it misses and pins the ones it only implies
slug: check-sigpipe-recognises-the-early-exit
epic: 
type: fix
status: in-review
phase: REVIEW
branch: story/HARNESS-061-check-sigpipe-recognises-the-early-exit
depends_on: [HARNESS-060] # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-sigpipe.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(survivors S03, S06 and real-tree probes Q01-Q03). The required gate is the
harness self-test (`sigpipe` suite) and CI's `check-sigpipe.sh` step. It
`depends_on` HARNESS-060 because both write `check-sigpipe.sh` and its suite.

**Fixture gaps (S03, S06).** Two mutants of `check-sigpipe.sh` survive the
`sigpipe` suite (82 passed, 0 failed) while changing what the guard reports on
real input:

- S03 drops `max-count` from the long-option early-reader list (line 143).
  `if cmd | grep --max-count=1 x; then :; fi` under pipefail is reported by the
  original and not by the mutant.
- S06 drops the `||` disposition (line 256). `cmd | grep -q x || echo no` under
  pipefail is reported by the original and not by the mutant.

**Reader shapes the guard cannot see (Q01-Q03).** Real-tree probes mutated
`scripts/check-boundaries.sh:527` (`| has_owner;`, under pipefail) into three
equivalent early-exit readers; each was reported 0 times, while the plain
`| grep -qi owner;` (Q00) and a `sed ... | grep -q .` (Q04) were reported:

    Q01  | LC_ALL=C grep -qi owner;      0 findings
    Q02  | grep -e owner -qi;            0 findings
    Q03  |& grep -qi owner;              0 findings

`early_reader` judges the first word after `|` (an assignment prefix is not
`grep`), stops reading options at the first non-option word (so an option after
`-e PAT` is unseen), and `|&` makes the next word `&`. None of the three shapes
is in the tree today (`git grep` over `*.sh` for them is empty), so this is a
latent gap: the next instance would pass CI.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — Under `set -o pipefail`, `if cmd | grep --max-count=1 x; then :; fi`
  is reported. Passes today; it is earned by mutant S03 going red (the
  `max-count` alternative removed), recorded in `## Regressions`.
- **AC-2** — Under pipefail, `cmd | grep -q x || echo no` is reported. Passes
  today; earned by mutant S06 going red.
- **AC-3** — Under pipefail, each of `cmd | LC_ALL=C grep -q x`,
  `cmd | env LC_ALL=C grep -q x`, `cmd | grep -e x -q` and `cmd |& grep -q x`,
  used as an `if` condition, is reported. Fails today. *Negative control:*
  `cmd | LC_ALL=C grep -c x` and `cmd | grep -e x -c` (draining readers) are
  still not reported.
- **AC-4** — The real-tree probes Q01-Q03 above, rerun through `mutate.sh`
  against `scripts/check-boundaries.sh:527`, each report that line. Recorded in
  `## Gate probes`.

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

**Writes:** `scripts/check-sigpipe.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

RED may amend any block below in place, with a reason; GREEN builds what the
amended block says. Anchors read off the tree at `1b89cab` (main after
HARNESS-060), 2026-10-17. A named mechanism here is checkable, not sacred.

**C-1. Where the reader is recognised.** `scripts/check-sigpipe.sh:129-155`,
`early_reader(s)`: `s` is the text after a `|`, split on whitespace; `a[1]`
through `bname` is the command word; `head` is a reader; for `grep`/`egrep`/
`fgrep` the loop over `a[2..n]` returns 1 at the first early-exit option
(`--quiet|--silent|--max-count|--files-with-matches|--files-without-match`, or
a short bundle matching `^-[A-Za-z]*[qlLm]`), returns 0 at `--`, and
**returns 0 at the first token that is not an option** (`:151`, "the pattern:
options are over"). `scan_line` (`:162-175`) calls it with the text after a
`|` and skips `||` (`:171`). The three misses follow directly:

- `LC_ALL=C grep -q x` and `env LC_ALL=C grep -q x`: `a[1]` is the
  assignment (or `env`), not `grep`.
- `grep -e x -q`: `-e` is an option, but its operand `x` is the next token and
  ends the loop before `-q` is seen.
- `|& grep -q x`: `scan_line` hands `early_reader` the text starting at `&`,
  whose first word is `&`, so it is nothing.

**C-2. The fix (GREEN, `early_reader` and `scan_line`).**
- Command-word prefixes: before taking `a[1]` as the command word, skip every
  leading token that is a shell assignment (`^[A-Za-z_][A-Za-z0-9_]*=`), and a
  leading `env` together with the assignments after it. `env`'s own options
  (`-i`, `-u NAME`) are out of scope; a token starting with `-` after `env`
  ends the skip and the word is not a reader.
- Option operands: `-e` and `-f` as whole tokens consume the next token as
  their operand and the loop continues; `--regexp` and `--file` as whole
  tokens do the same; `--regexp=X`, `--file=X` and a bundle ending in `e`/`f`
  (`-Fe x`) are single tokens whose operand follows: treat a short bundle whose
  LAST letter is `e` or `f` as consuming the next token too. A bundle that
  carries `q`, `l`, `L` or `m` before that letter still returns 1 first, as
  today (`-qe x` is a reader). `-m` followed by a separate count already
  returns 1 at `-m`.
- `|&`: in `scan_line`, when the character after `|` is `&`, call
  `early_reader` on the text after the `&` and keep the column of the `|`.
  `||` stays skipped.
Nothing else changes: draining readers (`-c`, `-v`, `-o` alone, `sed`, `awk`,
`wc`) stay unreported, and the AC-3 controls `LC_ALL=C grep -c x` and
`grep -e x -c` pin that the prefix and operand rules do not make `-c` a reader.

**C-3. What RED pins (`.claude/tests/sigpipe.test.sh`).** One new describe
before `summary "sigpipe"` (`:1298`), on a `make_project_fixture` with a
`scripts/probes/*.sh` file like `p_readers.sh` (AC-2 describe, `:390-396`,
`assert_flagged <file> "<line numbers>"`): a pipefail file whose numbered lines
hold, as `if` conditions, AC-1's `--max-count=1`, AC-2's `cmd | grep -q x ||
echo no` (a top-level pipeline whose status the `||` reads), AC-3's four
shapes, and the two AC-3 controls plus `cmd | env -i grep -c x` as a third.
`assert_flagged` pins the exact set of reported lines, so the controls are
pinned in the same assertion as the positives. AC-1 and AC-2 pass on arrival;
AC-3's four fail today (the file is reported at fewer lines).

*Amended by RED, 2026-10-17.* Two controls added to the same file and the same
set, both implied by C-2 rather than new behaviour: line 13 `cmd | grep -e -q x`
(the `-q` is `-e`'s operand, i.e. the pattern, so this drains: it pins that `-e`
CONSUMES its operand rather than the loop merely skipping non-option words, a
cheaper fix that would satisfy every other line) and line 14 `cmd |& grep -c x`
(pins that `|&` forwards to the reader test and is not itself a finding).
**Line 13 is reported today** - the current loop reads `-e` as an option,
`continue`s, and returns 1 at `-q`. So it is a false positive C-2's operand rule
removes, and GREEN must remove it: the pinned set is `4 5 6 7 8 9` and today's is
`4 5 13`. The fixture is `scripts/probes/p_h61.sh` in a `make_project_fixture`;
the census pinned is `check-sigpipe: scanned 1 shell file(s), 1 with pipefail, 6
finding(s)`.

**C-4. Earning AC-1 and AC-2 (RED, `## Regressions`).** Both pass against
code that already exists, so RED earns each with one `mutate.sh` run on
`scripts/check-sigpipe.sh` against this suite, pasting the output: S03,
`'143s#|max-count##'` (the `--max-count` alternative removed; AC-1's line must
drop out of the set), and S06, `'256s# || (index(grp, "||") > 0)##'` (the `||`
disposition removed; AC-2's line must drop out). Line numbers to be re-read at
RED; the audit's are from `c78917d`. If the mutated suite reports the whole
`assert_flagged` set as one FAIL, that is the expected shape: say which line
left the set.

**C-5. Floors.** `sigpipe` 89 (`floors.conf:61`, mirror `selftest.test.sh:553`),
raised to the executed count RED measures, recorded at the foot of
`floors.conf`.

**Oracle partition.** Mechanical throughout: an exact set of reported line
numbers per fixture file, and the exact census line.

**Callers of changed signatures.** None: `early_reader` and `scan_line` are
awk functions private to `AWK_RULE` in `check-sigpipe.sh`, called only at
`:171`, `:238` and `:270` (`git grep -n 'early_reader\|scan_line' scripts/`).
`check-grep-count.sh` has its own `scan_line` for a different operator and is
untouched. The real tree has none of the three AC-3 shapes today (`git grep
-nE '\| *(LC_ALL=[A-Za-z]+ |env )grep|\|& *grep|grep -e [^|]* -[a-zA-Z]*q' --
'*.sh'` is empty), so the census stays `0 finding(s)` after the fix; AC-4's
probes are what show the new rules fire on real text.

**Required gate.** The harness self-test (`sigpipe` suite) in CI's `selftest`
job, and CI's `check-sigpipe.sh` step. No `gates.sh` gate is configured here.

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
         reason. check-boundaries.sh refuses a PR that has neither. A result
         counts only as a block: a line beginning with three backticks or
         three tildes (a fence), or a line indented by exactly four spaces.
         Prose does not count, nor inline code in backticks, nor a tab, nor
         anything inside an HTML comment
     Schedule it into GATES rather than RED where you can: source is writable
     there, and a story that bounced back to RED mid-cycle gets its corrected
     assertions earned by the same mutation, for free. How many entries is the
     budget in rules.md, `Mutation work per story`: by default ONE
     "defect put back" entry for the story's central claim, run against the one
     suite that holds its assertion. A format or codec story may add one wrong VALUE
     mutation - a codec that is uniformly wrong round-trips through itself
     perfectly. Exhaustive earning of assertions that passed on arrival is not
     an entry here; it goes to `/audit-mutations`. -->

- **DV-1, AC-4: the rule probed against the tree it judges.** With
  `scripts/check-boundaries.sh:527` (`if printf '%s\n' "$dv" | has_owner;
  then`, under the file's pipefail) mutated into each of
  `| LC_ALL=C grep -qi owner;`, `| grep -e owner -qi;` and `|& grep -qi
  owner;`, `bash scripts/check-sigpipe.sh` MUST report
  `scripts/check-boundaries.sh:527` and exit 1, three runs, each via
  `bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#<shape>#' -- bash scripts/check-sigpipe.sh`;
  and with the file restored MUST report `0 finding(s)`. Owner: GATES (the
  audit measured 0 findings on each; the fix is not built in RED). The result
  is also `## Gate probes`.
- **DV-2, the defect put back.** With the prefix-skipping of C-2 removed from
  `early_reader` (the one `mutate.sh` expression GREEN names in `## Notes`),
  AC-3's `LC_ALL=C` and `env` lines MUST leave the reported set in the new
  describe, and nothing outside it fails. Owner: GATES.


**Results (GATES, orchestrator, 2026-10-17).** DV-1: each of the three
shapes the audit measured at 0 findings (Q01-Q03) is now reported at
`scripts/check-boundaries.sh:527`, and the restored tree is clean. DV-2:
with the command-word prefix skipping removed (`j = 1` at `:157`), the
`LC_ALL=C` and `env LC_ALL=C` lines (6, 7) leave the reported set, the census
assertion fails with them, and nothing outside the HARNESS-061 describe moves
(89 passed). Each file came back byte for byte.

```
--- DV-1 (AC-4, real-tree probes on check-boundaries.sh:527)
$ bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#| LC_ALL=C grep -qi owner;#' -- bash scripts/check-sigpipe.sh
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 527s#| has_owner;#| LC_ALL=C grep -qi owner;#) ===
  527 -   if printf '%s\n' "$dv" | has_owner; then
  527 +   if printf '%s\n' "$dv" | LC_ALL=C grep -qi owner; then
=== mutate: running bash scripts/check-sigpipe.sh ===
scripts/check-boundaries.sh:527
check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 1 finding(s)
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-boundaries.sh.20261017T17531
$ bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#| grep -e owner -qi;#' -- bash scripts/check-sigpipe.sh
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 527s#| has_owner;#| grep -e owner -qi;#) ===
  527 -   if printf '%s\n' "$dv" | has_owner; then
  527 +   if printf '%s\n' "$dv" | grep -e owner -qi; then
=== mutate: running bash scripts/check-sigpipe.sh ===
scripts/check-boundaries.sh:527
check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 1 finding(s)
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-boundaries.sh.20261017T17540
$ bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#|\& grep -qi owner;#' -- bash scripts/check-sigpipe.sh
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 527s#| has_owner;#|\& grep -qi owner;#) ===
  527 -   if printf '%s\n' "$dv" | has_owner; then
  527 +   if printf '%s\n' "$dv" |& grep -qi owner; then
=== mutate: running bash scripts/check-sigpipe.sh ===
scripts/check-boundaries.sh:527
check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 1 finding(s)
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-boundaries.sh.20261017T17550
$ bash scripts/check-sigpipe.sh   # restored tree
check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
--- DV-2 (defect put back)
$ bash scripts/mutate.sh scripts/check-sigpipe.sh 's#j = cmd_index(a, n)#j = 1#' -- bash .claude/tests/sigpipe.test.sh
=== mutate: scripts/check-sigpipe.sh (1 line(s) changed by s#j = cmd_index(a, n)#j = 1#) ===
  157 -   j = cmd_index(a, n)
  157 +   j = 1
=== mutate: running bash .claude/tests/sigpipe.test.sh ===
    FAIL HARNESS-061 AC-1..AC-3: --max-count=1, a pipeline read by ||, LC_ALL=C grep -q, env LC_ALL=C grep -q, grep -e x -q and |& grep -q are reported; LC_ALL=C grep -c, grep -e x -c, env -i grep -c,
         expected: 4 5 6 7 8 9
         actual:   4 5 8 9
    FAIL HARNESS-061: the census is exact - one file, one with pipefail, six findings
         expected: 1
         actual:   0
sigpipe: 89 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-sigpipe.sh.20261017T175738Z.
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
DV-DONE
```

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

Planned by `bash scripts/plan.sh write HARNESS-061` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po` orchestrator session, Fable 5.1 (`claude-fable-5-1`).
- RED: `test-developer`, dispatched with `model: opus`; it reported Opus 5.5 (`claude-opus-5-5`).
- GREEN: `feature-developer`, dispatched with `model: opus`; it reported Opus 5.5 (`claude-opus-5-5`).

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- `command grep`, `\grep`, `sudo grep` and other wrappers. Add them only if the
  tree uses one.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

Level: the guard's own suite, `.claude/tests/sigpipe.test.sh`, against a
throwaway `make_project_fixture` repo (never the real tree - a probe file under
`.claude/` classifies as harness and would be scanned by CI's real-tree step).
One new describe before `summary "sigpipe"`:
`HARNESS-061: assignment and env prefixes, -e operands and |& do not hide an early-exit reader`.

Fixture `scripts/probes/p_h61.sh` (`set -uo pipefail` on line 2):

| Line | Text | Role | Today | Pinned |
|---|---|---|---|---|
| 4 | `if cmd \| grep --max-count=1 x; then :; fi` | AC-1 | reported | reported |
| 5 | `cmd \| grep -q x \|\| echo no` | AC-2 | reported | reported |
| 6 | `if cmd \| LC_ALL=C grep -q x; then :; fi` | AC-3 | not | reported |
| 7 | `if cmd \| env LC_ALL=C grep -q x; then :; fi` | AC-3 | not | reported |
| 8 | `if cmd \| grep -e x -q; then :; fi` | AC-3 | not | reported |
| 9 | `if cmd \|& grep -q x; then :; fi` | AC-3 | not | reported |
| 10 | `if cmd \| LC_ALL=C grep -c x; then :; fi` | AC-3 control | not | not |
| 11 | `if cmd \| grep -e x -c; then :; fi` | AC-3 control | not | not |
| 12 | `if cmd \| env -i grep -c x; then :; fi` | C-3 control | not | not |
| 13 | `if cmd \| grep -e -q x; then :; fi` | RED control (C-3 amended): `-q` is `-e`'s operand | **reported** | not |
| 14 | `if cmd \|& grep -c x; then :; fi` | RED control (C-3 amended): `\|&` into a drain | not | not |

Two assertions:

1. `assert_flagged ... "scripts/probes/p_h61.sh" "4 5 6 7 8 9"` - AC-1, AC-2,
   AC-3 and all five controls, as one exact set.
2. census `check-sigpipe: scanned 1 shell file(s), 1 with pipefail, 6 finding(s)`
   (anchored prefix via `count_prefix`) - the set cannot pass by the file going
   unscanned or pipefail going unseen.

AC-4 is not tested here: it is a real-tree probe owned by GATES (DV-1), and no
test in this suite mutates the real tree.

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

RED by `test-developer`, resolved model **Opus 5.5 (`claude-opus-5-5`)**, as
planned; no override. 2026-10-17, local Windows / Git Bash, all timings local.

**Command.** `bash .claude/tests/sigpipe.test.sh` (about 4m20s locally; the new
describe adds one fixture and one guard run). Floor check:
`bash .claude/tests/selftest.test.sh`.

**Verbatim failure (unmutated tree):**

```
    FAIL HARNESS-061 AC-1..AC-3: --max-count=1, a pipeline read by ||, LC_ALL=C grep -q, env LC_ALL=C grep -q, grep -e x -q and |& grep -q are reported; LC_ALL=C grep -c, grep -e x -c, env -i grep -c, grep -e -q x and |& grep -c are not
         expected: 4 5 6 7 8 9
         actual:   4 5 13
    FAIL HARNESS-061: the census is exact - one file, one with pipefail, six findings
         expected: 1
         actual:   0

sigpipe: 89 passed, 2 failed
```

Why it is the right failure: the fixture was scanned (lines 4 and 5 are
reported, so pipefail was seen and the file enumerated); the four AC-3 lines 6-9
are absent from the set, and line 13 is present. Run directly in a scratch
fixture the guard prints `check-sigpipe: scanned 1 shell file(s), 1 with
pipefail, 3 finding(s)` - so the census assertion fails on the finding count,
not on a scan error. Every pre-existing assertion still passes (89).

**Tests -> ACs.**
- `HARNESS-061 AC-1..AC-3: ...` (assert_flagged, exact set `4 5 6 7 8 9`):
  AC-1 (line 4), AC-2 (line 5), AC-3 positives (6-9), AC-3 controls (10, 11),
  C-3 control (12), RED controls (13, 14).
- `HARNESS-061: the census is exact - one file, one with pipefail, six findings`:
  the exact census for that file; AC-3 (6 = 2 today + 4).

**Files touched.** `.claude/tests/sigpipe.test.sh` (new describe before
`summary "sigpipe"`), `.claude/tests/floors.conf` (`sigpipe` 89 -> 91 at :61,
and a HARNESS-061 note at the foot), `.claude/tests/selftest.test.sh` (mirror
`sigpipe 91` at :553), this story (Contract C-3 amendment, Test plan, Handoff,
Regressions). `scripts/check-sigpipe.sh` untouched (`git status` clean for it;
`mutate.sh --check` clean).

**Interface the tests pin.** No new export: the suite runs
`bash scripts/check-sigpipe.sh <pathspec>` in a fixture repo and reads its
stdout. Pinned: one finding line per reported line, `<path>:<line>: ...`, and
the census line `check-sigpipe: scanned N shell file(s), M with pipefail, K
finding(s)` - both formats unchanged from today. NOT constrained: how
`early_reader`/`scan_line` are restructured, the column `scan_line` returns for
`|&` (the suite reads line numbers only), the finding message text after the
line number, and every shape C-2 mentions but the fixture does not carry
(`--regexp X`, `--file X`, `--regexp=X`, `-Fe x`, `-qe x`, `-f FILE`, multiple
assignments, `env A=1 B=2 grep`). Those are C-2's design, unpinned; if GREEN
wants them guarded it should say so and RED adds lines.

**Callers checked.** `git grep -n 'early_reader\|scan_line' scripts/` on this
tree: `check-sigpipe.sh:125,129,157,162,171,238,270` and
`check-grep-count.sh:156,159,230` (its own, different `scan_line`, untouched).
Matches the Contract's list; line numbers unchanged from `1b89cab`.

**Passed on arrival.** AC-1 (line 4) and AC-2 (line 5) are in the set today.
Earned by C-4's two mutants, output in `## Regressions`: under S03 line 4 leaves
the set (`5 13`), under S06 line 5 leaves it (`4 13`). In RED the assertion is
red with or without the mutant (AC-3 is missing either way), so the evidence is
the line leaving the set, not a pass->fail flip; once GREEN lands the same two
mutants turn a green assertion red.

**Controls - expected values.** Measured outside the suite, by running the
guard directly over `p_h61.sh` in a scratch fixture repo (copy of `scripts/`,
`.claude/hooks`, `.claude/harness`), against today's guard and against a
scratch candidate of C-2 built in the scratch copy only (not the real tree).
"Reported" means the line is in the set; the threshold for every control is
"not in the set".

| Line | Control | Today | C-2 candidate | Mis-fix that the control catches, and what it measured |
|---|---|---|---|---|
| 10 | `LC_ALL=C grep -c x` | not | not | prefix rule that made any prefixed grep a reader (not built; by construction) |
| 11 | `grep -e x -c` | not | not | `-c` read as a reader after an operand (not built) |
| 12 | `env -i grep -c x` | not | not | **weak**: a mis-fix that skips every token after `env` until `grep` also gives `not` (measured: set `4 5 6 7 8 9`), because `-c` drains anyway. It pins only that `-c` stays a drain, not that `-i` ends the skip |
| 13 | `grep -e -q x` | **reported** | not | "skip non-option words instead of consuming `-e`'s operand": measured set `4 5 6 7 8 9 13`, census `7 finding(s)` - fires |
| 14 | `\|& grep -c x` | not | not | "every `\|&` is a finding": measured set `4 5 6 7 8 9 14`, census `7 finding(s)` - fires |
| - | DV-2 shape: prefix skipping removed from the candidate | - | - | measured set `4 5 8 9`, census `4 finding(s)` - lines 6 and 7 leave, as DV-2 requires |

C-2 candidate overall: set `4 5 6 7 8 9`, census `check-sigpipe: scanned 1
shell file(s), 1 with pipefail, 6 finding(s)` - so the pinned set is
achievable with exactly the Contract's design. These are claims about the
scratch candidate; GREEN confirms them against the shipped guard.

**Discovered - changes the approach.**
- Line 13 is a false positive TODAY (`-e` is `continue`d as an option, then
  `-q` returns 1). C-2's operand rule removes it, and GREEN must: the pinned set
  excludes 13. A fix that only stops returning 0 at the first non-option word
  would make 8 pass and leave 13 red.
- The scratch candidate's `|&` handling was one line in `scan_line`, placed
  directly after the `||` skip: `if (substr(s, i + 1, 1) == "&") { if (D == 0
  && res == 0 && early_reader(substr(s, i + 2))) res = i; i++; continue }`.
  Offered as evidence the pinned set is reachable, not as the implementation.
- Line 12 is weak by design of the story (see table); `env -i grep -q x` would
  pin "an `env` option ends the skip", but C-2 puts env options out of scope, so
  it is not pinned. Orchestrator's call.

**Deferred verifications.** DV-1 (AC-4, real-tree probes on
`scripts/check-boundaries.sh:527`) and DV-2 (defect put back) are **declined by
RED: they cannot run in RED** - DV-1 needs the fixed guard to report the
mutated line (today the audit measured 0 findings on each shape, so it would
only re-measure the defect), and DV-2 needs GREEN's prefix-skipping code to
remove. Both are owned by GATES and left to it. RED wrote no test that mutates
the real tree.

**Other runs.** `bash .claude/tests/selftest.test.sh`: `selftest: 268 passed, 0
failed`. `bash scripts/check-sigpipe.sh` (real tree): `check-sigpipe: scanned 49
shell file(s), 45 with pipefail, 0 finding(s)`. `bash scripts/check-grep-count.sh`:
`scanned 49 shell file(s), 0 finding(s)`. `bash scripts/mutate.sh --check`:
clean. `bash scripts/gates.sh --fast`: every gate UNCONFIGURED in this repo
(BOOTSTRAPPED=no), exit 0 - nothing there judges this suite; the binding check
is the selftest job. Floor: `sigpipe` 89 -> 91 (executed count 91 = 89 passed +
2 failed); until GREEN the suite passes 89, below its floor.

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

Not a return to RED. These are C-4's earnings of AC-1 and AC-2, which pass on
arrival against code that already exists. Each mutant ran once through
`mutate.sh` against the whole `sigpipe` suite, 2026-10-17, local. Baseline set
for `p_h61.sh` on the unmutated tree: `4 5 13`. In both runs the only change is
the AC's own line leaving the set; no other assertion in the suite moved
(89 passed both times, the same 89 as unmutated).

**S03 - `--max-count` removed from the long-option list (AC-1, line 4 leaves).**

```
=== mutate: scripts/check-sigpipe.sh (1 line(s) changed by 143s#|max-count##) ===
  143 -       if (t ~ /^--(quiet|silent|max-count|files-with-matches|files-without-match)/) return 1
  143 +       if (t ~ /^--(quiet|silent|files-with-matches|files-without-match)/) return 1
=== mutate: running bash .claude/tests/sigpipe.test.sh ===
    FAIL HARNESS-061 AC-1..AC-3: --max-count=1, a pipeline read by ||, LC_ALL=C grep -q, env LC_ALL=C grep -q, grep -e x -q and |& grep -q are reported; LC_ALL=C grep -c, grep -e x -c, env -i grep -c, grep -e -q x and |& grep -c are not
         expected: 4 5 6 7 8 9
         actual:   5 13
    FAIL HARNESS-061: the census is exact - one file, one with pipefail, six findings
         expected: 1
         actual:   0
sigpipe: 89 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/nervous-snyder-2b307a/.claude/state/mutations/scripts_check-sigpipe.sh.20261017T165717Z.51467.bak) ===
  143:       if (t ~ /^--(quiet|silent|max-count|files-with-matches|files-without-match)/) return 1
rc=1
```

**S06 - the `||` disposition removed (AC-2, line 5 leaves).**

```
=== mutate: scripts/check-sigpipe.sh (1 line(s) changed by 256s# || (index(grp, "||") > 0)##) ===
  256 -          (index(grp, "&&") > 0) || (index(grp, "||") > 0)
  256 +          (index(grp, "&&") > 0)
=== mutate: running bash .claude/tests/sigpipe.test.sh ===
    FAIL HARNESS-061 AC-1..AC-3: --max-count=1, a pipeline read by ||, LC_ALL=C grep -q, env LC_ALL=C grep -q, grep -e x -q and |& grep -q are reported; LC_ALL=C grep -c, grep -e x -c, env -i grep -c, grep -e -q x and |& grep -c are not
         expected: 4 5 6 7 8 9
         actual:   4 13
    FAIL HARNESS-061: the census is exact - one file, one with pipefail, six findings
         expected: 1
         actual:   0
sigpipe: 89 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/nervous-snyder-2b307a/.claude/state/mutations/scripts_check-sigpipe.sh.20261017T170501Z.66980.bak) ===
  256:          (index(grp, "&&") > 0) || (index(grp, "||") > 0)
rc=1
```

After both: `bash scripts/mutate.sh --check` -> `mutate: no stranded mutation;
nothing of a previous run is in the tree.`; `git status --short` shows
`scripts/check-sigpipe.sh` unmodified.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-17T18:03:37Z
    commit: 40217f4
    tree:   dc451ab6379175dd1db3af29418f1a85949c7d4f
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

**GP-1 (GATES, 2026-10-17): `check-sigpipe.sh` probed against a real line of
the tree, three ways.** The same runs as DV-1 in `## Deferred verifications`,
where the full output is pasted. Before this story each probe reported
`45 with pipefail, 0 finding(s)` (audit Q01-Q03).

    --- DV-1 (AC-4, real-tree probes on check-boundaries.sh:527)
    $ bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#| LC_ALL=C grep -qi owner;#' -- bash scripts/check-sigpipe.sh
    === mutate: scripts/check-boundaries.sh (1 line(s) changed by 527s#| has_owner;#| LC_ALL=C grep -qi owner;#) ===
      527 -   if printf '%s\n' "$dv" | has_owner; then
      527 +   if printf '%s\n' "$dv" | LC_ALL=C grep -qi owner; then
    === mutate: running bash scripts/check-sigpipe.sh ===
    scripts/check-boundaries.sh:527
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 1 finding(s)
    === mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-boundaries.sh.20261017T17531
    $ bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#| grep -e owner -qi;#' -- bash scripts/check-sigpipe.sh
    === mutate: scripts/check-boundaries.sh (1 line(s) changed by 527s#| has_owner;#| grep -e owner -qi;#) ===
      527 -   if printf '%s\n' "$dv" | has_owner; then
      527 +   if printf '%s\n' "$dv" | grep -e owner -qi; then
    === mutate: running bash scripts/check-sigpipe.sh ===
    scripts/check-boundaries.sh:527
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 1 finding(s)
    === mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-boundaries.sh.20261017T17540
    $ bash scripts/mutate.sh scripts/check-boundaries.sh '527s#| has_owner;#|\& grep -qi owner;#' -- bash scripts/check-sigpipe.sh
    === mutate: scripts/check-boundaries.sh (1 line(s) changed by 527s#| has_owner;#|\& grep -qi owner;#) ===
      527 -   if printf '%s\n' "$dv" | has_owner; then
      527 +   if printf '%s\n' "$dv" |& grep -qi owner; then
    === mutate: running bash scripts/check-sigpipe.sh ===
    scripts/check-boundaries.sh:527
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 1 finding(s)
    === mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/mutations/scripts_check-boundaries.sh.20261017T17550
    $ bash scripts/check-sigpipe.sh   # restored tree
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)

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

**GREEN, 2026-10-17, `feature-developer`, resolved model Opus 5.5
(`claude-opus-5-5`), dispatched as planned with no override.** Local Windows /
Git Bash.

*What changed* (`scripts/check-sigpipe.sh` only, inside `AWK_RULE`; no test,
`floors.conf` or `selftest.test.sh` touched):
- two new awk functions before `early_reader`: `is_assign(t)` (a token matching
  `^[A-Za-z_][A-Za-z0-9_]*=` that carries no `;&|)}<>`, so `x=1; grep -q y`
  does not skip into the next command) and `cmd_index(a, n)` (index of the
  command word past leading assignments and a leading `env` with its own; a
  `-` token after `env` returns n + 1, i.e. not a reader). `early_reader` takes
  `w` from `a[cmd_index(a, n)]` and starts the option loop after it.
- option loop: `--regexp`/`--file` as whole tokens, and a short bundle matching
  `^-[A-Za-z]*[ef]$` (covers `-e`, `-f`, `-Fe`), skip the next token. The
  `[qlLm]` test stays first, so `-qe x` is still a reader.
- `scan_line`: `|&` calls `early_reader(substr(s, i + 2))`, keeps column `i`,
  and skips the `&`; `||` is still skipped first.

*Measured.* `bash .claude/tests/sigpipe.test.sh` -> `sigpipe: 91 passed, 0
failed` (floor 91). Real tree: `check-sigpipe: scanned 49 shell file(s), 45 with
pipefail, 0 finding(s)`; `check-grep-count: scanned 49 shell file(s), 0
finding(s)`. Also `selftest: 268 passed, 0 failed`, `lib: 324 passed, 0
failed`, `grep-count: 38 passed, 0 failed`. `gates.sh --fast`: all gates
UNCONFIGURED here, exit 0 (judges nothing). `mutate.sh --check`: clean.

*Controls, against the shipped guard* (run directly on a scratch fixture repo
holding a verbatim copy of `p_h61.sh`; the mis-fix rows on a scratch copy of the
guard, never the tree). All match the handoff's table:

    unmutated tree before GREEN       4 5 13            3 finding(s)   (RED: 4 5 13)
    shipped guard                     4 5 6 7 8 9       6 finding(s)   (RED candidate: same)
      controls 10 11 12 13 14         none reported                    (RED: not, all five)
    mis-fix: skip non-option words    4 5 6 7 8 9 13    7 finding(s)   (RED: same)
    mis-fix: every |& a finding       4 5 6 7 8 9 14    7 finding(s)   (RED: same)
    DV-2 shape (j = 1)                4 5 8 9           4 finding(s)   (RED: same)

Line 12 remains weak as RED said. C-2 shapes the fixture does not carry, also
measured on the shipped guard (unpinned): reported - `--regexp x -q`,
`--regexp=x -q`, `-Fe x -q`, `-qe x`, `-f pats -q`, `A=1 B=2 grep -q`,
`env A=1 B=2 grep -q`, `LC_ALL="a b" grep -q`; not reported - `env -i grep -q x`
(env option ends the skip, per C-2), `--regexp -q x`, `-Fe -q x`,
`cmd | x=1; grep -q y`.

*DV-2 expression* (removes the prefix skipping at its one call site; lines 6
and 7 must leave the set, giving `4 5 8 9`):

    bash scripts/mutate.sh scripts/check-sigpipe.sh 's#j = cmd_index(a, n)#j = 1#' -- bash .claude/tests/sigpipe.test.sh

Checked to apply and restore, with a quick command in place of the suite (the
suite run itself is GATES' to paste):

    === mutate: scripts/check-sigpipe.sh (1 line(s) changed by s#j = cmd_index(a, n)#j = 1#) ===
      157 -   j = cmd_index(a, n)
      157 +   j = 1
    === mutate: running bash scripts/check-sigpipe.sh ===
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    === mutate: command exited 0; restored (verified byte-for-byte against .../scripts_check-sigpipe.sh.20261017T173609Z.43655.bak) ===
      157:   j = cmd_index(a, n)

Not committed (per dispatch).

**Self-test at GATES (orchestrator, 2026-10-17).** `bash scripts/selftest.sh`,
run detached and alone after `bash scripts/gates.sh` recorded a pass, exited 0
in 7278 s (about 2 hours). HARNESS-059's run took 2894 s and HARNESS-060's 5433 s
on this host, while CI ran HARNESS-060's whole job in 2m20s. No process from THIS
worktree was left running afterwards. But `ps -ef` showed two other
self-tests running on the same machine throughout: `bash scripts/selftest.sh`
from `/d/adh-WORLD-132` (started 12:55, in its `sigpipe` suite) and from
`/d/manga-translator` (started 14:10, in its `mutate` suite). They belong to
other sessions and were left alone. Concurrent self-tests competing for the
same host are a plausible contributor to the slowdown, and the evidence
shows nothing more than that.

    assertion floors: all 26 suite(s) met their declared floor (3614 assertions executed, 3388 declared).
    26 harness suite(s) passed.

**Handoff check.** RED's predicted DV-2 shape, `4 5 8 9`, is what DV-2 measured
against the shipped guard (`## Deferred verifications`). The rest of the table
belongs to `/audit-mutations`.

PR: https://github.com/ryanczhang7/agentic-dev-harness/pull/148 (opened 2026-10-17 from `10439b9`).
