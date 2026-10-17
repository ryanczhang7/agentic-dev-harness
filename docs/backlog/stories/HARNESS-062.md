---
id: HARNESS-062
title: check-boundaries matches gate names, owners and waivers as whole words, at DONE as well as REVIEW
slug: check-boundaries-matches-gate-names-owne
epic: 
type: chore
status: in-review
phase: REVIEW
branch: story/HARNESS-062-check-boundaries-matches-gate-names-owne
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/tests/boundaries.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(survivors B04, B05, B07 and B08). The required gate is the harness self-test
(`boundaries` suite) and CI's `check-boundaries.sh` step. Each mutant below
survives `boundaries.test.sh` (125 passed, 0 failed), and each loosens a match
`check-boundaries.sh` relies on to refuse a PR:

- **B08** (line 462). A story's `required_gates` entry `g` must appear as
  `PASS g` in the recorded run, followed by a space, `(` or end of line.
  Replacing that with a bare `$g` survives, so nothing pins that `PASS unit-slow`
  does not satisfy a required `unit`. This is a prefix match letting one gate's
  pass stand in for another's.
- **B04** (line 116). A deferred verification's owner must name a phase
  (`red|green|gates|review|done`). Widening that to `[a-z]*` survives, so
  nothing pins that `owner: banana` is refused.
- **B05** (line 99). `waived` must be a whole word. Replacing that with a
  substring match survives, so nothing pins that `unwaived` is not a waiver.
- **B07** (line 459). The required-gates check runs for `REVIEW|DONE`. Dropping
  `DONE` survives, so nothing pins the check at DONE.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — Given a REVIEW story with `required_gates: [unit]` whose
  `## Gate results` shows `PASS unit-slow` and no `PASS unit`, when
  `check-boundaries.sh` runs, then it fails naming `unit`. *Negative control:*
  `PASS unit` and `PASS unit (12s)` each satisfy it.
- **AC-2** — Given a `## Deferred verifications` section whose only owner line names no phase
  (`owner: banana`), then `check-boundaries.sh` refuses it; `owner: GREEN` is
  accepted.
- **AC-3** — Given a `## Deferred verifications` section with no owner that says `unwaived` (and not `waived` as a word),
  then it is not treated as waived; `waived` and `Waived:` still are.
- **AC-4** — Given a DONE story with `required_gates: [unit]` and no `PASS unit`
  in its recorded run, then `check-boundaries.sh` fails naming `unit`.
- Each of AC-1 to AC-4 passes on arrival unless the current code is wrong, so
  each is earned by its audit mutant (B08, B04, B05, B07) going red, recorded in
  `## Regressions`.

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

**Writes:** `.claude/tests/boundaries.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Pinned by the Lead PO on 2026-10-17, on main at `c54d8ca` (HARNESS-061
DONE).** `scripts/check-boundaries.sh` is NOT written by this story: the audit
judged the four lines correct and the tests absent, and the Context above
restates that. If RED finds a line wrong, that is an escalation, not a fix.
Every path here classifies as `harness` (`bash scripts/classify.sh`), so the
lock permits each phase to write any of them; the role table in `rules.md` is
what keeps RED out of `check-boundaries.sh`. No `## Scaffold inventory` is owed:
a `chore` owes one only when a source file changes without tests, and none does.
RED may amend any block below in place with a reason; what the amended block
says is what the story claims.

**C-0. The lines under test, verified by `grep -n` today.** Line numbers are
read from the tree, not from the audit, and RED re-reads them before using
the expressions in C-5, because `sed` addresses by line:

    scripts/check-boundaries.sh:99    has_waiver   exit (tolower(s) ~ /(^|[^a-z])waived([^a-z]|$)/) ? 0 : 1
    scripts/check-boundaries.sh:116   has_owner    ... owner[^a-z]*:?[^a-z]*(red|green|gates|review|done)([^a-z]|$) ...
    scripts/check-boundaries.sh:459   3e-i         REVIEW|DONE)
    scripts/check-boundaries.sh:462   3e-i         "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)"

**C-1. Where the tests go, and with what.** New assertions in
`.claude/tests/boundaries.test.sh`, inside the existing `describe` blocks that
own each rule, or new `describe` blocks beside them - RED's choice, said in
`## Test plan`. Everything they need exists in the file already:
`run_boundaries` (sets `$out` and `$rc`), `refused <what> <needle>` (message
AND non-zero exit), `assert_contains`, `assert_eq`, `whole_line`, `$WANT_3H`
(`:101`, the exact 3h refusal line), `story_on_branch [type] [extra-frontmatter-line]`
(`:72`, writes T-1 at `phase: REVIEW` with the body from stdin), `story_blocked
<phase> [required_gates]` (`:532`, a REAL gate record from `gates.sh`, with a
`unit` gate that passes), `gates_recorded <what>` (`:1390`), `write_conf`
and `commit_all`. Rule 3e-i (`:459-468`) reads the `## Gate results` SECTION
TEXT, so a pasted record is enough for it; the separate tree-hash rule (3e)
will also refuse a pasted record, with a different message, which is why
every refusal below asserts the 3e-i needle and every acceptance asserts the
`ok` line rather than `$rc`.

