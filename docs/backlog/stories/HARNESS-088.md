---
id: HARNESS-088
title: gates.sh refuses a duplicate gate id and an empty evidence regex, and a lowered threshold repeat is refused whichever repeat moved
slug: gates-sh-refuses-a-duplicate-gate-id-and
epic: 
type: feature
status: in-review
phase: REVIEW
branch: story/HARNESS-088-gates-sh-refuses-a-duplicate-gate-id-and
depends_on: []      # HARNESS-083 is DONE (PR #171); nothing else is needed first
touches: [scripts/gates.sh, scripts/check-boundaries.sh, .claude/tests/gates.test.sh, .claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION, .claude/skills/quality-gates/SKILL.md, .claude/tests/sigpipe.test.sh]
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

**Writes:** `scripts/gates.sh`, `scripts/check-boundaries.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`, `.claude/skills/quality-gates/SKILL.md`, `.claude/tests/sigpipe.test.sh` (added in GREEN: its C-5 freshness list pins `scripts/gates.sh:773`, which this story moves - see `## Regressions`)

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
(`106` -> `107`; planned as `102` -> `103` before HARNESS-084..087 landed
at 103..106).

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

**Results (GATES, 2026-11-04, orchestrator, all through `mutate.sh`; `mutate.sh --check` was clean after each).**

The narrow commands are scratchpad subsets built by GREEN:
- `subg.test.sh`: the `gates` helpers plus the two HARNESS-088 describes, 41 assertions;
- `subb.test.sh`: the `boundaries` helpers plus the HARNESS-088 describe, 18 assertions.

The "every other assertion stays green" half rests on the attested full runs on this same tree: `gates` 972/972 and `boundaries` 518/518, tree 6c6ae27.

**DV-1.** gates.sh:512's duplicate test was disabled (`is_dup=0` → `is_dup=1`). All 14 AC-1/AC-2 refusal assertions went red, plus the C-1 both-faults case; no control did. The subset was green again after the restore:

```
=== mutate: scripts/gates.sh (1 line(s) changed by 512s/is_dup=0/is_dup=1/) ===
    FAIL AC-1: --audit prints the duplicate's FAIL line, whole
    FAIL AC-1: and it is the audit's only FAIL line
    FAIL AC-1: the first line is still judged as today
    FAIL AC-1: the audit ends with 1 manifest problem(s).
    FAIL AC-1: and does not say it passed
    FAIL AC-1: and exits 1
    FAIL AC-2: a full run reports the first line, then the duplicate's FAIL, then 1 failed - the whole summary
    FAIL AC-2: and exits 1
    FAIL AC-2: the duplicate runs nothing - unit's command ran once
    FAIL AC-2: an optional second line with a failing command is the same fault, not a WARN - the whole summary
    FAIL AC-2: and that run exits 1
    FAIL AC-2 (C-1): --gate unit on a duplicated id reports the fault too
    FAIL AC-2 (C-1): and exits 1
    FAIL C-1: duplicated id with an empty regex - the first line's empty-regex FAIL, then the second's duplicate FAIL
gates: 27 passed, 14 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261104T012549Z.369222.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
gates: 41 passed, 0 failed
```

**DV-2.** check-boundaries.sh:999's first-value arm was disabled (`if (FI[2..] < FI[1..])` → `if (0)`). As predicted, only the `=90 =10 =95` → `=80 =10 =95` fixture went red. `=90 =10` → `=80 =10` stayed green, because the highest arm prints the same `90 -> 80`; that is why both fixtures exist.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 999s/if (FI\[2, id, nm\] + 0 < FI\[1, id, nm\] + 0)/if (0)/) ===
    FAIL HARNESS-088 AC-7: --cov-fail-under=90 =10 =95 -> =80 =10 =95 (only the first falls): refused by the whole line naming 'coverage: threshold lowered --cov-fail-under 90 -> 80'
         expected: 1
         actual:   0
    FAIL HARNESS-088 AC-7: --cov-fail-under=90 =10 =95 -> =80 =10 =95 (only the first falls): and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
         expected: 1|1
         actual:   0|0
boundaries: 16 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261104T012219Z.364136.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**DV-3.** Both probes were on the real `.claude/harness/project.conf` (line 311, `gate | lint      | required | . |`). After both, the restored file audits clean:

