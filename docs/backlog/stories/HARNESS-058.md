---
id: HARNESS-058
title: The Rust profile runs every test binary on its test gates and warns off --ignore-run-fail
slug: the-rust-profile-runs-every-test-binary
epic: 
type: chore
status: done
phase: DONE
branch: story/HARNESS-058-the-rust-profile-runs-every-test-binary
depends_on: [HARNESS-055] # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/skills/stack-profiles/reference/rust-cargo.md, .claude/tests/profiles.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

A port from the consuming project manhwa-cropper (`D:/manhwa-cropper`, commits
`b8ded77` MC-057 and `b23198c` MC-058, 2026-09-29), found by a triage on
2026-10-11 of every harness file that project changed locally. It is one of the
ports that must land upstream before manhwa-cropper's harness is refreshed;
the refresh replaces `.claude/skills/**`, so without it the guidance is lost.

**The defect.** By default `cargo test` stops at the first test *binary* with a
failing test and never runs the rest, so a change that breaks five suites
reports one, and the other four surface one re-run at a time. `cargo llvm-cov`
behaves the same. `--no-fail-fast` runs them all and still exits non-zero, so
the gate still fails; on a passing run the output is unchanged, so evidence
lines and floors read the same numbers. `cargo llvm-cov` also offers
`--ignore-run-fail`, which runs every test too but **exits 0** when tests fail
and the report succeeds: on a required gate that is a failing test graded as a
pass.

The upstream profile (release 94) has neither flag and no warning:

    $ grep -rn 'no-fail-fast\|ignore-run-fail' .claude/ docs/ scripts/
    (no output)
    $ sed -n 11,12p .claude/skills/stack-profiles/reference/rust-cargo.md
        gate | unit      | required | . | cargo test --workspace
        gate | coverage  | required | . | cargo llvm-cov --workspace --fail-under-lines 100

Nothing in `.claude/tests/profiles.test.sh` pins the cargo test-gate commands
today, so no test would notice the flag being dropped again. The required gate
holding this story's artefact is the harness self-test (`profiles` suite).

Split out of HARNESS-055 (the `no-count` declaration), which also edits
`rust-cargo.md` and `profiles.test.sh`: no mechanism is shared, so it is its own
story, and `depends_on` orders it after 055 to avoid the textual collision.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1** — Given `rust-cargo.md`'s `## Gate commands for project.conf` block,
  when `profiles.test.sh` reads its `gate | unit` and `gate | coverage` lines,
  then each command carries `--no-fail-fast` as a whole word, and the `unit`
  command still carries `--workspace`. Fails today (neither carries it).
  *Negative control:* the same check run over a fixture block whose `unit` line
  is `cargo test --workspace` must report it missing.
- **AC-2** — Given the same profile, when `profiles.test.sh` reads every
  `gate |` line in it, then none carries `--ignore-run-fail`; and the profile's
  prose names `--ignore-run-fail` together with the fact that it exits 0 on
  failing tests. The first half passes today (a guard, earned by DV-1); the
  second fails today. *Negative control:* a fixture `gate | coverage | required
  | . | cargo llvm-cov --workspace --ignore-run-fail` must be refused.
- **AC-3** — The profile explains why: a paragraph after the `--workspace`
  paragraph saying cargo stops at the first failing test binary, that
  `--no-fail-fast` runs them all and still exits non-zero, and that a passing
  run's evidence and floors are unchanged. Pinned by the presence of the phrase
  `first test *binary*` in that section. Fails today.

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

