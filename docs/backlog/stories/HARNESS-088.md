---
id: HARNESS-088
title: gates.sh refuses a duplicate gate id and an empty evidence regex, and a lowered threshold repeat is refused whichever repeat moved
slug: gates-sh-refuses-a-duplicate-gate-id-and
epic: 
type: feature
status: todo
phase: PLANNED
branch: story/HARNESS-088-gates-sh-refuses-a-duplicate-gate-id-and
depends_on: []      # HARNESS-083 is DONE (PR #171); nothing else is needed first
touches: [scripts/gates.sh, scripts/check-boundaries.sh, .claude/tests/gates.test.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION, .claude/skills/quality-gates/SKILL.md]
required_gates: []  # every gate is unconfigured here; the artifact is judged by selftest (see Context)
---

## Context

HARNESS-083 (PR #171, merged 2026-10-31) made `scripts/check-boundaries.sh`
block 3j compare `.claude/harness/project.conf` before and after every GREEN
or GATES commit and refuse a loosening as `[gate-loosened]`. Its diff reviews
(rounds 2 and 3) left three gaps, listed in its `## Notes` under "Follow-up
list (2026-10-31)". This story closes them.

1. **A duplicate `gate` id.** `project_conf_loosenings` reads only the first
   `gate` line per id, as `gates.sh`'s `table_get` does for the other tables -
   but `gates.sh`'s main loop runs **every** `gate` line, and `gates.sh
   --audit` accepts a duplicate. So a GREEN commit that adds a second
   `gate | coverage | optional | . | ... --cov-fail-under=10` line below the
   required one is silent in CI (sandboxed in round 2: `FAIL` rc 1 became
   `WARN ... optional` rc 0). The fix belongs at the source: `gates.sh` refuses
   a duplicate gate id, under `--audit` and on a run alike, so a duplicate can
   never be the manifest a run is judged by. Separately, and for the same
   reason, an **empty evidence regex** (`evidence | unit |` with nothing after)
   is refused: `gates.sh` matches it as `$0 ~ ""`, which every log line
   satisfies, so the gate passes having checked nothing (round 2, must-fix 1:
   a required gate running `echo "nothing here"` went `FAIL ... no evidence of
   work` to `PASS`, rc 0, and `--audit` passed it). HARNESS-083 taught
   `check-boundaries.sh` to read that as `evidence line removed`; `gates.sh`
   itself still accepts it.
2. **Repeated threshold flags** in one gate command. HARNESS-083's rule, as
   corrected in its GREEN return 2: per flag name, a finding when any of the
   after side's **first, last or lowest** value is below the before side's
   same statistic. Round 3 found (a) the "first value lowered" arm has no test
   that fails without it; (b) a lowered **middle** repeat of three is silent
   (`--threshold 60 ... 90 ... 60` -> `60 ... 70 ... 60`: first, last and
   lowest all unchanged); (c) the refusal prints `<highest before> -> <lowest
   after>`, which can name numbers the commit did not move (`=10 =90` -> `=10
   =80` prints `90 -> 10`). This story adds the **highest** statistic, prints
   the statistic that fell, and pins the first-value arm.
3. Other weakenings of an evidence regex (`.` in place of a real one) are
   **out of scope** again - see `## Out of scope` for the reason and the one
   mechanical rule that would cover a slice of it.

**The gate that fails if this story breaks:** every gate in this repository's
`project.conf` is UNCONFIGURED, so `bash scripts/gates.sh` judges nothing
here. The artifact is judged by `bash scripts/selftest.sh gates` and `bash
scripts/selftest.sh boundaries`, both of which CI runs (`selftest.sh` in
`.github/workflows/`), and by `bash scripts/gates.sh --audit`, which
`.github/workflows/gates.yml` runs against the real `project.conf`.
`required_gates` stays empty.

**Portability:** bash, awk and coreutils only. CI's awk is **mawk 1.3.4**: no
gawk-only functions, `[.]` not `\.` inside a string regex, no `mktemp` or
`$TMPDIR` in a shipped script (`lib.test.sh` refuses them).

## Acceptance criteria

- **AC-1** — Given a `project.conf` with two `gate | unit | ...` lines, when
  `bash scripts/gates.sh --audit` runs, then it prints one `FAIL unit` line
  saying the id is declared twice (the exact text is in C-1), ends with
  `1 manifest problem(s).` and exits non-zero. *Control:* the same file with
  the second line deleted prints `Manifest audit passed.` and exits 0.
- **AC-2** — Given the same duplicated `unit` gate, when `bash
  scripts/gates.sh` runs (a full run, no flags), then the run reports `FAIL
  unit` naming the duplicate, counts it as a failed gate and exits non-zero,
  whatever the two commands print. *Control:* with the duplicate deleted the
  same run passes.
- **AC-3** — Given a required gate whose `evidence` line has an empty value -
  any of `evidence | unit |`, `evidence | unit` and `evidence | unit |   ` -
  when `--audit` runs, then it prints one `FAIL unit` line saying the evidence
  regex is empty (C-1), and exits non-zero. *Controls:* `evidence | unit | -`
  is still `ok unit (liveness declared unassertable)`; a gate with no
  `evidence` line at all is still the `WARN ... no evidence line` of today,
  not a FAIL.
- **AC-4** — Given that empty-evidence gate with a command that exits 0 and
  prints nothing the real regex would match, when `bash scripts/gates.sh`
  runs, then the gate is `FAIL`, not `PASS`, and the run exits non-zero.
  *Control:* the same command under a real regex that its output matches
  is `PASS`.
- **AC-5** — Given a GREEN commit that changes a gate command from
  `a --threshold 60 && b --threshold 90 && c --threshold 60` to
  `a --threshold 60 && b --threshold 70 && c --threshold 60`, when `bash
  scripts/check-boundaries.sh main` runs, then it is refused as
  `[gate-loosened]` with `lint: threshold lowered --threshold 90 -> 70`.
  *Controls:* the middle value **raised** to `95`, and the command unchanged
  with `-q` added, are not refused.
- **AC-6** — Given a GREEN commit that changes `--cov-fail-under=10
  --cov-fail-under=90` to `--cov-fail-under=10 --cov-fail-under=80`, when
  `check-boundaries.sh` runs, then the refusal reads `coverage: threshold
  lowered --cov-fail-under 90 -> 80` - the numbers that moved, not `90 -> 10`.
- **AC-7** — Given a GREEN commit that changes `--cov-fail-under=90
  --cov-fail-under=10 --cov-fail-under=95` to `--cov-fail-under=80
  --cov-fail-under=10 --cov-fail-under=95` (only the **first** repeat falls;
  last, lowest and highest are unchanged), when `check-boundaries.sh` runs,
  then it is refused as `coverage: threshold lowered --cov-fail-under 90 ->
  80`. The same for `=90 =10` -> `=80 =10`, HARNESS-083's named case.
- **AC-8** — Given HARNESS-083's existing threshold fixtures (`=10 =90` ->
  `=10`; `=10 =90` -> `=90 =10`; the single-value lowered, raised, added,
  removed and equal cases; `threshold removed <flag> <highest before>`), when
  the `boundaries` suite runs against this story's GREEN, then every one of
  those assertions passes unchanged - their expected strings do not move.

