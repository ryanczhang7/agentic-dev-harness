---
id: HARNESS-041
title: Mutation gates need a killed count
slug: mutation-gates-need-a-killed-count
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-041-mutation-gates-need-a-killed-count
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [.claude/skills/stack-profiles/reference/node-typescript.md, .claude/skills/stack-profiles/reference/python-uv.md, .claude/skills/stack-profiles/reference/rust-cargo.md, .claude/skills/stack-profiles/reference/new-profile.md, .claude/skills/stack-profiles/SKILL.md, .claude/skills/quality-gates/SKILL.md, .claude/tests/profiles.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

GitHub issue #104 (ryanczhang7/agentic-dev-harness), **section 2** and the
"related observation" of section 1. Items 1A and 1B of the issue are DONE
(HARNESS-040 delivers missing `docs/` files on refresh; HARNESS-039 makes
`gates.sh --audit` FAIL a `mutation` gate with no `ondemand` line). This story
is the issue's progress comment's items 2 and 3, in one cycle.

The defect, measured by the issue's reporter on a consumer (fantasy-world-
builder) with `@stryker-mutator/core` 10.0.0, `@stryker-mutator/vitest-runner`
10.0.0, typescript 7.0.2, vitest 5.0.0, Node 24.19.0, pnpm 12.3.4, Windows 11
- **not re-measured here; that toolchain is not installed in this repository
and every number below is the reporter's**:

- `node-typescript.md:15` prescribes `pnpm exec stryker run` with no caveat. On
  TS 7 core's `TSConfigPreprocessor` calls `ts.parseConfigFileTextToJson`,
  which TS 7 (the native port) no longer has, whenever `tsconfigFile` names a
  file that exists; `checkers: []` does not avoid it. Separately, the vitest
  runner plugin, built against vitest 4.1.10 with a peer range of `>=2.0.0`,
  **runs no tests under vitest 5.0.0 and still reports a score**: one file
  85.79% (156 static mutants killed, 0 of 22 runtime mutants killed), another
  0 of 19 killed where the same mutant run by hand fails 9 tests. What worked
  was core's built-in command runner.
- The `mutation` gate has **no `evidence` line in any profile**
  (`node-typescript.md:30-33`, `python-uv.md:30-34`, `rust-cargo.md:36-43`),
  so `gates.sh` has nothing to hold such a run to: it exits 0 and is reported
  as a pass. A runner that tests nothing producing a plausible score is the
  exact failure the evidence mechanism exists for (`gates.sh:16-18`), arriving
  through the one gate nobody gave it.
- `node-typescript.md:45` says "Verified against vitest 5 and typescript 5 on
  Windows" directly under an evidence block in which `lint` and `build` are
  marked UNVERIFIED and `mutation` has no line at all. The sentence was written
  for the `unit`/`coverage` lines (commit `4f58e41`) and now reads as a claim
  about the block.
- A Tauri project (TS + Rust) combining two profiles gets two `mutation` gate
  lines with one id, and nothing says how to name the second.

**The gate that fails if this story's artifact breaks** is the harness's own
`selftest` (`.claude/tests/profiles.test.sh`), which CI runs on every PR: the
new rule and the regex controls live there. No `required_gates` entry is
needed; the profiles suite is not optional.

**Decision on HARNESS-039's id rule: unchanged.** HARNESS-039 keyed the audit
on the id `mutation` exactly, and AC-4b pins that `mutants` / `rust-mutation`
are not flagged, "for the combining-profiles story". This story keeps that
limit and documents the convention instead of extending the rule, for three
reasons. (1) Extending it means `scripts/gates.sh`, `gates.test.sh` and
AC-4b's pinned assertion - a second RED->GREEN cycle on a different file set,
and `gates.sh` is not in `touches:` here. (2) The convention has to exist
before a rule can be keyed on it; naming it is this story's job, and the
natural key - ids ending in `mutation` - is written down below so that a later
story can make it mechanical without re-deciding it. (3) The only consumer the
issue describes (the Tauri project) has one mutation gate today; no consumer
needs the second id judged yet. The new `profiles.test.sh` rule added here is
keyed on the same id `mutation`, for the same reason and with the same stated
limit. If a consumer combines two profiles, the follow-up story extends both
rules to the suffix and changes AC-4b on purpose.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. -->