**Writes:** `.claude/skills/stack-profiles/reference/rust-cargo.md`, `.claude/tests/profiles.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

**Re-anchored 2026-10-16 (Lead PO, before RED), after HARNESS-055 landed.**
Verified by grep today: the gate block is `rust-cargo.md:9-13` (`unit` at `:11`,
`coverage` at `:12`), the `--workspace` paragraph starts at `:25` and
`## Evidence of work` is `:32`, with 055's three `no-count` lines at `:42-44`
below the evidence lines - C-1's paragraph goes between `:25-31` and `:32`.
`profiles.test.sh` defines `line_of` at `:445`, `section` at `:448` and `RUST`
at `:453` - AFTER the describes at `:130-321` - so the new describe must sit
after `:453` (after the HARNESS-041 AC-5 block at `:517` is the natural place).
Both files classify as `harness` (`bash scripts/classify.sh`), so the lock
permits GREEN's profile edit and no `## Scaffold inventory` is owed for this
`chore`. No file in the tree mentions `--no-fail-fast` or `--ignore-run-fail`.

**PO decision 1 (2026-10-16).** The Contract's "no floor change" is reversed
for the same reason as HARNESS-057's: the `profiles` floor is **116** today
(`floors.conf:54`, mirrored at `selftest.test.sh:545` and in the sentence at
`:564`), and HARNESS-055, the story the Contract waited on, is DONE. RED raises
it to the executed count it reads off its own run, in all three places;
`touches:` and `**Writes:**` widened accordingly.

**C-1. The profile text (GREEN), verbatim from downstream `b23198c`'s final
state**, adapted only in the attribution sentence:

    gate | unit      | required | . | cargo test --workspace --no-fail-fast
    gate | coverage  | required | . | cargo llvm-cov --workspace --no-fail-fast --fail-under-lines 100

and, after the `--workspace` paragraph, before `## Evidence of work`:

    **`--no-fail-fast` on the test gates.** By default cargo stops at the first
    test *binary* with a failing test and never runs the rest, so a change that
    breaks five suites reports one, and the other four surface one re-run at a
    time. `--no-fail-fast` runs them all and still exits non-zero, so the gate
    still fails. On a passing run it changes nothing in the output, so evidence
    lines and floors read the same numbers. Found on a consuming project's
    unit gate, then its coverage gate. `cargo llvm-cov` also offers
    `--ignore-run-fail`, which runs every test too but **exits 0** when tests
    fail and the report succeeds. On a required gate that is a failing test
    graded as a pass: never use it there.

The `task | test` line is left as it is: it is a developer convenience, not a gate.
If HARNESS-055 has changed the gate block's surrounding lines (it adds
`no-count` lines), GREEN anchors on the two `gate |` lines by text, not by line
number.

**C-2. The tests (RED)**, a new `describe` block in `profiles.test.sh` using its
existing `$RUST` variable and `section`/`line_of` helpers. Read the gate block
with the existing section reader; match `gate` lines by id with an anchored ERE
(`^[[:space:]]*gate[[:space:]]*[|][[:space:]]*unit[[:space:]]*[|]`), and the
flag as a whole word (`(^|[[:space:]])--no-fail-fast([[:space:]]|$)`), so
`--no-fail-fast-x` or a commented mention does not satisfy it. The negative
controls (AC-1, AC-2) run the same matcher over a heredoc fixture, not over a
copy of the file, so a matcher that cannot fail is caught in RED.

**Oracle partition:** all three ACs are mechanical (text presence/absence in a
shipped file). Nothing here is settled by judgement.

**No floor change is required**: floors are minima. If RED raises the
`profiles` floor, `.claude/tests/floors.conf` and `selftest.test.sh` join
`touches:` and the story waits for HARNESS-055, which raises the same floor.

## Deferred verifications

- **DV-1 — the defect put back.** With `--no-fail-fast` removed from the `unit`
  line of the shipped profile, AC-1's shipped-file assertion MUST fail, and only
  it. Run via `bash scripts/mutate.sh .claude/skills/stack-profiles/reference/rust-cargo.md
  '/gate | unit/s/ --no-fail-fast//' -- bash scripts/selftest.sh profiles`.
  Owner: GATES. Cannot run in RED: the flag is not in the file yet.
- **DV-2 — the guard earned.** AC-2's "no gate line carries
  `--ignore-run-fail`" passes on arrival. With `--ignore-run-fail` appended to
  the shipped `coverage` line (`mutate.sh ... '/gate | coverage/s/$/ --ignore-run-fail/'
  -- bash scripts/selftest.sh profiles`), it MUST fail. Owner: GATES.