## Contract

**Writes:** `scripts/gates.sh`, `scripts/check-boundaries.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`, `.claude/skills/quality-gates/SKILL.md`

RED may amend any block in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria do not inherit that: a change to
one of them goes through `## Amendments`.

**C-1. `gates.sh`: two new manifest faults.** Both take the shape of the
existing manifest faults (`slow` with no reason, lines 615-624; a broken
`floor`, 657-664): under `--audit` a `printf 'FAIL %-12s %s\n' "$id" "<why>"`
line, otherwise a `results="$results\nFAIL         $id (<why>)"` line; each
adds one to `fails` and `continue`s, so the gate reports exactly one fault and
runs nothing. `--audit` then ends with `N manifest problem(s).` and exit 1 as
today (line 997); a run ends with its usual `N required gate(s) failed.` line
and exit 1 - RED reads the exact summary off the slow-with-no-reason case and
pins what it finds. `--list` is not a judge and prints the duplicate's two
lines and an empty `evidence:` as it does today.

The `<why>` texts, exactly:

| fault | `--audit` line (`%-12s` pads the id) | run line |
|---|---|---|
| duplicate id | `FAIL <id>         declared twice: a second \`gate\` line for one id; gates.sh would run both and check-boundaries.sh judges only the first - keep one` | `FAIL         <id> (declared twice: a second \`gate\` line for one id in project.conf; keep one)` |
| empty evidence | `FAIL <id>         evidence regex is empty: an empty regex matches every log line, so the gate would pass having checked nothing. Write the regex, or \`evidence \| <id> \| -\` to declare that no evidence exists` | `FAIL         <id> (evidence regex is empty in project.conf; an empty regex matches every log line)` |