- **AC-1 (a mutation gate carries an evidence line)** — Given a profile
  fixture that configures `gate | mutation | optional | . | x mutants` and
  every other profile rule satisfied (`profiles.test.sh:136-153`'s
  `base_profile`), when `profile_problems` runs over it, then it prints exactly
  one `mutation-evidence` line whose message is C-3's text; with
  `evidence | mutation | -` appended it prints the same line (a `-` is a
  declaration that no output exists, and a mutation tool always prints a
  count); and - the control - with `evidence | mutation | [1-9][0-9]* caught`
  appended it prints nothing for `mutation-evidence`. Given the three shipped
  profiles that configure a `mutation` gate (`node-typescript.md`,
  `python-uv.md`, `rust-cargo.md`), when the per-profile loop runs, then each
  reports nothing for `mutation-evidence`.
- **AC-2 (the regex requires a killed count, through `gates.sh`)** — Given a
  `make_project_fixture` whose `mutation` gate is `required` and whose command
  `printf`s a canned line, and whose `evidence | mutation` line is copied
  verbatim out of the real profile, when `bash scripts/gates.sh --gate
  mutation` runs there, then for each of the three profiles: the tool's
  **killed-N>0 line** (C-4's positive, N as given) gives `PASS         mutation`
  and the **0-killed line** (C-4's negative) gives `FAIL         mutation (…
  ran but produced no evidence of work: expected /<regex>/)` - the exact
  wording `gates.sh:583-584` prints. *Control:* the negative lines are real
  shapes (C-4 says where each comes from), not garbage; a regex that matched
  any line with digits in it would pass them and go red here.
- **AC-3 (the shape is readable by the suite, not re-derived)** — Given the
  three profiles, when the suite reads each one's `evidence | mutation` regex
  with the same `rest(3)` logic `profile_problems` uses (`profiles.test.sh:33`),
  then the regex it feeds into AC-2's fixture is byte-identical to the one on
  the profile line - the suite holds no second copy of any regex, so loosening
  the real line (DV-1) is what goes red, not a private copy. Observable as:
  the string the suite extracted equals `grep`'s view of the line with
  `evidence | mutation |` and surrounding space removed.
- **AC-4 (node-typescript says how stryker runs on TS 7 / Vitest 5)** — Given
  `node-typescript.md` after GREEN, when read, then (a) within the ten lines
  after its `gate | mutation` line there is a sentence naming TypeScript 7 and
  Vitest 5 and pointing at the new section; (b) a section headed `## The
  mutation gate on TypeScript 7 / Vitest 5` exists and contains, in one
  indented or fenced block, the keys `testRunner`, `commandRunner`,
  `coverageAnalysis`, `timeoutMS`, `tsconfigFile` and `plugins`; (c) that
  section attributes every measurement to issue #104's reporter and contains
  the words `not re-measured`; (d) the line `Verified against vitest 5 and
  typescript 5 on Windows.` no longer exists in that spelling, and the
  sentence that replaces it names `unit` and `coverage` as the verified lines
  and says the `mutation` line was derived from the reporter source and not
  run. Each is a `grep -c` with an exact count (1, or 0 for (d)'s old line);
  the needles are pinned in C-6.
- **AC-5 (combining two profiles' mutation gates is written down)** — Given
  `.claude/skills/stack-profiles/SKILL.md` after GREEN, when read, then its
  "Choosing" section (after the "Mixed-stack projects are normal" sentence,
  `SKILL.md:56-57`) carries a paragraph that names the convention: keep
  `mutation` for one stack and name the other `<stack>-mutation` (the example
  `rust-mutation`), copy the `evidence`, `slow` and `ondemand` lines under
  the new id, tell `/audit-mutations` to run `--gate rust-mutation` too, and
  state that `gates.sh --audit` and `profiles.test.sh` judge the id
  `mutation` only (HARNESS-039 AC-4b). Needles pinned in C-7; `grep -c` of
  each is 1. `node-typescript.md` and `rust-cargo.md` each carry one line
  beside their `ondemand | mutation` line pointing at it.

## Contract

**Writes:** `.claude/skills/stack-profiles/reference/node-typescript.md`, `.claude/skills/stack-profiles/reference/python-uv.md`, `.claude/skills/stack-profiles/reference/rust-cargo.md`, `.claude/skills/stack-profiles/reference/new-profile.md`, `.claude/skills/stack-profiles/SKILL.md`, `.claude/skills/quality-gates/SKILL.md`, `.claude/tests/profiles.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

Every path classifies as `harness` (`bash scripts/classify.sh` on each at
PLANNED: all nine print `harness`), so the phase lock freezes none of them.
The role boundary is honoured by the agents: RED writes `profiles.test.sh`,
`floors.conf` and `selftest.test.sh` only; GREEN writes the six documents
only. No existing export changes signature; there is no caller list.
`scripts/gates.sh` is **not** written (Context, the id decision).

**RED may amend any block below in place, with a reason; GREEN builds what
the amended block says.**

- **C-1 Where the rule lives (`.claude/tests/profiles.test.sh`, verified at
  PLANNED against release 84).** `profile_problems()` is the awk at `:28-91`;
  evidence lines are parsed at `:43` into `ev[id] = 1`, which records
  presence only. The new rule needs the regex text, so RED changes that line
  to also keep it: `ev[t($2)] = 1; evre[t($2)] = rest(3); next`. The rule
  itself goes in `END`, beside the `mutation-ondemand` rule at `:84-85`:

      if (("mutation" in gates) && (!("mutation" in ev) || evre["mutation"] == "-" || evre["mutation"] == ""))
        print "mutation-evidence\t<message of C-3>"

  `rest(3)` (`:33`) rejoins fields from `$3` with `|` and trims the ends, so
  a regex containing `[|]` or `[^|]` survives it - the same reason
  `gates.sh:157-158` uses `rest 3` ("so that a regex containing `|`
  survives"). The per-profile loop at `:180-205` gains one `check
  mutation-evidence "$name: its mutation gate has an evidence line"` inside
  the existing `if has_mutation_gate "$f"` at `:202-204`. The fixture checks
  follow the `ondemand_probs` pattern at `:126-166` (`base_profile`, append
  one line, compare the one check's output).
- **C-2 Where AC-2 lives.** Also `profiles.test.sh`, after the fixture
  checks: it sources `_lib.sh` already (`:16`), so `make_project_fixture` and
  `write_conf` (`_lib.sh:123-137`) are available. One helper, roughly
  `mutation_gate_verdict <profile> <canned line>`: extracts the regex from the
  profile (AC-3; `awk -F'|'` with the same `rest` logic, or `profile_problems`
  extended to print it under a `mutation-regex` tag - RED's choice, as long as
  there is one extraction and it is asserted equal to the line's text),
  writes a conf of exactly

      gate     | mutation | required | . | printf '%s\n' '<canned line>'
      evidence | mutation | <regex>
      ondemand | mutation | fixture

  and runs `bash scripts/gates.sh --gate mutation` in the fixture, returning
  the `PASS`/`FAIL` line. The gate is `required` in the fixture so that a
  non-match is a `FAIL` line rather than a `WARN` (an optional gate's
  no-evidence outcome is a WARN and the run still prints "All required gates
  passed" - measured at PLANNED, which is why the fixture must say
  `required`). `--gate` is not recorded and runs an `ondemand` gate
  (`gates.sh:7`). Needles: `^PASS +mutation ` and
  `^FAIL +mutation .*ran but produced no evidence of work`, counted with the
  suite's existing `assert_contains`/`assert_eq` on the grep'd line. The
  `printf '%s\n'` with the canned line single-quoted is what keeps `|`, `*`
  and the emoji literal through `eval` (`gates.sh:560`).
- **C-3 Message**, pinned byte for byte so RED's needle and GREEN's print
  cannot drift (as HARNESS-039 C-3 did). The text after the tab:

      configures a `mutation` gate with no `evidence | mutation | <regex>` line, so a runner that tests nothing passes it

  The same sentence shape as the `mutation-ondemand` message at `:85`, which
  `new-profile.md:51-55` paraphrases; GREEN adds "and an `evidence` line whose
  regex requires a killed count" to that list (C-8).
- **C-4 The three regexes and their canned lines.** Each regex is an awk ERE
  matched per line, unanchored, after `clean_log` has stripped ANSI colour and
  trailing CR (`gates.sh:263-266`, `:580`). No `\d`, no `{n}` intervals, no
  `\|`: CI's awk is mawk, and `[|]` / `[^|]` are POSIX bracket expressions
  every awk reads the same way (`\|` in a dynamic regex is engine-dependent).
  All three were run through `gates.sh` itself at PLANNED on a fixture, on
  gawk 5.4.1 / Windows: the positive lines `PASS`, the negatives `FAIL` with
  the C-2 wording.

  **node-typescript** (`evidence | mutation | All files *[|][^|]*[|][^|]*[|] *[1-9][0-9]* [|]`).
  Stryker's clear-text reporter draws a score table whose totals row is
  labelled `All files` (`packages/core/src/reporters/clear-text-score-table.ts`,
  `FILES_ROOT_NAME`, read 2026-10-06 on stryker-js `master`) with the
  columns, in order: `% Mutation score` total, covered, `# killed`,
  `# timeout`, `# survived`, `# no cov`, `# errors`; cells are right-padded
  values joined by `|` with a trailing `|`; the score cells are chalk-coloured
  (stripped by `clean_log`), the count cells are not; the table is written to
  `process.stdout`, not through the logger, so the row has no timestamp
  prefix. The regex walks three `|`-separated cells from `All files` and
  requires the third - `# killed` - to be a number not starting with `0`.
  The semantics: *a Stryker run in which no mutant was killed is not evidence
  that the tests were run.* Canned lines (shape from the source, numbers from
  issue #104):

      positive:  All files         |   85.79 |    85.79 |       156 |         0 |        27 |        0 |        0 |
      negative:  All files         |    0.00 |     0.00 |         0 |         0 |        19 |        0 |        0 |
      negative:  All files | n/a | n/a | 0 | 0 | 0 | 0 | 0 |

  **Honest limit, to be written into the profile:** the reporter's first
  measurement (85.79%, 156 killed) *would pass this line* - those 156 were
  static mutants, killed without the runner, while 0 of 22 runtime mutants
  were. The line catches the second shape (0 of 19) and the pure
  nothing-ran case. Under the configuration the profile now recommends,
  `coverageAnalysis: "off"`, no mutant is classified static (Stryker's
  `docs/configuration.md`: detecting static mutants "needs per test coverage
  analysis"), so every kill is one the command runner actually ran, and the
  line then means what it says. The profile says both halves.
  **No `floor` on this line**: `work_count` (`gates.sh:279-283`) reads the
  first digit run at or after the match, which is the score (`observed 85` on
  the positive row at PLANNED), not the kill count. Say so beside the line.

  **rust-cargo** (`evidence | mutation | [1-9][0-9]* caught`). cargo-mutants
  prints one summary line, `summary_string()` in `src/outcome.rs` (read
  2026-10-06): `<N> mutant(s) tested[ in <t>]: ` then, comma-joined, only the
  non-zero outcomes in the order `missed`, `caught`, `unviable`, `timeouts`,
  `succeeded`. **Measured here at PLANNED with cargo-mutants 27.1.0** on a
  one-function scratch crate: `4 mutants tested in 4s: 4 caught` and
  `4 mutants tested in 3s: 3 missed, 1 caught`. A run with no kills omits
  `caught` altogether, so the regex has nothing to match. Canned lines:

      positive:  4 mutants tested in 4s: 4 caught                      (measured)
      positive:  6 mutants tested in 1m 2s: 2 missed, 3 caught, 1 unviable
      negative:  3 mutants tested in 20s: 3 missed
      negative:  src/a.rs:3:5: replace f -> u8 with 1 ... caught in 0.1s   (a verbose per-mutant line; no digit directly before " caught")

  `work_count` reads `3` from the positive: a `floor` on this line is
  meaningful (the kill count), and the profile may say so.

  **python-uv** (`evidence | mutation | 🎉 [1-9][0-9]*`). mutmut 3's final
  status line is `print_stats()` in `src/mutmut/stats.py:102` (read
  2026-10-06): `{tested}/{total}  🎉 {killed} 🫥 {no_tests}  ⏰ {timeout}  🤔
  {suspicious}  🙁 {survived}  🔇 {skipped}  🧙 {caught_by_type_check}`, printed
  with `force_output=True` when the run ends (`__main__.py:1070`). The killed
  count follows the 🎉 and is the only number that does. The emoji is a
  4-byte UTF-8 literal; at PLANNED it matched byte-for-byte under both the
  UTF-8 and the C locale on gawk, and through `gates.sh` on the fixture.
  **UNVERIFIED against a mutmut run** - mutmut is not installed here - and
  the profile keeps its existing `# UNVERIFIED` comment style for it
  (`python-uv.md:28-29` precedent). Canned lines:

      positive:  1234/1234  🎉 1000 🫥 0  ⏰ 0  🤔 0  🙁 234  🔇 0  🧙 0
      negative:  19/19  🎉 0 🫥 0  ⏰ 0  🤔 0  🙁 19  🔇 0  🧙 0

- **C-5 Oracle partition.** Every criterion is **mechanical**: pin exactly.
  AC-1: one line, C-3's text, count 1 / 0. AC-2: `PASS`/`FAIL` lines through
  the real `gates.sh`, with C-4's lines verbatim - RED does not invent other
  lines, and does not weaken a negative to make it "more realistic". AC-3:
  string equality. AC-4, AC-5: `grep -c` of pinned needles (C-6, C-7). The
  numbers 85.79, 156, 19, 22 and the toolchain versions are **settled**
  (the reporter's, cited); the cargo-mutants lines are **settled** (measured
  at PLANNED, above). Nothing is oracle-free.
- **C-6 node-typescript.md, what GREEN writes (line numbers verified at
  PLANNED, release 84).**
  (a) After `:16` (`ondemand | mutation | …`), one indented comment line in
  the same block or one sentence directly under it: "On TypeScript 7 or
  Vitest 5, `stryker run` as shipped does not work; see *The mutation gate on
  TypeScript 7 / Vitest 5* below." Needle for AC-4(a): `TypeScript 7`
  within `sed -n 15,26p`.
  (b) In the evidence block (`:30-33`) add
  `evidence | mutation | All files *[|][^|]*[|][^|]*[|] *[1-9][0-9]* [|]`
  with two comment lines: the third numeric column of the `All files` row is
  `# killed`, and no `floor` (reads the score). Needle: the regex line,
  `grep -cF`.
  (c) Replace `:45`'s first sentence, "Verified against vitest 5 and
  typescript 5 on Windows." with: "The `unit` and `coverage` lines were
  verified against vitest 5 and typescript 5 on Windows; the `mutation` line
  was not run here - its shape is derived from Stryker's clear-text reporter
  source and checked by `profiles.test.sh` against canned rows, not against a
  Stryker run." Needles for AC-4(d): `grep -c 'Verified against vitest 5 and
  typescript 5 on Windows\.'` is 0; `grep -c 'The .unit. and .coverage. lines
  were verified'` is 1.
  (d) New section `## The mutation gate on TypeScript 7 / Vitest 5`, placed
  after `## What --fast should leave out` (`:56-65`) and before `## The 5,000
  ms default…` (`:67`), containing: the toolchain the reporter measured on
  (Context), the sentence "These are the reporter's measurements (issue #104,
  section 2), not re-measured here: that toolchain is not installed in the
  harness repository."; the two failure modes (`TSConfigPreprocessor` /
  `ts.parseConfigFileTextToJson` whenever `tsconfigFile` names an existing
  file, `checkers: []` not enough; vitest-runner 10.0.0 under vitest 5.0.0
  runs no tests, reports 85.79% and 0 of 19, `--maxTestRunnerReuse 1` and
  `--coverageAnalysis off` do not fix it, `--logLevel debug` crashes it); the
  working configuration in one block:

      // stryker.config.mjs - the shape the reporter measured working
      export default {
        testRunner: "command",
        commandRunner: { command: "pnpm exec vitest related --run <the files named in mutate>" },
        coverageAnalysis: "off",      // no static-mutant bookkeeping; every kill is a real run
        timeoutMS: 60000,             // 5,000 default: 5 of 19 were false timeouts on Windows
        tsconfigFile: "tsconfig.none.json",  // a path that does NOT exist, on TS 7
        plugins: [],                  // the command runner is built in; under pnpm a runner
                                      // plugin, if you use one, must be listed here explicitly
      };

  and the reporter's results with it (19 of 19 killed on the small file; 155
  killed / 22 timeouts / 6 survivors on the 501-line one), the note that
  `tsconfigFile` pointing nowhere loses nothing when `tsconfig.json` has no
  `extends` or `references`, and C-4's honest limit of the evidence line.
  Needles for AC-4(b): `grep -c '^## The mutation gate on TypeScript 7 / Vitest 5$'`
  is 1 and each of `testRunner`, `commandRunner`, `coverageAnalysis`,
  `timeoutMS`, `tsconfigFile`, `plugins` has `grep -c` >= 1 in the file;
  AC-4(c): `grep -c 'not re-measured'` is 1.
- **C-7 SKILL.md and the pointers.** After `stack-profiles/SKILL.md:57`
  ("…two sets of gates with distinct ids, and one `paths.conf`.") a paragraph
  whose needles are `rust-mutation`, `--gate rust-mutation`, `HARNESS-039`
  and `judge the id \`mutation\` only` (each `grep -c` 1). In
  `node-typescript.md` and `rust-cargo.md`, one line beside the `ondemand`
  line: "Combining this with another profile's `mutation` gate: see the
  stack-profiles skill, *Choosing*." (needle `Combining this with`, count 1
  in each). The convention, stated once in SKILL.md: a second mutation gate's
  id **ends in `mutation`** (`rust-mutation`, `python-mutation`) so a later
  story can key the audit on the suffix; `mutation` itself stays the one
  `/audit-mutations` runs by default.