```
=== mutate: .claude/harness/project.conf (1 line(s) changed by /^gate | lint /p) ===
FAIL lint         declared twice: a second `gate` line for one id; gates.sh would run both and check-boundaries.sh judges only the first - keep one
1 manifest problem(s).
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_harness_project.conf.20261104T012144Z.363404.bak) ===
=== mutate: .claude/harness/project.conf (1 line(s) changed by /^gate | lint /a evidence | lint |) ===
FAIL lint         evidence regex is empty: an empty regex matches every log line, so the gate would pass having checked nothing. Write the regex, or `evidence | lint | -` to declare that no evidence exists
1 manifest problem(s).
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_harness_project.conf.20261104T012150Z.363504.bak) ===
Manifest audit passed.
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

All the tests are mechanical, one level: the suites run the real scripts in a
fixture repository and pin whole lines, exit statuses and summaries. Nothing
reads either script's internals (C-6).

**`.claude/tests/gates.test.sh`**: two describes before `summary "gates"`, on
the shared `$FIX`, each starting from no active story. `h88_conf` writes
project.conf from whole lines with `printf`, so AC-3's trailing-space spelling
survives. The C-1 `<why>` texts are the constants `H88_DUP_AUDIT`,
`H88_DUP_RUN`, `H88_EMPTY_AUDIT` and `H88_EMPTY_RUN`, copied from C-1. They are
compared as whole lines (`count_line`, which is `grep -cxF`), as the complete
list of `^FAIL` lines (`h88_fails`), or as the complete run summary
(`verdict_of`, the HARNESS-052 helper, with timings masked to `(Ns`).

- `HARNESS-088 AC-1/AC-2`:
  - AC-1 is the duplicate under `--audit`. The FAIL line is whole and is the
    only FAIL. The first line is still `ok   unit         evidence: ...`
    exactly once. The audit ends `1 manifest problem(s).`, does not print
    `Manifest audit passed.`, and exits 1.
  - AC-1 control: the second line deleted gives `Manifest audit passed.`, no
    FAIL and rc 0.
  - AC-2 is the duplicate on a full run. The whole summary is `PASS unit (Ns,
    observed 47)` / the duplicate FAIL / `1 required gate(s) failed.`, rc 1,
    and `=== gate: unit (required) ===` appears once, so the duplicate runs
    nothing. The same holds for the HARNESS-083 round-2 shape (the second line
    is `optional` with `exit 1`, which today is a WARN at rc 0), and for
    `--gate unit` (C-1: the fault is detected before the filter).
  - AC-2 control: one line gives the whole summary `PASS` / `All required
    gates passed (1 ran, 0 unconfigured, 0 known).` and rc 0.
- `HARNESS-088 AC-3/AC-4`:
  - AC-3 runs `evidence | unit |`, `evidence | unit` and `evidence | unit |   `
    under `--audit`. Each gives the empty-regex FAIL as the only FAIL,
    `1 manifest problem(s).` and rc 1.
  - AC-3 controls: `-` is still `ok   unit         (liveness declared
    unassertable)`, and no evidence line is still `WARN unit         no
    evidence line; ...`. Each has no FAIL line, prints `Manifest audit
    passed.` and exits 0.
  - C-1 semantics: the same FAIL on an **optional** gate, on an
    **unconfigured** gate (no command), and on an empty **first** evidence line
    with a real regex after it.
  - AC-4: `printf 'nothing here\n'` under `evidence | unit |`, on a full run,
    gives the whole summary = the empty-regex run FAIL plus `1 required gate(s)
    failed.`, no `PASS unit` line, and rc 1.
  - AC-4 control: the same command under `evidence | unit | nothing here`
    gives the whole summary `PASS unit (Ns)` / `All required gates passed (1
    ran, 0 unconfigured, 0 known).` and rc 0. There is no `observed` count,
    because the matched line has no digits.
  - C-1, both faults on one gate (**pinned**): two `gate | unit` lines and
    `evidence | unit |`. The FAIL lines are exactly the empty-regex line, then
    the duplicate line, then `2 manifest problem(s).`, rc 1.

**`.claude/tests/boundaries.test.sh`**: one describe, `HARNESS-088: a repeated
threshold flag is judged by four statistics, and the refusal names the pair
that fell`. It sits after HARNESS-083 return 2 and before `summary`, uses
HARNESS-083's `conf_story`, `gl_swap`, `gl_refused` and `gl_clean`, and ends
with `checkout main`. Each `gl_refused` call is two assertions: the whole
`[gate-loosened]` line, and `rc|FAIL lines` = `1|1`. Each `gl_clean` call is
two: `0|`, and 3j's `1 commit(s) judged` line.

| case (C-2 row) | finding pinned | AC |
|---|---|---|
| lint `60 90 60` -> `60 70 60` | `lint: threshold lowered --threshold 90 -> 70` | AC-5 |
| lint `60 90 60` -> `60 95 60` | clean | AC-5 control |
| lint `60 90 60` with `-q` added | clean | AC-5 control |
| python `=10 =90` -> `=10 =80` | `coverage: threshold lowered --cov-fail-under 90 -> 80` | AC-6 |
| python `=90 =10` -> `=80 =10` | `... --cov-fail-under 90 -> 80` | AC-7 |
| python `=90 =10 =95` -> `=80 =10 =95` | `... --cov-fail-under 90 -> 80` (first arm alone; DV-2's fixture) | AC-7 |
| python `=90` -> `=90 =10` | `... --cov-fail-under 90 -> 10` (C-2 row "HARNESS-083's C-2 check") | C-2 |
| lint `80` -> `80 30 90` | `lint: threshold lowered --threshold 80 -> 30` (C-2 row, lowest arm) | C-2 |

AC-8 needs no new assertion (C-4). It was run against today's tree before
anything was written; the result is in the handoff.

**Floors**: `gates 920 -> 972` (+41 new, plus 11 that HARNESS-080 added
without raising the floor), `boundaries 502 -> 518` (+16), in `floors.conf`
and in its hand copy in `selftest.test.sh`.

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

RED was written on 2026-11-03 by `test-developer`, running on
**claude-opus-5-5** with no override. Every timing below is local; none is
from CI.

**Commands.**

    bash scripts/selftest.sh gates           # ~20 min here
    bash scripts/selftest.sh boundaries      # ~56 min here, host under load
    bash scripts/gates.sh --fast

Both new suites can be iterated on a scratch subset instead:

- `sub088.test.sh` takes boundaries.test.sh lines 1-110, 1985-2092, 2879-3024
  and the HARNESS-088 describe through to the end, with line 9 rewritten to the
  absolute `_lib.sh`. It runs in about 6 minutes: 18 assertions, which are the
  HARNESS-081 fixture, the HARNESS-083 premise and the 16 new ones.
- for gates, take lines 1-13 (line 8 rewritten to the absolute `_lib.sh`),
  843-844 (`count_line`, `count_re`), 3219-3226 (`verdict_of`) and the
  HARNESS-088 block. It runs in about 2.5 minutes.

**Attested runs** (the tree is `619fe3c...`, with every test file staged):

    bash scripts/attest.sh -- bash scripts/selftest.sh gates
      exit: 1  last: 1 of 1 harness suite(s) FAILED.
      log:  .claude/state/attest-logs/20261103T210541Z.42206.log
    bash scripts/attest.sh -- bash scripts/selftest.sh boundaries
      exit: 1  last: 1 of 1 harness suite(s) FAILED.
      log:  .claude/state/attest-logs/20261103T212522Z.67393.log
    bash scripts/attest.sh -- bash scripts/gates.sh --fast
      exit: 0  last: All required gates passed (0 ran, 5 unconfigured, 0 known).
      log:  .claude/state/attest-logs/20261103T222132Z.120108.log

Every gate in this repository is UNCONFIGURED, so `--fast` judges nothing
here. Its shape is correct: no gate failed on a config error or a timeout. The
real tree's `gates.sh --audit` still prints `Manifest audit passed.`

**Failure, gates** (the full suite, trimmed to the failures and the summary;
all 30 come after the `HARNESS-088 AC-1/AC-2` header, and none comes before it):

```
  HARNESS-088 AC-1/AC-2: a gate id declared twice is a manifest fault, under --audit and on a run
    FAIL AC-1: --audit prints the duplicate's FAIL line, whole
    FAIL AC-1: and it is the audit's only FAIL line
    FAIL AC-1: the first line is still judged as today
    FAIL AC-1: the audit ends with 1 manifest problem(s).
    FAIL AC-1: and does not say it passed
    FAIL AC-1: and exits 1
    FAIL AC-2: a full run reports the first line, then the duplicate's FAIL, then 1 failed - the whole summary
    FAIL AC-2: and exits 1
    FAIL AC-2: the duplicate runs nothing - unit's command ran once
    FAIL AC-2: an optional second line with a failing command is the same fault, not a WARN - the whole summary
    FAIL AC-2: and that run exits 1
    FAIL AC-2 (C-1): --gate unit on a duplicated id reports the fault too
    FAIL AC-2 (C-1): and exits 1

  HARNESS-088 AC-3/AC-4: an empty evidence regex is a manifest fault, under --audit and on a run
    FAIL AC-3: 'evidence | unit |' - --audit's only FAIL line is the empty-regex one, whole
    FAIL AC-3: 'evidence | unit |' - the audit ends with 1 manifest problem(s).
    FAIL AC-3: 'evidence | unit |' - and exits 1
    FAIL AC-3: 'evidence | unit' - --audit's only FAIL line is the empty-regex one, whole
    FAIL AC-3: 'evidence | unit' - the audit ends with 1 manifest problem(s).
    FAIL AC-3: 'evidence | unit' - and exits 1
    FAIL AC-3: 'evidence | unit |   ' - --audit's only FAIL line is the empty-regex one, whole
    FAIL AC-3: 'evidence | unit |   ' - the audit ends with 1 manifest problem(s).
    FAIL AC-3: 'evidence | unit |   ' - and exits 1
    FAIL AC-3 (C-1): an OPTIONAL gate with an empty regex is the same FAIL - FAIL lines|rc
    FAIL AC-3 (C-1): an UNCONFIGURED gate with an empty regex is the same FAIL, not ok (unconfigured) - FAIL lines|rc
    FAIL AC-3 (C-1): an empty FIRST evidence line is the fault though a real regex follows - FAIL lines|rc
    FAIL AC-4: a full run - the whole summary is the empty-regex FAIL and 1 failed
    FAIL AC-4: no PASS line for unit
    FAIL AC-4: and the run exits 1
    FAIL C-1: duplicated id with an empty regex - the first line's empty-regex FAIL, then the second's duplicate FAIL
    FAIL C-1: and that is 2 manifest problem(s)., exit 1

gates: 942 passed, 30 failed
FAIL gates  did 942 units of work, below the floor of 972 in .claude/tests/floors.conf
```

Two of the failures, shown with their expected and actual values:

```
    FAIL AC-2: a full run reports the first line, then the duplicate's FAIL, then 1 failed - the whole summary
         expected: PASS         unit (Ns, observed 47)
         FAIL         unit (declared twice: a second `gate` line for one id in project.conf; keep one)
         1 required gate(s) failed.
         actual:   PASS         unit (Ns, observed 47)
         PASS         unit (Ns, observed 47)
         All required gates passed (2 ran, 0 unconfigured, 0 known).
    FAIL AC-4: a full run - the whole summary is the empty-regex FAIL and 1 failed
         expected: FAIL         unit (evidence regex is empty in project.conf; an empty regex matches every log line)
         1 required gate(s) failed.
         actual:   PASS         unit (Ns)
         All required gates passed (1 ran, 0 unconfigured, 0 known).
```

**Failure, boundaries** (the full suite; all 5 come after the HARNESS-088
header, and none comes before it):

```
  HARNESS-088: a repeated threshold flag is judged by four statistics, and the refusal names the pair that fell
    FAIL HARNESS-088 AC-5: --threshold 60 90 60 -> 60 70 60 (only the highest falls): refused by the whole line naming 'lint: threshold lowered --threshold 90 -> 70'
         expected: 1
         actual:   0
    FAIL HARNESS-088 AC-5: --threshold 60 90 60 -> 60 70 60 (only the highest falls): and that is the run's only FAIL, so it exits 1 - rc|FAIL lines
         expected: 1|1
         actual:   0|0
    FAIL HARNESS-088 AC-6: --cov-fail-under=10 =90 -> =10 =80 names the pair that moved: refused by the whole line naming 'coverage: threshold lowered --cov-fail-under 90 -> 80'
         expected: 1
         actual:   0
    FAIL HARNESS-088 AC-7: --cov-fail-under=90 =10 -> =80 =10 (first and highest fall): refused by the whole line naming 'coverage: threshold lowered --cov-fail-under 90 -> 80'
         expected: 1
         actual:   0
    FAIL HARNESS-088 AC-7: --cov-fail-under=90 =10 =95 -> =80 =10 =95 (only the first falls): refused by the whole line naming 'coverage: threshold lowered --cov-fail-under 90 -> 80'
         expected: 1
         actual:   0

boundaries: 513 passed, 5 failed
FAIL boundaries  did 513 units of work, below the floor of 518 in .claude/tests/floors.conf
```

**Why these are the right failures.** Both suites load and run to `summary`.
Every pre-existing assertion passes: gates 931 and boundaries 502, the
executed counts before this story. Each red is an assertion this story
introduces, and it fails on today's behaviour:

- **gates.sh accepts the duplicate.** The audit prints `ok` twice and
  `Manifest audit passed.`; the run executes both lines and passes.
- **gates.sh accepts the empty regex.** The audit prints `ok   unit
  evidence: ` with rc 0; the run gives `PASS unit (Ns)`.
- **check-boundaries.sh has three statistics.** AC-5 is silent today (rc 0,
  no FAIL). AC-6/AC-7's refusals still fire (their `rc|FAIL lines` halves pass
  as `1|1`), but they print `<highest before> -> <lowest after>` (line 993).
  That pair is `90 -> 10`, `90 -> 10` and `95 -> 10`, which I derived from the
  line and did not print. Either way it is not the whole line pinned, so the
  whole-line half is red.

**Files touched, and the AC each covers.**

- `.claude/tests/gates.test.sh`: describes `HARNESS-088 AC-1/AC-2` (AC-1,
  AC-2, C-1's `--gate` clause) and `HARNESS-088 AC-3/AC-4` (AC-3, AC-4, C-1's
  optional / unconfigured / first-line clauses, C-1's both-faults case), with
  41 assertions. The Test plan has one line per case.
- `.claude/tests/boundaries.test.sh`: describe `HARNESS-088: ...`, with 16
  assertions (AC-5, AC-6, AC-7, and two C-2 rows).
- `.claude/tests/floors.conf`: `gates 920 -> 972`, `boundaries 502 -> 518`,
  with a comment.
- `.claude/tests/selftest.test.sh`: its hand copy, the same two numbers.
  `bash scripts/selftest.sh selftest` gives 268 passed, 0 failed.
- this story: `## Test plan` and this handoff.

**What the tests pin for GREEN.** They pin no function or exported name, only
the scripts' output:

- **gates.sh, `--audit`**: the exact lines are
  `printf 'FAIL %-12s %s\n' unit '<C-1 audit why>'` for both faults, with C-1's
  texts byte for byte (the backticks and `|` included), then
  `N manifest problem(s).` and exit 1. A duplicated first line must still
  print its own `ok   unit         evidence: <regex>` exactly once.
- **gates.sh, run**: the lines are `FAIL         unit (<C-1 run why>)` in
  `results`, counted in `fails`, giving `N required gate(s) failed.` and exit
  1. This was read off the slow-with-no-reason case, whose summary is
  `5 required gate(s) failed.`; that is the line this summary takes. The
  duplicate's FAIL comes after the first line's PASS, in source order, and
  the duplicate runs nothing: `=== gate: unit (required) ===` is printed once.
- **Both faults on one gate**: the first line gets the empty-regex fault and
  the second the duplicate, in that order, giving `2 manifest problem(s).`.
  That is C-1's "one fault per gate line, the first in source order wins".
  It follows if the duplicate test sits before `table_get exp` and the
  empty-evidence test right after it.
- **check-boundaries.sh**: the whole `[gate-loosened]` line through
  `want_gl`, with the pair as in C-2's table. Nothing reads `out()`'s
  tab-separated `<before>\t<after>` fields.
- **Not constrained**: where in the loop the duplicate test sits, provided it
  comes before the `--gate`/`--required` filters and after `fault_lose`;
  `GATE_IDS`' multiplicity; `--list` output (C-1: unchanged, no test);
  `GATES_FAULT_LOSE` on a duplicated id (not pinned); and how the awk chooses
  the pair, provided the order is first, last, lowest, highest.

**Passed on arrival** (11 in gates, 11 in boundaries), and what earns each:

| assertion | why it passes today | earned by |
|---|---|---|
| gates AC-1 control (3), AC-2 control (2) | a single `gate` line is today's manifest | negative controls: AC-1/AC-2 are the same fixture plus one line, and they are red |
| gates AC-3 controls (4): `-` is ok, no line is WARN | today's behaviour, which must survive | negative controls: AC-3's three spellings, one token away, are red |
| gates AC-4 control (2): `nothing here` regex PASS | today's behaviour | negative control: AC-4, the same command with an empty regex, is red |
| boundaries AC-5 controls (4): 60 95 60, `-q` added | nothing fires today | negative controls: AC-5 (60 70 60) is red. They become discriminating once GREEN adds the highest arm, since a reversed comparison would fire on 95 |
| boundaries AC-6, AC-7 x2 `rc\|FAIL lines` (3) | today refuses once, with the wrong pair | paired with their whole-line halves, which are red |
| boundaries C-2 rows `=90`->`=90 =10` and `80`->`80 30 90` (4) | today's `<highest before> -> <lowest after>` happens to be the right pair | **mutation, run in RED**, below |

The two C-2 rows were earned by printing `<highest before> -> <highest after>`
(scratch subset `sub088c2.test.sh`: the helpers, the fixture and those two
cases):

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by s/" -> " LO\[2, id, nm\], b, LO\[2, id, nm\])/" -> " HI[2, id, nm], b, HI[2, id, nm])/) ===
  993 -               out(id, "threshold lowered " nm " " b " -> " LO[2, id, nm], b, LO[2, id, nm])
  993 +               out(id, "threshold lowered " nm " " b " -> " HI[2, id, nm], b, HI[2, id, nm])
  HARNESS-088 C-2 rows (probe subset)
    FAIL HARNESS-088 C-2 row: --cov-fail-under=90 -> =90 =10 (the last falls): refused by the whole line naming 'coverage: threshold lowered --cov-fail-under 90 -> 10'
         expected: 1
         actual:   0
    FAIL HARNESS-088 C-2 row: --threshold 80 -> 80 30 90 (the lowest falls): refused by the whole line naming 'lint: threshold lowered --threshold 80 -> 30'
         expected: 1
         actual:   0
