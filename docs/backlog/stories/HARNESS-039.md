---
id: HARNESS-039
title: The manifest audit flags a mutation gate with no ondemand line
slug: the-manifest-audit-flags-a-mutation-gate
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-039-the-manifest-audit-flags-a-mutation-gate
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/gates.sh, .claude/tests/gates.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/skills/quality-gates/SKILL.md, .claude/harness/project.conf]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

GitHub issue #104 (ryanczhang7/agentic-dev-harness), section 1, **Symptom B**,
measured on fantasy-world-builder at harness release 64 and re-checked against
release 70: the project's `project.conf` configures a `mutation` gate with a
`slow` line and no `ondemand | mutation | <why>` line, and nothing reports it.
`slow` only keeps the gate out of `--fast`; `ondemand` (HARNESS-015) is what
keeps it out of a FULL run - every story's GATES and every PR's CI job. The
project survived only because the tool was not installed and the gate carried
a waiver. The moment a consumer installs stryker, mutmut or cargo-mutants and
removes the waiver, every full `gates.sh` run executes a mutation tool that
takes minutes to tens of minutes, which is the per-story cost HARNESS-015
exists to remove (`rules.md`, "Mutation work per story": on HARNESS-014 that
class of work was 2h20 of a 7.5h story and found no defect).

A second, independent instance, read read-only at PLANNED: **manga-translator**
(`D:\manga-translator`, harness release 82, 2026-10-06) has
`gate | mutation | optional | . | uv run mutmut run` (`project.conf:320`),
`slow | mutation | re-runs the suite once per mutant` (`:330`), a waiver
(`:656`) and **no** `ondemand | mutation` line. Today's `gates.sh --audit` on
that file prints only `WARN mutation  no evidence line` and `Manifest audit
passed.`, exit 0 (baseline pasted under DV-2).

The rule already exists once, for the stack profiles:
`.claude/tests/profiles.test.sh:84-85` fails a profile that "configures a
`mutation` gate with no `ondemand | mutation | <why>` line, so every full run
executes it" (HARNESS-015 AC-3). It judges the profile text in this
repository. Nothing judges the `project.conf` a consuming project actually
runs, which `refresh-harness.sh` deliberately leaves alone (it is LEFT, so a
profile line added upstream after the project was vendored never arrives).