- **C-8 Two one-line document edits.** `new-profile.md:51-55`: the rule list
  gains "a `mutation` gate has an `ondemand` line and an `evidence` line
  whose regex requires a non-zero killed count". `quality-gates/SKILL.md:326`:
  the waiver example's reason, "stryker needs a TS compiler API TS 7 lacks;
  stack.md s4", is now contradicted by the profile; GREEN changes it to a
  reason that is still true, e.g. "stryker's vitest runner tests nothing
  under vitest 5; command runner not wired yet - node-typescript.md", keeping
  the line's shape. No test pins either edit; review does.
- **C-9 Floors.** `floors.conf` has `floor | profiles | 50` and
  `selftest.test.sh:545` has `profiles 50` in its hand-copied `COUNTS` table.
  RED measures the new executed count with `bash scripts/selftest.sh
  profiles` (the `N passed, M failed` sum) and raises **both** in the RED
  commit, with the usual comment block in `floors.conf` (its HARNESS-039 and
  HARNESS-040 blocks are the shape). Estimate, not a floor: AC-1 fixtures 3
  + per-profile 3, AC-2 three profiles x (one positive + one or two
  negatives) 7-9, AC-3 3, AC-4 ~10, AC-5 ~6 - roughly 32-35 new, so about
  82-85. The number RED records is the measured one.
