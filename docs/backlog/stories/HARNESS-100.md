---
id: HARNESS-100
title: ci-local runs only workflows that trigger on pull_request
slug: ci-local-runs-only-workflows-that-trigge
epic: 
type: fix
status: in-review
phase: REVIEW
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
            if (this == 0 && $0 !~ /^-[[:space:]]/) exit
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
  TRIGGERS.` above `workflow_files()` and the six-line comment above
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
    next column-0 line that is not a `- ` sequence item, so a block sequence
    written in column 0 under `on:` is read like an indented one;
    *amended in RED on the return for R-1 (2026-11-09, test-developer): the
    code line above was `if (this == 0) exit`, clean_calendar's, which
    drops a column-0 `- pull_request` workflow; R-1 records the PO decision
    to diverge here. The line count of the script does not change;*
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

*Results (orchestrator, 2026-11-09, tree `c5a37a0`, all run in GATES):*

**DV-1, passed.** The same ten reds as RED, the floor FAIL at 38 against 48, and the restore verified:

```
=== mutate: scripts/ci-local.sh (1 line(s) changed by s/if triggers_on_pull_request "\$f"; then/if true; then/) ===
=== mutate: running bash scripts/selftest.sh ci-local ===
    FAIL AC-1: a push-only workflow's step is not listed
    FAIL AC-5: pull_request mentioned outside on: does not count
    FAIL AC-6: an excluded workflow is named on stderr
    FAIL AC-6: so is the one that only mentions pull_request
    FAIL AC-8: on: [pull_request_target] is not listed
    FAIL AC-8: a block on: holding only pull_request_target: is not listed
    FAIL AC-8: the inline pull_request_target workflow is named on stderr
    FAIL AC-8: the block pull_request_target workflow is named on stderr
    FAIL AC-2: the push-only workflow's step did not run
    FAIL AC-6: a real run names the excluded workflow too
