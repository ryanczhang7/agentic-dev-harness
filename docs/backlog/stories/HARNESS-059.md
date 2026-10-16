---
id: HARNESS-059
title: mutate.sh leaves the tree as it found it - --check sees dot-named sentinels and writing sed commands are refused
slug: mutate-sh-leaves-the-tree-as-it-found-it
epic: 
type: fix
status: done
phase: DONE
branch: story/HARNESS-059-mutate-sh-leaves-the-tree-as-it-found-it
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/mutate.sh, .claude/tests/mutate.test.sh, .claude/tests/gates.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

Filed by the mutation audit `docs/wiki/audits/harness-mutants-2026-10-15.md`
(findings F1, F5 and survivor M11). The required gate holding this story's
artefact is the harness self-test (`mutate` suite); `gates.sh` reads
`mutate.sh --check` before every run, so a wrong answer there reaches every gate.

**F1, seen in the wild during the audit.** A `mutate.sh` run against
`.claude/tests/gates.test.sh` died mid-command (a Cygwin fork failure), leaving
the file mutated and these sentinels behind:

    .claude/state/mutations/.claude_tests_gates.test.sh.20261016T053548Z.1527829.active
    .claude/state/mutations/.claude_tests_gates.test.sh.20261016T053548Z.1527829.bak

`bash scripts/mutate.sh --check` then printed
`mutate: no stranded mutation; nothing of a previous run is in the tree.` and
exited 0. The sentinel name is the target path with `/` turned to `_`, so every
target under `.claude/` (every hook, every test) gets a name starting with `.`.
`--check` enumerates with `for a in "$MUTDIR"/*.active`, and a bash glob does
not match a leading dot. The `scripts/` targets the audit mutated were all seen;
the `.claude/` ones never can be.

**F5.** `mutate.sh` applies any sed expression. One with an `s` command whose
pattern ran into a `#` delimiter (`768s#while ... "${#fly_ids[@]}" ...#while
false#`) parsed the remainder as flags, and the `w` flag wrote an untracked file
named `hile false#` at the repository root, twice. `mutate.sh` restored and
verified the target file and reported success; the stray file stayed. The
script's promise, "restores the file and proves it did", covers the target only.

**M11.** Replacing `[ "${1:-}" = "--" ] || die` with `true || die` survives the
`mutate` suite (189 passed, 0 failed): nothing pins that a missing `--` is
refused, and without the check the first word of the command is silently eaten.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->


- **AC-1** — Given a stranded mutation of a file under a dot-directory (a
  `.active` sentinel whose name starts with `.`, its process gone, the target
  differing from its backup), when `mutate.sh --check` runs, then it reports the
  mutation as unaccounted for, names the target `.claude/...` path, and exits 1.
  Fails today (it prints "no stranded mutation" and exits 0). *Negative
  control:* the same fixture with the sentinel for a `scripts/` target is
  reported today and must still be.
- **AC-2** — Given the same stranded sentinel, when `gates.sh` starts, then it
  refuses to run, as it does today for a stranded `scripts/` mutation.
- **AC-3** — Given a sed expression that writes or executes (`w`/`W` commands or
  flags, `e`, or `r`/`R`, in any of the delimiters sed accepts), when
  `mutate.sh FILE EXPR -- CMD` runs, then it refuses before touching FILE, exits
  non-zero, and no new file exists in the tree afterwards. The expression
  `1s#a#b#w out` is the minimal case. *Negative control:* `1s#a#b#g` and
  `1s/a/b/2` are still accepted.
- **AC-4** — Given `mutate.sh FILE EXPR CMD` with no `--`, then it exits
  non-zero naming the missing `--`, and FILE is unchanged.

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

**Writes:** `scripts/mutate.sh`, `.claude/tests/mutate.test.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`