**C-2. One signature changes.** `story_on_branch` gains a THIRD optional
argument, the phase, defaulting to `REVIEW`, so that every existing call
writes the same bytes it writes today (the HARNESS-054 shape for its second
argument). Callers, grep-listed today: 31 mentions in
`.claude/tests/boundaries.test.sh`, of which 4 pass arguments (`:1397`,
`:1407`, `:1422`, `:1432`, all `spike '...'`) and the rest pass none; no other
file calls it (`git grep -l story_on_branch` today: this suite, and prose in
the HARNESS-003, -006, -037 and -054 story files). RED's handoff states that this list was checked against
the tree. RED may instead write a separate helper and leave `story_on_branch`
alone, with a reason.

**C-3. The fixtures, one per criterion, with the exact needles.**

- *AC-1 (B08).* A REVIEW story with `required_gates: [unit]` whose
  `## Gate results` carries `PASS         unit-slow (1s)` and no line
  matching `PASS` + spaces + `unit` + (space, `(` or end of line). Pasted,
  via `story_on_branch feature 'required_gates: [unit]'` with the section on
  stdin, or real, via a `write_conf` naming a gate `unit-slow` (gate ids are
  free-form fields; `gates.sh:148-157` accepts the hyphen) and
  `gates_recorded` - either is fine; say which. Refusal needle, from `:465`:
  `frontmatter requires gate 'unit', but the recorded run has no PASS for it`.
  Negative controls, each asserted on the `ok` line from `:463`
  (`ok    story-required gate 'unit' passed in the recorded run`): a pasted
  `PASS         unit (12s)` and a pasted `PASS         unit` ending the line.
  The existing `story_blocked REVIEW '[unit]'` case at `:1361` already covers
  the real-record `(` form and stays as it is.
- *AC-2 (B04).* A `## Deferred verifications` whose only owner line is
  `owner: banana` (lower case, colon, one word - exactly the shape the mutant
  admits), carrying a fenced result so that 3h does not fire first. Needle:
  `does not declare an owner`. Control: the same section with `Owner: GREEN`
  asserts `ok    ## Deferred verifications names the phase that owns each entry`
  - every existing control says GATES, and the mutant keeps GATES.
- *AC-3 (B05).* A `## Deferred verifications` with `Owner: GATES`, no fenced or
  four-space-indented block, and the word `unwaived` in the prose (and no
  `waived` as a word - re-read the prose for one). Needle: `## Deferred
  verifications has no result and no waiver`, and `whole_line` against
  `$WANT_3H`. Controls: `waived` lower case mid-sentence, and `Waived:` at the
  start of a line, each asserting `ok    ## Deferred verifications carries an
  explicit waiver`. The existing `WAIVED -` case at `:702` stays.
- *AC-4 (B07).* A `phase: DONE` story with `required_gates: [unit]` and a
  `## Gate results` carrying `PASS         unit-slow (1s)` and no `PASS unit`.
  Needle: `frontmatter requires gate 'unit', but the recorded run has no PASS
  for it`. This is the one case that needs C-2. Under B07 the rule is skipped at
  DONE and the needle never prints; other rules still exit non-zero, which is
  why `refused` checks the message as well as the status.

**C-4. The floor.** `boundaries` is floored at **125** in
`.claude/tests/floors.conf:39` and mirrored in the COUNTS table at
`.claude/tests/selftest.test.sh:530`. RED raises both to the count it reads
off its own run of `bash scripts/selftest.sh boundaries` (the `N` of
`boundaries: N passed, M failed`, N+M executed), in the RED commit, with a
dated comment in `selftest.test.sh` beside the HARNESS-054 one at `:446-455`.
The audit measured **125 passed, 0 failed** on `d1db573`; the orchestrator's
own baseline run on this tree is pasted in `## Notes` (it takes more than five
minutes here, which matters for C-5).

**C-5. What earns the tests.** Every assertion this story adds passes on
arrival, because the four lines are correct today. So each is earned the way
`rules.md` says a test written against existing code is earned: one mutation
through `scripts/mutate.sh`, the one assertion it targets going red, the
restore verified, the output pasted into `## Regressions` by RED (the Test
Developer owns that section). The four expressions, dry-run today against the
line numbers in C-0 so that each changes exactly its one line (shown here as
typed inside single quotes at a shell; `\$` is deliberate):

    B05  bash scripts/mutate.sh scripts/check-boundaries.sh '99s#(^|\[^a-z\])waived(\[^a-z\]|$)#waived#' -- bash scripts/selftest.sh boundaries
    B04  bash scripts/mutate.sh scripts/check-boundaries.sh '116s#(red|green|gates|review|done)#[a-z]*#' -- bash scripts/selftest.sh boundaries
    B07  bash scripts/mutate.sh scripts/check-boundaries.sh '459s#REVIEW|DONE)#REVIEW)#' -- bash scripts/selftest.sh boundaries
    B08  bash scripts/mutate.sh scripts/check-boundaries.sh '462s#\$g( |\\(|\$)"#$g"#' -- bash scripts/selftest.sh boundaries