- **C-10 Test-only dependencies.** None. The suite is bash + awk + the
  existing `_lib.sh`.

## Deferred verifications

Budget per `rules.md`, "Mutation work per story": one "defect put back"
(DV-1) and, because the story adds a rule over the tree, one probe against a
REAL line of it (DV-2). `## Gate probes` is omitted, as HARNESS-039 did: this
repository's own gates are unchanged, and the evidence line this story adds is
a profile's, exercised permanently by AC-2 through the real `gates.sh` and
once more by DV-1 here. Each runs against the one suite that holds its
assertion, `profiles`, through `scripts/mutate.sh`, which restores the file and
proves it.

- **DV-1 (defect put back: a regex that accepts a kill-less run).** Owner:
  GATES. With the real `node-typescript.md` evidence regex loosened so that a
  `0` in the killed column matches, AC-2's node-typescript negative assertion
  **must** go red (RED predicts the exact count in `## Handoff`; it should be
  the one or two negative-line assertions for that profile and nothing else -
  the positive stays green, which is the point) while rust-cargo's and
  python-uv's stay green. RED cannot run it: the line does not exist in RED.
  One `sed` expression:

      bash scripts/mutate.sh .claude/skills/stack-profiles/reference/node-typescript.md 's/\[1-9\]\[0-9\]\* \[|\]/[0-9]* [|]/' -- bash scripts/selftest.sh profiles

  (`[1-9][0-9]* [|]` occurs once in the file after GREEN - the `unit`/`coverage`
  lines end in `passed`, not `[|]`; GREEN keeps it so, and GATES checks
  `grep -cF '[1-9][0-9]* [|]'` prints `1` before mutating.) GATES pastes the
  mutated run's `profiles: N passed, M failed` with the failing names, the
  `mutate.sh` restore line, and a clean re-run. If the negative stays green
  under this mutation, the assertion is not reading the real line (AC-3) and
  that is a return to RED, not a note.
