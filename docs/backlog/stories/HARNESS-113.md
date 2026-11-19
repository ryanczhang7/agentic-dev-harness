---
id: HARNESS-113
title: The docs-read rule and its header agree on the second root name
slug: the-docs-read-rule-and-its-header-agree
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-113-the-docs-read-rule-and-its-header-agree
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/shipped-docs.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the shipped-docs suite under its selftest floor, which CI runs in full on the PR
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

No epic, as HARNESS-106, HARNESS-107, HARNESS-109 and HARNESS-110, whose rule
this story corrects. Line numbers below are `origin/main` at `a349761`.

**Where it comes from.** HARNESS-110's diff reviews, rounds 1 and 2
(`bash scripts/story.sh section HARNESS-110 'Diff review'`): "not a finding
against this diff", offered both times as a follow-up story. The defect
predates HARNESS-110; the rule is HARNESS-106's and the sentence is
HARNESS-107's.

**The defect.** `.claude/tests/shipped-docs.test.sh` holds the rule
`suite_docs_reads` (comment 172-183, pattern `SDR_RE` 205): no upstream suite
line may read under the real checkout's `docs/`, because a consumer does not
have those files. The rule knows the real checkout by two names, `REPO_ROOT`
and `TESTS_DIR/../..`. Its header says (176-177) that after either name "any
of `}` and `"`" may follow, "so the braced and the quoted-root spellings
count". The pattern allows `}` and `"` only *after* `/../..`, and for the
second name the brace or quote closes *before* it. Measured at PLANNED
(2026-11-16, Git Bash, the pattern of line 205 with its `''` removed, run by
`awk` over lines of my own):

| Line | `SDR_RE` at `a349761` |
|---|---|
| `cat "$TESTS_DIR/../../docs/a"` | seen |
| `cat "${REPO_ROOT}/docs/a"` | seen |
| `cat "$REPO_ROOT"/docs/a` | seen |
| `cat "${TESTS_DIR}/../../docs/a"` | **not seen** |
| `cat "$TESTS_DIR"/../../docs/a` | **not seen** |
| `n=$(ls ${TESTS_DIR}/../../docs)` | **not seen** |

So the header promises something the rule does not do: a suite that reads the
project's docs through `"${TESTS_DIR}/../../docs/..."` passes the rule and
fails in a consumer, which is the failure HARNESS-106 exists to stop. No
line of the tree is written that way today (measured, see C-5), so nothing is
broken yet; what is wrong is the rule and what it says about itself.

**The fix, and the decision behind it (D-1 in the Contract).** Two ways to
make the header and the rule agree: widen the pattern so the two spellings
count (option a), or correct the header and name them in the written limit
(option b). **This story is written for option (a), the PO's recommendation;
D-1 is for the user to settle before the story leaves PLANNED, and says
exactly what changes under (b).**

**The gate that would fail if this broke.** `bash scripts/gates.sh --list`
shows every gate `<unconfigured>` in this repository (checked at PLANNED), so
no gate, required or optional, exercises this and `required_gates` stays
empty, as in HARNESS-106, -107, -109 and -110. The artifact is judged by the
`shipped-docs` self-test suite (`bash scripts/selftest.sh shipped-docs`) under
its floor in `.claude/tests/floors.conf`, which `selftest.sh --changed` runs
locally at GATES and CI runs in full on the PR, and by `check-boundaries.sh`
(the `VERSION` bump, the deferred verifications' pasted results).

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

Written for D-1 option (a). AC-2 holds under either option; AC-1 is replaced
by the text in D-1 if the user chooses (b).

- **AC-1** — Given a tree whose `.claude/tests/` holds one file, `c.test.sh`,
  with these ten lines in this order:

  1. `#!/usr/bin/env bash`
  2. `cat "${TESTS_DIR}/../../docs/a"`
  3. `cat "$TESTS_DIR"/../../docs/a`
  4. `n=$(ls ${TESTS_DIR}/../../docs)`
  5. `cat "$TESTS_DIR/../../docs/a"`
  6. `cat "${TESTS_DIR}/../docs/a"`
  7. `cat "${TESTS_DIR}/fixtures/docs/a"`
  8. `cat "$TESTS_DIR"/../../docsy/a`
  9. `cat "$TESTS_DIR/../.././docs/a"`
  10. `cat "${TESTS_DIR%/}/../../docs/a"`

  when the `shipped-docs` suite's rule `suite_docs_reads` runs over that
  tree, then it prints exactly four lines, in this order:
  `.claude/tests/c.test.sh:2`, `.claude/tests/c.test.sh:3`,
  `.claude/tests/c.test.sh:4`, `.claude/tests/c.test.sh:5`. The braced
  spelling (2, and unquoted in a command substitution, 4) and the quoted-root
  spelling (3) of the second root name are reported, as the plain one (5)
  already was. A path one level up (6) or under the suites' own directory
  (7) is not the real checkout's `docs/`, and `docsy` (8) is not `docs`;
  none is reported. Lines 9 and 10 stay the written limit (a `/./` before
  `docs`, as HARNESS-110 named for the first root name; and a `%/` on the
  name itself) and are not reported.
  *The defect, reproduced:* before the fix the same run prints only
  `.claude/tests/c.test.sh:5`.
  *Controls:* with the fix reverted the assertion must fail with that one
  line (DV-1). A pattern loosened to "anything between `TESTS_DIR` and
  `/docs`" must fail it the other way, reporting 6, 7, 9 and 10 as well
  (measured at PLANNED; lines 6-10 are in the fixture for this).
