---
id: HARNESS-071
title: A blocked required gate reaches REVIEW on pending CI
slug: a-blocked-required-gate-reaches-review-on
epic: 
type: fix
status: in-review
phase: REVIEW
branch: story/HARNESS-071-a-blocked-required-gate-reaches-review-on
depends_on: []      # story ids; phase.sh refuses to start this story until they are DONE
touches: [scripts/check-boundaries.sh, .claude/tests/boundaries.test.sh, .claude/tests/sigpipe.test.sh] # files this story expects to write; `plan.sh conflicts` reads it
required_gates: []  # gate ids that are optional for the repo but binding for THIS story
---

## Context

Found in clean_calendar, a consuming project, on CAL-016 (2026-10-23). Its
`db` gate is in the story's `required_gates` and was BLOCKED on the dev
machine (no Docker), so the story went to REVIEW with a one-line "db ...
pending CI" decision, as `/advance-story` prescribes. `check-boundaries.sh`
refused the REVIEW commit anyway:

- 3e, the BLOCKED check, accepted `db` on its pending-CI line;
- 3e-i, the story-required-gate loop, demanded a PASS for `db` in the
  record - `frontmatter requires gate 'db', but the recorded run has no PASS
  for it`.

A gate is only BLOCKED because it is required, and one the story escalated is
required for exactly that reason, so the two rules always collide: the
pending-CI path is closed to every story that escalated the gate it blocked
on. No local run can produce the PASS 3e-i demands. The existing case in
`boundaries.test.sh` ("a gate the story escalated for itself appears in the
record") pins the contradiction itself: a `[types]` story with a pending-CI
note, asserted refused.

clean_calendar fixed it in its vendored copy (commit 4df9364, PR
ryanczhang7/clean_calendar#17: boundaries 117/0, sigpipe 82/0, 26 suites).
This story carries the fix upstream. Here 3e-i sits in its own
`case "$ph" in REVIEW|DONE)` block outside 3e (HARNESS-062 moved it there so
spikes and stories without a record are judged too), so `bgates` - computed
inside 3e's `blocked*)` arm - is not in the loop's scope by construction and
has to be put there deliberately.

## Acceptance criteria

- **AC-1** — Given a story at REVIEW whose `required_gates` names a gate the
  recorded run shows `BLOCKED`, with a line naming that gate and "pending CI",
  `check-boundaries.sh` prints
  `ok    story-required gate '<g>' was BLOCKED; judged as pending CI above`
  and exits 0. Unfixed, it exits non-zero with the "no PASS" refusal.
- **AC-2** — The same story with no pending-CI line is still refused, by the
  BLOCKED check (`gate '<g>' was BLOCKED - the environment would not launch
  it - and nothing in the story says so`).
- **AC-3** — The same story at DONE with no CI run URL is still refused
  (`gate '<g>' was BLOCKED locally and has not been verified on CI`).
- **AC-4** — A required gate that is in the record neither as PASS nor as
  BLOCKED (escalated after the run) is still refused with
  `frontmatter requires gate '<g>', but the recorded run has no PASS for it`,
  and the existing control (a required gate that passed is reported passing,
  exit 0) is unchanged.
- **AC-5** — A spike story, which 3e does not judge, gets no deferral: a
  BLOCKED required gate there is not excused by 3e-i, because no BLOCKED check
  ran above it.

## Contract

**Writes:** `scripts/check-boundaries.sh`, `.claude/tests/boundaries.test.sh`, `.claude/tests/sigpipe.test.sh`

`scripts/check-boundaries.sh`:

- `bgates=""` immediately before 3e's `case "$ph:$story_type" in`, so it is
  set in the script's scope whatever 3e does, and non-empty only when 3e's
  `blocked*)` arm ran - which is when the BLOCKED check judged each gate in it.
  Spike, no marker, a `pass` result: empty, so 3e-i defers nothing (AC-5).
- In 3e-i's loop, first branch:
  `if grep -qx -- "$g" <<< "$bgates"; then ok "story-required gate '$g' was BLOCKED; judged as pending CI above"`,
  then `elif` the existing PASS awk, `else` the existing refusal. A
  here-string, not `printf | grep -q`: `check-sigpipe.sh` flags the pipe
  under pipefail. `-x` so `unit` does not match a blocked `unit-slow`.
- The 3e-i comment says why a BLOCKED required gate is deferred.

`.claude/tests/boundaries.test.sh`, describe "a gate the story escalated for
itself appears in the record": the case asserting refusal for
`story_blocked REVIEW '[types]'` with a pending-CI note is replaced by:
escalated-after-the-run (`lint` added to frontmatter after the run, refused,
AC-4); blocked required + pending CI (ok line and exit 0, AC-1); no pending-CI
line (refused by the BLOCKED check, AC-2); DONE without URL (refused, AC-3).
AC-5 gets one case: a spike with `required_gates: [types]` and a BLOCKED
record with a pending-CI line is refused with the "no PASS" message.

`.claude/tests/sigpipe.test.sh`: the `DISCARDED` line numbers for
`check-boundaries.sh` follow the edit.

Oracle partition: all mechanical (exact messages and exit codes).

## Deferred verifications

**DV-1 (defect put back).** With the 3e-i deferral branch removed from the
fixed script through `scripts/mutate.sh` (the `grep -qx` condition made never
true), `bash scripts/selftest.sh boundaries` must fail AC-1's two assertions
and nothing else. **Owner: GATES.**

**DV-2 (the deferral is conditional).** AC-4's case passes on arrival - the
refusal already exists. With the deferral made unconditional (`if true; then`
in place of the `grep -qx` condition), `bash scripts/selftest.sh boundaries`
must fail AC-4's refusal. **Owner: GATES.**

**DV-3 (only what 3e judged is deferred).** AC-5's case passes on arrival too.
With 3e's spike arm made unreachable (so a spike's BLOCKED record is judged by
3e and `bgates` set), the same suite must fail AC-5's refusal. **Owner: GATES.**

AC-2 and AC-3 assert refusals 3e already makes and the existing cases in
"a BLOCKED gate can reach REVIEW" already earned for a story without
`required_gates`; here they pin that the deferral does not reach past 3e, and
DV-1's run shows them unaffected.

Results, GATES, 2026-10-23 (orchestrator), this worktree at the GREEN commit.
Each through `scripts/mutate.sh`, output filtered to the mutate banners, FAIL
lines and the suite total; `mutate.sh --check` clean afterwards.

DV-1 - exactly AC-1's two assertions, nothing else (AC-2..AC-5 still green):

    === mutate: scripts/check-boundaries.sh (1 line(s) changed by s/if grep -qx -- "[$]g" <<< "[$]bgates"; then/if false; then/) ===
        FAIL a required gate that was BLOCKED defers to the pending-CI check
        FAIL and a blocked required gate recorded as pending CI is not refused
    boundaries: 139 passed, 2 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-071/.claude/state/mutations/scripts_check-boundaries.sh.20261023T202447Z.94652.bak) ===

