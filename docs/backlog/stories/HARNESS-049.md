---
id: HARNESS-049
title: The refresh names new files a project's linter will read
slug: the-refresh-names-new-files-a-project-s
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-049-the-refresh-names-new-files-a-project-s
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/refresh-harness.sh, .claude/tests/refresh.test.sh]       # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Found refreshing fantasy-world-builder from release 64 to 88 (2026-10-08).
The refresh brought in HARNESS-043's `.claude/skills/security-audit/`: two
`.cjs` validators, their two `.test.cjs` suites and `report-schema.json`. The
project's `biome.json` included `"**"`, so its required `lint` gate failed on
them, and so did `unit` and `coverage` through a guard requiring biome to
print no warnings. `format` warned on all five. It went red on `main` (CI run
ryanczhang7/fantasy-world-builder 37870684583) and was fixed there by adding
`"!.claude"` to `biome.json` (d91351f):

    FAIL         lint (2s, exit 1)
    FAIL         unit (190s, exit 1)
    FAIL         coverage (277s, exit 1)
    .claude\skills\security-audit\validate-findings.cjs:11:20 lint/style/useNodejsImportProtocol  FIXABLE
    .claude\skills\security-audit\validate-coverage-ledger.cjs:258:11 lint/complexity/useOptionalChain  FIXABLE

