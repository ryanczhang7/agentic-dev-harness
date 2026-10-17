---
id: HARNESS-060
title: The tree guards stay sighted past a quoted paren inside a quoted substitution
slug: the-tree-guards-stay-sighted-past-a-quot
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-060-the-tree-guards-stay-sighted-past-a-quot
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, scripts/check-grep-count.sh, .claude/tests/lib.test.sh, .claude/tests/grep-count.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(findings F2 and F3). It is the same class of defect as the release-40
here-string blindness in `rules.md`, "A rule is probed against the tree it
judges", and it was found the same way: by mutating a real line of the tree.
The required gate is the harness self-test (`grep-count`, `sigpipe` and `lib`
suites), and CI's `check-grep-count.sh` / `check-sigpipe.sh` steps.

**F2, the real-tree probe.** Line 1894 of `.claude/tests/gates.test.sh` was
mutated, via `mutate.sh`, into the exact defect `check-grep-count.sh` exists
to catch:

    h56_runs()    { grep -c '^ *run: ' "$T1" || printf 0; }

`bash scripts/check-grep-count.sh` reported `scanned 49 shell file(s), 0
finding(s)`. The same line in a one-line file is reported. Bisecting the masked
text (`masked_lines` from `lib.sh`) shows the masker's quote state flips at line
1812:

    assert_eq "AC-6: not the untracked-file one" 0 "$(count_re '^\(not recorded: .*untracked gated file' "$out")"

From there the masker treats code as quoted text, so `||` and `|` are masked
and neither guard sees an operator. Minimal reproduction, in an isolated copy of
the tree:

    x="$(f '(a')"
    y=$(grep -c x f || printf 0)      # check-grep-count: 0 findings

and with `set -o pipefail` and `if cmd | grep -q x; then :; fi` on line 2,
`check-sigpipe.sh` also reports 0 findings. What triggers it is an unbalanced `(`
inside a quoted word inside `"$( ... )"`: `x="$(f 'a)')"` and `x="$(f '(a)')"`
are seen; `x="$(f '(a')"`, `x="$(f "(a")"` and `x="$(f \()"` are not.
`check-grep-count.sh`'s `unwrap_quoted_subst` counts parentheses without regard
to quoting, which is one place the miscount happens; `check-sigpipe.sh` does not
use that helper and is blinded too, so the cause is not only there. RED should
pin the behaviour; where in the shared plumbing the fix belongs is GREEN's to
find.

**F3.** `check-grep-count.sh` misses a printing fallback on a backslash-
continued line, with no mutation applied:

    y=$(grep -c x f \
      || printf 0)                      # 0 findings

It folds continuation lines into one logical line (line 215), but `scan_line`
judges each raw line on its own, so the `||` on line 2 has no `grep -c` to its
left. The audit's mutant C07, which removes the folding, survives for that reason.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — Given a file whose line 1 is `x="$(f '(a')"` and whose line 2 is
  `y=$(grep -c x f || printf 0)`, when `check-grep-count.sh` scans it, then it
  reports line 2. The same holds for line 1 spelled `x="$(f "(a")"` and
  `x="$(f \()"`. Fails today (0 findings). *Negative control:* a file whose
  line 2 is `y=$(grep -c x f || true)` still reports nothing.
- **AC-2** — Given `set -o pipefail`, the same line 1, and line 3
  `if cmd | grep -q x; then :; fi`, when `check-sigpipe.sh` scans it, then it
  reports line 3. Fails today.
- **AC-3** — Given the real tree with `.claude/tests/gates.test.sh:1894`
  mutated (through `mutate.sh`) into `{ grep -c '^ *run: ' "$T1" || printf 0; }`,
  when `check-grep-count.sh` runs over the tree, then it reports
  `.claude/tests/gates.test.sh:1894`. Recorded in `## Gate probes` as a
  real-tree probe. Fails today.
- **AC-4** — Given `y=$(grep -c x f \` followed by `  || printf 0)`, when
  `check-grep-count.sh` scans it, then it reports the logical line (line 1).
  Fails today. *Negative control:* the same with `|| true` reports nothing.
- **AC-5** — The quoting fix does not unmask real quoted data: a quoted `||` or
  `|` in prose (`echo "a || printf 0"`) after any of the AC-1 lines is still
  not reported by either guard.

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

**Writes:** `.claude/hooks/lib.sh`, `scripts/check-grep-count.sh`, `.claude/tests/lib.test.sh`, `.claude/tests/grep-count.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