Semantics pinned:

- **Duplicate.** Detected in the main loop when a `gate` line's id is already
  in `reached` (line 506) - the **second** line is the fault, the first is
  judged as today, so a file with one good `unit` line and a duplicate below
  it reports `PASS unit` (or whatever the first earns) **and** `FAIL unit
  (declared twice ...)`. Detected before the `--gate`/`--required` filters,
  so `--gate unit` on a duplicated id reports the fault too. `GATE_IDS`
  (line 181) may keep listing the id twice; nothing reads its multiplicity.
  A `fault_lose` id (the `GATES_FAULT_LOSE` test hook) is skipped before
  `reached`, as today, and is not a duplicate.
- **Empty evidence.** `exp` after `table_get exp "$EVIDENCE" "$id"` (line 580)
  is the empty string and `table_get` returned 0 - the line exists with an
  empty value; `rest 3` gives `''` for all three spellings in AC-3, because
  `from_field` returns `''` for fewer than `n` fields and `trim` removes the
  spaces. `<none>` (no line) and `-` keep today's behaviour exactly. The check
  sits where `exp` is read, before the `floor`, `ci-factor`, waiver and
  command checks, and applies to **every** gate line - optional gates and
  unconfigured gates (no command) included, as a broken floor does - because a
  manifest fault is a fault of the file, not of the run. `table_get` returns
  the **first** evidence line of an id, so an empty first line is the fault
  even when a real regex follows it (that is the line `gates.sh` would match
  with).
- **Order between faults for one gate:** one fault per gate, the first in
  source order wins. Where this story's two faults meet (a duplicated id whose
  evidence is empty), the duplicate fault is reported for the second line
  and the empty evidence for the first; RED pins one such case or says it did
  not.

**C-2. `check-boundaries.sh`: the threshold rule, restated whole.** This
replaces HARNESS-083 C-2's threshold paragraph as the single statement of the
rule; the strings for every other finding are unchanged.

> Per gate on both sides and per threshold flag name (the flag ERE `TF` at
> line 949, names in first-occurrence order on the before side), take four
> statistics of the flag's numbers on each side: **first**, **last**,
> **lowest**, **highest**. A finding `threshold lowered <flag> <B> -> <A>`
> when any statistic is lower after than before, compared as numbers; `<B>`
> and `<A>` are the before and after values **of the first statistic that
> fell**, in the fixed order first, last, lowest, highest. No occurrence after
> is `threshold removed <flag> <highest before>`, unchanged. A flag present
> only after is no finding. One finding per flag name.

Why four: a first-wins parser, a last-wins parser (argparse under
pytest-cov), "any lower repeat", and the highest repeat, which is the only
one a lowered middle value moves. Worked rows, which RED turns into fixtures
or reads off HARNESS-083's existing ones:

| before -> after | first | last | lowest | highest | printed |
|---|---|---|---|---|---|
| `=10 =90` -> `=10` | 10,10 | 90,**10** | 10,10 | 90,10 | `90 -> 10` (last) - HARNESS-083, unchanged |
| `=10 =90` -> `=90 =10` | 10,90 | 90,**10** | 10,10 | 90,90 | `90 -> 10` (last) - HARNESS-083, unchanged |
| `=90` -> `=90 =10` | 90,90 | 90,**10** | 90,10 | 90,90 | `90 -> 10` (last) - HARNESS-083's C-2 check, unchanged |
| `80` -> `80 30 90` | 80,80 | 80,90 | 80,**30** | 80,90 | `80 -> 30` (lowest) - HARNESS-083's C-2 check, unchanged |
| `=10 =90` -> `=10 =80` | 10,10 | 90,**80** | 10,10 | 90,80 | `90 -> 80` (AC-6; today `90 -> 10`) |
| `=90 =10` -> `=80 =10` | 90,**80** | 10,10 | 10,10 | 90,80 | `90 -> 80` (AC-7; today `90 -> 10`) |
| `=90 =10 =95` -> `=80 =10 =95` | 90,**80** | 95,95 | 10,10 | 95,95 | `90 -> 80` (AC-7, first arm alone) |
| `60 90 60` -> `60 70 60` | 60,60 | 60,60 | 60,60 | 90,**70** | `90 -> 70` (AC-5, highest arm alone; today silent) |
| `60 90 60` -> `60 95 60` | eq | eq | eq | 90,95 | silent (AC-5 control) |
| `=10 =90` -> `=10 =90` with `-q` | eq | eq | eq | eq | silent (HARNESS-083 control, unchanged) |

Implementation note, not a constraint: the awk already keeps `HI`, `LO`,
`FI`, `LA` per side (lines 935-948); the change is the fourth disjunct at line
992 and the choice of which pair `out()` prints. The second `\t`-separated
fields of `out()` (`<before>\t<after>`) carry the same pair as the string; no
test reads them.

**C-3. Docs.** `.claude/skills/quality-gates/SKILL.md`: triage rule 5a's
parenthesis "a lower repeat of the flag counts, on either side" becomes "any
repeat of the flag lowered counts - first, last, lowest or highest - and the
refusal names the one that fell"; and the paragraph after "A gate with no
`evidence` line behaves exactly as before" (around line 226) gains one
sentence: `--audit` and a run refuse an evidence line with an **empty** regex
(it matches every line) and a gate id declared twice. `VERSION` bumps in GREEN
(`102` -> `103`).

**C-4. Self-tests.** `gates.test.sh`: one `describe` for AC-1/AC-2 and one for
AC-3/AC-4, each built with `write_conf` and `gates --audit` / `gates` as the
existing manifest-fault blocks are (lines 84-99, 160-191). `boundaries.test.sh`:
one `describe` marked HARNESS-088, after HARNESS-083's last describe and
before `summary`, using `conf_story`, `gl_swap`, `gl_refused` and `gl_clean`
as HARNESS-083's return-2 block does (lines 3435-3452; the `gl_py` gate is the
natural base for AC-6/AC-7 and the `lint` gate with `--threshold` for AC-5).
Floors in `floors.conf` and the hand copy in `selftest.test.sh` (`boundaries
502`, `gates 920`) rise in RED to the executed counts. AC-8 is a claim about
assertions that already exist: RED satisfies it by running the HARNESS-083
threshold subset against the shipped tree before writing (all green) and
GREEN by the full suite (all green); no new assertion is needed for it.

**C-5. Oracle partition.** All **mechanical**: exact strings, exit statuses,
and the four-statistic table above, which is **settled** - RED may add a row
it finds missing (with the four statistics worked) but not change a printed
value in an existing one. The `--audit` texts in C-1 are settled too; RED may
tighten wording in place with a reason, and GREEN builds the amended text.

**C-6. Callers of what changes.** No exported name or signature changes.
`project_conf_loosenings` is called only from 3j (`grep -n
project_conf_loosenings scripts/check-boundaries.sh`); `gates.sh`'s main loop
and `--audit` tail are not functions. Both suites drive the scripts, never
their internals.