Nothing in the refresh's report pointed at it: it prints `REPLACED
.claude/skills/` for the whole directory, so five NEW files of a kind a
JavaScript or JSON tool reads arrive under a line that reads as "the same as
before". Its last block does say to run `bash scripts/gates.sh` afterwards;
that was skipped, and the harness self-test (which was run) cannot see a
project's own linter. The cheapest point to catch it is the report itself,
in the dry run, before anything is written.

**The gate that fails if this breaks** is the harness's own `selftest` (the
`refresh` suite), which CI runs on every PR.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1 (a new lintable file is named, dry run and real run)** — Given a
  consumer whose `.claude/skills/` lacks a directory that upstream ships, and
  that directory holds a `.cjs` file and a `.json` file, when
  `refresh-harness.sh --dry-run` runs, then the report has one `NEW` line per
  such file naming its path, and a note that the project's own linters and
  formatters will read them unless it excludes `.claude`; the same lines
  appear in a real run.
- **AC-2 (an unchanged or non-code file is not named)** — Given the same
  consumer where the upstream file already exists at the same path, or where
  the new file is `.md` or `.sh`, when the refresh runs, then no `NEW` line
  names it. *Control:* a refresh between two identical trees prints no `NEW`
  line and no note at all.
- **AC-3 (the extension set is written once)** — Given the refresh script,
  when read, then the extensions it treats as read by a project's tools are
  defined in one place, and include at least `.js`, `.cjs`, `.mjs`, `.ts`,
  `.tsx`, `.json`, `.jsonc` and `.py`.

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

**Writes:** `scripts/refresh-harness.sh`, `.claude/tests/refresh.test.sh`

- "New" means: present in the upstream tree under a directory the refresh
  REPLACES (`.claude/{agents,commands,skills,hooks,tests}`, `scripts/`), and
  absent from the consumer's tree before the refresh. Compared by path, before
  any copy, so the dry run can say it.
- Output: after the REPLACED lines, `  NEW       <path>  (a <ext> file your
  linters and formatters will read - exclude .claude if they should not)`,
  one per file, then nothing else. Exact wording is RED's to pin.
- Not a refusal and not a nonzero exit: the refresh still completes. The
  harness cannot know which tools a consumer runs; it can only name the files.
- Portability: bash 3.2, awk and coreutils only (rules.md), no python.
- `sigpipe` pins line numbers in some scripts; check whether it pins any in
  `refresh-harness.sh` before GREEN adds lines (memory: full selftest before
  REVIEW).

**Pinned by the Lead PO before RED (2026-10-09).** RED may amend any block
below in place, with a reason beside it; GREEN builds what the amended block
says.

- **Where the comparison lives.** `scripts/refresh-harness.sh`, between the
  LOCAL block (ends line 336) and the `rm -rf`/`cp -r` loop (line 379). It
  walks `find . -type f` under each `$UP/.claude/$d` for `d in agents commands
  skills hooks tests`, and `$UP/scripts/*.sh` is excluded by AC-2 (`.sh` is
  not a lintable extension) — so the walk may skip `scripts/` entirely, or
  include it and let the extension filter drop it; RED's choice, say which.
  "Absent from the consumer" is `[ ! -e "$PROJ/.claude/$d/$rel" ]`, judged
  BEFORE the copy loop runs, so the dry run and the real run print the same
  lines (AC-1).
- **The extension set, once (AC-3).** One variable, at column 0, near the
  comparison:
  `LINTABLE_EXT="js cjs mjs ts tsx json jsonc py"` — a space-separated list,
  matched by `case "$rel" in *.js|*.cjs|...)` built from it, or by a `case`
  whose single pattern list IS the one place. The test for AC-3 reads the
  script with `grep`: pin that the eight names each appear on one line that
  also carries the variable name, and that no second assignment to that name
  exists. Exact spelling of the variable name is RED's to pin.
- **Output shape.** After the `REPLACED  .claude/<d>/` lines (line 397) and
  before the single-file `REPLACED` lines (line 400), one line per new file:

      ·· NEW       .claude/skills/security-audit/validate-findings.cjs  (a .cjs file your linters and formatters will read)

  (`··` = two spaces, column alignment with `KEPT      ` / `REPLACED  `; the
  word `NEW` is followed by seven spaces so the path starts in the same
  column). Then, once, after the last NEW line, the note:

      ··          Your project's own linters, formatters and test runners read
      ··          these unless they exclude .claude. If they should not, exclude it.

  Then an empty line. RED pins the exact wording; GREEN prints it verbatim.
  Zero new files: no NEW line and no note (AC-2 control).
- **Ordering.** NEW lines come out in `find` order; RED must not assert an
  order between two NEW lines (Git Bash `find` and Linux `find` differ).
- **Exit status and side effects.** Unchanged: exit 0 on both runs, nothing
  written in a dry run (the existing AC-4 fingerprint assertion stays green).
- **Oracle partition.** All three ACs are mechanical: exact lines in `$out`,
  counted with the suite's existing `whole_line_count` / `exact_count`
  helpers (here-doc, never a pipe — `check-sigpipe.sh` and
  `check-grep-count.sh` judge the test file too). No invented metric, no
  threshold.
- **Portability.** No new `"$(cmd | head …)"` substitution and no `grep -c …
  || printf 0`: `check-sigpipe.sh` pins four lines in this script (134, 135,
  147, 148, in `.claude/tests/sigpipe.test.sh` `DISCARDED`), so GREEN inserts
  **only below line 148** and adds no new pipefail SIGPIPE shape. A new
  pinned line would need that suite's table edited too.
- **Floors.** `.claude/tests/floors.conf` line 55 (`floor | refresh | 165`)
  and the hand-copied table at `.claude/tests/selftest.test.sh:546`
  (`refresh 165`) both carry the refresh suite's floor. RED raises BOTH to
  the EXECUTED count of its run (not the passing count), in its own commit,
  with the measurement comment the file's precedent shows (HARNESS-040's
  block there). Every file in this repository classifies `harness`, so the
  lock permits all of it; the role boundary is honoured by RED touching
  only the test file and the two floor tables, never the script.
- **Changed signatures.** None: no function in `refresh-harness.sh` changes
  its interface, and no other script or suite calls into it except
  `refresh.test.sh` and `security-audit.test.sh` (AC-4 there runs a real
  refresh and greps for `security-audit` paths — the NEW lines will name
  `.cjs`/`.json` files under it, which can only ADD matches; RED checks that
  suite's needles are anchored lines, not substrings that a NEW line would
  satisfy or break).
- **Test fixture.** The suite's `UP` already ships `.claude/skills/stack-
  profiles/reference/python-uv.md` and `.claude/tests/lib.test.sh`; add a
  `.cjs` and a `.json` under a NEW skill directory, plus a `.md` and a `.sh`
  there as AC-2's non-code controls, and one `.cjs` present in BOTH trees as
  AC-2's unchanged control. They must be committed into the fixture
  repository (`git add -A && commit`) or the LOCAL walk sees nothing
  different — but LOCAL judges the consumer's files, and these are absent
  from the consumer, so no LOCAL line appears; assert that too.

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

- **DV-1 (defect put back)** — With the NEW-file comparison made to return
  nothing (through `scripts/mutate.sh`), AC-1's assertions MUST go red in the
  `refresh` suite and AC-2's control stays green. Owner: GATES

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

Planned by `bash scripts/plan.sh write HARNESS-049` from `.claude/harness/models.conf`.
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

- Changing what upstream ships, or shipping a `.biomeignore`/`.eslintignore`:
  the consumer's tool config is the consumer's.
- Running the consumer's gates from the refresh.

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