RED may amend any block below in place, with a reason; GREEN builds what the
amended block says. Anchors read off the tree at `4b07ac2` (main after
HARNESS-059), 2026-10-16. A named mechanism here is checkable, not sacred.

**C-1. The cause, located (Lead PO, by reading `mask_shell_quotes`).**
`.claude/hooks/lib.sh:111-247` is the masker. Inside a double-quoted string a
`$(` moves it to `state = "subst"` with `depth = 1` (`:181-183`), and in that
state the only characters it interprets are `(` (depth++) and `)` (depth--,
back to `double` at zero); every other character, a quote included, is masked
(`:187-193`). So `x="$(f '(a')"` reaches depth 2 inside the single quotes,
comes back to 1 at the real `)`, and never returns to `double`, let alone
`none`: from there to the end of the file every operator is masked and both
guards see prose. That is why `x="$(f 'a)')"` and `x="$(f '(a)')"` are seen
(the counts happen to balance) and `x="$(f '(a')"`, `x="$(f "(a")"` and
`x="$(f \()"` are not. It is one state machine in one place, so the fix is one
place too: `mask_shell_quotes` (GREEN, `lib.sh`), with no second parser.

**C-2. The fix (GREEN, `lib.sh`, `state == "subst"` branch).** While in
`subst`, the masker tracks the inner quoting before it counts a paren:
a `'` opens a span in which nothing counts until the next `'`; a `"` opens a
span in which nothing counts until the next unescaped `"`, with `\"`, `\\`,
`\$` and `` \` `` consumed as pairs as the `double` state already does
(`:170-176`); a `\` outside those spans consumes the next character; a nested
`$(` is already a `(` and still counts. Every character inside the
substitution stays MASKED as today, spans included: lib.sh's trap 2 ("`"$(
... )"` is blanked wholesale") is deliberate for the phase lock, and this story
changes only where the substitution ENDS, never what is visible inside it. The
output for every input the current `lib.test.sh` masks must be byte-identical
(RED pins that with a round-trip, below). A `#` inside the substitution is not
a comment and is not treated as one.

**C-3. `unwrap_quoted_subst` (GREEN, `scripts/check-grep-count.sh:277-295`)**
counts parens the same way, ignoring quotes, so a `"$(f '(a')"` is never
unwrapped. It gets the same rule as C-2: a `'`-span, a `"`-span with the
escape pairs, and `\` outside them are stepped over while looking for the
matching `)`. Two copies of one rule is what `rules.md` forbids, so GREEN
prefers moving the paren-matching into one awk function in `lib.sh` that both
`mask_shell_quotes` and this helper call (`lib.sh` is sourced by the guard
already: `CLAUDE_PROJECT_DIR` is set for it at `:90`). If GREEN keeps two
copies it says why in `## Notes`.