RED may amend any block below in place, with a reason; GREEN builds what the
amended block says. Anchors verified by reading the tree at `2d2d1fb` (main
after #145), 2026-10-16.

**C-1. `--check` enumerates every sentinel (GREEN, `scripts/mutate.sh`).**
`mutate.sh:122` reads `for a in "$MUTDIR"/*.active; do`. Sentinel names are
`$SAFE.$STAMP.$$.active`, with `SAFE` the target's repository-relative path with
`/`, `\` and space turned to `_` (`:218`). A target under `.claude/` therefore
names a dotfile, which a bash glob skips. After this story the loop visits both
`"$MUTDIR"/*.active` and `"$MUTDIR"/.*.active`, each entry guarded by the existing
`[ -f "$a" ] || continue`, and **without** `shopt -s dotglob`. `dotglob`
would change every other glob in the script, and `.`/`..` are not
`.active` files. Nothing else in `--check` changes: the report lines, the
`found` count, exit 1, and "the file DIFFERS from the original. Put it back:" all
apply as they do for a `scripts/` target. A dot-named sentinel is reported with
its `file` value (`.claude/...`), as recorded in the sentinel.

**C-2. Writing, reading and executing sed commands are refused (GREEN).** The
apply step (`mutate.sh:331`, `sed -e "$EXPR" "$BAK" > "$NEW"`) becomes
`sed --sandbox -e "$EXPR" "$BAK" > "$NEW"`. GNU sed's sandbox mode rejects `e`,
`r`, `R`, `w` and `W`, as commands and as `s` flags, **at parse time**, before
anything is written. Measured on this host (GNU sed 4.9, Git Bash):
`sed --sandbox '1s/a/b/w /tmp/x'` prints
`sed: -e expression #1, char 8: e/r/w commands disabled in sandbox mode`,
exits 1, and `/tmp/x` does not exist afterwards. The same holds for `1e date`,
`1R /etc/hosts` and `1W /tmp/y`, while `1s#a#b#g` runs. CI's Ubuntu ships GNU
sed 4.8, and `--sandbox` exists since 4.3. The existing rejection path then
applies unchanged: `mutate: sed rejected the expression:`, sed's text indented,
the backup removed, exit 2, FILE untouched, and no `.active` written (the
sentinel is written later, `:435`).

**PO decision 1 (2026-10-16): a sed with no `--sandbox` makes `mutate.sh`
refuse, rather than run unguarded.** BSD sed (macOS) has no sandbox mode. A
lexical scan of a sed script for `w` is exactly the kind of private parser
`rules.md` warns about. Running unguarded would make AC-3 true only on some
hosts. So before the apply step `mutate.sh` probes `sed --sandbox -e ''
</dev/null >/dev/null 2>&1`. If that fails, it exits 2 with
`mutate: this sed has no --sandbox mode, so an expression could write files the restore never sees; install GNU sed (gsed) and put it first on PATH`
and touches nothing. RED can pin this with a fake `sed` on `PATH` that
rejects `--sandbox` and passes everything else through to the real one. This is
a portability cost on macOS, stated here so it can be overruled before GREEN.

**C-3. The `--` separator (no code change).** `mutate.sh:191` already refuses
a missing `--` with exit 2 and
`mutate: the command must be separated from the expression by -- <command>`.
AC-4 pins it. It passes on arrival and is earned by DV-3.

**C-4. AC-2 lives in `gates.test.sh`**, beside the HARNESS-030 sentinel
blocks (`:2700-2740`, which use `h30_plant`, `h30_fresh` and `H30MUT`). The
fixture plants a GONE (dead-pid) sentinel named
`.claude_hooks_lib.sh.<STAMP>.<pid>.active`, with its `.bak` differing from the
fixture's file. `gates.sh` then exits non-zero through the existing
`mutation_report` refusal (`gates.sh:233`), and its output names
`.claude/hooks/lib.sh`. The block's own trailing "no sentinel is left" check
(`:2735`) also globs `*.active` only. Widen it to see dot-named sentinels too,
or it would report a clean fixture over a stranded one: the same defect, in
the test.

**C-5. Floors.** Every new assertion raises its suite's floor in
`.claude/tests/floors.conf` (`mutate` at `:47`, `gates` at `:44`) and in the
mirror in `.claude/tests/selftest.test.sh` (`gates` at `:535`, `mutate` at `:538`), to the EXECUTED count
RED reads off its own run, as HARNESS-055 to 058 did. Record the measurement in
the comment block at the foot of `floors.conf`.

**Oracle partition.** All four criteria are mechanical (exit codes, exact
lines, file existence, byte equality). No metric is invented. The negative
controls are named in the ACs: a `scripts/` sentinel still reported, `g` and
numeric `s` flags still accepted, and `--` present still runs.

**Callers of changed signatures.** None. The CLI (`mutate.sh FILE EXPR --
CMD`, `--check`) keeps its arguments, exit codes and messages; only the set of
accepted expressions narrows. Callers that pass an expression, all checked by
`git grep -n 'mutate.sh'` to use `s` and `{...}` forms only: `gates.sh:233`
(`--check`), `.claude/commands/*.md`, `rules.md` and the stories' recorded
`## Deferred verifications`. `.claude/state/README.md` needs no new row: no new
state file.

**Required gate.** The harness self-test, `mutate` and `gates` suites, run by
CI's `selftest` job; `gates.sh` has no configured gates for this repository
(`gates.sh --list`: every gate `<unconfigured>`), as for every HARNESS story.

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

`mutate.sh` refuses to mutate itself (`:211`), so each entry below runs a
byte-identical copy of it, the audit's method: `mkdir -p
.claude/state/selfmut/scripts && cp scripts/mutate.sh
.claude/state/selfmut/scripts/ && cmp scripts/mutate.sh
.claude/state/selfmut/scripts/mutate.sh`. Then `bash
.claude/state/selfmut/scripts/mutate.sh scripts/mutate.sh 'EXPR' -- bash
.claude/tests/mutate.test.sh` (`gates.test.sh` for DV-1b). Remove the copy
afterwards.

- **DV-1, the defect put back.** With the `.*.active` half of C-1's loop
  removed (`--check` back to `"$MUTDIR"/*.active` alone), AC-1's "reported as
  unaccounted for" assertion MUST fail in `mutate.test.sh`. DV-1b: the same
  mutation MUST fail AC-2's refusal assertion in `gates.test.sh`.
  Owner: GATES. Cannot run in RED: C-1 is not built.
- **DV-2.** With `--sandbox` removed from the apply step, AC-3's "no file
  exists at the `w` target" assertion MUST fail. Owner: GATES.
- **DV-3, AC-4 earned.** AC-4 passes on arrival. With `[ "${1:-}" = "--" ] ||
  die` replaced by `true || die` (the audit's M11), AC-4 MUST fail.
  Owner: GATES.


**Results (GATES, orchestrator, 2026-10-16).** Each mutation of the real
`scripts/mutate.sh`, run by a `cmp`-identical copy under `.claude/state/selfmut/`
(removed afterwards), turned red exactly the assertions of the criterion it
targets and nothing else, and the file came back byte for byte. The AC-3 FAIL
lines under DV-2 are abridged to one line per expression; the full output was
45 FAIL lines, five per write/execute expression and four per read one. The
`$` lines name the target as `scripts/mutate.sh`; the copy was passed the
absolute `$ROOT/scripts/mutate.sh`, as each `===` line shows, because it
resolves a relative path against its own root.

```
$ cmp scripts/mutate.sh .claude/state/selfmut/scripts/mutate.sh   # identical
--- DV-1
$ bash .claude/state/selfmut/scripts/mutate.sh scripts/mutate.sh '127s| "$MUTDIR"/\.\*\.active||' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"
=== mutate: $ROOT/scripts/mutate.sh (1 line(s) changed by 127s| "$MUTDIR"/\.\*\.active||) ===
  127 -   for a in "$MUTDIR"/*.active "$MUTDIR"/.*.active; do
  127 +   for a in "$MUTDIR"/*.active; do
=== mutate: running bash -c cd $ROOT && bash .claude/tests/mutate.test.sh ===
    FAIL HARNESS-059 AC-1: a stranded dot-named sentinel makes --check exit 1
    FAIL HARNESS-059 AC-1: and --check does not print the clean line on stdout
    FAIL HARNESS-059 AC-1: it opens with the unaccounted-for line
    FAIL HARNESS-059 AC-1: it names the .claude/ target, as recorded
    FAIL HARNESS-059 AC-1: and reports its process as GONE
    FAIL HARNESS-059 AC-1: the file differs from its backup, and it says so
    FAIL HARNESS-059 AC-1: with the exact cp && cmp && rm -f remedy naming the dot-named sentinel
    FAIL HARNESS-059 AC-1: and counts it
    FAIL HARNESS-059 AC-1 (C-1): it names the .claude/ target
    FAIL HARNESS-059 AC-1 (C-1): and counts two
    FAIL HARNESS-059 AC-1 (C-1): a dot-named sentinel whose file matches still exits 1
    FAIL HARNESS-059 AC-1 (C-1): and prints the exact rm -f remedy for it
mutate: 296 passed, 12 failed
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harne
scripts/mutate.sh matches HEAD after the run
--- DV-1b
$ bash .claude/state/selfmut/scripts/mutate.sh scripts/mutate.sh '127s| "$MUTDIR"/\.\*\.active||' -- bash -c "cd $ROOT && bash .claude/tests/gates.test.sh"
=== mutate: $ROOT/scripts/mutate.sh (1 line(s) changed by 127s| "$MUTDIR"/\.\*\.active||) ===
  127 -   for a in "$MUTDIR"/*.active "$MUTDIR"/.*.active; do
  127 +   for a in "$MUTDIR"/*.active; do
=== mutate: running bash -c cd $ROOT && bash .claude/tests/gates.test.sh ===
    FAIL HARNESS-059 AC-2: behind a stranded .claude/ mutation gates.sh exits 2
    FAIL HARNESS-059 AC-2: it prints the refusal, whole
    FAIL HARNESS-059 AC-2: after --check's unaccounted-for line
    FAIL HARNESS-059 AC-2: which names .claude/hooks/lib.sh
    FAIL HARNESS-059 AC-2: no line says the run recorded
    FAIL HARNESS-059 AC-2: and the gate command never ran (marker absent)
    FAIL HARNESS-059 AC-2: gates.sh --gate unit is refused too, exit 2
    FAIL HARNESS-059 AC-2: --gate unit prints the refusal, whole
    FAIL HARNESS-059 AC-2: and --gate unit never ran the gate
gates: 673 passed, 9 failed
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harne
scripts/mutate.sh matches HEAD after the run
--- DV-2
$ bash .claude/state/selfmut/scripts/mutate.sh scripts/mutate.sh '349s|sed --sandbox -e|sed -e|' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"
=== mutate: $ROOT/scripts/mutate.sh (1 line(s) changed by 349s|sed --sandbox -e|sed -e|) ===
  349 - if ! sed --sandbox -e "$EXPR" "$BAK" > "$NEW" 2>"$NEW.err"; then
  349 + if ! sed -e "$EXPR" "$BAK" > "$NEW" 2>"$NEW.err"; then
=== mutate: running bash -c cd $ROOT && bash .claude/tests/mutate.test.sh ===
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): exits 2
    FAIL HARNESS-059 AC-3 1s/a/b/w h59-w-slash (w flag, /): exits 2
    FAIL HARNESS-059 AC-3 1s|a|b|gw h59-w-pipe (gw flags, |): exits 2
    FAIL HARNESS-059 AC-3 1w h59-w-cmd (w command): exits 2
    FAIL HARNESS-059 AC-3 1W h59-W-cmd (W command): exits 2
    FAIL HARNESS-059 AC-3 1e touch h59-e-cmd (e command): exits 2
    FAIL HARNESS-059 AC-3 1s/.*/touch h59-e-flag/e (e flag): exits 2
    FAIL HARNESS-059 AC-3 w on the second line of a two-line expression: exits 2
    FAIL HARNESS-059 AC-3 1r src/main.ts (r command): exits 2
    FAIL HARNESS-059 AC-3 1R src/main.ts (R command): exits 2
mutate: 263 passed, 45 failed
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harne
scripts/mutate.sh matches HEAD after the run
--- DV-3
$ bash .claude/state/selfmut/scripts/mutate.sh scripts/mutate.sh '196s#\[ "${1:-}" = "--" \] || die#true || die#' -- bash -c "cd $ROOT && bash .claude/tests/mutate.test.sh"
=== mutate: $ROOT/scripts/mutate.sh (1 line(s) changed by 196s#\[ "${1:-}" = "--" \] || die#true || die#) ===
  196 - [ "${1:-}" = "--" ] || die "the command must be separated from the expression by -- <command>"
  196 + true || die "the command must be separated from the expression by -- <command>"
=== mutate: running bash -c cd $ROOT && bash .claude/tests/mutate.test.sh ===
    FAIL HARNESS-059 AC-4: no -- before the command exits 2
    FAIL HARNESS-059 AC-4: and names the missing --, as a whole line
mutate: 306 passed, 2 failed
=== mutate: command exited 1; restored (verified byte-for-byte against $ROOT/.claude/state/selfmut/.claude/state/mutations/_d_agentic-dev-harne
scripts/mutate.sh matches HEAD after the run
mutate: no stranded mutation; nothing of a previous run is in the tree.
DV-DONE
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

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-059` from `.claude/harness/models.conf`.
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
- RED: `test-developer`, dispatched with `model: opus`; it reported Opus 5.5 (`claude-opus-5-5`).
- GREEN: `feature-developer`, dispatched with `model: opus`; it reported Opus 5.5 (`claude-opus-5-5`).
- GATES: run by the orchestrator session itself (no dispatch), then on Opus 5.5 (`claude-opus-5-5`); the session switched from Fable 5.1 to Opus 5.5 between RED and GREEN.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- Detecting every stray write a mutated *command* makes: the command is the
  caller's, and what it writes is the caller's concern. This story covers what
  the sed expression itself can write.
- Why the fork failure happened. That was the machine, not the script.

## Design notes

<!-- Filled by the Lead Designer for user-facing stories: layout, states,
     tokens, accessibility requirements. Omit for non-UI stories. -->

## Test plan

<!-- Filled by the Test Developer during RED: which tests, at which level,
     and which AC each one covers. -->

All tests are shell-level integration tests against a fixture repository
(`make_project_fixture`, which copies the real `scripts/` and `.claude/hooks/`),
because the behaviour lives at the CLI: exit codes, whole printed lines, and
what exists on disk afterwards. There is no unit level below a bash script here.

| Suite | Describe | AC | How |
|---|---|---|---|
| `mutate.test.sh` | HARNESS-059 AC-1: --check reports a stranded mutation of a file under a dot-directory | AC-1 (+ C-1 count, remedy) | planted GONE sentinel |
| `mutate.test.sh` | HARNESS-059 AC-3: a sed expression that writes, reads or executes is refused before FILE is touched | AC-3 | real mutate.sh run, ten expressions + two controls |
| `mutate.test.sh` | HARNESS-059 AC-3 (PO decision 1): a sed with no --sandbox mode makes mutate.sh refuse | AC-3 / PO decision 1 | fake `sed` first on PATH |
| `mutate.test.sh` | HARNESS-059 AC-4: a command with no -- before it is refused, and FILE is unchanged | AC-4 | real run |
| `gates.test.sh` | HARNESS-059 AC-2 block, in HARNESS-030's section, before its trailing "no sentinel is left" check (widened to `.*.active`) | AC-2 (C-4) | planted GONE sentinel, real gates.sh |

Every assertion runs unconditionally and loops have a fixed body, so the
executed count is fixed (floors: mutate 308, gates 682).

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

**Model.** Dispatched as `test-developer`. It ran on Opus 5.5
(`claude-opus-5-5`), which is what the agent file's `model: opus` plans. No
override was given.

### Commands

    bash .claude/tests/mutate.test.sh     # about 1m40s on this host
    bash .claude/tests/gates.test.sh      # about 6m15s on this host

The timings come from a local run (Git Bash, Windows 11) on 2026-10-16. None
come from CI. The new blocks add no step with a timeout.

### Verbatim failure output (mutate.sh unchanged; tree at 5187696 plus this RED)

`mutate.test.sh`, the FAIL lines and the summary:

```
    FAIL HARNESS-059 AC-1: a stranded dot-named sentinel makes --check exit 1
    FAIL HARNESS-059 AC-1: and --check does not print the clean line on stdout
    FAIL HARNESS-059 AC-1: it opens with the unaccounted-for line
    FAIL HARNESS-059 AC-1: it names the .claude/ target, as recorded
    FAIL HARNESS-059 AC-1: and reports its process as GONE
    FAIL HARNESS-059 AC-1: the file differs from its backup, and it says so
    FAIL HARNESS-059 AC-1: with the exact cp && cmp && rm -f remedy naming the dot-named sentinel
    FAIL HARNESS-059 AC-1: and counts it
    FAIL HARNESS-059 AC-1 (C-1): it names the .claude/ target
    FAIL HARNESS-059 AC-1 (C-1): and counts two
    FAIL HARNESS-059 AC-1 (C-1): a dot-named sentinel whose file matches still exits 1
    FAIL HARNESS-059 AC-1 (C-1): and prints the exact rm -f remedy for it
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): exits 2
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): no file exists at out afterwards
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1s/a/b/w h59-w-slash (w flag, /): exits 2
    FAIL HARNESS-059 AC-3 1s/a/b/w h59-w-slash (w flag, /): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1s/a/b/w h59-w-slash (w flag, /): no file exists at h59-w-slash afterwards
    FAIL HARNESS-059 AC-3 1s/a/b/w h59-w-slash (w flag, /): the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 1s/a/b/w h59-w-slash (w flag, /): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1s|a|b|gw h59-w-pipe (gw flags, |): exits 2
    FAIL HARNESS-059 AC-3 1s|a|b|gw h59-w-pipe (gw flags, |): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1s|a|b|gw h59-w-pipe (gw flags, |): no file exists at h59-w-pipe afterwards
    FAIL HARNESS-059 AC-3 1s|a|b|gw h59-w-pipe (gw flags, |): the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 1s|a|b|gw h59-w-pipe (gw flags, |): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1w h59-w-cmd (w command): exits 2
    FAIL HARNESS-059 AC-3 1w h59-w-cmd (w command): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1w h59-w-cmd (w command): no file exists at h59-w-cmd afterwards
    FAIL HARNESS-059 AC-3 1w h59-w-cmd (w command): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1W h59-W-cmd (W command): exits 2
    FAIL HARNESS-059 AC-3 1W h59-W-cmd (W command): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1W h59-W-cmd (W command): no file exists at h59-W-cmd afterwards
    FAIL HARNESS-059 AC-3 1W h59-W-cmd (W command): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1e touch h59-e-cmd (e command): exits 2
    FAIL HARNESS-059 AC-3 1e touch h59-e-cmd (e command): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1e touch h59-e-cmd (e command): no file exists at h59-e-cmd afterwards
    FAIL HARNESS-059 AC-3 1e touch h59-e-cmd (e command): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1s/.*/touch h59-e-flag/e (e flag): exits 2
    FAIL HARNESS-059 AC-3 1s/.*/touch h59-e-flag/e (e flag): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1s/.*/touch h59-e-flag/e (e flag): no file exists at h59-e-flag afterwards
    FAIL HARNESS-059 AC-3 1s/.*/touch h59-e-flag/e (e flag): the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 1s/.*/touch h59-e-flag/e (e flag): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 w on the second line of a two-line expression: exits 2
    FAIL HARNESS-059 AC-3 w on the second line of a two-line expression: says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 w on the second line of a two-line expression: no file exists at h59-w-line2 afterwards
    FAIL HARNESS-059 AC-3 w on the second line of a two-line expression: the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 w on the second line of a two-line expression: no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1r src/main.ts (r command): exits 2
    FAIL HARNESS-059 AC-3 1r src/main.ts (r command): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1r src/main.ts (r command): the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 1r src/main.ts (r command): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 AC-3 1R src/main.ts (R command): exits 2
    FAIL HARNESS-059 AC-3 1R src/main.ts (R command): says sed rejected the expression, as a whole line
    FAIL HARNESS-059 AC-3 1R src/main.ts (R command): the command never ran (no ran-marker)
    FAIL HARNESS-059 AC-3 1R src/main.ts (R command): no new file exists in the tree afterwards (git status unchanged)
    FAIL HARNESS-059 PO-1: with no --sandbox, an ordinary expression exits 2
    FAIL HARNESS-059 PO-1: and says why, as the exact whole line
    FAIL HARNESS-059 PO-1: the command never ran (no ran-marker)
mutate: 248 passed, 60 failed
```

Some of the detail lines, to show that it is the asserted behaviour failing and
not the harness:

```
    FAIL HARNESS-059 AC-1: a stranded dot-named sentinel makes --check exit 1
         expected: 1
         actual:   0
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): no file exists at out afterwards
         expected: absent
         actual:   present
    FAIL HARNESS-059 AC-3 1s#a#b#w out (w flag, # delimiter): no new file exists in the tree afterwards (git status unchanged)
         expected:  M src/main.ts
         ?? .claude/state/mutations/log
         actual:    M src/main.ts
         ?? .claude/state/mutations/log
         ?? out
         ?? ran-marker
    FAIL HARNESS-059 AC-3 1w h59-w-cmd (w command): exits 2
         expected: 2
         actual:   3
    FAIL HARNESS-059 PO-1: with no --sandbox, an ordinary expression exits 2
         expected: 2
         actual:   0