boundaries: 4 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261103T201154Z.14057.bak) ===
  993:               out(id, "threshold lowered " nm " " b " -> " LO[2, id, nm], b, LO[2, id, nm])
```

`mutate.sh --check` afterwards reported no stranded mutation.

**Negative controls, expected values.** Every gates control was run against
today's gates.sh and passed with these values. GREEN must confirm the same
values against its own code.

| control | expected (measured today) |
|---|---|
| AC-1: one `gate \| unit` line, `--audit` | `Manifest audit passed.`, no FAIL line, rc 0 |
| AC-2: one line, full run | `PASS         unit (Ns, observed 47)` / `All required gates passed (1 ran, 0 unconfigured, 0 known).`, rc 0 |
| AC-3: `evidence \| unit \| -` | `ok   unit         (liveness declared unassertable)`, audit passed, rc 0 |
| AC-3: no evidence line | `WARN unit         no evidence line; a vacuous pass would go unnoticed`, audit passed, rc 0 |
| AC-4: `evidence \| unit \| nothing here` | `PASS         unit (Ns)` (no count: the line has no digits) / `All required gates passed (1 ran, 0 unconfigured, 0 known).`, rc 0 |
| AC-5: `60 90 60` -> `60 95 60` | rc 0, no FAIL, `ok    GREEN/GATES added no suppression (1 commit(s) judged)` |
| AC-5: `60 90 60` with `-q` | the same |

**AC-8 (C-4), run before anything was written.** HEAD was 1f344cd, with
boundaries.test.sh unmodified. The subset is boundaries.test.sh lines 1-110,
1985-2092 and 2879-end, which is every HARNESS-083 describe, so it includes
every threshold fixture AC-8 names. Local, 30m22s:

    boundaries: 144 passed, 0 failed
    rc=0

The full suite on this RED tree also passes all 502 pre-existing assertions;
its only 5 failures are new.

**Deferred verifications: I decline all three; they belong to GATES.**
DV-1 cannot run in RED, because no duplicate-id test exists yet to delete.
DV-2 and DV-3 are GATES's, by the story. Expected values for DV-2, removing
the `FI[2, id, nm] + 0 < FI[1, id, nm] + 0 ||` disjunct:

| fixture | statistics (B,A) | expected under the mutation |
|---|---|---|
| `=90 =10 =95` -> `=80 =10 =95` | first 90,80; last 95,95; lowest 10,10; highest 95,95 | **red**: only the first falls, so nothing fires (rc 0, whole line absent) |
| `=90 =10` -> `=80 =10` | first 90,80; last 10,10; lowest 10,10; highest 90,80 | **green**: the highest arm fires and prints `90 -> 80` from the highest pair, which is the same pair |

**Amendments.** None. No contract block or AC changed.

**Discovered.**

1. The gates floor was stale. `floors.conf` said 920 while the suite executed
   931, because HARNESS-080 (5db0542) added 11 assertions and raised nothing.
   The attest logs in this worktree show `gates: 931 passed, 0 failed` at
   release 106. The new floor is the executed count, 972 = 931 + 41, not the
   briefed 920 + 41.
2. In the AC-4 control the PASS line carries no `observed` count, because the
   matched line has no digits. I read the expected value off the real run.

## Regressions

### GREEN -> RED: a stale line-number pin in `sigpipe.test.sh` C-5

**Which test.** `.claude/tests/sigpipe.test.sh`, the assertion `C-5 freshness:
all twelve status-discarded lines are still where this suite says they are`.
Its `DISCARDED` list (line 581) pinned
`scripts/gates.sh:773:why="could not launch: $(` - asserting that line 773 of
`gates.sh` still holds that status-discarded command substitution, so that the
C-5 exclusion assertion about it is not vacuous.