**Where the check lives: `gates.sh --audit`.** Every project runs it: CI does
(`.github/workflows/gates.yml:138`, the step before the full run at `:141`),
`ci-local.sh` does, and it is the one place that already judges the manifest
for exactly this family of fault - a `slow` line with no reason, an `ondemand`
line naming no gate ("worse than silent: the gate it meant stays on every full
run, which is the cost the line exists to stop", `gates.sh:694-702`).
`doctor.sh` was the alternative and is the wrong home: it reports the
toolchain, is not run by CI, and a consumer who never runs it is exactly the
consumer this story is for.

**FAIL, not WARN.** Three reasons, weighed against the cost that a FAIL breaks
a consumer's CI on its next refresh until one line is added:

1. The audit already treats the identical consequence as a FAIL: an
   `ondemand` line with a typo in the id (`gates.sh:700`) FAILs because the
   gate it meant stays on every full run. A missing line has the same effect
   as a misspelt one, and the audit cannot sensibly FAIL the typo and WARN the
   omission.
2. The issue's complaint is literally that *nothing reports it*. A WARN in
   `--audit` is printed into the log of a CI job that passes, and nobody reads
   a green job's log; the one WARN kind the audit has today (no evidence line)
   is also the one fault consumers have carried for weeks unnoticed.
3. The fix is one line, the FAIL message names it exactly, the gate is
   optional so the line costs nothing, and `rules.md` already says every stack
   profile marks the gate `ondemand`. Both known consumers: fantasy-world-builder
   added the line in WORLD-111; manga-translator will see this FAIL on its
   next refresh and fix it in one line. A project that genuinely wants a
   mutation tool on every full run has no way to say so under the id
   `mutation`, and that is deliberate: it renames the gate (AC-4b pins that
   the rule then leaves it alone) and so owns the per-story cost out loud.

**How "a mutation gate" is identified: the gate id is exactly `mutation`.**
The same rule as `profiles.test.sh:84` (`("mutation" in gates)`), the id every
profile prescribes (`node-typescript.md:15`, `python-uv.md:13`,
`rust-cargo.md:14`), the id `/audit-mutations` runs (`--gate mutation`) and the
id the harness's own template `project.conf:271` ships. Mechanical and
spelled once. What it does **not** catch, deliberately: a gate under another
id (`rust-mutation`, `mutants`, `ts-mutation`) or a command that happens to
name stryker/mutmut/cargo-mutants under some other id. Matching the command
would be a heuristic that breaks on wrappers (`pnpm run mutation`) and matching
`*mutation*` would be a second rule the profiles suite does not have; the
convention for a project combining two profiles' mutation gates is the
out-of-scope item from the same issue, and the rule here extends in both
places when that story names the convention. AC-4b pins the limit so that
story changes it deliberately rather than by accident.

**Scope of the rule.** Audit only (`--audit`), like the orphan checks it sits
beside; a full run is unchanged (CI runs the audit first, so a bad manifest
never reaches the full run there). Regardless of whether the gate has a
command: an empty-command `mutation` gate costs nothing today and the cost
arrives the day the command is filled in, by a bootstrap story that is not
thinking about `ondemand`; the template already carries the line, so a fresh
project passes. Regardless of `required`/`optional`: a required `mutation`
gate without the line gets this FAIL, and adding the line then gets the
existing "an on-request gate cannot be required" FAIL - two faults, two
messages, both true.

The required gate that fails if this story's artifact breaks: the harness's
own `selftest` (the `gates` suite), run by CI at `gates.yml:72` and `:104`.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

- **AC-1 (the bug)** — Given a `project.conf` with
  `gate | mutation | optional | . | <command>`, an `evidence | mutation | …`
  line, `slow | mutation | <why>` and **no** `ondemand | mutation` line, when
  `bash scripts/gates.sh --audit` runs, then it prints exactly one line
  `FAIL mutation     no `ondemand | mutation | <why>` line, so every full run executes it; `slow` alone only leaves it out of --fast`
  (the message of C-3, anchored `^FAIL +mutation +…$`), counts it in
  `N manifest problem(s).`, and exits 1. Today this manifest passes the
  audit with exit 0 - that is the defect reproduced.
- **AC-2 (control: the line is what passes)** — Given the same manifest plus
  `ondemand | mutation | <why>`, when `--audit` runs, then the message of
  AC-1 appears 0 times, no `FAIL` names `mutation`, the output contains
  `Manifest audit passed.` and the exit status is 0. (`gates.test.sh:915-925`
  is already this manifest; RED adds the count-0 assertion on the new message
  rather than relying on the existing `^FAIL +mutation` count.)
- **AC-3 (control: only the mutation gate)** — Given a manifest whose `unit`,
  `build` and `integration` gates (and any other non-`mutation` id) have no
  `ondemand` line, with or without a `mutation` gate that has one, when
  `--audit` runs, then the message of AC-1 appears 0 times and nothing FAILs
  those gates for lacking the line; and a manifest with **no** `mutation`
  gate at all passes the audit (the rule demands the line of a gate that
  exists, never the gate).
- **AC-4 (the rule is on the id)** — (a) Given
  `gate | mutation | optional | . |` with an **empty** command (the shape the
  harness's template ships before bootstrap) and no `ondemand | mutation`
  line, when `--audit` runs, then it prints the AC-1 line and exits 1: an
  unconfigured mutation gate is flagged, because the cost arrives the day the
  command is filled in. (b) Given `gate | mutants | optional | . | cargo mutants`
  with no `ondemand` line and no gate whose id is `mutation`, when `--audit`
  runs, then the AC-1 message appears 0 times and the audit passes: a mutation
  tool under another id is **not** caught, and this assertion is the written
  limit of the rule.
- **AC-5 (this repository and the profiles still pass)** — Given this
  repository's own `.claude/harness/project.conf` (`gate | mutation` at
  `:271`, `ondemand | mutation` at `:282`), when `bash scripts/gates.sh --audit`
  runs at the repository root, then it exits 0 and prints `Manifest audit
  passed.` - the CI step at `gates.yml:138` on this tree; and
  `bash scripts/selftest.sh profiles` is unchanged (50 executed, 0 failed),
  because the four stack profiles already carry the line the audit now
  demands of consumers.

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

**Writes:** `scripts/gates.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/skills/quality-gates/SKILL.md`, `.claude/harness/project.conf`

Every path classifies as `harness` (`bash scripts/classify.sh` on each, at
PLANNED), so the phase lock freezes none of them in any phase. The role
boundary is honoured by the agents: RED writes only `gates.test.sh`,
`floors.conf` and `selftest.test.sh`; GREEN writes only `gates.sh` and the two
documentation edits (C-6). No signature of any existing export changes; there
is no caller list.

- **C-1 Where (`scripts/gates.sh`, verified at PLANNED against release 82).**
  The post-loop audit block, `if [ "$AUDIT" = 1 ]; then` at `:683`. The new
  check goes **after** the `ondemand`-orphan loop (`:694-702`, ends
  `done <<< "$ONDEMANDS"`) and **before** the `ci-factor` comment at `:703`.
  Everything it needs is already in scope there: `GATE_IDS` (every gate id,
  space-separated, built at `:153`), `ONDEMANDS` (`<id><TAB><why>` lines,
  `:168`), `table_lookup` (`:255-261`; prints the value, returns 0 if found,
  1 if not) and `fails`. Inside the `AUDIT` block only - a full run is
  unchanged (Context, "Scope of the rule").
- **C-2 Shape.** One loop, no new function, no new table:

      # HARNESS-039 / issue #104 Symptom B: ...
      for gid in $GATE_IDS; do
        [ "$gid" = mutation ] || continue
        table_lookup "$ONDEMANDS" "$gid" >/dev/null && continue
        printf 'FAIL %-12s <message of C-3>\n' "$gid"; fails=$((fails+1))
      done

  The literal `[ "$gid" = mutation ]` is load-bearing: DV-1 and DV-3 mutate
  exactly that test with one `sed` expression each, so GREEN keeps the
  comparison on one line in that spelling (`= mutation ]`, once in the file -
  `grep -c '= mutation \]' scripts/gates.sh` prints `1` after GREEN). The id
  is compared exactly; no glob, no command inspection (Context).
- **C-3 Message**, pinned byte for byte so RED's needle and GREEN's `printf`
  cannot drift. After `FAIL ` and the `%-12s` id (`mutation` padded to 12,
  i.e. followed by five spaces), the text is:

      no `ondemand | mutation | <why>` line, so every full run executes it; `slow` alone only leaves it out of --fast

  RED anchors it: `count_re '^FAIL +mutation +no `ondemand \| mutation \| <why>` line, so every full run executes it; `slow` alone only leaves it out of --fast$'`
  (the `|` escaped for awk's ERE; `count_re` is `gates.test.sh:618`). The
  wording reuses `profiles.test.sh:85` ("… with no `ondemand | mutation | <why>`
  line, so every full run executes it") and adds the one clause the issue
  shows was misunderstood - that `slow` is not enough. It is a FAIL, counted
  in `fails`, so the existing `\n%d manifest problem(s).\n` / `exit 1` at
  `:759-760` carries it; nothing new is printed at the summary.
- **C-4 Semantics behind each decision** (each one sentence, so a reviewer
  can disagree with one line): id exactly `mutation`, because that is the one
  id every profile, the template and `/audit-mutations` use, and the profiles
  suite already judges it; regardless of command, because the cost arrives
  when the command is filled in; regardless of `required`, because a required
  mutation gate is two faults and gets two messages; FAIL not WARN, because a
  typo'd `ondemand` id already FAILs for the same consequence (`:700`) and a
  WARN in a passing CI log is the "nothing reports it" the issue filed.
- **C-5 Oracle partition.** Every criterion is **mechanical**: pin exactly.
  AC-1, AC-4a: exactly one line matching the C-3 regex, `count_re` of
  `^1 manifest problem\(s\)\.$` is 1 on a manifest with no other fault, exit
  1. AC-2, AC-3, AC-4b: C-3 regex count 0, `^Manifest audit passed\.$`
  count 1, exit 0. Nothing is settled-by-measurement and nothing is
  oracle-free; a threshold or a metric does not appear. RED should not
  invent one.
- **C-6 Documentation GREEN updates, in the same cycle** (both `harness`,
  both already describing this mechanism and both now one sentence short):
  `.claude/skills/quality-gates/SKILL.md:58` - after "`--audit` refuses one on
  a required gate", add that it refuses a `mutation` gate with no `ondemand`
  line; `.claude/harness/project.conf:135` - after "A mutation gate carries
  both lines, `slow` and `ondemand`.", add that `gates.sh --audit` refuses one
  that lacks the `ondemand` line. The `gates.sh` header (`:38-42`) gets the
  same half-line. No wiki page changes; `docs/wiki/` is not in `touches:`.
- **C-7 Counts (RED).** `gates` is floored at 470 (`.claude/tests/floors.conf:44`)
  and recorded at 470 in `selftest.test.sh` COUNTS (`:529-554`, line
  `gates 470`). The floor is the EXECUTED count (passed + failed) of
  `bash scripts/selftest.sh gates`. RED raises both to the number it measures
  on its own red run - the new assertions execute and fail, so they count -
  and writes the before/after in `## Handoff` the way `floors.conf:228-235`
  records earlier raises. `profiles` stays 50 (AC-5). Nothing else in COUNTS
  moves.
- **C-8 Line numbers that must not move.** `sigpipe.test.sh:567-568` pins
  `scripts/gates.sh:74` (`BOOTSTRAPPED="$(grep`) and `scripts/gates.sh:580`
  (`why="could not launch: $(`) as status-discarded lines. C-1 inserts at
  `:703`, below both, so neither moves and `sigpipe.test.sh` is not in
  `touches:`. If GREEN finds it must edit above `:580` (the header, C-6, is
  above `:74` - keep that edit to the EXISTING lines `:38-42` without adding
  a line, or add the line and update the `:580` pin in `sigpipe.test.sh` and
  add it to `touches:`; `:74` must not move either way), say so in
  `## Notes`.
- **C-9 Fixtures.** `make_project_fixture` + `write_conf` + `gates --audit`,
  as `gates.test.sh:869-925` does for HARNESS-015 AC-2; every gate command a
  `printf`. The AC-1 manifest is the AC-2 manifest at `:915-920` with the
  `ondemand` line replaced by `slow | mutation | re-runs the suite once per mutant`.
  The platform-independent `awk` rule applies (CI's `mawk`): `count_re` as
  written, no `gensub`, no `--re-interval`.
- **C-10 Test-only dependencies.** None; bash, awk and coreutils.

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

Budget per `rules.md`, "Mutation work per story": one "defect put back" (DV-1),
one earned-control mutation for the assertions that pass on arrival (DV-3),
and - because this story adds a rule over a tree - one probe against a REAL
tree (DV-2). `## Gate probes` is omitted: the story adds or changes no gate,
command or evidence line; the real-tree probe lives here, in DV-2, and nowhere
else.

- **DV-1 (defect put back).** Owner: GATES. With the id comparison of C-2
  pointed at an id no manifest has, AC-1's and AC-4a's assertions **must** go
  red and AC-2, AC-3 and AC-4b stay green; RED cannot run it because the rule
  does not exist in RED. One `sed` expression, through `mutate.sh`, against
  the one suite holding the assertions:

      bash scripts/mutate.sh scripts/gates.sh 's/= mutation \]/= no-such-gate ]/' -- bash scripts/selftest.sh gates

  RED predicts the exact count that goes red (the AC-1 line count, its
  `1 manifest problem(s)`, its exit 1, AC-4a's line count and exit - at least
  four) in `## Handoff`; GATES pastes the mutated run's `gates: N passed, M
  failed` with the failing names, the `mutate.sh` restore line, and a clean
  re-run.
- **DV-2 (the rule against a real tree, read-only).** Owner: GATES.
  manga-translator's real `.claude/harness/project.conf` (gate at `:320`,
  `slow` at `:330`, no `ondemand`; `D:\manga-translator`, release 82) copied
  verbatim into a `make_project_fixture` of THIS tree and audited with this
  tree's `gates.sh` **must** print exactly one C-3 line naming `mutation` and
  exit 1. Read-only on manga-translator: nothing there is written. Not a
  permanent test, because a suite cannot depend on a sibling checkout. Run as
  at PLANNED:

      cd <this worktree> && . .claude/tests/_lib.sh && FIX="$(make_project_fixture)" \
        && cp /d/manga-translator/.claude/harness/project.conf "$FIX/.claude/harness/project.conf" \
        && (cd "$FIX" && bash scripts/gates.sh --audit); echo "exit=$?"; rm -rf "$FIX"

  Baseline, measured at PLANNED (2026-10-06) with release 82's `gates.sh`,
  i.e. before the change - the audit passes the file that has the defect:

      ok   build        evidence: Building EXE from|completed successfully
                        slow:   PyInstaller freezes an interpreter and later ~1 GB of weights; 34 s at MT-001 with PySide6 alone, minutes once the weights land
      WARN mutation     no evidence line; a vacuous pass would go unnoticed

      Manifest audit passed.
      exit=0

  After GREEN the same command must show the C-3 FAIL (the `WARN … no
  evidence line` for the same gate stays, printed in the per-gate loop; the
  FAIL is printed after the loop) and `1 manifest problem(s).`, `exit=1`.
- **DV-3 (earning the controls).** Owner: GATES. AC-2, AC-3 and AC-4b assert
  that nothing is flagged, and they pass on arrival in RED against a
  `gates.sh` that flags nothing - the law in `rules.md` ("a test written
  against code that already exists") owes them one mutation. With the
  comparison inverted so that every gate EXCEPT `mutation` is judged, AC-3's
  count-0 assertions (and AC-1's, inversely) **must** go red:

      bash scripts/mutate.sh scripts/gates.sh 's/= mutation \]/!= mutation ]/' -- bash scripts/selftest.sh gates

  GATES pastes the mutated run's failing names, the restore line, and a clean
  re-run. If AC-3's assertions stay green under this mutation they assert
  nothing, and the story returns to RED.

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

Planned by `bash scripts/plan.sh write HARNESS-039` from `.claude/harness/models.conf`.
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

- PLANNED: `lead-po` dispatched as `/plan-story`, resolved to Fable 5.1
  (`claude-fable-5-1`), as planned; no override visible to the agent.
- Oracle partition for the RED brief: every criterion is mechanical (C-5);
  nothing is settled-by-measurement, nothing is oracle-free. Brief RED to pin
  the C-3 message byte for byte and to invent no metric.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

Everything else in issue #104, each a later story of its own:

- **Symptom A** - `refresh-harness.sh` delivering harness-shipped files under
  `docs/` that a consumer lacks (`docs/wiki/audits/TEMPLATE.md`), and the
  general "print profile lines added since the vendored release" refresh
  report. This story judges the manifest a consumer HAS; it does not deliver
  the line.
- **Section 2** - the TypeScript profile's mutation gate on TS 7 / Vitest 5:
  the `tsconfigFile` caveat, the command runner, and an `evidence` line that
  requires a non-zero killed count. Not touched; `node-typescript.md` is not in
  `touches:`.
- **Combining two profiles' mutation gates** (`mutation` + `rust-mutation`,
  or whatever that story decides). Until it decides, a mutation gate under any
  id other than `mutation` is not flagged, and AC-4b says so.
- A dangling-reference selftest for files commands name under `docs/`.
- Making a FULL run (not `--audit`) fail on this fault; the audit runs first
  in CI and in `ci-local.sh`.
- Fixing manga-translator's or any consumer's `project.conf`. DV-2 reads it
  and writes nothing; the consumer adds its own line on refresh.
- Any change to `doctor.sh`, `refresh-harness.sh`, the stack profiles, or
  `profiles.test.sh` (its rule is reused, not edited).

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

- Planned 2026-10-06 in worktree `nostalgic-williams-fcf700` at release 82
  (`75d6e17`). All line numbers in `## Contract` were read on that tree.
- GATES -> REVIEW runs the full selftest first (`SELFTEST_JOBS=4 bash
  scripts/selftest.sh`, 8-12 minutes on this machine); CI runs all suites on
  Ubuntu and, for manga-translator's vendored copy, on `windows-latest`.
- The PR body closes nothing in #104 by itself: Symptom B is one of four
  items. Say "addresses #104 section 1 Symptom B" and leave the issue open for
  the stories in `## Out of scope`.

**User decision, 2026-10-06 (orchestrator asked before RED).** FAIL, not WARN,
chosen by the user with the trade-off stated: a consuming project's CI goes red
on its next refresh until it adds the one `ondemand | mutation` line, and
manga-translator is such a project today.