**Results (GATES, orchestrator, 2026-10-16).** Each mutation turned exactly
the one targeted assertion red, nothing else, and the profile came back
byte for byte:

```
$ bash scripts/mutate.sh .claude/skills/stack-profiles/reference/rust-cargo.md '/gate | unit/s/ --no-fail-fast//' -- bash scripts/selftest.sh profiles
=== mutate: .claude/skills/stack-profiles/reference/rust-cargo.md (1 line(s) changed by /gate | unit/s/ --no-fail-fast//) ===
    FAIL AC-1: the rust `unit` gate runs every test binary (--no-fail-fast, as a whole word)
         expected: 1
         actual:   0
profiles: 131 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_skills_stack-profiles_reference_rust-cargo.md.20261016T023937Z.1013260.bak) ===

$ bash scripts/mutate.sh .claude/skills/stack-profiles/reference/rust-cargo.md '/gate | coverage/s/$/ --ignore-run-fail/' -- bash scripts/selftest.sh profiles
=== mutate: .claude/skills/stack-profiles/reference/rust-cargo.md (1 line(s) changed by /gate | coverage/s/$/ --ignore-run-fail/) ===
    FAIL AC-2: no `gate |` line in the rust profile carries --ignore-run-fail
         expected: 0
         actual:   1
profiles: 131 passed, 1 failed
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.claude_skills_stack-profiles_reference_rust-cargo.md.20261016T023959Z.1014543.bak) ===
$ bash scripts/mutate.sh --check
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

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

Planned by `bash scripts/plan.sh write HARNESS-058` from `.claude/harness/models.conf`.
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

- RED, `test-developer`, 2026-10-15: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override. Planned `opus`; no change.
- GREEN, `feature-developer`, 2026-10-15: **Opus 5.5** (`claude-opus-5-5`), its declared `model:`; no override. Planned `opus`; no change.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- `no-count` lines in the rust profile: HARNESS-055.
- The `task | test` line: a convenience, not a gate; it keeps fail-fast.
- Other profiles' test runners (vitest, pytest): they already run every file by
  default; nothing found says otherwise, and nothing here measures it.
- Changing any consuming project's `project.conf`: project-owned; manhwa-cropper
  already carries both flags (MC-057/058).

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

One new `describe` in `.claude/tests/profiles.test.sh`, placed after the
HARNESS-041 AC-5 block and before `summary "profiles"` (so after `line_of`,
`section`, `paras`, `count_paras`, `para_with` and `$RUST` are defined; the
re-anchored line numbers held: helpers at `:445-453`, AC-5 block at `:517`).
Level: a text-consistency check over the shipped profile, the only level at
which these criteria exist. All three ACs are mechanical; nothing is tuned.

Three local helpers carry the matching, ONE copy each, used on the shipped
file and on the heredoc fixtures alike (C-2):

- `gate_lines <id-ERE> <text>` - `awk` with
  `^[[:space:]]*gate[[:space:]]*[|][[:space:]]*<id>[[:space:]]*[|]`; the id sits
  between bars, so `unit` does not select `unit-x`, and a `# gate | unit` comment
  line is not a gate line.
- `word_count <flag> <text>` - `grep -cE -- '(^|[[:space:]])<flag>([[:space:]]|$)'`
  on a here-string, `|| true` for the exit status only (no printing fallback).