**Test-only dependencies:** none.

## Deferred verifications

**DV-1 (defect put back; central claim; AC-1/AC-2). Owner: GATES.** With
GREEN in the tree, `bash scripts/mutate.sh scripts/gates.sh '<expr>' -- bash
scripts/selftest.sh gates`, where `<expr>` deletes or disables the duplicate-id
test in the main loop (the gap HARNESS-083 left open is back). AC-1's and
AC-2's refusals **must** go red; AC-1's and AC-2's controls and every other
`gates` assertion stay green. Paste the red, the restore line, and a green
run after. Cannot run in RED: there is no duplicate-id test to delete.

**DV-2 (earns the "first value lowered" test, AC-7; the test is written
against an arm that already exists). Owner: GATES.** `bash scripts/mutate.sh
scripts/check-boundaries.sh '<expr>' -- <narrowest command holding AC-7>`,
where `<expr>` deletes the `FI[2, id, nm] + 0 < FI[1, id, nm] + 0 ||`
disjunct. The `=90 =10 =95` -> `=80 =10 =95` fixture **must** go red (it is
the one row where only the first statistic falls); `=90 =10` -> `=80 =10`
is **expected to stay green** (the highest arm also catches it - say so when
it does, that is the point of having both fixtures). Restore, paste, green
run. The narrowest command is a scratchpad subset of `boundaries.test.sh`
(HARNESS-083 did the same: helpers plus the one describe), never the full
40-minute suite per mutation.

**DV-3 (the new `--audit` rule against a REAL line of the tree). Owner:
GATES.** The real `.claude/harness/project.conf` has `gate | lint      |
required | . |` and no `evidence` lines. Two probes with `mutate.sh` on that
real file, each followed by `bash scripts/gates.sh --audit`:

1. duplicate the real `lint` line (`'/^gate | lint /p'` prints it twice) -
   the audit **must** print `FAIL lint         declared twice: ...` and
   `1 manifest problem(s).`, exit 1;
2. append `evidence | lint |` after it (`'/^gate | lint /a evidence | lint |'`,
   GNU sed, which Git Bash has) - the audit **must** print `FAIL lint
   evidence regex is empty: ...`, exit 1.

Then the audit on the restored file prints `Manifest audit passed.` Paste all
three. If `mutate.sh` refuses `project.conf` for a reason this story did not
foresee, say which and WAIVE with the reason; the fixture in `gates.test.sh`
is then the only evidence and the story's report says so.

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

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-088` from `.claude/harness/models.conf`.
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
  (2026-10-31), dispatched as a `/plan-story` subagent; no model override was
  passed. The story was cut and Context, AC, Contract, Deferred verifications,
  Out of scope and Notes written in this dispatch.

**Oracle partition:** every criterion is mechanical - an exact `--audit` or
run line, an exit status, or a row of C-2's four-statistic table, which is
settled. RED pins exactly and may add a worked row, not change a printed value.

## Out of scope

- **Evidence regexes weakened to something that still matches** - `.`,
  `.*`, `^`, a real regex replaced by a looser one. Whether one regex is
  weaker than another is a judgement, not a comparison the awk can make, and
  `.` is a legitimate regex for a tool whose only output is one line. Kept
  out, as HARNESS-083 did. **One mechanical slice exists and is deliberately
  not taken here:** a regex that matches the empty string (`awk 'BEGIN{exit
  !("" ~ r)}'`: `.*`, `^`, `$`, `x*`) matches every log line exactly as the
  empty regex does, and `--audit` could refuse it with one test. It would
  widen AC-3 by a single case; it is left for the user to pull in or not,
  because it also refuses `^` and `$` spellings somebody may have written on
  purpose. If pulled in, it is one more row in C-1, not a new story.
- **Reading every `gate` line in `project_conf_loosenings`.** The follow-up
  offered two fixes for the duplicate; this story takes the one at the source
  (`gates.sh` refuses it), so `check-boundaries.sh` keeps reading the first
  line per id. A duplicate can no longer survive `gates.sh --audit` in CI,
  which `gates.yml` runs, or a local full run, which stamps nothing while a
  manifest fault stands.