ci-local: 38 passed, 10 failed
FAIL ci-local  did 38 units of work, below the floor of 48 in .claude/tests/floors.conf
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_ci-local.sh.20261109T222245Z.2092607.bak) ===
mutate: no stranded mutation; nothing of a previous run is in the tree.
```

**DV-2, passed.** AC-3 and AC-4 go red and no AC-1 assertion fails (0 `FAIL AC-1:` lines). The count, 21 passed and 27 failed, matches the handoff's scratch-copy prediction; the rest are older inline-`on:` fixtures, the expected collateral. The restore was verified:

```
=== mutate: scripts/ci-local.sh (1 line(s) changed by s/found = (v ~/found = 0 \&\& (v ~/) ===
=== mutate: running bash scripts/selftest.sh ci-local ===
    FAIL AC-3: on: [push, pull_request] is listed
    FAIL AC-4: a bare on: pull_request is listed
ci-local: 21 passed, 27 failed
FAIL ci-local  did 21 units of work, below the floor of 48 in .claude/tests/floors.conf
=== mutate: command exited 1; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/scripts_ci-local.sh.20261109T222325Z.2093428.bak) ===
```

**DV-3(a), passed.** Unmutated, `ci-local.sh --dry-run` lists the `scripts/check-boundaries.sh` step once and prints 0 `not running` notes. With the real `boundaries.yml`'s `  pull_request:` changed to `  push:`, it prints the note and drops that step. The restore was verified:

```
=== mutate: .github/workflows/boundaries.yml (1 line(s) changed by s/^  pull_request:$/  push:/) ===
=== mutate: running bash -c bash scripts/ci-local.sh --dry-run 2>&1 ===
note: not running boundaries.yml: it does not trigger on pull_request
=== mutate: command exited 0; restored (verified byte-for-byte against /d/agentic-dev-harness/.claude/state/mutations/.github_workflows_boundaries.yml.20261109T222358Z.2094238.bak) ===
```

**DV-3(b), passed.** Two `--no-hardlinks` scratch clones, with `deploy.yml.template` renamed to `deploy.yml` and its leading `# ` stripped as its header says. At the story branch (`c5a37a0`), neither deploy step is listed and the note is printed. The control at `main` (`94acc3f`, the unfixed script) lists both:

```
story branch c5a37a0: lists 'gates.sh --gate build': 0; lists 'your target here': 0
  note: not running deploy.yml: it does not trigger on pull_request
main 94acc3f:         lists 'gates.sh --gate build': 1; lists 'your target here': 1; not-running notes: 0
```

**DV-4, passed.** Two `--no-hardlinks` clones of the story branch were given clean_calendar's real workflows (from its `main`, `a2c4f51`: `boundaries.yml`, `deploy.yml`, `deploy.yml.template`, `gates.yml`). The second clone also got clean_calendar's own `scripts/ci-local.sh`. Nothing was run in the clean_calendar clone. The results: 0 supabase deploy lines are listed; the `deploy.yml` note appears in both; stdout is byte-identical across the two, 11 lines; the `not running` lines are identical; and all 11 `run:` steps of the copied `gates.yml` and `boundaries.yml` are listed, the one `${{ github.base_ref }}` step resolved rather than skipped:

```
pnpm install --frozen-lockfile
pnpm exec playwright install --with-deps chromium
pnpm exec supabase start
bash scripts/selftest.sh
FORCE_COLOR=1 CLICOLOR_FORCE=1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=color.ui GIT_CONFIG_VALUE_0=always bash scripts/selftest.sh
bash scripts/check-sigpipe.sh
bash scripts/check-grep-count.sh
bash scripts/gates.sh --list
bash scripts/gates.sh --audit
bash scripts/gates.sh
bash scripts/check-boundaries.sh origin/story/HARNESS-100-ci-local-runs-only-workflows-that-trigge
note: not running deploy.yml: it does not trigger on pull_request
stdout byte-identical to clean_calendar's own script: yes (11 lines); run: steps missing: 0
```

*Re-run after R-1 (orchestrator, 2026-11-10, tree `4fe2e73`):* all four pass again on the fixed script.

- **DV-1:** the same reds as before plus the two R-1 push-only assertions, 40 passed and 12 failed. With the filter neutralised, the column-0 push-only workflow is listed and is not noted. The restore was verified.
- **DV-2:** 25 passed, 27 failed. AC-3 and AC-4 are red, and AC-1 and all four R-1 assertions stay green, because neither uses an inline `on:` value. The restore was verified.
- **DV-3(a):** with the real `boundaries.yml` made push-only, its note is printed and the `check-boundaries.sh` step is dropped; unmutated, 0 notes. The restore was verified.
- **DV-3(b):** with the template renamed to `deploy.yml`, the branch lists no deploy step and prints the note. The `main` control lists both steps.
- **DV-4:** clean_calendar's real workflows produce 0 supabase lines and 11 steps. Stdout is byte-identical to clean_calendar's own script, and the `deploy.yml` notes are identical. R-1 diverges from clean_calendar only on column-0 `on:` sequences, which its workflows do not use.

```
    FAIL AC-1: a push-only workflow's step is not listed
    FAIL AC-5: pull_request mentioned outside on: does not count
    FAIL AC-6: an excluded workflow is named on stderr
    FAIL AC-6: so is the one that only mentions pull_request
    FAIL AC-8: on: [pull_request_target] is not listed
    FAIL AC-8: a block on: holding only pull_request_target: is not listed
    FAIL AC-8: the inline pull_request_target workflow is named on stderr
    FAIL AC-8: the block pull_request_target workflow is named on stderr
    FAIL R-1: a column-0 on: sequence holding only - push is not listed, though jobs: mentions pull_request
    FAIL R-1: the column-0 push-only workflow is named on stderr
    FAIL AC-2: the push-only workflow's step did not run
    FAIL AC-6: a real run names the excluded workflow too
ci-local: 40 passed, 12 failed
    FAIL AC-3: on: [push, pull_request] is listed
    FAIL AC-4: a bare on: pull_request is listed
ci-local: 25 passed, 27 failed
note: not running boundaries.yml: it does not trigger on pull_request
DV-3(b) 4fe2e73: build=0 target=0 note=1 | main 94acc3f: build=1 target=1 note=0
DV-4 supabase=0 steps=11 stdout byte-identical to clean_calendar's script: yes
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
- RED - `test-developer`, planned `opus`, resolved **claude-opus-5-5**
  (2026-11-09), self-reported; `model: opus` passed. As planned.
- GREEN - `feature-developer`, planned `opus`, resolved **claude-opus-5-5**
  (2026-11-09), self-reported; `model: opus` passed. As planned.
- GATES - `feature-developer` (full gates run), planned `opus`, resolved
  **claude-opus-5-5** (2026-11-09), self-reported; `model: opus` passed. As
  planned.
- GATES - `feature-developer` (diff review, fresh), planned `opus`, resolved
  **claude-opus-5-5** (2026-11-09), self-reported. Ship, with Should fix 1 (R-1).
- RED (return, R-1) - `test-developer`, planned `opus`, resolved
  **claude-opus-5-5** (2026-11-09), self-reported. As planned.
- GREEN (after R-1) - `feature-developer`, planned `opus`, resolved
  **claude-opus-5-5** (2026-11-09), self-reported. As planned.
- GATES (after R-1) - `feature-developer` (full gates run), planned `opus`,
  resolved **claude-opus-5-5** (2026-11-10), self-reported. As planned.
- GATES (after R-1) - `feature-developer` (second diff review, fresh), planned
  `opus`, resolved **claude-opus-5-5** (2026-11-10), self-reported. Ship.
- GATES (after R-1) - `feature-developer` (`--changed` self-test), planned `opus`,
  resolved **claude-opus-5-5** (2026-11-10), self-reported. As planned.

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

Level: integration, one fixture. Every new assertion runs the real
`scripts/ci-local.sh` (dry and real) inside one `make_project_fixture` tree,
`TFIX`, whose `.github/workflows/` holds seven test-written workflows, each with
one step `touch .m-<name>`. That is the cheapest level that can falsify the
criteria: the predicate is private to the script, and what the story promises
is the script's stdout, stderr and side effects. All in one new describe,
`only workflows CI runs on a pull request`, at `.claude/tests/ci-local.test.sh`
416-579 (after HARNESS-079's `rm -rf "$SFIX"`, before `summary "ci-local"`).
Whole-line matching through `has_line` (awk `$0 == n` over a here-string);
substring absence through `has_text` (awk `index`). No `printf | grep -q`.

| Fixture file | `on:` | Role |
|---|---|---|
| `gates.yml` | block: `pull_request:`, a comment line, `schedule:` + `- cron:`, `workflow_dispatch:` | AC-1 positive, AC-2 control, AC-6 "not reported" |
| `deploy.yml` | block: `push:` + `branches: [main]`, `workflow_dispatch:` (deploy.yml.template's shape) | AC-1/AC-2 negative, AC-6 note |
| `both.yml` | `[push, pull_request]` | AC-3 |
| `bare.yml` | `pull_request` | AC-4 |
| `release.yml` | block `push:`; `pull_request` in a comment above `on:` and in `if: github.event_name != 'pull_request'` | AC-5 control (grep-the-word filter), AC-6 note |
| `target.yml` | `[pull_request_target]` | AC-8 control, inline branch |
| `target-block.yml` | block: `pull_request_target:` | AC-8 control, block branch |

Assertions (16, all unconditional, no loop):

| # | Title (as printed) | AC | Red today? |
|---|---|---|---|
| 1 | `AC-1: a block on: with pull_request among other events is listed` | AC-1 + | no (pass on arrival) |
| 2 | `AC-1: a push-only workflow's step is not listed` | AC-1 - | **yes** |
| 3 | `AC-3: on: [push, pull_request] is listed` | AC-3 | no (earned by DV-2) |
| 4 | `AC-4: a bare on: pull_request is listed` | AC-4 | no (earned by DV-2) |
| 5 | `AC-5: pull_request mentioned outside on: does not count` | AC-5 | **yes** |
| 6 | `AC-6: an excluded workflow is named on stderr` (deploy.yml, dry) | AC-6 | **yes** |
| 7 | `AC-6: so is the one that only mentions pull_request` (release.yml, dry) | AC-6 | **yes** |
| 8 | `AC-6: an included workflow is not reported excluded` | AC-6 | no (pass on arrival) |
| 9 | `AC-8: on: [pull_request_target] is not listed` | AC-8 | **yes** |
| 10 | `AC-8: a block on: holding only pull_request_target: is not listed` | AC-8 | **yes** |
| 11 | `AC-8: the inline pull_request_target workflow is named on stderr` | AC-8 | **yes** |
| 12 | `AC-8: the block pull_request_target workflow is named on stderr` | AC-8 | **yes** |
| 13 | `AC-2: the real run succeeds` (exit 0) | AC-2 | no (pass on arrival) |
| 14 | `AC-2: the pull_request workflow's step ran` (`.m-gates` exists) | AC-2 control | no (pass on arrival) |
| 15 | `AC-2: the push-only workflow's step did not run` (`.m-deploy` absent) | AC-2 | **yes** |
| 16 | `AC-6: a real run names the excluded workflow too` (combined output) | AC-6 | **yes** |

AC-7: no existing assertion touched (`git diff` of the suite is 164 pure
insertions, 0 deletions). AC-9: `floors.conf` line 42 and `selftest.test.sh`
line 533 both `48`; `sigpipe.test.sh` 577 moved 169 -> 208; `sigpipe` floor
91 unchanged; VERSION is GREEN's.

Note on naming: HARNESS-079's describe also titles its assertions `AC-8: ...`
(its own story's AC-8, the two-job gates.yml). The texts differ, so every
FAIL line is still unique; read the title, not only the prefix.

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

RED by `test-developer`, model **`claude-opus-5-5`** (Opus 5.5), as planned
(`opus`); no override in the dispatch. 2026-11-09, Windows host, local. Every
number below is from a local run; none from CI.

**Commands** (run through the attestation wrapper exactly as written):

    bash scripts/attest.sh -- bash scripts/selftest.sh ci-local
    bash scripts/attest.sh -- bash scripts/selftest.sh sigpipe
    bash scripts/attest.sh -- bash scripts/gates.sh --fast

**Files touched (all test / harness paths):**

- `.claude/tests/ci-local.test.sh` - new describe at 416-579 (C-4). +164, 0 removed.
- `.claude/tests/sigpipe.test.sh` - line 577 only: `scripts/ci-local.sh:169:dirty="$(git status` -> `scripts/ci-local.sh:208:dirty="$(git status` (C-3).
- `.claude/tests/floors.conf` - line 42 `floor | ci-local      | 48` (was 32), and a HARNESS-100 paragraph at the end of the comment block (C-5).
- `.claude/tests/selftest.test.sh` - line 533 `ci-local 48` (was 32).
- this story: `## Test plan`, this section.
- NOT touched: `scripts/ci-local.sh`, `.claude/harness/VERSION` (both GREEN's).

**ci-local, verbatim** (record `exit: 1`, `last: 1 of 1 harness suite(s) FAILED.`,
`log: .claude/state/attest-logs/20261109T212313Z.2053201.log`, tree
`280a045b688b5c43151be0b568a4815e9f2bb32e`, status ok, 44 s):

    FAIL AC-1: a push-only workflow's step is not listed
    FAIL AC-5: pull_request mentioned outside on: does not count
    FAIL AC-6: an excluded workflow is named on stderr
    FAIL AC-6: so is the one that only mentions pull_request
    FAIL AC-8: on: [pull_request_target] is not listed
    FAIL AC-8: a block on: holding only pull_request_target: is not listed
    FAIL AC-8: the inline pull_request_target workflow is named on stderr
    FAIL AC-8: the block pull_request_target workflow is named on stderr
    FAIL AC-2: the push-only workflow's step did not run
    FAIL AC-6: a real run names the excluded workflow too
    ci-local: 38 passed, 10 failed
    FAIL ci-local  did 38 units of work, below the floor of 48 in .claude/tests/floors.conf
    assertion floors: 0 of 1 suite(s) met their declared floor.
    1 of 1 harness suite(s) FAILED.

Why it is the right failure: exactly the ten the AC list's "expected red"
names (AC-1 negative, AC-2 `.m-deploy`, AC-5, the two dry AC-6 notes, the real
AC-6 note, the four AC-8), each red on its own assertion, and all 32 existing
assertions still green (AC-7). The suite loads and every assertion executes:
48 EXECUTED. The floor line is expected too: `selftest.sh` compares a floor
with the PASSED count (`did 38 units of work`), so the suite sits below 48
until GREEN lands. An earlier run before the floor edit (log
`.claude/state/attest-logs/20261109T210852Z.2037478.log`) printed the same ten
FAIL lines and `38 passed, 10 failed`.

**sigpipe, verbatim:** record `exit: 1`, `last: 1 of 1 harness suite(s) FAILED.`,
`log: .claude/state/attest-logs/20261109T212413Z.2054252.log`, tree
`280a045b688b5c43151be0b568a4815e9f2bb32e`, status ok, 425 s:

    FAIL C-5 freshness: all twelve status-discarded lines are still where this suite says they are
         expected: 12 lines, none stale
         actual:   12 lines,
           scripts/ci-local.sh:208 no longer holds [dirty="$(git status] - it holds:
    sigpipe: 90 passed, 1 failed
    FAIL sigpipe  did 90 units of work, below the floor of 91 in .claude/tests/floors.conf
    assertion floors: 0 of 1 suite(s) met their declared floor.
    1 of 1 harness suite(s) FAILED.

The one red is the moved pin: today's 191-line script has no line 208 (hence
"it holds:" with nothing after it). That is the C-3 freshness assertion and
nothing else; 91 executed, as the floor says. (An earlier sigpipe run,
started before the floor edit, was killed by me part-way so the recorded run
would be on the final tree - log
`.claude/state/attest-logs/20261109T211052Z.2038481.log`; it is not evidence.)

**gates --fast:** record `exit: 0`, `last: All required gates passed (0 ran, 5 unconfigured, 0 known).`,
`log: .claude/state/attest-logs/20261109T213135Z.2066384.log`, status ok, 2 s.
Every gate is UNCONFIGURED in this unbootstrapped tree (format, lint,
typecheck, unit, coverage), mutation ON REQUEST; so `--fast` judges nothing
here and the suites above are the evidence. (A first attempt at 21:27:59 was
refused by the run lock while sigpipe ran - log
`.claude/state/attest-logs/20261109T212759Z.2058902.log`, exit 2 - and was
rerun after it.)

**selftest (C-8, for the floor tables):** record `exit: 0`,
`last: 1 harness suite(s) passed.`,
`log: .claude/state/attest-logs/20261109T213146Z.2066542.log`, same tree,
233 s: `selftest: 366 passed, 0 failed` - the two floor tables agree at 48.

**Measured floors:** ci-local **48** executed (38 + 10) - written to both
files. sigpipe **91**: measured 91 executed (90 + 1), so the floor stays 91 in both files, unchanged. Neither number is arithmetic
on the Contract; the Contract's predictions (48; 38/10) matched the run.

**What GREEN must do:**

1. Apply C-2 to `scripts/ci-local.sh` exactly: the `workflow_files()` body,
   `triggers_on_pull_request()` and the two comment blocks, with the comment's
   `(HARNESS-052)` becoming `(HARNESS-100, from clean_calendar's HARNESS-052)`
   and the supabase example becoming upstream's `deploy.yml.template`,
   **without changing the number of lines**. Keep the function name
   `triggers_on_pull_request` (the DVs target it).
2. Confirm `grep -n 'dirty="\$(git status' scripts/ci-local.sh` prints `208:`
   (re-verified in RED: clean_calendar's `ci-local.sh.patch` applied with
   `git apply` to a scratch copy of this tree's script gives 230 lines and
   `208:dirty=...`, byte-identical to the planner's
   `scratchpad/h100/ci-local.sh`). If it does not land on 208, stop: the pin is
   frozen in GREEN.
3. `.claude/harness/VERSION` line 34: `118 (2026-11-08)` -> `119 (<date>)`.
4. Run `bash scripts/selftest.sh ci-local`, `... sigpipe`, `... selftest`.

**Predicted post-GREEN counts** (measured, not derived: a `--no-hardlinks`
scratch clone of this branch with this suite and the patched script from step 2,
clean_calendar's comment wording): `ci-local: 48 passed, 0 failed`. sigpipe:
`sigpipe: 91 passed, 0 failed` predicted (not measured with the patched
script: the C-5 freshness pin is the only assertion that reads the line, and the
patched copy has the shape at 208).

**Export shape the tests pin.** Not a module: the tests pin the script's
observable contract only -
- stdout of `--dry-run`: one step per line; `touch .m-<name>` for included
  workflows, nothing for excluded ones;
- stderr: the whole line `note: not running <basename>: it does not trigger on pull_request`
  per excluded file, verbatim, and none for an included one; on a real run the
  same line appears in the combined output;
- a real run exits 0 and executes only included steps.
Not constrained: the function names, the awk technique, the order of the
notes relative to each other, where in stderr the notes fall. (C-7.)

**Passed on arrival** (today's script includes everything): #1, #3, #4, #8,
#13, #14. #1/#13/#14 are the controls that the run happened at all; #8 is
vacuous until a filter exists, earned by DV-1's restoring direction; #3/#4 are
earned by DV-2 (GATES). None is earned in RED - no production code exists to
mutate that would make them red. This is declined below, not claimed.

**Negative controls - expected values.** Measured outside the worktree, in the
scratch clone above, by replacing the predicate in a COPY of the patched
script (never `scripts/ci-local.sh` in the worktree). These are RED's
measurements against the clean_calendar-worded copy; GREEN/GATES confirm them
against the shipped script.

| Control | Mutation (in the scratch copy) | Expected reds | Measured |
|---|---|---|---|
| none (patched script) | - | 0 | `48 passed, 0 failed` |
| unfixed script (today) | - | 10: #2 #5 #6 #7 #9-12 #15 #16 | `38 passed, 10 failed` (the worktree run) |
| AC-5 / grep-the-word filter | `triggers_on_pull_request() { grep -q pull_request "$1"; }` | #5, #7, #9-12 | `42 passed, 6 failed` (exactly those six) |
| AC-8 inline-branch prefix | `pull_request([^A-Za-z0-9_]\|$)/` -> `pull_request/` on the `found = (v ~` line | #9, #11 | `46 passed, 2 failed` (exactly those) |
| AC-8 block-branch prefix | line 118 `pull_request["\047]?[[:space:]]*(:\|#\|$)/` -> `pull_request/` | #10, #12 | `46 passed, 2 failed` (exactly those) |
| DV-1 expression | `s/if triggers_on_pull_request "\$f"; then/if true; then/` | the ten above | `38 passed, 10 failed`, the same ten FAIL lines |
| DV-2 expression | `s/found = (v ~/found = 0 \&\& (v ~/` | #3, #4 red; #1, #2 green; older inline fixtures red | `21 passed, 27 failed`; FAIL list includes #3, #4 and the HARNESS-079 `AC-8:` four; #1/#2 not in it |

So each control fires on the branch it exists for and on nothing else: the
two prefix controls split cleanly by branch, which is why AC-8 has two files.

**DV expressions re-checked against the patched copy:** DV-1's literal
`if triggers_on_pull_request "$f"; then` occurs on exactly 1 line; DV-2's
`found = (v ~` on exactly 1 line; DV-3(a)'s `^  pull_request:$` on exactly 1
line of the real `.github/workflows/boundaries.yml` (line 9; file is LF). No
correction needed. DV-2 measured 21/27 here (48 executed) against
clean_calendar's 17/23 (40): the difference is HARNESS-079's four inline
fixtures and this story's AC-8 four (which stay green, being excluded anyway).

**Deferred verifications declined.** DV-1, DV-2, DV-3 and DV-4 are owned by
GATES and I did not run them: DV-1 and DV-2 mutate the real
`triggers_on_pull_request`, which does not exist in this tree yet; DV-3 and
DV-4 need the fixed script. The scratch-copy measurements in the table above
are NOT those verifications - they ran against a copy, outside the worktree,
not through `mutate.sh` - and are recorded only as expected values.

**Callers check.** `grep -rn 'workflow_files\|triggers_on_pull_request'` over
`*.sh`, `*.md`, `*.yml` outside `scripts/ci-local.sh` and this story: no
hits. Suites mentioning `ci-local`: boundaries, gates, host-load, procedure,
rules-trim, run-lock, selftest, sigpipe (plus ci-local). None writes into
`.github/workflows` (`grep` for `workflows` with a write verb in each:
none); they read the script's text, pin its line (sigpipe) or its floor
(selftest), or quote a summary line (rules-trim). The filter cannot change
what they see.

**Discovered.** Nothing that changes the approach. The Contract's C-1..C-8
stand as written; no amendment.

### GREEN

feature-developer, resolved model `claude-opus-5-5`, no override.
clean_calendar's `ci-local.sh.patch` applied with `git apply` unchanged (191
-> 230 lines). Comment edits made in place, line count held at 230: the
example now names `deploy.yml.template` (renamed to deploy.yml, its `push`
deploy would have run locally), the reference reads `(HARNESS-100, from
clean_calendar's HARNESS-052)`, and the block's closing clause "in the same
voice as a skipped step" was dropped to keep the five-line count. No code
line differs from C-2. `dirty=` is at **208**. VERSION line 34 -> `119
(2026-11-09)`.

Controls against the shipped script: patched script `ci-local: 48 passed,
0 failed` (floor 48 met) and `sigpipe: 91 passed, 0 failed`, matching RED's
predictions. Each DV target occurs exactly once in the shipped file:
`if triggers_on_pull_request "$f"; then` (1), `found = (v ~` (1), the
inline-branch `pull_request([^A-Za-z0-9_]|$)/` (1), the block-branch
`pull_request["\047]?[[:space:]]*(:|#|$)/` (1, at line 118 as the handoff
says), and `^  pull_request:$` in `.github/workflows/boundaries.yml` (line
9). DV mutations not run: GATES owns them.

### R-1 (return to RED)

test-developer, model **`claude-opus-5-5`** (Opus 5.5). The plan says
`opus` and the dispatch had no override. Run on 2026-11-09, Windows host,
locally. Every number here comes from a local run. None comes from CI.

**Added.** The `TFIX` fixture in the HARNESS-100 describe of
`.claude/tests/ci-local.test.sh` gains `compact.yml` and `compact-push.yml`.
Four assertions titled `R-1: ...` go after the AC-8 ones. Their shapes, the
indentation departure from the brief and why are in `## Regressions` R-1. No
existing assertion changed. Files touched: `.claude/tests/ci-local.test.sh`
(+40 lines), `.claude/tests/floors.conf` (line 42 now `52`, plus an R-1
paragraph at the end), `.claude/tests/selftest.test.sh` (line 533 now
`ci-local 52`), and this story: the C-2 code line and its block-end bullet
were amended in place with a reason, plus this part and R-1.

| # | Assertion | On today's script |
|---|---|---|
| R-1a | `touch .m-compact` is a whole stdout line of `--dry-run` | FAIL |
| R-1b | stderr holds no `not running compact.yml` | FAIL |
| R-1c | no whole stdout line `touch .m-compact-push` | pass (earned by the over-broad mutant) |
| R-1d | stderr holds the whole line `note: not running compact-push.yml: it does not trigger on pull_request` | pass (earned, same mutant) |

**Red** (record: `exit: 1`, `last: 1 of 1 harness suite(s) FAILED.`,
`log: .claude/state/attest-logs/20261109T233145Z.2103978.log`):

    $ bash scripts/attest.sh -- bash scripts/selftest.sh ci-local
        FAIL R-1: an on: sequence written in column 0 holding - pull_request is listed
        FAIL R-1: the column-0 pull_request workflow is not reported excluded
    ci-local: 50 passed, 2 failed

It is the right failure. stdout lacks `touch .m-compact`, and stderr carries
`note: not running compact.yml: ...`: the predicate reads the workflow as
OUT. The run's floor line ("did 50 units of work, below the floor of 52")
shows what a red suite counts. The first RED looked the same way (38 against
48).

**Earned probe** (pasted in `## Regressions` R-1). On the scratch clone, the
planned fix gives `52 passed, 0 failed`. The over-broad `if (0) exit` gives
`50 passed, 2 failed`, with exactly R-1c and R-1d red.

**New floor.** ci-local **52** executed (50 + 2), in both
`floors.conf:42` and `selftest.test.sh:533`. sigpipe stays 91: no pin moved.

**GREEN's job.**
1. In `scripts/ci-local.sh`, line 114: `if (this == 0) exit` becomes
   `if (this == 0 && $0 !~ /^-[[:space:]]/) exit`. That is one line, edited in
   place, and the file stays 230 lines. `grep -n 'dirty="\$(git status'
   scripts/ci-local.sh` must still print `208:`, because sigpipe pins it and
   that pin is frozen.
2. Line 45: `sed -n '2,32p'` becomes `sed -n '2,33p'` (diff review, nice to
   have 2).
3. `.claude/harness/VERSION` stays at `119`, because GREEN already wrote it.
4. Run `bash scripts/selftest.sh ci-local`, `... sigpipe` and
   `... selftest`.

If the C-2 comment's description of the block end should mention column-0
items, rewording it must not change the line count. The tests do not
constrain the comment.

**Predicted counts after GREEN**, measured on the clone with the planned fix
(the `--help` change was not applied there): `ci-local: 52 passed, 0 failed`,
and `sigpipe: 91 passed, 0 failed`. The sigpipe figure is predicted, not
measured: `dirty=` stays at 208 on the clone.

**Negative control, expected value:**

| Control | Mutation (clone copy) | Expected reds | Measured |
|---|---|---|---|
| planned fix | - | 0 | `52 passed, 0 failed` |
| unfixed (today) | - | R-1a, R-1b | `50 passed, 2 failed` (worktree, attested) |
| over-broad block end | line 114 → `if (0) exit` | R-1c, R-1d | `50 passed, 2 failed` (exactly those) |

**gates --fast** (record: `exit: 0`, `last: All required gates passed (0 ran,
5 unconfigured, 0 known).`, `log:
.claude/state/attest-logs/20261109T233437Z.2107787.log`). Every gate is
unconfigured in this tree, so this run judges nothing.

**selftest** (C-8, which checks the floor tables). Record: `exit: 0`, `last: 1 harness suite(s) passed.`,
`log: .claude/state/attest-logs/20261109T233449Z.2107981.log`, 334 s,
`selftest: 366 passed, 0 failed`. Both floor tables agree at 52. All three
records are on tree `6a408038`, and `attest.sh check` on the ci-local record
says `fresh`.

### GREEN (after R-1)

feature-developer, model **`claude-opus-5-5`** (Opus 5.5), with no override.
Two lines changed in `scripts/ci-local.sh`, each edited in place. Line 114:
`if (this == 0) exit` became `if (this == 0 && $0 !~ /^-[[:space:]]/) exit`.
Line 45: `sed -n '2,32p'` became `sed -n '2,33p'`. The file is still 230
lines with LF endings (`i/lf w/lf`). `dirty=` is still on line 208.
VERSION is unchanged at `119`. `--help` now ends with
`story if the PR's own checks never ran.`

Records, all `fresh` under `attest.sh check`:

    ci-local  exit: 0  last: 1 harness suite(s) passed.  log: .claude/state/attest-logs/20261110T001310Z.2119232.log
              ci-local: 52 passed, 0 failed (floor 52 met)
    sigpipe   exit: 0  last: 1 harness suite(s) passed.  log: .claude/state/attest-logs/20261110T001404Z.2120064.log
              sigpipe: 91 passed, 0 failed (floor 91 met)
    --fast    exit: 0  last: All required gates passed (0 ran, 5 unconfigured, 0 known).  log: .claude/state/attest-logs/20261110T002146Z.2131618.log

The negative controls match RED. The planned fix gives `52 passed, 0 failed`,
the number the scratch clone predicted. The unfixed and over-broad rows were
measured in RED and not re-run here. The sigpipe prediction (91) is confirmed.

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

- **R-1 (2026-11-09, found at GATES → REVIEW by the fresh diff review).**
  - **What is missing:** a case. `triggers_on_pull_request` ends the `on:`
    block at the first line in column 0 (`if (this == 0) exit`). YAML also
    allows a block sequence in column 0 under its key (`on:` then
    `- pull_request`), and GitHub accepts that form. Such a workflow comes
    out OUT, so its steps are silently skipped and the run still reports
    green. This is the one failure the script exists to prevent. It is the
    unindented layout of the `- pull_request` shape the predicate already
    claims to read (C-2's comment), not a parser feature.
  - **How it was found:** the diff review measured it on a copy. The
    orchestrator reproduced it independently with its own fixtures on a copy
    of the shipped predicate:

        compact: OUT        (on:\n- pull_request\n- workflow_dispatch\njobs:...)
        indented: IN        (on:\n  - pull_request\njobs:...)
        compact-push: OUT   (on:\n- push\njobs:\n  a:\n    steps:\n    - pull_request)

  - **What RED adds:** a fixture workflow whose `on:` is a column-0 block
    sequence holding `- pull_request`. It must be listed and must get no
    `not running` note. A column-0 sequence holding only `- push` must not be
    listed. RED watches the first case fail against today's shipped script,
    so it is a new test against existing code that fails, earned by its own
    red.
  - **What GREEN changes (Contract C-2 amended, a PO decision):** at that one
    line, `if (this == 0 && $0 !~ /^-[[:space:]]/) exit`, so a column-0 `- `
    item continues the block while any other column-0 line (`jobs:`) still
    ends it. This is a deliberate divergence from clean_calendar's code. That
    project has the same gap, and its next refresh takes the fix.
  - **What RED added (test-developer, `claude-opus-5-5`, 2026-11-09):** two
    workflows in the existing `TFIX` fixture and four assertions after the
    AC-8 ones (`.claude/tests/ci-local.test.sh`). No existing assertion's
    text or expected value changed, and none could see the new files: their
    needles are `m-deploy`, `m-release`, `not running gates.yml` and whole
    lines naming other markers. `compact.yml` (`on:` / `- pull_request` /
    `- workflow_dispatch` in column 0, step `touch .m-compact`): listed as a
    whole line, and no `not running compact.yml` on stderr. `compact-push.yml`
    (`on:` / `- push` / `jobs:` / `- pull_request` / `- run: touch
    .m-compact-push`, all in column 0): not listed, and its whole-line note
    printed. **Departure from the brief:** the brief put the push control's
    `pull_request` mention under `jobs:` → `steps:`, indented. That shape
    cannot fail against the over-broad fix: the first-indentation rule
    (`ind = 0`) skips every indented line whatever ends the block. Measured
    on the scratch clone, the over-broad predicate gives OUT for it:

        $ triggers_on_pull_request indented.yml   # on:/- push/jobs:/  a:/.../    - pull_request, with `if (0) exit`
        OUT

    So the mention is in column 0. That is the diff review's measured shape
    (`on:\n- push\njobs:\n- pull_request`). The no-note negative uses
    `has_text`, the same as the existing gates.yml one, because the absence
    of a substring is the stronger negative. It also cannot match
    `compact-push.yml`'s note.
  - **Red against the shipped script** (the (a) pair; the (b) pair passes on
    arrival, because today's script excludes it):

        $ bash scripts/attest.sh -- bash scripts/selftest.sh ci-local
            FAIL R-1: an on: sequence written in column 0 holding - pull_request is listed
            FAIL R-1: the column-0 pull_request workflow is not reported excluded
                 stderr: note: not running compact-push.yml: it does not trigger on pull_request
                 note: not running compact.yml: it does not trigger on pull_request
        ci-local: 50 passed, 2 failed
        FAIL ci-local  did 50 units of work, below the floor of 52 in .claude/tests/floors.conf
        exit: 1   last: 1 of 1 harness suite(s) FAILED.
        log: .claude/state/attest-logs/20261109T233145Z.2103978.log

  - **Earned:** the (b) pair, on a `--no-hardlinks` clone of this branch
    (`scratchpad/r1-100`) with this suite and floors copied in. The
    worktree's `scripts/ci-local.sh` was never touched. Line 114 is replaced
    in the clone's copy only:

        planned fix  `if (this == 0 && $0 !~ /^-[[:space:]]/) exit` (230 lines, dirty= at 208)
        $ bash .claude/tests/ci-local.test.sh
        ci-local: 52 passed, 0 failed

        over-broad   `if (0) exit` (a column-0 line never ends the block)
        $ bash .claude/tests/ci-local.test.sh
            FAIL R-1: a column-0 on: sequence holding only - push is not listed, though jobs: mentions pull_request
            FAIL R-1: the column-0 push-only workflow is named on stderr
        ci-local: 50 passed, 2 failed

        restored     `if (this == 0 && $0 !~ /^-[[:space:]]/) exit`

    The over-broad mutant turns exactly the (b) pair red and nothing else.
    The (a) pair has its own red above.

## Diff review

Fresh `feature-developer` with the `diff-review` skill, 2026-11-09, over
`git diff 94acc3f HEAD` at `8ca43b0`. It resolved **claude-opus-5-5**, with
no override. It changed no file in the worktree, ran nothing there, and its
probes ran on copies in the scratchpad. Condensed; the findings are kept
whole.

- **Read correctly:** `on: # comment` followed by a block; `"on":`, `'on':`
  and `on :`; blank and comment lines before the first child; `push:` with
  nested `branches:` and then `pull_request:` at the same indent (IN); a
  `pull_request:` nested under `push:` (OUT); `- pull_request` in an indented
  sequence; CRLF in every form (IN, because `[[:space:]]` matches `\r`);
  `on: { pull_request: {} }` (IN) and `{pull_request_target: {}}` (OUT); a
  leading `---`; an `on:` key at deeper indent inside a job (OUT: the rule is
  anchored at column 0, and only the first top-level `on:` is read).
- **Not handled:** `true:` (OUT, which is correct, because GitHub reads
  `on`); tabs (YAML forbids them); anchors and multi-line flow sequences (out
  of scope); the column-0 block sequence (finding 1).
- **Other checks:** `deploy.yml.template` is not matched by `*.yml`; the
  loop emits gates.yml once, first; `scripts/gates.sh:1193` and
  `scripts/host-load.sh:10` mention ci-local only in comments; the
  derivation is unaffected. Every positive check is a whole-line
  `has_line`, and no substring negative can pass alone on an empty result.

**Should fix 1.** A pull-request workflow whose `on:` list is not indented
is dropped, and the run still reports green (`if (this == 0) exit`). The
proposed fix is `if (this == 0 && $0 !~ /^-[[:space:]]/) exit`; measured,
it reads the compact sequence as IN, keeps
`on:\n- push\njobs:\n- pull_request` OUT and leaves every other case
unchanged. It needs a fixture, so it goes back to RED. → **Taken, as R-1.**

**Nice to have 2.** `--help` cuts off the header's last line
(`sed -n '2,33p'`, not `'2,32p'`). It predates this story. → Folded into
GREEN, because it is the same file. It is one character, and the line count
does not change.

**Judgements:** skipping `workflow_dispatch`-only workflows is right.
Skipping `merge_group`-only and unfiltered `on: push` workflows is
defensible but leaves a gap for merge-queue consumers. CLAUDE.md, the README
and the header still say "every step CI runs", which the story's Out of
scope defers. → Recorded as a follow-up for the user.

Verdict: Ship.

*Orchestrator (2026-11-09):* Should fix 1 was reproduced independently (R-1)
and is taken here, since cause, reproduction and fix are all in hand. The
story returns to RED.

### Second review (2026-11-10, at `582b157`, after R-1)

Fresh `feature-developer` with the `diff-review` skill over the whole diff
`94acc3f..582b157`. It resolved **claude-opus-5-5**, with no override. It
changed no file in the worktree and ran nothing there; its probes ran on
copies in the scratchpad. Condensed; its measurements are kept.

- **The R-1 guard does not over-match.** I ran 18 hand-written files
  against the shipped check.
  - Read correctly (IN): a column-0 list with a blank line or a column-0
    `# comment` inside it; a leading `---`; `- "pull_request"`; CRLF; and
    `push:` with indented `branches:`, then `pull_request:`.
  - Dropped (OUT): a `---` or `...` inside the list; an empty `on:`
    followed by `jobs:` / `- pull_request`; `- pull_request_target`;
    `-pull_request` with no space; and a top-level `env:` before a column-0
    item.
  - A column-0 `- ` line keeps the block open only while no other column-0
    key has come first. To misread someone else's list, a file would need a
    column-0 item under `on:` that does not belong to `on:`. YAML gives such
    an item no other parent, and GitHub rejects workflows that do not parse.
- **`ind` interaction:** three mixed layouts (all invalid YAML) all come out
  OUT; no false IN.
- **R-1 assertions:** both positive checks and the "not listed" check are
  whole-line `has_line` checks. Each of the two substring absences reads an
  output on which a required whole line is also checked, so neither can
  pass on empty output. The column-0 step `- run: touch .m-compact-push` is
  readable by `workflow_steps`, so the "not listed" check is not passing
  merely because the step went unread.
- **`--help`:** prints exactly source lines 2-33, 32 lines, from `Run,
  locally and in order, …` to `story if the PR's own checks never ran.`,
  and no code.
- **Numbers:** the describe block holds 20 unconditional assertions. 32 +
  16 = 48, with 38/10 against the unfixed script; then 52, with 50/2
  before R-1's GREEN and 52/0 after. Both floor files say 52, and the
  sigpipe pin's line 208 matches.
- **C-2 matches the shipped code** byte for byte, except for whitespace.
  Two prose slips: "seven-line comment" should say six (now corrected), and
  C-2 does not mention `--help`, which is recorded under the first review
  and in Notes.
- **Nice to have 1:** the `--help` range is a hard-coded line number, which
  is how `2,32p` went wrong. Suggested replacement: stop at the first
  non-comment line.

Verdict: Ship.

*Orchestrator (2026-11-10):* the prose slip was corrected, story only.
Nice to have 1 is not taken, because it is a code change with no test and
would restart GATES. It is offered to the user as a follow-up.

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-11-10T00:26:16Z
    commit: 4fe2e73
    tree:   d0e1b97f893e2752d44c4f6c73bbea8e19be956c
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
- RED verified by the orchestrator (2026-11-09): `attest.sh check` said
  `fresh` for all three of RED's commands, so none was re-run.
  - `bash scripts/selftest.sh ci-local`: exit 1, `ci-local: 38 passed, 10
    failed`, log `20261109T212313Z.2053201.log`. The ten FAILs are exactly
    the AC list's "expected red"; the only other FAIL is the floor line.
  - `bash scripts/selftest.sh sigpipe`: exit 1, `sigpipe: 90 passed, 1
    failed`, log `20261109T212413Z.2054252.log`. The one FAIL is the moved
    C-5 pin, expected while the script has 191 lines.
  - `bash scripts/gates.sh --fast`: exit 0.
  - Diff read: `ci-local.test.sh` gains 164 lines and loses none (AC-7);
    `sigpipe.test.sh` changes line 577 only (169 → 208); `ci-local`'s floor
    goes 32 → 48 in both files; `sigpipe` stays at 91. `scripts/ci-local.sh`
    and VERSION are untouched.
- GREEN verified by the orchestrator (2026-11-09): `attest.sh check` said
  `fresh` for all three of GREEN's commands, so none was re-run.
  - `bash scripts/selftest.sh ci-local`: exit 0, `ci-local: 48 passed, 0
    failed`, log `20261109T214840Z.2088783.log`.
  - `bash scripts/selftest.sh sigpipe`: exit 0, `sigpipe: 91 passed, 0
    failed`, log `20261109T214141Z.2077815.log`.
  - `bash scripts/gates.sh --fast`: exit 0.
  - Diff read: `scripts/ci-local.sh` is 230 lines with `dirty=` at 208, the
    pinned line. With comments removed it is identical to clean_calendar's
    patched copy (C-2 holds exactly). Only the comment wording differs, as
    the handoff asked. Line endings are LF, matching `git ls-files --eol`
    `i/lf w/lf attr/text eol=lf`. VERSION is 119.
- GATES verified by the orchestrator (2026-11-09): I ran DV-1 to DV-4
  before `gates.sh`, and all passed; the results are pasted under
  `## Deferred verifications`. The full run was dispatched; `attest.sh check
  -- bash scripts/gates.sh` said `fresh` (exit 0, 2 s, log
  `20261109T222535Z.2095113.log`, verdict `All required gates passed (0 ran,
  7 unconfigured, 0 known).`), so it was not re-run. The developer changed
  no file.
- R-1 RED verified by the orchestrator (2026-11-09):
  - `attest.sh check` said `fresh` for `bash scripts/selftest.sh ci-local`
    (exit 1, `ci-local: 50 passed, 2 failed`, log
    `20261109T233145Z.2103978.log`). The two FAILs are exactly R-1a and
    R-1b, the column-0 `pull_request` workflow, and the floor line is the
    only other FAIL. `--fast` is also `fresh`, exit 0.
  - Diff read: `ci-local.test.sh` gains 40 lines and loses none, and
    `scripts/ci-local.sh` is untouched. The floor is now 52 in both files.
  - The test developer's departure from the brief on (b) was checked by
    reading the predicate. Once the first `on:` child is in column 0,
    `ind` is 0, so an indented `pull_request` under `jobs:` is skipped by
    `if (this != ind) next` whatever ends the block. That shape could not go
    red against an over-broad fix, and the column-0 shape it used instead
    can. Accepted.
- GREEN after R-1 verified by the orchestrator (2026-11-10): `attest.sh
  check` said `fresh` for all three of GREEN's commands, so none was re-run.
  - `bash scripts/selftest.sh ci-local`: exit 0, `ci-local: 52 passed, 0
    failed`, log `20261110T001310Z.2119232.log`. This matches RED's
    scratch-clone prediction.
  - `bash scripts/selftest.sh sigpipe`: exit 0, `91 passed, 0 failed`, log
    `20261110T001404Z.2120064.log`.
  - `bash scripts/gates.sh --fast`: exit 0.
  - Diff read: exactly two lines changed in `scripts/ci-local.sh`. One is the
    R-1 guard, `if (this == 0 && $0 !~ /^-[[:space:]]/) exit`; the other
    moves `--help` from `2,32p` to `2,33p`. The file is still 230 lines,
    `dirty=` is still at 208, and line endings are LF (`i/lf w/lf`).
- GATES after R-1 verified by the orchestrator (2026-11-10): I ran DV-1 to
  DV-4 again on `4fe2e73`, and all passed; the results are under `## Deferred
  verifications`. The full run was dispatched; `attest.sh check -- bash
  scripts/gates.sh` said `fresh` (exit 0, 2 s, log
  `20261110T002614Z.2135480.log`, verdict `All required gates passed (0 ran,
  7 unconfigured, 0 known).`), so it was not re-run.
- Diff review at GATES → REVIEW: the first review (`8ca43b0`) said Ship
  with Should fix 1, which was taken as R-1. The second review (`582b157`)
  said `Verdict: Ship.`. Both are in `## Diff review`.
- Self-test at GATES → REVIEW (2026-11-10): `selftest-needed: run`.
  `SELFTEST_JOBS=4 bash scripts/selftest.sh --changed` was dispatched,
  detached, and ran alone. `attest.sh check` said `fresh`, `exit: 0`,
  `last: 12 harness suite(s) passed.`, `duration: 2196s`, log
  `20261110T004905Z.2141876.log`. Header:
  `selftest: --changed — 12 of 34 suite(s) selected: boundaries ci-local doctor grep-count host-load lib procedure refresh run-lock selftest sigpipe worktree`.
  All 12 floors were met (2140 executed, 2140 declared), and the log has
  no FAIL line. `--changed` is enough here: `ci-local.sh` is not invoked by
  any other script (`gates.sh` and `host-load.sh` mention it only in
  comments), so case (b) does not apply.
- Follow-ups offered to the user, both outside this story:
  - `--help` uses a hard-coded line range; the second review suggests
    stopping at the first non-comment line.
  - `merge_group`-only and unfiltered `on: push` workflows are now
    skipped, and CLAUDE.md, the README and the script header still say
    "every step CI runs".
- This unblocks the clean_calendar 93 → 119 refresh.