```

`gates.test.sh` (each of the first six failed with expected/actual 2/0, 1/0,
1/0, 1/0, 0/1 and absent/present):

```
    FAIL HARNESS-059 AC-2: behind a stranded .claude/ mutation gates.sh exits 2
    FAIL HARNESS-059 AC-2: it prints the refusal, whole
    FAIL HARNESS-059 AC-2: after --check's unaccounted-for line
    FAIL HARNESS-059 AC-2: which names .claude/hooks/lib.sh
    FAIL HARNESS-059 AC-2: no line says the run recorded
    FAIL HARNESS-059 AC-2: and the gate command never ran (marker absent)
    FAIL HARNESS-059 AC-2: gates.sh --gate unit is refused too, exit 2
    FAIL HARNESS-059 AC-2: --gate unit prints the refusal, whole
    FAIL HARNESS-059 AC-2: and --gate unit never ran the gate
gates: 673 passed, 9 failed
```

**Why these are the right failures.** Today `--check` exits 0 and prints the
clean line over a dot-named sentinel. That is AC-1, and it is also why gates.sh
runs and records behind one (AC-2). Today sed also runs `w`/`W`/`e`
expressions and creates their files. Then either the command runs (exit 0), or,
where the output did not change (`1w`, `1W`, `1e`), mutate.sh refuses with exit
3, but only after sed has already written the file. None of the failures is an
import, timeout or fixture error. Every precondition passed.

**Other checks run.**
- `bash scripts/gates.sh --fast`: exit 0, "0 ran, 5 unconfigured". This
  repository configures no gates, as for every HARNESS story.
- `check-sigpipe.sh` and `check-grep-count.sh`: 0 findings across 49 files.
- `selftest.test.sh`, which checks the floor mirror: `selftest: 268 passed, 0 failed`.
- `mutate.sh --check` is clean. `ls -A .claude/state/mutations/` shows only
  `log`. I checked with `ls -A` because the unfixed `--check` cannot see a
  dot-named sentinel.

### What each test asserts

**`mutate.test.sh`, "HARNESS-059 AC-1"** (AC-1, C-1). The fixture plants a GONE
sentinel `.claude_hooks_lib.sh.20261016T053548Z.<deadpid>.active` for
`.claude/hooks/lib.sh`. Its `.bak` holds text that differs from the fixture's
lib.sh. The target file itself is not edited.
- Two preconditions: the pid is dead, and the fixture has `.claude/hooks/lib.sh`.
- `--check` exits 1, and stdout does not hold the clean line.
- stderr holds each of these as a whole line:
  - the unaccounted-for line
  - `  .claude/hooks/lib.sh`
  - `    process:     <pid> (GONE - ...)`
  - `    the file DIFFERS from the original. Put it back:`
  - exactly `      cp <bak> <abs lib.sh> && cmp <bak> <abs lib.sh> && rm -f <bak> <active>`
  - `1 unaccounted-for mutation(s). ...`
- Control, 3 assertions (green today and must stay green): the same setup with
  `scripts_gates.sh...active` exits 1, names `  scripts/gates.sh` and counts 1.
- C-1, 4 assertions: with both sentinels planted, exit 1, both targets named,
  and the line `2 unaccounted-for mutation(s). Nothing that judges this tree should run`.
- C-1, 2 assertions: a dot-named sentinel whose file matches its backup gives
  exit 1 and exactly the `      rm -f <bak> <active>` remedy.
- Once cleared, stdout is exactly the clean line.

**`mutate.test.sh`, "HARNESS-059 AC-3"** (AC-3, C-2). `h59_refused` runs
`mutate src/main.ts EXPR -- touch ran-marker` from the fixture root and asserts
eight things:
1. exit 2
2. the whole line `mutate: sed rejected the expression:`
3. no file at the path the expression would create
4. no `ran-marker`
5. `git status --porcelain --untracked-files=all` is the same before and after.
   This is the AC's "no new file exists in the tree".
6. FILE is byte-identical
7. no `.active` left (counting dot-named ones)
8. no `.bak` left (counting dot-named ones)

It runs ten expressions:
- `1s#a#b#w out` (the story's minimal case)
- `1s/a/b/w h59-w-slash`
- `1s|a|b|gw h59-w-pipe`
- `1w h59-w-cmd`
- `1W h59-W-cmd`
- `1e touch h59-e-cmd`
- `1s/.*/touch h59-e-flag/e`
- `s/90/-90/`, then a newline, then `w h59-w-line2`
- `1r src/main.ts`
- `1R src/main.ts`