*Note from RED, 2026-10-17 (not an amendment - the four expressions are right
as written):* an agent's Bash tool halves a doubled backslash before the shell
sees it, even inside single quotes (`printf '%s\n' 'a\\b'` prints `a\b`
there). Typed through that tool verbatim, B08 reaches sed as `\(` and is
refused - `mutate: sed rejected the expression: sed: -e expression #1, char
23: Unmatched ( or \(`, exit 2, nothing run. An agent re-running B08 (DV-1)
must type `\\\\(` to deliver C-5's `\\(`; the `=== mutate:` header in
`## Regressions` prints the expression sed actually received, and it is C-5's,
byte for byte.

Expected under each: the suite goes from N/0 to N-k passed, k failed, where k
is the number of assertions that criterion's fixture makes and the failures
name only that criterion; and `=== mutate: ... restored (verified byte-for-byte
...) ===` closes each run, with `bash scripts/mutate.sh --check` clean after the
last. Four runs of a five-minute suite is the budget here, and it is the one
`rules.md` requires (one per test written against existing code); the
"defect put back" for the story's central claim is these same four, not a
fifth. Run them one at a time: the suite and `gates.sh` share a run lock
(HARNESS-034), and nothing else may run in this tree while one is going.

**C-6. Oracle partition.** All four criteria are mechanical: an exact message
printed or not printed for an exact fixture. Nothing is settled by
measurement and nothing needs an invented metric; the only numbers in the story
are the line numbers in C-0 and the floor in C-4.

**C-7. Not constrained.** The wording of RED's `describe` titles and assertion
names; whether AC-1's fixture is pasted or real; whether C-2 is a third
argument or a new helper.

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

