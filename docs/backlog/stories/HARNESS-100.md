---
id: HARNESS-100
title: ci-local runs only workflows that trigger on pull_request
slug: ci-local-runs-only-workflows-that-trigge
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-100-ci-local-runs-only-workflows-that-trigge
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/ci-local.sh, .claude/tests/ci-local.test.sh, .claude/tests/sigpipe.test.sh, .claude/tests/floors.conf, .claude/tests/selftest.test.sh, .claude/harness/VERSION]  # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # every gate is unconfigured here; the artifact is judged by the ci-local suite under its selftest floor, which CI runs in full on the PR
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

**A port of a downstream fix.** The consuming project clean_calendar (harness
release 93) fixed `scripts/ci-local.sh` in its own repository as its story
HARNESS-052 "ci-local runs only workflows that trigger on pull_request" (PR #26,
commits `48a47f1..ad6e35b`, merged 2026-10-30 as `2fb628b`). The id collides
with upstream HARNESS-052, an unrelated story, and upstream never received the
fix. A refresh of clean_calendar replaces `scripts/ci-local.sh` and
`.claude/tests/ci-local.test.sh` and would silently lose the fix and its tests.
This story ports it first (port-before-refresh).

**The defect, upstream, on `main` at `94acc3f` (release 118).**
`scripts/ci-local.sh` claims to run "exactly what CI runs" on a pull request.
`workflow_files()` (lines 83-91) emits `gates.yml` first and then every other
`.github/workflows/*.yml`, with no regard to what triggers it, and
`workflow_steps()` emits each file's `run:` steps. A push-only workflow's
plain-shell steps are therefore RUN from a developer's machine. This is not a
hypothetical upstream either: upstream ships `.github/workflows/deploy.yml.template`
(inert, and not matched by `*.yml`), whose header says "rename to deploy.yml,
fill in your target". Its `on:` is `push: branches: [main]` plus
`workflow_dispatch:` - so the first project that follows those instructions gets
its deploy step run by `bash scripts/ci-local.sh`. clean_calendar did exactly
that (`deploy.yml` with `supabase db push --linked` and `functions deploy`).

**The fix.** Only workflows whose top-level `on:` names the `pull_request`
event contribute steps; each one dropped is named on stderr with
`note: not running <file>: it does not trigger on pull_request`.

**Upstream's own run does not change.** Measured at PLANNED with the
downstream predicate extracted from the patched copy (scratch, not the
worktree): `.github/workflows/boundaries.yml` IN (`on:` block, `pull_request:`),
`.github/workflows/gates.yml` IN (`on:` block with `pull_request:`, `schedule:`,
`workflow_dispatch:`), `deploy.yml.template` OUT (and not globbed anyway). So
the story's behaviour is exercised only by fixtures in the suite, plus the
real-tree probes in `## Deferred verifications`.