Controls, 3 assertions each, for `1s#a#b#g` and `1s/a/b/2`: exit 0, no
rejection line, and the file restored.

**`mutate.test.sh`, "HARNESS-059 AC-3 (PO decision 1)".** A fake `sed` sits in
a temp dir placed first on PATH. Given a `--sandbox` argument it prints
`sed: illegal option -- -` and exits 1. Every other call `exec`s the real sed,
whose path is taken from `command -v sed` before PATH changes.
- Two preconditions: the fake refuses `--sandbox`, and it passes `s/a/b/` through.
- Under the fake, `s/90/-90/ -- touch ran-marker` must give: exit 2; the whole line
  `mutate: this sed has no --sandbox mode, so an expression could write files the restore never sees; install GNU sed (gsed) and put it first on PATH`;
  FILE byte-identical; no `ran-marker`; and no `.active`, `.bak` or `.new` left.

**`mutate.test.sh`, "HARNESS-059 AC-4"** (AC-4, C-3). It runs
`mutate src/main.ts 's/90/-90/' touch ran-marker` and asserts: exit 2; the whole
line `mutate: the command must be separated from the expression by -- <command>`;
FILE byte-identical; no `ran-marker`. **All four pass on arrival.** They are not
earned in RED; DV-3 earns them at GATES.

