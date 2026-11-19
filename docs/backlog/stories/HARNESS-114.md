---
id: HARNESS-114
title: Docs-read rule pins brace with quote
slug: docs-read-rule-pins-brace-with-quote
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-114-docs-read-rule-pins-brace-with-quote
depends_on: [HARNESS-113]      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/shipped-docs.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the shipped-docs suite under its selftest floor, which CI runs in full on the PR
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

No epic, as HARNESS-106, -107, -109, -110 and -113, whose rule this story
pins. Line numbers below are the tip of HARNESS-113's branch, `2cc293e`
(`132 (2026-11-18)`), which is the tree this story was planned on.

**Where it comes from.** HARNESS-113's diff review, round 1, Should fix 1
(`bash scripts/story.sh section HARNESS-113 'Diff review'`): "The 'any
number, any order' half of the widening has no test." The reviewer placed it
in a follow-up story because it could not be done inside HARNESS-113's frozen
criteria. **`depends_on: [HARNESS-113]` is a true dependency:** the class this
story pins at the `TESTS_DIR` position exists only once HARNESS-113 (PR #203,
open on 2026-11-19) has merged.

**The defect.** `.claude/tests/shipped-docs.test.sh` holds the rule
`suite_docs_reads` and its pattern `SDR_RE` (line 210): no upstream suite line
may read under the real checkout's `docs/`. The pattern holds the class
`[}"]*` twice: between `TESTS_DIR` and its `/../..` (position 1,
HARNESS-113), and between either root and `/docs` (position 2, HARNESS-106).
The star is deliberate: HARNESS-113's C-1 says "zero or more of `}` ... and
`"` ..., in any order, so `"${TESTS_DIR}"/../..` counts too". No fixture line
anywhere in the suite holds more than one of the two characters at either
position, so the star is untested: a later edit that narrows either class to
one character stays green, and a suite reading the project's docs through
`"${TESTS_DIR}"/../../docs/...` or `"${REPO_ROOT}"/docs/...` would then pass
the rule and fail in a consumer.