- **AC-2** — Given this repository's own tree, when the `shipped-docs` suite
  runs, then every assertion the suite holds before this story is unchanged
  and still passes, the rule still reports nothing over the real tree, and
  the suite's passed count is exactly one higher than before this story
  (22 becomes 23).

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

Everything below is pinned against `origin/main` at `a349761`
(`130 (2026-11-16)`). HARNESS-112, PLANNED on a local branch, does not write
`shipped-docs.test.sh` (Notes); RED re-reads lines 172-205 and the end of
`.claude/tests/shipped-docs.test.sh` anyway and amends in place if it did.

**D-1. PO decision, for the user, before the story leaves PLANNED: widen the
pattern for the second root name (a), or correct the header (b).**
Recommended: **(a)**. The rest of this story is written for (a).
**Approved by the user, 2026-11-16: (a), widen the pattern.** In the same
answer the user chose to keep fixture lines 9 and 10, the two `TESTS_DIR`
spellings that stay unseen, and C-2's sentence naming them. The (b) text
below is kept as the record of the option the user turned down.

- *(a) Widen `SDR_RE`, by one character class in one place* (C-1): `}` and
  `"` may also stand between `TESTS_DIR` and its `/../..`. Recommended, for
  these reasons.
  1. *It makes a promise true instead of withdrawing it.* HARNESS-110's D-1
     ("name them, do not widen", the user's choice on 2026-11-14) was about
     spellings the header never claimed. This one the header does claim, and
     `"${VAR}/..."` and `"$VAR"/...` are the two most ordinary ways to write
     a path in bash, which is why HARNESS-106 covered them for `REPO_ROOT`.
     Under (b) the rule would treat its two names differently for a reason
     no reader would guess.
  2. *The change is closed, not the open family D-1 turned down.* It reuses
     the class the pattern already has (`[}"]*`) at one more position. It
     adds no new arm, and what stays unseen for this name is stated and
     pinned (lines 9 and 10 of the fixture, C-2's limit sentence).
  3. *No false positive, measured.* Over the real tree, 37 files in
     `.claude/tests/*.sh`, the widened pattern reports nothing, comments
     included, as the current one does (C-5). A match still needs the
     literal name, then `/../..`, then `/docs` as a whole component, so the
     near misses in the fixture (one level up, under `fixtures/`, `docsy`)
     stay silent.
  4. *The suite's own lines are safe.* The fixture is written with `$SDR_T`
     (line 380), so this suite's source never holds the name next to
     `/../../docs`; the pattern line itself spells the name in two pieces.
     Measured: the widened pattern over the whole suite with the widened
     line in place matches nothing. The real-tree assertion (369-370) is the
     standing check.
  5. *Cost:* one new assertion (22 becomes 23), one pattern line, a header
     sentence and a limit sentence, and two `mutate.sh` runs at GATES (DV-1,
     and DV-2 because the rule over the tree changes). That is one
     `mutate.sh` run more than (b).
- *(b) Correct the header and name the spellings in the limit.* The pattern
  is not touched. Consistent with HARNESS-110's D-1, and no line of the tree
  uses either spelling (C-5), so nothing is missed today. Its cost is the
  same assertion and one mutation; what it gives up is the two commonest
  spellings of one of the rule's own two names, in a rule whose only job is
  to catch a read before a consumer does.

**If the user chooses (b), these replace the blocks named, and nothing else
changes** (AC-2, C-0, C-4, the callers, the count 22 becomes 23, the title
and slug, which were chosen to fit both):

- *AC-1 under (b):* Given a tree whose `.claude/tests/` holds one file,
  `c.test.sh`, with these five lines in this order: `#!/usr/bin/env bash`,
  `cat "${TESTS_DIR}/../../docs/a"`, `cat "$TESTS_DIR"/../../docs/a`,
  `cat "$TESTS_DIR/../.././docs/a"`, `cat "$TESTS_DIR/../../docs/a"`; when
  `suite_docs_reads` runs over that tree, then it prints exactly one line,
  `.claude/tests/c.test.sh:5`. *Control:* with `SDR_RE` widened as C-1
  describes, the same run must print lines 2, 3 and 5, and the assertion
  must fail. The criterion pins what the rule does; it is not a claim that
  missing these lines is desirable.
- *C-1 under (b):* `SDR_RE` and both functions are not edited.
- *C-2 under (b):* header line 177 becomes "then any of `}` and `"` (so the
  braced and the quoted-root spellings of REPO_ROOT count; for TESTS_DIR
  they do not, see the limit)", re-wrapped; the limit paragraph gains, after
  "(HARNESS-110, D-1).": "Nor are the braced and the quoted-root spellings
  of the second root name ("${TESTS_DIR}/../../docs/a",
  "$TESTS_DIR"/../../docs/a): the pattern wants /../.. straight after the
  name. The assertion headed HARNESS-113 below pins them (HARNESS-113,
  D-1)."
- *C-3 under (b):* the same block and file name, the five lines above, the
  expected output `.claude/tests/c.test.sh:5`. It passes on arrival; RED
  says so and claims no watched failure.
- *Deferred verifications under (b):* DV-1 becomes the limit assertion's
  earning mutation, `bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#_DIR/#_DIR[}"]*/#' -- bash scripts/selftest.sh shipped-docs`,
  predicted 1 line changed, `shipped-docs: 22 passed, 1 failed`, the
  HARNESS-113 assertion with actual `:2`, `:3`, `:5`. DV-2 is dropped: the
  rule over the tree does not change.

**C-0. Who writes which.** All four paths classify as `harness`
(`bash scripts/classify.sh <path>`, checked at PLANNED), so the phase lock
divides nothing and this block does. The rule lives in the suite, so, as in
HARNESS-107, the defect is *in* a test file and RED fixes it there.

- **RED (test-developer):** `.claude/tests/shipped-docs.test.sh` only, in
  two steps. Step 1: the fixture and the assertion (C-3), run, and the
  failure pasted into the handoff. Step 2: the pattern (C-1) and the comment
  (C-2), run again, green.
- **GREEN (feature-developer):** the floor records in
  `.claude/tests/floors.conf` and `.claude/tests/selftest.test.sh`, and
  `.claude/harness/VERSION` (C-4). GREEN touches no line of
  `shipped-docs.test.sh`.

**C-1. The pattern (line 205).** One edit, on the one line that starts
`SDR_RE=`. It reads:

    SDR_RE='(REPO''_ROOT|TESTS''_DIR/[.][.]/[.][.])(%/)?[}"]*/+docs([^A-Za-z0-9_.-]|$)'

and becomes:

    SDR_RE='(REPO''_ROOT|TESTS''_DIR[}"]*/[.][.]/[.][.])(%/)?[}"]*/+docs([^A-Za-z0-9_.-]|$)'

That is `[}"]*` inserted between `_DIR` and `/[.][.]/[.][.]`, nothing else.
What each piece means: after the name `TESTS_DIR`, zero or more of `}` (the
brace of `${TESTS_DIR}` closing) and `"` (the quote of `"$TESTS_DIR"`
closing), in any order, so `"${TESTS_DIR}"/../..` counts too; then exactly
`/../..`. The rest of the pattern, `suite_docs_reads` (214-227) and
`suite_docs_files` (206-213) are not edited. Not added: a `%/` on the name
(`${TESTS_DIR%/}`), a doubled slash inside `/../..`, any other expansion.
`sed '/^SDR_RE=/s#_DIR/#_DIR[}"]*/#'` over the file at `a349761` produces
exactly this line and changes no other (checked at PLANNED on a copy).

**C-2. The comment.** Two places, both whole-line comments, which the rule
skips.

*The header (175-177).* It reads:

    # REPO_ROOT or TESTS_DIR/../.., then optionally `%/` (the root with one
    # trailing slash stripped, still the root; nothing else may follow the `%`),
    # then any of `}` and `"` (so the braced and the quoted-root spellings count),

It must come to say where `}` and `"` may stand for the second name, for
example:

    # REPO_ROOT or TESTS_DIR/../.. (any of `}` and `"` may stand between
    # TESTS_DIR and its /../.., so the braced and the quoted spellings of that
    # name count: HARNESS-113), then optionally `%/` (the root with one
    # trailing slash stripped, still the root; nothing else may follow the `%`),
    # then any of `}` and `"` (so the braced and the quoted-root spellings count),

*The "Written limit" paragraph (187-197).* Nothing in it is removed or
reworded. After its last sentence, "(HARNESS-110, D-1).", inside the same
paragraph, this is appended:

    # For the second root name the same `/./` ("$TESTS_DIR/../.././docs/a") is
    # not seen, nor a `%/` on the name itself ("${TESTS_DIR%/}/../../docs/a");
    # the assertion headed HARNESS-113 below pins both (HARNESS-113, D-1).

Wording of both may be adjusted by RED provided the header says the braced
and quoted spellings of `TESTS_DIR` count, and the limit names the two
unseen spellings by example and points at the assertion. No assertion pins
the comment's wording and none is to be added (HARNESS-110, D-1); the diff
review reads the comment against this block. Neither example matches the
widened pattern (measured), so writing the name in full in these comment
lines does not make the suite report itself.

**C-3. The fixture and the one assertion (AC-1).** A new `describe` block,
the last before `summary "shipped-docs"` (line 464), so after the
HARNESS-110 block (444-462), titled
`the second root name, braced and quoted (HARNESS-113)`. It reuses `$SDR_T`
from the HARNESS-106 block (line 380), so the name is spelled in pieces in
this suite's own source.

The fixture root is a new directory under `$WORK`, `$WORK/suite-second-root`,
in variable `t` (`d`, `g`, `p` and `q` are taken; `t` is free, checked),
holding `.claude/tests/c.test.sh`, exactly these ten lines:

| Line | Text as the fixture file holds it | Rule after the fix | Rule at `a349761` |
|---|---|---|---|
| 1 | `#!/usr/bin/env bash` | not a read | - |
| 2 | `cat "${TESTS_DIR}/../../docs/a"` | **seen** | not seen |
| 3 | `cat "$TESTS_DIR"/../../docs/a` | **seen** | not seen |
| 4 | `n=$(ls ${TESTS_DIR}/../../docs)` | **seen** | not seen |
| 5 | `cat "$TESTS_DIR/../../docs/a"` | seen | seen |
| 6 | `cat "${TESTS_DIR}/../docs/a"` | not seen: one level up is `.claude/docs` | not seen |
| 7 | `cat "${TESTS_DIR}/fixtures/docs/a"` | not seen: the suites' own fixtures | not seen |
| 8 | `cat "$TESTS_DIR"/../../docsy/a` | not seen: not the component `docs` | not seen |
| 9 | `cat "$TESTS_DIR/../.././docs/a"` | not seen: the limit | not seen |
| 10 | `cat "${TESTS_DIR%/}/../../docs/a"` | not seen: the limit | not seen |

Written as the HARNESS-110 block writes its fixture, one `printf '%s\n'` per
line, for example `printf '%s\n' "cat \"\${$SDR_T}/../../docs/a\""`.

One `assert_eq` on the whole output of `suite_docs_reads "$t"`. Expected,
exactly, four lines: `.claude/tests/c.test.sh:2`, `:3`, `:4`, `:5`. Its name
starts `HARNESS-113 AC-1:` and says in words that the braced and the
quoted-root spellings of the second root name are reported, and that a path
one level up, under fixtures, a docs-prefixed name, a `/./` and a `%/` on
the name are not.

One assertion, not a positive and a twin: the whole-output comparison over
one file carries both directions. Lines 2-4 missing fail it, and any of
6-10 appearing fails it.

Measured at PLANNED (each pattern run by `awk` over these ten lines).
**Settled: read it out.**

| Pattern | Lines reported |
|---|---|
| `SDR_RE` at `a349761` | 5 |
| C-1's pattern | 2, 3, 4, 5 |
| loosened: `TESTS_DIR.*` in place of the second name's arm | 2, 3, 4, 5, 6, 7, 9, 10 |

*RED's runs.* Each is
`bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs`, one at a
time, after checking machine-wide that no other self-test or gates run is
going (`ps -ef | grep -E 'selftest|gates\.sh' | grep -v grep | grep -v 'attest.sh check'`).
After step 1, expected `shipped-docs: 22 passed, 1 failed`: the new
assertion, actual `.claude/tests/c.test.sh:5`. That is the right failure:
the rule ran over the file, reported the plain read, and missed the three
the header promises. After step 2, expected `shipped-docs: 23 passed,
0 failed`, above the recorded floor of 22, so nothing is red at the end of
RED.

**C-4. Floors and the release (GREEN).**

- `.claude/tests/floors.conf`: line 67, `floor | shipped-docs  | 22`, becomes
  `23`, the count GREEN measures passing; and the dated history comment at
  the end of the file (the HARNESS-110 paragraph is 1257-1260) gains a
  paragraph in the same form: story id, GREEN and the local calendar date,
  the measured line `shipped-docs: 23 passed, 0 failed`, and "+1 (the
  HARNESS-113 second-root assertion)".
- `.claude/tests/selftest.test.sh`: the `COUNTS` entry `shipped-docs 22`
  (line 559) becomes `shipped-docs 23`.
- `.claude/harness/VERSION`: the last line, `130 (2026-11-16)`, becomes the
  next release after whatever `main` holds when GREEN runs (131, or 132 if HARNESS-112
  merged first), with that day's local calendar date in brackets.
  `check-boundaries.sh` refuses a harness change without the bump.
- GREEN's runs, one at a time, with the same machine-wide check first:
  `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs selftest`
  and `bash scripts/attest.sh -- bash scripts/gates.sh --fast`.

**C-5. Baseline, measured at PLANNED on `a349761`. Settled: read it out.**

- `.claude/tests/*.sh` is 37 files, none named `project-*.test.sh`.
- Outside `shipped-docs.test.sh` they hold 13 references to `TESTS_DIR`
  (`_lib.sh` 3, `boundaries` 3, `run-queue` 3, `spawns` 2, `gates` 1,
  `mutate` 1). Exactly one is followed by `/../..`: `_lib.sh:36`,
  `REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"`, the definition of the first
  name. None is braced, and none has the quote closing straight after the
  name.
- The pattern at `a349761` and C-1's pattern each report nothing over those
  37 files, whole-line comments included.
- `CLASSIFY_FIXTURES="$TESTS_DIR/fixtures/classify"` is line 29 of
  `.claude/tests/spawns.test.sh` and occurs once in `.claude/tests/*.sh`
  (DV-2's real line).

**Callers.** No export changes signature. `SDR_RE`, `suite_docs_files` and
`suite_docs_reads` are defined and used only in
`.claude/tests/shipped-docs.test.sh` (grep at PLANNED). The five existing
assertions that call `suite_docs_reads` over fixtures (their calls are at lines
408, 413, 428, 438 and 462) hold no braced or quoted
`TESTS_DIR` line, so their expected output does not move; the one
`TESTS_DIR` line among them (`a.test.sh` line 8, the plain spelling) is seen
before and after.

**Oracle partition.** AC-1 is **settled**: the expected output is the
measured table in C-3, read out, not derived. AC-2 is **mechanical**: the
count is 23 and no existing assertion's text changes.

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

The budget is `rules.md`, "Mutation work per story". Two entries, each one
`mutate.sh` run against the one suite that holds its assertion: DV-1 is the
defect put back for the central claim; DV-2 is the probe the law owes a
changed rule over the tree, against a real line of it. Both expressions are
restated by RED's handoff against the file as built. (Under D-1 option (b)
this section is one entry; D-1 gives it.)

- **DV-1, the defect put back (AC-1).** With C-1's `[}"]*` taken out of
  `SDR_RE` again, the rule is the one `main` has today. `mutate.sh` must
  report 1 line changed (the `SDR_RE=` line). `shipped-docs` **must** report
  exactly 1 failed, `shipped-docs: 22 passed, 1 failed`: the
  `HARNESS-113 AC-1` assertion, its actual value the one line
  `.claude/tests/c.test.sh:5`. Every other assertion still passes: no other
  fixture holds a braced or quoted `TESTS_DIR` line (Contract, Callers), and
  the real tree holds none (C-5). The selftest runner then also prints its
  floor line, 22 against a floor of 23; that is the same failure counted,
  not a second one. RED watches the same red in its step 1, but as an
  observation of the unfixed tree, not a mutation of the fixed one; one run
  at GATES covers the story as committed. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#_DIR\[}"\]\*/#_DIR/#' -- bash scripts/selftest.sh shipped-docs

  (Checked at PLANNED on a copy holding C-1's line: this `sed` gives back
  the line of `a349761` byte for byte.)

- **DV-2, the widened pattern against a real line of this tree (AC-1,
  AC-2).** One line of a real suite, rewritten to the braced spelling the
  old pattern could not see, must be reported. `mutate.sh` must report
  1 line changed. `shipped-docs` **must** report exactly 1 failed,
  `shipped-docs: 22 passed, 1 failed`: the real-tree assertion
  (`HARNESS-106 AC-3: suite_docs_reads over the real tree prints nothing`),
  its actual value the one line `.claude/tests/spawns.test.sh:29`. The
  mutated suite is only read as text by this run, never executed. Under the
  pattern of `a349761` the same mutation reports nothing (measured at
  PLANNED), which is what makes the result a statement about the new
  pattern. It needs the widened pattern, so RED could run it only after its
  step 2, on a tree that is not the committed one. **Owner: GATES.**

      bash scripts/mutate.sh .claude/tests/spawns.test.sh 's|^CLASSIFY_FIXTURES="\$TESTS_DIR/fixtures/classify"$|CLASSIFY_FIXTURES="${TESTS_DIR}/../../docs/a"|' -- bash scripts/selftest.sh shipped-docs

  (`CLASSIFY_FIXTURES="$TESTS_DIR/fixtures/classify"` is line 29 at
  `a349761` and occurs once in `.claude/tests/*.sh`.)

**Results, GATES, 2026-11-18, on the GREEN commit; both as predicted.**

DV-1: 1 line changed (the SDR_RE= line), exactly 1 failed, the HARNESS-113 AC-1 assertion with actual `.claude/tests/c.test.sh:5`; floor line 22 against 23 is the same failure counted; file restored and verified.

    === mutate: .claude/tests/shipped-docs.test.sh (1 line(s) changed by /^SDR_RE=/s#_DIR\[}"\]\*/#_DIR/#) ===
    === mutate: running bash scripts/selftest.sh shipped-docs ===
        FAIL HARNESS-113 AC-1: the braced and the quoted-root spellings of the second root name are reported, as the plain one is, while a path one level up, one under the suites' fixtures, a docs-prefixed name, a /./ before docs and a %/ on the name are not
             expected: .claude/tests/c.test.sh:2
             .claude/tests/c.test.sh:3
             .claude/tests/c.test.sh:4
             .claude/tests/c.test.sh:5
             actual:   .claude/tests/c.test.sh:5
    shipped-docs: 22 passed, 1 failed
    FAIL shipped-docs  did 22 units of work, below the floor of 23 in .claude/tests/floors.conf
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests_shipped-docs.test.sh.20261119T042557Z.14742.bak) ===

DV-2: 1 line changed (spawns.test.sh:29), exactly 1 failed, the HARNESS-106 AC-3 real-tree assertion with actual `.claude/tests/spawns.test.sh:29`; file restored and verified.

    === mutate: .claude/tests/spawns.test.sh (1 line(s) changed by s|^CLASSIFY_FIXTURES="\$TESTS_DIR/fixtures/classify"$|CLASSIFY_FIXTURES="${TESTS_DIR}/../../docs/a"|) ===
    === mutate: running bash scripts/selftest.sh shipped-docs ===
        FAIL HARNESS-106 AC-3: suite_docs_reads over the real tree prints nothing: no suite line reads the project's own docs, which a consumer does not share
             expected: 
             actual:   .claude/tests/spawns.test.sh:29
    shipped-docs: 22 passed, 1 failed
    FAIL shipped-docs  did 22 units of work, below the floor of 23 in .claude/tests/floors.conf
    1 of 1 harness suite(s) FAILED.
    === mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_tests_spawns.test.sh.20261119T042955Z.16390.bak) ===