DV-2 - AC-4's refusal goes red (with AC-5 and the `[unit]` control, which an
unconditional deferral also excuses):

    === mutate: scripts/check-boundaries.sh (1 line(s) changed by s/if grep -qx -- "[$]g" <<< "[$]bgates"; then/if true; then/) ===
        FAIL a required gate the record has no PASS for
        FAIL a spike's blocked required gate is not deferred, since nothing judged it
        FAIL one that did pass is reported as passing
    boundaries: 129 passed, 12 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-071/.claude/state/mutations/scripts_check-boundaries.sh.20261023T205744Z.128159.bak) ===

DV-3 - AC-5's refusal goes red:

    === mutate: scripts/check-boundaries.sh (1 line(s) changed by s/REVIEW:spike|DONE:spike)/REVIEW:nospike|DONE:nospike)/) ===
        FAIL a spike's blocked required gate is not deferred, since nothing judged it
    boundaries: 138 passed, 3 failed
    === mutate: command exited 1; restored (verified byte-for-byte against /d/adh-HARNESS-071/.claude/state/mutations/scripts_check-boundaries.sh.20261023T212857Z.160626.bak) ===

(The filter kept only FAIL lines of the form `FAIL <lowercase>`; the other
failures in DV-2 and DV-3 are existing spike and required-gate cases whose
names begin otherwise. The condition each entry states is met either way.)