- **DV-1 — RED's mutation table, checked by a run RED did not make.** RED's
  `## Regressions` will claim four mutations, each turning only its own
  criterion's assertions red. The orchestrator re-runs ONE of them, the one
  whose predicted catch is the smallest number of assertions (B07, AC-4, unless
  RED's table says otherwise), and compares the count RED recorded with the
  count it sees, then confirms `bash scripts/selftest.sh boundaries` is back at
  N/0 and `bash scripts/mutate.sh --check` is clean. Falsifiable condition:
  the failing assertions are exactly the ones RED named, and no fewer. RED
  cannot discharge this - it is a check on RED's claim, so it is made by
  someone else. **Owner: GATES.**

  **Result (GATES, orchestrator, 2026-10-17).** Target moved to B04 per
  `## Notes` 4 (RED's table has AC-4 at two assertions, AC-2 at one). Run
  detached under the run lock on commit `0288fec`, 22:12:28Z to 22:26Z; the
  count, the assertion and the restore all match what RED recorded:

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 116s#(red|green|gates|review|done)#[a-z]*#) ===
=== mutate: running bash scripts/selftest.sh boundaries ===
    FAIL HARNESS-062 AC-2: an owner line naming no phase (owner: banana) is refused
boundaries: 135 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261017T221229Z.27372.bak)
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

  The suite was 136/0 on this tree before the run (`## Notes` 5) and the full
  gate run that follows judges the restored tree.

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

Planned by `bash scripts/plan.sh write HARNESS-062` from `.claude/harness/models.conf`.
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

- PLANNED, orchestrator (`lead-po` role, this session), 2026-10-17: **Fable 5.1** (`claude-fable-5-1`), the session's model. Planned `fable`; no change.
- RED, `test-developer`, 2026-10-17: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override passed. Planned `opus`; no change.
- GREEN, 2026-10-17: **no dispatch.** RED's handoff predicted a no-op and the orchestrator verified it rather than hand an agent nothing to do: `git diff f2181f4 ee345c2 --stat -- scripts .claude/hooks` is empty, and the boundaries suite re-run on the RED commit is pasted in `## Notes`.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- B09 (the frontmatter-start check, line 144), which survives because the
  per-key checks below it also fire. Recorded in the audit as low impact.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

All eleven new assertions are integration-level: each builds a real two-branch
fixture repository with `story_on_branch`, runs the real
`scripts/check-boundaries.sh main` through `run_boundaries`, and reads `$out`
(and `$rc`, through `refused`). That is the cheapest level that can falsify
any of the four criteria - the rules under test are awk regexes inside a
script, reached only by running the script. All four criteria are mechanical
(C-6): exact needles, exact fixtures, no measured thresholds.

Placement (C-1, RED's choice): beside the existing case that owns each rule,
appended at the end of its describe.

- **AC-2 and AC-3** at the end of `describe "a deferred verification is
  discharged or waived, never just filed"`, after the HARNESS-037 AC-3 (d) case.
- **AC-1 and AC-4** at the end of `describe "a gate the story escalated for
  itself appears in the record"`, after `"and the run is clean"`.

| AC | Assertion name | Kind | Fixture |
|---|---|---|---|
| AC-1 | `HARNESS-062 AC-1: a PASS for unit-slow does not satisfy a required unit` | `refused` (needle + non-zero exit) | REVIEW, `required_gates: [unit]`, pasted `PASS         unit-slow (1s)` |
| AC-1 | `HARNESS-062 AC-1: PASS unit followed by its timing satisfies a required unit` | control, ok line | pasted `PASS         unit (12s)` |
| AC-1 | `HARNESS-062 AC-1: PASS unit ending the line satisfies a required unit` | control, ok line | pasted `PASS         unit` |
| AC-2 | `HARNESS-062 AC-2: an owner line naming no phase (owner: banana) is refused` | `refused` | `owner: banana`, fenced result |
| AC-2 | `HARNESS-062 AC-2: the same section with Owner: GREEN is accepted as owned` | control, ok line | `Owner: GREEN`, fenced result |
| AC-3 | `HARNESS-062 AC-3: 'unwaived' is not a waiver, so the entry has no result and no waiver` | `refused` | `Owner: GATES.`, no block, `unwaived` |
| AC-3 | `HARNESS-062 AC-3: and the refusal is the whole 3h line` | `whole_line` vs `$WANT_3H` | same run |
| AC-3 | `HARNESS-062 AC-3: 'waived' in lower case mid-sentence is a waiver` | control, ok line | `The PO waived it on ...` |
| AC-3 | `HARNESS-062 AC-3: 'Waived:' starting a line is a waiver` | control, ok line | `Waived: the encoder moved ...` at column 0 |
| AC-4 | `HARNESS-062 AC-4: at DONE, a PASS for unit-slow does not satisfy a required unit` | `refused` | DONE, `required_gates: [unit]`, pasted `PASS         unit-slow (1s)` |
| AC-4 | `HARNESS-062 AC-4: at DONE, a recorded PASS unit is reported as passing` | ok line (second direction of the same rule at DONE) | DONE, pasted `PASS         unit (12s)` |

AC-1's record is PASTED, not run through `gates.sh` (C-3 left the choice):
rule 3e-i reads only the section text, and a pasted record keeps the fixture
to one heredoc. The tree-hash rule refuses every pasted record with its own
message, so the controls assert the `ok` line and never `$rc`.

AC-4 has a second assertion the brief did not ask for: at DONE, a passing
record is SAID to pass. It is the same rule from the other side and it goes
red under B07 as well (the rule does not run, so no ok line), which makes the
DONE arm pinned in both directions.

Out of scope and not pinned: B09 (`## Out of scope`).

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

Written by the Test Developer (agent definition `model: opus`; dispatched
without an override, so far as this agent can see - the orchestrator records
what it resolved to).

**GREEN is expected to be a no-op: no source changes.** The four lines in
`scripts/check-boundaries.sh` (C-0, re-read with `grep -n` on this tree: 99,
116, 459, 462 - unchanged) are correct; every new assertion passes on arrival
and is earned by its audit mutant instead (`## Regressions`). Nothing found in
RED says otherwise.

**Command.**

    bash scripts/selftest.sh boundaries

Takes about 9 minutes on this machine (8m46s measured locally for the first
clean run); it holds the run lock, so nothing else may run alongside it.

**Clean run on this tree** (after the floor was raised to 136, with
`check-boundaries.sh` untouched):

    boundaries: 136 passed, 0 failed

    assertion floors: all 1 suite(s) met their declared floor (136 assertions executed, 136 declared).
    1 harness suite(s) passed.

136 executed (125 before + 11 new). The `selftest` suite, which mirrors the
floor in its COUNTS table, also ran clean after the change:
`selftest: 268 passed, 0 failed`. `bash scripts/gates.sh --fast`: every gate
UNCONFIGURED (this repository is not bootstrapped), `All required gates passed
(0 ran, 5 unconfigured, 0 known)` - nothing a gate could trip on.

**There is no red to hand over** - the right "failure" here is the mutant runs,
one per criterion, pasted in full in `## Regressions`.

**Files touched.**

- `.claude/tests/boundaries.test.sh` - `story_on_branch` gains a third
  argument (below); eleven new assertions.
- `.claude/tests/floors.conf` - `boundaries` 125 -> 136 (line 39), and a dated
  HARNESS-062 comment appended after the HARNESS-061 one at the end of the
  file. The brief placed the HARNESS-054 comment at `selftest.test.sh:446-455`;
  on this tree it is at `floors.conf:446-455`, and every floor-raise comment
  lives in `floors.conf`, so the new one went there too.
- `.claude/tests/selftest.test.sh` - COUNTS table `boundaries 125` -> `136`
  (line 530). Nothing else.
- this story: `## Test plan`, `## Handoff: RED -> GREEN`, `## Regressions`,
  and a note (not an amendment) under C-5 about typing B08 through an agent's
  Bash tool.

**Assertions, by name, and the AC each covers.**

| AC | Assertion |
|---|---|
| AC-1 | `HARNESS-062 AC-1: a PASS for unit-slow does not satisfy a required unit` |
| AC-1 control | `HARNESS-062 AC-1: PASS unit followed by its timing satisfies a required unit` |
| AC-1 control | `HARNESS-062 AC-1: PASS unit ending the line satisfies a required unit` |
| AC-2 | `HARNESS-062 AC-2: an owner line naming no phase (owner: banana) is refused` |
| AC-2 control | `HARNESS-062 AC-2: the same section with Owner: GREEN is accepted as owned` |
| AC-3 | `HARNESS-062 AC-3: 'unwaived' is not a waiver, so the entry has no result and no waiver` |
| AC-3 | `HARNESS-062 AC-3: and the refusal is the whole 3h line` |
| AC-3 control | `HARNESS-062 AC-3: 'waived' in lower case mid-sentence is a waiver` |
| AC-3 control | `HARNESS-062 AC-3: 'Waived:' starting a line is a waiver` |
| AC-4 | `HARNESS-062 AC-4: at DONE, a PASS for unit-slow does not satisfy a required unit` |
| AC-4 | `HARNESS-062 AC-4: at DONE, a recorded PASS unit is reported as passing` |

**C-2, as built: a third optional argument, not a new helper.**
`story_on_branch [type] [extra-frontmatter-line] [phase]`, phase defaulting to
`REVIEW`. The frontmatter printf changed from a literal `phase: REVIEW` to
`phase: %s` fed `"$phase"`, so every call that passes no third argument writes
the same bytes as before. The only new callers passing it are the two AC-4
cases (`story_on_branch feature 'required_gates: [unit]' DONE`). Callers
checked against the tree by this agent: `git grep -l story_on_branch` returns
`.claude/tests/boundaries.test.sh` and prose in the HARNESS-003, -006, -037,
-054 and -062 story files only; in the suite, 31 mentions before this change
(comment, definition, and 29 calls - 4 with arguments, the `spike '...'` ones
at the old `:1397,:1407,:1422,:1432`), matching C-2. The full suite running
136/0 with the three-argument form is the evidence that none of them changed
behaviour.

**Export shape.** Not applicable in the module sense: the tests run
`scripts/check-boundaries.sh main` as a process and pin its output lines,
exactly:

- `frontmatter requires gate 'unit', but the recorded run has no PASS for it`
  (substring, with a non-zero exit)
- `ok    story-required gate 'unit' passed in the recorded run`
- `does not declare an owner` (substring, non-zero exit)
- `ok    ## Deferred verifications names the phase that owns each entry`
- `## Deferred verifications has no result and no waiver` (substring,
  non-zero exit) and the whole line `$WANT_3H`
- `ok    ## Deferred verifications carries an explicit waiver`

All of these strings exist unchanged in `check-boundaries.sh` today. Not
constrained: anything else the script prints, and its exit status on the
acceptance controls (the tree-hash rule refuses every pasted `## Gate results`,
so those runs exit 1 whatever 3e-i says).

**Mutation table** (each against the whole `boundaries` suite, 136 assertions
at the time, floor still 125; full output in `## Regressions`):

| Mutant | Expression (as sed received it - C-5's, verbatim) | Assertions red | k | Suite under mutant |
|---|---|---|---|---|
| B05 (AC-3) | `99s#(^\|\[^a-z\])waived(\[^a-z\]\|$)#waived#` | `HARNESS-062 AC-3: 'unwaived' is not a waiver, so the entry has no result and no waiver`; `HARNESS-062 AC-3: and the refusal is the whole 3h line` | 2 | 134 passed, 2 failed |
| B04 (AC-2) | `116s#(red\|green\|gates\|review\|done)#[a-z]*#` | `HARNESS-062 AC-2: an owner line naming no phase (owner: banana) is refused` | 1 | 135 passed, 1 failed |
| B07 (AC-4) | `459s#REVIEW\|DONE)#REVIEW)#` | `HARNESS-062 AC-4: at DONE, a PASS for unit-slow does not satisfy a required unit`; `HARNESS-062 AC-4: at DONE, a recorded PASS unit is reported as passing` | 2 | 134 passed, 2 failed |
| B08 (AC-1) | `462s#\$g( \|\\(\|\$)"#$g"#` | `HARNESS-062 AC-1: a PASS for unit-slow does not satisfy a required unit`; `HARNESS-062 AC-4: at DONE, a PASS for unit-slow does not satisfy a required unit` | 2 | 134 passed, 2 failed |

(`\|` in the table is markdown escaping for the pipe; the expressions are the
C-5 lines.) `bash scripts/mutate.sh --check` after the last run: `mutate: no
stranded mutation; nothing of a previous run is in the tree.`

**Cross-criterion catch, stated rather than hidden.** B08 also turns AC-4's
refusal red. That is the fixture working, not a leak: AC-4's DONE story carries
the same `unit-slow` record, so a prefix match satisfies it at DONE as it does
AC-1's at REVIEW. No other mutant touches another criterion, and no pre-existing
assertion went red under any of the four.

**For DV-1 (owner GATES).** The smallest predicted catch is now **B04, k=1**,
not B07 (k=2, because AC-4 gained a second, acceptance-side assertion). Re-run
whichever the orchestrator chooses; if the re-run is made through an agent's
Bash tool, B08 must be typed with `\\\\(` (C-5's note).

**Negative controls: expected values.** All mechanical, so each "value" is a
line present or absent, and all were measured in the clean run above (the
suite does not fail at import - every assertion executed, 136/0):

| Control | Expected | Measured (clean) | Under its criterion's mutant |
|---|---|---|---|
| AC-1 `PASS unit (12s)` | ok line printed | printed | still printed (B08 loosens) |
| AC-1 `PASS unit` at end of line | ok line printed | printed | still printed (B08 loosens) |
| AC-2 `Owner: GREEN` | ok owner line printed | printed | still printed (B04 loosens) |
| AC-3 `waived` mid-sentence | ok waiver line printed | printed | still printed (B05 loosens) |
| AC-3 `Waived:` at column 0 | ok waiver line printed | printed | still printed (B05 loosens) |

What these controls are NOT earned by: each audit mutant loosens a match, and
an acceptance control cannot go red under a looser match. They guard the other
direction - a change that over-tightens. Dropping the `|$` alternative at line
462 would turn the end-of-line control red; dropping `green` from line 116's
list would turn the Owner: GREEN control red; dropping `tolower` at line 99
would turn the `Waived:` control red. None of those tightening mutants was run; per `rules.md` "Mutation work per story" that is `/audit-mutations`
work, not this story's.

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

**Not a return to RED.** This story never left RED; the section carries the
probes that earn the eleven assertions written against a `check-boundaries.sh`
that was already correct, as `rules.md` requires of a test written while the
implementation exists. One mutant per criterion, each run through
`scripts/mutate.sh` against the whole `boundaries` suite (the one suite that
holds the assertions), one at a time, before the floor was raised (so the floor
line reads 125). Clean baseline on the same tree, after the eleven were added:
`boundaries: 136 passed, 0 failed`.

The trailing `Bnn rc=N` line in each block is the exit status, appended by the
wrapper that ran it; everything above it is mutate.sh's and selftest.sh's own
output, unedited.

### AC-3 - B05, line 99: `waived` matched as a substring

2 red, both AC-3's refusal case; the two AC-3 waiver controls stay green (B05
loosens, so the controls cannot be what it catches - see the handoff).

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 99s#(^|\[^a-z\])waived(\[^a-z\]|$)#waived#) ===
  99 -          exit (tolower(s) ~ /(^|[^a-z])waived([^a-z]|$)/) ? 0 : 1
  99 +          exit (tolower(s) ~ /waived/) ? 0 : 1

=== mutate: running bash scripts/selftest.sh boundaries ===

=== boundaries ===

  a return to RED has to show the red

  the story comes from GITHUB_HEAD_REF where CI sets it

  a PR is opened from REVIEW, as committed

  the same rule covers gate probes

  acceptance criteria are frozen

  criteria freeze at the last committed PLANNED state (HARNESS-033)

  a BLOCKED gate can reach REVIEW, but only with the decision written down

  a deferred verification is discharged or waived, never just filed
    FAIL HARNESS-062 AC-3: 'unwaived' is not a waiver, so the entry has no result and no waiver
         expected a refusal saying: ## Deferred verifications has no result and no waiver
         actual:                    ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in REVIEW
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         ok    ## Handoff is filled in
         ok    ## Deferred verifications names the phase that owns each entry
         ok    ## Deferred verifications carries an explicit waiver
    FAIL HARNESS-062 AC-3: and the refusal is the whole 3h line
         expected: 1
         actual:   0

  a harness change bumps the stamp

  RED may add a test dependency, and only a test dependency

  the story is found by what claims the branch, not by the branch's name

  a story is located by its filename, so the id inside must agree

  the handoff is the only channel to the next agent

  a gate the story escalated for itself appears in the record

  a spike that escalates a gate has to have run it

  machine-local state is never committed

  a section is not empty because it was too big to read

  the gate record is a stamp on a tree, not a sentence about one

  the local verdict and CI's verdict agree about an untracked file (HARNESS-014, AC-2)

  production code arrives with tests, or with an inventory

  a story that predates touches: is still accepted (HARNESS-006, AC-5 control)

boundaries: 134 passed, 2 failed

assertion floors: all 1 suite(s) met their declared floor (134 assertions executed, 125 declared).
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261017T210733Z.1832.bak) ===
  99:          exit (tolower(s) ~ /(^|[^a-z])waived([^a-z]|$)/) ? 0 : 1
B05 rc=1
```

### AC-2 - B04, line 116: the owner's phase list widened to `[a-z]*`

1 red, AC-2's refusal; its Owner: GREEN control stays green.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 116s#(red|green|gates|review|done)#[a-z]*#) ===
  116 -          exit (tolower(s) ~ /(^|[^a-z])owner[^a-z]*:?[^a-z]*(red|green|gates|review|done)([^a-z]|$)/) ? 0 : 1
  116 +          exit (tolower(s) ~ /(^|[^a-z])owner[^a-z]*:?[^a-z]*[a-z]*([^a-z]|$)/) ? 0 : 1

=== mutate: running bash scripts/selftest.sh boundaries ===

=== boundaries ===

  a return to RED has to show the red

  the story comes from GITHUB_HEAD_REF where CI sets it

  a PR is opened from REVIEW, as committed

  the same rule covers gate probes

  acceptance criteria are frozen

  criteria freeze at the last committed PLANNED state (HARNESS-033)

  a BLOCKED gate can reach REVIEW, but only with the decision written down

  a deferred verification is discharged or waived, never just filed
    FAIL HARNESS-062 AC-2: an owner line naming no phase (owner: banana) is refused
         expected a refusal saying: does not declare an owner
         actual:                    ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in REVIEW
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         ok    ## Handoff is filled in
         ok    ## Deferred verifications names the phase that owns each entry
         ok    ## Deferred verifications carries its result

  a harness change bumps the stamp

  RED may add a test dependency, and only a test dependency

  the story is found by what claims the branch, not by the branch's name

  a story is located by its filename, so the id inside must agree

  the handoff is the only channel to the next agent

  a gate the story escalated for itself appears in the record

  a spike that escalates a gate has to have run it

  machine-local state is never committed

  a section is not empty because it was too big to read

  the gate record is a stamp on a tree, not a sentence about one

  the local verdict and CI's verdict agree about an untracked file (HARNESS-014, AC-2)

  production code arrives with tests, or with an inventory

  a story that predates touches: is still accepted (HARNESS-006, AC-5 control)

boundaries: 135 passed, 1 failed

assertion floors: all 1 suite(s) met their declared floor (135 assertions executed, 125 declared).
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261017T211733Z.19317.bak) ===
  116:          exit (tolower(s) ~ /(^|[^a-z])owner[^a-z]*:?[^a-z]*(red|green|gates|review|done)([^a-z]|$)/) ? 0 : 1
B04 rc=1
```

### AC-4 - B07, line 459: the required-gates rule dropped at DONE

2 red, both AC-4's (the refusal and the acceptance at DONE: the rule does not
run, so neither its FAIL nor its ok line is printed).

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 459s#REVIEW|DONE)#REVIEW)#) ===
  459 -   REVIEW|DONE)
  459 +   REVIEW)

