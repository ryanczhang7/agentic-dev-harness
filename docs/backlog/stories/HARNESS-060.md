---
id: HARNESS-060
title: The tree guards stay sighted past a quoted paren inside a quoted substitution
slug: the-tree-guards-stay-sighted-past-a-quot
epic: 
type: fix
status: in-progress
phase: RED
branch: story/HARNESS-060-the-tree-guards-stay-sighted-past-a-quot
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/hooks/lib.sh, scripts/check-grep-count.sh, .claude/tests/lib.test.sh, .claude/tests/grep-count.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/gates.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
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

**Writes:** `.claude/hooks/lib.sh`, `scripts/check-grep-count.sh`, `.claude/tests/lib.test.sh`, `.claude/tests/grep-count.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

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

*Amended in RED (test-developer, 2026-10-16), reason: measured.* **A heredoc
opened inside the substitution is a body, not code.** Both tree guards hold
their rule in exactly that shape - `AWK_RULE="$(cat <<'AWKEOF'` ...
`AWKEOF` / `)"` (`check-sigpipe.sh:102-289`, `check-grep-count.sh:97`) - and
the awk program in the body is full of unpaired `'`, `"` and parens. A
scratch candidate that implemented only the quote rule above (no heredoc rule)
passed every AC pin but read the body's quotes as spans, so its state after
`AWKEOF` depends on the body's quote parity: it changed the masking of
`check-sigpipe.sh` from line 183 and of `lib.sh` from line 1062. So, in
`subst`: a `<<WORD` / `<<-WORD` / `<<'WORD'` / `<<"WORD"` opener (not `<<<`)
makes the following lines body, masked as heredoc bodies are today and with
nothing counted, until the delimiter line; then the substitution resumes and
its `)` ends it. Pinned in `lib.test.sh` (the "after a heredoc inside a quoted
substitution" pair). The quote-only candidate fails that pin, so a GREEN that
builds only the paragraph above is not finished.

**C-3. `unwrap_quoted_subst` (GREEN, `scripts/check-grep-count.sh:277-295`)**
counts parens the same way, ignoring quotes, so a `"$(f '(a')"` is never
unwrapped. It gets the same rule as C-2: a `'`-span, a `"`-span with the
escape pairs, and `\` outside them are stepped over while looking for the
matching `)`. Two copies of one rule is what `rules.md` forbids, so GREEN
prefers moving the paren-matching into one awk function in `lib.sh` that both
`mask_shell_quotes` and this helper call (`lib.sh` is sourced by the guard
already: `CLAUDE_PROJECT_DIR` is set for it at `:90`). If GREEN keeps two
copies it says why in `## Notes`.

*Amended in RED (test-developer, 2026-10-16), reason: measured, and it bears
on DV-2.* With a quote-aware unwrap in `check-grep-count.sh` as a SEPARATE
copy and `lib.sh` at `4b07ac2` (no C-2 at all), `grep-count.test.sh` ran
`38 passed, 0 failed`: the unwrap strips the outer quotes of `x="$(f '(a')"`,
the masker then sees a bare `$( ... )` whose quotes it already tracks, and
AC-1 and AC-5 pass without C-2. So DV-2's grep-count half ("AC-1's assertions
MUST fail in grep-count.test.sh") holds only if the paren matching is ONE
function both callers use. Two copies make DV-2 vacuous for grep-count; then
DV-2 has to remove the rule from both, and `sigpipe.test.sh` (which does not
unwrap) is the suite that discriminates C-2 alone. C-3 is pinned by
`grep-count.test.sh` "HARNESS-060 C-3" (a printing fallback inside
`"$(grep -c '(a' f || printf 0)"`), which C-2 alone does not satisfy (measured:
`actual: 1`, expected `1 2`).

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