**`gates.test.sh`, "HARNESS-059 AC-2"** (AC-2, C-4). The block sits in
HARNESS-030's section, after the AC-6 control with the live sentinel. It uses
`h30_plant`, `h30_fresh`, `H30MUT`, `H30_REFUSAL`, `H30_UNACCOUNTED`,
`H30_RECORDED` and `h30_mark`.
- It plants a GONE `.claude_hooks_lib.sh.20261016T053548Z.<deadpid>.active`
  whose `.bak` differs from the fixture's lib.sh.
- Two preconditions: the pid is dead, and the backup differs.
- Full run: exit 2; the refusal as a whole line; the unaccounted-for line as a
  whole line; `  .claude/hooks/lib.sh` as a whole line; no "recorded in" line;
  marker absent.
- `--gate unit`: exit 2; the refusal as a whole line; marker absent.
- Afterwards the sentinel is removed. The block's trailing "no sentinel is left
  in the shared fixture" check now globs both `*.active` and `.*.active`.

### Files touched

- `.claude/tests/mutate.test.sh`: four describes added before `summary "mutate"`.
- `.claude/tests/gates.test.sh`: the AC-2 block and the widened trailing glob, both in HARNESS-030's section.
- `.claude/tests/floors.conf`: `gates` 671 -> 682 and `mutate` 189 -> 308, with the measurement in the comment at the foot.
- `.claude/tests/selftest.test.sh`: the mirror, now `gates 682` and `mutate 308`.
- `docs/backlog/stories/HARNESS-059.md`: `## Test plan` and this handoff.