=== mutate: running bash scripts/selftest.sh boundaries ===

=== boundaries ===

  a return to RED has to show the red

  the story comes from GITHUB_HEAD_REF where CI sets it

  a PR is opened from REVIEW, as committed

  the same rule covers gate probes

  acceptance criteria are frozen

  criteria freeze at the last committed PLANNED state (HARNESS-033)

  a BLOCKED gate can reach REVIEW, but only with the decision written down

  a deferred verification is discharged or waived, never just filed

  a harness change bumps the stamp

  RED may add a test dependency, and only a test dependency

  the story is found by what claims the branch, not by the branch's name

  a story is located by its filename, so the id inside must agree

  the handoff is the only channel to the next agent

  a gate the story escalated for itself appears in the record
    FAIL HARNESS-062 AC-4: at DONE, a PASS for unit-slow does not satisfy a required unit
         expected a refusal saying: frontmatter requires gate 'unit', but the recorded run has no PASS for it
         actual:                    ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in DONE
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         ok    ## Handoff is filled in
    FAIL HARNESS-062 AC-4: at DONE, a recorded PASS unit is reported as passing
         expected to contain: ok    story-required gate 'unit' passed in the recorded run
         actual:               ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in DONE
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         ok    ## Handoff is filled in

  a spike that escalates a gate has to have run it

  machine-local state is never committed

  a section is not empty because it was too big to read

  the gate record is a stamp on a tree, not a sentence about one

  the local verdict and CI's verdict agree about an untracked file (HARNESS-014, AC-2)

  production code arrives with tests, or with an inventory

  a story that predates touches: is still accepted (HARNESS-006, AC-5 control)

