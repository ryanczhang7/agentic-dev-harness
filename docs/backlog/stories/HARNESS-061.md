---
id: HARNESS-061
title: check-sigpipe recognises the early-exit reader shapes it misses and pins the ones it only implies
slug: check-sigpipe-recognises-the-early-exit
epic: 
type: fix
status: todo
phase: PLANNED
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
`:173` and `:260-262` (`git grep -n 'early_reader\|scan_line' scripts/`).
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