Nothing under `scripts/` was written.

### What the tests pin (stated as fact)

Nothing is imported. The interface is the CLI of `scripts/mutate.sh`.
- `mutate.sh --check` over a sentinel whose name starts with `.` gives exactly
  the report a plain sentinel gets: the same lines, the same `found` count, and
  exit 1. The name it prints is the sentinel's `file` value. The order of the
  two globs is not pinned, because the both-at-once case counts lines rather
  than checking their order.
- `mutate.sh FILE EXPR -- CMD`, where EXPR has a `w`/`W`/`e`/`r`/`R` command or a
  `w`/`e` flag: exit 2 and the whole line `mutate: sed rejected the expression:`.
  Nothing is created, the command does not run, and no `.active` or `.bak` is
  left. sed's own message below that line is **not** pinned.
- With a sed whose `--sandbox` fails, an otherwise valid expression gives exit 2
  and the exact whole line from PO decision 1. No `.active`, `.bak` or `.new` is
  left, and the command does not run.
- **Not pinned:**
  - whether the PO decision 1 message goes through `die` (and so has the usage
    text after it) or a plain printf
  - whether the probe runs before or after the backup is taken; only that
    nothing is left behind
  - how the probe is spelled (`sed --sandbox -e '' </dev/null` is the
    Contract's suggestion)
  - anything on `--check`'s stdout beyond whether the clean line is there

### Negative controls: expected values

No import blocked any assertion. These suites run against the existing
`mutate.sh`, so every control below **did run** in this RED run, against the
unchanged script. What is still a claim is how they behave against GREEN's
script, and GREEN confirms each one.

| Control | Threshold | Measured in RED (unchanged mutate.sh) | Expected after GREEN |
|---|---|---|---|
| scripts/ sentinel reported (AC-1) | exit 1, names `  scripts/gates.sh`, count 1 | exit 1, 1, 1 (pass) | same |
| `1s#a#b#g` accepted (AC-3) | exit 0, 0 rejection lines, restored | 0, 0, restored (pass) | same |
| `1s/a/b/2` accepted (AC-3) | exit 0, 0 rejection lines, restored | 0, 0, restored (pass) | same |
| fake sed refuses `--sandbox` (PO-1 precondition) | `refused` | refused (pass) | same |
| fake sed passes `s/a/b/` through | `b` | b (pass) | same |
| widened trailing glob in gates.test.sh | a dot-named sentinel is listed | measured outside the suite: old glob `[]`, new `[.claude_hooks_lib.sh.X.1.active ]`; a plain sentinel is listed by both; an empty dir gives `[]` for both | in-suite value `""` (passes now and after) |

Measured outside the suite with GNU sed 4.9 (Git Bash) on 2026-10-16:
- `sed --sandbox` exits 1 with `e/r/w commands disabled in sandbox mode` for
  each of the ten AC-3 expressions, and exits 0 for both controls.
- Without `--sandbox`, each of `1s#a#b#w ...`, `1w ...`, `1e touch ...` and
  `1s/.*/touch .../e` created its file.
- CI's sed is 4.8 (the Contract's note). I did not measure there.