**Reproduced at PLANNED, 2026-11-19, on this tree, by `mutate.sh`** (the
reviewer had measured position 1 only). Each run changed 1 line, the
`SDR_RE=` line, and was restored and verified:

    === mutate: .claude/tests/shipped-docs.test.sh (1 line(s) changed by /^SDR_RE=/s#_DIR\[}"\]\*#_DIR[}"]?#) ===
    shipped-docs: 23 passed, 0 failed
    === mutate: .claude/tests/shipped-docs.test.sh (1 line(s) changed by /^SDR_RE=/s#(%/)?\[}"\]\*#(%/)?[}"]?#) ===
    shipped-docs: 23 passed, 0 failed

Both narrowings are green today. That is the bug: the suite cannot tell
`[}"]*` from `[}"]?` at either position.

**The fix.** One fixture and one assertion, added to the suite; the pattern
is not edited, because it is already right. So the new assertion passes on
arrival, and what earns it is the two narrowings above, run again at GATES
and this time watched to go red (Deferred verifications).

**The gate that would fail if this broke.** `bash scripts/gates.sh --list`
shows every gate `<unconfigured>` in this repository (checked at PLANNED), so
`required_gates` stays empty, as in HARNESS-113. The artifact is judged by
the `shipped-docs` self-test suite (`bash scripts/selftest.sh shipped-docs`)
under its floor in `.claude/tests/floors.conf`, which
`selftest.sh --changed` runs locally at GATES and CI runs in full on the PR,
and by `check-boundaries.sh` (the `VERSION` bump, the deferred
verifications' pasted results).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given a tree whose `.claude/tests/` holds one file, `d.test.sh`,
  with these five lines in this order:

  1. `#!/usr/bin/env bash`
  2. `cat "${TESTS_DIR}"/../../docs/a`
  3. `cat "${REPO_ROOT}"/docs/a`
  4. `cat "${D:-"$TESTS_DIR"}/../../docs/a"`
  5. `cat "${D:-"$REPO_ROOT"}/docs/a"`

  when the `shipped-docs` suite's rule `suite_docs_reads` runs over that
  tree, then it prints exactly four lines, in this order:
  `.claude/tests/d.test.sh:2`, `.claude/tests/d.test.sh:3`,
  `.claude/tests/d.test.sh:4`, `.claude/tests/d.test.sh:5`. A root name
  followed by both a closing brace and a closing quote is reported, at the
  second root name's own position (2, 4) and before `/docs` (3, 5), with the
  brace first (2, 3) and with the quote first (4, 5).
  *The defect, reproduced:* the suite as it stands holds no such line, and
  with either class narrowed from "any run of `}` and `"`" to "at most one"
  it still reports `23 passed, 0 failed` (Context).
  *Controls:* with the class between `TESTS_DIR` and `/../..` narrowed to at
  most one character, the same run must print only lines 3 and 5, and the
  assertion must fail (DV-1). With the class before `/docs` narrowed the
  same way, it must print only lines 2 and 4, and the assertion must fail
  (DV-2).
- **AC-2** — Given this repository's own tree, when the `shipped-docs` suite
  runs, then every assertion the suite holds before this story is unchanged
  and still passes, the rule still reports nothing over the real tree, and
  the suite's passed count is exactly one higher than before this story
  (23 becomes 24).


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

RED may amend any block below, in place, with a reason; GREEN builds what the
amended block says. The acceptance criteria are not amendable this way.

**Writes:** `.claude/tests/shipped-docs.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

Everything below is pinned against the tip of HARNESS-113's branch,
`2cc293e` (`132 (2026-11-18)`). The story starts only after HARNESS-113 has
merged; RED re-reads line 210 and the end of
`.claude/tests/shipped-docs.test.sh` on the tree it starts from and amends
line numbers in place if they moved.

**D-1. One assertion, not two. PO decision, recorded.** Both positions are
pinned by one whole-output `assert_eq` over one fixture file. Reasons:

1. *It is one claim.* "A run of `}` and `"`, in either order, counts
   wherever the class stands." The two positions are the two places the same
   class appears in one pattern line.
2. *One comparison already tells the positions apart.* Narrowing position 1
   loses lines 2 and 4; narrowing position 2 loses lines 3 and 5. The actual
   output of a failure names the position, so a second assertion would
   discriminate nothing the first does not (measured, C-2).
3. *It is the suite's convention.* The HARNESS-110 and HARNESS-113 blocks
   are each one fixture and one whole-output comparison.
4. *Cost.* One count unit (23 becomes 24) instead of two, one fixture
   directory instead of two. The mutation work is the same either way: one
   narrowing per position (Deferred verifications).

What one assertion gives up: with both classes narrowed at once it fails
once, not twice. Nothing counts failures per position, so nothing is lost.

**D-2. The order half is in the fixture too (lines 4 and 5).** The finding
is headed "any number, any order". Lines 2 and 3 are brace-then-quote, the
spelling C-1 of HARNESS-113 names. Lines 4 and 5 are quote-then-brace, which
real bash produces when a quoted root is the default of another expansion
(`"${D:-"$TESTS_DIR"}/../../docs/a"`). They cost two fixture lines in the
same assertion and no extra run: a pattern that fixes the order to `}?"?`
loses line 4 (position 1) or line 5 (position 2), measured in C-2. No
mutation is owed for the order half (Deferred verifications, "Not owed").
**Approved by the user, 2026-11-19: keep lines 4 and 5.**

**C-0. Who writes which.** All four paths classify as `harness`
(`bash scripts/classify.sh <path>`, checked at PLANNED), so the phase lock
divides nothing and this block does, as in HARNESS-113.

- **RED (test-developer):** `.claude/tests/shipped-docs.test.sh` only: the
  new `describe` block of C-1. No other line of the file.
- **GREEN (feature-developer):** the floor records in
  `.claude/tests/floors.conf` and `.claude/tests/selftest.test.sh`, and
  `.claude/harness/VERSION` (C-3). GREEN touches no line of
  `shipped-docs.test.sh`.

**C-1. The fixture and the one assertion (AC-1).** A new `describe` block,
the last before `summary "shipped-docs"` (line 498), so after the
HARNESS-113 block (469-496), titled
`a run of brace and quote after a root name (HARNESS-114)`. It reuses
`$SDR_R` and `$SDR_T` from the HARNESS-106 block (line 385), so neither name
is spelled whole in this suite's own source.

The fixture root is a new directory under `$WORK`, `$WORK/suite-run`, in
variable `u` (`d`, `g`, `p`, `q` and `t` are taken; `u` is free, checked),
holding `.claude/tests/d.test.sh`, exactly these five lines:

| Line | Text as the fixture file holds it | After the root name | Position |
|---|---|---|---|
| 1 | `#!/usr/bin/env bash` | not a read | - |
| 2 | `cat "${TESTS_DIR}"/../../docs/a` | `}"` | 1 |
| 3 | `cat "${REPO_ROOT}"/docs/a` | `}"` | 2 |
| 4 | `cat "${D:-"$TESTS_DIR"}/../../docs/a"` | `"}` | 1 |
| 5 | `cat "${D:-"$REPO_ROOT"}/docs/a"` | `"}` | 2 |

Written as the HARNESS-113 block writes its fixture, one `printf '%s\n'` per
line. These five source lines produce exactly the file above (checked at
PLANNED by `diff`):

    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "cat \"\${$SDR_T}\"/../../docs/a"
    printf '%s\n' "cat \"\${$SDR_R}\"/docs/a"
    printf '%s\n' "cat \"\${D:-\"\$$SDR_T\"}/../../docs/a\""
    printf '%s\n' "cat \"\${D:-\"\$$SDR_R\"}/docs/a\""

One `assert_eq` on the whole output of `suite_docs_reads "$u"`. Expected,
exactly, four lines: `.claude/tests/d.test.sh:2`, `:3`, `:4`, `:5`. Its name
starts `HARNESS-114 AC-1:` and says in words that a root name followed by
both a closing brace and a closing quote, in either order, is reported at
both positions. The block's own comment says what lines 2-5 are and that
narrowing either class to one character turns the assertion red; it is a
whole-line comment, which the rule skips, and it still spells neither name
whole next to `/docs`.

No unseen line is in this fixture, on purpose: what the rule must not see is
already pinned by the HARNESS-106 twin, the HARNESS-110 block and lines 6-10
of the HARNESS-113 block, and this story changes nothing they pin.

**Not edited:** the `SDR_RE=` line, its header and "Written limit" comment,
`suite_docs_files`, `suite_docs_reads`, and every existing fixture and
assertion (the HARNESS-106, -109, -110 and -113 blocks). The header already
says "any of `}` and `"`" at both positions; it needs no new sentence.

**C-2. Measured at PLANNED** (each pattern run by `awk`, as
`suite_docs_reads` runs it, over the five lines above). **Settled: read it
out.**

| Pattern | Lines reported |
|---|---|
| `SDR_RE` at `2cc293e` | 2, 3, 4, 5 |
| position 1 narrowed: `TESTS_DIR[}"]?/` | 3, 5 |
| position 2 narrowed: `(%/)?[}"]?/+docs` | 2, 4 |
| both narrowed | none |
| position 1 with the order fixed: `TESTS_DIR}?"?/` | 2, 3, 5 |
| position 2 with the order fixed: `(%/)?}?"?/+docs` | 2, 3, 4 |
| position 1 without its class (the pattern before HARNESS-113) | 3, 5 |

And by `mutate.sh` on the whole suite, before the new block exists
(Context): each narrowing changes 1 line and leaves
`shipped-docs: 23 passed, 0 failed`. So no existing assertion depends on the
star, and each of DV-1 and DV-2 must come to exactly 1 failed, the new
assertion.

*RED's run.*
`bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs`, after
checking machine-wide that no other self-test or gates run is going
(`ps -ef | awk '(($6=="bash")&&($7=="scripts/selftest.sh"||$7=="scripts/gates.sh"))||(($8=="bash")&&($9=="scripts/selftest.sh"||$9=="scripts/gates.sh"))'`
prints nothing). Expected `shipped-docs: 24 passed, 0 failed`, above the
recorded floor of 23, so nothing is red at the end of RED. **The new
assertion passes on arrival. RED says so in its handoff and claims no
watched failure;** it restates DV-1's and DV-2's expressions against the
file as built and leaves the runs to GATES. If the count is not 24, or the
new assertion fails, RED stops and reports: that would mean the pattern on
the tree is not the one this story was planned against.

**C-3. Floors and the release (GREEN).**

- `.claude/tests/floors.conf`: line 67, `floor | shipped-docs  | 23`, becomes
  `24`, the count GREEN measures passing; and the dated history comment at
  the end of the file (the HARNESS-113 paragraph is 1274-1277) gains a
  paragraph in the same form: story id, GREEN and the local calendar date,
  the measured line `shipped-docs: 24 passed, 0 failed`, and "+1 (the
  HARNESS-114 brace-with-quote assertion)".
- `.claude/tests/selftest.test.sh`: the `COUNTS` entry `shipped-docs 23`
  (line 559) becomes `shipped-docs 24`.
- `.claude/harness/VERSION`: the last line becomes the next release after
  whatever `main` holds when GREEN runs, with that day's local calendar date
  in brackets. `main` is 131 on 2026-11-19 and HARNESS-113 takes 132, so 133
  unless another story merges first. `check-boundaries.sh` refuses a harness
  change without the bump.
- GREEN's runs, one at a time, with the same machine-wide check first:
  `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs selftest`
  and `bash scripts/attest.sh -- bash scripts/gates.sh --fast`.

**C-4. Baseline, measured at PLANNED on `2cc293e`. Settled: read it out.**

- `bash scripts/selftest.sh shipped-docs` is 23 assertions; the floor and
  the `COUNTS` mirror both say 23.
- `.claude/tests/*.sh` is 37 files. `SDR_RE` and each narrowed pattern of
  C-2 report nothing over them, whole-line comments included, and no line of
  them holds a root name followed by two or more of `}` and `"`
  (`grep -nE '(REPO_ROOT|TESTS_DIR)[}"]{2,}'` is empty). So no line of the
  real tree uses the combined spelling, and the real-tree assertion does not
  move under DV-1 or DV-2.

**Callers.** No export changes signature and no function is edited.
`SDR_RE`, `suite_docs_files` and `suite_docs_reads` are defined and used only
in `.claude/tests/shipped-docs.test.sh`.

**Oracle partition.** AC-1 is **settled**: the expected output is the first
row of C-2's table, read out, not derived. AC-2 is **mechanical**: the count
is 24 and no existing assertion's text changes.

**Test-only dependencies.** None.

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

The budget is `rules.md`, "Mutation work per story". The new assertion is
written against a rule that already exists, so it passes on arrival and the
law owes it a mutation. Two entries, not one, because the one assertion
carries one claim at two positions of the pattern and a narrowing at one
position says nothing about the other (C-2: each loses a different pair of
lines). Each is one `mutate.sh` run against the one suite that holds the
assertion, and each is also the story's "defect put back": the narrowing the
suite could not see before. RED could run neither as evidence for the
committed story: the floors and the release are GREEN's, and one run at
GATES covers the story as committed. Both expressions are restated by RED's
handoff against the file as built.

- **DV-1, position 1 narrowed (AC-1).** With the class between `TESTS_DIR`
  and `/../..` narrowed from `[}"]*` to `[}"]?`, `mutate.sh` must report
  1 line changed (the `SDR_RE=` line). `shipped-docs` **must** report exactly
  1 failed, `shipped-docs: 23 passed, 1 failed`: the `HARNESS-114 AC-1`
  assertion, its actual value the two lines `.claude/tests/d.test.sh:3` and
  `.claude/tests/d.test.sh:5`. Every other assertion still passes (measured
  at PLANNED, Context). The selftest runner then also prints its floor line,
  23 against a floor of 24; that is the same failure counted, not a second
  one. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#_DIR\[}"\]\*#_DIR[}"]?#' -- bash scripts/selftest.sh shipped-docs

- **DV-2, position 2 narrowed (AC-1).** With the class between the root and
  `/docs` narrowed from `[}"]*` to `[}"]?`, `mutate.sh` must report 1 line
  changed (the `SDR_RE=` line). `shipped-docs` **must** report exactly
  1 failed, `shipped-docs: 23 passed, 1 failed`: the `HARNESS-114 AC-1`
  assertion, its actual value the two lines `.claude/tests/d.test.sh:2` and
  `.claude/tests/d.test.sh:4`. The floor line is as in DV-1.
  **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#(%/)?\[}"\]\*#(%/)?[}"]?#' -- bash scripts/selftest.sh shipped-docs

(Both expressions were run at PLANNED on `2cc293e`: each changes exactly the
`SDR_RE=` line, at its own position only, and `mutate.sh` restored and
verified the file both times.)

**Results, GATES, 2026-11-19, on the GREEN commit; both as predicted.**

DV-1: 1 line changed, exactly 1 failed, the HARNESS-114 AC-1 assertion with actual `:3` and `:5`; file restored and verified.

    === mutate: .claude/tests/shipped-docs.test.sh (1 line(s) changed by /^SDR_RE=/s#_DIR\[}"\]\*#_DIR[}"]?#) ===
    === mutate: running bash scripts/selftest.sh shipped-docs ===
        FAIL HARNESS-114 AC-1: a root name followed by both a closing brace and a closing quote, in either order, is reported at both positions, after the second root name and before docs
             expected: .claude/tests/d.test.sh:2
             .claude/tests/d.test.sh:3
             .claude/tests/d.test.sh:4
             .claude/tests/d.test.sh:5
             actual:   .claude/tests/d.test.sh:3
             .claude/tests/d.test.sh:5
    shipped-docs: 23 passed, 1 failed
    FAIL shipped-docs  did 23 units of work, below the floor of 24 in .claude/tests/floors.conf
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-114/.claude/state/mutations/.claude_tests_shipped-docs.test.sh.20261119T155718Z.1776.bak) ===

DV-2: 1 line changed, exactly 1 failed, the same assertion with actual `:2` and `:4`; file restored and verified.

    === mutate: .claude/tests/shipped-docs.test.sh (1 line(s) changed by /^SDR_RE=/s#(%/)?\[}"\]\*#(%/)?[}"]?#) ===
    === mutate: running bash scripts/selftest.sh shipped-docs ===
        FAIL HARNESS-114 AC-1: a root name followed by both a closing brace and a closing quote, in either order, is reported at both positions, after the second root name and before docs
             expected: .claude/tests/d.test.sh:2
             .claude/tests/d.test.sh:3
             .claude/tests/d.test.sh:4
             .claude/tests/d.test.sh:5
             actual:   .claude/tests/d.test.sh:2
             .claude/tests/d.test.sh:4
    shipped-docs: 23 passed, 1 failed
    FAIL shipped-docs  did 23 units of work, below the floor of 24 in .claude/tests/floors.conf
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-114/.claude/state/mutations/.claude_tests_shipped-docs.test.sh.20261119T160012Z.3400.bak) ===

Not owed, and stated so that nobody adds one: a mutation for the order half
(lines 4 and 5 are pinned by the same whole-output comparison and measured
in C-2; earning them separately is `/audit-mutations` work); a probe against
a real line of the tree (the rule over the tree does not change in this
story, and HARNESS-113's DV-2 is that probe for the pattern as it stands);
and anything for the floors or the release, which have no behaviour of
their own.

## Amendments

<!-- Acceptance criteria are frozen once the story leaves PLANNED. If one turns
     out to be wrong or unsatisfiable, stop, put it to the product owner, and
     record the change here: which AC, what it said, what it says now, who
     approved it and why. check-boundaries.sh fails a PR whose criteria differ
     from their last committed PLANNED state (else the base branch) without an
     entry here. Omit the section if unused.
     Head each entry AM-<n> (`- **AM-1 (AC-2).** ...`), and give it its
     adjudication record, a line of its own in this section, outside any
     comment or fence - check-boundaries.sh refuses a new entry without one:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A claim that a criterion is wrong is also what an agent says when it
     wants to stop failing, so it is judged by a fresh `fable` dispatch - a
     `lead-po` on the ADJUDICATE row of models.conf, on different inputs, not
     the claimant's code - and that dispatch writes the judgement and the
     record line; the judgement is never the orchestrator's. An entry that
     follows a diff-review or PR-feedback finding routed RED or AMEND was
     judged by that review, so the orchestrator writes its record, naming the
     round and finding (or the PR-feedback item) and the model the review was
     planned on and resolved to:
       - **Adjudicated AM-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Its being upheld does not replace the user's approval; both go in the
     entry. A change
     the user asked for unprompted is not a claim: `- **Adjudicated AM-<n>:**
     requested by the user, <date>`. -->

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-114` from `.claude/harness/models.conf`.
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
| DIFF-REVIEW | `lead-po` | `fable` | reading a whole diff for the defect no test was written for is judgement against the contract, and it is where a wrong call ships; a finding it labels goes back to GATES or RED, on opus |
| REVIEW | `lead-po` | `fable` | reading review feedback against the contract is orchestration judgement, and a wrong call here ships; a fix it finds goes back to GATES or RED, on opus |
| SCAFFOLD | `lead-po` | `opus` | source, tests and config in one indivisible derivation - code, with no failing test in front of any of it, so the stronger development model |
| ADJUDICATE | `lead-po` | `fable` | a claim that an acceptance criterion, a threshold or a frozen test is wrong is judged against the contract by a fresh dispatch on different inputs, never by the orchestrator that wants the answer; needed in any phase, so it is last |

**Resolved:**

- PLANNED, `lead-po`, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`), 2026-11-19; no override reported.
- RED, `test-developer`, resolved Opus 5.5 (`claude-opus-5-5`), as planned; no override.
- GREEN, `feature-developer`, resolved Opus 5.5 (`claude-opus-5-5`), as planned; no override.
- GATES, `feature-developer`, resolved Opus 5.5 (`claude-opus-5-5`), as planned; no override.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Any edit to the `SDR_RE=` line, its header or its "Written limit" comment.
  The pattern is right; this story only pins it. If RED finds the new
  assertion red on arrival, it stops and reports rather than touching the
  pattern.
- Any edit to an existing fixture or assertion: the HARNESS-106, -109, -110
  and -113 blocks stay byte for byte. The new lines go in a fixture file of
  their own, `d.test.sh`.
- A second assertion, or a fixture per position (D-1).
- Unseen lines in the new fixture, and any new spelling made to match or
  pinned as unseen: a run of three or more characters, a `%/` together with
  a run (`"${REPO_ROOT%/}"/docs/a` is seen today and is not pinned here), a
  left anchor for the root names, the written limit's spellings.
- A check that no suite of the real tree uses the combined spelling.
  Measured once at PLANNED (C-4); the rule itself reports such a line.
- Exhaustive earning of the suite's other assertions against other
  narrowings of the pattern. That is `/audit-mutations` work.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

One shell-level test, in the suite that owns the rule
(`.claude/tests/shipped-docs.test.sh`, run by `bash scripts/selftest.sh
shipped-docs`). The rule is a function of that suite, so the suite is both
the cheapest and the only level that can falsify it.

- **AC-1 (settled, read out from C-2):** one fixture file, `d.test.sh`, five
  lines (C-1), and one anchored whole-output `assert_eq` on
  `suite_docs_reads`: exactly `:2`, `:3`, `:4`, `:5`. Passes on arrival by
  design (the pattern is not changed); earned at GATES by DV-1 (position 1
  narrowed, expected actual `:3`, `:5`) and DV-2 (position 2 narrowed,
  expected actual `:2`, `:4`).
- **AC-2 (mechanical):** the pre-existing assertions stay byte for byte
  (pure insertion), the real-tree assertion keeps passing over the suite's
  own new lines, and the count goes 23 -> 24. Floors are GREEN's (C-3).

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

Written by the test-developer, RED, 2026-11-19. Resolved model: Opus 5.5
(`claude-opus-5-5`), as `test-developer.md` declares (`opus`); no override
was given in the dispatch.

**The new assertion PASSES ON ARRIVAL, and that is expected. No watched
failure is claimed.** This story pins an existing pattern; it changes no line
of `SDR_RE`. The fixture's four reads are all matched by the pattern as it
stands (C-2, first row), so the assertion is green on its first execution.
It is earned at GATES by DV-1 and DV-2, which RED declines: in RED they
would mutate the committed rule before the floors and the release that make
the story's tree exist, and the story's Deferred verifications assign both
to GATES. RED did not run them under `mutate.sh`.

**Starting tree.** `git diff 2cc293e HEAD -- .claude/tests/shipped-docs.test.sh`
is empty, so the contract's line numbers held: `SDR_RE=` at 210, `SDR_R`/`SDR_T`
at 385, the HARNESS-113 block 469-496, `summary "shipped-docs"` at 498 before
this change. No Contract block was amended.

**Command.**

    bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs

Attested, on the tree handed over: `exit: 0`,
`last: 1 harness suite(s) passed.`, log
`.claude/state/attest-logs/20261119T153938Z.414.log`, tree
`7cff05a710e45160bcb7ccb664cc88af8a3579a4`, duration 78 s (local). Verbatim
tail from the log:

```
  the second root name, braced and quoted (HARNESS-113)

  a run of brace and quote after a root name (HARNESS-114)

shipped-docs: 24 passed, 0 failed

assertion floors: all 1 suite(s) met their declared floor (24 assertions executed, 23 declared).
1 harness suite(s) passed.
```

"24 executed, 23 declared" is AC-2's +1 against the floor GREEN has not yet
raised (C-3): `floors.conf` line 67 and the `COUNTS` entry in
`selftest.test.sh` still say 23. That is GREEN's edit, not a defect.

    bash scripts/attest.sh -- bash scripts/gates.sh --fast

Attested, same tree: `exit: 0`,
`last: All required gates passed (0 ran, 5 unconfigured, 0 known).`, log
`.claude/state/attest-logs/20261119T154137Z.2066.log`. Shape: every required
gate is UNCONFIGURED on this harness repository (`BOOTSTRAPPED=no`), mutation
ON REQUEST, integration build skipped by `--fast`. Nothing is red, and nothing
here is meant to be: the suite judging this story is the self-test above.

**Files touched.**

- `.claude/tests/shipped-docs.test.sh`: one new `describe` block,
  `a run of brace and quote after a root name (HARNESS-114)`, inserted
  directly before `summary "shipped-docs"`, after the HARNESS-113 block. No
  other line of the file changed (`git diff` shows a pure insertion).
- this story file: `## Test plan` and this section.

**Tests, one line each.**

- `HARNESS-114 AC-1: a root name followed by both a closing brace and a closing quote, in either order, is reported at both positions, after the second root name and before docs`
  — `assert_eq` on the whole output of `suite_docs_reads "$u"` over
  `$WORK/suite-run/.claude/tests/d.test.sh`; expected exactly
  `.claude/tests/d.test.sh:2` .. `:5`, four lines, in order. Covers AC-1.
- AC-2 is covered by the suite as a whole: every pre-existing assertion
  unchanged and passing (the diff is a pure insertion; 24 passed, 0 failed),
  the real-tree assertion (`HARNESS-106 AC-3`) still passing with the new
  block's lines in the scanned file, and the count 23 -> 24.

**The fixture, as written.** The five `printf '%s\n'` lines are C-1's,
character for character. Their output was checked on a scratch file against
AC-1's five lines and is identical:

```
#!/usr/bin/env bash
cat "${TESTS_DIR}"/../../docs/a
cat "${REPO_ROOT}"/docs/a
cat "${D:-"$TESTS_DIR"}/../../docs/a"
cat "${D:-"$REPO_ROOT"}/docs/a"
```

The block's comment is whole-line and names neither root whole; the new
source lines spell them only through `$SDR_R`/`$SDR_T`, and the real-tree
assertion still passing is the check that no line of the suite became an
offending one.

**Export shape pinned.** None new. The block uses the suite's existing
`suite_docs_reads <root>` (prints `<relative path>:<line>` per reported line),
`assert_eq <name> <expected> <actual>`, `describe`, `$WORK`, `$SDR_R`,
`$SDR_T`. It defines one new variable, `u`. GREEN edits none of it (C-0).

**Not constrained:** nothing about the floors' history paragraph wording or
the release number beyond C-3.

**Deferred controls, declined by RED in writing, expected values.** Both
expressions restated against the file as built: `SDR_RE=` is still line 210
and its text is unchanged, so the expressions are the Deferred verifications'
own, unmodified. On a scratch copy (never the real file) each changes exactly
line 210, at its own position only, and the pattern it leaves, run by plain
`awk '$0 ~ re'` over the fixture file above, reports the lines below. These
are measured outside the suite; the suite-level outcome (`23 passed, 1
failed`, the failing assertion being HARNESS-114 AC-1) is a claim until
GATES runs `mutate.sh`.

| Control | Expression (`mutate.sh` on `.claude/tests/shipped-docs.test.sh`) | Lines changed | Fixture lines reported (scratch, awk) | Expected suite result | Owner |
|---|---|---|---|---|---|
| unmutated | none | 0 | 2, 3, 4, 5 (the suite run above) | `24 passed, 0 failed` (observed) | RED, done |
| DV-1, position 1 `[}"]*` -> `[}"]?` | `'/^SDR_RE=/s#_DIR\[}"\]\*#_DIR[}"]?#'` | 1 (line 210) | 3, 5 | `23 passed, 1 failed`; HARNESS-114 AC-1 actual `.claude/tests/d.test.sh:3` and `:5` | GATES |
| DV-2, position 2 `[}"]*` -> `[}"]?` | `'/^SDR_RE=/s#(%/)?\[}"\]\*#(%/)?[}"]?#'` | 1 (line 210) | 2, 4 | `23 passed, 1 failed`; HARNESS-114 AC-1 actual `.claude/tests/d.test.sh:2` and `:4` | GATES |

Each run is `bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '<expr>' -- bash scripts/selftest.sh shipped-docs`.
After GREEN raises the floor to 24 the runner will also print a floor line
(23 against 24) under each; that is the same failure counted again.

**Timings.** The one duration above (78 s for the suite) is from a local run
on this machine, with no other self-test or gates run going (`ps` check
empty before each run). No timeout is involved in this suite.

**Approach.** Nothing discovered changes it. GREEN does C-3 only.

## Regressions

<!-- REQUIRED if this story ever returned to RED after GREEN or GATES; omit
     otherwise. A test that is wrong is never edited into passing, and the
     return is not a footnote - it is the story failing to be one clean cycle,
     and the next person needs to know why. One block per return, headed
     R-<n> (`### R-1 (the count test)`), and carrying its adjudication
     record - a line of its own, outside any comment or fence, written by
     the fresh `fable` dispatch (a `lead-po` on the ADJUDICATE row of
     models.conf) that judged the claim the test is wrong; the judgement is
     never the orchestrator's. check-boundaries.sh refuses a new entry
     without one:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, <what it reproduced>
     A return that follows a diff-review or PR-feedback finding routed RED
     or AMEND was judged by that review, so the orchestrator writes the
     record, naming the round and finding (or the PR-feedback item) and the
     model the review was planned on and resolved to:
       - **Adjudicated R-<n>:** `fable` (resolved <name>), <date>, diff review round <r>, finding <f>
     Then:
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

## Diff review

### Round 1, 2026-11-19

Reviewer: `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override. Changed no file.

Checked, nothing to fix: the diff is the four contracted files plus the story, the suite change a pure 25-line insertion before `summary` with `SDR_RE`, its header and every earlier block unchanged; the committed `printf` lines give AC-1's five lines exactly; the reviewer rebuilt the fixture and ran its own narrowings through `awk` (committed: 2 3 4 5; position 1 `[}"]?`: 3 5; position 2 `[}"]?`: 2 4; position 1 order fixed `}?"?` / `"?}?`: 2 3 5 / 3 4 5; position 2 `}?"?` / `"?}?`: 2 3 4 / 2 4 5; position 1 `[}]*"?`: 2 3 5), matching C-2 and the pasted DV-1 and DV-2; the suite's new lines are not offending lines; one run `shipped-docs: 24 passed, 0 failed`, floors 24 executed, 24 declared; `check-sigpipe.sh` and `check-grep-count.sh` exit 0, `bash -n` clean; floors 24 in both records, `origin/main` at 132 so 133 is next; `SDR_RE` and both functions used only in this suite, none edited.