**What was wrong.** The pin is a line number, and this story's GREEN moves it:
GREEN inserted 28 lines above that statement in `gates.sh`, so it now sits at
line 801 (on HEAD `647f80b` it is at 773; in the working tree at 801). The
story's `## Contract` did not list `.claude/tests/sigpipe.test.sh` as a file the
change would reach, so RED did not update the pin. The assertion was correct;
its data was stale. The other four pins into files this story changes
(`gates.sh:93`, `check-boundaries.sh:395`, `434`, `626`) still hold.

**How it was found.** The GREEN feature-developer's narrow sigpipe run, which
reported:

    scripts/gates.sh:773 no longer holds [why="could not launch: $(] - it holds:     fi

**What it asserts now.** The same thing at the new address:
`scripts/gates.sh:801:why="could not launch: $(`. One number changed; no
needle, no other spec line and no assertion count changed (floor 91).

**What earns it.** One mutation through `scripts/mutate.sh`, changing the text
at `gates.sh:801` so the pin can no longer match. The freshness assertion goes
red naming `scripts/gates.sh:801`, and the file is restored and verified:

```
=== mutate: scripts/gates.sh (1 line(s) changed by 801s/could not launch: /could not start: /) ===
  801 -       why="could not launch: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"
  801 +       why="could not start: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"

=== mutate: running bash .claude/tests/sigpipe.test.sh ===
...
    FAIL C-5 freshness: all twelve status-discarded lines are still where this suite says they are
         expected: 12 lines, none stale
         actual:   12 lines,
           scripts/gates.sh:801 no longer holds [why="could not launch: $(] - it holds:       why="could not start: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"
...
sigpipe: 90 passed, 1 failed

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_gates.sh.20261103T225950Z.147073.bak) ===
  801:       why="could not launch: $(clean_log "$log" | grep -Eom1 -- "$blockpat" | head -1)"
```

`bash scripts/mutate.sh --check` afterwards:
`mutate: no stranded mutation; nothing of a previous run is in the tree.`

Unmutated, attested: `bash scripts/attest.sh -- bash scripts/selftest.sh sigpipe`
- exit 0, `sigpipe: 91 passed, 0 failed`, floor met (91 executed, 91 declared),
`last: 1 harness suite(s) passed.`, log
`.claude/state/attest-logs/20261103T230505Z.157107.log`, tree
`6c6ae27deb7d064c69fa20e7e196c497907c8b74`. `attest.sh check` on that command
reports `fresh` after this section was written.

## Diff review

Round 1 (2026-11-04). A fresh feature-developer ran the review with the `diff-review` skill. It resolved to claude-opus-5-5, with no override, and changed no file. Its report, as returned:

What this change does: `scripts/gates.sh` now refuses a project.conf in two new cases: an id with a second `gate` line, and an `evidence` line with an empty regex. It refuses them both under `--audit` and on a run, in the same shape as the existing manifest faults. `scripts/check-boundaries.sh` block 3j now judges four values of a repeated threshold flag (first, last, lowest, highest), and the refusal prints the before and after of the first one that fell. The SKILL.md text, VERSION 107, the floors and one sigpipe line pin are updated to match.

What I checked:
- Read the whole `git diff main...HEAD`, the main loop of gates.sh (lines 480-650), the post-loop audit checks, the lost-gate accounting (lines 1105-1117), and the awk function with its only consumer (check-boundaries.sh lines 1090-1110).
- Ran the awk function from the branch on scratch fixtures under gawk, `gawk --posix` and `gawk --traditional`. There is no mawk on this host.
- Ran `gates.sh --list` and `--audit` from the branch in a scratch repo, on a manifest with a duplicated id and an empty regex.

On the orchestrator's points:

1. **`is_dup`.** The logic is right. The test runs before the append, so the first line is never a duplicate and the second is. The 0-means-yes value follows the convention the same loop already uses: `is_skip=0` (line 549) and `is_slow=$?` / `is_ondemand=$?` (shell exit status, 0 = true). The name is consistent with its neighbours, so it is not a defect and not worth a change.

2. **Placement of the empty-regex check.** It contradicts the letter of C-1's "every gate line" on a run. It does not matter in practice:
   - A gate skipped on a run (on request, slow under `--fast`, `--gate`/`--required`/`--skip` filtered) runs no command, so there is no vacuous pass to stop.
   - `--audit` reaches the check for every line, because the on-request and slow skips are guarded by `AUDIT=0`. The fixture shows it.
   - The existing broken-floor fault, which C-1 names as its model, sits after the same filters, so the placement matches that precedent.
   - One small side effect: a gate whose `ondemand` line is itself broken reports only that fault until it is fixed. That is C-1's "one fault per gate".

3. **Interactions.**
   - `--list`: both checks are guarded by `LIST=0`. The probe printed both `unit` lines and an empty `evidence:`, as C-1 requires.
   - Lost-gate accounting: the duplicate is still added to `reached` before the `continue`. `GATE_IDS` lists the id twice and `reached` lists it twice, so both entries are paid off and no "never accounted for" line appears.
   - `GATES_FAULT_LOSE`: a lost id is skipped before the duplicate test and before `reached`, so it is never a duplicate. A lost id declared twice gives two "never accounted for" lines, as before.
   - `--gate`/`--required`: the duplicate test is before both filters. So a filtered run on any duplicated id fails, even when that id is not the one asked for. This matches the "filtered or not" stance of the lost-gate accounting. The empty-regex check is after the filters (see 2).

4. **awk.**
   - `fb = fa = ""` (chained assignment) and the `if / else if` chain are POSIX awk. Both ran correctly under `--posix` and `--traditional`.
   - `fb` is always a non-empty number string when a value fell, so `fb != ""` is a sound test, including for `0`.
   - The `out()` pair (fields 3 and 4) equals the `B -> A` in the message. The only consumer reads only `sup_gid` and `sup_what`.
   - `threshold removed`, floor, evidence, covers, discovery and severity findings are unchanged. Probes: `60 90 60 -> 60 70 60` printed `90 -> 70`, and `60 90 -> 60.5 89.9` printed `90 -> 89.9`.

5. **Other pins.** I grepped `.claude/tests/` for `gates.sh:N` and `check-boundaries.sh:N`.
   - Every pin in gates.sh is below line 503, except the moved 801, which I confirmed holds `why="could not launch: $(`.
   - The check-boundaries.sh pins (144-626) are all above the change at about line 910.
   - No test reads the changed SKILL.md wording, the check-boundaries.sh comment or VERSION.

Should fix:

1. **The `--list` exemption of both new faults has no test** (`scripts/gates.sh:514`, `:601`)
   - **What this is:** The `[ "$LIST" = 0 ]` guard on each new check. It makes `--list` print a duplicated id's two lines and an empty `evidence:`, as C-1 requires.
   - **Problem:** No `gates --list` test uses a duplicate or an empty regex. If either guard is dropped, `--list` stops printing the second line, or the empty-regex gate entirely: the check `continue`s and `--list` exits 0 before results are printed. Every test stays green.
   - **Fix:** One `--list` assertion on the manifest from the C-1 "two faults meet" case: both `unit` lines present, rc 0. This is a return to RED, and the test must be earned with one `mutate.sh` run that drops a guard.
   - **If we skip it:** `--list` can silently stop describing the manifest it is asked to show, with no failure. The impact is low: `--list` is descriptive and judges nothing.

Not checked: mawk 1.3.4 itself (it is not installed here; I used gawk's `--posix` and `--traditional` modes instead). I ran neither scratch subset, nor the full gates or boundaries suites.

Model: Opus 5.5 (claude-opus-5-5), as the feature-developer definition declares. I was not dispatched with an override.

Verdict: Ship.

**PO decisions on round 1.**
- **PO decision 8, on points 1 and 2: accepted as built.** `is_dup` follows the loop's own 0-means-yes convention. The empty-regex check's placement on a run matches the broken-floor precedent C-1 names; a skipped gate runs nothing that could pass vacuously; and `--audit`, which CI runs, judges every line. C-1's "every gate line" is read as "every line `--audit` judges".
- **PO decision 9, on Should fix 1: declined for this story, filed as a follow-up.** `--list` judges nothing. The test means a return to RED and another 18-minute `gates` run for a descriptive path. The reviewer's probe showed `--list` printing both lines and the empty `evidence:` on this tree. The follow-up is one `--list` assertion on the both-faults manifest, earned by dropping one `LIST` guard with `mutate.sh`.
- mawk 1.3.4 is not on this host. CI runs the `boundaries` suite under it, so the PR's CI run is the mawk check.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-04T01:27:58Z
    commit: 3391c15
    tree:   f98cec274470ab9c56c0e43847ffbd95e069d96f
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

**Pre-dispatch checks (orchestrator, PLANNED → RED, 2026-11-03, release 106):**
none of `scripts/gates.sh`, `scripts/check-boundaries.sh`,
`.claude/tests/gates.test.sh` or `.claude/tests/boundaries.test.sh` has
changed since this story was planned (d8cfc42). The Contract's line
references hold: gates.sh 181, 506, 580 and 997, and check-boundaries.sh 949
(`TF`) and 992 (the three-disjunct test). The floors are still
`boundaries 502` and `gates 920` in both tables. Rule 5a's parenthesis is
at quality-gates SKILL.md:613-614, and the "behaves exactly as before"
paragraph is at :225. The only stale item was C-3's VERSION number, now
106 → 107, a contract edit at PLANNED with no AC touched. Callers (C-6):
`project_conf_loosenings` is called only from 3j, which I rechecked; no
signature changes. `epic:` is empty, so there is no done-when to check. No
configured gate here; the artifact is judged by `selftest.sh gates`,
`selftest.sh boundaries` and `gates.sh --audit`, all run by CI.

**RED verification (orchestrator, 2026-11-03):** the test-developer resolved to
claude-opus-5-5. All three attest records were `fresh` on tree 619fe3c:
- `selftest.sh gates`: `exit: 1`, `gates: 942 passed, 30 failed`.
- `selftest.sh boundaries`: `exit: 1`, `boundaries: 513 passed, 5 failed`.
- `gates.sh --fast`: `exit: 0`; no gate is configured.
In both logs every FAIL line falls after the first `HARNESS-088` header
(0 before it), so no pre-existing assertion broke. The gates floor goes to
972, not 961, because HARNESS-080 left it at 920 while the suite executed
931. That 931 is confirmed by HARNESS-087's self-test log
(`20261103T162503Z.12206.log`: `gates: 931 passed, 0 failed`). I read the
new gates describes' assertions; `mutate.sh --check` is clean. No command
was re-run by the orchestrator.

**GREEN verification (orchestrator, 2026-11-04):**
- The feature-developer resolved to claude-opus-5-5, both before and after the RED return.
- RED return R-1 (`sigpipe.test.sh` pin 773 → 801): test-developer resolved to claude-opus-5-5. I reproduced the moved line myself (HEAD 773, tree 801), and the other four pins still hold.
- All four attest records were `fresh` on tree 6c6ae27, each with `exit: 0`:
  - `selftest.sh gates`: 972/972, 1101 s;
  - `selftest.sh boundaries`: 518/518, 3489 s;
  - `selftest.sh sigpipe`: 91/91;
  - `gates.sh --fast`: 0 gates configured.
- `gates.sh --audit` on the real file: `Manifest audit passed.`
- I read both script diffs. Two points for the diff review:
  - `is_dup` is 0 when the id IS a duplicate, an inverted name;
  - the empty-regex check sits after the ondemand / `--fast`-slow skips, so a skipped gate is judged only under `--audit`. The developer reported this.
- No command was re-run by the orchestrator.

**GATES verification (orchestrator, 2026-11-04):** I ran DV-1..DV-3 myself
with `mutate.sh`; the results are pasted in their block. The full gates
were dispatched to a feature-developer, which resolved to claude-opus-5-5.
`attest.sh check -- bash scripts/gates.sh` answered `fresh` with `exit: 0`.
The verdict, at log line 17 of
`.claude/state/attest-logs/20261104T012754Z.372179.log`, is
`All required gates passed (0 ran, 7 unconfigured, 0 known).`
- Follow-up, not this story (diff review round 1, Should fix 1, PO decision 9): add a `gates --list` assertion on a manifest with a duplicated id and an empty regex (both lines present, rc 0), earned by dropping one `LIST` guard with `mutate.sh`. It needs a failing test first.
- Self-test at GATES → REVIEW (2026-11-04), dispatched to a feature-developer (resolved to claude-opus-5-5): `attest.sh check -- SELFTEST_JOBS=4 bash scripts/selftest.sh` answered `fresh`, `exit: 1`, `last: 1 of 34 harness suite(s) FAILED.`, `duration: 11419s`, log `.claude/state/attest-logs/20261104T014702Z.396343.log`. The only failure is `mutate`, with 306 passed and 2 failed: HARNESS-030 AC-6 C-1 (`--check` with `HARNESS_MUTATION` naming a live sentinel, expected exit 0, got 1). The floor shortfall 306/308 is the same two failures. This branch does not change `scripts/mutate.sh` or `.claude/tests/mutate.test.sh` (`git diff --stat main...HEAD` over both is empty). The orchestrator re-ran `bash .claude/tests/mutate.test.sh` alone on the same tree: `mutate: 308 passed, 0 failed` in 236 s. Cause not shown. One candidate the log does not confirm: C-1's "live" process is a `sleep 30` planted at AC-4, and the run's 11,419 s suggests heavy host load. Under that load the window may close before C-1 runs. The control just before C-1 still saw the process RUNNING.
- PO decision 10 (2026-11-04, user's choice "Open the PR"): go to REVIEW without a second local self-test. CI's self-test on the PR runs every suite and is the confirmation for `mutate` HARNESS-030 AC-6 C-1. If it fails there too, the story returns to GATES.