### Green on arrival

- **AC-4, 4 assertions.** DV-3 earns them at GATES. I decline that here (see below).
- **The controls.** The AC-1 scripts/ control (3) and the AC-3 `g` and numeric
  controls (6) are green by design.
- **Three of `h59_refused`'s eight assertions, for every expression.** FILE
  byte-identical, no `.active` and no `.bak` already pass, because the current
  script does restore the target; the defect is what sed writes beside it.
  These three pin that GREEN's refusal path keeps it that way.
- **`1w`, `1W` and `1e`.** "The command never ran" also passes today for these,
  because mutate.sh exits 3 before the command.
- **`1r` and `1R`.** "No file at <made>" is vacuous for these: they create
  nothing, and the name is one no case writes. The exit, the rejection line, the
  command not running and the git-status comparison carry these two cases.
- **The preconditions** (dead pid, fixture file present, backup differs).

### Deferred verifications

DV-1, DV-1b, DV-2 and DV-3 all have `Owner: GATES`. I did not run any of them,
and I decline them here. DV-1, DV-1b and DV-2 need C-1 and C-2 to be built, and
in RED they are not. DV-3 belongs to the same GATES pass under the story's plan.

### Callers checked

I ran `git grep -n 'mutate.sh'` over the tree and took every expression
recorded in single quotes after `mutate.sh FILE`: 94 unique ones, across
`.claude/`, `CLAUDE.md`, `README.md`, the stories and the audits. Each was run
through `sed -e` and `sed --sandbox -e` on `/dev/null`. None parses without the
sandbox and fails with it. `git status` showed no new files afterwards. The
Contract's "Callers of changed signatures: none" holds.