- `prose_paras_with <needle> <text>` - the paragraphs (via the file's `paras`)
  containing the needle that do NOT start with four spaces, so a config block
  carrying a flag is not mistaken for a warning about it.

| # | Assertion (as the failure message reads) | AC | On arrival |
|---|---|---|---|
| 1 | precondition: the Gate commands section has exactly one `gate \| unit` line | AC-1 | green |
| 2 | precondition: ... exactly one `gate \| coverage` line | AC-1 | green |
| 3 | AC-1: the rust `unit` gate runs every test binary (--no-fail-fast, as a whole word) | AC-1 | **red** |
| 4 | AC-1: the rust `unit` gate still tests every workspace member (--workspace) | AC-1 | green (regression guard; the flag exists today and must survive the edit) |
| 5 | AC-1: the rust `coverage` gate runs every test binary (--no-fail-fast, as a whole word) | AC-1 | **red** |
| 6 | AC-1 control: a `unit` line of plain `cargo test --workspace` is reported missing the flag | AC-1 neg. control | green (control) |
| 7 | AC-1 control: `--no-fail-fast-x` on the coverage line is not the flag | AC-1 neg. control | green (control) |
| 8 | AC-1 control: the matcher does find the flag on a unit line that carries it | AC-1 pos. control | green (control) |
| 9 | precondition: the AC-2 guard reads at least the five required gate lines | AC-2 | green |
| 10 | AC-2: no `gate \|` line in the rust profile carries --ignore-run-fail | AC-2 | green (guard; earned by DV-2) |
| 11 | AC-2 control: a coverage gate carrying --ignore-run-fail is refused by the same matcher | AC-2 neg. control | green (control) |
| 12 | AC-2: one prose paragraph names --ignore-run-fail and says it exits 0 when tests fail | AC-2 | **red** |
| 13 | precondition: AC-3's window starts at the --workspace paragraph | AC-3 | green |
| 14 | AC-3: between the --workspace paragraph and Evidence of work, one paragraph says cargo stops at the 'first test *binary*' | AC-3 | **red** |
| 15 | AC-3: that paragraph says --no-fail-fast still exits non-zero | AC-3 | **red** |
| 16 | AC-3: that paragraph says a passing run leaves evidence lines and floors unchanged | AC-3 | **red** |

Preconditions 1, 2, 9 and 13 exist so that a "0" or an absence below them
means the flag/phrase is missing, not that the reader found nothing.

Floor (PO decision 1): `profiles` 116 -> **132** in `floors.conf:54`, the mirrored
table in `selftest.test.sh` (`profiles 132`) and the sentence/value at
`selftest.test.sh:564-565`, with a dated measurement note at the foot of
`floors.conf`.

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

**Run on:** `claude-opus-5-5` (Opus 5.5), as `test-developer`; no override.

**Commands**

    bash scripts/selftest.sh profiles     # the suite holding every new assertion (~22 s here)
    bash scripts/selftest.sh selftest     # the floor table (profiles 132)
    bash scripts/check-sigpipe.sh         # 0 findings
    bash scripts/check-grep-count.sh      # 0 findings

`bash scripts/gates.sh --fast` runs nothing in this repository
(`0 ran, 5 unconfigured`), so the suites above are the gate.

**Failure output on this tree (rust-cargo.md unchanged), verbatim:**

```
  the rust profile runs every test binary on its test gates and warns off --ignore-run-fail (HARNESS-058, AC-1..AC-3)
    FAIL AC-1: the rust `unit` gate runs every test binary (--no-fail-fast, as a whole word)
         expected: 1
         actual:   0
    FAIL AC-1: the rust `coverage` gate runs every test binary (--no-fail-fast, as a whole word)
         expected: 1
         actual:   0
    FAIL AC-2: one prose paragraph names --ignore-run-fail and says it exits 0 when tests fail
         expected: 1
         actual:   0
    FAIL AC-3: between the --workspace paragraph and Evidence of work, one paragraph says cargo stops at the 'first test *binary*'
         expected: 1
         actual:   0
    FAIL AC-3: that paragraph says --no-fail-fast still exits non-zero
         expected to contain: still exits non-zero
         actual:               <no paragraph naming first test *binary*>
    FAIL AC-3: that paragraph says a passing run leaves evidence lines and floors unchanged
         expected to contain: evidence lines and floors
         actual:               <no paragraph naming first test *binary*>

profiles: 126 passed, 6 failed
FAIL profiles  did 126 units of work, below the floor of 132 in .claude/tests/floors.conf
```

It is the right failure: every other describe in the suite is unchanged and
green, the four preconditions are green (the readers found the lines and the
window), and the six reds are exactly the shipped-file assertions for AC-1's
two flags, AC-2's prose and AC-3. Unlike an import-failing RED, every
assertion in this block **did execute** - the controls below ran inside the
framework against their fixtures and passed.

`selftest: 268 passed, 0 failed` (floor table with `profiles 132`);
`check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)`;
`check-grep-count: scanned 49 shell file(s), 0 finding(s)`.

**Assertions -> AC:** the table in `## Test plan` (16 rows; 6 red, 10 green).

**Files touched**

- `.claude/tests/profiles.test.sh` - the new describe (+108 lines), before `summary "profiles"`
- `.claude/tests/floors.conf` - `floor | profiles | 132`, measurement note at the foot
- `.claude/tests/selftest.test.sh` - `profiles 132` in the COUNTS table; the
  `profiles is floored at its 132 executed assertions` sentence and its value
- this story (`## Test plan`, `## Handoff`)

**What the tests pin in `rust-cargo.md` (GREEN's only file)** - there are no
exports; the "shape" is text:

- In `## Gate commands for project.conf`, exactly one line matching
  `gate | unit |` and one matching `gate | coverage |`; each carries
  `--no-fail-fast` as a whitespace-delimited word; the unit line also carries
  `--workspace`. C-1's two lines satisfy it verbatim:

      gate | unit      | required | . | cargo test --workspace --no-fail-fast
      gate | coverage  | required | . | cargo llvm-cov --workspace --no-fail-fast --fail-under-lines 100

- No line anywhere in the file matching `gate | <anything> |` carries
  `--ignore-run-fail` as a word; at least five gate lines exist.
- Exactly one paragraph between the line beginning
  ``**`--workspace` on every command`` and the line `## Evidence of work`
  contains the literal `first test *binary*` (asterisks included), and that
  paragraph contains `still exits non-zero` and `evidence lines and floors`.
  Paragraphs are joined across line wraps (the suite's `paras`), so C-1's wrap
  of `first` / `test *binary*` and `evidence` / `lines and floors` is fine.
- Exactly one non-indented paragraph anywhere in the file contains
  `--ignore-run-fail`, `exits 0` and `tests fail` (the `**` around `exits 0`
  does not matter; the same paragraph as above, in C-1).

**Left to GREEN:** the paragraph's wording beyond those phrases, its exact
position inside the window (it must be after the `--workspace` paragraph's
first line and before `## Evidence of work`), its heading/bold lead, and the
attribution sentence. Not constrained: the `task | test` line (out of scope,
and nothing reads it), the order of the flags on each gate line, the other
gate lines. Keep `--ignore-run-fail` out of every `gate |` line, and do not
put the warning in an indented block - an indented paragraph is read as
configuration, not prose.

**Checked before handing over (outside the real file):** C-1's text applied
verbatim to a scratch copy of `rust-cargo.md` and the suite pointed at it
(only `RUST=` changed in a scratch copy of the test) gave
`profiles: 132 passed, 0 failed`. DV-1 and DV-2's `sed` expressions applied to
that scratch copy each gave exactly one failure, the assertion they target:

```
DV-1
    FAIL AC-1: the rust `unit` gate runs every test binary (--no-fail-fast, as a whole word)
profiles: 131 passed, 1 failed
DV-2
    FAIL AC-2: no `gate |` line in the rust profile carries --ignore-run-fail
profiles: 131 passed, 1 failed
```

That is a rehearsal on a scratch copy, **not** DV-1/DV-2: both still have to
be run in GATES with `scripts/mutate.sh` against the shipped file, and RED
declines them in writing here - in RED the flag is not in the file, so DV-1
cannot run, and DV-2 belongs to the phase that owns it.

**Passed on arrival, and what earns each**

| Assertion | Earned by |
|---|---|
| 1, 2, 9, 13 preconditions | fail if the reader breaks; each is the denominator of a red below |
| 4 unit keeps `--workspace` | regression guard for an invariant the profile already states; DV-1's rehearsal deletes the neighbouring flag only - a mutation dropping `--workspace` belongs to `/audit-mutations` |
| 6, 7, 8, 11 controls | themselves: they ran in the framework against heredoc fixtures |
| 10 no gate carries `--ignore-run-fail` | DV-2 (GATES); rehearsed above |

**Negative controls - measured, in the framework, on this tree**

| Control | Fixture | Threshold | Expected | Measured |
|---|---|---|---|---|
| 6 | `gate \| unit \| ... \| cargo test --workspace` | `word_count == 0` | 0 | 0 |
| 7 | `gate \| coverage \| ... --no-fail-fast-x ...` | `word_count == 0` | 0 | 0 |
| 8 (positive) | `gate \| unit \| ... --workspace --no-fail-fast` | `word_count == 1` | 1 | 1 |
| 11 | `gate \| coverage \| required \| . \| cargo llvm-cov --workspace --ignore-run-fail` | `word_count == 1` (refused) | 1 | 1 |

The AC-1 fixture also carries a `gate | unit-x` line WITH the flag, a
`# gate | unit | ... --no-fail-fast` comment and a prose mention, none of
which may be selected as the unit line - control 6 would read 1 if any were.
GREEN: confirm the four still read as above once the profile changes (they do
not read the profile, so they should not move).

**Discovered**

- AC-2's text says its guard is "earned by DV-1"; it is DV-2 that earns it
  (DV-1 removes `--no-fail-fast`). Not an AC change worth an amendment - the
  DV block is right - but noted so REVIEW does not chase it.
- The Contract's re-anchor block is dated 2026-10-16; this RED ran 2026-10-15.
  The line numbers it gives all held.

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

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-16T02:40:21Z
    commit: 4ae26fe
    tree:   b0f5384c2530bba83b1e8d51e95cc75fc9358c28
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


**Provenance.** Planned 2026-10-12 by the orchestrator (Opus 5.5), split out of
HARNESS-055 at that planner's recommendation. Source commits:
`git -C D:/manhwa-cropper show b8ded77 b23198c -- .claude/skills/stack-profiles/reference/rust-cargo.md`.
Both commit messages say the change was "probed both ways"; the probe output
is in downstream's `docs/backlog/stories/MC-057.md` and `MC-058.md`, which this
planner did not re-read or re-run.

### RED verification (orchestrator, 2026-10-15)

RED dispatched to `test-developer`; it reported running on `opus`. Its diff
was read in full: one describe in `profiles.test.sh` (+108, 16 assertions)
after the HARNESS-041 AC-5 block, with one copy of each matcher used on the
shipped profile and on heredoc fixtures alike (`gate_lines` anchored by id
between bars, `word_count` whole-word, `prose_paras_with` excluding indented
blocks), two preconditions, AC-1 x3 plus three fixture controls, the AC-2
guard with its precondition and control, AC-2's prose paragraph, AC-3's
window precondition and three paragraph phrases; `profiles` floor 116 -> 132
in all three places. Nothing outside test files and this story.

Orchestrator's own run against the unchanged `rust-cargo.md`:

    $ bash scripts/selftest.sh profiles
        FAIL AC-1: the rust `unit` gate runs every test binary (--no-fail-fast, as a whole word)      (expected 1, actual 0)
        FAIL AC-1: the rust `coverage` gate runs every test binary (--no-fail-fast, as a whole word)  (expected 1, actual 0)
        FAIL AC-2: one prose paragraph names --ignore-run-fail and says it exits 0 when tests fail    (expected 1, actual 0)
        FAIL AC-3: between the --workspace paragraph and Evidence of work, one paragraph says cargo stops at the 'first test *binary*'
        FAIL AC-3: that paragraph says --no-fail-fast still exits non-zero          (<no paragraph naming first test *binary*>)
        FAIL AC-3: that paragraph says a passing run leaves evidence lines and floors unchanged
    profiles: 126 passed, 6 failed
    FAIL profiles  did 126 units of work, below the floor of 132
    $ bash scripts/selftest.sh selftest
    selftest: 268 passed, 0 failed
    $ bash scripts/check-sigpipe.sh
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    $ bash scripts/check-grep-count.sh
    check-grep-count: scanned 49 shell file(s), 0 finding(s)
    $ bash scripts/gates.sh --fast
    All required gates passed (0 ran, 5 unconfigured, 0 known).

Right failure: exactly the six shipped-file assertions are red (AC-1's two
flags, AC-2's prose, AC-3's paragraph and its two phrases); the `--workspace`
check, the AC-2 guard and all four fixture controls are green, as predicted.
Floors count passes, so the suite also sits 6 below its new floor until GREEN.
RED rehearsed C-1's text on a scratch copy (132/0 there, and each DV `sed`
reddening exactly one assertion) - a rehearsal, not the DVs, which GATES runs.

**Two corrections from the handoff, accepted:** AC-2's text says its guard is
"earned by DV-1" and means DV-2 (the DV section is right; the AC wording is
not amended - it is a cross-reference, not a criterion). The Contract's
re-anchor block is dated 2026-10-16 but was written on 2026-10-15; the line
numbers in it held.

### GREEN verification (orchestrator, 2026-10-15)

The feature-developer's diff was read in full: `rust-cargo.md` only
(+13/-2) - the two gate lines are C-1's verbatim, `task | test` untouched,
and C-1's paragraph sits unindented between the `--workspace` paragraph and
`## Evidence of work`, word for word. Nothing else changed.

Orchestrator's own runs against the shipped profile:

    $ bash scripts/selftest.sh profiles
    profiles: 132 passed, 0 failed
    assertion floors: all 1 suite(s) met their declared floor (132 assertions executed, 132 declared).
    $ bash scripts/gates.sh --audit
    Manifest audit passed.
    $ bash scripts/gates.sh --fast
    All required gates passed (0 ran, 5 unconfigured, 0 known).
    $ bash scripts/check-sigpipe.sh
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    $ bash scripts/check-grep-count.sh
    check-grep-count: scanned 49 shell file(s), 0 finding(s)

The six RED assertions pass; the `--workspace` check, the `--ignore-run-fail`
guard and the four fixture controls stayed green (the suite prints only
failures). DV-1 and DV-2 are GATES' to run.

### GATES (orchestrator, 2026-10-16)

DV-1 and DV-2 ran through `scripts/mutate.sh` against the `profiles` suite
before the gate run - the flag removed from the `unit` line, and
`--ignore-run-fail` appended to the `coverage` line - each caught by exactly
its one targeted assertion (131/1 both times), each restored byte for byte,
`--check` clean; results pasted in `## Deferred verifications`. Then
`bash scripts/gates.sh` recorded `result: pass (0 ran, 7 unconfigured,
0 known)` against `4ae26fe`; every gate is unconfigured on this repository,
so the suites and the full self-test before REVIEW are the judge.

### Full self-test before REVIEW (orchestrator, 2026-10-15)

    $ time bash scripts/selftest.sh
    profiles: 132 passed, 0 failed
    gates: 671 passed, 0 failed
    ...
    assertion floors: all 26 suite(s) met their declared floor (3416 assertions executed, 3190 declared).
    26 harness suite(s) passed.
    real    51m18.123s
    exit=0

Every suite green, every floor met.

PR: https://github.com/ryanczhang7/agentic-dev-harness/pull/144 (opened 2026-10-15 from `01ad466`).

### DONE (2026-10-16)

Merged as #144 (`8a45267`, 2026-10-16T03:52:32Z). CI on the final head
`9a8e122`: run 38846402626 `gates` success, run 38846402635 `boundaries`
success. Timings read from the `gates` job: `Harness self-test` 03:37:04 ->
03:39:15 (2m11s, all 26 suites) against the job's `timeout-minutes: 45`;
the sigpipe and grep-count steps 3s and 2s.