## Model guidance

Planned by `bash scripts/plan.sh write HARNESS-071` from `.claude/harness/models.conf`.
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

- PLANNED, RED, GREEN, GATES: the orchestrating session itself, **Opus 5.5
  (`claude-opus-5-5`)**, no dispatch. PLANNED planned for `fable`: departed
  from, for a port of a fix already diagnosed, reproduced and merged-tested
  downstream (clean_calendar 4df9364). Success condition: AC-1 red unfixed,
  green fixed, DV-1..DV-3 as stated - met (above).

<!-- One line per dispatch, as it happened: phase, agent, the model that
     actually ran, and — if a phase was planned for one model and ran on
     another — what that changed. A choice with no verdict is folklore. -->
## Out of scope

- How `/advance-story` words the pending-CI decision; unchanged.
- gates.sh's own required-gate enforcement while it runs; unchanged.

## Test plan

## Handoff: RED -> GREEN

Command: `bash scripts/selftest.sh boundaries`. Tests, all in the describe
"a gate the story escalated for itself appears in the record" of
`.claude/tests/boundaries.test.sh`: the old `[types]`-refused case is
replaced by AC-4 (`lint` escalated after the run, refused), AC-1 (ok line,
exit 0), AC-2 (no pending-CI line, refused by 3e), AC-3 (DONE without URL,
refused), AC-5 (spike, refused with the "no PASS" message). The existing
`[unit]` control after them is unchanged.

Against the unfixed `check-boundaries.sh` (RED, 2026-10-23), exactly AC-1's
two assertions fail, and with the refusal the story's Context describes:

    a gate the story escalated for itself appears in the record
      FAIL a required gate that was BLOCKED defers to the pending-CI check
           expected to contain: ok    story-required gate 'types' was BLOCKED; judged as pending CI above
           ...
           FAIL  story T-1: frontmatter requires gate 'types', but the recorded run has no PASS for it. Run 'bash scripts/gates.sh' again.
      FAIL and a blocked required gate recorded as pending CI is not refused
           expected: 0
           actual:   1
    boundaries: 139 passed, 2 failed

AC-2..AC-5 pass on arrival: they pin refusals that exist today and must
survive the change. AC-4 and AC-5 are earned by DV-2 and DV-3 at GATES; AC-2
and AC-3 as the Deferred verifications section says. GREEN writes only
`scripts/check-boundaries.sh` as the Contract states, then moves the sigpipe
suite's `DISCARDED` line numbers (a test file - so that edit is a RED change,
made now if the shift is predictable, otherwise a return to RED).

## Gate results

<!-- gates.sh: written by bash scripts/gates.sh; do not edit or paste by hand -->

    run:    2026-10-23T22:04:45Z
    commit: e1ca2b2
    tree:   afeb0f4e6edbfb682085f884faf70b09376c3a27
    result: pass (0 ran, 7 unconfigured, 0 known)

    UNCONFIGURED format
    UNCONFIGURED lint
    UNCONFIGURED typecheck
    UNCONFIGURED unit
    UNCONFIGURED coverage
    UNCONFIGURED integration
    UNCONFIGURED build
    ON REQUEST   mutation (not run: per-story cost the user declined (HARNESS-015); run it with /audit-mutations; bash scripts/gates.sh --gate mutation)

## Notes

**Full self-test at GATES (2026-10-23, this worktree at 090ab6f), run alone
after HARNESS-068's self-test in the main checkout had exited, 4,309 s:**

    assertion floors: all 28 suite(s) met their declared floor (4005 assertions executed, 3825 declared).
    28 harness suite(s) passed.
    exit=0 duration=4309s