**The derivation at the top of `.claude/tests/ci-local.test.sh` (lines 40-60)
needs no filter.** It reads `"$WF"/gates.yml "$WF"/boundaries.yml` BY NAME, not
by glob, and asserts a subset: every `run:` command in those two files appears
in the script's `--dry-run`. Both trigger on `pull_request` in this tree, so the
filtered script still emits all of them; a push-only workflow in a fixture or a
consumer is never read by the derivation, so the two cannot disagree. The same
fact is why the derivation cannot notice a leak (it never asserts "nothing
else"), which is what the new describe block is for. Changing the derivation is
out of scope.

**Required gate.** None is configured in this unbootstrapped tree; the artifact
is judged by `bash scripts/selftest.sh ci-local` under its floor, and CI's
`gates` workflow runs the full self-test on the PR. `required_gates` stays empty.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

All of AC-1 to AC-6 and AC-8 run from one project fixture
(`make_project_fixture`) whose `.github/workflows/` the test writes; each
workflow's only step is `touch .m-<name>`, so the dry listing and the real run
are judged against the same names. AC-1 to AC-7 are clean_calendar's, ported;
AC-8 and AC-9 are upstream's.

- **AC-1** — Given a `gates.yml` whose `on:` is a block mapping holding
  `pull_request:`, a comment line, `schedule:` (with a `- cron:` item) and
  `workflow_dispatch:` (the real file's shape), and a `deploy.yml` whose `on:`
  is a block mapping holding only `push:` (with `branches: [main]`) and
  `workflow_dispatch:` (the shape of upstream's own `deploy.yml.template`),
  when `bash scripts/ci-local.sh --dry-run` runs, then stdout holds the whole
  line `touch .m-gates` and no line containing `m-deploy`.
- **AC-2** — Given the same fixture, when `bash scripts/ci-local.sh` runs for
  real, then it exits 0, `.m-gates` exists afterwards (the control that the run
  executed anything at all) and `.m-deploy` does not.
- **AC-3** — Given a workflow whose `on:` is the flow sequence
  `[push, pull_request]`, when `--dry-run` runs, then its step is listed as a
  whole line.
- **AC-4** — Given a workflow whose `on:` is the bare scalar `pull_request`,
  when `--dry-run` runs, then its step is listed as a whole line.
- **AC-5** — Given a push-only workflow that mentions `pull_request` outside
  `on:` - in a comment above `on:` and in a step's
  `if: github.event_name != 'pull_request'` - when `--dry-run` runs, then its
  step is NOT listed. *Control:* this is the negative control for a filter that
  greps the file for the word; such a filter lists it.
- **AC-6** — Given the excluded workflows of AC-1 and AC-5, when `ci-local.sh`
  runs, dry and real, then stderr (dry) and the combined output (real) hold the
  whole lines `note: not running deploy.yml: it does not trigger on pull_request`
  and `note: not running release.yml: it does not trigger on pull_request`
  (release.yml being AC-5's file), and no line containing
  `not running gates.yml`.
- **AC-7** — Every case already in `.claude/tests/ci-local.test.sh` stays green
  with its text and expected values unchanged (their fixtures all spell
  `on: [pull_request]`), including the derivation block at lines 40-60, which
  keeps reading `gates.yml` and `boundaries.yml` by name.
- **AC-8** — Given a workflow whose `on:` is `[pull_request_target]` and
  another whose `on:` is a block mapping holding only `pull_request_target:`,
  when `--dry-run` runs, then neither step is listed and stderr names each
  file with the AC-6 note. `pull_request_target` runs the BASE branch's code,
  so it is not "what this PR runs". *Control:* a filter that matches
  `pull_request` as a prefix lists both - in the inline branch and the block
  branch separately, which is why there are two files.
- **AC-9** — Bookkeeping, measured on this tree: `floor | ci-local | <N>` in
  `.claude/tests/floors.conf` and `ci-local <N>` in
  `.claude/tests/selftest.test.sh` carry the ci-local suite's executed count,
  equal; the C-5 pin in `.claude/tests/sigpipe.test.sh` names the line of
  `scripts/ci-local.sh` that holds `dirty="$(git status` after the change, and
  `bash scripts/selftest.sh sigpipe` reports `0 failed`; `floor | sigpipe` is
  unchanged at 91; `.claude/harness/VERSION` reads `119 (<date>)`.

*Expected red on today's script* (all includes everything, announces nothing):
AC-1's negative half, AC-2's `.m-deploy` half, AC-5, both AC-6 notes (dry), the
real-run AC-6 note, and all four AC-8 assertions fail; AC-1's positive half,
AC-2's exit and `.m-gates` halves, AC-3, AC-4 and AC-6's "gates not reported"
pass on arrival. AC-3 and AC-4 are earned by DV-2. The sigpipe C-5 freshness
assertion fails too, because RED moves the pin to a line today's 191-line
script does not have.

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

**Writes:** `scripts/ci-local.sh`, `.claude/tests/ci-local.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/tests/floors.conf`, `.claude/tests/selftest.test.sh`, `.claude/harness/VERSION`

**RED may amend any block below in place, with a reason; GREEN then builds what
the amended block says.** The acceptance criteria are not in that licence.

- **C-1. Anchors (`main` at `94acc3f`, release 118, verified with `grep -n` /
  `cat -n` at PLANNED).** `scripts/ci-local.sh` is 191 lines:
  `workflow_files()` 83-91 (comment above it 72-82), `workflow_steps()` 96-115,
  the step loop 117-134 with the `${{` skip note at 130, the "no run: steps
  found" exit 2 at 136-139, `dirty="$(git status ...` at **169**.
  `.claude/tests/ci-local.test.sh` is 416 lines: the derivation 40-60, the
  ordering block ending `rm -rf "$OFIX"` at 370, the HARNESS-079 AC-8 describe
  373-414, `summary "ci-local"` 416. Upstream changed that suite once since
  release 93 (`0fdfbe9`, HARNESS-079, adding the 373-414 block), which is why
  the downstream suite patch does not apply. `.claude/tests/sigpipe.test.sh`
  line **577**, inside C-5's `DISCARDED` list, reads
  `scripts/ci-local.sh:169:dirty="$(git status` - the only pin of a
  `ci-local.sh` line number anywhere in `.claude/`, `scripts/` or `docs/wiki/`.
  Floors: `floor | ci-local      | 32` (floors.conf line 42), `ci-local 32`
  (selftest.test.sh 533), `floor | sigpipe       | 91`, `sigpipe 91`.
  `.claude/harness/VERSION` line 34: `118 (2026-11-08)`. Baseline run:
  `bash .claude/tests/ci-local.test.sh` -> `ci-local: 32 passed, 0 failed`.

- **C-2. The script change (GREEN).** Port clean_calendar's patch to
  `scripts/ci-local.sh` (measured: `git apply --check` applies it cleanly to
  `main`; the file is unchanged upstream since release 93). Its code, to be
  reproduced exactly:

      workflow_files() {
        local first="$WFDIR/gates.yml" f n=0
        for f in "$first" "$WFDIR"/*.yml; do
          n=$((n + 1))
          [ -e "$f" ] || continue
          [ "$n" -gt 1 ] && [ "$f" = "$first" ] && continue
          if triggers_on_pull_request "$f"; then
            printf '%s\n' "$f"
          else
            printf 'note: not running %s: it does not trigger on pull_request\n' "$(basename "$f")" >&2
          fi
        done
      }

      triggers_on_pull_request() { # <workflow file>
        awk '
          inon {
            if ($0 ~ /^[[:space:]]*(#|$)/) next
            match($0, /^[[:space:]]*/); this = RLENGTH
            if (this == 0) exit
            if (ind < 0) ind = this
            if (this != ind) next
            line = $0; sub(/^[[:space:]]*(-[[:space:]]+)?/, "", line)
            if (line ~ /^["\047]?pull_request["\047]?[[:space:]]*(:|#|$)/) { found = 1; exit }
            next
          }
          /^["\047]?on["\047]?[[:space:]]*:/ {
            v = $0
            sub(/^["\047]?on["\047]?[[:space:]]*:[[:space:]]*/, "", v)
            sub(/[[:space:]]*#.*$/, "", v)
            if (v != "") { found = (v ~ /(^|[^A-Za-z0-9_])pull_request([^A-Za-z0-9_]|$)/); exit }
            inon = 1; ind = -1
          }
          END { exit !found }
        ' "$1"
      }

  plus the six-line comment block that opens `# ONLY WORKFLOWS A PULL REQUEST
  TRIGGERS.` above `workflow_files()` and the seven-line comment above
  `triggers_on_pull_request()`. In the comment, the downstream reference
  `(HARNESS-052)` becomes `(HARNESS-100, from clean_calendar's HARNESS-052)`
  and the example names upstream's `deploy.yml.template` rather than supabase,
  **without changing the number of lines**. Semantics:
  - only the top-level `on:` key (column 0, optionally quoted) is read; a
    comment, an `if:`, a `name:` or a job key elsewhere says nothing;
  - inline value on the key's own line (scalar or flow sequence/mapping):
    included iff `pull_request` appears as a whole word, where `_` is a word
    character - so `pull_request_target` does not match;
  - block value: only lines at the block's FIRST indentation are read, as a
    mapping key `pull_request:` or a sequence item `- pull_request`, optionally
    quoted, optionally followed by a comment; deeper lines (`branches:`,
    `- cron:`) and comment or blank lines are skipped; the block ends at the
    next column-0 line;
  - `workflow_files()` keeps its order (gates.yml first, then the rest by glob
    name order) and emits only files for which the predicate holds;
  - the existing "no run: steps found" exit 2 is unchanged and now also covers
    "no workflow triggers on pull_request".

- **C-3. The line the sigpipe pin follows.** Applied to a scratch COPY of
  `scripts/ci-local.sh` (never the worktree), the patch puts
  `dirty="$(git status --porcelain 2>/dev/null | grep -vE '^\?\?' | head -1)"`
  at line **208**: exactly 39 lines are added above it. So RED changes
  `sigpipe.test.sh:577` from `scripts/ci-local.sh:169:` to
  `scripts/ci-local.sh:208:` and nothing else in that suite. GREEN's change
  must land `dirty=` on 208 - if a rewording of the comments moves it, GREEN
  stops and says so (the pin is frozen in GREEN; moving it would be a return
  to RED). clean_calendar found this the slow way, as its R-1: GREEN moved the
  line, GATES' full self-test caught the stale pin, and a return to RED moved
  it. Moving the pin in RED, where it is red until GREEN lands, avoids that
  round trip. The new code adds no pipeline and no `grep -c`, so
  `check-sigpipe.sh` and `check-grep-count.sh` have nothing new to flag.

- **C-4. The suite change (RED).** In `.claude/tests/ci-local.test.sh`, a new
  `describe "only workflows CI runs on a pull request"` block between the
  HARNESS-079 AC-8 block's `rm -rf "$SFIX"` (414) and `summary "ci-local"`
  (416). Port clean_calendar's block (scratch:
  `C:/Users/ryanc/AppData/Local/Temp/claude/4cfd7d19cf4ea1ee/13cff595-70f1-48a0-9b4b-07e8e971562b/scratchpad/cc-port/ci-local.test.sh.patch`,
  hunk at its line 369) with:
  - its helpers `has_line` (whole-line equality through awk over a
    here-string) and `has_text` (awk `index()`), never `printf | grep -q`
    (sigpipe);
  - fixture `TFIX` with five workflows: `gates.yml`, `deploy.yml`, `both.yml`,
    `bare.yml`, `release.yml` as described in AC-1 to AC-5, each step
    `touch .m-<name>`;
  - **upstream additions for AC-8:** `target.yml` with `on: [pull_request_target]`
    and `target-block.yml` with `on:` / `  pull_request_target:`, steps
    `touch .m-target` and `touch .m-targetblock`; four assertions: no
    stdout line equal to `touch .m-target`, none equal to
    `touch .m-targetblock`, and the two whole-line notes
    `note: not running target.yml: ...` / `note: not running target-block.yml: ...`
    on dry stderr;
  - comments that name this story as `HARNESS-100 (ported from clean_calendar
    HARNESS-052)` and name `deploy.yml.template`'s shape, not CAL-030;
  - assertion titles prefixed with the AC they cover (`AC-1: ...`).
  No existing assertion changes. Expected count: 32 existing + 12 ported + 4
  AC-8 = **48 executed**; on today's script **38 passed, 10 failed**. RED
  measures both and records them; the floors follow the measurement, not this
  arithmetic.

- **C-5. Floors and version.** RED raises `floor | ci-local` and
  `selftest.test.sh`'s `ci-local` line to the measured executed count, in the
  same commit (`selftest.test.sh`'s "each records the executed count measured
  on this tree" otherwise fails), with a `floors.conf` comment in the style of
  HARNESS-079's (date, delta, `ci-local: 38 passed, 10 failed` measured,
  "until GREEN lands the run is red - expected"). `sigpipe` stays 91: one pin
  moved, no assertion added. GREEN writes `119 (<date>)` on
  `.claude/harness/VERSION` line 34.

- **C-6. Oracle partition.** *Mechanical:* AC-1 to AC-6 and AC-8 - stdout
  lines, stderr note text and marker files, pinned exactly as whole lines; the
  note text is pinned verbatim. *Settled:* AC-9 - read the counts and the line
  number out of a run on this tree; do not derive or "calibrate" them. AC-7 is
  a non-change. Nothing is oracle-free.

- **C-7. What the tests do not constrain.** The function name
  `triggers_on_pull_request` and the awk technique are the Contract's, not the
  tests'; the DVs target the name, so keep it. No test-only dependency is
  needed (bash, awk, git). No existing export changes signature; nothing has
  callers to list.

- **C-8. Commands.** RED and GREEN: `bash scripts/selftest.sh ci-local` and
  `bash scripts/selftest.sh sigpipe`, then `bash scripts/selftest.sh selftest`
  for the floors; run through `bash scripts/attest.sh --`. GATES: the
  self-test `/advance-story` names for this diff (`SELFTEST_JOBS=4 bash
  scripts/selftest.sh --changed`, or the full run in the cases it lists) -
  check that `bash scripts/selftest-needed.sh --suites` on the GREEN diff
  includes `ci-local`, `sigpipe` and `selftest`, and run the full suite if it
  does not, since `sigpipe` pins a line of `ci-local.sh` from another file -
  then `bash scripts/gates.sh` and `bash scripts/check-boundaries.sh`.

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

Budget: `rules.md`, "Mutation work per story" - one defect-put-back (DV-1),
the earning of the tests that pass on arrival against code that already
exists (DV-2), the real-tree probe a rule over the tree owes (DV-3), and the
end-to-end check against the consumer this port exists for (DV-4). Every
mutation goes through `bash scripts/mutate.sh` against the narrowest command,
`bash scripts/selftest.sh ci-local`, never the full suite.

- **DV-1 (defect put back)** — With `workflow_files()`'s call to
  `triggers_on_pull_request` neutralised through `scripts/mutate.sh`
  (`s/if triggers_on_pull_request "\$f"; then/if true; then/`), the
  assertions of AC-1 (negative half), AC-2 (`.m-deploy` half), AC-5, the three
  AC-6 notes and the four AC-8 assertions MUST go red in
  `bash scripts/selftest.sh ci-local` - ten reds, the same ten as RED's - and
  the restore MUST be verified. RED cannot run this: the call it removes does
  not exist yet. Owner: GATES.

- **DV-2 (earns AC-3 and AC-4)** — Both pass on arrival, because today's
  script includes everything. With the predicate's inline-value branch made
  to never match (`s/found = (v ~/found = 0 \&\& (v ~/`), AC-3's and AC-4's
  assertions MUST go red, and AC-1's positive and negative assertions MUST
  stay green (AC-1's `gates.yml` is a block `on:`). Every older fixture spells
  `on: [pull_request]` inline, so those cases go red too - expected collateral,
  as clean_calendar measured (`ci-local: 17 passed, 23 failed` there).
  Owner: GATES.

- **DV-3 (probe against the real tree)** — A rule over the tree's workflows is
  probed against a real line of that tree. Two parts, both in GATES:
  (a) in the story worktree,
  `bash scripts/mutate.sh .github/workflows/boundaries.yml 's/^  pull_request:$/  push:/' -- bash -c 'bash scripts/ci-local.sh --dry-run 2>&1'`
  MUST print `note: not running boundaries.yml: it does not trigger on pull_request`
  and NO line holding `scripts/check-boundaries.sh`; unmutated, the same
  command MUST list the `check-boundaries.sh` step and print no
  `not running` note at all (upstream's own run is unchanged). Restore
  verified.
  (b) in a `git clone --no-hardlinks` scratch clone of the story branch (never
  the worktree), the template renamed as its own header instructs - its
  leading `# ` stripped into `.github/workflows/deploy.yml` - then
  `bash scripts/ci-local.sh --dry-run` MUST list neither
  `bash scripts/gates.sh --gate build` nor the `echo "your target here ...`
  step and MUST print the `not running deploy.yml` note; and the same clone
  checked out at `main` (the unfixed script) MUST list both - the control
  that the probe could see the defect at all. Owner: GATES.

- **DV-4 (end-to-end against clean_calendar's real workflows)** — In a fresh
  `--no-hardlinks` scratch clone of the story branch, replace
  `.github/workflows/` with a copy of clean_calendar's (from the read-only
  scratch clone
  `C:/Users/ryanc/AppData/Local/Temp/claude/4cfd7d19cf4ea1ee/13cff595-70f1-48a0-9b4b-07e8e971562b/scratchpad/cc/.github/workflows/`,
  or a new scratch clone of `ryanczhang7/clean_calendar` at `main` if that is
  gone; NEVER `D:\clean_calendar`). Then `bash scripts/ci-local.sh --dry-run`
  MUST list no line containing `supabase link`, `supabase db push` or
  `supabase functions`, MUST print `note: not running deploy.yml: it does not
  trigger on pull_request`, and MUST list every `run:` step of the copied
  `gates.yml` and `boundaries.yml` that holds no unresolvable `${{` (the
  derivation's own rule). And its stdout MUST be byte-identical to the stdout
  of clean_calendar's own `scripts/ci-local.sh --dry-run` over the same
  workflow files, and the `note: not running` lines of the two stderrs
  identical - the port behaves as the fix it ports. Run clean_calendar's
  script from a SECOND `--no-hardlinks` clone of the story branch with the
  same workflows copied in and clean_calendar's `scripts/ci-local.sh` copied
  over upstream's, so nothing is run inside the clean_calendar clone. At
  PLANNED the extracted predicate already classifies clean_calendar's three
  workflows as `boundaries.yml` IN, `deploy.yml` OUT, `gates.yml` IN.
  Owner: GATES.

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

## Suppressions

<!-- One line per suppression this story's GREEN or GATES deliberately added:
     the path, the rule id in brackets, `approved by <who>`, and why that line
     and not a fix. check-boundaries.sh refuses any lint, type, coverage or
     mutation suppression a GREEN or GATES commit adds to source or config
     unless one line here names it. Omit the section if unused. -->

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-100` from `.claude/harness/models.conf`.
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
- PLANNED, `lead-po`: ran on **opus** (`claude-opus-5-5`, Opus 5.5), not the planned `fable`, by the user's decision (2026-11-09), because the account's Fable usage limit was reached - an earlier Fable dispatch stopped on HTTP 429 before writing anything.

Brief for RED: the oracle partition is the Contract's C-6 - AC-1 to AC-6 and
AC-8 mechanical (pin exact whole lines and the verbatim note text), AC-9
settled (read counts and the line number out of a run, do not derive them),
AC-7 a non-change.

## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- `pull_request_target` as an included event. It runs on a pull request but
  checks out and runs the BASE branch's code, so its steps are not what this
  PR runs. AC-8 pins that it is excluded.
- Branch and path filters (`pull_request: branches: [...]`, `paths:`,
  `types:`). A workflow that triggers on `pull_request` at all is included;
  reproducing GitHub's filter semantics locally is not attempted.
- Job-level and step-level `if:` conditions, and `on:` events other than
  `pull_request` (`merge_group`, `workflow_call`, ...). Unchanged from today.
- Changing the derivation at the top of `ci-local.test.sh` (lines 40-60). It
  reads `gates.yml` and `boundaries.yml` by name and asserts a subset; see
  `## Context`. A consumer whose `gates.yml` or `boundaries.yml` stopped
  triggering on `pull_request` would see the derivation report steps missing,
  which is a true disagreement, not a defect of this story.
- A full YAML parser. The predicate reads the shapes GitHub's own examples
  use; anchors, aliases and multi-document files are not handled.
- `CLAUDE.md`, `README.md` and `ci-local.sh`'s header (lines 2-33). The header
  still says "exactly what CI runs" and "the two workflows"; editing it would
  move the sigpipe pin (C-3). A follow-up may reword prose, with the pin.
- Refreshing clean_calendar. This story unblocks it and does not do it.

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

- **Origin and credit.** Ported from clean_calendar's HARNESS-052 "ci-local runs
  only workflows that trigger on pull_request", PR #26 (merged 2026-10-30 as
  `2fb628b`), commits `48a47f1..ad6e35b` (PLANNED `48a47f1`, RED `40f2e6a`,
  GREEN `debf5f4`, GATES `501c332`/`9c93fd5`, RED R-1 `23ddf48`, GATES
  `4971efb`, DONE `ad6e35b`). The criteria, the predicate and the suite block
  are theirs; AC-8 (`pull_request_target`), AC-9's bookkeeping and DV-3(b)/DV-4
  are upstream's additions. Downstream material, extracted read only at
  PLANNED into the session scratchpad
  `C:/Users/ryanc/AppData/Local/Temp/claude/4cfd7d19cf4ea1ee/13cff595-70f1-48a0-9b4b-07e8e971562b/scratchpad/cc-port/`
  (`cc-HARNESS-052-story.md`, `ci-local.sh.patch`, `ci-local.test.sh.patch`,
  `sigpipe.test.sh.patch`, `cc-harness-052.patch`); `D:\clean_calendar` was
  not touched. If the scratchpad is gone, C-2 carries the script change
  verbatim and the suite block is in clean_calendar's `main` at
  `.claude/tests/ci-local.test.sh`.
- **This blocks the clean_calendar 93 -> 119 refresh.** clean_calendar's copy
  of `scripts/ci-local.sh` and `.claude/tests/ci-local.test.sh` are LOCAL
  changes; refreshing before this lands would overwrite them and drop the fix
  and its twelve assertions. Once this is DONE, that refresh takes release 119.
- **Re-measured here, not copied.** clean_calendar's numbers were taken on its
  tree and do not carry: its `dirty=` pin went 169 -> 208 (here also 208,
  re-derived by applying the patch to a scratch copy: C-3), its ci-local floor
  was 28 -> 40 (here 32 -> 48 expected: C-4), its sigpipe floor was 82 (here
  91, unchanged). The suite patch does not apply here because of HARNESS-079's
  block; the sigpipe patch does not apply because that suite changed 13 times
  since release 93 - only the one line it changes is ported.
- **Phase split.** RED: the new describe block, the C-5 pin to 208, both floor
  files. Expected red: `ci-local: 38 passed, 10 failed` and the sigpipe C-5
  freshness assertion (`sigpipe: 90 passed, 1 failed` if the suite executes
  its floor of 91 today; RED measures it - a PLANNED run of the suite did not
  finish within the planning session). GREEN: C-2 in
  `scripts/ci-local.sh` and `VERSION` 119; then `ci-local` 48/0 and `sigpipe`
  91/0. Planned 2026-11-09 on `main` at `94acc3f`.
- PLANNED did not branch or commit (the dispatch said not to); the story file
  is the only file written.
- PLANNED → RED checks (orchestrator, 2026-11-09, `main` at `94acc3f`):
  - Every C-1 anchor was re-read and matches: `ci-local.sh` is 191 lines with
    `dirty=` at 169; `ci-local.test.sh` is 416 lines with `summary` at 416;
    the sigpipe pin is at 577; floors `ci-local 32` are at floors.conf 42 and
    selftest.test.sh 533; VERSION line 34 reads `118`.
  - **Callers:** no file outside `scripts/ci-local.sh` calls
    `workflow_files` or `triggers_on_pull_request`. Six other suites mention
    `ci-local.sh` (`boundaries`, `gates`, `host-load`, `procedure`,
    `run-lock`, `sigpipe`). None of them writes a workflow file, so the
    filter cannot change what they see: they read the script's text or run
    it over the real tree, whose two workflows trigger on `pull_request`.
  - `gates.sh --list`: every gate is unconfigured, so `required_gates: []`
    stands. The epic is empty.