Not owed, and stated so that nobody adds one: a mutation per fixture line
(lines 3, 4 and 6-10 are pinned by the same whole-output comparison, and
earning each is `/audit-mutations` work); the loosened-pattern control of
AC-1 as a run (it is a measurement in C-3, and lines 6-10 hold it in the
assertion); and anything for the comment, which has no behaviour.

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

Planned by `bash scripts/plan.sh write HARNESS-113` from `.claude/harness/models.conf`.
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

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->

- PLANNED, `lead-po`, resolved Fable 5.2 (`claude-fable-5-2`), as planned; no override.
- RED, `test-developer`, resolved Opus 5.5 (`claude-opus-5-5`), as planned; no override.
- GREEN, `feature-developer`, resolved Opus 5.5 (`claude-opus-5-5`), as planned; no override. It replaced VERSION's line 131 with 132 rather than appending, as C-4 and the file header say; the orchestrator's brief had said append, wrongly.
- GATES, `feature-developer`, resolved Opus 5.5 (`claude-opus-5-5`), as planned; no override.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Any other spelling of the second root name: a `%/` on the name
  (`${TESTS_DIR%/}/../..`), a doubled slash inside `/../..`, a `:?` or any
  other expansion, a `/./` before `docs`. The first and the last are named
  in the limit and pinned as unseen (fixture lines 10 and 9); none is made
  to match.