*Amended in RED (test-developer, 2026-10-16), reason: a round trip cannot pin
byte identity.* `mask | unmask` is the identity whatever was masked, so it
cannot see C-2 changing what is masked. The byte-identity promise is pinned
instead as a GOLDEN: the masked text (rendered with `cat -v`, newlines as
`<NL>`) of each of the 23 inputs the mask describes feed the masker, as
`4b07ac2` produces it. The three openers' round trips are kept as well. Added
beyond the block above: the exact masked text of each opener and the two lines
after it (C-2 in one comparison), the heredoc-in-substitution pair (C-2
amendment), C-3's quoted-paren unwrap in `grep-count.test.sh`, and in
`sigpipe.test.sh` AC-5's prose sits in one-line function bodies, because a
top-level `echo "... | head -1"` has its status discarded and is silent even
unmasked (measured).

*Amended in RED (test-developer, 2026-10-16), reason: found.* **The fix makes
nine real findings visible in `.claude/tests/gates.test.sh`**, at
2114, 2905, 2912, 2943, 2948, 2951, 2985, 3013 and 3080. All are
`printf ... | grep -q/-m1` pipelines under pipefail that today's masker hides
(its state flips at `gates.test.sh:809`, a `"$(count_re '^\(not recorded: ...`
line). With a scratch C-2 candidate, `check-sigpipe.sh` over the tree reports
`scanned 49 shell file(s), 45 with pipefail, 9 finding(s)` and
`sigpipe.test.sh` "C-3: and the real tree has no findings at all" goes red
(`expected: 0, actual: 9`). That file is in neither `touches:` nor
`**Writes:**`, and it is a test file. **Escalated to the orchestrator; not
resolved in RED.**

**C-6. Floors.** `grep-count` 20 (`floors.conf:45`), `sigpipe` 82 (`:61`),
`lib` 283 (`:46`), mirrored in `selftest.test.sh` (`:536`, `:553`, `:537`),
raised to the executed counts RED measures, with the measurement recorded at
the foot of `floors.conf`.

*Amended in RED (test-developer, 2026-10-16), reason: a third mirror.*
`selftest.test.sh:566-567` also names lib's floor ("lib is floored at its N
executed assertions") and failed `expected: 283, actual: 322` until raised.
Raised: `grep-count` 20 -> 38, `lib` 283 -> 324, `sigpipe` 82 -> 89, at
`floors.conf:45/:46/:61` and `selftest.test.sh:536/:537/:553/:566-567`.

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

**C-7. PO decision 1 (2026-10-16, approved by the user): the defects the fix
unhides are fixed here, in RED.** RED's candidate masker, measured in a scratch
clone, made `check-sigpipe.sh` report 9 real findings in
`.claude/tests/gates.test.sh` (lines 2114, 2905, 2912, 2943, 2948, 2951, 2985,
3013, 3080 at `4b07ac2`), all `printf '%s\n' "$x" | grep -q/-Fxq/-m1 ...` under
the pipefail `_lib.sh` sets (`_lib.sh:14`). They were hidden because the masker
flips at `gates.test.sh:809`. With them, `sigpipe.test.sh`'s "C-3: and the
real tree has no findings at all" fails and GREEN cannot reach green. The
orchestrator reproduced the shape independently: those nine lines, extracted
into a fixture with `set -uo pipefail` and judged by the CURRENT guard (no
masker change), are reported.

The options were rewriting them or marking each `# sigpipe-ok:`. The user
chose the rewrite, in this story. Each pipeline becomes a here-string
(`grep ... <<<"$x"`), and `3013`'s `printf | tr | grep` becomes
`grep -Fxq b <<<"$(tr ... <<<"$note_line")"`. That is the idiom the tree
already uses, as `grep-count.test.sh:275` does. The rewrite was made in RED,
because `gates.test.sh` is a test file, and it is behaviour-preserving:
`printf '%s\n' "$x"` and `<<<"$x"` feed the same bytes. It is earned by the
`gates` suite staying 682/0 and by one probe recorded in `## Regressions`.
`gates.test.sh` joins `touches:` and `**Writes:**`, and HARNESS-064, which
also writes `gates.test.sh`, now `depends_on` this story.

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

- PLANNED: `lead-po` orchestrator session, Fable 5.1 (`claude-fable-5-1`).
- RED: `test-developer`, dispatched with `model: opus`; it reported Opus 5.5 (`claude-opus-5-5`). The C-7 rewrite of nine `gates.test.sh` lines was made by the orchestrator session itself, then on Opus 5.5.

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