### For the implementation

- The suite's older helpers in mutate.test.sh (`actives`, `clear_strays`,
  `the_bak`) glob `*.active` only. The HARNESS-059 blocks use their own
  dot-aware `h59_*` helpers, so GREEN does not need to touch the older ones.
- `1w`, `1W` and `1e` leave sed's output unchanged, so today's script refuses
  them with exit 3, but only after sed has already written the file. The
  sandbox therefore has to apply at the apply step itself, not at a later check.
- No Contract block was amended.

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

    run:    2026-10-16T22:21:43Z
    commit: 0278488
    tree:   d97c40b6157bfe1a33567bbc02673ce19ccf134e
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

**GREEN (2026-10-16, `feature-developer`, Opus 5.5 `claude-opus-5-5`, no
override).** Only `scripts/mutate.sh` changed, in three places:
- C-1: `--check` loops over `"$MUTDIR"/*.active "$MUTDIR"/.*.active`, keeping
  the existing `[ -f "$a" ] || continue` guard. No `dotglob`.
- C-2: the apply step is `sed --sandbox -e "$EXPR" "$BAK" > "$NEW"`. The
  existing rejection path (exit 2, `mutate: sed rejected the expression:`,
  backup removed) is unchanged.
- PO decision 1: `sed --sandbox -e '' </dev/null >/dev/null 2>&1` is probed
  after the self-mutation refusal and before `mkdir`/backup. On failure it
  prints the Contract's exact line and exits 2 through a plain printf, not
  `die`, so no usage text follows. Nothing has been created at that point,
  so nothing is left behind.

Before the change, `mutate.test.sh` gave `248 passed, 60 failed`, the same as
RED. After it:

    mutate: 308 passed, 0 failed
    gates: 682 passed, 0 failed
    check-sigpipe: scanned 49 shell file(s), 45 with pipefail, 0 finding(s)
    check-grep-count: scanned 49 shell file(s), 0 finding(s)
    gates.sh --fast: All required gates passed (0 ran, 5 unconfigured, 0 known).
    mutate.sh --check: no stranded mutation; nothing of a previous run is in the tree.

Controls, measured against the shipped script in a scratch git fixture
outside the suite:
- A dead-pid `scripts_gates.sh` sentinel planted beside a `.claude_hooks_lib.sh`
  one: `--check` exits 1, names `  scripts/gates.sh` and
  `  .claude/hooks/lib.sh`, and counts 2.
- `1s#a#b#g`: exit 0, no rejection line, file restored.
- `1s/a/b/2` (on a line with two `a`s): exit 0, no rejection line, restored.
- `1s#a#b#w out`: exit 2, the rejection line, and no `out`.
- No `--`: exit 2 with the C-3 message. With `--`: exit 0.
- A fake sed that refuses `--sandbox` (PATH given as `/c/...`; a `C:/` entry
  splits on its colon and is silently ignored): exit 2, the exact PO-1 line,
  no `ran-marker`, only `log` in mutations/, and FILE unchanged.

All of these match RED's table. The only divergence is in my own fixture: my
first `1s/a/b/2` gave exit 3 because the line had one `a`. The script was not
at fault.

**Self-test at GATES (orchestrator, 2026-10-16).** `bash scripts/selftest.sh`,
run detached and alone after `bash scripts/gates.sh` recorded a pass, exited 0
in 2894 s (about 48 minutes, against the 25 once recorded on this host; nothing
else ran in the worktree during it):

    assertion floors: all 26 suite(s) met their declared floor (3546 assertions executed, 3320 declared).
    26 harness suite(s) passed.

**Handoff check.** RED's mutation table was not re-run beyond the story's
deferred verifications. DV-1, DV-1b, DV-2 and DV-3 are those runs, and each
turned exactly its criterion's assertions red (see `## Deferred verifications`).

PR: https://github.com/ryanczhang7/agentic-dev-harness/pull/146 (opened 2026-10-16 from `4a27ff7`).

**CI (REVIEW -> DONE, 2026-10-16).** PR #146 merged as `4b394fc`. The PR's
`gates` run, https://github.com/ryanczhang7/agentic-dev-harness/actions/runs/38980131785,
took 2m37s (23:12:10Z to 23:14:47Z) against the workflow's 45-minute limit, and
its self-test step ended:

    assertion floors: all 26 suite(s) met their declared floor (3546 assertions executed, 3320 declared).
    26 harness suite(s) passed.

The `boundaries` run, https://github.com/ryanczhang7/agentic-dev-harness/actions/runs/38980132034,
passed in 9 s. No gate reached REVIEW marked pending CI.