**C-4. Continuation lines (GREEN, `check-grep-count.sh:201-221`).** The END
block folds a backslash-continued group into `grp` (`:215`) but then calls
`scan_line(raw[k])` per physical line (`:220`), so a `||` on the second line
has no `grep -c` to its left. GREEN scans the folded group as one line: the
text `raw[start]..raw[last]` joined with the trailing `\` and newline of each
line replaced by a single space, passed once to `scan_line`, and a hit
reported at `start` (the logical line, as AC-4 says). `D` is still reset per
group. A continuation INSIDE a quoted string (`"a \` / `b"`) is masked by the
masker before this code runs and is unaffected.

**C-5. What RED pins, by file.**
- `.claude/tests/lib.test.sh`, in the `mask_shell_quotes` describes
  (`:108-250`): for each of the three AC-1 openers, masking
  `x="$(f '(a')"` NEWLINE `y=a || b` leaves the second line's `||` unmasked
  (and `echo "a || b"` after it masked, AC-5); and a round trip
  (`mask | unmask`) of every existing fixture in those describes is unchanged.
  The spans inside the substitution stay masked (trap 2).
- `.claude/tests/grep-count.test.sh`, a new describe before `summary`
  (`:288`): AC-1's three files (finding at line 2), its `|| true` control,
  AC-4's continuation file (finding at line 1) and its control, AC-5's prose
  line. Fixtures go under the fixture project's `scripts/`, as the existing
  describes do (`:128-220`), never under the real tree.
- `.claude/tests/sigpipe.test.sh`, a new describe before `summary` (`:1247`),
  on a `make_project_fixture` like C-11's (`:639`): AC-2's file, reported at
  line 3, with the `echo "a || printf 0"` prose line not reported.
- AC-3 is a real-tree probe and is owned by GATES (DV-1 below); RED writes no
  test that mutates the real tree. The existing AC-4 block of
  `grep-count.test.sh` (`:265`) already asserts the real tree is clean, and
  stays.

**C-6. Floors.** `grep-count` 20 (`floors.conf:45`), `sigpipe` 82 (`:61`),
`lib` 283 (`:46`), mirrored in `selftest.test.sh` (`:536`, `:553`, `:537`),
raised to the executed counts RED measures, with the measurement recorded at
the foot of `floors.conf`.

**Oracle partition.** Every criterion is mechanical: which line a guard
reports, or none, on a named fixture. No invented metric. Negative controls are
in the criteria (`|| true`, the prose line) and C-5's round trip.

**Callers of changed signatures.** No signature changes. `mask_shell_quotes`
is read from stdin by `masked_lines` (`lib.sh:316-317`, both guards),
`phase-guard.sh:145` (the lock's command parsing) and `lib.test.sh:110`,
`:111`, `:601`, `:684`. `unmask_shell_quotes` at `lib.sh:1029` and
`phase-guard.sh:211`. `unwrap_quoted_subst` only at `check-grep-count.sh:300`.
All checked with `git grep` on 2026-10-16. The lock is a consumer of C-2:
after a `"$(f '(a')"` it will now SEE the rest of a command where it used to
see prose, which is the direction the lock wants (an unmasked redirect is
judged; a masked one failed open). `phase-guard.test.sh` (378) and
`worktree.test.sh` (73) judge that at the GATES self-test.

**Required gate.** The harness self-test (`lib`, `grep-count`, `sigpipe`
suites) in CI's `selftest` job, and CI's `check-grep-count.sh` /
`check-sigpipe.sh` steps. No `gates.sh` gate is configured for this
repository.

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

- **DV-1, AC-3: the rule probed against the tree it judges.** With
  `.claude/tests/gates.test.sh:1894` mutated into
  `h56_runs()    { grep -c '^ *run: ' "$T1" || printf 0; }`,
  `bash scripts/check-grep-count.sh` MUST report
  `.claude/tests/gates.test.sh:1894` and exit 1; and with the file restored,
  MUST report 0 findings. Run via
  `bash scripts/mutate.sh .claude/tests/gates.test.sh '1894s#"$T1"; }#"$T1" || printf 0; }#' -- bash scripts/check-grep-count.sh`.
  Owner: GATES (the fix is not built in RED; the audit measured 0 findings on
  this exact probe). The result is also the story's `## Gate probes` entry.
- **DV-2, the defect put back.** With C-2's quote tracking removed from the
  `subst` state of `mask_shell_quotes` (the mutation GREEN names in
  `## Notes`, one `mutate.sh` expression on `.claude/hooks/lib.sh`), AC-1's
  and AC-2's assertions MUST fail, in `grep-count.test.sh` and
  `sigpipe.test.sh` respectively, and nothing else in those suites. Owner:
  GATES.

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

Planned by `bash scripts/plan.sh write HARNESS-060` from `.claude/harness/models.conf`.
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

- A full shell parser. The guards stay awk over masked text; this story makes
  the masking right for the shapes above and the shapes the tree uses.
- Backticks, which the guards deliberately do not treat as substitution.

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

