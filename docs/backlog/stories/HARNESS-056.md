---
id: HARNESS-056
title: A gate run that started earlier never overwrites a newer gate record
slug: a-gate-run-that-started-earlier-never-ov
epic: 
type: fix
status: todo
phase: PLANNED
branch: story/HARNESS-056-a-gate-run-that-started-earlier-never-ov
depends_on: [HARNESS-055]      # 052, 055 and 056 all edit scripts/gates.sh and the sigpipe line pins; serialise
touches: [scripts/gates.sh, .claude/tests/gates.test.sh, .claude/tests/sigpipe.test.sh, .claude/skills/quality-gates/SKILL.md]         # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

<!-- Why this story exists. Link the epic and any wiki pages that constrain it.
     Name the REQUIRED gate that would fail if this story's artifact broke. If
     only an optional gate can, put it in required_gates above before RED:
     every required gate once passed over a story none of them exercised. -->

**Port** of the second half of manhwa-cropper commit `dccbbf6` ("harness: one
gate run at a time, and a record that cannot go backwards";
`git -C D:/manhwa-cropper show dccbbf6`). Triaged 2026-10-11 against release
93; `scripts/gates.sh` is unchanged in release 94 (`8048134`).

**The field case, downstream (MC-026).** An orchestrator and a subagent it
had dispatched ran `gates.sh` at once in one checkout. The story ended up
recording `result: fail` against tree `2b4248021a96`, then `result: pass`
against the SAME tree, with three runs' durations interleaved, while the
coverage log on disk held a complete table at 99.71% against a floor of 95.
Nothing had failed; the losing process wrote last. Downstream fixed it with
two guards. The first - one run at a time - upstream already has in a
different form: `scripts/run-lock.sh` (HARNESS-034), refuse-never-wait, exit
2. The second is missing here, and it is the one that catches the MC-026
shape *directly*, whichever path lets two runs touch one story file.

**The defect, upstream, today.** `scripts/gates.sh` `record_in_story()`
(`:299-318`) stamps `run:` with `$(date …)` at *write* time (`:306`) and
replaces the `## Gate results` body unconditionally. Nothing compares the
record it is about to overwrite with the run doing the overwriting. So a run
that started earlier and finished later always wins, and a newer record -
possibly a `pass` against the tree the PR will carry - is replaced by an
older run's verdict.

**How two runs reach one story file with the refuse-only lock.** This is the
triager's reading of the code, NOT reproduced:

- a lock deleted by hand while the holder is still running. The refusal
  message invites exactly that (`scripts/run-lock.sh:66`: "If pid N is not
  that run, delete .claude/state/run.lock and run again"); after the delete
  a second run takes a fresh lock, finishes, records, and the first run
  records over it when it finishes;
- a nested run in the same tree. `run_lock_acquire` case (1)
  (`scripts/run-lock.sh:91-96`) lets a run through without taking the lock
  when `HARNESS_RUN_LOCK`/`HARNESS_RUN_LOCK_PID` name the live holder - by
  design, for a gate command that runs `selftest.sh`. A gate command that
  (transitively) runs `gates.sh` records into the same story before its
  parent does, and the parent then overwrites it;
- a pid that reads as dead when it is not: `run_lock_alive` is `kill -0`,
  and a lock written by a run on another host over a shared filesystem has a
  pid this host cannot see, so the lock is reclaimed under a live run.

The downstream wait-mode lock (`GATES_LOCK_WAIT`, `--no-wait`, exit 3,
host-aware stale detection) is a deliberate design difference and is **not**
ported; see Out of scope.

**The triage run, verbatim** - the downstream test adapted to this tree's
fixture (story on branch `story/T-1-fixture` and committed, because
HARNESS-026 refuses to record from another branch and HARNESS-014 refuses
while gated files are untracked), run against unpatched `scripts/gates.sh`:

    [dccbbf6 half 2] the record: an older run does not overwrite a newer one
      FAIL the older run declines to record
      FAIL saying whose record stands
      ok   and the gates' own verdict is unchanged
      FAIL the newer record is left alone
           ...    run:    2026-10-11T20:42:20Z   (the 2099 record was clobbered)
      ok   and was not appended to

With the port applied (the `record` part of the triage diff alone): 5
passed, 0 failed. The whole `gates.test.sh` with this port and the
HARNESS-055 `no-count` port together: `gates: 507 passed, 0 failed`
(47m36s wall).

**What reads `run:`.** Nothing but the eye. `grep -n 'run:'
scripts/check-boundaries.sh` finds only a comment at `:163`;
`check-boundaries.sh` reads `result:` (`:394`) and `tree:` (`:433`). So
changing `run:` from "when the record was written" to "when the run started"
breaks no reader, and the skill text that describes the record
(`.claude/skills/quality-gates/SKILL.md:497-515`, "The gate record is written
by the tool") is updated to say what it now means.

Required gate that fails if this breaks: `selftest`
(`.claude/tests/gates.test.sh` runs under `bash scripts/selftest.sh gates`
and in CI's `selftest` step). No optional gate is involved, so
`required_gates` stays empty.

## Acceptance criteria

<!-- Each AC is independently testable and phrased as observable behaviour.
     The Test Developer writes at least one failing test per AC.
     An AC that names a statistic, a metric or a threshold names a NEGATIVE
     CONTROL too: the deliberately broken input the metric must reject, and
     roughly what it should score. A criterion can be perfectly testable and
     still be blind to the defect it exists to catch, and that is more
     dangerous than a vague one - it survives review and goes green. -->

All criteria run in a project fixture (`make_project_fixture`) whose story
`T-1` is at phase GATES, on branch `story/T-1-fixture`, with the story file
committed, under a one-gate `project.conf` whose gate passes with evidence
(`printf 'Tests  47 passed (47)\n'`, `evidence | unit | Tests +[1-9][0-9]*
passed`). "A newer record" means a `## Gate results` body written in the
tool's own shape - the `GATE_MARKER` line from `.claude/hooks/lib.sh:38`,
then `run:`, `commit:`, `tree:`, `result:` and a summary line, four-space
indented - whose `run:` is `2099-01-01T00:00:00Z`.

- **AC-1** — Given the story holds a newer record, when a full `bash
  scripts/gates.sh` runs and its gate passes, then its output contains no
  line `recorded in docs/backlog/stories/T-1.md (## Gate results)` and
  contains exactly one line beginning `(not recorded: ` which names the
  story file, the standing record's `run:` value `2099-01-01T00:00:00Z`,
  and this run's own start time.
- **AC-2** — Given the same, when that run finishes, then the story's
  `## Gate results` body is byte-for-byte what it was before the run: the
  `run:` line still reads `2099-01-01T00:00:00Z`, `grep -c '^ *run: '` over
  the story file is `1`, and nothing was appended to or inserted in the
  section.
- **AC-3** — Given the same, when that run finishes, then its exit status is
  the gates' own verdict - `0` for the passing fixture gate - and
  `.claude/state/last-gate-run` says `RESULT=pass` and `FULL=yes`. Declining
  to record is not a refusal of the run and does not change what the gates
  judged.
- **AC-4** — Given the same fixture but with the gate failing (`printf
  'Tests  0 passed\n'; exit 1` or an evidence miss), when a full run
  finishes, then it still declines to record with the same `(not recorded:
  … )` line, the 2099 record still stands, and the exit status is the
  failing verdict (non-zero). A fail must not get to overwrite what a pass
  may not.
- **AC-5 (control: an older record is replaced)** — Given the story holds a
  record whose `run:` is `2000-01-01T00:00:00Z` (older than any run this
  test can start), when a full run passes, then the output contains exactly
  one line `recorded in docs/backlog/stories/T-1.md (## Gate results)`, no
  line beginning `(not recorded:`, the `run:` line now holds this run's
  start time (matches `^    run:    20[2-9][0-9]-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$`
  and is not `2000-01-01T00:00:00Z`), and `grep -c '^ *run: '` is `1`. The
  same holds for a story whose `## Gate results` section is empty (the
  template case): it is written, not declined.
- **AC-6** — Given no active story and `--list`, when `bash scripts/gates.sh
  --list` runs, then the HARNESS-024 AC-1 process budget (`gates.test.sh:1152`,
  "at most 20 processes, no sed, no cut" over the synthetic manifest) still
  holds with no assertion changed. The start-time capture must not cost
  `--list` a `date` process.

*Negative control for AC-1/AC-2/AC-4:* on the unpatched tree the triage run
above shows exactly which assertions go red - "declines to record", "saying
whose record stands", "the newer record is left alone" - and that the
clobbering value is this run's own write time. RED must watch each of
AC-1, AC-2 and AC-4 fail with that shape before GREEN. AC-3, AC-5 and AC-6
pass on the unpatched tree; they are controls, and their earning is DV-2.

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

**Writes:** `scripts/gates.sh`, `.claude/tests/gates.test.sh`, `.claude/tests/sigpipe.test.sh`, `.claude/skills/quality-gates/SKILL.md`

**Pinned by the Lead PO before RED (2026-10-12).** RED may amend any block
below in place, with a reason beside it; GREEN builds what the amended block
says. Line numbers are release 94's and will have moved once HARNESS-055
(the `no-count` port, which also edits `gates.sh`) is merged; GREEN re-greps.

- **The run's start time: `RUN_STARTED_AT`.** A global, UTC to the second in
  the shape `run:` already uses, set *inside* the existing lock block
  `if [ "$LIST" = 0 ] && [ "$AUDIT" = 0 ]; then … fi` (`scripts/gates.sh:244-250`),
  before or after `run_lock_acquire` - GREEN's choice. Inside that block and
  not at top level because `--list` is under a process budget (AC-6,
  HARNESS-024) and `date` is a process; `--list` and `--audit` never record,
  so they never need it. `set -u` is on (`:47`): `record_in_story` is only
  reachable from a full run, which is inside the block, so the variable is
  always set where it is read.

      RUN_STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  `scripts/run-lock.sh` writes its own `started` field with its own `date`;
  the two are not unified by this story (Out of scope).

- **`record_in_story() { # <story-file> <result-text> <summary-lines>`**
  (`scripts/gates.sh:299`) keeps its name and three arguments and gains a
  return value: `0` the record was written, `1` it was declined because the
  file already holds a record whose `run:` is later than `$RUN_STARTED_AT`.
  On `1` it writes nothing - not the `.tmp`, not an appended section - and
  sets a global `RECORD_SKIPPED` to the standing record's `run:` value,
  verbatim. `RECORD_SKIPPED=""` is initialised beside the function. The
  downstream implementation, verbatim, which GREEN may take as-is:

      RECORD_SKIPPED=""
      record_in_story() { # <story-file> <result-text> <summary-lines>
        local f="$1" res="$2" body="$3" commit tree block prev pn cn
        # Never overwrite a record whose run: is LATER than this run's start.
        prev="$(awk '/^## Gate results/ { b = 1; next } b && /^## / { exit } b && $1 == "run:" { print $2; exit }' "$f")"
        pn="${prev//[!0-9]/}"; cn="${RUN_STARTED_AT//[!0-9]/}"
        if [ -n "$pn" ] && [ "${#pn}" = "${#cn}" ] && [ "$pn" -gt "$cn" ]; then RECORD_SKIPPED="$prev"; return 1; fi
        commit="$(commit_with_note)"
        tree="$(gate_tree_hash)"
        block="$(printf '%s\n' \
          "$GATE_MARKER" \
          "" \
          "    run:    $RUN_STARTED_AT" \
          …   # the rest of the function unchanged

  **The semantics behind the comparison.** `prev` is the first `run:` value
  inside `## Gate results`, read by awk from the section only (a `run:` in
  `## Notes` or a comment is not a record). Both timestamps are reduced to
  their digits and compared as integers - `20990101000000` against
  `20261012…` - which is a correct ordering only while both are the same
  width, hence the `${#pn} = ${#cn}` guard: a malformed or hand-edited
  `run:` of a different width never declines a record, it is simply
  replaced (AC-5's "older record is replaced" is the one direction; the
  guard is why a garbage `run:` lands on that side rather than on "decline
  forever"). Strictly greater: a record from the same second is
  overwritten, which keeps a re-run inside one second from being refused
  for nothing. `run:` now means *when the run started*; a run started at
  `S` that finds a record `R > S` is by definition from a run that started
  after it, and that run's verdict is the later one.

- **The caller** (`scripts/gates.sh:991-992`, in the `else` branch of the
  record block) tests the return value and prints one of two lines, keeping
  the exit code it would have had either way:

      if record_in_story "$STORY_FILE" "$result" "$(printf '%b' "$results")"; then
        printf '\nrecorded in docs/backlog/stories/%s.md (## Gate results)\n' "$STORY"
      else
        printf '\n(not recorded: docs/backlog/stories/%s.md already holds a record from a gate run that started at %s; this one started at %s, so the newer record stands)\n' "$STORY" "$RECORD_SKIPPED" "$RUN_STARTED_AT"
      fi

  The `(not recorded: ` prefix is the one every other decline already uses
  (`:983-989`), so the existing `count_re '^\(not recorded:'` assertions in
  `gates.test.sh` (`:1477`, `:1492`, `:1502`, `:1511`) keep meaning what
  they mean. Exit status is computed before this block and untouched by it.
  `.claude/state/last-gate-run` is written before this block (`:950-962`)
  and untouched by it (AC-3).

- **The record's `run:` line** writes `$RUN_STARTED_AT` instead of a fresh
  `date`. Readers: none in scripts (`check-boundaries.sh` reads `result:`
  at `:394` and `tree:` at `:433`, nothing reads `run:`). The skill
  (`.claude/skills/quality-gates/SKILL.md:499-500`, "a marker line, the UTC
  time, the commit") is amended to "the UTC time the run started", plus one
  sentence: a full run that finds a record from a run that started later
  declines to record, says so on a `(not recorded: …)` line, and leaves the
  newer record standing. A docs edit, allowed in every phase; GREEN makes it.

- **Tests** go in `.claude/tests/gates.test.sh` as a new `describe` block
  near the HARNESS-026 record-refusal cases (`:1442-1519`), using the same
  fixture discipline: `story "$FIX" T-1 GATES </dev/null`, `git checkout -q
  -B story/T-1-fixture`, `set_phase "$FIX" GATES`, commit after planting the
  record. The downstream fixture-planting, adapted and known to work on this
  tree (it is what the triage ran):

      MARKER="$(sed -n "s/^GATE_MARKER='\(.*\)'$/\1/p" "$FIX/.claude/hooks/lib.sh")"
      {
        sed -e '/^## Gate results/q' "$FIX/docs/backlog/stories/T-1.md"
        printf '\n%s\n\n' "$MARKER"
        printf '    run:    2099-01-01T00:00:00Z\n    commit: deadbee\n    tree:   abc123\n'
        printf '    result: pass (1 ran, 0 unconfigured, 0 known)\n    PASS         unit (0s)\n\n'
        printf '## Notes\n'
      } > "$FIX/t1.new" && mv "$FIX/t1.new" "$FIX/docs/backlog/stories/T-1.md"
      git -C "$FIX" add -A >/dev/null 2>&1; git -C "$FIX" -c user.email=t@t -c user.name=t commit -qm s2 >/dev/null 2>&1

  Anchor the needles (rules.md, "an assertion's needle is part of the
  assertion"): count `^recorded in docs/backlog/stories/T-1\.md` and
  `^\(not recorded: .*2099-01-01T00:00:00Z` with `count_re`, never a bare
  `assert_contains "not recorded"` (which the untracked-file and branch
  refusals would also satisfy). AC-2 compares the whole `## Gate results`
  section before and after (`sed -n '/^## Gate results/,/^## Notes/p'`),
  not only the `run:` line. Suite command: `bash scripts/selftest.sh gates`.
  No wall-clock `sleep`, no background process: every case here is
  deterministic because the "newer" record is planted, not raced.

- **`sigpipe` line pins.** `.claude/tests/sigpipe.test.sh:567-568` pin
  `scripts/gates.sh:74:BOOTSTRAPPED="$(grep` and
  `scripts/gates.sh:580:why="could not launch: $(`. This port adds about six
  lines above `:580` (one in the lock block, `RECORD_SKIPPED=""`, three
  comparison lines and a comment in `record_in_story`) and four at `:991`,
  so the `:580` pin moves and the `:74` pin does not; HARNESS-055 will have
  moved it already. GREEN updates the pin to the new line, confirms with
  `bash scripts/selftest.sh sigpipe`, and runs the full `bash
  scripts/selftest.sh` before REVIEW (memory: CI runs every suite).

- **Oracle partition.** Every criterion is *mechanical*: exact lines, exact
  counts, an exact timestamp, exit codes, a byte-for-byte section. Pin
  exactly. The one *settled* value is the comparison rule above (strictly
  later, same width, digits only): read it out, do not redesign it.

- **No signature changes.** `record_in_story` keeps its arguments; its only
  caller is `scripts/gates.sh:991` (`grep -rn record_in_story scripts
  .claude` finds the definition, that caller, and nothing in tests). A
  return value added to a function whose caller ignored it is not a changed
  signature; the caller is changed in the same story.

- **Test-only dependencies:** none. bash, awk, coreutils (rules.md,
  Portability).

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

- **DV-1 (defect put back)** — With the comparison disabled again in
  `record_in_story` (through `scripts/mutate.sh`, a `sed` that turns the
  `-gt` into `-lt`, or deletes the `return 1` line - GREEN's exact spelling
  decides which), AC-1's "no `recorded in` line / one `(not recorded:` line"
  and AC-2's "the 2099 `run:` still stands" MUST go red in the `gates`
  suite, with the clobbering `run:` being this run's start time; AC-5
  (older record replaced) MUST stay green under the deleted-`return` form
  and MUST go red under the `-lt` form. RED cannot run this: the comparison
  it would disable does not exist yet. Owner: GATES. Command shape, for
  the orchestrator to adapt to GREEN's exact text:

      bash scripts/mutate.sh scripts/gates.sh \
        's/"\$pn" -gt "\$cn"/"$pn" -lt "$cn"/' \
        -- bash scripts/selftest.sh gates

  Paste the failing assertion names and the restore line here.

- **DV-2 (earning the controls)** — AC-3, AC-5 and AC-6 are green on the
  unpatched tree, so RED cannot watch them fail. They are earned by the
  mutation in DV-1 (AC-5 under `-lt`), and AC-3 by a second `sed` on the
  caller that replaces the `else` branch's `printf` with `exit 1` - the
  "declining changed the verdict" defect - which MUST turn AC-3's exit-code
  assertion red and nothing else. AC-6 is earned by its own existing
  instrument (HARNESS-024's process trace), which the lock-block placement
  is there to satisfy; moving `RUN_STARTED_AT` to top level with
  `scripts/mutate.sh` MUST raise the traced `--list` process count by one -
  paste the count, red or not, and say which. Owner: GATES.

That is the rules.md budget plus the controls the law owes: the central
claim's defect put back, and one mutation per test that arrives green.

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

Planned by `bash scripts/plan.sh write HARNESS-056` from `.claude/harness/models.conf`.
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

- PLANNED, `lead-po`, 2026-10-12: **Fable 5.1** (`claude-fable-5-1`) - the
  agent's declared `model:`, matching the plan; no override reported.

**Oracle partition for the RED brief:** every criterion is *mechanical*
(exact output lines counted with anchored regexes, an exact planted
timestamp, exit codes, a byte-for-byte `## Gate results` section, a process
count already instrumented by HARNESS-024); the comparison rule in the
Contract (strictly later, same width, digits only) is *settled* and is read
out, not redesigned. Nothing is oracle-free. Pin exactly, and plant the
"newer" record rather than racing for it - no `sleep`, no background run.

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

<!-- Explicit non-goals. Prevents the Feature Developer from over-building. -->

- **The downstream lock design (dccbbf6 half 1).** `GATES_LOCK_WAIT`,
  `--no-wait`, exit 3, polling, host-aware stale detection, rename-before-
  remove takeover. Upstream has `scripts/run-lock.sh` (HARNESS-034):
  refuse-never-wait, exit 2, pid-only staleness. That is a deliberate
  design difference, not a gap, and this story does not touch
  `run-lock.sh` or the lock's `started` field.
- **Reproducing a real path to two runs on one story file.** The three
  windows in Context are the triager's reading, not reproductions. The
  record-level invariant holds whichever path is real, and a fixture that
  plants a newer record is deterministic where a race is not. If the user
  wants a path reproduced, it is its own story (the nested-run shape is the
  cheapest: a gate command that runs `gates.sh` under the lock markers, with
  a `sleep` to cross a second boundary - which is the MC-044 class below).
- **Unifying `RUN_STARTED_AT` with `run-lock.sh`'s `started` field**, or
  passing one to the other. Two `date` calls, two purposes.
- **Changing what `check-boundaries.sh` reads.** It reads `result:` and
  `tree:` and keeps doing so; `run:` stays unread by tools.
- **The `no-count` port** (HARNESS-055, the other half of the triage diff)
  and whatever HARNESS-052 does to `gates.sh`. This story is serialised
  after 055 by `depends_on` because the three share `gates.sh` and the
  `sigpipe` pins; it does not carry their changes.
- **Sub-second ordering.** Two runs started inside the same second are not
  ordered by this story; the later writer wins, as today.
- **Follow-up, not this story: MC-044-class wall-clock live owners in
  upstream fixtures.** `.claude/tests/run-lock.test.sh:225-226` (`sleep
  600 &` twice, across ~20 invocations), `.claude/tests/mutate.test.sh:888`
  (`sleep 30 &`), `.claude/tests/gates.test.sh:2288` (`sleep 30 &`). Where
  one live pid suffices, `$$` (the test's own shell) removes the sleeper and
  the kill-on-exit bookkeeping. Worth a chore; it is not this fix, and this
  story adds no sleeper of its own.

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

- **Provenance.** Port of manhwa-cropper `dccbbf6` (2026-09-15, "harness:
  one gate run at a time, and a record that cannot go backwards"), half 2
  only. Triaged 2026-10-11 against release 93 in scratch
  `triage-gates1/` (`port.diff` - the `record` hunks; `up/.claude/tests/
  triage.test.sh` with `ONLY_PART=record`; `ported-gates.out`, the 507/0
  full-suite run). The scratch directory is gone; everything the next agent
  needs from it is pasted into Context and Contract above, verbatim for
  code.
- Planned 2026-10-12 on branch `harness/HARNESS-052-057-plan`, in the main
  checkout, by the Lead PO dispatched as a subagent alongside five sibling
  planners writing HARNESS-052..055 and 057; this planner wrote only this
  file. The model this planning dispatch resolved to is **Fable 5.1**
  (`claude-fable-5-1`), the agent's own declared `model:`; no override was
  reported to it. Recorded again under `## Model guidance` once `plan.sh
  write` has rendered it.
- `depends_on: [HARNESS-055]` is a serialisation, not a true dependency:
  052, 055 and 056 all edit `scripts/gates.sh` and the `sigpipe.test.sh`
  line pins, and `touches:` alone would only keep them out of one wave.
  The brief chose `depends_on` so that `phase.sh set` refuses to start this
  one early; `story-authoring` prefers `touches:` + waves for a pure
  collision, and the choice is recorded here so it is not read as "056
  needs something 055 decided". It does not - the two diffs are
  independent hunks of one file.
- Open question for the user (also in the planner's report): whether a
  record-level invariant is worth shipping without a reproduced real path
  to two runs on one story file. The planner's position: yes - it is
  deterministic to test, cheap, and the defence that catches the MC-026
  shape regardless of which lock window is real; the path reproduction is
  cut separately if wanted (Out of scope).