boundaries: 134 passed, 2 failed

assertion floors: all 1 suite(s) met their declared floor (134 assertions executed, 125 declared).
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261017T212739Z.37236.bak) ===
  459:   REVIEW|DONE)
B07 rc=1
```

### AC-1 - B08, line 462: the gate id's terminator dropped

2 red: AC-1's refusal, and AC-4's refusal as well. That second one is not
noise: AC-4's DONE fixture uses the same `unit-slow` record, so under a prefix
match it is satisfied at DONE exactly as AC-1's is at REVIEW. The two AC-1
controls stay green (B08 loosens). The first attempt at this run was refused by
sed before anything ran, because the agent's Bash tool halves a doubled backslash (C-5's
note); the header below shows the expression sed received, and it is C-5's.

```
=== mutate: scripts/check-boundaries.sh (1 line(s) changed by 462s#\$g( |\\(|\$)"#$g"#) ===
  462 -       if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
  462 +       if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g" <<< "$gr"; then

=== mutate: running bash scripts/selftest.sh boundaries ===

=== boundaries ===

  a return to RED has to show the red

  the story comes from GITHUB_HEAD_REF where CI sets it

  a PR is opened from REVIEW, as committed

  the same rule covers gate probes

  acceptance criteria are frozen

  criteria freeze at the last committed PLANNED state (HARNESS-033)

  a BLOCKED gate can reach REVIEW, but only with the decision written down

  a deferred verification is discharged or waived, never just filed

  a harness change bumps the stamp

  RED may add a test dependency, and only a test dependency

  the story is found by what claims the branch, not by the branch's name

  a story is located by its filename, so the id inside must agree

  the handoff is the only channel to the next agent

  a gate the story escalated for itself appears in the record
    FAIL HARNESS-062 AC-1: a PASS for unit-slow does not satisfy a required unit
         expected a refusal saying: frontmatter requires gate 'unit', but the recorded run has no PASS for it
         actual:                    ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in REVIEW
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         ok    story-required gate 'unit' passed in the recorded run
         ok    ## Handoff is filled in
    FAIL HARNESS-062 AC-4: at DONE, a PASS for unit-slow does not satisfy a required unit
         expected a refusal saying: frontmatter requires gate 'unit', but the recorded run has no PASS for it
         actual:                    ok    story files validated
         ok    harness state not tracked
         ok    source changes accompanied by test changes (0 source, 0 test)
         ok    story T-1 is in DONE
         ok    branch matches the story's frontmatter
         ok    acceptance criteria unchanged since main
         FAIL  story T-1: ## Gate results was not written by scripts/gates.sh. Run 'bash scripts/gates.sh' - it records its own result; a pasted summary is not evidence.
         ok    story-required gate 'unit' passed in the recorded run
         ok    ## Handoff is filled in

  a spike that escalates a gate has to have run it

  machine-local state is never committed

  a section is not empty because it was too big to read

  the gate record is a stamp on a tree, not a sentence about one

  the local verdict and CI's verdict agree about an untracked file (HARNESS-014, AC-2)

  production code arrives with tests, or with an inventory

  a story that predates touches: is still accepted (HARNESS-006, AC-5 control)

boundaries: 134 passed, 2 failed

assertion floors: all 1 suite(s) met their declared floor (134 assertions executed, 125 declared).
1 of 1 harness suite(s) FAILED.

=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_check-boundaries.sh.20261017T213709Z.1857.bak) ===
  462:       if awk 'BEGIN{r=ARGV[1];ARGV[1]=""} $0~r{h=1} END{exit !h}' "^[[:space:]]*PASS[[:space:]]+$g( |\(|$)" <<< "$gr"; then