Not checked: full self-test, full gates, `check-boundaries.sh` (as briefed); DV-1 and DV-2 read from the pasted output and matched against the reviewer's own reproduction, not re-run.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-19T16:04:10Z
    commit: 286f05d
    tree:   81ac06d8ecdd8ed2be2019f513e7aa4311996abf
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

- **PLANNED, 2026-11-19.** Planned by a `lead-po` dispatch on the PLANNED
  row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override
  was reported to it. Planned in the worktree `D:\adh-HARNESS-114` on the
  temporary branch `story/HARNESS-114-plan`, cut from the tip of
  HARNESS-113's branch (`2cc293e`), so the widened pattern was in the tree.
  The frontmatter's `branch:` is the story's real branch name; the
  orchestrator names the branch.
- **`depends_on: [HARNESS-113]`** is ordering, not collision: position 1's
  class does not exist on `main` until PR #203 merges. `phase.sh set` will
  refuse to move this story past PLANNED until HARNESS-113 is DONE.
- **Not already delivered.** Both narrowings were run with `mutate.sh` at
  PLANNED and both left the suite at `23 passed, 0 failed` (Context).
- **Two PO decisions, neither put to the user:** one assertion rather than
  two (D-1), and the quote-then-brace lines 4 and 5 (D-2), which take the
  finding's "any order" half in the same assertion at no extra run. Both are
  inside the request's scope ("a test fails if either position's class is
  narrowed to one character"); D-2 can be dropped by removing lines 4 and 5
  from AC-1 before the story leaves PLANNED, with nothing else changing but
  the expected output and DV-1's and DV-2's actual values.

- **`bash scripts/plan.sh conflicts`, 2026-11-19, this worktree:**
  `fewer than two startable stories; nothing to compare` (exit 0). It judged
  no pair, so it is not evidence that any pair is clear. HARNESS-113 writes
  the same four files; that pair is ordered by `depends_on`. Any other open
  story that moves a floor, the `COUNTS` mirror or `VERSION` collides on
  those three files and takes the next release number when it merges second.
- GATES → REVIEW, 2026-11-19: diff review round 1 ships, no findings. DIFF-REVIEW, `lead-po`, resolved Fable 5.2 (`claude-fable-5-2`).
- GATES → REVIEW, 2026-11-19: `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`, run by a `feature-developer` on the GATES row (resolved Opus 5.5, `claude-opus-5-5`): 11 suites passed, `assertion floors: all 11 suite(s) met their declared floor (2137 assertions executed, 2137 declared)`, exit 0, 964 s, tree e634e3c; `attest.sh check` fresh. A first attempt (16:14Z) died at start with an MSYS `get_proc_lock` error and left a stale run lock, which the second run reclaimed itself.