- **DV-2 (the presence rule against a real line of the tree).** Owner: GATES.
  With the real `rust-cargo.md` `evidence | mutation` line deleted, AC-1's
  per-profile assertion for `rust-cargo.md` **must** print C-3's message and go
  red, and AC-2's rust-cargo assertions go red with it (no regex to extract);
  the other two profiles stay green. RED cannot run it: the rule does not
  exist in RED. One `sed` expression:

      bash scripts/mutate.sh .claude/skills/stack-profiles/reference/rust-cargo.md '/^ *evidence *| *mutation *|/d' -- bash scripts/selftest.sh profiles

  GATES pastes the mutated run's failing names, the restore line, and a clean
  re-run. This is the probe `rules.md` ("A rule is probed against the tree it
  judges") owes: AC-1's fixtures were written from the same reading of the
  line shape as the rule, and only a real profile line says the rule can see
  the spelling the tree uses.

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

Planned by `bash scripts/plan.sh write HARNESS-041` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`, resolved to **Fable 5.1** (`claude-fable-5-1`), as
  planned; no override was reported to the dispatcher.

## Out of scope

- **Re-measuring anything on TS 7 / Vitest 5.** That toolchain is not
  installed here; every number in the new section is the reporter's and is
  attributed as such. A consumer that runs the configuration and finds a
  number wrong files it against the profile, not against the harness's
  measurements, because the harness made none.
- **Extending `gates.sh --audit` or `profiles.test.sh` to ids other than
  `mutation`** (`rust-mutation`, `mutants`). HARNESS-039 AC-4b's limit stands
  (Context, the id decision). The convention is named here so that the
  follow-up can key on the suffix; it is cut only when a consumer combines two
  profiles. `scripts/gates.sh` and `gates.test.sh` are not written.
- **An `evidence` line in this repository's own `project.conf`**, whose
  `mutation` gate has no command (`project.conf:272`) and whose evidence block
  is empty by design ("filled in by the bootstrap story").
- **Verifying the mutmut regex against a mutmut run**, or the Stryker regex
  against a Stryker run. Both are derived from the tools' source at a named
  date and marked so; the cargo-mutants one is measured. A consumer's
  bootstrap story corrects a profile line against real output, as the
  profiles already say for `lint` and `build`.
- **The `Ran N tests per mutant on average.` line** Stryker's reporter also
  prints (`clear-text-reporter.ts:150`), which would read `0.00` in the
  broken-runner case and catch the 85.79% shape this story's line cannot.
  Its presence depends on `clearTextReporter.reportMutants` and could not be
  confirmed here; the profile may mention it as a second, unverified needle
  for a consumer to confirm, but no `evidence` line is built on it.
- Changing the `ondemand`, `slow` or gate-command lines of any profile.
- Fixing any consumer's `project.conf` or `stryker.config`.

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

## Notes

- **PLANNED measurements (2026-10-06, release 84, gawk 5.4.1 on Windows).**
  All three C-4 regexes were run through the real `gates.sh` on a
  `make_project_fixture` with the gates `required`:

      PASS         mutation (1s, observed 85)        <- Stryker positive row; "85" is the score, hence no floor
      FAIL         mutation0 (0s, ran but produced no evidence of work: expected /All files *[|][^|]*[|][^|]*[|] *[1-9][0-9]* [|]/)
      PASS         mm (0s, observed 7)               <- mutmut positive
      FAIL         mm0 (0s, ran but produced no evidence of work: expected /🎉 [1-9][0-9]*/)
      PASS         cm (0s, observed 3)               <- cargo-mutants positive
      FAIL         cm0 (0s, ran but produced no evidence of work: expected /[1-9][0-9]* caught/)

  With the gates `optional` the same fixture printed `All required gates
  passed` three times and nothing a test could anchor on - which is why C-2
  says `required`.
- **cargo-mutants 27.1.0, measured at PLANNED** on a scratch crate
  (`pub fn add(a: u32, b: u32) -> u32 { a + b }` with one test):
  `4 mutants tested in 4s: 4 caught`; with the test's assertion removed,
  `4 mutants tested in 3s: 3 missed, 1 caught` (the `+ -> -` mutant still
  panics on underflow in debug, so a genuinely zero-kill line was not produced;
  its shape, `N mutants tested in T: N missed`, follows from `summary_string`
  omitting zero outcomes).
- Line numbers cited in the Contract were re-verified at PLANNED against this
  tree: `node-typescript.md:15-16` (gate + ondemand), `:30-33` (evidence
  block), `:45` (the "Verified against" sentence), `:56-65` (`--fast`
  section), `:60` (`slow | mutation`); `rust-cargo.md:14-15`, `:36-43`;
  `python-uv.md:13-14`, `:28-34`; `profiles.test.sh:33` (`rest`), `:43`
  (evidence parse), `:84-85` (the `mutation-ondemand` rule), `:123`
  (`has_mutation_gate`), `:136-153` (`base_profile`), `:174` (the three
  profiles), `:202-204` (per-profile mutation check); `stack-profiles/
  SKILL.md:56-57`; `new-profile.md:51-55`; `quality-gates/SKILL.md:325-326`;
  `gates.sh:157-158`, `:263-266`, `:279-283`, `:560`, `:580-584`;
  `selftest.test.sh:545`; `floors.conf` `floor | profiles | 50`.