B08 rc=1
```

### After the last mutant

```
mutate: no stranded mutation; nothing of a previous run is in the tree.
check rc=0
```

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-17T22:27:02Z
    commit: 0288fec
    tree:   4b842be7af804d360fb4b150649a9561895c9d72
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

1. **PO decision (PLANNED, 2026-10-17).** `scripts/check-boundaries.sh` is
   not written by this story: the audit judged the four lines correct, and
   every criterion is earned by its mutant rather than by a red run. GREEN is
   therefore expected to be a no-op, and is verified by the orchestrator
   rather than dispatched (`## Model guidance`).
2. **The orchestrator's baseline run says nothing, and here is why.** A
   `bash scripts/selftest.sh boundaries` started on the clean tree at
   2026-10-17T20:43:49Z (before RED) ended with
   `assertion floors: 0 of 1 suite(s) met their declared floor. 1 of 1
   harness suite(s) FAILED.` - because RED raised the `boundaries` floor to
   136 in `floors.conf` while that run was still going, and the floor is read
   back at the end against the 125 the old tree executed. The per-suite output
   was not captured. The audit's `125 passed, 0 failed` on `d1db573` and RED's
   `136 passed, 0 failed` (handoff) stand; the GREEN re-run below is the
   orchestrator's own count.
3. **C-4 corrected by RED, accepted.** The floor-raise comments live in
   `.claude/tests/floors.conf` (HARNESS-054's at `:446-455`), not in
   `selftest.test.sh` as the Contract said; the COUNTS line at
   `selftest.test.sh:530` is the only change there.
4. **DV-1's target changes to B04.** RED's table shows AC-4 carrying two
   assertions under B07 (the refusal and the ok line at DONE), so the single-
   assertion catch is B04 (`owner: banana`, AC-2, 135/1). GATES runs B04.
5. **GREEN verified as a no-op by the orchestrator (2026-10-17).** On the RED
   commit `ee345c2`, with `git diff f2181f4 ee345c2 --stat -- scripts
   .claude/hooks` empty, `nohup bash scripts/selftest.sh boundaries`
   (started 22:00:38Z, finished 22:11:59Z, 11m21s, detached under the run
   lock):

    boundaries: 136 passed, 0 failed

    assertion floors: all 1 suite(s) met their declared floor (136 assertions executed, 136 declared).
    1 harness suite(s) passed.

   `bash scripts/gates.sh --fast` at the end of RED: `All required gates
   passed (0 ran, 5 unconfigured, 0 known)` - this repository configures no
   gates, so the self-test is the gate, as the Context says.
6. **Full self-test at GATES (orchestrator, 2026-10-17).** `nohup bash
   scripts/selftest.sh` on commit `03eb337`, detached under the run lock,
   alone in the tree, started 22:27:07Z and finished 23:49Z - **1h22m** on
   this Windows host (the previous record here was about 25 minutes; the
   `boundaries` and `phase-guard` suites took most of it and no orphaned
   run was present - the lock named one pid throughout). Every suite green;
   the exit status was not captured through `nohup ... &`, and the last two
   lines are the ones `selftest.sh` prints only on exit 0:

    boundaries: 136 passed, 0 failed
    ...
    worktree: 73 passed, 0 failed

    assertion floors: all 26 suite(s) met their declared floor (3625 assertions executed, 3399 declared).
    26 harness suite(s) passed.

   Log: `.claude/state/h062-selftest-full.log` (machine-local, not committed).