- **`covers` globs narrowed, `ci-factor` changed, `blocked-when`,
  `skipped-when`, `keep-when` and `task` lines**, and thresholds in a stack's
  own configuration files - all out, as in HARNESS-083.
- **`BOOTSTRAPPED`, `floor`, `evidence line removed` and every other finding
  of C-2's table** - unchanged, and their strings are not rewritten.
- **The `--list` output** - it reports, it does not judge; it stays as is.
- **A duplicate id in `floors.conf`** (`selftest.sh`'s own floor table, which
  uses the same grammar) - a different reader and a different file.

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
     otherwise. One block per return: which test, what it asserted, what was
     wrong, how it was found, what it asserts now, and what EARNS it - a probe
     through scripts/mutate.sh with the output pasted as a fence or a
     four-space-indented block. -->

## Gate results

<!-- Written by scripts/gates.sh itself on every full run, stamped with the
     commit and a hash of the code it ran against. Do not paste or edit it:
     check-boundaries.sh refuses a PR whose recorded run does not match the
     code being merged. -->

## Gate probes

<!-- REQUIRED if this story adds or changes a gate, its command, or its
     evidence line. Omit the section entirely otherwise.
     This story changes no gate of this repository's project.conf; it changes
     what gates.sh --audit refuses, and DV-3 is the probe of that rule against
     the real file. Leave this section out at REVIEW unless a gate line of
     this repository's own project.conf changes. -->

## Notes

**PO decisions at PLANNED (2026-10-31), each one the user may overrule:**

1. **One story, not two.** Items 1 and 2 of HARNESS-083's follow-up list are
   both bash/awk against two scripts that already have fixture-driven suites;
   together they are two `describe`s in `gates.test.sh` and one in
   `boundaries.test.sh`, and the GREEN diff is a few dozen lines. One cycle.
2. **Type `feature`.** AC-6 (the message prints numbers the commit did not
   move) is a bug on its own, but the story's weight is two new refusals and
   a widened rule; `fix` would understate it.
3. **The duplicate is refused on a run, not only under `--audit`** (AC-2).
   Every other manifest fault in `gates.sh` is refused both ways, and a local
   full run that stamped a story green over a duplicated manifest would be the
   same hole one step later.
4. **Empty evidence is a FAIL on every gate line, optional and unconfigured
   included** (C-1), as a broken `floor` is; a manifest fault is the file's,
   not the run's.
5. **The refusal prints the first statistic that fell, in the order first,
   last, lowest, highest** (C-2). Any fallen statistic is honest; a fixed
   order makes the string deterministic. The alternative - print the largest
   drop - was not taken because it names a pair no parser reads.
6. **Item 3 (weakened-but-matching regexes) stays out**, with the one
   mechanical slice (a regex matching the empty string) named in `## Out of
   scope` for the user to pull in by adding a row to C-1.
7. **`project_conf_loosenings` keeps reading the first `gate` line per id.**
   Closing the duplicate at the source makes the second line unreachable by
   any judged tree; teaching the awk to read every line would be a second,
   redundant rule with its own fixtures.

**Conflicts (2026-10-31):** `touches:` shares `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh` and `.claude/harness/VERSION` with every one
of HARNESS-084..087, so `plan.sh conflicts` reports CONFLICT against each;
the result is recorded in the planning report. Those three files are the
per-story floor and version bumps every harness story makes; the conflict is
real (two stories bumping `VERSION` from the same base both write `103`) and
is resolved by running this story after whichever of them is in flight, or by
a merge of `main` into this branch before its GATES run, as the Lead PO's
"Two PRs at REVIEW" procedure says.

**Where the checkout stood when this was planned:** the main checkout was on
`story/HARNESS-084-...` with HARNESS-084 active at RED (docs writable, which
is all this planning wrote); the story branch above is created by `phase.sh
set HARNESS-088 RED` from `main` when the story starts, not now.