- Any change to what the rule sees for `REPO_ROOT`. HARNESS-110's three
  limit spellings stay unseen, and its fixture and assertion are not edited.
- Any edit to `suite_docs_reads` or `suite_docs_files`, or to an existing
  fixture or assertion. The new lines go in a fixture of their own, not into
  `a.test.sh` of the HARNESS-106 block.
- A left anchor for the root names (`MY_TESTS_DIR/../..` matches today, as
  `XREPO_ROOT` does). Not this defect.
- An assertion on the comment's wording (HARNESS-110, D-1).
- A check that no suite spells `TESTS_DIR` with a brace or a closing quote.
  Measured once at PLANNED (C-5); not enforced beyond what the rule itself
  now reports.
- Data-flow reads (a variable, a `cd`, `git -C`): already the written limit,
  unchanged.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

Level: suite-internal unit, the cheapest level that can falsify the rule.
`suite_docs_reads` is a function of `.claude/tests/shipped-docs.test.sh`, and
the assertion calls it directly over a fixture tree under `$WORK`.

| Test (in `.claude/tests/shipped-docs.test.sh`) | Asserts | AC |
|---|---|---|
| new block `the second root name, braced and quoted (HARNESS-113)`, one `assert_eq` named `HARNESS-113 AC-1: the braced and the quoted-root spellings of the second root name are reported, ...` | the whole output of `suite_docs_reads "$t"` over `$WORK/suite-second-root/.claude/tests/c.test.sh` (the AC's ten lines, verbatim) is exactly the four lines `.claude/tests/c.test.sh:2`, `:3`, `:4`, `:5`, in that order. Anchored: a full-string compare, not a substring | AC-1 |
| the 22 existing assertions, not edited (no existing fixture or assertion touched) | unchanged and passing; among them `HARNESS-106 AC-3: suite_docs_reads over the real tree prints nothing`, which now runs the widened pattern over the real tree | AC-2 |
| the suite's count | `shipped-docs: 23 passed, 0 failed` (22 before) | AC-2 |

The fixture is written with `$SDR_T` (HARNESS-106 block), so this suite's
source never holds the name next to `/../../docs`. Its bytes were checked
outside the framework against the AC's ten lines before the first run
(identical).

## Handoff: RED -> GREEN

**Command.** `bash scripts/selftest.sh shipped-docs` (C-4). GREEN's own runs
are C-4's: `bash scripts/attest.sh -- bash scripts/selftest.sh shipped-docs selftest`
and `bash scripts/attest.sh -- bash scripts/gates.sh --fast`, one at a time,
after the machine-wide `ps` check.

**Step 1, the fixture and assertion against the unfixed `SDR_RE`** (the
pattern of `a349761`, unchanged at HEAD `77d1355`). Attested:
`exit: 1`, `last: 1 of 1 harness suite(s) FAILED.`,
log `.claude/state/attest-logs/20261119T035625Z.5259.log`
(tree `bf191d9367818f7dc86e6edf74c2c4e153a34319`). Verbatim from the log:

```
  the second root name, braced and quoted (HARNESS-113)
    FAIL HARNESS-113 AC-1: the braced and the quoted-root spellings of the second root name are reported, as the plain one is, while a path one level up, one under the suites' fixtures, a docs-prefixed name, a /./ before docs and a %/ on the name are not
         expected: .claude/tests/c.test.sh:2
         .claude/tests/c.test.sh:3
         .claude/tests/c.test.sh:4
         .claude/tests/c.test.sh:5
         actual:   .claude/tests/c.test.sh:5

shipped-docs: 22 passed, 1 failed

assertion floors: all 1 suite(s) met their declared floor (22 assertions executed, 22 declared).
1 of 1 harness suite(s) FAILED.
```

Why it is the right failure: the rule ran over the file (the plain read on
line 5 was reported, so the fixture was scanned and the pattern fired) and
missed exactly the three spellings the header promises (2, 3, 4). It is the
defect as AC-1 states it ("before the fix the same run prints only
`.claude/tests/c.test.sh:5`"), not a load or fixture error; the other 22
assertions passed.

**Step 2, C-1's `SDR_RE` and C-2's comment applied.** `SDR_RE=` (now line
210) gained `[}"]*` between `_DIR` and `/[.][.]/[.][.]`, nothing else; the
header gained the three lines C-2 gives; the limit paragraph gained C-2's
three-line sentence after "(HARNESS-110, D-1).". Attested:
`exit: 0`, `last: 1 harness suite(s) passed.`,
log `.claude/state/attest-logs/20261119T035835Z.2226.log`
(tree `f61ecbb5fb14302e3d86ffe299a210842d8bb5c3`):

```
  the second root name, braced and quoted (HARNESS-113)

shipped-docs: 23 passed, 0 failed

assertion floors: all 1 suite(s) met their declared floor (23 assertions executed, 22 declared).
1 harness suite(s) passed.
```

Final attested runs, on the tree handed over (tree `f61ecbb5fb14302e3d86ffe299a210842d8bb5c3`;
the work-tree hash does not cover this story file, and it was the same
before and after this handoff was written):

- `bash scripts/selftest.sh shipped-docs`: `exit: 0`,
  `last: 1 harness suite(s) passed.`, log
  `.claude/state/attest-logs/20261119T040052Z.3041.log` (23 passed, 0 failed).
- `bash scripts/gates.sh --fast`: `exit: 0`,
  `last: All required gates passed (0 ran, 5 unconfigured, 0 known).`, log
  `.claude/state/attest-logs/20261119T040211Z.3800.log`. Shape: this
  repository's `project.conf` is not bootstrapped, so format, lint,
  typecheck, unit and coverage are UNCONFIGURED (warnings), mutation is on
  request, integration and build skipped by `--fast`. No gate ran the suite,
  so `--fast` says nothing about it here; the harness's own gate for this
  story is the self-test (C-4).

**Files touched.** `.claude/tests/shipped-docs.test.sh` (pattern, header,
limit sentence, new block before `summary "shipped-docs"`) and this story's
`## Test plan` and `## Handoff`. Nothing else.

**What GREEN writes (C-4), and only that.** `floors.conf` `floor | shipped-docs | 22`
-> `23` plus the dated history paragraph; `selftest.test.sh` `COUNTS`
`shipped-docs 22` -> `23`; `VERSION` bump to the next release after
`main` (main is now at 131, HARNESS-112's, so 132 unless something else lands).
The runner currently prints `23 assertions executed, 22 declared`: that is the
floor GREEN raises, not a failure. GREEN touches no line of
`shipped-docs.test.sh`.

**Export shape pinned.** No module, no export. The test calls
`suite_docs_reads <root>` (defined in the same suite) and compares its stdout
as a string. Not constrained: nothing for GREEN; the floor-history wording is
GREEN's.

**Passed on arrival.** None new. AC-2's 22 existing assertions are unchanged
and were already green; the one that judges the widened pattern over the real
tree (`HARNESS-106 AC-3 ... prints nothing`) is earned for the new pattern by
DV-2 at GATES.

**Contract line numbers.** C-1..C-3 cite the file as it was at `a349761`,
identical at HEAD before RED (`git diff a349761 HEAD -- .claude/tests/shipped-docs.test.sh`
empty), so no amendment. After RED: `SDR_RE=` is line 210 (was 205),
`summary "shipped-docs"` line 498, the HARNESS-113 assertion line 492.

**Negative controls, expected values.** Measured outside the framework:
the fixture regenerated from the suite's own `printf` lines, and each pattern
run by `awk` with the rule's comment skip, as `suite_docs_reads` runs it.
Unlike an import-failure RED, the AC-1 assertion itself *did* execute in both
steps, so control (i) is an observed result, not only a claim.

| Control | Pattern | Expected lines of `c.test.sh` | Measured (RED, outside the framework) | Observed in the suite |
|---|---|---|---|---|
| (i) fix reverted (DV-1) | `SDR_RE` of `a349761` | 5 | 5 | step 1: actual `.claude/tests/c.test.sh:5`, 22 passed 1 failed |
| the fix | C-1's pattern | 2, 3, 4, 5 | 2, 3, 4, 5 | step 2: 23 passed |
| (ii) loosened, `TESTS_DIR.*` in place of the second name's arm | not run in the suite (C-3, "Not owed") | 2, 3, 4, 5, 6, 7, 9, 10 | 2, 3, 4, 5, 6, 7, 9, 10 | - (would fail AC-1 by adding 6, 7, 9, 10) |
| real tree, C-1's pattern | 37 files of `.claude/tests/*.sh` | nothing | nothing | `HARNESS-106 AC-3 ... prints nothing` passes |
| DV-2 mutation, on a copy of `spawns.test.sh` | `SDR_RE` of `a349761` / C-1's | nothing / 29 | nothing / 29 | not run (GATES) |

**DV-1 declined by RED, owner GATES.** It mutates the fixed file, and the
committed tree is the one to judge; RED's step 1 is the observation of the
unfixed tree, not this mutation. Restated against the file as built (the
expression is unchanged; checked on a copy: exactly one line changes, line
210, and the result is byte-identical to the `SDR_RE=` line of HEAD):

    bash scripts/mutate.sh .claude/tests/shipped-docs.test.sh '/^SDR_RE=/s#_DIR\[}"\]\*/#_DIR/#' -- bash scripts/selftest.sh shipped-docs

Predicted: 1 line changed; `shipped-docs: 22 passed, 1 failed`, the
`HARNESS-113 AC-1` assertion with actual `.claude/tests/c.test.sh:5`; after
GREEN raises the floor, also the floor line, 22 against 23 (the same failure
counted).

**DV-2 declined by RED, owner GATES.** It needs the widened pattern on the
committed tree. `CLASSIFY_FIXTURES="$TESTS_DIR/fixtures/classify"` is still
line 29 of `.claude/tests/spawns.test.sh` and occurs once in
`.claude/tests/*.sh` (grep after step 2). Expression unchanged (checked on a
copy: exactly line 29 changes, to `CLASSIFY_FIXTURES="${TESTS_DIR}/../../docs/a"`):

    bash scripts/mutate.sh .claude/tests/spawns.test.sh 's|^CLASSIFY_FIXTURES="\$TESTS_DIR/fixtures/classify"$|CLASSIFY_FIXTURES="${TESTS_DIR}/../../docs/a"|' -- bash scripts/selftest.sh shipped-docs

Predicted: 1 line changed; `shipped-docs: 22 passed, 1 failed`, the
`HARNESS-106 AC-3: suite_docs_reads over the real tree prints nothing`
assertion with actual `.claude/tests/spawns.test.sh:29`; under the old
pattern the same mutated line is not reported (measured on the copy).

**Approach changes.** None.

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

### Round 1, 2026-11-18

Reviewer: `lead-po` on the DIFF-REVIEW row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override. Changed no file.

Checked: the committed `SDR_RE` over 16 lines of the reviewer's own (seen: braced, quote-closed, both together, unquoted, a doubled slash before `docs`, a bare `.../docs` at end of line; not seen: `docs-shipped.conf`, three levels up, `${TESTS_DIR:?}`, `TESTS_DIRS`, a path built in a variable, a whole-line comment; `$MY_TESTS_DIR` is seen, the missing left anchor Out of scope names); the real tree (no match, comments included; the 13 `TESTS_DIR` references as C-5 lists them); the fixture's ten `printf` lines against AC-1's ten lines; the header and limit comment against C-2; callers (`SDR_RE` and both functions are used only in this suite; no older fixture holds a braced or quote-closed `TESTS_DIR` line); floors and release (23 in both records, VERSION 132 over main's 131); per-commit write sets; AC text unchanged since the PLANNED commit; DV-1 and DV-2 pasted with verified restores.

**Should fix:**

1. **The "any number, any order" half of the widening has no test** (`.claude/tests/shipped-docs.test.sh:210`, fixture 480-491). `[}"]*` lets any run of `}` and `"` stand between the name and `/../..`, which C-1 says is so that `"${TESTS_DIR}"/../../docs/a` counts. No fixture line holds both. Measured: with `[}"]?` in place of `[}"]*` all 23 assertions stay green and that combined line is no longer reported. Fix: one fixture line `cat "${TESTS_DIR}"/../../docs/a` expected reported; this cannot be done inside the frozen criteria (an eleventh line changes AC-1, a separate assertion makes the count 24 where AC-2 says 23), so a follow-up story is the cheaper home. If skipped: a later narrowing to one character goes unnoticed; the same gap exists for `REPO_ROOT` (HARNESS-106's fixture never holds both), and no line of the tree uses the combined spelling. Does not block. **Route:** RED

Not checked: the reviewer ran no suite (two `gates.sh` runs were live on the machine); the orchestrator checks the gate record.

Verdict: Ship.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-19T04:43:22Z
    commit: 708a897
    tree:   e678bc1a48bdb09be909b846208d5bce32c11867
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

- **PLANNED, 2026-11-16.** Planned by a `lead-po` dispatch on the PLANNED
  row, planned `fable`, resolved Fable 5.2 (`claude-fable-5-2`); no override
  was reported to it. D-1 (widen for the second root name, recommended, or
  correct the header) is a PO decision for the orchestrator to put to the
  user before the story leaves PLANNED. The story is written for (a); D-1
  lists every block that changes under (b).
- **The title and slug fit both options on purpose**, so the user's choice
  does not rename the branch.
- **`bash scripts/plan.sh conflicts`, 2026-11-16, this worktree:**
  `fewer than two startable stories; nothing to compare` (exit 0). It judged
  no pair, so it is not evidence that any pair is clear: it sees only the
  stories in this tree, and this is the only one here that is not DONE.
- **HARNESS-112 collides, read by hand.** It is PLANNED on the local branch
  `story/HARNESS-112-the-run-queue-suite-reaches-the-exit-for` (worktree
  `laughing-shirley-5afc9b`), not on `origin/main`, and its `touches:` names
  `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh` and
  `.claude/harness/VERSION`, three of this story's four files. That is a
  collision, not a dependency, so it is not in `depends_on`: it changes the
  `run-queue` floor line and COUNTS entry, this story the `shipped-docs`
  ones, and each takes its own release number. The two must not be treated
  as a clear pair; whichever merges second merges `main`, takes the next
  release number and has its gates run again.
- **This story was first cut as HARNESS-112** and renumbered at PLANNED,
  before any commit, when the orchestrator found that id held by the story
  above.
- **Not already delivered.** Checked at PLANNED by running the pattern of
  line 205 over lines of my own (Context table): the braced and quoted
  spellings of the second name are missed on `a349761`.
- **The third spelling in the request, `"$TESTS_DIR/../.././docs/a"`,** is
  not a broken promise of the header: it is the `/./` case HARNESS-110
  already put in the written limit, for either name. Under both options it
  stays unseen and is pinned as such.
- GATES → REVIEW, 2026-11-18: diff review round 1 ships. Its one Should fix (no fixture line holds both a brace and a closing quote, so narrowing `[}"]*` to `[}"]?` stays green) is routed RED but needs AC-1 and AC-2 changed, which the reviewer itself places in a follow-up story; it is not taken in this story and is offered to the user as one. DIFF-REVIEW, `lead-po`, resolved Fable 5.2 (`claude-fable-5-2`).
- GATES → REVIEW, 2026-11-19: `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed`, run by a `feature-developer` on the GATES row (resolved Opus 5.5, `claude-opus-5-5`) after waiting for four other gates runs on the machine to finish: 11 suites passed, `assertion floors: all 11 suite(s) met their declared floor (2136 assertions executed, 2136 declared)`, exit 0, 10837 s, tree 5127644; `attest.sh check` fresh.