Every criterion is mechanical (which line a guard reports, or none, on a named
fixture), so every pin is an exact line list, an exact census line, or exact
masked text. Two levels:

- **Unit, the masker** (`.claude/tests/lib.test.sh`, describe "HARNESS-060: a
  quoted paren inside a quoted substitution does not hide the next line",
  after the comment describe). Where the cause lives (C-1). Each of the three
  openers `x="$(f '(a')"`, `x="$(f "(a")"`, `x="$(f \()"` followed by
  `y=a || b` and `echo "a || b"`.
- **Integration, each guard end to end** on a `make_project_fixture` with
  files under the fixture's `scripts/`, never the real tree:
  `.claude/tests/grep-count.test.sh` and `.claude/tests/sigpipe.test.sh`, one
  new describe each, before `summary`.
- **AC-3 is not tested in RED.** It is a real-tree probe, owned by GATES as
  DV-1; no test here mutates the real tree.

| AC | Where | What would break it |
|---|---|---|
| AC-1 | grep-count: a1_{SQ,DQ,BS}.sh -> `2`, census `scanned 3 shell file(s), 3 finding(s)`, exit 1; lib: line 2 is `y=a \|\| b` | the masker staying in the substitution |
| AC-1 control | grep-count: c1_* (`\|\| true`, exactly the AC's two lines) -> none; s1_* (same plus a printing fallback on line 3) -> `3` | a fix that flags `\|\| true`; s1 stops c1 being satisfied by blindness |
| AC-2 | sigpipe: h60_{SQ,DQ,BS}.sh -> `3`, census `scanned 3 shell file(s), 3 with pipefail, 3 finding(s)` | the same, in the guard that does not unwrap |
| AC-4 | grep-count: k4.sh -> `1`; controls n4.sh -> none, m4.sh -> `3` | judging physical lines instead of the folded logical line |
| AC-5 | grep-count p5_*: prose on 2-4 silent, positive on 5 -> `5`; sigpipe q60_*: prose on 3-5 silent, positive on 6 -> `6`; lib: line 3 masks to `echo "a^F^A^A^Fb"` | a fix that unmasks quoted text |
| C-2 | lib: exact mask of each opener + two lines; heredoc-in-substitution pair; trap-2 interior x3; golden of 23 existing fixtures + census | the substitution ending in the wrong place, its interior unmasked, or any old input masked differently |
| C-3 | grep-count u3.sh -> `1 2` | the unwrap still counting a quoted paren |
| AC-3 | DV-1, GATES | - |

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

Written by the test-developer, RED, 2026-10-16, resolved model Opus 5.5
(`claude-opus-5-5`), no override.

**STOP FIRST: one open escalation.** Once the masker is fixed, nine real
findings in `.claude/tests/gates.test.sh` become visible to
`check-sigpipe.sh` (Contract C-5 amendment lists them), and `sigpipe.test.sh`
"C-3: and the real tree has no findings at all" goes red with `actual: 9`.
That file is a test file outside `touches:`; RED was told not to touch it.
The orchestrator has to decide who fixes those nine lines, and in which phase,
before GREEN can reach green.

**Commands** (from the worktree root):

    bash .claude/tests/lib.test.sh          # ~1 min
    bash .claude/tests/grep-count.test.sh   # ~1 min
    bash .claude/tests/sigpipe.test.sh      # ~2.5 min
    bash .claude/tests/selftest.test.sh     # the floors mirror, green now

**Failure output, verbatim** (lib.sh and scripts/*.sh untouched):

```
    FAIL HARNESS-060 AC-1: after x="$(f '(a')" the next line's || is syntax again
         expected: y=a || b
         actual:   
    FAIL HARNESS-060 AC-5: after x="$(f '(a')" a quoted || on a later line is still masked
         expected: echo "a^F^A^A^Fb"
         actual:   
    FAIL HARNESS-060 AC-1: after x="$(f "(a")" the next line's || is syntax again
         expected: y=a || b
         actual:   
    FAIL HARNESS-060 AC-5: after x="$(f "(a")" a quoted || on a later line is still masked
         expected: echo "a^F^A^A^Fb"
         actual:   
    FAIL HARNESS-060 AC-1: after x="$(f \()" the next line's || is syntax again
         expected: y=a || b
         actual:   
    FAIL HARNESS-060 AC-5: after x="$(f \()" a quoted || on a later line is still masked
         expected: echo "a^F^A^A^Fb"
         actual:   
    FAIL HARNESS-060 C-2: the exact mask of the single-quote opener and the lines after it
         expected: x="$(f^F'^Na')"<NL>y=a || b<NL>echo "a^F^A^A^Fb"
         actual:   x="$(f^F'^Na'^O"^Hy=a^F^A^A^Fb^Hecho^F"a^F^A^A^Fb"
    FAIL HARNESS-060 C-2: the exact mask of the double-quote opener and the lines after it
         expected: x="$(f^F"^Na")"<NL>y=a || b<NL>echo "a^F^A^A^Fb"
         actual:   x="$(f^F"^Na"^O"^Hy=a^F^A^A^Fb^Hecho^F"a^F^A^A^Fb"
    FAIL HARNESS-060 C-2: the exact mask of the backslash opener and the lines after it
         expected: x="$(f^F\^N)"<NL>y=a || b<NL>echo "a^F^A^A^Fb"
         actual:   x="$(f^F\^N^O"^Hy=a^F^A^A^Fb^Hecho^F"a^F^A^A^Fb"
    FAIL HARNESS-060 C-2: after a heredoc inside a quoted substitution, the next line's || is syntax again
         expected: y=a || b
         actual:   
lib: 314 passed, 10 failed

    FAIL HARNESS-060 AC-1: after the SQ opener, a printing fallback on line 2 is reported
         expected: 2
         actual:   
    FAIL HARNESS-060 AC-1 control: after the SQ opener, || true is silent and the printing fallback below it is not
         expected: 3
         actual:   
    FAIL HARNESS-060 AC-5: after the SQ opener, quoted || prose is not reported and the real fallback after it is
         expected: 5
         actual:   
    (the same three for DQ and BS)
    FAIL HARNESS-060 AC-1: the census names three files and three findings
         expected: 1
         actual:   0
    FAIL HARNESS-060 AC-1: and the guard exits non-zero on them
         expected: 1
         actual:   0
    FAIL HARNESS-060 C-3: a printing fallback inside a quoted substitution is reported even when its pattern holds a quoted paren
         expected: 1 2
         actual:   1
    FAIL HARNESS-060 AC-4: a printing fallback on a continuation line is reported at the logical line
         expected: 1
         actual:   
grep-count: 25 passed, 13 failed

    FAIL HARNESS-060 AC-2: after the SQ opener, a pipeline into grep -q under pipefail on line 3 is reported
         expected: 3
         actual:   
    FAIL HARNESS-060 AC-5: after the SQ opener, quoted pipelines are not reported and the real one after them is
         expected: 6
         actual:   
    (the same two for DQ and BS)
    FAIL HARNESS-060 AC-2: the census is exact - three files, three with pipefail, three findings
         expected: 1
         actual:   0
sigpipe: 82 passed, 7 failed
```

**Why this is the right failure.** Every red line is the guard reporting
nothing (`actual:` empty, census 0) or the masker emitting one
`\010`-folded record where three lines should be: the operators past the
opener are masked. No fixture error, no syntax error, no missing file:
the unchanged assertions in all three suites still pass (`lib` 283 of 283
old, `grep-count` 20 of 20, `sigpipe` 82 of 82). C-3's `actual: 1` is line 1
(a balanced pattern) reported and line 2 (the quoted paren) not, so the miss
is the paren and nothing else.

**One line per test.** `lib.test.sh` (describe after "a comment is data"):
- AC-1 x3 - after each opener, line 2 of the mask is exactly `y=a || b`.
- AC-5 x3 - line 3, `echo "a || b"`, masks to exactly `echo "a^F^A^A^Fb"` (cat -v).
- trap 2 x3 - the first record past `x="$(` holds no visible space, `(` or operator. Passes on arrival.
- round trip x3 - mask | unmask of the three lines is the input. Passes on arrival.
- C-2 exact mask x3 - the whole cat -v rendering, interior masked as today, `)"` unmasked, real newlines.
- C-2 heredoc pair - after `X="$(cat <<'EOF'` / `it's (a || b` / `EOF` / `)"`, line 2 is `y=a || b` (red); the body's `||` is still masked (passes on arrival).
- C-2 golden x23 + census - the cat -v mask of every input the mask describes feed the masker equals `4b07ac2`'s. Pass on arrival.

`grep-count.test.sh` (describe before `summary`, fixture `$G60`):
- AC-1 x3 - `scripts/h60/a1_<o>.sh`, the AC's two lines, reported at `2`.
- AC-1 control x3 - `scripts/h60c/c1_<o>.sh`, `|| true` on line 2, reports nothing. Passes on arrival.
- AC-1 control x3 - `scripts/h60c/s1_<o>.sh`, the same plus `z=$(grep -c x f || printf 0)` on line 3, reports `3`.
- AC-5 x3 - `scripts/h60p/p5_<o>.sh`: opener, `echo "a || printf 0"`, `echo "a; grep -c x f || printf 0"`, `echo 'b; grep -c x f || printf 0'`, positive; reports `5`.
- AC-1 census + exit - `check-grep-count: scanned 3 shell file(s), 3 finding(s)` (anchored prefix), exit 1.
- C-3 - `scripts/h60k/u3.sh`, `m="$(grep -c '(a)' f || printf 0)"` then `n="$(grep -c '(a' f || printf 0)"`, reports `1 2`.
- AC-4 - `k4.sh`, `y=$(grep -c x f \` / `  || printf 0)`, reports `1`.
- AC-4 controls - `n4.sh` (`|| true`) nothing; `m4.sh` (same plus positive on 3) `3`. Pass on arrival.

`sigpipe.test.sh` (describe before `summary`, fixture `$S60`):
- AC-2 x3 - `scripts/h60/h60_<o>.sh`: opener, `set -o pipefail`, `if cmd | grep -q x; then :; fi`; reports `3`.
- AC-5 x3 - `scripts/q60/q60_<o>.sh`: pipefail, opener, `echo "a || printf 0"`, `p() { echo "run: cat x | head -1"; }`, `q() { echo 'usage: foo | grep -q bar'; }`, the real pipeline; reports `6`.
- AC-2 census - `check-sigpipe: scanned 3 shell file(s), 3 with pipefail, 3 finding(s)`.

**Files touched:** `.claude/tests/lib.test.sh`, `.claude/tests/grep-count.test.sh`,
`.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`,
`.claude/tests/selftest.test.sh`, this story (Contract amendments, Test plan,
Handoff). Not `.claude/hooks/lib.sh`, not `scripts/*.sh`.

**Floors** (executed counts, measured above): `lib` 283 -> 324, `grep-count`
20 -> 38, `sigpipe` 82 -> 89, at `floors.conf:45/:46/:61` and
`selftest.test.sh:536/:537/:553` plus `:566-567` (a third mirror the Contract
did not list; C-6 amended). `selftest: 268 passed, 0 failed`.

**Shape the tests pin.** No new export is imported. They use
`mask_shell_quotes` (stdin to stdout) and `unmask_shell_quotes` from
`.claude/hooks/lib.sh`, sourced with `CLAUDE_PROJECT_DIR` set, exactly as the
existing describes do; and the guards' CLI output, unchanged:
`<path>:<line>:...` per finding, and the census lines
`check-grep-count: scanned N shell file(s), M finding(s)` and
`check-sigpipe: scanned N shell file(s), P with pipefail, M finding(s)`.
The exact masked text pinned: inside a substitution every character is
`maskchar`ed as today, quotes included; the `)` that ends it is emitted raw;
a line break outside any quote is `\n`, not `\010`. **Not constrained:**
where the shared paren matching lives or what it is called, how the state is
held, and how C-4 joins the folded group, as long as a hit lands on the
group's first line.

**Passed on arrival, and what earns each.** 31 in lib, 5 in grep-count, 0 in
sigpipe. Probed in RED against a scratch clone at `d783d60` carrying a
candidate C-2 masker (quote spans and escapes inside `subst`, no heredoc rule),
never against the real tree:

| Pin | Mutation of the candidate | Result |
|---|---|---|
| trap 2 x3, C-2 exact x3, golden #6 (`git commit -m "$(printf ...)"`) | interior emitted unmasked (`out = out c` in subst's default branch) | all 7 red; `lib: 315 passed, 7 failed` |
| trap 2 (SQ), C-2 exact (SQ) | the `'` span inside subst emitted unmasked | both red; `lib: 320 passed, 2 failed` |
| grep-count AC-5 x3 | top-level double quotes stop masking | red, `actual: 3 5` |
| grep-count AC-5 x3 | top-level single quotes stop masking | red, `actual: 4 5` |
| sigpipe AC-5 x3 | double quotes stop masking | red, `actual: 4 6` |
| sigpipe AC-5 x3 | single quotes stop masking | red, `actual: 5 6` |

Not earned in RED: the 22 other golden entries (they pin "unchanged", and no
candidate change touched them); the heredoc body-is-data pin; round trip x3;
c1 x3, n4 and m4, which are silent today because the guard is blind or
because of the existing rule. c1 is paired with s1 and n4/m4 with k4, all red
until GREEN. DV-2 at GATES is where these get earned on the shipped code.

**Negative controls, expected values.** Every number below was measured by
running the real suites in that scratch clone, not in the framework of this
tree: (a) unchanged code, (b) candidate C-2 only, (c) candidate C-2 plus a
quote-aware unwrap (C-3) and a folded-group scan (C-4). GREEN confirms
column (c) against what it ships.

| Control | Pass condition | (a) today | (b) C-2 only | (c) C-2+C-3+C-4 |
|---|---|---|---|---|
| grep-count c1_* | none reported | none | none | none |
| grep-count s1_* | exactly `3` | none | `3` | `3` |
| grep-count p5_* prose | exactly `5` | none | `5` | `5` |
| grep-count n4 / m4 | none / `3` | none / `3` | none / `3` | none / `3` |
| grep-count C-3 u3 | `1 2` | `1` | `1` | `1 2` |
| sigpipe q60_* prose | exactly `6` | none | `6` | `6` |
| lib AC-5 line 3 | `echo "a^F^A^A^Fb"` | no line 3 | as pinned | as pinned |
| real tree, check-grep-count | 0 findings | 0 | 0 | 0 |
| real tree, check-sigpipe | 0 findings | 0 | **9** (gates.test.sh) | **9** |

Suites in the clone: (b) `lib: 322 passed, 0 failed` (before the heredoc pair
was added; with it, `323 passed, 1 failed`, the heredoc pin), `grep-count: 36
passed, 2 failed` (C-3, AC-4), `sigpipe: 87 passed, 2 failed` (the real-tree
C-3 pair, `actual: 9`); (c) `grep-count: 38 passed, 0 failed`. With (b) also
`phase-guard: 378 passed, 0 failed` and `worktree: 73 passed, 0 failed`, the
lock-side consumers C-2's caller paragraph names.

**What changes the approach.**
1. *Heredoc inside a quoted substitution* (C-2 amendment). The tree's two
   guards hold their rules in `"$(cat <<'AWKEOF' ... )"`. Quote tracking
   alone is not enough there; a heredoc opener inside `subst` must start a
   body that nothing in is counted. The quote-only candidate fails the pin.
2. *C-3 as a second copy makes DV-2 vacuous for grep-count* (C-3 amendment):
   measured `grep-count: 38 passed, 0 failed` with the old masker and a
   quote-aware unwrap. One shared function, or DV-2 has to break both copies.
3. *The fix widens what the masker sees across the tree*: masked text changes
   in `lib.sh` (from 1062), `_lib.sh` (321), `gates.test.sh` (809),
   `lib.test.sh` (437), `run-lock.test.sh` (487), `security-audit.test.sh`
   (145), `settings.test.sh` (107) and `check-sigpipe.sh` (183). Only
   `gates.test.sh` gains findings (the nine above, escalated);
   `check-grep-count.sh` stays at 0 over the tree.
4. This file's own new lines are written so that neither the old nor the new
   masker changes state on them (checked: the first masked difference in
   `lib.test.sh` is the old line 437; none in the other two suites). The one
   line that holds the tested shape uses a bare `$( )` on purpose, with a
   comment saying why.

**Declined to GATES, in those words.** DV-1 (AC-3, the real-tree probe at
`gates.test.sh:1894`) and DV-2 (the defect put back) both need the fix to
exist and are owned by GATES; RED did not run them and claims neither. The
scratch-clone numbers above are candidates', not the shipped code's.

**Callers checked** with
`git grep -n 'mask_shell_quotes\|masked_lines\|unwrap_quoted_subst'` on
2026-10-16: the Contract's list holds. `lib.test.sh`'s callers moved down by
this story's insertion (`:110`, `:111`, `:246`, `:266` new, `:746`, `:829`,
`:840`); no new caller outside tests.

**Other checks run in RED:** `bash scripts/gates.sh --fast` - every gate
UNCONFIGURED in this repository, `All required gates passed (0 ran, 5
unconfigured, 0 known)`, so the self-test is the judge here;
`bash scripts/check-sigpipe.sh` - `scanned 49 shell file(s), 45 with
pipefail, 0 finding(s)`; `bash scripts/check-grep-count.sh` - `scanned 49
shell file(s), 0 finding(s)` (fixtures live in temp fixtures and heredocs, so
neither guard scans them); `bash scripts/mutate.sh --check` - no stranded
mutation. No timeout budgets apply: these are bash suites with no framework
timeout.

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

**R-1 (RED, orchestrator, 2026-10-17): nine `gates.test.sh` pipelines
rewritten as here-strings (Contract C-7, PO decision 1).** What was wrong:
`printf '%s\n' "$x" | grep -q ...` under pipefail at 2114, 2905, 2912,
2942-2952 (six in `ac1_outcome`), 2985, 3013 and 3080. These are the shape
`check-sigpipe.sh` exists to refuse, and they were hidden from it by the masker
defect this story fixes. How it was found: RED's candidate masker reported
them, and the orchestrator reproduced them on an extracted fixture with the
current guard. What they assert instead: nothing different. `<<<"$x"` feeds
grep the same bytes `printf '%s\n' "$x"` did, so every assertion keeps its
meaning. Verified three ways:

- the `gates` suite still passes, 682/0, after the rewrite;
- with the subagent's candidate `lib.sh` in a scratch clone, both guards report
  0 findings over the rewritten tree (`check-sigpipe: scanned 49 shell
  file(s), 45 with pipefail, 0 finding(s)`, `check-grep-count: ... 0
  finding(s)`);
- one probe through `mutate.sh`, on a `gates.sh` line those helpers judge, went
  red through `assert_line` and was restored:

```
$ bash .claude/tests/gates.test.sh
gates: 682 passed, 0 failed
$ bash scripts/mutate.sh scripts/gates.sh '1113s#never accounted for; this run#never accounted for. This run#' -- bash .claude/tests/gates.test.sh
=== mutate: scripts/gates.sh (1 line(s) changed by 1113s#never accounted for; this run#never accounted for. This run#) ===
  1113 -   printf '\n%d declared gate(s) never accounted for; this run certifies nothing.\n' "$lost"
  1113 +   printf '\n%d declared gate(s) never accounted for. This run certifies nothing.\n' "$lost"
=== mutate: running bash .claude/tests/gates.test.sh ===
    FAIL (a) and the refusals are counted
    FAIL (b) and both are counted
    FAIL (c) and counted
    FAIL (a) --fast: exactly one gate is counted lost
    FAIL (b) --required: exactly one gate is counted lost
    FAIL (c) --gate b: exactly one gate is counted lost
    FAIL (d) --gate a: exactly one gate is counted lost
gates: 675 passed, 7 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/worktrees/nervous-snyder-2b307a/.claude/state/mutations/scripts_gates.sh.20261017T042641Z.42468.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

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

